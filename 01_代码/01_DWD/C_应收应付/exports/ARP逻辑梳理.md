# ARP 往来账龄 —— 全链路逻辑梳理（对数/排查用）

> 目的：把 M01→M02→坏账→投保→周转 每个字段的**取数口径 + 存储过程行号**理出来。
> 对数发现差异时，按本文定位到具体过程/行，再看是否需要改。
>
> 代码位置：`01_代码/02_DWM/C_应收应付/`（DWM 层）、`01_代码/03_DWS/C_应收应付/`（DWS 层）
> 生成时间：2026-10-16

---

## 一、整体链路

```
DWD 层
  DWD_FI_MR_ARAP_SUM_MI ─┐
  AW_MR9_REVM01_000001  ─┴─► CPM_SP_D2M_ARP_M_PHASE2  ──► AW_MR9_ARPM01_000001   (M01 底稿)
                                     │
                                     ▼
                            CPM_SP_M2M_ARP_AG_M_PHASE2 ──► AW_MR9_ARPM02_000001  (M02 结果表)
                                     │                              ▲
       AW_MR6_ARPINS_000001 ─────────┼─► CPM_SP_M2M_ARP_INS_M_PHASE2┘ (投保：更新账龄/未覆盖比例)
                                     │
                                     ▼
                            CPM_SP_M2M_ARP_BD_M_PHASE2 ──►（回写 ARPM02：BD_BASE/BD/SPID/BD_AFAL）
                                     │
   DWD_FI_MR_AR_IMOCC_MI / REVM01 / CPRS01
                                     ▼
                            CPM_SP_M2S_ARP_TOV_M_PHASE2 ──► AW_MR8_ARPS01_000001 (S 层周转)
```

| 环节 | 存储过程 | 源表 | 目标表 | 文件行数 |
|---|---|---|---|---|
| M01 | `CPM_SP_D2M_ARP_M_PHASE2` | DWD_FI_MR_ARAP_SUM_MI、AW_MR9_REVM01_000001 | AW_MR9_ARPM01_000001 | 965 |
| M02 | `CPM_SP_M2M_ARP_AG_M_PHASE2` | ARPM01、ARPM02(历史)、DATI_CAMBIO、SQF_TEST | AW_MR9_ARPM02_000001 | 1662 |
| 坏账 | `CPM_SP_M2M_ARP_BD_M_PHASE2` | ARPM01、ARPM02、ARPINS、AW_RUL_ARPBDR_000001、DWD_FI_MR_ARAP_SUM_MI | AW_MR9_ARPM02_000001 | 986 |
| 投保 | `CPM_SP_M2M_ARP_INS_M_PHASE2` | AW_MR6_ARPINS_000001、ARPM02、DATI_CAMBIO | AW_MR6_ARPINS_000001 | 294 |
| 周转 | `CPM_SP_M2S_ARP_TOV_M_PHASE2` | ARPM02、DWD_FI_MR_AR_IMOCC_MI、REVM01、AW_MR8_CPRS01_000001 | AW_MR8_ARPS01_000001 | 1048 |

**执行顺序**：M01 → M02 → （坏账 BD、投保 INS 可穿插）→ TOV。BD 依赖 M02 已生成（BCY_ADJ_INCL_*）、INS 依赖 M02（AR 账龄）。

---

## 二、公共机制（所有过程一致，对数先查这里）

### 1. 时间参数

| 变量 | 口径 | 说明 |
|---|---|---|
| `V_SCENARIO` | =入参场景（如 `2026ACT`） | |
| `V_PERIODO` | =`LPAD(期间,2,'0')` | 如 `08` |
| `V_YEARMONTH` | `SUBSTR(场景,1,4) || 期间` | 如 `202608` |
| `V_LAST_DAY` | 当月最后一天 | |
| `V_PREV_YEARMONTH` | `ADD_MONTHS(-1)` | 上月 |

**M02 专有的历史期间口径**（`CPM_SP_M2M_ARP_AG_M_PHASE2` L74-79）：
- `V_BY_SCENARIO` = 上年场景（年份-1 + 后缀），`V_BY_PERIODO` = **固定 '12'**
- `V_LM_SCENARIO` / `V_LM_PERIODO` = **自然上月**场景/期间

### 2. 公司范围（最容易造成"总数对不上"的地方）

