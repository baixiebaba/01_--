CREATE OR REPLACE PROCEDURE CPM_SP_M2M_ARP_INS_M_PHASE2(
    P_SCENARIO  IN VARCHAR2
  , P_PERIODO   IN VARCHAR2
  , P_AZIENDA   IN VARCHAR2
  , SESSION_USER IN VARCHAR2
) AS
  /**************************************************************************
  最后更新时间：20260923
  上一版本信息：
  名称：CPM_SP_M2M_ARP_INS_M_PHASE2
  用途：根据投保信息和往来账龄，更新投保本位币金额、账龄金额及未覆盖比例
  源表：AW_MR6_ARPINS_000001、AW_MR9_ARPM02_000001、DATI_CAMBIO
  目标表：AW_MR6_ARPINS_000001
  特殊逻辑：
    1. 公司范围沿用D2M/M2M的SESSION_AZIENDA_LIST，并排除当前期间锁定公司。
    2. 往来账龄按公司+客商编码匹配，且仅取LE_AGE_FLAG='AR'的数据。
    3. MTD_END_RATE = 公司本位币（AZIENDA.COD_VALUTA）期末汇率 / 投保币种期末汇率；币种一致时为1。
    4. INS_COV_DAYS按30、60-90、120-180、360分别累计账龄段0-3。
    5. 未覆盖比例沿用投保旧逻辑中的A、B、R、D计算公式。

  说明：
    AW_MR9_ARPM02_000001按公司+客商汇总账龄金额；公司本位币取TGK_FIMA_HISENSE.AZIENDA.COD_VALUTA，
    投保币种取QCY_INS_CODE，汇率表取当前场景和期间的CAMBIO_FINALE。

  版本信息：最新修改记录放最上面
    20260923 KIRO.EX 统一D2M/M2M过程格式及SESSION公司范围
    20260923 KIRO.EX 新增投保未覆盖比例更新过程

  手工执行：CALL CPM_SP_M2M_ARP_INS_M_PHASE2('2025ACT','06','6700','USER');
  **************************************************************************/
  V_SCENARIO      VARCHAR2(30);
  V_PERIODO       VARCHAR2(30);
  V_YEARMONTH     VARCHAR2(10);
  V_AZIENDA       VARCHAR2(4000);
  V_SESSION_ID    NUMBER;
  V_ERROR_COD     NUMBER;
  V_ERROR_MSG     VARCHAR2(4000);
