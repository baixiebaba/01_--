# 设计评审：ARPM02 坏账计算三步骤

## 结论

**CHANGES_REQUESTED**。共 7 个 HIGH、2 个 MEDIUM、1 个 NIT；存在未解决的核心规则来源、字段覆盖、账龄范围和实施可行性问题，当前设计不能直接交给实现。

## Findings

1. **[HIGH] STEP2 的比例来源被设计错误地排除，导致核心业务规则无法实现。** 位置：`02-design.md`“概述/结构元数据预检与未知接口处理”及“STEP2”段，设计称仓库没有 `AW_RUL_ARPBDR_000001`、`BD_RATIO_1..15`，因此“不把它们写入静态 SQL”。但已结构化读取的 Excel `ARPM02-坏账计算表-STEP2坏账计算` 第 26 行明确规定：BATCH_ID=1/2/3 分别按客户级、性质级、通用级匹配 `AW_RUL_ARPBDR_000001`，并取 `BD_RATIO_1`；第 27–40 行要求各账龄使用对应比例。现有源码反而用 `TGK_GB_HISENSE.FORM_DATI` 的 `IMPORTO_6..12、22、21`，且只实现 1–9 账龄。具体修复：将设计基准改为 Excel 规定的规则表，定义 owner、列白名单、BATCH_ID 优先级、`GRP_SCOPE` 前三位匹配、客户字段使用 `CUST_HEAD_CODE` 还是 `CUST_CODE` 的精确规则，并给出每个 `BD_RATIO_1..15` 到 `BD_n_AMT` 的映射；实施前预检该对象，缺表/缺列即阻断。若业务确认继续用 FORM_DATI，必须先修改 Excel/需求，而不能在设计中擅自替换。

2. **[HIGH] STEP2 的 10–15 账龄处理与 Excel 明确要求冲突，设计仍保留不确定分支。** 位置：`02-design.md`“STEP2”及“STEP3”段写成“10..15 按设计若无输入明确为零”“若 XML 规定参与则传递”。但 XML 已明确：STEP2 输出 `BD_10_AMT` 至 `BD_15_AMT`，STEP3 `AGE_ALLOC_10_AMT` 至 `AGE_ALLOC_15_AMT` 和 `BD_AFAL_10_AMT` 至 `BD_AFAL_15_AMT` 均按对应账龄金额计算；现有源码在 STEP2 将 `BD_10_AMT..BD_15_AMT` 硬编码为 0，在 STEP3 将 `AGE_ALLOC_10_AMT..15_AMT` 硬编码为 0。具体修复：删除“若 XML/若无输入”的条件措辞，固定实现 1–15 全部账龄；为规则表定义 `BD_RATIO_1..15`，统一计算 `BD_n_AMT = SPID_n_AMT（存在时）否则 BD_BASE_n_AMT * BD_RATIO_n * 投保系数`，STEP3 对 1–15 均执行负数池分摊并写回，`*_0` 明确为 1–15 合计。

3. **[HIGH] STEP1 漏掉设计要求的返利扣减字段和来源。** 位置：`02-design.md`“STEP1：坏账计提基数”段只描述 `ARP_02_001` 垫资，并列出不把个别认定、上月坏账或核销混入基数；没有 `SPC_REB_DED_AMT`。Excel `ARPM02-坏账计算表-STEP1坏账计提基数` 第 35 行明确要求按公司+客户+利润中心、`COD_CATEGORIA='ZFAMOUNT'`、`D_ADJ_TYPE='ARP_02_003'` 读取返利扣减并输出 `SPC_REB_DED_AMT`。当前源码也完全没有该来源和目标字段写回。具体修复：在 STEP1 设计中明确 `ARP_02_001` 与 `ARP_02_003` 各自的聚合、符号、扣减顺序、空值行为及字段写回；若返利确实不应参与计算，需在设计中引用正式业务决策并同步修订需求/Excel，而非遗漏。

4. **[HIGH] 设计没有给出可执行的规则匹配实现，且“来源存在即覆盖”的状态设计未落到 15 个字段。** 位置：`02-design.md`“STEP2：坏账计算、比例和个别认定”段。它提出 `HAS_INDIVIDUAL`，但未定义 CTE/列清单、如何从 `SPID_0..15` 传播到 STEP3、个别认定来源是否按场景/期间过滤以及目标清零的具体 SQL；同时 Excel 要求 16 个 `SPID_0..15` 和 15 个坏账账龄字段。当前源码的 `CALCULATION_BASE` 只取个别认定 1–9，且用 `<> 0` 判断存在，STEP3 也用 `SPID_1_AMT IS NOT NULL`。具体修复：给出 `INDIVIDUAL_DATA` 的完整 SELECT（`SPID_0..15`、`HAS_INDIVIDUAL`、场景、期间、完整业务键），明确 `HAS_INDIVIDUAL = COUNT(*) > 0` 的粒度，并规定 STEP2/STEP3 对 n=1..15 的逐列 CASE；明确无来源时先清零哪些旧值以及零金额来源如何覆盖。

