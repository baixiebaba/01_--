# Implementation Plan

## 一、调查结论与证据边界

- 已完整阅读以下三份 SQL：
  - `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询.sql`
  - `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询_2026ACT08_2600_ALL.sql`
  - `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql`
- 已按需核对同目录收入校验脚本，以及 `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/01_DWD/C_应收应付/dwd_fi_mr_ar_imocc_mi.sql`。未发现本任务需要修改目标 SQL 之外的文件；DDL、配置表实际数据和 Oracle 执行结果当前无法取得。
- 项目没有 README、AGENTS.md、CONTRIBUTING.md、package.json 或 SQL 测试命令；已读取 `.kiro/steering/sql-code-style.md`。后续实施只能按 Oracle SQL 静态检查和目标 Oracle 环境中的只读/编译验证执行，不能声称本地已完成 Oracle 运行验证。
- 本文件只规划修改，不修改两份业务 SQL，不修改存储过程，不创建 Git 提交。

## 二、已确认的 TOV 实际口径

### 1. ARPTOV_RULE 的真实来源、有效期和规则条件

存储过程的 `ARPTOV_RULE` CTE 直接读取未加 schema 的 `AW_RUL_ARPTOV_000001`，不是通过外部表 JOIN 连接；只保留：

- `R.VALID_FR <= V_YEARMONTH`
- `NVL(R.VALID_TO, '999999') >= V_YEARMONTH`
- `R.BATCH_ID IN ('1', '2', '3', '4', '6')`
- 读取字段并 `TRIM`：`BATCH_ID`、`COD_AZIENDA`、`CUST_CODE`、`NATURE_L2_NAME`、`D_SALE_DEPT`。

存储过程的 ARPM02 规则不是普通等值 JOIN，而是对每一条 ARPM02 记录使用相关 `EXISTS/NOT EXISTS` 判定。准确连接键和剔除条件如下：

- BATCH_ID=6：若存在当前期间有效、`COD_AZIENDA` 与 ARPM02 公司相等且 `NATURE_L2_NAME IS NOT NULL` 的公司配置，则只保留 `R6.NATURE_L2_NAME = TRIM(A.NATURE_L2_NAME)` 的记录；若该公司没有这种配置，则默认全部取数。换言之，标记条件是“公司存在二级性质白名单，但本行二级性质未精确命中”。
- BATCH_ID=1：不连接公司；只要有效规则的 `CUST_CODE IS NOT NULL`，并且 `TRIM(A.CUST_CODE) LIKE '%' || R1.CUST_CODE || '%'`，即剔除。
- BATCH_ID=2：`R2.COD_AZIENDA = TRIM(A.COD_AZIENDA)` 且 `R2.CUST_CODE IS NOT NULL` 且 `R2.CUST_CODE = TRIM(A.CUST_CODE)`，即剔除。
- BATCH_ID=3：`R3.NATURE_L2_NAME IS NOT NULL` 且 `R3.NATURE_L2_NAME = TRIM(A.NATURE_L2_NAME)`，即剔除；不连接公司。
- BATCH_ID=4：`R4.COD_AZIENDA = TRIM(A.COD_AZIENDA)` 且 `R4.D_SALE_DEPT IS NOT NULL` 且 `R4.D_SALE_DEPT = TRIM(A.D_SALE_DEPT)`，即剔除。
- 规则标记使用这些条件的 OR：命中 BATCH_ID=1/2/3/4 任一剔除条件，或命中 BATCH_ID=6 的“公司有配置但二级性质未命中”条件，`ARPTOV_FLAG='Y'`；否则 `ARPTOV_FLAG='N'`。配置行本身不直接导致重复，因为应使用 `EXISTS`，不能把规则表明细直接 JOIN 到事实表。

当前 TOV 的 `ARPM02_SOURCE` 在上述条件上使用 `NOT EXISTS` 过滤掉记录；校验查询必须改为“保留来源行、只打标”。实际有效周转/负净额计算仍须只使用 `ARPTOV_FLAG='N'`，否则会把本来不进 ARPM03 的配置剔除数据混入净额。

### 2. ARPM02、IMOCC 原始条件和类别口径

