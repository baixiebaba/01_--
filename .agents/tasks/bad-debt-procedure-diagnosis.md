# 坏账存储过程诊断报告

## 一、总结结论

诊断对象：`/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_BD_M_PHASE2.sql`。

**结论先行：该过程确实存在会直接导致 ARPM02 结果错误的实现问题，不是校验 SQL 本身的问题。最确定的三项是：**

1. **STEP1 负数冲减的 FIFO 窗口粒度错误**：`AGE_SUMMARY` 已经把同一公司、客商、账龄的金额作为窗口值重复挂到每一行，但 `AGE_FIFO` 又按明细行使用 `ROWS` 累计，且没有账龄内的稳定排序；同一账龄有多行时会把同一账龄金额重复计入“较长账龄已占用金额”，负数冲减结果会依赖行顺序并可能被过度冲减。
2. **STEP2 只计算 1–9 段，10–15 段被强制清零**：`CALCULATION_BASE`、个别认定聚合和坏账计算只取到 9 段；UPDATE 明确将 `BD_10_AMT` 至 `BD_15_AMT` 置为 0。由于 STEP3 又只使用 1–9 段的分摊金额，最终 `BD_AFAL_10_AMT` 至 `BD_AFAL_15_AMT` 也只能为个别认定值或 0，无法体现 STEP1 的 15 个账龄基数。
3. **个别认定 SPID 没有覆盖未匹配行的清理逻辑**：第一段 MERGE 只更新有 `ARP_02_002` 匹配的 OID，未匹配 OID 的旧 `SPID_*` 不会清空；重跑时旧个别认定值仍可能被 STEP3 的 `SPID_n_AMT IS NOT NULL` 分支优先使用，造成历史结果残留。

此外，STEP1 当前回写的 `BD_BASE_1_AMT` 至 `BD_BASE_15_AMT` 是经过垫资和负数处理后的金额，但没有按用户提供的字段定义在 STEP1 内按投保保障天数及未覆盖比例进行处理；投保乘数目前放到了 STEP2，且只覆盖前四段。这是与给定字段描述的明确不一致，是否要把投保处理从 STEP2 前移到 STEP1，需要业务确认后实施。

本报告只做静态代码诊断，未修改 SQL、未提交 Git、未连接或执行数据库。

## 二、已确认问题及证据

### 1. STEP1 负数 FIFO 的窗口聚合粒度不正确（高风险）

**位置：** `AGE_SUMMARY`、`AGE_FIFO`、`AGE_ALLOCATED`，约第 160–177 行。

关键代码逻辑：

```sql
SUM(ADJ_POS) OVER (
  PARTITION BY COD_AZIENDA, CUST_CODE, AGE_NO
) AGE_POS
...
SUM(AGE_POS) OVER (
  PARTITION BY COD_AZIENDA, CUST_CODE
  ORDER BY AGE_NO DESC
  ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
) OLDER_POS
```

`AGE_SUMMARY` 中的 `AGE_POS` 是公司+客商+账龄的汇总值，但它被重复放在该账龄的每个 OID 行上。随后 `AGE_FIFO` 使用 `ROWS` 按明细行滚动，且 `ORDER BY` 只有 `AGE_NO`：

- 同一 `AGE_NO` 存在多行时，某一行可能把同一账龄其他行的 `AGE_POS` 计入 `OLDER_POS`；
- 同账龄行没有稳定的 tie-breaker，结果可能随执行计划或行顺序变化；
- 负数冲减的“先长账龄、再短账龄”应以“账龄汇总行”为单位计算，而不是把已经汇总的账龄金额再次按明细行累计。

后续第 175–177 行用 `NEG_TOTAL - OLDER_POS` 计算 `FINAL_AGE_POS`，因此上述错误会直接改变 `BD_BASE_1_AMT` 至 `BD_BASE_15_AMT`。这不是单纯的展示问题，而是基数金额计算错误。

**建议修改方案：** 先按公司+客商+账龄聚合出唯一的 `AGE_POS`，在唯一账龄粒度上按 `AGE_NO DESC` 计算累计冲减额，再将该账龄剩余金额按各 OID 的 `ADJ_POS / AGE_POS` 比例回分；或者保留明细粒度时使用先去重的账龄汇总 CTE 与明确的账龄级累计，不要对重复的 `AGE_POS` 使用 `ROWS` 窗口。

### 2. STEP1 的垫资扣减范围和回写 OID 机制基本清晰，但负数/垫资组合仍受上述 FIFO 缺陷影响

