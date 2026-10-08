WITH params AS (
    SELECT ${$Scenario.code} AS p_scenario,  /* 场景 (年份+场景码) */
           ${$Period.code}     AS p_periodo    /* 期间, 两位月份码 */
    FROM   dual
),
/* 公司限制清单: 从公司维度表取, IN 里填要查的公司编码; 查全部公司则去掉各取数段的 IN 限制 */
azi AS (
    SELECT a.cod_azienda
    FROM   tgk_gb_hisense.azienda a
    WHERE  a.cod_azienda IN (${$Entity.code})
),
/* 往来项目 ? 科目映射 (2.0 / 1.0 账龄表均为精确科目号) */
itm AS (
    SELECT '应收账款'     item_name,  1 seq, '1122000000' conto20, '1122000000' conto10 FROM dual UNION ALL
    SELECT '其他应收款'   item_name,  2 seq, '122101F'    conto20, '122101F'    conto10 FROM dual UNION ALL
    SELECT '预付账款'     item_name,  3 seq, '1123000000' conto20, '1123000000' conto10 FROM dual UNION ALL
    SELECT '应收款项融资' item_name,  4 seq, '1124001000' conto20, '1124001000' conto10 FROM dual UNION ALL
    SELECT '合同资产'     item_name,  5 seq, '1460000000' conto20, '1460000000' conto10 FROM dual UNION ALL
    SELECT '应付账款'     item_name,  6 seq, '2202000000' conto20, '2202000000' conto10 FROM dual UNION ALL
    SELECT '其他应付款'   item_name,  7 seq, '224199F'    conto20, '224199F'    conto10 FROM dual UNION ALL
    SELECT '预收账款'     item_name,  8 seq, '2203000000' conto20, '2203000000' conto10 FROM dual UNION ALL
    SELECT '合同负债'     item_name,  9 seq, '2204000000' conto20, '2204000000' conto10 FROM dual UNION ALL
    SELECT '长期应收款'   item_name, 10 seq, '1531000000' conto20, '1531000000' conto10 FROM dual
),
/* 2.0 账龄表: 公司 + 项目 + 客商 聚合 */
t20c AS (
    SELECT a.cod_azienda                     company_code,
           i.seq, i.item_name,
           /* 去前导零; LTRIM 对全零编码会返回空串(Oracle 空串=NULL), 统一置为 '(NO_CUST)' 以便配对 */
           NVL(LTRIM(a.cust_head_code, '0'), '(NO_CUST)') cust_code,
           MAX(a.cust_head_name)                  cust_name,
           COUNT(*)                          row_cnt,   /* 行数标记, 用于判断该侧是否有数据 */
           SUM(a.by_bcy_0_amt)               by_amt,   /* 年初 */
           SUM(a.lm_bcy_0_amt)               lm_amt,   /* 上月 */
           SUM(a.bcy_0_amt)                  cur_amt   /* 本月 */
    FROM   tgk_fima_dev.aw_mr9_arpm02_000001 a
    CROSS  JOIN params p
    JOIN   itm i ON a.cod_conto = i.conto20
    WHERE  a.cod_periodo   = p.p_periodo
      AND  a.cod_categoria = 'ZAMOUNT'
      AND  a.cod_scenario  = p.p_scenario
      AND  a.cod_azienda   IN (SELECT cod_azienda FROM azi)   /* 公司限制 */
    GROUP  BY a.cod_azienda, i.seq, i.item_name, NVL(LTRIM(a.cust_head_code, '0'), '(NO_CUST)')
),
/* 1.0 账龄表: 公司 + 项目 + 客商 聚合 (客商编码/名称按科目开头取不同字段) */
t10c AS (
    SELECT f.cod_azienda company_code,
           i.seq, i.item_name,
           NVL(LTRIM(CASE WHEN SUBSTR(f.cod_conto, 1, 1) = '1'
                          THEN f.testo_14          /* 1开头科目: 客商编码 */
                          ELSE f.testo_5           /* 2开头科目: 客商编码 */
                     END, '0'), '(NO_CUST)')                      cust_code,
           MAX(CASE WHEN SUBSTR(f.cod_conto, 1, 1) = '1'
                    THEN f.testo_15          /* 1开头科目: 客商名称 */
                    ELSE f.testo_6           /* 2开头科目: 客商名称 */
               END)                                             cust_name,
           MAX(f.importo_36) adj_flag,       /* 是否调整 (1.0 FORM_DATI.IMPORTO_36) */
           COUNT(*)          row_cnt,        /* 行数标记, 用于判断该侧是否有数据 */
           SUM(f.importo_1) by_amt,          /* 年初 */
           SUM(f.importo_2) lm_amt,          /* 上月 */
           SUM(f.importo_3) cur_amt          /* 本月 */
    FROM   tgk_gb_hisense.form_dati f
    CROSS  JOIN params p
    JOIN   itm i ON f.cod_conto = i.conto10
    WHERE  f.cod_prospetto IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
      AND  f.cod_categoria IN ('$AMOUNT', '1ADJ', '1REC')
      AND  f.cod_periodo   = p.p_periodo
      AND  f.cod_scenario  = p.p_scenario
      AND  f.cod_azienda   IN (SELECT cod_azienda FROM azi)   /* 公司限制 */
    GROUP  BY f.cod_azienda, i.seq, i.item_name,
              NVL(LTRIM(CASE WHEN SUBSTR(f.cod_conto, 1, 1) = '1'
                             THEN f.testo_14 ELSE f.testo_5 END, '0'), '(NO_CUST)')
)
SELECT NVL(t20c.company_code, t10c.company_code)                 AS company_code,
       NVL(t20c.item_name, t10c.item_name)                       AS item_name,
       NVL(t20c.cust_code, t10c.cust_code)                       AS cust_code,
       NVL(t20c.cust_name, t10c.cust_name)                       AS cust_name,
       /* ===== 2.0账龄 (年初 / 上月 / 本月) ===== */
       NVL(t20c.by_amt, 0)                                       AS by_amt_20,
       NVL(t20c.lm_amt, 0)                                       AS lm_amt_20,
       NVL(t20c.cur_amt, 0)                                      AS cur_amt_20,
       /* ===== 1.0账龄 (年初 / 上月 / 本月) ===== */
       NVL(t10c.by_amt, 0)                                       AS by_amt_10,
       NVL(t10c.lm_amt, 0)                                       AS lm_amt_10,
       NVL(t10c.cur_amt, 0)                                      AS cur_amt_10,
       /* ===== 差异 (2.0 - 1.0) ===== */
       NVL(t20c.by_amt, 0)  - NVL(t10c.by_amt, 0)                AS by_amt_diff,
       NVL(t20c.lm_amt, 0)  - NVL(t10c.lm_amt, 0)                AS lm_amt_diff,
       NVL(t20c.cur_amt, 0) - NVL(t10c.cur_amt, 0)               AS cur_amt_diff,
       /* ===== 来源标记(用行数标记判断, 避免客商编码为空导致的误判) ===== */
       CASE WHEN NVL(t20c.row_cnt, 0) = 0 THEN '仅1.0有'
            WHEN NVL(t10c.row_cnt, 0) = 0 THEN '仅2.0有'
            ELSE '两边都有' END                                  AS match_flag,
       /* ===== 是否调整 (取自 1.0 FORM_DATI.IMPORTO_36) ===== */
       NVL(t10c.adj_flag, 0)                                     AS adj_flag
FROM   t20c
FULL   OUTER JOIN t10c
       ON  t20c.company_code = t10c.company_code
       AND t20c.seq          = t10c.seq
       AND t20c.cust_code    = t10c.cust_code
WHERE  NVL(t20c.by_amt, 0)  - NVL(t10c.by_amt, 0)  NOT BETWEEN -0.01 AND 0.01
   OR  NVL(t20c.lm_amt, 0)  - NVL(t10c.lm_amt, 0)  NOT BETWEEN -0.01 AND 0.01
   OR  NVL(t20c.cur_amt, 0) - NVL(t10c.cur_amt, 0) NOT BETWEEN -0.01 AND 0.01
ORDER  BY NVL(t20c.company_code, t10c.company_code), NVL(t20c.seq, t10c.seq), NVL(t20c.cust_code, t10c.cust_code)