5. **[HIGH] 规则优先级和字段语义与权威 Excel 不一致，设计却把 FORM_DATI 匹配作为已确认现状。** 位置：`02-design.md`“当前过程已确认的接口和现状”“FORM_DATI 的真实 owner继续使用……”以及 STEP2 的“比例按公司归并、科目、类别及客商/性质/通用优先级匹配”。Excel 规定的是规则表 BATCH_ID 1/2/3、公司+科目+`GRP_SCOPE` 前三位，并在客户级使用 `CUST_HEAD_CODE` 匹配 `CUST_CODE`，性质级使用 `NATURE_L3_NAME`；设计既没有明确 `GRP_SCOPE` 前三位，也没有说明 `CUST_HEAD_CODE` 与 `CUST_CODE` 的选择，反而将 FORM_DATI 的 `TESTO_14/TESTO_2` 当作基准。具体修复：逐个定义三种匹配的 join 条件、优先级（1 优先于 2 优先于 3）、重复规则处理（建议同一 OID+优先级不唯一即报错，不得按 OID 最小值静默选择）和无匹配默认值；将 FORM_DATI 降为仅在有明确设计依据时使用的兼容方案。

6. **[HIGH] STEP3 的分摊粒度仍未固定，无法保证勾稽且与 Excel 的业务键描述不完全一致。** 位置：`02-design.md`“STEP3：账龄分摊、上月、核销及写回”只写“同一文档维度”“只有文档确认的键才进入 JOIN”，没有把该维度列出来。Excel STEP3 第 9–25 行明确分摊比例按公司+客户+科目；当前源码 `POS_TOTAL/ALLOC_RATIO` 和负数池按 `COD_AZIENDA,CUST_CODE,COD_CONTO`，但上月又只按公司+客户+利润中心，核销则按公司+科目+客户+利润中心+销售部门。设计不能只以“文档确认”代替可实现的键定义。具体修复：在设计中列出三个数据集的完整键、空值等值规则及是否包含 `COD_DEST2`/`D_SALE_DEPT`；明确分摊池按公司+客户+科目、上月按公司+客户+利润中心、核销按 Excel 第 44 行全部键，并提供多对多前后行数/金额断言和最终勾稽公式。

7. **[HIGH] 参数验证与异常边界虽描述完整，但未说明如何与现有过程的事务/日志顺序兼容，且当前实现完全没有这些保护。** 位置：`02-design.md`“公共参数、范围和失败边界”。现有源码在校验前直接 `LPAD(P_PERIODO,2,'0')`、计算日期、删除会话表并插入/提交 BEGIN 日志；异常块中的 `ROLLBACK`、清理和 ERROR 日志也未嵌套保护，清理或日志失败会覆盖原异常。设计只给错误码和概念性“嵌套保护”，没有 PL/SQL 可直接实施的局部变量、校验顺序、日志提交边界和重抛代码。具体修复：给出入口校验的 PL/SQL 伪代码/精确规则（先保存原参，验证后再 `TO_DATE` 和操作会话表），给出异常模板：保存 `SQLCODE/SQLERRM`，清理与错误日志各自 `BEGIN...EXCEPTION...END`，最后按原异常码重抛；明确 BEGIN 日志不得在无效参数或空公司时提交。

8. **[MEDIUM] “每个 MERGE 前重复断言”没有定义完整清单、SQL 和失败动作，不能验收。** 位置：`02-design.md`“STEP1”“STEP2”“MERGE 唯一性与事务”。设计要求目标 OID、来源 OID、规则匹配键、核销键、上月键断言，却没有给出每个 MERGE 对应的键、断言使用的聚合结果、日志 REMARK 格式或失败时是否回滚已完成的前一步。具体修复：为 STEP1、SPID 回写、STEP2、STEP3 分别列出 `COUNT(*)` 与 `COUNT(DISTINCT OID)` SQL，规则/上月/核销的重复检测 SQL，规定统一抛出错误码并在 MERGE 前停止；说明已提交的前一步是否保留，以及这是否符合“批次失败”语义。

