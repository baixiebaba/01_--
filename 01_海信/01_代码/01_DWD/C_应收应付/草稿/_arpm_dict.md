#### AW_MR9_ARPM01_000001
**说明**: 往来账龄计算底稿；DWM 层 STEP1 数据聚合，将 D 层往来账龄汇总推到 M 层，并汇总出库未开与退货未办数据
**存储过程**: `CPM_SP_D2M_ARP_M`
**数仓分层**: DWM ｜ **表类型**: 事实表 ｜ **更新方式**: 增量更新 ｜ **数仓目录**: 管理财经 → 财报管理 → 应收
**参数**: 场景 `P_SCENARIO`、期间 `P_PERIODO`、公司 `P_AZIENDA`、用户 `SESSION_USER`
**源表(7路)**: ①`dwd_fi_mr_arap_sum_mi`（主，往来账龄明细）②`AW_MR9_REVM01_000001`（单体销售明细，出库/退货）③`dwd_fi_mr_ar_overdue_mi`（超期款）④`dwd_fi_mr_arap_sum_mi`（提前回款）⑤`dwd_fi_mr_arap_sum_mi`（电商零售销售节奏）⑥`dwd_fi_mr_arap_sum_mi`（欠付费用）⑦`dwd_fi_mr_arap_sum_mi`（欠付返利）
**抽取范围限制**: ①`is_apar_flag` 为 Y 或为空；②公司限制在 `AW_RUL_DWMCRS_000001` 中 `ARP_FLAG` 为 Y 的 `COD_AZIENDA` 范围内
**数据分类(SRC_DETAIL)取值**: `ZTSO04_CK-出库未开`（S600101%）、`ZTSO04_TH-退货未办`（S600102%）、`overdue-超期款`、`inv_sample-开票样机额度`、`epay-提前回款`、`ECLS-电商零售`、`ufee-欠付费用`、`ureb-欠付返利`，其余为 `ORG%` 原始往来

