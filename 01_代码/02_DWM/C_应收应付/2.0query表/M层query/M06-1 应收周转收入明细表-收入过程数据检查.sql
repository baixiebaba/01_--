/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261110 18:14
 * 本次修改：ALTER BY 20261110 18:14 SHIQINGFENG.EX 收入利润中心映射改按AW_RUL_ARPPRC_000001：ARPPRC公司级 > ARPPRC利润中心级 > DIM_RULE物料组(batch6) > 原值，复刻TOV映射链并补齐缺失的batch6层。
 * 上次修改：ALTER BY 20261109 17:52 SHIQINGFENG.EX 金额全为0的记录不再输出。
 *
 * 查询名称  ：应收周转收入明细表-收入过程数据检查
 * 源表      ：AW_MR9_REVM01_000001、TGK_FIMA_HISENSE.AW_RUL_ARPPRC_000001、TGK_FIMA_HISENSE.DIM_RULE_FI_MR_AR_PROFIT_MAPPING、TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 等，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261110 18:14 SHIQINGFENG.EX 收入利润中心映射改按AW_RUL_ARPPRC_000001：ARPPRC公司级 > ARPPRC利润中心级 > DIM_RULE物料组(batch6) > 原值，复刻TOV映射链并补齐缺失的batch6层。
 *   ALTER BY 20261109 17:52 SHIQINGFENG.EX 金额全为0的记录不再输出。
 *   ALTER BY 20261102 18:56 SHIQINGFENG.EX 按 SQL 编码规范统一右对齐：FROM/JOIN 组关键字右端对齐（CROSS JOIN 顶格）、OR/ON 右对齐、WHERE 嵌套条件分层、CASE 表达式 WHEN/THEN/ELSE/END 分行，未修改业务逻辑。
 *   ALTER BY 20261102 17:36 SHIQINGFENG.EX 按规范补查询说明文件头（查询名称+源表），未修改业务主体。
 *******************************************************************************/
