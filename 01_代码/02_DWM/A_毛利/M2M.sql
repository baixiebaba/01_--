CREATE OR REPLACE PROCEDURE CPM_SP_M2M_REV_M (
  P_SCENARIO    IN VARCHAR2,
  P_PERIODO     IN VARCHAR2,  -- YYYYMM
  P_AZIENDA     IN VARCHAR2,
  SESSION_USER  IN VARCHAR2
) AS
/******

修改日志：
  20260716 shiqingfeng.ex 新增插入墨西哥利润调整
  20260730 SHQINGFENG.EX 新增 MA_SALE_COGS 字段
  20260804 SHIQINGFENG.EX 补充2900公司取数时排除ZZFT
  20260806-1 【需求】管报中国区(1180、12**公司)政策分摊兜底逻辑：D_CHANNEL替换为D_ECOM_BU；D_ECOM_BU为空或ZZZZ不分摊；不跨公司分摊
  20260806-2 【fix】1.1保留D_ECOM_BU空/ZZZZ记录，A_STEP3收入端排除并自然落入1.4未分配政策；1.4的M端D_CHANNEL同步转换
  20260806-3 新增将单体前三个月的数据缓存到temp表，将后续所有单体表替换为temp表
  20260810-1 shiqingfeng.ex 对方公司是中国区公司，不生成成本抵消数
  20260810-2 shiqingfeng.ex 需排除科目为S6401开头，SALE_COGS=0且SH_BF_SALE_COGS不为0 ---该部分为成本分摊前金额
  20260810-3 shiqingfeng.ex SXX补充逻辑【中国区专题】：
                            如果公司范围是中国区公司【公司节点为200】
                            且科目范围为S6401开头
                            则限制业务分类范围在AW_RUL_CNMECL_000001-中国区-其他业务收入范围配置表范围内的才取成本数，其他公司直接取SALE_COGS
   20260817-1 CHENDONG3.ex  新增6012公司处理字段ASSESS_MANG_COST逻辑
   20260817-2 CHENDONG3.ex  将中国区费用转政策的业务在产品公司还原的部分，对方公司置为空，以确保后续不参与抵消





******/
  v_per0  VARCHAR2(6);
  v_per1  VARCHAR2(6);
  v_per2  VARCHAR2(6);
  v_per0_ACT  VARCHAR2(7);
  v_per1_ACT  VARCHAR2(7);
  v_per2_ACT  VARCHAR2(7);
  v_per0_PER  VARCHAR2(7);
  v_per1_PER  VARCHAR2(7);
  v_per2_PER  VARCHAR2(7);
  V_CN_AZIENDA VARCHAR2(4000) ;
  V_HITACHI_AZIENDA VARCHAR2(4000);
  V_AZIENDA        VARCHAR2(5000);-- 公司
  V_ENTITY       VARCHAR2(5000);-- 用于存放如果遇到【合并收入，冰箱、厨卫（63、67）-BX，空气（62、68）-KT，视像（2、163）-SX】公司需要把参数调整成BX\KT\SX 以及ALL
  V_AZI_CTP       VARCHAR2(5000);-- 对方公司，海信内部公司的三级分类有值时，要限制海信内部公司即对方公司不参与分摊
  V_MATERIAL     VARCHAR2(4000);-- 虚拟物料
  V_PRO_CLASS    VARCHAR2(4000); -- 配件类不参与分摊:通用规则:根据物料对应产品中类为配件的不参与分摊，或物料组1100105(附加产品)、1100107(商显附加产品)不参与分摊
  V_ERROR_COD          NUMBER;
  V_ERROR_MSG      VARCHAR2(4000);--错误信息
  V_SESSION_ID  NUMBER;
BEGIN
-- 获取当前 Session ID
    V_SESSION_ID := SYS_CONTEXT('USERENV', 'SESSIONID');
-- 插入本 Session 数据
    INSERT INTO SESSION_V_REF_AZIENDA (SESSION_ID, HIE, NODE, ELEM)
    SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_AZIENDA
    ;
    INSERT INTO SESSION_V_REF_DEST3_NONAME (SESSION_ID, HIE, NODE, ELEM)
    SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_DEST3_NONAME
    ;
    INSERT INTO SESSION_V_REF_DEST2 (SESSION_ID, HIE, NODE, ELEM)
    SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_DEST2
    ;


    -- rolling quarter: 当前月 + 前两月
    v_per0 := SUBSTR(P_SCENARIO,1,4) || P_PERIODO ;
    v_per1 := TO_CHAR(ADD_MONTHS(TO_DATE(SUBSTR(P_SCENARIO,1,4) || P_PERIODO || '01', 'YYYYMMDD'), -1), 'YYYYMM');
    v_per2 := TO_CHAR(ADD_MONTHS(TO_DATE(SUBSTR(P_SCENARIO,1,4) || P_PERIODO || '01', 'YYYYMMDD'), -2), 'YYYYMM');
    /*因为有BGT场景的数据，所以取数的时候需要现在实际场景*/
    v_per0_ACT:= SUBSTR(v_per0,0,4)||'ACT';
    v_per1_ACT:= SUBSTR(v_per1,0,4)||'ACT';
    v_per2_ACT:= SUBSTR(v_per2,0,4)||'ACT';

    v_per0_per := SUBSTR(v_per0,-2);
    v_per1_per := SUBSTR(v_per1,-2);
    v_per2_per := SUBSTR(v_per2,-2);
  -- 公司参数赋值
  SELECT LISTAGG(COD_AZIENDA, ',')
    INTO V_CN_AZIENDA
    FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
   WHERE COD_BG = 'BG012'
     AND COD_AZIENDA <> '1183'
     ;

  SELECT LISTAGG(ELEM, ',')
    INTO V_HITACHI_AZIENDA
    FROM SESSION_V_REF_AZIENDA
   WHERE 1=1
     AND SESSION_ID = V_SESSION_ID
     AND HIE = '10'
     AND NODE = '050'
     /*20260226 新增排除锁定公司*/
     AND ELEM NOT IN (SELECT COD_AZIENDA
                        FROM AW_RUL_DWMCRS_000001 T
                       WHERE REV05_FLAG = 'Y'
                         AND T.COD_SCENARIO = P_SCENARIO
                         AND T.COD_PERIODO = P_PERIODO
                         AND T.COD_CONTO = 'ZAW_D2M_LOCK')
      ;

  -- 公司参数赋值,除了电冰空工厂需要集体跑，其他都可以按照单家去运行

INSERT INTO SESSION_AZIENDA_LIST(SESSION_ID, ELEM)
SELECT DISTINCT V_SESSION_ID,ELEM
  FROM(
    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'BX' OR P_AZIENDA LIKE '63%' OR P_AZIENDA LIKE '67%' OR P_AZIENDA LIKE '6000%')
          AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '6000%')

      UNION ALL

    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'KT' OR P_AZIENDA LIKE '62%' OR P_AZIENDA LIKE '68%')
          AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')

      UNION ALL

    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'SX' OR P_AZIENDA LIKE '2%' OR P_AZIENDA LIKE '163%')
          AND (COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%')

      UNION ALL

        SELECT DISTINCT ELEM
        FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID AND P_AZIENDA = 'ALL' AND HIE = '10'

      UNION ALL

        SELECT DISTINCT ELEM
        FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID AND HIE = '10'
        AND (    INSTR(','||P_AZIENDA||',',','||ELEM||',') > 0
              OR INSTR(','||P_AZIENDA||',',','||NODE||',') > 0
              OR ((P_AZIENDA LIKE '17%' OR P_AZIENDA = '6240') AND NODE = '050')
            )
        AND ELEM NOT LIKE '63%'
        AND ELEM NOT LIKE '67%'
        AND ELEM NOT LIKE '62%'
        AND ELEM NOT LIKE '68%'
        AND ELEM NOT LIKE '2%'
        AND ELEM NOT LIKE '163%'
    )
    /*20260226 新增排除锁定公司*/
   WHERE ELEM NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   )
    ;


  SELECT LISTAGG(ELEM,',') INTO V_AZIENDA
  FROM(
    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'BX' OR P_AZIENDA LIKE '63%' OR P_AZIENDA LIKE '67%' OR P_AZIENDA LIKE '6000%')
          AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '6000%')

      UNION ALL

    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'KT' OR P_AZIENDA LIKE '62%' OR P_AZIENDA LIKE '68%')
          AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')

      UNION ALL

    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'SX' OR P_AZIENDA LIKE '2%' OR P_AZIENDA LIKE '163%')
          AND (COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%')

      UNION ALL

        SELECT DISTINCT ELEM
        FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID AND P_AZIENDA = 'ALL' AND HIE = '10'

      UNION ALL

        SELECT DISTINCT ELEM
        FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID AND HIE = '10'
        AND (    INSTR(','||P_AZIENDA||',',','||ELEM||',') > 0
              OR INSTR(','||P_AZIENDA||',',','||NODE||',') > 0
              OR ((P_AZIENDA LIKE '17%' OR P_AZIENDA = '6240') AND NODE = '050')
            )
        AND ELEM NOT LIKE '63%'
        AND ELEM NOT LIKE '67%'
        AND ELEM NOT LIKE '62%'
        AND ELEM NOT LIKE '68%'
        AND ELEM NOT LIKE '2%'
        AND ELEM NOT LIKE '163%'
    )
    /*20260226 新增排除锁定公司*/
   WHERE ELEM NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   )
    ;


/*
INSERT INTO TMP_V_REF_DEST3_NONAME( HIE,NODE,ELEM)
SELECT HIE,NODE,ELEM FROM SESSION_V_REF_DEST3_NONAME;
*/

--如果遇到【合并收入，冰箱、厨卫（63、67）-BX，空气（62、68）-KT，视像（2、163）-SX】公司需要把参数调整成BX\KT\SX
IF P_AZIENDA = 'ALL' THEN V_ENTITY := 'ALL';
ELSIF P_AZIENDA <> 'ALL' AND (','||V_AZIENDA||',' LIKE '%,62%' OR ','||V_AZIENDA||',' LIKE '%,68%') THEN V_ENTITY := 'KT';
ELSIF P_AZIENDA <> 'ALL' AND (','||V_AZIENDA||',' LIKE '%,63%' OR ','||V_AZIENDA||',' LIKE '%,67%') THEN V_ENTITY := 'BX';
ELSIF P_AZIENDA <> 'ALL' AND (','||V_AZIENDA||',' LIKE '%,2%' OR ','||V_AZIENDA||',' LIKE '%,163%') THEN V_ENTITY := 'SX';
ELSE V_ENTITY := P_AZIENDA;
END IF
;

  --海信内部公司的三级分类有值时，要限制海信内部公司即对方公司不参与分摊
  SELECT LISTAGG(COD_AZIENDA,',')
  INTO V_AZI_CTP
  FROM TGK_FIMA_HISENSE.AW_RUL_PLCCTP_000001 A
  WHERE A.VALID_FR <= CONCAT(SUBSTR(P_SCENARIO,1,4),P_PERIODO) AND A.VALID_TO >= CONCAT(SUBSTR(P_SCENARIO,1,4),P_PERIODO) ;

  --配件类不参与分摊:通用规则:根据物料对应产品中类为配件的不参与分摊，或物料组1100105(附加产品)、1100107(商显附加产品)不参与分摊
  SELECT LISTAGG(D_PRO_CLASS,',')
  INTO V_PRO_CLASS
  FROM TGK_FIMA_HISENSE.AW_RUL_PROCLS_000001 A ;
  --WHERE A.VALID_FR <= CONCAT(SUBSTR(P_SCENARIO,1,4),P_PERIODO) AND A.VALID_TO > CONCAT(SUBSTR(P_SCENARIO,1,4),P_PERIODO) ;

  --虚拟物料
  SELECT LISTAGG(T.MATERIAL_CODE,',')
  INTO V_MATERIAL
    FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 t
    WHERE T.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
    AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
    AND MATERIAL_CODE IS NOT NULL ;

    -- 记录开始日志
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '0.0 START', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '大系统产销存销售、收入、成本计算开始',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 0.  创建全局临时表-迁移时候运行一次
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- 1.1  缓存政策数据及事业部组织数据
  -----------------------------------------------------------------------------

