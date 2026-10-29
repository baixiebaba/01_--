/*******************************************************************************
 *                                  脚本说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261029 15:15
 * 本次修改：ALTER BY 20261029 15:15 SHIQINGFENG.EX 排除法人口径、管理口径及调整金额全部为0的明细记录。
 * 上次修改：ALTER BY 20261029 11:18 SHIQINGFENG.EX COMPANY_NAME改为通过F_TGK_GET_DIMNAME函数获取。
 *
 * 脚本名称  ：应收占用管法差明细表query.sql
 * 功能描述  ：按事业部范围读取M02账龄数据，匹配M03管理口径应收占用，计算其他调整项、调整后管理口径应收占用及管法差金额。
 * 源表      ：AW_MR9_ARPM02_000001、AW_MR9_ARPM03_000001、AW_RUL_ATSMAP_000001、AW_RUL_ARPTOV_000001，详见Query正文。
 * 目标表    ：无，报表Query直接输出。
 *
 * 修改历史：
 *   ALTER BY 20261029 15:15 SHIQINGFENG.EX 排除法人口径、管理口径及调整金额全部为0的明细记录。
 *   ALTER BY 20261029 11:18 SHIQINGFENG.EX COMPANY_NAME改为通过F_TGK_GET_DIMNAME函数获取。
 *   ALTER BY 20261029 11:16 SHIQINGFENG.EX 按DEST3层级平铺表补充大区名称，优先取4级节点描述并回退5级节点描述。
 *   ALTER BY 20261029 11:14 SHIQINGFENG.EX BUSINESS_UNIT_NAME改为通过F_TGK_GET_DIMNAME函数获取，保留账套节点描述原值。
 *   ALTER BY 20261029 11:05 SHIQINGFENG.EX 保留节点描述，仅将维度要素名称改为通过F_TGK_GET_DIMNAME函数获取。
 *   ALTER BY 20261029 11:03 SHIQINGFENG.EX 维度名称统一使用F_TGK_GET_DIMNAME函数获取。
 *   ALTER BY 20261029 10:57 SHIQINGFENG.EX 取消公司参数限制，按所选事业部下全部有效账套取数。
 *   ALTER BY 20261029 10:49 SHIQINGFENG.EX 新增应收占用管法差明细表Query。
 *******************************************************************************/

/*
 * 参数说明：
 * ${$Scenario.code}：场景，例如2026ACT（实际）或2026BGT（预算/计划）。
 * ${$Period.code}：期间，取值01至12。
 * ${$ANL_D_BG.code}：事业部清单，用于取得事业部下当前期间有效的全部账套；本Query不使用公司参数限制。
 *
 * 口径说明：
 * 1. 法人口径账龄分类取LE_AGE_FLAG，管理口径账龄分类取ME_AGE_FLAG。
 * 2. M02仅保留LE_AGE_FLAG或ME_AGE_FLAG属于AR、CA、A10的数据。
 * 3. 法人口径应收占用仅在LE_AGE_FLAG属于AR、CA、A10时取BCY_0_AMT。
 * 4. 管理口径应收占用按事业部、公司、客商、利润中心匹配M03的AR_AMT；
 *    管理单体账龄对应M03的ZAMOUNT类别。
 * 5. 日立公司范围按公司架构HIE=10、NODE=050识别，其他调整项取UREB_AMT；
 *    非日立公司其他调整项取SPC_DSV_DED_AMT。
 * 6. 管理口径应收占用-调整后 = 管理口径应收占用 - 其他调整项。
 * 7. 管法差金额 = 法人口径应收占用 - 管理口径应收占用-调整后。
 * 8. M03先按四个匹配键汇总再关联，避免M03自身多行直接连接放大M02记录。
 */