9. **[MEDIUM] 精度和尾差方案引入了未定义的“分摊池最后一行”，与当前逐行 MERGE 设计不匹配。** 位置：`02-design.md`“金额精度采用以下固定实施门槛”。设计要求按稳定 OID 排序由最后一行吸收尾差，但没有定义每个分摊池、来源总额、已写入额的计算和如何在一个 MERGE 的 `USING` 查询中实现；同时没有确认目标表实际存在/精度的列清单。具体修复：明确每个池的分区键、来源总额、`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY OID)`、累计值和最后行公式；先用 `ALL_TAB_COLUMNS` 返回列名/precision/scale，并规定无元数据时阻断，不要只写概念性门槛。

10. **[NIT] 设计对 XML 读取结果的“关键区域可解析”没有验收判据。** 位置：`02-design.md`“设计依据与核对边界”。虽然要求保留字段、来源、过滤、关联键、公式和目标映射，但没有定义哪些行/列必须存在，也没有说明 Excel 合并单元格/空白继承如何解析。具体修复：列出三个 sheet 的最小证据清单：STEP1 行 34–53，STEP2 行 9–40，STEP3 行 9–45；结构化读取时继承合并单元格值，并对每个必需字段/规则断言缺失即失败。

## Verified Assumptions

- 已读取 `01-requirements.md` 与 `02-design.md`，并以需求指定的三个 Excel sheet 作为业务基准。
- 已使用本地 OOXML/XML 方式结构化读取实际 workbook；三个目标 sheet 均存在。关键事实包括：STEP1 行 34/35 分别为 `ARP_02_001` 垫资和 `ARP_02_003` 返利；STEP2 行 26 明确 `AW_RUL_ARPBDR_000001`、BATCH_ID 1/2/3 和 `BD_RATIO_1`，行 27–40 覆盖 BD_1–BD_15；STEP3 行 9–25 覆盖 AGE_ALLOC_1–15，行 27–41 覆盖 BD_AFAL_1–15。
- 实际源码 `CPM_SP_M2M_ARP_BD_M_PHASE2.sql` 已核对：STEP1 只读取 `ARP_02_001`；STEP2 比例来自 `TGK_GB_HISENSE.FORM_DATI` 且只计算 1–9，`BD_10_AMT..BD_15_AMT` 写死为 0；STEP3 `AGE_ALLOC_10_AMT..15_AMT` 写死为 0，个别认定分支使用 `SPID_n_AMT IS NOT NULL`，异常块未做独立清理/日志保护。
- 现有源码的 STEP3 `ALLOC_RATIO` 和负数池确实按公司+客户+科目计算；上月和核销 join 使用不同键，设计必须明确并验证这种差异。

## Unverified/Wrong Assumptions

- **错误假设：** 设计认为 `AW_RUL_ARPBDR_000001`、`BD_RATIO_1..15` 不是本需求接口，因此可以排除。Excel 明确要求它们；仓库静态搜索未发现对象定义不等于业务接口不存在。
- **错误假设：** 设计把 FORM_DATI 的字段映射视为已确认的比例来源。权威 Excel 的 STEP2 规则是 `AW_RUL_ARPBDR_000001` BATCH_ID 规则；FORM_DATI 是否为兼容来源未经设计或需求确认。
- **错误假设：** 10–15 账龄“若无输入明确为零”。Excel 已明确要求 1–15 账龄输出和分摊，不能保留该分支。
- **未验证：** 未连接 Oracle，因此未验证规则表/目标表/FORM_DATI 的真实 owner、列类型、目标金额列 precision/scale、权限、PL/SQL 编译和运行结果。
- **未验证：** 未能证明现有 SQL 的 FORM_DATI 规则与 Excel 规则等价，也未能证明上月/核销键在实际数据中唯一；必须由 Oracle 元数据及测试数据验证。
- **未验证：** 未执行 Oracle 运行、金额勾稽、重复断言或尾差测试；本次仅完成设计、Excel OOXML 和源码静态核对。

## Validation Evidence

- 结构化读取尝试：`python3` 使用 `openpyxl` 失败（环境未安装模块）；随后使用 Python 标准库 `zipfile` + `xml.etree.ElementTree` 成功读取三个 sheet。
- 源码核对：读取并检索 `CPM_SP_M2M_ARP_BD_M_PHASE2.sql`，确认上述字段、过滤条件、账龄硬编码和异常处理现状。
- 未执行 Oracle 编译/运行验证，原因是当前环境无 Oracle 连接。
