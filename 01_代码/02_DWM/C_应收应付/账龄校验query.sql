WITH
/* 往来项目、2.0/1.0账龄表科目映射，以及单体法人科目节点映射。 */
itm AS (
    SELECT '应收账款'     item_name,  1 seq, '1122000000' conto20, '1122000000' conto10, '1122'       node_code FROM dual UNION ALL
    SELECT '其他应收款'   item_name,  2 seq, '122101F'    conto20, '122101F'    conto10, '1221'       node_code FROM dual UNION ALL
    SELECT '预付账款'     item_name,  3 seq, '1123000000' conto20, '1123000000' conto10, '1123'       node_code FROM dual UNION ALL
    SELECT '应收款项融资' item_name,  4 seq, '1124001000' conto20, '1124001000' conto10, '112400'     node_code FROM dual UNION ALL
    SELECT '合同资产'     item_name,  5 seq, '1460000000' conto20, '1460000000' conto10, '146200A01'  node_code FROM dual UNION ALL
    SELECT '合同资产'     item_name,  5 seq, '1460000000' conto20, '1460000000' conto10, '1910000A30' node_code FROM dual UNION ALL
    SELECT '应付账款'     item_name,  6 seq, '2202000000' conto20, '2202000000' conto10, '220200'     node_code FROM dual UNION ALL
    SELECT '其他应付款'   item_name,  7 seq, '224199F'    conto20, '224199F'    conto10, '224100'     node_code FROM dual UNION ALL
    SELECT '预收账款'     item_name,  8 seq, '2203000000' conto20, '2203000000' conto10, '220300'     node_code FROM dual UNION ALL
    SELECT '合同负债'     item_name,  9 seq, '2204000000' conto20, '2204000000' conto10, '220400'     node_code FROM dual UNION ALL
    SELECT '长期应收款'   item_name, 10 seq, '1531000000' conto20, '1531000000' conto10, '153110'     node_code FROM dual
),
/* 合同资产存在两个单体法人节点；2.0和1.0账龄汇总时按项目科目去重。 */
itm_dedup AS (
    SELECT seq
         , item_name
         , conto20
         , conto10
    FROM   itm
    GROUP  BY seq
            , item_name
            , conto20
            , conto10
),
/* 原合计口径：2.0账龄表按公司和往来项目汇总，保留原有全部集团所属范围数据。 */
t20_total AS (
    SELECT a.cod_azienda company_code
         , i.seq
         , i.item_name
         , SUM(a.by_bcy_0_amt) by_amt
         , SUM(a.lm_bcy_0_amt) lm_amt
         , SUM(a.bcy_0_amt)    cur_amt
    FROM   aw_mr9_arpm02_000001 a
    JOIN   itm_dedup i
      ON   a.cod_conto = i.conto20
    WHERE  a.cod_periodo   = ${$Period.code}
      AND  a.cod_categoria = 'ZAMOUNT'
      AND  a.cod_scenario  = ${$Scenario.code}
      /* 公司限制已下沉至本数据包内部。 */
      AND  a.cod_azienda   IN (${$Entity.code})
    GROUP  BY a.cod_azienda
            , i.seq
            , i.item_name
),
/* 原合计口径：1.0账龄表按公司和往来项目汇总，保留原有三类账龄类别。 */
t10_total AS (
    SELECT f.cod_azienda company_code
         , i.seq
         , i.item_name
         , SUM(f.importo_1) by_amt
         , SUM(f.importo_2) lm_amt
         , SUM(f.importo_3) cur_amt
    FROM   TGK_GB_HISENSEform_dati f
    JOIN   itm_dedup i
      ON   f.cod_conto = i.conto10
    WHERE  f.cod_prospetto IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
      AND  f.cod_categoria IN ('$AMOUNT', '1ADJ', '1REC')
      AND  f.cod_periodo   = ${$Period.code}
      AND  f.cod_scenario  = ${$Scenario.code}
      /* 公司限制已下沉至本数据包内部。 */
      AND  f.cod_azienda   IN (${$Entity.code})
    GROUP  BY f.cod_azienda
            , i.seq
            , i.item_name
),
/* 原合计口径：HIE='01'下节点与科目的全量映射。 */
node_elem AS (
    SELECT rc.node
         , rc.elem
    FROM   tgk_gb_hisense.v_ref_conto rc
    WHERE  rc.hie = '01'
),
/* 原合计口径：单体法人按年初、上月和本月快照汇总。 */
tsd AS (
    SELECT s.cod_azienda company_code
         , i.seq
         , i.item_name
         , SUM(CASE
                   WHEN s.cod_scenario = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                    AND s.cod_periodo = '12'
                   THEN s.importo
               END) by_amt
         , SUM(CASE
                   WHEN s.cod_scenario = CASE
                                             WHEN ${$Period.code} = '01'
                                             THEN TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                                             ELSE ${$Scenario.code}
                                         END
                    AND s.cod_periodo = CASE
                                             WHEN ${$Period.code} = '01' THEN '12'
                                             ELSE LPAD(TO_NUMBER(${$Period.code}) - 1, 2, '0')
                                         END
                   THEN s.importo
               END) lm_amt
         , SUM(CASE
                   WHEN s.cod_scenario = ${$Scenario.code}
                    AND s.cod_periodo = ${$Period.code}
                   THEN s.importo
               END) cur_amt
    FROM   TGK_GB_HISENSEdati_saldi_lordi s
    JOIN   node_elem ne
      ON   ne.elem = s.cod_conto
    JOIN   itm i
      ON   i.node_code = ne.node
    WHERE  ((s.cod_scenario = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
             AND s.cod_periodo = '12')
            OR (s.cod_scenario = CASE
                                      WHEN ${$Period.code} = '01'
                                      THEN TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                                      ELSE ${$Scenario.code}
                                  END
                AND s.cod_periodo = CASE
                                        WHEN ${$Period.code} = '01' THEN '12'
                                        ELSE LPAD(TO_NUMBER(${$Period.code}) - 1, 2, '0')
                                    END)
            OR (s.cod_scenario = ${$Scenario.code}
                AND s.cod_periodo = ${$Period.code}))
      AND  s.cod_categoria IN ('$AMOUNT', '1ADJ', '1SPA', '1REC', '2ADJ_CF', '2ADJ_OB')
      /* 公司限制已下沉至本数据包内部。 */
      AND  s.cod_azienda   IN (${$Entity.code})
    GROUP  BY s.cod_azienda
            , i.seq
            , i.item_name
),
/* 原合计口径的公司驱动集合，保留单体法人来源公司。 */
company_dim_total AS (
    SELECT company_code FROM t20_total
    UNION
    SELECT company_code FROM t10_total
    UNION
    SELECT company_code FROM tsd
),
/* ALTER BY SHIQINGFENG.EX 20261023 18:30 在原合计后新增集团所属范围三段校验；新增段Lordi固定为0且不参与校验。 */
/* 新增三段校验配置：控制2.0集团所属范围、1.0类别和展示顺序。 */
scope_config AS (
    SELECT 1 scope_seq, '所属子公司' group_scope, 'SUB-子公司' t20_grp_scope, '$AMOUNT' t10_category FROM dual UNION ALL
    SELECT 2 scope_seq, '集团内'     group_scope, 'GIN-集团内' t20_grp_scope, '1ADJ'    t10_category FROM dual UNION ALL
    SELECT 3 scope_seq, '集团外'     group_scope, 'GEX-集团外' t20_grp_scope, '1REC'    t10_category FROM dual
),
/* 新增范围口径：2.0账龄按公司、往来项目和集团所属范围汇总。 */
t20_scope AS (
    SELECT a.cod_azienda company_code
         , i.seq
         , i.item_name
         , sc.scope_seq
         , sc.group_scope
         , SUM(a.by_bcy_0_amt) by_amt
         , SUM(a.lm_bcy_0_amt) lm_amt
         , SUM(a.bcy_0_amt)    cur_amt
    FROM   aw_mr9_arpm02_000001 a
    JOIN   itm_dedup i
      ON   a.cod_conto = i.conto20
    JOIN   scope_config sc
      ON   a.grp_scope = sc.t20_grp_scope
    WHERE  a.cod_periodo   = ${$Period.code}
      AND  a.cod_categoria = 'ZAMOUNT'
      AND  a.cod_scenario  = ${$Scenario.code}
      /* 公司限制已下沉至本数据包内部。 */
      AND  a.cod_azienda   IN (${$Entity.code})
    GROUP  BY a.cod_azienda
            , i.seq
            , i.item_name
            , sc.scope_seq
            , sc.group_scope
),
/* 新增范围口径：1.0账龄按三段配置限定类别后汇总。 */
t10_scope AS (
    SELECT f.cod_azienda company_code
         , i.seq
         , i.item_name
         , sc.scope_seq
         , sc.group_scope
         , SUM(f.importo_1) by_amt
         , SUM(f.importo_2) lm_amt
         , SUM(f.importo_3) cur_amt
    FROM   TGK_GB_HISENSEform_dati f
    JOIN   itm_dedup i
      ON   f.cod_conto = i.conto10
    JOIN   scope_config sc
      ON   f.cod_categoria = sc.t10_category
    WHERE  f.cod_prospetto IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
      AND  f.cod_periodo   = ${$Period.code}
      AND  f.cod_scenario  = ${$Scenario.code}
      /* 公司限制已下沉至本数据包内部。 */
      AND  f.cod_azienda   IN (${$Entity.code})
    GROUP  BY f.cod_azienda
            , i.seq
            , i.item_name
            , sc.scope_seq
            , sc.group_scope
),
/* 新增范围口径的公司驱动集合，仅由2.0和1.0账龄表构成。 */
company_dim_scope AS (
    SELECT company_code FROM t20_scope
    UNION
    SELECT company_code FROM t10_scope
),
/* 原合计结果：金额和单体法人校验逻辑保持原样，仅补充“总计”范围标识。 */
total_result AS (
    SELECT c.company_code
         , i.item_name
         , '总计' group_scope
         , NVL(t20.by_amt, 0) by_amt_20
         , NVL(t20.lm_amt, 0) lm_amt_20
         , NVL(t20.cur_amt, 0) cur_amt_20
         , NVL(t10.by_amt, 0) by_amt_10
         , NVL(t10.lm_amt, 0) lm_amt_10
         , NVL(t10.cur_amt, 0) cur_amt_10
         , NVL(tsd.by_amt, 0) by_amt_lordi
         , NVL(tsd.lm_amt, 0) lm_amt_lordi
         , NVL(tsd.cur_amt, 0) cur_amt_lordi
         , NVL(t20.by_amt, 0) - NVL(t10.by_amt, 0) by_amt_diff
         , NVL(t20.lm_amt, 0) - NVL(t10.lm_amt, 0) lm_amt_diff
         , NVL(t20.cur_amt, 0) - NVL(t10.cur_amt, 0) cur_amt_diff
         , i.seq item_seq
         , 0 scope_seq
    FROM   company_dim_total c
    CROSS  JOIN itm_dedup i
    LEFT   JOIN t20_total t20
      ON   t20.company_code = c.company_code
     AND   t20.seq          = i.seq
    LEFT   JOIN t10_total t10
      ON   t10.company_code = c.company_code
     AND   t10.seq          = i.seq
    LEFT   JOIN tsd
      ON   tsd.company_code = c.company_code
     AND   tsd.seq          = i.seq
),
/* 新增范围结果：不读取单体法人表，Lordi金额固定为0，只校验2.0与1.0账龄。 */
scope_result AS (
    SELECT c.company_code
         , i.item_name
         , sc.group_scope
         , NVL(t20.by_amt, 0) by_amt_20
         , NVL(t20.lm_amt, 0) lm_amt_20
         , NVL(t20.cur_amt, 0) cur_amt_20
         , NVL(t10.by_amt, 0) by_amt_10
         , NVL(t10.lm_amt, 0) lm_amt_10
         , NVL(t10.cur_amt, 0) cur_amt_10
         , 0 by_amt_lordi
         , 0 lm_amt_lordi
         , 0 cur_amt_lordi
         , NVL(t20.by_amt, 0) - NVL(t10.by_amt, 0) by_amt_diff
         , NVL(t20.lm_amt, 0) - NVL(t10.lm_amt, 0) lm_amt_diff
         , NVL(t20.cur_amt, 0) - NVL(t10.cur_amt, 0) cur_amt_diff
         , i.seq item_seq
         , sc.scope_seq
    FROM   company_dim_scope c
    CROSS  JOIN itm_dedup i
    CROSS  JOIN scope_config sc
    LEFT   JOIN t20_scope t20
      ON   t20.company_code = c.company_code
     AND   t20.seq          = i.seq
     AND   t20.scope_seq    = sc.scope_seq
    LEFT   JOIN t10_scope t10
      ON   t10.company_code = c.company_code
     AND   t10.seq          = i.seq
     AND   t10.scope_seq    = sc.scope_seq
),
/* 合计结果与新增三段范围结果并集展示。 */
all_result AS (
    SELECT company_code
         , item_name
         , group_scope
         , by_amt_20
         , lm_amt_20
         , cur_amt_20
         , by_amt_10
         , lm_amt_10
         , cur_amt_10
         , by_amt_lordi
         , lm_amt_lordi
         , cur_amt_lordi
         , by_amt_diff
         , lm_amt_diff
         , cur_amt_diff
         , item_seq
         , scope_seq
    FROM   total_result
    UNION ALL
    SELECT company_code
         , item_name
         , group_scope
         , by_amt_20
         , lm_amt_20
         , cur_amt_20
         , by_amt_10
         , lm_amt_10
         , cur_amt_10
         , by_amt_lordi
         , lm_amt_lordi
         , cur_amt_lordi
         , by_amt_diff
         , lm_amt_diff
         , cur_amt_diff
         , item_seq
         , scope_seq
    FROM   scope_result
)
SELECT company_code
     , item_name
     , group_scope
     , by_amt_20
     , lm_amt_20
     , cur_amt_20
     , by_amt_10
     , lm_amt_10
     , cur_amt_10
     , by_amt_lordi
     , lm_amt_lordi
     , cur_amt_lordi
     , by_amt_diff
     , lm_amt_diff
     , cur_amt_diff
FROM   all_result
/* 按公司、往来项目、总计及用户指定的三段集团所属范围顺序展示。 */
ORDER  BY company_code
        , item_seq
        , scope_seq
