/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:35
 * 本次修改：ALTER BY 20261102 17:35 SHIQINGFENG.EX 精简查询说明文件头：删除功能描述、宿主表、展示逻辑行，改为查询名称+源表版式，未修改业务主体。
 * 上次修改：ALTER BY 20261102 17:23 SHIQINGFENG.EX 统一 Query 文件头、关键字大小写、字段逐行排列和查询条件排版，未修改业务主体。
 *
 * 查询名称  ：往来账龄结果表M02-账龄结果表
 * 源表      ：AW_MR9_ARPM02_000001
 *
 * 修改历史：
 *   ALTER BY 20261102 17:35 SHIQINGFENG.EX 精简查询说明文件头：删除功能描述、宿主表、展示逻辑行，改为查询名称+源表版式，未修改业务主体。
 *   ALTER BY 20261102 17:23 SHIQINGFENG.EX 统一 Query 文件头、关键字大小写、字段逐行排列和查询条件排版，未修改业务主体。
 *******************************************************************************/
SELECT COD_SCENARIO                                                       /* 场景 */
     , COD_PERIODO                                                        /* 期间 */
     , COD_AZIENDA                                                        /* 公司 */
     , A.COD_CONTO                                                        /* 科目 */
     , F_TGK_GET_DIMNAME('CONTO', COD_CONTO) AS DESC_CONTO1               /* 科目名称 */
     , LE_AGE_FLAG                                                        /* 法人单体账龄标识 */
     , IS_REC_LG                                                          /* 是否重分类_法人 */
     , ME_AGE_FLAG                                                        /* 管理单体账龄标识 */
     , IS_REC_ME                                                          /* 是否重分类_管理 */
     , MB_AGE_FLAG                                                        /* 管理分公司账龄标识 */
     , IS_REC_MB                                                          /* 是否重分类_管理分公司 */
     , CUST_CODE                                                          /* 客商编码 */
     , CUST_NAME                                                          /* 客商名称 */
     , CUST_HEAD_CODE                                                     /* 主户编码 */
     , CUST_HEAD_NAME                                                     /* 主户名称 */
     , CUST_BRANCH_CODE                                                   /* 分户编码 */
     , CUST_BRANCH_NAME                                                   /* 分户名称 */
     , COD_AZI_CTP                                                        /* 对方公司 */
     , COUNTRY_CODE                                                       /* 国家编码 */
     , COUNTRY_NAME                                                       /* 国家名称 */
     , GRP_SCOPE                                                          /* 集团归属范围（子公司/集团内/集团外） */
     , NATURE_L1_NAME                                                     /* 一级性质 */
     , NATURE_L2_NAME                                                     /* 二级性质 */
     , NATURE_L3_NAME                                                     /* 三级性质 */
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
     , D_TOV_CHAN                                                         /* 周转分析渠道 */
     , F_TGK_GET_DIMNAME('D_TOV_CHAN', D_TOV_CHAN) AS D_TOV_CHAN_DESC     /* 周转分析渠道名称 */
     , D_CC_CUSTGRP                                                       /* 商冷客户群 */
     , F_TGK_GET_DIMNAME('D_CC_CUSTGRP', D_CC_CUSTGRP) AS D_CC_CUSTGRP_DESC  /* 商冷客户群名称 */
     , TAX_RATE                                                           /* 税率 */
     , COD_VALUTA                                                         /* 货币 */
     , COD_VALUTA_ORIGINARIA                                              /* 交易币币种 */
     , BY_BCY_0_AMT                                                       /* 年初-本位币余额 */
     , LM_BCY_0_AMT                                                       /* 上月-本位币余额 */
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
     , SHP_NINV_AMT                                                       /* 出库未开金额 */
     , RET_NTRF_AMT                                                       /* 退货未办退税金额 */
     , BCY_ADJ_INCL_0_AMT                                                 /* 本位币金额-调整后含税-本月账龄 */
     , BCY_ADJ_INCL_1_AMT                                                 /* 本位币金额-调整后含税-1个月 */
     , BCY_ADJ_INCL_2_AMT                                                 /* 本位币金额-调整后含税-2-3个月 */
     , BCY_ADJ_INCL_3_AMT                                                 /* 本位币金额-调整后含税-4-6个月 */
     , BCY_ADJ_INCL_4_AMT                                                 /* 本位币金额-调整后含税- 7-12个月 */
     , BCY_ADJ_INCL_5_AMT                                                 /* 本位币金额-调整后含税- 1-2年 */
     , BCY_ADJ_INCL_6_AMT                                                 /* 本位币金额-调整后含税-2-3年 */
     , BCY_ADJ_INCL_7_AMT                                                 /* 本位币金额-调整后含税- 3-4年 */
     , BCY_ADJ_INCL_8_AMT                                                 /* 本位币金额-调整后含税-4-5年 */
     , BCY_ADJ_INCL_9_AMT                                                 /* 本位币金额-调整后含税-5年以上 */
     , BCY_ADJ_INCL_10_AMT                                                /* 本位币金额-调整后含税-账龄区间段10 */
     , BCY_ADJ_INCL_11_AMT                                                /* 本位币金额-调整后含税-账龄区间段11 */
     , BCY_ADJ_INCL_12_AMT                                                /* 本位币金额-调整后含税-账龄区间段12 */
     , BCY_ADJ_INCL_13_AMT                                                /* 本位币金额-调整后含税-账龄区间段13 */
     , BCY_ADJ_INCL_14_AMT                                                /* 本位币金额-调整后含税-账龄区间段14 */
     , BCY_ADJ_INCL_15_AMT                                                /* 本位币金额-调整后含税-账龄区间段15 */
     , BCY_ADJ_EXCL_0_AMT                                                 /* 本位币金额-调整后不含税-本月账龄 */
     , OVERDUE_0_AMT                                                      /* 超期款金额 */
     , OVERDUE_1_AMT                                                      /* 超期款金额-1个月以内 */
     , OVERDUE_2_AMT                                                      /* 超期款金额-2-3个月 */
     , OVERDUE_3_AMT                                                      /* 超期款金额-4-6个月 */
     , OVERDUE_4_AMT                                                      /* 超期款金额-7-12个月 */
     , OVERDUE_5_AMT                                                      /* 超期款金额-1-2年 */
     , OVERDUE_6_AMT                                                      /* 超期款金额-2-3年 */
     , OVERDUE_7_AMT                                                      /* 超期款金额-3-4年 */
     , OVERDUE_8_AMT                                                      /* 超期款金额-4-5年 */
     , OVERDUE_9_AMT                                                      /* 超期款金额-5年以上 */
     , INV_SAMPLE_AMT                                                     /* 开票样机金额 */
     , EPAY_AMT                                                           /* 提前回款金额 */
     , ECLS_AMT                                                           /* 电商零售金额 */
     , UREB_AMT                                                           /* 欠付返利余额 */
     , UFEE_AMT                                                           /* 欠付费用金额 */
     , PAY_TERM_CODE                                                      /* 付款条件代码 */
     , PAY_TERM_DESC                                                      /* 付款条件描述 */
     , CLOSING_RATE_BCY_AMT                                               /* 期末汇率余额 */
     , POSTING_RATE_BCY_AMT                                               /* 记账汇率余额 */
     , EXCHANGE_RATE_EVAL_FLAG                                            /* 汇率评估标识 */
     , TH_FX_EVAL_AMT                                                     /* 理论汇兑评估 */
     , CURRENCY_ACCT_DETAIL                                               /* 币种科目构成明细 */
     , ADJ_REB_AMT                                                        /* 调整后返利金额 */
     , ADJ_RET_AMT                                                        /* 调整后退货金额 */
     , DEAD_AMT                                                           /* 呆死金额 */
     , RISK_AMT                                                           /* 风险金额 */
     , PAY_METHOD                                                         /* 付款方式 */
     , IS_LN_AGE                                                          /* 是否长账龄 */
     , LN_AGE_RSN                                                         /* 长账龄原因-大类 */
     , IS_ABN                                                             /* 是否异常 */
     , IS_EXS                                                             /* 是否存续 */
     , SUSP_RSN                                                           /* 挂账原因 */
     , CLR_MEA                                                            /* 清理措施 */
     , EST_CLR_DT                                                         /* 预计清理时间 */
     , CLR_PROG                                                           /* 清理进度 */
     , RSP_PSN                                                            /* 责任人 */
     , IS_ADJ                                                             /* 是否调整 */
     , ADJ_RSN                                                            /* 调整原因 */
     , A.USERUPD                                                          /* 更新用户 */
     , A.DATEUPD                                                          /* 更新时间 */
  FROM AW_MR9_ARPM02_000001 A
 WHERE COD_SCENARIO = ${$Scenario.code}
   AND COD_PERIODO = ${$Period.code}
   AND COD_AZIENDA IN (${$Entity.code})
 ORDER BY COD_AZIENDA
        , A.COD_CONTO
        , LE_AGE_FLAG
