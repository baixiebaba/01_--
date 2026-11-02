/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:26
 * 本次修改：ALTER BY 20261102 17:26 SHIQINGFENG.EX 将公司参数筛选由等值判断统一为 IN 写法，并统一 Query 排版，未修改其他逻辑。
 * 上次修改：原文件无修改记录。
 *
 * 查询名称  ：坏账计提结果表-坏账计算表（管理口径-事业部）
 * 功能描述  ：按场景、期间、公司和管理口径账龄标识查询事业部坏账计算结果。
 * 宿主表    ：AW_MR9_ARPM02_000001、CONTO
 * 展示逻辑  ：展示管理口径坏账基数、分配金额、坏账金额及校验金额。
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
       - BD_BASE_12_AMT - BD_BASE_13_AMT - BD_BASE_14_AMT - BD_BASE_15_AMT AS CHECK1
     , BD_0_AMT
     , BD_1_AMT
     , BD_2_AMT
     , BD_3_AMT
     , BD_4_AMT
     , BD_5_AMT
     , BD_6_AMT
     , BD_7_AMT
     , BD_8_AMT
     , BD_9_AMT
     , BD_10_AMT
     , BD_11_AMT
     , BD_12_AMT
     , BD_13_AMT
     , BD_14_AMT
     , BD_15_AMT
     , BD_0_AMT - BD_1_AMT - BD_2_AMT - BD_3_AMT
       - BD_4_AMT - BD_5_AMT - BD_6_AMT - BD_7_AMT
       - BD_8_AMT - BD_9_AMT - BD_10_AMT - BD_11_AMT
       - BD_12_AMT - BD_13_AMT - BD_14_AMT - BD_15_AMT AS CHECK2
     , BD_ALLOC_RATIO
     , AGE_ALLOC_0_AMT
     , AGE_ALLOC_1_AMT
     , AGE_ALLOC_2_AMT
     , AGE_ALLOC_3_AMT
     , AGE_ALLOC_4_AMT
     , AGE_ALLOC_5_AMT
     , AGE_ALLOC_6_AMT
     , AGE_ALLOC_7_AMT
     , AGE_ALLOC_8_AMT
     , AGE_ALLOC_9_AMT
     , AGE_ALLOC_10_AMT
     , AGE_ALLOC_11_AMT
     , AGE_ALLOC_12_AMT
     , AGE_ALLOC_13_AMT
     , AGE_ALLOC_14_AMT
     , AGE_ALLOC_15_AMT
     , AGE_ALLOC_0_AMT - AGE_ALLOC_1_AMT - AGE_ALLOC_2_AMT - AGE_ALLOC_3_AMT
       - AGE_ALLOC_4_AMT - AGE_ALLOC_5_AMT - AGE_ALLOC_6_AMT - AGE_ALLOC_7_AMT
       - AGE_ALLOC_8_AMT - AGE_ALLOC_9_AMT - AGE_ALLOC_10_AMT - AGE_ALLOC_11_AMT
       - AGE_ALLOC_12_AMT - AGE_ALLOC_13_AMT - AGE_ALLOC_14_AMT - AGE_ALLOC_15_AMT AS CHECK3
     , BD_AFAL_0_AMT
     , BD_AFAL_1_AMT
     , BD_AFAL_2_AMT
     , BD_AFAL_3_AMT
     , BD_AFAL_4_AMT
     , BD_AFAL_5_AMT
     , BD_AFAL_6_AMT
     , BD_AFAL_7_AMT
     , BD_AFAL_8_AMT
     , BD_AFAL_9_AMT
     , BD_AFAL_10_AMT
     , BD_AFAL_11_AMT
     , BD_AFAL_12_AMT
     , BD_AFAL_13_AMT
     , BD_AFAL_14_AMT
     , BD_AFAL_15_AMT
     , BD_AFAL_0_AMT - BD_AFAL_1_AMT - BD_AFAL_2_AMT - BD_AFAL_3_AMT
       - BD_AFAL_4_AMT - BD_AFAL_5_AMT - BD_AFAL_6_AMT - BD_AFAL_7_AMT
       - BD_AFAL_8_AMT - BD_AFAL_9_AMT - BD_AFAL_10_AMT - BD_AFAL_11_AMT
       - BD_AFAL_12_AMT - BD_AFAL_13_AMT - BD_AFAL_14_AMT - BD_AFAL_15_AMT AS CHECK4
     , LM_BD_AFAL_0_AMT
     , WRITEOFF_AMT
     , MTD_BD_PROV_OCUR_AMT
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
