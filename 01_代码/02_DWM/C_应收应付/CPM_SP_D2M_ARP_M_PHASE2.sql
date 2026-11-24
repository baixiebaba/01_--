CREATE OR REPLACE PROCEDURE CPM_SP_D2M_ARP_M_PHASE2(
    P_SCENARIO  IN VARCHAR2
  , P_PERIODO   IN VARCHAR2
  , P_AZIENDA   IN VARCHAR2
  , SESSION_USER IN VARCHAR2
) AS
  /*******************************************************************************
   *                              存储过程说明
   *-----------------------------------------------------------------------------
   * 最后更新时间：20261124 18:14
   * 本次修改：ALTER BY 20261124 18:14 SHIQINGFENG.EX 收入来源渠道分组、利润中心、业务范围、业务管理单元改按映射规则表取值。
   * 上次修改：ALTER BY 20261123 11:35 SHIQINGFENG.EX 锁定范围改为按SRC_DETAIL和LOCK_FLAG控制。
   *
   * 过程名称  ：CPM_SP_D2M_ARP_M_PHASE2
   * 功能描述  ：DWD->DWM往来账龄数据抽取
   * 源表      ：DWD_FI_MR_ARAP_SUM_MI、AW_MR9_REVM01_000001、AW_RUL_ARPPRC_000001、DIM_RULE_FI_MR_AR_PROFIT_MAPPING、DIM_RULE_FI_MR_AR_NF_MAPPING、DIM_RULE_FI_MR_AR_BUSRANGE_MAPPING、DIM_RULE_FI_MR_AR_COUNTRY_BUSRANGE_MAPPING、DIM_RULE_FI_MR_AR_BUSDEPT_MAPPING、DIM_RULE_FI_MR_BMU_TO_PROFITCENTER、DWD_FI_MR_SAP_KNA1_DD、DIM_CUSTOMER_BASE_INFO_DD、AW_MR9_ARPM01_000001（底稿调整数据自读）
   * 目标表    ：AW_MR9_ARPM01_000001
   *
   * 修改历史：
   *   ALTER BY 20261124 18:14 SHIQINGFENG.EX 收入来源渠道分组、利润中心、业务范围、业务管理单元改按映射规则表取值。
   *   ALTER BY 20261123 11:35 SHIQINGFENG.EX 锁定范围改为按SRC_DETAIL和LOCK_FLAG控制。
   *   ALTER BY 20261118 22:04 SHIQINGFENG.EX 利润中心映射改用AW_RUL_ARPPRC_000001应收周转利润中心映射表，并补充按公司兜底。
   *   ALTER BY 20261117 15:32 SHIQINGFENG.EX 取消公司2023本位币乘100补偿，币种小数位统一由DWD按TCURX还原。
   *   ALTER BY 20261117 11:35 SHIQINGFENG.EX 交易币去除尾随空格，修复同一币种被拆成多个分组
   *   ALTER BY 20261104 14:05 SHIQINGFENG.EX 调整副本SRC_DETAIL改按D_ADJ_TYPE映射
   *   ALTER BY 20261104 11:45 SHIQINGFENG.EX 新增底稿手工调整数据插行装载
   *   ALTER BY 20261102 15:49 SHIQINGFENG.EX 移除D_TOV_CHAN维度取数
   *   ALTER BY 20261102 15:00 SHIQINGFENG.EX 新增渠道BU维度D_CHANNEL_BU
   *   ALTER BY 20261030 18:24 ZHOUHONG.EX 收入取数排除类别GA00_PA_IN、GA00_PA_OUT（内部购销配对，金额正负互抵，不计收入）
   *   ALTER BY 20261029 18:10 SHIQINGFENG.EX 收入利润中心映射新增BATCH_ID=6（按公司+物料组），优先级BATCH_ID=2>6>收入原利润中心
   *   ALTER BY 20261028 19:31 SHIQINGFENG.EX 收入取数限定S600101%/S600102%
   *   ALTER BY 20261027 14:08 SHIQINGFENG.EX M01收入按BATCH_ID=2映射转为往来利润中心
   *   20261010 修正账龄标识对应科目映射、来源字段作用域及未命中时保留原科目
   *   20260924 汇率和税率处理由AG过程负责，D2M仅完成ARPM01来源装载及重分类标识回写
   *   20260923 修正日立公司GRP_SCOPE对方公司节点取数逻辑
   *   20260921 SHIQINGFENG.EX 新增重分类标识及集团归属范围更新
   *   20260920 SHIQINGFENG.EX 新增
   *******************************************************************************/
  V_SCENARIO      VARCHAR2(30);
  V_PERIODO       VARCHAR2(30);
  V_YEARMONTH     VARCHAR2(10);
  V_LAST_DAY      DATE;
  V_AZIENDA       VARCHAR2(4000);
  V_SESSION_ID    NUMBER;
  V_ERROR_COD     NUMBER;
  V_ERROR_MSG     VARCHAR2(4000);
BEGIN
  V_SESSION_ID := SYS_CONTEXT('USERENV', 'SESSIONID');

  /* 清理本会话参数公司，避免上次中断残留导致公司范围扩大。 */
  DELETE FROM SESSION_AZIENDA_LIST
   WHERE SESSION_ID = V_SESSION_ID;
  DELETE FROM SESSION_V_REF_AZIENDA
   WHERE SESSION_ID = V_SESSION_ID;

  INSERT INTO SESSION_V_REF_AZIENDA (SESSION_ID, HIE, NODE, ELEM)
  SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_AZIENDA;

  V_SCENARIO := P_SCENARIO;
  V_PERIODO := LPAD(P_PERIODO, 2, '0');

  V_YEARMONTH := SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO;
  V_LAST_DAY := LAST_DAY(TO_DATE(V_YEARMONTH || '01', 'YYYYMMDD'));

  /* LOCK_FLAG=N保留全部允许进数公司，LOCK_FLAG=Y再排除已锁定公司。
     ALTER BY 20261123 11:35 SHIQINGFENG.EX 锁定范围改为按SRC_DETAIL和LOCK_FLAG控制 */
  INSERT INTO SESSION_AZIENDA_LIST (SESSION_ID, HIE, NODE, ELEM, LOCK_FLAG)
  SELECT DISTINCT V_SESSION_ID AS SESSION_ID
       , A.HIE AS HIE
       , A.NODE AS NODE
       , A.ELEM AS ELEM
       , L.LOCK_FLAG AS LOCK_FLAG
    FROM SESSION_V_REF_AZIENDA A
   CROSS JOIN (
         SELECT 'N' AS LOCK_FLAG
           FROM DUAL
          UNION ALL
         SELECT 'Y' AS LOCK_FLAG
           FROM DUAL
   ) L
   WHERE A.HIE = '10'
     AND (
           INSTR(',' || P_AZIENDA || ',', ',' || A.ELEM || ',') > 0
        OR INSTR(',' || P_AZIENDA || ',', ',' || A.NODE || ',') > 0
        OR P_AZIENDA = 'ALL'
     )
     AND A.ELEM IN (
           SELECT COD_AZIENDA AS COD_AZIENDA
             FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
            WHERE ARP_FLAG = 'Y'
              AND VALID_FR <= V_YEARMONTH
              AND NVL(VALID_TO, '999999') >= V_YEARMONTH
              AND COD_CONTO = 'ZAW_D2M_IN'
     )
     AND (
           L.LOCK_FLAG = 'N'
        OR (
             L.LOCK_FLAG = 'Y'
             AND A.ELEM NOT IN (
                   SELECT T.COD_AZIENDA AS COD_AZIENDA
                     FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001 T
                    WHERE T.ARP_FLAG = 'Y'
                      AND T.COD_SCENARIO = V_SCENARIO
                      AND T.COD_PERIODO = V_PERIODO
                      AND T.COD_CONTO = 'ZAW_D2M_LOCK'
             )
        )
     );

  /* 本次运行的公司清单，写入日志便于按公司追溯。 */
  SELECT LISTAGG(ELEM, ',') WITHIN GROUP (ORDER BY ELEM)
    INTO V_AZIENDA
    FROM (
      SELECT DISTINCT ELEM AS ELEM
        FROM SESSION_AZIENDA_LIST
       WHERE SESSION_ID = V_SESSION_ID
         AND LOCK_FLAG = 'N'
    );

  INSERT INTO ZTAB_CPM_LOG (CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA)
  VALUES ('CPM_SP_D2M_ARP_M_PHASE2', 'BEGIN 开始执行', SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO, V_AZIENDA);
  COMMIT;

  /* 按SRC_DETAIL对应的LOCK_FLAG公司范围删除旧批次，保留已锁定来源。
     ALTER BY 20261123 11:35 SHIQINGFENG.EX 锁定范围改为按SRC_DETAIL和LOCK_FLAG控制 */
  DELETE FROM AW_MR9_ARPM01_000001 T
   WHERE T.COD_SCENARIO = V_SCENARIO
     AND T.COD_PERIODO = V_PERIODO
     AND EXISTS (
           SELECT 1 AS MATCH_FLAG
             FROM SESSION_AZIENDA_LIST S
            WHERE S.SESSION_ID = V_SESSION_ID
              AND S.ELEM = T.COD_AZIENDA
              AND S.LOCK_FLAG = CASE
                    WHEN T.SRC_DETAIL IN ('ORG_ZZT003', 'ORG_XH', 'ZTSO04_CK', 'ZTSO04_TH', 'ZZT003_ADJ') THEN 'Y'
                    ELSE 'N'
                  END
     )
     AND T.PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
     ;

  INSERT INTO ZTAB_CPM_LOG (CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA)
  VALUES ('CPM_SP_D2M_ARP_M_PHASE2', '当前批次删除完成', SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO, V_AZIENDA);
