/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:26
 * 本次修改：ALTER BY 20261102 17:26 SHIQINGFENG.EX 将公司参数筛选由等值判断统一为 IN 写法，并统一 Query 排版，未修改其他逻辑。
 * 上次修改：原文件无修改记录。
 *
 * 查询名称  ：坏账计提结果表-坏账计算表（法人口径）
 * 功能描述  ：按场景、期间、公司和法人口径账龄标识汇总坏账计算结果。
 * 宿主表    ：AW_MR9_ARPM02_000001、CONTO
 * 展示逻辑  ：按公司、科目、客商主户和坏账方法汇总坏账基数及计提金额。
 *
 * 修改历史：
 *   ALTER BY 20261102 17:26 SHIQINGFENG.EX 将公司参数筛选由等值判断统一为 IN 写法，并统一 Query 排版，未修改其他逻辑。
 *******************************************************************************/
SELECT COD_SCENARIO
     , COD_PERIODO
     , COD_AZIENDA
     , A.COD_CONTO
     , DESC_CONTO1
     , CUST_HEAD_CODE
     , CUST_HEAD_NAME
     , GRP_SCOPE
     , SUM(BD_BASE_0_AMT) AS BD_BASE_0_AMT
     , SUM(BD_BASE_1_AMT) AS BD_BASE_1_AMT
     , SUM(BD_BASE_2_AMT) AS BD_BASE_2_AMT
     , SUM(BD_BASE_3_AMT) AS BD_BASE_3_AMT
     , SUM(BD_BASE_4_AMT) AS BD_BASE_4_AMT
     , SUM(BD_BASE_5_AMT) AS BD_BASE_5_AMT
     , SUM(BD_BASE_6_AMT) AS BD_BASE_6_AMT
     , SUM(BD_BASE_7_AMT) AS BD_BASE_7_AMT
     , SUM(BD_BASE_8_AMT) AS BD_BASE_8_AMT
     , SUM(BD_BASE_9_AMT) AS BD_BASE_9_AMT
     , SUM(BD_BASE_10_AMT) AS BD_BASE_10_AMT
     , SUM(BD_BASE_11_AMT) AS BD_BASE_11_AMT
     , SUM(BD_BASE_12_AMT) AS BD_BASE_12_AMT
     , SUM(BD_BASE_13_AMT) AS BD_BASE_13_AMT
     , SUM(BD_BASE_14_AMT) AS BD_BASE_14_AMT
     , SUM(BD_BASE_15_AMT) AS BD_BASE_15_AMT
     , SUM(BD_BASE_0_AMT) - SUM(BD_BASE_1_AMT) - SUM(BD_BASE_2_AMT) - SUM(BD_BASE_3_AMT)
       - SUM(BD_BASE_4_AMT) - SUM(BD_BASE_5_AMT) - SUM(BD_BASE_6_AMT) - SUM(BD_BASE_7_AMT)
       - SUM(BD_BASE_8_AMT) - SUM(BD_BASE_9_AMT) - SUM(BD_BASE_10_AMT) - SUM(BD_BASE_11_AMT)
       - SUM(BD_BASE_12_AMT) - SUM(BD_BASE_13_AMT) - SUM(BD_BASE_14_AMT) - SUM(BD_BASE_15_AMT) AS CHECK2
     , SUM(BD_AFAL_0_AMT) AS BD_AFAL_0_AMT
     , SUM(BD_AFAL_1_AMT) AS BD_AFAL_1_AMT
     , SUM(BD_AFAL_2_AMT) AS BD_AFAL_2_AMT
     , SUM(BD_AFAL_3_AMT) AS BD_AFAL_3_AMT
     , SUM(BD_AFAL_4_AMT) AS BD_AFAL_4_AMT
     , SUM(BD_AFAL_5_AMT) AS BD_AFAL_5_AMT
     , SUM(BD_AFAL_6_AMT) AS BD_AFAL_6_AMT
     , SUM(BD_AFAL_7_AMT) AS BD_AFAL_7_AMT
     , SUM(BD_AFAL_8_AMT) AS BD_AFAL_8_AMT
     , SUM(BD_AFAL_9_AMT) AS BD_AFAL_9_AMT
     , SUM(BD_AFAL_10_AMT) AS BD_AFAL_10_AMT
     , SUM(BD_AFAL_11_AMT) AS BD_AFAL_11_AMT
     , SUM(BD_AFAL_12_AMT) AS BD_AFAL_12_AMT
     , SUM(BD_AFAL_13_AMT) AS BD_AFAL_13_AMT
     , SUM(BD_AFAL_14_AMT) AS BD_AFAL_14_AMT
     , SUM(BD_AFAL_15_AMT) AS BD_AFAL_15_AMT
     , SUM(BD_AFAL_0_AMT) - SUM(BD_AFAL_1_AMT) - SUM(BD_AFAL_2_AMT) - SUM(BD_AFAL_3_AMT)
       - SUM(BD_AFAL_4_AMT) - SUM(BD_AFAL_5_AMT) - SUM(BD_AFAL_6_AMT) - SUM(BD_AFAL_7_AMT)
       - SUM(BD_AFAL_8_AMT) - SUM(BD_AFAL_9_AMT) - SUM(BD_AFAL_10_AMT) - SUM(BD_AFAL_11_AMT)
       - SUM(BD_AFAL_12_AMT) - SUM(BD_AFAL_13_AMT) - SUM(BD_AFAL_14_AMT) - SUM(BD_AFAL_15_AMT) AS CHECK4
     , SUM(SPID_0_AMT) AS SPID_0_AMT
     , SUM(LM_BD_AFAL_0_AMT) AS LM_BD_AFAL_0_AMT
     , SUM(WRITEOFF_AMT) AS WRITEOFF_AMT
     , SUM(MTD_BD_PROV_OCUR_AMT) AS MTD_BD_PROV_OCUR_AMT
     , BD_PROV_METHOD
     , A.USERUPD
     , A.DATEUPD
  FROM AW_MR9_ARPM02_000001 A
  LEFT JOIN CONTO
    ON A.COD_CONTO = CONTO.COD_CONTO
 WHERE COD_SCENARIO = ${$Scenario.code}
   AND COD_PERIODO = ${$Period.code}
   AND COD_AZIENDA IN (${$Entity.code})
   AND ME_AGE_FLAG IN ('AR', 'OR', 'CA')
 GROUP BY COD_SCENARIO
        , COD_PERIODO
        , COD_AZIENDA
        , A.COD_CONTO
        , DESC_CONTO1
        , CUST_HEAD_CODE
        , CUST_HEAD_NAME
        , GRP_SCOPE
        , BD_PROV_METHOD
        , A.USERUPD
        , A.DATEUPD
 ORDER BY COD_AZIENDA
        , A.COD_CONTO