- ARPM02 保留存储过程中的正常条件：场景、期间、公司范围、`COD_DEST2 IS NOT NULL`、`COD_DEST2 <> 'ZZZZ'`，以及用户明确要求的 `(ME_AGE_FLAG IN ('AR','CA','A10') OR MB_AGE_FLAG IN ('AR','CA','A10'))`。
- ARPM02 必须只读取一次，不再按 ME、MB 拆成两个 `UNION ALL` 分支。使用与 TOV 完全相同的 `CASE` 优先级：先命中 ME 则 `COD_CATEGORIA='ZAMOUNT'`，否则命中 MB 则 `COD_CATEGORIA='ZAMOUNT_L2'`。因此一条记录即使两个账龄标识都命中，也只生成一条，避免金额重复计数；这也是存储过程当前实际逻辑。
- ARPM02 金额字段是 `NVL(A.BCY_ADJ_INCL_0_AMT,0)`；账龄辅助金额按存储过程保留，至少包括 `OVERDUE_0_AMT`、`EPAY_AMT`、`ECLS_AMT`、`UREB_AMT`、`UFEE_AMT`、`INV_SAMPLE_AMT` 等原始字段口径。校验结果当前只展示周转金额时，不应为了需求擅自扩展更多金额展示列。
- IMOCC 保留存储过程正常条件：`DT_MONTH=YYYYMM`、`COMPANY_CODE IN ('1740','2080')`、`TRIM(CP_COMPANY_CODE) IS NULL`、利润中心非空且不为 `ZZZZ`、`NVL(IMOCC_CNY_AMT,0) <> 0`、公司进入查询公司范围；金额为 `NVL(I.IMOCC_CNY_AMT,0)`，类别固定为 `ZAMOUNT`，来源为集团外。
- IMOCC 的 `CUST_HEAD_CODE` 必须按 TOV 实际逻辑使用 `TRIM(I.CUST_CODE)`，而不是当前校验查询中的 NULL。否则 IMOCC 不会按主户参与负净额事业部识别，无法复刻 ARPM03 前的过滤。

### 3. 事业部映射、参数范围和未映射处理

TOV 的有效事业部范围来自 `TGK_FIMA_HISENSE.AW_RUL_COSMAP_000001`：`AR_TOV_FLAG='Y'`、`VALID_FR <= YYYYMM`、`NVL(VALID_TO,'999999') >= YYYYMM`；同时排除 `COD_BG LIKE 'CXC%'`。账套映射来自 `TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001`，利润中心映射来自 `TGK_FIMA_HISENSE.AW_RUL_PCRMAP_000001`，二者都按同一有效期、周转范围和非 CXC 条件处理。利润中心先经过 `DIM_RULE_FI_MR_AR_PROFIT_MAPPING` 的 `BATCH_ID=2`、同一有效期规则，按 `LTRIM(TRIM(SRC_PROFITCENTER_CODE),'0')` 连接，并用 `MAX(PROFITCENTER_CODE)` 去重，随后才连接 PCRMAP。

当前两个校验查询的现状是：

- `TOV_BG_SCOPE`、`ATS_BG_MAP`、`PCR_BG_MAP` 结构基本复刻有效期和事业部范围；参数版按 `${$ANL_D_BG.code}` 限制，固定版用 ALL 语义取消限制。
- `MAPPED_TURNOVER` 使用利润中心和账套事业部内连接，只保留 `ATS.COD_BG = PCR.COD_BG`；没有利润中心映射、没有账套映射、公司与利润中心事业部不一致、或事业部不在所选范围的记录全部消失。
- 当前 `AZI_SCOPE` 还把账套是否命中所选事业部范围放在源表入口处，因此参数版无法展示“本身有映射但被当前事业部参数排除”的数据。

实施时需把“来源公司范围”和“事业部有效范围”分开：来源公司仍按 HIE=10、公司参数和 TOV 的 D2M 进数条件控制，但不要在来源入口因选定 BG 没有 ATS 映射就丢掉记录；事业部参数/范围只在映射判定中执行。这样才能保留用户要求的可追溯剔除记录，同时让有效记录仍完全遵循 TOV 的 BG 范围。若业务坚持严格复刻过程的 `SESSION_AZIENDA_LIST`、不展示参数范围外公司，则该点需在 Oracle/业务确认；本计划按用户明确要求“因事业部参数/范围排除也保留并置空”处理。

采用一个必要的展示状态字段 `BUSINESS_UNIT_MAP_STATUS`，不新增多个拆分标志：