BEGIN
  /* 统一标准事实接口并写入目标表 */
  INSERT INTO AW_MR9_ARPM01_000001 (
      OID
    , COD_SCENARIO
    , COD_PERIODO
    , COD_AZIENDA
    , COD_CATEGORIA
    , SRC_DETAIL
    , CUST_CODE
    , CUST_NAME
    , CUST_HEAD_CODE
    , CUST_HEAD_NAME
    , CUST_BRANCH_CODE
    , CUST_BRANCH_NAME
    , COD_AZI_CTP
    , COUNTRY_CODE
    , COUNTRY_NAME
    , ACCT_SRC_CODE
    , ACCT_REC_CODE
    , ACCT_MAP_CODE
    , LE_AGE_FLAG
    , ME_AGE_FLAG
    , MB_AGE_FLAG
    , GRP_SCOPE
    , D_CHANNEL
    , D_CHANNEL_BU
    , D_CC_CUSTGRP
    , D_ONOFFLINE
    , COD_DEST2
    , COD_DEST3
    , D_SALE_DEPT
    , NATURE_L1_NAME
    , NATURE_L2_NAME
    , NATURE_L3_NAME
    , UFEE_UREB_FLAG
    , ECLS_FLAG
    , PAY_TERM_CODE
    , PAY_TERM_DESC
    , EXCHANGE_RATE_EVAL_FLAG
    , TAX_RATE
    , COD_VALUTA
    , COD_VALUTA_ORIGINARIA
    , BCY_0_AMT
    , BCY_1_AMT
    , BCY_2_AMT
    , BCY_3_AMT
    , BCY_4_AMT
    , BCY_5_AMT
    , BCY_6_AMT
    , BCY_7_AMT
    , BCY_8_AMT
    , BCY_9_AMT
    , BCY_10_AMT
    , BCY_11_AMT
    , BCY_12_AMT
    , BCY_13_AMT
    , BCY_14_AMT
    , BCY_15_AMT
    , QCY_0_AMT
    , QCY_1_AMT
    , QCY_2_AMT
    , QCY_3_AMT
    , QCY_4_AMT
    , QCY_5_AMT
    , QCY_6_AMT
    , QCY_7_AMT
    , QCY_8_AMT
    , QCY_9_AMT
    , QCY_10_AMT
    , QCY_11_AMT
    , QCY_12_AMT
    , QCY_13_AMT
    , QCY_14_AMT
    , QCY_15_AMT
    , SYSTEM_SRC
    , D_ADJ_TYPE
    , PROVENIENZA
    , DATEUPD
    , USERUPD
  )
  WITH
  /* 应收周转利润中心映射BATCH_ID=1：按公司映射周转利润中心。 */
  /* ALTER BY 20261118 22:07 SHIQINGFENG.EX 利润中心映射改用AW_RUL_ARPPRC_000001应收周转利润中心映射表，按批次号顺序排列。 */
  PROFIT_CENTER_RULE_1 AS (
    SELECT TRIM(COD_AZIENDA) AS COD_AZIENDA
         , MAX(COD_DEST2) AS PROFITCENTER_CODE
      FROM TGK_FIMA_HISENSE.AW_RUL_ARPPRC_000001
     WHERE TRIM(BATCH_ID) = '1'
       AND VALID_FR <= V_YEARMONTH
       AND NVL(VALID_TO, '999999') >= V_YEARMONTH
     GROUP BY TRIM(COD_AZIENDA)
  ),
  /* 应收周转利润中心映射BATCH_ID=2：按源利润中心映射周转利润中心，按源利润中心去前导零去重。 */
  /* ALTER BY 20261118 22:07 SHIQINGFENG.EX 规则CTE改名为PROFIT_CENTER_RULE_2，按批次号命名。 */
  /* ALTER BY 20261027 14:08 SHIQINGFENG.EX 收入利润中心按有效期及BATCH_ID=2映射为往来利润中心；按源利润中心去前导零去重。 */
  PROFIT_CENTER_RULE_2 AS (
    SELECT LTRIM(TRIM(SRC_PROFITCENTER_CODE), '0') AS SRC_PROFITCENTER_CODE
         , MAX(COD_DEST2) AS PROFITCENTER_CODE
      FROM TGK_FIMA_HISENSE.AW_RUL_ARPPRC_000001
     WHERE TRIM(BATCH_ID) = '2'
       AND VALID_FR <= V_YEARMONTH
       AND NVL(VALID_TO, '999999') >= V_YEARMONTH
     GROUP BY LTRIM(TRIM(SRC_PROFITCENTER_CODE), '0')
  ),
  /* ALTER BY 20261029 18:10 SHIQINGFENG.EX 新增BATCH_ID=6利润中心映射（按公司+物料组）。 */
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
       AND PM.VALID_FR <= V_YEARMONTH
       AND NVL(PM.VALID_TO, '999999') >= V_YEARMONTH
     GROUP BY A.COD_AZIENDA
            , TRIM(PM.MATERIAL_GROUP_CODE)
  ),
  /* 公司分类层级：按三级渠道反查一级、二级编码，收入来源未自带分类编码时使用。
     ALTER BY 20261124 18:14 SHIQINGFENG.EX 新增收入来源四字段映射规则 */
  CHANNEL_LEVEL_DIM AS (
    SELECT TRIM(COD) AS CHANNEL_L3_CODE
         , MAX(NULLIF(TRIM(COD_ELEGER5), '')) AS CHANNEL_L2_CODE
         , MAX(NULLIF(TRIM(COD_ELEGER6), '')) AS CHANNEL_L1_CODE
      FROM TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT
     WHERE COD_GERARCHIA = '01'
     GROUP BY TRIM(COD)
  ),
  /* 公司10架构：01020为商显公司，050为日立公司，用于业务范围特殊口径。 */
  COMPANY10_SCOPE AS (
    SELECT TRIM(ELEM) AS COMPANY_CODE
         , MAX(CASE WHEN TRIM(NODE) = '01020' THEN 'SX' ELSE 'RL' END) AS COMPANY_SCOPE
      FROM TGK_FIMA_HISENSE.V_REF_AZIENDA
     WHERE HIE = '10'
       AND TRIM(NODE) IN ('01020', '050')
     GROUP BY TRIM(ELEM)
  ),
  /* SAP客户主数据国家：收入客商多为SAP编码，按去前导零后的编码聚合。 */
  SAP_CUST_COUNTRY AS (
    SELECT NULLIF(LTRIM(TRIM(KUNNR), '0'), '') AS CUST_KEY
         , MAX(TRIM(LAND1)) AS COUNTRY_CODE
      FROM TGK_FIMA_HISENSE.DWD_FI_MR_SAP_KNA1_DD
     WHERE NVL(TRIM(LAND1), '#') <> '#'
     GROUP BY NULLIF(LTRIM(TRIM(KUNNR), '0'), '')
  ),
  /* MDG客商主数据国家：SAP客商未命中时兜底。 */
  MDG_CUST_COUNTRY AS (
    SELECT NULLIF(LTRIM(TRIM(CUST_CODE), '0'), '') AS CUST_KEY
         , MAX(TRIM(COUNTRY_CODE)) AS COUNTRY_CODE
      FROM TGK_FIMA_HISENSE.DIM_CUSTOMER_BASE_INFO_DD
     WHERE NVL(TRIM(COUNTRY_CODE), '#') <> '#'
     GROUP BY NULLIF(LTRIM(TRIM(CUST_CODE), '0'), '')
  ),
  /* 渠道分组映射规则：批次1公司+客商、2公司、3公司+三级分类、4公司+一级分类，公司编码按通配展开。 */
  NF_MAPPING_RULE AS (
    SELECT TRIM(A.BATCH_ID) AS BATCH_ID
         , TRIM(B.COD_AZIENDA) AS COMPANY_CODE
         , NULLIF(LTRIM(TRIM(A.CUST_CODE), '0'), '') AS CUST_CODE
         , NULLIF(TRIM(A.CHANNEL_L3_CODE), '') AS CHANNEL_L3_CODE
         , NULLIF(TRIM(A.CHANNEL_L1_CODE), '') AS CHANNEL_L1_CODE
         , MAX(TRIM(A.ONOFFLINE_CODE)) AS ONOFFLINE_CODE
      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_AR_NF_MAPPING A
      JOIN (SELECT DISTINCT COD_AZIENDA FROM TGK_FIMA_HISENSE.AZIENDA) B
        ON B.COD_AZIENDA LIKE TRIM(A.COMPANY_CODE)
     WHERE TRIM(A.BATCH_ID) IN ('1', '2', '3', '4')
       AND NVL(A.VALID_FR, '202401') <= V_YEARMONTH
       AND NVL(A.VALID_TO, '999999') >= V_YEARMONTH
     GROUP BY TRIM(A.BATCH_ID)
            , TRIM(B.COD_AZIENDA)
            , NULLIF(LTRIM(TRIM(A.CUST_CODE), '0'), '')
            , NULLIF(TRIM(A.CHANNEL_L3_CODE), '')
            , NULLIF(TRIM(A.CHANNEL_L1_CODE), '')
  ),
  /* 利润中心映射批次1：公司编码通配展开后按公司+渠道分组匹配。 */
  PROFIT_RULE_M1 AS (
    SELECT TRIM(B.COD_AZIENDA) AS COMPANY_CODE
         , NULLIF(TRIM(A.ONOFFLINE_CODE), '') AS ONOFFLINE_CODE
         , MAX(TRIM(A.PROFITCENTER_CODE)) AS PROFITCENTER_CODE
      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_AR_PROFIT_MAPPING A
      JOIN (SELECT DISTINCT COD_AZIENDA FROM TGK_FIMA_HISENSE.AZIENDA) B
        ON B.COD_AZIENDA LIKE TRIM(A.COMPANY_CODE)
     WHERE TRIM(A.BATCH_ID) = '1'
       AND NVL(A.VALID_FR, '202401') <= V_YEARMONTH
       AND NVL(A.VALID_TO, '999999') >= V_YEARMONTH
     GROUP BY TRIM(B.COD_AZIENDA)
            , NULLIF(TRIM(A.ONOFFLINE_CODE), '')
  ),
  /* 业务范围映射规则：批次1公司+二级分类、批次3公司，三级性质优先级取消。
     规则公司编码含通配符（如12%），先按公司主数据展开为实际公司，事实侧按公司等值匹配。 */
  BUSRANGE_RULE AS (
    SELECT TRIM(A.BATCH_ID) AS BATCH_ID
         , TRIM(B.COD_AZIENDA) AS COMPANY_CODE
         , NULLIF(TRIM(A.CHANNEL_L2_CODE), '') AS CHANNEL_L2_CODE
         , MAX(TRIM(A.BUS_RANGE_CODE)) AS BUS_RANGE_CODE
      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_AR_BUSRANGE_MAPPING A
      JOIN (SELECT DISTINCT COD_AZIENDA FROM TGK_FIMA_HISENSE.AZIENDA) B
        ON B.COD_AZIENDA LIKE TRIM(A.COMPANY_CODE)
     WHERE TRIM(A.BATCH_ID) IN ('1', '3')
       AND NVL(A.VALID_FR, '202401') <= V_YEARMONTH
       AND NVL(A.VALID_TO, '999999') >= V_YEARMONTH
     GROUP BY TRIM(A.BATCH_ID)
            , TRIM(B.COD_AZIENDA)
            , NULLIF(TRIM(A.CHANNEL_L2_CODE), '')
  ),
  /* 国家业务范围映射规则：日立公司非中国区按国家取值。 */
  COUNTRY_BUSRANGE_RULE AS (
    SELECT TRIM(COUNTRY_CODE) AS COUNTRY_CODE
         , MAX(TRIM(BUS_RANGE_CODE)) AS BUS_RANGE_CODE
      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_AR_COUNTRY_BUSRANGE_MAPPING
     WHERE NVL(VALID_FR, '202401') <= V_YEARMONTH
       AND NVL(VALID_TO, '999999') >= V_YEARMONTH
     GROUP BY TRIM(COUNTRY_CODE)
  ),
  /* 业务管理单元映射规则：批次1按系统号+利润中心。 */
  BUSDEPT_RULE AS (
    SELECT TRIM(SYSTEM_SRC) AS SYSTEM_SRC
         , NULLIF(LTRIM(TRIM(PROFITCENTER_CODE), '0'), '') AS PROFITCENTER_CODE
         , MAX(TRIM(MARKETING_DEPT_CODE)) AS MARKETING_DEPT_CODE
      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_AR_BUSDEPT_MAPPING
     WHERE TRIM(BATCH_ID) = '1'
       AND NVL(VALID_FR, '202401') <= V_YEARMONTH
       AND NVL(VALID_TO, '999999') >= V_YEARMONTH
     GROUP BY TRIM(SYSTEM_SRC)
            , NULLIF(LTRIM(TRIM(PROFITCENTER_CODE), '0'), '')
  ),
  /* 利润中心映射业务管理单元：限制专业公司口径，按利润中心取业务管理单元。 */
  BMU_RULE AS (
    SELECT NULLIF(LTRIM(TRIM(PROFITCENTER_CODE), '0'), '') AS PROFITCENTER_CODE
         , MAX(TRIM(BMU_CODE)) AS BMU_CODE
      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_BMU_TO_PROFITCENTER
     WHERE TRIM(DIM_FLAG) = '01'
     GROUP BY NULLIF(LTRIM(TRIM(PROFITCENTER_CODE), '0'), '')
  ),
  /* DWD普通账龄：读取源表并直接转换为目标事实接口 */
  DWD_STANDARD AS (
    SELECT V_SCENARIO AS COD_SCENARIO
         , V_PERIODO AS COD_PERIODO
         , COMPANY_CODE AS COD_AZIENDA
         , 'ZAMOUNT' AS COD_CATEGORIA
         , ODS_SRC AS SRC_DETAIL
         , CUST_CODE
         , CUST_NAME
         , CUST_HEAD_CODE
         , CUST_HEAD_NAME
         , CUST_BRANCH_CODE
         , CUST_BRANCH_NAME
         , CP_COMPANY_CODE AS COD_AZI_CTP
         , COUNTRY_CODE
         , COUNTRY_NAME
         , ACCT_SRC_CODE
         , CASE
               WHEN ACCT_SRC_CODE LIKE '1466%' THEN '1466000000'
               WHEN COMPANY_CODE IN ('6500', '6510')
                AND ACCT_SRC_CODE IN ('2241010100', '2241010200', '2241020000', '2241040000') THEN '2241010100'
               WHEN COMPANY_CODE IN ('6500', '6510')
                AND ACCT_SRC_CODE IN ('1221010000', '1221020000', '1221040000') THEN '1221010000'
               WHEN COMPANY_CODE IN ('1007', '1008', '1041')
                AND ACCT_SRC_CODE LIKE '2202%' THEN '2202000000'
               WHEN COMPANY_CODE LIKE '66%'
                AND COMPANY_CODE <> '6600'
                AND ACCT_SRC_CODE LIKE '1131%'
                AND ACCT_SRC_CODE <> '1131999001' THEN '1131002000'
               WHEN COMPANY_CODE LIKE '66%'
                AND COMPANY_CODE <> '6600'
                AND ACCT_SRC_CODE LIKE '1133%'
                AND ACCT_SRC_CODE <> '1133999001' THEN '1133001003'
               WHEN COMPANY_CODE LIKE '66%'
                AND COMPANY_CODE <> '6600'
                AND ACCT_SRC_CODE LIKE '2181%'
                AND ACCT_SRC_CODE <> '2181999001' THEN '2181001005'
               WHEN COMPANY_CODE LIKE '66%'
                AND COMPANY_CODE <> '6600'
                AND ACCT_SRC_CODE LIKE '2121%'
                AND ACCT_SRC_CODE <> '2121999001' THEN '2121001000'
               WHEN COMPANY_CODE IN ('6000','6000A','6000B','6000C', '6600')
                AND ACCT_SRC_CODE LIKE '1131%' THEN '1131002000'
               WHEN COMPANY_CODE IN ('6000','6000A','6000B','6000C', '6600')
                AND ACCT_SRC_CODE LIKE '1133%' THEN '1133001003'
               WHEN COMPANY_CODE IN ('6000','6000A','6000B','6000C', '6600')
                AND ACCT_SRC_CODE LIKE '2181%' THEN '2181001005'
               WHEN COMPANY_CODE IN ('6000','6000A','6000B','6000C', '6600')
                AND ACCT_SRC_CODE LIKE '2121%' THEN '2121001000'
               WHEN COMPANY_CODE LIKE '16%'
                AND COMPANY_CODE NOT LIKE '163%'
                AND COMPANY_CODE NOT LIKE '162%'
                AND ACCT_SRC_CODE IN ('2202000000', '2202000089') THEN '2202000000'
               ELSE ACCT_SRC_CODE
           END AS ACCT_REC_CODE
         , ACCT_MAP_CODE
         , NULL AS LE_AGE_FLAG
         , NULL AS ME_AGE_FLAG
         , NULL AS MB_AGE_FLAG
         , NULL AS GRP_SCOPE
         , CHANNEL_L3_CODE AS D_CHANNEL
         , CHANNEL_BU_CODE AS D_CHANNEL_BU
         , CC_CUST_GROUP_CODE AS D_CC_CUSTGRP
         , ONOFFLINE_CODE AS D_ONOFFLINE
         , PROFITCENTER_CODE AS COD_DEST2
         , BUS_RANGE_CODE AS COD_DEST3
         , MARKETING_DEPT_CODE AS D_SALE_DEPT
         , NATURE_L1_NAME
         , NATURE_L2_NAME
         , NATURE_L3_NAME
         , UFEE_UREB_FLAG
         , ECLS_FLAG
         , PAY_TERM_CODE
         , PAY_TERM_DESC
         , EXCHANGE_RATE_EVAL_FLAG
         , TAX_RATE
         , BCY_CODE AS COD_VALUTA
         /* 交易币为CHAR定长带尾随空格，不去空格同一币种会分成两组。
            ALTER BY 20261117 11:35 SHIQINGFENG.EX 交易币去除尾随空格，修复分组不聚合 */
         , TRIM(QCY_CODE) AS COD_VALUTA_ORIGINARIA
         , NVL(BCY_0_AMT, 0) AS BCY_0_AMT
         , NVL(BCY_1_AMT, 0) AS BCY_1_AMT
         , NVL(BCY_2_AMT, 0) AS BCY_2_AMT
         , NVL(BCY_3_AMT, 0) AS BCY_3_AMT
         , NVL(BCY_4_AMT, 0) AS BCY_4_AMT
         , NVL(BCY_5_AMT, 0) AS BCY_5_AMT
         , NVL(BCY_6_AMT, 0) AS BCY_6_AMT
         , NVL(BCY_7_AMT, 0) AS BCY_7_AMT
         , NVL(BCY_8_AMT, 0) AS BCY_8_AMT
         , NVL(BCY_9_AMT, 0) AS BCY_9_AMT
         , NVL(BCY_10_AMT, 0) AS BCY_10_AMT
         , NVL(BCY_11_AMT, 0) AS BCY_11_AMT
         , NVL(BCY_12_AMT, 0) AS BCY_12_AMT
         , NVL(BCY_13_AMT, 0) AS BCY_13_AMT
         , NVL(BCY_14_AMT, 0) AS BCY_14_AMT
         , NVL(BCY_15_AMT, 0) AS BCY_15_AMT
         , NVL(QCY_0_AMT, 0) AS QCY_0_AMT
         , NVL(QCY_1_AMT, 0) AS QCY_1_AMT
         , NVL(QCY_2_AMT, 0) AS QCY_2_AMT
         , NVL(QCY_3_AMT, 0) AS QCY_3_AMT
         , NVL(QCY_4_AMT, 0) AS QCY_4_AMT
         , NVL(QCY_5_AMT, 0) AS QCY_5_AMT
         , NVL(QCY_6_AMT, 0) AS QCY_6_AMT
         , NVL(QCY_7_AMT, 0) AS QCY_7_AMT
         , NVL(QCY_8_AMT, 0) AS QCY_8_AMT
         , NVL(QCY_9_AMT, 0) AS QCY_9_AMT
         , NVL(QCY_10_AMT, 0) AS QCY_10_AMT
         , NVL(QCY_11_AMT, 0) AS QCY_11_AMT
         , NVL(QCY_12_AMT, 0) AS QCY_12_AMT
         , NVL(QCY_13_AMT, 0) AS QCY_13_AMT
         , NVL(QCY_14_AMT, 0) AS QCY_14_AMT
         , NVL(QCY_15_AMT, 0) AS QCY_15_AMT
         , SYSTEM_SRC
         , 'ZZZZ' AS D_ADJ_TYPE
      FROM DWD_FI_MR_ARAP_SUM_MI
     WHERE DT_MONTH = V_YEARMONTH
       /* 限制需要进数范围的公司和客商，在D打标为Y或为空的 */
       AND NVL(IS_APAR_FLAG, 'Y') = 'Y'
       /* 锁定来源取LOCK_FLAG=Y公司，其余来源取LOCK_FLAG=N公司。
          ALTER BY 20261123 11:35 SHIQINGFENG.EX 锁定范围改为按SRC_DETAIL和LOCK_FLAG控制 */
       AND EXISTS (
             SELECT 1 AS MATCH_FLAG
               FROM SESSION_AZIENDA_LIST S
              WHERE S.SESSION_ID = V_SESSION_ID
                AND S.ELEM = COMPANY_CODE
                AND S.LOCK_FLAG = CASE
                      WHEN ODS_SRC IN ('ORG_ZZT003', 'ORG_XH') THEN 'Y'
                      ELSE 'N'
                    END
       )
  ),

  /* 收入明细基础行：补齐渠道分类层级、客商国家与公司架构范围，供四字段映射使用。 */
  /* ALTER BY 20261124 18:14 SHIQINGFENG.EX 收入来源四字段改按规则表映射，新增基础行CTE */
  M01_BASE AS (
    SELECT T.COD_AZIENDA
         , T.CUST_CODE
         , NULLIF(LTRIM(TRIM(T.CUST_CODE), '0'), '') AS CUST_KEY
         , T.CUST_NAME
         , T.COD_AZI_CTP
         , T.COD_CONTO
         , T.D_CHANNEL
         , T.D_CHANNEL_BU
         , T.COD_DEST2 AS SRC_COD_DEST2
         , T.COD_DEST3 AS SRC_COD_DEST3
         , T.D_SALE_DEPT AS SRC_D_SALE_DEPT
         , T.SRC_SYSTEM
         , T.MATERIAL_GROUP_CODE
         , T.COD_VALUTA
         , T.COD_VALUTA_ORIGINARIA
         , T.BCY_REV
         , T.ORG_REV
         , T.D_ADJ_TYPE
         , CL.CHANNEL_L1_CODE
         , CL.CHANNEL_L2_CODE
         , NVL(SC.COUNTRY_CODE, MC.COUNTRY_CODE) AS COUNTRY_CODE
         , CS.COMPANY_SCOPE
      FROM TGK_FIMA_HISENSE.AW_MR9_REVM01_000001 T
      LEFT JOIN CHANNEL_LEVEL_DIM CL
        ON CL.CHANNEL_L3_CODE = TRIM(T.D_CHANNEL)
      LEFT JOIN SAP_CUST_COUNTRY SC
        ON SC.CUST_KEY = NULLIF(LTRIM(TRIM(T.CUST_CODE), '0'), '')
      LEFT JOIN MDG_CUST_COUNTRY MC
        ON MC.CUST_KEY = NULLIF(LTRIM(TRIM(T.CUST_CODE), '0'), '')
      LEFT JOIN COMPANY10_SCOPE CS
        ON CS.COMPANY_CODE = T.COD_AZIENDA
     WHERE T.COD_SCENARIO = V_SCENARIO
       AND T.COD_PERIODO = V_PERIODO
       /* 出库未开、退货未办均为锁定来源，只取LOCK_FLAG=Y公司。
          ALTER BY 20261123 11:35 SHIQINGFENG.EX 锁定范围改为按SRC_DETAIL和LOCK_FLAG控制 */
       AND T.COD_AZIENDA IN (
             SELECT S.ELEM AS ELEM
               FROM SESSION_AZIENDA_LIST S
              WHERE S.SESSION_ID = V_SESSION_ID
                AND S.LOCK_FLAG = 'Y'
       )
       /* ALTER BY 20261028 19:31 SHIQINGFENG.EX 收入取数限定S600101%/S600102%，排除SRC_DETAIL含LM数据，ADJM01仅保留D_ADJ_TYPE=REV_01_201。 */
       AND (T.COD_CONTO LIKE 'S600101%' OR T.COD_CONTO LIKE 'S600102%')
       AND NVL(T.SRC_DETAIL, 'ZZZZ') NOT LIKE '%LM'
       AND (NVL(T.SRC_DETAIL, 'ZZZZ') <> 'ADJM01' OR T.D_ADJ_TYPE = 'REV_01_201')
       /* ALTER BY 20261030 18:24 ZHOUHONG.EX 收入取数排除类别GA00_PA_IN、GA00_PA_OUT（内部购销配对，金额正负互抵，不计收入）。 */
       AND NVL(T.COD_CATEGORIA, 'ZZZZ') NOT IN ('GA00_PA_IN', 'GA00_PA_OUT')
  ),
  /* 渠道分组映射：批次1→2→3→4顺序回退，全部未命中取默认零售-传统零售。 */
  M01_NF AS (
    SELECT B.*
         , NVL(NVL(NVL(F1.ONOFFLINE_CODE, F2.ONOFFLINE_CODE), NVL(F3.ONOFFLINE_CODE, F4.ONOFFLINE_CODE)), '020_OFF_002') AS D_ONOFFLINE
      FROM M01_BASE B
      LEFT JOIN NF_MAPPING_RULE F1
        ON F1.BATCH_ID = '1'
       AND F1.COMPANY_CODE = B.COD_AZIENDA
       AND F1.CUST_CODE = B.CUST_KEY
      LEFT JOIN NF_MAPPING_RULE F2
        ON F2.BATCH_ID = '2'
       AND F2.COMPANY_CODE = B.COD_AZIENDA
      LEFT JOIN NF_MAPPING_RULE F3
        ON F3.BATCH_ID = '3'
       AND F3.COMPANY_CODE = B.COD_AZIENDA
       AND F3.CHANNEL_L3_CODE = TRIM(B.D_CHANNEL)
      LEFT JOIN NF_MAPPING_RULE F4
        ON F4.BATCH_ID = '4'
       AND F4.COMPANY_CODE = B.COD_AZIENDA
       AND F4.CHANNEL_L1_CODE = B.CHANNEL_L1_CODE
  ),
  /* 利润中心映射：公司+渠道分组 → 按公司 → 按源利润中心 → 公司+物料组 → 原利润中心顺序回退。 */
  M01_PROFIT AS (
    SELECT N.*
         , NVL(NVL(P1.PROFITCENTER_CODE, R1.PROFITCENTER_CODE), NVL(R2.PROFITCENTER_CODE, NVL(P6.PROFITCENTER_CODE, N.SRC_COD_DEST2))) AS COD_DEST2
      FROM M01_NF N
      LEFT JOIN PROFIT_RULE_M1 P1
        ON P1.COMPANY_CODE = N.COD_AZIENDA
       AND P1.ONOFFLINE_CODE = N.D_ONOFFLINE
      LEFT JOIN PROFIT_CENTER_RULE_1 R1
        ON R1.COD_AZIENDA = N.COD_AZIENDA
      LEFT JOIN PROFIT_CENTER_RULE_2 R2
        ON R2.SRC_PROFITCENTER_CODE = LTRIM(TRIM(N.SRC_COD_DEST2), '0')
      LEFT JOIN PROFIT_CENTER_RULE_6 P6
        ON P6.COMPANY_CODE = N.COD_AZIENDA
       AND P6.MATERIAL_GROUP_CODE = TRIM(N.MATERIAL_GROUP_CODE)
  ),
  /* M01：出库未开、退货未办，BCY_REV写入本位币0/1桶，ORG_REV写入交易币0/1桶 */
  M01_FACT AS (
    SELECT V_SCENARIO AS COD_SCENARIO
         , V_PERIODO AS COD_PERIODO
         , M.COD_AZIENDA
         , 'ZAMOUNT' AS COD_CATEGORIA
         , CASE WHEN M.COD_CONTO LIKE 'S600101%' THEN 'ZTSO04_CK'
                WHEN M.COD_CONTO LIKE 'S600102%' THEN 'ZTSO04_TH'
           END AS SRC_DETAIL
         , M.CUST_CODE
         , M.CUST_NAME
         , M.CUST_CODE AS CUST_HEAD_CODE
         , M.CUST_NAME AS CUST_HEAD_NAME
         , NULL AS CUST_BRANCH_CODE
         , NULL AS CUST_BRANCH_NAME
         , M.COD_AZI_CTP
         , NULL AS COUNTRY_CODE
         , NULL AS COUNTRY_NAME
         , '1122000000' AS ACCT_SRC_CODE
         , '1122000000' AS ACCT_REC_CODE
         , '1122000000' AS ACCT_MAP_CODE
         , NULL AS LE_AGE_FLAG
         , NULL AS ME_AGE_FLAG
         , NULL AS MB_AGE_FLAG
         , NULL AS GRP_SCOPE
         , M.D_CHANNEL
         /* ALTER BY 20261102 15:00 SHIQINGFENG.EX 渠道BU跟D_CHANNEL一样从来源继承（M01是出库/退货，无周转渠道但有三类渠道）。 */
         , M.D_CHANNEL_BU
         , NULL AS D_CC_CUSTGRP
         , M.D_ONOFFLINE
         /* 业务范围分三档：商显按国家取中国区/海外公共，日立非中国区按国家映射表，其余按公司+二级分类再回退公司。
            ALTER BY 20261124 18:14 SHIQINGFENG.EX 渠道分组、利润中心、业务范围、业务管理单元改按规则表映射 */
         , M.COD_DEST2
         , CASE
               WHEN M.COMPANY_SCOPE = 'SX' AND UPPER(TRIM(M.COUNTRY_CODE)) = 'CN' THEN '2000'
               WHEN M.COMPANY_SCOPE = 'SX' THEN '3000'
               WHEN M.COMPANY_SCOPE = 'RL' AND UPPER(TRIM(M.COUNTRY_CODE)) = 'CN' THEN '2200'
               WHEN M.COMPANY_SCOPE = 'RL' THEN CR.BUS_RANGE_CODE
               ELSE NVL(NVL(BR1.BUS_RANGE_CODE, BR3.BUS_RANGE_CODE), M.SRC_COD_DEST3)
           END AS COD_DEST3
         , NVL(NVL(BD.MARKETING_DEPT_CODE, BM.BMU_CODE), M.SRC_D_SALE_DEPT) AS D_SALE_DEPT
         , NULL AS NATURE_L1_NAME
         , NULL AS NATURE_L2_NAME
         , NULL AS NATURE_L3_NAME
         , NULL AS UFEE_UREB_FLAG
         , NULL AS ECLS_FLAG
         , NULL AS PAY_TERM_CODE
         , NULL AS PAY_TERM_DESC
         , NULL AS EXCHANGE_RATE_EVAL_FLAG
         , NULL AS TAX_RATE
         , M.COD_VALUTA
         /* 底稿自读的历史行同样可能带尾随空格，一并TRIM。 */
         , TRIM(M.COD_VALUTA_ORIGINARIA) AS COD_VALUTA_ORIGINARIA
         , ROUND(0-M.BCY_REV,2) AS BCY_0_AMT
         , ROUND(0-M.BCY_REV,2) AS BCY_1_AMT
         , 0 AS BCY_2_AMT, 0 AS BCY_3_AMT, 0 AS BCY_4_AMT
         , 0 AS BCY_5_AMT, 0 AS BCY_6_AMT, 0 AS BCY_7_AMT
         , 0 AS BCY_8_AMT, 0 AS BCY_9_AMT, 0 AS BCY_10_AMT
         , 0 AS BCY_11_AMT, 0 AS BCY_12_AMT, 0 AS BCY_13_AMT
         , 0 AS BCY_14_AMT, 0 AS BCY_15_AMT
         , ROUND(0-M.ORG_REV,2) AS QCY_0_AMT
         , ROUND(0-M.ORG_REV,2) AS QCY_1_AMT
         , 0 AS QCY_2_AMT, 0 AS QCY_3_AMT, 0 AS QCY_4_AMT
         , 0 AS QCY_5_AMT, 0 AS QCY_6_AMT, 0 AS QCY_7_AMT
         , 0 AS QCY_8_AMT, 0 AS QCY_9_AMT, 0 AS QCY_10_AMT
         , 0 AS QCY_11_AMT, 0 AS QCY_12_AMT, 0 AS QCY_13_AMT
         , 0 AS QCY_14_AMT, 0 AS QCY_15_AMT
         , 'TA' AS SYSTEM_SRC
         , NVL(M.D_ADJ_TYPE, 'ZZZZ') AS D_ADJ_TYPE
      FROM M01_PROFIT M
      LEFT JOIN BUSRANGE_RULE BR1
        ON BR1.BATCH_ID = '1'
       AND BR1.COMPANY_CODE = M.COD_AZIENDA
       AND BR1.CHANNEL_L2_CODE = M.CHANNEL_L2_CODE
      LEFT JOIN BUSRANGE_RULE BR3
        ON BR3.BATCH_ID = '3'
       AND BR3.COMPANY_CODE = M.COD_AZIENDA
      LEFT JOIN COUNTRY_BUSRANGE_RULE CR
        ON CR.COUNTRY_CODE = M.COUNTRY_CODE
      /* 业务管理单元优先取营销部门映射，未命中回退利润中心映射的专业公司业务单元。 */
      LEFT JOIN BUSDEPT_RULE BD
        ON BD.SYSTEM_SRC = M.SRC_SYSTEM
       AND BD.PROFITCENTER_CODE = NULLIF(LTRIM(TRIM(M.COD_DEST2), '0'), '')
      LEFT JOIN BMU_RULE BM
        ON BM.PROFITCENTER_CODE = NULLIF(LTRIM(TRIM(M.COD_DEST2), '0'), '')
  ),
  AGG_FACT AS (
    SELECT COD_SCENARIO
         , COD_PERIODO
         , COD_AZIENDA
         , COD_CATEGORIA
         , SRC_DETAIL
         , CUST_CODE
         , CUST_NAME
         , CUST_HEAD_CODE
         , CUST_HEAD_NAME
         , CUST_BRANCH_CODE
         , CUST_BRANCH_NAME
         , COD_AZI_CTP
         , COUNTRY_CODE
         , COUNTRY_NAME
         , ACCT_SRC_CODE
         , ACCT_REC_CODE
         , ACCT_MAP_CODE
         , LE_AGE_FLAG
         , ME_AGE_FLAG
         , MB_AGE_FLAG
         , GRP_SCOPE
         , D_CHANNEL
         , D_CHANNEL_BU
         , D_CC_CUSTGRP
         , D_ONOFFLINE
         , COD_DEST2
         , COD_DEST3
         , D_SALE_DEPT
         , NATURE_L1_NAME
         , NATURE_L2_NAME
         , NATURE_L3_NAME
         , UFEE_UREB_FLAG
         , ECLS_FLAG
         , PAY_TERM_CODE
         , PAY_TERM_DESC
         , EXCHANGE_RATE_EVAL_FLAG
         , TAX_RATE
         , COD_VALUTA
         , COD_VALUTA_ORIGINARIA
         , SUM(BCY_0_AMT) AS BCY_0_AMT
         , SUM(BCY_1_AMT) AS BCY_1_AMT
         , SUM(BCY_2_AMT) AS BCY_2_AMT
         , SUM(BCY_3_AMT) AS BCY_3_AMT
         , SUM(BCY_4_AMT) AS BCY_4_AMT
         , SUM(BCY_5_AMT) AS BCY_5_AMT
         , SUM(BCY_6_AMT) AS BCY_6_AMT
         , SUM(BCY_7_AMT) AS BCY_7_AMT
         , SUM(BCY_8_AMT) AS BCY_8_AMT
         , SUM(BCY_9_AMT) AS BCY_9_AMT
         , SUM(BCY_10_AMT) AS BCY_10_AMT
         , SUM(BCY_11_AMT) AS BCY_11_AMT
         , SUM(BCY_12_AMT) AS BCY_12_AMT
         , SUM(BCY_13_AMT) AS BCY_13_AMT
         , SUM(BCY_14_AMT) AS BCY_14_AMT
         , SUM(BCY_15_AMT) AS BCY_15_AMT
         , SUM(QCY_0_AMT) AS QCY_0_AMT
         , SUM(QCY_1_AMT) AS QCY_1_AMT
         , SUM(QCY_2_AMT) AS QCY_2_AMT
         , SUM(QCY_3_AMT) AS QCY_3_AMT
         , SUM(QCY_4_AMT) AS QCY_4_AMT
         , SUM(QCY_5_AMT) AS QCY_5_AMT
         , SUM(QCY_6_AMT) AS QCY_6_AMT
         , SUM(QCY_7_AMT) AS QCY_7_AMT
         , SUM(QCY_8_AMT) AS QCY_8_AMT
         , SUM(QCY_9_AMT) AS QCY_9_AMT
         , SUM(QCY_10_AMT) AS QCY_10_AMT
         , SUM(QCY_11_AMT) AS QCY_11_AMT
         , SUM(QCY_12_AMT) AS QCY_12_AMT
         , SUM(QCY_13_AMT) AS QCY_13_AMT
         , SUM(QCY_14_AMT) AS QCY_14_AMT
         , SUM(QCY_15_AMT) AS QCY_15_AMT
         , SYSTEM_SRC
         , D_ADJ_TYPE
      FROM (
        SELECT * FROM DWD_STANDARD
        UNION ALL
        SELECT * FROM M01_FACT
      )
     GROUP BY COD_SCENARIO, COD_PERIODO, COD_AZIENDA, COD_CATEGORIA, SRC_DETAIL
            , CUST_CODE, CUST_NAME, CUST_HEAD_CODE, CUST_HEAD_NAME
            , CUST_BRANCH_CODE, CUST_BRANCH_NAME, COD_AZI_CTP, COUNTRY_CODE, COUNTRY_NAME
            , ACCT_SRC_CODE, ACCT_REC_CODE, ACCT_MAP_CODE
            , LE_AGE_FLAG, ME_AGE_FLAG, MB_AGE_FLAG, GRP_SCOPE
            , D_CHANNEL, D_CHANNEL_BU, D_CC_CUSTGRP, D_ONOFFLINE, COD_DEST2, COD_DEST3, D_SALE_DEPT
            , NATURE_L1_NAME, NATURE_L2_NAME, NATURE_L3_NAME
            , UFEE_UREB_FLAG, ECLS_FLAG, PAY_TERM_CODE, PAY_TERM_DESC
            , EXCHANGE_RATE_EVAL_FLAG, TAX_RATE
            , COD_VALUTA, COD_VALUTA_ORIGINARIA, SYSTEM_SRC, D_ADJ_TYPE
  )
  SELECT NEWID() AS OID
       , COD_SCENARIO
       , COD_PERIODO
       , COD_AZIENDA
       , COD_CATEGORIA
       , SRC_DETAIL
       , CUST_CODE
       , CUST_NAME
       , CUST_HEAD_CODE
       , CUST_HEAD_NAME
       , CUST_BRANCH_CODE
       , CUST_BRANCH_NAME
       , COD_AZI_CTP
       , COUNTRY_CODE
       , COUNTRY_NAME
       , ACCT_SRC_CODE
       , ACCT_REC_CODE
       , ACCT_MAP_CODE
       , LE_AGE_FLAG
       , ME_AGE_FLAG
       , MB_AGE_FLAG
       , GRP_SCOPE
       , D_CHANNEL
       , D_CHANNEL_BU
       , D_CC_CUSTGRP
       , D_ONOFFLINE
       , COD_DEST2
       , COD_DEST3
       , D_SALE_DEPT
       , NATURE_L1_NAME
       , NATURE_L2_NAME
       , NATURE_L3_NAME
       , UFEE_UREB_FLAG
       , ECLS_FLAG
       , PAY_TERM_CODE
       , PAY_TERM_DESC
       , EXCHANGE_RATE_EVAL_FLAG
       , TAX_RATE
       , COD_VALUTA
       , COD_VALUTA_ORIGINARIA
       , BCY_0_AMT
       , BCY_1_AMT
       , BCY_2_AMT
       , BCY_3_AMT
       , BCY_4_AMT
       , BCY_5_AMT
       , BCY_6_AMT
       , BCY_7_AMT
       , BCY_8_AMT
       , BCY_9_AMT
       , BCY_10_AMT
       , BCY_11_AMT
       , BCY_12_AMT
       , BCY_13_AMT
       , BCY_14_AMT
       , BCY_15_AMT
       , QCY_0_AMT
       , QCY_1_AMT
       , QCY_2_AMT
       , QCY_3_AMT
       , QCY_4_AMT
       , QCY_5_AMT
       , QCY_6_AMT
       , QCY_7_AMT
       , QCY_8_AMT
       , QCY_9_AMT
       , QCY_10_AMT
       , QCY_11_AMT
       , QCY_12_AMT
       , QCY_13_AMT
       , QCY_14_AMT
       , QCY_15_AMT
       , SYSTEM_SRC
       , D_ADJ_TYPE
       , 'CPM_SP_D2M_ARP_M_PHASE2' AS PROVENIENZA
       , SYSDATE AS DATEUPD
       , SESSION_USER AS USERUPD
    FROM AGG_FACT;
