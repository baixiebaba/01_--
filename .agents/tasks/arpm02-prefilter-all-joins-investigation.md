# ARPM02 全过程关联与来源查询前置过滤检查报告

## 总结结论

1. 已完整静态检查目标过程 `01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_BD_M_PHASE2.sql`（915 行），覆盖初始化、STEP1、STEP2、STEP3 的全部 `MERGE`、`UPDATE`、CTE、内联视图、来源表和关联。
2. 目标 SQL 当前工作区不是基线状态：`git status` 显示该文件已有未提交修改，差异主要包括 STEP2 个别认定的 `T0/A` 场景、期间、公司、业务类型前置，以及 `INDIVIDUAL_DATA` 的公司范围过滤。本报告只读检查，没有修改该文件，也没有创建提交。
3. 用户最近指定的 `AW_MR9_ARPM02_000001` / `AW_MR9_ARPM01_000001` STEP2 个别认定关联目前已经采用两侧内联视图前置过滤（目标 SQL 第 286–320 行）；STEP1 的垫资、返利、投保聚合和 STEP3 的主要来源 CTE 也已经有场景、期间、公司或月份过滤。
4. 仍值得确认的优化优先级：
   - P1：STEP1 将当前期间 `AW_MR9_ARPM02_000001 A` 也改成显式内联视图/CTE，并考虑将 `AW_MR9_ARPM01_000001` 的垫资和返利两次扫描合并成一次条件聚合；这属于高数据量路径，但需先确认 `NULL` 连接键和现有聚合口径。
   - P1：STEP2 配置表 `AW_RUL_ARPBDR_000001 R` 将有效期及批次条件放进独立来源内联视图/CTE，再与 `CALCULATION_SOURCE` 关联；现有写法语义上已由内连接保证等价，但显式前置可减少进入匹配表达式的数据。
   - P2：STEP3 对 `SESSION_AZIENDA_LIST` 的反复标量/集合子查询统一为一次会话公司来源 CTE（或在各来源 CTE 中继续保留现状），属于可读性和重复访问优化，预计收益取决于 Oracle 优化器与临时表统计信息。
5. 当前没有发现明显的笛卡尔连接：所有显式 JOIN 都有业务键；但配置表、个别认定来源和规则来源的多行性仍必须依靠聚合或 `ROW_NUMBER()` 控制，否则会造成金额放大。现有 STEP2 个别认定通过分组、配置通过 `ROW_NUMBER()`，STEP1 通过来源聚合，STEP3 通过键级聚合降低了该风险。
6. 本检查不能通过 Oracle 数据库执行计划、实际行数、索引/分区信息或运行耗时验证。以下影响是基于 SQL 结构的静态判断；上线前必须在测试库用实际参数比较 `DBMS_XPLAN`、来源行数、MERGE 源唯一性和结果金额。

## 证据与全量来源/关联清单

### 初始化和会话范围（过程第 54–105 行）

| 位置/符号 | 来源或目标 | 关联/过滤说明 |
|---|---|---|
| 54–57 | `SESSION_AZIENDA_LIST`、`SESSION_V_REF_AZIENDA` | 按 `SESSION_ID` 清理当前会话数据；这是过程副作用，不是业务 JOIN。 |
| 59–63 | `TGK_FIMA_HISENSE.V_REF_AZIENDA` → `SESSION_V_REF_AZIENDA` | 全量复制 `HIE/NODE/ELEM`，未按层级预过滤；后续按 `HIE/NODE` 使用。 |
| 65–90 | `SESSION_V_REF_AZIENDA`、`AW_RUL_DWMCRS_000001` | 生成公司清单；输入公司/节点或 `ALL`，并要求 `ARP_FLAG='Y'`、`VALID_FR <= V_YEARMONTH`、`VALID_TO` 有效、`COD_CONTO='ZAW_D2M_IN'`，再排除当前场景期间的 `ZAW_D2M_LOCK` 公司。两个规则子查询均已在自身 WHERE 中过滤。 |
| 93–98 | `SESSION_AZIENDA_LIST` | `LISTAGG` 生成日志用公司字符串。 |
| 99–105 | `ZTAB_CPM_LOG` | BEGIN 日志写入，不参与业务关联。 |

### STEP1：坏账计提基数（过程第 110–267 行）