- 公司事业部和利润中心事业部都在当前选定范围内且相等：保留 `BUSINESS_UNIT_CODE`，状态为已映射同一事业部。
- 两者均存在但不相等：`BUSINESS_UNIT_CODE` 置 NULL，状态为公司与利润中心事业部不一致；该行视为 TOV 的事业部剔除。
- 利润中心没有有效映射：事业部置 NULL，状态为利润中心未映射事业部。
- 公司没有有效映射：事业部置 NULL，状态为账套未映射事业部。
- 全局当前有效周转映射存在、但不在参数选择/当前有效范围内：事业部置 NULL，状态说明被事业部参数/范围排除。为区分“完全没有映射”和“有映射但当前参数排除”，可额外建立只在 CTE 内使用的 ALL 范围映射集合，但不新增展示字段。
- 映射 CTE 至少用 `DISTINCT` 消除完全重复配置；如 Oracle 实际存在同一利润中心对应多个不同事业部，不能静默择一，应在状态中按冲突处理并置空，且记录为待确认，因为 TOV 源码没有给出多事业部配置的明确仲裁规则。

### 4. 负净额事业部与 AR_AMT_FLAG

存储过程的负净额逻辑在收入匹配前执行：

- 先按 `COD_SCENARIO`、`COD_PERIODO`、`COD_AZIENDA`、标准化的 `CUST_HEAD_CODE`、`COD_CATEGORIA`、`D_BG` 分组。
- 分组金额为周转金额 `SUM(AR_AMT)`；ARPM02 来源为 `BCY_ADJ_INCL_0_AMT`，IMOCC 来源为 `IMOCC_CNY_AMT`。
- 事业部净额小于 0，且同一场景、期间、公司、主户、类别存在另一个不同 `D_BG`，该事业部整体被识别为负净额事业部。
- TOV 的 `TURNOVER_MAPPED` 只包含 `GRP_SCOPE='GEX-集团外'`，并且只包含已通过 ARPTOV 配置过滤和公司/利润中心事业部匹配的记录；校验查询的负净额 CTE 必须按同一有效集合计算。

校验查询不应再使用 `FILTERED_TURNOVER` 的物理 `WHERE NOT EXISTS` 删除负净额行，而应保留所有来源行并使用 `AR_AMT_FLAG`：命中负净额事业部的有效周转行标记 `Y`，其他行标记 `N`。ARPTOV 已标记 `Y` 或事业部映射无效的行不参加负净额分组；它们仍保留展示，`ARPTOV_FLAG` 和 `BUSINESS_UNIT_MAP_STATUS` 分别解释原因，`AR_AMT_FLAG` 默认 `N`，避免把两个剔除原因混为一谈。

负净额匹配使用标准化主户键；由于负净额 CTE 本身只取 `TRIM(CUST_HEAD_CODE) IS NOT NULL`，其 `CUST_MATCH_CODE` 非 NULL，外层回标时可用同一标准化值等值连接，不得用会把 NULL 错误匹配的笼统 `NVL`。事业部和利润中心 NULL 也必须通过 LEFT JOIN/显式 NULL 分支处理，不能用假编码强行匹配。

## 三、目标脚本现状和两份脚本差异

- 参数版当前文件头为 20261020 新增版本；参数为 `${$Scenario.code}`、`${$Period.code}`、`${$Entity.code}`、`${$ANL_D_BG.code}`。
- 固定版当前文件头为 20261020 新增版本；固定参数为场景 `2026ACT`、期间 `08`、公司 `2600`、事业部 ALL。
- 两份脚本 CTE 结构和最终展示粒度基本一致：`REF_AZIENDA`、`TOV_BG_SCOPE`、`AZI_SCOPE`、利润中心规则、ATS/PCR 映射、`TURNOVER_SOURCE`、标准化、事业部映射、负净额过滤、最终聚合。
- 两份脚本当前均存在同样问题：没有 `ARPTOV_RULE`；ARPM02 两个 `UNION ALL` 分支可能重复；IMOCC 主户字段与 TOV 不一致；事业部内连接直接丢失未映射/不一致/参数外行；负净额直接过滤而非打标；最终 `WHERE NVL(F.TURNOVER_AMT,0) <> 0` 与全量查询要求冲突。
- 参数版和固定版后续必须保持同一 CTE 顺序、字段顺序、判断条件、聚合粒度和标记语义；固定版只把参数 token 替换成对应常量，另改文件头说明和最新版本记录。建议用同一 ALL 哨兵条件表达两版范围逻辑，例如参数版使用 `(${事业部列表条件} OR 'ALL' IN (${事业部列表条件}))`，固定版把相同位置替换为 `'ALL'`，避免“一版有条件、一版删条件”造成逻辑漂移；具体 token 拼接须按现有查询工具的参数展开格式落地。

