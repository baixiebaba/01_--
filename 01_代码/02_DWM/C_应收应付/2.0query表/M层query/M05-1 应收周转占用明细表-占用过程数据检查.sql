/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261110 18:45
 * 本次修改：ALTER BY 20261110 18:45 SHIQINGFENG.EX 新增原始利润中心编码与名称，置于映射后周转利润中心之前。
 * 上次修改：ALTER BY 20261110 18:12 SHIQINGFENG.EX ARPM02利润中心改按AW_RUL_ARPPRC_000001映射：batch1公司+源利润中心 > batch2源利润中心 > 原值，复刻TOV。
 *
 * 查询名称  ：应收周转占用明细表-占用过程数据检查
 * 源表      ：AW_MR9_ARPM02_000001、AW_MR9_ARPM01_000001、TGK_FIMA_HISENSE.AW_RUL_ARPPRC_000001、DWD_FI_MR_AR_IMOCC_MI 等，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261110 18:45 SHIQINGFENG.EX 新增原始利润中心编码与名称，置于映射后周转利润中心之前。
 *   ALTER BY 20261110 18:12 SHIQINGFENG.EX ARPM02利润中心改按AW_RUL_ARPPRC_000001映射：batch1公司+源利润中心 > batch2源利润中心 > 原值，复刻TOV。
 *   ALTER BY 20261110 10:46 SHIQINGFENG.EX 周转利润中心编码前新增二级性质字段NATURE_L2_NAME。
 *******************************************************************************/