WITH
/* 应收周转利润中心映射：batch1按公司+源利润中心（一公司一行），batch2仅按源利润中心，源利润中心去前导零匹配。 */
ARPPRC_RULE_1 AS (
    SELECT TRIM(COD_AZIENDA) AS COD_AZIENDA
         , NULLIF(LTRIM(TRIM(SRC_PROFITCENTER_CODE), '0'), '') AS SRC_PROFITCENTER_CODE
         , MAX(TRIM(COD_DEST2)) AS COD_DEST2
      FROM TGK_FIMA_HISENSE.AW_RUL_ARPPRC_000001
     WHERE BATCH_ID = '1'
       AND VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
     GROUP BY TRIM(COD_AZIENDA)
            , NULLIF(LTRIM(TRIM(SRC_PROFITCENTER_CODE), '0'), '')
),
ARPPRC_RULE_2 AS (
    SELECT NULLIF(LTRIM(TRIM(SRC_PROFITCENTER_CODE), '0'), '') AS SRC_PROFITCENTER_CODE
         , MAX(TRIM(COD_DEST2)) AS COD_DEST2
      FROM TGK_FIMA_HISENSE.AW_RUL_ARPPRC_000001
     WHERE BATCH_ID = '2'
       AND VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
     GROUP BY NULLIF(LTRIM(TRIM(SRC_PROFITCENTER_CODE), '0'), '')
),
/* 收入物料组映射规则：batch6先按公司主数据展开公司通配，物料组为空的配置不参与。 */
PROFIT_CENTER_RULE_6 AS (
    SELECT A.COD_AZIENDA AS COMPANY_CODE
         , TRIM(PM.MATERIAL_GROUP_CODE) AS MATERIAL_GROUP_CODE
         , MAX(PM.PROFITCENTER_CODE) AS PROFITCENTER_CODE
      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_AR_PROFIT_MAPPING PM
      JOIN (SELECT DISTINCT COD_AZIENDA
              FROM TGK_FIMA_HISENSE.AZIENDA) A
        ON A.COD_AZIENDA LIKE TRIM(PM.COMPANY_CODE)
     WHERE PM.BATCH_ID = 6
       AND NVL(TRIM(PM.MATERIAL_GROUP_CODE), 'ZZZZ') <> 'ZZZZ'
       AND PM.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(PM.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
     GROUP BY A.COD_AZIENDA
            , TRIM(PM.MATERIAL_GROUP_CODE)
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
         , R.MATERIAL_GROUP_CODE
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
       AND R.SRC_DETAIL <> 'BSEG_FLJC'
       AND R.COD_CATEGORIA NOT IN ('GA00_PA_IN', 'GA00_PA_OUT')
       AND R.D_ADJ_TYPE NOT IN ('REV_01_210', 'REV_01_212')
       AND R.COD_AZIENDA IN (SELECT COD_AZIENDA FROM ATS_BG_MAP)
),
/* REVENUE_CALC：收入利润中心按ARPPRC公司级 > ARPPRC利润中心级 > DIM_RULE物料组(batch6) > 原值映射；未命中时回退原始收入利润中心。 */
REVENUE_CALC AS (
    SELECT R.COD_SCENARIO
         , R.COD_PERIODO
         , R.COD_AZIENDA
         , TRIM(R.CUST_CODE) AS CUST_CODE
         , R.CUST_NAME
         , R.COD_AZI_CTP
         , R.COD_DEST2 AS INCOME_PROFITCENTER_CODE
         , F_TGK_GET_DIMNAME('DEST2', NVL(R.COD_DEST2, 'ZZZZ')) AS INCOME_PROFITCENTER_NAME
         , NVL(P1.COD_DEST2, NVL(P2.COD_DEST2, NVL(PM6.PROFITCENTER_CODE, NVL(R.COD_DEST2, 'ZZZZ')))) AS MAPPED_PROFITCENTER_CODE
         , F_TGK_GET_DIMNAME('DEST2', NVL(P1.COD_DEST2, NVL(P2.COD_DEST2, NVL(PM6.PROFITCENTER_CODE, NVL(R.COD_DEST2, 'ZZZZ'))))) AS MAPPED_PROFITCENTER_NAME
         , CASE
             WHEN NVL(P1.COD_DEST2, NVL(P2.COD_DEST2, PM6.PROFITCENTER_CODE)) IS NULL
               THEN '未命中收入利润中心映射'
             ELSE '已命中收入利润中心映射'
           END AS INCOME_PC_MAP_STATUS
         , CASE
             WHEN CUR_NODE.SELF_NODE = CASE
                                         WHEN CUR_NODE.IS_HITACHI = 1
                                           THEN NVL(CTP_NODE.NODES, CTP_NODE.NODE)
                                         ELSE CTP_NODE.NODE
                                       END
              AND CUR_NODE.HQ = CTP_NODE.HQ
               THEN 'SUB-子公司'
             WHEN CUR_NODE.HQ = CTP_NODE.HQ
               THEN 'GIN-集团内'
             ELSE 'GEX-集团外'
           END AS GRP_SCOPE
         , (CASE WHEN R.SRC_DETAIL = 'BSEG_FLJC' THEN 0 ELSE R.ORG_REV END)
           - (CASE
                WHEN R.SRC_DETAIL = 'BSEG_FLJC'
                  THEN 0
                WHEN R.SRC_DETAIL = 'VBRP' OR R.SRC_SYSTEM IN ('SMS', 'GSMS')
                  THEN R.POLICY_AMT / CA.CAMBIO_PERIODO
                ELSE R.POLICY_AMT
              END)
           - (CASE
                WHEN R.SRC_DETAIL = 'BSEG_FLJC'
                  THEN 0
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
      LEFT JOIN ARPPRC_RULE_1 P1
        ON P1.COD_AZIENDA = TRIM(R.COD_AZIENDA)
      LEFT JOIN ARPPRC_RULE_2 P2
        ON P2.SRC_PROFITCENTER_CODE = LTRIM(TRIM(R.COD_DEST2), '0')
      LEFT JOIN PROFIT_CENTER_RULE_6 PM6
        ON PM6.COMPANY_CODE = R.COD_AZIENDA
       AND PM6.MATERIAL_GROUP_CODE = TRIM(R.MATERIAL_GROUP_CODE)
     WHERE CASE
             WHEN CUR_NODE.SELF_NODE = CASE
                                         WHEN CUR_NODE.IS_HITACHI = 1
                                           THEN NVL(CTP_NODE.NODES, CTP_NODE.NODE)
                                         ELSE CTP_NODE.NODE
                                       END
              AND CUR_NODE.HQ = CTP_NODE.HQ
               THEN F_TGK_UNICODE_AS('decode','SUB-子公司')
             WHEN CUR_NODE.HQ = CTP_NODE.HQ
               THEN F_TGK_UNICODE_AS('decode','GIN-集团内')
             ELSE F_TGK_UNICODE_AS('decode','GEX-集团外')
           END = F_TGK_UNICODE_AS('decode','GEX-集团外')
       AND NVL(P1.COD_DEST2, NVL(P2.COD_DEST2, NVL(PM6.PROFITCENTER_CODE, R.COD_DEST2))) IS NOT NULL
       AND NVL(P1.COD_DEST2, NVL(P2.COD_DEST2, NVL(PM6.PROFITCENTER_CODE, R.COD_DEST2))) <> 'ZZZZ'
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
              AND ATS.COD_BG = PCR.COD_BG
               THEN PCR.COD_BG
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
              AND ATS.COD_BG <> PCR.COD_BG
               THEN '公司与利润中心事业部不一致'
             WHEN PCR.COD_BG IS NULL
               THEN '利润中心未映射事业部'
             WHEN ATS.COD_BG IS NULL
               THEN '账套未映射事业部'
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
SELECT R.COD_SCENARIO AS SCENARIO                                /* 场景 */
     , R.COD_PERIODO AS PERIODO                                  /* 期间 */
     , R.COD_AZIENDA AS COMPANY_CODE                             /* 公司 */
     , R.CUST_CODE                                               /* 客商编码 */
     , R.CUST_NAME                                               /* 客商名称 */
     , R.GRP_SCOPE                                               /* 集团归属范围 */
     , R.COD_AZI_CTP AS CP_COMPANY_CODE                          /* 对方公司 */
     , R.INCOME_PROFITCENTER_CODE                                /* 收入利润中心编码 */
     , R.INCOME_PROFITCENTER_NAME                                /* 收入利润中心名称 */
     , R.MAPPED_PROFITCENTER_CODE AS TURNOVER_PROFITCENTER_CODE  /* 映射后周转利润中心编码 */
     , R.MAPPED_PROFITCENTER_NAME AS TURNOVER_PROFITCENTER_NAME  /* 映射后周转利润中心名称 */
     , R.BUSINESS_UNIT_CODE                                      /* 事业部编码 */
     , R.BUSINESS_UNIT_NAME                                      /* 事业部名称 */
     , R.MANAGE_REV_AMT                                          /* 管理口径收入金额 */
  FROM REVENUE_AGG R
 WHERE NVL(R.MANAGE_REV_AMT, 0) <> 0
 ORDER BY R.COD_AZIENDA
        , R.CUST_CODE
        , R.INCOME_PROFITCENTER_CODE
        , R.MAPPED_PROFITCENTER_CODE
