# ARP 第二段 MERGE 客商粒度不一致诊断报告

## 摘要结论

已核实，用户在第二段 `MERGE` 的 `TARGET_FACT` 内看到的单个客商结果，与把客商条件加到最后展示 `SELECT` 后看到的结果不一致，最可能不是 `MERGE ... ON (T.OID = S.OID)` 的客商关联错误，而是**窗口函数的计算范围和最后客商展示过滤范围不同**：三个窗口金额（`LE_BCY_AMT`、`ME_BCY_AMT`、`MB_BCY_AMT`）在 `TARGET_FACT` 的内层查询中已经对符合公司、期间、来源和过程标识的全量行计算，随后才由外层 `WHERE AA.COD_AZIENDA IN (...)` 限制会话公司；如果再把 `CUST_CODE` 条件仅加在最末端 `SELECT`，它只裁剪展示行，不会重算窗口金额。

更严重且可直接由 SQL 证明的是：窗口 `PARTITION BY` 使用 `A.CUST_HEAD_CODE`，没有使用 `CUST_CODE` 或显式的 `CUST_KEY`；而 `M01_FACT` 明确将 `CUST_HEAD_CODE` 设为 `NULL`。因此同一公司、同一 `SYSTEM_SRC`、同一 `ACCT_REC_CODE` 下的多个 M01 客商会共享同一个窗口分区，`ME_BCY_AMT`/`MB_BCY_AMT` 会把这些客商合并计算。最后只筛一个 `CUST_CODE` 时，显示出来的仍可能是包含其他客商金额的窗口结果。这是当前反馈场景最优先验证和修复的根因。

此外，6000 系列公司存在有意的合并重分类逻辑：内层将 `6000/6000A/6000B/6000C/6600` 在特定科目下归一为 `6000`，并通过 `UNION ALL` 扩大内层参与窗口计算的公司集合，外层再恢复为当前会话公司。若用户只选择其中一个公司，这一设计也会使窗口金额包含同组其他公司；这属于公司合并口径造成的第二个范围差异，不能误认为是客商过滤问题。

## 已核实事实

### 1. 程序和知识库口径

- 知识库副本 `98_临时存/kbdata_副本.json` 将 `CPM_SP_D2M_ARP_M_PHASE2` 登记为应收应付模块的 DWM、D2M 程序，目标表为 `AW_MR9_ARPM01_000001`（往来账龄计算底稿），来源登记为 `DWD_FI_MR_ARAP_SUM_MI`、`AW_MR9_REVM01_000001`，用途为“DWD->DWM往来账龄数据抽取”。证据：知识库程序台账记录（约第 477712 行起及第 525210 行起）。
- 知识库同时登记 `dwd_fi_mr_arap_sum_mi` 为 DWD 往来账龄汇总表，并将 `AW_MR9_ARPM01_000001` 作为后续 `CPM_SP_M2M_ARP_AG_M_PHASE2` 的输入。证据：知识库对象/程序台账记录（约第 18353 行、第 477684 行起）。
- 以上是知识库台账口径；下述窗口、过滤和字段行为均直接来自当前实际 SQL。知识库没有登记本次 `TARGET_FACT` 的窗口分区细节，因此不能用知识库替代 SQL 事实。

### 2. DWD 和 M01 装载阶段的客商字段

- `DWD_STANDARD` 从 `DWD_FI_MR_ARAP_SUM_MI` 读取 `CUST_CODE`、`CUST_HEAD_CODE`、`CUST_BRANCH_CODE`，并把 `ODS_SRC` 作为 `SRC_DETAIL`；同时限制期间、`NVL(IS_APAR_FLAG,'Y')='Y'` 和会话公司。见目标 SQL 第 202-321 行附近。
- `M01_FACT` 从 `AW_MR9_REVM01_000001` 读取 `CUST_CODE`，但明确写入 `CAST(NULL AS VARCHAR2(30)) AS CUST_HEAD_CODE` 和 `CAST(NULL AS VARCHAR2(30)) AS CUST_BRANCH_CODE`；其来源标识为 `ZTSO04_CK` 或 `ZTSO04_TH`。见第 324-390 行附近。
- 两者经 `AGG_FACT` 按包括 `CUST_CODE`、`CUST_HEAD_CODE`、来源、公司、科目等字段聚合后写入 `AW_MR9_ARPM01_000001`。因此 M01 的客商明细虽保留在 `CUST_CODE`，但主客商字段为空并非第二段临时计算才发生。