WITH
/* 当前期间、参数事业部下的全部有效账套范围；事业部和公司名称通过维度函数获取，账套节点描述保留配置表原值。 */
BUSINESS_SCOPE AS (
    SELECT A.COD_BG AS BUSINESS_UNIT_CODE
         , F_TGK_GET_DIMNAME('D_BG', A.COD_BG) AS BUSINESS_UNIT_NAME
         , A.COD_AZIENDA AS COMPANY_CODE
         , F_TGK_GET_DIMNAME('AZIENDA', A.COD_AZIENDA) AS COMPANY_NAME
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
     WHERE A.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(A.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND A.COD_BG IN (${$ANL_D_BG.code})
     GROUP BY A.COD_BG
            , A.COD_AZIENDA
),
/* 公司架构10下050节点的日立公司范围，用于判断其他调整项取返利还是垫资扣减。 */
HITACHI_COMPANY AS (
    SELECT DISTINCT A.ELEM AS COMPANY_CODE
      FROM TGK_FIMA_HISENSE.V_REF_AZIENDA A
     WHERE A.HIE = '10'
       AND A.NODE = '050'
),
/* 公司分类层级：一级、二级节点描述保留层级视图原值，三级维度要素名称在输出层通过函数获取。 */
CHANNEL_DIM AS (
    SELECT C.COD AS CHANNEL_L3_CODE
         , MAX(C.DESC0) AS CHANNEL_L3_NAME
         , MAX(C.COD_ELEGER5) AS CHANNEL_L2_CODE
         , MAX(C.DESC_ELEGER5) AS CHANNEL_L2_NAME
         , MAX(C.COD_ELEGER6) AS CHANNEL_L1_CODE
         , MAX(C.DESC_ELEGER6) AS CHANNEL_L1_NAME
      FROM TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT C
     GROUP BY C.COD
),
/* DEST3层级节点：按HIE=01取得大区描述，优先使用4级节点，4级为空时回退5级节点。 */
DEST3_REGION_DIM AS (
    SELECT DISTINCT D.COD_DEST3
         , D.DESC_DEST3_ELEGER4
         , D.DESC_DEST3_ELEGER5
      FROM TGK_FIMA_HISENSE.DEST3_GERARCHIA_FLAT D
     WHERE D.COD_DEST3_GERARCHIA = '01'
),
/* 匹配顺序2的公司和客户特殊剔除配置，仅取当前年月有效记录。 */
SPECIAL_EXCLUDE_RULE AS (
    SELECT DISTINCT TRIM(R.COD_AZIENDA) AS COMPANY_CODE
         , TRIM(R.CUST_CODE) AS CUST_CODE
      FROM AW_RUL_ARPTOV_000001 R
     WHERE R.BATCH_ID = '2'
       AND R.VALID_FR <= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND NVL(R.VALID_TO, '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || LPAD(${$Period.code}, 2, '0')
       AND R.COD_AZIENDA IS NOT NULL
       AND R.CUST_CODE IS NOT NULL
),
/*
 * M03管理口径应收占用：按事业部、公司、客商、利润中心四个匹配键汇总AR_AMT。
 * ZAMOUNT对应管理单体账龄口径，利润中心统一去除前导零后参与匹配。
 */
M03_AR_SUM AS (
    SELECT M.D_BG AS BUSINESS_UNIT_CODE
         , M.COD_AZIENDA AS COMPANY_CODE
         , TRIM(M.CUST_CODE) AS CUST_CODE
         , NVL(LTRIM(TRIM(M.COD_DEST2), '0'), '0') AS PROFITCENTER_MATCH_CODE
         , SUM(NVL(M.AR_AMT, 0)) AS MANAGE_AR_OCCUPATION_AMT
      FROM AW_MR9_ARPM03_000001 M
     WHERE M.COD_SCENARIO = ${$Scenario.code}
       AND M.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
       AND M.D_BG IN (${$ANL_D_BG.code})
       AND M.COD_CATEGORIA = 'ZAMOUNT'
     GROUP BY M.D_BG
            , M.COD_AZIENDA
            , TRIM(M.CUST_CODE)
            , NVL(LTRIM(TRIM(M.COD_DEST2), '0'), '0')
),
/*
 * M02明细：按所选事业部取得有效账套数据，保留法人口径或管理口径属于AR、CA、A10的记录。
 * ALTER BY 20261029 15:15 SHIQINGFENG.EX 排除法人口径、管理口径及调整金额全部为0的明细记录。
 */
M02_BASE AS (
    SELECT A.COD_SCENARIO
         , A.COD_PERIODO
         , S.BUSINESS_UNIT_CODE
         , S.BUSINESS_UNIT_NAME
         , A.COD_AZIENDA AS COMPANY_CODE
         , S.COMPANY_NAME
         , A.LE_AGE_FLAG AS LEGAL_AGE_CLASS
         , A.ME_AGE_FLAG AS MANAGE_AGE_CLASS
         , TRIM(A.CUST_CODE) AS CUST_CODE
         , A.CUST_NAME
         , A.CUST_HEAD_CODE
         , A.CUST_HEAD_NAME
         , A.CUST_BRANCH_CODE
         , A.CUST_BRANCH_NAME
         , A.GRP_SCOPE
         , A.COD_AZI_CTP AS CP_COMPANY_CODE
         , A.COUNTRY_NAME
         , A.NATURE_L2_NAME
         , A.D_CHANNEL
         , A.D_ONOFFLINE
         , A.COD_DEST2 AS PROFITCENTER_CODE
         , NVL(LTRIM(TRIM(A.COD_DEST2), '0'), '0') AS PROFITCENTER_MATCH_CODE
         , A.COD_DEST3 AS BUSINESS_RANGE_CODE
         , A.D_SALE_DEPT AS SALE_DEPT_CODE
         , A.D_TOV_CHAN AS TOV_CHANNEL_CODE
         , A.D_CC_CUSTGRP AS CC_CUST_GROUP_CODE
         , A.COD_VALUTA AS LOCAL_CURRENCY_CODE
         , CASE
               WHEN A.LE_AGE_FLAG IN ('AR', 'CA', 'A10')
               THEN NVL(A.BCY_0_AMT, 0)
               ELSE 0
           END AS LEGAL_AR_OCCUPATION_AMT
         , CASE
               WHEN H.COMPANY_CODE IS NOT NULL THEN NVL(A.UREB_AMT, 0)
               ELSE NVL(A.SPC_DSV_DED_AMT, 0)
           END AS OTHER_ADJ_AMT
         , CASE
               WHEN H.COMPANY_CODE IS NOT NULL THEN '日立返利'
               ELSE '垫资扣减'
           END AS OTHER_ADJ_TYPE
      FROM AW_MR9_ARPM02_000001 A
      JOIN BUSINESS_SCOPE S
        ON S.COMPANY_CODE = A.COD_AZIENDA
      LEFT JOIN HITACHI_COMPANY H
        ON H.COMPANY_CODE = A.COD_AZIENDA
     WHERE A.COD_SCENARIO = ${$Scenario.code}
       AND A.COD_PERIODO = LPAD(${$Period.code}, 2, '0')
       AND (
             A.LE_AGE_FLAG IN ('AR', 'CA', 'A10')
          OR A.ME_AGE_FLAG IN ('AR', 'CA', 'A10')
       )
),
/* 关联M03管理口径金额并按业务公式计算调整后金额、管法差金额及差异原因。 */
CALC_DETAIL AS (
    SELECT A.*
         , NVL(M.MANAGE_AR_OCCUPATION_AMT, 0) AS MANAGE_AR_OCCUPATION_AMT
         , NVL(M.MANAGE_AR_OCCUPATION_AMT, 0) - A.OTHER_ADJ_AMT AS MANAGE_AR_OCCUPATION_ADJ_AMT
         , A.LEGAL_AR_OCCUPATION_AMT
           - (NVL(M.MANAGE_AR_OCCUPATION_AMT, 0) - A.OTHER_ADJ_AMT) AS LEGAL_MANAGE_DIFF_AMT
         , CASE
               WHEN A.CUST_CODE LIKE 'XH%' THEN '应收账款-信汇'
               WHEN A.NATURE_L2_NAME = '货款-材料外协' THEN '货款-材料外协'
               WHEN A.GRP_SCOPE IN ('SUB-子公司', 'GIN-集团内') THEN A.GRP_SCOPE
               WHEN EXISTS (
                      SELECT 1
                        FROM SPECIAL_EXCLUDE_RULE R
                       WHERE R.COMPANY_CODE = TRIM(A.COMPANY_CODE)
                         AND R.CUST_CODE = A.CUST_CODE
                    ) THEN '特殊剔除'
               WHEN A.OTHER_ADJ_AMT <> 0 THEN '其他调整项'
           END AS DIFF_REASON
      FROM M02_BASE A
      LEFT JOIN M03_AR_SUM M
        ON M.BUSINESS_UNIT_CODE = A.BUSINESS_UNIT_CODE
       AND M.COMPANY_CODE = A.COMPANY_CODE
       AND M.CUST_CODE = A.CUST_CODE
       AND M.PROFITCENTER_MATCH_CODE = A.PROFITCENTER_MATCH_CODE
)
/* 按需求字段顺序输出应收占用管法差明细。 */
SELECT A.COD_SCENARIO AS SCENARIO
     , A.COD_PERIODO AS PERIOD_CODE
     , A.BUSINESS_UNIT_CODE
     , A.BUSINESS_UNIT_NAME
     , A.COMPANY_CODE
     , A.COMPANY_NAME
     , A.LEGAL_AGE_CLASS
     , A.MANAGE_AGE_CLASS
     , A.CUST_CODE
     , A.CUST_NAME
     , A.CUST_HEAD_CODE
     , A.CUST_HEAD_NAME
     , A.CUST_BRANCH_CODE
     , A.CUST_BRANCH_NAME
     , A.GRP_SCOPE
     , A.CP_COMPANY_CODE
     , A.COUNTRY_NAME
     , A.NATURE_L2_NAME
     , C.CHANNEL_L1_CODE
     , C.CHANNEL_L1_NAME
     , C.CHANNEL_L2_CODE
     , C.CHANNEL_L2_NAME
     , C.CHANNEL_L3_CODE
     , F_TGK_GET_DIMNAME('D_CHANNEL', C.CHANNEL_L3_CODE) AS CHANNEL_L3_NAME
     , A.D_ONOFFLINE AS CHANNEL_GROUP_CODE
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', A.D_ONOFFLINE) AS CHANNEL_GROUP_NAME
     , A.PROFITCENTER_CODE
     , F_TGK_GET_DIMNAME('DEST2', A.PROFITCENTER_CODE) AS PROFITCENTER_NAME
     , A.BUSINESS_RANGE_CODE
     , F_TGK_GET_DIMNAME('DEST3', A.BUSINESS_RANGE_CODE) AS BUSINESS_RANGE_NAME
     , A.SALE_DEPT_CODE
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', A.SALE_DEPT_CODE) AS SALE_DEPT_NAME
     , A.TOV_CHANNEL_CODE
     , F_TGK_GET_DIMNAME('D_TOV_CHAN', A.TOV_CHANNEL_CODE) AS TOV_CHANNEL_NAME
     , A.CC_CUST_GROUP_CODE
     , F_TGK_GET_DIMNAME('D_CC_CUSTGRP', A.CC_CUST_GROUP_CODE) AS CC_CUST_GROUP_NAME
     , A.LOCAL_CURRENCY_CODE
     , NVL(R.DESC_DEST3_ELEGER4, R.DESC_DEST3_ELEGER5) AS REGION_NAME
     , A.LEGAL_AR_OCCUPATION_AMT
     , A.MANAGE_AR_OCCUPATION_AMT
     , A.OTHER_ADJ_AMT
     , A.MANAGE_AR_OCCUPATION_ADJ_AMT
     , A.LEGAL_MANAGE_DIFF_AMT
     , A.DIFF_REASON
  FROM CALC_DETAIL A
  LEFT JOIN CHANNEL_DIM C
    ON C.CHANNEL_L3_CODE = A.D_CHANNEL
  LEFT JOIN DEST3_REGION_DIM R
    ON R.COD_DEST3 = A.BUSINESS_RANGE_CODE
 WHERE NVL(A.LEGAL_AR_OCCUPATION_AMT, 0) <> 0
    OR NVL(A.MANAGE_AR_OCCUPATION_AMT, 0) <> 0
    OR NVL(A.OTHER_ADJ_AMT, 0) <> 0
    OR NVL(A.MANAGE_AR_OCCUPATION_ADJ_AMT, 0) <> 0
    OR NVL(A.LEGAL_MANAGE_DIFF_AMT, 0) <> 0
 ORDER BY A.BUSINESS_UNIT_CODE
        , A.COMPANY_CODE
        , A.CUST_CODE
        , A.PROFITCENTER_CODE
;