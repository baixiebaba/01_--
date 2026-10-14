# AG 过程 `COD_VALUTA_ORIGINARIA` 分析报告

## 一、总结结论

在 `CPM_SP_M2M_ARP_AG_PHASE2` 中，`COD_VALUTA_ORIGINARIA` 的直接来源是当前期间 `AW_MR9_ARPM01_000001` 的 `A.COD_VALUTA_ORIGINARIA`，入口位于 `CURRENT_SOURCE_BASE` CTE。该字段随后经 `CURRENT_SOURCE` 原样传递，并在 `CURRENT_DIM`、`DIM_CANDIDATE`、`RESULT_BASE`、`RESULT_FACT` 以及最终 `MERGE` 的 UPDATE/INSERT 中继续原样传递；过程没有对它做 `CASE`、`NVL` 或其他值改写。

但是，AG 的实际结果粒度没有把 `COD_VALUTA_ORIGINARIA`（也没有把 `COD_VALUTA`）纳入业务键。当前金额聚合 `CURRENT_SOURCE_AGG` 按“公司 + 科目 + 客商 + 利润中心”汇总，`CURRENT_DIM` 也在同一粒度上用 `ROW_NUMBER()` 选一条维度行，`ALL_KEYS` 及 `RESULT_BASE` 的各个 JOIN 仍然只按这四个键匹配。故 M01 同一公司、科目、客商、利润中心同时存在 JPY/CNY/USD 时，AG 会先把不同交易币记录合并成一条 M02 业务记录，再从其中一条明细（优先 ORG，随后按 OID）拿一个 `COD_VALUTA_ORIGINARIA` 显示。显示的币种可能是任意被选中的一个，并不代表该 M02 行的全部交易币。

交易币金额的影响分两部分：

1. `QCY_0_AMT` 至 `QCY_15_AMT` 在 `CURRENT_SOURCE_AGG` 中按上述四键直接 `SUM`，因此不同交易币的原币金额会被加在一起，但结果只带一个交易币币种，金额与币种语义不一致。
2. 本位币侧的 `ORG_BCY_*_AMT`、`CALC_BCY_*_AMT` 会逐条应用各自来源币种对应的汇率/税率逻辑后再汇总，所以本位币金额可能仍然是多币种折算后的合计；但最终行展示的 `COD_VALUTA_ORIGINARIA` 不能解释该合计。若某些来源行没有有效汇率，计算还会回落到原始 `BCY_*_AMT`，进一步造成不同币种金额在同一行混合的风险。

要保证币种和金额一致，首先应确定 M02 设计粒度是否要“一币种一行”。若是，应将 `COD_VALUTA` 和 `COD_VALUTA_ORIGINARIA`（至少原币币种，通常本位币也应同时作为粒度维度）加入当前/历史的业务键、聚合、窗口分区、所有键集合、JOIN 和 INPUT_DEFORM 复用 OID 的匹配条件；不能只在输出列中继续传递字段。若业务仍要求“一业务键一行”，则不能把多币种原币金额放在同一个 `QCY_*` 字段中，必须明确改成按币种拆行或另行保存分币种明细/汇总，不能用任选一条币种作为整行币种。

## 二、准确逻辑链与证据

### 1. 从 M01 读取及入口过滤

AG 的 `CURRENT_SOURCE_BASE` 从 `AW_MR9_ARPM01_000001 A` 读取当前场景、期间、批次公司的记录，并过滤 `NVL(A.LE_AGE_FLAG,'|') <> '|'` 和 `SRC_DETAIL LIKE 'ORG%'`（约第 186–300 行）。在 SELECT 中直接选择：

```sql
, A.COD_VALUTA
, A.COD_VALUTA_ORIGINARIA
```

对应文件约第 222–224 行、第 288–300 行。这里没有 `CASE` 或 `NVL` 包裹 `COD_VALUTA_ORIGINARIA`，所以入口值就是 M01 值；`NVL` 只用于 `BCY_*`、`QCY_*` 金额字段。

此外，AG 中还存在 `SUPPLEMENT_AGG`，它从同一张 M01 表读取无账龄/补充来源，但该 CTE 只选择公司、科目、客商、利润中心及补充金额，完全不读取 `COD_VALUTA_ORIGINARIA`（约第 478–525 行）。它只通过四个业务键回接到当前主汇总，不会为币种建立独立粒度。

### 2. 汇率逻辑是否改写该字段

`CURRENT_SOURCE_BASE` 通过以下关系使用原币字段计算 `CONVERSION_FACTOR`（约第 261–288 行）：