统一逻辑（M01 L55-81、M02 L82-107、BD L69-93、INS L57-83、TOV L44-79）：

```
SESSION_V_REF_AZIENDA ← TGK_FIMA_HISENSE.V_REF_AZIENDA（全量公司树快照）
SESSION_AZIENDA_LIST  ← HIE='10' 且命中入参公司/节点 或 入参='ALL'
                        AND ELEM IN (AW_RUL_DWMCRS_000001 WHERE COD_CONTO='ZAW_D2M_IN' 有效期命中)
                        AND ELEM NOT IN (AW_RUL_DWMCRS_000001 WHERE COD_CONTO='ZAW_D2M_LOCK' 且 场景+期间命中)
```

| 过程 | 差异 |
|---|---|
| M01 / M02 / BD / INS | 只看 `ZAW_D2M_IN`（进数范围）+ 排除 `ZAW_D2M_LOCK`（锁定公司） |
| **TOV** | 额外叠加 `AW_RUL_ATSMAP_000001` 的 **BG（事业部）过滤** |

> ⚠️ **对数要点**：同一公司编号，M02 有数、TOV 没数（或反之），先查 `AW_RUL_DWMCRS_000001` 的 `ZAW_D2M_IN/LOCK` 与 `AW_RUL_ATSMAP_000001` 的 BG 映射。

### 3. 重跑/删除策略 & OID

| 过程 | 删除范围 | OID 策略 |
|---|---|---|
| M01 | `AW_MR9_ARPM01` where 场景+期间+本次公司 + `PROVENIENZA='CPM_SP_D2M_ARP_M_PHASE2'`（L100-109） | 全表 `NEWID()` 新生成 |
| M02 | `AW_MR9_ARPM02` where 场景+期间+本次公司 + `PROVENIENZA='CPM_SP_M2M_ARP_AG_M_PHASE2'`（L128-136） | **优先复用界面行 OID**：按 场景+期间+公司+科目+客商+利润中心 匹配 `PROVENIENZA='INPUT_DEFORM'` 行，命中则 UPDATE，否则 INSERT（L1227-1278） |
| BD | 不删除（只 UPDATE 回写），`PROVENIENZA` 不更新 | 按 `T.OID = S.OID` MERGE |
| INS | **测试用**：`DELETE FROM AW_MR6_ARPINS_000001`（全表！）后从 `TGK_FIMA_HISENSE.AW_MR6_ARPINS_000001` 全量复制（L102-106）→ **上线前必须去掉** | — |

> ⚠️ **对数要点**：M02 的 `INPUT_DEFORM` 界面人工行会被保留并复用 OID，如果对数时发现某行金额"非过程算出"，查该行 `PROVENIENZA` 是否为 `INPUT_DEFORM`。

### 4. 日志

所有过程写 `ZTAB_CPM_LOG`（CPM/STEP/EXECTIME/CREATEBY/场景/期间/公司），排查"哪一步挂了"直接查这张表。
`SESSION_*` 临时表在结束前清理（M02/BD 有 EXCEPTION 块，M01 的 EXCEPTION 被注释掉了 L948-965）。

---

## 三、M01（D2M）—— AW_MR9_ARPM01_000001

### 3.1 两组来源 UNION ALL（L198-390）

**包 A：DWD_STANDARD**（L200-320，`SYSTEM_SRC` = 源表自带值）
- 源：`DWD_FI_MR_ARAP_SUM_MI`
- 过滤：`DT_MONTH = V_YEARMONTH`、`NVL(IS_APAR_FLAG,'Y')='Y'`、公司 ∈ SESSION_AZIENDA_LIST
- 字段直接映射；**`COD_CATEGORIA` 固定 `'ZAMOUNT'`**；`D_ADJ_TYPE` 固定 `'ZZZZ'`

**包 B：M01_FACT**（L322-390，`SYSTEM_SRC = 'TA'`）
- 源：`AW_MR9_REVM01_000001`，只取 `COD_CONTO LIKE 'S600101%'` 或 `'S600102%'`
- `S600101%` → `SRC_DETAIL='ZTSO04_CK'`（出库未开）；`S600102%` → `'ZTSO04_TH'`（退货未办）
- **科目固定** ASRC/REC/MAP = `1122000000`
- `BCY_0_AMT` 和 `BCY_1_AMT` 都 = `BCY_REV`；`QCY_0_AMT`/`QCY_1_AMT` 都 = `ORG_REV`（即落 0/1 两个桶，L365-373）

