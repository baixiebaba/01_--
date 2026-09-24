# 项目长期笔记（C_应收应付）

## 权威数据字典位置
`/Users/zhouhong/Documents/01_TA工作/01_海信/99_AI/数据字典与ER关系知识库.md`
（2.5MB / 64488 行，2026-09-16 更新。所有字段命名、口径必须对齐此库）

## 知识库结构（六大块）
1. **02_单体收入成本(D2M/M2M)（185张表）** — AW_MR9_*（M层21张）、AW_MR8_*（S层9张）、AW_RUL_*（规则21张）、AW_MAGVAR_*（2张）、CPM_*（13张）、TMP_*（34张）、ZTAB_*（44张）、V_REF_*（26张）、SESSION_*、DATI_*、DWD_*、FORM_*、其他表7张
2. **核心字段含义速查**（200+字段）
3. **业务模块数据流**（跑数链路、各层核心表、M/S层字段体系、维度表对照）
4. **KPI计算体系**
5. **全量数据库表字段清单（2381张表）**，按字母 A-Z 分组
6. **维度层级体系与表关联关系**（ALLVIEW提取）

## 应收应付相关条目（重点关注）
- `DWD_FI_AR_AGE_DETAIL_MI`（第17492行）：应收账龄+超期款+坏账计提宽表，300字段；含16段账龄 BCY/QCY_0~15_AMT、超期款 OVERDUE_AMT0~9、LE/ME/MB 三种账龄标识
- `DWD_FI_MR_ARAP_SMS_BALANCE_MI`（第18090行）：SMS返利余额月报，粒度 dt_month+company_code+sales_code+leibie
- `DWD_FI_MR_ARAP_SUM_MI`（第64391行）：往来账龄汇总表，聚合 DETAIL/信汇/超期款/开票样机/SMS/政策返利/国际营销/核销
- `DWD_FI_MR_GP_MSUM_CKTH_MI`（第5342行）：毛利汇总（含 ACCT_MAP_CODE、COGS_AMT）
- `FORM_DATI`（第5488行）：Tagetik 通用表单表，账龄存储过程 CPM_SP_APAR_2022 的落地表

## DWM 层应收账龄 M 表（2026-09-24 补充）
- `AW_MR9_ARPM01_000001` 往来账龄计算底稿（73+1字段，STEP1数据聚合），存储过程 `CPM_SP_D2M_ARP_M`
  - 7路来源：dwd_fi_mr_arap_sum_mi（主）、AW_MR9_REVM01_000001（出库/退货）、dwd_fi_mr_ar_overdue_mi（超期款）、
    sum_mi×4（提前回款/电商零售/欠付费用/欠付返利）
  - 抽取限制：`is_apar_flag` 为 Y 或空；公司在 `AW_RUL_DWMCRS_000001` 中 `ARP_FLAG='Y'` 范围
  - STEP3 重分类用函数 `F_APAR_REC`，输出 LE/ME/MB_AGE_FLAG 与 IS_REC_LG/ME/MB
  - GRP_SCOPE 由 `V_APAR_ELEM_NODE_TAB` 的 node+hq 判断：SUB-子公司 / GIN-集团内 / GEX-集团外
- `AW_MR9_ARPM02_000001` 往来账龄结果表（110字段），存储过程 `CPM_SP_M2M_ARP_AG_M`
  - 把底稿 SRC_DETAIL 各分类平铺成列；`LE_AGE_FLAG='CL'` 且 `IS_REC_LG='Y'` 时 `/(1+TAX_RATE)` 剔税
  - 年初/上月余额按 公司+科目+客商+利润中心 全量匹配本表对应期间取 `BCY_0_AMT`
- 设计文档源：`草稿/经分二期-应收-数据模型详细设计文档.xlsx`（41 sheet，含 ARPM04/05、ARPINS、DWS、ADS 各层）

## Tagetik（管报1.0/2.0）参数约定（2026-09-24 确认）
- **场景 `COD_SCENARIO`**：`年份+场景码`，如 `2026ACT`；上一年场景 = 年份-1 + 后缀（2026ACT → 2025ACT）
- **期间 `COD_PERIODO`**：**两位月份码**（如 `08`），不是 YYYYMM；FORM_DATI / DATI_SALDI_LORDI / AW_MR9_ARPM02 均为 2 位
- **公司 `COD_AZIENDA`**：4 位编码，如 `1740`
- 1.0 与 2.0 **共用同一组**参数（场景/期间/公司）
- 期间推算：上月 = 同场景月份-1（01 月取上一年场景 '12'）；年初 = 上一年场景 '12'（若系统用本年期初则改 '00'）
- 1.0/2.0 账龄表的年初、上月金额已存于本月记录（`IMPORTO_1/2`、`BY/LM_BCY_0_AMT`），只需按本月期间取数；
  `DATI_SALDI_LORDI` 单期间只有一条 `IMPORTO`，需按 (场景,期间) 组合取三个快照
- 科目层级：`TGK_GB_HISENSE.V_REF_CONTO`（HIE/NODE/ELEM/DESC0/DESC_ELEGER0），`hie='01' AND node=节点编码` 取 ELEM 后限制 `DATI_SALDI_LORDI.COD_CONTO`

## 命名规范（已确认）
- 海信 DWD 层：小写英文 + 下划线，如 `cust_head_code`、`cust_branch_code`、`bill_model_amt`、`dt_month`
- 金额字段以 `_amt` 结尾，编码 `_code`，名称 `_name`
- 本币金额 `bcy_amt` / 交易币 `qcy_amt`
- 维度成对出现：`xxx_code` + `xxx_name`

## 关键业务口径（应收应付）
- 账龄起算日 `baseline_dt`：统驭行 AB 凭证取 ZFBDT，否则按配置取 ZFBDT 或 BLDAT；余额行取参数月末
- `aging_days` = 参数月末 - 账龄起算日 + 1；余额行固定 1
- Sum 排除 DETAIL 中 `acct_map_code IN ('1122000095','2202000095')`（两个信汇科目独立构造）
- 超期款 `start_dt` 为参数月份**下月月初**（如 20260901 代表 202608）
- 付款条件关联 `dwd_fi_mr_ar_cterm_md`，按 system_src+company_code+cust_code，关联前需去重
- SQL 校验/查询脚本的输出列别名统一使用**英文小写下划线**（如 by_amt_20 / lm_amt_10 / cur_amt_diff / match_flag / adj_flag），不用中文带引号别名
- 交付的 SQL 脚本注释统一使用**块注释 `/* ... */`**，不用 `--` 行注释（含行尾注释）
