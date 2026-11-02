/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:36
 * 本次修改：ALTER BY 20261102 17:36 SHIQINGFENG.EX 统一查询说明文件头为查询名称+源表精简版式，未修改业务主体。
 * 上次修改：ALTER BY 20261102 16:51 SHIQINGFENG.EX 新增渠道BU编码/名称及商冷客户群编码/名称字段。
 *
 * 查询名称  ：往来账龄明细数据-DWD_FI_MR_ARAP_SUM_MI
 * 源表      ：DWD_FI_MR_ARAP_SUM_MI
 *
 * 修改历史：
 *   ALTER BY 20261102 17:36 SHIQINGFENG.EX 统一查询说明文件头为查询名称+源表精简版式，未修改业务主体。
 *   ALTER BY 20261102 16:51 SHIQINGFENG.EX 新增渠道BU编码/名称及商冷客户群编码/名称字段。
 *******************************************************************************/
SELECT 
      DT_MONTH                 /* 年月 */
    , YEAR                     /* 年份 */
    , MONTH                    /* 月份 */
    , COMPANY_CODE             /* 组织 */
    , CUST_CODE                /* 客商编码 */
    , CUST_NAME                /* 客商名称 */
    , CUST_HEAD_CODE           /* 主户编码 */
    , CUST_HEAD_NAME           /* 主户名称 */
    , CUST_BRANCH_CODE         /* 分户编码 */
    , CUST_BRANCH_NAME         /* 分户名称 */
    , CP_COMPANY_CODE          /* 对方公司 */
    , COUNTRY_CODE             /* 国家编码 */
    , COUNTRY_NAME             /* 国家名称 */
    , ACCT_TYPE_CODE           /* 科目类型：D应收，K应付 */
    , ACCT_SRC_CODE            /* 原始科目编码 */
    , ACCT_MAP_CODE            /* 映射后科目编码 */
    , CHANNEL_L1_CODE          /* 一级公司分类编码 */
    , CHANNEL_L1_NAME          /* 一级公司分类名称 */
    , CHANNEL_L2_CODE          /* 二级公司分类编码 */
    , CHANNEL_L2_NAME          /* 二级公司分类名称 */
    , CHANNEL_L3_CODE          /* 三级公司分类编码 */
    , CHANNEL_L3_NAME          /* 三级公司分类名称 */
    , CHANNEL_BU_CODE          /* 渠道BU编码 */
    , CHANNEL_BU_NAME          /* 渠道BU名称 */
    , CC_CUST_GROUP_CODE       /* 商冷客户群编码 */
    , CC_CUST_GROUP_NAME       /* 商冷客户群名称 */
    , ONOFFLINE_CODE           /* 线上线下编码 */
    , ONOFFLINE_NAME           /* 线上线下名称 */
    , SRC_PROFITCENTER_CODE    /* 原始利润中心编码 */
    , SRC_PROFITCENTER_NAME    /* 原始利润中心名称 */
    , PROFITCENTER_CODE        /* 映射后利润中心编码 */
    , PROFITCENTER_NAME        /* 映射后利润中心名称 */
    , BUS_RANGE_CODE           /* 业务范围编码 */
    , BUS_RANGE_NAME           /* 业务范围名称 */
    , MARKETING_DEPT_CODE      /* 业务管理单元编码 */
    , MARKETING_DEPT_NAME      /* 业务管理单元名称 */
    , PAY_REASON_CODE          /* 付款原因代码 */
    , BCY_CODE                 /* 本位币币种 */
    , QCY_CODE                 /* 交易币币种 */
    , BCY_0_AMT                /* 本位币金额-本月账龄 */
    , BCY_1_AMT                /* 本位币金额- 1个月 */
    , BCY_2_AMT                /* 本位币金额-2-3个月 */
    , BCY_3_AMT                /* 本位币金额-4-6个月 */
    , BCY_4_AMT                /* 本位币金额- 7-12个月 */
    , BCY_5_AMT                /* 本位币金额- 1-2年 */
    , BCY_6_AMT                /* 本位币金额-2-3年 */
    , BCY_7_AMT                /* 本位币金额- 3-4年 */
    , BCY_8_AMT                /* 本位币金额-4-5年 */
    , BCY_9_AMT                /* 本位币金额-5年以上 */
    , BCY_10_AMT               /* 本位币金额-账龄区间段10 */
    , BCY_11_AMT               /* 本位币金额-账龄区间段11 */
    , BCY_12_AMT               /* 本位币金额-账龄区间段12 */
    , BCY_13_AMT               /* 本位币金额-账龄区间段13 */
    , BCY_14_AMT               /* 本位币金额-账龄区间段14 */
    , BCY_15_AMT               /* 本位币金额-账龄区间段15 */
    , QCY_0_AMT                /* 交易币金额-本月账龄 */
    , QCY_1_AMT                /* 交易币金额-1个月 */
    , QCY_2_AMT                /* 交易币金额-2-3个月 */
    , QCY_3_AMT                /* 交易币金额-4-6个月 */
    , QCY_4_AMT                /* 交易币金额- 7-12个月 */
    , QCY_5_AMT                /* 交易币金额- 1-2年 */
    , QCY_6_AMT                /* 交易币金额-2-3年 */
    , QCY_7_AMT                /* 交易币金额- 3-4年 */
    , QCY_8_AMT                /* 交易币金额-4-5年 */
    , QCY_9_AMT                /* 交易币金额-5年以上 */
    , QCY_10_AMT               /* 交易币金额-账龄区间段10 */
    , QCY_11_AMT               /* 交易币金额-账龄区间段11 */
    , QCY_12_AMT               /* 交易币金额-账龄区间段12 */
    , QCY_13_AMT               /* 交易币金额-账龄区间段13 */
    , QCY_14_AMT               /* 交易币金额-账龄区间段14 */
    , QCY_15_AMT               /* 交易币金额-账龄区间段15 */
    , SYSTEM_SRC               /* 来源系统 */
    , ODS_SRC                  /* 数据来源 */
    , REB_TYPE                 /* 返利性质 */
    , UFEE_UREB_FLAG           /* 返利/费用标识 */
    , ECLS_FLAG                /* 电商零售标识 */
    , LEDGER_STATUS            /* 台账状态 */
    , ACCT_CERT_TYPE           /* 凭证类型 */
    , TAX_RATE                 /* 税率 */
    , NATURE_L1_NAME           /* 一级性质 */
    , NATURE_L2_NAME           /* 二级性质 */
    , NATURE_L3_NAME           /* 三级性质 */
    , EXCHANGE_RATE_EVAL_FLAG  /* 汇率评估标识 */
    , IS_APAR_FLAG             /* 账龄是否进数 */
    , PAY_TERM_CODE            /* 付款条件代码 */
    , PAY_TERM_DESC            /* 付款条件描述 */
    , LOAD_DT                  /* 更新时间 */
FROM DWD_FI_MR_ARAP_SUM_MI
WHERE YEAR = ${$Scenario.year}
AND MONTH = ${$Period.code}
AND COMPANY_CODE IN (${$Entity.code})