### 3.2 聚合（L391-480）

按业务键 GROUP BY + SUM 所有 BCY_x/QCY_x。业务键：
`场景,期间,公司,类别,SRC_DETAIL,客商编码/名称,主户编码/名称,分户编码/名称,对方公司,国家编码/名称,ACCT_SRC_CODE,ACCT_REC_CODE,ACCT_MAP_CODE,三个账龄标识,GRP_SCOPE,D_CHANNEL,D_TOV_CHAN,D_CC_CUSTGRP,D_ONOFFLINE,COD_DEST2,COD_DEST3,D_SALE_DEPT,NATURE_L1/2/3,UFEE_UREB_FLAG,ECLS_FLAG,PAY_TERM_CODE/DESC,EXCHANGE_RATE_EVAL_FLAG,TAX_RATE,COD_VALUTA,COD_VALUTA_ORIGINARIA,SYSTEM_SRC,D_ADJ_TYPE`

### 3.3 科目映射 `ACCT_REC_CODE`（L216-253）—— 重要

由 `ACCT_SRC_CODE`（原始科目）按 CASE 映射。主要规则（左→右）：

| 条件 | 映射结果 |
|---|---|
| `ACCT_SRC_CODE LIKE '1466%'` | `1466000000` |
| 公司∈{6500,6510} 且 src∈{2241010100,2241010200,2241020000,2241040000} | `2241010100` |
| 公司∈{6500,6510} 且 src∈{1221010000,1221020000,1221040000} | `1221010000` |
| 公司∈{1007,1008,1041} 且 src LIKE '2202%' | `2202000000` |
| 公司 LIKE '66%'（≠6600）且 src LIKE '1131%'（≠1131999001） | `1131002000` |
| 公司 LIKE '66%'（≠6600）且 src LIKE '1133%'（≠1133999001） | `1133001003` |
| 公司 LIKE '66%'（≠6600）且 src LIKE '2181%'（≠2181999001） | `2181001005` |
| 公司 LIKE '66%'（≠6600）且 src LIKE '2121%'（≠2121999001） | `2121001000` |
| 公司∈{6000,6000A,6000B,6000C,6600} 且 src LIKE '1131%' | `1131002000` |
| 公司∈{6000…,6600} 且 src LIKE '1133%' | `1133001003` |
| 公司∈{6000…,6600} 且 src LIKE '2181%' | `2181001005` |
| 公司∈{6000…,6600} 且 src LIKE '2121%' | `2121001000` |
| 公司 LIKE '16%'（∉163%,162%）且 src∈{2202000000,2202000089} | `2202000000` |
| 其他 | 原样 `ACCT_SRC_CODE` |

### 3.4 重分类/账龄标识/集团归属（MERGE，L565-911）

**Step 1 — 三个开窗汇总金额（L610-658）**

| 字段 | PARTITION BY | 含哪些 SRC_DETAIL |
|---|---|---|
| `LE_BCY_AMT` | SYSTEM_SRC + 公司(6000系并表) + 主户 + ACCT_REC_CODE | 仅 `ORG%` |
| `ME_BCY_AMT` | 同上 | `ORG%` + `ZTSO04%` |
| `MB_BCY_AMT` | 同上 + **COD_DEST2** | `ORG%` + `ZTSO04%` |

> 公司并表：公司∈{6000,6000A,6000B,6000C,6600} 且 ACCT_REC_CODE∈{1131002000,1133001003,2181001005,2121001000} 时统一按 `6000` 分组（L618-622）。

**Step 2 — 调用重分类函数 `F_APAR_REC`（L691-786）**

`TGK_GB_HISENSE.F_APAR_REC(年月份, MANDT, 公司, ACCT_REC_CODE, 主户编码, 汇总金额, 模式)`
- 模式 `'1'` → 返回**是否重分类** → `IS_REC_LG` / `IS_REC_ME` / `IS_REC_MB`
- 模式 `'2'` → 返回**账龄标识** → `LE_AGE_FLAG` / `ME_AGE_FLAG` / `MB_AGE_FLAG`
- `SRC_DETAIL LIKE '%XH%'` 时不做重分类：`IS_REC_*= 'N'`，账龄标识按科目硬编（`1122000095`→`AR`，`2202000095`→`AP`）（L693-695, 707-710）

