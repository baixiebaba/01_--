# M01 多交易币种到 M02 只剩一行的调查报告

## 摘要结论

**已由代码静态确认，币种记录不是在 M01 生成阶段丢失，而是在 `CPM_SP_M2M_ARP_AG_M_PHASE2` 的当前期间聚合阶段被按“公司 + 科目 + 客商 + 利润中心”合并。** 该过程的聚合键没有 `COD_VALUTA` 或 `COD_VALUTA_ORIGINARIA`；币种只作为被选中的一条维度属性写回结果。因此，对于用户给出的 `2026ACT/08/2910/224199F/402281`，若 4 条 M01 记录的 `COD_DEST2` 相同，AG 的设计结果就是 1 条 M02 记录。

具体造成收敛的链路是：

1. M01 的 `CPM_SP_D2M_ARP_M_PHASE2.AGG_FACT` 明确把 `COD_VALUTA`、`COD_VALUTA_ORIGINARIA` 放进 `GROUP BY`，所以同一业务键的 JPY、CNY、USD 在 M01 中可以保持为不同记录。
2. AG 的 `CURRENT_DIM` 却按 `COD_AZIENDA, COD_CONTO, CUST_CODE, COD_DEST2` 分区，仅通过 `ROW_NUMBER()` 取一条维度行；币种不参与分区。
3. AG 的 `CURRENT_SOURCE_AGG` 按同样的四列分组，使用 `SUM` 汇总所有 ORG 来源的金额；币种不参与分组。
4. `RESULT_BASE` 以 `ALL_KEYS` 的同一四列键连接 `CURRENT_AGG`，最终 `RESULT_FACT` 只有一个结果行，且 `COD_VALUTA/COD_VALUTA_ORIGINARIA` 来自 `CURRENT_DIM` 选中的那一行。用户看到 M02 为 `JPY/JPY`，与 `CURRENT_DIM` 的选行规则一致，并不表示 CNY/USD 没有参与金额计算。

金额方面，代码显示 M02 的 `BCY_0_AMT` 不是简单取某一条 M01 的 BCY，而是将各 M01 行先按来源和汇率规则计算后再求和。因此，M02 的 `BCY_0_AMT` 很可能已经包含 4 条币种记录的汇总/换算结果；但仅凭用户截图中的约数和当前工作区静态文件，无法验证 `-751,348,675` 是否精确等于数据库实际 4 行经本过程公式计算后的合计，也无法确认每条记录是否命中税率、汇率评估标识或汇率缺失分支。需要执行本文 SQL 进行事实核对。

## 证据与代码定位

### 1. M01 生成阶段保留了币种粒度

文件：`01_代码/02_DWM/C_应收应付/CPM_SP_D2M_ARP_M_PHASE2.sql`

- `DWD_STANDARD` 将 DWD 的 `BCY_CODE` 映射到 M01 的 `COD_VALUTA`，将 `QCY_CODE` 映射到 `COD_VALUTA_ORIGINARIA`（约第 275 行）。
- `M01_FACT` 直接继承来源交易币种字段（约第 363-364 行）。
- `AGG_FACT` 的选择列包含 `COD_VALUTA`、`COD_VALUTA_ORIGINARIA`（约第 429 行），并在金额汇总的 `GROUP BY` 中再次包含这两列（约第 479 行）。因此，若其他分组维度相同而来源币种不同，M01 仍会形成多行；这与用户提供的 4 行事实相符。

M01 的 `AGG_FACT` 同时对 `BCY_0_AMT` 和 `QCY_0_AMT` 做 `SUM`（约第 432 行及后续同类列）。这只是同一币种分组内的汇总，不是本次跨币种合并的来源。

### 2. AG 的真正业务键排除了币种

文件：`01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_AG_M_PHASE2.sql`

#### `CURRENT_DIM`：维度只保留一条

`CURRENT_DIM` 位于约第 530-580 行。其内层查询使用：