| 符号/位置 | 来源表或 CTE | JOIN 类型与粒度 | 现有过滤/风险 |
|---|---|---|---|
| MERGE 第 111 行 | 目标 `AW_MR9_ARPM02_000001 T` | `ON T.OID=S.OID` | 目标只回写匹配行；源端最终应保证每个 OID 唯一。 |
| `BASE_DATA` 第 116–156 行 | `AW_MR9_ARPM02_000001 A` | 左连接 D、R、I | A 在 CTE 的 WHERE 中按当前 `COD_SCENARIO`、`COD_PERIODO`、会话公司过滤；字段粒度为目标明细 OID、公司、客户、科目、目的地。可进一步把 A 改成显式内联视图，以符合用户要求的“各表先过滤再 JOIN”。 |
| D 第 128–136 行 | `AW_MR9_ARPM01_000001` | `LEFT JOIN`，按公司+科目+客户+`COD_DEST2` 回接；先聚合 | 已按当前场景、期间、公司、`COD_CATEGORIA='ZFAMOUNT'`、`D_ADJ_TYPE='ARP_02_001'` 前置过滤并按业务键 SUM，来源一行/键，避免放大。 |
| R 第 137–145 行 | `AW_MR9_ARPM01_000001` | `LEFT JOIN`，同 D | 已按当前场景、期间、公司、`ZFAMOUNT`、`ARP_02_003` 前置并聚合。与 D 对同一物理表重复扫描，是 STEP1 的主要静态性能候选。 |
| I 第 146–153 行 | `AW_MR6_ARPINS_000001` | `LEFT JOIN`，公司+科目+客户；`MAX` 聚合 | 已按当前场景、期间、公司过滤并按公司+科目+客户聚合。由于业务键未包含 `COD_DEST2`，这是当前设计的投保匹配粒度，不能仅以性能名义增加连接列。 |
| `AGE_UNPIVOT` 第 158–166 行 | `BASE_DATA` | CTE 展开 15 个账龄列 | 无表 JOIN；会将每个目标明细扩成 15 行，属于算法必需的行数放大，不是笛卡尔 JOIN。 |
| `AGE_PROGRESS`、`DEDUCTED_AGE`、`AGE_SUMMARY` 第 169–186 行 | 前序 CTE | 窗口计算 | `AGE_PROGRESS` 按 `OID,COD_CONTO` 计算 FIFO，`AGE_SUMMARY` 按 `COD_AZIENDA,CUST_CODE,COD_CONTO` 计算负数总额；粒度不同，需业务确认是否是有意设计。 |
| `AGE_TOTAL`、`AGE_FIFO_TOTAL` 第 188–203 行 | 前序 CTE | 公司+客户+科目+账龄聚合/窗口 | 先聚合账龄，避免同账龄多明细行重复参与 FIFO。 |
| `AGE_FIFO` 第 206–214 行 | `AGE_SUMMARY` + `AGE_FIFO_TOTAL` | 内连接，完整公司+客户+科目+账龄键 | 两侧粒度一致，理论上不放大；若 NULL 业务键需要被视为相等，当前 `=` 不会匹配，这是现有语义而非本次性能修改可擅自改变。 |
| `BASE_RESULT` 第 222–240 行 | `AGE_ALLOCATED` | OID+科目聚合 | 最终源按 OID、科目聚合后供 MERGE；若 OID 在表内不是唯一标识，`ON T.OID=S.OID` 仍有源/目标不唯一风险。 |

### STEP2：坏账计算（过程第 269–507 行）

