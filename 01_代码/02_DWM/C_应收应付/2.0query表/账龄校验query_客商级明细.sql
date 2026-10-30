/* ============================================================================
 * 查询说明
 *   查询名称：账龄校验（客商级明细）
 *   功能描述：按公司 + 往来项目 + 客商校验 2.0 账龄表与 1.0 账龄表的年初/上月/本月余额，
 *             并标记该客商是「两边都有 / 仅2.0有 / 仅1.0有」，附 1.0 的调整标记。
 *   宿主表  ：TGK_FIMA_HISENSE.AW_MR9_ARPM02_000001（2.0 账龄）
 *             TGK_GB_HISENSE.FORM_DATI（1.0 账龄）
 *   展示逻辑：按 公司 -> 往来项目 -> 客商编码 排序，只输出存在差异的客商
 *
 *   参数    ：场景 ${$Scenario.code}｜期间 ${$Period.code}｜公司 ${$Entity.code}
 *   口径要点：
 *     1. 客商编码去前导零；全零编码 LTRIM 后为空串（Oracle 空串=NULL），统一置 '(NO_CUST)' 便于配对。
 *     2. 1.0 侧客商编码/名称按科目首位取不同字段：
 *        1 开头（资产）取 TESTO_14 / TESTO_15；2 开头（负债）取 TESTO_5 / TESTO_6。
 *     3. 1.0 的集团所属范围由 COD_CATEGORIA 体现，此处只做合计口径（三类全取）。
 *     4. 差异 = 2.0 - 1.0，>0 表示 2.0 多算。
 * ==========================================================================*/