```sql
ROW_NUMBER() OVER (
  PARTITION BY S.COD_AZIENDA,
               S.COD_CONTO,
               S.CUST_CODE,
               S.COD_DEST2
  ORDER BY CASE WHEN S.SRC_DETAIL LIKE 'ORG%' THEN 1 ELSE 2 END,
           S.OID
) AS RN
```

随后只保留 `RN = 1`。分区列没有 `COD_VALUTA`、`COD_VALUTA_ORIGINARIA`，但外层选择又把这两个字段带出。因此，当 4 条 M01 行的四列业务键相同时，只有排序最靠前的一行提供 M02 的币种和相关维度属性。ORG 来源优先，ORG 内再按 OID 决定；这解释了为什么最终币种可能显示为 JPY/JPY，而不是同时显示 JPY/CNY/USD。

#### `CURRENT_SOURCE_AGG`：金额跨币种求和

`CURRENT_SOURCE_AGG` 从约第 583 行开始，分组明确为：

```sql
GROUP BY S.COD_AZIENDA,
         S.COD_CONTO,
         S.CUST_CODE,
         S.COD_DEST2
```

同一 CTE 中对 `ORG_BCY_0_AMT`、`CALC_BCY_0_AMT`、各账龄 BCY、ORG QCY 及汇率金额使用 `SUM`。币种字段既没有出现在 `GROUP BY`，也没有生成按币种分别的结果列；因此多币种在此处被压成一个四列业务键。

`CURRENCY_ACCT_DETAIL` 虽使用 `LISTAGG` 拼接来源科目、原币种和交易币金额，但它只是一个明细字符串，不能恢复独立的 M02 行。该字段位于 `CURRENT_SOURCE_AGG` 约第 740-745 行。

### 3. 最终结果再次按同一业务键装配

`ALL_KEYS`（约第 868-877 行）只取：

```sql
COD_AZIENDA, COD_CONTO, CUST_CODE, COD_DEST2
```

`RESULT_BASE`（约第 920 行以后）以这四列连接 `DIM_CANDIDATE`、`CURRENT_AGG`、`BY_HISTORY` 和 `LM_HISTORY`。其中 `DIM_CANDIDATE` 再按这四列使用 `ROW_NUMBER()` 取优先级最高的维度行。故本月当前数据即使在来源层有多个币种，最终也只产生一个当前键结果。

最后的 `MERGE INTO AW_MR9_ARPM02_000001` 以 OID 匹配更新（约第 1275 行），这不是本次丢币种的原因；OID 是前面结果集生成时才分配的。`INPUT_DEFORM` 复用逻辑也只按场景、期间、公司、科目、客商、利润中心找一条人工行（约第 1450 行以后），同样不包含币种，反而会强化“一个四列业务键一条结果”的设计。

### 4. 汇率和金额计算路径

`CURRENT_SOURCE_BASE`（约第 186-289 行）保留 M01 的 `COD_VALUTA`、`COD_VALUTA_ORIGINARIA`、BCY/QCY 金额，并分别关联：

- `QCY_RATE`：以 `COD_VALUTA_ORIGINARIA` 查 `DATI_CAMBIO`；
- `BCY_RATE`：以 `COD_VALUTA` 查 `DATI_CAMBIO`；
- 2023 公司另查 `TCURR_CONVERSION_RATE`。

当 `EXCHANGE_RATE_EVAL_FLAG` 为空且汇率条件满足时，非 2023 公司计算：

```text
CONVERSION_FACTOR = BCY 币种汇率 / QCY 币种汇率
```

CNY 作为人民币基准时对应因子按 1 处理。`CURRENT_SOURCE`（约第 300 行以后）对非 `AC/AS/CL` 的 ORG 来源，若有转换因子则使用 `QCY_0_AMT * CONVERSION_FACTOR`，否则回退使用 M01 的 `BCY_0_AMT`；对 `CL + IS_REC_LG='Y'` 的行使用 `BCY_0_AMT * TAX_FACTOR`，其他情况也有直接使用 BCY 的分支。

