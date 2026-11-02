/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:23
 * 本次修改：ALTER BY 20261102 17:23 SHIQINGFENG.EX 统一 Query 文件头、关键字大小写、字段逐行排列和查询条件排版，未修改业务主体。
 * 上次修改：原文件无修改记录。
 *
 * 查询名称  ：往来账龄结果表M02-账龄结果表
 * 功能描述  ：按场景、期间和公司查询M02账龄结果及坏账、回款等明细指标。
 * 宿主表    ：AW_MR9_ARPM02_000001
 * 展示逻辑  ：按原有字段顺序展示账龄分类、金额、调整项和更新信息。
 *
 * 修改历史：
 *   ALTER BY 20261102 17:23 SHIQINGFENG.EX 统一 Query 文件头、关键字大小写、字段逐行排列和查询条件排版，未修改业务主体。
 *******************************************************************************/
SELECT COD_SCENARIO
     , COD_PERIODO
     , COD_AZIENDA
     , A.COD_CONTO
     , F_TGK_GET_DIMNAME('CONTO', COD_CONTO) AS DESC_CONTO1
     , LE_AGE_FLAG
     , IS_REC_LG
     , ME_AGE_FLAG
     , IS_REC_ME
     , MB_AGE_FLAG
     , IS_REC_MB
     , CUST_CODE
     , CUST_NAME
     , CUST_HEAD_CODE
     , CUST_HEAD_NAME
     , CUST_BRANCH_CODE
     , CUST_BRANCH_NAME
     , COD_AZI_CTP
     , COUNTRY_CODE
     , COUNTRY_NAME
     , GRP_SCOPE
     , NATURE_L1_NAME
     , NATURE_L2_NAME
     , NATURE_L3_NAME
     , D_CHANNEL
     , F_TGK_GET_DIMNAME('D_CHANNEL', D_CHANNEL) AS D_CHANNEL_DESC
     , D_ONOFFLINE
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', D_ONOFFLINE) AS D_ONOFFLINE_DESC
     , COD_DEST2
     , F_TGK_GET_DIMNAME('DEST2', COD_DEST2) AS COD_DEST2_DESC
     , COD_DEST3
     , F_TGK_GET_DIMNAME('DEST3', COD_DEST3) AS COD_DEST3_DESC
     , D_SALE_DEPT
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', D_SALE_DEPT) AS D_SALE_DEPT_DESC
     , D_TOV_CHAN
     , F_TGK_GET_DIMNAME('D_TOV_CHAN', D_TOV_CHAN) AS D_TOV_CHAN_DESC
     , D_CC_CUSTGRP
     , F_TGK_GET_DIMNAME('D_CC_CUSTGRP', D_CC_CUSTGRP) AS D_CC_CUSTGRP_DESC
     , TAX_RATE
     , COD_VALUTA
     , COD_VALUTA_ORIGINARIA
     , BY_BCY_0_AMT
     , LM_BCY_0_AMT
     , BCY_0_AMT
     , BCY_1_AMT
     , BCY_2_AMT
     , BCY_3_AMT
     , BCY_4_AMT
     , BCY_5_AMT
     , BCY_6_AMT
     , BCY_7_AMT
     , BCY_8_AMT
     , BCY_9_AMT
     , BCY_10_AMT
     , BCY_11_AMT
     , BCY_12_AMT
     , BCY_13_AMT
     , BCY_14_AMT
     , BCY_15_AMT
     , QCY_0_AMT
     , QCY_1_AMT
     , QCY_2_AMT
     , QCY_3_AMT
     , QCY_4_AMT
     , QCY_5_AMT
     , QCY_6_AMT
     , QCY_7_AMT
     , QCY_8_AMT
     , QCY_9_AMT
     , QCY_10_AMT
     , QCY_11_AMT
     , QCY_12_AMT
     , QCY_13_AMT
     , QCY_14_AMT
     , QCY_15_AMT
     , SHP_NINV_AMT
     , RET_NTRF_AMT
     , BCY_ADJ_INCL_0_AMT
     , BCY_ADJ_INCL_1_AMT
     , BCY_ADJ_INCL_2_AMT
     , BCY_ADJ_INCL_3_AMT
     , BCY_ADJ_INCL_4_AMT
     , BCY_ADJ_INCL_5_AMT
     , BCY_ADJ_INCL_6_AMT
     , BCY_ADJ_INCL_7_AMT
     , BCY_ADJ_INCL_8_AMT
     , BCY_ADJ_INCL_9_AMT
     , BCY_ADJ_INCL_10_AMT
     , BCY_ADJ_INCL_11_AMT
     , BCY_ADJ_INCL_12_AMT
     , BCY_ADJ_INCL_13_AMT
     , BCY_ADJ_INCL_14_AMT
     , BCY_ADJ_INCL_15_AMT
     , BCY_ADJ_EXCL_0_AMT
     , OVERDUE_0_AMT
     , OVERDUE_1_AMT
     , OVERDUE_2_AMT
     , OVERDUE_3_AMT
     , OVERDUE_4_AMT
     , OVERDUE_5_AMT
     , OVERDUE_6_AMT
     , OVERDUE_7_AMT
     , OVERDUE_8_AMT
     , OVERDUE_9_AMT
     , INV_SAMPLE_AMT
     , EPAY_AMT
     , ECLS_AMT
     , UREB_AMT
     , UFEE_AMT
     , PAY_TERM_CODE
     , PAY_TERM_DESC
     , CLOSING_RATE_BCY_AMT
     , POSTING_RATE_BCY_AMT
     , EXCHANGE_RATE_EVAL_FLAG
     , TH_FX_EVAL_AMT
     , CURRENCY_ACCT_DETAIL
     , ADJ_REB_AMT
     , ADJ_RET_AMT
     , DEAD_AMT
     , RISK_AMT
     , PAY_METHOD
     , IS_LN_AGE
     , LN_AGE_RSN
     , IS_ABN
     , IS_EXS
     , SUSP_RSN
     , CLR_MEA
     , EST_CLR_DT
     , CLR_PROG
     , RSP_PSN
     , IS_ADJ
     , ADJ_RSN
     , A.USERUPD
     , A.DATEUPD
  FROM AW_MR9_ARPM02_000001 A
 WHERE COD_SCENARIO = ${$Scenario.code}
   AND COD_PERIODO = ${$Period.code}
   AND COD_AZIENDA IN (${$Entity.code})
 ORDER BY COD_AZIENDA
        , A.COD_CONTO
        , LE_AGE_FLAG