BEGIN

  V_SESSION_ID := SYS_CONTEXT('USERENV', 'SESSIONID');
  /* 删除本session的参数公司，防止同一窗口中止后接着执行时公司范围扩大 */
  DELETE FROM SESSION_AZIENDA_LIST
   WHERE SESSION_ID = V_SESSION_ID;
  DELETE FROM SESSION_V_REF_AZIENDA
   WHERE SESSION_ID = V_SESSION_ID;

  INSERT INTO SESSION_V_REF_AZIENDA(SESSION_ID, HIE, NODE, ELEM)
  SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_AZIENDA;

  /* 时间参数初始化 */
  V_SCENARIO := P_SCENARIO;
  V_PERIODO := LPAD(P_PERIODO, 2, '0');
  V_YEARMONTH := SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO;

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
     /* 需要在抽取范围内且有效的公司才抽数 */
     AND ELEM IN (SELECT COD_AZIENDA
                    FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
                   WHERE ARP_FLAG = 'Y'
                     AND VALID_FR <= V_YEARMONTH
                     AND NVL(VALID_TO, '999999') >= V_YEARMONTH
                     AND COD_CONTO = 'ZAW_D2M_IN'
                  )
    /* 排除锁定公司 */
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
      'CPM_SP_M2M_ARP_INS_M_PHASE2', 'BEGIN 开始执行', SYSDATE, SESSION_USER,
      V_SCENARIO, V_PERIODO, V_AZIENDA
  );
  COMMIT;

  /* 测试用 从生产环境拉取收录数据进行更新 */
  DELETE FROM AW_MR6_ARPINS_000001;
  INSERT INTO AW_MR6_ARPINS_000001
  SELECT * FROM TGK_FIMA_HISENSE.AW_MR6_ARPINS_000001;
  /* 测试用 从生产环境拉取收录数据进行更新 */


  /* 更新投保信息录入表的本位币金额、账龄金额及未覆盖比例 */
  MERGE INTO AW_MR6_ARPINS_000001 T
  USING (
    WITH
    RATE_LIST AS (
      /* 当前调度场景、期间的期末汇率；同币种重复时取唯一汇率值 */
      SELECT R.COD_VALUTA
           , MAX(R.CAMBIO_FINALE) AS CAMBIO_FINALE
        FROM TGK_FIMA_HISENSE.DATI_CAMBIO R
       WHERE R.COD_SCENARIO = V_SCENARIO
         AND R.COD_PERIODO = V_PERIODO
       GROUP BY R.COD_VALUTA
    )
    , CALC_AMOUNT AS (
      /* 计算投保金额及免赔额的本位币金额，并将无匹配账龄置为0 */
      SELECT C.TARGET_OID
           , C.MTD_END_RATE
           , C.QCY_INS_AMT * C.MTD_END_RATE AS BCY_INS_AMT
           , C.QCY_INS_DDBL_AMT * C.MTD_END_RATE AS BCY_INS_DDBL_AMT
           , NVL(C.BCY_0_AMT, 0) AS BCY_0_AMT
           , NVL(C.BCY_1_AMT, 0) AS BCY_1_AMT
           , NVL(C.BCY_2_AMT, 0) AS BCY_2_AMT
           , NVL(C.BCY_3_AMT, 0) AS BCY_3_AMT
           , CASE C.INS_COV_DAYS
                 WHEN 30 THEN NVL(C.BCY_0_AMT, 0)
                 WHEN 360 THEN NVL(C.BCY_0_AMT, 0)
                             + NVL(C.BCY_1_AMT, 0)
                             + NVL(C.BCY_2_AMT, 0)
                             + NVL(C.BCY_3_AMT, 0)
                 ELSE CASE
                          WHEN C.INS_COV_DAYS BETWEEN 60 AND 90
                           THEN NVL(C.BCY_0_AMT, 0)
                              + NVL(C.BCY_1_AMT, 0)
                          WHEN C.INS_COV_DAYS BETWEEN 120 AND 180
                           THEN NVL(C.BCY_0_AMT, 0)
                              + NVL(C.BCY_1_AMT, 0)
                              + NVL(C.BCY_2_AMT, 0)
                        END
             END AS AGE_BALANCE
           , C.INS_CLM_RATIO
        FROM (
          SELECT I.OID AS TARGET_OID
               , I.QCY_INS_AMT
               , I.QCY_INS_DDBL_AMT
               , I.INS_COV_DAYS
               , I.INS_CLM_RATIO
               , A.BCY_0_AMT
               , A.BCY_1_AMT
               , A.BCY_2_AMT
               , A.BCY_3_AMT
               , CASE
                     WHEN I.QCY_INS_CODE IS NOT NULL
                      AND AZ.COD_VALUTA IS NOT NULL
                      AND I.QCY_INS_CODE = AZ.COD_VALUTA
                       THEN 1
                     WHEN QCY_RATE.CAMBIO_FINALE IS NOT NULL
                      AND QCY_RATE.CAMBIO_FINALE <> 0
                      AND BCY_RATE.CAMBIO_FINALE IS NOT NULL
                       THEN BCY_RATE.CAMBIO_FINALE / QCY_RATE.CAMBIO_FINALE
                   END AS MTD_END_RATE
            FROM AW_MR6_ARPINS_000001 I
            LEFT JOIN (
              SELECT A.COD_AZIENDA
                   , A.CUST_CODE
                   , SUM(NVL(A.BCY_0_AMT, 0)) AS BCY_0_AMT
                   , SUM(NVL(A.BCY_1_AMT, 0)) AS BCY_1_AMT
                   , SUM(NVL(A.BCY_2_AMT, 0)) AS BCY_2_AMT
                   , SUM(NVL(A.BCY_3_AMT, 0)) AS BCY_3_AMT
                FROM AW_MR9_ARPM02_000001 A
               WHERE A.COD_SCENARIO = V_SCENARIO
                 AND A.COD_PERIODO = V_PERIODO
                 AND A.LE_AGE_FLAG = 'AR'
                 AND A.COD_AZIENDA IN (
                       SELECT ELEM
                         FROM SESSION_AZIENDA_LIST
                        WHERE SESSION_ID = V_SESSION_ID
                 )
               GROUP BY A.COD_AZIENDA
                      , A.CUST_CODE
            ) A
              ON A.COD_AZIENDA = I.COD_AZIENDA
             AND A.CUST_CODE = I.CUST_CODE
            LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
              ON AZ.COD_AZIENDA = I.COD_AZIENDA
            LEFT JOIN RATE_LIST QCY_RATE
              ON QCY_RATE.COD_VALUTA = I.QCY_INS_CODE
            LEFT JOIN RATE_LIST BCY_RATE
              ON BCY_RATE.COD_VALUTA = AZ.COD_VALUTA
           WHERE I.COD_SCENARIO = V_SCENARIO
             AND I.COD_PERIODO = V_PERIODO
             AND I.COD_AZIENDA IN (
                   SELECT ELEM
                     FROM SESSION_AZIENDA_LIST
                    WHERE SESSION_ID = V_SESSION_ID
             )
        ) C
    )
    SELECT C.TARGET_OID
         , C.MTD_END_RATE
         , C.BCY_INS_AMT
         , C.BCY_INS_DDBL_AMT
         , C.BCY_0_AMT
         , C.BCY_1_AMT
         , C.BCY_2_AMT
         , C.BCY_3_AMT
         , CASE
               /* 汇率或投保基础参数缺失时不套用B=0公式，避免误算为未覆盖比例1 */
               WHEN C.BCY_INS_AMT IS NULL
                 OR C.BCY_INS_DDBL_AMT IS NULL
                 OR C.INS_CLM_RATIO IS NULL
                 THEN NULL
               /* A = BCY_INS_AMT，B = 按保障天数匹配的账龄余额合计 */
               WHEN C.BCY_INS_AMT > C.AGE_BALANCE
                THEN CASE
                         WHEN C.AGE_BALANCE = 0
                           THEN 0
                         ELSE (
                                C.AGE_BALANCE * (1 - C.INS_CLM_RATIO)
                              + C.BCY_INS_DDBL_AMT
                              ) / C.AGE_BALANCE
                     END
               ELSE CASE
                        WHEN C.AGE_BALANCE = 0
                          THEN 1
                        ELSE 1 - (
                               C.BCY_INS_AMT - C.BCY_INS_DDBL_AMT
                             ) * C.INS_CLM_RATIO / C.AGE_BALANCE
                    END
           END AS INS_UNCOV_RATIO
      FROM CALC_AMOUNT C
  ) S
     ON (T.OID = S.TARGET_OID)
   WHEN MATCHED THEN UPDATE SET
         T.BCY_INS_AMT = S.BCY_INS_AMT
       , T.BCY_INS_DDBL_AMT = S.BCY_INS_DDBL_AMT
       , T.MTD_END_RATE = S.MTD_END_RATE
       , T.BCY_0_AMT = S.BCY_0_AMT
       , T.BCY_1_AMT = S.BCY_1_AMT
       , T.BCY_2_AMT = S.BCY_2_AMT
       , T.BCY_3_AMT = S.BCY_3_AMT
       , T.INS_UNCOV_RATIO = S.INS_UNCOV_RATIO
       , T.PROVENIENZA = 'CPM_SP_M2M_ARP_INS_M_PHASE2'
       , T.DATEUPD = SYSDATE
       , T.USERUPD = SESSION_USER;

  INSERT INTO ZTAB_CPM_LOG(
      CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
  ) VALUES (
      'CPM_SP_M2M_ARP_INS_M_PHASE2', '目标表相关字段更新完成', SYSDATE, SESSION_USER,
      V_SCENARIO, V_PERIODO, V_AZIENDA
  );
  COMMIT;

  /* 清理当前会话数据 */
  DELETE FROM SESSION_AZIENDA_LIST
   WHERE SESSION_ID = V_SESSION_ID;
  DELETE FROM SESSION_V_REF_AZIENDA
   WHERE SESSION_ID = V_SESSION_ID;

  INSERT INTO ZTAB_CPM_LOG(
      CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
  ) VALUES (
      'CPM_SP_M2M_ARP_INS_M_PHASE2', 'END 执行完成', SYSDATE, SESSION_USER,
      V_SCENARIO, V_PERIODO, V_AZIENDA
  );
  COMMIT;

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
        'CPM_SP_M2M_ARP_INS_M_PHASE2', 'ERROR 执行报错', V_ERROR_COD || ':' || V_ERROR_MSG,
        SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO, NVL(V_AZIENDA, P_AZIENDA)
    );
    COMMIT;
    RAISE;
END CPM_SP_M2M_ARP_INS_M_PHASE2;