`CURRENT_SOURCE_AGG` 的 `ORG_BCY_0_AMT` 和 `CALC_BCY_0_AMT` 都是对这些逐行结果求和；`RESULT_FACT` 约第 1000 行以后将 `CALC_BCY_0_AMT` 写成 M02 的 `BCY_0_AMT`，而将 `ORG_QCY_0_AMT` 写成 M02 的 `QCY_0_AMT`。所以：

- **记录合并的直接原因是业务键设计和聚合，不是汇率表 JOIN 直接过滤了 CNY/USD 行。** 汇率 JOIN 是 `LEFT JOIN`，本身不会因无汇率而删除来源行。
- **汇率/税率可能改变合计金额。** 有因子时使用交易币金额换算；无因子时通常回退到 M01 BCY；CL 且法人应收时还可能套税率因子。
- **M02 的币种标签不代表金额只来自该币种。** 标签来自 `CURRENT_DIM` 的代表行，而金额来自 `CURRENT_SOURCE_AGG` 对所有币种的 SUM。

### 5. 下游过程不是本次首要原因

`CPM_SP_M2M_ARP_BD_M_PHASE2.sql` 的坏账处理主要按 M02 的 OID 回写坏账字段，虽然多个 CTE 会按公司、客商、科目、利润中心聚合辅助金额，但它在 AG 之后运行，不能解释“AG 执行后 M02 从 4 行变 1 行”。

`CPM_SP_M2M_ARP_INS_M_PHASE2.sql` 对 M02 账龄金额按公司+客商汇总投保数据，也是在 M02 已经生成后更新投保表，不会造成本次币种行数变化。

## 针对用户样例的判断

样例键为：

```text
COD_SCENARIO = '2026ACT'
COD_PERIODO  = '08'
COD_AZIENDA  = '2910'
COD_CONTO    = '224199F'
CUST_CODE    = '402281'
```

需要额外确认 `COD_DEST2` 是否 4 行完全相同。若相同，则与 AG 四列分组完全命中，静态代码已足以解释从 4 行到 1 行。若 `COD_DEST2` 不同，则理论上 AG 应至少保留不同利润中心的多行；此时应检查用户查询是否省略了 `COD_DEST2`，以及 M01/M02 的实际值是否存在空值与非空值差异。AG 的连接使用 `NVL(COD_DEST2,'#')`，空值和空值会视为同一键。

用户给出的 4 个约数直接相加约为 398 百万元，而 M02 约为 -751 百万元；这个差异不能仅凭截图证明是代码错误，因为：

1. 这些数值是“约数”，且可能并非同一字段或同一口径；
2. AG 可能对部分行使用 QCY×汇率因子而非 M01 BCY；
3. 可能存在 `EXCHANGE_RATE_EVAL_FLAG`、`LE_AGE_FLAG`、`IS_REC_LG`、税率及汇率缺失分支；
4. M01 查询可能未包含同一四列键下的所有来源行或 `SRC_DETAIL` 行。

因此“跨币种被聚合”是已验证事实；“M02 -751,348,675 精确由哪几行、哪几个汇率/税率分支构成”必须通过下列数据库 SQL 验证，不能在静态分析中冒充已验证。

## 可执行验证 SQL

以下 SQL 面向 Oracle 语法。将 `TGK_FIMA_DEV` 替换为实际数据 schema（如果当前连接默认 schema 已包含目标表，可去掉前缀）。所有 SQL 均为只读查询。

### SQL 1：确认 M01 四行的完整业务键、币种和金额