**位置：** `BASE_DATA` 第 105–134 行、`AGE_PROGRESS` 第 146–152 行、`DEDUCTED_AGE` 第 153–158 行、`BASE_RESULT` 第 180–202 行。

已确认的实现关系：

- 当前场景、期间、纳入会话公司范围的 ARPM02 行从 `AW_MR9_ARPM02_000001` 读取；
- 垫资扣减从 `AW_MR9_ARPM01_000001` 按公司+客商+利润中心汇总，类型为 `ARP_02_001`；
- `AGE_PROGRESS` 按单个 `OID` 的 `AGE_NO DESC` 计算前序正数，意图是从长账龄开始扣垫资；
- `BASE_RESULT` 按 `OID` 聚合，最终通过 `MERGE ... ON (T.OID = S.OID)` 回写 `BD_BASE_0_AMT` 和 `BD_BASE_1_AMT` 至 `BD_BASE_15_AMT`，回写键本身是明确的。

但是，垫资处理后的 `ADJ_POS` 又进入存在粒度问题的 `AGE_SUMMARY/AGE_FIFO`，所以不能据此认定负数冲减结果正确。建议先修复账龄级 FIFO，再验证垫资与负数同时存在时是否满足“垫资从长账龄扣减、负数按长账龄冲减正数”的规则。

### 3. STEP1 没有按提供的字段定义在基数阶段应用投保规则（高风险，定义不一致）

**位置：** `BASE_DATA` 第 105–134 行、`BASE_RESULT` 第 180–202 行；投保数据来自约第 120–134 行；STEP2 的投保乘数在第 413–416 行。

STEP1 读取 `INS_COV_DAYS`、`INS_UNCOV_RATIO`，并在第 207 行回写 `INS_COV_DAYS`、`INS_UNCOV_RATE`，但 `BD_BASE_1_AMT` 至 `BD_BASE_15_AMT` 的计算仅为负数/垫资处理后的 `FINAL_AGE_POS * POS_RATE`，没有使用投保字段。

投保条件实际出现在 STEP2：

```sql
BD_BASE_1_AMT * rate * 投保条件
BD_BASE_2_AMT * rate * 投保条件
BD_BASE_3_AMT * rate * 投保条件
BD_BASE_4_AMT * rate * 投保条件
```

而用户提供的字段定义对 `BD_BASE_1_AMT` 至 `BD_BASE_4_AMT` 已明确描述了保障天数和未覆盖比例条件，并将它们定义为 STEP1 各账龄基数。当前实现因此出现语义错位：表中的 `BD_BASE_*` 看起来是原始/调整后基数，但字段定义要求它们已经包含投保规则；同时 STEP2 又再次根据投保条件处理。

**建议修改方案：** 先确认 `BD_BASE_*` 的正式口径：若字段定义为准，STEP1 应在形成 `BASE_RESULT` 时按 1–4 段投保规则处理，STEP2 不应再次重复乘投保比例；若设计实际要求 `BD_BASE_*` 保留投保前基数，则应修订字段描述/数据字典，明确投保只属于 STEP2，避免校验人员按字段定义误判。

### 4. STEP2/STEP3 对 10–15 账龄段不完整，导致最终字段无法覆盖 15 段（高风险）

**位置：** STEP2 个别认定 MERGE 约第 230–273 行；`CALCULATION_BASE` 第 383–409 行；`BAD_DEBT_CALCULATION` 第 410–420 行；STEP2 UPDATE 第 422–442 行；STEP3 `ALLOCATION_DATA` 第 464–475 行和 `CALCULATION_RESULT` 约第 502–570 行。

具体证据：

- STEP2 第一段 MERGE 虽然汇总了 `SPID_0_AMT` 至 `SPID_15_AMT`，但后续 `INDIVIDUAL_DATA` 只聚合 `BCY_1_AMT` 至 `BCY_9_AMT`；
- `CALCULATION_BASE` 只选择 `BD_BASE_1_AMT` 至 `BD_BASE_9_AMT` 和 `INDIVIDUAL_1_AMT` 至 `INDIVIDUAL_9_AMT`；
- `BAD_DEBT_CALCULATION` 只生成 `CALCULATED_1_AMT` 至 `CALCULATED_9_AMT`，合计也只加 1–9；
- STEP2 UPDATE 明确执行：

```sql
T.BD_10_AMT = 0 ... T.BD_15_AMT = 0
```