## 四、实施步骤

- [ ] 1. 在两份目标脚本文件头新增最新版本修改记录，并统一基础参数/期间表达式。
      最新记录说明：按 TOV 实际 ARPTOV_RULE 规则保留 ARPM02 全量来源并新增 `ARPTOV_FLAG`，保留 ARPM02/IMOCC 合并后的事业部剔除记录并新增映射状态，保留负净额事业部记录并新增 `AR_AMT_FLAG`；同时取消最终非零金额过滤以支持全量核查。保持历史版本记录不改写。两份脚本的参数版/固定版差异只存在于参数常量、文件头说明和版本记录。
      文件：`01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询.sql`、`01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询_2026ACT08_2600_ALL.sql`
      Verify：静态检查两份文件头最新记录均在历史记录之前；`git diff --check -- <两个目标文件>` 无空白错误，且 `git diff --name-only` 只出现这两个目标文件（实现阶段不得创建提交）。

- [ ] 2. 重构范围和规则 CTE，精确复制 TOV 的有效期、参数和 ARPTOV 规则。
      在现有 `TOV_BG_SCOPE`、`ATS_BG_MAP`、`PCR_BG_MAP` 前后补充当前有效的 ALL 范围映射集合（仅 CTE 内使用），保留 `AR_TOV_FLAG='Y'`、`VALID_FR <= YYYYMM`、`NVL(VALID_TO,'999999') >= YYYYMM`、`NOT LIKE 'CXC%'` 和参数范围条件。把来源公司范围与事业部映射范围解耦，保留 HIE=10、公司参数和 D2M 进数条件，以便参数外/无映射行进入校验结果而在映射状态中置空。
      新增 `ARPTOV_RULE` CTE，完全按存储过程的表名、有效期、批次和 TRIM 字段读取；不得直接 JOIN 规则明细。后续 `ARPM02_SOURCE` 用五组 `EXISTS/NOT EXISTS` 构造 `ARPTOV_FLAG`，条件必须与本计划第二节逐项一致，特别是 BATCH_ID=6 的“公司配置时按二级性质白名单、公司无配置默认全取”语义。
      文件：上述两个目标 SQL 文件。
      Verify：静态逐项核对两份文件均包含 `VALID_FR`/`VALID_TO`、批次 1/2/3/4/6、BATCH 1 的模糊客商、BATCH 2 的公司+客商、BATCH 3 的二级性质、BATCH 4 的公司+销售部门、BATCH 6 的公司+二级性质条件；不得出现把 ARPTOV_RULE 明细直接 JOIN 到事实来源的写法。目标 Oracle 上另执行只读规则边界查询，验证无配置、BATCH 6 命中、BATCH 6 未命中、BATCH 1~4 命中各至少一类结果。

- [ ] 3. 合并并重写 `TURNOVER_SOURCE`，保证 ARPM02 一条源记录只产生一条类别记录。
      用单个 ARPM02 SELECT 替换当前 ME/MB 两个 `UNION ALL` 分支：保留所有原有正常筛选和 OR 账龄条件，按 TOV 的 CASE 优先级生成 `ZAMOUNT`/`ZAMOUNT_L2`，并投影 `ARPTOV_FLAG`。IMOCC 保留原有 TOV 条件，补齐 `CUST_HEAD_CODE=TRIM(I.CUST_CODE)`；两来源再按明确的 `DATA_SOURCE`、类别和金额字段进入统一周转 CTE。不要用规则 JOIN 或映射 JOIN 在来源阶段扩行。
      对来源后首次聚合时，至少保留 `DATA_SOURCE`、`ARPTOV_FLAG` 和所有当前展示维度，避免 ARPTOV=Y/N 或来源不同的记录在标记前被合并；负净额 CTE 后续再故意去掉 `DATA_SOURCE`，确保 ARPM02 与 IMOCC 会在相同主户/类别/事业部上合并计算。
      文件：上述两个目标 SQL 文件。
      Verify：静态确认 ARPM02 表在来源 CTE 中只有一个事实 SELECT；确认账龄条件仍是带括号的 `ME ... OR MB ...`；确认 `CASE WHEN ME ... THEN 'ZAMOUNT' WHEN MB ... THEN 'ZAMOUNT_L2'` 只出现一次且不存在 ARPM02 的第二个 `UNION ALL` 分支。目标 Oracle 上用同一条同时命中 ME/MB 的样例，核对只返回一个类别和一份金额。

