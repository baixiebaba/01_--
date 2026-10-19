# ARPM01 `CL` / `AR` 差异重新诊断报告

## 摘要结论

1. **当前 SQL 中 `TARGET_FACT` 本身没有 `LE_AGE_FLAG`。** 它只从 `AW_MR9_ARPM01_000001` 取待重分类行，并计算 `LE_BCY_AMT`、`ME_BCY_AMT`、`MB_BCY_AMT`。`LE_AGE_FLAG` 是 `REC_FLAG_FACT` 中调用 `TGK_GB_HISENSE.F_APAR_REC(..., LE_BCY_AMT, '2')` 后才生成的。因此“在 TARGET_FACT 看到 CL”不是当前 CTE 原样可见的结果，实际应当是调试查询把 `REC_FLAG_FACT` 或其后续 SELECT 也展开了，或者把窗口金额误认为标识。
2. 把 `A.CUST_CODE='2018840'` 放在窗口所在内层 WHERE，和把 `F.CUST_CODE='2018840'` 放在 `REC_FLAG_FACT` 外层，**语义不等价**：前者先缩小窗口输入，再计算金额；后者先对完整 `TARGET_FACT` 计算窗口金额和调用函数，再只筛输出行。即使目标行的 `CUST_CODE`、`CUST_HEAD_CODE` 都是 `2018840`，仍不能仅凭这两个字段证明窗口集合相同；需要检查同一分区中是否存在 NULL/其他客商、来源、系统、科目、公司归并值、利润中心和金额不同的行。
3. 对当前问题参数 `2026ACT/08/2600/2018840`，**最可能的直接原因不是缺少 `CUST_CODE` 分区键，而是调试位置/过滤时机不同，或两次调试所用的 `LE_BCY_AMT`、`CUST_KEY`、`MANDT`、`ACCT_REC_CODE` 实际不同**。当前函数参数使用的是 `CUST_KEY = A.CUST_HEAD_CODE`，不是 `A.CUST_CODE`；公司 2600 也不触发当前代码的 6000 特殊归并。若确认问题行及其完整窗口集合的两个客商字段都完全一致，则新增 `CUST_CODE` 对该行应当无效，不能作为根因或继续保留的业务修改。
4. `CL` 已由用户确认正确；在未完成下面对比前不应继续改窗口分区。建议先回退这三个未经证明的 `CUST_CODE` 分区改动（仅回退工作区改动，不在本次调查执行），再依据函数参数对比结果修复。

## 证据与 SQL 结构

### 1. `TARGET_FACT` 不生成账龄标识

目标文件 `01_代码/02_DWM/C_应收应付/CPM_SP_D2M_ARP_M_PHASE2.sql` 的第二段 `MERGE`（约 565 行起）中：

- `TARGET_FACT` 约 568--694 行从目标表 `AW_MR9_ARPM01_000001 A` 读取，选择了 `A.CUST_CODE`、`A.CUST_HEAD_CODE`、`A.ACCT_REC_CODE`、`A.SYSTEM_SRC` 等字段；
- 它计算三个窗口金额：`LE_BCY_AMT`（约 612--627 行）、`ME_BCY_AMT`（约 628--644 行）、`MB_BCY_AMT`（约 645--662 行）；
- WHERE 只限制场景、期间、公司、来源过程及 `SRC_DETAIL LIKE 'ORG%' OR SRC_DETAIL LIKE 'ZTSO04%'`，没有生成 `LE_AGE_FLAG`；
- `REC_FLAG_FACT` 约 696--792 行才对 `TARGET_FACT F` 调用函数。法人账龄标识明确是：

```sql
CASE
  WHEN F.SRC_DETAIL LIKE '%XH%' AND F.ACCT_SRC_CODE = '1122000095' THEN 'AR'
  WHEN F.SRC_DETAIL LIKE '%XH%' AND F.ACCT_SRC_CODE = '2202000095' THEN 'AP'
  WHEN F.SRC_DETAIL LIKE 'ORG%' THEN
    TGK_GB_HISENSE.F_APAR_REC(
        V_YEARMONTH, F.MANDT, F.COD_AZIENDA, F.ACCT_REC_CODE,
        F.CUST_KEY, F.LE_BCY_AMT, '2'
    )
END AS LE_AGE_FLAG
```

当前筛选的 `SRC_DETAIL` 只有 ORG/ZTSO04；`%XH%` 分支在当前 `TARGET_FACT` 输入中不会命中。因此问题行的 `LE_AGE_FLAG` 来源是 `F_APAR_REC`，不是 CASE 静态映射。最终 `MERGE` 约 891--910 行把 `S.LE_AGE_FLAG` 写回 `T.LE_AGE_FLAG`，并据此写 `COD_CONTO`；随后非 ORG 行才由独立 UPDATE 写默认科目。

