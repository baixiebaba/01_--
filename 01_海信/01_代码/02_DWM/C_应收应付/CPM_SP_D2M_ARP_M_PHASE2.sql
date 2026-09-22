CREATE OR REPLACE PROCEDURE CPM_SP_D2M_ARP_M_PHASE2(
    P_SCENARIO  IN VARCHAR2
  , P_PERIODO   IN VARCHAR2
  , P_AZIENDA   IN VARCHAR2
  , SESSION_USER IN VARCHAR2
) AS
  /**************************************************************************
  最后更新时间：
  上一版本信息：
  名称：CPM_SP_D2M_ARP_M
  用途：DWD->DWM往来账龄数据抽取
  源表：DWD_FI_MR_ARAP_SUM_MI、AW_MR9_REVM01_000001
  目标表：AW_MR9_ARPM01_000001
  逻辑文档地址: https://hisenseex.feishu.cn/sheets/JVJsssmEqh9Uk6tSffEci4khnIf?from=from_copylink&sheet=jNeukA
  特殊逻辑：仅取DWD_STANDARD和M01_FACT两个数据包

  版本信息：最新修改记录放最上面
    
    20260921 SHIQINGFENG.EX 新增重分类标识及集团归属范围更新
    20260920 SHIQINGFENG.EX 新增

  手工执行：CALL CPM_SP_D2M_ARP_M_PHASE2('2025ACT','06','6700','USER');
  **************************************************************************/
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
  /* 删除本session的参数公司，防止再同一个窗口跑中止后接着跑，之后出现公司范围扩大 */
  DELETE FROM SESSION_AZIENDA_LIST
   WHERE SESSION_ID = V_SESSION_ID;
  DELETE FROM SESSION_V_REF_AZIENDA
   WHERE SESSION_ID = V_SESSION_ID;

  INSERT INTO SESSION_V_REF_AZIENDA(
      SESSION_ID
    , HIE
    , NODE
    , ELEM
  )
  SELECT V_SESSION_ID
       , HIE
       , NODE
       , ELEM
    FROM TGK_FIMA_HISENSE.V_REF_AZIENDA;

  /* 时间参数初始化 */
  V_SCENARIO := P_SCENARIO;
  V_PERIODO := LPAD(P_PERIODO, 2, '0');

  V_YEARMONTH := SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO;
  V_LAST_DAY := LAST_DAY(TO_DATE(V_YEARMONTH || '01', 'YYYYMMDD'));

  /* 组织参数初始化 */
  INSERT INTO SESSION_AZIENDA_LIST(SESSION_ID, ELEM)
  SELECT DISTINCT V_SESSION_ID
       , ELEM
    FROM SESSION_V_REF_AZIENDA
   WHERE HIE = '10'
     AND (
           INSTR(',' || P_AZIENDA || ',', ',' || ELEM || ',') > 0
        OR INSTR(',' || P_AZIENDA || ',', ',' || NODE || ',') > 0
        OR P_AZIENDA = 'ALL'
     )
     /*需要再抽取范围内的公司才抽数*/
     AND ELEM IN (SELECT COD_AZIENDA
                    FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
                   WHERE ARP_FLAG = 'Y'
                     AND VALID_FR <= V_YEARMONTH
                     AND NVL(VALID_TO,'999999') >= V_YEARMONTH
                     AND COD_CONTO = 'ZAW_D2M_IN'
                  )
    /*排除锁定公司*/
     AND ELEM NOT IN (
           SELECT COD_AZIENDA
             FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001 T
            WHERE ARP_FLAG = 'Y'
              AND T.COD_SCENARIO = V_SCENARIO
              AND T.COD_PERIODO = V_PERIODO
              AND T.COD_CONTO = 'ZAW_D2M_LOCK'
     );
  /* 获取所有跑的公司列表，供日志插入使用 */
  SELECT LISTAGG(ELEM, ',') WITHIN GROUP (ORDER BY ELEM)
    INTO V_AZIENDA
    FROM (
      SELECT DISTINCT ELEM
        FROM SESSION_AZIENDA_LIST
       WHERE SESSION_ID = V_SESSION_ID
    );

  INSERT INTO ZTAB_CPM_LOG(
      CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
  ) VALUES (
      'CPM_SP_D2M_ARP_M_PHASE2', 'BEGIN 开始执行', SYSDATE, SESSION_USER,
      V_SCENARIO, V_PERIODO, V_AZIENDA
  );
  COMMIT;

  /* 删除当前批次，保证增量重跑不产生重复数据 */
  DELETE FROM AW_MR9_ARPM01_000001
   WHERE COD_SCENARIO = V_SCENARIO
     AND COD_PERIODO = V_PERIODO
     AND COD_AZIENDA IN (
           SELECT ELEM
             FROM SESSION_AZIENDA_LIST
            WHERE SESSION_ID = V_SESSION_ID
     )
     AND PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
     ;

  INSERT INTO ZTAB_CPM_LOG(
      CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
  ) VALUES (
      'CPM_SP_D2M_ARP_M_PHASE2', '当前批次删除完成', SYSDATE, SESSION_USER,
      V_SCENARIO, V_PERIODO, V_AZIENDA
  );

  /* 统一标准事实接口并写入目标表 */
  INSERT INTO AW_MR9_ARPM01_000001(
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
               WHEN COMPANY_CODE IN ('6000', '6600')
                AND ACCT_SRC_CODE LIKE '1131%' THEN '1131002000'
               WHEN COMPANY_CODE IN ('6000', '6600')
                AND ACCT_SRC_CODE LIKE '1133%' THEN '1133001003'
               WHEN COMPANY_CODE IN ('6000', '6600')
                AND ACCT_SRC_CODE LIKE '2181%' THEN '2181001005'
               WHEN COMPANY_CODE IN ('6000', '6600')
                AND ACCT_SRC_CODE LIKE '2121%' THEN '2121001000'
               WHEN COMPANY_CODE LIKE '16%'
                AND COMPANY_CODE NOT LIKE '163%'
                AND COMPANY_CODE NOT LIKE '162%'
                AND ACCT_SRC_CODE IN ('2202000000', '2202000089') THEN '2202000000'
               ELSE ACCT_SRC_CODE
           END AS ACCT_REC_CODE
         , ACCT_MAP_CODE
         , CAST(NULL AS VARCHAR2(30)) AS LE_AGE_FLAG
         , CAST(NULL AS VARCHAR2(30)) AS ME_AGE_FLAG
         , CAST(NULL AS VARCHAR2(30)) AS MB_AGE_FLAG
         , CAST(NULL AS VARCHAR2(30)) AS GRP_SCOPE
         , CHANNEL_L3_CODE AS D_CHANNEL
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
         , QCY_CODE AS COD_VALUTA_ORIGINARIA
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
       AND COMPANY_CODE IN (
             SELECT ELEM
               FROM SESSION_AZIENDA_LIST
              WHERE SESSION_ID = V_SESSION_ID
       )
  ),

  /* M01：出库未开、退货未办，BCY_REV写入本位币0/1桶，ORG_REV写入交易币0/1桶 */
  M01_FACT AS (
    SELECT V_SCENARIO AS COD_SCENARIO
         , V_PERIODO AS COD_PERIODO
         , T.COD_AZIENDA
         , 'ZAMOUNT' AS COD_CATEGORIA
         , CASE WHEN T.COD_CONTO LIKE 'S600101%' THEN 'ZTSO04_CK'
                WHEN T.COD_CONTO LIKE 'S600102%' THEN 'ZTSO04_TH' 
           END AS SRC_DETAIL
         , T.CUST_CODE
         , T.CUST_NAME
         , CAST(NULL AS VARCHAR2(30)) AS CUST_HEAD_CODE
         , CAST(NULL AS VARCHAR2(200)) AS CUST_HEAD_NAME
         , CAST(NULL AS VARCHAR2(30)) AS CUST_BRANCH_CODE
         , CAST(NULL AS VARCHAR2(200)) AS CUST_BRANCH_NAME
         , T.COD_AZI_CTP
         , CAST(NULL AS VARCHAR2(30)) AS COUNTRY_CODE
         , CAST(NULL AS VARCHAR2(200)) AS COUNTRY_NAME
         , '1122000000' AS ACCT_SRC_CODE
         , '1122000000' AS ACCT_REC_CODE
         , '1122000000' AS ACCT_MAP_CODE
         , CAST(NULL AS VARCHAR2(30)) AS LE_AGE_FLAG
         , CAST(NULL AS VARCHAR2(30)) AS ME_AGE_FLAG
         , CAST(NULL AS VARCHAR2(30)) AS MB_AGE_FLAG
         , CAST(NULL AS VARCHAR2(30)) AS GRP_SCOPE
         , T.D_CHANNEL
         , T.D_ONOFFLINE
         , T.COD_DEST2
         , T.COD_DEST3
         , T.D_SALE_DEPT
         , CAST(NULL AS VARCHAR2(2000)) AS NATURE_L1_NAME
         , CAST(NULL AS VARCHAR2(2000)) AS NATURE_L2_NAME
         , CAST(NULL AS VARCHAR2(2000)) AS NATURE_L3_NAME
         , CAST(NULL AS VARCHAR2(30)) AS UFEE_UREB_FLAG
         , CAST(NULL AS VARCHAR2(30)) AS ECLS_FLAG
         , CAST(NULL AS VARCHAR2(300)) AS PAY_TERM_CODE
         , CAST(NULL AS VARCHAR2(2000)) AS PAY_TERM_DESC
         , CAST(NULL AS VARCHAR2(200)) AS EXCHANGE_RATE_EVAL_FLAG
         , CAST(NULL AS NUMBER(27, 9)) AS TAX_RATE
         , T.COD_VALUTA
         , T.COD_VALUTA_ORIGINARIA
         , T.BCY_REV AS BCY_0_AMT
         , T.BCY_REV AS BCY_1_AMT
         , 0 AS BCY_2_AMT, 0 AS BCY_3_AMT, 0 AS BCY_4_AMT
         , 0 AS BCY_5_AMT, 0 AS BCY_6_AMT, 0 AS BCY_7_AMT
         , 0 AS BCY_8_AMT, 0 AS BCY_9_AMT, 0 AS BCY_10_AMT
         , 0 AS BCY_11_AMT, 0 AS BCY_12_AMT, 0 AS BCY_13_AMT
         , 0 AS BCY_14_AMT, 0 AS BCY_15_AMT
         , T.ORG_REV AS QCY_0_AMT
         , T.ORG_REV AS QCY_1_AMT
         , 0 AS QCY_2_AMT, 0 AS QCY_3_AMT, 0 AS QCY_4_AMT
         , 0 AS QCY_5_AMT, 0 AS QCY_6_AMT, 0 AS QCY_7_AMT
         , 0 AS QCY_8_AMT, 0 AS QCY_9_AMT, 0 AS QCY_10_AMT
         , 0 AS QCY_11_AMT, 0 AS QCY_12_AMT, 0 AS QCY_13_AMT
         , 0 AS QCY_14_AMT, 0 AS QCY_15_AMT
         , 'TA' AS SYSTEM_SRC
         , NVL(T.D_ADJ_TYPE, 'ZZZZ') AS D_ADJ_TYPE
      FROM AW_MR9_REVM01_000001 T
     WHERE T.COD_SCENARIO = V_SCENARIO
       AND T.COD_PERIODO = V_PERIODO
       AND T.COD_AZIENDA IN (
             SELECT ELEM
               FROM SESSION_AZIENDA_LIST
              WHERE SESSION_ID = V_SESSION_ID
       )
       AND (T.COD_CONTO LIKE 'S600101%' OR T.COD_CONTO LIKE 'S600102%')
  ),
  STANDARD_FACT AS (
    SELECT * FROM DWD_STANDARD
    UNION ALL
    SELECT * FROM M01_FACT
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
      FROM STANDARD_FACT
     GROUP BY COD_SCENARIO, COD_PERIODO, COD_AZIENDA, COD_CATEGORIA, SRC_DETAIL
            , CUST_CODE, CUST_NAME, CUST_HEAD_CODE, CUST_HEAD_NAME
            , CUST_BRANCH_CODE, CUST_BRANCH_NAME, COD_AZI_CTP, COUNTRY_CODE, COUNTRY_NAME
            , ACCT_SRC_CODE, ACCT_REC_CODE, ACCT_MAP_CODE
            , LE_AGE_FLAG, ME_AGE_FLAG, MB_AGE_FLAG, GRP_SCOPE
            , D_CHANNEL, D_ONOFFLINE, COD_DEST2, COD_DEST3, D_SALE_DEPT
            , NATURE_L1_NAME, NATURE_L2_NAME, NATURE_L3_NAME
            , UFEE_UREB_FLAG, ECLS_FLAG, PAY_TERM_CODE, PAY_TERM_DESC
            , EXCHANGE_RATE_EVAL_FLAG, TAX_RATE
            , COD_VALUTA, COD_VALUTA_ORIGINARIA, SYSTEM_SRC, D_ADJ_TYPE
  )
  SELECT NEWID()
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

  -- ============================================================================
  -- 更新重分类标识及集团归属范围
  -- 法人/管理单体按账套+公司+有效客商开窗，管理分公司增加利润中心。
  -- 科目范围由当前目标行ACCT_SRC_CODE传入重分类函数，有主户时优先使用主户编码。
  -- ============================================================================
  MERGE INTO AW_MR9_ARPM01_000001 T
  USING (
    WITH TARGET_FACT AS (
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
           , CASE WHEN A.SYSTEM_SRC LIKE 'S%' THEN SUBSTR(A.SYSTEM_SRC,2,4)
                  ELSE A.SYSTEM_SRC
             END AS MANDT
           , NVL(A.BCY_0_AMT, 0) AS BCY_0_AMT
        FROM AW_MR9_ARPM01_000001 A
       WHERE A.COD_SCENARIO = V_SCENARIO
         AND A.COD_PERIODO = V_PERIODO
         AND A.COD_AZIENDA IN (
               SELECT ELEM
                 FROM SESSION_AZIENDA_LIST
                WHERE SESSION_ID = V_SESSION_ID
         )
         AND A.PROVENIENZA = 'CPM_SP_D2M_ARP_M_PHASE2'
         AND (A.SRC_DETAIL LIKE 'ORG%'
              OR A.SRC_DETAIL LIKE 'ZTSO04%' 
             )
    ),
    AMOUNT_FACT AS (
      SELECT F.*
           , SUM(
                 CASE WHEN F.SRC_DETAIL LIKE 'ORG%'
                        THEN F.BCY_0_AMT
                      ELSE 0
                 END
               ) OVER (
                 PARTITION BY F.SYSTEM_SRC
                            , F.COD_AZIENDA
                            , F.CUST_KEY
                            , F.ACCT_REC_CODE
               ) AS LE_BCY_AMT
           , SUM(
                 CASE WHEN F.SRC_DETAIL LIKE 'ORG%'
                            OR F.SRC_DETAIL LIKE 'ZTSO04%'
                      THEN F.BCY_0_AMT
                      ELSE 0
                 END
               ) OVER (
                 PARTITION BY F.SYSTEM_SRC
                            , F.COD_AZIENDA
                            , F.CUST_KEY
                            , F.ACCT_REC_CODE
               ) AS ME_BCY_AMT
           , SUM(
                 CASE WHEN F.SRC_DETAIL LIKE 'ORG%'
                            OR F.SRC_DETAIL LIKE 'ZTSO04%'
                      THEN F.BCY_0_AMT
                      ELSE 0
                 END
               ) OVER (
                 PARTITION BY F.SYSTEM_SRC
                            , F.COD_AZIENDA
                            , F.CUST_KEY
                            , F.COD_DEST2
                            , F.ACCT_REC_CODE
               ) AS MB_BCY_AMT
        FROM TARGET_FACT F
    ),
    REC_FLAG_FACT AS (
      SELECT F.*
           , CASE WHEN F.SRC_DETAIL LIKE 'ORG%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_SRC_CODE
                      , F.CUST_KEY
                      , F.LE_BCY_AMT
                      , '1'
                    )
                  END AS IS_REC_LG
           , CASE WHEN F.SRC_DETAIL LIKE 'ORG%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_SRC_CODE
                      , F.CUST_KEY
                      , F.LE_BCY_AMT
                      , '2'
                    )
                  END AS LE_AGE_FLAG
           , CASE WHEN F.SRC_DETAIL LIKE 'ORG%'
                         OR F.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_SRC_CODE
                      , F.CUST_KEY
                      , F.ME_BCY_AMT
                      , '1'
                    )
                  END AS IS_REC_ME
           , CASE WHEN F.SRC_DETAIL LIKE 'ORG%'
                        OR F.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_SRC_CODE
                      , F.CUST_KEY
                      , F.ME_BCY_AMT
                      , '2'
                    )
                  END AS ME_AGE_FLAG
           , CASE WHEN F.SRC_DETAIL LIKE 'ORG%'
                        OR F.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_SRC_CODE
                      , F.CUST_KEY
                      , F.MB_BCY_AMT
                      , '1'
                    )
                  END AS IS_REC_MB
           , CASE WHEN F.SRC_DETAIL LIKE 'ORG%'
                        OR F.SRC_DETAIL LIKE 'ZTSO04%'
                    THEN
                    TGK_GB_HISENSE.F_APAR_REC(
                        V_YEARMONTH
                      , F.MANDT
                      , F.COD_AZIENDA
                      , F.ACCT_SRC_CODE
                      , F.CUST_KEY
                      , F.MB_BCY_AMT
                      , '2'
                    )
                  END AS MB_AGE_FLAG
        FROM AMOUNT_FACT F
    ),
    HITACHI_ELEM AS (
      SELECT DISTINCT R.ELEM
        FROM TGK_GB_HISENSE.V_REF_AZIENDA_TV R
       WHERE R.COD_SCENARIO = V_SCENARIO
         AND R.COD_PERIODO = V_PERIODO
         AND R.HIE = '30'
         AND R.NODE = '1730'
    ),
    NODE_MAP AS (
      SELECT N.COD_SCENARIO
           , N.COD_PERIODO
           , N.ELEM
           , N.NODE AS NODE
           , CASE WHEN H.ELEM IS NOT NULL THEN NVL(N.NODES, N.NODE)
                  ELSE N.NODE
             END AS SELF_NODE
           , N.HQ
        FROM TGK_GB_HISENSE.V_APAR_ELEM_NODE_TAB N
        LEFT JOIN HITACHI_ELEM H
          ON H.ELEM = N.ELEM
       WHERE N.COD_SCENARIO = V_SCENARIO
         AND N.COD_PERIODO = V_PERIODO
    )
    -- 以下维度、金额和节点字段仅用于测试查询展示，不参与OID关联。
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
         , P.NODE AS CTP_NODE
         , P.HQ AS CTP_HQ
         , F.LE_AGE_FLAG
         , F.IS_REC_LG
         , F.ME_AGE_FLAG
         , F.IS_REC_ME
         , F.MB_AGE_FLAG
         , F.IS_REC_MB
         , CASE
               WHEN C.SELF_NODE = P.NODE AND C.HQ = P.HQ THEN 'SUB-子公司'
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
         T.ACCT_REC_CODE = CASE S.LE_AGE_FLAG
                                 WHEN 'AR' THEN '1122000000'
                                 WHEN 'OR' THEN '122101F'
                                 WHEN 'AS' THEN '1123000000'
                                 WHEN 'CA' THEN '1460000000'
                                 WHEN 'RF' THEN '1124001000'
                                 WHEN 'AP' THEN '2202000000'
                                 WHEN 'OP' THEN '224199F'
                                 WHEN 'AC' THEN '2203000000'
                                 WHEN 'CL' THEN '2204000000'
                                 WHEN 'A9' THEN '1910000A70'
                                 WHEN 'A10' THEN '1531000000'
                                 ELSE T.ACCT_REC_CODE
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






  INSERT INTO ZTAB_CPM_LOG(
      CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
  ) VALUES (
      'CPM_SP_D2M_ARP_M_PHASE2', '目标表装载完成', SYSDATE, SESSION_USER,
      V_SCENARIO, V_PERIODO, V_AZIENDA
  );
  COMMIT;

  /* 4.1 清理当前会话数据 */
  DELETE FROM SESSION_AZIENDA_LIST
   WHERE SESSION_ID = V_SESSION_ID;
  DELETE FROM SESSION_V_REF_AZIENDA
   WHERE SESSION_ID = V_SESSION_ID;

  INSERT INTO ZTAB_CPM_LOG(
      CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
  ) VALUES (
      'CPM_SP_D2M_ARP_M_PHASE2', 'END 执行完成', SYSDATE, SESSION_USER,
      V_SCENARIO, V_PERIODO, V_AZIENDA
  );
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