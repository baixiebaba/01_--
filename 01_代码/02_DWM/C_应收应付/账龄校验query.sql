WITH
/* 往来项目 ? 科目映射 (2.0/1.0 账龄表: 精确科目号; 单体法人: V_REF_CONTO 节点编码) */
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
itm_dedup AS (   /* 合同资产占两行(两个节点), 科目映射去重后每个项目一行 */
    SELECT seq, item_name, conto20, conto10
    FROM   itm
    GROUP  BY seq, item_name, conto20, conto10
),
/* 2.0 账龄表: 按公司和往来项目汇总 */
t20 AS (
    SELECT a.cod_azienda company_code, i.seq, i.item_name,
           SUM(a.by_bcy_0_amt) by_amt,    /* 年初 */
           SUM(a.lm_bcy_0_amt) lm_amt,    /* 上月 */
           SUM(a.bcy_0_amt)    cur_amt    /* 本月 */
    FROM   aw_mr9_arpm02_000001 a
    JOIN   itm_dedup i ON a.cod_conto = i.conto20
    WHERE  a.cod_periodo   = ${$Period.code}
      AND  a.cod_categoria = 'ZAMOUNT'
      AND  a.cod_scenario  = ${$Scenario.code}
      AND  a.cod_azienda   IN (${$Entity.code})              /* 公司限制已下沉至本数据包内部 */
    GROUP  BY a.cod_azienda, i.seq, i.item_name
),
/* 1.0 账龄表: 按公司和往来项目汇总 (客商不参与汇总, 仅科目维度) */
t10 AS (
    SELECT f.cod_azienda company_code, i.seq, i.item_name,
           SUM(f.importo_1) by_amt,       /* 年初 */
           SUM(f.importo_2) lm_amt,       /* 上月 */
           SUM(f.importo_3) cur_amt       /* 本月 */
    FROM   TGK_GB_HISENSEform_dati f
    JOIN   itm_dedup i ON f.cod_conto = i.conto10
    WHERE  f.cod_prospetto IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
      AND  f.cod_categoria IN ('$AMOUNT', '1ADJ', '1REC')
      AND  f.cod_periodo   = ${$Period.code}
      AND  f.cod_scenario  = ${$Scenario.code}
      AND  f.cod_azienda   IN (${$Entity.code})              /* 公司限制已下沉至本数据包内部 */
    GROUP  BY f.cod_azienda, i.seq, i.item_name
),
/* 科目层级视图: HIE='01' 下 NODE ? ELEM 全量映射 */
node_elem AS (
    SELECT rc.node, rc.elem
    FROM   tgk_gb_hisense.v_ref_conto rc
    WHERE  rc.hie = '01'
),
/* 1.0 单体法人: 三个月份快照各取 IMPORTO, 科目经 V_REF_CONTO 按 NODE 展开后限制 */
tsd AS (
    SELECT s.cod_azienda company_code, i.seq, i.item_name,
           /* 年初: 上一年场景 + 12月 */
           SUM(CASE WHEN s.cod_scenario = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                          AND s.cod_periodo = '12' THEN s.importo END) by_amt,
           /* 上月: 上月场景 + 上月期间 */
           SUM(CASE WHEN s.cod_scenario = CASE WHEN ${$Period.code} = '01'
                                                   THEN TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                                                   ELSE ${$Scenario.code} END
                          AND s.cod_periodo = CASE WHEN ${$Period.code} = '01'
                                                   THEN '12'
                                                   ELSE LPAD(TO_NUMBER(${$Period.code}) - 1, 2, '0') END THEN s.importo END) lm_amt,
           /* 本月 */
           SUM(CASE WHEN s.cod_scenario = ${$Scenario.code}
                          AND s.cod_periodo = ${$Period.code} THEN s.importo END) cur_amt
    FROM   TGK_GB_HISENSEdati_saldi_lordi s
    JOIN   node_elem ne ON ne.elem      = s.cod_conto
    JOIN   itm      i  ON i.node_code = ne.node
    WHERE  (   (s.cod_scenario = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                AND s.cod_periodo = '12')                                      /* 年初(去年12月) */
            OR (s.cod_scenario = CASE WHEN ${$Period.code} = '01'
                                      THEN TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code}, 1, 4)) - 1) || SUBSTR(${$Scenario.code}, 5)
                                      ELSE ${$Scenario.code} END
                AND s.cod_periodo = CASE WHEN ${$Period.code} = '01'
                                         THEN '12'
                                         ELSE LPAD(TO_NUMBER(${$Period.code}) - 1, 2, '0') END) /* 上月 */
            OR (s.cod_scenario = ${$Scenario.code}
                AND s.cod_periodo = ${$Period.code}))                         /* 本月 */
      AND  s.cod_categoria IN ('$AMOUNT', '1ADJ', '1SPA', '1REC', '2ADJ_CF', '2ADJ_OB')
      AND  s.cod_azienda   IN (${$Entity.code})              /* 公司限制已下沉至本数据包内部 */
    GROUP  BY s.cod_azienda, i.seq, i.item_name
),
/* 公司驱动集合: 汇总各来源中参数范围内实际出现的公司 */
company_dim AS (
    SELECT company_code FROM t20
    UNION
    SELECT company_code FROM t10
    UNION
    SELECT company_code FROM tsd
)
SELECT c.company_code                                                        AS company_code,
       i.item_name                                                            AS item_name,
       /* ===== 2.0账龄 (年初 / 上月 / 本月) ===== */
       NVL(t20.by_amt, 0)                                                     AS by_amt_20,
       NVL(t20.lm_amt, 0)                                                     AS lm_amt_20,
       NVL(t20.cur_amt, 0)                                                    AS cur_amt_20,
       /* ===== 1.0账龄 (年初 / 上月 / 本月) ===== */
       NVL(t10.by_amt, 0)                                                     AS by_amt_10,
       NVL(t10.lm_amt, 0)                                                     AS lm_amt_10,
       NVL(t10.cur_amt, 0)                                                    AS cur_amt_10,
       /* ===== 1.0单体法人 (年初 / 上月 / 本月) ===== */
       NVL(tsd.by_amt, 0)                                                     AS by_amt_lordi,
       NVL(tsd.lm_amt, 0)                                                     AS lm_amt_lordi,
       NVL(tsd.cur_amt, 0)                                                    AS cur_amt_lordi,
       /* ===== 差异 (2.0 - 1.0) ===== */
       NVL(t20.by_amt, 0)  - NVL(t10.by_amt, 0)                               AS by_amt_diff,
       NVL(t20.lm_amt, 0)  - NVL(t10.lm_amt, 0)                               AS lm_amt_diff,
       NVL(t20.cur_amt, 0) - NVL(t10.cur_amt, 0)                              AS cur_amt_diff
FROM   company_dim c
CROSS  JOIN itm_dedup i                                   /* 每个公司均输出完整往来项目清单 */
LEFT   JOIN t20  ON t20.company_code = c.company_code AND t20.seq  = i.seq
LEFT   JOIN t10  ON t10.company_code = c.company_code AND t10.seq  = i.seq
LEFT   JOIN tsd  ON tsd.company_code = c.company_code AND tsd.seq  = i.seq
ORDER  BY c.company_code, i.seq