**Step 3 — 集团归属 `GRP_SCOPE`（L789-877，NODE_MAP = `V_APAR_ELEM_NODE_TAB`）**

| 条件 | 结果 |
|---|---|
| 本方节点 = 对方节点 且 HQ 相同 | `SUB-子公司` |
| HQ 相同 | `GIN-集团内` |
| 其他 | `GEX-集团外` |

日立公司（HIE=30 且 NODE=1730）特殊：本方/对方节点优先取 `NODES`，为空回退 `NODE`（L795-798, 860-862）。

**Step 4 — `COD_CONTO` 由 `LE_AGE_FLAG` 映射（L890-902）**

| 账龄标识 | COD_CONTO | 含义 |
|---|---|---|
| AR | `1122000000` | 应收账款 |
| OR | `122101F` | 其他应收 |
| AS | `1123000000` | 预付账款 |
| CA | `1460000000` | 合同资产 |
| RF | `1124001000` | 应收款项融资 |
| AP | `2202000000` | 应付账款 |
| OP | `224199F` | 其他应付 |
| AC | `2203000000` | 预收账款 |
| CL | `2204000000` | 合同负债 |
| A9 | `1910000A70` | 其他非流动性资产 |
| A10 | `1531000000` | 长期应收款 |

**Step 5 — 兜底（L913-925）**：非 ORG 来源且 `COD_CONTO` 为空 → 统一 `1122000000`。

---

## 四、M02（AG）—— AW_MR9_ARPM02_000001 ★核心

### 4.1 汇率（L152-181）

| 汇率源 | 用途 | 取值 |
|---|---|---|
| `CONVERSION_RATE` | 一般公司 | `DATI_CAMBIO`，场景=`年||'ACT'`+期间，按币种 `MAX(CAMBIO_FINALE)` |
| `TCURR_CONVERSION_RATE` | **仅 2023 公司** | `SQF_TEST`，`KURST='M'`，取上月最后一天；VND 特殊×100/×1000 |

> ⚠️ L160-161 注释：**上线前 SQF_TEST 要替换为 `DWD_FI_MR_SAP_TCURR_DD` 并加 `MANDT='600'`**。测试环境硬编码，对数时若涉 2023 公司需注意。

### 4.2 当前来源标准化（L182-309）

`CURRENT_SOURCE_BASE`：来自 ARPM01，**只取 `SRC_DETAIL LIKE 'ORG%'` 且 `NVL(LE_AGE_FLAG,'|')<>'|'`**（L307-308）。
- `COD_CONTO`：EPAY 来源且科目为空 → 强制 `1122000000`（L186-190）

`CURRENT_SOURCE` 计算各账龄 `CALC_BCY_x_AMT`（L311-484），三分支：
1. `CL`(合同负债) 且重分类 `Y` → `BCY_x * TAX_FACTOR`，其中 `TAX_FACTOR = 1/(1+税率)`（除税）
2. 非 AC/AS/CL 且有 `CONVERSION_FACTOR` → `QCY_x * CONVERSION_FACTOR`（交易币折算）
3. 其他 → 原 `BCY_x`

`CONVERSION_FACTOR`（L264-291）：仅当**汇率评估标识为空**且 交易币/本位币 均有汇率时 = BCY率 / QCY率（币种为 CNY 时取 1），保留 5 位小数。

### 4.3 补充来源（L486-532，`SUPPLEMENT_AGG`）

按 公司+科目+客商+利润中心 聚合，**只用 `BCY_0_AMT`**：

| 输出字段 | 条件 |
|---|---|
| `SHP_NINV_AMT` | `SRC_DETAIL LIKE 'ZTSO04_CK%'` |
| `RET_NTRF_AMT` | `SRC_DETAIL LIKE 'ZTSO04_TH%'` |
| `OVERDUE_AMT` | `SRC_DETAIL LIKE 'OVERDUE%'` |
| `INV_SAMPLE_AMT` | `SRC_DETAIL LIKE 'INV_SAMPLE%'` |
| `EPAY_AMT` | `SRC_DETAIL LIKE 'EPAY%'` |
| `ECLS_AMT` | `ECLS_FLAG='Y'` |
| `UREB_AMT` | `SRC_DETAIL LIKE 'UREB%'` 或 `UFEE_UREB_FLAG='UREB'` |
| `UFEE_AMT` | `UFEE_UREB_FLAG='UFEE'` |