WITH PARAMS AS (
    SELECT ${$Scenario.code} AS P_SCENARIO
         , ${$Period.code}   AS P_PERIODO
    FROM   DUAL
),
/* 公司限制清单：从公司主数据取，IN 里填要查的公司编码。 */
AZI AS (
    SELECT A.COD_AZIENDA
    FROM   TGK_FIMA_HISENSE.AZIENDA A
    WHERE  A.COD_AZIENDA IN (${$Entity.code})
),
/* 往来项目与科目映射（2.0 / 1.0 账龄表均为精确科目号）。 */
ITM AS (
    SELECT '应收账款'     ITEM_NAME,  1 SEQ, '1122000000' CONTO20, '1122000000' CONTO10 FROM DUAL UNION ALL
    SELECT '其他应收款'   ITEM_NAME,  2 SEQ, '122101F'    CONTO20, '122101F'    CONTO10 FROM DUAL UNION ALL
    SELECT '预付账款'     ITEM_NAME,  3 SEQ, '1123000000' CONTO20, '1123000000' CONTO10 FROM DUAL UNION ALL
    SELECT '应收款项融资' ITEM_NAME,  4 SEQ, '1124001000' CONTO20, '1124001000' CONTO10 FROM DUAL UNION ALL
    SELECT '合同资产'     ITEM_NAME,  5 SEQ, '1460000000' CONTO20, '1460000000' CONTO10 FROM DUAL UNION ALL
    SELECT '应付账款'     ITEM_NAME,  6 SEQ, '2202000000' CONTO20, '2202000000' CONTO10 FROM DUAL UNION ALL
    SELECT '其他应付款'   ITEM_NAME,  7 SEQ, '224199F'    CONTO20, '224199F'    CONTO10 FROM DUAL UNION ALL
    SELECT '预收账款'     ITEM_NAME,  8 SEQ, '2203000000' CONTO20, '2203000000' CONTO10 FROM DUAL UNION ALL
    SELECT '合同负债'     ITEM_NAME,  9 SEQ, '2204000000' CONTO20, '2204000000' CONTO10 FROM DUAL UNION ALL
    SELECT '长期应收款'   ITEM_NAME, 10 SEQ, '1531000000' CONTO20, '1531000000' CONTO10 FROM DUAL
),
/* 2.0 账龄表：公司 + 项目 + 客商 聚合。 */
T20C AS (
    SELECT A.COD_AZIENDA                                                      COMPANY_CODE
         , I.SEQ
         , I.ITEM_NAME
         , NVL(LTRIM(A.CUST_HEAD_CODE, '0'), '(NO_CUST)')                     CUST_CODE
         , MAX(A.CUST_HEAD_NAME)                                              CUST_NAME
         , COUNT(*)                                                           ROW_CNT
         , SUM(A.BY_BCY_0_AMT)                                                BY_AMT
         , SUM(A.LM_BCY_0_AMT)                                                LM_AMT
         , SUM(A.BCY_0_AMT)                                                   CUR_AMT
    FROM   TGK_FIMA_HISENSE.AW_MR9_ARPM02_000001 A
    CROSS  JOIN PARAMS P
    JOIN   ITM I
      ON   A.COD_CONTO = I.CONTO20
    WHERE  A.COD_PERIODO   = P.P_PERIODO
      AND  A.COD_CATEGORIA = 'ZAMOUNT'
      AND  A.COD_SCENARIO  = P.P_SCENARIO
      AND  A.COD_AZIENDA   IN (SELECT COD_AZIENDA FROM AZI)
    GROUP  BY A.COD_AZIENDA
            , I.SEQ
            , I.ITEM_NAME
            , NVL(LTRIM(A.CUST_HEAD_CODE, '0'), '(NO_CUST)')
),
/* 1.0 账龄表：公司 + 项目 + 客商 聚合（客商编码/名称按科目首位取不同字段）。 */
T10C AS (
    SELECT F.COD_AZIENDA                                                     COMPANY_CODE
         , I.SEQ
         , I.ITEM_NAME
         , NVL(LTRIM(CASE WHEN SUBSTR(F.COD_CONTO, 1, 1) = '1'
                          THEN F.TESTO_14
                          ELSE F.TESTO_5
                     END, '0'), '(NO_CUST)')                                 CUST_CODE
         , MAX(CASE WHEN SUBSTR(F.COD_CONTO, 1, 1) = '1'
                    THEN F.TESTO_15
                    ELSE F.TESTO_6
               END)                                                          CUST_NAME
         , MAX(F.IMPORTO_36)                                                 ADJ_FLAG
         , COUNT(*)                                                          ROW_CNT
         , SUM(F.IMPORTO_1)                                                  BY_AMT
         , SUM(F.IMPORTO_2)                                                  LM_AMT
         , SUM(F.IMPORTO_3)                                                  CUR_AMT
    FROM   TGK_GB_HISENSE.FORM_DATI F
    CROSS  JOIN PARAMS P
    JOIN   ITM I
      ON   F.COD_CONTO = I.CONTO10
    WHERE  F.COD_PROSPETTO IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
      AND  F.COD_CATEGORIA IN ('$AMOUNT', '1ADJ', '1REC')
      AND  F.COD_PERIODO   = P.P_PERIODO
      AND  F.COD_SCENARIO  = P.P_SCENARIO
      AND  F.COD_AZIENDA   IN (SELECT COD_AZIENDA FROM AZI)
    GROUP  BY F.COD_AZIENDA
            , I.SEQ
            , I.ITEM_NAME
            , NVL(LTRIM(CASE WHEN SUBSTR(F.COD_CONTO, 1, 1) = '1'
                             THEN F.TESTO_14
                             ELSE F.TESTO_5
                        END, '0'), '(NO_CUST)')
)
SELECT NVL(T20C.COMPANY_CODE, T10C.COMPANY_CODE)                   AS COMPANY_CODE
     , NVL(T20C.ITEM_NAME, T10C.ITEM_NAME)                         AS ITEM_NAME
     , NVL(T20C.CUST_CODE, T10C.CUST_CODE)                         AS CUST_CODE
     , NVL(T20C.CUST_NAME, T10C.CUST_NAME)                         AS CUST_NAME
     /* 2.0 账龄：年初 / 上月 / 本月 */
     , NVL(T20C.BY_AMT, 0)                                         AS BY_AMT_20
     , NVL(T20C.LM_AMT, 0)                                         AS LM_AMT_20
     , NVL(T20C.CUR_AMT, 0)                                        AS CUR_AMT_20
     /* 1.0 账龄：年初 / 上月 / 本月 */
     , NVL(T10C.BY_AMT, 0)                                         AS BY_AMT_10
     , NVL(T10C.LM_AMT, 0)                                         AS LM_AMT_10
     , NVL(T10C.CUR_AMT, 0)                                        AS CUR_AMT_10
     /* 差异 = 2.0 - 1.0 */
     , NVL(T20C.BY_AMT, 0)  - NVL(T10C.BY_AMT, 0)                   AS BY_AMT_DIFF
     , NVL(T20C.LM_AMT, 0)  - NVL(T10C.LM_AMT, 0)                   AS LM_AMT_DIFF
     , NVL(T20C.CUR_AMT, 0) - NVL(T10C.CUR_AMT, 0)                  AS CUR_AMT_DIFF
     /* 来源标记：用行数判断，避免客商编码为空导致误判 */
     , CASE WHEN NVL(T20C.ROW_CNT, 0) = 0 THEN '仅1.0有'
            WHEN NVL(T10C.ROW_CNT, 0) = 0 THEN '仅2.0有'
            ELSE '两边都有'
        END                                                         AS MATCH_FLAG
     /* 调整标记：取自 1.0 FORM_DATI.IMPORTO_36 */
     , NVL(T10C.ADJ_FLAG, 0)                                        AS ADJ_FLAG
FROM   T20C
FULL   OUTER JOIN T10C
       ON  T20C.COMPANY_CODE = T10C.COMPANY_CODE
       AND T20C.SEQ          = T10C.SEQ
       AND T20C.CUST_CODE    = T10C.CUST_CODE
/* 只输出有差异的客商；要看全量把下面三个条件注释掉 */
WHERE  NVL(T20C.BY_AMT, 0)  - NVL(T10C.BY_AMT, 0)  NOT BETWEEN -0.01 AND 0.01
   OR  NVL(T20C.LM_AMT, 0)  - NVL(T10C.LM_AMT, 0)  NOT BETWEEN -0.01 AND 0.01
   OR  NVL(T20C.CUR_AMT, 0) - NVL(T10C.CUR_AMT, 0) NOT BETWEEN -0.01 AND 0.01
ORDER  BY NVL(T20C.COMPANY_CODE, T10C.COMPANY_CODE)
        , NVL(T20C.SEQ, T10C.SEQ)
        , NVL(T20C.CUST_CODE, T10C.CUST_CODE)