| 符号/位置 | 来源表或 CTE | JOIN 类型与粒度 | 现有过滤/风险 |
|---|---|---|---|
| 清零 UPDATE 第 270–277 行 | `AW_MR9_ARPM02_000001` | 直接更新 | 已按当前场景、期间、会话公司清零 SPID 0–15；这是保证无来源时不沿用旧值的业务逻辑，不应改成仅更新有来源行。 |
| 个别认定 MERGE 第 278–344 行 | 目标 `AW_MR9_ARPM02_000001 T` | `ON T.OID=S.OID` | 源在第 286–298 行先筛目标表当前场景、期间、公司；第 300–318 行先筛 `AW_MR9_ARPM01_000001` 当前场景、期间、公司、`ZFAMOUNT`、`ARP_02_002`，再按场景+期间+公司+客户+目的地+科目+性质 JOIN。第 320–321 行按 OID、科目聚合。此次用户要求的两个表关联已完成显式前置。 |
| `CALCULATION_SOURCE` 第 350–362 行 | `AW_MR9_ARPM02_000001 A` | 当前期间目标源 | 已按场景、期间、公司前置，并保留 `A.*`；可进一步只选实际使用字段，减少宽行传递，但属于次要收益且需要逐字段核对。 |
| `FORM_RATE_SOURCE` 第 365–402 行 | `TGK_FIMA_HISENSE.AW_RUL_ARPBDR_000001 R` + `CALCULATION_SOURCE A` | 内连接；规则按 A.OID+科目 `ROW_NUMBER()` 去重 | R 与 A 按公司、科目、`SUBSTR(GRP_SCOPE,1,3)` 匹配；BATCH 1=公司+客商，BATCH 2=公司+性质，BATCH 3=公司级通用；有效期在 JOIN 后 WHERE，批次在 JOIN 后 WHERE。因为这是 INNER JOIN，且条件只引用 R，搬进 R 的内联来源视图在语义上安全；必须保留前三位截取、用户确认的优先级 1>2>3、`COD_CONTO` 和 `COD_AZIENDA` 匹配。当前规则表可能有多个有效重叠配置，`ROW_NUMBER()` 是防止配置放大所必需的。 |
| `FORM_RATE_SELECTED` 第 404–414 行 | `FORM_RATE_SOURCE` | OID+科目唯一候选 | 只是投影，没有新来源或过滤。 |
| `CALCULATION_BASE` 第 417–455 行 | `CALCULATION_SOURCE A` | 左连接 `INDIVIDUAL_DATA`，左连接 `FORM_RATE_SELECTED` | A 已前置；个别认定聚合在第 432–451 行按当前场景、期间、公司、`ZFAMOUNT`、`ARP_02_002` 过滤，并按公司+科目+客户+目的地+性质聚合；规则配置已经在上游去重。左连接必须保留，因为无个别认定/无配置时仍需计算普通坏账或使用比例 0。 |
| `BAD_DEBT_CALCULATION` 第 458–480 行 | `CALCULATION_BASE` | 无表 JOIN | 按个别认定存在性决定采用个别金额还是账龄基数×比例；无 10–15 比例时非个别认定按设计为 0。 |
| STEP2 外层 SELECT 第 482–507 行 | `BAD_DEBT_CALCULATION` | 无表 JOIN | 统一 `ROUND(...,2)`，包括各账龄和总额；ROUND 放在结果选择层，不应为性能检查移回基础计算层。 |

### STEP3：坏账分摊及本月坏账发生额（过程第 509–829 行）

| 符号/位置 | 来源表或 CTE | JOIN 类型与粒度 | 现有过滤/风险 |
|---|---|---|---|
| `BASE_DATA` 第 514–537 行 | `AW_MR9_ARPM02_000001 A` | STEP3 当前期间目标源 | 已按场景、期间、会话公司前置；只选实际使用字段。 |
| `INDIVIDUAL_KEYS` 第 539–555 行 | `AW_MR9_ARPM01_000001 I` | 后续 LEFT JOIN 的存在性键 | 已按当前场景、期间、`ZFAMOUNT`、`ARP_02_002`、公司过滤，按公司+客户+目的地+科目+性质去重；只用于 HAS_INDIVIDUAL，保留左连接语义。 |
| `KEY_TOTAL` 第 557–580 行 | `BASE_DATA` | 公司+客户+科目聚合 | 同一次 BASE_DATA 扫描汇总正数总额和负数各账龄金额，避免重复来源扫描。是否应含 `COD_DEST2`/性质由当前“公司+客户+科目”分摊设计决定，不应在性能修改中擅自改变。 |
| `ALLOCATION_DATA` 第 583–599 行 | BASE_DATA + INDIVIDUAL_KEYS + KEY_TOTAL | 两个 LEFT JOIN | 连接键分别为个别认定完整键、KEY_TOTAL 的公司+客户+科目；来源均已唯一化/聚合，暂无笛卡尔放大证据。缺失个别认定和汇总时通过 `CASE/NVL` 保持 0。 |
| `WRITEOFF_DATA` 第 601–622 行 | `DWD_FI_MR_ARAP_SUM_MI` | 独立聚合来源 | 已按 `DT_MONTH=V_YEARMONTH`、`ODS_SRC='WRITEOFF'`、会话公司过滤，按公司、科目、客户、利润中心、销售部门汇总。后续为 LEFT JOIN，保留无核销数据的目标行。 |
| `LAST_MONTH_DATA` 第 624–638 行 | `AW_MR9_ARPM02_000001` | 独立聚合来源 | 按上月场景、上月期间、会话公司过滤，按公司+科目+客户+利润中心汇总；后续 LEFT JOIN。上月参数由当前场景/期间推导，不能替换为当前期间。 |
| `CALCULATION_RESULT` 第 641–744 行 | ALLOCATION_DATA + LAST_MONTH_DATA + WRITEOFF_DATA | 两个 LEFT JOIN | 上月按公司+科目+客户+利润中心连接；核销再加销售部门。来源均先聚合，连接键与业务粒度一致。过滤条件若移到外层 WHERE 会把 LEFT JOIN 变成 INNER JOIN，不得这样改。 |
| `SESSION_V_REF_AZIENDA` 第 681–725 行附近 | 组合判定中的多个 IN 子查询 | 相关集合判断 | 通过 `SESSION_ID`、`HIE`、`NODE` 判断公司和对方公司分组；这些条件是 `CASE` 业务判定，不是可随意放到来源表 WHERE 的 JOIN 过滤。可在后续确认后用一次分类 CTE 减少重复读取，但需验证重叠层级和 `CASE` 优先顺序。 |
| STEP3 外层 SELECT 第 748–829 行 | `CALCULATION_RESULT` | 无表 JOIN | 统一计算 AGE_ALLOC_0、BD_AFAL_0、MTD_BD_PROV_OCUR_AMT 后回写。 |