另外，`TARGET_FACT` 中明确写的是：

```sql
A.CUST_HEAD_CODE AS CUST_KEY
```

所以不能只检查 `CUST_CODE` 和 `CUST_HEAD_CODE` 的显示值，还必须确认传给函数的 `CUST_KEY`、函数的金额和其他参数。

### 2. 当前未提交改动的实际影响

工作区相对 HEAD 的唯一差异是把 `A.CUST_CODE` 加入三个窗口：`LE_BCY_AMT`、`ME_BCY_AMT`、`MB_BCY_AMT`。这三个改动分别位于约 621--625、637--641、653--658 行；其余逻辑未变。

窗口输入顺序很关键：窗口函数位于从 `AW_MR9_ARPM01_000001 A` 读取的内层查询中，WHERE 先过滤，窗口再计算；`REC_FLAG_FACT` 的 `F.CUST_CODE` 若放在 CTE 末端/外层，则发生在窗口计算及函数调用之后。可用以下只读 SQL 验证两种语义（在实际过程同一 session 的参数公司范围内执行；若直接执行，请将过程变量替换为字面量并按实际 Oracle 对象权限调整）：

```sql
-- 先看当前过程真正会进入 TARGET_FACT 的原始行，不计算标识
SELECT A.OID,
       A.COD_AZIENDA,
       A.SRC_DETAIL,
       A.SYSTEM_SRC,
       A.CUST_CODE,
       A.CUST_HEAD_CODE,
       A.CUST_HEAD_CODE AS CUST_KEY,
       A.ACCT_SRC_CODE,
       A.ACCT_REC_CODE,
       A.COD_DEST2,
       A.BCY_0_AMT,
       A.COD_CONTO,
       A.LE_AGE_FLAG
  FROM AW_MR9_ARPM01_000001 A
 WHERE A.COD_SCENARIO = '2026ACT'
   AND A.COD_PERIODO = '08'
   AND A.COD_AZIENDA = '2600'
   AND A.PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
   AND (A.SRC_DETAIL LIKE 'ORG%' OR A.SRC_DETAIL LIKE 'ZTSO04%')
 ORDER BY A.SYSTEM_SRC, A.CUST_HEAD_CODE, A.CUST_CODE,
          A.ACCT_REC_CODE, A.COD_DEST2, A.OID;
```

对当前公司 2600 的说明：三个窗口中的 CASE 只把 `6000`、`6000A`、`6000B`、`6000C`、`6600` 且指定 `ACCT_REC_CODE` 的行归并成窗口公司 `6000`。`2600` 不在列表中，因此不会触发该特殊逻辑；但仍需实际检查同一窗口的系统、客商、科目及金额。

```sql
-- 检查“问题行所在完整窗口”是否含有其他客商、NULL 客商、不同来源/系统/科目/金额
SELECT A.SYSTEM_SRC,
       A.COD_AZIENDA,
       A.CUST_HEAD_CODE,
       A.CUST_CODE,
       A.ACCT_REC_CODE,
       A.SRC_DETAIL,
       A.COD_DEST2,
       COUNT(*) AS ROW_COUNT,
       SUM(CASE WHEN A.SRC_DETAIL LIKE 'ORG%' THEN NVL(A.BCY_0_AMT, 0) ELSE 0 END) AS LE_BCY_AMT,
       SUM(CASE WHEN A.SRC_DETAIL LIKE 'ORG%' OR A.SRC_DETAIL LIKE 'ZTSO04%'
                THEN NVL(A.BCY_0_AMT, 0) ELSE 0 END) AS ME_BCY_AMT
  FROM AW_MR9_ARPM01_000001 A
 WHERE A.COD_SCENARIO = '2026ACT'
   AND A.COD_PERIODO = '08'
   AND A.COD_AZIENDA = '2600'
   AND A.PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
   AND (A.SRC_DETAIL LIKE 'ORG%' OR A.SRC_DETAIL LIKE 'ZTSO04%')
   AND A.CUST_HEAD_CODE = '2018840'
 GROUP BY A.SYSTEM_SRC, A.COD_AZIENDA, A.CUST_HEAD_CODE,
          A.CUST_CODE, A.ACCT_REC_CODE, A.SRC_DETAIL, A.COD_DEST2
 ORDER BY A.SYSTEM_SRC, A.ACCT_REC_CODE, A.SRC_DETAIL,
          A.CUST_CODE, A.COD_DEST2;
```

上面必须特别观察：`CUST_CODE IS NULL`、`CUST_CODE <> '2018840'`、`CUST_HEAD_CODE IS NULL`、`SYSTEM_SRC` 不同、`SRC_DETAIL` 是 ORG 还是 ZTSO04、`ACCT_REC_CODE` 不同、`BCY_0_AMT` 的正负和合计是否不同。用户给出的“问题行两个客商字段均为 2018840”只能说明该行自身，不能证明窗口内只有这一行。