END;


  /* 更新重分类标识及集团归属范围：按账套+公司+有效客商开窗（管理分公司加利润中心），
     科目由ACCT_SRC_CODE传入重分类函数，有主户时优先主户编码。 */
BEGIN
  MERGE INTO AW_MR9_ARPM01_000001 T
  USING (
    WITH TARGET_FACT AS (
    SELECT *
      FROM
        (
          SELECT A.OID
              , A.COD_SCENARIO
              , A.COD_PERIODO
              , A.COD_AZIENDA
              , A.COD_CATEGORIA
              , A.SRC_DETAIL
              , A.CUST_CODE
              , A.CUST_NAME
              , A.CUST_HEAD_CODE
              , A.CUST_HEAD_NAME
              , A.CUST_BRANCH_CODE
              , A.CUST_BRANCH_NAME
              , A.CUST_HEAD_CODE AS CUST_KEY
              , A.COD_AZI_CTP
              , A.COUNTRY_CODE
              , A.COUNTRY_NAME
              , A.ACCT_SRC_CODE
              , A.ACCT_REC_CODE
              , A.ACCT_MAP_CODE
              , A.D_CHANNEL
              , A.D_ONOFFLINE
              , A.COD_DEST2
              , A.COD_DEST3
              , A.D_SALE_DEPT
              , A.NATURE_L1_NAME
              , A.NATURE_L2_NAME
              , A.NATURE_L3_NAME
              , A.UFEE_UREB_FLAG
              , A.ECLS_FLAG
              , A.PAY_TERM_CODE
              , A.PAY_TERM_DESC
              , A.EXCHANGE_RATE_EVAL_FLAG
              , A.TAX_RATE
              , A.COD_VALUTA
              , A.COD_VALUTA_ORIGINARIA
              , A.SYSTEM_SRC
              , A.D_ADJ_TYPE
              , A.PROVENIENZA
              , AZ.CITTA_LEGALE AS MANDT
              , NVL(A.BCY_0_AMT, 0) AS BCY_0_AMT
              , SUM(
                    CASE WHEN A.SRC_DETAIL LIKE 'ORG%'
                            THEN NVL(A.BCY_0_AMT, 0)
                          ELSE 0
                    END
                  ) OVER (
                    PARTITION BY  CASE WHEN A.COD_AZIENDA IN ('6000', '6000A', '6000B', '6000C', '6600')
                                            AND A.ACCT_REC_CODE IN ('1131002000', '1133001003', '2181001005', '2121001000')
                                        THEN '6000'
                                        ELSE A.COD_AZIENDA
                                  END
                                , A.CUST_HEAD_CODE
                                , A.ACCT_REC_CODE
                  ) AS LE_BCY_AMT
              , SUM(
                    CASE WHEN A.SRC_DETAIL LIKE 'ORG%'
                                OR A.SRC_DETAIL LIKE 'ZTSO04%'
                          THEN NVL(A.BCY_0_AMT, 0)
                          ELSE 0
                    END
                  ) OVER (
                    PARTITION BY  CASE WHEN A.COD_AZIENDA IN ('6000', '6000A', '6000B', '6000C', '6600')
                                            AND A.ACCT_REC_CODE IN ('1131002000', '1133001003', '2181001005', '2121001000')
                                        THEN '6000'
                                        ELSE A.COD_AZIENDA
                                  END
                                , A.CUST_HEAD_CODE
                                , A.ACCT_REC_CODE
                  ) AS ME_BCY_AMT
              , SUM(
                    CASE WHEN A.SRC_DETAIL LIKE 'ORG%'
                                OR A.SRC_DETAIL LIKE 'ZTSO04%'
                          THEN NVL(A.BCY_0_AMT, 0)
                          ELSE 0
                    END
                  ) OVER (
                    PARTITION BY  CASE WHEN A.COD_AZIENDA IN ('6000', '6000A', '6000B', '6000C', '6600')
                                            AND A.ACCT_REC_CODE IN ('1131002000', '1133001003', '2181001005', '2121001000')
                                        THEN '6000'
                                        ELSE A.COD_AZIENDA
                                  END
                                , A.CUST_HEAD_CODE
                                , A.COD_DEST2
                                , A.ACCT_REC_CODE
                  ) AS MB_BCY_AMT
            FROM AW_MR9_ARPM01_000001 A
            LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
              ON A.COD_AZIENDA = AZ.COD_AZIENDA
           WHERE A.COD_SCENARIO = V_SCENARIO
             AND A.COD_PERIODO = V_PERIODO
             /* 重分类按SRC_DETAIL选择LOCK_FLAG公司范围。
                ALTER BY 20261123 11:35 SHIQINGFENG.EX 锁定范围改为按SRC_DETAIL和LOCK_FLAG控制 */
             AND (
                   EXISTS (
                     SELECT 1 AS MATCH_FLAG
                       FROM SESSION_AZIENDA_LIST S
                      WHERE S.SESSION_ID = V_SESSION_ID
                        AND S.ELEM = A.COD_AZIENDA
                        AND S.LOCK_FLAG = CASE
                              WHEN A.SRC_DETAIL IN ('ORG_ZZT003', 'ORG_XH', 'ZTSO04_CK', 'ZTSO04_TH', 'ZZT003_ADJ') THEN 'Y'
                              ELSE 'N'
                            END
                   )
                OR (
                     /* 6000/6000A/6000B/6000C/6600 合并重分类 */
                     A.COD_AZIENDA IN ('6000', '6000A', '6000B', '6000C', '6600')
                     AND EXISTS (
                           SELECT 1 AS MATCH_FLAG
                             FROM SESSION_AZIENDA_LIST S
                            WHERE S.SESSION_ID = V_SESSION_ID
                              AND S.ELEM IN ('6000', '6000A', '6000B', '6000C', '6600')
                              AND S.LOCK_FLAG = CASE
                                    WHEN A.SRC_DETAIL IN ('ORG_ZZT003', 'ORG_XH', 'ZTSO04_CK', 'ZTSO04_TH', 'ZZT003_ADJ') THEN 'Y'
                                    ELSE 'N'
                                  END
                     )
                )
             )
             AND A.PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
             AND (A.SRC_DETAIL LIKE 'ORG%'
                   OR A.SRC_DETAIL LIKE 'ZTSO04%'
                 )
        ) AA
         WHERE AA.COD_AZIENDA IN (
                   SELECT S.ELEM AS ELEM
                     FROM SESSION_AZIENDA_LIST S
                    WHERE S.SESSION_ID = V_SESSION_ID
                      AND S.LOCK_FLAG = CASE
                            WHEN AA.SRC_DETAIL IN ('ORG_ZZT003', 'ORG_XH', 'ZTSO04_CK', 'ZTSO04_TH', 'ZZT003_ADJ') THEN 'Y'
                            ELSE 'N'
                          END
         )
    ),
    REC_FLAG_FACT AS (
      SELECT F.*
           , CASE WHEN F.SRC_DETAIL LIKE '%XH%'
                    THEN 'N'
                  WHEN F.SRC_DETAIL LIKE 'ORG%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_REC_CODE
                      , F.CUST_KEY
                      , F.LE_BCY_AMT
                      , '1'
                    )
                  END AS IS_REC_LG
           , CASE WHEN F.SRC_DETAIL LIKE '%XH%' AND F.ACCT_SRC_CODE = '1122000095'
                    THEN 'AR'
                  WHEN F.SRC_DETAIL LIKE '%XH%' AND F.ACCT_SRC_CODE = '2202000095'
                    THEN 'AP'
                  WHEN F.SRC_DETAIL LIKE 'ORG%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_REC_CODE
                      , F.CUST_KEY
                      , F.LE_BCY_AMT
                      , '2'
                    )
                  END AS LE_AGE_FLAG
           , CASE WHEN F.SRC_DETAIL LIKE '%XH%'
                    THEN 'N'
                  WHEN F.SRC_DETAIL LIKE 'ORG%'
                         OR F.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_REC_CODE
                      , F.CUST_KEY
                      , F.ME_BCY_AMT
                      , '1'
                    )
                  END AS IS_REC_ME
           , CASE WHEN F.SRC_DETAIL LIKE '%XH%' AND F.ACCT_SRC_CODE = '1122000095'
                    THEN 'AR'
                  WHEN F.SRC_DETAIL LIKE '%XH%' AND F.ACCT_SRC_CODE = '2202000095'
                    THEN 'AP'
                  WHEN F.SRC_DETAIL LIKE 'ORG%'
                        OR F.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_REC_CODE
                      , F.CUST_KEY
                      , F.ME_BCY_AMT
                      , '2'
                    )
                  END AS ME_AGE_FLAG
           , CASE WHEN F.SRC_DETAIL LIKE '%XH%'
                    THEN 'N'
                  WHEN F.SRC_DETAIL LIKE 'ORG%'
                        OR F.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_REC_CODE
                      , F.CUST_KEY
                      , F.MB_BCY_AMT
                      , '1'
                    )
                  END AS IS_REC_MB
           , CASE WHEN F.SRC_DETAIL LIKE '%XH%' AND F.ACCT_SRC_CODE = '1122000095'
                    THEN 'AR'
                  WHEN F.SRC_DETAIL LIKE '%XH%' AND F.ACCT_SRC_CODE = '2202000095'
                    THEN 'AP'
                  WHEN F.SRC_DETAIL LIKE 'ORG%'
                        OR F.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_REC_CODE
                      , F.CUST_KEY
                      , F.MB_BCY_AMT
                      , '2'
                    )
                  END AS MB_AGE_FLAG
        FROM TARGET_FACT F
    ),
    NODE_MAP AS (
      SELECT N.COD_SCENARIO
           , N.COD_PERIODO
           , N.ELEM
           , N.NODE
           , N.NODES
           , CASE WHEN H.ELEM IS NOT NULL THEN 1 ELSE 0 END AS IS_HITACHI
           , CASE WHEN H.ELEM IS NOT NULL THEN NVL(N.NODES, N.NODE)
                  ELSE N.NODE
             END AS SELF_NODE
           , N.HQ
        FROM TGK_GB_HISENSE.V_APAR_ELEM_NODE_TAB N
        LEFT JOIN (
          SELECT DISTINCT R.ELEM
            FROM TGK_GB_HISENSE.V_REF_AZIENDA_TV R
           WHERE R.COD_SCENARIO = V_SCENARIO
             AND R.COD_PERIODO = V_PERIODO
             AND R.HIE = '30'
             AND R.NODE = '1730'
        ) H
          ON H.ELEM = N.ELEM
       WHERE N.COD_SCENARIO = V_SCENARIO
         AND N.COD_PERIODO = V_PERIODO
    )
    /* 以下维度、金额和节点字段仅用于查询展示，不参与OID关联；日立公司对方节点优先NODES，为空回退NODE。 */
    SELECT F.OID
         , F.COD_SCENARIO
         , F.COD_PERIODO
         , F.COD_AZIENDA
         , F.COD_CATEGORIA
         , F.SRC_DETAIL
         , F.CUST_CODE
         , F.CUST_NAME
         , F.CUST_HEAD_CODE
         , F.CUST_HEAD_NAME
         , F.CUST_BRANCH_CODE
         , F.CUST_BRANCH_NAME
         , F.CUST_KEY
         , F.COD_AZI_CTP
         , F.COUNTRY_CODE
         , F.COUNTRY_NAME
         , F.ACCT_SRC_CODE
         , F.ACCT_REC_CODE
         , F.ACCT_MAP_CODE
         , F.D_CHANNEL
         , F.D_ONOFFLINE
         , F.COD_DEST2
         , F.COD_DEST3
         , F.D_SALE_DEPT
         , F.NATURE_L1_NAME
         , F.NATURE_L2_NAME
         , F.NATURE_L3_NAME
         , F.UFEE_UREB_FLAG
         , F.ECLS_FLAG
         , F.PAY_TERM_CODE
         , F.PAY_TERM_DESC
         , F.EXCHANGE_RATE_EVAL_FLAG
         , F.TAX_RATE
         , F.COD_VALUTA
         , F.COD_VALUTA_ORIGINARIA
         , F.SYSTEM_SRC
         , F.MANDT
         , F.D_ADJ_TYPE
         , F.PROVENIENZA
         , F.BCY_0_AMT
         , F.LE_BCY_AMT
         , F.ME_BCY_AMT
         , F.MB_BCY_AMT
         , C.SELF_NODE AS CUR_NODE
         , C.HQ AS CUR_HQ
         , CASE WHEN C.IS_HITACHI = 1 THEN NVL(P.NODES, P.NODE)
                ELSE P.NODE
           END AS CTP_NODE
         , P.HQ AS CTP_HQ
         , F.LE_AGE_FLAG
         , F.IS_REC_LG
         , F.ME_AGE_FLAG
         , F.IS_REC_ME
         , F.MB_AGE_FLAG
         , F.IS_REC_MB
         , CASE
               WHEN C.SELF_NODE = CASE WHEN C.IS_HITACHI = 1 THEN NVL(P.NODES, P.NODE)
                                       ELSE P.NODE
                                  END
                AND C.HQ = P.HQ THEN 'SUB-子公司'
               WHEN C.HQ = P.HQ THEN 'GIN-集团内'
               ELSE 'GEX-集团外'
           END AS GRP_SCOPE
      FROM REC_FLAG_FACT F
      LEFT JOIN NODE_MAP C
        ON C.COD_SCENARIO = F.COD_SCENARIO
       AND C.COD_PERIODO = F.COD_PERIODO
       AND C.ELEM = F.COD_AZIENDA
      LEFT JOIN NODE_MAP P
        ON P.COD_SCENARIO = F.COD_SCENARIO
       AND P.COD_PERIODO = F.COD_PERIODO
       AND P.ELEM = F.COD_AZI_CTP
  ) S
     ON (T.OID = S.OID)
   WHEN MATCHED THEN UPDATE SET
         T.COD_CONTO = CASE
                                 WHEN S.LE_AGE_FLAG = 'AR' THEN '1122000000'
                                 WHEN S.LE_AGE_FLAG = 'OR' THEN '122101F'
                                 WHEN S.LE_AGE_FLAG = 'AS' THEN '1123000000'
                                 WHEN S.LE_AGE_FLAG = 'CA' THEN '1460000000'
                                 WHEN S.LE_AGE_FLAG = 'RF' THEN '1124001000'
                                 WHEN S.LE_AGE_FLAG = 'AP' THEN '2202000000'
                                 WHEN S.LE_AGE_FLAG = 'OP' THEN '224199F'
                                 WHEN S.LE_AGE_FLAG = 'AC' THEN '2203000000'
                                 WHEN S.LE_AGE_FLAG = 'CL' THEN '2204000000'
                                 WHEN S.LE_AGE_FLAG = 'A9' THEN '1910000A70'
                                 WHEN S.LE_AGE_FLAG = 'A10' THEN '1531000000'
                             END
       , T.LE_AGE_FLAG = S.LE_AGE_FLAG
       , T.IS_REC_LG = S.IS_REC_LG
       , T.ME_AGE_FLAG = S.ME_AGE_FLAG
       , T.IS_REC_ME = S.IS_REC_ME
       , T.MB_AGE_FLAG = S.MB_AGE_FLAG
       , T.IS_REC_MB = S.IS_REC_MB
       , T.GRP_SCOPE = S.GRP_SCOPE
       , T.DATEUPD = SYSDATE
       , T.USERUPD = SESSION_USER;