/*20260806 shiqingfeng.ex 新增将单体前三个月的数据缓存到temp表，将政策分摊的所有的单体表替换为temp表*/
/*
CREATE TABLE AW_MR9_REVM01_000001_CON_TEMP AS
SELECT * FROM AW_MR9_REVM01_000001_CON_TEMP
WHERE 1=2


*/
INSERT INTO AW_MR9_REVM01_000001_CON_TEMP(
OID, COD_SCENARIO, COD_PERIODO, SHOP_CODE, COD_AZIENDA, COD_DEST1, COD_AZI_CTP, D_PRC_GRP, COD_CONTO, D_SALE_DEPT, COD_DEST3, COD_CATEGORIA, D_PRO_CLASS, D_DATA_BLOCK, D_DIFF_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_QUA_METHOD, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_MODEL_LCA, D_PRO_TYPE, SALE_MODEL_NAME, D_POL_CLASS, MODEL_NAME, CUST_CODE, MODEL_CODE, SALE_MODEL_CODE, CUST_NAME, D_CHANNEL, D_MODE, D_ONOFFLINE, D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, D_IND_C_TYPE, D_CNL_C_TYPE, COD_VALUTA, SHIP_QTY, COD_VALUTA_ORIGINARIA, ORDER_QTY, BILL_QTY, SALE_REV, DISCOUNT_3, DISCOUNT_4, DISCOUNT_5, DISCOUNT_6, TAX_RATE, EXCHANGE_RATE, ORG_QTY, MAP_QTY, ORG_REV, MAP_REV, MAP_REV1, MAP_DIS3, MAP_DIS4, MAP_DIS5, MAP_DIS6, POLICY_AMT, BATCH_ID, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, SRC_SYSTEM, SRC_DETAIL, SHOP_NAME, AGENCY_CODE, AGENCY_NAME, IS_MINILED_CODE, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, SALE_COGS, DISCOUNT_1, MAP_DIS1, DISCOUNT_30, DISCOUNT_34, MAP_DIS30, MAP_DIS34, NOTE, D_BU_TRAN, CUSTOMER_MODEL, ORDER_TYPE_CODE, ZCALASSET, CALC_RULE, STATUTORY_ACCT_CODE, MAP_ZUM, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, D_ADJ_TYPE, CHANGE_COEFFICIENT, GFCFY_AMOUNT, GFCFL_AMOUNT, D_OPER_TYPE, BCY_REV, BCY_COGE, BCY_COGS, MATERIAL_GROUP_NAME, ORG_GP, AVG_UNIT_COST, BAC_AZIENDA, BAC_SRC_AZIENDA, MAKTX_S810, BUS_SCE_CAT_CODE, BUS_SCE_CAT_NAME, IS_SMALL_B, IS_SALE, D_BUS_SCE_S, D_MINILED, INVOICE_CODE, ADJ_LEV_2, STD_QTY, ZA_SALE_COGS, AD_SALE_COGS, MA_SALE_COGS, CALC_RULE_1, SH_BF_SALE_COGS
)

 SELECT OID, COD_SCENARIO, COD_PERIODO, SHOP_CODE, COD_AZIENDA, COD_DEST1, COD_AZI_CTP, D_PRC_GRP, COD_CONTO
 , D_SALE_DEPT, COD_DEST3, COD_CATEGORIA, D_PRO_CLASS, D_DATA_BLOCK
 , D_DIFF_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4
 , D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_QUA_METHOD, D_PRO_STAGE
 , D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_MODEL_LCA, D_PRO_TYPE, SALE_MODEL_NAME
 , D_POL_CLASS, MODEL_NAME, CUST_CODE, MODEL_CODE, SALE_MODEL_CODE, CUST_NAME, D_CHANNEL, D_MODE
 , D_ONOFFLINE, D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME
 , D_IND_C_TYPE, D_CNL_C_TYPE, COD_VALUTA, SHIP_QTY, COD_VALUTA_ORIGINARIA, ORDER_QTY, BILL_QTY, SALE_REV
 , DISCOUNT_3, DISCOUNT_4, DISCOUNT_5, DISCOUNT_6, TAX_RATE, EXCHANGE_RATE, ORG_QTY, MAP_QTY, ORG_REV, MAP_REV
 , MAP_REV1, MAP_DIS3, MAP_DIS4, MAP_DIS5, MAP_DIS6
 , POLICY_AMT, BATCH_ID, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE
 , SRC_SYSTEM, SRC_DETAIL, SHOP_NAME, AGENCY_CODE, AGENCY_NAME, IS_MINILED_CODE, PROVENIENZA
 , USERUPD, DATEUPD, EN_VERSION
 , SALE_COGS
 , DISCOUNT_1, MAP_DIS1, DISCOUNT_30, DISCOUNT_34, MAP_DIS30, MAP_DIS34, NOTE, D_BU_TRAN, CUSTOMER_MODEL, ORDER_TYPE_CODE, ZCALASSET, CALC_RULE, STATUTORY_ACCT_CODE, MAP_ZUM, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, D_ADJ_TYPE, CHANGE_COEFFICIENT, GFCFY_AMOUNT, GFCFL_AMOUNT, D_OPER_TYPE, BCY_REV, BCY_COGE, BCY_COGS, MATERIAL_GROUP_NAME, ORG_GP, AVG_UNIT_COST, BAC_AZIENDA, BAC_SRC_AZIENDA, MAKTX_S810, BUS_SCE_CAT_CODE, BUS_SCE_CAT_NAME, IS_SMALL_B, IS_SALE, D_BUS_SCE_S, D_MINILED, INVOICE_CODE, ADJ_LEV_2, STD_QTY, ZA_SALE_COGS, AD_SALE_COGS, MA_SALE_COGS, CALC_RULE_1, SH_BF_SALE_COGS
   FROM TGK_FIMA_HISENSE.AW_MR9_REVM01_000001 T
  WHERE --SUBSTR(T.COD_SCENARIO,1,4) || T.COD_PERIODO IN (v_per0, v_per1, v_per2)
    1=1
    AND (
           (T.COD_SCENARIO = v_per0_ACT
          AND T.COD_PERIODO = v_per0_per
           )
          OR
           (T.COD_SCENARIO = v_per1_ACT
          AND T.COD_PERIODO = v_per1_per
          )
          OR
           (T.COD_SCENARIO = v_per2_ACT
          AND T.COD_PERIODO = v_per2_per
          )
        )
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                    WHERE SESSION_ID = V_SESSION_ID
                    )
    ;




    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '0.1 START', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '单体临时表数据插入完成',P_AZIENDA);
    COMMIT;

    /*20260810-2 shiqingfeng.ex 需排除科目为S6401开头，SALE_COGS=0且SH_BF_SALE_COGS不为0 ---该部分为成本分摊前金额*/
    DELETE FROM AW_MR9_REVM01_000001_CON_TEMP T
      WHERE 1=1
        AND (
               (T.COD_SCENARIO = v_per0_ACT
              AND T.COD_PERIODO = v_per0_per
               )
              OR
               (T.COD_SCENARIO = v_per1_ACT
              AND T.COD_PERIODO = v_per1_per
              )
              OR
               (T.COD_SCENARIO = v_per2_ACT
              AND T.COD_PERIODO = v_per2_per
              )
            )
        AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                        WHERE SESSION_ID = V_SESSION_ID
                        )
        AND (COD_CONTO LIKE 'S6401%' AND SALE_COGS = 0 AND SH_BF_SALE_COGS <> 0)
  ;


    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '0.2 START', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '剔除成本分摊前',P_AZIENDA);
    COMMIT;


    /*20260810-3 shiqingfeng.ex 20260810 SXX补充逻辑【中国区专题】：
                  如果公司范围是中国区公司【公司节点为200】
                  且科目范围为S6401开头
                  则限制业务分类范围在AW_RUL_CNMECL_000001-中国区-其他业务收入范围配置表范围内的才取成本数，其他公司直接取SALE_COGS
    */
    DELETE FROM AW_MR9_REVM01_000001_CON_TEMP T
      WHERE 1=1
        AND (
               (T.COD_SCENARIO = v_per0_ACT
              AND T.COD_PERIODO = v_per0_per
               )
              OR
               (T.COD_SCENARIO = v_per1_ACT
              AND T.COD_PERIODO = v_per1_per
              )
              OR
               (T.COD_SCENARIO = v_per2_ACT
              AND T.COD_PERIODO = v_per2_per
              )
            )
        AND COD_AZIENDA IN (SELECT ELEM
                              FROM SESSION_AZIENDA_LIST A
                             WHERE SESSION_ID = V_SESSION_ID
                               AND EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S WHERE SESSION_ID = V_SESSION_ID AND S.HIE = '10' AND S.NODE = '200' AND A.ELEM = S.ELEM)
                        )
        AND COD_CONTO LIKE 'S6401%'
        AND NOT EXISTS (SELECT D_OPER_TYPE
                    FROM TGK_FIMA_HISENSE.AW_RUL_CNMECL_000001 OPER_MAP
                   WHERE VALID_FR <= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                     AND NVL(VALID_TO,'999999') >= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                     AND OPER_MAP.D_OPER_TYPE = T.D_OPER_TYPE
                  )

  ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '0.3 START', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '中国区-其他业务收入范围配置表范围内的才取成本',P_AZIENDA);
    COMMIT;


    --插入分公司政策数据到临时表
  INSERT INTO TMP_TABLE_POLICY(SESSION_ID,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)
    --非空调
  SELECT
       V_SESSION_ID ,COD_AZIENDA, COD_DEST2, NVL(D_ONOFFLINE,'') D_ONOFFLINE,
        --【20260806 修改v2】1180/12**使用D_ECOM_BU；空/ZZZZ政策保留，待1.4作为未分配政策落表
        CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
             THEN NVL(D_ECOM_BU,'')
             ELSE NVL(D_CHANNEL,'')
         END AS D_CHANNEL, NVL(CUST_CODE,'') CUST_CODE,
        NULL MATERIAL_CODE, NULL COD_AZIENDA_NEW, SUM(POLICY_AMT) POLICY_AMT, NULL STEP_ID, NULL GROUP_ID
    FROM AW_MR9_REVM01_000001_CON_TEMP
   WHERE SRC_DETAIL IN ('POLICY_YT','ADJM01')
     AND COD_CONTO IN ('S6001G5','S6001G5AD')
     AND COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%')
                            --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                         )
     --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
     --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
     AND (MATERIAL_CODE IS NULL OR MATERIAL_CODE = 'ZZZZ')
     /*20260226 新增排除锁定公司*/
     /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                               FROM AW_RUL_DWMCRS_000001 T
                              WHERE REV05_FLAG = 'Y'
                                AND T.COD_SCENARIO = P_SCENARIO
                                AND T.COD_PERIODO = P_PERIODO
                                AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                             )*/
    GROUP BY COD_AZIENDA, COD_DEST2, NVL(D_ONOFFLINE,''),
         CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
              THEN NVL(D_ECOM_BU,'')
              ELSE NVL(D_CHANNEL,'')
          END, NVL(CUST_CODE,'')
    HAVING SUM(POLICY_AMT) <> 0
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '插入分公司政策数据到临时表-非空调', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;


  INSERT INTO TMP_TABLE_POLICY(SESSION_ID,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)

  --空调
    SELECT
         V_SESSION_ID ,COD_AZIENDA, D_SALE_DEPT AS COD_DEST2, NVL(D_ONOFFLINE,'') D_ONOFFLINE,
        CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
             THEN NVL(D_ECOM_BU,'')
             ELSE NVL(D_CHANNEL,'')
         END AS D_CHANNEL, NVL(CUST_CODE,'') CUST_CODE,
        NULL MATERIAL_CODE, NULL COD_AZIENDA_NEW, SUM(POLICY_AMT) POLICY_AMT, NULL STEP_ID, NULL GROUP_ID
    FROM AW_MR9_REVM01_000001_CON_TEMP
   WHERE SRC_DETAIL IN ('POLICY_YT','ADJM01')
     AND COD_CONTO IN ('S6001G5','S6001G5AD')
     AND COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                            --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                         )
     --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
     --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
     AND (MATERIAL_CODE IS NULL OR MATERIAL_CODE = 'ZZZZ')
          /*20260226 新增排除锁定公司*/
     /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                               FROM AW_RUL_DWMCRS_000001 T
                              WHERE REV05_FLAG = 'Y'
                                AND T.COD_SCENARIO = P_SCENARIO
                                AND T.COD_PERIODO = P_PERIODO
                                AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                              )*/
    GROUP BY COD_AZIENDA, D_SALE_DEPT, NVL(D_ONOFFLINE,''),
         CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
              THEN NVL(D_ECOM_BU,'')
              ELSE NVL(D_CHANNEL,'')
          END, NVL(CUST_CODE,'')
    HAVING SUM(POLICY_AMT) <> 0
    ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '插入分公司政策数据到临时表-空调', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --插入公司对应的事业部关系进入临时表
    INSERT INTO TMP_TABLE_ENT(SESSION_ID,COD_CTP, COD_BU)
    SELECT V_SESSION_ID,COD_AZIENDA COD_CTP, 'BX' COD_BU
    FROM AZIENDA
    WHERE COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%'
    ;

    INSERT INTO TMP_TABLE_ENT(SESSION_ID,COD_CTP, COD_BU)
    SELECT V_SESSION_ID,COD_AZIENDA COD_CTP, 'KT' COD_BU
    FROM AZIENDA
    WHERE COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%'
    ;

    INSERT INTO TMP_TABLE_ENT(SESSION_ID,COD_CTP, COD_BU)
    SELECT V_SESSION_ID,COD_AZIENDA COD_CTP, 'SX' COD_BU
    FROM AZIENDA
    WHERE COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%'
    ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '插入公司对应的事业部关系进入临时表', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
  ------------------------------------------------------------------------------
  -- 1.2A  处理分公司及总部线上政策数据
  ------------------------------------------------------------------------------

    --Step1 对所有的政策数据，根据账套+利润中心/业务管理单元+线上线下+客户去收入中进行查找，并标记STEP, GROUP
    UPDATE TMP_TABLE_POLICY M  SET STEP_ID = 'A_STEP1',
                                   GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
     WHERE EXISTS( SELECT 1
                     FROM (
                            --本期的收入中的账套+利润中心+线上线下+客户组合 非空调
                            SELECT COD_AZIENDA, LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, CUST_CODE
                              FROM AW_MR9_REVM01_000001_CON_TEMP
                            LEFT JOIN TMP_TABLE_ENT E
                                   ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                            WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                            WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                            ELSE 'OTH'
                                        END) = E.COD_BU
                                    AND COD_AZI_CTP = E.COD_CTP
                                    AND E.SESSION_ID = V_SESSION_ID
                             WHERE COD_SCENARIO = P_SCENARIO
                               AND COD_PERIODO = P_PERIODO
                               AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                      AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%'
                                                            OR ELEM LIKE '8%' OR ELEM LIKE 'G%')
                                                   )
                               --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                               AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                               --分公司&总公司线上
                               AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600')
                                    OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%')
                                    )
                               --开票收入、出库未开、退货未办且排除国际营销公司
                               AND COD_CONTO LIKE 'S60010%'
                               --AND COD_AZIENDA NOT LIKE '8%'
                               --AND COD_AZIENDA NOT LIKE 'G%'
                               AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                               --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                               AND MAP_REV1 <> 0
                               --剔除虚拟物料
                               AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                               --剔除配件
                               AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                               AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                               --限制内销
                               AND COD_DEST3 LIKE '2%'
                               /*20260226 新增排除锁定公司*/
                               /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                         FROM AW_RUL_DWMCRS_000001 T
                                                        WHERE REV05_FLAG = 'Y'
                                                          AND T.COD_SCENARIO = P_SCENARIO
                                                          AND T.COD_PERIODO = P_PERIODO
                                                          AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                       )*/
                               AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                          GROUP BY COD_AZIENDA, LTRIM(COD_DEST2,'0') , D_ONOFFLINE, CUST_CODE
                            HAVING ROUND(SUM(MAP_REV1),2) <> 0

                           UNION ALL

                            --本期的收入中的账套+利润中心+线上线下+客户组合 空调

                            SELECT COD_AZIENDA, LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, CUST_CODE
                              FROM AW_MR9_REVM01_000001_CON_TEMP
                         LEFT JOIN TMP_TABLE_ENT E
                                ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                         WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                         WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                         ELSE 'OTH'
                                     END) = E.COD_BU
                                 AND COD_AZI_CTP = E.COD_CTP
                                 AND E.SESSION_ID = V_SESSION_ID
                              WHERE COD_SCENARIO = P_SCENARIO
                                AND COD_PERIODO = P_PERIODO
                                AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                   )
                                --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                                AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                                --分公司&总公司线上
                                AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                                --开票收入、出库未开、退货未办且排除国际营销公司
                                AND COD_CONTO LIKE 'S60010%'
                                --AND COD_AZIENDA NOT LIKE '8%'
                                --AND COD_AZIENDA NOT LIKE 'G%'
                                AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                                --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                                AND MAP_REV1 <> 0
                                --剔除虚拟物料
                                AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                                --剔除配件
                                AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                                AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                                --限制内销
                                AND COD_DEST3 LIKE '2%'
                                 /*20260226 新增排除锁定公司*/
                                /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                          FROM AW_RUL_DWMCRS_000001 T
                                                         WHERE REV05_FLAG = 'Y'
                                                           AND T.COD_SCENARIO = P_SCENARIO
                                                           AND T.COD_PERIODO = P_PERIODO
                                                           AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                       )*/
                                AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                           GROUP BY COD_AZIENDA, LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, CUST_CODE
                             HAVING ROUND(SUM(MAP_REV1),2) <> 0
                           ) A1
                      WHERE M.COD_AZIENDA = A1.COD_AZIENDA
                        AND M.COD_DEST2 = A1.COD_DEST2
                        AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                        AND M.CUST_CODE = A1.CUST_CODE
              )
         AND M.SESSION_ID = V_SESSION_ID
         AND M.STEP_ID IS NULL
         
         AND (M.COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (M.COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND M.D_ONOFFLINE LIKE '020_ON%'))
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-update-A_STEP1', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --Step2 对没有匹配到的政策数据，根据滚动季度(上2个月中)账套+利润中心/业务范围+线上线下+客户去收入中进行查找前20物料，并标记STEP, GROUP
    --打标记
    UPDATE TMP_TABLE_POLICY M SET STEP_ID = 'A_STEP2_READY',
                                  GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
    WHERE EXISTS (SELECT 1
                    FROM (
                          SELECT COD_AZIENDA, LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE
                            FROM (
                                  SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE,
                                         ROW_NUMBER() OVER(PARTITION BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE ORDER BY REV DESC) RN
                                    FROM (
                                           --非空调
                                           SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, ROUND(SUM(MAP_REV1),2) REV
                                             FROM AW_MR9_REVM01_000001_CON_TEMP
                                        LEFT JOIN TMP_TABLE_ENT E
                                               ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                                        WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                                        WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                                        ELSE 'OTH'
                                                    END) = E.COD_BU
                                               AND COD_AZI_CTP = E.COD_CTP
                                               AND E.SESSION_ID = V_SESSION_ID
                                             WHERE --SUBSTR(COD_SCENARIO,1,4) || COD_PERIODO IN (v_per1, v_per2)
                                               1=1
                                              AND (
                                                  (COD_SCENARIO = v_per1_ACT
                                                  AND COD_PERIODO = v_per1_per
                                                  )
                                                  OR
                                                  (COD_SCENARIO = v_per2_ACT
                                                  AND COD_PERIODO = v_per2_per
                                                  )
                                                )
                                              AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                                          WHERE SESSION_ID = V_SESSION_ID
                                                                            --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                                            AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%'
                                                                                  OR ELEM LIKE '8%' OR ELEM LIKE 'G%')
                                                                        )
                                               --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                                               AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                                               AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                                               --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                                               AND COD_CONTO LIKE 'S60010%'
                                               --AND COD_AZIENDA NOT LIKE '8%'
                                               --AND COD_AZIENDA NOT LIKE 'G%'
                                               AND (CUST_CODE IS NOT NULL AND CUST_CODE <> 'ZZZZ')
                                               AND (MATERIAL_CODE IS NOT NULL AND MATERIAL_CODE <> 'ZZZZ')
                                               --剔除虚拟物料
                                               AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                                               --剔除配件
                                               AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                                               AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                                               --限制内销
                                               AND COD_DEST3 LIKE '2%'
                                               AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                                               /*20260226 新增排除锁定公司*/
                                               /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                                         FROM AW_RUL_DWMCRS_000001 T
                                                                        WHERE REV05_FLAG = 'Y'
                                                                          AND T.COD_SCENARIO = P_SCENARIO
                                                                          AND T.COD_PERIODO = P_PERIODO
                                                                          AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                                        )*/
                                              AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                                         GROUP BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE

                                          UNION ALL
                                          --空调
                                          SELECT COD_AZIENDA, D_SALE_DEPT AS COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, ROUND(SUM(MAP_REV1),2) REV
                                            FROM AW_MR9_REVM01_000001_CON_TEMP
                                       LEFT JOIN TMP_TABLE_ENT E
                                              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                                       ELSE 'OTH'
                                                   END) = E.COD_BU
                                              AND COD_AZI_CTP = E.COD_CTP
                                              AND E.SESSION_ID = V_SESSION_ID
                                            WHERE --SUBSTR(COD_SCENARIO,1,4) || COD_PERIODO IN (v_per1, v_per2)
                                              1=1
                                              AND (
                                                  ( COD_SCENARIO = v_per1_ACT
                                                  AND COD_PERIODO = v_per1_per
                                                  )
                                                  OR
                                                  (COD_SCENARIO = v_per2_ACT
                                                  AND COD_PERIODO = v_per2_per
                                                  )
                                                )
                                              AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                                          WHERE SESSION_ID = V_SESSION_ID
                                                                            AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                                            --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                                        )
                                              --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                                              AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                                              AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                                              --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                                              AND COD_CONTO LIKE 'S60010%'
                                              --AND COD_AZIENDA NOT LIKE '8%'
                                              --AND COD_AZIENDA NOT LIKE 'G%'
                                              AND (CUST_CODE IS NOT NULL AND CUST_CODE <> 'ZZZZ')
                                              AND (MATERIAL_CODE IS NOT NULL AND MATERIAL_CODE <> 'ZZZZ')
                                              --剔除虚拟物料
                                              AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                                              --剔除配件
                                              AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                                              AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                                              --限制内销
                                              AND COD_DEST3 LIKE '2%'
                                              AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                                              /*20260226 新增排除锁定公司*/
                                              /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                                        FROM AW_RUL_DWMCRS_000001 T
                                                                       WHERE REV05_FLAG = 'Y'
                                                                         AND T.COD_SCENARIO = P_SCENARIO
                                                                         AND T.COD_PERIODO = P_PERIODO
                                                                         AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                                      )*/
                                              AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                                         GROUP BY COD_AZIENDA, D_SALE_DEPT, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE
                                        ) T
                                   WHERE T.REV <> 0
                                  ) TT
                           WHERE RN <= 20
                      )A1
                WHERE M.COD_AZIENDA = A1.COD_AZIENDA
                  AND M.COD_DEST2 = A1.COD_DEST2
                  AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                  AND M.CUST_CODE = A1.CUST_CODE
                )
                AND M.SESSION_ID = V_SESSION_ID
                AND M.STEP_ID IS NULL
                AND (M.COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (M.COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND M.D_ONOFFLINE LIKE '020_ON%'))
 ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-update-A_STEP2_READY', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --扩展物料编码
    INSERT INTO TMP_TABLE_POLICY(SESSION_ID,D_CHANNEL,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)
    SELECT
        DISTINCT V_SESSION_ID,M.D_CHANNEL,M.COD_AZIENDA, M.COD_DEST2, M.D_ONOFFLINE, M.CUST_CODE, A1.MATERIAL_CODE, NULL COD_AZIENDA_NEW, M.POLICY_AMT, 'A_STEP2' STEP_ID, M.GROUP_ID
    FROM TMP_TABLE_POLICY M
    JOIN (
          SELECT COD_AZIENDA, LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE
            FROM (
                  SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE,
                         ROW_NUMBER() OVER(PARTITION BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE ORDER BY REV DESC) RN
                    FROM (
                            --非空调
                            SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, ROUND(SUM(MAP_REV1),2) REV
                              FROM AW_MR9_REVM01_000001_CON_TEMP
                         LEFT JOIN TMP_TABLE_ENT E
                               ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                        WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                        WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                        ELSE 'OTH'
                                     END) = E.COD_BU
                               AND COD_AZI_CTP = E.COD_CTP
                               AND E.SESSION_ID = V_SESSION_ID
                             WHERE /* SUBSTR(COD_SCENARIO,1,4) || COD_PERIODO IN (v_per1, v_per2) */
                               1=1
                               AND (
                                      (COD_SCENARIO = v_per1_ACT
                                      AND COD_PERIODO = v_per1_per
                                      )
                                      OR
                                      (COD_SCENARIO = v_per2_ACT
                                      AND COD_PERIODO = v_per2_per
                                      )
                                    )
                               AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                      AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%'
                                                             OR ELEM LIKE '8%' OR ELEM LIKE 'G%')
                                                   )
                               --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                               AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                               AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                               --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                               AND COD_CONTO LIKE 'S60010%'
                               --AND COD_AZIENDA NOT LIKE '8%'
                               --AND COD_AZIENDA NOT LIKE 'G%'
                               AND (CUST_CODE IS NOT NULL AND CUST_CODE <> 'ZZZZ')
                               AND (MATERIAL_CODE IS NOT NULL AND MATERIAL_CODE <> 'ZZZZ')
                               --剔除虚拟物料
                               AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                               --剔除配件
                               AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                               AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                               --限制内销
                               AND COD_DEST3 LIKE '2%'
                               AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                               /*20260226 新增排除锁定公司*/
                               /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                         FROM AW_RUL_DWMCRS_000001 T
                                                        WHERE REV05_FLAG = 'Y'
                                                          AND T.COD_SCENARIO = P_SCENARIO
                                                          AND T.COD_PERIODO = P_PERIODO
                                                          AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                       )*/
                              AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                         GROUP BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE

                      UNION ALL
                          --空调
                          SELECT COD_AZIENDA, D_SALE_DEPT AS COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, ROUND(SUM(MAP_REV1),2) REV
                            FROM AW_MR9_REVM01_000001_CON_TEMP
                       LEFT JOIN TMP_TABLE_ENT E
                              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                       ELSE 'OTH'
                                   END) = E.COD_BU
                             AND COD_AZI_CTP = E.COD_CTP
                             AND E.SESSION_ID = V_SESSION_ID
                           WHERE /* SUBSTR(COD_SCENARIO,1,4) || COD_PERIODO IN (v_per1, v_per2) */
                             1=1
                             AND (
                                    (COD_SCENARIO = v_per1_ACT
                                    AND COD_PERIODO = v_per1_per
                                    )
                                    OR
                                    (COD_SCENARIO = v_per2_ACT
                                    AND COD_PERIODO = v_per2_per
                                    )
                                  )
                             AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                   )
                             --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                             AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                             AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                             --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                             AND COD_CONTO LIKE 'S60010%'
                             --AND COD_AZIENDA NOT LIKE '8%'
                             --AND COD_AZIENDA NOT LIKE 'G%'
                             AND (CUST_CODE IS NOT NULL AND CUST_CODE <> 'ZZZZ')
                             AND (MATERIAL_CODE IS NOT NULL AND MATERIAL_CODE <> 'ZZZZ')
                             --剔除虚拟物料
                             AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                             --剔除配件
                             AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                             AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                             --限制内销
                             AND COD_DEST3 LIKE '2%'
                             AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                             /*20260226 新增排除锁定公司*/
                             /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                       FROM AW_RUL_DWMCRS_000001 T
                                                      WHERE REV05_FLAG = 'Y'
                                                        AND T.COD_SCENARIO = P_SCENARIO
                                                        AND T.COD_PERIODO = P_PERIODO
                                                        AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                      )*/
                            AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                       GROUP BY COD_AZIENDA, D_SALE_DEPT, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE
                     ) T
                  WHERE T.REV <> 0
                ) TT
           WHERE RN <= 20
         ) A1
      ON M.COD_AZIENDA = A1.COD_AZIENDA
     AND M.COD_DEST2 = A1.COD_DEST2
     AND M.D_ONOFFLINE = A1.D_ONOFFLINE
     AND M.CUST_CODE = A1.CUST_CODE
   WHERE M.STEP_ID IN ('A_STEP2_READY')
   AND M.SESSION_ID = V_SESSION_ID
   ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-update-扩展物料编码', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

    --剔除原来STEP2的准备记录
    DELETE FROM TMP_TABLE_POLICY M WHERE M.STEP_ID IN ('A_STEP2_READY') AND M.SESSION_ID = V_SESSION_ID;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-剔除原来STEP2的准备记录', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

    --Step3 对所有的政策数据，根据账套+利润中心+线上线下+渠道去收入中进行查找，并标记STEP, GROUP
    UPDATE TMP_TABLE_POLICY M SET STEP_ID = 'A_STEP3',
                                  GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
    WHERE EXISTS(SELECT 1
                  FROM (
                        --非空调
                        SELECT DISTINCT COD_AZIENDA, LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE,
                               --【20260806 修改v2】收入端按D_ECOM_BU匹配；空/ZZZZ在WHERE中排除
                               CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                    THEN D_ECOM_BU
                                    ELSE D_CHANNEL
                                END AS D_CHANNEL
                          FROM AW_MR9_REVM01_000001_CON_TEMP
                     LEFT JOIN TMP_TABLE_ENT E
                            ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                     WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                     WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                    ELSE 'OTH'
                                 END) = E.COD_BU
                            AND COD_AZI_CTP = E.COD_CTP
                            AND E.SESSION_ID = V_SESSION_ID
                          WHERE COD_SCENARIO = P_SCENARIO
                            AND COD_PERIODO = P_PERIODO
                            AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                      AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%'
                                                             OR ELEM LIKE '8%' OR ELEM LIKE 'G%')
                                                   )
                            --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                            AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                            AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                            --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                            AND COD_CONTO LIKE 'S60010%'
                            --AND COD_AZIENDA NOT LIKE '8%'
                            --AND COD_AZIENDA NOT LIKE 'G%'
                            AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                            AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
                            --剔除虚拟物料
                            AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                            --剔除配件
                            AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                            AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                            --【20260806 修改v2】D_ECOM_BU为空或ZZZZ时不打A_STEP3，自然落入1.4未分配政策
                            AND NOT ((COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                     AND NVL(D_ECOM_BU,'ZZZZ') = 'ZZZZ')
                            --限制内销
                            AND COD_DEST3 LIKE '2%'
                            /*20260226 新增排除锁定公司*/
                            AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                      FROM AW_RUL_DWMCRS_000001 T
                                                     WHERE REV05_FLAG = 'Y'
                                                       AND T.COD_SCENARIO = P_SCENARIO
                                                       AND T.COD_PERIODO = P_PERIODO
                                                       AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                   )
                           AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                          GROUP BY COD_AZIENDA, LTRIM(COD_DEST2,'0'), D_ONOFFLINE,
                               CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                    THEN D_ECOM_BU
                                    ELSE D_CHANNEL
                                END
                        HAVING ROUND(SUM(MAP_REV1),2) <> 0

                    UNION ALL
                        --空调
                        SELECT DISTINCT COD_AZIENDA, LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE,
                               CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                    THEN D_ECOM_BU
                                    ELSE D_CHANNEL
                                END AS D_CHANNEL
                          FROM AW_MR9_REVM01_000001_CON_TEMP
                     LEFT JOIN TMP_TABLE_ENT E
                          ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                   WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                   WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                  ELSE 'OTH'
                               END) = E.COD_BU
                         AND COD_AZI_CTP = E.COD_CTP
                         AND E.SESSION_ID = V_SESSION_ID
                       WHERE COD_SCENARIO = P_SCENARIO
                         AND COD_PERIODO = P_PERIODO
                         AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                   )
                         --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                         AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                         AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                         --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                         AND COD_CONTO LIKE 'S60010%'
                         --AND COD_AZIENDA NOT LIKE '8%'
                         --AND COD_AZIENDA NOT LIKE 'G%'
                         AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                         AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
                         --剔除虚拟物料
                         AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                         --剔除配件
                         AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                         AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                         --限制内销
                         AND COD_DEST3 LIKE '2%'
                         /*20260226 新增排除锁定公司*/
                         /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                   FROM AW_RUL_DWMCRS_000001 T
                                                  WHERE REV05_FLAG = 'Y'
                                                    AND T.COD_SCENARIO = P_SCENARIO
                                                    AND T.COD_PERIODO = P_PERIODO
                                                    AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                  )*/
                         AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                    GROUP BY COD_AZIENDA, LTRIM(D_SALE_DEPT,'0'), D_ONOFFLINE,
                             CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                  THEN D_ECOM_BU
                                  ELSE D_CHANNEL
                              END
                      HAVING ROUND(SUM(MAP_REV1),2) <> 0
                     ) A1
              WHERE M.COD_AZIENDA = A1.COD_AZIENDA
                AND M.COD_DEST2 = A1.COD_DEST2
                AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                AND M.D_CHANNEL = A1.D_CHANNEL
            )
           AND M.SESSION_ID = V_SESSION_ID
           AND M.STEP_ID IS NULL
           AND (M.COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (M.COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND M.D_ONOFFLINE LIKE '020_ON%'))
