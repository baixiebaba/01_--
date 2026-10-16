# ARP 系列存储过程清单（M 表生成逻辑）

> 整理时间：2026-10-16　来源：本地代码仓库 + `草稿/_arpm_dict.md` 数据字典 + Tagetik 表单实测

## 一、M 表 ↔ 存储过程 ↔ 数仓表 映射

| Tagetik 表单 | 数仓表 | 存储过程 | 数仓层 | 用途 |
|---|---|---|---|---|
| XC001_K_M_0001 往来账龄计算底稿M01 | `AW_MR9_ARPM01_000001` | **`CPM_SP_D2M_ARP_M_PHASE2`** | DWM | DWD→DWM 往来账龄数据抽取 |
| XC001_K_M_0002 往来账龄结果表M02 | `AW_MR9_ARPM02_000001` | **`CPM_SP_M2M_ARP_AG_M_PHASE2`** | DWM | ARPM01 底稿平铺为 ARPM02 结果表 |
| XC001_K_M_0003 坏账计提结果表 | `AW_MR9_ARPM02_000001`（回写 `DEAD_AMT`） | **`CPM_SP_M2M_ARP_BD_M_PHASE2`** | DWM | 坏账计提：STEP1 基数 → STEP2 计算 → STEP3 分摊 |
| 投保表（M 层辅助） | `AW_MR6_ARPINS_000001` | **`CPM_SP_M2M_ARP_INS_M_PHASE2`** | DWM | 更新投保本位币金额、账龄金额、未覆盖比例 |
| 应收周转（S 层） | `AW_MR8_ARPS01_000001` | **`CPM_SP_M2S_ARP_TOV_M_PHASE2`** | DWS | 应收周转计算汇总表装载 |

## 二、文件位置

### 正式版本 `01_代码/02_DWM/C_应收应付/`

| 文件 | 大小 | 目标表 |
|---|---|---|
| `CPM_SP_D2M_ARP_M_PHASE2.sql` | 34.6 KB | `AW_MR9_ARPM01_000001` |
| `CPM_SP_M2M_ARP_AG_M_PHASE2.sql` | 66.6 KB | `AW_MR9_ARPM02_000001` |
| `CPM_SP_M2M_ARP_BD_M_PHASE2.sql` | 56.2 KB | `AW_MR9_ARPM02_000001`（坏账字段） |
| `CPM_SP_M2M_ARP_INS_M_PHASE2.sql` | 11.5 KB | `AW_MR6_ARPINS_000001` |
| `账龄校验query.sql` / `账龄校验query_客商级明细.sql` | 8.1 / 6.7 KB | 校验用 |
| `坏账校验query.sql` / `坏账校验query_客商级明细.sql` | 6.0 / 7.9 KB | 校验用 |

### S 层 `01_代码/03_DWS/C_应收应付/`

| 文件 | 大小 | 目标表 |
|---|---|---|
| `CPM_SP_M2S_ARP_TOV_M_PHASE2.sql` | 37.6 KB | `AW_MR8_ARPS01_000001` |

### 草稿/历史 `01_代码/02_DWM/C_应收应付/草稿/`

| 文件 | 说明 |
|---|---|
| `CPM_SP_APAR_2022.sql`（158.8 KB） | 2022 版 APAR 老存储过程 + `_字段取数逻辑.md` |
| `CPM_SP_AG_HZOC.sql`（74.3 KB） | 早期合并口径版本 |
| `CPM_SP_AG_INSURE.sql`（8.9 KB） | 投保早期版本 |
| `ETL_HI_DATA_APARAGI.sql`（24.9 KB） | ETL 抽取脚本 + `_字段取数逻辑.md` |
| `F_APAR_REC`（43.5 KB） | **重分类函数**（M01 的 LE/ME/MB_AGE_FLAG 依赖它） |
| `V_APAR_ELEM_NODE_TAB.sql`（2.8 KB） | 集团归属范围判断视图（GRP_SCOPE） |
| `dim_rule_fi_mr_ar_reclass-*.sql` | 重分类规则配置表（建表/初始化/匹配模板/设计说明） |
| `投保.sql`、`查询客商主数据_1000077.sql` | 辅助查询 |

## 三、公共调用约定（所有 ARP 过程一致）

- **入参**：`P_SCENARIO`（场景）、`P_PERIODO`（期间）、`P_AZIENDA`（公司）、`SESSION_USER`（用户）
- **执行骨架**：
  1. 装载会话隔离表 `SESSION_AZIENDA_LIST` / `SESSION_V_REF_AZIENDA`（按 SESSION_ID 隔离）
  2. `DELETE FROM 目标表` 对应场景/期间/公司数据
  3. 分 STEP 执行 `INSERT`/`MERGE` 装载
  4. 每步写 `ZTAB_CPM_LOG` 审计日志
  5. 清理会话表

## 四、核心逻辑要点