END;

  /* 非ORG来源且科目为空的记录回写默认应收科目，按来源选择LOCK_FLAG公司。
     ALTER BY 20261123 11:35 SHIQINGFENG.EX 锁定范围改为按SRC_DETAIL和LOCK_FLAG控制 */
BEGIN
  UPDATE AW_MR9_ARPM01_000001 T
     SET COD_CONTO = '1122000000'
   WHERE T.COD_SCENARIO = V_SCENARIO
     AND T.COD_PERIODO = V_PERIODO
     AND EXISTS (
           SELECT 1 AS MATCH_FLAG
             FROM SESSION_AZIENDA_LIST S
            WHERE S.SESSION_ID = V_SESSION_ID
              AND S.ELEM = T.COD_AZIENDA
              AND S.LOCK_FLAG = CASE
                    WHEN T.SRC_DETAIL IN ('ORG_ZZT003', 'ORG_XH', 'ZTSO04_CK', 'ZTSO04_TH', 'ZZT003_ADJ') THEN 'Y'
                    ELSE 'N'
                  END
     )
     AND T.PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
     AND T.SRC_DETAIL NOT LIKE 'ORG%'
     AND T.COD_CONTO IS NULL;
END;
  /* 手工调整数据复制为调整副本：SRC_DETAIL按D_ADJ_TYPE映射，客商分户优先回退主户，插行不走重分类、随下轮批清理。
     ALTER BY 20261104 11:45 SHIQINGFENG.EX 新增底稿手工调整数据插行装载
     ALTER BY 20261104 14:05 SHIQINGFENG.EX 副本SRC_DETAIL改按D_ADJ_TYPE映射 */