;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-update-A_STEP3', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 1.2B  处理总公司线下政策数据
  ------------------------------------------------------------------------------
    --Step1 对所有的政策数据，根据账套+利润中心+线上线下+渠道+客户去收入中进行查找，并标记STEP, GROUP
    --打标记
    UPDATE TMP_TABLE_POLICY M SET STEP_ID = 'B_STEP1_READY',
                                  GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
    WHERE EXISTS(SELECT 1
                   FROM (
                        --非空调
                        SELECT DISTINCT
                               CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                    WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                    WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                END AS COD_AZIENDA,
                                LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE
                                ,D_CHANNEL, CUST_CODE
                        FROM AW_MR9_REVM01_000001_CON_TEMP
                   LEFT JOIN TMP_TABLE_ENT E
                          ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                   WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                   WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                   ELSE 'OTH'
                               END) = E.COD_BU
                          AND COD_AZI_CTP = E.COD_CTP
                          AND E.SESSION_ID = V_SESSION_ID
                        WHERE COD_SCENARIO = P_SCENARIO
                          AND COD_PERIODO = P_PERIODO
                          AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      AND (ELEM LIKE '63%' OR ELEM LIKE '67%' OR ELEM LIKE '2%')
                                                   )
                          --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
                          AND D_ONOFFLINE LIKE '020_OFF%'
                          --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                          AND COD_CONTO LIKE 'S60010%'
                          --AND COD_AZIENDA NOT LIKE '8%'
                          --AND COD_AZIENDA NOT LIKE 'G%'
                          AND  ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                          --剔除虚拟物料
                          AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                          --剔除配件
                          AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                          AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                          --限制内销
                          AND COD_DEST3 LIKE '2%'
                          AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                     GROUP BY CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                   WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                   WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                               END,
                               LTRIM(COD_DEST2,'0') , D_ONOFFLINE
                               ,D_CHANNEL, CUST_CODE
                       HAVING ROUND(SUM(MAP_REV1),2) <> 0

                      UNION ALL
                        --空调
                        SELECT DISTINCT
                               CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                    WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                    WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                END AS COD_AZIENDA,
                                LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
                        FROM AW_MR9_REVM01_000001_CON_TEMP
                   LEFT JOIN TMP_TABLE_ENT E
                          ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                   WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                   WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                   ELSE 'OTH'
                              END) = E.COD_BU
                         AND COD_AZI_CTP = E.COD_CTP
                         AND E.SESSION_ID = V_SESSION_ID
                       WHERE COD_SCENARIO = P_SCENARIO
                         AND COD_PERIODO = P_PERIODO
                         AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                   )
                         --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
                         AND D_ONOFFLINE LIKE '020_OFF%'
                         --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                         AND COD_CONTO LIKE 'S60010%'
                         --AND COD_AZIENDA NOT LIKE '8%'
                         --AND COD_AZIENDA NOT LIKE 'G%'
                         AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                         --剔除虚拟物料
                         AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                         --剔除配件
                         AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                         AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                         --限制内销
                         AND COD_DEST3 LIKE '2%'
                         AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                        GROUP BY CASE
                                    WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                    WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                    WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                 END ,
                                LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
                         HAVING ROUND(SUM(MAP_REV1),2) <> 0
                      ) A1
                  WHERE (CASE WHEN M.COD_AZIENDA IN ('2000','2300','2600') THEN '2600' ELSE M.COD_AZIENDA END) = A1.COD_AZIENDA
                    AND M.COD_DEST2 = A1.COD_DEST2
                    AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                    AND M.D_CHANNEL = A1.D_CHANNEL
                    AND M.CUST_CODE = A1.CUST_CODE
              )
             AND M.SESSION_ID = V_SESSION_ID
             AND M.STEP_ID IS NULL
             AND M.COD_AZIENDA IN ('6700','6800','2000','2300','2600')
             AND M.D_ONOFFLINE LIKE '020_OFF%'
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-update-B_STEP1_READY', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

    --扩展账套编码
    INSERT INTO TMP_TABLE_POLICY(SESSION_ID,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)
    SELECT
        DISTINCT V_SESSION_ID,M.COD_AZIENDA, M.COD_DEST2, M.D_ONOFFLINE, M.D_CHANNEL, M.CUST_CODE, NULL MATERIAL_CODE, A1.COD_AZIENDA_NEW, M.POLICY_AMT, 'B_STEP1' STEP_ID, M.GROUP_ID
    FROM TMP_TABLE_POLICY M
    JOIN (
          --非空调
          SELECT DISTINCT COD_AZIENDA COD_AZIENDA_NEW,
                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                  END AS COD_AZIENDA,
                  LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
             FROM AW_MR9_REVM01_000001_CON_TEMP
        LEFT JOIN TMP_TABLE_ENT E
               ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                        WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                        WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                        ELSE 'OTH'
                    END) = E.COD_BU
              AND COD_AZI_CTP = E.COD_CTP
              AND E.SESSION_ID = V_SESSION_ID
             WHERE COD_SCENARIO = P_SCENARIO
               AND COD_PERIODO = P_PERIODO
               AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '63%' OR ELEM LIKE '67%' OR ELEM LIKE '2%')
                                   )
               --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
               AND D_ONOFFLINE LIKE '020_OFF%'
               --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
               AND COD_CONTO LIKE 'S60010%'
               --AND COD_AZIENDA NOT LIKE '8%'
               --AND COD_AZIENDA NOT LIKE 'G%'
               AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
               --剔除虚拟物料
               AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
               --剔除配件
               AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
               AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
               --限制内销
               AND COD_DEST3 LIKE '2%'
               AND NVL(SRC_DETAIL,'|') <> 'REVM01'
          GROUP BY COD_AZIENDA ,
                   CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                        WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                        WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                   END ,
                  LTRIM(COD_DEST2,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
           HAVING ROUND(SUM(MAP_REV1),2) <> 0

          UNION ALL

              --非空调
          SELECT DISTINCT COD_AZIENDA COD_AZIENDA_NEW,
                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                  END AS COD_AZIENDA,
                  LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
            FROM AW_MR9_REVM01_000001_CON_TEMP
       LEFT JOIN TMP_TABLE_ENT E
              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                       ELSE 'OTH'
                   END) = E.COD_BU
             AND COD_AZI_CTP = E.COD_CTP
             AND E.SESSION_ID = V_SESSION_ID
           WHERE COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
             AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                   )
             --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
             AND D_ONOFFLINE LIKE '020_OFF%'
             --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
             AND COD_CONTO LIKE 'S60010%'
             --AND COD_AZIENDA NOT LIKE '8%'
             --AND COD_AZIENDA NOT LIKE 'G%'
             AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
             --剔除虚拟物料
             AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
             --剔除配件
             AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
             AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
             --限制内销
             AND COD_DEST3 LIKE '2%'
             AND NVL(SRC_DETAIL,'|') <> 'REVM01'
        GROUP BY COD_AZIENDA ,
                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                  END ,
                  LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
         HAVING ROUND(SUM(MAP_REV1),2) <> 0
        ) A1
       ON CASE WHEN M.COD_AZIENDA IN ('2000','2300','2600') THEN '2600' ELSE M.COD_AZIENDA END = A1.COD_AZIENDA
      AND M.COD_DEST2 = A1.COD_DEST2
      AND M.D_ONOFFLINE = A1.D_ONOFFLINE
      AND M.D_CHANNEL = A1.D_CHANNEL
      AND M.CUST_CODE = A1.CUST_CODE
    WHERE M.STEP_ID IN ('B_STEP1_READY')
      AND M.SESSION_ID = V_SESSION_ID
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-扩展账套编码', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --剔除原来STEP1的准备记录
    DELETE FROM TMP_TABLE_POLICY M WHERE M.STEP_ID IN ('B_STEP1_READY') AND M.SESSION_ID = V_SESSION_ID;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-剔除原来STEP1的准备记录', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --Step2 对所有的政策数据，根据账套+利润中心+线上线下+渠道去收入中进行查找，并标记STEP, GROUP
    --打标记
    UPDATE TMP_TABLE_POLICY M SET STEP_ID = 'B_STEP2_READY',
                                  GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
    WHERE EXISTS( SELECT 1
                    FROM (
                          --非空调
                          SELECT DISTINCT
                                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                 END AS COD_AZIENDA,
                                 LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL
                            FROM AW_MR9_REVM01_000001_CON_TEMP
                       LEFT JOIN TMP_TABLE_ENT E
                              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                       ELSE 'OTH'
                                   END) = E.COD_BU
                              AND COD_AZI_CTP = E.COD_CTP
                              AND E.SESSION_ID = V_SESSION_ID
                            WHERE COD_SCENARIO = P_SCENARIO
                              AND COD_PERIODO = P_PERIODO
                              AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '63%' OR ELEM LIKE '67%' OR ELEM LIKE '2%')
                                   )
                              --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
                              AND D_ONOFFLINE LIKE '020_OFF%'
                              --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                              AND COD_CONTO LIKE 'S60010%'
                              --AND COD_AZIENDA NOT LIKE '8%'
                              --AND COD_AZIENDA NOT LIKE 'G%'
                              AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                              AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
                              --剔除虚拟物料
                              AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                              --剔除配件
                              AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                              AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                              --限制内销
                              AND COD_DEST3 LIKE '2%'
                              AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                         GROUP BY CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                       WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                       WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                   END ,
                                  LTRIM(COD_DEST2,'0') , D_ONOFFLINE, D_CHANNEL
                          HAVING ROUND(SUM(MAP_REV1),2) <> 0

                          UNION ALL
                          --空调
                          SELECT DISTINCT
                                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                  END AS COD_AZIENDA,
                                  LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL
                            FROM AW_MR9_REVM01_000001_CON_TEMP
                      LEFT JOIN TMP_TABLE_ENT E
                             ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                      WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                      WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                      ELSE 'OTH'
                                  END) = E.COD_BU
                            AND COD_AZI_CTP = E.COD_CTP
                            AND E.SESSION_ID = V_SESSION_ID
                          WHERE COD_SCENARIO = P_SCENARIO
                            AND COD_PERIODO = P_PERIODO
                            AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                   )
                            --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
                            AND D_ONOFFLINE LIKE '020_OFF%'
                            --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                            AND COD_CONTO LIKE 'S60010%'
                            --AND COD_AZIENDA NOT LIKE '8%'
                            --AND COD_AZIENDA NOT LIKE 'G%'
                            AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                            AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
                            --剔除虚拟物料
                            AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                            --剔除配件
                            AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                            AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                            --限制内销
                            AND COD_DEST3 LIKE '2%'
                            AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                        GROUP BY CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                 END ,
                                 LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, D_CHANNEL
                          HAVING ROUND(SUM(MAP_REV1),2) <> 0
                        ) A1
                    WHERE CASE WHEN M.COD_AZIENDA IN ('2000','2300','2600') THEN '2600' ELSE M.COD_AZIENDA END = A1.COD_AZIENDA
                      AND M.COD_DEST2 = A1.COD_DEST2
                      AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                      AND M.D_CHANNEL = A1.D_CHANNEL
             )
            AND M.SESSION_ID = V_SESSION_ID
            AND M.STEP_ID IS NULL
            AND M.COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND M.D_ONOFFLINE LIKE '020_OFF%'
 ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-B_STEP2_READY', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

    
    --扩展账套编码
    INSERT INTO TMP_TABLE_POLICY(SESSION_ID,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)
    SELECT
        DISTINCT V_SESSION_ID,M.COD_AZIENDA, M.COD_DEST2, M.D_ONOFFLINE, M.D_CHANNEL, M.CUST_CODE, NULL MATERIAL_CODE, A1.COD_AZIENDA_NEW, M.POLICY_AMT, 'B_STEP2' STEP_ID, M.GROUP_ID
    FROM TMP_TABLE_POLICY M
    JOIN
          (
          --非空调
          SELECT DISTINCT
                 COD_AZIENDA COD_AZIENDA_NEW,
                 CASE
                     WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                     WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                     WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                 END AS COD_AZIENDA,
                 LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
            FROM AW_MR9_REVM01_000001_CON_TEMP
       LEFT JOIN TMP_TABLE_ENT E
              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                       ELSE 'OTH'
                   END) = E.COD_BU
             AND COD_AZI_CTP = E.COD_CTP
             AND E.SESSION_ID = V_SESSION_ID
           WHERE COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
             AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '63%' OR ELEM LIKE '67%' OR ELEM LIKE '2%')
                                   )
             --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
             AND D_ONOFFLINE LIKE '020_OFF%'
             --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
             AND COD_CONTO LIKE 'S60010%'
             --AND COD_AZIENDA NOT LIKE '8%'
             --AND COD_AZIENDA NOT LIKE 'G%'
             AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
             AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
             --剔除虚拟物料
             AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
             --剔除配件
             AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
             AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
             --限制内销
             AND COD_DEST3 LIKE '2%'
             AND NVL(SRC_DETAIL,'|') <> 'REVM01'
        GROUP BY COD_AZIENDA ,
                 CASE
                     WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                     WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                     WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                 END ,
                 LTRIM(COD_DEST2,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
         HAVING ROUND(SUM(MAP_REV1),2) <> 0

         UNION ALL
          --空调
          SELECT DISTINCT
                 COD_AZIENDA COD_AZIENDA_NEW,
                 CASE
                     WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                     WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                     WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                 END AS COD_AZIENDA,
                 LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
            FROM AW_MR9_REVM01_000001_CON_TEMP
       LEFT JOIN TMP_TABLE_ENT E
              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                       ELSE 'OTH'
                   END) = E.COD_BU
             AND COD_AZI_CTP = E.COD_CTP
             AND E.SESSION_ID = V_SESSION_ID
           WHERE COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
             AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                   )
             --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
             AND D_ONOFFLINE LIKE '020_OFF%'
             --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
             AND COD_CONTO LIKE 'S60010%'
             --AND COD_AZIENDA NOT LIKE '8%'
             --AND COD_AZIENDA NOT LIKE 'G%'
             AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
             AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
             --剔除虚拟物料
             AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
             --剔除配件
             AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
             AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
             --限制内销
             AND COD_DEST3 LIKE '2%'
             AND NVL(SRC_DETAIL,'|') <> 'REVM01'
        GROUP BY COD_AZIENDA ,
                 CASE
                     WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                     WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                     WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                 END ,
                 LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
         HAVING ROUND(SUM(MAP_REV1),2) <> 0
        ) A1
    ON (CASE WHEN M.COD_AZIENDA IN ('2000','2300','2600') THEN '2600' ELSE M.COD_AZIENDA END) = A1.COD_AZIENDA
   AND M.COD_DEST2 = A1.COD_DEST2
   AND M.D_ONOFFLINE = A1.D_ONOFFLINE
   AND M.D_CHANNEL = A1.D_CHANNEL
 WHERE M.STEP_ID IN ('B_STEP2_READY')
 AND M.SESSION_ID = V_SESSION_ID
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-扩展账套编码', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --剔除原来STEP2的准备记录
    DELETE FROM TMP_TABLE_POLICY M
    WHERE M.STEP_ID IN ('B_STEP2_READY') 
    AND M.SESSION_ID = V_SESSION_ID;

    -- 1.2 总分公司政策分摊与收入匹配完成
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.2 总分公司政策分摊与收入匹配完成',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 1.3  生成政策分摊数据
  ------------------------------------------------------------------------------

    --在每条收入明细上，生成对应的分摊数据
    INSERT INTO TMP_TABLE_POLICY_ALLOC(SESSION_ID,OID,STEP_ID,GROUP_ID,MAP_REV1,POLICY_AMT,POLICY_ALC_AMT
                                       ,BL,MAX_ABS_BL)
    SELECT
        V_SESSION_ID,OID, STEP_ID, GROUP_ID, MAP_REV1, POLICY_AMT
        /*20260714 shiqingfeng.ex 如果组内任意一行的分摊比例绝对值>10，则整组不参与分摊*/
        , POLICY_AMT*CASE WHEN MAX_ABS_BL > 10 THEN 0 ELSE BL END AS POLICY_ALC_AMT
        , BL
        , MAX_ABS_BL
    FROM(
      SELECT T2.*,
             -- 组内最大绝对比例，用于判断整组是否排除
             MAX(ABS(T2.BL)) OVER(PARTITION BY T2.STEP_ID, T2.GROUP_ID) AS MAX_ABS_BL
       FROM(
          SELECT
                A1.STEP_ID, A1.GROUP_ID, M.OID,
                M.MAP_REV1,
                A1.POLICY_AMT,
                CASE
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) <> 0
                    THEN M.MAP_REV1/SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) = 0 AND M.MAP_REV1 > 0
                    THEN (CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END)/SUM(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                END BL/*,
                CASE
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) <> 0
                    THEN A1.POLICY_AMT*M.MAP_REV1/SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) = 0 AND M.MAP_REV1 > 0
                    THEN A1.POLICY_AMT*(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END)/SUM(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                END AS POLICY_ALC_AMT*/
           FROM (
                  SELECT OID, COD_SCENARIO, COD_PERIODO, COD_AZIENDA,
                         (CASE WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN D_SALE_DEPT ELSE COD_DEST2 END) AS COD_DEST2,
                         --【20260806 修改v2】1180/12**收入明细按D_ECOM_BU与政策匹配
                         D_ONOFFLINE,
                         CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                              THEN D_ECOM_BU
                              ELSE D_CHANNEL
                          END AS D_CHANNEL,
                         CUST_CODE, MATERIAL_CODE, COD_AZI_CTP,MAP_REV1
                   FROM AW_MR9_REVM01_000001_CON_TEMP T
                  WHERE --SUBSTR(T.COD_SCENARIO,1,4) || T.COD_PERIODO IN (v_per0, v_per1, v_per2)
                    1=1
                    AND (
                           (T.COD_SCENARIO = v_per0_ACT
                          AND T.COD_PERIODO = v_per0_per
                           )
                          OR
                           (T.COD_SCENARIO = v_per1_ACT
                          AND T.COD_PERIODO = v_per1_per
                          )
                          OR
                           (T.COD_SCENARIO = v_per2_ACT
                          AND T.COD_PERIODO = v_per2_per
                          )
                        )
                    AND T.COD_CONTO LIKE 'S60010%'
                    --AND T.COD_AZIENDA NOT LIKE '8%'
                    --AND T.COD_AZIENDA NOT LIKE 'G%'
                    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND ELEM NOT LIKE '8%'
                                      AND ELEM NOT LIKE 'G%'
                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                    )
                    AND INSTR(V_HITACHI_AZIENDA,T.COD_AZIENDA) = 0
                    AND T.MAP_REV1 <> 0
                    --剔除虚拟物料
                    AND INSTR(V_MATERIAL, T.MATERIAL_CODE) = 0
                    --剔除配件
                    AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                    AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                    --限制内销
                    AND COD_DEST3 LIKE '2%'
                    AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                ) M
           JOIN (
                SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL,
                       CASE WHEN STEP_ID IN ('A_STEP3','B_STEP2') THEN NULL ELSE CUST_CODE END CUST_CODE,
                       CASE WHEN STEP_ID IN ('A_STEP2') THEN MATERIAL_CODE ELSE NULL END MATERIAL_CODE,
                       CASE WHEN STEP_ID IN ('B_STEP1','B_STEP2') THEN COD_AZIENDA_NEW ELSE NULL END COD_AZIENDA_NEW,
                       SUM(POLICY_AMT) POLICY_AMT,
                       STEP_ID,GROUP_ID
                  FROM TMP_TABLE_POLICY
                 WHERE SESSION_ID = V_SESSION_ID
                   AND STEP_ID IS NOT NULL
              GROUP BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL,
                       CASE WHEN STEP_ID IN ('A_STEP3','B_STEP2') THEN NULL ELSE CUST_CODE END ,
                       CASE WHEN STEP_ID IN ('A_STEP2') THEN MATERIAL_CODE ELSE NULL END ,
                       CASE WHEN STEP_ID IN ('B_STEP1','B_STEP2') THEN COD_AZIENDA_NEW ELSE NULL END,
                       STEP_ID,GROUP_ID
                ) A1
             ON ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
                 /*M.COD_SCENARIO = v_per0_ACT AND M.COD_PERIODO = v_per0_per*/
                 AND A1.STEP_ID IN ('A_STEP1') AND M.COD_AZIENDA = A1.COD_AZIENDA AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.CUST_CODE = A1.CUST_CODE)
             OR ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per1, v_per2)
                  /*(M.COD_SCENARIO = v_per1_ACT AND M.COD_PERIODO = v_per1_per
                   OR M.COD_SCENARIO = v_per2_ACT AND M.COD_PERIODO = v_per2_per)*/
                 AND A1.STEP_ID IN ('A_STEP2') AND M.COD_AZIENDA = A1.COD_AZIENDA AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.CUST_CODE = A1.CUST_CODE AND M.MATERIAL_CODE = A1.MATERIAL_CODE)
             OR ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
                  /*M.COD_SCENARIO = v_per0_ACT AND M.COD_PERIODO = v_per0_per*/
                  AND A1.STEP_ID IN ('A_STEP3') AND M.COD_AZIENDA = A1.COD_AZIENDA AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.D_CHANNEL = A1.D_CHANNEL)
             OR ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
                  /*M.COD_SCENARIO = v_per0_ACT AND M.COD_PERIODO = v_per0_per*/
                  AND A1.STEP_ID IN ('B_STEP1') AND M.COD_AZIENDA = A1.COD_AZIENDA_NEW AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.D_CHANNEL = A1.D_CHANNEL AND M.CUST_CODE = A1.CUST_CODE)
             OR ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
                  /*M.COD_SCENARIO = v_per0_ACT AND M.COD_PERIODO = v_per0_per*/
                  AND A1.STEP_ID IN ('B_STEP2') AND M.COD_AZIENDA = A1.COD_AZIENDA_NEW AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.D_CHANNEL = A1.D_CHANNEL)
      LEFT JOIN TMP_TABLE_ENT A2
             ON (CASE WHEN M.COD_AZIENDA LIKE '63%' OR M.COD_AZIENDA LIKE '67%' THEN 'BX'
                      WHEN M.COD_AZIENDA LIKE '62%' OR M.COD_AZIENDA LIKE '68%' THEN 'KT'
                      WHEN M.COD_AZIENDA LIKE '2%' THEN 'SX'
                      ELSE 'OTH'
                  END) = A2.COD_BU
            AND M.COD_AZI_CTP = A2.COD_CTP
            AND A2.SESSION_ID = V_SESSION_ID
          WHERE ((M.COD_AZI_CTP IS NULL OR M.COD_AZI_CTP = 'ZZZZ') OR (M.COD_AZI_CTP <> 'ZZZZ' AND A2.COD_CTP IS NULL))
        ) T2
      ) T
  WHERE T.POLICY_AMT*BL <> 0
  /*20260714 shiqingfeng.ex 如果组内任意一行的分摊比例绝对值>10，则整组不参与分摊*/
  --AND T.MAX_ABS_BL <= 10
;
 INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.3 生成政策分摊后的数据',P_AZIENDA);
    COMMIT;

    --把政策分摊数据进行汇总，为后续插入做准备
  INSERT INTO TMP_TABLE_POLICY_ALLOC(SESSION_ID,OID,STEP_ID,GROUP_ID,MAP_REV1,POLICY_AMT,POLICY_ALC_AMT)
    --本月
  SELECT
       V_SESSION_ID, OID, 'CURRENT_PERIOD' STEP_ID, NULL GROUP_ID, NULL MAP_REV1, NULL POLICY_AMT, SUM(POLICY_ALC_AMT) POLICY_ALC_AMT

    FROM TMP_TABLE_POLICY_ALLOC
    WHERE SESSION_ID = V_SESSION_ID
      AND STEP_ID IS NOT NULL
      AND STEP_ID <> 'A_STEP2'
  GROUP BY OID

  UNION ALL
  --上2个月
  SELECT
        V_SESSION_ID,OID, 'LAST_TWO_PERIOD' STEP_ID, NULL GROUP_ID, NULL MAP_REV1, NULL POLICY_AMT, SUM(POLICY_ALC_AMT) POLICY_ALC_AMT
    FROM TMP_TABLE_POLICY_ALLOC
    WHERE SESSION_ID = V_SESSION_ID
      AND STEP_ID IS NOT NULL
      AND STEP_ID = 'A_STEP2'
    GROUP BY OID
     ;

    -- 1.3 生成并汇总政策分摊后的数据
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.3 汇总政策分摊后的数据',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 1.4  政策和收入数据一起插入目标表, MAP_QTY, ORG_REV, SALE_COGS, POLICY_AMT, POLICY_CASH_PD
  ------------------------------------------------------------------------------

    --删除上次更新的数据
    DELETE
      FROM AW_MR9_REVM05_000001_TEMP
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO = P_PERIODO
       AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
       --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
       AND  PROVENIENZA = 'CPM_SP_M2M_REV_M'
       /*20260226 新增排除锁定公司*/
       /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                 FROM AW_RUL_DWMCRS_000001 T
                                WHERE REV05_FLAG = 'Y'
                                  AND T.COD_SCENARIO = P_SCENARIO
                                  AND T.COD_PERIODO = P_PERIODO
                                  AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                               )*/
     ;


    --插入未分配的政策分摊数据
    INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
        AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
        DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
        CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
        CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
       ,D_BUS_SCE_S
       ,D_MINILED,MA_SALE_COGS

    )
    SELECT
        NEWID() AS OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, M.COD_AZIENDA,COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, M.CUST_CODE, CUST_NAME,
        M.D_CHANNEL, D_MODE, M.D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        M.MATERIAL_CODE, MATERIAL_NAME, M.COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_ZUM MAP_QTY, M.ORG_REV, M.POLICY_AMT,
        0 AS POLICY_CASH_PD,D_ADJ_TYPE,
        NULL, SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        M.CN_MAP_ZUM,M.CN_ORG_REV,M.CN_SALE_COGS,M.CUSTOMER_MODEL,M.BILL_QTY as ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED,M.MA_SALE_COGS
    FROM AW_MR9_REVM01_000001_CON_TEMP M
    JOIN (SELECT *
            FROM TMP_TABLE_POLICY A11
           WHERE A11.SESSION_ID = V_SESSION_ID
             AND (A11.STEP_ID IS NULL
                  OR EXISTS
                    (SELECT 1
                       FROM TMP_TABLE_POLICY_ALLOC A22
                      WHERE A22.SESSION_ID = V_SESSION_ID
                        AND A11.STEP_ID = A22.STEP_ID
                        AND A11.GROUP_ID = A22.GROUP_ID
                        AND A22.MAX_ABS_BL > 10
                    )
                 )
          ) A1
      ON M.COD_AZIENDA = A1.COD_AZIENDA
     AND (CASE WHEN M.COD_AZIENDA LIKE '62%' OR M.COD_AZIENDA LIKE '68%'
         THEN M.D_SALE_DEPT ELSE M.COD_DEST2 END) = A1.COD_DEST2
     AND NVL(M.D_ONOFFLINE,'Z') = NVL(A1.D_ONOFFLINE,'Z')
     --【20260806 修改v2】M端同步转换D_ECOM_BU，保证空/ZZZZ政策可按原维度落入未分配政策
     AND NVL(CASE WHEN (M.COD_AZIENDA = '1180' OR M.COD_AZIENDA LIKE '12%')
                       THEN M.D_ECOM_BU
                       ELSE M.D_CHANNEL
                   END,'Z') = NVL(A1.D_CHANNEL,'Z')
     AND NVL(M.CUST_CODE,'Z') = NVL(A1.CUST_CODE,'Z')
   WHERE 1=1
     AND M.SRC_DETAIL IN ('POLICY_YT','ADJM01')
     AND M.COD_SCENARIO = P_SCENARIO
     AND M.COD_PERIODO = P_PERIODO
     AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
     --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND M.COD_CONTO IN ('S6001G5','S6001G5AD')
     AND (M.MATERIAL_CODE IS NULL OR M.MATERIAL_CODE = 'ZZZZ')
     /*20260226 新增排除锁定公司*/
     /*AND M.COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                FROM AW_RUL_DWMCRS_000001 T
                               WHERE REV05_FLAG = 'Y'
                                 AND T.COD_SCENARIO = P_SCENARIO
                                 AND T.COD_PERIODO = P_PERIODO
                                 AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                               )*/
    ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入未分配的政策分摊数据',P_AZIENDA);
    COMMIT;


/*20260716 删除未分摊或分摊后为0的临时表中的政策数据*/
/*
DELETE FROM TMP_TABLE_POLICY_ALLOC
 WHERE NVL(MAX_ABS_BL,0) > 10
 ;*/

    --插入收入、出库未开、退货未办、已政策分摊数据
    INSERT INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
        AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
        DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
        CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
        CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
        ,D_BUS_SCE_S
        ,D_MINILED,MA_SALE_COGS
    )

    SELECT
        NEWID() AS OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, LTRIM(COD_DEST2,'0') AS COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_ZUM MAP_QTY, M.ORG_REV, A1.POLICY_ALC_AMT POLICY_AMT,
        CASE WHEN M.SRC_DETAIL IN ('VBRP','REVM01','ADJM01') OR M.SRC_SYSTEM IN ('SMS','GSMS') THEN NVL(MAP_DIS1,0)+NVL(MAP_DIS3,0)+NVL(MAP_DIS4,0)+NVL(MAP_DIS30,0)+NVL(MAP_DIS34,0)
             ELSE 0
         END AS POLICY_CASH_PD,
        D_ADJ_TYPE,
        NULL, SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        M.CN_MAP_ZUM,M.CN_ORG_REV,M.CN_SALE_COGS,M.CUSTOMER_MODEL,M.MAP_QTY AS ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED,M.MA_SALE_COGS
    FROM AW_MR9_REVM01_000001_CON_TEMP M
  --LEFT JOIN， 要COPY所有记录
    LEFT JOIN (SELECT *
                 FROM TMP_TABLE_POLICY_ALLOC
                WHERE SESSION_ID = V_SESSION_ID
                  AND STEP_ID = 'CURRENT_PERIOD') A1
           ON M.OID = A1.OID
        WHERE 1=1
          AND M.COD_CONTO LIKE 'S60010%'
          --AND M.COD_AZIENDA NOT LIKE '8%'
          --AND M.COD_AZIENDA NOT LIKE 'G%'
          --AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
          --AND SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
          AND M.COD_SCENARIO = v_per0_ACT
          AND M.COD_PERIODO = v_per0_per
          AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND ELEM NOT LIKE '8%'
                                      AND ELEM NOT LIKE 'G%'
                                    )
          --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
          /*20260226 新增排除锁定公司*/
          /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                    FROM AW_RUL_DWMCRS_000001 T
                                   WHERE REV05_FLAG = 'Y'
                                     AND T.COD_SCENARIO = P_SCENARIO
                                     AND T.COD_PERIODO = P_PERIODO
                                     AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                  )*/

     ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入收入、出库未开、退货未办、已政策分摊数据',P_AZIENDA);
    COMMIT;


    --插入收入、出库未开、退货未办、已政策分摊数据
    INSERT INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
        AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
        DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
        CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
        CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
        ,D_BUS_SCE_S
        ,D_MINILED,MA_SALE_COGS
    )

    SELECT
        NEWID() AS OID, P_SCENARIO AS COD_SCENARIO, P_PERIODO AS COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, LTRIM(COD_DEST2,'0') AS COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,0 AS MAP_QTY, 0 AS ORG_REV, A1.POLICY_ALC_AMT AS POLICY_AMT,
        0 AS POLICY_CASH_PD,D_ADJ_TYPE,
        NULL, 0 AS SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        0 AS CN_MAP_ZUM,0 AS CN_ORG_REV,0 AS CN_SALE_COGS,M.CUSTOMER_MODEL,0 AS ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED,M.MA_SALE_COGS
    FROM AW_MR9_REVM01_000001_CON_TEMP M
  --注意这里要用inner join， 只COPY匹配记录
    JOIN (SELECT *
            FROM TMP_TABLE_POLICY_ALLOC
           WHERE SESSION_ID = V_SESSION_ID
             AND STEP_ID = 'LAST_TWO_PERIOD') A1
      ON M.OID = A1.OID
    WHERE 1=1
      AND M.COD_CONTO LIKE 'S60010%'
      --AND M.COD_AZIENDA NOT LIKE '8%'
      --AND M.COD_AZIENDA NOT LIKE 'G%'
      AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
      --AND SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per1, v_per2)
      AND ((M.COD_SCENARIO = v_per1_ACT AND M.COD_PERIODO= v_per1_PER)
         OR (M.COD_SCENARIO = v_per2_ACT  AND M.COD_PERIODO= v_per2_PER)
      )

      AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND ELEM NOT LIKE '8%'
                                      AND ELEM NOT LIKE 'G%'
                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                    )
      --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
      /*20260226 新增排除锁定公司*/
      /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                FROM AW_RUL_DWMCRS_000001 T
                               WHERE REV05_FLAG = 'Y'
                                 AND T.COD_SCENARIO = P_SCENARIO
                                 AND T.COD_PERIODO = P_PERIODO
                                 AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                 )*/
 ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入收入、出库未开、退货未办、已政策分摊数据',P_AZIENDA);
    COMMIT;


    INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
        AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
        DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
        CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
        CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
       ,D_BUS_SCE_S
       ,D_MINILED
       ,STD_QTY,MA_SALE_COGS

    )
    SELECT
        NEWID() AS OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, M.COD_AZIENDA,COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, M.CUST_CODE, CUST_NAME,
        M.D_CHANNEL, D_MODE, M.D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        M.MATERIAL_CODE, MATERIAL_NAME, M.COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_ZUM MAP_QTY, M.ORG_REV, M.POLICY_AMT,
        0 AS POLICY_CASH_PD,D_ADJ_TYPE,
        NULL, SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        M.CN_MAP_ZUM,M.CN_ORG_REV,M.CN_SALE_COGS,M.CUSTOMER_MODEL,M.BILL_QTY as ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED
       ,M.STD_QTY,M.MA_SALE_COGS
    FROM AW_MR9_REVM01_000001_CON_TEMP M
    WHERE 1=1
      AND M.SRC_DETAIL IN ('POLICY_YT','ADJM01','REVM01')
      AND M.COD_SCENARIO = P_SCENARIO
      AND M.COD_PERIODO = P_PERIODO
      AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
      --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
      AND M.COD_CONTO IN ('S6001G5','S6001G5AD')
      AND (
          (M.SRC_DETAIL <> 'REVM01' AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0 AND NOT (M.MATERIAL_CODE IS NULL OR M.MATERIAL_CODE = 'ZZZZ'))   OR
          (M.SRC_DETAIL <> 'REVM01' AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) > 0) OR
          (M.SRC_DETAIL = 'REVM01')
          )
      /*20260226 新增排除锁定公司*/
      /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                FROM AW_RUL_DWMCRS_000001 T
                               WHERE REV05_FLAG = 'Y'
                                 AND T.COD_SCENARIO = P_SCENARIO
                                 AND T.COD_PERIODO = P_PERIODO
                                 AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                              )*/
    ;


    -- 1.4 插入收入、出库未开、退货未办、已分摊政策、未分摊政策数据
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.4 插入收入、出库未开、退货未办、已分摊政策、未分摊政策数据',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 1.5  插入除开票收入、出库未开、退货未办、政策分摊数据,MAP_QTY, ORG_REV, SALE_COGS
  ------------------------------------------------------------------------------

  --插入除开票、出库未开、退货未办、及政策分摊外的数据
  INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
        AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
        DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
        CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
        CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
       ,D_BUS_SCE_S
       ,D_MINILED
       ,STD_QTY,MA_SALE_COGS
    )

  SELECT
        NEWID() AS OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, LTRIM(COD_DEST2,'0') AS COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_ZUM MAP_QTY, M.ORG_REV,
        CASE WHEN INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) > 0 THEN POLICY_AMT ELSE 0 END  AS POLICY_AMT,
        0 AS POLICY_CASH_PD,
        D_ADJ_TYPE,
        NULL, SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        M.CN_MAP_ZUM,M.CN_ORG_REV,M.CN_SALE_COGS,M.CUSTOMER_MODEL,M.MAP_QTY AS ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED
       ,M.STD_QTY,M.MA_SALE_COGS
    FROM AW_MR9_REVM01_000001_CON_TEMP M
    WHERE 1=1
      AND (
           (M.COD_CONTO NOT LIKE 'S60010%' AND M.COD_CONTO NOT IN ('S6001G5','S6001G5AD')) OR
           COD_AZIENDA LIKE '8%' OR
           COD_AZIENDA LIKE 'G%'
          )
      AND M.COD_SCENARIO = P_SCENARIO
      AND M.COD_PERIODO = P_PERIODO
      AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
      --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
      /*20260226 新增排除锁定公司*/
      /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                FROM AW_RUL_DWMCRS_000001 T
                               WHERE REV05_FLAG = 'Y'
                                 AND T.COD_SCENARIO = P_SCENARIO
                                 AND T.COD_PERIODO = P_PERIODO
                                 AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                              )*/
;



    -- 1.5 插入除收入、出库未开、退货未办、政策分摊数据
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.5 插入除收入、出库未开、退货未办、政策分摊数据',P_AZIENDA);
    COMMIT;

