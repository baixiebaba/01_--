/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:35
 * 本次修改：ALTER BY 20261102 17:35 SHIQINGFENG.EX 精简查询说明文件头：删除功能描述、宿主表、展示逻辑行，改为查询名称+源表版式，未修改业务主体。
 * 上次修改：ALTER BY 20261102 17:26 SHIQINGFENG.EX 将公司参数筛选由等值判断统一为 IN 写法，并统一 Query 排版，未修改其他逻辑。
 *
 * 查询名称  ：坏账计提结果表-坏账计提基数表
 * 源表      ：AW_MR9_ARPM02_000001
 *
 * 修改历史：
 *   ALTER BY 20261102 17:35 SHIQINGFENG.EX 精简查询说明文件头：删除功能描述、宿主表、展示逻辑行，改为查询名称+源表版式，未修改业务主体。
 *   ALTER BY 20261102 17:26 SHIQINGFENG.EX 将公司参数筛选由等值判断统一为 IN 写法，并统一 Query 排版，未修改其他逻辑。
 *******************************************************************************/
SELECT COD_SCENARIO                             /* 场景 */
     , COD_PERIODO                                   /* 期间 */
     , COD_AZIENDA                                   /* 公司 */
     , A.COD_CONTO                                   /* 科目 */
     , DESC_CONTO1                                   /* 科目名称 */
     , CUST_CODE                                     /* 客商编码 */
     , CUST_NAME                                     /* 客商名称 */
     , CUST_HEAD_CODE                                /* 主户编码 */
     , CUST_HEAD_NAME                                /* 主户名称 */
     , CUST_BRANCH_CODE                              /* 分户编码 */
     , CUST_BRANCH_NAME                              /* 分户名称 */
     , GRP_SCOPE                                     /* 集团归属范围（ profitcenter_code,varchar(30),利润中心编码 cod_dest2,varchar(30),利润中心编码 onoffline_code,varchar(30),渠道分组编码 d_onoffline,varchar(30),渠道分组编码 channel_l3_code,varchar(30),三级公司分类编码 d_channel,varchar(30),三级公司分类编码 bus_range_code,varchar(30),业务范围编码 bcy_0_amt,number(27 */
     , D_ONOFFLINE                                   /* 渠道分组编码 */
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', D_ONOFFLINE) AS D_ONOFFLINE_DESC /* 渠道分组名称 */
     , COD_DEST2                                     /* 利润中心编码 */
     , F_TGK_GET_DIMNAME('DEST2', COD_DEST2) AS COD_DEST2_DESC /* 利润中心名称 */
     , COD_DEST3                                     /* 业务范围编码 */
     , F_TGK_GET_DIMNAME('DEST3', COD_DEST3) AS COD_DEST3_DESC /* 业务范围名称 */
     , D_SALE_DEPT                                   /* 业务管理单元编码 */
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', D_SALE_DEPT) AS D_SALE_DEPT_DESC /* 业务管理单元名称 */
     , BCY_ADJ_INCL_0_AMT                            /* 本位币金额-调整后含税-本月账龄 */
     , BCY_ADJ_INCL_1_AMT                            /* 本位币金额-调整后含税-账龄区间段1 */
     , BCY_ADJ_INCL_2_AMT                            /* 本位币金额-调整后含税-账龄区间段2 */
     , BCY_ADJ_INCL_3_AMT                            /* 本位币金额-调整后含税-账龄区间段3 */
     , BCY_ADJ_INCL_4_AMT                            /* 本位币金额-调整后含税-账龄区间段4 */
     , BCY_ADJ_INCL_5_AMT                            /* 本位币金额-调整后含税-账龄区间段5 */
     , BCY_ADJ_INCL_6_AMT                            /* 本位币金额-调整后含税-账龄区间段6 */
     , BCY_ADJ_INCL_7_AMT                            /* 本位币金额-调整后含税-账龄区间段7 */
     , BCY_ADJ_INCL_8_AMT                            /* 本位币金额-调整后含税-账龄区间段8 */
     , BCY_ADJ_INCL_9_AMT                            /* 本位币金额-调整后含税-账龄区间段9 */
     , BCY_ADJ_INCL_10_AMT                           /* 本位币金额-调整后含税-账龄区间段10 */
     , BCY_ADJ_INCL_11_AMT                           /* 本位币金额-调整后含税-账龄区间段11 */
     , BCY_ADJ_INCL_12_AMT                           /* 本位币金额-调整后含税-账龄区间段12 */
     , BCY_ADJ_INCL_13_AMT                           /* 本位币金额-调整后含税-账龄区间段13 */
     , BCY_ADJ_INCL_14_AMT                           /* 本位币金额-调整后含税-账龄区间段14 */
     , BCY_ADJ_INCL_15_AMT                           /* 本位币金额-调整后含税-账龄区间段15 */
     , BCY_ADJ_INCL_0_AMT - BCY_ADJ_INCL_1_AMT - BCY_ADJ_INCL_2_AMT - BCY_ADJ_INCL_3_AMT
       - BCY_ADJ_INCL_4_AMT - BCY_ADJ_INCL_5_AMT - BCY_ADJ_INCL_6_AMT - BCY_ADJ_INCL_7_AMT
       - BCY_ADJ_INCL_8_AMT - BCY_ADJ_INCL_9_AMT - BCY_ADJ_INCL_10_AMT - BCY_ADJ_INCL_11_AMT
       - BCY_ADJ_INCL_12_AMT - BCY_ADJ_INCL_13_AMT - BCY_ADJ_INCL_14_AMT - BCY_ADJ_INCL_15_AMT AS CHECK1  /* 校验：调整后含税总额减各分段合计 */
     , SPC_DSV_DED_AMT                               /* 特殊调整项-直销垫资扣减金额 */
     , SPC_REB_DED_AMT                               /* 特殊调整项-返利扣减金额 */
     , BD_BASE_0_AMT                                 /* 坏账计提基数金额 */
     , BD_BASE_1_AMT                                 /* 坏账计提基数-账龄区间段1 */
     , BD_BASE_2_AMT                                 /* 坏账计提基数-账龄区间段2 */
     , BD_BASE_3_AMT                                 /* 坏账计提基数-账龄区间段3 */
     , BD_BASE_4_AMT                                 /* 坏账计提基数-账龄区间段4 */
     , BD_BASE_5_AMT                                 /* 坏账计提基数-账龄区间段5 */
     , BD_BASE_6_AMT                                 /* 坏账计提基数-账龄区间段6 */
     , BD_BASE_7_AMT                                 /* 坏账计提基数-账龄区间段7 */
     , BD_BASE_8_AMT                                 /* 坏账计提基数-账龄区间段8 */
     , BD_BASE_9_AMT                                 /* 坏账计提基数-账龄区间段9 */
     , BD_BASE_10_AMT                                /* 坏账计提基数-账龄区间段10 */
     , BD_BASE_11_AMT                                /* 坏账计提基数-账龄区间段11 */
     , BD_BASE_12_AMT                                /* 坏账计提基数-账龄区间段12 */
     , BD_BASE_13_AMT                                /* 坏账计提基数-账龄区间段13 */
     , BD_BASE_14_AMT                                /* 坏账计提基数-账龄区间段14 */
     , BD_BASE_15_AMT                                /* 坏账计提基数-账龄区间段15 */
     , BD_BASE_0_AMT - BD_BASE_1_AMT - BD_BASE_2_AMT - BD_BASE_3_AMT
       - BD_BASE_4_AMT - BD_BASE_5_AMT - BD_BASE_6_AMT - BD_BASE_7_AMT
       - BD_BASE_8_AMT - BD_BASE_9_AMT - BD_BASE_10_AMT - BD_BASE_11_AMT
       - BD_BASE_12_AMT - BD_BASE_13_AMT - BD_BASE_14_AMT - BD_BASE_15_AMT AS CHECK2  /* 校验：坏账基数总额减各分段合计 */
     , A.USERUPD                                     /* 更新用户 */
     , A.DATEUPD                                     /* 更新时间 */
  FROM AW_MR9_ARPM02_000001 A
  LEFT JOIN CONTO
    ON A.COD_CONTO = CONTO.COD_CONTO
 WHERE COD_SCENARIO = ${$Scenario.code}
   AND COD_PERIODO = ${$Period.code}
   AND COD_AZIENDA IN (${$Entity.code})
   AND ME_AGE_FLAG IN ('AR', 'OR', 'CA')
 ORDER BY COD_AZIENDA
        , A.COD_CONTO