- STEP3 的 `ALLOCATION_DATA` 只生成 `AGE_ALLOC_1` 至 `AGE_ALLOC_9`；
- STEP3 对 `AGE_ALLOC_10_AMT` 至 `AGE_ALLOC_15_AMT` 固定写 0；
- STEP3 对 `BD_AFAL_10_AMT` 至 `BD_AFAL_15_AMT` 虽读取 `SPID_10_AMT` 至 `SPID_15_AMT`，但无个别认定时只走 `NVL(SPID_n_AMT, 0)`，不会使用对应 `BD_n_AMT` 计算。

因此，只要 STEP1 的 `BD_BASE_10_AMT` 至 `BD_BASE_15_AMT` 有金额，正常账龄计提链路仍会在 STEP2 被清零，最终 `BD_AFAL_10_AMT` 至 `BD_AFAL_15_AMT` 不能反映这些基数。这个问题与用户提供的 `BD_BASE_1~15`、`BD_AFAL_1~15` 字段定义直接冲突。

**建议修改方案：** 统一把 1–15 段纳入个别认定聚合、基数选择、比例字段映射、坏账计算、合计和 STEP3 负数分摊；不要用固定清零替代未配置比例的计算。每一段的比例来源（尤其 10–15 段对应的 `FORM_DATI.IMPORTO_*`）必须按正式设计文档逐段确认并写成显式映射。

### 5. 个别认定值存在重跑残留风险（高风险）

**位置：** STEP2 第一段个别认定 MERGE，约第 230–273 行；STEP3 个别认定优先逻辑，约第 522–546 行。

第一段 MERGE 的 USING 查询只返回存在 `ARP_02_002` 明细的 OID，且只写 `WHEN MATCHED`。当某 OID 本次没有个别认定明细时，不会进入 UPDATE，因此该 OID 之前已有的 `SPID_0_AMT` 至 `SPID_15_AMT` 不会被置空或置零。

STEP3 又使用：

```sql
CASE WHEN ALLOCATION_DATA.SPID_1_AMT IS NOT NULL
     THEN ALLOCATION_DATA.SPID_1_AMT
     ELSE ...计算值...
END
```

所以旧的非空 SPID 会继续覆盖本次正常计算。由于过程分 STEP1、STEP2、STEP3 提交，重跑同一期间时该问题尤其容易出现。

**建议修改方案：** 在同一批次开始时，对当前场景、期间、公司范围内所有目标 OID 先将 `SPID_0_AMT` 至 `SPID_15_AMT` 统一清空/置零，再写入本批次匹配结果；同时明确“空值”和“金额为 0”的业务语义。更稳妥的做法是把匹配结果做成覆盖全量目标 OID 的 `LEFT JOIN` 源集，让无匹配行也显式回写 0/NULL。

### 6. 个别认定匹配粒度未包含科目，可能把多个科目的调整合并使用

**位置：** STEP2 第一段 MERGE JOIN 约第 240–248 行，以及 `INDIVIDUAL_DATA` 聚合/连接约第 394–407 行。

当前个别认定匹配键包含场景、期间、公司、客商、利润中心和 `NATURE_L3_NAME`，但没有 `COD_CONTO`：

```sql
A.COD_AZIENDA = T0.COD_AZIENDA
AND A.CUST_CODE = T0.CUST_CODE
AND A.COD_DEST2 = T0.COD_DEST2
AND A.NATURE_L3_NAME = T0.NATURE_L3_NAME
```

如果同一公司+客商+利润中心+三级性质下存在多个科目，某一科目的个别认定金额会被聚合后复制到同组其他科目。这个是连接粒度风险；是否故意按客商/性质跨科目使用，不能仅凭过程确认。

**建议修改方案：** 若个别认定应按“公司+科目+客商+利润中心”匹配，则在两处 JOIN/GROUP BY 都补充 `COD_CONTO`；若业务确实要求跨科目共用，则应在设计说明中明确，并增加防止重复计提的校验。

### 7. 上月期末坏账的连接粒度跨科目，可能使同一上月金额重复带到多个科目

**位置：** `LAST_MONTH_DATA` 约第 495–500 行，及与 `ALLOCATION_DATA` 的连接约第 580–584 行。

`LAST_MONTH_DATA` 按 `COD_AZIENDA, CUST_CODE, COD_DEST2` 汇总上月 `BD_AFAL_0_AMT`，没有 `COD_CONTO`；STEP3 连接时也只按公司、客商、利润中心连接。若同组存在多个科目，上月合计会在每个科目行重复使用，进而影响各行的 `MTD_BD_PROV_OCUR_AMT`。

**建议修改方案：** 如果本月发生额应按科目核算，`LAST_MONTH_DATA` 应按并连接 `COD_CONTO`；如果业务口径确实是客商级/利润中心级统一余额，则应确认 `MTD_BD_PROV_OCUR_AMT` 是否允许在科目明细行重复展示，而不是直接相加后作为科目级结果。

