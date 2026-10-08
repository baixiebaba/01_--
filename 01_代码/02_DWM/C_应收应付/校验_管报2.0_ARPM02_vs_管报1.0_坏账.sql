/* ============================================================================
 * 坏账结果表差异校验 —— 2.0 ARPM02 vs 1.0 ZTAB_AG_TF_OC
 *   数据源A(2.0) : TGK_FIMA_DEV.AW_MR9_ARPM02_000001  (管报系统2.0)
 *   数据源B(1.0) : TGK_GB_HISENSE.ZTAB_AG_TF_OC        (管报系统1.0)
 *
 * 输出: 场景期间、公司、科目大类、2.0金额、1.0金额、差异
 *   2.0金额 = BD_AFAL_0_AMT
 *   1.0金额 = HZYE
 *   粒度: 公司 + 科目大类
 *
 * 版本记录:
 *   2026-03-09  新增坏账结果差异校验
 * ============================================================================*/
WITH
/* 坏账校验科目大类及两套系统对应科目 */
ITM AS (
    SELECT '应收账款'    AS ITEM_NAME
           , 1            AS SEQ
           , '1122000000' AS CONTO20
           , '1122000000' AS CONTO10
    FROM   DUAL
    UNION ALL
    SELECT '其他应收款'  AS ITEM_NAME
           , 2            AS SEQ
           , '122101F'    AS CONTO20
           , '122101F'    AS CONTO10
    FROM   DUAL
    UNION ALL
    SELECT '合同资产'    AS ITEM_NAME
           , 3            AS SEQ
           , '1460000000' AS CONTO20
           , '1460000000' AS CONTO10
    FROM   DUAL
),
/* 2.0 坏账金额: 本月按公司+科目大类汇总 */
T20 AS (
    SELECT A.COD_SCENARIO || A.COD_PERIODO AS SCENARIO_PERIOD
           , A.COD_AZIENDA                 AS COMPANY_CODE
           , I.SEQ                         AS ITEM_SEQ
           , I.ITEM_NAME                   AS ITEM_NAME
           , SUM(A.BD_AFAL_0_AMT)          AS AMT_20
    FROM   TGK_FIMA_DEV.AW_MR9_ARPM02_000001 A
    JOIN   ITM I
           ON I.CONTO20 = A.COD_CONTO
    WHERE  A.COD_SCENARIO  = ${$Scenario.code}
      AND  A.COD_PERIODO   = ${$Period.code}
      AND  A.COD_CATEGORIA = 'ZAMOUNT'
      AND  A.COD_AZIENDA   IN (${$Entity.code})
    GROUP  BY A.COD_SCENARIO || A.COD_PERIODO
              , A.COD_AZIENDA
              , I.SEQ
              , I.ITEM_NAME
),
/* 1.0 坏账金额: 本月按公司+科目大类汇总 */
T10 AS (
    SELECT SUBSTR(${$Scenario.code}, 1, 4) || ${$Period.code} AS SCENARIO_PERIOD
           , T.BUKRS                                             AS COMPANY_CODE
           , I.SEQ                                                AS ITEM_SEQ
           , I.ITEM_NAME                                          AS ITEM_NAME
           , SUM(T.HZYE)                                          AS AMT_10
    FROM   TGK_GB_HISENSE.ZTAB_AG_TF_OC T
    JOIN   ITM I
           ON I.CONTO10 = T.HKONT
    WHERE  T.YEARMONTH = SUBSTR(${$Scenario.code}, 1, 4) || ${$Period.code}
      AND  T.BUKRS     IN (${$Entity.code})
    GROUP  BY SUBSTR(${$Scenario.code}, 1, 4) || ${$Period.code}
              , T.BUKRS
              , I.SEQ
              , I.ITEM_NAME
)
SELECT   NVL(T20.ITEM_NAME, T10.ITEM_NAME)           AS ITEM_NAME
       , NVL(T20.AMT_20, 0)                          AS AMT_20
       , NVL(T10.AMT_10, 0)                          AS AMT_10
       , NVL(T20.AMT_20, 0) - NVL(T10.AMT_10, 0)     AS AMT_DIFF
FROM   T20
FULL   OUTER JOIN T10
       ON  T20.COMPANY_CODE = T10.COMPANY_CODE
       AND T20.ITEM_SEQ     = T10.ITEM_SEQ
ORDER  BY NVL(T20.COMPANY_CODE, T10.COMPANY_CODE)
          , NVL(T20.ITEM_SEQ, T10.ITEM_SEQ)