### 3. 精确比较内层过滤与外层过滤

以下 SQL 用同一组输入构造两个版本：`INNER_FILTER` 模拟把客户条件放到窗口所在内层 WHERE；`OUTER_FILTER` 模拟先计算完整窗口后在末端筛 `F.CUST_CODE`。它不调用 `F_APAR_REC`，先证明两种过滤是否产生不同的金额输入：

```sql
WITH BASE AS (
    SELECT A.OID,
           A.COD_AZIENDA,
           A.SRC_DETAIL,
           A.SYSTEM_SRC,
           A.CUST_CODE,
           A.CUST_HEAD_CODE,
           A.ACCT_REC_CODE,
           A.COD_DEST2,
           NVL(A.BCY_0_AMT, 0) AS BCY_0_AMT
      FROM AW_MR9_ARPM01_000001 A
     WHERE A.COD_SCENARIO = '2026ACT'
       AND A.COD_PERIODO = '08'
       AND A.COD_AZIENDA = '2600'
       AND A.PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
       AND (A.SRC_DETAIL LIKE 'ORG%' OR A.SRC_DETAIL LIKE 'ZTSO04%')
),
INNER_FILTER AS (
    SELECT B.*,
           SUM(CASE WHEN B.SRC_DETAIL LIKE 'ORG%' THEN B.BCY_0_AMT ELSE 0 END)
             OVER (PARTITION BY B.SYSTEM_SRC, B.COD_AZIENDA,
                                B.CUST_HEAD_CODE, B.CUST_CODE, B.ACCT_REC_CODE) AS LE_AMT_INNER,
           SUM(CASE WHEN B.SRC_DETAIL LIKE 'ORG%' OR B.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN B.BCY_0_AMT ELSE 0 END)
             OVER (PARTITION BY B.SYSTEM_SRC, B.COD_AZIENDA,
                                B.CUST_HEAD_CODE, B.CUST_CODE, B.ACCT_REC_CODE) AS ME_AMT_INNER
      FROM BASE B
     WHERE B.CUST_CODE = '2018840'
),
FULL_WINDOW AS (
    SELECT B.*,
           SUM(CASE WHEN B.SRC_DETAIL LIKE 'ORG%' THEN B.BCY_0_AMT ELSE 0 END)
             OVER (PARTITION BY B.SYSTEM_SRC, B.COD_AZIENDA,
                                B.CUST_HEAD_CODE, B.CUST_CODE, B.ACCT_REC_CODE) AS LE_AMT_OUTER,
           SUM(CASE WHEN B.SRC_DETAIL LIKE 'ORG%' OR B.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN B.BCY_0_AMT ELSE 0 END)
             OVER (PARTITION BY B.SYSTEM_SRC, B.COD_AZIENDA,
                                B.CUST_HEAD_CODE, B.CUST_CODE, B.ACCT_REC_CODE) AS ME_AMT_OUTER
      FROM BASE B
)
SELECT 'INNER_FILTER' AS TEST_SIDE, OID, CUST_CODE, CUST_HEAD_CODE,
       SYSTEM_SRC, SRC_DETAIL, ACCT_REC_CODE, COD_DEST2,
       LE_AMT_INNER AS LE_AMT, ME_AMT_INNER AS ME_AMT
  FROM INNER_FILTER
UNION ALL
SELECT 'OUTER_FILTER' AS TEST_SIDE, OID, CUST_CODE, CUST_HEAD_CODE,
       SYSTEM_SRC, SRC_DETAIL, ACCT_REC_CODE, COD_DEST2,
       LE_AMT_OUTER AS LE_AMT, ME_AMT_OUTER AS ME_AMT
  FROM FULL_WINDOW
 WHERE CUST_CODE = '2018840'
 ORDER BY OID, TEST_SIDE;
```

如果上述结果的同一 `OID` 金额一致，`CUST_CODE` 加入分区不会解释 `CL`/`AR`；如果不一致，说明存在相同 `CUST_CODE`/`CUST_HEAD_CODE` 下的其他分区维度或 NULL 客商行影响了输入，仍需按函数实际参数继续比较，而不是直接认定分区改动正确。

### 4. 对 `F_APAR_REC` 全参数的最终对比

当前代码对 ORG 行的 `LE_AGE_FLAG` 使用参数顺序：`202608`、`MANDT`、`COD_AZIENDA`、`ACCT_REC_CODE`、`CUST_KEY`（即 `CUST_HEAD_CODE`）、`LE_BCY_AMT`、`'2'`。下面查询应在能调用该函数的同一 Oracle 环境执行，分别对“完整窗口”和“仅客户内层窗口”计算函数结果；先用明确参数输出，避免只看最终标签：