- 对 2023 公司：`TCURR_CONV.TCURR = TRIM(A.COD_VALUTA)` 且 `TCURR_CONV.FCURR = TRIM(A.COD_VALUTA_ORIGINARIA)`；
- 其他公司：`QCY_RATE.COD_VALUTA = TRIM(A.COD_VALUTA_ORIGINARIA)`，`BCY_RATE.COD_VALUTA = TRIM(A.COD_VALUTA)`；
- 非 2023 公司在满足汇率条件时计算：
  `BCY_RATE.RATE / QCY_RATE.RATE`，其中原币为 CNY 时分母按 1 处理；本位币为 CNY 时分子按 1 处理。

该逻辑只产生派生列 `CONVERSION_FACTOR`，没有给 `COD_VALUTA_ORIGINARIA` 赋新值。`CURRENT_SOURCE`（约第 305 行起）用 `CONVERSION_FACTOR` 和 `TAX_FACTOR` 计算 `CALC_BCY_0_AMT` 至 `CALC_BCY_15_AMT`、`CALC_CLOSING_RATE_BCY_AMT`、`CALC_POSTING_RATE_BCY_AMT`，但通过 `S.*` 继续原样携带 `COD_VALUTA_ORIGINARIA`。

因此应区分两件事：币种字段没有被汇率逻辑转换；金额字段确实可能被汇率和税率逻辑改写。`CONVERSION_FACTOR IS NULL` 时，`CALC_BCY_*_AMT` 的对应分支会保留 `BCY_*_AMT`；有因子时，非某些账龄分支使用 `QCY_*_AMT * CONVERSION_FACTOR`。最终本位币金额与原币金额的来源可能不同，但币种列仍只是来源字段。

### 3. 各 CTE 的传递及粒度缺失

#### `CURRENT_DIM`

`CURRENT_DIM` 从 `CURRENT_SOURCE` 选择 `COD_VALUTA_ORIGINARIA`（约第 540–568 行），但其去重窗口为：

```sql
ROW_NUMBER() OVER (
  PARTITION BY S.COD_AZIENDA
             , S.COD_CONTO
             , S.CUST_CODE
             , S.COD_DEST2
  ORDER BY CASE WHEN S.SRC_DETAIL LIKE 'ORG%' THEN 1 ELSE 2 END
         , S.OID
)
```

约第 569–579 行。分区中缺少 `COD_VALUTA` 和 `COD_VALUTA_ORIGINARIA`。因此同一四键下 JPY/CNY/USD 多行时只保留 RN=1 的一行维度；优先 ORG 来源，ORG 内再按 OID 选择，而不是按币种选择。

#### `CURRENT_SOURCE_AGG`

该 CTE 的 SELECT 只输出四键（约第 705–711 行），随后对 `ORG_BCY_*_AMT`、`CALC_BCY_*_AMT` 和 `ORG_QCY_*_AMT` 做 SUM；`LISTAGG` 中虽然把 `COD_VALUTA_ORIGINARIA` 拼入 `CURRENCY_ACCT_DETAIL`，但这只是文本明细，不是关系型粒度字段。其 GROUP BY（约第 746–750 行）只有：

```sql
GROUP BY S.COD_AZIENDA
       , S.COD_CONTO
       , S.CUST_CODE
       , S.COD_DEST2
```

所以 JPY/CNY/USD 的 QCY 金额会被加到同一 `ORG_QCY_*_AMT`，本位币金额也会先逐条换算后在同一四键内汇总。

`CURRENCY_ACCT_DETAIL`（约第 733–745 行）会把 `ACCT_SRC_CODE`、按来源计算的 BCY 金额、`COD_VALUTA_ORIGINARIA` 和 QCY 金额拼接保存。这能保留部分审计信息，但不改变主结果的币种粒度，且不能使 `QCY_*_AMT` 成为单一币种金额。

#### `BY_HISTORY` 与 `LM_HISTORY`

年初和上月历史 CTE 都选择 `T.COD_VALUTA_ORIGINARIA`（约第 779–806 行、约第 829–855 行），但读取 M02 时没有在 CTE 内按币种聚合，注释所称设计业务键仍然只是四键。后续历史记录参与 `ALL_KEYS` 和结果回接时也没有币种键，因此历史币种不能作为独立结果行保留。

#### `ALL_KEYS`、`DIM_CANDIDATE`

`ALL_KEYS`（约第 859–871 行）从当前维度、补充汇总、年初历史、上月历史做 UNION，但每个 SELECT 只有公司、科目、客商、利润中心；没有 `COD_VALUTA` 或 `COD_VALUTA_ORIGINARIA`。