## 可优化候选、具体前置条件和预计影响

### P1：STEP1 当前目标表 A 显式内联过滤

当前写法是 `BASE_DATA` 第 116–127 行直接 `FROM AW_MR9_ARPM02_000001 A`，过滤位于三个左连接之后的 WHERE（第 154 行）。建议改成：

- `FROM (SELECT ... FROM AW_MR9_ARPM02_000001 WHERE COD_SCENARIO=V_SCENARIO AND COD_PERIODO=V_PERIODO AND COD_AZIENDA IN (会话公司)) A`；
- 保持 D、R、I 为 LEFT JOIN，保持它们各自来源内的场景、期间、公司、业务类型过滤；
- 不把任何 D/R/I 缺失判断放入外层 WHERE。

这是显式表达“先缩小目标数据再关联”，预计可降低连接、UNPIVOT 和窗口函数的输入行数；Oracle 可能已自动谓词下推，因此真实收益必须用执行计划验证。该改动语义上安全，前提是只把 A 自身过滤放入 A 来源。

### P1：STEP1 合并 ARPM01 的 D/R 两次扫描

当前 D（`ARP_02_001`）和 R（`ARP_02_003`）分别扫描 `AW_MR9_ARPM01_000001`、分别聚合，再 LEFT JOIN。可在同一个内联来源中保留当前场景、期间、公司、`COD_CATEGORIA='ZFAMOUNT'`，并用：

- `SUM(CASE WHEN D_ADJ_TYPE='ARP_02_001' THEN BCY_0_AMT ELSE 0 END)`；
- `SUM(CASE WHEN D_ADJ_TYPE='ARP_02_003' THEN BCY_0_AMT ELSE 0 END)`；
- `WHERE D_ADJ_TYPE IN ('ARP_02_001','ARP_02_003')`；
- 按当前 D/R 两个连接键 `COD_AZIENDA,COD_CONTO,CUST_CODE,COD_DEST2` 聚合。

这样可把两次大表扫描/聚合压缩为一次，预计收益高于单纯改写内联视图。需用户确认 `BCY_0_AMT` 为 NULL 时的 SUM/NVL 行为、同一键同时出现两类调整时的结果，以及是否保留“来源无行”和“来源有行但金额为 NULL”的区别；确认后再实施。

### P1：STEP2 规则表有效期/批次过滤前置

`FORM_RATE_SOURCE` 第 379–402 行当前直接 JOIN 规则表，再在外层 WHERE 筛选 `VALID_FR`、`VALID_TO`、`BATCH_ID`。建议新增规则来源内联视图/CTE：