/*

    --20260716 新增插入墨西哥利润调整
    INSERT INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO,
         COD_PERIODO,
         SRC_DETAIL,
         COD_CONTO,
         COD_CATEGORIA,
         COD_AZIENDA,
         D_MODE,
         D_ONOFFLINE,
         COD_DEST3,
         D_SALE_DEPT,
         D_ADJ_TYPE,
         COD_DEST2,
         COD_DEST4,
         SALE_COGS,
         PROVENIENZA,DATEUPD, USERUPD

    )
      SELECT
           NEWID() AS OID
         , P_SCENARIO AS COD_SCENARIO
         , P_PERIODO AS COD_PERIODO
         , 'HB_ADJM01' AS SRC_DETAIL
         , 'S640100AD' AS COD_CONTO
         , 'GA00_CON_BG' AS COD_CATEGORIA
         , '2000' AS COD_AZIENDA
         , 'ZZZZ' AS D_MODE
         , '020_OFF_002' AS D_ONOFFLINE
         , '3020' AS COD_DEST3
         , 'ZZZZ' AS D_SALE_DEPT
         , 'REV_01_501' AS D_ADJ_TYPE
         , '101001001' AS COD_DEST2
         , '0003' AS COD_DEST4
         , SALE_COGS_PY10 - SALE_COGS_PY09 AS SALE_COGS
         , 'CPM_SP_M2M_REV_M' AS PROVENIENZA
         , SYSDATE AS DATEUPD
         , SESSION_USER AS USERUPD
        FROM

        (
          SELECT   ABS(SUM(CASE WHEN MAP_CAT_IM IN ('PY10') THEN IMPORTO_IM ELSE 0 END)) AS SALE_COGS_PY10
                , ABS(SUM(CASE WHEN MAP_CAT_IM IN ('PY09') THEN IMPORTO_IM ELSE 0 END)) AS SALE_COGS_PY09
           FROM TGK_FIMA_HISENSE.ZTAB_IM_SYNC_ZB_MAP A
          WHERE 1=1
            AND COD_SCENARIO = P_SCENARIO
            AND COD_PERIODO = P_PERIODO
            AND MAP_CAT_IM IN ('PY10','PY09')
            AND '2000' IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
        )
        ;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '插入墨西哥利润调整', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入墨西哥利润调整完成',P_AZIENDA);
    COMMIT;*/


  --2026.02.06  BY YANGHAO 汇率折算
MERGE INTO AW_MR9_REVM05_000001_TEMP SS
USING(
  SELECT AZIENDA.COD_VALUTA,CAMBIO_PERIODO,COD_AZIENDA
  FROM AZIENDA
  LEFT JOIN DATI_CAMBIO
  ON AZIENDA.COD_VALUTA = DATI_CAMBIO.COD_VALUTA
 WHERE DATI_CAMBIO.COD_SCENARIO = P_SCENARIO
   AND DATI_CAMBIO.COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
   /*20260226 新增排除锁定公司*/
          /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   )*/
) C
ON
(SS.COD_AZIENDA = C.COD_AZIENDA
AND SS.COD_SCENARIO = P_SCENARIO
 AND SS.COD_PERIODO = P_PERIODO
 AND SS.PROVENIENZA = 'CPM_SP_M2M_REV_M'
 )
WHEN MATCHED THEN UPDATE SET
  --SS.POLICY_AMT = NVL(SS.POLICY_AMT,0) * C.CAMBIO_PERIODO,
  SS.POLICY_CASH_PD = NVL(SS.POLICY_CASH_PD,0) / C.CAMBIO_PERIODO;
 COMMIT;


  ------------------------------------------------------------------------------
  -- 2  插入合并层调整数据
  ------------------------------------------------------------------------------
  -- 补充调整数
  INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP
  (
    OID,
    COD_SCENARIO,
    COD_PERIODO,
    SRC_DETAIL,
    COD_CONTO,
    COD_AZIENDA,
    COD_CATEGORIA,
    CUST_CODE,
    CUST_NAME,
    D_ONOFFLINE,
    COD_DEST3,
    D_SALE_DEPT,
    MATERIAL_CODE,
    MATERIAL_NAME,
    COD_DEST2,
    COD_DEST4,
    COD_AZI_CTP_ORG,
    MAP_QTY,
    ORG_REV,
    SALE_COGS,
    PROVENIENZA,
    DATEUPD,
    USERUPD,
    D_ADJ_TYPE,
    POLICY_AMT,
    POLICY_CASH_PD,
    BILL_QTY,
    COD_AZI_CTP,
    SOLD_TO_CODE,
    SOLD_TO_NAME,
    COD_DEST1
  )
  SELECT
    NEWID(),
    P_SCENARIO AS COD_SCENARIO,
    P_PERIODO AS COD_PERIODO,
    'HB_ADJM01' AS SRC_DETAIL,
    CASE
      WHEN NVL(MAP_QTY,0)<>0 OR NVL(ORG_REV,0)<>0 THEN 'S600100AD'
      WHEN NVL(SALE_COGS,0)<>0 THEN 'S640100AD'
     WHEN NVL(POLICY_AMT,0) <> 0 THEN 'S6001G5AD'
      ELSE 'S600100AD'
    END AS COD_CONTO,
    COD_AZIENDA,
    CASE WHEN COD_CATEGORIA = 'GA00_CON_L2' THEN 'GA00_CON_L2' ELSE 'GA00_CON' END AS COD_CATEGORIA,
    CUST_CODE,
    CUST_NAME,
    D_ONOFFLINE,
    COD_DEST3,
    D_SALE_DEPT,
    MATERIAL_CODE,
    MATERIAL_NAME,
    COD_DEST2,
    COD_DEST4,
    COD_AZI_CTP AS COD_AZI_CTP_ORG,
    MAP_QTY,
    ORG_REV,
    SALE_COGS,
    'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
    D_ADJ_TYPE,
    POLICY_AMT,
    POLICY_CASH_PD,
    CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN MAP_QTY ELSE 0 END AS BILL_QTY, --0304 fjf_add
    COD_AZI_CTP,
    SOLD_TO_CODE,
    SOLD_TO_NAME,
    CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1

  FROM TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001
  WHERE COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
    --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
    AND COD_CONTO='ZAW_DWM_REV_MERG'
    /*20260526 shqingfeng.ex 修改限制条件*/
    AND COD_CATEGORIA IN ('GA00_CON_L2','GA00_CON')
    --AND COD_CATEGORIA='ZFAMOUNT'
    --AND D_ADJ_TYPE='REV_01_301'
    AND NOT (NVL(SALE_COGS,0)=0 AND NVL(MAP_QTY,0)=0 AND NVL(ORG_REV,0)=0 AND NVL(POLICY_AMT,0)=0 AND NVL(POLICY_CASH_PD,0)=0)
      /*20260226 新增排除锁定公司*/
          /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   )*/
  ;

  COMMIT;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '2  插入合并层调整数据', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 2.1 REV005_STEP_2-1（插入中国区其他业务）
  ------------------------------------------------------------------------------

  INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP
  (
    OID
   ,COD_SCENARIO
   ,COD_PERIODO
   ,SRC_DETAIL
   ,COD_CONTO
   ,COD_CATEGORIA
   ,COD_AZIENDA
   ,AGENCY_CODE
   ,AGENCY_NAME
   ,CUST_CODE
   ,CUST_NAME
   ,D_CHANNEL
   ,D_MODE
   ,D_ONOFFLINE
   ,D_CNL_C_TYPE
   ,D_IND_C_TYPE
   ,D_ECOM_BU
   ,CUST_UNITY_NAME
   ,CREDIT_LEVEL_NAME
   ,CUST_NATURE_NAME
   ,CUST_TYPE_NAME
   ,SOLD_TO_CODE
   ,SOLD_TO_NAME
   ,COD_DEST3
   ,D_SALE_DEPT
   ,D_DATA_BLOCK
   ,D_DIFF_TYPE
   ,D_ADJ_TYPE
   ,MATERIAL_CODE
   ,MATERIAL_NAME
   ,COD_DEST2
   ,COD_DEST4
   ,D_MARKET_PNT
   ,D_PRO_SSER
   ,D_SPEC_SEC
   ,D_PRO_TYPE_S
   ,D_PRO_STAGE
   ,D_PRI_RANGE
   ,D_PRO_SERIES
   ,D_TECH_TYPE
   ,IS_MINILED_CODE
   ,D_PRO_CLASS
   ,D_MODEL_LCA
   ,D_PRO_TYPE
   ,SALE_MODEL_CODE
   ,SALE_MODEL_NAME
   ,MODEL_CODE
   ,MODEL_NAME
   ,BATCH_ID
   ,D_PRC_GRP
   ,MATERIAL_GROUP_CODE
   ,SHOP_CODE
   ,SHOP_NAME
   ,D_POL_CLASS
   ,COD_AZI_CTP
   ,ORG_QTY
   ,BILL_QTY
   ,MAP_QTY
   ,ORG_REV
   ,POLICY_AMT
   ,POLICY_CASH_PD
   ,ASSESSED_REV
   ,SALE_COGS
   ,CN_CLASS_MARK_CODE
   ,CN_CLASS_MARK_NAME
   ,SALE_CERT_TYPE
   ,CUSTOMER_MODEL
   ,D_OPER_TYPE
   ,COD_DEST1
    ,PROVENIENZA
    ,DATEUPD
    ,USERUPD
    ,COD_AZI_CTP_ORG
  ,D_MINILED
  )
  SELECT
     NEWID()OID
   ,COD_SCENARIO
   ,COD_PERIODO
   ,'REVM05' AS SRC_DETAIL
   ,COD_CONTO
   ,'GA00_BF' AS COD_CATEGORIA
   ,COD_AZIENDA
   ,AGENCY_CODE
   ,AGENCY_NAME
   ,CUST_CODE
   ,CUST_NAME
   ,D_CHANNEL
   ,D_MODE
   ,D_ONOFFLINE
   ,D_CNL_C_TYPE
   ,D_IND_C_TYPE
   ,D_ECOM_BU
   ,CUST_UNITY_NAME
   ,CREDIT_LEVEL_NAME
   ,CUST_NATURE_NAME
   ,CUST_TYPE_NAME
   ,SOLD_TO_CODE
   ,SOLD_TO_NAME
   ,COD_DEST3
   ,D_SALE_DEPT
   ,D_DATA_BLOCK
   ,D_DIFF_TYPE
   ,'REV_01_311' AS D_ADJ_TYPE
   ,MATERIAL_CODE
   ,MATERIAL_NAME
   ,COD_DEST2
   ,COD_DEST4
   ,D_MARKET_PNT
   ,D_PRO_SSER
   ,D_SPEC_SEC
   ,D_PRO_TYPE_S
   ,D_PRO_STAGE
   ,D_PRI_RANGE
   ,D_PRO_SERIES
   ,D_TECH_TYPE
   ,IS_MINILED_CODE
   ,D_PRO_CLASS
   ,D_MODEL_LCA
   ,D_PRO_TYPE
   ,SALE_MODEL_CODE
   ,SALE_MODEL_NAME
   ,MODEL_CODE
   ,MODEL_NAME
   ,BATCH_ID
   ,D_PRC_GRP
   ,MATERIAL_GROUP_CODE
   ,SHOP_CODE
   ,SHOP_NAME
   ,D_POL_CLASS
   ,COD_AZI_CTP
   ,0-ORG_QTY AS ORG_QTY
   ,0-BILL_QTY AS BILL_QTY
   ,0-MAP_QTY AS MAP_QTY
   ,0-ORG_REV AS ORG_REV
   ,0-POLICY_AMT AS POLICY_AMT
   ,0-POLICY_CASH_PD AS POLICY_CASH_PD
   ,0-ASSESSED_REV AS ASSESSED_REV
   ,0-SALE_COGS AS SALE_COGS
   ,CN_CLASS_MARK_CODE
   ,CN_CLASS_MARK_NAME
   ,SALE_CERT_TYPE
   ,CUSTOMER_MODEL
   ,D_OPER_TYPE
   ,COD_DEST1
    ,'CPM_SP_M2M_REV_M' PROVENIENZA
   ,SYSDATE DATEUPD
   ,SESSION_USER USERUPD
   ,COD_AZI_CTP_ORG AS COD_AZI_CTP_ORG
   ,D_MINILED
   FROM AW_MR9_REVM05_000001_TEMP
  WHERE COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
    AND D_OPER_TYPE IN (SELECT D_OPER_TYPE
                    FROM AW_RUL_CNMECL_000001
                   WHERE VALID_FR <= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                     AND NVL(VALID_TO,'999999') >= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                  )
      /*20260226 新增排除锁定公司*/
/*    AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
           FROM AW_RUL_DWMCRS_000001 T
          WHERE REV05_FLAG = 'Y'
            AND T.COD_SCENARIO = P_SCENARIO
            AND T.COD_PERIODO = P_PERIODO
            AND T.COD_CONTO = 'ZAW_D2M_LOCK'
            ) */
  ;

  COMMIT;




    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_2-1（插入中国区其他业务）完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);
    COMMIT;



  ------------------------------------------------------------------------------
  -- 3  插入未实现数据和产销存单位成本, BEG_UNREAL_GP, END_UNREAL_GP, WTD_UNIT_COST, DOM_PSI_COST
  ------------------------------------------------------------------------------


MERGE
INTO AW_MR9_REVM05_000001_TEMP A
USING (

WITH
/* ===== CTE 区：所有重复子查询只查一次 ===== */

-- CTE 1: L1级别的业务组列表（替代4处重复的 CASE WHEN V_ENTITY 子查询）
CTE_L1_BU AS (
    SELECT CASE WHEN V_ENTITY = 'BX' THEN 'CXC030'
                WHEN V_ENTITY = 'KT' THEN 'BG003_BU011'
                WHEN V_ENTITY = 'SX' THEN 'BG001_BU001'
                ELSE ''
           END AS D_BU
      FROM AW_RUL_REVCXC_000001
     WHERE COST_CALC_LEVEL = 'L1'
),
-- CTE 2: 符合L1条件的公司集合（替代3处 COD_AZIENDA IN (SELECT ... ATSMAP WHERE COD_BG IN (SELECT ...))）
CTE_L1_AZI AS (
    SELECT A.COD_AZIENDA, A.COD_BG
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
      INNER JOIN CTE_L1_BU L ON A.COD_BG = L.D_BU
),
-- CTE 3: 同业务组公司对（用于排除"公司+CTP在同一BG"的情况）
CTE_SAME_BG_PAIR AS (
    SELECT A1.COD_AZIENDA AS COD_AZI_SELL, A2.COD_AZIENDA AS COD_AZI_BUY
      FROM CTE_L1_AZI A1
      INNER JOIN CTE_L1_AZI A2 ON A1.COD_BG = A2.COD_BG
),
-- CTE 4: 内销DEST3（HN）
CTE_DEST3_HN AS (
    SELECT ELEM
      FROM SESSION_V_REF_DEST3_NONAME
     WHERE SESSION_ID = V_SESSION_ID
       AND NODE = 'HN'
),
-- CTE 5: 锁定公司
/*CTE_LOCK_AZI AS (
    SELECT COD_AZIENDA
      FROM AW_RUL_DWMCRS_000001
     WHERE REV05_FLAG   = 'Y'
       AND COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO  = P_PERIODO
       AND COD_CONTO    = 'ZAW_D2M_LOCK'
),*/
-- CTE 6: 单位成本（原 B2 子查询）
CTE_UC AS (
    SELECT TRIM(MATERIAL_CODE) AS MATERIAL_CODE, MAX(UC) AS WTD_UNIT_COST
      FROM TGK_FIMA_HISENSE.ZTAB_UC_LIST
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO  = P_PERIODO
       AND TRIM(MATERIAL_CODE) IS NOT NULL
       AND D_BU IN ('CXC030', 'BG003_BU011', 'BG001_BU001')
     GROUP BY TRIM(MATERIAL_CODE)
),
-- CTE 7: 上一期未实现毛利（原 B3 子查询，用 CTE_L1_AZI 替代重复子查询）
CTE_PREV_GP AS (
    SELECT MATERIAL_CODE,
           SUM(BEG_UNREAL_GP) AS BEG_UNREAL_GP,
           SUM(END_UNREAL_GP) AS END_UNREAL_GP
      FROM (
          SELECT COD_AZIENDA, TRIM(MATERIAL_CODE) AS MATERIAL_CODE,
                 SUM(NVL(BEG_UNREAL_GP, 0)) AS BEG_UNREAL_GP,
                 SUM(NVL(END_UNREAL_GP, 0)) AS END_UNREAL_GP
            FROM TGK_FIMA_HISENSE.AW_MR9_REVM04_000001
           WHERE COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO  = P_PERIODO
             AND COD_AZIENDA IN (SELECT COD_AZIENDA FROM CTE_L1_AZI)
             AND D_BU IN ('CXC030', 'BG003_BU011', 'BG001_BU001')
             AND TRIM(MATERIAL_CODE) IS NOT NULL
             AND (NVL(BEG_UNREAL_GP, 0) <> 0 OR NVL(END_UNREAL_GP, 0) <> 0)
             AND COD_DEST3 IN (SELECT ELEM FROM CTE_DEST3_HN)
           GROUP BY COD_AZIENDA, MATERIAL_CODE
      )
      WHERE TRIM(MATERIAL_CODE) IS NOT NULL
        AND NVL(MATERIAL_CODE, '|') <> 'ZZZZ'
      GROUP BY MATERIAL_CODE
)
    /* 核心逻辑：
       B1: 主表 + 套机单机映射 → 窗口函数计算 BL（分摊比例）
       B2: 单位成本（CTE_UC）
       B3: 上一期未实现毛利（CTE_PREV_GP），按 ZDETAIL 匹配
       外层 SUM(GP.BEG_UNREAL_GP * MD.BL) = 按比例分摊上一期毛利
    */
    SELECT MD.OID,
           MD.MATERIAL_CODE,
           MAX(UC.WTD_UNIT_COST) AS WTD_UNIT_COST,
           SUM(GP.BEG_UNREAL_GP * MD.BL) AS BEG_UNREAL_GP,
           SUM(GP.END_UNREAL_GP * MD.BL) AS END_UNREAL_GP
      FROM (
          SELECT OID, MATERIAL_CODE, ZDETAIL,
                 RATIO_TO_REPORT(ORG_QTY) OVER (PARTITION BY ZDETAIL) AS BL
            FROM (
                SELECT AW.OID, AW.MATERIAL_CODE,
                       CASE WHEN M_LIST.ZDETAIL IS NULL THEN AW.MATERIAL_CODE
                            ELSE M_LIST.ZDETAIL
                       END AS ZDETAIL,
                       AW.ORG_QTY
                  FROM AW_MR9_REVM05_000001_TEMP AW
                  LEFT JOIN (SELECT ZSET, ZDETAIL
                               FROM TGK_FIMA_HISENSE.ZTAB_MATNR_TJ) M_LIST
                         ON AW.MATERIAL_CODE = M_LIST.ZSET
                 WHERE AW.COD_SCENARIO = P_SCENARIO
                   AND AW.COD_PERIODO  = P_PERIODO
                   AND AW.MATERIAL_CODE IS NOT NULL
                   AND AW.ORG_QTY <> 0
                   AND AW.COD_AZIENDA IN (SELECT COD_AZIENDA FROM CTE_L1_AZI)
                   AND AW.COD_DEST3 IN (SELECT ELEM FROM CTE_DEST3_HN)
                   AND NOT EXISTS (
                       SELECT 1 FROM CTE_SAME_BG_PAIR P
                        WHERE P.COD_AZI_SELL = AW.COD_AZIENDA
                          AND P.COD_AZI_BUY  = NVL(AW.COD_AZI_CTP_ORG, '9999')
                   )
            )
      ) MD
      /* LEFT JOIN 单位成本 */
      LEFT JOIN CTE_UC UC ON MD.MATERIAL_CODE = UC.MATERIAL_CODE
      /* LEFT JOIN 上一期未实现毛利（按套机/单机 ZDETAIL 匹配）*/
      LEFT JOIN CTE_PREV_GP GP ON MD.ZDETAIL = GP.MATERIAL_CODE
     GROUP BY MD.OID, MD.MATERIAL_CODE

) B
ON (A.OID = B.OID)
WHEN MATCHED THEN
    UPDATE SET
        A.BEG_UNREAL_GP   = B.BEG_UNREAL_GP,
        A.END_UNREAL_GP   = B.END_UNREAL_GP,
        A.WTD_UNIT_COST   = B.WTD_UNIT_COST
;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_3（插入未实现及产销存单位成本）完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);
    COMMIT;


-- ============================================================
-- ② 主查询：内销未实现GP + 物料主数据维度
-- ============================================================
INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP
(
OID,
D_ONOFFLINE,
SRC_DETAIL,
COD_CONTO,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
COD_CATEGORIA,
MATERIAL_CODE,
COD_DEST2,
COD_DEST3,
COD_DEST4,
BEG_UNREAL_GP,
END_UNREAL_GP,
DATEUPD,
USERUPD,
PROVENIENZA,

--COD_DEST4,
D_MARKET_PNT,
D_PRO_SSER,
D_SPEC_SEC,
D_PRO_TYPE_S,
D_PRO_STAGE,
D_PRI_RANGE,
D_PRO_SERIES,
D_TECH_TYPE,
D_PRO_CLASS,
D_MODEL_LCA,
CUSTOMER_MODEL,
MATERIAL_NAME,
MODEL_NAME,
MODEL_CODE,
IS_MINILED_CODE,
MATERIAL_GROUP_CODE,
SALE_MODEL_CODE,
SALE_MODEL_NAME

)
WITH
  bg_azienda AS (
    SELECT COD_BG, COD_AZIENDA
    FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
    WHERE COD_BG IN ('BG001_BU001')
  ),

  excl_mat AS (
    SELECT CASE WHEN M_LIST.ZDETAIL IS NULL
                THEN AW.MATERIAL_CODE
                ELSE M_LIST.ZDETAIL
           END AS MATERIAL_CODE
    FROM AW_MR9_REVM05_000001_TEMP AW
    LEFT JOIN TGK_FIMA_HISENSE.ZTAB_MATNR_TJ M_LIST
           ON AW.MATERIAL_CODE = M_LIST.ZSET
    WHERE AW.COD_SCENARIO = P_SCENARIO
      AND AW.COD_PERIODO  = P_PERIODO
      AND AW.COD_AZIENDA IN (
              SELECT COD_AZIENDA FROM bg_azienda WHERE COD_BG = 'BG001_BU001'
          )
      AND NOT EXISTS (
              SELECT 1
              FROM bg_azienda A1
              INNER JOIN bg_azienda A2 ON A1.COD_BG = A2.COD_BG
              WHERE A1.COD_AZIENDA = AW.COD_AZIENDA
                AND A2.COD_AZIENDA = NVL(AW.COD_AZI_CTP_ORG, '9999')
          )
      AND AW.COD_DEST3 IN (
              SELECT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE SESSION_ID = V_SESSION_ID AND NODE = 'HN'
          )
    GROUP BY
      CASE WHEN M_LIST.ZDETAIL IS NULL
           THEN AW.MATERIAL_CODE
           ELSE M_LIST.ZDETAIL
      END
    HAVING SUM(NVL(AW.BEG_UNREAL_GP, 0)) <> 0
        OR SUM(NVL(AW.END_UNREAL_GP, 0)) <> 0
  )

SELECT
  NEWID()                                              AS OID,
  '020_OFF_002'                                        AS D_ONOFFLINE,
  'UP'                                                 AS SRC_DETAIL,
  'S640110C'                                           AS COD_CONTO,
  X1.COD_SCENARIO,
  X1.COD_PERIODO,
  '2000'                                               AS COD_AZIENDA,
  'ZAMOUNT'                                            AS COD_CATEGORIA,
  X1.MATERIAL_CODE,
  X1.COD_DEST2,
  X1.COD_DEST3,
  X1.COD_DEST4,
  X1.BEG_UNREAL_GP,
  X1.END_UNREAL_GP,
  SYSDATE                                              AS DATEUPD,
  SESSION_USER                                         AS USERUPD,
  'CPM_SP_M2M_REV_M'                                   AS PROVENIENZA,
  NVL(MARA.MARKET_POS_CODE,   'ZZZZ')                 AS D_MARKET_PNT,       -- 市场定位
  NVL(MARA.prod_suite_code,   'ZZZZ')                 AS D_PRO_SSER,         -- 产品套系
  NVL(CASE WHEN MARA.big_class_code = 'P01' THEN MARA.SCREEN_SIZE_CODE
       WHEN MARA.big_class_code = 'P02' THEN MARA.SPEC_RANGE_CODE
       WHEN MARA.big_class_code = 'P03' THEN MARA.TOTAL_CAPACITY_CODE
       WHEN MARA.big_class_code = 'P04' THEN MARA.WASHING_CAPACITY_CODE
  END,'ZZZZ')                 AS D_SPEC_SEC,         -- 规格段
  NVL(MARA.PRODUCT_SPEC_CODE, 'ZZZZ')                 AS D_PRO_TYPE_S,       -- 产品规格类型
  NVL(MARA.PROD_STAGE_CODE,   'ZZZZ')                 AS D_PRO_STAGE,        -- 产品阶段
  NVL(MARA.PRICE_RANGE_CODE,  'ZZZZ')                 AS D_PRI_RANGE,        -- 价格段
  NVL(MARA.SERIES_CODE,       'ZZZZ')                 AS D_PRO_SERIES,       -- 产品系列
  NVL(MARA.AC_CT_CODE,        'ZZZZ')                 AS D_TECH_TYPE,        -- 技术类型
  NVL(MARA.small_class_code,  'ZZZZ')                 AS D_PRO_CLASS,        -- 产品小类
  NVL(MARA.model_lca,         'ZZZZ')                 AS D_MODEL_LCA,        -- 型号生命周期
  COALESCE(
    NULLIF(UPPER(MARA.sale_model_name), '无'),
    NULLIF(UPPER(MARA.zcusmodel),       '无')
  )                                                    AS CUSTOMER_MODEL,    -- 客户型号
  MARA.product_name                                    AS MATERIAL_NAME,     -- 物料描述
  NVL(MARA.model_name,        'ZZZZ')                 AS MODEL_NAME,         -- 型号名称
  NVL(MARA.model_code,        'ZZZZ')                 AS MODEL_CODE,         -- 型号编码
  NVL(CASE WHEN MARA.is_miniled_code = 'PC00013001' THEN '是'
           WHEN MARA.is_miniled_code = 'PC00013002' THEN '否'
           ELSE ''
       END, 'ZZZZ')                                    AS IS_MINILED_CODE,   -- 是否MiniLED
  NVL(REPLACE(REPLACE(REPLACE(MARA.prod_line,'BP',''),'DS',''),'TA',''),
      'ZZZZ')                                          AS MATERIAL_GROUP_CODE, -- 物料组
  NVL(COALESCE(
        NULLIF(TRIM(MARA.zzprdmodel),    ''),
        NULLIF(TRIM(MARA.zfacmodel),     ''),
        NULLIF(TRIM(MARA.pmodel_number), '')
      ), 'ZZZZ')                                       AS SALE_MODEL_CODE,   -- 销售型号
  NVL(MARA.sale_model_name,   'ZZZZ')                 AS SALE_MODEL_NAME

FROM (
    SELECT MATERIAL_CODE,
           COD_SCENARIO,
           COD_PERIODO,
           COD_DEST2,
           COD_DEST3,
           COD_DEST4,
           BEG_UNREAL_GP,
           END_UNREAL_GP
    FROM TGK_FIMA_HISENSE.AW_MR9_REVM04_000001
    WHERE COD_SCENARIO = P_SCENARIO
      AND COD_PERIODO  = P_PERIODO
      /* AND COD_AZIENDA IN (
                     SELECT COD_AZIENDA
                     FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                     WHERE COD_BG IN ('BG001_BU001')
                   ) */
      AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                             AND ELEM IN (
                                         SELECT COD_AZIENDA
                                         FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                                         WHERE COD_BG IN ('BG001_BU001')
                                      )
                                    )
     --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
      AND D_BU         = 'BG001_BU001'
      AND COD_DEST3 IN (
              SELECT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE SESSION_ID = V_SESSION_ID AND NODE = 'HN'
          )


) X1
LEFT JOIN TGK_FIMA_HISENSE.DIM_FI_PRODUCT MARA
       ON X1.MATERIAL_CODE = MARA.MATNR

WHERE NOT EXISTS (
    SELECT 1 FROM excl_mat e
    WHERE e.MATERIAL_CODE = X1.MATERIAL_CODE
)
;



    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_3（插入无销量未实现金额）完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);