### M01 底稿 `CPM_SP_D2M_ARP_M_PHASE2`
- **源表**：`DWD_FI_MR_ARAP_SUM_MI`（主）、`AW_MR9_REVM01_000001`（出库/退货）
- **7 路数据来源**：主往来 + 出库未开/退货未办 + 超期款 + 提前回款 + 电商零售 + 欠付费用 + 欠付返利
- **过滤**：`is_apar_flag` 为 Y 或空；公司限 `AW_RUL_DWMCRS_000001.ARP_FLAG = Y`
- **重分类**：函数 `F_APAR_REC` → `LE_AGE_FLAG` / `ME_AGE_FLAG` / `MB_AGE_FLAG`
- **科目映射**：AR→1122000000、OR→122101F、AS→1123000000、AP→2202000000、OP→224199F、CL→2204000000 等
- **集团归属**：视图 `V_APAR_ELEM_NODE_TAB` → SUB/GIN/GEX

### M02 结果表 `CPM_SP_M2M_ARP_AG_M_PHASE2`
- **源表**：`AW_MR9_ARPM01_000001` 为主，另有 `AW_MR9_ARPM02_000001`、`DATI_CAMBIO`（汇率）、`SQF_TEST`
- **三条核心口径**：
  1. 本月账龄：`LE_AGE_FLAG='CL'` 且 `IS_REC_LG='Y'` 的行，取 `SRC_DETAIL` 为 `ORG%` 的金额 `/(1+TAX_RATE)` 剔除税额
  2. 年初/上月余额：按 公司+科目+客商+利润中心 全量匹配，本月无而历史有则保留历史行
  3. 专项金额（出库未开/退货未办/超期款/开票样机/提前回款/电商零售/欠付返利/欠付费用）按 科目+客户+利润中心 落到同一行
- **OID 处理**：过程生成用 `NEWID()`，重跑时人工行须复用目标表原 OID
- **字段规模**：136 列（维度 + BY/LM 余额 + BCY_0~15 + QCY_0~15 + 专项金额 + `DEAD_AMT`/`RISK_AMT` + 管理状态字段）

### 坏账 `CPM_SP_M2M_ARP_BD_M_PHASE2`
- **三步**：STEP1 坏账计提基数（FIFO）→ STEP2 坏账计算 → STEP3 坏账分摊
- **源表**：ARPM01、ARPM02、`AW_MR6_ARPINS_000001`、`AW_RUL_ARPBDR_000001`（坏账规则）、`DWD_FI_MR_ARAP_SUM_MI`
- **MERGE ON 统一按 OID**；STEP2 个别认定来源用 ARPM02 的 `SPID` 字段
- 近期高频迭代（20261009~20261018 共 10+ 次修改）

### 投保 `CPM_SP_M2M_ARP_INS_M_PHASE2`
- 根据投保信息 + 往来账龄，更新投保本位币金额、账龄金额、未覆盖比例

### 周转 `CPM_SP_M2S_ARP_TOV_M_PHASE2`
- **源表**：ARPM02、`DWD_FI_MR_AR_IMOCC_MI`、`AW_MR9_REVM01_000001`、`AW_MR8_CPRS01_000001`
- 先汇总周转、再匹配收入；事业部映射与负周转剔除在合并后执行

## 五、M02 关键字段速查（136 列）

| 分组 | 字段 |
|---|---|
| 维度 | COD_SCENARIO / COD_PERIODO / COD_AZIENDA / COD_CONTO / DESC_CONTO1 / CUST_CODE / CUST_HEAD_CODE / CUST_BRANCH_CODE / COD_AZI_CTP / COUNTRY_CODE |
| 账龄标识 | LE_AGE_FLAG / IS_REC_LG / ME_AGE_FLAG / IS_REC_ME / MB_AGE_FLAG / IS_REC_MB |
| 分类维度 | GRP_SCOPE / NATURE_L1~L3_NAME / D_CHANNEL / D_ONOFFLINE / COD_DEST2 / COD_DEST3 / D_SALE_DEPT / D_TOV_CHAN / D_CC_CUSTGRP |
| 余额 | BY_BCY_0_AMT（年初）/ LM_BCY_0_AMT（上月）/ BCY_0_AMT（本月） |
| 账龄段 | BCY_1~15_AMT / QCY_0~15_AMT |
| 含税调整 | BCY_ADJ_INCL_0~15_AMT / BCY_ADJ_EXCL_0_AMT |
| 专项金额 | SHP_NINV_AMT（出库未开）/ RET_NTRF_AMT（退货未办）/ OVERDUE_0~9_AMT（超期）/ INV_SAMPLE_AMT（开票样机）/ EPAY_AMT（提前回款）/ ECLS_AMT（电商零售）/ UREB_AMT（欠付返利）/ UFEE_AMT（欠付费用） |
| 坏账 | **DEAD_AMT**（坏账金额）/ RISK_AMT |
| 汇率 | CLOSING_RATE_BCY_AMT / POSTING_RATE_BCY_AMT / EXCHANGE_RATE_EVAL_FLAG / TH_FX_EVAL_AMT |
| 管理状态 | IS_LN_AGE / LN_AGE_RSN / IS_ABN / IS_EXS / SUSP_RSN / CLR_MEA / EST_CLR_DT / CLR_PROG / RSP_PSN / IS_ADJ / ADJ_RSN |

## 六、逻辑文档

- M01：`https://hisenseex.feishu.cn/sheets/JVJsssmEqh9Uk6tSffEci4khnIf`（飞书）
- M02/坏账：`草稿/经分二期-应收-数据模型详细设计文档.xlsx`
- 字段级规则：`01_DWD/C_应收应付/草稿/_arpm_dict.md`（ARPM01/ARPM02 全字段取数规则）
