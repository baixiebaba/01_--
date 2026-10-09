# ARPM02 坏账计算三步骤核对与修复技术设计

## 概述

本设计限定为 Oracle PL/SQL 存储过程的最小、可追溯修复，目标文件为 `01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_BD_M_PHASE2.sql`。以 Excel 的三个工作表为业务基准，按 STEP1→STEP2→STEP3 顺序核对并修复现有过程；不修改 Excel、表结构、调度、其他 SQL 或提交 Git。技术栈锁定为 Oracle PL/SQL（过程内 MERGE/CTE/窗口函数）及 Python 标准库 `zipfile`/`xml.etree.ElementTree` 的一次性本地结构检查；由于环境没有 Oracle 连接，数据库对象元数据和编译结果必须作为实施前阻断条件，不可假定通过。

本设计保留过程签名、目标表 `AW_MR9_ARPM02_000001`、日志表 `ZTAB_CPM_LOG`、会话公司范围表及现有 `TGK_GB_HISENSE.FORM_DATI` 接口。仓库中没有可确认的 `AW_RUL_ARPBDR_000001`、`BD_RATIO_1..15`、`SPC_REB_DED_AMT` 等接口，因此不把它们写入静态 SQL，也不通过臆造字段替换现有接口。

## 设计依据与核对边界

Excel 三个指定 sheet 先用本地 OOXML 结构化读取：根据 `xl/workbook.xml` 与关系文件定位 sheet，解析 shared strings、单元格坐标和值；输出需保留 sheet 名、行号、字段名、来源、过滤、关联键、公式和目标字段映射。若本地环境安装 `openpyxl`，可用只读模式复核，但不能以截图或人工浏览代替结构化结果。设计实施只接受三个 sheet 均存在且关键区域可解析的结果。

当前过程已确认的接口和现状作为待修复基线：STEP1 从 `AW_MR9_ARPM01_000001` 的 `D_ADJ_TYPE='ARP_02_001'` 汇总 `SPC_DSV_DED_AMT`，并依据目标表 `BCY_ADJ_INCL_1..15` 做垫资扣减、长账龄优先负数冲减和明细比例回写；STEP2 从 `ARP_02_002` 汇总个别认定并以 `FORM_DATI` 的 `IMPORTO_6..12、22、21` 匹配比例；STEP3 汇总负数坏账为 `AGE_ALLOC_1..15`，结合正数行比例、上月 `BD_AFAL_0_AMT` 和核销表计算 `BD_AFAL`、`MTD_BD_PROV_OCUR_AMT`。上述每一项仍须与 XML 读取的字段/公式逐项对照，只有有文档或确定静态依据的问题才修改。

## 公共参数、范围和失败边界

过程入口首先保存原始参数到局部变量，再按以下顺序验证，验证完成前不写会话范围表：`P_SCENARIO` 必填且匹配 `^[0-9]{4}[A-Za-z0-9_]+$`；`P_PERIODO` 必填且只允许一至两位数字，解析后必须为 `01` 到 `12`；`P_AZIENDA` 必填且为 `ALL` 或逗号分隔的非空公司/节点编码，去除每项两侧空格后不得包含逗号、引号、空白内部字符或通配符；`SESSION_USER` 必填且长度不超过目标日志字段允许长度。场景年份和期间解析失败使用固定应用错误 `-20001`，公司参数格式错误使用 `-20002`，有效公司解析为空使用 `-20003`；错误消息包含字段名但不回显超长原始值。

随后计算当前/月前场景和期间，清理并重建 `SESSION_AZIENDA_LIST`、`SESSION_V_REF_AZIENDA`。若解析后的公司列表为空，属于致命错误：写 ERROR 后抛出，不执行任一步骤。会话表仍按 `SESSION_ID` 隔离，成功和失败均清理本 session 的行。

异常处理采用嵌套保护，避免清理或日志失败覆盖原异常：主异常块先保存 `SQLCODE`、截断后的 `SQLERRM` 和原始场景/期间/公司参数；在独立 `BEGIN ... EXCEPTION WHEN OTHERS THEN NULL END` 中执行 `ROLLBACK` 后的会话清理，在另一个独立嵌套块中插入 ERROR 日志并提交；最后用保存的错误码重抛（应用错误保留原码，普通错误使用 `RAISE` 语义）。清理失败和日志失败只作为内部告警，不替换原始异常；日志包含过程名、固定错误步骤、原始参数和已解析公司范围（若尚未解析则使用原始 `P_AZIENDA`）。每个 STEP 的成功日志和提交点保持现有顺序，异常不会声称成功。