BEGIN
  INSERT INTO AW_MR9_ARPM01_000001 (
      OID
    , COD_SCENARIO
    , COD_PERIODO
    , COD_AZIENDA
    , COD_CATEGORIA
    , SRC_DETAIL
    , CUST_CODE
    , CUST_NAME
    , CUST_HEAD_CODE
    , CUST_HEAD_NAME
    , CUST_BRANCH_CODE
    , CUST_BRANCH_NAME
    , COD_AZI_CTP
    , COUNTRY_CODE
    , COUNTRY_NAME
    , ACCT_SRC_CODE
    , ACCT_REC_CODE
    , ACCT_MAP_CODE
    , LE_AGE_FLAG
    , ME_AGE_FLAG
    , MB_AGE_FLAG
    , GRP_SCOPE
    , D_CHANNEL
    , D_CHANNEL_BU
    , D_CC_CUSTGRP
    , D_ONOFFLINE
    , COD_DEST2
    , COD_DEST3
    , D_SALE_DEPT
    , NATURE_L1_NAME
    , NATURE_L2_NAME
    , NATURE_L3_NAME
    , UFEE_UREB_FLAG
    , ECLS_FLAG
    , PAY_TERM_CODE
    , PAY_TERM_DESC
    , EXCHANGE_RATE_EVAL_FLAG
    , TAX_RATE
    , COD_VALUTA
    , COD_VALUTA_ORIGINARIA
    , BCY_0_AMT
    , BCY_1_AMT
    , BCY_2_AMT
    , BCY_3_AMT
    , BCY_4_AMT
    , BCY_5_AMT
    , BCY_6_AMT
    , BCY_7_AMT
    , BCY_8_AMT
    , BCY_9_AMT
    , BCY_10_AMT
    , BCY_11_AMT
    , BCY_12_AMT
    , BCY_13_AMT
    , BCY_14_AMT
    , BCY_15_AMT
    , QCY_0_AMT
    , QCY_1_AMT
    , QCY_2_AMT
    , QCY_3_AMT
    , QCY_4_AMT
    , QCY_5_AMT
    , QCY_6_AMT
    , QCY_7_AMT
    , QCY_8_AMT
    , QCY_9_AMT
    , QCY_10_AMT
    , QCY_11_AMT
    , QCY_12_AMT
    , QCY_13_AMT
    , QCY_14_AMT
    , QCY_15_AMT
    , SYSTEM_SRC
    , D_ADJ_TYPE
    , COD_CONTO
    , PROVENIENZA
    , DATEUPD
    , USERUPD
  )
  SELECT NEWID() AS OID
       , A.COD_SCENARIO
       , A.COD_PERIODO
       , A.COD_AZIENDA
       , 'ZAMOUNT' AS COD_CATEGORIA
       , CASE A.D_ADJ_TYPE
           WHEN 'ARP_01_001' THEN 'OVERDUE_ADJ'
           WHEN 'ARP_01_002' THEN 'EPAY_ADJ'
           WHEN 'ARP_01_003' THEN 'UFEE_ADJ'
           WHEN 'ARP_01_004' THEN 'UREB_ADJ'
           WHEN 'ARP_03_003' THEN 'INV_SAMPLE_ADJ'
           WHEN 'ARP_01_000' THEN 'ZZT003_ADJ'
         END AS SRC_DETAIL
       , NVL(NULLIF(LTRIM(A.CUST_BRANCH_CODE,0), ''), LTRIM(A.CUST_HEAD_CODE,0)) AS CUST_CODE
       , NVL(NULLIF(LTRIM(A.CUST_BRANCH_NAME,0), ''), LTRIM(A.CUST_HEAD_NAME,0)) AS CUST_NAME
       , LTRIM(A.CUST_HEAD_CODE,0)
       , LTRIM(A.CUST_HEAD_NAME,0)
       , A.CUST_BRANCH_CODE
       , A.CUST_BRANCH_NAME
       , A.COD_AZI_CTP
       , NULL AS COUNTRY_CODE
       , NULL AS COUNTRY_NAME
       , NULL AS ACCT_SRC_CODE
       , NULL AS ACCT_REC_CODE
       , NULL AS ACCT_MAP_CODE
       , NULL AS LE_AGE_FLAG
       , NULL AS ME_AGE_FLAG
       , NULL AS MB_AGE_FLAG
       , A.GRP_SCOPE
       , A.D_CHANNEL
       , A.D_CHANNEL_BU
       , A.D_CC_CUSTGRP
       , A.D_ONOFFLINE
       , A.COD_DEST2
       , A.COD_DEST3
       , A.D_SALE_DEPT
       , A.NATURE_L1_NAME AS NATURE_L1_NAME
       , A.NATURE_L2_NAME AS NATURE_L2_NAME
       , A.NATURE_L3_NAME AS NATURE_L3_NAME
       , CASE WHEN D_ADJ_TYPE = 'ARP_01_003'
                THEN 'UFEE_ADJ'
              WHEN D_ADJ_TYPE = 'ARP_01_004'
                THEN 'UREB_ADJ'
         END AS UFEE_UREB_FLAG
       , NULL AS ECLS_FLAG
       , NULL AS PAY_TERM_CODE
       , NULL AS PAY_TERM_DESC
       , NULL AS EXCHANGE_RATE_EVAL_FLAG
       , NULL AS TAX_RATE
       , A.COD_VALUTA
       , A.COD_VALUTA_ORIGINARIA
       , A.BCY_0_AMT
       , A.BCY_1_AMT
       , A.BCY_2_AMT
       , A.BCY_3_AMT
       , A.BCY_4_AMT
       , A.BCY_5_AMT
       , A.BCY_6_AMT
       , A.BCY_7_AMT
       , A.BCY_8_AMT
       , A.BCY_9_AMT
       , A.BCY_10_AMT
       , A.BCY_11_AMT
       , A.BCY_12_AMT
       , A.BCY_13_AMT
       , A.BCY_14_AMT
       , A.BCY_15_AMT
       , A.QCY_0_AMT
       , A.QCY_1_AMT
       , A.QCY_2_AMT
       , A.QCY_3_AMT
       , A.QCY_4_AMT
       , A.QCY_5_AMT
       , A.QCY_6_AMT
       , A.QCY_7_AMT
       , A.QCY_8_AMT
       , A.QCY_9_AMT
       , A.QCY_10_AMT
       , A.QCY_11_AMT
       , A.QCY_12_AMT
       , A.QCY_13_AMT
       , A.QCY_14_AMT
       , A.QCY_15_AMT
       , NULL AS SYSTEM_SRC
       , A.D_ADJ_TYPE
       , A.COD_CONTO
       , 'CPM_SP_D2M_ARP_M_PHASE2' AS PROVENIENZA
       , SYSDATE AS DATEUPD
       , SESSION_USER AS USERUPD
    FROM AW_MR9_ARPM01_000001 A
   WHERE A.COD_SCENARIO = V_SCENARIO
     AND A.COD_PERIODO = V_PERIODO
     AND A.COD_CATEGORIA = 'ZFAMOUNT'
     /* ZZT003_ADJ取LOCK_FLAG=Y公司，其余调整副本取LOCK_FLAG=N公司。
        ALTER BY 20261123 11:35 SHIQINGFENG.EX 锁定范围改为按SRC_DETAIL和LOCK_FLAG控制 */
     AND EXISTS (
           SELECT 1 AS MATCH_FLAG
             FROM SESSION_AZIENDA_LIST S
            WHERE S.SESSION_ID = V_SESSION_ID
              AND S.ELEM = A.COD_AZIENDA
              AND S.LOCK_FLAG = CASE
                    WHEN A.D_ADJ_TYPE = 'ARP_01_000' THEN 'Y'
                    ELSE 'N'
                  END
     );
