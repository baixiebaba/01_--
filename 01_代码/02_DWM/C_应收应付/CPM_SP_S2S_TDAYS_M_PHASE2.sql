CREATE OR REPLACE PROCEDURE CPM_SP_S2S_TDAYS_M_PHASE2(
    P_SCENARIO   IN VARCHAR2
  , P_PERIODO   IN VARCHAR2
  , P_AZIENDA   IN VARCHAR2
  , P_BG        IN VARCHAR2
  , P_EXP       IN VARCHAR2
  , SESSION_USER IN VARCHAR2
) AS
  /****
  最后更新时间：20261021
  本次修改：新增模块参数P_EXP，仅读取AW_RUL_TOVCAL_000001中EXP_TYPE=P_EXP的有效配置。
            目标表新增IS_MTR_FLAG字段，直接写入配置表当前IS_MTR_FLAG。
            日志COD_AZIENDA统一按参考TOV过程记录为P_BG || '|' || V_AZIENDA。
  上次修改：按AW_RUL_TOVCAL_000001有效配置逐条动态读取来源表，直接汇总并写入配置目标表。
            不使用SESSION_TOVCAL_RESULT、SESSION_TOVCAL_SCOPE、GTT或DBMS_SQL暂存结果。
  名称：CPM_SP_S2S_TDAYS_M_PHASE2
  用途：周转计算配置驱动的S2S装载过程。
  源表：AW_RUL_TOVCAL_000001配置的SOURCE_TABLE。
  目标表：AW_RUL_TOVCAL_000001配置的TARGET_TABLE，当前业务目标为AW_MR7_ARPA01_000001。
  说明：每条配置均按10组取数限制读取来源表，按COD_CATEGORIA、COD_VALUTA和配置目标维度汇总18个金额，
        再在外层SELECT计算6个周转天数后直接插入目标表。
  版本信息：最新修改记录放在最上面
  **************************************************************************/
  V_SCENARIO       VARCHAR2(30);
  V_PERIODO        VARCHAR2(30);
  V_YEARMONTH      VARCHAR2(10);
  V_AZIENDA        VARCHAR2(4000);
  V_BG             VARCHAR2(4000);
  V_SESSION_ID     NUMBER;
  V_SQL            CLOB;
  V_DELETE_SQL     VARCHAR2(32767);
  V_TARGET_OBJECT  VARCHAR2(261);
  V_TARGET_SCOPE   VARCHAR2(4000);
  V_TARGET_AZIENDA VARCHAR2(4000);
  V_TARGET_BG      VARCHAR2(4000);
  V_SOURCE_OBJECT  VARCHAR2(261);
  V_CONFIG_COUNT   NUMBER := 0;
  V_INSERT_COUNT   NUMBER := 0;
  V_SESSION_AZIENDA_COUNT NUMBER := 0;
  V_ERROR_COD      NUMBER;
  V_ERROR_MSG      VARCHAR2(4000);
  V_ERROR_STAGE    VARCHAR2(100) := '参数校验';
  V_ERROR_SOURCE   VARCHAR2(261);
  V_ERROR_TARGET   VARCHAR2(261);
  V_ERROR_RULE     VARCHAR2(4000);

  TYPE T_SEEN_TABLE IS TABLE OF BOOLEAN INDEX BY VARCHAR2(4000);
  V_TARGET_SEEN T_SEEN_TABLE;

  TYPE T_BIND_TABLE IS TABLE OF VARCHAR2(4000) INDEX BY PLS_INTEGER;
  V_BIND_VALUE T_BIND_TABLE;
  V_BIND_AUX   T_BIND_TABLE;
  V_BIND_EXTRA T_BIND_TABLE;

  -- 功能：规范化逗号分隔的运行参数列表。
  -- 处理：去除首尾空格、统一转换为大写，并清理逗号两侧的空白。
  -- 用途：统一处理P_AZIENDA和P_BG，便于后续进行公司/事业部范围匹配。
  FUNCTION NORMALIZE_LIST(P_VALUE VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN UPPER(REGEXP_REPLACE(TRIM(P_VALUE), '[[:space:]]*,[[:space:]]*', ','));
  END;

  -- 功能：判断一个值是否命中逗号分隔的参数列表。
  -- 处理：参数列表为ALL时代表不限制；否则按完整编码匹配，避免部分字符串误匹配。
  -- 用途：判断当前配置的事业部是否属于本次过程的P_BG运行范围。
  FUNCTION LIST_MATCH(P_LIST VARCHAR2, P_VALUE VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN UPPER(TRIM(P_LIST)) = 'ALL'
       OR INSTR(',' || P_LIST || ',', ',' || UPPER(TRIM(P_VALUE)) || ',') > 0;
  END;

  -- 功能：生成目标维度字段的标准值。
  -- 处理：目标配置为空或仅包含空白时，统一写入ZZZZ；其他值去除首尾空格后原样保留。
  -- 用途：用于配置生成的目标维度，确保目标表输出粒度稳定。
  FUNCTION DIM_VALUE(P_VALUE VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN NVL(NULLIF(TRIM(P_VALUE), ''), 'ZZZZ');
  END;

  -- 功能：生成目标公司维度的标准值。
  -- 处理：配置公司为空时写入ZZZZ，具体公司保留原编码；当前资料未确认其他配置通配字面量。
  -- 用途：区分配置目标公司与P_AZIENDA运行参数，避免把运行参数ALL写入目标维度。
  FUNCTION TARGET_AZIENDA_VALUE(P_VALUE VARCHAR2) RETURN VARCHAR2 IS
  BEGIN
    RETURN NVL(NULLIF(TRIM(P_VALUE), ''), 'ZZZZ');
  END;

  -- 功能：校验并规范化动态表名或视图名.
  -- 处理：只允许简单对象名或OWNER.OBJECT格式，并通过DBMS_ASSERT防止非法对象注入。
  -- 用途：SOURCE_TABLE、TARGET_TABLE以及HIE引用表都会先经过本函数处理，再拼接到动态SQL中。
  FUNCTION SAFE_OBJECT(P_OBJECT_NAME VARCHAR2) RETURN VARCHAR2 IS
    V_OBJECT_NAME VARCHAR2(261) := UPPER(TRIM(P_OBJECT_NAME));
  BEGIN
    IF V_OBJECT_NAME IS NULL
       OR NOT REGEXP_LIKE(V_OBJECT_NAME, '^[A-Z][A-Z0-9_$#]*(\.[A-Z][A-Z0-9_$#]*)?$') THEN
      RAISE_APPLICATION_ERROR(-20001, '动态对象名非法：' || SUBSTR(P_OBJECT_NAME, 1, 200));
    END IF;
    RETURN DBMS_ASSERT.SQL_OBJECT_NAME(V_OBJECT_NAME);
  END;

  -- 功能：校验并规范化动态字段名。
  -- 处理：只允许简单字段名，并通过DBMS_ASSERT限制为合法SQL标识符。
  -- 用途：COLUMN_NAME_1至COLUMN_NAME_10会调用本函数，防止配置字段名直接注入动态SQL。
  FUNCTION SAFE_COLUMN(P_COLUMN_NAME VARCHAR2) RETURN VARCHAR2 IS
    V_COLUMN_NAME VARCHAR2(128) := UPPER(TRIM(P_COLUMN_NAME));
  BEGIN
    IF V_COLUMN_NAME IS NULL
       OR NOT REGEXP_LIKE(V_COLUMN_NAME, '^[A-Z][A-Z0-9_$#]*$') THEN
      RAISE_APPLICATION_ERROR(-20002, '动态字段名非法：' || SUBSTR(P_COLUMN_NAME, 1, 200));
    END IF;
    RETURN DBMS_ASSERT.SIMPLE_SQL_NAME(V_COLUMN_NAME);
  END;

  -- 功能：将一组配置字段、筛选规则和筛选值转换为动态SQL条件。
  -- 处理：根据规则生成=、<>、IN、LIKE、NOT LIKE、HIE、NOT IN、IS NULL和IS NOT NULL条件。
  -- 处理：筛选值通过绑定变量传入；字段名和HIE引用表经过安全校验后才拼接SQL。
  -- 用途：被主过程调用10次，10组有效取数限制之间使用AND关系。
  PROCEDURE APPEND_FILTER(
      P_COLUMN    IN VARCHAR2
    , P_OPERATOR  IN VARCHAR2
    , P_VALUE     IN VARCHAR2
    , P_GROUP_NO  IN PLS_INTEGER
  ) IS
    V_COLUMN       VARCHAR2(128) := UPPER(TRIM(P_COLUMN));
    V_OPERATOR     VARCHAR2(30) := UPPER(TRIM(P_OPERATOR));
    V_VALUE        VARCHAR2(4000) := P_VALUE;
    V_HIE_OBJECT   VARCHAR2(261);
    V_HIE          VARCHAR2(4000);
    V_NODE         VARCHAR2(4000);
    V_POSITION     PLS_INTEGER;
    V_BIND_PREFIX  VARCHAR2(30) := 'B_G' || LPAD(P_GROUP_NO, 2, '0');
  BEGIN
    V_BIND_VALUE(P_GROUP_NO) := NULL;
    V_BIND_AUX(P_GROUP_NO) := NULL;
    V_BIND_EXTRA(P_GROUP_NO) := NULL;

    -- 每组筛选都保留三个绑定位置：值、HIE/NODE辅助值和无业务含义的占位值。
    -- 这样可使用EXECUTE IMMEDIATE完成全部10组动态条件，不引入DBMS_SQL。
    IF V_COLUMN IS NULL AND V_OPERATOR IS NULL AND V_VALUE IS NULL THEN
      V_SQL := V_SQL || CHR(10) || ' AND (NVL(LENGTH(:' || V_BIND_PREFIX || '_V), 0) >= 0'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_A), 0) >= 0'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_X), 0) >= 0)';
      RETURN;
    END IF;

    IF V_COLUMN IS NULL OR V_OPERATOR IS NULL THEN
      RAISE_APPLICATION_ERROR(-20003, '第' || P_GROUP_NO || '组筛选必须同时填写字段和规则');
    END IF;
    V_COLUMN := SAFE_COLUMN(V_COLUMN);

    -- 当前组：普通等值和不等值筛选。
    IF V_OPERATOR IN ('=', '<>') THEN
      IF TRIM(V_VALUE) IS NULL OR INSTR(V_VALUE, ',') > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, '第' || P_GROUP_NO || '组' || V_OPERATOR || '规则值非法');
      END IF;
      V_BIND_VALUE(P_GROUP_NO) := TRIM(V_VALUE);
      V_SQL := V_SQL || CHR(10) || ' AND (S.' || V_COLUMN || ' ' || V_OPERATOR
        || ' :' || V_BIND_PREFIX || '_V'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_A), 0) >= 0'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_X), 0) >= 0)';

    -- 当前组：IN和NOT IN值以逗号分隔，值本身使用绑定变量。
    ELSIF V_OPERATOR IN ('IN', 'NOT IN') THEN
      IF TRIM(V_VALUE) IS NULL OR REGEXP_LIKE(V_VALUE, '(^|,)[[:space:]]*(,|$)') THEN
        RAISE_APPLICATION_ERROR(-20005, '第' || P_GROUP_NO || '组' || V_OPERATOR || '规则含空值项');
      END IF;
      V_BIND_VALUE(P_GROUP_NO) := V_VALUE;
      V_SQL := V_SQL || CHR(10) || ' AND (S.' || V_COLUMN || ' ' || V_OPERATOR || ' ('
        || 'SELECT TRIM(REGEXP_SUBSTR(L.LIST_VALUE, ''[^,]+'', 1, LEVEL))'
        || ' FROM (SELECT :' || V_BIND_PREFIX || '_V AS LIST_VALUE FROM DUAL) L'
        || ' CONNECT BY LEVEL <= REGEXP_COUNT(L.LIST_VALUE, '','') + 1)'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_A), 0) >= 0'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_X), 0) >= 0)';
      -- IN/NOT IN的第一个绑定值由子查询只读取一次，另外两个位置为占位绑定。
      V_BIND_AUX(P_GROUP_NO) := NULL;

    -- 当前组：LIKE和NOT LIKE筛选。
    ELSIF V_OPERATOR IN ('LIKE', 'NOT LIKE') THEN
      IF V_VALUE IS NULL THEN
        RAISE_APPLICATION_ERROR(-20006, '第' || P_GROUP_NO || '组' || V_OPERATOR || '规则必须填写值');
      END IF;
      V_BIND_VALUE(P_GROUP_NO) := V_VALUE;
      V_SQL := V_SQL || CHR(10) || ' AND (S.' || V_COLUMN || ' ' || V_OPERATOR
        || ' :' || V_BIND_PREFIX || '_V'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_A), 0) >= 0'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_X), 0) >= 0)';

    -- 当前组：HIE值按HIE|NODE拆分并通过引用表ELEM过滤。
    ELSIF V_OPERATOR = 'HIE' THEN
      V_POSITION := INSTR(V_VALUE, '|');
      IF V_POSITION <= 1 OR V_POSITION = LENGTH(V_VALUE)
         OR INSTR(V_VALUE, '|', V_POSITION + 1) > 0 THEN
        RAISE_APPLICATION_ERROR(-20007, '第' || P_GROUP_NO || '组HIE值必须为HIE|NODE格式');
      END IF;
      V_HIE := TRIM(SUBSTR(V_VALUE, 1, V_POSITION - 1));
      V_NODE := TRIM(SUBSTR(V_VALUE, V_POSITION + 1));
      IF V_HIE IS NULL OR V_NODE IS NULL THEN
        RAISE_APPLICATION_ERROR(-20008, '第' || P_GROUP_NO || '组HIE或NODE不能为空');
      END IF;
      IF SUBSTR(V_COLUMN, 1, 4) = 'COD_' THEN
        V_HIE_OBJECT := SAFE_OBJECT('V_REF_' || SUBSTR(V_COLUMN, 5));
      ELSIF SUBSTR(V_COLUMN, 1, 2) = 'D_' THEN
        V_HIE_OBJECT := SAFE_OBJECT('V_REF_ED_' || V_COLUMN);
      ELSE
        RAISE_APPLICATION_ERROR(-20009, '第' || P_GROUP_NO || '组HIE字段必须以COD_或D_开头：' || V_COLUMN);
      END IF;
      V_BIND_VALUE(P_GROUP_NO) := V_HIE;
      V_BIND_AUX(P_GROUP_NO) := V_NODE;
      V_SQL := V_SQL || CHR(10) || ' AND (S.' || V_COLUMN || ' IN ('
        || 'SELECT ELEM FROM ' || V_HIE_OBJECT
        || ' WHERE HIE = :' || V_BIND_PREFIX || '_V'
        || ' AND NODE = :' || V_BIND_PREFIX || '_A)'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_X), 0) >= 0)';

    -- 当前组：空值和非空值筛选。
    ELSIF V_OPERATOR IN ('IS NULL', 'IS NOT NULL') THEN
      IF V_VALUE IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20010, '第' || P_GROUP_NO || '组' || V_OPERATOR || '规则值必须为空');
      END IF;
      V_SQL := V_SQL || CHR(10) || ' AND (S.' || V_COLUMN || ' ' || V_OPERATOR
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_V), 0) >= 0'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_A), 0) >= 0'
        || ' AND NVL(LENGTH(:' || V_BIND_PREFIX || '_X), 0) >= 0)';
    ELSE
      RAISE_APPLICATION_ERROR(-20011, '第' || P_GROUP_NO || '组不支持筛选规则：' || V_OPERATOR);
    END IF;
  END;