### 3. TARGET_FACT 的内外层过滤顺序

- 第二段 `MERGE` 从目标表 `AW_MR9_ARPM01_000001 A` 读取，内层 `WHERE` 限制：当前场景、期间、会话公司并追加 6000 系列公司集合、`PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'`，以及 `SRC_DETAIL LIKE 'ORG%' OR SRC_DETAIL LIKE 'ZTSO04%'`。见第 565-684 行附近。
- 三个窗口表达式位于同一个内层 SELECT 中，因此是在该内层行集上计算的。外层才执行 `WHERE AA.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST...)`。见第 569-685 行附近。
- 这意味着外层公司过滤不会回溯重算窗口值。SQL 优化器可能改变物理执行计划，但不能改变这个查询的逻辑语义：窗口值的逻辑输入是窗口所在 SELECT 的行集，而不是最末端展示 SELECT 的行集。
- `REC_FLAG_FACT` 仅从已经产生窗口金额的 `TARGET_FACT F` 调用 `F_APAR_REC`；后续 `NODE_MAP` 只用于集团范围节点判断。见第 691-812 行附近。

### 4. 客商字段转换和窗口粒度

- `TARGET_FACT` 中显式定义 `A.CUST_HEAD_CODE AS CUST_KEY`，并没有将 `CUST_CODE` 转换成 `CUST_KEY`，也没有 `NVL(CUST_HEAD_CODE,CUST_CODE)` 之类的回退。见第 576-584 行附近。
- `LE_BCY_AMT` 和 `ME_BCY_AMT` 的分区键均为：`SYSTEM_SRC`、6000 系列特定条件下归一后的公司、`CUST_HEAD_CODE`、`ACCT_REC_CODE`。见第 612-642 行附近。
- `MB_BCY_AMT` 的分区键在上述基础上增加 `COD_DEST2`，但仍然只有 `CUST_HEAD_CODE`，没有 `CUST_CODE`。见第 643-659 行附近。
- `LE_BCY_AMT` 只累计 `SRC_DETAIL LIKE 'ORG%'`；`ME_BCY_AMT`、`MB_BCY_AMT` 累计 `ORG%` 或 `ZTSO04%`。见第 612-659 行附近以及 `REC_FLAG_FACT` 第 694-785 行附近。
- `REC_FLAG_FACT` 将 `F.CUST_KEY`（即 `CUST_HEAD_CODE`）传给 `TGK_GB_HISENSE.F_APAR_REC`，而不是 `CUST_CODE`。见第 697-722、728-754、760-785 行附近。对 M01 行而言该参数为 NULL；对存在主客商的 DWD 行而言，多个分支客商可能按主客商合并。

### 5. 最终 SELECT 和 MERGE 的作用

- CTE 最终 SELECT 输出大量客商、公司、金额和节点字段，但 MERGE 的关联条件只有 `ON (T.OID = S.OID)`，真正更新的是与 OID 对应的目标行。见第 814-888 行和第 888-909 行附近。
- 当前 SQL 中没有客商条件。若调试时把 `WHERE F.CUST_CODE = :某客商` 放在最末端 SELECT（即 `FROM REC_FLAG_FACT F ...` 之后的展示层），该条件只能减少 `S` 返回的 OID 行，不能改变 `REC_FLAG_FACT` 已经取得的窗口金额。
- MERGE 更新 `COD_CONTO`、账龄标识、重分类标识和 `GRP_SCOPE`；`COD_CONTO` 的 CASE 没有 ELSE，因此未命中时会得到 NULL，随后仅对非 ORG 来源且 `COD_CONTO IS NULL` 的当前过程行执行默认科目回写。见第 890-909 行和第 912-926 行附近。该回写与本次客商窗口粒度问题是两个独立步骤。

