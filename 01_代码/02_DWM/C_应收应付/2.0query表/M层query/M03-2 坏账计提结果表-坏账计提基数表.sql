/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:26
 * 本次修改：ALTER BY 20261102 17:26 SHIQINGFENG.EX 将公司参数筛选由等值判断统一为 IN 写法，并统一 Query 排版，未修改其他逻辑。
 * 上次修改：原文件无修改记录。
 *
 * 查询名称  ：坏账计提结果表-坏账计提基数表
 * 功能描述  ：按场景、期间、公司和管理口径账龄标识查询坏账计提基数。
 * 宿主表    ：AW_MR9_ARPM02_000001、CONTO
 * 展示逻辑  ：展示账龄调整、坏账基数及校验金额等原有字段。
 *
 * 修改历史：
 *   ALTER BY 20261102 17:26 SHIQINGFENG.EX 将公司参数筛选由等值判断统一为 IN 写法，并统一 Query 排版，未修改其他逻辑。
 *******************************************************************************/
SELECT COD_SCENARIO
     , COD_PERIODO
     , COD_AZIENDA
     , A.COD_CONTO
     , DESC_CONTO1
     , CUST_CODE
     , CUST_NAME
     , CUST_HEAD_CODE
     , CUST_HEAD_NAME
     , CUST_BRANCH_CODE
     , CUST_BRANCH_NAME
     , GRP_SCOPE
     , D_ONOFFLINE
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', D_ONOFFLINE) AS D_ONOFFLINE_DESC
     , COD_DEST2
     , F_TGK_GET_DIMNAME('DEST2', COD_DEST2) AS COD_DEST2_DESC
     , COD_DEST3
     , F_TGK_GET_DIMNAME('DEST3', COD_DEST3) AS COD_DEST3_DESC
     , D_SALE_DEPT
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', D_SALE_DEPT) AS D_SALE_DEPT_DESC
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
     , BCY_ADJ_INCL_0_AMT - BCY_ADJ_INCL_1_AMT - BCY_ADJ_INCL_2_AMT - BCY_ADJ_INCL_3_AMT
       - BCY_ADJ_INCL_4_AMT - BCY_ADJ_INCL_5_AMT - BCY_ADJ_INCL_6_AMT - BCY_ADJ_INCL_7_AMT
       - BCY_ADJ_INCL_8_AMT - BCY_ADJ_INCL_9_AMT - BCY_ADJ_INCL_10_AMT - BCY_ADJ_INCL_11_AMT
       - BCY_ADJ_INCL_12_AMT - BCY_ADJ_INCL_13_AMT - BCY_ADJ_INCL_14_AMT - BCY_ADJ_INCL_15_AMT AS CHECK1
     , SPC_DSV_DED_AMT
     , SPC_REB_DED_AMT
     , BD_BASE_0_AMT
     , BD_BASE_1_AMT
     , BD_BASE_2_AMT
     , BD_BASE_3_AMT
     , BD_BASE_4_AMT
     , BD_BASE_5_AMT
     , BD_BASE_6_AMT
     , BD_BASE_7_AMT
     , BD_BASE_8_AMT
     , BD_BASE_9_AMT
     , BD_BASE_10_AMT
     , BD_BASE_11_AMT
     , BD_BASE_12_AMT
     , BD_BASE_13_AMT
     , BD_BASE_14_AMT
     , BD_BASE_15_AMT
     , BD_BASE_0_AMT - BD_BASE_1_AMT - BD_BASE_2_AMT - BD_BASE_3_AMT
       - BD_BASE_4_AMT - BD_BASE_5_AMT - BD_BASE_6_AMT - BD_BASE_7_AMT
       - BD_BASE_8_AMT - BD_BASE_9_AMT - BD_BASE_10_AMT - BD_BASE_11_AMT
       - BD_BASE_12_AMT - BD_BASE_13_AMT - BD_BASE_14_AMT - BD_BASE_15_AMT AS CHECK2
     , A.USERUPD
     , A.DATEUPD
  FROM AW_MR9_ARPM02_000001 A
  LEFT JOIN CONTO
    ON A.COD_CONTO = CONTO.COD_CONTO
 WHERE COD_SCENARIO = ${$Scenario.code}
   AND COD_PERIODO = ${$Period.code}
   AND COD_AZIENDA IN (${$Entity.code})
   AND ME_AGE_FLAG IN ('AR', 'OR', 'CA')
 ORDER BY COD_AZIENDA
        , A.COD_CONTO