`DIM_CANDIDATE`（约第 874–911 行）在三类维度候选中传递 `COD_VALUTA_ORIGINARIA`，但仅用优先级区分 CURRENT/BY/LM。`RESULT_BASE` 内再次以四键执行：

```sql
ROW_NUMBER() OVER (
  PARTITION BY C.COD_AZIENDA
             , C.COD_CONTO
             , C.CUST_CODE
             , C.COD_DEST2
  ORDER BY C.PRIORITY
)
```

约第 1017–1025 行，仍缺少两个币种字段。因此即使候选来源分别带有不同币种，最终维度仍只选优先级最高的一条。

#### `RESULT_BASE`

`RESULT_BASE` 直接选择 `D.COD_VALUTA_ORIGINARIA`（约第 913–949 行），并从 `CURRENT_AGG`、`BY_HISTORY`、`LM_HISTORY` 回接金额。四类 JOIN 均只按四键：

- `D` 与 `ALL_KEYS`：约第 1027–1032 行；
- `CURRENT_AGG A`：约第 1033–1037 行；
- `BY_HISTORY B`：约第 1038–1042 行；
- `LM_HISTORY L`：约第 1043–1047 行。

这些 JOIN 条件全部没有 `COD_VALUTA` 或 `COD_VALUTA_ORIGINARIA`。`RESULT_BASE` 中的 `NVL` 仅用于历史/当前金额以及 `CURRENCY_ACCT_DETAIL`，没有对原币字段做 NVL。

#### `RESULT_FACT`

`RESULT_FACT` 直接选择 `R.COD_VALUTA_ORIGINARIA`（约第 1051–1084 行），没有再次 CASE/NVL/汇率处理。它把 `R.CALC_BCY_*_AMT` 输出为 M02 的 `BCY_*_AMT`，把 `R.ORG_QCY_*_AMT` 输出为 M02 的 `QCY_*_AMT`，并计算账龄调整、汇率评估和其他横向字段。该 CTE 不会恢复已经在前面四键聚合时丢失的币种粒度。

## 三、最终 MERGE 如何写入 M02

### 1. INPUT_DEFORM 复用 OID 的匹配粒度

在 `RESULT_FACT` 后，源结果通过左连接寻找目标表中 `PROVENIENZA = 'INPUT_DEFORM'` 的人工行。该人工行选择使用窗口分区（约第 1241–1261 行）：

```sql
PARTITION BY T.COD_SCENARIO
         , T.COD_PERIODO
         , T.COD_AZIENDA
         , T.COD_CONTO
         , T.CUST_CODE
         , T.COD_DEST2
```

并在与 `RESULT_FACT` 连接时按场景、期间、公司、科目、客商、利润中心匹配（约第 1264–1271 行），同样缺少两种币种字段。如果同一业务键存在多币种人工行，AG 会把它们视作同一组，只保留最新/最小 OID 的一条用于复用。

### 2. `MERGE ... WHEN MATCHED THEN UPDATE`

目标匹配条件是 `ON (T.OID = S.OID)`（约第 1274 行）。在 UPDATE 部分，币种列明确写入：

```sql
T.COD_VALUTA = S.COD_VALUTA
T.COD_VALUTA_ORIGINARIA = S.COD_VALUTA_ORIGINARIA
```

约第 1309–1311 行。也就是说 UPDATE 不会保留人工行原值，而是用本次结果中由 `CURRENT_DIM`/历史回退选出的单个币种覆盖它。

### 3. `MERGE ... WHEN NOT MATCHED THEN INSERT`

INSERT 列清单包含 `COD_VALUTA`、`COD_VALUTA_ORIGINARIA`（约第 1420–1425 行），VALUES 中对应写入 `S.COD_VALUTA`、`S.COD_VALUTA_ORIGINARIA`（约第 1536–1540 行）。因此新生成的 M02 行也只写入结果源中选出来的一个原币币种；INSERT 本身没有额外改写，但前面的聚合和维度选择已经决定了该值。

## 四、为什么 M01 的 JPY/CNY/USD 到 M02 可能只剩一个币种

假设 M01 同一 `COD_AZIENDA + COD_CONTO + CUST_CODE + COD_DEST2` 下有三行，原币分别为 JPY、CNY、USD：

