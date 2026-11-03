/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261103 09:53
 *   ALTER BY 20261102 18:56 SHIQINGFENG.EX 按 SQL 编码规范统一右对齐：FROM/JOIN 组关键字右端对齐（CROSS JOIN 顶格）、OR/ON 右对齐、WHERE 嵌套条件分层、CASE 表达式 WHEN/THEN/ELSE/END 分行，未修改业务逻辑。
 * 本次修改：ALTER BY 20261103 09:53 SHIQINGFENG.EX 周转分析渠道维度更换为渠道BU（D_TOV_CHAN→D_CHANNEL_BU），字段注释与段注释同步更新，未修改其它逻辑。
 * 上次修改：ALTER BY 20261102 20:30 SHIQINGFENG.EX 统一字段别名 AS 写法，CASE 按 WHEN/ELSE 同列、THEN 对齐 WHEN 末字母、条件续行 AND 对齐 WHEN 末字母分行，并对齐行尾注释列，未修改业务逻辑。
 *   ALTER BY 20261029 11:18 SHIQINGFENG.EX COMPANY_NAME改为通过F_TGK_GET_DIMNAME函数获取。
 *
 * 查询名称  ：应收占用管法差明细表
 * 源表      ：AW_MR9_ARPM02_000001、AW_MR9_ARPM03_000001、AW_RUL_ARPTOV_000001 等，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261103 09:53 SHIQINGFENG.EX 周转分析渠道维度更换为渠道BU（D_TOV_CHAN→D_CHANNEL_BU），字段注释与段注释同步更新，未修改其它逻辑。
 *   ALTER BY 20261102 20:30 SHIQINGFENG.EX 统一字段别名 AS 写法，CASE 按 WHEN/ELSE 同列、THEN 对齐 WHEN 末字母、条件续行 AND 对齐 WHEN 末字母分行，并对齐行尾注释列，未修改业务逻辑。
 *   ALTER BY 20261102 18:56 SHIQINGFENG.EX 按 SQL 编码规范统一右对齐：FROM/JOIN 组关键字右端对齐（CROSS JOIN 顶格）、OR/ON 右对齐、WHERE 嵌套条件分层、CASE 表达式 WHEN/THEN/ELSE/END 分行，未修改业务逻辑。
 *   ALTER BY 20261102 17:36 SHIQINGFENG.EX 统一查询说明文件头为查询名称+源表精简版式，未修改业务主体。
 *   ALTER BY 20261029 15:15 SHIQINGFENG.EX 排除法人口径、管理口径及调整金额全部为0的明细记录。
 *   ALTER BY 20261029 11:18 SHIQINGFENG.EX COMPANY_NAME改为通过F_TGK_GET_DIMNAME函数获取。
 *******************************************************************************/
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
/* DEST3????:?HIE=01取得大区描述，优先使用4级节点，4级为空时回退5级节点。 */
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
         , A.D_CHANNEL_BU AS TOV_CHANNEL_CODE
         , A.D_CC_CUSTGRP AS CC_CUST_GROUP_CODE
         , A.COD_VALUTA AS LOCAL_CURRENCY_CODE
         , CASE
             WHEN A.LE_AGE_FLAG IN ('AR', 'CA', 'A10')
               THEN NVL(A.BCY_0_AMT, 0)
             ELSE 0
           END AS LEGAL_AR_OCCUPATION_AMT
         , CASE
             WHEN H.COMPANY_CODE IS NOT NULL
               THEN NVL(A.UREB_AMT, 0)
             ELSE NVL(A.SPC_DSV_DED_AMT, 0)
           END AS OTHER_ADJ_AMT
         , CASE
             WHEN H.COMPANY_CODE IS NOT NULL
               THEN '日立返利'
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
             WHEN A.CUST_CODE LIKE 'XH%'
               THEN '应收账款-信汇'
             WHEN A.NATURE_L2_NAME = '货款-材料外协'
               THEN '货款-材料外协'
             WHEN A.GRP_SCOPE IN ('SUB-子公司', 'GIN-集团内')
               THEN A.GRP_SCOPE
             WHEN EXISTS (
                      SELECT 1
                        FROM SPECIAL_EXCLUDE_RULE R
                       WHERE R.COMPANY_CODE = TRIM(A.COMPANY_CODE)
              AND R.CUST_CODE = A.CUST_CODE
                    )
               THEN '特殊剔除'
             WHEN A.OTHER_ADJ_AMT <> 0
               THEN '其他调整项'
           END AS DIFF_REASON
      FROM M02_BASE A
      LEFT JOIN M03_AR_SUM M
        ON M.BUSINESS_UNIT_CODE = A.BUSINESS_UNIT_CODE
       AND M.COMPANY_CODE = A.COMPANY_CODE
       AND M.CUST_CODE = A.CUST_CODE
       AND M.PROFITCENTER_MATCH_CODE = A.PROFITCENTER_MATCH_CODE
)
/* 按需求字段顺序输出应收占用管法差明细。 */
SELECT A.COD_SCENARIO AS SCENARIO                                      /* 场景 */
     , A.COD_PERIODO AS PERIOD_CODE                                    /* 期间 */
     , A.BUSINESS_UNIT_CODE                                            /* 事业部编码 */
     , A.BUSINESS_UNIT_NAME                                            /* 事业部名称 */
     , A.COMPANY_CODE                                                  /* 公司编码 */
     , A.COMPANY_NAME                                                  /* 公司名称 */
     , A.LEGAL_AGE_CLASS                                               /* 法人口径账龄分类 */
     , A.MANAGE_AGE_CLASS                                              /* 管理口径账龄分类 */
     , A.CUST_CODE                                                     /* 客商编码 */
     , A.CUST_NAME                                                     /* 客商名称 */
     , A.CUST_HEAD_CODE                                                /* 主户编码 */
     , A.CUST_HEAD_NAME                                                /* 主户名称 */
     , A.CUST_BRANCH_CODE                                              /* 分户编码 */
     , A.CUST_BRANCH_NAME                                              /* 分户名称 */
     , A.GRP_SCOPE                                                     /* 集团归属范围 */
     , A.CP_COMPANY_CODE                                               /* 对方公司 */
     , A.COUNTRY_NAME                                                  /* 国家名称 */
     , A.NATURE_L2_NAME                                                /* 二级性质 */
     , C.CHANNEL_L1_CODE                                               /* 一级公司分类编码 */
     , C.CHANNEL_L1_NAME                                               /* 一级公司分类名称 */
     , C.CHANNEL_L2_CODE                                               /* 二级公司分类编码 */
     , C.CHANNEL_L2_NAME                                               /* 二级公司分类名称 */
     , C.CHANNEL_L3_CODE                                               /* 三级公司分类编码 */
     , F_TGK_GET_DIMNAME('D_CHANNEL', C.CHANNEL_L3_CODE) AS CHANNEL_L3_NAME  /* 三级公司分类名称 */
     , A.D_ONOFFLINE AS CHANNEL_GROUP_CODE                             /* 渠道分组编码 */
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', A.D_ONOFFLINE) AS CHANNEL_GROUP_NAME  /* 渠道分组名称 */
     , A.PROFITCENTER_CODE                                             /* 利润中心编码 */
     , F_TGK_GET_DIMNAME('DEST2', A.PROFITCENTER_CODE) AS PROFITCENTER_NAME  /* 利润中心名称 */
     , A.BUSINESS_RANGE_CODE                                           /* 业务范围编码 */
     , F_TGK_GET_DIMNAME('DEST3', A.BUSINESS_RANGE_CODE) AS BUSINESS_RANGE_NAME  /* 业务范围名称 */
     , A.SALE_DEPT_CODE                                                /* 业务管理单元编码 */
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', A.SALE_DEPT_CODE) AS SALE_DEPT_NAME  /* 业务管理单元名称 */
     , A.TOV_CHANNEL_CODE                                              /* 渠道BU编码 */
     , F_TGK_GET_DIMNAME('D_CHANNEL_BU', A.TOV_CHANNEL_CODE) AS TOV_CHANNEL_NAME  /* 渠道BU名称 */
     , A.CC_CUST_GROUP_CODE                                            /* 商冷客户群编码 */
     , F_TGK_GET_DIMNAME('D_CC_CUSTGRP', A.CC_CUST_GROUP_CODE) AS CC_CUST_GROUP_NAME  /* 商冷客户群名称 */
     , A.LOCAL_CURRENCY_CODE                                           /* 本位币币种 */
     , NVL(R.DESC_DEST3_ELEGER4, R.DESC_DEST3_ELEGER5) AS REGION_NAME  /* 业务范围区域名称 */
     , A.LEGAL_AR_OCCUPATION_AMT                                       /* 法人口径应收占用 */
     , A.MANAGE_AR_OCCUPATION_AMT                                      /* 管理口径应收占用 */
     , A.OTHER_ADJ_AMT                                                 /* 其他调整金额 */
     , A.MANAGE_AR_OCCUPATION_ADJ_AMT                                  /* 调整后管理口径应收占用 */
     , A.LEGAL_MANAGE_DIFF_AMT                                         /* 管法差金额 */
     , A.DIFF_REASON                                                   /* 差异原因 */
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