WITH
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
/* 周转原始来源：ARPM02单次取数并生成ARPTOV正向取数标记，IMOCC保留TOV正常来源条件，智动精工和模具按TOV特殊来源固定事业部取数。 */
TURNOVER_SOURCE AS (
    SELECT A.COD_SCENARIO
         , A.COD_PERIODO
         , A.COD_AZIENDA
         , 'ARPM02' AS DATA_SOURCE
         , CASE
             WHEN A.ME_AGE_FLAG IN ('AR', 'CA', 'A10')
               THEN 'ZAMOUNT'
             WHEN A.MB_AGE_FLAG IN ('AR', 'CA', 'A10')
               THEN 'ZAMOUNT_L2'
           END AS COD_CATEGORIA
         , 'ARPM02-账龄表' AS SRC_DETAIL
         , TRIM(A.CUST_CODE) AS CUST_CODE
         , A.CUST_NAME
         , A.CUST_HEAD_CODE
         , A.CUST_HEAD_NAME
         , TRIM(A.CUST_CODE) AS SUB_CUST_CODE
         , A.CUST_NAME AS SUB_CUST_NAME
         , A.GRP_SCOPE
         , A.COD_AZI_CTP AS CP_COMPANY_CODE
         , A.NATURE_L2_NAME
         , A.COD_DEST2 AS SRC_PROFITCENTER_CODE
         /* 利润中心按ARPPRC映射：batch1公司+源利润中心 > batch2源利润中心 > 原值。 */
         , NVL(P1.COD_DEST2, NVL(P2.COD_DEST2, A.COD_DEST2)) AS MAPPED_PROFITCENTER_CODE
         , NULL AS FIXED_BG
         /* TOV_FLAG由AG过程统一打标，涵盖利润中心、账龄标识及特殊取数剔除规则；N行保留用于过程留痕。
            ALTER BY 20261109 11:12 SHIQINGFENG.EX ARPTOV_FLAG改取ARPM02的TOV_FLAG标识列 */
         , A.TOV_FLAG AS ARPTOV_FLAG
         , NVL(A.BCY_ADJ_INCL_0_AMT, 0) AS TURNOVER_AMT
         , NVL(A.UREB_AMT, 0) AS UREB_AMT
         , NVL(A.SPC_DSV_DED_AMT, 0) AS SPC_DSV_DED_AMT
         /* 应收占用金额：050节点公司按未兑现回款冲减，其他公司按DSV专扣冲减。 */
         , CASE
             WHEN EXISTS (
                   SELECT 1
                     FROM TGK_FIMA_HISENSE.V_REF_AZIENDA R10_050
                    WHERE R10_050.HIE = '10'
                      AND R10_050.NODE = '050'
                      AND R10_050.ELEM = A.COD_AZIENDA
                ) THEN CASE
                    WHEN NVL(A.UREB_AMT, 0) > NVL(A.BCY_ADJ_INCL_0_AMT, 0)
                      THEN 0
                    ELSE NVL(A.BCY_ADJ_INCL_0_AMT, 0) - NVL(A.UREB_AMT, 0)
                  END
             ELSE NVL(A.BCY_ADJ_INCL_0_AMT, 0) - NVL(A.SPC_DSV_DED_AMT, 0)
           END AS AR_AMT
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
      LEFT JOIN ARPPRC_RULE_1 P1
        ON P1.COD_AZIENDA = TRIM(A.COD_AZIENDA)
       AND P1.SRC_PROFITCENTER_CODE = LTRIM(TRIM(A.COD_DEST2), '0')
      LEFT JOIN ARPPRC_RULE_2 P2
        ON P2.SRC_PROFITCENTER_CODE = LTRIM(TRIM(A.COD_DEST2), '0')
     WHERE A.COD_SCENARIO = ${$Scenario.code}
       AND A.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
       AND A.GRP_SCOPE = F_TGK_UNICODE_AS('decode', 'GEX-集团外')
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
         , 'IMOCC-国际营销占用' AS SRC_DETAIL
         , TRIM(I.CUST_CODE) AS CUST_CODE
         , I.CUST_NAME
         , TRIM(I.CUST_CODE) AS CUST_HEAD_CODE
         , I.CUST_NAME AS CUST_HEAD_NAME
         , TRIM(I.CUST_CODE) AS SUB_CUST_CODE
         , I.CUST_NAME AS SUB_CUST_NAME
         , 'GEX-集团外' AS GRP_SCOPE
         , I.CP_COMPANY_CODE AS CP_COMPANY_CODE
         , NULL AS NATURE_L2_NAME
         , I.PROFITCENTER_CODE AS SRC_PROFITCENTER_CODE
         , I.PROFITCENTER_CODE AS MAPPED_PROFITCENTER_CODE
         , NULL AS FIXED_BG
         , 'Y' AS ARPTOV_FLAG
         , NVL(I.IMOCC_CNY_AMT, 0) AS TURNOVER_AMT
         , 0 AS UREB_AMT
         , 0 AS SPC_DSV_DED_AMT
         , NVL(I.IMOCC_CNY_AMT, 0) AS AR_AMT
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

     UNION ALL

    /* 智动精工占用：复用TOV特殊来源口径，绕过利润中心映射，直接挂固定事业部。 */
    SELECT ${$Scenario.code} AS COD_SCENARIO
         , LPAD(${$Period.code}, 2, '0') AS COD_PERIODO
         , '4330' AS COD_AZIENDA
         , 'GB' AS DATA_SOURCE
         , 'ZAMOUNT' AS COD_CATEGORIA
         , 'GB-1.0取数' AS SRC_DETAIL
         , NULL AS CUST_CODE
         , NULL AS CUST_NAME
         , NULL AS CUST_HEAD_CODE
         , NULL AS CUST_HEAD_NAME
         , NULL AS SUB_CUST_CODE
         , NULL AS SUB_CUST_NAME
         , 'GEX-集团外' AS GRP_SCOPE
         , 'ZZZZ' AS CP_COMPANY_CODE
         , NULL AS NATURE_L2_NAME
         , 'ZZZZ' AS SRC_PROFITCENTER_CODE
         , 'ZZZZ' AS MAPPED_PROFITCENTER_CODE
         , 'BG001_BU001' AS FIXED_BG
         , 'Y' AS ARPTOV_FLAG
         , NVL(SUM(A.IMPORTO), 0) AS TURNOVER_AMT
         , 0 AS UREB_AMT
         , 0 AS SPC_DSV_DED_AMT
         , NVL(SUM(A.IMPORTO), 0) AS AR_AMT
         , 0 AS F1_ODUE_AMT
         , 0 AS F2_EPAY_AMT
         , 0 AS F3_ECR_AMT
         , 0 AS F4_UREB_AMT
         , 0 AS F5_UFEE_AMT
         , 0 AS F6_INVSM_AMT
         , 0 AS F7_GSUB_AMT
         , 0 AS F8_ADJ_AMT
      FROM TGK_GB_HISENSE.DATI_SALDI_LORDI A
     WHERE A.COD_SCENARIO = ${$Scenario.code}
       AND A.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
       AND A.COD_AZIENDA IN (
             SELECT ELEM
               FROM TGK_GB_HISENSE.V_REF_AZIENDA
              WHERE HIE = '10'
                AND NODE = '150'
           )
       AND A.COD_CONTO = 'SZK1011'
       AND A.COD_CATEGORIA IN ('ZAMOUNT', 'ZB00')
       AND A.COD_DEST1 = 'ZZCC'
       AND A.COD_DEST5 = 'ZZOT'

     UNION ALL

    /* 模具占用：复用TOV特殊来源口径，绕过利润中心映射，直接挂固定事业部。 */
    SELECT ${$Scenario.code} AS COD_SCENARIO
         , LPAD(${$Period.code}, 2, '0') AS COD_PERIODO
         , '1100' AS COD_AZIENDA
         , 'GB' AS DATA_SOURCE
         , 'ZAMOUNT' AS COD_CATEGORIA
         , 'GB-1.0取数' AS SRC_DETAIL
         , NULL AS CUST_CODE
         , NULL AS CUST_NAME
         , NULL AS CUST_HEAD_CODE
         , NULL AS CUST_HEAD_NAME
         , NULL AS SUB_CUST_CODE
         , NULL AS SUB_CUST_NAME
         , 'GEX-集团外' AS GRP_SCOPE
         , 'ZZZZ' AS CP_COMPANY_CODE
         , NULL AS NATURE_L2_NAME
         , 'ZZZZ' AS SRC_PROFITCENTER_CODE
         , 'ZZZZ' AS MAPPED_PROFITCENTER_CODE
         , 'BG004_BU001' AS FIXED_BG
         , 'Y' AS ARPTOV_FLAG
         , NVL(SUM(A.IMPORTO), 0) AS TURNOVER_AMT
         , 0 AS UREB_AMT
         , 0 AS SPC_DSV_DED_AMT
         , NVL(SUM(A.IMPORTO), 0) AS AR_AMT
         , 0 AS F1_ODUE_AMT
         , 0 AS F2_EPAY_AMT
         , 0 AS F3_ECR_AMT
         , 0 AS F4_UREB_AMT
         , 0 AS F5_UFEE_AMT
         , 0 AS F6_INVSM_AMT
         , 0 AS F7_GSUB_AMT
         , 0 AS F8_ADJ_AMT
      FROM TGK_GB_HISENSE.DATI_SALDI_LORDI A
     WHERE A.COD_SCENARIO = ${$Scenario.code}
       AND A.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
       AND A.COD_AZIENDA IN (
             SELECT ELEM
               FROM TGK_GB_HISENSE.V_REF_AZIENDA
              WHERE HIE = '10'
                AND NODE IN ('100', '110')
           )
       AND A.COD_CONTO = 'SZK1014'
       /* BGT和ACT仅使用各自维护的占用类别。 */
       AND (
             (SUBSTR(${$Scenario.code}, -3) = 'BGT'
               AND A.COD_CATEGORIA IN ('ZAMOUNT', 'ZT01'))
          OR (SUBSTR(${$Scenario.code}, -3) = 'ACT'
               AND A.COD_CATEGORIA IN ('ZAMOUNT', '1ADJ', 'ZB00', 'ZADJ'))
           )
       AND A.COD_DEST1 IN (
             SELECT ELEM
               FROM TGK_GB_HISENSE.V_REF_DEST1
              WHERE HIE = '01'
                AND NODE = '110'
             UNION ALL
             SELECT 'ZZCC'
               FROM DUAL
           )
       AND A.COD_DEST5 = 'ZZOT'
),
/* 周转利润中心仅按TOV实际逻辑标准化：ARPM02取ARPPRC映射后的COD_DEST2，IMOCC取PROFITCENTER_CODE，均在此处去除前导零一次。 */
TURNOVER_NORMALIZED AS (
    SELECT T.COD_SCENARIO
         , T.COD_PERIODO
         , T.COD_AZIENDA
         , CASE
             WHEN COUNT(DISTINCT T.DATA_SOURCE) > 1
               THEN 'ARPM02+IMOCC'
             ELSE MAX(T.DATA_SOURCE)
           END AS DATA_SOURCE
         , T.COD_CATEGORIA
         , T.SRC_DETAIL
         , T.CUST_CODE
         , T.CUST_NAME
         , T.CUST_HEAD_CODE
         , T.CUST_HEAD_NAME
         , T.SUB_CUST_CODE
         , T.SUB_CUST_NAME
         , T.GRP_SCOPE
         , T.CP_COMPANY_CODE
         , T.NATURE_L2_NAME
         , LTRIM(TRIM(T.SRC_PROFITCENTER_CODE), '0') AS SRC_PROFITCENTER_CODE
         , LTRIM(TRIM(T.MAPPED_PROFITCENTER_CODE), '0') AS TURNOVER_PROFITCENTER_CODE
         , T.FIXED_BG
         , T.ARPTOV_FLAG
         , SUM(T.TURNOVER_AMT) AS TURNOVER_AMT
         , SUM(T.UREB_AMT) AS UREB_AMT
         , SUM(T.SPC_DSV_DED_AMT) AS SPC_DSV_DED_AMT
         , SUM(T.AR_AMT) AS AR_AMT
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
            , T.SRC_DETAIL
            , T.CUST_CODE
            , T.CUST_NAME
            , T.CUST_HEAD_CODE
            , T.CUST_HEAD_NAME
            , T.SUB_CUST_CODE
            , T.SUB_CUST_NAME
            , T.GRP_SCOPE
            , T.CP_COMPANY_CODE
            , T.NATURE_L2_NAME
            , LTRIM(TRIM(T.SRC_PROFITCENTER_CODE), '0')
            , LTRIM(TRIM(T.MAPPED_PROFITCENTER_CODE), '0')
            , T.FIXED_BG
            , T.ARPTOV_FLAG
),
/* 账套映射聚合：每个账套只保留一个状态行，供未映射留痕使用。 */
ATS_BG_STATUS AS (
    SELECT A.COD_AZIENDA
         , COUNT(DISTINCT A.COD_BG) AS ATS_BG_COUNT
      FROM ATS_BG_MAP A
     GROUP BY A.COD_AZIENDA
),
/* 利润中心映射聚合：每个利润中心只保留一个状态行，供未映射留痕使用。 */
PCR_BG_STATUS AS (
    SELECT P.COD_DEST2
         , COUNT(DISTINCT P.COD_BG) AS PCR_BG_COUNT
      FROM PCR_BG_MAP P
     GROUP BY P.COD_DEST2
),
/* 利润中心与公司的事业部交集：命中几个事业部就出几行，与TOV的INNER JOIN口径一致。
   ALTER BY 20261109 18:32 SHIQINGFENG.EX 取消事业部映射冲突判定 */