## 结构元数据预检与未知接口处理

不能在过程内用静态 SQL 引用不存在的规则表或列，因为缺失对象会在编译阶段失败。实施前执行一次只读 `ALL_TAB_COLUMNS`/`ALL_OBJECTS` 查询，owner 和完整白名单固定为现有过程实际引用的 owner/table/column：`TGK_GB_HISENSE.FORM_DATI` 的 `COD_PROSPETTO、COD_SCENARIO、COD_PERIODO、COD_AZIENDA、COD_CONTO、COD_CATEGORIA、TESTO_14、TESTO_2、IMPORTO_6..12、IMPORTO_21、IMPORTO_22、OID_FORM_DATI`，以及目标表、调整表、投保表、核销表所用列。owner 不从用户参数拼接。

预检缺表、缺列、类型不兼容或目标表账龄列不存在时，阻断部署/实施并记录结果；不得生成静态引用，也不得用动态 SQL 绕过未知业务接口。`FORM_DATI` 的真实 owner 继续使用代码中已存在的 `TGK_GB_HISENSE`。只有在 Oracle 元数据确认另有设计对象且字段清单与 Excel 一致时，才另行评审并扩展接口，本次设计不包含该变更。

## STEP1：坏账计提基数

保留目标行过滤：当前 `COD_SCENARIO/PERIODO` 且公司在本 session 范围内；以 `OID` 作为目标行唯一键。调整来源按文档指定的 `COD_SCENARIO、COD_PERIODO、COD_CATEGORIA='ZFAMOUNT'、D_ADJ_TYPE='ARP_02_001'` 和文档规定的公司/客户/目的地维度先聚合，再连接目标；垫资扣减只作用于正数基础，账龄按 15→1 长账龄优先，负数总额按同一公司、客户和文档指定粒度冲减正数，最后按原目标行该账龄正数占比分配。每个账龄结果和 `BD_BASE_0_AMT` 按设计公式汇总，空来源以零处理，不把个别认定、上月坏账或核销混入 STEP1 基数。

`BASE_DATA`、`AGE_UNPIVOT`、`AGE_PROGRESS`、`DEDUCTED_AGE`、`AGE_SUMMARY`、`AGE_FIFO`、`AGE_ALLOCATED`、`BASE_RESULT` CTE 边界保留，避免无关格式化。修复只针对 XML/静态检查确认的过滤或粒度差异。来源聚合完成后必须有 `GROUP BY OID` 唯一性断言；目标当前范围必须满足 `COUNT(*)=COUNT(DISTINCT OID)`。断言失败在 MERGE 前写 ERROR、回滚并终止，不等待 `ORA-30926`。

## STEP2：坏账计算、比例和个别认定

个别认定来源按完整业务键聚合：`COD_SCENARIO、COD_PERIODO、COD_AZIENDA、CUST_CODE、COD_DEST2、NATURE_L3_NAME`，并按 `D_ADJ_TYPE='ARP_02_002'`、`COD_CATEGORIA='ZFAMOUNT'` 过滤。先把当前范围目标行 `SPID_0_AMT..SPID_15_AMT` 清零，再将有来源的聚合结果写回，防止上次运行的旧值残留；来源行是否存在不能由金额是否为零推断。

不新增目标列保存状态，而是在 STEP2 的计算 CTE 中按同一完整业务键重新聚合来源，并以 `COUNT(*) > 0 AS HAS_INDIVIDUAL` 传递存在状态到 STEP3。来源存在时，即使各账龄合计为零或为负，个别认定金额仍覆盖普通计提；来源不存在时才使用 `BD_BASE_n_AMT × FORM_DATI 比例 × 投保未覆盖系数`。所有账龄使用文档确认的比例映射；当前已确认的 `IMPORTO_6..12、IMPORTO_22、IMPORTO_21` 映射到 1..9，10..15 按设计若无输入明确为零，不引入未验证的 `BD_RATIO` 字段。比例按公司归并、科目、类别及客商/性质/通用优先级匹配，必须先聚合或排名为每个 OID 一行；同一优先级存在多条有效规则时不静默取任意行，应在 MERGE 前断言并终止。无匹配比例按设计为零，并记录静态核对结果。