### 6. 公司合并和会话公司范围

- 内层公司条件先取会话公司，再 `UNION ALL` 加入 6000 系列公司（前提是会话中至少含有一个 6000 系列公司）。
- 窗口中的公司键又把 6000 系列特定科目归一成 `'6000'`。所以当会话公司范围只包含一个 6000 系列成员时，内层仍可能把同组其他成员纳入同一窗口；外层只保留会话公司成员。这会导致“某公司行显示的窗口金额”与只对该公司单独计算的结果不同。
- 这是 SQL 中明确写出的合并重分类规则，且注释说明“6000/6000A/6000B/6000C/6600 合并重分类”；是否符合用户当前要看的“单公司”口径，需要业务确认，不能直接删除。

## 最可能根因排序

1. **首要根因：客商过滤放在窗口计算之后，且窗口没有按 `CUST_CODE` 分区。** 用户最后 SELECT 的客商限制只筛行，不会重新计算 `SUM(...) OVER`。当同一 `CUST_HEAD_CODE` 对应多个 `CUST_CODE`，或者 M01 的 `CUST_HEAD_CODE` 全为空时，单客商结果天然会带有其他客商的 `ME_BCY_AMT`/`MB_BCY_AMT`。
2. **次要根因：M01 客商主键缺失。** `M01_FACT` 只保留 `CUST_CODE`，把 `CUST_HEAD_CODE` 固定为空；而第二段用 `CUST_HEAD_CODE` 作为窗口客商粒度及函数入参。对 M01 的 `ZTSO04` 行，`ME_BCY_AMT`、`MB_BCY_AMT` 会按公司/系统/科目（及 MB 的利润中心）把所有空主客商行合并。
3. **条件性根因：6000 系列公司合并。** 若问题客商所在公司属于该组且科目命中归一化范围，窗口输入包括同组公司，单公司最终 SELECT 与全量目标表结果会不同。
4. `CUST_KEY` 本身不是独立来源字段，而是 `CUST_HEAD_CODE` 的别名；因此若用户以 `CUST_CODE` 识别客商，当前代码不存在“把当前客商转换成主客商后再按当前客商计算”的逻辑。`CUST_CODE/CUST_HEAD_CODE/CUST_KEY` 三者不能按同一字段理解。

## 可验证 SQL / 操作（只读）

以下操作用于复现，不应在生产会话执行 DML；将变量替换成实际场景、期间、公司和客商即可。

### A. 验证同一窗口分区是否包含多个客商

在复用当前 `TARGET_FACT` 内层查询（保留现有公司、期间、来源和过程过滤）的结果上执行：

```sql
SELECT
    SYSTEM_SRC,
    COD_AZIENDA,
    CUST_HEAD_CODE,
    ACCT_REC_CODE,
    COD_DEST2,
    COUNT(DISTINCT CUST_CODE) AS CUST_CNT,
    LISTAGG(DISTINCT CUST_CODE, ',') WITHIN GROUP (ORDER BY CUST_CODE) AS CUST_LIST,
    SUM(CASE WHEN SRC_DETAIL LIKE 'ORG%' OR SRC_DETAIL LIKE 'ZTSO04%' THEN NVL(BCY_0_AMT, 0) ELSE 0 END) AS WINDOW_ME_MB_INPUT
FROM <复用后的_TARGET_FACT_内层基础行>
GROUP BY SYSTEM_SRC, COD_AZIENDA, CUST_HEAD_CODE, ACCT_REC_CODE, COD_DEST2
HAVING COUNT(DISTINCT CUST_CODE) > 1;
```

预期：问题客商为 M01 时，可见 `CUST_HEAD_CODE IS NULL` 的分区中出现多个 `CUST_CODE`；若出现，则可以直接证明最后筛客商不能代表按客商重算。

