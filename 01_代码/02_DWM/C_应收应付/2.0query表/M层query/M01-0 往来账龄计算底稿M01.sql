/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261103 14:08
 * 本次修改：ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。
 * 上次修改：ALTER BY 20261103 14:04 SHIQINGFENG.EX 将公司分类标量子查询改为去重后的 CHANNEL_DIM 关联，未修改业务逻辑。
 *
 * 查询名称  ：往来账龄计算底稿M01
 * 源表      ：AW_MR9_ARPM01_000001、TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。
 *   ALTER BY 20261103 14:04 SHIQINGFENG.EX 将公司分类标量子查询改为去重后的 CHANNEL_DIM 关联，未修改业务逻辑。
 *   ALTER BY 20261102 17:35 SHIQINGFENG.EX 精简查询说明文件头：删除功能描述、宿主表、展示逻辑行，改为查询名称+源表版式，未修改业务主体。
 *   ALTER BY 20261102 17:23 SHIQINGFENG.EX 统一 Query 文件头、关键字大小写、字段逐行排列和查询条件排版，未修改业务主体。
 *******************************************************************************/
WITH
/* 按公司三级分类编码去重，供公司一级、二级分类字段关联，避免明细行被层级表重复记录放大。 */
CHANNEL_DIM AS (
    SELECT C.COD
         , MAX(C.COD_ELEGER6) AS COD_ELEGER6
         , MAX(C.DESC_ELEGER6) AS DESC_ELEGER6
         , MAX(C.COD_ELEGER5) AS COD_ELEGER5
         , MAX(C.DESC_ELEGER5) AS DESC_ELEGER5
      FROM TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT C
     WHERE C.COD_GERARCHIA = '01'
     GROUP BY C.COD
)
/* ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。 */
SELECT COD_SCENARIO                                                       /* 场景 */
     , COD_PERIODO                                                        /* 期间 */
     , COD_AZIENDA                                                        /* 公司 */
     , COD_CONTO                                                          /* 科目 */
     , COD_CATEGORIA                                                      /* 类别 */
     , D_ADJ_TYPE                                                         /* 调整类型 */
     , SRC_DETAIL                                                         /* 数据分类 */
     , CUST_CODE                                                          /* 客商编码 */
     , CUST_NAME                                                          /* 客商名称 */
     , CUST_HEAD_CODE                                                     /* 主户编码 */
     , CUST_HEAD_NAME                                                     /* 主户名称 */
     , CUST_BRANCH_CODE                                                   /* 分户编码 */
     , CUST_BRANCH_NAME                                                   /* 分户名称 */
     , COD_AZI_CTP                                                        /* 对方公司 */
     , COUNTRY_CODE                                                       /* 国家编码 */
     , COUNTRY_NAME                                                       /* 国家名称 */
     , ACCT_SRC_CODE                                                      /* 原始科目编码 */
     , ACCT_REC_CODE                                                      /* 重分类科目编码 */
     , ACCT_MAP_CODE                                                      /* 映射后科目编码 */
     , LE_AGE_FLAG                                                        /* 法人单体账龄标识 */
     , IS_REC_LG                                                          /* 是否重分类_法人 */
     , ME_AGE_FLAG                                                        /* 管理单体账龄标识 */
     , IS_REC_ME                                                          /* 是否重分类_管理 */
     , MB_AGE_FLAG                                                        /* 管理分公司账龄标识 */
     , IS_REC_MB                                                          /* 是否重分类_管理分公司 */
     , GRP_SCOPE                                                          /* 集团归属范围（ 子公司/集团内/集团外） */
