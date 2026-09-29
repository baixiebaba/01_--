# 周转明细表 ADS 表 — 字段英文命名（知识库风格）

> 生成日期: 2026-09-02 | 表名待定（示例: CPM_SP_TOV_M / ADS 层）
> 命名基准: 参照《数据字典与ER关系知识库》中 DWD_FI_AR_AGE_DETAIL_MI 条目既有的指标/维度词

## 一、命名规则

| 要素 | 缩写 | 说明 |
|------|------|------|
| 场景-计划 | PLN | PLAN 计划 |
| 场景-实际 | ACT | ACTUAL 实际 |
| 场景-同期 | LY | LAST YEAR 上年同期(如项目用 Same Period 可换 SP) |
| 时点-期初 | BEG | BEGINNING |
| 时点-上月 | LM | LAST MONTH (与知识库 LM_BD_AFAL_0_AMT 一致) |
| 时点-期末 | END | ENDING |
| 时点-本月 | MTD | MONTH TO DATE (与知识库 MTD_BD_PROV_AMT 一致) |
| 时点-累计 | YTD | YEAR TO DATE (如指累计平均占用可换 AVG) |
| 应收占用 | AR | 对应知识库 AR_AMT(期末应收占用) |
| 收入 | REV | 对应知识库 REV_AMT |
| 因素1~8 | F1_ODUE ~ F8_ADJ | 完全沿用知识库 F1_ODUE_AMT~F8_ADJ_AMT |
| 金额后缀 | _AMT | 全部金额字段 |

> 组合规则: `{场景}_{时点}_{指标主体}_AMT`，例: 实际-期初-因素1-超期款金额 = `ACT_BEG_F1_ODUE_AMT`
> 展示为大写；Doris 物理列名按建表习惯转小写即可。

## 二、字段清单（共 93 列）