### B. 对照“先筛客商再开窗”和“先开窗再筛客商”

将现有窗口计算逻辑复制为两个只读查询：

```sql
-- 口径 1：当前程序语义，先对全量目标行开窗，再筛客商
SELECT *
FROM (
    <当前 TARGET_FACT 内层 SELECT，保留三个 SUM(...) OVER>
) X
WHERE X.CUST_CODE = :CUST_CODE;

-- 口径 2：按客商重算，客商条件必须进入窗口所在 SELECT 的 FROM/WHERE 之前
SELECT *
FROM (
    <当前 TARGET_FACT 内层 SELECT，增加 A.CUST_CODE = :CUST_CODE 后再计算三个窗口>
) X;
```

比较同一 OID 的 `LE_BCY_AMT`、`ME_BCY_AMT`、`MB_BCY_AMT`；若口径 1 大于口径 2，即可复现反馈。不建议直接在最外层 SELECT 加条件后将其当作口径 2。

### C. 验证 M01 的主客商为空导致跨客商合并

```sql
SELECT
    COD_AZIENDA,
    SYSTEM_SRC,
    ACCT_REC_CODE,
    COD_DEST2,
    COUNT(DISTINCT CUST_CODE) AS CUST_CNT,
    COUNT(*) AS ROW_CNT
FROM AW_MR9_ARPM01_000001
WHERE COD_SCENARIO = :SCENARIO
  AND COD_PERIODO = LPAD(:PERIODO, 2, '0')
  AND PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
  AND SRC_DETAIL LIKE 'ZTSO04%'
  AND CUST_HEAD_CODE IS NULL
GROUP BY COD_AZIENDA, SYSTEM_SRC, ACCT_REC_CODE, COD_DEST2
HAVING COUNT(DISTINCT CUST_CODE) > 1;
```

若返回记录，说明当前 M01 数据确实共享 `CUST_HEAD_CODE IS NULL` 的窗口分区。查询只读目标表，不执行修改。

### D. 验证 6000 系列公司扩大范围

```sql
SELECT
    CASE WHEN COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              AND ACCT_REC_CODE IN ('1131002000','1133001003','2181001005','2121001000')
         THEN '6000' ELSE COD_AZIENDA END AS WINDOW_COMPANY,
    COD_AZIENDA,
    COUNT(*) AS ROW_CNT,
    SUM(NVL(BCY_0_AMT, 0)) AS AMT
FROM AW_MR9_ARPM01_000001
WHERE COD_SCENARIO = :SCENARIO
  AND COD_PERIODO = LPAD(:PERIODO, 2, '0')
  AND PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
  AND CUST_CODE = :CUST_CODE
  AND COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
GROUP BY CASE WHEN COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
                   AND ACCT_REC_CODE IN ('1131002000','1133001003','2181001005','2121001000')
              THEN '6000' ELSE COD_AZIENDA END,
         COD_AZIENDA;
```

同时核对实际 `SESSION_AZIENDA_LIST`。若同一 `WINDOW_COMPANY='6000'` 下有多个实际公司，需将公司合并影响与客商粒度影响分开判断。

### E. 验证最终 SELECT 是否只是展示过滤

在调试版本中分别记录同一 OID 在：

1. `TARGET_FACT` 内层窗口结果；
2. `REC_FLAG_FACT` 结果；
3. 最终节点 JOIN 后结果；
4. 最终 `SELECT` 增加客商条件后的结果；
5. `MERGE` 更新后的目标表。

四个派生字段金额应在 1-4 阶段保持不变；最终客商条件只应减少 OID 行数。若金额在第 4 步才变化，通常说明调试 SQL 已把客商条件放进窗口所在层，而不是仅放在最后展示层，应重新对齐复现口径。

## 修复建议

### 建议一：先确认业务目标，再选择窗口客商粒度

若业务要求“一个客商单独计算”，应把客商筛选放到窗口函数所在数据集的上游，并将窗口粒度改为明确的业务客商键。最低限度应由业务确认是否使用：