| 字段名 | 类型 | 长度/精度 | 可空 | 含义 | 取数来源与规则 |
|--------|------|-----------|------|------|----------------|
| COD_SCENARIO | VARCHAR2 | 15 | N | 场景 | 限制条件： 1、取is_apar_flag为Y或为空的 2、限制公司在抽取范围内的AW_RUL_DWMCRS_000001中ARP_FLAG为Y的COD_AZIENDA范围；出库/退货路：AW_MR9_REVM01_000001 COD_SCENARIO 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi year+"ACT" 直接对应 |
| COD_PERIODO | VARCHAR2 | 2 | Y | 期间 | 直接对应 dwd_fi_mr_arap_sum_mi.month；出库/退货路：AW_MR9_REVM01_000001 COD_PERIODO 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi month 直接对应 |
| COD_AZIENDA | VARCHAR2 | 30 | Y | 公司 | 直接对应 dwd_fi_mr_arap_sum_mi.company_code；STEP2/3：按《账龄表进数范围维护》按取数类型剔除：EX1-按公司+客商剔除；EX2-按公司+科目剔除；EX3-按系统号+科目剔除；IN1-按系统号+公司+科目取数；出库/退货路：AW_MR9_REVM01_000001 COD_AZIENDA 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi company_code 直接对应 |
| COD_CONTO | VARCHAR2 | 30 | Y | 科目 | STEP2/3：由 `LE_AGE_FLAG` 映射，AR→1122000000、OR→122101F、AS→1123000000、CA→1460000000、RF→1124001000、AP→2202000000、OP→224199F、AC→2203000000、CL→2204000000、A9→1910000A70、A10→1531000000；源头取 `dwd_fi_mr_arap_sum_mi.acct_map_code` |
| COD_CATEGORIA | VARCHAR2 | 30 | Y | 类别 | ZAMOUNT；出库/退货路：ZAMOUNT；超期款路：ZAMOUNT |
| SRC_DETAIL | VARCHAR2 | 100 | Y | 数据分类 | 直接对应 dwd_fi_mr_arap_sum_mi.ods_src；出库/退货路：AW_MR9_REVM01_000001 COD_CONTO 如果是S600101%则ZTSO04_CK-出库未开，如果是S600102%则ZTSO04_TH-退货未办；超期款路：dwd_fi_mr_ar_overdue_mi 取overdue_amt金额时，放overdue-超期款 取inv_sample_amt金额时，放inv_sample-开票样机额度 |
| CUST_CODE | VARCHAR2 | 30 | Y | 客商编码 | 直接对应 dwd_fi_mr_arap_sum_mi.cust_code；出库/退货路：AW_MR9_REVM01_000001 cust_code 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi cust_code 直接对应 |
| CUST_NAME | VARCHAR2 | 200 | Y | 客商名称 | 直接对应 dwd_fi_mr_arap_sum_mi.cust_name；出库/退货路：AW_MR9_REVM01_000001 cust_name 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi cust_name 直接对应 |
| CUST_HEAD_CODE | VARCHAR2 | 30 | Y | 主户编码 | 直接对应 dwd_fi_mr_arap_sum_mi.cust_head_code |
| CUST_HEAD_NAME | VARCHAR2 | 200 | Y | 主户名称 | 直接对应 dwd_fi_mr_arap_sum_mi.cust_head_name |
| CUST_BRANCH_CODE | VARCHAR2 | 20 | Y | 分户编码 | 直接对应 dwd_fi_mr_arap_sum_mi.cust_branch_code |
| CUST_BRANCH_NAME | VARCHAR2 | 200 | Y | 分户名称 | 直接对应 dwd_fi_mr_arap_sum_mi.cust_branch_name |
| COD_AZI_CTP | VARCHAR2 | 30 | Y | 对方公司 | 直接对应 dwd_fi_mr_arap_sum_mi.cp_company_code；出库/退货路：AW_MR9_REVM01_000001 COD_AZI_CTP 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi cp_company_code 直接对应 |
| COUNTRY_CODE | VARCHAR2 | 8 | Y | 国家编码 | 直接对应 dwd_fi_mr_arap_sum_mi.country_code |
| COUNTRY_NAME | VARCHAR2 | 200 | Y | 国家名称 | 直接对应 dwd_fi_mr_arap_sum_mi.country_name |
| ACCT_SRC_CODE | VARCHAR2 | 30 | Y | 原始科目编码 | 直接对应 dwd_fi_mr_arap_sum_mi.acct_src_code；超期款路：dwd_fi_mr_ar_overdue_mi acct_src_code 直接对应 |
| ACCT_REC_CODE | VARCHAR2 | 30 | Y | 重分类科目编码 | 根据原始科目判断合并 |
| ACCT_MAP_CODE | VARCHAR2 | 30 | Y | 映射后科目编码 | 直接对应 dwd_fi_mr_arap_sum_mi.acct_map_code |
| LE_AGE_FLAG | VARCHAR2 | 10 | Y | 法人单体账龄标识 | STEP2/3：重分类函数 `F_APAR_REC`：按 系统号+公司+科目范围+主户 匹配，判断同一账套+主户编码下 数据分类为 BS% 和总账标识（FAGLFLEXT/GLFUNCT）的 bcy_amt 汇总是否符合金额条件，输出【重分类标识】 |
| ME_AGE_FLAG | VARCHAR2 | 10 | Y | 管理单体账龄标识 | STEP2/3：重分类函数 `F_APAR_REC`：口径同法人，但汇总范围额外包含 `ZTSO04%`（出库未开/退货未办） |
| MB_AGE_FLAG | VARCHAR2 | 10 | Y | 管理分公司账龄标识 | STEP2/3：重分类函数 `F_APAR_REC`：口径同管理单体，且汇总粒度增加【利润中心】 |
| GRP_SCOPE | VARCHAR2 | 30 | Y | 集团归属范围（ 子公司/集团内/集团外） | STEP2/3：按场景期间公司取视图 `V_APAR_ELEM_NODE_TAB` 得到 node（日立公司取 nodes）与 hq，再用对方公司匹配该视图：node 与 hq 均相等 → `SUB-子公司`；仅 hq 相等 → `GIN-集团内`；其余 → `GEX-集团外` |
| D_CHANNEL | VARCHAR2 | 30 | Y | 三级公司分类编码 | 直接对应 dwd_fi_mr_arap_sum_mi.channel_l3_code；出库/退货路：AW_MR9_REVM01_000001 D_CHANNEL 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi channel_l3_code 直接对应 |
| D_ONOFFLINE | VARCHAR2 | 30 | Y | 渠道分组编码 | 直接对应 dwd_fi_mr_arap_sum_mi.onoffline_code；出库/退货路：AW_MR9_REVM01_000001 D_ONOFFLINE 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi onoffline_code 直接对应 |
| COD_DEST2 | VARCHAR2 | 30 | Y | 利润中心编码 | 直接对应 dwd_fi_mr_arap_sum_mi.profitcenter_code；出库/退货路：AW_MR9_REVM01_000001 COD_DEST2 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi profitcenter_code 直接对应 |
| COD_DEST3 | VARCHAR2 | 30 | Y | 业务范围编码 | 直接对应 dwd_fi_mr_arap_sum_mi.bus_range_code；出库/退货路：AW_MR9_REVM01_000001 COD_DEST3 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi bus_range_code 直接对应 |
| D_SALE_DEPT | VARCHAR2 | 30 | Y | 业务管理单元编码 | 直接对应 dwd_fi_mr_arap_sum_mi.marketing_dept_code；出库/退货路：AW_MR9_REVM01_000001 D_SALE_DEPT 直接对应；超期款路：dwd_fi_mr_ar_overdue_mi marketing_dept_code 直接对应 |
| D_TOV_CHAN | VARCHAR2 | 30 | Y | 周转分析渠道 | 直接对应 dwd_fi_mr_arap_sum_mi.tov_channel_code |
| D_CC_CUSTGRP | VARCHAR2 | 30 | Y | 商冷客户群 | 直接对应 dwd_fi_mr_arap_sum_mi.cc_cust_group_code |
| COD_VALUTA | VARCHAR2 | 30 | Y | 本位币币种 | 直接对应 dwd_fi_mr_arap_sum_mi.bcy_code；出库/退货路：AW_MR9_REVM01_000001 COD_VALUTA 直接对应；超期款路：直接对应 |
| COD_VALUTA_ORIGINARIA | VARCHAR2 | 5 | Y | 交易币币种 | 直接对应 dwd_fi_mr_arap_sum_mi.qcy_code；出库/退货路：CNY；超期款路：CNY |
| BCY_0_AMT | NUMBER | 27,9 | Y | 本位币金额-本月账龄 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_0_AMT；出库/退货路：AW_MR9_REVM01_000001 BCY_REV 汇总同一维度的BCY_REV金额数；超期款路：dwd_fi_mr_ar_overdue_mi overdue_amt inv_sample_amt overdue_amt inv_sample_amt 分两行数据展示 |
| BCY_1_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段1 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_1_AMT；出库/退货路：AW_MR9_REVM01_000001 BCY_REV 汇总同一维度的BCY_REV金额数；超期款路：dwd_fi_mr_ar_overdue_mi overdue_amt inv_sample_amt overdue_amt inv_sample_amt 分两行数据展示 |
| BCY_2_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段2 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_2_AMT |
| BCY_3_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段3 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_3_AMT |
| BCY_4_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段4 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_4_AMT |
| BCY_5_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段5 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_5_AMT |
| BCY_6_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段6 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_6_AMT |
| BCY_7_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段7 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_7_AMT |
| BCY_8_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段8 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_8_AMT |
| BCY_9_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段9 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_9_AMT |
| BCY_10_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段10 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_10_AMT |
| BCY_11_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段11 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_11_AMT |
| BCY_12_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段12 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_12_AMT |
| BCY_13_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段13 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_13_AMT |
| BCY_14_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段14 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_14_AMT |
| BCY_15_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段15 | 直接对应 dwd_fi_mr_arap_sum_mi.BCY_15_AMT |
| QCY_0_AMT | NUMBER | 27,9 | Y | 交易币金额-本月账龄 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_0_AMT；出库/退货路：AW_MR9_REVM01_000001 ORG_REV 汇总同一维度的ORG_REV金额数；超期款路：dwd_fi_mr_ar_overdue_mi overdue_amt inv_sample_amt overdue_amt inv_sample_amt 分两行数据展示 |
| QCY_1_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段1 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_1_AMT；出库/退货路：AW_MR9_REVM01_000001 ORG_REV 汇总同一维度的ORG_REV金额数；超期款路：dwd_fi_mr_ar_overdue_mi overdue_amt inv_sample_amt overdue_amt inv_sample_amt 分两行数据展示 |
| QCY_2_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段2 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_2_AMT |
| QCY_3_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段3 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_3_AMT |
| QCY_4_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段4 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_4_AMT |
| QCY_5_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段5 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_5_AMT |
| QCY_6_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段6 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_6_AMT |
| QCY_7_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段7 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_7_AMT |
| QCY_8_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段8 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_8_AMT |
| QCY_9_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段9 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_9_AMT |
| QCY_10_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段10 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_10_AMT |
| QCY_11_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段11 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_11_AMT |
| QCY_12_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段12 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_12_AMT |
| QCY_13_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段13 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_13_AMT |
| QCY_14_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段14 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_14_AMT |
| QCY_15_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段15 | 直接对应 dwd_fi_mr_arap_sum_mi.QCY_15_AMT |
| SYSTEM_SRC | VARCHAR2 | 150 | Y | 来源系统 | 直接对应 dwd_fi_mr_arap_sum_mi.system_src |
| D_ADJ_TYPE | VARCHAR2 | 30 | Y | 调整类型 | 直接对应 ZZZZ |
| TAX_RATE | NUMBER | 27,9 | Y | 税率 | 直接对应 dwd_fi_mr_arap_sum_mi.TAX_RATE |
| NATURE_L1_NAME | VARCHAR2 | 100 | Y | 一级性质 | 直接对应 dwd_fi_mr_arap_sum_mi.NATURE_L1_NAME |
| NATURE_L2_NAME | VARCHAR2 | 100 | Y | 二级性质 | 直接对应 dwd_fi_mr_arap_sum_mi.NATURE_L2_NAME |
| NATURE_L3_NAME | VARCHAR2 | 100 | Y | 三级性质 | 直接对应 dwd_fi_mr_arap_sum_mi.NATURE_L3_NAME |
| UFEE_UREB_FLAG | VARCHAR2 | 30 | Y | 返利/费用标识 | 直接对应 dwd_fi_mr_arap_sum_mi.UFEE_UREB_FLAG |
| ECLS_FLAG | VARCHAR2 | 30 | Y | 电商零售标识 | 直接对应 dwd_fi_mr_arap_sum_mi.ECLS_FLAG |
| PAY_TERM_CODE | VARCHAR2 | 24 | Y | 付款条件代码 | 直接对应 dwd_fi_mr_arap_sum_mi.PAY_TERM_CODE |
| PAY_TERM_DESC | VARCHAR2 | 300 | Y | 付款条件描述 | 直接对应 dwd_fi_mr_arap_sum_mi.PAY_TERM_DESC |
| EXCHANGE_RATE_EVAL_FLAG | VARCHAR2 | 200 | Y | 汇率评估标识 | 直接对应 dwd_fi_mr_arap_sum_mi.EXCHANGE_RATE_EVAL_FLAG |

