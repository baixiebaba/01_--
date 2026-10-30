/*
============================================================================
ARPM02与IMOCC周转校验查询
用途：按 CPM_SP_M2M_ARP_TOV_M_PHASE2 口径查询周转和国际营销应收占用数据。
参数：场景使用 ${$Scenario.code}，期间使用 ${$Period.code}，公司使用 ${$Entity.code}，事业部使用 ${$ANL_D_BG.code}。
      参数直接写入各源表和规则表 SELECT 的 WHERE 限制，不依赖存储过程或参数包。
口径：按TOV实际ARPTOV_RULE规则保留ARPM02来源并生成正向取数标记，保留事业部映射剔除和负净额事业部剔除记录。
输出：场景、期间、账套、数据来源、类别、客商、集团所属范围、对方公司、
      周转利润中心编码及描述、事业部编码及描述、ARPTOV_FLAG、AR_AMT_FLAG、事业部映射状态、周转金额。
版本信息：
  20261021 按TOV实际规则修正周转利润中心仅标准化一次，参数版仅在最终层限制事业部，修复事业部映射为空问题。
  20261021 删除公司进数和锁定限制，改为全量事业部计算负净额并在最终层执行事业部展示筛选；完成SQL完整性静态检查。
  20261021 按TOV实际规则改为ARPM02与IMOCC全量留痕，新增ARPTOV_FLAG、AR_AMT_FLAG和事业部映射状态，取消最终非零金额过滤。
  20261020 新增 ARPM02 与 IMOCC 周转校验查询。
============================================================================
*/
WITH
/* 公司层级和实际公司参数范围：仅保留HIE=10公司，不依赖公司进数或锁定表。 */
AZI_SCOPE AS (
    SELECT DISTINCT R.ELEM AS COD_AZIENDA
      FROM TGK_FIMA_HISENSE.V_REF_AZIENDA R
     WHERE R.HIE = '10'
       AND R.ELEM IN (${$Entity.code})
),
/* 当前期间有效的全部周转事业部范围：排除CXC事业部，供映射存在性判断使用。 */
TOV_BG_SCOPE_ALL AS (
    SELECT DISTINCT C.COD_BG
      FROM TGK_FIMA_HISENSE.AW_RUL_COSMAP_000001 C
     WHERE C.AR_TOV_FLAG = 'Y'
       AND C.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(C.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
),
/* 当前期间全部有效账套事业部映射：不按事业部参数过滤，供最终映射和留痕使用。 */
ATS_BG_MAP AS (
    SELECT DISTINCT A.COD_AZIENDA
         , A.COD_BG
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
     WHERE A.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(A.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND A.COD_BG IN (SELECT COD_BG FROM TOV_BG_SCOPE_ALL)
       AND A.COD_BG NOT LIKE 'CXC%'
),
/* 当前期间全部有效利润中心事业部映射：不按事业部参数过滤，供最终映射和留痕使用。 */
PCR_BG_MAP AS (
    SELECT DISTINCT LTRIM(TRIM(P.COD_DEST2), '0') AS COD_DEST2
         , P.COD_BG
      FROM TGK_FIMA_HISENSE.AW_RUL_PCRMAP_000001 P
     WHERE P.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(P.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND P.COD_BG IN (SELECT COD_BG FROM TOV_BG_SCOPE_ALL)
       AND P.COD_BG NOT LIKE 'CXC%'
),
/* ARPM02特殊取数配置：读取当前期间有效的规则；批次1至4为剔除规则，批次6为取数规则。 */
/* 规则明细先去重，来源层通过EXISTS按业务记录判断，避免规则多行关联放大金额。 */
ARPTOV_RULE AS (
    SELECT DISTINCT R.BATCH_ID
         , TRIM(R.COD_AZIENDA) AS COD_AZIENDA
         , TRIM(R.CUST_CODE) AS CUST_CODE
         , TRIM(R.NATURE_L2_NAME) AS NATURE_L2_NAME
         , TRIM(R.D_SALE_DEPT) AS D_SALE_DEPT
      FROM AW_RUL_ARPTOV_000001 R
     WHERE R.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(R.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND R.BATCH_ID IN ('1', '2', '3', '4', '6')
),
/* ARPM01调整汇总：完全复用TOV按场景、期间、公司、客商和利润中心汇总因素7、因素8的逻辑。 */
ARPM01_ADJ_SUM AS (
    SELECT A.COD_SCENARIO
         , A.COD_PERIODO
         , A.COD_AZIENDA
         , TRIM(A.CUST_CODE) AS CUST_CODE
         , TRIM(A.COD_DEST2) AS COD_DEST2
         , SUM(CASE WHEN A.D_ADJ_TYPE = 'ARP_03_001' THEN NVL(A.BCY_0_AMT, 0) ELSE 0 END) AS F7_GSUB_AMT
         , SUM(CASE WHEN A.D_ADJ_TYPE = 'ARP_03_002' THEN NVL(A.BCY_0_AMT, 0) ELSE 0 END) AS F8_ADJ_AMT
      FROM AW_MR9_ARPM01_000001 A
     WHERE A.COD_SCENARIO = ${$Scenario.code}
       AND A.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
       /* 仅取ZFAMOUNT类别及TOV因素7、因素8对应的调整类型。 */
       AND A.COD_CATEGORIA = 'ZFAMOUNT'
       AND A.D_ADJ_TYPE IN ('ARP_03_001', 'ARP_03_002')
     GROUP BY A.COD_SCENARIO
            , A.COD_PERIODO
            , A.COD_AZIENDA
            , TRIM(A.CUST_CODE)
            , TRIM(A.COD_DEST2)
),
/* 周转原始来源：ARPM02单次取数并生成ARPTOV正向取数标记，IMOCC保留TOV正常来源条件。 */
TURNOVER_SOURCE AS (
    SELECT A.COD_SCENARIO
         , A.COD_PERIODO
         , A.COD_AZIENDA
         , 'ARPM02' AS DATA_SOURCE
         , CASE
               WHEN A.ME_AGE_FLAG IN ('AR', 'CA', 'A10') THEN 'ZAMOUNT'
               WHEN A.MB_AGE_FLAG IN ('AR', 'CA', 'A10') THEN 'ZAMOUNT_L2'
           END AS COD_CATEGORIA
         , TRIM(A.CUST_CODE) AS CUST_CODE
         , A.CUST_NAME
         , A.CUST_HEAD_CODE
         , A.CUST_HEAD_NAME
         , TRIM(A.CUST_CODE) AS SUB_CUST_CODE
         , A.CUST_NAME AS SUB_CUST_NAME
         , A.GRP_SCOPE
         , A.COD_AZI_CTP AS CP_COMPANY_CODE
         , A.COD_DEST2 AS SRC_PROFITCENTER_CODE
         , CASE
/* TOV实际优先级：1至4命中即不取数，优先于后续取数规则。 */
               WHEN EXISTS (
                      SELECT 1
                        FROM ARPTOV_RULE R1
                       WHERE R1.BATCH_ID = '1'
                         AND R1.CUST_CODE IS NOT NULL
                         AND TRIM(A.CUST_CODE) LIKE '%' || R1.CUST_CODE || '%'
                    )
                 OR EXISTS (
                      SELECT 1
                        FROM ARPTOV_RULE R2
                       WHERE R2.BATCH_ID = '2'
                         AND R2.COD_AZIENDA = TRIM(A.COD_AZIENDA)
                         AND R2.CUST_CODE IS NOT NULL
                         AND R2.CUST_CODE = TRIM(A.CUST_CODE)
                    )
                 OR EXISTS (
                      SELECT 1
                        FROM ARPTOV_RULE R3
                       WHERE R3.BATCH_ID = '3'
                         AND R3.NATURE_L2_NAME IS NOT NULL
                         AND R3.NATURE_L2_NAME = TRIM(A.NATURE_L2_NAME)
                    )
                 OR EXISTS (
                      SELECT 1
                        FROM ARPTOV_RULE R4
                       WHERE R4.BATCH_ID = '4'
                         AND R4.COD_AZIENDA = TRIM(A.COD_AZIENDA)
                         AND R4.D_SALE_DEPT IS NOT NULL
                         AND R4.D_SALE_DEPT = TRIM(A.D_SALE_DEPT)
                    )
               THEN 'N'
               /* 批次6沿用TOV：公司未维护二级性质时默认取数，维护时仅取配置性质。 */
               WHEN NOT EXISTS (
                      SELECT 1
                        FROM ARPTOV_RULE R6
                       WHERE R6.BATCH_ID = '6'
                         AND R6.COD_AZIENDA IS NOT NULL
                         AND R6.NATURE_L2_NAME IS NOT NULL
                         AND R6.COD_AZIENDA = TRIM(A.COD_AZIENDA)
                    )
                 OR EXISTS (
                      SELECT 1
                        FROM ARPTOV_RULE R6
                       WHERE R6.BATCH_ID = '6'
                         AND R6.COD_AZIENDA = TRIM(A.COD_AZIENDA)
                         AND R6.NATURE_L2_NAME = TRIM(A.NATURE_L2_NAME)
                    )
               THEN 'Y'
               ELSE 'N'
           END AS ARPTOV_FLAG
         , NVL(A.BCY_ADJ_INCL_0_AMT, 0) AS TURNOVER_AMT
         , NVL(A.OVERDUE_0_AMT, 0) AS F1_ODUE_AMT
         , NVL(A.EPAY_AMT, 0) AS F2_EPAY_AMT
         , NVL(A.ECLS_AMT, 0) AS F3_ECR_AMT
         , NVL(A.UREB_AMT, 0) AS F4_UREB_AMT
         , NVL(A.UFEE_AMT, 0) AS F5_UFEE_AMT
         , NVL(A.INV_SAMPLE_AMT, 0) AS F6_INVSM_AMT
         , NVL(ADJ.F7_GSUB_AMT, 0) AS F7_GSUB_AMT
         , NVL(ADJ.F8_ADJ_AMT, 0) AS F8_ADJ_AMT
      FROM AW_MR9_ARPM02_000001 A
      LEFT JOIN ARPM01_ADJ_SUM ADJ
        ON ADJ.COD_SCENARIO = A.COD_SCENARIO
       AND ADJ.COD_PERIODO = A.COD_PERIODO
       AND ADJ.COD_AZIENDA = A.COD_AZIENDA
       AND ADJ.CUST_CODE = TRIM(A.CUST_CODE)
       AND ADJ.COD_DEST2 = TRIM(A.COD_DEST2)
     WHERE A.COD_SCENARIO = ${$Scenario.code}
       AND A.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
       AND A.GRP_SCOPE = 'GEX-集团外'
       AND A.COD_AZIENDA IN (SELECT COD_AZIENDA FROM AZI_SCOPE)
       AND A.COD_DEST2 IS NOT NULL
       AND A.COD_DEST2 <> 'ZZZZ'
       /* 保留TOV要求的两类账龄标识范围，单条ARPM02记录只生成一个类别。 */
       AND (
             A.ME_AGE_FLAG IN ('AR', 'CA', 'A10')
          OR A.MB_AGE_FLAG IN ('AR', 'CA', 'A10')
       )

    UNION ALL

    /* IMOCC未提供独立主户字段，按TOV现行口径以当前客户字段兼作主户，并同步作为分户展示，保持原有主户匹配口径不变。 */
    SELECT ${$Scenario.code} AS COD_SCENARIO
         , LPAD(${$Period.code}, 2, '0') AS COD_PERIODO
         , I.COMPANY_CODE AS COD_AZIENDA
         , 'IMOCC' AS DATA_SOURCE
         , 'ZAMOUNT' AS COD_CATEGORIA
         , TRIM(I.CUST_CODE) AS CUST_CODE
         , I.CUST_NAME
         , TRIM(I.CUST_CODE) AS CUST_HEAD_CODE
         , I.CUST_NAME AS CUST_HEAD_NAME
         , TRIM(I.CUST_CODE) AS SUB_CUST_CODE
         , I.CUST_NAME AS SUB_CUST_NAME
         , 'GEX-集团外' AS GRP_SCOPE
         , I.CP_COMPANY_CODE AS CP_COMPANY_CODE
         , I.PROFITCENTER_CODE AS SRC_PROFITCENTER_CODE
         , 'Y' AS ARPTOV_FLAG
         , NVL(I.IMOCC_CNY_AMT, 0) AS TURNOVER_AMT
         , 0 AS F1_ODUE_AMT
         , 0 AS F2_EPAY_AMT
         , 0 AS F3_ECR_AMT
         , 0 AS F4_UREB_AMT
         , 0 AS F5_UFEE_AMT
         , 0 AS F6_INVSM_AMT
         , 0 AS F7_GSUB_AMT
         , 0 AS F8_ADJ_AMT
      FROM DWD_FI_MR_AR_IMOCC_MI I
     WHERE I.DT_MONTH = SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND I.COMPANY_CODE IN ('1740', '2080')
       AND TRIM(I.CP_COMPANY_CODE) IS NULL
       AND I.PROFITCENTER_CODE IS NOT NULL
       AND I.PROFITCENTER_CODE <> 'ZZZZ'
       AND NVL(I.IMOCC_CNY_AMT, 0) <> 0
       AND I.COMPANY_CODE IN (SELECT COD_AZIENDA FROM AZI_SCOPE)
),
/* 周转利润中心仅按TOV实际逻辑标准化：ARPM02取COD_DEST2，IMOCC取PROFITCENTER_CODE，均在此处去除前导零一次。 */
TURNOVER_NORMALIZED AS (
    SELECT T.COD_SCENARIO
         , T.COD_PERIODO
         , T.COD_AZIENDA
         , CASE
               WHEN COUNT(DISTINCT T.DATA_SOURCE) > 1 THEN 'ARPM02+IMOCC'
               ELSE MAX(T.DATA_SOURCE)
           END AS DATA_SOURCE
         , T.COD_CATEGORIA
         , T.CUST_CODE
         , T.CUST_NAME
         , T.CUST_HEAD_CODE
         , T.CUST_HEAD_NAME
         , T.SUB_CUST_CODE
         , T.SUB_CUST_NAME
         , T.GRP_SCOPE
         , T.CP_COMPANY_CODE
         , LTRIM(TRIM(T.SRC_PROFITCENTER_CODE), '0') AS TURNOVER_PROFITCENTER_CODE
         , T.ARPTOV_FLAG
         , SUM(T.TURNOVER_AMT) AS TURNOVER_AMT
         , SUM(T.F1_ODUE_AMT) AS F1_ODUE_AMT
         , SUM(T.F2_EPAY_AMT) AS F2_EPAY_AMT
         , SUM(T.F3_ECR_AMT) AS F3_ECR_AMT
         , SUM(T.F4_UREB_AMT) AS F4_UREB_AMT
         , SUM(T.F5_UFEE_AMT) AS F5_UFEE_AMT
         , SUM(T.F6_INVSM_AMT) AS F6_INVSM_AMT
         , SUM(T.F7_GSUB_AMT) AS F7_GSUB_AMT
         , SUM(T.F8_ADJ_AMT) AS F8_ADJ_AMT
      FROM TURNOVER_SOURCE T
     GROUP BY T.COD_SCENARIO
            , T.COD_PERIODO
            , T.COD_AZIENDA
            , T.COD_CATEGORIA
            , T.CUST_CODE
            , T.CUST_NAME
            , T.CUST_HEAD_CODE
            , T.CUST_HEAD_NAME
            , T.SUB_CUST_CODE
            , T.SUB_CUST_NAME
            , T.GRP_SCOPE
            , T.CP_COMPANY_CODE
            , LTRIM(TRIM(T.SRC_PROFITCENTER_CODE), '0')
            , T.ARPTOV_FLAG
),
/* 账套映射聚合：每个账套只保留一个状态行，供未映射和冲突留痕使用。 */
ATS_BG_STATUS AS (
    SELECT A.COD_AZIENDA
         , COUNT(DISTINCT A.COD_BG) AS ATS_BG_COUNT
      FROM ATS_BG_MAP A
     GROUP BY A.COD_AZIENDA
),
/* 利润中心映射聚合：每个利润中心只保留一个状态行，供未映射和冲突留痕使用。 */
PCR_BG_STATUS AS (
    SELECT P.COD_DEST2
         , COUNT(DISTINCT P.COD_BG) AS PCR_BG_COUNT
      FROM PCR_BG_MAP P
     GROUP BY P.COD_DEST2
),
/* 按TOV实际连接方式匹配公司与利润中心的共同事业部，避免分别聚合后丢失有效交集。 */
MATCHED_BG_STATUS AS (
    SELECT P.COD_DEST2
         , A.COD_AZIENDA
         , COUNT(DISTINCT P.COD_BG) AS MATCHED_BG_COUNT
         , MAX(P.COD_BG) AS MATCHED_BG_CODE
      FROM PCR_BG_MAP P
      JOIN ATS_BG_MAP A
        ON A.COD_BG = P.COD_BG
     GROUP BY P.COD_DEST2
            , A.COD_AZIENDA
),
/* 映射后的周转数据：全量事业部先计算，保留映射冲突、未映射和公司与利润中心不一致的留痕状态。 */
MAPPED_TURNOVER AS (
    SELECT T.COD_SCENARIO
         , T.COD_PERIODO
         , T.COD_AZIENDA
         , T.DATA_SOURCE
         , T.COD_CATEGORIA
         , T.CUST_CODE
         , T.CUST_NAME
         , T.CUST_HEAD_CODE
         , T.CUST_HEAD_NAME
         , T.SUB_CUST_CODE
         , T.SUB_CUST_NAME
         , T.GRP_SCOPE
         , T.CP_COMPANY_CODE
         , T.TURNOVER_PROFITCENTER_CODE
         , CASE
               WHEN MATCHED.MATCHED_BG_COUNT = 1
               THEN MATCHED.MATCHED_BG_CODE
           END AS BUSINESS_UNIT_CODE
         , T.ARPTOV_FLAG
         , CASE
               WHEN MATCHED.MATCHED_BG_COUNT > 1 THEN '事业部映射冲突'
               WHEN PCR.PCR_BG_COUNT IS NULL THEN '利润中心未映射事业部'
               WHEN ATS.ATS_BG_COUNT IS NULL THEN '账套未映射事业部'
               WHEN MATCHED.MATCHED_BG_COUNT IS NULL THEN '公司与利润中心事业部不一致'
               ELSE '已映射同一事业部'
           END AS BUSINESS_UNIT_MAP_STATUS
         , CASE
               WHEN TRIM(T.CUST_HEAD_CODE) IS NULL THEN NULL
               ELSE NVL(LTRIM(TRIM(T.CUST_HEAD_CODE), '0'), '0')
           END AS CUST_MATCH_CODE
         , T.TURNOVER_AMT
         , T.F1_ODUE_AMT
         , T.F2_EPAY_AMT
         , T.F3_ECR_AMT
         , T.F4_UREB_AMT
         , T.F5_UFEE_AMT
         , T.F6_INVSM_AMT
         , T.F7_GSUB_AMT
         , T.F8_ADJ_AMT
      FROM TURNOVER_NORMALIZED T
      LEFT JOIN PCR_BG_STATUS PCR
        ON PCR.COD_DEST2 = T.TURNOVER_PROFITCENTER_CODE
      LEFT JOIN ATS_BG_STATUS ATS
        ON ATS.COD_AZIENDA = T.COD_AZIENDA
      LEFT JOIN MATCHED_BG_STATUS MATCHED
        ON MATCHED.COD_DEST2 = T.TURNOVER_PROFITCENTER_CODE
       AND MATCHED.COD_AZIENDA = T.COD_AZIENDA
),
/* 按场景、期间、公司、主户、类别和全量事业部计算有效周转净额；仅正向取数且映射有效的行参与。 */
BG_TURNOVER_NET AS (
    SELECT M.COD_SCENARIO
         , M.COD_PERIODO
         , M.COD_AZIENDA
         , M.CUST_MATCH_CODE
         , M.COD_CATEGORIA
         , M.BUSINESS_UNIT_CODE
         , SUM(M.TURNOVER_AMT) AS TURNOVER_AMT
      FROM MAPPED_TURNOVER M
     WHERE M.ARPTOV_FLAG = 'Y'
       AND M.GRP_SCOPE = 'GEX-集团外'
       AND M.BUSINESS_UNIT_MAP_STATUS = '已映射同一事业部'
       AND M.CUST_MATCH_CODE IS NOT NULL
     GROUP BY M.COD_SCENARIO
            , M.COD_PERIODO
            , M.COD_AZIENDA
            , M.CUST_MATCH_CODE
            , M.COD_CATEGORIA
            , M.BUSINESS_UNIT_CODE
),
/* 负净额事业部：存在其他事业部时，净额小于0的事业部整体标记为不取数。 */
NEGATIVE_BG_TURNOVER AS (
    SELECT B.COD_SCENARIO
         , B.COD_PERIODO
         , B.COD_AZIENDA
         , B.CUST_MATCH_CODE
         , B.COD_CATEGORIA
         , B.BUSINESS_UNIT_CODE
      FROM BG_TURNOVER_NET B
     WHERE B.TURNOVER_AMT < 0
       AND EXISTS (
           SELECT 1
             FROM BG_TURNOVER_NET X
            WHERE X.COD_SCENARIO = B.COD_SCENARIO
              AND X.COD_PERIODO = B.COD_PERIODO
              AND X.COD_AZIENDA = B.COD_AZIENDA
              AND X.CUST_MATCH_CODE = B.CUST_MATCH_CODE
              AND X.COD_CATEGORIA = B.COD_CATEGORIA
              AND X.BUSINESS_UNIT_CODE <> B.BUSINESS_UNIT_CODE
       )
),
/* 最终周转校验数据：在全量事业部完成负净额标记后，保留来源行并回标AR_AMT_FLAG。 */
FILTERED_TURNOVER AS (
    SELECT M.COD_SCENARIO
         , M.COD_PERIODO
         , M.COD_AZIENDA
         , M.DATA_SOURCE
         , M.COD_CATEGORIA
         , M.CUST_CODE
         , M.CUST_NAME
         , M.CUST_HEAD_CODE
         , M.CUST_HEAD_NAME
         , M.SUB_CUST_CODE
         , M.SUB_CUST_NAME
         , M.GRP_SCOPE
         , M.CP_COMPANY_CODE
         , M.TURNOVER_PROFITCENTER_CODE
         , M.BUSINESS_UNIT_CODE
         , M.ARPTOV_FLAG
         , CASE
               /* 正向金额取数标记：通过ARPTOV且未被负净额事业部规则过滤，才进入ARPM03。 */
               WHEN M.ARPTOV_FLAG = 'Y'
                AND M.BUSINESS_UNIT_MAP_STATUS = '已映射同一事业部'
                AND NOT EXISTS (
                    SELECT 1
                      FROM NEGATIVE_BG_TURNOVER N
                     WHERE N.COD_SCENARIO = M.COD_SCENARIO
                       AND N.COD_PERIODO = M.COD_PERIODO
                       AND N.COD_AZIENDA = M.COD_AZIENDA
                       AND N.COD_CATEGORIA = M.COD_CATEGORIA
                       AND N.BUSINESS_UNIT_CODE = M.BUSINESS_UNIT_CODE
                       AND N.CUST_MATCH_CODE = M.CUST_MATCH_CODE
                )
               THEN 'Y'
               ELSE 'N'
           END AS AR_AMT_FLAG
         , M.BUSINESS_UNIT_MAP_STATUS
         , M.TURNOVER_AMT
         , M.F1_ODUE_AMT
         , M.F2_EPAY_AMT
         , M.F3_ECR_AMT
         , M.F4_UREB_AMT
         , M.F5_UFEE_AMT
         , M.F6_INVSM_AMT
         , M.F7_GSUB_AMT
         , M.F8_ADJ_AMT
      FROM MAPPED_TURNOVER M
),
/* 事业部最终展示层：负净额标记完成后才执行参数事业部范围处理，参数外记录留空留痕。 */
DISPLAY_TURNOVER AS (
    SELECT F.COD_SCENARIO
         , F.COD_PERIODO
         , F.COD_AZIENDA
         , F.DATA_SOURCE
         , F.COD_CATEGORIA
         , F.CUST_CODE
         , F.CUST_NAME
         , F.CUST_HEAD_CODE
         , F.CUST_HEAD_NAME
         , F.SUB_CUST_CODE
         , F.SUB_CUST_NAME
         , F.GRP_SCOPE
         , F.CP_COMPANY_CODE
         , F.TURNOVER_PROFITCENTER_CODE
         , CASE
               WHEN F.BUSINESS_UNIT_CODE IS NULL
                 OR F.BUSINESS_UNIT_CODE IN (${$ANL_D_BG.code})
               THEN F.BUSINESS_UNIT_CODE
           END AS BUSINESS_UNIT_CODE
         , F.ARPTOV_FLAG
         , F.AR_AMT_FLAG
         , CASE
               WHEN F.BUSINESS_UNIT_CODE IS NOT NULL
                AND F.BUSINESS_UNIT_CODE NOT IN (${$ANL_D_BG.code})
               THEN '被事业部参数排除'
               ELSE F.BUSINESS_UNIT_MAP_STATUS
           END AS BUSINESS_UNIT_MAP_STATUS
         , F.TURNOVER_AMT
         , F.F1_ODUE_AMT
         , F.F2_EPAY_AMT
         , F.F3_ECR_AMT
         , F.F4_UREB_AMT
         , F.F5_UFEE_AMT
         , F.F6_INVSM_AMT
         , F.F7_GSUB_AMT
         , F.F8_ADJ_AMT
      FROM FILTERED_TURNOVER F
),
/* 最终事业部筛选：仅保留事业部为空或命中参数的展示记录；参数外记录已在上一层置空。 */
FINAL_TURNOVER AS (
    SELECT D.COD_SCENARIO
         , D.COD_PERIODO
         , D.COD_AZIENDA
         , D.DATA_SOURCE
         , D.COD_CATEGORIA
         , D.CUST_CODE
         , D.CUST_NAME
         , D.CUST_HEAD_CODE
         , D.CUST_HEAD_NAME
         , D.SUB_CUST_CODE
         , D.SUB_CUST_NAME
         , D.GRP_SCOPE
         , D.CP_COMPANY_CODE
         , D.TURNOVER_PROFITCENTER_CODE
         , D.BUSINESS_UNIT_CODE
         , D.ARPTOV_FLAG
         , D.AR_AMT_FLAG
         , D.BUSINESS_UNIT_MAP_STATUS
         , D.TURNOVER_AMT
         , D.F1_ODUE_AMT
         , D.F2_EPAY_AMT
         , D.F3_ECR_AMT
         , D.F4_UREB_AMT
         , D.F5_UFEE_AMT
         , D.F6_INVSM_AMT
         , D.F7_GSUB_AMT
         , D.F8_ADJ_AMT
      FROM DISPLAY_TURNOVER D
     WHERE D.BUSINESS_UNIT_CODE IS NULL
        OR D.BUSINESS_UNIT_CODE IN (${$ANL_D_BG.code})
)
SELECT F.COD_SCENARIO AS SCENARIO
     , F.COD_PERIODO AS PERIODO
     , F.COD_AZIENDA AS COMPANY_CODE
     , F.COD_CATEGORIA
     , F.CUST_CODE
     , MAX(F.CUST_NAME) AS CUST_NAME
     , F.CUST_HEAD_CODE AS CUST_HEAD_CODE
     , MAX(F.CUST_HEAD_NAME) AS CUST_HEAD_NAME
     , F.SUB_CUST_CODE AS SUB_CUST_CODE
     , MAX(F.SUB_CUST_NAME) AS SUB_CUST_NAME
     , F.CP_COMPANY_CODE AS CP_COMPANY_CODE
     , F.TURNOVER_PROFITCENTER_CODE
     , F_TGK_GET_DIMNAME('DEST2', F.TURNOVER_PROFITCENTER_CODE) AS TURNOVER_PROFITCENTER_NAME
     , F.BUSINESS_UNIT_CODE
     , CASE
           WHEN F.BUSINESS_UNIT_CODE IS NULL THEN NULL
           ELSE F_TGK_GET_DIMNAME('D_BG', F.BUSINESS_UNIT_CODE)
       END AS BUSINESS_UNIT_NAME
     , SUM(F.TURNOVER_AMT) AS TURNOVER_AMT
     , SUM(F.F1_ODUE_AMT) AS F1_ODUE_AMT
     , SUM(F.F2_EPAY_AMT) AS F2_EPAY_AMT
     , SUM(F.F3_ECR_AMT) AS F3_ECR_AMT
     , SUM(F.F4_UREB_AMT) AS F4_UREB_AMT
     , SUM(F.F5_UFEE_AMT) AS F5_UFEE_AMT
     , SUM(F.F6_INVSM_AMT) AS F6_INVSM_AMT
     , SUM(F.F7_GSUB_AMT) AS F7_GSUB_AMT
     , SUM(F.F8_ADJ_AMT) AS F8_ADJ_AMT
     , F.ARPTOV_FLAG
     , F.AR_AMT_FLAG
  FROM FINAL_TURNOVER F
 GROUP BY F.COD_SCENARIO
        , F.COD_PERIODO
        , F.COD_AZIENDA
        , F.COD_CATEGORIA
        , F.CUST_CODE
        , F.CUST_HEAD_CODE
        , F.SUB_CUST_CODE
        , F.CP_COMPANY_CODE
        , F.TURNOVER_PROFITCENTER_CODE
        , F.BUSINESS_UNIT_CODE
        , F.ARPTOV_FLAG
        , F.AR_AMT_FLAG
 ORDER BY F.COD_AZIENDA
        , F.CUST_CODE
        , F.TURNOVER_PROFITCENTER_CODE
        , F.BUSINESS_UNIT_CODE
;