```sql
SELECT COD_AZIENDA,
       COD_CONTO,
       CUST_CODE,
       COD_DEST2,
       COD_VALUTA,
       COD_VALUTA_ORIGINARIA,
       SRC_DETAIL,
       LE_AGE_FLAG,
       IS_REC_LG,
       EXCHANGE_RATE_EVAL_FLAG,
       TAX_RATE,
       BCY_0_AMT,
       QCY_0_AMT,
       OID
  FROM AW_MR9_ARPM01_000001
 WHERE COD_SCENARIO = '2026ACT'
   AND COD_PERIODO = '08'
   AND COD_AZIENDA = '2910'
   AND COD_CONTO = '224199F'
   AND CUST_CODE = '402281'
 ORDER BY COD_DEST2, COD_VALUTA_ORIGINARIA, OID;
```

预期：核实是否确实为 4 行，以及 4 行的 `COD_DEST2` 是否一致；同时确认是否都是 ORG 来源、各自账龄标识和汇率评估标识。

### SQL 2：直接模拟 AG 的业务键压缩效果

```sql
SELECT COD_AZIENDA,
       COD_CONTO,
       CUST_CODE,
       COD_DEST2,
       COUNT(*) AS M01_ROW_COUNT,
       COUNT(DISTINCT COD_VALUTA) AS BCY_CURRENCY_COUNT,
       COUNT(DISTINCT COD_VALUTA_ORIGINARIA) AS QCY_CURRENCY_COUNT,
       LISTAGG(COD_VALUTA_ORIGINARIA, ',')
         WITHIN GROUP (ORDER BY COD_VALUTA_ORIGINARIA) AS QCY_CURRENCIES,
       SUM(NVL(BCY_0_AMT, 0)) AS M01_BCY_SUM,
       SUM(NVL(QCY_0_AMT, 0)) AS M01_QCY_SUM
  FROM AW_MR9_ARPM01_000001
 WHERE COD_SCENARIO = '2026ACT'
   AND COD_PERIODO = '08'
   AND COD_AZIENDA = '2910'
   AND COD_CONTO = '224199F'
   AND CUST_CODE = '402281'
 GROUP BY COD_AZIENDA, COD_CONTO, CUST_CODE, COD_DEST2;
```

预期：如果返回 1 个四列键且 `QCY_CURRENCY_COUNT > 1`，就直接证明 AG 的 `CURRENT_SOURCE_AGG` 会把这些币种纳入同一个聚合组。

### SQL 3：核对 AG 的代表币种选择（CURRENT_DIM 的等价检查）

```sql
SELECT COD_AZIENDA,
       COD_CONTO,
       CUST_CODE,
       COD_DEST2,
       COD_VALUTA,
       COD_VALUTA_ORIGINARIA,
       SRC_DETAIL,
       OID,
       ROW_NUMBER() OVER (
         PARTITION BY COD_AZIENDA, COD_CONTO, CUST_CODE, COD_DEST2
         ORDER BY CASE WHEN SRC_DETAIL LIKE 'ORG%' THEN 1 ELSE 2 END,
                  OID
       ) AS DIM_RN
  FROM AW_MR9_ARPM01_000001
 WHERE COD_SCENARIO = '2026ACT'
   AND COD_PERIODO = '08'
   AND COD_AZIENDA = '2910'
   AND COD_CONTO = '224199F'
   AND CUST_CODE = '402281'
 ORDER BY COD_DEST2, DIM_RN;
```

预期：`DIM_RN = 1` 的币种就是 AG 可能写入 M02 的币种标签；若为 JPY/JPY，即可解释用户看到的结果。

### SQL 4：查询实际汇率，确认 CNY/USD/JPY 的换算条件

```sql
SELECT COD_VALUTA,
       MAX(CAMBIO_FINALE) AS RATE
  FROM TGK_FIMA_HISENSE.DATI_CAMBIO
 WHERE COD_SCENARIO = '2026ACT'
   AND COD_PERIODO = '08'
   AND COD_VALUTA IN ('JPY', 'CNY', 'USD')
 GROUP BY COD_VALUTA
 ORDER BY COD_VALUTA;
```

若公司 2910 的逻辑不属于 2023，按 AG 公式检查：`BCY` 为 JPY 时，非 CNY 原币行的因子为 `RATE(JPY) / RATE(QCY)`；CNY 原币的分母按 1 处理。

