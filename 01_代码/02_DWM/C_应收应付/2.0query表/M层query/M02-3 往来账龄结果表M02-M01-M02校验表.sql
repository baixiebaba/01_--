/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261109 18:00
 * 本次修改：ALTER BY 20261109 18:00 SHIQINGFENG.EX 金额全为0的记录不再输出。
 * 上次修改：ALTER BY 20261104 17:56 SHIQINGFENG.EX 恢复校验设计：M02金额按存储过程从M01重算，不读取M02目标表；删除CURRENT_SOURCE_ROW_CNT，并完成M01/M02键级对账。
 *
 * 查询名称  ：SUPPLEMENT_AGG补充金额进入M02校验
 * 源表      ：TGK_FIMA_HISENSE.AW_MR9_ARPM01_000001、TGK_FIMA_HISENSE.DATI_CAMBIO、TGK_FIMA_HISENSE.SQF_TEST
 *
 * 修改历史：
 *   ALTER BY 20261109 18:00 SHIQINGFENG.EX 金额全为0的记录不再输出。
 *   ALTER BY 20261104 17:56 SHIQINGFENG.EX 恢复校验设计：M02金额按存储过程从M01重算，不读取M02目标表；删除CURRENT_SOURCE_ROW_CNT，并完成M01/M02键级对账。
 *   ALTER BY 20261104 17:51 SHIQINGFENG.EX 修正M01/M02金额来源：M01直接汇总ARPM01当前ORG来源，M02直接汇总ARPM02实际落表；删除CURRENT_SOURCE_ROW_CNT。
 *   ALTER BY 20261104 17:43 SHIQINGFENG.EX 修正校验范围：改用CURRENT_SOURCE_KEY与SUPPLEMENT_AGG业务键并集，完整保留仅M01/M02和仅补充金额数据；补全SQF_TEST schema。
 *   ALTER BY 20261104 17:02 SHIQINGFENG.EX 新增M01金额、M02口径金额、汇率评估标识和是否重分类-法人；M02金额复用过程的汇率换算及合同负债剔税逻辑。
 *   ALTER BY 20261104 16:08 SHIQINGFENG.EX 新增科目名称、客商名称和利润中心名称；科目、利润中心名称使用维度函数获取，客商名称直接取补充来源。
 *   ALTER BY 20261104 16:00 SHIQINGFENG.EX 新建SUPPLEMENT_AGG补充金额进入M02校验，按公司、科目、客商、利润中心判断补充金额能否匹配CURRENT_SOURCE_BASE。
 *******************************************************************************/
  WITH
  /* M02过程汇率表：汇率以人民币为基准，按实际场景和查询期间取值。 */
  CONVERSION_RATE AS (
      SELECT A.COD_VALUTA
          , MAX(A.CAMBIO_FINALE) AS RATE
        FROM TGK_FIMA_HISENSE.DATI_CAMBIO A
      WHERE A.COD_SCENARIO = SUBSTR(${$Scenario.code}, 1, 4) || 'ACT'
        AND A.COD_PERIODO = ${$Period.code}
      GROUP BY A.COD_VALUTA
  ),
  /* 2023公司复用M02过程的SAP TCURR汇率口径。 */
  TCURR_CONVERSION_RATE AS (
      SELECT TRIM(B.TCURR) AS TCURR
          , TRIM(B.FCURR) AS FCURR
          , B.UKURS * CASE
                          WHEN B.TCURR = 'VND' AND B.FCURR IN ('USD')
                              THEN 1000
                          WHEN B.TCURR = 'VND'
                              THEN 100
                          ELSE 1
                      END AS RATE
        FROM TGK_FIMA_HISENSE.SQF_TEST B
      WHERE B.KURST = 'M'
        AND TO_CHAR(99999999 - B.GDATU) = TO_CHAR(
              TRUNC(
                  ADD_MONTHS(
                      LAST_DAY(
                          TO_DATE(
                              SUBSTR(${$Scenario.code}, 1, 4) || ${$Period.code}
                            , 'YYYYMM'
                          )
                      )
                    , -1
                  ) + 1
              )
            , 'YYYYMMDD'
        )
  ),
  /* CURRENT_SOURCE_BASE复用M02过程口径，基于M01数据计算汇率转换因子和合同负债剔税因子。 */
  /* ALTER BY 20261104 17:56 SHIQINGFENG.EX 恢复校验设计：M02金额按存储过程从M01重算，不读取M02目标表；删除CURRENT_SOURCE_ROW_CNT，并完成M01/M02键级对账。 */
  CURRENT_SOURCE_BASE AS (
      SELECT A.OID
          , A.COD_AZIENDA
          , CASE
                WHEN A.SRC_DETAIL LIKE 'EPAY%'
                  AND NVL(TRIM(A.COD_CONTO), '|') = '|'
                    THEN '1122000000'
                ELSE A.COD_CONTO
            END AS COD_CONTO
          , A.SRC_DETAIL
          , A.CUST_CODE
          , A.CUST_NAME
          , A.COD_DEST2
          , A.LE_AGE_FLAG
          , A.IS_REC_LG
          , A.EXCHANGE_RATE_EVAL_FLAG
          , A.TAX_RATE
          , A.COD_VALUTA
          , A.COD_VALUTA_ORIGINARIA
          , NVL(A.BCY_0_AMT, 0) AS BCY_0_AMT
          , NVL(A.QCY_0_AMT, 0) AS QCY_0_AMT
          , CASE
                WHEN A.LE_AGE_FLAG = 'CL' AND A.IS_REC_LG = 'Y'
                    THEN 1 / NULLIF(1 + NVL(A.TAX_RATE, 0), 0)
                ELSE 1
            END AS TAX_FACTOR
          , CASE
                WHEN TRIM(A.EXCHANGE_RATE_EVAL_FLAG) IS NULL
                  AND TRIM(A.COD_VALUTA_ORIGINARIA) IS NOT NULL
                  AND TRIM(A.COD_VALUTA) IS NOT NULL
                  AND (
                        (A.COD_AZIENDA = '2023'
                         AND TCURR_CONV.RATE IS NOT NULL
                         AND TCURR_CONV.RATE <> 0)
                     OR (NVL(A.COD_AZIENDA, '#') <> '2023'
                         AND (
                               TRIM(A.COD_VALUTA_ORIGINARIA) = 'CNY'
                            OR (QCY_RATE.RATE IS NOT NULL AND QCY_RATE.RATE <> 0)
                         )
                         AND (
                               TRIM(A.COD_VALUTA) = 'CNY'
                            OR (BCY_RATE.RATE IS NOT NULL AND BCY_RATE.RATE <> 0)
                         ))
                  )
                    THEN CASE
                             WHEN A.COD_AZIENDA = '2023'
                                 THEN TCURR_CONV.RATE
                             ELSE ROUND(
                                      (CASE WHEN TRIM(A.COD_VALUTA) = 'CNY' THEN 1 ELSE BCY_RATE.RATE END)
                                      / (CASE WHEN TRIM(A.COD_VALUTA_ORIGINARIA) = 'CNY' THEN 1 ELSE QCY_RATE.RATE END)
                                    , 5
                                  )
                         END
            END AS CONVERSION_FACTOR
        FROM TGK_FIMA_HISENSE.AW_MR9_ARPM01_000001 A
        LEFT JOIN CONVERSION_RATE QCY_RATE
          ON QCY_RATE.COD_VALUTA = TRIM(A.COD_VALUTA_ORIGINARIA)
        LEFT JOIN CONVERSION_RATE BCY_RATE
          ON BCY_RATE.COD_VALUTA = TRIM(A.COD_VALUTA)
        LEFT JOIN TCURR_CONVERSION_RATE TCURR_CONV
          ON TCURR_CONV.TCURR = TRIM(A.COD_VALUTA)
         AND TCURR_CONV.FCURR = TRIM(A.COD_VALUTA_ORIGINARIA)
      WHERE A.COD_SCENARIO = ${$Scenario.code}
        AND A.COD_PERIODO = ${$Period.code}
        /* 公司范围由报表参数传入，保留IN写法以支持多公司。 */
        AND A.COD_AZIENDA IN (${$Entity.code})
        AND NVL(A.LE_AGE_FLAG, '|') <> '|'
        AND A.SRC_DETAIL LIKE 'ORG%'
  ),
  /* CURRENT_SOURCE_BASE按业务键汇总：M01保留原始BCY_0，M02逐行执行汇率换算或合同负债剔税后汇总。 */
  CURRENT_SOURCE_KEY AS (
      SELECT A.COD_AZIENDA
          , A.COD_CONTO
          , A.CUST_CODE
          , MAX(A.CUST_NAME) KEEP (DENSE_RANK FIRST ORDER BY A.OID) AS CUST_NAME
          , A.COD_DEST2
          , SUM(A.BCY_0_AMT) AS M01_BCY_0_AMT
          , SUM(
                CASE
                    WHEN A.SRC_DETAIL LIKE 'ORG%'
                      AND A.LE_AGE_FLAG = 'CL'
                      AND A.IS_REC_LG = 'Y'
                        THEN A.BCY_0_AMT * A.TAX_FACTOR
                    WHEN A.SRC_DETAIL LIKE 'ORG%'
                      AND A.LE_AGE_FLAG NOT IN ('AC', 'AS', 'CL')
                      AND A.CONVERSION_FACTOR IS NOT NULL
                        THEN A.QCY_0_AMT * A.CONVERSION_FACTOR
                    ELSE A.BCY_0_AMT
                END
            ) AS M02_BCY_0_AMT
          , MAX(A.EXCHANGE_RATE_EVAL_FLAG) KEEP (DENSE_RANK FIRST ORDER BY A.OID) AS EXCHANGE_RATE_EVAL_FLAG
          , MAX(A.IS_REC_LG) KEEP (DENSE_RANK FIRST ORDER BY A.OID) AS IS_REC_LG
          , 1 AS CURRENT_SOURCE_MATCHED
        FROM CURRENT_SOURCE_BASE A
      GROUP BY A.COD_AZIENDA
              , A.COD_CONTO
              , A.CUST_CODE
              , A.COD_DEST2
  ),
  /* SUPPLEMENT_AGG完整复用M02过程的补充金额范围、业务键及金额字段。 */
  SUPPLEMENT_AGG AS (
      SELECT S.COD_AZIENDA
          , CASE
                WHEN S.SRC_DETAIL LIKE 'EPAY%'
                  AND NVL(TRIM(S.COD_CONTO), '|') = '|'
                    THEN '1122000000'
                ELSE S.COD_CONTO
            END AS COD_CONTO
          , S.CUST_CODE
          /* ALTER BY 20261104 16:08 SHIQINGFENG.EX 新增科目名称、客商名称和利润中心名称；科目、利润中心名称使用维度函数获取，客商名称直接取补充来源。 */
          , MAX(S.CUST_NAME) AS CUST_NAME
          , S.COD_DEST2
          , SUM(CASE WHEN S.SRC_DETAIL LIKE 'ZTSO04_CK%' THEN NVL(S.BCY_0_AMT, 0) ELSE 0 END) AS SHP_NINV_AMT
          , SUM(CASE WHEN S.SRC_DETAIL LIKE 'ZTSO04_TH%' THEN NVL(S.BCY_0_AMT, 0) ELSE 0 END) AS RET_NTRF_AMT
          , SUM(CASE WHEN S.SRC_DETAIL LIKE 'OVERDUE%' THEN NVL(S.BCY_0_AMT, 0) ELSE 0 END) AS OVERDUE_AMT
          , SUM(CASE WHEN S.SRC_DETAIL LIKE 'INV_SAMPLE%' THEN NVL(S.BCY_0_AMT, 0) ELSE 0 END) AS INV_SAMPLE_AMT
          , SUM(CASE WHEN S.SRC_DETAIL LIKE 'EPAY%' THEN NVL(S.BCY_0_AMT, 0) ELSE 0 END) AS EPAY_AMT
          , SUM(CASE WHEN S.ECLS_FLAG = 'Y' THEN NVL(S.BCY_0_AMT, 0) ELSE 0 END) AS ECLS_AMT
          , SUM(CASE WHEN S.UFEE_UREB_FLAG LIKE 'UREB%' THEN NVL(S.BCY_0_AMT, 0) ELSE 0 END) AS UREB_AMT
          , SUM(CASE WHEN S.UFEE_UREB_FLAG LIKE 'UFEE%' THEN NVL(S.BCY_0_AMT, 0) ELSE 0 END) AS UFEE_AMT
        FROM TGK_FIMA_HISENSE.AW_MR9_ARPM01_000001 S
      WHERE S.COD_SCENARIO = ${$Scenario.code}
        AND S.COD_PERIODO = ${$Period.code}
        /* 公司范围与CURRENT_SOURCE_BASE保持一致。 */
        AND S.COD_AZIENDA IN (${$Entity.code})
        AND (
              S.SRC_DETAIL LIKE 'ZTSO04_CK%'
            OR S.SRC_DETAIL LIKE 'ZTSO04_TH%'
            OR S.SRC_DETAIL LIKE 'OVERDUE%'
            OR S.SRC_DETAIL LIKE 'INV_SAMPLE%'
            OR S.SRC_DETAIL LIKE 'EPAY%'
            OR S.ECLS_FLAG = 'Y'
            OR S.UFEE_UREB_FLAG LIKE 'UREB%'
            OR S.UFEE_UREB_FLAG LIKE 'UFEE%'
        )
      GROUP BY S.COD_AZIENDA
              , CASE
                    WHEN S.SRC_DETAIL LIKE 'EPAY%'
                    AND NVL(TRIM(S.COD_CONTO), '|') = '|'
                        THEN '1122000000'
                    ELSE S.COD_CONTO
                END
              , S.CUST_CODE
              , S.COD_DEST2
  ),
  /* M01重算结果与补充来源业务键取并集，完整保留仅M01/M02计算数据和仅补充金额数据。 */
  /* ALTER BY 20261104 17:56 SHIQINGFENG.EX 恢复校验设计：M02金额按存储过程从M01重算，不读取M02目标表；删除CURRENT_SOURCE_ROW_CNT，并完成M01/M02键级对账。 */
  ALL_KEYS AS (
      SELECT A.COD_AZIENDA
          , A.COD_CONTO
          , A.CUST_CODE
          , A.COD_DEST2
        FROM CURRENT_SOURCE_KEY A
      UNION
      SELECT S.COD_AZIENDA
          , S.COD_CONTO
          , S.CUST_CODE
          , S.COD_DEST2
        FROM SUPPLEMENT_AGG S
  )
  /* 以业务键并集为主表，分别回连当前来源和补充来源，支持三类数据范围校验。 */
  /* ALTER BY 20261104 16:08 SHIQINGFENG.EX 新增科目名称、客商名称和利润中心名称；科目、利润中心名称使用维度函数获取，客商名称直接取补充来源。 */
  SELECT K.COD_AZIENDA                                            AS COD_AZIENDA       /* 公司 */
      , K.COD_CONTO                                              AS COD_CONTO         /* 科目 */
      , F_TGK_GET_DIMNAME('CONTO', NVL(K.COD_CONTO, 'ZZZZ'))     AS COD_CONTO_NAME    /* 科目名称 */
      , K.CUST_CODE                                              AS CUST_CODE         /* 客商 */
      , NVL(S.CUST_NAME, C.CUST_NAME)                            AS CUST_NAME         /* 客商名称 */
      , K.COD_DEST2                                              AS COD_DEST2         /* 利润中心 */
      , F_TGK_GET_DIMNAME('DEST2', NVL(K.COD_DEST2, 'ZZZZ'))     AS COD_DEST2_NAME    /* 利润中心名称 */
      /* ALTER BY 20261104 17:02 SHIQINGFENG.EX 新增M01金额、M02口径金额、汇率评估标识和是否重分类-法人；M02金额复用过程的汇率换算及合同负债剔税逻辑。 */
      , CASE
            WHEN S.COD_AZIENDA IS NULL
                THEN 'Y-有账龄但无调整金额'
            WHEN C.CURRENT_SOURCE_MATCHED IS NOT NULL
                THEN 'Y-有账龄及调整金额列'
            ELSE 'N-无账龄但有调整金额'
        END                                                      AS M02_ENTRY_FLAG    /* 数据范围及补充金额进入M02标识 */
      , NVL(C.M01_BCY_0_AMT, 0)                                 AS M01_BCY_0_AMT     /* M01原始本位币金额 */
      , NVL(C.M02_BCY_0_AMT, 0)                                 AS M02_BCY_0_AMT     /* M02汇率换算或合同负债剔税后金额 */
      , C.EXCHANGE_RATE_EVAL_FLAG                                AS EXCHANGE_RATE_EVAL_FLAG /* 汇率评估标识 */
      , C.IS_REC_LG                                              AS IS_REC_LG         /* 是否重分类-法人 */
      , NVL(S.SHP_NINV_AMT, 0)                                  AS SHP_NINV_AMT      /* 已发货未开票金额 */
      , NVL(S.RET_NTRF_AMT, 0)                                  AS RET_NTRF_AMT      /* 退货未过账金额 */
      , NVL(S.OVERDUE_AMT, 0)                                   AS OVERDUE_AMT       /* 超期款金额 */
      , NVL(S.INV_SAMPLE_AMT, 0)                                AS INV_SAMPLE_AMT    /* 样机款金额 */
      , NVL(S.EPAY_AMT, 0)                                      AS EPAY_AMT          /* 提前回款金额 */
      , NVL(S.ECLS_AMT, 0)                                      AS ECLS_AMT          /* 电商零售金额 */
      , NVL(S.UREB_AMT, 0)                                      AS UREB_AMT          /* 未结返利金额 */
      , NVL(S.UFEE_AMT, 0)                                      AS UFEE_AMT          /* 未结费用金额 */
    FROM ALL_KEYS K
    LEFT JOIN CURRENT_SOURCE_KEY C
      ON C.COD_AZIENDA = K.COD_AZIENDA
     AND NVL(C.COD_CONTO, '#') = NVL(K.COD_CONTO, '#')
     AND NVL(C.CUST_CODE, '#') = NVL(K.CUST_CODE, '#')
     AND NVL(C.COD_DEST2, '#') = NVL(K.COD_DEST2, '#')
    LEFT JOIN SUPPLEMENT_AGG S
      ON S.COD_AZIENDA = K.COD_AZIENDA
     AND NVL(S.COD_CONTO, '#') = NVL(K.COD_CONTO, '#')
     AND NVL(S.CUST_CODE, '#') = NVL(K.CUST_CODE, '#')
     AND NVL(S.COD_DEST2, '#') = NVL(K.COD_DEST2, '#')
   /* 金额全为 0 的记录不输出 */
   WHERE NVL(C.M01_BCY_0_AMT, 0) <> 0
      OR NVL(C.M02_BCY_0_AMT, 0) <> 0
      OR NVL(S.SHP_NINV_AMT, 0) <> 0
      OR NVL(S.RET_NTRF_AMT, 0) <> 0
      OR NVL(S.OVERDUE_AMT, 0) <> 0
      OR NVL(S.INV_SAMPLE_AMT, 0) <> 0
      OR NVL(S.EPAY_AMT, 0) <> 0
      OR NVL(S.ECLS_AMT, 0) <> 0
      OR NVL(S.UREB_AMT, 0) <> 0
      OR NVL(S.UFEE_AMT, 0) <> 0
  ORDER BY M02_ENTRY_FLAG
          , K.COD_AZIENDA
          , K.COD_CONTO
          , K.CUST_CODE
          , K.COD_DEST2