- `VALID_FR <= V_YEARMONTH`；
- `NVL(VALID_TO,'999999') >= V_YEARMONTH`；
- `BATCH_ID IN (1,2,3)`；
- 仅投影匹配和比例/排序所需字段。

这是 INNER JOIN 且条件只引用规则侧，语义等价，能减少进入 `SUBSTR(GRP_SCOPE)`、客商/性质 OR 匹配及 `ROW_NUMBER()` 的规则行。不能删除 `R.CUST_CODE IS NOT NULL/IS NULL`、`R.NATURE_L3_NAME IS NOT NULL/IS NULL`，因为它们定义三档优先级。

### P2：STEP2/STEP3 缩窄宽行和统一会话公司来源

`CALCULATION_SOURCE` 已按场景、期间、公司过滤但使用 `A.*`；可改为明确字段清单，减少后续 CTE 的宽行传输。STEP1/STEP2/STEP3 多处重复读取 `SESSION_AZIENDA_LIST WHERE SESSION_ID=V_SESSION_ID`，可确认 Oracle 临时表访问计划后决定是否抽成一次 CTE。预计收益中低，且 Oracle 可能已做子查询缓存/半连接转换，不应在未看计划前优先改写。

### P2：初始化 `V_REF_AZIENDA` 复制范围

第 59–63 行将 `V_REF_AZIENDA` 全量复制到会话表，而 STEP3 只使用若干 `HIE/NODE`，STEP1/2 使用 HIE=10 的公司范围。可考虑只装载本过程需要的层级，但这是会话范围初始化逻辑，涉及 `P_AZIENDA='ALL'`、节点展开和后续组合判断；需业务确认完整层级是否还会被其他判断隐式依赖，不建议和关联前置优化混合实施。

## 外连接与语义敏感条件：不建议直接搬动

1. `BASE_DATA` 对 D、R、I 的 `LEFT JOIN` 必须保留。来源侧仅有来源自身的场景、期间、公司、类别、调整类型过滤，放入各来源内联视图安全；若把“来源存在/金额非零”等条件放到外层 WHERE，会丢失目标行并改变 `NVL(...,0)` 结果。
2. STEP2 `INDIVIDUAL_DATA` 是 LEFT JOIN。无个别认定时 `HAS_INDIVIDUAL=0`，必须继续走比例计算；不能改 INNER JOIN，也不能仅因为来源表有当前批次过滤就删掉目标清零 UPDATE。
3. STEP2 `FORM_RATE_SELECTED` 是 LEFT JOIN。无配置时比例按 `NVL(...,0)` 处理；不得把配置匹配改为 INNER JOIN。规则表的有效期/批次条件可以前置到规则来源，因为它们只引用 R，但匹配 OR、三档优先级和 `ROW_NUMBER()` 不能删除。
4. STEP3 `ALLOCATION_DATA` 中 `INDIVIDUAL_KEYS`、`KEY_TOTAL` 均为 LEFT JOIN。它们的缺失值分别表示非个别认定和无可分摊汇总，不能用 WHERE 过滤掉。
5. STEP3 `LAST_MONTH_DATA` 与 `WRITEOFF_DATA` 必须保持 LEFT JOIN。上月无记录或当月无核销时要得到 0；把来源过滤写在最终 WHERE 会变成 INNER JOIN。来源内部的月份、ODS_SRC、公司过滤可以保留在来源 CTE。
6. `SESSION_V_REF_AZIENDA` 的 `IN` 子查询位于 `CASE` 分支中，存在分支顺序语义：`HIE='01', NODE='2910'`、`2000` 及对方公司 `2000B`、`1000` 的判定不能仅按性能重排或合并，必须验证集合重叠时原 CASE 结果。
7. 所有关联使用普通 `=`。客户、性质、目的地等字段为空时不会匹配；用户已说明 `CUST_CODE` 为空可能走其他优先级，但这只适用于规则表的 BATCH 逻辑，不能泛化为对所有 JOIN 使用 `NVL`，否则会改变 NULL 连接语义并可能放大结果。
8. `SUBSTR(GRP_SCOPE,1,3)` 是用户明确要求参与匹配的条件。可以在规则来源增加预计算/筛选字段，但不能取消前三位截取或改成全值匹配。

## 重复扫描、粒度和放大检查结论