BEGIN
  -- ============================================================================
  -- 第一阶段：初始化运行参数。
  -- 将场景、期间、公司和事业部参数标准化，并生成配置有效期匹配使用的YYYYMM。
  -- ============================================================================
  V_ERROR_STAGE := '参数校验';
  V_SCENARIO := TRIM(P_SCENARIO);
  V_PERIODO := LPAD(TRIM(P_PERIODO), 2, '0');
  V_AZIENDA := NORMALIZE_LIST(P_AZIENDA);
  V_BG := NORMALIZE_LIST(P_BG);
  V_YEARMONTH := SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO;

  IF V_SCENARIO IS NULL OR V_PERIODO IS NULL OR V_AZIENDA IS NULL OR V_BG IS NULL
     OR TRIM(P_EXP) IS NULL OR TRIM(SESSION_USER) IS NULL THEN
    RAISE_APPLICATION_ERROR(-20012, '场景、期间、公司、事业部、模块和用户不能为空');
  END IF;
  IF NOT REGEXP_LIKE(SUBSTR(V_SCENARIO, 1, 4), '^[0-9]{4}$') THEN
    RAISE_APPLICATION_ERROR(-20013, 'P_SCENARIO前四位必须为年份');
  END IF;
  IF NOT REGEXP_LIKE(V_PERIODO, '^(0[1-9]|1[0-2])$') THEN
    RAISE_APPLICATION_ERROR(-20014, 'P_PERIODO必须为01至12');
  END IF;

  -- ============================================================================
  -- 第二阶段：按参考TOV过程初始化当前数据库SESSION的公司范围。
  -- P_AZIENDA/P_BG是本次运行范围；SESSION_AZIENDA_LIST是按账套、事业部及有效规则
  -- 计算出的实际来源公司范围，配置表COD_AZIENDA/D_BG则是目标维度，三者不是同一层含义。
  -- SESSION表字段和条件沿用参考TOV源码，不新增其他SESSION表或字段。
  -- ============================================================================
  V_ERROR_STAGE := '初始化SESSION公司范围';
  V_SESSION_ID := SYS_CONTEXT('USERENV', 'SESSIONID');

  DELETE FROM SESSION_AZIENDA_LIST
   WHERE SESSION_ID = V_SESSION_ID;

  DELETE FROM SESSION_V_REF_AZIENDA
   WHERE SESSION_ID = V_SESSION_ID;

  INSERT INTO SESSION_V_REF_AZIENDA(SESSION_ID, HIE, NODE, ELEM)
  SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_AZIENDA;

  -- SESSION_AZIENDA_LIST仅保留参考TOV规则计算出的实际来源公司。
  -- P_AZIENDA支持ALL、公司编码或公司节点逗号列表；P_BG支持ALL或事业部逗号列表。
  INSERT INTO SESSION_AZIENDA_LIST(SESSION_ID, ELEM)
  SELECT DISTINCT V_SESSION_ID
       , ELEM
    FROM SESSION_V_REF_AZIENDA
   WHERE HIE = '10'
     AND (
           INSTR(',' || V_AZIENDA || ',', ',' || ELEM || ',') > 0
        OR INSTR(',' || V_AZIENDA || ',', ',' || NODE || ',') > 0
        OR V_AZIENDA = 'ALL'
     )
     AND ELEM IN (
           SELECT A.COD_AZIENDA
             FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
            WHERE A.VALID_FR <= V_YEARMONTH
              AND NVL(A.VALID_TO, '999999') >= V_YEARMONTH
              AND (
                    V_BG = 'ALL'
                 OR INSTR(',' || V_BG || ',', ',' || A.COD_BG || ',') > 0
              )
              AND A.COD_BG NOT LIKE 'CXC%'
              AND A.COD_BG IN (
                    SELECT C.COD_BG
                      FROM TGK_FIMA_HISENSE.AW_RUL_COSMAP_000001 C
                     WHERE C.AR_TOV_FLAG = 'Y'
                       AND C.VALID_FR <= V_YEARMONTH
                       AND NVL(C.VALID_TO, '999999') >= V_YEARMONTH
              )
     )
     AND ELEM IN (
           SELECT COD_AZIENDA
             FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
            WHERE ARP_FLAG = 'Y'
              AND VALID_FR <= V_YEARMONTH
              AND NVL(VALID_TO, '999999') >= V_YEARMONTH
              AND COD_CONTO = 'ZAW_D2M_IN'
     )
     AND ELEM NOT IN (
           SELECT COD_AZIENDA
             FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
            WHERE ARP_FLAG = 'Y'
              AND COD_SCENARIO = V_SCENARIO
              AND COD_PERIODO = V_PERIODO
              AND COD_CONTO = 'ZAW_D2M_LOCK'
     );

  -- TOV过程以V_AZIENDA保存当前SESSION实际公司清单，日志统一写P_BG || '|' || V_AZIENDA。
  -- 本过程沿用该口径；SESSION表仅负责来源取数范围，不单独用于日志字段。
  SELECT LISTAGG(ELEM, ',') WITHIN GROUP (ORDER BY ELEM)
    INTO V_AZIENDA
    FROM (
      SELECT DISTINCT ELEM
        FROM SESSION_AZIENDA_LIST
       WHERE SESSION_ID = V_SESSION_ID
    );

  -- ============================================================================
  -- 第三阶段：记录过程开始日志。
  -- 日志直接写入ZTAB_CPM_LOG，不再通过WRITE_LOG子过程封装。
  -- ============================================================================
  INSERT INTO ZTAB_CPM_LOG(
      CPM, STEP, REMARK, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
  ) VALUES (
      'CPM_SP_S2S_TDAYS_M_PHASE2', 'BEGIN 开始执行',
      '配置表=AW_RUL_TOVCAL_000001;模块=' || TRIM(P_EXP) || ';期间=' || V_YEARMONTH,
      SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO,
      SUBSTR(P_BG || '|' || V_AZIENDA, 1, 4000)
  );

  -- ============================================================================
  -- 第四阶段：读取当前场景和期间有效的周转计算配置。
  -- 每条配置决定来源表、目标表、目标维度以及最多10组来源筛选条件。
  -- ============================================================================
  V_ERROR_STAGE := '读取有效配置';
  FOR R IN (
    SELECT ROWID AS RULE_ROWID
         , VALID_FR
         , VALID_TO
         , TARGET_TABLE
         , SOURCE_TABLE
         , D_GRAN_CAL
         , D_BG
         , COD_CONTO
         , COD_AZIENDA
         , COD_DEST2
         , D_ONOFFLINE
         , D_SALE_DEPT
         , D_CHANNEL
         , D_TOV_CHAN
         , D_CC_CUSTGRP
         , COD_DEST3
         , EXP_TYPE
         , IS_MTR_FLAG
         , COLUMN_NAME_1, COLUMN_FILTER_1, COLUMN_VALUE_1
         , COLUMN_NAME_2, COLUMN_FILTER_2, COLUMN_VALUE_2
         , COLUMN_NAME_3, COLUMN_FILTER_3, COLUMN_VALUE_3
         , COLUMN_NAME_4, COLUMN_FILTER_4, COLUMN_VALUE_4
         , COLUMN_NAME_5, COLUMN_FILTER_5, COLUMN_VALUE_5
         , COLUMN_NAME_6, COLUMN_FILTER_6, COLUMN_VALUE_6
         , COLUMN_NAME_7, COLUMN_FILTER_7, COLUMN_VALUE_7
         , COLUMN_NAME_8, COLUMN_FILTER_8, COLUMN_VALUE_8
         , COLUMN_NAME_9, COLUMN_FILTER_9, COLUMN_VALUE_9
         , COLUMN_NAME_10, COLUMN_FILTER_10, COLUMN_VALUE_10
      FROM AW_RUL_TOVCAL_000001
     WHERE TRIM(VALID_FR) <= V_YEARMONTH
       AND NVL(TRIM(VALID_TO), '999999') >= V_YEARMONTH
       AND TRIM(EXP_TYPE) = TRIM(P_EXP)
     ORDER BY ROWIDTOCHAR(ROWID)
  ) LOOP
    V_CONFIG_COUNT := V_CONFIG_COUNT + 1;
    V_ERROR_RULE := ROWIDTOCHAR(R.RULE_ROWID);
    V_TARGET_OBJECT := SAFE_OBJECT(R.TARGET_TABLE);
    V_SOURCE_OBJECT := SAFE_OBJECT(R.SOURCE_TABLE);
    V_ERROR_TARGET := V_TARGET_OBJECT;
    V_ERROR_SOURCE := V_SOURCE_OBJECT;

    IF R.VALID_FR IS NULL OR NOT REGEXP_LIKE(TRIM(R.VALID_FR), '^[0-9]{6}$')
       OR (R.VALID_TO IS NOT NULL AND NOT REGEXP_LIKE(TRIM(R.VALID_TO), '^[0-9]{6}$'))
       OR (R.VALID_TO IS NOT NULL AND TRIM(R.VALID_FR) > TRIM(R.VALID_TO)) THEN
      RAISE_APPLICATION_ERROR(-20015, '有效期配置非法，规则=' || V_ERROR_RULE);
    END IF;

    -- 运行参数范围与配置目标维度分开判断：
    -- 具体配置公司必须属于本次SESSION实际公司范围；当前资料未确认配置公司的通配字面量，
    -- 因此仅将空配置公司作为目标ZZZZ，来源仍只允许读取SESSION_AZIENDA_LIST中的公司。
    -- PL/SQL控制流不能直接使用SQL子查询；这里先按当前SESSION_ID计数，
    -- 保持配置R.COD_AZIENDA非空时仅命中SESSION_AZIENDA_LIST才处理，未命中则跳过。
    IF TRIM(R.COD_AZIENDA) IS NOT NULL THEN
      SELECT COUNT(*)
        INTO V_SESSION_AZIENDA_COUNT
        FROM SESSION_AZIENDA_LIST L
       WHERE L.SESSION_ID = V_SESSION_ID
         AND TRIM(L.ELEM) = TRIM(R.COD_AZIENDA);

      IF V_SESSION_AZIENDA_COUNT = 0 THEN
        CONTINUE;
      END IF;
    END IF;

    -- P_BG是运行事业部范围；配置D_BG是目标事业部。
    -- P_BG=ALL纳入所有有效配置目标事业部，空目标事业部输出ZZZZ；具体列表只匹配配置D_BG。
    IF TRIM(R.D_BG) IS NOT NULL AND NOT LIST_MATCH(V_BG, R.D_BG) THEN
      CONTINUE;
    END IF;

    -- 目标公司、目标事业部先在PL/SQL中标准化。
    -- 不能在静态INSERT的VALUES中直接调用过程内函数，否则低版本Oracle会报PLS-00231。
    V_TARGET_AZIENDA := TARGET_AZIENDA_VALUE(R.COD_AZIENDA);
    V_TARGET_BG := DIM_VALUE(R.D_BG);

    -- ============================================================================
    -- 第五阶段：按本次所有适用配置目标范围执行清理。
    -- 删除同时限定场景、期间、来源、当前目标表，以及同一配置行的目标公司和目标事业部，
    -- 避免P_AZIENDA/P_BG=ALL时因公司与事业部分开匹配而交叉扩大删除范围。
    -- 同一目标表在本次运行中只删除一次。
    -- ============================================================================
    V_TARGET_SCOPE := V_TARGET_OBJECT
      || '|'
      || V_TARGET_AZIENDA
      || '|'
      || V_TARGET_BG;

    -- 同一目标公司、目标事业部范围只在首次装载前删除一次。
    -- 删除条件直接使用当前已筛选的配置目标维度，避免多层EXISTS动态拼接产生括号错误。
    IF NOT V_TARGET_SEEN.EXISTS(V_TARGET_SCOPE) THEN
      -- 删除范围值均来自过程参数或当前有效配置，拼接前统一转义单引号。
      -- 此处不使用USING绑定列表，避免当前Oracle版本对该动态DELETE绑定语法的解析错误。
      V_DELETE_SQL := 'DELETE FROM ' || V_TARGET_OBJECT
        || ' D WHERE D.COD_SCENARIO = ''' || REPLACE(V_SCENARIO, '''', '''''') || ''''
        || ' AND D.COD_PERIODO = ''' || REPLACE(V_PERIODO, '''', '''''') || ''''
        || ' AND D.PROVENIENZA = ''CPM_SP_S2S_TDAYS_M_PHASE2'''
        || ' AND NVL(NULLIF(TRIM(D.COD_AZIENDA), ''''), ''ZZZZ'') = '''
        || REPLACE(V_TARGET_AZIENDA, '''', '''''') || ''''
        || ' AND NVL(NULLIF(TRIM(D.D_BG), ''''), ''ZZZZ'') = '''
        || REPLACE(V_TARGET_BG, '''', '''''') || '''';
      EXECUTE IMMEDIATE V_DELETE_SQL;
      V_TARGET_SEEN(V_TARGET_SCOPE) := TRUE;

      INSERT INTO ZTAB_CPM_LOG(
          CPM, STEP, REMARK, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
      ) VALUES (
          'CPM_SP_S2S_TDAYS_M_PHASE2', '目标表删除完成',
          'TARGET=' || V_TARGET_OBJECT
          || ';目标公司=' || V_TARGET_AZIENDA
          || ';目标事业部=' || V_TARGET_BG
          || ';来源=CPM_SP_S2S_TDAYS_M_PHASE2',
          SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO,
          SUBSTR(P_BG || '|' || V_AZIENDA, 1, 4000)
      );
    END IF;

    -- ============================================================================
    -- 第六阶段：拼接本条配置的动态取数和装载SQL。
    -- 先从来源表按10组筛选条件取数并聚合18个金额，再在外层计算6个周转天数。
    -- ============================================================================
    V_ERROR_STAGE := '动态汇总并装载';
    V_BIND_VALUE.DELETE;
    V_BIND_AUX.DELETE;
    V_BIND_EXTRA.DELETE;

    -- 直接动态写入目标表：参数和配置目标维度使用绑定变量，来源表、目标表及HIE表使用安全拼接。
    -- AGG先按来源类别、币种聚合18个金额；外层SELECT再计算6个周转天数。
    V_SQL := 'INSERT INTO ' || V_TARGET_OBJECT || '('
      || 'OID, COD_SCENARIO, COD_PERIODO, D_BG, COD_CONTO, COD_AZIENDA, D_GRAN_CAL, COD_CATEGORIA'
      || ', D_CHANNEL, D_ONOFFLINE, COD_DEST2, COD_DEST3, D_SALE_DEPT, D_TOV_CHAN, D_CC_CUSTGRP, COD_VALUTA'
      || ', PLN_BEG_OCP_AMT, PLN_LM_OCP_AMT, PLN_END_OCP_AMT, PLN_YTD_OCP_AMT, PLN_MTD_CSM_AMT, PLN_YTD_CSM_AMT'
      || ', ACT_BEG_OCP_AMT, ACT_LM_OCP_AMT, ACT_END_OCP_AMT, ACT_YTD_OCP_AMT, ACT_MTD_CSM_AMT, ACT_YTD_CSM_AMT'
      || ', LY_BEG_OCP_AMT, LY_LM_OCP_AMT, LY_END_OCP_AMT, LY_YTD_OCP_AMT, LY_MTD_CSM_AMT, LY_YTD_CSM_AMT'
      || ', PLN_MTD_TDAYS, PLN_YTD_TDAYS, ACT_MTD_TDAYS, ACT_YTD_TDAYS, LY_MTD_TDAYS, LY_YTD_TDAYS'
      || ', IS_MTR_FLAG, PROVENIENZA, DATEUPD, USERUPD)'
      || CHR(10) || 'WITH PARAMS AS ('
      || CHR(10) || '  SELECT :B_SCENARIO AS COD_SCENARIO'
      || ', :B_PERIODO AS COD_PERIODO'
      || ', :B_SESSION_ID AS SESSION_ID'
      || ', :B_CONFIG_AZIENDA AS TARGET_COD_AZIENDA'
      || ', :B_D_BG AS TARGET_D_BG'
      || ', :B_COD_CONTO AS TARGET_COD_CONTO'
      || ', :B_D_GRAN_CAL AS TARGET_D_GRAN_CAL'
      || ', :B_D_CHANNEL AS TARGET_D_CHANNEL'
      || ', :B_D_ONOFFLINE AS TARGET_D_ONOFFLINE'
      || ', :B_COD_DEST2 AS TARGET_COD_DEST2'
      || ', :B_COD_DEST3 AS TARGET_COD_DEST3'
      || ', :B_D_SALE_DEPT AS TARGET_D_SALE_DEPT'
      || ', :B_D_TOV_CHAN AS TARGET_D_TOV_CHAN'
      || ', :B_D_CC_CUSTGRP AS TARGET_D_CC_CUSTGRP'
      || ', :B_IS_MTR_FLAG AS IS_MTR_FLAG'
      || ', :B_USER AS USERUPD'
      || ' FROM DUAL)'
      || CHR(10) || ', AGG AS ('
      || CHR(10) || '  SELECT S.COD_CATEGORIA'
      || ', S.COD_VALUTA'
      || ', SUM(NVL(S.PLN_BEG_OCP_AMT, 0)) AS PLN_BEG_OCP_AMT'
      || ', SUM(NVL(S.PLN_LM_OCP_AMT, 0)) AS PLN_LM_OCP_AMT'
      || ', SUM(NVL(S.PLN_END_OCP_AMT, 0)) AS PLN_END_OCP_AMT'
      || ', SUM(NVL(S.PLN_YTD_OCP_AMT, 0)) AS PLN_YTD_OCP_AMT'
      || ', SUM(NVL(S.PLN_MTD_CSM_AMT, 0)) AS PLN_MTD_CSM_AMT'
      || ', SUM(NVL(S.PLN_YTD_CSM_AMT, 0)) AS PLN_YTD_CSM_AMT'
      || ', SUM(NVL(S.ACT_BEG_OCP_AMT, 0)) AS ACT_BEG_OCP_AMT'
      || ', SUM(NVL(S.ACT_LM_OCP_AMT, 0)) AS ACT_LM_OCP_AMT'
      || ', SUM(NVL(S.ACT_END_OCP_AMT, 0)) AS ACT_END_OCP_AMT'
      || ', SUM(NVL(S.ACT_YTD_OCP_AMT, 0)) AS ACT_YTD_OCP_AMT'
      || ', SUM(NVL(S.ACT_MTD_CSM_AMT, 0)) AS ACT_MTD_CSM_AMT'
      || ', SUM(NVL(S.ACT_YTD_CSM_AMT, 0)) AS ACT_YTD_CSM_AMT'
      || ', SUM(NVL(S.LY_BEG_OCP_AMT, 0)) AS LY_BEG_OCP_AMT'
      || ', SUM(NVL(S.LY_LM_OCP_AMT, 0)) AS LY_LM_OCP_AMT'
      || ', SUM(NVL(S.LY_END_OCP_AMT, 0)) AS LY_END_OCP_AMT'
      || ', SUM(NVL(S.LY_YTD_OCP_AMT, 0)) AS LY_YTD_OCP_AMT'
      || ', SUM(NVL(S.LY_MTD_CSM_AMT, 0)) AS LY_MTD_CSM_AMT'
      || ', SUM(NVL(S.LY_YTD_CSM_AMT, 0)) AS LY_YTD_CSM_AMT'
      || CHR(10) || '    FROM ' || V_SOURCE_OBJECT || ' S CROSS JOIN PARAMS P'
      || CHR(10) || '   WHERE S.COD_SCENARIO = P.COD_SCENARIO'
      || CHR(10) || '     AND S.COD_PERIODO = P.COD_PERIODO'
      || CHR(10) || '     AND S.COD_AZIENDA IN ('
      || CHR(10) || '           SELECT L.ELEM'
      || CHR(10) || '             FROM SESSION_AZIENDA_LIST L'
      || CHR(10) || '            WHERE L.SESSION_ID = P.SESSION_ID'
      || CHR(10) || '     )'
      || CHR(10) || '     AND (P.TARGET_COD_AZIENDA = ''ZZZZ'' OR TRIM(S.COD_AZIENDA) = TRIM(P.TARGET_COD_AZIENDA))';

    -- 同表读写边界：目标删除先于本目标首次写入；来源等于目标时排除本过程来源，
    -- 避免同一过程前一条配置刚写入的结果被后一条配置再次读取并重复累加。
    IF V_SOURCE_OBJECT = V_TARGET_OBJECT THEN
      V_SQL := V_SQL || CHR(10) || '     AND NVL(S.PROVENIENZA, ''ZZZZ'') <> ''' || 'CPM_SP_S2S_TDAYS_M_PHASE2' || '''';
    END IF;

    -- 第七阶段：逐组追加配置筛选条件。
    -- 每个非空配置组生成一个AND括号条件，10组之间整体为AND关系。
    -- HIE规则会根据字段名前缀动态定位V_REF_或V_REF_ED_引用表。
    APPEND_FILTER(R.COLUMN_NAME_1, R.COLUMN_FILTER_1, R.COLUMN_VALUE_1, 1);
    APPEND_FILTER(R.COLUMN_NAME_2, R.COLUMN_FILTER_2, R.COLUMN_VALUE_2, 2);
    APPEND_FILTER(R.COLUMN_NAME_3, R.COLUMN_FILTER_3, R.COLUMN_VALUE_3, 3);
    APPEND_FILTER(R.COLUMN_NAME_4, R.COLUMN_FILTER_4, R.COLUMN_VALUE_4, 4);
    APPEND_FILTER(R.COLUMN_NAME_5, R.COLUMN_FILTER_5, R.COLUMN_VALUE_5, 5);
    APPEND_FILTER(R.COLUMN_NAME_6, R.COLUMN_FILTER_6, R.COLUMN_VALUE_6, 6);
    APPEND_FILTER(R.COLUMN_NAME_7, R.COLUMN_FILTER_7, R.COLUMN_VALUE_7, 7);
    APPEND_FILTER(R.COLUMN_NAME_8, R.COLUMN_FILTER_8, R.COLUMN_VALUE_8, 8);
    APPEND_FILTER(R.COLUMN_NAME_9, R.COLUMN_FILTER_9, R.COLUMN_VALUE_9, 9);
    APPEND_FILTER(R.COLUMN_NAME_10, R.COLUMN_FILTER_10, R.COLUMN_VALUE_10, 10);

    -- 第八阶段：补充聚合分组和最终输出字段。
    -- 类别和币种直接取来源字段；配置目标维度使用DIM_VALUE处理空值。
    -- 周转天数必须使用聚合后的金额计算，分母为0时返回0。
    V_SQL := V_SQL
      || CHR(10) || '   GROUP BY S.COD_CATEGORIA, S.COD_VALUTA)'
      || CHR(10) || 'SELECT NEWID()'
      || ', P.COD_SCENARIO'
      || ', P.COD_PERIODO'
      || ', P.TARGET_D_BG'
      || ', P.TARGET_COD_CONTO'
      || ', P.TARGET_COD_AZIENDA'
      || ', P.TARGET_D_GRAN_CAL'
      || ', A.COD_CATEGORIA'
      || ', P.TARGET_D_CHANNEL'
      || ', P.TARGET_D_ONOFFLINE'
      || ', P.TARGET_COD_DEST2'
      || ', P.TARGET_COD_DEST3'
      || ', P.TARGET_D_SALE_DEPT'
      || ', P.TARGET_D_TOV_CHAN'
      || ', P.TARGET_D_CC_CUSTGRP'
      || ', A.COD_VALUTA'
      || ', A.PLN_BEG_OCP_AMT, A.PLN_LM_OCP_AMT, A.PLN_END_OCP_AMT, A.PLN_YTD_OCP_AMT, A.PLN_MTD_CSM_AMT, A.PLN_YTD_CSM_AMT'
      || ', A.ACT_BEG_OCP_AMT, A.ACT_LM_OCP_AMT, A.ACT_END_OCP_AMT, A.ACT_YTD_OCP_AMT, A.ACT_MTD_CSM_AMT, A.ACT_YTD_CSM_AMT'
      || ', A.LY_BEG_OCP_AMT, A.LY_LM_OCP_AMT, A.LY_END_OCP_AMT, A.LY_YTD_OCP_AMT, A.LY_MTD_CSM_AMT, A.LY_YTD_CSM_AMT'
      || ', CASE WHEN A.PLN_MTD_CSM_AMT = 0 THEN 0 ELSE ((A.PLN_LM_OCP_AMT + A.PLN_END_OCP_AMT) / 2 * 30) / A.PLN_MTD_CSM_AMT END'
      || ', CASE WHEN A.PLN_YTD_CSM_AMT = 0 THEN 0 ELSE ((A.PLN_BEG_OCP_AMT / 2 + A.PLN_YTD_OCP_AMT - A.PLN_END_OCP_AMT / 2) * 30) / A.PLN_YTD_CSM_AMT END'
      || ', CASE WHEN A.ACT_MTD_CSM_AMT = 0 THEN 0 ELSE ((A.ACT_LM_OCP_AMT + A.ACT_END_OCP_AMT) / 2 * 30) / A.ACT_MTD_CSM_AMT END'
      || ', CASE WHEN A.ACT_YTD_CSM_AMT = 0 THEN 0 ELSE ((A.ACT_BEG_OCP_AMT / 2 + A.ACT_YTD_OCP_AMT - A.ACT_END_OCP_AMT / 2) * 30) / A.ACT_YTD_CSM_AMT END'
      || ', CASE WHEN A.LY_MTD_CSM_AMT = 0 THEN 0 ELSE ((A.LY_LM_OCP_AMT + A.LY_END_OCP_AMT) / 2 * 30) / A.LY_MTD_CSM_AMT END'
      || ', CASE WHEN A.LY_YTD_CSM_AMT = 0 THEN 0 ELSE ((A.LY_BEG_OCP_AMT / 2 + A.LY_YTD_OCP_AMT - A.LY_END_OCP_AMT / 2) * 30) / A.LY_YTD_CSM_AMT END'
      || ', P.IS_MTR_FLAG'
      || ', ''' || 'CPM_SP_S2S_TDAYS_M_PHASE2' || ''''
      || ', SYSDATE'
      || ', P.USERUPD'
      || CHR(10) || '  FROM AGG A CROSS JOIN PARAMS P';

    -- 第九阶段：执行当前配置的动态INSERT。
    -- 使用绑定变量传入运行参数、目标维度和筛选值，避免把业务值直接拼接到SQL中。
    EXECUTE IMMEDIATE V_SQL USING
        V_SCENARIO
      , V_PERIODO
      , V_SESSION_ID
      , TARGET_AZIENDA_VALUE(R.COD_AZIENDA)
      , DIM_VALUE(R.D_BG)
      , DIM_VALUE(R.COD_CONTO)
      , DIM_VALUE(R.D_GRAN_CAL)
      , DIM_VALUE(R.D_CHANNEL)
      , DIM_VALUE(R.D_ONOFFLINE)
      , DIM_VALUE(R.COD_DEST2)
      , DIM_VALUE(R.COD_DEST3)
      , DIM_VALUE(R.D_SALE_DEPT)
      , DIM_VALUE(R.D_TOV_CHAN)
      , DIM_VALUE(R.D_CC_CUSTGRP)
      , R.IS_MTR_FLAG
      , SESSION_USER
      , V_BIND_VALUE(1), V_BIND_AUX(1), V_BIND_EXTRA(1)
      , V_BIND_VALUE(2), V_BIND_AUX(2), V_BIND_EXTRA(2)
      , V_BIND_VALUE(3), V_BIND_AUX(3), V_BIND_EXTRA(3)
      , V_BIND_VALUE(4), V_BIND_AUX(4), V_BIND_EXTRA(4)
      , V_BIND_VALUE(5), V_BIND_AUX(5), V_BIND_EXTRA(5)
      , V_BIND_VALUE(6), V_BIND_AUX(6), V_BIND_EXTRA(6)
      , V_BIND_VALUE(7), V_BIND_AUX(7), V_BIND_EXTRA(7)
      , V_BIND_VALUE(8), V_BIND_AUX(8), V_BIND_EXTRA(8)
      , V_BIND_VALUE(9), V_BIND_AUX(9), V_BIND_EXTRA(9)
      , V_BIND_VALUE(10), V_BIND_AUX(10), V_BIND_EXTRA(10);

    V_INSERT_COUNT := V_INSERT_COUNT + SQL%ROWCOUNT;
  END LOOP;

  -- ============================================================================
  -- 第十阶段：记录装载完成日志、清理SESSION范围并提交本次业务处理结果。
  -- ============================================================================
  INSERT INTO ZTAB_CPM_LOG(
      CPM, STEP, REMARK, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
  ) VALUES (
      'CPM_SP_S2S_TDAYS_M_PHASE2', '目标表装载完成',
      '配置数量=' || V_CONFIG_COUNT || ';插入数量=' || V_INSERT_COUNT,
      SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO,
      SUBSTR(P_BG || '|' || V_AZIENDA, 1, 4000)
  );

  -- 成功路径清理当前数据库SESSION的实际公司范围；字段和条件与参考TOV过程一致。
  DELETE FROM SESSION_AZIENDA_LIST
   WHERE SESSION_ID = V_SESSION_ID;

  DELETE FROM SESSION_V_REF_AZIENDA
   WHERE SESSION_ID = V_SESSION_ID;

  INSERT INTO ZTAB_CPM_LOG(
      CPM, STEP, REMARK, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
  ) VALUES (
      'CPM_SP_S2S_TDAYS_M_PHASE2', 'END 执行完成',
      '配置数量=' || V_CONFIG_COUNT || ';插入数量=' || V_INSERT_COUNT,
      SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO,
      SUBSTR(P_BG || '|' || V_AZIENDA, 1, 4000)
  );
  COMMIT;
  -- ============================================================================
  -- 异常处理：回滚本次业务装载，清理当前SESSION公司范围，记录错误后重新抛出异常。
  -- ============================================================================
EXCEPTION
  WHEN OTHERS THEN
    V_ERROR_COD := SQLCODE;
    V_ERROR_MSG := SUBSTR(SQLERRM, 1, 3500);
    ROLLBACK;

    -- 异常路径使用与成功路径完全相同的SESSION字段和SESSION_ID条件清理范围。
    DELETE FROM SESSION_AZIENDA_LIST
     WHERE SESSION_ID = V_SESSION_ID;

    DELETE FROM SESSION_V_REF_AZIENDA
     WHERE SESSION_ID = V_SESSION_ID;

    INSERT INTO ZTAB_CPM_LOG(
        CPM, STEP, REMARK, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA
    ) VALUES (
        'CPM_SP_S2S_TDAYS_M_PHASE2', 'ERROR 执行报错',
        SUBSTR(
            '阶段=' || V_ERROR_STAGE || ';规则=' || V_ERROR_RULE
            || ';SOURCE=' || V_ERROR_SOURCE || ';TARGET=' || V_ERROR_TARGET
            || ';错误=' || V_ERROR_COD || ':' || V_ERROR_MSG,
            1, 4000
        ),
        SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO,
        SUBSTR(P_BG || '|' || V_AZIENDA, 1, 4000)
    );
    COMMIT;
    RAISE;
END CPM_SP_S2S_TDAYS_M_PHASE2;
/