`CALCULATED_n` 明确区分普通计提和个别认定，不用 `<> 0` 判断个别认定。负数金额保持符号，不取绝对值；`BD_0_AMT` 为各账龄和，STEP2 只写坏账计算结果，不在此阶段混入上月或核销。STEP2 来源键和目标 OID 均需执行重复断言，成功后才 MERGE 并提交。

## STEP3：账龄分摊、上月、核销及写回

负数坏账按 Excel 规定的分摊池和账龄顺序汇总，正数坏账行按 `BD_0_AMT` 在同一文档维度计算 `BD_ALLOC_RATIO`；`AGE_ALLOC_n_AMT` 为负数池各账龄金额乘正数行比例，`AGE_ALLOC_0_AMT` 是 1..15 明细之和。实现不得把 10..15 无依据地硬编码成零：若 XML 规定该范围参与分摊，则从 STEP2 的 `BD_10..15` 传递；若 XML 明确未使用，保留零并在核对记录中说明。

`HAS_INDIVIDUAL` 采用 STEP2 约定的完整键重新聚合并用 `COUNT(*)>0`，不能用 `SPID_n IS NOT NULL`、`SPID_n <> 0` 或 `BD_n <> 0` 替代。来源存在时 `BD_AFAL_1..15 = SPID_1..15`（包含零值和负值）；无来源时正数行使用 `BD_n + AGE_ALLOC_n_AMT`，负数行按设计写零/对应个别结果。`BD_AFAL_0_AMT` 始终为 1..15 合计。

上月数据按 Excel 明确的公司、客户、目的地及其他维度聚合 `LM_BD_AFAL_0_AMT`；核销按文档规定的公司、科目、客户、目的地和销售部门键聚合 `WRITEOFF_AMT`。只有文档确认的键才进入 JOIN，避免把上月或核销多对多放大。`MTD_BD_PROV_OCUR_AMT = BD_AFAL_0_AMT - LM_BD_AFAL_0_AMT + WRITEOFF_AMT`，符号保持来源符号，且在统一汇总后写回。

金额精度采用以下固定实施门槛：部署前必须用 `ALL_TAB_COLUMNS.DATA_SCALE` 查询 `AGE_ALLOC_n_AMT、BD_AFAL_n_AMT、MTD_BD_PROV_OCUR_AMT` 目标列。若目标列为无定标 `NUMBER`，计算不 ROUND，并以 Oracle NUMBER 精确勾稽；若目标列有定标，统一使用 `ROUND(value, DATA_SCALE)`，按稳定唯一 `OID` 升序让每个分摊池的最后一行写入“来源总额减此前已写入额”，吸收尾差。该查询结果必须在实施记录中固定，不能由实现者临时选择；缺少 scale 或唯一排序键时阻断实施。允许勾稽误差为 0（精确 NUMBER）或不超过最小定标单位（定标列）。

## MERGE 唯一性与事务

每个 MERGE 前执行只读断言：目标当前范围 `OID` 唯一；USING 来源按 MERGE 键聚合后 `COUNT(*)=COUNT(DISTINCT OID)`；个别认定完整业务键、比例匹配键、核销键和上月键均不得产生一对多结果。发现重复时先写带步骤和键摘要的 ERROR，回滚当前批次并停止。断言 SQL 不修改业务表；日志失败按公共异常策略处理。

过程继续在 STEP1、STEP2、STEP3 成功后分别记录日志并提交，保持步骤间结果可复用。每个步骤只写本步骤负责的字段，STEP3 最后写 `AGE_ALLOC`、`BD_AFAL`、上月坏账、核销、计提方式及 `MTD_BD_PROV_OCUR_AMT`；不更新 `PROVENIENZA`。

## 文件修改点与实施顺序

