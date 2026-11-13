CREATE OR REPLACE FUNCTION F_TGK_GET_DIMNAME(
    P_DIM_NAME  IN VARCHAR2
  , P_COD       IN VARCHAR2
) RETURN VARCHAR2
/* RESULT_CACHE：相同(维度, 编码)只查一次，后续从内存直接返回；
   适用于 GROUP BY 场景——百万行数据里维度编码通常只有几百个不同值。 */
RESULT_CACHE RELIES_ON (
    SCENARIO, AZIENDA, CONTO, DEST1, DEST2, DEST3, DEST4, DEST5, CATEGORIA, VALUTA
)
AS
  /*******************************************************************************
   *                              函数说明
   *-----------------------------------------------------------------------------
   * 最后更新时间：20261112 18:15
   * 本次修改：ALTER BY 20261112 18:15 SHIQINGFENG.EX 自定义维度改为按 ED_<维度名> 动态取表，新增维度不再改函数。
   * 上次修改：ALTER BY 20261112 18:00 SHIQINGFENG.EX 新增维度描述函数归档文件，源码从 TGK_FIMA_HISENSE 导出。
   *
   * 函数名称  ：F_TGK_GET_DIMNAME
   * 功能描述  ：按维度名 + 维度编码返回维度描述，库内为加密串，展示侧由报表标准功能统一解码。
   * 源表      ：标准维度 SCENARIO、AZIENDA、CONTO、DEST1~DEST5、CATEGORIA、VALUTA；
   *             自定义维度动态读取 TGK_FIMA_HISENSE.ED_<维度名>。
   * 返回说明  ：编码不存在、维度名不支持、入参为空、内部任何异常，一律返回 NULL，不抛错。
   *
   * 修改历史：
   *   ALTER BY 20261112 18:15 SHIQINGFENG.EX 自定义维度改为按 ED_<维度名> 动态取表，新增维度不再改函数。
   *   ALTER BY 20261112 18:00 SHIQINGFENG.EX 新增维度描述函数归档文件，源码从 TGK_FIMA_HISENSE 导出。
   *******************************************************************************/
  /* 取数规则
     1. 标准维度（10 个）：表名和描述字段都不规则，写死。
        SCENARIO→DESC_SCENARIO、VALUTA→DESC_VALUTA、AZIENDA→DESC_AZIENDA0、CONTO→DESC_CONTO0、
        DEST1~DEST5→DESC_DEST10~DESC_DEST50、CATEGORIA→DESC_CATEGORIA0。
     2. 自定义维度：后台表统一为 ED_<维度名>、列统一为 COD + DESC0，动态拼表名取数；
        后台建好新维度表，入参写维度名即可，函数不用改。D_GRP 是历史例外，走 ED_GRP。
     3. 入参不是 D_ 开头、或表不存在（ORA-00942 被兜底吞掉），一律返回 NULL，
        名称列为空即是这两种情况，不报错。
     4. 库为 19c，RESULT_CACHE 自动跟踪依赖（含动态 SQL 引用的表），维度表重载后缓存自动失效；
        RELIES_ON 自 12c 起已废弃，这里只保留 10 张标准维度表作为来源说明。
     5. 新建维度表后若名称仍为空，多是被兜底缓存的 NULL —— 执行 DBMS_RESULT_CACHE.FLUSH 或重编函数即可。 */
  V_DIM    VARCHAR2(100);
  V_TABLE  VARCHAR2(128);
  V_DESC0  VARCHAR2(4000);
BEGIN
  IF P_DIM_NAME IS NULL OR P_COD IS NULL THEN
    RETURN NULL;
  END IF;

  V_DIM := UPPER(TRIM(P_DIM_NAME));

  /* 标准维度 */
  IF V_DIM = 'SCENARIO' THEN
    SELECT DESC_SCENARIO INTO V_DESC0 FROM SCENARIO WHERE COD_SCENARIO = P_COD AND ROWNUM = 1;
  ELSIF V_DIM = 'VALUTA' THEN
    SELECT DESC_VALUTA INTO V_DESC0 FROM VALUTA WHERE COD_VALUTA = P_COD AND ROWNUM = 1;
  ELSIF V_DIM = 'AZIENDA' THEN
    SELECT DESC_AZIENDA0 INTO V_DESC0 FROM AZIENDA WHERE COD_AZIENDA = P_COD AND ROWNUM = 1;
  ELSIF V_DIM = 'CONTO' THEN
    SELECT DESC_CONTO0 INTO V_DESC0 FROM CONTO WHERE COD_CONTO = P_COD AND ROWNUM = 1;
  ELSIF V_DIM = 'DEST1' THEN
    SELECT DESC_DEST10 INTO V_DESC0 FROM DEST1 WHERE COD_DEST1 = P_COD AND ROWNUM = 1;
  ELSIF V_DIM = 'DEST2' THEN
    SELECT DESC_DEST20 INTO V_DESC0 FROM DEST2 WHERE COD_DEST2 = P_COD AND ROWNUM = 1;
  ELSIF V_DIM = 'DEST3' THEN
    SELECT DESC_DEST30 INTO V_DESC0 FROM DEST3 WHERE COD_DEST3 = P_COD AND ROWNUM = 1;
  ELSIF V_DIM = 'DEST4' THEN
    SELECT DESC_DEST40 INTO V_DESC0 FROM DEST4 WHERE COD_DEST4 = P_COD AND ROWNUM = 1;
  ELSIF V_DIM = 'DEST5' THEN
    SELECT DESC_DEST50 INTO V_DESC0 FROM DEST5 WHERE COD_DEST5 = P_COD AND ROWNUM = 1;
  ELSIF V_DIM = 'CATEGORIA' THEN
    SELECT DESC_CATEGORIA0 INTO V_DESC0 FROM CATEGORIA WHERE COD_CATEGORIA = P_COD AND ROWNUM = 1;
  ELSE
    /* 自定义维度：表名按 ED_<维度名> 动态拼；先校验入参形态，非 D_ 开头直接兜底，
       避免把任意字符串拼进 SQL。 */
    IF NOT REGEXP_LIKE(V_DIM, '^D_[A-Z0-9_]+$') THEN
      RETURN NULL;
    END IF;
    V_TABLE := CASE WHEN V_DIM = 'D_GRP' THEN 'ED_GRP' ELSE 'ED_' || V_DIM END;
    EXECUTE IMMEDIATE 'SELECT DESC0 FROM TGK_FIMA_HISENSE.' || V_TABLE || ' WHERE COD = :1 AND ROWNUM = 1'
      INTO V_DESC0 USING P_COD;
  END IF;

  RETURN V_DESC0;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
  WHEN OTHERS THEN
    RETURN NULL;
END;
/
