/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:35
 * 本次修改：ALTER BY 20261102 17:35 SHIQINGFENG.EX 精简查询说明文件头：删除功能描述、宿主表、展示逻辑行，改为查询名称+源表版式，未修改业务主体。
 * 上次修改：ALTER BY 20261102 17:23 SHIQINGFENG.EX 统一 Query 文件头、关键字大小写、字段缩进和查询条件排版，未修改业务主体。
 *
 * 查询名称  ：国际营销占用数据-DWD_FI_MR_AR_IMOCC_MI
 * 源表      ：TGK_FIMA_DEV.DWD_FI_MR_AR_IMOCC_MI
 *
 * 修改历史：
 *   ALTER BY 20261102 17:35 SHIQINGFENG.EX 精简查询说明文件头：删除功能描述、宿主表、展示逻辑行，改为查询名称+源表版式，未修改业务主体。
 *   ALTER BY 20261102 17:23 SHIQINGFENG.EX 统一 Query 文件头、关键字大小写、字段缩进和查询条件排版，未修改业务主体。
 *******************************************************************************/
SELECT DT_MONTH                /* 年月 */
     , YEAR                    /* 年份 */
     , MONTH                   /* 月份 */
     , COMPANY_SRC_CODE        /* 原始组织 */
     , COMPANY_CODE            /* 组织 */
     , REGION_CODE             /* 大区编码 */
     , REGION_NAME             /* 大区名称 */
     , REGION_FLAG             /* 大区标识 */
     , AREA_GROUP_CODE         /* 区组编码 */
     , AREA_GROUP_NAME         /* 区组名称 */
     , AREA_GROUP_FLAG         /* 区组标识 */
     , BUS_MODEL_CODE          /* 业务模式 */
     , PRODUCT_BIG_CLASS_CODE  /* 产品大类编码 */
     , PRODUCT_BIG_CLASS_NAME  /* 产品大类名称 */
     , PRODUCT_LINE_CODE       /* 产品线编码 */
     , PRODUCT_LINE_NAME       /* 产品线名称 */
     , CUST_PAY_TERM           /* 客户账期编码/描述 */
     , DATA_SCOPE_CODE         /* 范围 */
     , CUST_CODE               /* 客商编码 */
     , CUST_NAME               /* 客商名称 */
     , CUST_BRANCH_CODE        /* 分户编码 */
     , CUST_BRANCH_NAME        /* 分户名称 */
     , CP_COMPANY_CODE         /* 对方公司 */
     , COUNTRY_CODE            /* 国家编码 */
     , COUNTRY_NAME            /* 国家名称 */
     , CHANNEL_L1_CODE         /* 一级公司分类编码 */
     , CHANNEL_L1_NAME         /* 一级公司分类名称 */
     , CHANNEL_L2_CODE         /* 二级公司分类编码 */
     , CHANNEL_L2_NAME         /* 二级公司分类名称 */
     , CHANNEL_L3_CODE         /* 三级公司分类编码 */
     , CHANNEL_L3_NAME         /* 三级公司分类名称 */
     , BUS_RANGE_CODE          /* 业务范围编码 */
     , BUS_RANGE_NAME          /* 业务范围名称 */
     , PROFITCENTER_CODE       /* 利润中心编码 */
     , PROFITCENTER_NAME       /* 利润中心名称 */
     , BCY_CODE                /* 本位币币种 */
     , QCY_CODE                /* 交易币币种 */
     , IMOCC_CNY_AMT           /* 国际营销应收占用金额-人民币 */
     , IMOCC_CON_AMT           /* 国际营销应收占用金额-美元 */
     , IMOCC_USD_AMT           /* 国际营销应收占用金额-本位币 */
     , ODS_SRC                 /* 数据来源 */
     , LOAD_DT                 /* 更新时间 */
  FROM DWD_FI_MR_AR_IMOCC_MI A
 WHERE YEAR = ${$Scenario.year}
   AND MONTH = ${$Period.code}
   AND COMPANY_CODE IN (${$Entity.code})