/* ALTER BY 20261103 11:49 SHIQINGFENG.EX 补充公司一级、二级分类编码及描述，D_CHANNEL作为公司三级分类，未修改金额和过滤逻辑。 */
     , C.COD_ELEGER6 AS COD_ELEGER6                                  /* 公司一级分类编码 */
     , C.DESC_ELEGER6 AS DESC_ELEGER6                                /* 公司一级分类描述 */
     , C.COD_ELEGER5 AS COD_ELEGER5                                  /* 公司二级分类编码 */
     , C.DESC_ELEGER5 AS DESC_ELEGER5                                /* 公司二级分类描述 */
     , D_CHANNEL                                                          /* 公司三级分类 */
     , F_TGK_GET_DIMNAME('D_CHANNEL', D_CHANNEL) AS D_CHANNEL_DESC        /* 三级公司分类名称 */
     , D_ONOFFLINE                                                        /* 渠道分组 */
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', D_ONOFFLINE) AS D_ONOFFLINE_DESC  /* 渠道分组名称 */
     , COD_DEST2                                                          /* 利润中心 */
     , F_TGK_GET_DIMNAME('DEST2', COD_DEST2) AS COD_DEST2_DESC            /* 利润中心名称 */
     , COD_DEST3                                                          /* 业务范围 */
     , F_TGK_GET_DIMNAME('DEST3', COD_DEST3) AS COD_DEST3_DESC            /* 业务范围名称 */
     , D_SALE_DEPT                                                        /* 业务管理单元 */
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', D_SALE_DEPT) AS D_SALE_DEPT_DESC  /* 业务管理单元名称 */
     , D_CHANNEL_BU                                                       /* 【二期新增】渠道BU */
     , F_TGK_GET_DIMNAME('D_CHANNEL_BU', D_CHANNEL_BU) AS D_TOV_CHAN_DESC  /* 渠道BU名称 */
     , D_CC_CUSTGRP                                                       /* 【二期新增】商冷客户群 */
     , F_TGK_GET_DIMNAME('D_CC_CUSTGRP', D_CC_CUSTGRP) AS D_CC_CUSTGRP_DESC  /* 商冷客户群名称 */
     , COD_VALUTA                                                         /* 本位币币种 */
     , COD_VALUTA_ORIGINARIA                                              /* 交易币币种 */
     , BCY_0_AMT                                                          /* 本位币金额-本月账龄 */
     , BCY_1_AMT                                                          /* 本位币金额- 1个月 */
     , BCY_2_AMT                                                          /* 本位币金额-2-3个月 */
     , BCY_3_AMT                                                          /* 本位币金额-4-6个月 */
     , BCY_4_AMT                                                          /* 本位币金额- 7-12个月 */
     , BCY_5_AMT                                                          /* 本位币金额- 1-2年 */
     , BCY_6_AMT                                                          /* 本位币金额-2-3年 */
     , BCY_7_AMT                                                          /* 本位币金额- 3-4年 */
     , BCY_8_AMT                                                          /* 本位币金额-4-5年 */
     , BCY_9_AMT                                                          /* 本位币金额-5年以上 */
     , BCY_10_AMT                                                         /* 本位币金额-账龄区间段10 */
     , BCY_11_AMT                                                         /* 本位币金额-账龄区间段11 */
     , BCY_12_AMT                                                         /* 本位币金额-账龄区间段12 */
     , BCY_13_AMT                                                         /* 本位币金额-账龄区间段13 */
     , BCY_14_AMT                                                         /* 本位币金额-账龄区间段14 */
     , BCY_15_AMT                                                         /* 本位币金额-账龄区间段15 */
     , QCY_0_AMT                                                          /* 交易币金额-本月账龄 */
     , QCY_1_AMT                                                          /* 交易币金额-1个月 */
     , QCY_2_AMT                                                          /* 交易币金额-2-3个月 */
     , QCY_3_AMT                                                          /* 交易币金额-4-6个月 */
     , QCY_4_AMT                                                          /* 交易币金额- 7-12个月 */
     , QCY_5_AMT                                                          /* 交易币金额- 1-2年 */
     , QCY_6_AMT                                                          /* 交易币金额-2-3年 */
     , QCY_7_AMT                                                          /* 交易币金额- 3-4年 */
     , QCY_8_AMT                                                          /* 交易币金额-4-5年 */
     , QCY_9_AMT                                                          /* 交易币金额-5年以上 */
     , QCY_10_AMT                                                         /* 交易币金额-账龄区间段10 */
     , QCY_11_AMT                                                         /* 交易币金额-账龄区间段11 */
     , QCY_12_AMT                                                         /* 交易币金额-账龄区间段12 */
     , QCY_13_AMT                                                         /* 交易币金额-账龄区间段13 */
     , QCY_14_AMT                                                         /* 交易币金额-账龄区间段14 */
     , QCY_15_AMT                                                         /* 交易币金额-账龄区间段15 */
     , PAY_TERM_CODE                                                      /* 付款条件代码 */
     , PAY_TERM_DESC                                                      /* 付款条件描述 */
     , NATURE_L1_NAME                                                     /* 一级性质 */
     , NATURE_L2_NAME                                                     /* 二级性质 */
     , NATURE_L3_NAME                                                     /* 三级性质 */
     , CLOSING_RATE_BCY_AMT                                               /* 【废弃】期末汇率余额 */
     , POSTING_RATE_BCY_AMT                                               /* 记账汇率余额 */
     , EXCHANGE_RATE_EVAL_FLAG                                            /* 汇率评估标识 */
     , SYSTEM_SRC                                                         /* 来源系统 */
     , TH_FX_EVAL_AMT                                                     /* 【废弃】理论汇兑评估 */
     , CURRENCY_ACCT_DETAIL                                               /* 【废弃】币种科目构成明细 */
     , ADJ_REB_AMT                                                        /* 【废弃】调整后返利金额 */
     , ADJ_RET_AMT                                                        /* 【废弃】调整后退货金额 */
     , TAX_RATE                                                           /* 税率 */
     , UFEE_UREB_FLAG                                                     /* 返利/费用标识 */
     , ECLS_FLAG                                                          /* 电商零售标识 */
     , DATEUPD                                                            /* 更新时间 */
     , USERUPD                                                            /* 更新用户 */
  FROM AW_MR9_ARPM01_000001 A
  LEFT JOIN CHANNEL_DIM C
    ON C.COD = A.D_CHANNEL
 WHERE COD_SCENARIO = ${$Scenario.code}
   AND COD_PERIODO = ${$Period.code}
   AND COD_AZIENDA IN (${$Entity.code})
 ORDER BY SRC_DETAIL,COD_AZIENDA,COD_CONTO