只修改 `/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_BD_M_PHASE2.sql`：文件头在现有“版本信息：最新修改记录放最上面”下新增本次日期和修复摘要，保留历史记录；在入口加入参数校验和安全异常边界；在 STEP2 增加个别认定存在状态的重新聚合和清零旧值；在 STEP3 采用 `HAS_INDIVIDUAL` 选择 `BD_AFAL`；按 XML 核对结果修复确证的键、账龄和公式差异；在各 MERGE 前加入可执行重复断言（使用现有日志，不新增表）。不改现有 CTE 名称和无关排版。

实施顺序固定为：先以 Python 标准库 XML 读取三个 sheet 并保存本轮报告中的行/字段证据；再执行 Oracle 元数据预检，确认 owner、列清单和目标 scale；然后修改过程；最后只读静态检查和 Oracle 编译/测试（若获得连接）。不创建验证脚本文件、不创建临时仓库产物、不修改 Excel；验证命令使用内联 Python/命令行，结果写入后续报告而非仓库。

## 错误处理和可测试性

可单元测试的部分是 XML sheet 定位/单元格解析、正则参数校验、年龄 FIFO/负数冲减公式、个别认定存在标志和尾差公式；可集成测试的部分是 Oracle CTE 聚合、FORM_DATI 优先级、MERGE 唯一性断言、会话公司范围、日志/提交/回滚。最小 Oracle 测试数据必须覆盖：无个别来源、来源全零、来源负数、来源正负混合、FORM_DATI 无匹配/多匹配、15 个账龄、零正数分母、核销/上月无匹配、多条来源重复以及目标 OID 重复。每个场景检查 STEP2 到 STEP3 的金额勾稽和写回字段。

没有 Oracle 连接时只能运行本地 XML/静态结构验证，不能声称 PL/SQL 编译、对象权限、目标 scale、重复断言、金额勾稽或运行结果已验证；这些全部列为未验证项。若 `ALL_TAB_COLUMNS` 预检失败或三个 sheet 解析失败，实施步骤应停止，不生成会编译失败的 SQL。

## 上线前只读核对 SQL

上线核对 SQL 不写入过程、不创建仓库文件，由发布人员在 Oracle 客户端以相同 `P_SCENARIO/P_PERIODO/P_AZIENDA` 解析出的 session 范围执行：查询目标范围 OID 重复；逐 OID 检查 `BD_BASE_0_AMT` 等于 1..15 之和；检查 `BD_AFAL_0_AMT` 等于 1..15 之和；按文档分摊池检查 `SUM(AGE_ALLOC_n_AMT)` 与负数来源账龄合计相等；检查 `MTD_BD_PROV_OCUR_AMT` 等于期末减上月加核销；检查每个 MERGE 键的重复计数为零。核对 SQL 是只读查询，不提交、不回滚、不改变过程事务；具体查询文本放在发布报告/运行手册，不作为本次变更文件。

## 对本轮设计评审发现的响应

1. **规则表/字段预检：已处理。** 明确 owner、完整白名单和 `ALL_TAB_COLUMNS`/`ALL_OBJECTS` 部署前阻断；不在静态过程引用未确认的规则对象，缺表/缺列不生成 SQL。
2. **零值/负值个别认定状态：已处理。** 不新增列，STEP2/STEP3 按完整业务键重新聚合并用 `COUNT(*)>0` 得到 `HAS_INDIVIDUAL`；`BD_AFAL` 不再用金额非零判断，并纳入零值、负值测试。
3. **参数、空公司、错误日志：已处理。** 给出校验顺序、固定错误码、原始参数记录和嵌套清理/日志异常保护，保存原错误后重抛。
4. **MERGE 唯一性：已处理。** 每个 MERGE 前明确目标 OID、来源 OID、比例/投保/核销/上月键的重复断言及失败时机。
5. **精度/尾差：已处理。** 以 `ALL_TAB_COLUMNS.DATA_SCALE` 为实施阻断门槛；无定标 NUMBER 不舍入，有定标列统一 ROUND 并按唯一 OID 由最后一行吸收尾差，误差阈值固定。
6. **验证脚本范围：已处理。** 不创建验证脚本文件，使用一次性内联 Python/XML 和命令行验证，仓库只允许目标过程文件变更。
7. **上线核对 SQL：已处理。** 明确为发布报告/运行手册中的只读查询，不写入过程、不影响事务，参数、检查项和预期结果已定义。