- [ ] 4. 改造事业部映射为 LEFT JOIN 留痕，并只新增一个必要的映射状态字段。
      将当前 `TURNOVER_NORMALIZED` 的利润中心内连接改为可保留未命中来源的左连接，保留 TOV 的利润中心标准化结果；将 `PCR_BG_MAP`、`ATS_BG_MAP` 的事业部判断改为不会扩行的映射状态逻辑。`BUSINESS_UNIT_CODE` 只有在当前有效范围内公司事业部与利润中心事业部相等时填值，否则置 NULL；用 `BUSINESS_UNIT_MAP_STATUS` 区分一致、不一致、利润中心未映射、账套未映射和被当前事业部参数/范围排除。不能以 `ZZZZ` 代替 NULL 事业部。
      `TURNOVER_PROFITCENTER_CODE` 保持现有输出字段，映射后利润中心无命中时按 TOV 校验可追溯需要保留原始利润中心；描述函数对 NULL 事业部应采用显式 CASE，不能因函数调用再次丢行。最终展示只增加 `BUSINESS_UNIT_MAP_STATUS`，不额外增加公司映射字段、利润中心映射字段等未经要求的展示列。
      文件：上述两个目标 SQL 文件。
      Verify：静态确认事业部映射不再使用只会消失记录的 `JOIN PCR... JOIN ATS...` 作为唯一结果路径；确认不一致、未映射和参数外分支均把 `BUSINESS_UNIT_CODE` 置 NULL；目标 Oracle 用四类样例核对：同事业部保留编码、不同事业部空编码、无任一映射空编码、映射存在但不在参数范围空编码。检查相同来源行不会因多个相同配置行被金额放大。

- [ ] 5. 按 TOV 粒度计算负净额并回标 `AR_AMT_FLAG`，不再删除被标记数据。
      新增/改造 `BG_TURNOVER_NET`、`NEGATIVE_BG_TURNOVER` 和后续标记 CTE：只使用 `ARPTOV_FLAG='N'`、集团外、事业部映射有效且当前范围内的记录；按场景、期间、公司、标准化主户、类别、事业部分组，金额使用 ARPM02 `BCY_ADJ_INCL_0_AMT` 与 IMOCC `IMOCC_CNY_AMT` 的合计。存在不同事业部且本事业部净额小于 0 时，该事业部全部明细回标 `AR_AMT_FLAG='Y'`，否则 `N`。回标键必须包含场景、期间、公司、类别、事业部和标准化主户；NULL 主户不参与负净额组，保持 TOV 实际逻辑。
      将当前 `FILTERED_TURNOVER` 的负净额 `WHERE NOT EXISTS` 改为保留行的 CASE 标记；最终 SELECT、最终聚合和 ORDER BY 均不得再过滤 `AR_AMT_FLAG='Y'`。ARPTOV 标记行、事业部无效行仍保留并分别由 `ARPTOV_FLAG`/`BUSINESS_UNIT_MAP_STATUS` 解释，避免把配置剔除和负净额剔除叠加误判。
      文件：上述两个目标 SQL 文件。
      Verify：静态确认 `AR_AMT_FLAG` 的 Y 只由负净额规则产生，确认最终查询不存在按 `AR_AMT_FLAG` 或 `NOT EXISTS NEGATIVE...` 删除行；目标 Oracle 用一主户多事业部、负事业部、仅一个事业部、主户 NULL、ARPTOV=Y 混合样例核对标记和净额。

