/*
============================================================================
REVM01收入校验查询
用途：仅核对REVM01管理口径收入，并按参数映射收入利润中心和事业部。
口径：收入计算复刻CPM_SP_M2M_ARP_TOV_M_PHASE2的REVENUE_CALC，不参与周转匹配。
参数：场景、期间、账套和事业部由查询参数控制；事业部参数命中指定范围，同时保留事业部为空的记录。
说明：输出收入原始利润中心、映射后收入利润中心、利润中心事业部、账套事业部和管理口径收入，按最终映射粒度汇总。
============================================================================
*/
WITH
/* 当前查询实际纳入的账套：只受公司参数限制。 */
AZI_SCOPE AS (
    SELECT DISTINCT R.ELEM AS COD_AZIENDA
      FROM TGK_FIMA_HISENSE.V_REF_AZIENDA R
     WHERE R.HIE = '10'
       AND R.ELEM IN (${$Entity.code})
),
/* 收入利润中心映射规则：按源收入利润中心和有效期匹配。 */
PROFIT_CENTER_RULE AS (
    SELECT LTRIM(TRIM(M.SRC_PROFITCENTER_CODE), '0') AS SRC_PROFITCENTER_CODE
         , MAX(M.PROFITCENTER_CODE) AS PROFITCENTER_CODE
      FROM DIM_RULE_FI_MR_AR_PROFIT_MAPPING M
     WHERE M.BATCH_ID = 2
       AND M.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(M.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
     GROUP BY LTRIM(TRIM(M.SRC_PROFITCENTER_CODE), '0')
),
/* 周转事业部范围：复刻TOV，仅保留当前期间AR_TOV_FLAG=Y且命中事业部参数的范围。 */
TOV_BG_SCOPE AS (
    SELECT DISTINCT C.COD_BG
      FROM TGK_FIMA_HISENSE.AW_RUL_COSMAP_000001 C
     WHERE C.AR_TOV_FLAG = 'Y'
       AND C.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(C.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND C.COD_BG IN (${$ANL_D_BG.code})
),
/* 账套事业部配置：复刻TOV的有效账套事业部范围。 */
ATS_BG_MAP AS (
    SELECT DISTINCT A.COD_AZIENDA
         , A.COD_BG
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
     WHERE A.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(A.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND A.COD_BG IN (SELECT COD_BG FROM TOV_BG_SCOPE)
       AND A.COD_BG NOT LIKE 'CXC%'
),
/* 利润中心事业部配置：限制为参数事业部，并保留事业部为空的利润中心映射。 */
PCR_BG_MAP AS (
    SELECT DISTINCT LTRIM(TRIM(P.COD_DEST2), '0') AS COD_DEST2
         , P.COD_BG
      FROM TGK_FIMA_HISENSE.AW_RUL_PCRMAP_000001 P
     WHERE P.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(P.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND P.COD_BG IN (SELECT COD_BG FROM TOV_BG_SCOPE)
       AND P.COD_BG NOT LIKE 'CXC%'
),
/* 日立特殊节点清单：用于复刻收入集团归属判断。 */
HITACHI_ELEM AS (
    SELECT DISTINCT V.ELEM
      FROM TGK_GB_HISENSE.V_REF_AZIENDA_TV V
     WHERE V.COD_SCENARIO = ${$Scenario.code}
       AND V.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
       AND V.HIE = '30'
       AND V.NODE = '1730'
),
/* 当前场景期间的公司节点关系：用于计算集团归属范围。 */
NODE_MAP AS (
    SELECT N.COD_SCENARIO
         , N.COD_PERIODO
         , N.ELEM
         , N.NODE
         , N.NODES
         , CASE WHEN H.ELEM IS NOT NULL THEN 1 ELSE 0 END AS IS_HITACHI
         , CASE WHEN H.ELEM IS NOT NULL THEN NVL(N.NODES, N.NODE) ELSE N.NODE END AS SELF_NODE
         , N.HQ
      FROM TGK_GB_HISENSE.V_APAR_ELEM_NODE_TAB N
      LEFT JOIN HITACHI_ELEM H
        ON H.ELEM = N.ELEM
     WHERE N.COD_SCENARIO = ${$Scenario.code}
       AND N.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
),
/* REVM01原始收入：保留存储过程REVENUE_CALC使用的源字段和过滤条件。 */
REVM01_BASE AS (
    SELECT R.COD_SCENARIO
         , R.COD_PERIODO
         , R.COD_AZIENDA
         , R.CUST_CODE
         , R.CUST_NAME
         , R.COD_AZI_CTP
         , R.SRC_SYSTEM
         , R.SRC_DETAIL
         , R.COD_DEST2
         , R.D_ADJ_TYPE
         , 0 - R.ORG_REV AS ORG_REV
         , R.POLICY_AMT
         , 0 - R.MAP_DIS1 AS MAP_DIS1
         , 0 - R.MAP_DIS3 AS MAP_DIS3
         , 0 - R.MAP_DIS4 AS MAP_DIS4
         , 0 - R.MAP_DIS30 AS MAP_DIS30
         , 0 - R.MAP_DIS34 AS MAP_DIS34
         , R.D_SALE_DEPT
      FROM AW_MR9_REVM01_000001 R
     WHERE R.COD_SCENARIO = ${$Scenario.code}
       AND R.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
       AND R.COD_AZIENDA IN (SELECT COD_AZIENDA FROM AZI_SCOPE)
       AND R.SRC_DETAIL <> 'BSEG_FLJC'
       AND R.COD_CATEGORIA NOT IN ('GA00_PA_IN', 'GA00_PA_OUT')
       AND R.D_ADJ_TYPE NOT IN ('REV_01_210', 'REV_01_212')
),
/* REVENUE_CALC：直接取收入原始利润中心，完成收入利润中心映射；未命中时回退原始收入利润中心。 */
REVENUE_CALC AS (
    SELECT R.COD_SCENARIO
         , R.COD_PERIODO
         , R.COD_AZIENDA
         , TRIM(R.CUST_CODE) AS CUST_CODE
         , R.CUST_NAME
         , R.COD_AZI_CTP
         , R.COD_DEST2 AS INCOME_PROFITCENTER_CODE
         , F_TGK_GET_DIMNAME('DEST2', NVL(R.COD_DEST2, 'ZZZZ')) AS INCOME_PROFITCENTER_NAME
         , NVL(PM.PROFITCENTER_CODE, NVL(R.COD_DEST2, 'ZZZZ')) AS MAPPED_PROFITCENTER_CODE
         , F_TGK_GET_DIMNAME('DEST2', NVL(PM.PROFITCENTER_CODE, NVL(R.COD_DEST2, 'ZZZZ'))) AS MAPPED_PROFITCENTER_NAME
         , CASE
               WHEN PM.PROFITCENTER_CODE IS NULL THEN '未命中收入利润中心映射'
               ELSE '已命中收入利润中心映射'
           END AS INCOME_PC_MAP_STATUS
         , CASE
               WHEN CUR_NODE.SELF_NODE = CASE
                   WHEN CUR_NODE.IS_HITACHI = 1 THEN NVL(CTP_NODE.NODES, CTP_NODE.NODE)
                   ELSE CTP_NODE.NODE
                 END
                AND CUR_NODE.HQ = CTP_NODE.HQ THEN 'SUB-子公司'
               WHEN CUR_NODE.HQ = CTP_NODE.HQ THEN 'GIN-集团内'
               ELSE 'GEX-集团外'
           END AS GRP_SCOPE
         , (CASE WHEN R.SRC_DETAIL = 'BSEG_FLJC' THEN 0 ELSE R.ORG_REV END)
           - (CASE
                WHEN R.SRC_DETAIL = 'BSEG_FLJC' THEN 0
                WHEN R.SRC_DETAIL = 'VBRP' OR R.SRC_SYSTEM IN ('SMS', 'GSMS')
                    THEN R.POLICY_AMT / CA.CAMBIO_PERIODO
                ELSE R.POLICY_AMT
              END)
           - (CASE
                WHEN R.SRC_DETAIL = 'BSEG_FLJC' THEN 0
                WHEN R.SRC_DETAIL = 'VBRP' OR R.SRC_SYSTEM IN ('SMS', 'GSMS')
                    THEN (NVL(R.MAP_DIS1, 0) + NVL(R.MAP_DIS3, 0)
                        + NVL(R.MAP_DIS4, 0) + NVL(R.MAP_DIS30, 0)
                        + NVL(R.MAP_DIS34, 0)) / CA.CAMBIO_PERIODO
                ELSE NVL(R.MAP_DIS1, 0) + NVL(R.MAP_DIS3, 0)
                   + NVL(R.MAP_DIS4, 0) + NVL(R.MAP_DIS30, 0)
                   + NVL(R.MAP_DIS34, 0)
              END) AS REV_AMT
      FROM REVM01_BASE R
      LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
        ON AZ.COD_AZIENDA = R.COD_AZIENDA
      LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
        ON CA.COD_SCENARIO = R.COD_SCENARIO
       AND CA.COD_PERIODO = R.COD_PERIODO
       AND CA.COD_VALUTA = AZ.COD_VALUTA
      LEFT JOIN NODE_MAP CUR_NODE
        ON CUR_NODE.COD_SCENARIO = R.COD_SCENARIO
       AND CUR_NODE.COD_PERIODO = R.COD_PERIODO
       AND CUR_NODE.ELEM = R.COD_AZIENDA
      LEFT JOIN NODE_MAP CTP_NODE
        ON CTP_NODE.COD_SCENARIO = R.COD_SCENARIO
       AND CTP_NODE.COD_PERIODO = R.COD_PERIODO
       AND CTP_NODE.ELEM = R.COD_AZI_CTP
      LEFT JOIN PROFIT_CENTER_RULE PM
        ON PM.SRC_PROFITCENTER_CODE = LTRIM(TRIM(R.COD_DEST2), '0')
     WHERE CASE
             WHEN CUR_NODE.SELF_NODE = CASE
                 WHEN CUR_NODE.IS_HITACHI = 1 THEN NVL(CTP_NODE.NODES, CTP_NODE.NODE)
                 ELSE CTP_NODE.NODE
               END
              AND CUR_NODE.HQ = CTP_NODE.HQ THEN 'SUB-子公司'
             WHEN CUR_NODE.HQ = CTP_NODE.HQ THEN 'GIN-集团内'
             ELSE 'GEX-集团外'
           END = 'GEX-集团外'
       AND NVL(PM.PROFITCENTER_CODE, R.COD_DEST2) IS NOT NULL
       AND NVL(PM.PROFITCENTER_CODE, R.COD_DEST2) <> 'ZZZZ'
),
/* REVENUE_BG_MAP：完成收入利润中心映射后，再匹配利润中心事业部和账套事业部。 */
REVENUE_BG_MAP AS (
    SELECT R.COD_SCENARIO
         , R.COD_PERIODO
         , R.COD_AZIENDA
         , R.CUST_CODE
         , R.CUST_NAME
         , R.COD_AZI_CTP
         , R.INCOME_PROFITCENTER_CODE
         , R.INCOME_PROFITCENTER_NAME
         , R.MAPPED_PROFITCENTER_CODE
         , R.MAPPED_PROFITCENTER_NAME
         , R.INCOME_PC_MAP_STATUS
         , R.GRP_SCOPE
         , PCR.COD_BG AS PROFITCENTER_BG_CODE
         , CASE
               WHEN PCR.COD_BG IS NOT NULL
                AND ATS.COD_BG = PCR.COD_BG THEN PCR.COD_BG
               ELSE NULL
           END AS BUSINESS_UNIT_CODE
         , CASE
               WHEN PCR.COD_BG IS NOT NULL
                AND ATS.COD_BG = PCR.COD_BG
                 THEN F_TGK_GET_DIMNAME('D_BG', PCR.COD_BG)
               ELSE NULL
           END AS BUSINESS_UNIT_NAME
         , CASE
               WHEN PCR.COD_BG IS NOT NULL
                AND ATS.COD_BG IS NOT NULL
                AND ATS.COD_BG <> PCR.COD_BG THEN '公司与利润中心事业部不一致'
               WHEN PCR.COD_BG IS NULL THEN '利润中心未映射事业部'
               WHEN ATS.COD_BG IS NULL THEN '账套未映射事业部'
               ELSE '公司与利润中心已映射同一事业部'
           END AS BUSINESS_UNIT_MAP_STATUS
         , R.REV_AMT AS MANAGE_REV_AMT
      FROM REVENUE_CALC R
      LEFT JOIN PCR_BG_MAP PCR
        ON PCR.COD_DEST2 = LTRIM(TRIM(R.MAPPED_PROFITCENTER_CODE), '0')
      LEFT JOIN ATS_BG_MAP ATS
        ON ATS.COD_AZIENDA = R.COD_AZIENDA
     WHERE NOT EXISTS (
           SELECT 1
             FROM ATS_BG_MAP ATS_DIFF
            WHERE ATS_DIFF.COD_AZIENDA = R.COD_AZIENDA
              AND PCR.COD_BG IS NOT NULL
              AND ATS_DIFF.COD_BG IS NOT NULL
              AND ATS_DIFF.COD_BG <> PCR.COD_BG
     )
),
/* REVENUE_AGG：按映射结果汇总收入，参数事业部过滤在聚合前执行，并排除汇总后金额为0的记录。 */
REVENUE_AGG AS (
    SELECT R.COD_SCENARIO
         , R.COD_PERIODO
         , R.COD_AZIENDA
         , R.CUST_CODE
         , MAX(R.CUST_NAME) AS CUST_NAME
         , R.GRP_SCOPE
         , R.COD_AZI_CTP
         , R.INCOME_PROFITCENTER_CODE
         , R.INCOME_PROFITCENTER_NAME
         , R.MAPPED_PROFITCENTER_CODE
         , R.MAPPED_PROFITCENTER_NAME
         , R.BUSINESS_UNIT_CODE
         , R.BUSINESS_UNIT_NAME
         , SUM(R.MANAGE_REV_AMT) AS MANAGE_REV_AMT
      FROM REVENUE_BG_MAP R
     WHERE R.CUST_CODE IS NOT NULL
     GROUP BY R.COD_SCENARIO
            , R.COD_PERIODO
            , R.COD_AZIENDA
            , R.CUST_CODE
            , R.GRP_SCOPE
            , R.COD_AZI_CTP
            , R.INCOME_PROFITCENTER_CODE
            , R.INCOME_PROFITCENTER_NAME
            , R.MAPPED_PROFITCENTER_CODE
            , R.MAPPED_PROFITCENTER_NAME
            , R.BUSINESS_UNIT_CODE
            , R.BUSINESS_UNIT_NAME
    HAVING NVL(SUM(R.MANAGE_REV_AMT), 0) <> 0
)
SELECT R.COD_SCENARIO AS SCENARIO
     , R.COD_PERIODO AS PERIODO
     , R.COD_AZIENDA AS COMPANY_CODE
     , R.CUST_CODE
     , R.CUST_NAME
     , R.GRP_SCOPE
     , R.COD_AZI_CTP AS CP_COMPANY_CODE
     , R.INCOME_PROFITCENTER_CODE
     , R.INCOME_PROFITCENTER_NAME
     , R.MAPPED_PROFITCENTER_CODE AS TURNOVER_PROFITCENTER_CODE
     , R.MAPPED_PROFITCENTER_NAME AS TURNOVER_PROFITCENTER_NAME
     , R.BUSINESS_UNIT_CODE
     , R.BUSINESS_UNIT_NAME
     , R.MANAGE_REV_AMT
  FROM REVENUE_AGG R
 ORDER BY R.COD_AZIENDA
        , R.CUST_CODE
        , R.INCOME_PROFITCENTER_CODE
        , R.MAPPED_PROFITCENTER_CODE
;