### 4.4 业务键与聚合（L533-772）

业务键（4 个）：**公司 + 科目(COD_CONTO，=ARPM01.ACCT_REC_CODE) + 客商编码 + 利润中心**。
- `CURRENT_DIM`（L533-584）：每键取维度基准行，ORG 来源优先
- `CURRENT_SOURCE_AGG`（L587-754）：按 4 键聚合 `ORG_BCY_x`（交易币折算后的 ORG 原值）+ `CALC_BCY_x` + `CURRENCY_ACCT_DETAIL`（科目:金额\币种:金额 拼接）
- `CURRENT_AGG`（L756-772）：`CURRENT_SOURCE_AGG LEFT JOIN SUPPLEMENT_AGG`，NULL 键用 `'#'` 匹配

### 4.5 历史回接（L773-915）

| CTE | 取数 | 用途 |
|---|---|---|
| `BY_HISTORY` | 上年12月 ARPM02 的 `BCY_0_AMT` | → `BY_BCY_0_AMT`（年初余额） |
| `LM_HISTORY` | 自然上月 ARPM02 的 `BCY_0_AMT` | → `LM_BCY_0_AMT`（上月余额） |

两者都要求 `NVL(LE_AGE_FLAG,'|')<>'|'`。
`ALL_KEYS` = 当前 ∪ 补充 ∪ 年初 ∪ 上月 → **当前无数据但历史有余额的行也会输出**。
`DIM_CANDIDATE` 优先级：1 当前 / 2 年初 / 3 上月。

### 4.6 最终金额字段（`RESULT_FACT`，L1053-1224）★最关键

| 输出字段 | 公式 | 行号 |
|---|---|---|
| `BCY_0..15_AMT` | = `CALC_BCY_0..15_AMT` | L1090-1105 |
| `QCY_0..15_AMT` | = `CALC_BCY_0..15_AMT`（⚠️**交易币列直接赋成本位币计算结果**） | L1106-1121 |
| `BCY_ADJ_INCL_0` | `CL 且 IS_REC_LG='N'` → `ORG_BCY_0*(1+税率)`；否则 `ORG_BCY_0 + SHP_NINV - RET_NTRF` | L1124-1128 |
| `BCY_ADJ_INCL_1..15` | `CL 且 IS_REC_LG='N'` → `ORG_BCY_x*(1+税率)`；否则 = `ORG_BCY_x` | L1129-1188 |
| `BCY_ADJ_EXCL_0` | `ME_AGE_FLAG='CL' 且 IS_REC_ME='Y'` → `ORG_BCY_0/(1+税率) + 出库 - 退货`；`=N` → `ORG_BCY_0+出库-退货`；其他 → 同 `N` | L1189-1198 |
| `OVERDUE_0_AMT` / `OVERDUE_1_AMT` | = `OVERDUE_AMT`（段 2-9 置 NULL） | L1199-1208 |
| `TH_FX_EVAL_AMT` | = `CLOSING_RATE_BCY_AMT - POSTING_RATE_BCY_AMT` | L1219 |
| `ADJ_REB_AMT` | = `UREB_AMT - LEAST(ORG_BCY_0, UREB_AMT)` | L1221 |
| `ADJ_RET_AMT` | = `LEAST(ORG_BCY_0, RET_NTRF_AMT)` | L1222 |
| `COD_VALUTA_ORIGINARIA` | = `COD_VALUTA`（⚠️两者被赋成同一值） | L1087 |

> ⚠️ **对数要点**：
> 1. `QCY_*`（交易币列）实际等于 `BCY_*`，不是真实交易币 → 对交易币口径有疑问先看这里。
> 2. `BCY_*`（本月账龄）= 已含除税/折算的结果；`BCY_ADJ_INCL_*` 才是给坏账用的"调整后含税"基数。

### 4.7 未写字段（由其他过程或界面负责）