COMMIT;




INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  插入日立单位成本开始', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  插入日立单位成本开始',P_AZIENDA);
    COMMIT;

  /* 更新日立产销存单位成本字段 WTD_UNIT_COST --fjf_add */
  MERGE /*+ USE_HASH(SS T) */ INTO AW_MR9_REVM05_000001_TEMP SS
  USING (SELECT A.OID, B.DWCB AS WTD_UNIT_COST
           FROM (SELECT OID, COD_AZIENDA, MATERIAL_CODE, MANG_QTY
                   FROM AW_MR9_REVM05_000001_TEMP T
                  WHERE 1 = 1
                    AND COD_SCENARIO = P_SCENARIO
                    AND COD_PERIODO = P_PERIODO
                    --AND (COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240')
                    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '17%' OR ELEM = '6240')
                                    )
                    AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
                    ) A
          INNER JOIN (SELECT GJAHR,
                            POPER,
                            MATNR,
                            MEINS,
                            BISMT,
                            SUM(COST_MO) AS COST_MO,
                            SUM(MNG_SALE) AS MNG_SALE,
                            DECODE(SUM(MNG_SALE),
                                   0,
                                   0,
                                   SUM(COST_MO) / SUM(MNG_SALE)) AS DWCB
                     --SELECT *
                       FROM TGK_GB_HISENSE.V_HITACH_ZXSLR_CONS T --合并成本
                      WHERE 1 = 1
                        AND T.GJAHR = SUBSTR(P_SCENARIO, 1, 4)
                        AND T.POPER = P_PERIODO
                      GROUP BY GJAHR, POPER, MATNR, MEINS, BISMT
                     HAVING SUM(MNG_SALE) <> 0) B
             ON A.MATERIAL_CODE = B.MATNR) T

  ON (SS.OID = T.OID
  --and SS.COD_SCENARIO = P_SCENARIO
  --AND SS.COD_PERIODO = P_PERIODO

  --AND (INSTR(V_AZIENDA, SS.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')

  /*20260226 新增排除锁定公司*/
  /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                            FROM AW_RUL_DWMCRS_000001 T
                           WHERE REV05_FLAG = 'Y'
                             AND T.COD_SCENARIO = P_SCENARIO
                             AND T.COD_PERIODO = P_PERIODO
                             AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
   )
  WHEN MATCHED THEN
    UPDATE SET WTD_UNIT_COST = T.WTD_UNIT_COST;

INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  插入日立单位成本结束', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  插入日立单位成本结束',P_AZIENDA);
    COMMIT;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  日立内外销成本及成本轧差处理开始', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  日立内外销成本及成本轧差处理开始',P_AZIENDA);
    COMMIT;


  UPDATE AW_MR9_REVM05_000001_TEMP
     SET DOM_PSI_COST = NVL(BILL_QTY, 0) * NVL(WTD_UNIT_COST, 0)
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND (ELEM LIKE '17%' OR ELEM = '6240')
                        )
     AND COD_DEST3 IN (SELECT ELEM
                         FROM SESSION_V_REF_DEST3_NONAME
                        WHERE SESSION_ID = V_SESSION_ID
                          AND HIE = '01'
                          AND NODE = 'HN')
    AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
  ;



  UPDATE AW_MR9_REVM05_000001_TEMP
     SET DOM_PSI_COST = NVL(ORG_QTY, 0) * NVL(WTD_UNIT_COST, 0)
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND NOT (ELEM LIKE '17%' OR ELEM = '6240')
                        )
     AND COD_DEST3 IN (SELECT ELEM
                         FROM SESSION_V_REF_DEST3_NONAME
                        WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01'
                          AND NODE = 'HN')
     AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
  ;



  UPDATE AW_MR9_REVM05_000001_TEMP
     SET FAC_EXTERNAL_SALE_COST = NVL(BILL_QTY, 0) * NVL(WTD_UNIT_COST, 0)
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND (ELEM LIKE '17%' OR ELEM = '6240')
                        )
     AND COD_DEST3 IN
                    (SELECT ELEM
                       FROM SESSION_V_REF_DEST3_NONAME
                      WHERE SESSION_ID = V_SESSION_ID AND HIE = '01'
                        AND NODE = 'HW')
     AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
  ;




/*
  UPDATE AW_MR9_REVM05_000001_TEMP
     SET DOM_PSI_COST = CASE
                        \* 更新日立工厂端内销销售成本字段 --fjf_add *\
                          WHEN COD_DEST3 IN (SELECT ELEM
                                               FROM SESSION_V_REF_DEST3_NONAME
                                              WHERE SESSION_ID = V_SESSION_ID
                                                AND HIE = '01'
                                                AND NODE = 'HN') AND
                               (COD_AZIENDA LIKE '17%' OR
                               COD_AZIENDA = '6240') THEN
                           NVL(BILL_QTY, 0) * NVL(WTD_UNIT_COST, 0)
                          WHEN COD_DEST3 IN (SELECT ELEM
                                               FROM SESSION_V_REF_DEST3_NONAME
                                              WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01'
                                                AND NODE = 'HN') THEN
                           NVL(ORG_QTY, 0) * NVL(WTD_UNIT_COST, 0)
                          ELSE
                           0
                        END

         \* 更新日立工厂端外销销售成本字段 --fjf_add *\,
         FAC_EXTERNAL_SALE_COST = CASE
                                    WHEN COD_DEST3 IN
                                         (SELECT ELEM
                                            FROM SESSION_V_REF_DEST3_NONAME
                                           WHERE SESSION_ID = V_SESSION_ID AND HIE = '01'
                                             AND NODE = 'HW') AND
                                         (COD_AZIENDA LIKE '17%' OR
                                         COD_AZIENDA = '6240') THEN
                                     NVL(BILL_QTY, 0) * NVL(WTD_UNIT_COST, 0)
                                    ELSE
                                     0
                                  END
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
    --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
        \*20260226 新增排除锁定公司*\
     \* AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK') *\
     AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
  ---AND SRC_DETAIL='VBRP'
  ;
*/


 /* 日立成本轧差处理：因为日立的老管报成本和现有成本两边不一致_fjf_add */
 INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP
  (
    OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT
    , D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES
    , D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE
    , SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE
    , SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST, AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST
    , OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL, FAC_EXTERNAL_SALE_REVENUE
    , IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM
    , COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY, CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST
    , ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY
    , FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY, DOM_PSI_COST, FAC_EXTERNAL_SALE_COST,D_MINILED
    )

WITH SRC AS
(
  SELECT OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT
    , D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES
    , D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE
    , SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE
    , SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST, AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST
    , OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL, FAC_EXTERNAL_SALE_REVENUE
    , IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM
    , COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY, CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST
    , ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY
    , FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY
  , NVL(DOM_PSI_COST,0) AS DOM_PSI_COST
  , NVL(FAC_EXTERNAL_SALE_COST,0) AS FAC_EXTERNAL_SALE_COST
  ,D_MINILED
  FROM AW_MR9_REVM05_000001_TEMP
  WHERE 1 = 1
  AND COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                       WHERE SESSION_ID = V_SESSION_ID
                          AND (ELEM LIKE '17%' OR ELEM = '6240')
                                    )
  --AND (COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240')
  AND COD_CONTO NOT LIKE '%AD'
)

SELECT NEWID() AS OID, COD_SCENARIO, COD_PERIODO, 'GB_ZXSLR' AS SRC_DETAIL,'S640100'AS COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT
    , D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES
    , D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE
    , SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE
    , SHOP_NAME
    , 0 AS MAP_QTY, 0 AS ORG_REV, 0 AS POLICY_AMT,0 AS ASSESSED_REV,0 AS SALE_COGS,0 AS BEG_UNREAL_GP,0 AS END_UNREAL_GP,0 AS COMB_COST,0 AS AVG_UNIT_COST
    , 0 AS COMB_COST_AVG,0 AS PSI_COMB_COST,0 AS WTD_UNIT_COST
    , 0 AS OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, 0 AS POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL
    , 0 AS FAC_EXTERNAL_SALE_REVENUE, 0 AS IM_SALE_COST
    , COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE
    , 0 AS CN_SALE_COGS, 0 AS CN_ORG_REV, 0 AS CN_MAP_ZUM
    , COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST,0 ELIM_REV,0 COMB_REV,0 MANG_REV,0 ENT_QTY,0 ENT_QTY_ADJ,0 ELIM_QTY,0 CADJ_QTY,0 MANG_QTY,0 ENT_REV,0 ENT_REV_ADJ,0 CADJ_REV, ENT_COST
    , ENT_COST_ADJ, CADJ_COST,0 CN_ELIM_QTY,0 CN_MANG_QTY,0 CN_ELIM_REV,0 CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE
    , 0 AS ORG_QTY
    , 0 FAC_MANG_REV,0 IM_MANG_REV,0 FAC_CADJ_REV,0 CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1
    , 0 AS BILL_QTY
    , CASE WHEN T.COD_DEST3 IN (SELECT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01' AND NODE = 'HN') THEN D.CY_COST ELSE 0 END AS DOM_PSI_COST
    , CASE WHEN T.COD_DEST3 IN (SELECT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01' AND NODE = 'HW') THEN D.CY_COST ELSE 0 END AS  FAC_EXTERNAL_SALE_COST
  ,D_MINILED
FROM(
    SELECT * FROM SRC
  )T
INNER JOIN
  (
    SELECT OID,CY_COST
    FROM( --按物料找出最大销量对应行ID：维度按照销量最大的行的维度来定义
        SELECT OID, MATERIAL_CODE, BILL_QTY
        FROM(
            SELECT OID, MATERIAL_CODE, BILL_QTY
              ,ROW_NUMBER() OVER (PARTITION BY MATERIAL_CODE ORDER BY BILL_QTY DESC) AS RN
            FROM SRC
          )
        WHERE RN = 1
      )SRC
    INNER JOIN
      (
        --取出两边系统的成本然后计算出成本差
        SELECT B.GJAHR AS COD_SCENARIO,B.POPER AS COD_PERIODO,B.MATNR AS MATERIAL_CODE
          ,NVL(B.COST_MO,0) - NVL(A.TOTAL_COST,0) AS CY_COST
        FROM(
            SELECT COD_SCENARIO, COD_PERIODO,  MATERIAL_CODE
              ,SUM(NVL(DOM_PSI_COST,0) + NVL(FAC_EXTERNAL_SALE_COST,0)) AS TOTAL_COST
              ,SUM(BILL_QTY) AS BILL_QTY
            FROM SRC
            GROUP BY COD_SCENARIO,COD_PERIODO,MATERIAL_CODE
            HAVING SUM(DOM_PSI_COST + FAC_EXTERNAL_SALE_COST) <> 0
          ) A
        LEFT JOIN
          ( --老管报合并成本
            SELECT GJAHR,POPER,MATNR,SUM(NVL(COST_MO,0)) AS COST_MO,SUM(MNG_SALE) AS MNG_SALE
            FROM TGK_GB_HISENSE.V_HITACH_ZXSLR_CONS T --合并成本
            WHERE 1 = 1
            AND T.GJAHR = SUBSTR(P_SCENARIO ,1 ,4)
            AND T.POPER = P_PERIODO
            GROUP BY GJAHR,POPER,MATNR
            HAVING SUM(MNG_SALE) <> 0
          ) B
        ON A.MATERIAL_CODE = B.MATNR
        WHERE (NVL(B.COST_MO,0) - NVL(A.TOTAL_COST,0)) <> 0
        AND NVL(B.COST_MO,0) <> 0
      )C
    ON SRC.MATERIAL_CODE = C.MATERIAL_CODE
  )D
ON T.OID = D.OID
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  日立内外销成本及成本轧差处理结束', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  日立内外销成本及成本轧差处理结束',P_AZIENDA);
    COMMIT;


    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  插入未实现数据和产销存单位成本', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  插入未实现数据和产销存单位成本',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 4  插入无物料总账成本分摊数据及小B国补, OTH_ASSESS_COST, FAC_CADJ_REV, CN_CADJ_REV
  ------------------------------------------------------------------------------

--edit by lc 260207 分事业部跑
IF V_ENTITY = 'BX' THEN
   CPM_SP_M2M_ZZFT_M(P_SCENARIO,P_PERIODO,'6700',SESSION_USER);
END IF
;

IF V_ENTITY = 'KT' THEN
   CPM_SP_M2M_ZZFT_M(P_SCENARIO,P_PERIODO,'6800',SESSION_USER);
END IF
;

IF V_ENTITY = 'SX' THEN
   CPM_SP_M2M_ZZFT_M(P_SCENARIO,P_PERIODO,'2000',SESSION_USER);
END IF
;

IF V_ENTITY = 'ALL' THEN
   CPM_SP_M2M_ZZFT_M(P_SCENARIO,P_PERIODO,'ALL',SESSION_USER);
END IF
;

  UPDATE AW_MR9_REVM05_000001_TEMP
     SET PSI_COMB_COST = NVL(DOM_PSI_COST, 0) + NVL(OTH_ASSESS_COST, 0)
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
    --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
        /*20260226 新增排除锁定公司*/
     /* AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
  ;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '4  插入无物料总账成本分摊数据', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '4.1  插入无物料总账成本分摊数据',P_AZIENDA);

    COMMIT;
/* 临时处理 视像分摊总账数据的  单体字段  分摊没有考虑手工调整，回写 先处理视像*/
UPDATE AW_MR9_REVM05_000001_TEMP t
   SET ENT_COST = NVL(SALE_COGS, 0)
 WHERE COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                           AND ELEM IN (SELECT COD_AZIENDA
                                     FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                                    WHERE COD_BG = 'BG001_BU001')
                       )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
   /* AND COD_AZIENDA IN (SELECT COD_AZIENDA
                         FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                        WHERE COD_BG = 'BG001_BU001') */
   AND PROVENIENZA = 'CPM_SP_ZZFT_M_T0'
      /*20260226 新增排除锁定公司*/
   /* AND COD_AZIENDA NOT IN
       (SELECT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001 T
         WHERE REV05_FLAG = 'Y'
           AND T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO = P_PERIODO
           AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
           ;

  ------------------------------------------------------------------------------
  -- 5  计算单体原始数据、单体调整数据、合并调整数据, ENT, ENT_ADJ, CADJ FOR QTY, REV, COST
  ------------------------------------------------------------------------------

  UPDATE AW_MR9_REVM05_000001_TEMP
     SET ENT_QTY = CASE
                     WHEN COD_CATEGORIA IN ('ZAMOUNT', 'ZFAMOUNT') THEN
                      NVL(MAP_QTY, 0)
                     ELSE
                      0
                   END,
         ENT_QTY_ADJ = CASE
                         WHEN COD_CATEGORIA IN
                              ('GA00_DI_IN',
                               'GA00_DI_OUT',
                               'GA00_BF',
                               'GA00_REV_KH',
                               'GA00_PA_IN',
                               'GA00_PA_OUT') THEN
                          NVL(MAP_QTY, 0)
                         ELSE
                          0
                       END,
         CADJ_QTY = CASE
                      WHEN COD_CATEGORIA LIKE 'GA00_CON%' THEN
                       NVL(MAP_QTY, 0)
                      ELSE
                       0
                    END,
         ENT_REV = CASE
                     WHEN COD_AZIENDA = '2023' AND COD_CONTO = 'S600111' AND
                          COD_CATEGORIA IN ('ZAMOUNT', 'ZFAMOUNT') THEN
                      NVL(ORG_REV, 0)
                     WHEN COD_CATEGORIA IN ('ZAMOUNT', 'ZFAMOUNT') THEN
                      NVL(ORG_REV, 0)
                     ELSE
                      0
                   END,
         ENT_REV_ADJ = CASE
                         WHEN COD_AZIENDA = '2023' AND COD_CONTO = 'S600111' AND
                              COD_CATEGORIA IN
                              ('GA00_DI_IN',
                               'GA00_DI_OUT',
                               'GA00_BF',
                               'GA00_REV_KH',
                               'GA00_AF',
                               'GA00_PA_IN',
                               'GA00_PA_OUT') THEN
                          NVL(ORG_REV, 0)
                         WHEN COD_CATEGORIA IN
                              ('GA00_DI_IN',
                               'GA00_DI_OUT',
                               'GA00_BF',
                               'GA00_REV_KH',
                               'GA00_AF',
                               'GA00_PA_IN',
                               'GA00_PA_OUT') THEN
                          NVL(ORG_REV, 0)
                         ELSE
                          0
                       END,
         CADJ_REV = CASE
                      WHEN COD_CATEGORIA LIKE 'GA00_CON%' THEN
                       NVL(ORG_REV, 0)
                      ELSE
                       0
                    END,
         ENT_COST = CASE
                      WHEN COD_CATEGORIA IN ('ZAMOUNT', 'ZFAMOUNT') THEN
                       NVL(SALE_COGS, 0)
                      ELSE
                       0
                    END,
         ENT_COST_ADJ = CASE
                          WHEN COD_CATEGORIA IN
                               ('GA00_DI_IN',
                                'GA00_DI_OUT',
                                'GA00_BF',
                                'GA00_REV_KH',
                                'GA00_AF',
                                'GA00_PA_IN',
                                'GA00_PA_OUT') THEN
                           NVL(SALE_COGS, 0)
                          ELSE
                           0
                        END,
         CADJ_COST = CASE
                       WHEN COD_CATEGORIA LIKE 'GA00_CON%' THEN
                        NVL(SALE_COGS, 0)
                       ELSE
                        0
                     END
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                       )
    --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
        --对于收入直接调整数据也要做相同逻辑处理
     AND PROVENIENZA IN
         ('CPM_SP_M2M_REV_M', 'INPUT_DEFORM', 'CPM_SP_ZZFT_M_T0')
        --排除返利价差科目余额, 不进入到管理口径，被政策分摊和政策兑现数据替换
     AND (COD_CONTO NOT IN ('S600111') OR COD_AZIENDA = '2023')
        /*20260226 新增排除锁定公司*/
     /* AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
  ---AND SRC_DETAIL='VBRP'
  ;

  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '5  计算单体原始数据、单体调整数据、合并调整数据', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '5  计算单体原始数据、单体调整数据、合并调整数据',P_AZIENDA);
    COMMIT;


--20260206 新增手工调整数据客商信息和物料信息补充更新
MERGE /*+ USE_HASH(T C) */INTO AW_MR9_REVM05_000001_TEMP T
USING (
SELECT distinct CASE
                  WHEN nvl(aw.D_MARKET_PNT, '|') = '|' OR
                       aw.D_MARKET_PNT = 'ZZZZ' THEN
                   MARA.market_pos_code
                  ELSE
                   aw.D_MARKET_PNT
                END AS D_MARKET_PNT -- 营销定位编码
               ,
                CASE
                  WHEN nvl(aw.D_CNL_C_TYPE, '|') = '|' OR
                       aw.D_CNL_C_TYPE = 'ZZZZ' THEN
                   CUST_INFO.channel_small_class_code
                  ELSE
                   aw.D_CNL_C_TYPE
                END AS D_CNL_C_TYPE -- 渠道客户小类编码
               ,
                CASE
                  WHEN nvl(AW.D_CHANNEL, '|') = '|' OR AW.D_CHANNEL = 'ZZZZ' THEN
                   CUST_INFO.com_3rd_code
                  ELSE
                   AW.D_CHANNEL
                END AS D_CHANNEL -- 销售渠道三级编码
               ,
                CASE
                  WHEN nvl(aw.D_PRO_CLASS, '|') = '|' OR
                       aw.D_PRO_CLASS = 'ZZZZ' THEN
                   MARA.small_class_code
                  ELSE
                   aw.D_PRO_CLASS
                END AS D_PRO_CLASS -- 产品小类编码
               ,
                CASE
                  WHEN nvl(aw.MATERIAL_GROUP_CODE, '|') = '|' OR
                       aw.MATERIAL_GROUP_CODE = 'ZZZZ' THEN
                   CASE
                     WHEN AZ.SAP_VERSION IN ('S600', 'S900') THEN
                      REPLACE(REPLACE(REPLACE(mara.prod_line, 'BP', ''),
                                      'DS',
                                      ''),
                              'TA',
                              '')
                     ELSE
                      LTRIM(mara.matkl, '0')
                   END
                  ELSE
                   aw.MATERIAL_GROUP_CODE --物料组编码
                END AS MATERIAL_GROUP_CODE,
                CASE
                  WHEN nvl(aw.model_code, '|') = '|' OR
                       aw.model_code = 'ZZZZ' THEN
                   MARA.model_code
                  ELSE
                   aw.model_code
                END AS model_code -- 产品型号
               ,
                CASE
                  WHEN nvl(aw.COD_AZI_CTP, '|') = '|' OR
                       aw.COD_AZI_CTP = 'ZZZZ' THEN
                   CTP.COD_AZI_CTP
                  ELSE
                   aw.COD_AZI_CTP
                END AS COD_AZI_CTP,
                AW.OID
  FROM (SELECT OID,
               COD_AZI_CTP,
               model_code,
               MATERIAL_GROUP_CODE,
               D_PRO_CLASS,
               D_CHANNEL,
               D_MARKET_PNT,
               D_CNL_C_TYPE,
               COD_AZIENDA,
               CUST_CODE,
               MATERIAL_CODE
          FROM AW_MR9_REVM05_000001_TEMP
         WHERE COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO = P_PERIODO
           AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0')
              /*20260226 新增排除锁定公司*/
           /* AND COD_AZIENDA NOT IN
               (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
           AND SRC_DETAIL = 'HB_ADJM01') AW
  LEFT JOIN (SELECT COD_AZIENDA, 'S' || CITTA_LEGALE SAP_VERSION
               FROM TGK_FIMA_HISENSE.AZIENDA) AZ
    ON AW.COD_AZIENDA = AZ.COD_AZIENDA
  LEFT JOIN (SELECT 'S' || MANDT AS SAP_VERSION, KUNNR, zkunnr_mdg, name1
               FROM TGK_FIMA_HISENSE.DS_DWD_SAP_KNA1) KNA1
    ON AZ.SAP_VERSION = KNA1.SAP_VERSION
   AND LTRIM(KNA1.kunnr, '0') = AW.CUST_CODE
  LEFT JOIN TGK_FIMA_HISENSE.DIM_CUSTOMER_BASE_INFO_DD CUST_INFO
    ON LTRIM(KNA1.zkunnr_mdg, '0') = LTRIM(CUST_INFO.cust_code, '0')
  LEFT JOIN TGK_FIMA_HISENSE.DIM_FI_PRODUCT MARA
    ON MARA.matnr = AW.MATERIAL_CODE
  LEFT JOIN (SELECT cust_code       AS kunrg,
                    cp_company_code AS COD_AZI_CTP,
                    system_src      AS system_src
               FROM TGK_FIMA_HISENSE.dim_rule_fi_mr_cust2ctp_mapping a
              WHERE cust_type_code = 'C'
                AND NVL(valid_fr, '202401') <=
                    SUBSTR(P_SCENARIO, 0, 4) || P_PERIODO
                AND NVL(valid_to, '999999') >=
                    SUBSTR(P_SCENARIO, 0, 4) || P_PERIODO) CTP
    ON CTP.kunrg = AW.CUST_CODE
   AND CTP.system_src = AZ.SAP_VERSION
) C
ON(
   T.OID = C.OID
)
WHEN MATCHED THEN
UPDATE SET  T.D_MARKET_PNT = C.D_MARKET_PNT
      , T.D_CNL_C_TYPE = C.D_CNL_C_TYPE
      , T.D_CHANNEL = C.D_CHANNEL
      , T.D_PRO_CLASS = C.D_PRO_CLASS
      , T.MATERIAL_GROUP_CODE = C.MATERIAL_GROUP_CODE
      , T.model_code = C.model_code
    , T.COD_AZI_CTP = C.COD_AZI_CTP
      ;
  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '手工调整数据客商信息和物料信息补充更新完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;


/*插入抵消数据之前将政策兑现字段更新成0
20260626SXX补充逻辑：
如果本方对方同时在事业部对应账套配置表【AW_RUL_ATSMAP_000001】的视像、冰箱、空调、中国区的公司范围里，则该字段放0
视像：BG001_BU001、BG002_BU001
冰箱：BG004_BU001、BG005_BU001
空调：BG003_BU011
中国区：BG012_BU

注意：
①如果是视像范围，需要是本方对方同事在视像范围里才把这个字段放0
②注意要考虑开始时间跟结束时间
*/

UPDATE AW_MR9_REVM05_000001_TEMP A
SET POLICY_CASH_PD = 0
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  AND (
        (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG001_BU001','BG002_BU001')
                           AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')

                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG001_BU001','BG002_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )

      )
  ;
  ------------------------------------------------------------------------------
  -- 6  插入抵消数据-根据有CTP的收入, 未实现不能复制, ELIM_QTY, ELIM_REV, ELIM_COST, CN_ELIM_QTY, CN_ELIM_REV, CN_ELIM_COST
  ------------------------------------------------------------------------------

INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_AZI_CTP, COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST1, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS, D_ADJ_TYPE,
    PROVENIENZA,DATEUPD, USERUPD,
    CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,
    CUSTOMER_MODEL,
    ELIM_QTY, ELIM_REV, ELIM_COST,
    CN_ELIM_QTY, CN_ELIM_REV
  ,D_MINILED
  ,ORG_QTY --原始销量
  ,MAP_QTY --数量(处理后)
  ,BILL_QTY --开票销量（日立用）
  ,STD_QTY
    )
WITH CN_AZI AS (
    -- 中国区公司集合（等同于 V_CN_AZIENDA 的 LISTAGG 来源）
    SELECT COD_AZIENDA
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
     WHERE COD_BG = 'BG012'
       AND COD_AZIENDA <> '1183'
),
NODE_200 AS
(
SELECT NODE,ELEM FROM SESSION_V_REF_AZIENDA S
 WHERE SESSION_ID = V_SESSION_ID AND S.HIE = '10' AND S.NODE = '200'
)
  SELECT NEWID() AS OID,
         COD_SCENARIO,
         COD_PERIODO,
         'ELIM' AS SRC_DETAIL,
         COD_CONTO,
         M.COD_AZIENDA,
         COD_AZI_CTP_ORG AS COD_AZI_CTP,
         COD_AZI_CTP_ORG,
         'GA00_ELIM' AS COD_CATEGORIA,
         AGENCY_CODE,
         AGENCY_NAME,
         CUST_CODE,
         CUST_NAME,
         D_CHANNEL,
         D_MODE,
         D_ONOFFLINE,
         D_CNL_C_TYPE,
         D_IND_C_TYPE,
         D_ECOM_BU,
         CUST_UNITY_NAME,
         CREDIT_LEVEL_NAME,
         CUST_NATURE_NAME,
         CUST_TYPE_NAME,
         SOLD_TO_CODE,
         SOLD_TO_NAME,
         COD_DEST3,
         D_SALE_DEPT,
         D_DATA_BLOCK,
         D_DIFF_TYPE,
         MATERIAL_CODE,
         MATERIAL_NAME,
         COD_DEST1,
         COD_DEST2,
         COD_DEST4,
         D_MARKET_PNT,
         D_PRO_SSER,
         D_SPEC_SEC,
         D_PRO_TYPE_S,
         D_PRO_STAGE,
         D_PRI_RANGE,
         D_PRO_SERIES,
         D_TECH_TYPE,
         IS_MINILED_CODE,
         D_PRO_CLASS,
         D_MODEL_LCA,
         D_PRO_TYPE,
         SALE_MODEL_CODE,
         SALE_MODEL_NAME,
         MODEL_CODE,
         MODEL_NAME,
         BATCH_ID,
         D_PRC_GRP,
         MATERIAL_GROUP_CODE,
         SHOP_CODE,
         SHOP_NAME,
         D_POL_CLASS,
         D_ADJ_TYPE,
         PROVENIENZA,
         DATEUPD,
         USERUPD,
         M.CN_CLASS_MARK_CODE,
         M.CN_CLASS_MARK_NAME,
         M.SALE_CERT_TYPE,
         M.CUSTOMER_MODEL,
         -1 * (NVL(ENT_QTY, 0) + NVL(ENT_QTY_ADJ, 0) + NVL(CADJ_QTY, 0)) AS ELIM_QTY,
         -1 * (NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) -
         NVL(POLICY_CASH_PD, 0) + NVL(CADJ_REV, 0)) AS ELIM_REV,
         CASE
           /*20260810-1 shiqingfeng.ex 对方公司是中国区公司，不生成成本抵消数*/
           WHEN NODE_200.ELEM IS NOT NULL
             THEN 0
           WHEN CN_SELL.COD_AZIENDA IS NOT NULL AND
                CN_BUY.COD_AZIENDA IS NOT NULL THEN
            0
           ELSE
            NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) +
            NVL(CADJ_REV, 0) - NVL(POLICY_CASH_PD, 0)
         END AS ELIM_COST,
         CASE
           WHEN CN_SELL.COD_AZIENDA IS NOT NULL AND
                CN_BUY.COD_AZIENDA IS NOT NULL THEN
            -1 * NVL(CN_MAP_ZUM, 0)
           ELSE
            0
         END AS CN_ELIM_QTY,
         CASE
           WHEN CN_SELL.COD_AZIENDA IS NOT NULL AND
                CN_BUY.COD_AZIENDA IS NOT NULL THEN
            -1 * (NVL(CN_ORG_REV, 0) + NVL(POLICY_AMT, 0) -
            NVL(POLICY_CASH_PD, 0))
           ELSE
            0
         END AS CN_ELIM_REV,
         D_MINILED,
         -1 * NVL(ORG_QTY, 0) AS ORG_QTY --原始销量
        ,
         -1 * NVL(MAP_QTY, 0) AS MAP_QTY --数量(处理后)
        ,
         -1 * NVL(BILL_QTY, 0) AS BILL_QTY --开票销量（日立用）
        ,-1 * NVL(STD_QTY, 0) AS STD_QTY
    FROM AW_MR9_REVM05_000001_TEMP M
    LEFT JOIN CN_AZI CN_SELL ON CN_SELL.COD_AZIENDA = M.COD_AZIENDA
    LEFT JOIN CN_AZI CN_BUY  ON CN_BUY.COD_AZIENDA  = M.COD_AZI_CTP_ORG
    LEFT JOIN NODE_200 ON NODE_200.ELEM  = M.COD_AZI_CTP_ORG
   WHERE 1 = 1
     AND M.COD_SCENARIO = P_SCENARIO
     AND M.COD_PERIODO = P_PERIODO
     AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
     --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND M.COD_AZI_CTP_ORG IS NOT NULL
     AND EXISTS (
         SELECT 1 FROM SESSION_V_REF_AZIENDA S
          WHERE SESSION_ID = V_SESSION_ID AND S.HIE = '10' AND S.ELEM <> 'Z001' AND S.ELEM = M.COD_AZI_CTP_ORG
     )
     AND M.SRC_DETAIL <> 'ZTAB_IM_ZB'
     AND M.COD_CONTO LIKE 'S6001%'
     AND M.PROVENIENZA <> 'INPUT_DEFORM'
     AND NOT EXISTS (
         SELECT 1 FROM AW_RUL_DWMCRS_000001 T
          WHERE T.REV05_FLAG = 'Y'
            AND T.COD_SCENARIO = P_SCENARIO
            AND T.COD_PERIODO = P_PERIODO
            AND T.COD_CONTO = 'ZAW_D2M_LOCK'
            AND T.COD_AZIENDA = M.COD_AZIENDA
     )
     /* AND NOT
          (EXISTS (
              SELECT 1 FROM tgk_gb_hisense.FORM_DIZIONARIO_ELEMENTO t
               WHERE t.COD_ELEDIZ = NVL(M.MATERIAL_CODE, '|')
                 AND t.COD_DIZIONARIO = 'LIST_ZHEKOU_MM'
                 AND t.ATTRIBUTO1_ELEDIZ = '600'
          )
          AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZIENDA
          )
          AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZI_CTP_ORG
          )) */
         ;