- `AW_MR9_ARPM01_000001` 在 STEP1 D/R 两个来源各扫描一次，在 STEP2 个别认定聚合、STEP2 `INDIVIDUAL_DATA`、STEP3 `INDIVIDUAL_KEYS` 分别再次读取。STEP2 与 STEP3 的读取用途不同（金额聚合 vs 存在性），不能无条件合并；STEP1 D/R 可以优先评估合并。
- `AW_MR9_ARPM02_000001` 在 STEP1 当前行、STEP2 清零/个别认定/计算来源、STEP3 当前数据/上月数据中多次读取，这是跨步骤业务必需的重复；由于每一步有不同期间和计算状态，不建议为性能强行合并。
- `SESSION_AZIENDA_LIST` 在多个来源反复作为 `IN` 子查询访问；可能由 Oracle 转为半连接，但应通过执行计划确认。
- `AW_RUL_ARPBDR_000001` 规则表可能一对多，当前 `ROW_NUMBER() OVER (PARTITION BY A.OID,A.COD_CONTO)` 控制为最高优先级候选。若修改分区键，可能恢复金额/配置多行放大，必须保持该粒度，除非业务确认 OID+科目不是唯一配置粒度。
- STEP2 个别认定按 OID、科目聚合，JOIN 键含场景、期间、公司、客户、目的地、科目、性质；STEP2 `INDIVIDUAL_DATA` 按公司、科目、客户、目的地、性质聚合，连接到当前期间 A，结构上可避免一对多。
- STEP3 `KEY_TOTAL` 是公司+客户+科目级，`WRITEOFF_DATA` 是公司+科目+客户+利润中心+销售部门级，`LAST_MONTH_DATA` 是公司+科目+客户+利润中心级；来源粒度与后续连接键一致。仍需数据库数据检查每个来源的连接键确实唯一。
- 未静态发现无连接条件的显式业务表 JOIN。CTE 链中的 `UNPIVOT` 和窗口函数造成的行数变化属于算法处理，不是笛卡尔连接。

## 待用户确认的修改范围和优先级

建议先确认以下范围，再进行任何 SQL 修改：

1. **P1 必改候选**：仅修改 STEP1 `BASE_DATA` 的目标表 A 为显式预过滤内联视图；不改变三个 LEFT JOIN 及其业务键。
2. **P1 性能候选**：是否允许将 STEP1 D/R 两个 `AW_MR9_ARPM01_000001` 聚合合并一次扫描。确认金额 NULL、同键双类型和无来源行的预期结果。
3. **P1 可安全候选**：是否将 STEP2 `AW_RUL_ARPBDR_000001` 的有效期和 BATCH 条件移入规则内联来源，同时保留优先级 1>2>3、`COD_AZIENDA`、`COD_CONTO`、`SUBSTR(GRP_SCOPE,1,3)`、CUST_CODE/NATURE 条件。
4. **P2 可选**：是否将 STEP2 `CALCULATION_SOURCE A.*` 缩窄为字段清单，以及是否统一会话公司来源；这两项需以执行计划/统计信息为依据。
5. **暂不修改**：外连接的来源缺失语义、STEP3 上月/核销过滤位置、组合判定 `CASE`、NULL 连接规则和 `KEY_TOTAL` 的业务粒度，除非用户提供明确业务确认。

## 静态验证结果和限制

- 已读取目标 SQL 全文并按 STEP1、STEP2、STEP3 对 `MERGE INTO`、`UPDATE`、CTE、内联视图、JOIN、聚合、窗口函数、来源过滤逐项核对。
- 已检查当前 Git 状态：目标 SQL 存在未提交改动；报告文件是本次唯一新增调查产物，未修改目标 SQL、未提交、未重启服务。
- 仓库中未找到 `README`、`AGENTS.md`、`CONTRIBUTING.md` 或可用于本 SQL 的构建/测试命令，因此本调查没有可执行的项目级 SQL 单元测试命令。
- 未连接 Oracle，无法验证语法编译、`EXPLAIN PLAN`/`DBMS_XPLAN.DISPLAY_CURSOR`、实际访问路径、索引/分区命中、CTE 合并/物化行为、来源键唯一性和运行耗时。
- 后续实施前建议在测试库固定同一 `P_SCENARIO/P_PERIODO/P_AZIENDA`，分别记录：每个来源过滤前后行数、各聚合键重复数、每个 MERGE 源 OID 重复数、结果金额差异，以及执行计划的连接顺序/访问路径；确认结果等价后再提交 SQL 变更。