| # | 中文名 | 英文名 | 分组/说明 |
|---|--------|--------|-----------|
| 1 | 场景 | SCENARIO_CODE | 维度1 计划/实际/同期 行标识(若场景已按列展开可删此列) |
| 2 | 期间 | DT_MONTH | 维度2 知识库现成词: DWD_FI_AR_AGE_DETAIL_MI.DT_MONTH=年月 |
| 3 | 事业部编码 | BU_CODE | 维度3 事业部 |
| 4 | 公司 | COMPANY_CODE | 维度4 知识库现成词: COMPANY_CODE=公司/组织 |
| 5 | 类别 | CATEGORY_CODE | 维度5 类别(若指客户/公司类别可换 CUST_TYPE_CODE/COMP_TYPE_CODE) |
| 6 | 三级公司分类编码 | CHANNEL_L3_CODE | 维度6 知识库现成词: 三级公司分类编码 |
| 7 | 渠道分组编码 | ONOFFLINE_CODE | 维度7 线上线下渠道分组(毛利表 onoffline / 知识库 D_ONOFFLINE) |
| 8 | 利润中心编码 | PROFIT_CENTER_CODE | 维度8 利润中心(毛利表 profitcenter_code) |
| 9 | 业务范围编码 | BUS_RANGE_CODE | 维度9 知识库现成词: 业务范围编码 |
| 10 | 业务管理单元编码 | MARKETING_DEPT_CODE | 维度10 知识库现成词: 业务管理单元编码 |
| 11 | 本位币币种 | BCY_CODE | 维度11 知识库现成词: BCY_CODE=本位币币种 |
| 12 | 计划期初应收占用金额 | PLN_BEG_AR_AMT | 应收占用/收入-计划 |
| 13 | 计划上月应收占用金额 | PLN_LM_AR_AMT | 应收占用/收入-计划 |
| 14 | 计划期末应收占用金额 | PLN_END_AR_AMT | 应收占用/收入-计划 |
| 15 | 计划累计应收占用金额 | PLN_YTD_AR_AMT | 应收占用/收入-计划 |
| 16 | 计划本月收入金额 | PLN_MTD_REV_AMT | 应收占用/收入-计划 |
| 17 | 计划累计收入金额 | PLN_YTD_REV_AMT | 应收占用/收入-计划 |
| 18 | 实际期初应收占用金额 | ACT_BEG_AR_AMT | 应收占用/收入-实际 |
| 19 | 实际上月应收占用金额 | ACT_LM_AR_AMT | 应收占用/收入-实际 |
| 20 | 实际期末应收占用金额 | ACT_END_AR_AMT | 应收占用/收入-实际 |
| 21 | 实际累计应收占用金额 | ACT_YTD_AR_AMT | 应收占用/收入-实际 |
| 22 | 实际本月收入金额 | ACT_MTD_REV_AMT | 应收占用/收入-实际 |
| 23 | 实际累计收入金额 | ACT_YTD_REV_AMT | 应收占用/收入-实际 |
| 24 | 同期期初应收占用金额 | LY_BEG_AR_AMT | 应收占用/收入-同期 |
| 25 | 同期上月应收占用金额 | LY_LM_AR_AMT | 应收占用/收入-同期 |
| 26 | 同期期末应收占用金额 | LY_END_AR_AMT | 应收占用/收入-同期 |
| 27 | 同期累计应收占用金额 | LY_YTD_AR_AMT | 应收占用/收入-同期 |
| 28 | 同期本月收入金额 | LY_MTD_REV_AMT | 应收占用/收入-同期 |
| 29 | 同期累计收入金额 | LY_YTD_REV_AMT | 应收占用/收入-同期 |
| 30 | 实际-期初-因素1-超期款金额 | ACT_BEG_F1_ODUE_AMT | F1_ODUE-实际 |
| 31 | 实际-上月-因素1-超期款金额 | ACT_LM_F1_ODUE_AMT | F1_ODUE-实际 |
| 32 | 实际-期末-因素1-超期款金额 | ACT_END_F1_ODUE_AMT | F1_ODUE-实际 |
| 33 | 实际-累计-因素1-超期款金额 | ACT_YTD_F1_ODUE_AMT | F1_ODUE-实际 |
| 34 | 同期-期初-因素1-超期款金额 | LY_BEG_F1_ODUE_AMT | F1_ODUE-同期 |
| 35 | 同期-上月-因素1-超期款金额 | LY_LM_F1_ODUE_AMT | F1_ODUE-同期 |
| 36 | 同期-期末-因素1-超期款金额 | LY_END_F1_ODUE_AMT | F1_ODUE-同期 |
| 37 | 同期-累计-因素1-超期款金额 | LY_YTD_F1_ODUE_AMT | F1_ODUE-同期 |
| 38 | 实际-期初-因素2-提前回款金额 | ACT_BEG_F2_EPAY_AMT | F2_EPAY-实际 |
| 39 | 实际-上月-因素2-提前回款金额 | ACT_LM_F2_EPAY_AMT | F2_EPAY-实际 |
| 40 | 实际-期末-因素2-提前回款金额 | ACT_END_F2_EPAY_AMT | F2_EPAY-实际 |
| 41 | 实际-累计-因素2-提前回款金额 | ACT_YTD_F2_EPAY_AMT | F2_EPAY-实际 |
| 42 | 同期-期初-因素2-提前回款金额 | LY_BEG_F2_EPAY_AMT | F2_EPAY-同期 |
| 43 | 同期-上月-因素2-提前回款金额 | LY_LM_F2_EPAY_AMT | F2_EPAY-同期 |
| 44 | 同期-期末-因素2-提前回款金额 | LY_END_F2_EPAY_AMT | F2_EPAY-同期 |
| 45 | 同期-累计-因素2-提前回款金额 | LY_YTD_F2_EPAY_AMT | F2_EPAY-同期 |
| 46 | 实际-期初-因素3-电商零售销售节奏 | ACT_BEG_F3_ECR_AMT | F3_ECR-实际 |
| 47 | 实际-上月-因素3-电商零售销售节奏 | ACT_LM_F3_ECR_AMT | F3_ECR-实际 |
| 48 | 实际-期末-因素3-电商零售销售节奏 | ACT_END_F3_ECR_AMT | F3_ECR-实际 |
| 49 | 实际-累计-因素3-电商零售销售节奏 | ACT_YTD_F3_ECR_AMT | F3_ECR-实际 |
| 50 | 同期-期初-因素3-电商零售销售节奏 | LY_BEG_F3_ECR_AMT | F3_ECR-同期 |
| 51 | 同期-上月-因素3-电商零售销售节奏 | LY_LM_F3_ECR_AMT | F3_ECR-同期 |
| 52 | 同期-期末-因素3-电商零售销售节奏 | LY_END_F3_ECR_AMT | F3_ECR-同期 |
| 53 | 同期-累计-因素3-电商零售销售节奏 | LY_YTD_F3_ECR_AMT | F3_ECR-同期 |
| 54 | 实际-期初-因素4-已确认未兑现返利余额 | ACT_BEG_F4_UREB_AMT | F4_UREB-实际 |
| 55 | 实际-上月-因素4-已确认未兑现返利余额 | ACT_LM_F4_UREB_AMT | F4_UREB-实际 |
| 56 | 实际-期末-因素4-已确认未兑现返利余额 | ACT_END_F4_UREB_AMT | F4_UREB-实际 |
| 57 | 实际-累计-因素4-已确认未兑现返利余额 | ACT_YTD_F4_UREB_AMT | F4_UREB-实际 |
| 58 | 同期-期初-因素4-已确认未兑现返利余额 | LY_BEG_F4_UREB_AMT | F4_UREB-同期 |
| 59 | 同期-上月-因素4-已确认未兑现返利余额 | LY_LM_F4_UREB_AMT | F4_UREB-同期 |
| 60 | 同期-期末-因素4-已确认未兑现返利余额 | LY_END_F4_UREB_AMT | F4_UREB-同期 |
| 61 | 同期-累计-因素4-已确认未兑现返利余额 | LY_YTD_F4_UREB_AMT | F4_UREB-同期 |
| 62 | 实际-期初-因素5-已账扣未报账的欠付费用 | ACT_BEG_F5_UFEE_AMT | F5_UFEE-实际 |
| 63 | 实际-上月-因素5-已账扣未报账的欠付费用 | ACT_LM_F5_UFEE_AMT | F5_UFEE-实际 |
| 64 | 实际-期末-因素5-已账扣未报账的欠付费用 | ACT_END_F5_UFEE_AMT | F5_UFEE-实际 |
| 65 | 实际-累计-因素5-已账扣未报账的欠付费用 | ACT_YTD_F5_UFEE_AMT | F5_UFEE-实际 |
| 66 | 同期-期初-因素5-已账扣未报账的欠付费用 | LY_BEG_F5_UFEE_AMT | F5_UFEE-同期 |
| 67 | 同期-上月-因素5-已账扣未报账的欠付费用 | LY_LM_F5_UFEE_AMT | F5_UFEE-同期 |
| 68 | 同期-期末-因素5-已账扣未报账的欠付费用 | LY_END_F5_UFEE_AMT | F5_UFEE-同期 |
| 69 | 同期-累计-因素5-已账扣未报账的欠付费用 | LY_YTD_F5_UFEE_AMT | F5_UFEE-同期 |
| 70 | 实际-期初-因素6-开票样机额度 | ACT_BEG_F6_INVSM_AMT | F6_INVSM-实际 |
| 71 | 实际-上月-因素6-开票样机额度 | ACT_LM_F6_INVSM_AMT | F6_INVSM-实际 |
| 72 | 实际-期末-因素6-开票样机额度 | ACT_END_F6_INVSM_AMT | F6_INVSM-实际 |
| 73 | 实际-累计-因素6-开票样机额度 | ACT_YTD_F6_INVSM_AMT | F6_INVSM-实际 |
| 74 | 同期-期初-因素6-开票样机额度 | LY_BEG_F6_INVSM_AMT | F6_INVSM-同期 |
| 75 | 同期-上月-因素6-开票样机额度 | LY_LM_F6_INVSM_AMT | F6_INVSM-同期 |
| 76 | 同期-期末-因素6-开票样机额度 | LY_END_F6_INVSM_AMT | F6_INVSM-同期 |
| 77 | 同期-累计-因素6-开票样机额度 | LY_YTD_F6_INVSM_AMT | F6_INVSM-同期 |
| 78 | 实际-期初-因素7-国补未回款影响金额 | ACT_BEG_F7_GSUB_AMT | F7_GSUB-实际 |
| 79 | 实际-上月-因素7-国补未回款影响金额 | ACT_LM_F7_GSUB_AMT | F7_GSUB-实际 |
| 80 | 实际-期末-因素7-国补未回款影响金额 | ACT_END_F7_GSUB_AMT | F7_GSUB-实际 |
| 81 | 实际-累计-因素7-国补未回款影响金额 | ACT_YTD_F7_GSUB_AMT | F7_GSUB-实际 |
| 82 | 同期-期初-因素7-国补未回款影响金额 | LY_BEG_F7_GSUB_AMT | F7_GSUB-同期 |
| 83 | 同期-上月-因素7-国补未回款影响金额 | LY_LM_F7_GSUB_AMT | F7_GSUB-同期 |
| 84 | 同期-期末-因素7-国补未回款影响金额 | LY_END_F7_GSUB_AMT | F7_GSUB-同期 |
| 85 | 同期-累计-因素7-国补未回款影响金额 | LY_YTD_F7_GSUB_AMT | F7_GSUB-同期 |
| 86 | 实际-期初-因素8手工导入因素 | ACT_BEG_F8_ADJ_AMT | F8_ADJ-实际 |
| 87 | 实际-上月-因素8手工导入因素 | ACT_LM_F8_ADJ_AMT | F8_ADJ-实际 |
| 88 | 实际-期末-因素8手工导入因素 | ACT_END_F8_ADJ_AMT | F8_ADJ-实际 |
| 89 | 实际-累计-因素8手工导入因素 | ACT_YTD_F8_ADJ_AMT | F8_ADJ-实际 |
| 90 | 同期-期初-因素8手工导入因素 | LY_BEG_F8_ADJ_AMT | F8_ADJ-同期 |
| 91 | 同期-上月-因素8手工导入因素 | LY_LM_F8_ADJ_AMT | F8_ADJ-同期 |
| 92 | 同期-期末-因素8手工导入因素 | LY_END_F8_ADJ_AMT | F8_ADJ-同期 |
| 93 | 同期-累计-因素8手工导入因素 | LY_YTD_F8_ADJ_AMT | F8_ADJ-同期 |