DELETE FROM AW_MR9_REVM05_000001_TEMP M
 WHERE COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND SRC_DETAIL = 'ELIM'
   AND (EXISTS (
              SELECT 1 FROM tgk_gb_hisense.FORM_DIZIONARIO_ELEMENTO t
               WHERE t.COD_ELEDIZ = NVL(M.MATERIAL_CODE, '|')
                 AND t.COD_DIZIONARIO = 'LIST_ZHEKOU_MM'
                 AND t.ATTRIBUTO1_ELEDIZ = '600'
          )
          AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZIENDA
          )
          AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZI_CTP_ORG
          )
         )
 ;


  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '6  插入抵消数据-根据有CTP的收入, 未实现不能复制完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

/* 20260406 zhuangxinzhou 视像ZK01兑现抵消逻辑 与中国区逻辑不一致 尚未拉通，单独设置
            中国区逻辑3月变化，视像与原逻辑保持一致
 POLICY_CASH_PD */
  INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_AZI_CTP, COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST1, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,   D_ADJ_TYPE,
    PROVENIENZA,DATEUPD, USERUPD,
    CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,
    CUSTOMER_MODEL,
    ELIM_QTY, ELIM_REV, ELIM_COST,
    CN_ELIM_QTY, CN_ELIM_REV, CN_ELIM_COST
  ,D_MINILED
  ,ORG_QTY --原始销量
  ,MAP_QTY --数量(处理后)
  ,BILL_QTY --开票销量（日立用）
  ,STD_QTY
    )
  SELECT NEWID() AS OID,
         COD_SCENARIO,
         COD_PERIODO,
         'ELIM' AS SRC_DETAIL,
         COD_CONTO,
         COD_AZIENDA,
         COD_AZI_CTP_ORG AS COD_AZI_CTP,
         COD_AZI_CTP_ORG,
         'GA00_ELIM' AS COD_CATEGORIA,
         AGENCY_CODE,
         AGENCY_NAME,
         CUST_CODE,
         CUST_NAME,
         D_CHANNEL,
         D_MODE,
         D_ONOFFLINE,
         D_CNL_C_TYPE,
         D_IND_C_TYPE,
         D_ECOM_BU,
         CUST_UNITY_NAME,
         CREDIT_LEVEL_NAME,
         CUST_NATURE_NAME,
         CUST_TYPE_NAME,
         SOLD_TO_CODE,
         SOLD_TO_NAME,
         COD_DEST3,
         D_SALE_DEPT,
         D_DATA_BLOCK,
         D_DIFF_TYPE,
         MATERIAL_CODE,
         MATERIAL_NAME,
         COD_DEST1,
         COD_DEST2,
         COD_DEST4,
         D_MARKET_PNT,
         D_PRO_SSER,
         D_SPEC_SEC,
         D_PRO_TYPE_S,
         D_PRO_STAGE,
         D_PRI_RANGE,
         D_PRO_SERIES,
         D_TECH_TYPE,
         IS_MINILED_CODE,
         D_PRO_CLASS,
         D_MODEL_LCA,
         D_PRO_TYPE,
         SALE_MODEL_CODE,
         SALE_MODEL_NAME,
         MODEL_CODE,
         MODEL_NAME,
         BATCH_ID,
         D_PRC_GRP,
         MATERIAL_GROUP_CODE,
         SHOP_CODE,
         SHOP_NAME,
         D_POL_CLASS,
         D_ADJ_TYPE,
         PROVENIENZA,
         DATEUPD,
         USERUPD,
         M.CN_CLASS_MARK_CODE,
         M.CN_CLASS_MARK_NAME,
         M.SALE_CERT_TYPE,
         M.CUSTOMER_MODEL,
         -1 * (NVL(ENT_QTY, 0) + NVL(ENT_QTY_ADJ, 0) + NVL(CADJ_QTY, 0)) AS ELIM_QTY,
         -1 * (NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) -
         NVL(POLICY_CASH_PD, 0) + NVL(CADJ_REV, 0)) AS ELIM_REV,
         NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) +
         NVL(CADJ_REV, 0) /*-NVL(POLICY_CASH_PD,0)*/ AS ELIM_COST,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            -1 * NVL(CN_MAP_ZUM, 0)
           ELSE
            0
         END AS CN_ELIM_QTY,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            -1 * (NVL(CN_ORG_REV, 0) + NVL(POLICY_AMT, 0) -
            NVL(POLICY_CASH_PD, 0))
           ELSE
            0
         END AS CN_ELIM_REV,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            NVL(CN_ORG_REV, 0) + NVL(POLICY_AMT, 0) - NVL(POLICY_CASH_PD, 0)
           ELSE
            0
         END AS CN_ELIM_COST,
         D_MINILED,
         -1 * NVL(ORG_QTY, 0) AS ORG_QTY --原始销量
        ,
         -1 * NVL(MAP_QTY, 0) AS MAP_QTY --数量(处理后)
        ,
         -1 * NVL(BILL_QTY, 0) AS BILL_QTY --开票销量（日立用）
        ,-1 * NVL(STD_QTY, 0) AS STD_QTY
    FROM AW_MR9_REVM05_000001_TEMP M
   WHERE 1 = 1
     AND M.COD_SCENARIO = P_SCENARIO
     AND M.COD_PERIODO = P_PERIODO
     AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
     --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     --AND M.COD_AZI_CTP_ORG IS NOT NULL
     AND M.COD_AZI_CTP_ORG IN
         (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE HIE = '10' AND SESSION_ID = V_SESSION_ID)
     AND COD_AZI_CTP_ORG NOT IN ('Z001')
     AND
        --国际营销提供抵消后结果
         M.SRC_DETAIL <> 'ZTAB_IM_ZB'
     --AND (M.COD_CONTO LIKE 'S6001%' OR M.COD_CONTO LIKE 'S6001G%')
     AND M.COD_CONTO LIKE 'S6001%'
     AND M.PROVENIENZA <> 'INPUT_DEFORM'
     /*AND NOT EXISTS (
         SELECT 1 FROM AW_RUL_DWMCRS_000001 T
          WHERE T.REV05_FLAG = 'Y'
            AND T.COD_SCENARIO = P_SCENARIO
            AND T.COD_PERIODO = P_PERIODO
            AND T.COD_CONTO = 'ZAW_D2M_LOCK'
            AND T.COD_AZIENDA = M.COD_AZIENDA
     )*/
     AND EXISTS (
              SELECT 1 FROM tgk_gb_hisense.FORM_DIZIONARIO_ELEMENTO t
               WHERE t.COD_ELEDIZ = NVL(M.MATERIAL_CODE, '|')
                 AND t.COD_DIZIONARIO = 'LIST_ZHEKOU_MM'
                 AND t.ATTRIBUTO1_ELEDIZ = '600'
          )
     AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZIENDA
          )
     AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZI_CTP_ORG
          )
         ;


     /*
        \*20260226 新增排除锁定公司*\
     AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK')
     AND (NVL(MATERIAL_CODE, '|') IN
         (SELECT COD_ELEDIZ
             FROM tgk_gb_hisense.FORM_DIZIONARIO_ELEMENTO t
            WHERE COD_DIZIONARIO = 'LIST_ZHEKOU_MM'
              AND ATTRIBUTO1_ELEDIZ = '600') AND
         COD_AZIENDA IN (SELECT COD_AZIENDA
                            FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                           WHERE COD_BG = 'BG001_BU001') AND
         cod_azi_ctp_org IN
         (SELECT COD_AZIENDA
             FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
            WHERE COD_BG = 'BG001_BU001'))
         ;*/
  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '中国区逻辑3月变化，视像与原逻辑保持一致', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

IF P_SCENARIO='2026ACT' AND P_PERIODO='01' THEN
INSERT INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_AZI_CTP, COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST1, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, OTH_ASSESS_COST,
    PROVENIENZA,DATEUPD, USERUPD,
    CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
    CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,
    ELIM_QTY, ELIM_REV, ELIM_COST,
    CN_ELIM_QTY, CN_ELIM_REV, CN_ELIM_COST
  ,D_MINILED
    )


  SELECT NEWID() AS OID,
         COD_SCENARIO,
         COD_PERIODO,
         'ELIM' AS SRC_DETAIL,
         COD_CONTO,
         COD_AZIENDA,
         COD_AZI_CTP_ORG AS COD_AZI_CTP,
         COD_AZI_CTP_ORG,
         'GA00_ELIM' AS COD_CATEGORIA,
         AGENCY_CODE,
         AGENCY_NAME,
         CUST_CODE,
         CUST_NAME,
         D_CHANNEL,
         D_MODE,
         D_ONOFFLINE,
         D_CNL_C_TYPE,
         D_IND_C_TYPE,
         D_ECOM_BU,
         CUST_UNITY_NAME,
         CREDIT_LEVEL_NAME,
         CUST_NATURE_NAME,
         CUST_TYPE_NAME,
         SOLD_TO_CODE,
         SOLD_TO_NAME,
         COD_DEST3,
         D_SALE_DEPT,
         D_DATA_BLOCK,
         D_DIFF_TYPE,
         MATERIAL_CODE,
         MATERIAL_NAME,
         COD_DEST1,
         COD_DEST2,
         COD_DEST4,
         D_MARKET_PNT,
         D_PRO_SSER,
         D_SPEC_SEC,
         D_PRO_TYPE_S,
         D_PRO_STAGE,
         D_PRI_RANGE,
         D_PRO_SERIES,
         D_TECH_TYPE,
         IS_MINILED_CODE,
         D_PRO_CLASS,
         D_MODEL_LCA,
         D_PRO_TYPE,
         SALE_MODEL_CODE,
         SALE_MODEL_NAME,
         MODEL_CODE,
         MODEL_NAME,
         BATCH_ID,
         D_PRC_GRP,
         MATERIAL_GROUP_CODE,
         SHOP_CODE,
         SHOP_NAME,
         D_POL_CLASS,
         0 AS MAP_QTY,
         0 AS ORG_REV,
         0 AS POLICY_AMT,
         0 AS POLICY_CASH_PD,
         D_ADJ_TYPE,
         0 AS ASSESSED_REV,
         0 AS SALE_COGS,
         0 AS BEG_UNREAL_GP,
         0 AS END_UNREAL_GP,
         0 AS OTH_ASSESS_COST,
         PROVENIENZA,
         DATEUPD,
         USERUPD,
         M.CN_CLASS_MARK_CODE,
         M.CN_CLASS_MARK_NAME,
         M.SALE_CERT_TYPE,
         0 AS CN_MAP_ZUM,
         0 AS CN_ORG_REV,
         0 AS CN_SALE_COGS,
         M.CUSTOMER_MODEL,
         -1 * (NVL(ENT_QTY, 0) + NVL(ENT_QTY_ADJ, 0)) AS ELIM_QTY,
         -1 * (NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) -
         NVL(POLICY_CASH_PD, 0)) AS ELIM_REV,
         (NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0)) AS ELIM_COST,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            -1 * NVL(CN_MAP_ZUM, 0)
           ELSE
            0
         END AS CN_ELIM_QTY,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            -1 * NVL(CN_ORG_REV, 0)
           ELSE
            0
         END AS CN_ELIM_REV,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            NVL(CN_ORG_REV, 0)
           ELSE
            0
         END AS CN_ELIM_COST,
         D_MINILED
    FROM AW_MR9_REVM05_000001_TEMP M
   WHERE 1 = 1
     AND M.COD_SCENARIO = P_SCENARIO
     AND M.COD_PERIODO = P_PERIODO
     AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND M.COD_AZI_CTP_ORG IS NOT NULL
     AND M.COD_AZI_CTP_ORG IN
         (SELECT DISTINCT ELEM FROM SESSION_V_REF_AZIENDA WHERE HIE = '10' AND SESSION_ID = V_SESSION_ID)
     AND COD_AZI_CTP_ORG NOT IN ('Z001')
     AND
        --国际营销提供抵消后结果
         (COD_SCENARIO = '2026ACT' AND COD_PERIODO = '01' AND
         COD_AZIENDA = '6515' AND SRC_DETAIL = 'CON_INP' AND
         COD_CONTO = 'S600111')
        /*20260226 新增排除锁定公司*/
     AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK');
END IF ;

  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '6  插入抵消数据完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '6  插入抵消数据',P_AZIENDA);
    COMMIT;


/*ELIM_COST成本抵消-法人更新为0
20260626SXX补充逻辑：
如果本方对方同时在事业部对应账套配置表【AW_RUL_ATSMAP_000001】的视像、冰箱、空调、中国区的公司范围里且属于折扣物料，则该字段放0
视像：BG001_BU001、BG002_BU001
冰箱：BG004_BU001、BG005_BU001
空调：BG003_BU011
中国区：BG012_BU
折扣物料取数范围：AW_RUL_REVEMA_000001-折扣物料清单
注意：
①如果是视像范围，需要是本方对方同事在视像范围里才把这个字段放0
②注意要考虑开始时间跟结束时间

*/

UPDATE AW_MR9_REVM05_000001_TEMP A
SET ELIM_COST = 0
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
  --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  AND A.MATERIAL_CODE IN (  SELECT T.MATERIAL_CODE
                              FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 t
                            WHERE T.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
                              AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                              AND MATERIAL_CODE IS NOT NULL
                           )
  AND ( (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      /* OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
 */
      )
  ;



UPDATE AW_MR9_REVM05_000001_TEMP A
SET ELIM_COST = 0
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
  --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  AND A.MATERIAL_CODE IN (  SELECT T.MATERIAL_CODE
                              FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 t
                            WHERE T.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
                              AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                              AND MATERIAL_CODE IS NOT NULL
                           )
  AND ( /* (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR */ (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      /* OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         ) */

      )
  ;




UPDATE AW_MR9_REVM05_000001_TEMP A
SET ELIM_COST = 0
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
  --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  AND A.MATERIAL_CODE IN (  SELECT T.MATERIAL_CODE
                              FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 t
                            WHERE T.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
                              AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                              AND MATERIAL_CODE IS NOT NULL
                           )
  AND ( /* (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR */ (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )

      )
  ;


  ------------------------------------------------------------------------------
  -- 7  内销-计算法人成本和大系统产销存的差，在工厂内销账套范围内根据利润中心把差值分摊，写入VAR_ALLOC_COST
  ------------------------------------------------------------------------------
IF P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL' THEN
   INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '7.0 START  计算法人成本和大系统产销存的差并分摊', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;

  MERGE INTO AW_MR9_REVM05_000001_TEMP M
  USING (SELECT A.OID,
                COD_SCENARIO,
                COD_PERIODO,
                CASE
                  WHEN NVL(B.DIFF_AMT, 0) <> 0 AND NVL(DOM_PSI_COST, 0) = 0 THEN
                   NVL(B.DIFF_AMT, 0)
                  ELSE
                   B.DIFF_AMT * DOM_PSI_COST / SUM_DOM_PSI_COST
                END VAR_ALLOC_COST
           FROM (
                 --在物料内，按照大系统产销存的金额进行分摊
                 SELECT OID,
                         COD_SCENARIO,
                         COD_PERIODO,
                         MATERIAL_CODE,
                         NVL(DOM_PSI_COST, 0) DOM_PSI_COST,
                         SUM(NVL(DOM_PSI_COST, 0)) OVER(PARTITION BY COD_SCENARIO, COD_PERIODO, MATERIAL_CODE) SUM_DOM_PSI_COST
                   FROM AW_MR9_REVM05_000001_TEMP
                  WHERE COD_SCENARIO = P_SCENARIO
                    AND COD_PERIODO = P_PERIODO
                    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST A1
                                         WHERE SESSION_ID = V_SESSION_ID
                                           AND EXISTS (SELECT 1
                                                   FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A2
                                                  WHERE COD_BG = 'BG001_BU001'
                                                    AND A2.COD_AZIENDA = A1.ELEM
                                                    )
                              )
                    /*AND COD_AZIENDA IN
                        (SELECT COD_AZIENDA
                           FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                          WHERE COD_BG = 'BG001_BU001')*/
                    AND COD_DEST3 LIKE '2%'
                    /*AND COD_DEST3 IN (SELECT ELEM
                                        FROM SESSION_V_REF_DEST3_NONAME
                                       WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01'
                                         AND NODE = 'HN')*/

                    AND
                       --(COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' /*OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%'*/) AND
                        NVL(DOM_PSI_COST, 0) <> 0
                    AND PROVENIENZA NOT IN ('INPUT_DEFORM')
                    ) A
           JOIN (
                --按照物料获取差值
                SELECT MATERIAL_CODE,
                        SUM(CASE
                              WHEN COD_AZI_CTP IN
                                   (SELECT COD_AZIENDA
                                      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                                     WHERE COD_BG = 'BG001_BU001') THEN
                               NVL(ENT_COST, 0) + NVL(ENT_COST_ADJ, 0) +
                               NVL(ELIM_COST, 0) /*+ NVL(OTH_ASSESS_COST,0)*/
                               -NVL(DOM_PSI_COST, 0)
                              ELSE
                               NVL(ENT_COST, 0) + NVL(ENT_COST_ADJ, 0) /*+ NVL(OTH_ASSESS_COST,0)*/
                               -NVL(DOM_PSI_COST, 0)
                            END) DIFF_AMT
                  FROM AW_MR9_REVM05_000001_TEMP
                 WHERE COD_SCENARIO = P_SCENARIO
                   AND COD_PERIODO = P_PERIODO
                   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST A1
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND EXISTS (SELECT 1
                                                   FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A2
                                                  WHERE COD_BG = 'BG001_BU001'
                                                    AND A2.COD_AZIENDA = A1.ELEM
                                                    )
                              )
                   /*AND COD_AZIENDA IN
                       (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG = 'BG001_BU001')*/
                   AND COD_DEST3 LIKE '2%'
                   /*AND COD_DEST3 IN (SELECT ELEM
                                       FROM SESSION_V_REF_DEST3_NONAME
                                      WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01'
                                        AND NODE = 'HN')*/

                   AND
                      --(COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' /*OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%'*/) AND
                       (NVL(ENT_COST, 0) <> 0 OR NVL(ENT_COST_ADJ, 0) <> 0 OR
                       NVL(ELIM_COST, 0) <> 0 OR
                       NVL(OTH_ASSESS_COST, 0) <> 0OR
                        NVL(DOM_PSI_COST, 0) <> 0)
                 GROUP BY MATERIAL_CODE) B
             ON A.MATERIAL_CODE = B.MATERIAL_CODE
          WHERE ROUND(A.SUM_DOM_PSI_COST, 3) <> 0) T

  ON (M.OID = T.OID
  --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  /*20260226 新增排除锁定公司*/
  /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                            FROM AW_RUL_DWMCRS_000001 T
                           WHERE REV05_FLAG = 'Y'
                             AND T.COD_SCENARIO = P_SCENARIO
                             AND T.COD_PERIODO = P_PERIODO
                             AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
   )
  WHEN MATCHED THEN
    UPDATE SET VAR_ALLOC_COST = T.VAR_ALLOC_COST
    ;

   INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '7.1  计算法人成本 ', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;
 /*物料分摊后仍未分摊金额*/

MERGE /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP A
USING (
WITH
BG001_AZI AS (
    SELECT COD_AZIENDA
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
     WHERE COD_BG = 'BG001_BU001'
),
NEED_UPDATE_MC AS (
    SELECT T.MATERIAL_CODE
      FROM AW_MR9_REVM05_000001_TEMP T
      LEFT JOIN BG001_AZI BG_CTP
             ON BG_CTP.COD_AZIENDA = T.COD_AZI_CTP_ORG
     WHERE T.COD_SCENARIO = P_SCENARIO
       AND T.COD_PERIODO  = P_PERIODO
       AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
       AND T.COD_AZIENDA IN (SELECT COD_AZIENDA FROM BG001_AZI)
       AND NOT EXISTS (
           SELECT 1 FROM AW_RUL_DWMCRS_000001 L
            WHERE L.REV05_FLAG   = 'Y'
              AND L.COD_SCENARIO = P_SCENARIO
              AND L.COD_PERIODO  = P_PERIODO
              AND L.COD_CONTO    = 'ZAW_D2M_LOCK'
              AND L.COD_AZIENDA  = T.COD_AZIENDA
       )
       AND T.COD_DEST3 LIKE '2%'
       /*AND T.COD_DEST3 IN (
           SELECT ELEM
             FROM SESSION_V_REF_DEST3_NONAME
            WHERE SESSION_ID = V_SESSION_ID
              AND HIE = '01'
              AND NODE = 'HN'
       )*/
       AND T.MATERIAL_CODE IS NOT NULL
       AND NVL(T.SRC_DETAIL, '|') NOT IN ('CON_INP')
       AND T.COD_CONTO <> 'SEGP000'
     GROUP BY T.MATERIAL_CODE
    HAVING ROUND(
             SUM(NVL(T.DOM_PSI_COST, 0))                     /* DOM_PSI_COST */
           + SUM(NVL(T.VAR_ALLOC_COST, 0))                   /* VAR_ALLOC_COST */
           - SUM(NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)) /* ENT_COST */
           - SUM(CASE WHEN BG_CTP.COD_AZIENDA IS NOT NULL
                      THEN NVL(T.ELIM_COST, 0)
                      ELSE 0 END)                            /* ELIM_COST */
           , 3
           ) <> 0
)
    SELECT T.OID AS OID,
           T.VAR_ALLOC_COST
         + NVL(T.ENT_COST_ADJ, 0)
         + NVL(T.ENT_COST, 0)
         + CASE
             WHEN BG_CTP.COD_AZIENDA IS NOT NULL
             THEN NVL(T.ELIM_COST, 0)
             ELSE 0
           END
           AS NEW_VAR_ALLOC_COST
      FROM AW_MR9_REVM05_000001_TEMP T
      INNER JOIN NEED_UPDATE_MC MC
              ON MC.MATERIAL_CODE = T.MATERIAL_CODE
      LEFT JOIN BG001_AZI BG_CTP
             ON BG_CTP.COD_AZIENDA = T.COD_AZI_CTP_ORG
     WHERE T.COD_SCENARIO = P_SCENARIO
       AND T.COD_PERIODO  = P_PERIODO
       AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
      --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
       AND T.COD_AZIENDA IN (SELECT COD_AZIENDA FROM BG001_AZI)
       /* AND NOT EXISTS (
           SELECT 1 FROM AW_RUL_DWMCRS_000001 L
            WHERE L.REV05_FLAG   = 'Y'
              AND L.COD_SCENARIO = P_SCENARIO
              AND L.COD_PERIODO  = P_PERIODO
              AND L.COD_CONTO    = 'ZAW_D2M_LOCK'
              AND L.COD_AZIENDA  = T.COD_AZIENDA
       ) */
       AND T.COD_DEST3 LIKE '2%'
       /*AND T.COD_DEST3 IN (
           SELECT ELEM
             FROM SESSION_V_REF_DEST3_NONAME
            WHERE SESSION_ID = V_SESSION_ID
              AND HIE = '01'
              AND NODE = 'HN'
       )*/
       AND T.MATERIAL_CODE IS NOT NULL
       AND NVL(T.SRC_DETAIL, '|') NOT IN ('CON_INP')
       AND T.COD_CONTO <> 'SEGP000'
) S
ON (A.OID = S.OID)
WHEN MATCHED THEN
  UPDATE SET A.VAR_ALLOC_COST = S.NEW_VAR_ALLOC_COST
;

   INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '7.2  物料分摊后仍未分摊金额', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;
/*物料号为空的 赋值到差异分摊中*/