**STEP3 重分类补充字段**（ARPM02 引用，STEP1 页未列出，取自 STEP3 页）：

| 字段名 | 类型 | 长度/精度 | 可空 | 含义 | 取数来源与规则 |
|--------|------|-----------|------|------|----------------|
| IS_REC_LG | VARCHAR2 | 5 | Y | 是否重分类_法人 | 重分类函数 `F_APAR_REC`：按 系统号+公司+科目范围+主户 匹配，判断同一账套+主户编码下数据分类为 BS% 和总账标识（FAGLFLEXT/GLFUNCT）的 bcy_amt 汇总是否符合金额条件，输出【是否重分类】 |
| IS_REC_ME | VARCHAR2 | 5 | Y | 是否重分类_管理 | 同 `IS_REC_LG`，汇总范围额外包含 `ZTSO04%` |
| IS_REC_MB | VARCHAR2 | 5 | Y | 是否重分类_管理分公司 | 同 `IS_REC_ME`，汇总粒度增加【利润中心】 |

> **注1**: `ACCT_REC_CODE`（重分类科目编码）按原始科目判断合并，核心规则：`ACCT_SRC_CODE LIKE '1466%' → `1466000000`；公司 `6500/6510` 且原始科目 `2241010100/2241010200/2241020000/2241040000` → `2241010100`。
> **注2**: `D_ADJ_TYPE`（调整类型）默认填 `ZZZZ`；`COD_CATEGORIA`（类别）各路统一填 `ZAMOUNT`。
> **注3**: 出库/退货路（来源②）金额汇总自 `AW_MR9_REVM01_000001` 的 `BCY_REV`（本位币）/`ORG_REV`（交易币），按同一维度聚合；`SRC_DETAIL` 由 `COD_CONTO` 判断，S600101% → `ZTSO04_CK-出库未开`，S600102% → `ZTSO04_TH-退货未办`。
> **注4**: 超期款路（来源③）同一金额拆两行展示：`overdue_amt` → `overdue-超期款`，`inv_sample_amt` → `inv_sample-开票样机额度`；该路仅提供 `BCY_0_AMT`/`QCY_0_AMT`（本月账龄段），其余账龄段不适用。
> **注5**: 提前回款路（来源④）`SRC_DETAIL` 固定 `epay-提前回款`，核心过滤为 `ods_src` 属 bsid/bsad 且 `pay_reason_code=400`、`acct_map_code` 为 1122%，并按 `baseline_dt` 判断；电商零售路（来源⑤）固定 `ECLS-电商零售` 且排除《电商零售客户》范围内客户。

#### AW_MR9_ARPM02_000001
**说明**: 往来账龄结果表；DWM 层，将计算底稿 `AW_MR9_ARPM01_000001` 中不同数据分类的数据平铺到列上展示，并对应收重分类到合同负债的数据剔除对应税额
**存储过程**: `CPM_SP_M2M_ARP_AG_M`
**数仓分层**: DWM ｜ **表类型**: 事实表 ｜ **更新方式**: 增量更新 ｜ **数仓目录**: 管理财经 → 财报管理 → 应收
**参数**: 场景 `P_SCENARIO`、期间 `P_PERIODO`、公司 `P_AZIENDA`、用户 `SESSION_USER`
**源表**: `AW_MR9_ARPM01_000001`（往来账龄计算底稿）
**核心口径**: ①本月账龄金额对 `LE_AGE_FLAG` 为 CL 且 `IS_REC_LG` 为 Y 的行，取 `SRC_DETAIL` 为 `ORG%` 的数据 `/(1+TAX_RATE)` 剔除税额；②年初/上月余额按 公司+科目+客商+利润中心 全量匹配本表对应场景期间取 `BCY_0_AMT`，本月无而年初/上月有的，其余字段取年初/上月信息；③各类专项金额（出库未开、退货未办、超期款、开票样机、提前回款、电商零售、欠付返利、欠付费用）按 科目+客户+利润中心 匹配到同一行

| 字段名 | 类型 | 长度/精度 | 可空 | 含义 | 取数来源与规则 |
|--------|------|-----------|------|------|----------------|
| COD_SCENARIO | VARCHAR2 | 15 | N | 场景 | 直接对应 AW_MR9_ARPM01_000001.COD_SCENARIO |
| COD_PERIODO | VARCHAR2 | 2 | Y | 期间 | 直接对应 AW_MR9_ARPM01_000001.COD_PERIODO |
| COD_AZIENDA | VARCHAR2 | 30 | Y | 公司 | 直接对应 AW_MR9_ARPM01_000001.COD_AZIENDA |
| COD_CONTO | VARCHAR2 | 30 | Y | 科目 | 直接对应 AW_MR9_ARPM01_000001.COD_CONTO |
| COD_CATEGORIA | VARCHAR2 | 30 | Y | 类别 | ZAMOUNT |
| CUST_CODE | VARCHAR2 | 30 | Y | 客商编码 | 直接对应 AW_MR9_ARPM01_000001.CUST_CODE |
| CUST_NAME | VARCHAR2 | 200 | Y | 客商名称 | 直接对应 AW_MR9_ARPM01_000001.CUST_NAME |
| CUST_HEAD_CODE | VARCHAR2 | 30 | Y | 主户编码 | 直接对应 AW_MR9_ARPM01_000001.CUST_HEAD_CODE |
| CUST_HEAD_NAME | VARCHAR2 | 200 | Y | 主户名称 | 直接对应 AW_MR9_ARPM01_000001.CUST_HEAD_NAME |
| CUST_BRANCH_CODE | VARCHAR2 | 20 | Y | 分户编码 | 直接对应 AW_MR9_ARPM01_000001.CUST_BRANCH_CODE |
| CUST_BRANCH_NAME | VARCHAR2 | 200 | Y | 分户名称 | 直接对应 AW_MR9_ARPM01_000001.CUST_BRANCH_NAME |
| COD_AZI_CTP | VARCHAR2 | 30 | Y | 对方公司 | 直接对应 AW_MR9_ARPM01_000001.COD_AZI_CTP |
| COUNTRY_CODE | VARCHAR2 | 8 | Y | 国家编码 | 直接对应 AW_MR9_ARPM01_000001.COUNTRY_CODE |
| COUNTRY_NAME | VARCHAR2 | 200 | Y | 国家名称 | 直接对应 AW_MR9_ARPM01_000001.COUNTRY_NAME |
| ACCT_SRC_CODE | VARCHAR2 | 30 | Y | 原始科目编码 | 直接对应 AW_MR9_ARPM01_000001.ACCT_SRC_CODE |
| LE_AGE_FLAG | VARCHAR2 | 10 | Y | 法人单体账龄标识 | 直接对应 AW_MR9_ARPM01_000001.LE_AGE_FLG |
| IS_REC_LG | VARCHAR2 | 5 | Y | 是否重分类_法人 | 直接对应 AW_MR9_ARPM01_000001.IS_REC_LG |
| ME_AGE_FLAG | VARCHAR2 | 10 | Y | 管理单体账龄标识 | 直接对应 AW_MR9_ARPM01_000001.ME_AGE_FLG |
| IS_REC_ME | VARCHAR2 | 5 | Y | 是否重分类_管理 | 直接对应 AW_MR9_ARPM01_000001.IS_REC_ME |
| MB_AGE_FLAG | VARCHAR2 | 10 | Y | 管理分公司账龄标识 | 直接对应 AW_MR9_ARPM01_000001.MB_AGE_FLG |
| IS_REC_MB | VARCHAR2 | 5 | Y | 是否重分类_管理分公司 | 直接对应 AW_MR9_ARPM01_000001.IS_REC_MB |
| GRP_SCOPE | VARCHAR2 | 30 | Y | 集团归属范围（ 子公司/集团内/集团外） | 直接对应 AW_MR9_ARPM01_000001.GRP_SCOPE |
| NATURE_L1_NAME | VARCHAR2 | 2000 | Y | 一级性质 | 直接对应 AW_MR9_ARPM01_000001.NATURE_L1_NAME |
| NATURE_L2_NAME | VARCHAR2 | 2000 | Y | 二级性质 | 直接对应 AW_MR9_ARPM01_000001.NATURE_L2_NAME |
| NATURE_L3_NAME | VARCHAR2 | 2000 | Y | 三级性质 | 直接对应 AW_MR9_ARPM01_000001.NATURE_L3_NAME |
| D_CHANNEL | VARCHAR2 | 30 | Y | 三级公司分类编码 | 直接对应 AW_MR9_ARPM01_000001.D_CHANNEL |
| D_ONOFFLINE | VARCHAR2 | 30 | Y | 渠道分组编码 | 直接对应 AW_MR9_ARPM01_000001.D_ONOFFLINE |
| COD_DEST2 | VARCHAR2 | 30 | Y | 利润中心编码 | 直接对应 AW_MR9_ARPM01_000001.COD_DEST2 |
| COD_DEST3 | VARCHAR2 | 30 | Y | 业务范围编码 | 直接对应 AW_MR9_ARPM01_000001.COD_DEST3 |
| D_SALE_DEPT | VARCHAR2 | 30 | Y | 业务管理单元编码 | 直接对应 AW_MR9_ARPM01_000001.D_SALE_DEPT |
| TAX_RATE | VARCHAR2 | 30 | Y | 税率 | 直接对应 AW_MR9_ARPM01_000001.TAX_RATE |
| COD_VALUTA | VARCHAR2 | 30 | Y | 本位币币种 | 直接对应 AW_MR9_ARPM01_000001.COD_VALUTA |
| COD_VALUTA_ORIGINARIA | VARCHAR2 | 5 | Y | 交易币币种 | 直接对应 AW_MR9_ARPM01_000001.COD_VALUTA_ORIGINARIA |
| BY_BCY_0_AMT | NUMBER | 27,9 | Y | 年初-本位币余额 | AW_MR9_ARPM02_000001年初的场景期间，根据公司+科目+客商+利润中心匹配取BCY_0_AMT，全量匹配，如果本月没有，年初有，则其他字段取年初的信息 |
| LM_BCY_0_AMT | NUMBER | 27,9 | Y | 上月-本位币余额 | AW_MR9_ARPM02_000001上月的场景期间，根据公司+科目+客商+利润中心匹配取BCY_0_AMT，全量匹配，如果本月没有，上月有，则其他字段取上月的信息 |
| BCY_0_AMT | NUMBER | 27,9 | Y | 本位币金额-本月账龄 | 判断le_age_flg为CL且IS_REC_LG为Y的，取SRC_DETAIL为ORG%的数据/（1+tax_rate）；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| BCY_1_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段1 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT1 |
| BCY_2_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段2 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT2 |
| BCY_3_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段3 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT3 |
| BCY_4_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段4 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT4 |
| BCY_5_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段5 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT5 |
| BCY_6_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段6 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT6 |
| BCY_7_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段7 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT7 |
| BCY_8_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段8 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT8 |
| BCY_9_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段9 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT9 |
| BCY_10_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段10 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT10 |
| BCY_11_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段11 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT11 |
| BCY_12_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段12 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT12 |
| BCY_13_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段13 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT13 |
| BCY_14_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段14 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT14 |
| BCY_15_AMT | NUMBER | 27,9 | Y | 本位币金额-账龄区间段15 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT15 |
| QCY_0_AMT | NUMBER | 27,9 | Y | 交易币金额-本月账龄 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT0 |
| QCY_1_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段1 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT1 |
| QCY_2_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段2 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT2 |
| QCY_3_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段3 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT3 |
| QCY_4_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段4 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT4 |
| QCY_5_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段5 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT5 |
| QCY_6_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段6 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT6 |
| QCY_7_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段7 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT7 |
| QCY_8_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段8 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT8 |
| QCY_9_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段9 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT9 |
| QCY_10_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段10 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT10 |
| QCY_11_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段11 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT11 |
| QCY_12_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段12 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT12 |
| QCY_13_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段13 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT13 |
| QCY_14_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段14 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT14 |
| QCY_15_AMT | NUMBER | 27,9 | Y | 交易币金额-账龄区间段15 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.QCY_AMT15 |
| SHP_NINV_AMT | NUMBER | 27,9 | Y | 出库未开金额 | 取SRC_DETAIL为ZSTO04_CK%的数据，根据科目+客户+利润中心匹配到同一行；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| RET_NTRF_AMT | NUMBER | 27,9 | Y | 退货未办退税金额 | 取SRC_DETAIL为ZTSO04_TH%的数据，根据科目+客户+利润中心匹配到同一行；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| BCY_ADJ_INCL_0_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-本月账龄 | 判断le_age_flg为CL且IS_REC_LG为N的，取SRC_DETAIL为ORG%的数据*（1+tax_rate）+shp_ninv_amt-ret_ntrf_amt 其余取SRC_DETAIL为ORG%的数据+shp_ninv_amt-ret_ntrf_amt；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| BCY_ADJ_INCL_1_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段1 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT1 |
| BCY_ADJ_INCL_2_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段2 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT2 |
| BCY_ADJ_INCL_3_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段3 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT3 |
| BCY_ADJ_INCL_4_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段4 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT4 |
| BCY_ADJ_INCL_5_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段5 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT5 |
| BCY_ADJ_INCL_6_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段6 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT6 |
| BCY_ADJ_INCL_7_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段7 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT7 |
| BCY_ADJ_INCL_8_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段8 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT8 |
| BCY_ADJ_INCL_9_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段9 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT9 |
| BCY_ADJ_INCL_10_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段10 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT10 |
| BCY_ADJ_INCL_11_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段11 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT11 |
| BCY_ADJ_INCL_12_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段12 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT12 |
| BCY_ADJ_INCL_13_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段13 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT13 |
| BCY_ADJ_INCL_14_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段14 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT14 |
| BCY_ADJ_INCL_15_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后含税-账龄区间段15 | 同本月账龄处理逻辑；← AW_MR9_ARPM01_000001.BCY_AMT15 |
| BCY_ADJ_EXCL_0_AMT | NUMBER | 27,9 | Y | 本位币金额-调整后不含税-本月账龄 | 判断me_age_flg为CL且IS_REC_ME为N的，取SRC_DETAIL为ORG%的数据+shp_ninv_amt-ret_ntrf_amt me_age_flg为CL且IS_REC_ME为Y的，SRC_DETAIL为ORG%的数据/（1+tax_rate）+shp_ninv_amt-ret_ntrf_amt；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| overdue_0_amt | NUMBER | 27,9 | Y | 超期款金额 | 取SRC_DETAIL为overdue%的数据，根据科目+客户+利润中心匹配到同一行 |
| overdue_1_amt | NUMBER | 27,9 | Y | 超期款金额-1个月以内 | 取SRC_DETAIL为overdue%的数据，根据科目+客户+利润中心匹配到同一行；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| overdue_2_amt | NUMBER | 27,9 | Y | 超期款金额-2-3个月 | 置空；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| overdue_3_amt | NUMBER | 27,9 | Y | 超期款金额-4-6个月 | 置空 |
| overdue_4_amt | NUMBER | 27,9 | Y | 超期款金额-7-12个月 | 置空 |
| overdue_5_amt | NUMBER | 27,9 | Y | 超期款金额-1-2年 | 置空 |
| overdue_6_amt | NUMBER | 27,9 | Y | 超期款金额-2-3年 | 置空 |
| overdue_7_amt | NUMBER | 27,9 | Y | 超期款金额-3-4年 | 置空 |
| overdue_8_amt | NUMBER | 27,9 | Y | 超期款金额-4-5年 | 置空 |
| overdue_9_amt | NUMBER | 27,9 | Y | 超期款金额-5年以上 | 置空 |
| INV_SAMPLE_AMT | NUMBER | 27,9 | Y | 开票样机金额 | 取SRC_DETAIL为inv_sample%的数据，根据科目+客户+利润中心匹配到同一行；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| EPAY_AMT | NUMBER | 27,9 | Y | 提前回款金额 | 取SRC_DETAIL为epay%的数据，根据科目+客户+利润中心匹配到同一行；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| ECLS_AMT | NUMBER | 27,9 | Y | 电商零售金额 | 取SRC_DETAIL为ECLS%的数据，根据科目+客户+利润中心匹配到同一行；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| UREB_AMT | NUMBER | 27,9 | Y | 欠付返利余额 | 取SRC_DETAIL为ufee%的数据，根据科目+客户+利润中心匹配到同一行；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| UFEE_AMT | NUMBER | 27,9 | Y | 欠付费用金额 | 取SRC_DETAIL为ureb%的数据，根据科目+客户+利润中心匹配到同一行；← AW_MR9_ARPM01_000001.BCY_AMT0 |
| PAY_TERM_CODE | VARCHAR2 | 300 | Y | 付款条件代码 | 直接对应 AW_MR9_ARPM01_000001.PAY_TERM_CODE |
| PAY_TERM_DESC | VARCHAR2 | 2000 | Y | 付款条件描述 | 直接对应 AW_MR9_ARPM01_000001.PAY_TERM_DESC |
| CLOSING_RATE_BCY_AMT | NUMBER | 27,9 | Y | 期末汇率余额 | 1、非2023公司： 交易币且本位币<>CNY， 根据交易币计算折算成本位币的汇率，汇率取系统的汇率表中的最终汇率；保留5位小数，用汇率*交易币金额 2、2023公司： 根据交易币计算折算成本位币的汇率，汇率取SAP-TCURR的汇率，用汇率*交易币金额 3、其他：根据交易币计算折算成本位币的汇率，汇率取系统的汇率表中的最终汇率；用汇率*交易币金额；← DATI_CAMBIO ODS.ODSS600_TCURR@FMSLK.CAMBIO_FINALE UKURS*(CASE WHEN TCURR='VND' AND FCURR IN ('USD') THEN 1000 WHEN TCURR='VND' THEN 100 ELSE 1… |
| POSTING_RATE_BCY_AMT | NUMBER | 27,9 | Y | 记账汇率余额 | 直接对应 AW_MR9_ARPM01_000001.BCY_0_AMT |
| EXCHANGE_RATE_EVAL_FLAG | VARCHAR2 | 200 | Y | 汇率评估标识 | 直接对应 AW_MR9_ARPM01_000001.EXCHANGE_RATE_EVAL_FLAG |
| TH_FX_EVAL_AMT | NUMBER | 27,9 | Y | 理论汇兑评估金额 | BCY_AMT0 - posting_rate_bcy_amt |
| CURRENCY_ACCT_DETAIL | VARCHAR2 | 200 | Y | 币种科目构成明细 | 格式为：【法人分类标识:本币余额\原币:原币余额;】；← AW_MR9_ARPM01_000001.LISTAGG(LE_AGE_FLG // ':' // BCY_0_AMT// '\' // COD_VALUTA_ORIGINARIA // ':' // QCY_0_AMT, ';') WITHIN GROUP (ORDER BY LE_AGE_FLG, BCY_0_AMT) |
| ADJ_REB_AMT | NUMBER | 27,9 | Y | 调整后返利金额 | UREB_AMT - MIN(BCY_AMT0/UREB_AMT) |
| ADJ_RET_AMT | NUMBER | 27,9 | Y | 调整后退货金额 | MIN(BCY_AMT0/ret_ntrf_amt) |

> **注1**: `CURRENCY_ACCT_DETAIL`（币种科目构成明细）格式为 `【法人分类标识:本币余额\原币:原币余额;】`，实现为 `LISTAGG(LE_AGE_FLG || ':' || BCY_0_AMT || '\' || COD_VALUTA_ORIGINARIA || ':' || QCY_0_AMT, ';') WITHIN GROUP (ORDER BY LE_AGE_FLG, BCY_0_AMT)`。
> **注2**: `TH_FX_EVAL_AMT`（理论汇兑评估金额）= `BCY_0_AMT - POSTING_RATE_BCY_AMT`。
> **注3**: `CLOSING_RATE_BCY_AMT`（期末汇率余额）：2023 公司取 SAP `ODS.ODSS600_TCURR@FMSLK` 的 `UKURS`（TCURR=VND 且 FCURR=USD 时 ×1000，TCURR=VND 其他时 ×100）；其余公司取 `DATI_CAMBIO.CAMBIO_FINALE`；交易币且本位币非 CNY 时按交易币折算本位币后保留 5 位小数。
> **注4**: `overdue_2_amt` ～ `overdue_9_amt`（超期款 2-3个月 至 5年以上）当前规则为**置空**，仅 `overdue_0_amt`/`overdue_1_amt` 取数。
> **注5**: `UFEE_AMT`（欠付费用金额）取 `SRC_DETAIL` 为 **`ureb%`** 的数据，`UREB_AMT`（欠付返利余额）取 `SRC_DETAIL` 为 **`ufee%`** 的数据，两字段 SRC_DETAIL 前缀为交叉对应，按设计文档原样保留，开发时需重点核对。
> **注6**: `ADJ_REB_AMT`（调整后返利金额）= `UREB_AMT - MIN(BCY_AMT0 / UREB_AMT)`；`ADJ_RET_AMT`（调整后退货金额）= `MIN(BCY_AMT0 / ret_ntrf_amt)`。
> **注7**: `LE/ME/MB_AGE_FLAG` 在底稿中字段名为 `LE_AGE_FLG`/`ME_AGE_FLG`/`MB_AGE_FLG`，到本表统一改为 `_FLAG` 后缀。