`DESC_CONTO1`、`D_CHANNEL_DESC`、`D_ONOFFLINE_DESC`、`COD_DEST2_DESC`、`COD_DEST3_DESC`、`D_SALE_DEPT_DESC`、`D_TOV_CHAN_DESC`、`D_CC_CUSTGRP_DESC`（描述类，报表取）、
`SPID_*`、`BD_BASE_*`、`BD_*`、`BD_AFAL_*`、`BD_ALLOC_RATIO`、`BD_PROV_METHOD`、`WRITEOFF_AMT`、`LM_BD_AFAL_0_AMT`、`AGE_ALLOC_*`、`SPC_DSV_DED_AMT`、`SPC_REB_DED_AMT`、`INS_COV_DAYS`、`INS_UNCOV_RATE`（坏账/投保过程）、
`DEAD_AMT`、`RISK_AMT`、`PAY_METHOD`、`IS_LN_AGE`、`LN_AGE_RSN`、`IS_ABN`、`IS_EXS`、`SUSP_RSN`、`CLR_MEA`、`EST_CLR_DT`、`CLR_PROG`、`RSP_PSN`、`IS_ADJ`、`ADJ_RSN`（界面录入/其他）

---

## 五、坏账 BD —— 三步（回写 ARPM02）

### STEP1 计提基数（L110-274）

- 基础：`BCY_ADJ_INCL_1_AMT ~ _15_AMT`
- 垫资/返利扣减：`SPC_DSV_DED_AMT`（ARPM01 中 `D_ADJ_TYPE='ARP_02_001'`）、`SPC_REB_DED_AMT`（`='ARP_02_003'`），**仅 `COD_CATEGORIA='ZFAMOUNT'`**（L141-151）
- 逻辑：账龄列 UNPIVOT（L166-175）→ 从**长账龄**开始 FIFO 扣减（L177-228）→ 负数按 公司+客户+科目 冲减正数、按原行正数比例回写 → `BD_BASE_1..15`
- 投保取 `MAX(INS_COV_DAYS)`、`MAX(INS_UNCOV_RATIO)`（L156-163）

### STEP2 坏账计算（L275-576）

1. **清零** 本批次 `SPID_*`（L279-286）
2. **个别认定**：若存在 `COD_CATEGORIA='ZFAMOUNT'` 且 `D_ADJ_TYPE='ARP_02_002'` 的来源 → 按 公司+客商+利润中心+科目+三级性质 聚合回写 `SPID_*`（L287-390）
3. **按规则表计算**（L401-568）：
   - 规则表 `AW_RUL_ARPBDR_000001`，`BATCH_ID IN (1,2,3)`，有效期 `VALID_FR/VALID_TO` 命中
   - 匹配优先级 = `BATCH_ID`：**1=公司+客商，2=公司+三级性质，3=公司级通用**；`SUBSTR(GRP_SCOPE,1,3)` 需一致；同一 OID 只取一条（L436-471）
   - 账龄 1-4 额外乘**投保未覆盖系数**：
     | 账龄 | INS_COV_DAYS 分段 | 系数 |
     |---|---|---|
     | 1 | ≤0 / ≤30 / 其他 | 1 / UNCOV_RATE / 0 |
     | 2 | ≤0 / 31-90 / 其他 | 1 / UNCOV_RATE / 0 |
     | 3 | ≤0 / 91-180 / 其他 | 1 / UNCOV_RATE / 0 |
     | 4 | ≤0 / >180 | 1 / UNCOV_RATE |
     | 5-9 | — | 只乘比例 |
     | 10-15 | — | 无配置比例，**仅个别认定时才有值** |
   - `HAS_INDIVIDUAL=1` 时直接用 `SPID_*`，**不乘比例**
   - `BD_*` 统一 `ROUND(...,2)`（L547-557）

### STEP3 分摊与本月发生额（L577-986）

- 负数 `BD_0_AMT` 按 公司+客商+科目 的正数合计比例分摊（L617-664）
- `BD_AFAL_x` = 个别认定 → `SPID_x`；正数 → `BD_x + AGE_ALLOC_x * 分摊比例`；否则 0（L719-763）
- `BD_AFAL_0` = 1..15 合计
- `BD_PROV_METHOD` 计提方式（L766-820）：按 NODE 2910 / 2000 判定 → `视像合并组合` / `TVS组合` / `关联方组合` / `账龄组合`
- `WRITEOFF_AMT`：`DWD_FI_MR_ARAP_SUM_MI` 中 `ODS_SRC='WRITEOFF'`（L666-686）
- `LM_BD_AFAL_0_AMT`：上月 ARPM02 期末坏账（L688-699）

---

## 六、投保 INS —— AW_MR6_ARPINS_000001