MERGE /*取消并发*/
INTO AW_MR9_REVM05_000001_TEMP A
USING (
    WITH
    -- CTE 1: BG001_BU001 公司集合（SET 和 WHERE 各用一次，合并为1个CTE）
    CTE_BG001 AS (
        SELECT COD_AZIENDA
          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
         WHERE COD_BG = 'BG001_BU001'
    ),
    -- CTE 2: 内销 DEST3 集合
    CTE_DEST3_HN AS (
        SELECT ELEM
          FROM SESSION_V_REF_DEST3_NONAME
         WHERE SESSION_ID = V_SESSION_ID
           AND HIE = '01'
           AND NODE = 'HN'
    ),
    -- CTE 3: 锁定公司集合
    CTE_LOCK_AZI AS (
        SELECT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001
         WHERE REV05_FLAG = 'Y'
           AND COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO = P_PERIODO
           AND COD_CONTO = 'ZAW_D2M_LOCK'
    ),
    -- 主查询：筛选需要更新的行，预计算新值
    CTE_UPD AS (
        SELECT T.OID AS OID,
               -- 预计算 VAR_ALLOC_COST 新值
               NVL(T.ENT_COST_ADJ, 0)
             + NVL(T.ENT_COST, 0)
             + CASE WHEN CTP_BG.COD_AZIENDA IS NOT NULL  -- CTP_ORG 属于 BG001_BU001
                    THEN NVL(T.ELIM_COST, 0)
                    ELSE 0
               END AS NEW_VAR_ALLOC_COST
          FROM AW_MR9_REVM05_000001_TEMP T
          -- LEFT JOIN: 判断 CTP_ORG 是否属于 BG001_BU001（替代 SET 中的相关子查询）
          LEFT JOIN CTE_BG001 CTP_BG
                 ON CTP_BG.COD_AZIENDA = T.COD_AZI_CTP_ORG
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           -- 卖方属于 BG001_BU001
           AND EXISTS (SELECT 1 FROM CTE_BG001 S WHERE S.COD_AZIENDA = T.COD_AZIENDA)
           -- 内销
           AND EXISTS (SELECT 1 FROM CTE_DEST3_HN D WHERE D.ELEM = T.COD_DEST3)
           -- 无物料
           AND T.MATERIAL_CODE IS NULL
           -- 排除特定来源
           AND NVL(T.SRC_DETAIL, '|') NOT IN ('CON_INP')
           AND T.COD_CONTO <> 'SEGP000'
           -- 有成本数据才更新
           AND (NVL(T.ENT_COST, 0) <> 0
             OR NVL(T.ELIM_COST, 0) <> 0
             OR NVL(T.ENT_COST_ADJ, 0) <> 0)
           -- 公司过滤
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           -- 排除锁定公司
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
    )
    SELECT OID, NEW_VAR_ALLOC_COST
      FROM CTE_UPD

) S
ON (A.OID = S.OID)
WHEN MATCHED THEN
    UPDATE SET A.VAR_ALLOC_COST = S.NEW_VAR_ALLOC_COST
;

  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '7.3 END  计算法人成本和大系统产销存的差并分摊', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;

END IF;
  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '计算法人成本和大系统产销存的差并分摊仅视像运行', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;


MERGE /*取消并发*/
INTO AW_MR9_REVM05_000001_TEMP A
USING (
    WITH
    -- ---------------------------------------------------------------
    -- CTE1：BG001_BU020-显示事业部-贵阳工厂端 公司范围
    -- ---------------------------------------------------------------
    CTE_BG001 AS (
        SELECT COD_AZIENDA
          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
         WHERE COD_BG = 'BG001_BU020'
    ),
    -- ---------------------------------------------------------------
    -- CTE2：内销 DEST3 集合（HIE='01', NODE='HN'）
    -- ---------------------------------------------------------------
    CTE_DEST3_HN AS (
        SELECT ELEM
          FROM SESSION_V_REF_DEST3_NONAME
         WHERE SESSION_ID = V_SESSION_ID
           AND HIE = '01'
           AND NODE = 'HN'
    ),
    -- ---------------------------------------------------------------
    -- CTE3：锁定公司集合
    -- ---------------------------------------------------------------
    CTE_LOCK_AZI AS (
        SELECT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001
         WHERE REV05_FLAG  = 'Y'
           AND COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO  = P_PERIODO
           AND COD_CONTO    = 'ZAW_D2M_LOCK'
    ),
    -- ---------------------------------------------------------------
    -- CTE4：折扣物料清单（带有效期判断）
    -- ---------------------------------------------------------------
    ZK_MATERIAL_CODE AS (
        SELECT MATERIAL_CODE
          FROM TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001
         WHERE COD_CONTO = 'ZAW_DWD_LIST_ZHEKOU'
           AND SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
               BETWEEN NVL(VALID_FR, '000000') AND NVL(VALID_TO, '999999')
           AND MATERIAL_CODE IS NOT NULL
    ),
    -- ---------------------------------------------------------------
    -- CTE5：DEST2 映射关系（源→目标，无配置则保留原值）
    -- ---------------------------------------------------------------
    D2_MAP AS (
        SELECT DISTINCT
               CASE WHEN M.FROM_COLUMN_VALUE_1 = '990990000'
                      THEN 'ZZZZ'
                    ELSE M.FROM_COLUMN_VALUE_1
               END AS D2_SRC,
               NVL(D2.ELEM, M.TO_COLUMN_VALUE_1) AS D2_MAP
          FROM TGK_FIMA_HISENSE.AW_RUL_ALCMAP_000001 M
          LEFT JOIN (
                    SELECT NODE, ELEM
                      FROM SESSION_V_REF_DEST2
                     WHERE SESSION_ID = V_SESSION_ID
                    ) D2
            ON M.TO_COLUMN_VALUE_1 = D2.NODE
         WHERE SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
               BETWEEN NVL(M.BEGIN_DATE, '000000') AND NVL(M.END_DATE, '999999')
           AND M.ALCMAP_ID IN (
               'EXP-MAP-A10001', 'EXP-MAP-A10002', 'EXP-MAP-A10003',
               'EXP-MAP-A10004', 'EXP-MAP-A10013', 'EXP-MAP-A10008'
           )
    ),
    -- ---------------------------------------------------------------
    -- CTE6：DEST3 映射关系（源→目标，无配置则保留原值）
    -- ---------------------------------------------------------------
    D3_MAP AS (
        SELECT DISTINCT
               M.FROM_COLUMN_VALUE_1             AS D3_SRC,
               NVL(D3.ELEM, M.TO_COLUMN_VALUE_1) AS D3_MAP
          FROM TGK_FIMA_HISENSE.AW_RUL_ALCMAP_000001 M
          LEFT JOIN (
                    SELECT NODE, ELEM
                      FROM SESSION_V_REF_DEST3_NONAME
                     WHERE SESSION_ID = V_SESSION_ID
                    ) D3
            ON M.TO_COLUMN_VALUE_1 = D3.NODE
         WHERE SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
               BETWEEN NVL(M.BEGIN_DATE, '000000') AND NVL(M.END_DATE, '999999')
           AND M.ALCMAP_ID IN (
               'EXP-MAP-A10006', 'EXP-MAP-A10011', 'EXP-MAP-A100013'
           )
    ),
    -- ---------------------------------------------------------------
    -- CTE7：分摊基础数据（未汇总，只做条件过滤）
    -- ---------------------------------------------------------------
    ALLOC_BASE AS (
        -- 部分①：折扣物料抵消金额
        --   条件：SRC_DETAIL='ELIM' + 本方&对方同在BG001 + 内销 + 折扣物料
        SELECT T.COD_DEST2,
               T.COD_DEST3,
               NVL(T.ELIM_COST, 0) AS ALLOC_AMT
          FROM AW_MR9_REVM05_000001_TEMP T
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           AND T.SRC_DETAIL   = 'ELIM'
           AND EXISTS (SELECT 1 FROM CTE_BG001     B WHERE B.COD_AZIENDA  = T.COD_AZIENDA)
           AND EXISTS (SELECT 1 FROM CTE_BG001     B WHERE B.COD_AZIENDA  = T.COD_AZI_CTP_ORG)
           AND EXISTS (SELECT 1 FROM CTE_DEST3_HN  D WHERE D.ELEM         = T.COD_DEST3)
           AND EXISTS (SELECT 1 FROM ZK_MATERIAL_CODE M WHERE M.MATERIAL_CODE = T.MATERIAL_CODE)
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND (P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL')
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND NVL(T.ELIM_COST, 0) <> 0
        UNION ALL
        -- 部分②：无物料单体成本
        --   条件：MATERIAL_CODE IS NULL + 本方在BG001 + 内销
        SELECT T.COD_DEST2,
               T.COD_DEST3,
               NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0) AS ALLOC_AMT
          FROM AW_MR9_REVM05_000001_TEMP T
         WHERE T.COD_SCENARIO  = P_SCENARIO
           AND T.COD_PERIODO   = P_PERIODO
           AND T.SRC_DETAIL   <> 'ZZFT'
           AND EXISTS (SELECT 1 FROM CTE_BG001    B WHERE B.COD_AZIENDA = T.COD_AZIENDA)
           AND EXISTS (SELECT 1 FROM CTE_DEST3_HN D WHERE D.ELEM        = T.COD_DEST3)
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND (P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL')
         AND T.MATERIAL_CODE IS NULL
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0) <> 0
    ),
    -- ---------------------------------------------------------------
    -- CTE8：待分摊金额
    -- ---------------------------------------------------------------
    ALLOC_COST AS (
        SELECT B.SRC_DEST2, B.SRC_DEST3,
               NVL(D2.D2_MAP, B.SRC_DEST2) AS TARGET_DEST2,
               NVL(D3.D3_MAP, B.SRC_DEST3) AS TARGET_DEST3,
               SUM(B.TOTAL_ALLOC_AMT) AS TOTAL_ALLOC_AMT
          FROM (
                   -- 按原始 DEST2/DEST3 汇总金额
                   SELECT COD_DEST2 AS SRC_DEST2,
                          COD_DEST3 AS SRC_DEST3,
                          SUM(ALLOC_AMT) AS TOTAL_ALLOC_AMT
                     FROM ALLOC_BASE
                    GROUP BY COD_DEST2, COD_DEST3
                    HAVING SUM(ALLOC_AMT) <> 0
               ) B
          LEFT JOIN D2_MAP D2 ON B.SRC_DEST2 = D2.D2_SRC
          LEFT JOIN D3_MAP D3 ON B.SRC_DEST3 = D3.D3_SRC
          GROUP BY B.SRC_DEST2, B.SRC_DEST3,NVL(D2.D2_MAP, B.SRC_DEST2),
                   NVL(D3.D3_MAP, B.SRC_DEST3)
    ),
    -- ---------------------------------------------------------------
    -- CTE9：分摊因子 + 分摊比例
    -- ---------------------------------------------------------------
    ALLOC_BL AS (
        SELECT T.OID,
               ALLOC_COST.SRC_DEST2,ALLOC_COST.SRC_DEST3,
               T.COD_DEST2,
               T.COD_DEST3,
               NVL(T.PSI_COMB_COST, 0) AS BL,
               RATIO_TO_REPORT(NVL(T.PSI_COMB_COST, 0)) OVER (PARTITION BY ALLOC_COST.SRC_DEST2,ALLOC_COST.SRC_DEST3) AS ALLOC_RATIO
          FROM AW_MR9_REVM05_000001_TEMP T
          LEFT JOIN (SELECT DISTINCT SRC_DEST2,SRC_DEST3,TARGET_DEST2,TARGET_DEST3 FROM ALLOC_COST) ALLOC_COST
            ON T.COD_DEST2 = ALLOC_COST.TARGET_DEST2
           AND T.COD_DEST3 = ALLOC_COST.TARGET_DEST3
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           AND EXISTS (SELECT 1 FROM CTE_BG001 B WHERE B.COD_AZIENDA = T.COD_AZIENDA)
           AND T.COD_CATEGORIA NOT IN ('GA00_PA_IN','GA00_PA_IN')
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND (P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL')
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND NVL(T.PSI_COMB_COST, 0) <> 0
    )
    SELECT BL.OID,
           SUM(NVL(AC.TOTAL_ALLOC_AMT,0) * NVL(BL.ALLOC_RATIO,0)) AS ASSESS_NM_ALLOC_COST
      FROM ALLOC_BL BL
      LEFT JOIN ALLOC_COST AC
        ON BL.COD_DEST2 = AC.TARGET_DEST2
       AND BL.COD_DEST3 = AC.TARGET_DEST3
       AND BL.SRC_DEST2 = AC.SRC_DEST2
       AND BL.SRC_DEST3 = AC.SRC_DEST3
     GROUP BY BL.OID
     HAVING SUM(NVL(AC.TOTAL_ALLOC_AMT,0) * NVL(BL.ALLOC_RATIO,0)) <> 0
) S
ON (A.OID = S.OID)
WHEN MATCHED THEN
    UPDATE SET A.ASSESS_NM_ALLOC_COST = S.ASSESS_NM_ALLOC_COST
;





  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_7（ 考核成本无物料分摊）结束', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;





  ------------------------------------------------------------------------------
  -- 8  外销成本处理
  ------------------------------------------------------------------------------


  /*如果收入成本是以下条件的，才把对应字段进行在此列赋值
  收入成本表取数限制条件：
  ①公司范围：【COD_AZIENDA】
  取工厂法人（视像:2000/2300/2330/2900；
  激光：2050;空调：62开头公司（目前6220/6210/6230）；
  冰冷洗：63开头公司（目前6300/6320/6330/6360/6370）；
  厨电：6515）；商冷：6380 20260114 SXX新增）
  ②科目范围限制【COD_CONTO】
  取收入-S6001开头科目，成本-S6401开头科目。
  需剔除AD结尾科目
  ③业务范围限制【COD_DEST3】
  取外销类业务，节点在HW-海外节点下的所有要素
  ④对方公司限制【COD_AZI_CTP_ORG】
  剔除对方公司为工厂法人（视像:2000/2300/2330/2900；
  激光：2050;空调：62开头公司（目前6220/6210/6230）；
  冰冷洗：63开头公司（目前6300/6320/6330/6360/6370）；
  厨电：6515）；商冷：6380 20260114 SXX新增）
  ⑤增加管法差类型限制，只取空调返利【D_DIFF_TYPE】
  限制
  只取【D_DIFF_TYPE】为空、为ZZZZ、为140304001-供应商直接返给空调的外销-压缩机返利，
  法人计入空调，管理口径调给国际营销
  20260114 SXX新增
  */

  /*如果收入成本是以下条件的，才把对应字段进行在此列赋值
  收入成本表取数限制条件：
  ①公司范围：【COD_AZIENDA】
  限制公司为10-海信管理架构下 020节点-国际营销下所有公司
  ②科目范围限制【COD_CONTO】
  成本-S6401开头科目。*/

MERGE /*+ USE_HASH(A S)*/
INTO AW_MR9_REVM05_000001_TEMP A
USING (
    WITH
    -- CTE 1: 外销公司列表（硬编码，与原代码一致）
    -- 原代码中 COD_AZIENDA IN (...) 和 CTP_ORG NOT IN (...) 用的是同一组公司
    CTE_HW_AZI AS (
        SELECT '2000' AS COD_AZIENDA FROM DUAL UNION ALL
        SELECT '2080' FROM DUAL UNION ALL
        SELECT '2023' FROM DUAL UNION ALL
        SELECT '2300' FROM DUAL UNION ALL
        SELECT '2330' FROM DUAL UNION ALL
        SELECT '2900' FROM DUAL UNION ALL
        SELECT '2050' FROM DUAL UNION ALL
        SELECT '6012' FROM DUAL UNION ALL
        SELECT '6220' FROM DUAL UNION ALL
        SELECT '6210' FROM DUAL UNION ALL
        SELECT '6230' FROM DUAL UNION ALL
        SELECT '6300' FROM DUAL UNION ALL
        SELECT '6320' FROM DUAL UNION ALL
        SELECT '6330' FROM DUAL UNION ALL
        SELECT '6360' FROM DUAL UNION ALL
        SELECT '6370' FROM DUAL UNION ALL
        SELECT '6375' FROM DUAL UNION ALL
        SELECT '6515' FROM DUAL UNION ALL
        SELECT '6380' FROM DUAL UNION ALL
        SELECT '6012' FROM DUAL
    ),
    -- CTE 2: DEST3 外销集合
    CTE_DEST3_HW AS (
        SELECT ELEM
          FROM SESSION_V_REF_DEST3_NONAME
         WHERE SESSION_ID = V_SESSION_ID
           AND NODE = 'HW'
    ),
    -- CTE 3: 锁定公司（两个UPDATE共用）
    CTE_LOCK_AZI AS (
        SELECT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001
         WHERE REV05_FLAG = 'Y'
           AND COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO = P_PERIODO
           AND COD_CONTO = 'ZAW_D2M_LOCK'
    ),
    -- CTE 4: 国际营销公司（第二个UPDATE用）
    CTE_IM_AZI AS (
        SELECT ELEM AS COD_AZIENDA
          FROM SESSION_V_REF_AZIENDA
         WHERE NODE = '020'
           AND SESSION_ID = V_SESSION_ID
    ),
    -- CTE 5: 排除的 DEST2（商显+日立利润中心）
    CTE_EXCL_DEST2 AS (
        SELECT ELEM
          FROM SESSION_V_REF_DEST2
         WHERE SESSION_ID = V_SESSION_ID
           AND NODE = '0103'
        UNION ALL
        SELECT '109080000' FROM DUAL UNION ALL
        SELECT '109081000' FROM DUAL UNION ALL
        SELECT '109083000' FROM DUAL UNION ALL
        SELECT '109082000' FROM DUAL UNION ALL
        SELECT '109071000' FROM DUAL UNION ALL
        SELECT '109072000' FROM DUAL UNION ALL
        SELECT '109073000' FROM DUAL UNION ALL
        SELECT '109074000' FROM DUAL UNION ALL
        SELECT '109075000' FROM DUAL UNION ALL
        SELECT '109076000' FROM DUAL UNION ALL
        SELECT '109077000' FROM DUAL UNION ALL
        SELECT '109087000' FROM DUAL UNION ALL
        SELECT '109091000' FROM DUAL
    ),
    -- CTE 6: 主查询 — 判断每行命中哪个UPDATE，预计算新值
    CTE_UPD AS (
        SELECT T.OID AS RID,
               -- 标志位：命中第一个UPDATE条件
               CASE WHEN EXISTS (SELECT 1 FROM CTE_HW_AZI H WHERE H.COD_AZIENDA = T.COD_AZIENDA)
                     AND EXISTS (SELECT 1 FROM CTE_DEST3_HW D WHERE D.ELEM = T.COD_DEST3)
                     AND NOT EXISTS (SELECT 1 FROM CTE_HW_AZI H WHERE H.COD_AZIENDA = NVL(T.COD_AZI_CTP_ORG, '|'))
                     AND NVL(T.CUST_CODE, '|') NOT IN ('4000033', '1010132')
                     AND NVL(T.SRC_DETAIL, '-') <> 'ELIM'
                     AND SUBSTR(T.COD_CONTO, 1, 5) IN ('S6001', 'S6401')
                    THEN 'Y' ELSE 'N'
               END AS IS_HW_UPDATE,
               -- 标志位：命中第二个UPDATE条件
               CASE WHEN EXISTS (SELECT 1 FROM CTE_IM_AZI I WHERE I.COD_AZIENDA = T.COD_AZIENDA)
                     AND T.COD_CONTO LIKE 'S6401%'
                     AND NOT EXISTS (SELECT 1 FROM CTE_EXCL_DEST2 E WHERE E.ELEM = T.COD_DEST2)
                     AND NVL(T.SRC_DETAIL, '-') <> 'ELIM'
                    THEN 'Y' ELSE 'N'
               END AS IS_IM_UPDATE,
               -- 预计算第一个UPDATE的新值
               T.SALE_COGS,
               CASE WHEN T.COD_AZIENDA = '2080' THEN 0 ELSE T.ORG_REV END AS NEW_FAC_EXT_REV
          FROM AW_MR9_REVM05_000001_TEMP T
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND T.PROVENIENZA IN ('CPM_SP_M2M_REV_M')  -- 两个UPDATE都要求
           AND (  -- 至少命中一个UPDATE条件才有意义
               (EXISTS (SELECT 1 FROM CTE_HW_AZI H WHERE H.COD_AZIENDA = T.COD_AZIENDA)
                AND SUBSTR(T.COD_CONTO, 1, 5) IN ('S6001', 'S6401'))
               OR
               (EXISTS (SELECT 1 FROM CTE_IM_AZI I WHERE I.COD_AZIENDA = T.COD_AZIENDA)
                AND T.COD_CONTO LIKE 'S6401%')
           )
    )
    SELECT RID,
           IS_HW_UPDATE,
           IS_IM_UPDATE,
           SALE_COGS,
           NEW_FAC_EXT_REV
      FROM CTE_UPD
     WHERE IS_HW_UPDATE = 'Y' OR IS_IM_UPDATE = 'Y'

) S
ON (A.OID = S.RID)
WHEN MATCHED THEN
    UPDATE SET
        -- 第一个UPDATE的字段（仅命中时赋值，否则保持原值）
        A.FAC_EXTERNAL_SALE_COST    = CASE WHEN S.IS_HW_UPDATE = 'Y' THEN S.SALE_COGS ELSE A.FAC_EXTERNAL_SALE_COST END,
        A.FAC_EXTERNAL_SALE_REVENUE = CASE WHEN S.IS_HW_UPDATE = 'Y' THEN S.NEW_FAC_EXT_REV ELSE A.FAC_EXTERNAL_SALE_REVENUE END,
        -- 第二个UPDATE的字段（仅命中时赋值，否则保持原值）
        A.IM_SALE_COST              = CASE WHEN S.IS_IM_UPDATE = 'Y' THEN S.SALE_COGS ELSE A.IM_SALE_COST END
;

COMMIT;

  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '8  外销成本处理', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '8  外销成本处理',P_AZIENDA);
    COMMIT;


  ------------------------------------------------------------------------------
  -- 9  计算合并销量、合并收入、合并成本
  ------------------------------------------------------------------------------