### SQL 5：按 AG 公式重算样例的候选 BCY 合计

```sql
WITH rate AS (
  SELECT COD_VALUTA, MAX(CAMBIO_FINALE) AS RATE
    FROM TGK_FIMA_HISENSE.DATI_CAMBIO
   WHERE COD_SCENARIO = '2026ACT'
     AND COD_PERIODO = '08'
   GROUP BY COD_VALUTA
), src AS (
  SELECT A.*,
         CASE
           WHEN TRIM(A.EXCHANGE_RATE_EVAL_FLAG) IS NULL
            AND TRIM(A.COD_VALUTA_ORIGINARIA) IS NOT NULL
            AND TRIM(A.COD_VALUTA) IS NOT NULL
            AND (TRIM(A.COD_VALUTA_ORIGINARIA) = 'CNY'
                 OR Q.RATE IS NOT NULL AND Q.RATE <> 0)
            AND (TRIM(A.COD_VALUTA) = 'CNY'
                 OR B.RATE IS NOT NULL AND B.RATE <> 0)
           THEN ROUND(
                  (CASE WHEN TRIM(A.COD_VALUTA) = 'CNY' THEN 1 ELSE B.RATE END)
                  /
                  (CASE WHEN TRIM(A.COD_VALUTA_ORIGINARIA) = 'CNY' THEN 1 ELSE Q.RATE END),
                  5)
         END AS CONVERSION_FACTOR
    FROM AW_MR9_ARPM01_000001 A
    LEFT JOIN rate Q ON Q.COD_VALUTA = TRIM(A.COD_VALUTA_ORIGINARIA)
    LEFT JOIN rate B ON B.COD_VALUTA = TRIM(A.COD_VALUTA)
   WHERE A.COD_SCENARIO = '2026ACT'
     AND A.COD_PERIODO = '08'
     AND A.COD_AZIENDA = '2910'
     AND A.COD_CONTO = '224199F'
     AND A.CUST_CODE = '402281'
     AND A.SRC_DETAIL LIKE 'ORG%'
)
SELECT COD_VALUTA,
       COD_VALUTA_ORIGINARIA,
       LE_AGE_FLAG,
       IS_REC_LG,
       EXCHANGE_RATE_EVAL_FLAG,
       BCY_0_AMT,
       QCY_0_AMT,
       CONVERSION_FACTOR,
       CASE
         WHEN LE_AGE_FLAG = 'CL' AND IS_REC_LG = 'Y'
           THEN BCY_0_AMT / NULLIF(1 + NVL(TAX_RATE, 0), 0)
         WHEN LE_AGE_FLAG NOT IN ('AC', 'AS', 'CL')
          AND CONVERSION_FACTOR IS NOT NULL
           THEN QCY_0_AMT * CONVERSION_FACTOR
         ELSE BCY_0_AMT
       END AS AG_CALC_BCY_0_AMT
  FROM src
 ORDER BY COD_VALUTA_ORIGINARIA;
```

将该查询的 `AG_CALC_BCY_0_AMT` 求和，并与 M02 查询结果比较。注意：AG 源码中的 `CALC_BCY_0_AMT` 对 `CL + IS_REC_LG='Y'` 的具体税因子还依赖前面 `TAX_FACTOR` 定义；上面 SQL 使用的是源码中该分支的等价业务意图，若要逐项完全复刻，应把 `TAX_FACTOR` 定义改成源码原式 `1 / NULLIF(1 + NVL(TAX_RATE, 0), 0)` 后再计算。

### SQL 6：核对 M02 实际结果及其是否只有一行

