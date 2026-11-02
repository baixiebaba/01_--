WITH
/* 往来项目、2.0/1.0账龄表科目映射，以及单体法人科目节点映射。 */
ITM AS (
    SELECT '应收账款'     ITEM_NAME,  1 SEQ, '1122000000' CONTO20, '1122000000' CONTO10, '1122'       NODE_CODE FROM DUAL UNION ALL
    SELECT '其他应收款'   ITEM_NAME,  2 SEQ, '122101F'    CONTO20, '122101F'    CONTO10, '1221'       NODE_CODE FROM DUAL UNION ALL
    SELECT '预付账款'     ITEM_NAME,  3 SEQ, '1123000000' CONTO20, '1123000000' CONTO10, '1123'       NODE_CODE FROM DUAL UNION ALL
    SELECT '应收款项融资' ITEM_NAME,  4 SEQ, '1124001000' CONTO20, '1124001000' CONTO10, '112400'     NODE_CODE FROM DUAL UNION ALL
    SELECT '合同资产'     ITEM_NAME,  5 SEQ, '1460000000' CONTO20, '1460000000' CONTO10, '146200A01'  NODE_CODE FROM DUAL UNION ALL
    SELECT '合同资产'     ITEM_NAME,  5 SEQ, '1460000000' CONTO20, '1460000000' CONTO10, '1910000A30' NODE_CODE FROM DUAL UNION ALL
    SELECT '应付账款'     ITEM_NAME,  6 SEQ, '2202000000' CONTO20, '2202000000' CONTO10, '220200'     NODE_CODE FROM DUAL UNION ALL
    SELECT '其他应付款'   ITEM_NAME,  7 SEQ, '224199F'    CONTO20, '224199F'    CONTO10, '224100'     NODE_CODE FROM DUAL UNION ALL
    SELECT '预收账款'     ITEM_NAME,  8 SEQ, '2203000000' CONTO20, '2203000000' CONTO10, '220300'     NODE_CODE FROM DUAL UNION ALL
    SELECT '合同负债'     ITEM_NAME,  9 SEQ, '2204000000' CONTO20, '2204000000' CONTO10, '220400'     NODE_CODE FROM DUAL UNION ALL
    SELECT '长期应收款'   ITEM_NAME, 10 SEQ, '1531000000' CONTO20, '1531000000' CONTO10, '153110'     NODE_CODE FROM DUAL
),
/* 合同资产存在两个单体法人节点；2.0和1.0账龄汇总时按项目科目去重。 */
ITM_DEDUP AS (
    SELECT SEQ
         , ITEM_NAME
         , CONTO20
         , CONTO10
    FROM   ITM
    GROUP  BY SEQ
            , ITEM_NAME
            , CONTO20
            , CONTO10
),
/* 原合计口径：2.0账龄表按公司和往来项目汇总，保留原有全部集团所属范围数据。 */
T20_TOTAL AS (
    SELECT A.COD_AZIENDA COMPANY_CODE
         , I.SEQ
         , I.ITEM_NAME
         , SUM(A.BY_BCY_0_AMT) BY_AMT
         , SUM(A.LM_BCY_0_AMT) LM_AMT
         , SUM(A.BCY_0_AMT)    CUR_AMT
    FROM   AW_MR9_ARPM02_000001 A
    JOIN   ITM_DEDUP I
      ON   A.COD_CONTO = I.CONTO20
    WHERE  A.COD_PERIODO   = ${$Period.code}
      AND  A.COD_CATEGORIA = 'ZAMOUNT'
      AND  A.COD_SCENARIO  = ${$Scenario.code}
      /* 公司限制已下沉至本数据包内部。 */
      AND  A.COD_AZIENDA   IN (${$Entity.code})
    GROUP  BY A.COD_AZIENDA
            , I.SEQ
            , I.ITEM_NAME
),
/* 原合计口径：1.0账龄表按公司和往来项目汇总，保留原有三类账龄类别。 */
T10_TOTAL AS (
    SELECT F.COD_AZIENDA COMPANY_CODE
         , I.SEQ
         , I.ITEM_NAME
         , SUM(F.IMPORTO_1) BY_AMT
         , SUM(F.IMPORTO_2) LM_AMT
         , SUM(F.IMPORTO_3) CUR_AMT
    FROM   TGK_GB_HISENSEFORM_DATI F
    JOIN   ITM_DEDUP I
      ON   F.COD_CONTO = I.CONTO10
    WHERE  F.COD_PROSPETTO IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
      AND  F.COD_CATEGORIA IN ('$AMOUNT', '1ADJ', '1REC')
      AND  F.COD_PERIODO   = ${$Period.code}
      AND  F.COD_SCENARIO  = ${$Scenario.code}
      /* 公司限制已下沉至本数据包内部。 */
      AND  F.COD_AZIENDA   IN (${$Entity.code})
    GROUP  BY F.COD_AZIENDA
            , I.SEQ
            , I.ITEM_NAME
),
/* 原合计口径：HIE='01'下节点与科目的全量映射。 */
NODE_ELEM AS (
    SELECT RC.NODE
         , RC.ELEM
    FROM   TGK_GB_HISENSE.V_REF_CONTO RC
    WHERE  RC.HIE = '01'
),
/* 原合计口径：单体法人按年初、上月和本月快照汇总。 */
TSD AS (
    SELECT S.COD_AZIENDA COMPANY_CODE
         , I.SEQ
         , I.ITEM_NAME
         , SUM(CASE
                   WHEN S.COD_SCENARIO = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                    AND S.COD_PERIODO = '12'
                   THEN S.IMPORTO
               END) BY_AMT
         , SUM(CASE
                   WHEN S.COD_SCENARIO = CASE
                                             WHEN ${$Period.code} = '01'
                                             THEN TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                                             ELSE ${$Scenario.code}
                                         END
                    AND S.COD_PERIODO = CASE
                                             WHEN ${$Period.code} = '01' THEN '12'
                                             ELSE LPAD(TO_NUMBER(${$Period.code}) - 1, 2, '0')
                                         END
                   THEN S.IMPORTO
               END) LM_AMT
         , SUM(CASE
                   WHEN S.COD_SCENARIO = ${$Scenario.code}
                    AND S.COD_PERIODO = ${$Period.code}
                   THEN S.IMPORTO
               END) CUR_AMT
    FROM   TGK_GB_HISENSEDATI_SALDI_LORDI S
    JOIN   NODE_ELEM NE
      ON   NE.ELEM = S.COD_CONTO
    JOIN   ITM I
      ON   I.NODE_CODE = NE.NODE
    WHERE  ((S.COD_SCENARIO = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
             AND S.COD_PERIODO = '12')
            OR (S.COD_SCENARIO = CASE
                                      WHEN ${$Period.code} = '01'
                                      THEN TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                                      ELSE ${$Scenario.code}
                                  END
                AND S.COD_PERIODO = CASE
                                        WHEN ${$Period.code} = '01' THEN '12'
                                        ELSE LPAD(TO_NUMBER(${$Period.code}) - 1, 2, '0')
                                    END)
            OR (S.COD_SCENARIO = ${$Scenario.code}
                AND S.COD_PERIODO = ${$Period.code}))
      AND  S.COD_CATEGORIA IN ('$AMOUNT', '1ADJ', '1SPA', '1REC', '2ADJ_CF', '2ADJ_OB')
      /* 公司限制已下沉至本数据包内部。 */
      AND  S.COD_AZIENDA   IN (${$Entity.code})
    GROUP  BY S.COD_AZIENDA
            , I.SEQ
            , I.ITEM_NAME
),
/* 原合计口径的公司驱动集合，保留单体法人来源公司。 */
COMPANY_DIM_TOTAL AS (
    SELECT COMPANY_CODE FROM T20_TOTAL
    UNION
    SELECT COMPANY_CODE FROM T10_TOTAL
    UNION
    SELECT COMPANY_CODE FROM TSD
),
/* ALTER BY SHIQINGFENG.EX 20261023 18:30 在原合计后新增集团所属范围三段校验；新增段Lordi固定为0且不参与校验。 */
/* 新增三段校验配置：控制2.0集团所属范围、1.0类别和展示顺序。 */
SCOPE_CONFIG AS (
    SELECT 1 SCOPE_SEQ, '所属子公司' GROUP_SCOPE, 'SUB-子公司' T20_GRP_SCOPE, '$AMOUNT' T10_CATEGORY FROM DUAL UNION ALL
    SELECT 2 SCOPE_SEQ, '集团内'     GROUP_SCOPE, 'GIN-集团内' T20_GRP_SCOPE, '1ADJ'    T10_CATEGORY FROM DUAL UNION ALL
    SELECT 3 SCOPE_SEQ, '集团外'     GROUP_SCOPE, 'GEX-集团外' T20_GRP_SCOPE, '1REC'    T10_CATEGORY FROM DUAL
),
/* 新增范围口径：2.0账龄按公司、往来项目和集团所属范围汇总。 */
T20_SCOPE AS (
    SELECT A.COD_AZIENDA COMPANY_CODE
         , I.SEQ
         , I.ITEM_NAME
         , SC.SCOPE_SEQ
         , SC.GROUP_SCOPE
         , SUM(A.BY_BCY_0_AMT) BY_AMT
         , SUM(A.LM_BCY_0_AMT) LM_AMT
         , SUM(A.BCY_0_AMT)    CUR_AMT
    FROM   AW_MR9_ARPM02_000001 A
    JOIN   ITM_DEDUP I
      ON   A.COD_CONTO = I.CONTO20
    JOIN   SCOPE_CONFIG SC
      ON   A.GRP_SCOPE = SC.T20_GRP_SCOPE
    WHERE  A.COD_PERIODO   = ${$Period.code}
      AND  A.COD_CATEGORIA = 'ZAMOUNT'
      AND  A.COD_SCENARIO  = ${$Scenario.code}
      /* 公司限制已下沉至本数据包内部。 */
      AND  A.COD_AZIENDA   IN (${$Entity.code})
    GROUP  BY A.COD_AZIENDA
            , I.SEQ
            , I.ITEM_NAME
            , SC.SCOPE_SEQ
            , SC.GROUP_SCOPE
),
/* 新增范围口径：1.0账龄按三段配置限定类别后汇总。 */
T10_SCOPE AS (
    SELECT F.COD_AZIENDA COMPANY_CODE
         , I.SEQ
         , I.ITEM_NAME
         , SC.SCOPE_SEQ
         , SC.GROUP_SCOPE
         , SUM(F.IMPORTO_1) BY_AMT
         , SUM(F.IMPORTO_2) LM_AMT
         , SUM(F.IMPORTO_3) CUR_AMT
    FROM   TGK_GB_HISENSEFORM_DATI F
    JOIN   ITM_DEDUP I
      ON   F.COD_CONTO = I.CONTO10
    JOIN   SCOPE_CONFIG SC
      ON   F.COD_CATEGORIA = SC.T10_CATEGORY
    WHERE  F.COD_PROSPETTO IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
      AND  F.COD_PERIODO   = ${$Period.code}
      AND  F.COD_SCENARIO  = ${$Scenario.code}
      /* 公司限制已下沉至本数据包内部。 */
      AND  F.COD_AZIENDA   IN (${$Entity.code})
    GROUP  BY F.COD_AZIENDA
            , I.SEQ
            , I.ITEM_NAME
            , SC.SCOPE_SEQ
            , SC.GROUP_SCOPE
),
/* 新增范围口径的公司驱动集合，仅由2.0和1.0账龄表构成。 */
COMPANY_DIM_SCOPE AS (
    SELECT COMPANY_CODE FROM T20_SCOPE
    UNION
    SELECT COMPANY_CODE FROM T10_SCOPE
),
/* 原合计结果：金额和单体法人校验逻辑保持原样，仅补充总计范围标识。 */
TOTAL_RESULT AS (
    SELECT C.COMPANY_CODE
         , I.ITEM_NAME
         , '总计' GROUP_SCOPE
         , NVL(T20.BY_AMT, 0) BY_AMT_20
         , NVL(T20.LM_AMT, 0) LM_AMT_20
         , NVL(T20.CUR_AMT, 0) CUR_AMT_20
         , NVL(T10.BY_AMT, 0) BY_AMT_10
         , NVL(T10.LM_AMT, 0) LM_AMT_10
         , NVL(T10.CUR_AMT, 0) CUR_AMT_10
         , NVL(TSD.BY_AMT, 0) BY_AMT_LORDI
         , NVL(TSD.LM_AMT, 0) LM_AMT_LORDI
         , NVL(TSD.CUR_AMT, 0) CUR_AMT_LORDI
         , NVL(T20.BY_AMT, 0) - NVL(T10.BY_AMT, 0) BY_AMT_DIFF
         , NVL(T20.LM_AMT, 0) - NVL(T10.LM_AMT, 0) LM_AMT_DIFF
         , NVL(T20.CUR_AMT, 0) - NVL(T10.CUR_AMT, 0) CUR_AMT_DIFF
         , I.SEQ ITEM_SEQ
         , 0 SCOPE_SEQ
    FROM   COMPANY_DIM_TOTAL C
    CROSS  JOIN ITM_DEDUP I
    LEFT   JOIN T20_TOTAL T20
      ON   T20.COMPANY_CODE = C.COMPANY_CODE
     AND   T20.SEQ          = I.SEQ
    LEFT   JOIN T10_TOTAL T10
      ON   T10.COMPANY_CODE = C.COMPANY_CODE
     AND   T10.SEQ          = I.SEQ
    LEFT   JOIN TSD
      ON   TSD.COMPANY_CODE = C.COMPANY_CODE
     AND   TSD.SEQ          = I.SEQ
),
/* 新增范围结果：不读取单体法人表，Lordi金额固定为0，只校验2.0与1.0账龄。 */
SCOPE_RESULT AS (
    SELECT C.COMPANY_CODE
         , I.ITEM_NAME
         , SC.GROUP_SCOPE
         , NVL(T20.BY_AMT, 0) BY_AMT_20
         , NVL(T20.LM_AMT, 0) LM_AMT_20
         , NVL(T20.CUR_AMT, 0) CUR_AMT_20
         , NVL(T10.BY_AMT, 0) BY_AMT_10
         , NVL(T10.LM_AMT, 0) LM_AMT_10
         , NVL(T10.CUR_AMT, 0) CUR_AMT_10
         , 0 BY_AMT_LORDI
         , 0 LM_AMT_LORDI
         , 0 CUR_AMT_LORDI
         , NVL(T20.BY_AMT, 0) - NVL(T10.BY_AMT, 0) BY_AMT_DIFF
         , NVL(T20.LM_AMT, 0) - NVL(T10.LM_AMT, 0) LM_AMT_DIFF
         , NVL(T20.CUR_AMT, 0) - NVL(T10.CUR_AMT, 0) CUR_AMT_DIFF
         , I.SEQ ITEM_SEQ
         , SC.SCOPE_SEQ
    FROM   COMPANY_DIM_SCOPE C
    CROSS  JOIN ITM_DEDUP I
    CROSS  JOIN SCOPE_CONFIG SC
    LEFT   JOIN T20_SCOPE T20
      ON   T20.COMPANY_CODE = C.COMPANY_CODE
     AND   T20.SEQ          = I.SEQ
     AND   T20.SCOPE_SEQ    = SC.SCOPE_SEQ
    LEFT   JOIN T10_SCOPE T10
      ON   T10.COMPANY_CODE = C.COMPANY_CODE
     AND   T10.SEQ          = I.SEQ
     AND   T10.SCOPE_SEQ    = SC.SCOPE_SEQ
),
/* 合计结果与新增三段范围结果并集展示。 */
ALL_RESULT AS (
    SELECT COMPANY_CODE
         , ITEM_NAME
         , GROUP_SCOPE
         , BY_AMT_20
         , LM_AMT_20
         , CUR_AMT_20
         , BY_AMT_10
         , LM_AMT_10
         , CUR_AMT_10
         , BY_AMT_LORDI
         , LM_AMT_LORDI
         , CUR_AMT_LORDI
         , BY_AMT_DIFF
         , LM_AMT_DIFF
         , CUR_AMT_DIFF
         , ITEM_SEQ
         , SCOPE_SEQ
    FROM   TOTAL_RESULT
    UNION ALL
    SELECT COMPANY_CODE
         , ITEM_NAME
         , GROUP_SCOPE
         , BY_AMT_20
         , LM_AMT_20
         , CUR_AMT_20
         , BY_AMT_10
         , LM_AMT_10
         , CUR_AMT_10
         , BY_AMT_LORDI
         , LM_AMT_LORDI
         , CUR_AMT_LORDI
         , BY_AMT_DIFF
         , LM_AMT_DIFF
         , CUR_AMT_DIFF
         , ITEM_SEQ
         , SCOPE_SEQ
    FROM   SCOPE_RESULT
)
SELECT COMPANY_CODE
     , ITEM_NAME
     , GROUP_SCOPE
     , BY_AMT_20
     , LM_AMT_20
     , CUR_AMT_20
     , BY_AMT_10
     , LM_AMT_10
     , CUR_AMT_10
     , BY_AMT_LORDI
     , LM_AMT_LORDI
     , CUR_AMT_LORDI
     , BY_AMT_DIFF
     , LM_AMT_DIFF
     , CUR_AMT_DIFF
FROM   ALL_RESULT
/* 按公司、往来项目、总计及用户指定的三段集团所属范围顺序展示。 */
ORDER  BY COMPANY_CODE
        , ITEM_SEQ
        , SCOPE_SEQ