MERGE INTO AW_MR9_REVM05_000001_TEMP M
USING (


  SELECT    OID
          , CASE WHEN AZ_BG003.COD_AZIENDA IS NOT NULL AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6015'
                   THEN 0
                   ELSE NVL(AW.ENT_QTY,0) + NVL(AW.ENT_QTY_ADJ,0) + NVL(AW.ELIM_QTY,0) + NVL(AW.CADJ_QTY,0)
            END AS MANG_QTY
          , CASE WHEN AZ_BG003.COD_AZIENDA IS NOT NULL AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6015'
                   THEN 0
                   ELSE NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0)
            END AS MANG_REV --端到端收入-BG
          , CASE WHEN AZ_BG003.COD_AZIENDA IS NOT NULL AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6015'
                   THEN 0
                   ELSE NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0) + NVL(AW.FAC_CADJ_REV,0) + NVL(AW.CN_CADJ_REV,0)
            END AS FAC_MANG_REV  --工厂端收入-BU
          , CASE WHEN AZ_BG003.COD_AZIENDA IS NOT NULL AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6015'
                   THEN 0
                   ELSE NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0)
            END AS IM_MANG_REV --国际营销收入-BU
          , CASE WHEN DEST3_HW.ELEM IS NOT NULL AND NVL(AW.SRC_DETAIL,'|') = 'HB_ADJM01'
                   THEN NVL(AW.IM_SALE_COST,0) + NVL(AW.END_UNREAL_GP,0)-NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.CADJ_COST,0)
                 WHEN DEST3_HW.ELEM IS NOT NULL AND NVL(AW.SRC_DETAIL,'|') <> 'ELIM'
                   THEN  NVL(AW.FAC_EXTERNAL_SALE_COST,0)
                      + NVL(AW.IM_SALE_COST,0)
                      + NVL(AW.END_UNREAL_GP,0)-NVL(AW.BEG_UNREAL_GP,0)+ NVL(AW.CADJ_COST,0)
                      + CASE WHEN AW.COD_AZIENDA in('1098') AND NOT(AW.COD_SCENARIO='2026ACT' AND AW.COD_PERIODO='01')
                                THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0)+ NVL(AW.CADJ_COST,0)
                            ELSE 0
                        END
                --非收入成本抵消来源处理-日立
                WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM' AND (AW.COD_AZIENDA LIKE '17%' OR AW.COD_AZIENDA IN ('6240'))
                  THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.CADJ_COST,0)
                --非收入成本抵消来源处理-冰冷洗 & 空调
                WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM' AND (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA IN ( '6000A','6000') OR AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%')
                  THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.CADJ_COST,0)
                --非收入成本抵消来源处理-显示
                WHEN /*SRC_DETAIL <> 'ELIM' AND */
                  (AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%' )
                  AND (NVL(AW.SRC_DETAIL,'|') <> 'ELIM'
                        OR (NVL(AW.SRC_DETAIL,'|') ='ELIM' AND AZ_BG001.COD_AZIENDA IS NOT NULL)
                      )
                  THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.VAR_ALLOC_COST,0) + NVL(AW.END_UNREAL_GP,0) - NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.CADJ_COST,0)
                --非收入成本抵消来源处理-非电冰空
                WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM'
                  THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0) + NVL(AW.END_UNREAL_GP,0) - NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.ELIM_COST,0) + NVL(AW.CADJ_COST,0)
                --外销 内部流转
                WHEN AW.SRC_DETAIL = 'ELIM' AND DEST3_HA0.ELEM IS NOT NULL AND
                  (
                    (
                        (AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%')
                    AND AZ_BG001.COD_AZIENDA IS NOT NULL
                    )
                    OR
                    (
                      (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA  IN ( '6000A','6000') ) AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR AW.COD_AZI_CTP_ORG IN ('6000A','6000'))
                    )
                    OR
                    (
                      (AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%')
                    )
                  )
                THEN NVL(AW.ELIM_COST,0)
              --收入成本抵消来源处理-统一
              WHEN AW.SRC_DETAIL = 'ELIM' AND
               NOT (
                      (
                        (AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%')
                        AND AZ_BG001.COD_AZIENDA IS NOT NULL
                      )
                      OR
                      (
                        (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000') )
                        AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR NVL(AW.COD_AZI_CTP_ORG,'|')  IN( '6000A','6000','6015','6002'))
                      )
                      OR
                      (
                        (AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%'  OR NVL(AW.COD_AZI_CTP_ORG,'|') IN( '6015') )
                      )
                   )
                THEN NVL(AW.ELIM_COST,0)
                ELSE 0
            END AS MANG_COST --端到端成本-BG
          , CASE
              --外销成本 非内部流转
              WHEN DEST3_HW.ELEM IS NOT NULL
                  AND
                    NOT (
                          ((AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%') AND (AZ_BG001.COD_AZIENDA IS NOT NULL))
                          OR
                          ((AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000') ) AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR NVL(AW.COD_AZI_CTP_ORG,'|')    IN( '6000A','6000')))
                          OR
                          ((AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%'))
                        )
                THEN NVL(AW.FAC_EXTERNAL_SALE_COST,0)
              --外销 内部流转
              WHEN AW.SRC_DETAIL = 'ELIM' AND DEST3_HA0.ELEM IS NOT NULL
                   AND
                  (
                      ((AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%') AND (AZ_BG001.COD_AZIENDA IS NOT NULL))
                      OR
                      ((AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000') ) AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR NVL(AW.COD_AZI_CTP_ORG,'|')    IN( '6000A','6000')))
                      OR
                      ((AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%'))
                  )
                THEN NVL(AW.ELIM_COST,0)
              --非收入成本抵消来源处理-日立
              WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM' AND (AW.COD_AZIENDA LIKE '17%' OR AW.COD_AZIENDA IN ('6240'))
                THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.CADJ_COST,0)
              --非收入成本抵消来源处理-冰冷洗 & 空调
              WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM' AND (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%'  OR AW.COD_AZIENDA IN ( '6000A','6000') OR AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%')
                THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.CADJ_COST,0)

              --非收入成本抵消来源处理-显示
              WHEN (AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%' )
                THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.VAR_ALLOC_COST,0) + NVL(AW.END_UNREAL_GP,0) - NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.CADJ_COST,0)

              --非收入成本抵消来源处理-非电冰空
              WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM'
                THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0) + NVL(AW.END_UNREAL_GP,0) - NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.ELIM_COST,0) + NVL(AW.CADJ_COST,0)

              --收入成本抵消来源处理-统一
              WHEN AW.SRC_DETAIL = 'ELIM' AND
              NOT (
                    ((AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%') AND (AZ_BG001.COD_AZIENDA IS NOT NULL))
                    OR
                    ((AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000')) AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR NVL(AW.COD_AZI_CTP_ORG,'|') IN( '6000A','6000')))
                    OR
                    ((AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%'))
                  )
              THEN NVL(AW.ELIM_COST,0)
              ELSE 0
          END AS FAC_MANG_COST --工厂端成本-BU
        , CASE
                    --外销成本
            WHEN DEST3_HW.ELEM IS NOT NULL
              THEN NVL(AW.IM_SALE_COST,0)
               + CASE WHEN AW.COD_AZIENDA in('1098') AND NOT(AW.COD_SCENARIO='2026ACT' AND AW.COD_PERIODO='01')
                        THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0)+ NVL(AW.CADJ_COST,0)
                      ELSE 0
                 END/*20260302 1098 香港分 外销成本算到终端成本 后续2910 也需要增加  即 市场端外销成本 不限于国际营销的成本*/
                    --内销
            ELSE 0
          END AS IM_MANG_COST --国际营销成本-BU
        , NVL(AW.CN_MAP_ZUM,0) + NVL(AW.CN_ELIM_QTY,0) AS CN_MANG_QTY
        , CASE WHEN NVL(AW.COD_CONTO,'|') <> 'S600111'
                 THEN (NVL(AW.CN_ORG_REV,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.CN_ELIM_REV,0))
               ELSE 0
          END AS CN_MANG_REV
        , NVL(AW.CN_SALE_COGS,0) AS CN_MANG_COST
        , CASE WHEN AZ_010102.ELEM IS NOT NULL AND AZ_BG001_BG002.COD_AZIENDA IS NOT NULL
                THEN 0
               WHEN AW.COD_AZIENDA = '2900'
                THEN NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0)
                ELSE NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0)
          END AS ASSESS_MANG_REV
        , CASE WHEN AZ_010102.ELEM IS NOT NULL AND AZ_BG001_BG002.COD_AZIENDA IS NOT NULL
                 THEN 0
               WHEN AW.COD_AZIENDA = '2900'
                THEN NVL(AW.ENT_QTY,0) + NVL(AW.ENT_QTY_ADJ,0)
                  ELSE NVL(AW.ENT_QTY,0) + NVL(AW.ENT_QTY_ADJ,0) + NVL(AW.ELIM_QTY,0) + NVL(AW.CADJ_QTY,0)
          END AS ASSESS_MANG_QTY
        , CASE WHEN AW.COD_AZIENDA IN ('2900','6012')
                /*20260804 SHIQINGFENG.EX 补充2900公司取数时排除ZZFT*/
                /*20260817 CHENDONG3.EX 新增6012公司同逻辑处理*/
                AND SRC_DETAIL <> 'ZZFT'
                 THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0)
               WHEN AZ_010102.ELEM IS NOT NULL
                THEN CASE WHEN DEST3_HW.ELEM IS NOT NULL
                            THEN NVL(AW.CADJ_COST,0) + NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0)
                          WHEN DEST3_HW.ELEM IS NULL
                            THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.ASSESS_NM_ALLOC_COST,0)
                     END
              ELSE 0
          END AS ASSESS_MANG_COST
    FROM AW_MR9_REVM05_000001_TEMP AW
    LEFT JOIN (SELECT DISTINCT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG003_BU011') AZ_BG003
      ON AZ_BG003.COD_AZIENDA = AW.COD_AZIENDA
    LEFT JOIN (SELECT DISTINCT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE SESSION_ID = V_SESSION_ID AND HIE='01' AND NODE='HW') DEST3_HW
      ON DEST3_HW.ELEM = AW.COD_DEST3
    LEFT JOIN (SELECT DISTINCT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG001_BU001') AZ_BG001
      ON AZ_BG001.COD_AZIENDA = AW.COD_AZI_CTP_ORG
    LEFT JOIN (SELECT DISTINCT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE SESSION_ID = V_SESSION_ID AND HIE='01' AND NODE='HA0') DEST3_HA0
      ON DEST3_HA0.ELEM = AW.COD_DEST3
    LEFT JOIN (SELECT DISTINCT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND  HIE = '10' AND NODE = '010102') AZ_010102
      ON AZ_010102.ELEM = AW.COD_AZIENDA
    LEFT JOIN (SELECT DISTINCT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG IN ('BG001_BU001','BG002_BU001')) AZ_BG001_BG002
      ON AZ_BG001_BG002.COD_AZIENDA = AW.COD_AZI_CTP_ORG
  WHERE AW.COD_SCENARIO=P_SCENARIO
  AND AW.COD_PERIODO=P_PERIODO
  AND AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
  --AND (INSTR(V_AZIENDA, AW.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  --对于收入直接调整数据也要做相同逻辑处理 分摊没有物料的 回写反冲值也需要参与
  AND AW.PROVENIENZA IN ('CPM_SP_M2M_REV_M','INPUT_DEFORM','CPM_SP_ZZFT_M_T0')
  AND ( NVL(AW.SRC_DETAIL,'|') NOT IN ( 'CON_INP')
   --OR (AW.COD_SCENARIO='2026ACT' AND AW.COD_PERIODO='01'AND AW.COD_AZIENDA='6515' AND AW.SRC_DETAIL='CON_INP'AND AW.COD_CONTO='S600111')
  )
  /*20260226 新增排除锁定公司*/
/*          AND AW.COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   )*/
) T
ON (M.OID = T.OID)
WHEN MATCHED THEN
  UPDATE SET
        M.MANG_QTY = T.MANG_QTY
      , M.MANG_REV = T.MANG_REV
      , M.FAC_MANG_REV = T.FAC_MANG_REV
      , M.IM_MANG_REV = T.IM_MANG_REV
      , M.MANG_COST = T.MANG_COST
      , M.FAC_MANG_COST = T.FAC_MANG_COST
      , M.IM_MANG_COST = T.IM_MANG_COST
      , M.CN_MANG_QTY = T.CN_MANG_QTY
      , M.CN_MANG_REV = T.CN_MANG_REV
      , M.CN_MANG_COST = T.CN_MANG_COST
      , M.ASSESS_MANG_REV = T.ASSESS_MANG_REV
      , M.ASSESS_MANG_QTY = T.ASSESS_MANG_QTY
      , M.ASSESS_MANG_COST = T.ASSESS_MANG_COST
    ;

    COMMIT;

MERGE INTO AW_MR9_REVM05_000001_TEMP A
USING (
    WITH
    CTE_BG001 AS (
        SELECT DISTINCT COD_AZIENDA
          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
         WHERE COD_BG = 'BG001_BU001'
           AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST A1
                                    WHERE SESSION_ID = V_SESSION_ID)
    ),
    -- CTE 2: 外销 DEST3 集合
    CTE_DEST3_HW AS (
        SELECT DISTINCT ELEM
          FROM SESSION_V_REF_DEST3_NONAME
         WHERE SESSION_ID = V_SESSION_ID
           AND HIE = '01'
           AND NODE = 'HW'
    ),
    -- CTE 3: 利润中心映射
    CTE_DEST2 AS (
        SELECT DISTINCT COD_DEST2
          FROM TGK_FIMA_HISENSE.AW_RUL_PCRMAP_000001
         WHERE COD_BG IN ('BG001_BU001', 'BG002_BU001')
    )/*,
    -- CTE 4: 锁定公司
    CTE_LOCK_AZI AS (
        SELECT DISTINCT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001
         WHERE REV05_FLAG = 'Y'
           AND COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO = P_PERIODO
           AND COD_CONTO = 'ZAW_D2M_LOCK'
    )*/
    -- 主查询：筛选行 + 预计算所有新值（CASE 逻辑全部在此完成）
    SELECT T.OID AS OID,
           CASE WHEN NVL(T.SRC_DETAIL, '|') = 'ELIM' AND CTP_BG.COD_AZIENDA IS NOT NULL
                THEN NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
                   + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
                   + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
                   + NVL(T.ELIM_COST, 0)
                ELSE NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
                   + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
                   + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
           END AS NEW_FAC_EXT_COST,
           CASE WHEN NVL(T.SRC_DETAIL, '|') = 'ELIM' AND CTP_BG.COD_AZIENDA IS NOT NULL
                THEN NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
                   + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
                   + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
                   + NVL(T.ELIM_COST, 0)
                ELSE NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
                   + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
                   + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
           END AS NEW_FAC_MANG_COST,
           NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
         + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
         + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
         + NVL(T.ELIM_COST, 0) AS NEW_MANG_COST
      FROM AW_MR9_REVM05_000001_TEMP T
      LEFT JOIN CTE_BG001 CTP_BG
             ON CTP_BG.COD_AZIENDA = NVL(T.COD_AZI_CTP_ORG, '|')
     WHERE T.COD_SCENARIO = P_SCENARIO
       AND T.COD_PERIODO = P_PERIODO
       AND T.COD_AZIENDA IN (SELECT COD_AZIENDA FROM CTE_BG001)
      --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
       AND EXISTS (SELECT 1 FROM CTE_DEST3_HW D WHERE D.ELEM = T.COD_DEST3)
       --AND EXISTS (SELECT 1 FROM CTE_BG001 S WHERE S.COD_AZIENDA = T.COD_AZIENDA)
       AND EXISTS (SELECT 1 FROM CTE_DEST2 P WHERE P.COD_DEST2 = T.COD_DEST2)
       AND NVL(T.SRC_DETAIL, '|') NOT IN ('CON_INP')
       /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */

) S
ON (A.OID = S.OID)
WHEN MATCHED THEN
    UPDATE SET
        A.FAC_EXTERNAL_SALE_COST = S.NEW_FAC_EXT_COST,
        A.FAC_MANG_COST          = S.NEW_FAC_MANG_COST,
        A.MANG_COST              = S.NEW_MANG_COST
;

    COMMIT;


  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '9  计算合并销量、合并收入、合并成本', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '9  计算合并销量、合并收入、合并成本',P_AZIENDA);
    COMMIT;


 INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
  VALUES('CPM_SP_M2M_REV_M', '客商信息和物料信息补充更新开始', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '客商信息和物料信息补充更新',P_AZIENDA);
  COMMIT;

--20260522 新增客商信息和物料信息补充更新
MERGE  INTO AW_MR9_REVM05_000001_TEMP T
USING (

SELECT DISTINCT
       CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.product_name ELSE AW.MATERIAL_NAME END AS MATERIAL_NAME  --物料描述
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.market_pos_code,'ZZZZ') ELSE AW.D_MARKET_PNT END AS D_MARKET_PNT  --营销定位
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.prod_suite_code,'ZZZZ') ELSE AW.D_PRO_SSER END AS D_PRO_SSER  --产品套系
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(CASE WHEN MARA.big_class_code = 'P01' THEN MARA.SCREEN_SIZE_CODE
                          WHEN MARA.big_class_code = 'P02' THEN MARA.SPEC_RANGE_CODE
                          WHEN MARA.big_class_code = 'P03' THEN MARA.TOTAL_CAPACITY_CODE
                          WHEN MARA.big_class_code = 'P04' THEN MARA.WASHING_CAPACITY_CODE
                     END,'ZZZZ')
            ELSE AW.D_SPEC_SEC END AS D_SPEC_SEC  --规格
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.product_spec_code,'ZZZZ') ELSE AW.D_PRO_TYPE_S END AS D_PRO_TYPE_S  --产品形态分类
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.prod_stage_code,'ZZZZ') ELSE AW.D_PRO_STAGE END AS D_PRO_STAGE  --产品阶段
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.price_range_code,'ZZZZ') ELSE AW.D_PRI_RANGE END AS D_PRI_RANGE  --价格段
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.series_code,'ZZZZ') ELSE AW.D_PRO_SERIES END AS D_PRO_SERIES  --产品系列
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.ac_ct_code,'ZZZZ') ELSE AW.D_TECH_TYPE END AS D_TECH_TYPE  --技术类型
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CASE WHEN MARA.is_miniled_code = 'PC00013001' THEN '是'
                      WHEN MARA.is_miniled_code = 'PC00013002' THEN '否'
                      ELSE ''
                 END
            ELSE AW.IS_MINILED_CODE END AS IS_MINILED_CODE  --是否MiniLED
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.small_class_code,'ZZZZ') ELSE AW.D_PRO_CLASS END AS D_PRO_CLASS  --产品类别（产品大中小类）
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.model_lca,'ZZZZ') ELSE AW.D_MODEL_LCA END AS D_MODEL_LCA  --产品型号生命周期
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN '' ELSE AW.SALE_MODEL_NAME END AS SALE_MODEL_NAME  --销售型号
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.MODEL_CODE ELSE AW.MODEL_CODE END AS MODEL_CODE  --产品型号
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.model_name ELSE AW.MODEL_NAME END AS MODEL_NAME  --产品型号
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CASE WHEN AZ.SAP_VERSION IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                     ELSE LTRIM(mara.matkl,'0')
                END
            ELSE AW.MATERIAL_GROUP_CODE END AS MATERIAL_GROUP_CODE  --物料组
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.miniled_type_code,'ZZZZ') ELSE AW.D_MINILED END AS D_MINILED  --miniled类型
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN COALESCE(
                     NULLIF(UPPER(MARA.sale_model_name), '无'),
                     NULLIF(UPPER(MARA.zcusmodel),       '无')
                 )
            ELSE AW.customer_model END AS customer_model  --客户型号

     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN KNA1.name1 ELSE AW.CUST_NAME END AS CUST_NAME  --客商描述
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(CUST_INFO.com_3rd_code,'ZZZZ') ELSE AW.D_CHANNEL END AS D_CHANNEL  --公司三级分类
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(CUST_TRADE_INFO.MARKET_MODE_CODE,'ZZZZ') ELSE AW.D_MODE END AS D_MODE  --营销模式
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(CUST_INFO.channel_small_class_code,'ZZZZ') ELSE AW.D_CNL_C_TYPE END AS D_CNL_C_TYPE  --渠道客户小类
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(CUST_INFO.ind_small_class_code,'ZZZZ') ELSE AW.D_IND_C_TYPE END AS D_IND_C_TYPE  --行业客户小类
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CUST_INFO.cust_unity_name ELSE AW.CUST_UNITY_NAME END AS CUST_UNITY_NAME  --统一客户组
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CUST_INFO.credit_level ELSE AW.CREDIT_LEVEL_NAME END AS CREDIT_LEVEL_NAME  --信用等级
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CUST_INFO.unit_nature_name ELSE AW.CUST_NATURE_NAME END AS CUST_NATURE_NAME  --单位性质
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CASE
                   WHEN CUST_INFO.is_channel_cust_type IS NULL
                    AND CUST_INFO.is_ent_cust_type IS NULL
                    AND CUST_INFO.is_fi_cust_type IS NULL
                   THEN NULL
                   ELSE REGEXP_REPLACE(
                       CASE WHEN CUST_INFO.is_channel_cust_type = 'Y' THEN ',渠道客户(经营)' ELSE '' END ||
                       CASE WHEN CUST_INFO.is_ent_cust_type = 'Y' THEN ',企事业单位(消费)' ELSE '' END ||
                       CASE WHEN CUST_INFO.is_fi_cust_type = 'Y' THEN ',财务类客户' ELSE '' END
                       , '^,|,$'
                       , ''
                     )
                 END
            ELSE AW.CUST_TYPE_NAME END AS CUST_TYPE_NAME  --客户类型
     , CASE WHEN NVL(LTRIM(AW.sold_to_code),'ZZZZ') <> 'ZZZZ'
            THEN KNA1_sold.name1 ELSE AW.sold_to_name END AS sold_to_name  --售达方名称

     , OID
  FROM
(
-- AW子查询：从目标表中取出所有需要保留原值的字段
SELECT OID
     , COD_AZIENDA
     , CUST_CODE
     , sold_to_code
     , MATERIAL_CODE
     , MATERIAL_GROUP_CODE
     -- 物料相关原值字段
     , MATERIAL_NAME
     , D_MARKET_PNT
     , D_PRO_SSER
     , D_SPEC_SEC
     , D_PRO_TYPE_S
     , D_PRO_STAGE
     , D_PRI_RANGE
     , D_PRO_SERIES
     , D_TECH_TYPE
     , IS_MINILED_CODE
     , D_PRO_CLASS
     , D_MODEL_LCA
     , SALE_MODEL_NAME
     , MODEL_CODE
     , MODEL_NAME
     , D_MINILED
     , customer_model
     -- 客商相关原值字段
     , CUST_NAME
     , D_CHANNEL
     , D_MODE
     , D_CNL_C_TYPE
     , D_IND_C_TYPE
     , CUST_UNITY_NAME
     , CREDIT_LEVEL_NAME
     , CUST_NATURE_NAME
     , CUST_TYPE_NAME
     , sold_to_name
  FROM AW_MR9_REVM05_000001_TEMP PS
 WHERE COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
   AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0')
   /*20260226 新增排除锁定公司*/
   /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                            FROM AW_RUL_DWMCRS_000001 T
                           WHERE REV05_FLAG = 'Y'
                             AND T.COD_SCENARIO = P_SCENARIO
                             AND T.COD_PERIODO = P_PERIODO
                             AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                           ) */
   AND (SRC_DETAIL IN ('HB_ADJM01','POLICY_YT','ELIM') OR NVL(POLICY_AMT,0) <> 0)
) AW
LEFT JOIN (SELECT COD_AZIENDA,'S'||CITTA_LEGALE SAP_VERSION FROM tgk_fima_hisense.AZIENDA) AZ
  ON AW.COD_AZIENDA = AZ.COD_AZIENDA
LEFT JOIN
(
SELECT 'S'||MANDT AS SAP_VERSION,KUNNR,zkunnr_mdg,name1 FROM tgk_fima_hisense.DS_DWD_SAP_KNA1
) KNA1
  ON AZ.SAP_VERSION = KNA1.SAP_VERSION
 AND LTRIM(KNA1.kunnr,'0') = AW.CUST_CODE
LEFT JOIN
(
SELECT 'S'||MANDT AS SAP_VERSION,KUNNR,zkunnr_mdg,name1 FROM tgk_fima_hisense.DS_DWD_SAP_KNA1
) KNA1_sold
  ON AZ.SAP_VERSION = KNA1_sold.SAP_VERSION
 AND LTRIM(KNA1_sold.kunnr,'0') = AW.sold_to_code

LEFT JOIN tgk_fima_hisense.DIM_CUSTOMER_BASE_INFO_DD CUST_INFO
  ON LTRIM(KNA1.zkunnr_mdg,'0') = LTRIM(CUST_INFO.cust_code,'0')
LEFT JOIN TGK_FIMA_HISENSE.DIM_FI_PRODUCT MARA
  ON MARA.matnr = AW.MATERIAL_CODE
LEFT JOIN tgk_fima_hisense.DIM_CUSTOMER_TRADE_INFO_DD CUST_TRADE_INFO
  ON LTRIM(KNA1.zkunnr_mdg,'0') = LTRIM(CUST_TRADE_INFO.cust_code,'0')
 AND AW.COD_AZIENDA = CUST_TRADE_INFO.sale_org
 AND CASE WHEN NVL(LTRIM(AW.MATERIAL_GROUP_CODE),'|') = '|' OR AW.MATERIAL_GROUP_CODE = 'ZZZZ'
           THEN CASE WHEN AZ.SAP_VERSION IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                ELSE LTRIM(mara.matkl,'0')
                END
           ELSE AW.MATERIAL_GROUP_CODE
      END  = CUST_TRADE_INFO.material_group_code
LEFT JOIN (
  SELECT cust_code AS kunrg
        ,cp_company_code AS COD_AZI_CTP
        ,system_src AS system_src
    FROM tgk_fima_hisense.dim_rule_fi_mr_cust2ctp_mapping a
  WHERE cust_type_code = 'C'
    AND NVL(valid_fr,'202401') <= SUBSTR(P_SCENARIO,0,4)||P_PERIODO
    AND NVL(valid_to,'999999') >= SUBSTR(P_SCENARIO,0,4)||P_PERIODO
) CTP
ON CTP.kunrg = AW.CUST_CODE
AND CTP.system_src = AZ.SAP_VERSION

) C
ON(
   T.OID = C.OID
)
WHEN MATCHED THEN
UPDATE SET
       T.MATERIAL_NAME      = C.MATERIAL_NAME             -- 物料描述
      ,T.D_MARKET_PNT       = C.D_MARKET_PNT              -- 营销定位
      ,T.D_PRO_SSER         = C.D_PRO_SSER                -- 产品套系
      ,T.D_SPEC_SEC         = C.D_SPEC_SEC                -- 规格
      ,T.D_PRO_TYPE_S       = C.D_PRO_TYPE_S              -- 产品形态分类
      ,T.D_PRO_STAGE        = C.D_PRO_STAGE               -- 产品阶段
      ,T.D_PRI_RANGE        = C.D_PRI_RANGE               -- 价格段
      ,T.D_PRO_SERIES       = C.D_PRO_SERIES              -- 产品系列
      ,T.D_TECH_TYPE        = C.D_TECH_TYPE               -- 技术类型
      ,T.IS_MINILED_CODE    = C.IS_MINILED_CODE           -- 是否MiniLED
      ,T.D_PRO_CLASS        = C.D_PRO_CLASS                -- 产品类别（产品大中小类）
      ,T.D_MODEL_LCA        = C.D_MODEL_LCA               -- 产品型号生命周期
      ,T.SALE_MODEL_NAME    = C.SALE_MODEL_NAME           -- 销售型号
      ,T.MODEL_CODE         = C.MODEL_CODE                 -- 产品型号编码
      ,T.MODEL_NAME         = C.MODEL_NAME                 -- 产品型号名称
      ,T.MATERIAL_GROUP_CODE= C.MATERIAL_GROUP_CODE        -- 物料组
      ,T.D_MINILED          = C.D_MINILED                  -- miniled类型
      ,T.customer_model     = C.customer_model             -- 客户型号
      ,T.CUST_NAME          = C.CUST_NAME                  -- 客商描述
      ,T.D_CHANNEL          = C.D_CHANNEL                  -- 公司三级分类
      ,T.D_MODE             = C.D_MODE                     -- 营销模式
      ,T.D_CNL_C_TYPE       = C.D_CNL_C_TYPE              -- 渠道客户小类
      ,T.D_IND_C_TYPE       = C.D_IND_C_TYPE              -- 行业客户小类
      ,T.CUST_UNITY_NAME    = C.CUST_UNITY_NAME           -- 统一客户组
      ,T.CREDIT_LEVEL_NAME  = C.CREDIT_LEVEL_NAME         -- 信用等级
      ,T.CUST_NATURE_NAME   = C.CUST_NATURE_NAME          -- 单位性质
      ,T.CUST_TYPE_NAME     = C.CUST_TYPE_NAME            -- 客户类型
      ,T.sold_to_name       = C.sold_to_name               -- 售达方名称
;


INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
  VALUES('CPM_SP_M2M_REV_M', '临时表处理', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '临时表处理完成,插入aw表开始',P_AZIENDA);
  COMMIT;
    DELETE FROM AW_MR9_REVM05_000001
    WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
     --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0')
      /*20260226 新增排除锁定公司*/
      /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   ) */
          ;

  INSERT INTO AW_MR9_REVM05_000001
  (OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT, D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST, AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST, DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL, FAC_EXTERNAL_SALE_COST, FAC_EXTERNAL_SALE_REVENUE, IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY, CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST, ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY, FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY,D_MINILED,ASSESS_MANG_COST,ASSESS_MANG_REV,ASSESS_MANG_QTY
  ,D_BUS_SCE_S
  ,ASSESS_NM_ALLOC_COST
  ,STD_QTY
  ,MA_SALE_COGS
  )

  SELECT NEWID() OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT, D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST, AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST, DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL, FAC_EXTERNAL_SALE_COST, FAC_EXTERNAL_SALE_REVENUE, IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY, CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST, ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY, FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY ,D_MINILED,ASSESS_MANG_COST,ASSESS_MANG_REV,ASSESS_MANG_QTY
  ,D_BUS_SCE_S
  ,ASSESS_NM_ALLOC_COST
  ,STD_QTY
  ,MA_SALE_COGS
  FROM AW_MR9_REVM05_000001_TEMP
    WHERE COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
   AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0')
          /*20260226 新增排除锁定公司*/
          /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   ) */
          ;
INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
  VALUES('CPM_SP_M2M_REV_M', '临时表插入AW', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入完成',P_AZIENDA);
  COMMIT;
  
--EDIT BY CHENDONG3.EX 260817 将中国区费用转政策的业务在产品公司还原的部分，对方公司置为空，以确保后续不参与抵消
UPDATE AW_MR9_REVM05_000001 T
SET T.COD_AZI_CTP = ''
WHERE D_OPER_TYPE IN ('OPTY039','OPTY040')
     AND D_ADJ_TYPE = 'REV_01_221'
     AND COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
     AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0')
     ;
  
--用于获取外销成本-高低开及预分成调整数
CPM_SP_M2M_REVADJ_M(P_SCENARIO,P_PERIODO,SESSION_USER);

--EDIT BY LC 260302 空调配套数据生成
IF V_ENTITY = 'KT' OR P_AZIENDA = 'ALL' THEN
   CPM_SP_M2M_ZSET_M(P_SCENARIO,P_PERIODO,SESSION_USER);
END IF;

--ADD BY YH 20260405 新增调用CPM_SP_M2M_OPL_SUP程序
 CPM_SP_M2M_OPL_SUP(P_SCENARIO,P_PERIODO,SESSION_USER);



DELETE
   FROM AW_MR9_REVM01_000001_CON_TEMP T
  WHERE --SUBSTR(T.COD_SCENARIO,1,4) || T.COD_PERIODO IN (v_per0, v_per1, v_per2)
    1=1
    AND (
           (T.COD_SCENARIO = v_per0_ACT
          AND T.COD_PERIODO = v_per0_per
           )
          OR
           (T.COD_SCENARIO = v_per1_ACT
          AND T.COD_PERIODO = v_per1_per
          )
          OR
           (T.COD_SCENARIO = v_per2_ACT
          AND T.COD_PERIODO = v_per2_per
          )
        )
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                    WHERE SESSION_ID = V_SESSION_ID
                    )
    ;
-- 删除本 Session 数据
DELETE FROM TMP_TABLE_POLICY_ALLOC
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM TMP_TABLE_POLICY
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM TMP_TABLE_ENT
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_V_REF_AZIENDA
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_V_REF_DEST3_NONAME
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_V_REF_DEST2
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_AZIENDA_LIST
WHERE SESSION_ID = V_SESSION_ID;


/* 记录日志 */
INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
  VALUES('CPM_SP_M2M_REV_M', '99 ENDT', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '计算完成',P_AZIENDA);

  COMMIT;




/*    EXCEPTION
    WHEN OTHERS THEN
    ROLLBACK;
    V_ERROR_COD:=SQLCODE;
    V_ERROR_MSG:=SQLERRM;
    INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M',SUBSTR(V_ERROR_COD||V_ERROR_MSG,1,1000),SYSDATE,SESSION_USER,P_SCENARIO,P_PERIODO,P_AZIENDA);
    COMMIT;*/

END ;