```sql
SELECT COD_AZIENDA,
       COD_CONTO,
       CUST_CODE,
       COD_DEST2,
       COD_VALUTA,
       COD_VALUTA_ORIGINARIA,
       BCY_0_AMT,
       QCY_0_AMT,
       BY_BCY_0_AMT,
       LM_BCY_0_AMT,
       CURRENCY_ACCT_DETAIL,
       PROVENIENZA,
       OID
  FROM AW_MR9_ARPM02_000001
 WHERE COD_SCENARIO = '2026ACT'
   AND COD_PERIODO = '08'
   AND COD_AZIENDA = '2910'
   AND COD_CONTO = '224199F'
   AND CUST_CODE = '402281'
 ORDER BY COD_DEST2, OID;
```

重点检查 `CURRENCY_ACCT_DETAIL`：若其中出现多个原币种片段，而 M02 只有一行，就能同时证明币种金额曾参与 AG 汇总，但币种维度只以字符串审计信息保留。

### SQL 7：检查历史记录和人工行是否造成额外覆盖

```sql
SELECT PROVENIENZA,
       COUNT(*) AS ROW_COUNT,
       COUNT(DISTINCT COD_VALUTA_ORIGINARIA) AS QCY_CURRENCY_COUNT,
       SUM(NVL(BCY_0_AMT, 0)) AS BCY_SUM
  FROM AW_MR9_ARPM02_000001
 WHERE COD_SCENARIO = '2026ACT'
   AND COD_PERIODO = '08'
   AND COD_AZIENDA = '2910'
   AND COD_CONTO = '224199F'
   AND CUST_CODE = '402281'
 GROUP BY PROVENIENZA;
```

该查询用于排除 `INPUT_DEFORM` 或重复运行残留对最终观察结果的影响；但即便存在人工行，AG 当前 MERGE 的匹配业务键也不含币种。

## 结论与建议

### 已验证事实（静态代码）

- M01 `AGG_FACT` 的分组包含两类币种字段，能够保留多币种行。
- AG `CURRENT_DIM`、`CURRENT_SOURCE_AGG`、`ALL_KEYS`、`RESULT_BASE` 均以公司+科目+客商+利润中心为粒度，没有币种字段。
- `CURRENT_DIM` 任取一条维度币种；`CURRENT_SOURCE_AGG` 对来源金额做跨币种 `SUM`；因此 M02 一行显示单一币种但金额可能来自多币种。
- 汇率关联使用 `LEFT JOIN`，静态上没有“因汇率不存在而过滤行”的证据。

### 尚未由数据库验证的事项

- 用户给出的四个约数是否是 M01 每行的 `BCY_0_AMT`，还是其他展示口径。
- 四行是否有完全相同的 `COD_DEST2`、`SRC_DETAIL` 和相关账龄字段。
- M02 的 `-751,348,675` 是否精确等于 AG 对这些行套用实际汇率、税率和年龄标识后的计算合计。
- 当前数据库中 `DATI_CAMBIO` 的 JPY/CNY/USD 汇率以及这些行的 `EXCHANGE_RATE_EVAL_FLAG` 实际值。

### 修复方向（本次未实施）

如果业务要求 M02 保留每个交易币种独立行，应将币种粒度贯穿 AG 的设计：至少在 `CURRENT_DIM`、`CURRENT_SOURCE_AGG`、`ALL_KEYS`、`DIM_CANDIDATE`、`RESULT_BASE`、人工行复用键及最终 MERGE 业务键中加入 `COD_VALUTA` 和 `COD_VALUTA_ORIGINARIA`，并重新定义 BY/LM 及坏账过程的粒度。不能只把币种字段加进最终 SELECT，因为金额已在 `CURRENT_SOURCE_AGG` 处完成不可逆的跨币种汇总。

如果业务设计本意就是“本位币单行汇总”，则当前行数结果符合该设计，但应避免把代表行的 `COD_VALUTA_ORIGINARIA` 当作整行唯一交易币种；建议继续保留并校验 `CURRENCY_ACCT_DETAIL`，并在报表/校验中明确 M02 为跨币种折算后的本位币汇总，另增加按原币种的审计明细或独立明细表。

本调查未修改任何 SQL、数据或服务器。