```sql
-- 对实际候选行和实际函数参数逐行核对；MANDT 取公司维表 CITTA_LEGALE
SELECT A.OID,
       A.COD_AZIENDA,
       AZ.CITTA_LEGALE AS MANDT,
       A.SRC_DETAIL,
       A.SYSTEM_SRC,
       A.CUST_CODE,
       A.CUST_HEAD_CODE AS CUST_KEY,
       A.ACCT_SRC_CODE,
       A.ACCT_REC_CODE,
       NVL(A.BCY_0_AMT, 0) AS BCY_0_AMT,
       SUM(CASE WHEN A.SRC_DETAIL LIKE 'ORG%' THEN NVL(A.BCY_0_AMT, 0) ELSE 0 END)
         OVER (PARTITION BY A.SYSTEM_SRC, A.COD_AZIENDA,
                            A.CUST_HEAD_CODE, A.CUST_CODE, A.ACCT_REC_CODE) AS LE_BCY_AMT,
       TGK_GB_HISENSE.F_APAR_REC(
           '202608', AZ.CITTA_LEGALE, A.COD_AZIENDA, A.ACCT_REC_CODE,
           A.CUST_HEAD_CODE,
           SUM(CASE WHEN A.SRC_DETAIL LIKE 'ORG%' THEN NVL(A.BCY_0_AMT, 0) ELSE 0 END)
             OVER (PARTITION BY A.SYSTEM_SRC, A.COD_AZIENDA,
                                A.CUST_HEAD_CODE, A.CUST_CODE, A.ACCT_REC_CODE),
           '2') AS LE_FLAG_FULL_WINDOW
  FROM AW_MR9_ARPM01_000001 A
  LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
    ON AZ.COD_AZIENDA = A.COD_AZIENDA
 WHERE A.COD_SCENARIO = '2026ACT'
   AND A.COD_PERIODO = '08'
   AND A.COD_AZIENDA = '2600'
   AND A.PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
   AND A.CUST_CODE = '2018840'
   AND A.SRC_DETAIL LIKE 'ORG%'
 ORDER BY A.OID;
```

将这个结果与调试出的 `REC_FLAG_FACT` 行逐列对照，尤其是：

- `MANDT` 是否真为该公司在 `TGK_FIMA_HISENSE.AZIENDA.CITTA_LEGALE` 的值；
- `COD_AZIENDA` 是否为 2600，而非被 6000 特殊分支改写（当前代码传给函数的仍是 `F.COD_AZIENDA`，窗口才使用 CASE 归并键）；
- `ACCT_REC_CODE` 是否相同；它在 DWD_STANDARD 前段约 217--253 行由 `ACCT_SRC_CODE` 和公司规则重算，不能只看原始科目；
- `CUST_KEY` 是否为 2018840，且不是 NULL；
- `LE_BCY_AMT` 是否相同；
- 期间是否是 `'202608'`，而非把场景 `2026ACT` 或 `'08'` 直接传入函数；
- 最后参数是否为 `'2'`。

## 结论与建议

### 最可能根因

最可能是两次调试没有在同一层、同一过滤时机和同一函数输入上比较：所谓“TARGET_FACT=CL”不符合当前 CTE 定义，真正的 `CL/AR` 只能来自 `REC_FLAG_FACT` 的函数结果。其次是窗口金额的输入行集合不同，或 `F_APAR_REC` 的 `MANDT`、`ACCT_REC_CODE`、`CUST_KEY`、`LE_BCY_AMT` 有差异。单凭问题行 `CUST_CODE=CUST_HEAD_CODE=2018840` 不能排除这些差异。

### 是否修改

当前不建议继续修改 SQL。先执行上述三组只读对比：

1. 若完整窗口与内层客户过滤的 `LE_BCY_AMT` 相同，但函数参数或函数结果不同，修复调试取数/参数来源，不改窗口分区。
2. 若 `LE_BCY_AMT` 不同，定位造成差异的实际行（NULL/其他客商、来源、系统、科目、金额或利润中心），再由业务确认是否应当按 `CUST_CODE` 分区；不能仅以这一个客户样本证明应加入。
3. 若完整窗口函数结果稳定为 `CL`，而外层调试显示 `AR`，优先检查外层查询是否引用了另一个金额字段（如 `ME_BCY_AMT`）、另一科目或另一期间。
4. 若完整、内层两种输入及全部函数参数完全相同却结果不同，则应进一步核查函数本体/配置表有效期；仅凭本存储过程无法证明函数内部规则，需读取 `F_APAR_REC` 的实现或对应规则数据。
5. 在证据不足时，建议回退工作区当前三个 `PARTITION BY` 中新增的 `A.CUST_CODE`，恢复原提交版本，避免未经证明的业务口径变化；本次调查未执行回退。