- 汇率 `MTD_END_RATE` = 本位币（`AZIENDA.COD_VALUTA`）期末汇率 / 投保币种期末汇率，币种一致为 1
- 账龄金额：从 ARPM02 按 **公司+客商** 汇总，**仅 `LE_AGE_FLAG='AR'`**
- `INS_COV_DAYS`：按 30 / 60-90 / 120-180 / 360 累计账龄段 0-3
- 未覆盖比例：沿用旧逻辑 A/B/R/D 公式
- ⚠️ **L102-106 测试用全表 DELETE+复制生产数据，上线必须删除**

---

## 七、周转 TOV —— AW_MR8_ARPS01_000001（S 层）

- 入参多一个 `P_BG`（事业部）
- 公司范围：`AW_RUL_ATSMAP_000001`（BG 映射）∩ `AW_RUL_DWMCRS_000001`（ZAW_D2M_IN）− LOCK
- 源：ARPM02 + `DWD_FI_MR_AR_IMOCC_MI`（收入）+ `AW_MR9_REVM01_000001` + `AW_MR8_CPRS01_000001`
- ARPM02 与 IMOCC **先汇总后按 公司+客商+利润中心 匹配收入**，未匹配收入追加；`D_BG` 统一后置映射；剔除多事业部客户的负周转行

---

## 八、对数问题 → 排查路径（速查）

| 现象 | 先查 | 再查 |
|---|---|---|
| 公司少/多 | `AW_RUL_DWMCRS_000001`（`ZAW_D2M_IN`/`ZAW_D2M_LOCK`）；TOV 另查 `AW_RUL_ATSMAP_000001` | 入参公司/节点是否命中 `V_REF_AZIENDA` |
| M01 总数不对 | `DWD_FI_MR_ARAP_SUM_MI` 的 `DT_MONTH`/`IS_APAR_FLAG`；REVM01 的 `S600101/02` | M01 三个开窗 `LE/ME/MB_BCY_AMT` 与 `F_APAR_REC` |
| M02 某科目行缺失 | ARPM01 该行 `LE_AGE_FLAG` 是否为空、`SRC_DETAIL` 是否 `ORG%`（M02 只取这两类，L307-308） | M01 重分类是否打上标识 |
| M02 金额与 ARPM01 不等 | 除税分支（CL+重分类Y）、折算分支（汇率评估标识空） | `DATI_CAMBIO` 汇率是否会取错（`MAX`）、2023 公司 SQF_TEST |
| 交易币金额不对 | **`QCY_*` 直接 = `BCY_*`（L1106-1121）**，非真实交易币 | `COD_VALUTA_ORIGINARIA` 也被赋成 `COD_VALUTA`（L1087） |
| 年初/上月余额不对 | 历史期间 ARPM02 是否已跑（`V_BY`=上年12月、`V_LM`=自然上月） | 业务键 4 元组是否一致 |
| 行数比历史多/少 | 业务键（公司+科目+客商+利润中心）；`ALL_KEYS` 并集（L871-880） | `DIM_CANDIDATE` 优先级回退 |
| 行金额"不像过程算的" | 该行 `PROVENIENZA='INPUT_DEFORM'`（界面行被保留） | OID 复用匹配是否命中 |
| 坏账基数不对 | STEP1 垫资/返利 `ARP_02_001`/`ARP_02_003`（仅 ZFAMOUNT） | FIFO 冲减顺序（长账龄优先） |
| 坏账金额不对 | 规则表 `AW_RUL_ARPBDR_000001`（BATCH_ID 1/2/3、有效期、GRP_SCOPE 前3位） | 投保未覆盖系数（`INS_COV_DAYS` 分段） |
| 坏账分摊不对 | 分摊基数 = 公司+客商+科目 的正数合计 | `BD_AFAL` 是否被个别认定替换 |
| 投保不对 | ARPM02 的 `LE_AGE_FLAG='AR'` 汇总 | 汇率、`INS_COV_DAYS` 分段、A/B/R/D 公式 |

---

## 九、已知待处理项（代码内注释标记）

| 项 | 位置 | 说明 |
|---|---|---|
| SQF_TEST 硬编码 | M02 L160-170 | 上线前替换为 `DWD_FI_MR_SAP_TCURR_DD` + `MANDT='600'` |
| ARPINS 全表清空 | INS L102-106 | 测试用，上线前必须移除 |
| M01 EXCEPTION 被注释 | M01 L948-965 | 报错时不回滚/不写日志（M02/BD 正常） |