MATCHED_BG_STATUS AS (
    SELECT DISTINCT P.COD_DEST2
         , A.COD_AZIENDA
         , P.COD_BG
      FROM PCR_BG_MAP P
      JOIN ATS_BG_MAP A
        ON A.COD_BG = P.COD_BG
),
/* 映射后的周转数据：每个命中事业部出一行，保留未映射和公司与利润中心不一致的留痕状态；
   智动精工和模具等特殊来源无利润中心映射，直接使用固定事业部。 */
MAPPED_TURNOVER AS (
    SELECT T.COD_SCENARIO
         , T.COD_PERIODO
         , T.COD_AZIENDA
         , T.DATA_SOURCE
         , T.COD_CATEGORIA
         , T.SRC_DETAIL
         , T.CUST_CODE
         , T.CUST_NAME
         , T.CUST_HEAD_CODE
         , T.CUST_HEAD_NAME
         , T.SUB_CUST_CODE
         , T.SUB_CUST_NAME
         , T.GRP_SCOPE
         , T.CP_COMPANY_CODE
         , T.NATURE_L2_NAME
         , T.SRC_PROFITCENTER_CODE
         , T.TURNOVER_PROFITCENTER_CODE
         , T.FIXED_BG
         , NVL(MATCHED.COD_BG, T.FIXED_BG) AS BUSINESS_UNIT_CODE
         , T.ARPTOV_FLAG
         , CASE
             WHEN T.FIXED_BG IS NOT NULL
               THEN '特殊来源固定事业部'
             WHEN PCR.PCR_BG_COUNT IS NULL
               THEN '利润中心未映射事业部'
             WHEN ATS.ATS_BG_COUNT IS NULL
               THEN '账套未映射事业部'
             WHEN MATCHED.COD_BG IS NULL
               THEN '公司与利润中心事业部不一致'
             ELSE '已映射同一事业部'
           END AS BUSINESS_UNIT_MAP_STATUS
         , CASE
             WHEN TRIM(T.CUST_HEAD_CODE) IS NULL
               THEN NULL
             ELSE NVL(LTRIM(TRIM(T.CUST_HEAD_CODE), '0'), '0')
           END AS CUST_MATCH_CODE
         , T.TURNOVER_AMT
         , T.UREB_AMT
         , T.SPC_DSV_DED_AMT
         , T.AR_AMT
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
       AND M.GRP_SCOPE = F_TGK_UNICODE_AS('decode', 'GEX-集团外')
       AND M.BUSINESS_UNIT_MAP_STATUS = F_TGK_UNICODE_AS('decode','已映射同一事业部')
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
         , M.SRC_DETAIL
         , M.CUST_CODE
         , M.CUST_NAME
         , M.CUST_HEAD_CODE
         , M.CUST_HEAD_NAME
         , M.SUB_CUST_CODE
         , M.SUB_CUST_NAME
         , M.GRP_SCOPE
         , M.CP_COMPANY_CODE
         , M.NATURE_L2_NAME
         , M.SRC_PROFITCENTER_CODE
         , M.TURNOVER_PROFITCENTER_CODE
         , M.FIXED_BG
         , M.BUSINESS_UNIT_CODE
         , M.ARPTOV_FLAG
         , CASE
               /* 正向金额取数标记：通过ARPTOV且未被负净额事业部规则过滤，才进入ARPM03。 */
             WHEN M.ARPTOV_FLAG = 'Y'
              AND M.BUSINESS_UNIT_MAP_STATUS IN ('已映射同一事业部', '特殊来源固定事业部')
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
         , M.UREB_AMT
         , M.SPC_DSV_DED_AMT
         , M.AR_AMT
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
/* 事业部展示层：保留原始事业部编码，参数范围统一在最终层筛选。 */
DISPLAY_TURNOVER AS (
    SELECT F.COD_SCENARIO
         , F.COD_PERIODO
         , F.COD_AZIENDA
         , F.DATA_SOURCE
         , F.COD_CATEGORIA
         , F.SRC_DETAIL
         , F.CUST_CODE
         , F.CUST_NAME
         , F.CUST_HEAD_CODE
         , F.CUST_HEAD_NAME
         , F.SUB_CUST_CODE
         , F.SUB_CUST_NAME
         , F.GRP_SCOPE
         , F.CP_COMPANY_CODE
         , F.NATURE_L2_NAME
         , F.SRC_PROFITCENTER_CODE
         , F.TURNOVER_PROFITCENTER_CODE
         , F.FIXED_BG
         , F.BUSINESS_UNIT_CODE
         , F.ARPTOV_FLAG
         , F.AR_AMT_FLAG
         , CASE
             WHEN F.BUSINESS_UNIT_CODE IS NOT NULL
              AND F.BUSINESS_UNIT_CODE NOT IN (${$ANL_D_BG.code})
               THEN '被事业部参数排除'
             ELSE F.BUSINESS_UNIT_MAP_STATUS
           END AS BUSINESS_UNIT_MAP_STATUS
         , F.TURNOVER_AMT
         , F.UREB_AMT
         , F.SPC_DSV_DED_AMT
         , F.AR_AMT
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
/* 参数事业部只用于圈定公司范围，展示不再按事业部裁剪；事业部列原样输出，由使用者自行筛选。 */
FINAL_TURNOVER AS (
    SELECT D.COD_SCENARIO
         , D.COD_PERIODO
         , D.COD_AZIENDA
         , D.DATA_SOURCE
         , D.COD_CATEGORIA
         , D.SRC_DETAIL
         , D.CUST_CODE
         , D.CUST_NAME
         , D.CUST_HEAD_CODE
         , D.CUST_HEAD_NAME
         , D.SUB_CUST_CODE
         , D.SUB_CUST_NAME
         , D.GRP_SCOPE
         , D.CP_COMPANY_CODE
         , D.NATURE_L2_NAME
         , D.SRC_PROFITCENTER_CODE
         , D.TURNOVER_PROFITCENTER_CODE
         , D.FIXED_BG
         , D.BUSINESS_UNIT_CODE
         , D.ARPTOV_FLAG
         , D.AR_AMT_FLAG
         , D.BUSINESS_UNIT_MAP_STATUS
         , D.TURNOVER_AMT
         , D.UREB_AMT
         , D.SPC_DSV_DED_AMT
         , D.AR_AMT
         , D.F1_ODUE_AMT
         , D.F2_EPAY_AMT
         , D.F3_ECR_AMT
         , D.F4_UREB_AMT
         , D.F5_UFEE_AMT
         , D.F6_INVSM_AMT
         , D.F7_GSUB_AMT
         , D.F8_ADJ_AMT
      FROM DISPLAY_TURNOVER D
     WHERE (   D.FIXED_BG IS NULL
           AND D.COD_AZIENDA IN (
                 SELECT M.COD_AZIENDA
                   FROM ATS_BG_MAP M
                  WHERE M.COD_BG IN (${$ANL_D_BG.code})
               )
        OR D.FIXED_BG IN (${$ANL_D_BG.code})
           )
)
SELECT F.COD_SCENARIO AS SCENARIO               /* 场景 */
     , F.COD_PERIODO AS PERIODO                 /* 期间 */
     , F.COD_AZIENDA AS COMPANY_CODE            /* 公司 */
     , CASE WHEN F.COD_CATEGORIA = 'ZAMOUNT' 
              THEN '事业部口径' 
            WHEN F.COD_CATEGORIA = 'ZAMOUNT_L2' 
              THEN '分公司口径'
       END COD_CATEGORIA                        /* 类别 */
     , F.SRC_DETAIL                             /* 数据源标识 */
     , F.CUST_CODE                              /* 客商编码 */
     , MAX(F.CUST_NAME) AS CUST_NAME            /* 客商名称 */
     , F.CUST_HEAD_CODE AS CUST_HEAD_CODE       /* 主户编码 */
     , MAX(F.CUST_HEAD_NAME) AS CUST_HEAD_NAME  /* 主户名称 */
     , F.SUB_CUST_CODE AS SUB_CUST_CODE         /* 分户编码 */
     , MAX(F.SUB_CUST_NAME) AS SUB_CUST_NAME    /* 分户名称 */
     , F.CP_COMPANY_CODE AS CP_COMPANY_CODE     /* 对方公司 */
     , MAX(F.NATURE_L2_NAME) AS NATURE_L2_NAME  /* 二级性质 */
     , F.SRC_PROFITCENTER_CODE                  /* 原始利润中心编码 */
     , MAX(F_TGK_GET_DIMNAME('DEST2', F.SRC_PROFITCENTER_CODE)) AS SRC_PROFITCENTER_NAME  /* 原始利润中心名称 */
     , F.TURNOVER_PROFITCENTER_CODE             /* 周转利润中心编码 */
     , F_TGK_GET_DIMNAME('DEST2', F.TURNOVER_PROFITCENTER_CODE) AS TURNOVER_PROFITCENTER_NAME  /* 周转利润中心名称 */
     , F.BUSINESS_UNIT_CODE                     /* 事业部编码 */
     , CASE
         WHEN F.BUSINESS_UNIT_CODE IS NULL
           THEN NULL
         ELSE F_TGK_GET_DIMNAME('D_BG', F.BUSINESS_UNIT_CODE)
       END AS BUSINESS_UNIT_NAME            /* 事业部名称 */
     , F.ARPTOV_FLAG                        /* 周转取数来源标记 */
     , SUM(F.TURNOVER_AMT) AS TURNOVER_AMT  /* 周转金额 */
     , SUM(F.UREB_AMT) AS UREB_AMT          /* 已回款未开票金额 */
     , SUM(F.SPC_DSV_DED_AMT) AS SPC_DSV_DED_AMT  /* DSV专扣金额 */
     , SUM(F.AR_AMT) AS AR_AMT              /* 应收占用金额 */
     , SUM(F.F1_ODUE_AMT) AS F1_ODUE_AMT    /* 因素1-超期款金额 */
     , SUM(F.F2_EPAY_AMT) AS F2_EPAY_AMT    /* 因素2-提前回款金额 */
     , SUM(F.F3_ECR_AMT) AS F3_ECR_AMT      /* 因素3-电商零售销售节奏 */
     , SUM(F.F4_UREB_AMT) AS F4_UREB_AMT    /* 因素4-已确认未兑现返利余额 */
     , SUM(F.F5_UFEE_AMT) AS F5_UFEE_AMT    /* 因素5-已账扣未报账的欠付费用 */
     , SUM(F.F6_INVSM_AMT) AS F6_INVSM_AMT  /* 因素6-开票样机额度 */
     , SUM(F.F7_GSUB_AMT) AS F7_GSUB_AMT    /* 因素7-国补未回款影响金额 */
     , SUM(F.F8_ADJ_AMT) AS F8_ADJ_AMT      /* 因素8手工导入因素 */
     
  FROM FINAL_TURNOVER F
 WHERE  SRC_DETAIL = F_TGK_UNICODE_AS('decode','ARPM02-账龄表')
 GROUP BY F.COD_SCENARIO
        , F.COD_PERIODO
        , F.COD_AZIENDA
        , F.COD_CATEGORIA
        , F.SRC_DETAIL
        , F.CUST_CODE
        , F.CUST_HEAD_CODE
        , F.SUB_CUST_CODE
        , F.CP_COMPANY_CODE
        , F.SRC_PROFITCENTER_CODE
        , F.TURNOVER_PROFITCENTER_CODE
        , F.BUSINESS_UNIT_CODE
        , F.ARPTOV_FLAG
   HAVING SUM(F.TURNOVER_AMT) <> 0
       OR SUM(F.AR_AMT) <> 0
       OR SUM(F.F1_ODUE_AMT) <> 0
       OR SUM(F.F2_EPAY_AMT) <> 0
       OR SUM(F.F3_ECR_AMT) <> 0
       OR SUM(F.F4_UREB_AMT) <> 0
       OR SUM(F.F5_UFEE_AMT) <> 0
       OR SUM(F.F6_INVSM_AMT) <> 0
       OR SUM(F.F7_GSUB_AMT) <> 0
       OR SUM(F.F8_ADJ_AMT) <> 0
 ORDER BY F.COD_AZIENDA
        , F.CUST_CODE
        , F.TURNOVER_PROFITCENTER_CODE
        , F.BUSINESS_UNIT_CODE