### 8. STEP3 的负数分摊只覆盖 1–9 段，与目标字段 1–15 不一致

**位置：** `ALLOCATION_DATA` 约第 464–475 行，`CALCULATION_RESULT` 约第 504–519 行和第 553–570 行。

负数行的 `BD_1_AMT` 至 `BD_9_AMT`被汇总为 `AGE_ALLOC_1` 至 `AGE_ALLOC_9`，10–15 没有对应的负数来源；随后 10–15 的分摊金额固定为 0。即使修复 STEP2 的 10–15 计算，STEP3 仍会遗漏 10–15 的负数冲减/分摊。

**建议修改方案：** 将 `AGE_ALLOC_10` 至 `AGE_ALLOC_15` 按与 1–9 相同的逻辑补齐，并将其纳入 `AGE_ALLOC_0_AMT`、`BD_AFAL_0_AMT` 和本月发生额合计。

## 三、需要用户确认的业务规则

以下事项从代码可以确认“实现方式”，但不能仅凭当前文件确认“正确业务口径”，不应在没有确认的情况下直接改 SQL：

1. **BD_BASE 的投保口径**：字段定义描述似乎要求 STEP1 基数包含投保保障天数/未覆盖比例，但现代码把投保乘数放在 STEP2。需确认 `BD_BASE_*` 是“投保前调整后基数”还是“投保后坏账计提基数”。
2. **10–15 段的坏账比例来源**：当前 `FORM_DATI` 只映射到 `IMPORTO_6` 至 `IMPORTO_12`、`IMPORTO_22`、`IMPORTO_21`，需要确认这 9 个比例分别对应哪些账龄段，以及 10–15 段应从哪些字段取比例。
3. **个别认定匹配是否跨科目**：现代码按公司+客商+利润中心+三级性质聚合，没有科目；需确认是否应补 `COD_CONTO`。
4. **负数冲减范围**：STEP1 按公司+客商跨科目、跨利润中心、跨类别冲减；STEP3 则按公司+客商+科目分摊。需确认 STEP1 是否确实不需要科目、利润中心和类别，两个步骤的粒度是否应统一。
5. **个别认定金额为 0 的含义**：当前 `INDIVIDUAL_n_AMT <> 0` 才覆盖计算值，显式输入 0 会被视为“没有个别认定”并回退到比例计算。需确认 0 是有效覆盖值还是代表未配置。
6. **上月期末余额及本月发生额的粒度**：需确认 `BD_AFAL_0_AMT` 与 `MTD_BD_PROV_OCUR_AMT` 是科目级，还是公司+客商+利润中心级后在多个科目行展示。
7. **无投保信息时的默认规则**：现代码将 `INS_COV_DAYS` 为空/小于等于 0 视为不适用投保并使用比例 1；需确认这是否与正式规则一致。
8. **目标表是否保证 OID 唯一且 BCY_ADJ_INCL 只在单行存在**：STEP1 最后按 OID 回写是合理的前提是 OID 唯一；若同一业务键有多行，仍需明确行级分摊规则。

## 四、建议的修改顺序

1. 先确认上述业务规则，尤其是 BD_BASE 投保口径、10–15 比例映射和科目粒度；
2. 修复 STEP1 的账龄级聚合/FIFO，确保同一账龄只参与一次长账龄累计，再按原 OID 比例回写；
3. 让 STEP2 全量覆盖 1–15 段，移除无业务依据的 10–15 清零，并同步补齐个别认定字段和比例映射；
4. 对每次运行的目标 OID 先清理或全量覆盖 SPID，消除重跑残留；
5. 按确认后的业务粒度统一 STEP1 负数、STEP2 个别认定、STEP3 上月余额及分摊连接键；
6. 补齐 STEP3 10–15 段负数分摊和最终余额合计；
7. 在数据库变更前用固定样例验证：单一 OID、多 OID 同账龄、垫资跨账龄、负数跨账龄、投保 0/30/90/180/大于180天、10–15 段金额、个别认定删除后重跑，以及多科目同客商场景。

## 五、静态检查边界

本次仅读取并分析上述一个存储过程文件。未读取数据库元数据，因此没有对字段实际存在性、字段类型、唯一键约束或 `FORM_DATI` 比例字段的真实含义作数据库级确认；涉及这些内容的结论已在“需要用户确认的业务规则”中单独标出。未修改任何 SQL 或其他文件，也未执行数据库操作。