- [ ] 6. 调整最终聚合和非零过滤，保证全量可查且两版结构完全一致。
      最终输出保留现有展示字段顺序，在来源/类别附近加入 `ARPTOV_FLAG`，在事业部金额附近加入 `AR_AMT_FLAG` 和 `BUSINESS_UNIT_MAP_STATUS`；最终 GROUP BY 必须包含这些标志和状态，避免同一展示粒度下 Y/N 记录被错误合并。保持 `DATA_SOURCE`、`COD_CATEGORIA`、客商、集团范围、对方公司、标准化利润中心和事业部的现有展示粒度；负净额判定的聚合粒度仍不包含 `DATA_SOURCE`，以实现 ARPM02 与 IMOCC 合并计算。
      删除最终 `WHERE NVL(F.TURNOVER_AMT,0) <> 0`。这是全量校验的必要调整：ARPM02 的零金额/汇总后为零记录不能因末尾过滤消失；IMOCC 来源本身的 `NVL(I.IMOCC_CNY_AMT,0) <> 0` 仍保留，因为它是 TOV 源头正常条件，不是末尾展示过滤。用连续中文 `--` 注释说明“来源正常非零条件保留、最终非零条件取消以留痕”的原因。
      两份脚本逐字段、逐 CTE、逐 JOIN 和逐 GROUP BY 对齐；参数版只保留参数 token，固定版只替换场景/期间/公司/ALL 常量及文件头，不得出现一版有额外业务分支的情况。
      文件：上述两个目标 SQL 文件。
      Verify：`git diff --check -- <两个目标文件>` 通过；使用 Python 只读脚本将固定版中的 `2026ACT`、`08`、`2600`、`ALL` 和参数版对应 token 归一化后，逐段比较 CTE 名称、输出列、`CASE` 条件、JOIN/WHERE/GROUP BY 结构；确认差异仅为参数常量、文件头和版本记录。目标 Oracle 执行 `EXPLAIN PLAN` 或只读查询，确认 SQL 可解析且最终零金额、ARPTOV=Y、AR_AMT_FLAG=Y、事业部 NULL 行均可返回。

- [ ] 7. 完成范围守护和交付前核对，不修改无关文件且不提交。
      对两个目标 SQL 做括号/CTE/UNION 列数的静态检查，核对每个 CTE 上方为连续 `--` 中文用途注释、Oracle 对象名/关键字大写、逗号前置、字段逐行；不要顺带格式化存储过程、DWD SQL 或其他校验脚本。核对 `ARPTOV_FLAG`、`AR_AMT_FLAG`、`BUSINESS_UNIT_MAP_STATUS` 在 SELECT、聚合和最终输出中列序一致。
      文件：仅上述两个目标 SQL 文件；调查计划文件为本文件，属于任务交付物，不得新增其他 SQL/DDL/配置文件。
      Verify：`git diff --name-only` 只列两个目标 SQL（若计划文件已被任务流程纳入，则单独确认其为计划产物）；`git diff --check` 无输出；无 Oracle 连接时在交付说明中明确列出“未完成 Oracle 编译、执行、实际金额勾稽和规则数据边界验证”，不得声称通过数据库验证。

## 五、待确认事项

1. `AW_RUL_ARPTOV_000001` 在存储过程中未带 schema，而其他规则表带 `TGK_FIMA_HISENSE`；实施时应保留过程中的对象名，部署前确认当前 SQL 执行用户的默认 schema/synonym，否则不能擅自改 owner。
2. TOV 的过程入口 `SESSION_AZIENDA_LIST` 会把不在 `P_BG` 范围的公司排除，而用户又要求校验表展示“因事业部参数/范围排除”的记录。本计划采用“来源公司范围与事业部映射范围分离、结果置空并标记”的校验表方案；若业务要求绝对复刻过程入口，应确认是否允许从源入口保留这些记录。
3. TOV 源码没有明确同一利润中心或同一公司可同时存在多个不同有效事业部映射时的仲裁规则。计划不通过事实 JOIN 放大金额；若实际配置存在多值，应以 Oracle 配置数据和业务确认决定是否统一判为冲突并置空，不能凭 `MAX(COD_BG)` 静默选择。
4. 当前校验查询没有 `GRP_SCOPE='GEX-集团外'` 条件，但 TOV 的 `TURNOVER_MAPPED` 有该条件。本计划按 TOV 对负净额/有效周转集合使用集团外条件，同时保留校验来源行；非集团外行若需要在结果中单独标识，需业务确认是否复用映射状态字段，避免擅自再增加展示字段。
5. 当前没有 Oracle 连接、目标对象元数据或实际配置数据，因此无法静态确认规则表列类型、参数展开语法、映射唯一性、函数对 NULL 的行为和金额结果；这些属于实施后的目标环境验证项。