END;
  /* 目标表装载完成，提交事务。 */
  INSERT INTO ZTAB_CPM_LOG (CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA)
  VALUES ('CPM_SP_D2M_ARP_M_PHASE2', '目标表装载完成', SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO, V_AZIENDA);
  COMMIT;

  /* 清理会话数据后记录执行完成。 */
  DELETE FROM SESSION_AZIENDA_LIST
   WHERE SESSION_ID = V_SESSION_ID;
  DELETE FROM SESSION_V_REF_AZIENDA
   WHERE SESSION_ID = V_SESSION_ID;

  INSERT INTO ZTAB_CPM_LOG (CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA)
  VALUES ('CPM_SP_D2M_ARP_M_PHASE2', 'END 执行完成', SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO, V_AZIENDA);
  COMMIT;
/*
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DELETE FROM SESSION_AZIENDA_LIST
     WHERE SESSION_ID = V_SESSION_ID;
    DELETE FROM SESSION_V_REF_AZIENDA
     WHERE SESSION_ID = V_SESSION_ID;
    V_ERROR_COD := SQLCODE;
    V_ERROR_MSG := SUBSTR(SQLERRM, 1, 4000);
    INSERT INTO ZTAB_CPM_LOG(
        CPM, STEP, REMARK, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
    ) VALUES (
        'CPM_SP_D2M_ARP_M_PHASE2', 'ERROR 执行报错', V_ERROR_COD || ':' || V_ERROR_MSG,
        SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO, P_AZIENDA
    );
    COMMIT;
    RAISE;*/
END CPM_SP_D2M_ARP_M_PHASE2;