- `CUST_CODE`：按分支/明细客商计算；或
- `NVL(CUST_HEAD_CODE, CUST_CODE)`：有主户按主户合并、无主户按自身客商计算；或
- 另一个经规则表确认的标准客商键。

不建议实现人员自行把 `CUST_CODE` 替换 `CUST_HEAD_CODE`，因为知识库规则要求客商、账龄和重分类口径优先结合规则表、现有程序和最新需求确认；当前 SQL 只证明了现状，不证明哪一个键是最终业务口径。

### 建议二：对 M01 明确建立客商粒度

如果 M01 的 `CUST_CODE` 就是有效客商键，则在第二段窗口中使用经过确认的回退键，并保证传给 `F_APAR_REC` 的 `CUST_KEY` 与该口径一致；同时检查 `AGG_FACT` 是否需要保留该键的唯一性。若 M01 必须按主户计算，则应在 M01 装载阶段补充可靠的 `CUST_HEAD_CODE` 映射，不能继续用 NULL 代表所有客商。

### 建议三：调试查询必须在开窗前过滤客商

用于单客商核对的 SQL 应将客商条件放在 `TARGET_FACT` 的窗口所在 SELECT 的 `FROM/WHERE` 层，或新增一个明确的上游过滤 CTE；不要只在最终展示 SELECT 添加 `WHERE CUST_CODE=...`。但正式过程是否接受按客商缩小计算范围，必须确认，因为正式运行通常需要同时更新整个公司范围，不能把调试条件直接上线。

### 建议四：保留并单独验证公司合并逻辑

6000 系列归一及内层公司扩展应作为独立口径测试：确认用户的“一个客商”比较是否同时要求“一个公司”隔离。如果要求单公司结果，则需业务确认是否取消该科目范围下的公司合并；如果仍保留合并，报告和核对 SQL 必须明确显示合并公司集合。

### 建议五：修复后的回归验证

至少覆盖：一个普通 ORG 客商、同一主户下多个 `CUST_CODE`、一个 M01 `ZTSO04` 客商、一个 6000 系列公司客商、日立节点公司及无对方公司节点场景。逐 OID 对比窗口金额、`F_APAR_REC` 返回的账龄标识、`GRP_SCOPE` 和 `COD_CONTO`，再验证全公司批量运行不会因客商条件而漏更新。

## 风险与边界

- 若直接把 `CUST_CODE` 加入现有 `PARTITION BY`，会改变账龄/重分类金额和函数入参的业务粒度，可能导致历史结果变化；这是行为变更，需业务确认并做期间回归。
- 若只把客商条件加在 MERGE 最后 SELECT，不能修复窗口污染，只会减少被 MERGE 更新的 OID，可能造成同批次部分行未更新。
- 若把 `CUST_HEAD_CODE` 改成 `NVL(CUST_HEAD_CODE,CUST_CODE)`，M01 结果可能合理化，但会改变无主户行的函数查询键；还需确认函数 `F_APAR_REC` 对客商键的配置要求。
- 若移除 6000 合并，会改变跨公司重分类口径；应与现有版本注释、规则表和用户期望共同确认。
- 日立节点逻辑位于最终节点 JOIN：当前公司为日立时对方节点使用 `NVL(P.NODES,P.NODE)`，它不改变前面窗口金额的客商分区，但会影响 `GRP_SCOPE`，需要单独回归，不应把该差异与窗口金额差异混在一起。

## 最终判断

当前 SQL 已足以支持以下判断：**最后 SELECT 的客商限制不是等价的“按客商计算”，因为窗口先按 `CUST_HEAD_CODE` 在更大行集上计算；M01 又把该字段置 NULL，导致客商之间最容易发生跨客商合并。** 先用上述 A-C 查询确认问题客商是否落入共享分区，再用 B 查询量化“先开窗后过滤”和“先过滤后开窗”的差异；若差异存在，应优先按已确认的业务客商键重构窗口输入范围，同时单独保留/验证 6000 公司合并和日立节点规则。