1. `CURRENT_SOURCE_BASE` 读取三行原始 `COD_VALUTA_ORIGINARIA`，并分别计算可能不同的汇率因子。
2. `CURRENT_SOURCE` 保留三行及其各自金额/币种。
3. `CURRENT_DIM` 用四键分区的 `ROW_NUMBER()` 只选一行作为维度代表，优先 ORG，再按 OID。因此代表币种可能是 JPY，也可能是 CNY/USD，取决于数据的来源类别和 OID。
4. `CURRENT_SOURCE_AGG` 用四键 GROUP BY，将三行的 QCY 金额相加，将逐行换算后的本位币金额相加。
5. `ALL_KEYS` 只产生一个四键，`RESULT_BASE` 通过该四键回接一条维度代表和一组跨币种合计金额。
6. `RESULT_FACT` 继续携带代表行币种，MERGE UPDATE/INSERT 将该代表币种写入 M02。

因此“币种只剩一个”不是 `COD_VALUTA_ORIGINARIA` 在某个表达式中被转换成了某个固定值，而是币种字段没有参与确定结果行粒度，结果层先聚合了多币种金额，再从多行中选一条展示字段。

## 五、改造时必须关注的粒度位置（仅建议，不实施）

### 方案判断

推荐将 M02 改为“同一业务维度 + 本位币 + 交易币一行”，因为当前表同时保存 `QCY_*_AMT`（交易币金额）和 `BCY_*_AMT`（本位币金额），而交易币金额不可能在一个数值列中同时表达 JPY、CNY、USD。仅把币种字段加到最终 SELECT 或 UPDATE/INSERT 不够，必须贯穿所有产生结果行的操作。

### 必须同步检查/修改的位置

1. `CURRENT_DIM`：`ROW_NUMBER()` 的 `PARTITION BY` 加入 `COD_VALUTA`、`COD_VALUTA_ORIGINARIA`，或改为每个币种组合保留一行。
2. `CURRENT_SOURCE_AGG`：GROUP BY 加入 `COD_VALUTA`、`COD_VALUTA_ORIGINARIA`，使 `ORG_QCY_*_AMT` 等汇总保持单币种；`CURRENCY_ACCT_DETAIL` 可继续保留作为明细审计，但不能替代分组键。
3. `SUPPLEMENT_AGG`：补充来源若金额也需要按币种隔离，应读取/聚合币种并在 `CURRENT_AGG` JOIN 中加入相同币种；若补充金额业务上定义为本位币金额，则需明确其与币种结果行的分配规则，不能无条件复制到每个币种行。
4. `BY_HISTORY`、`LM_HISTORY`：历史数据读取及必要的去重/汇总要采用相同币种粒度，避免历史余额按四键匹配到多个或错误币种。
5. `ALL_KEYS`：UNION 的键集合加入两种币种（并决定 NULL 的匹配规范），否则当前有三币种仍只形成一个结果键。
6. `DIM_CANDIDATE` 和 `RESULT_BASE` 的窗口分区：加入相同币种字段，确保维度优先级只在同一币种内选择。
7. `RESULT_BASE` 的四类 JOIN：`D`、`CURRENT_AGG`、`BY_HISTORY`、`LM_HISTORY` 与 `ALL_KEYS` 均加入 `COD_VALUTA`/`COD_VALUTA_ORIGINARIA`，并统一 NULL/空格处理规则。
8. INPUT_DEFORM 复用 OID：窗口分区和与结果源连接均加入币种字段，否则多币种人工行仍会错误共用一条 OID。
9. 汇率连接：`QCY_RATE`、`BCY_RATE`、`TCURR_CONV` 已经使用原币/本位币字段；改造后需确认它们在逐币种明细上计算，并检查同币种汇总不会重复关联。
10. M02 表及下游约束：确认目标表允许同四键多币种行，检查唯一键/索引以及其它 AG 内部删除、保留人工行和重跑逻辑是否也采用完整币种键。若表定义实际上只允许四键唯一，则应先改模型/唯一键，不能只改 CTE。

### 验证建议

本次为只读静态分析，未连接数据库、未执行存储过程，也未修改任何文件。实施改造后至少应使用一组同四键含 JPY/CNY/USD 的 M01 样本验证：

- M02 是否生成三条对应币种的结果行；
- 每条 `QCY_*_AMT` 是否只包含本币种金额；
- 三条 `BCY_*_AMT` 之和是否等于按各自币种汇率换算后的预期本位币合计；
- `COD_VALUTA` 与 `COD_VALUTA_ORIGINARIA` 是否成对正确；
- 重跑时普通自动行删除、INPUT_DEFORM 的 OID 复用和 UPDATE/INSERT 是否都按币种隔离。

本报告只分析指定文件 `01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_AG_M_PHASE2.sql`，未分析 DWD、D2M、BD、INS，也未执行数据库操作。
