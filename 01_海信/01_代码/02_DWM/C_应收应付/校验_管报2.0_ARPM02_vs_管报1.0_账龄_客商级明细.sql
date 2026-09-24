/* ============================================================================
 * 账龄表校验 —— ②客商级明细 (2.0 vs 1.0, 不含单体法人)
 *   数据源A(2.0账龄表) : TGK_FIMA_DEV.AW_MR9_ARPM02_000001   (管报系统2.0)
 *   数据源B(1.0账龄表) : TGK_GB_HISENSE.FORM_DATI            (管报系统1.0)
 *
 *   配套文件: 校验_管报2.0_ARPM02_vs_管报1.0_账龄.sql (①科目级, 含单体法人)
 *
 *   粒度: 公司 + 往来项目 + 客商
 *   新增列: company_code(公司) / cust_code(客商编码) / cust_name(客商名称)
 *   客商编码:
 *     2.0 → CUST_CODE
 *     1.0 → 1开头科目 TESTO_14, 2开头科目 TESTO_5
 *   客商名称:
 *     2.0 → CUST_NAME
 *     1.0 → 1开头科目 TESTO_15, 2开头科目 TESTO_6
 *   是否调整: 取自 1.0 FORM_DATI.IMPORTO_36 (MAX 聚合), 放在最后一列; 2.0 无对应字段, 取 0
 *   两侧客商编码均 LTRIM(·,'0') 去前导零后对齐; 金额差异 = 2.0 - 1.0
 *
 * 参数(params, 只改这里; 1.0 与 2.0 共用同一组参数):
 *   p_scenario  场景  例: '2026ACT' (年份+场景码)
 *   p_periodo   期间  例: '08'      (两位月份码, 非 YYYYMM)
 *
 * 公司限制(azi CTE): 从公司维度表 TGK_GB_HISENSE.AZIENDA 取, IN 里填公司编码;
 *                   查全部公司则把各取数段的 `AND ... IN (SELECT cod_azienda FROM azi)` 注释掉
 *
 * 科目限制: 2.0 / 1.0 账龄表均为精确科目号 COD_CONTO (见 itm CTE)
 * 输出(列别名全部英文): company_code / seq / item_name / cust_code / cust_name
 *       + by/lm/cur_amt_20   (2.0账龄 年初 / 上月 / 本月)
 *       + by/lm/cur_amt_10   (1.0账龄 年初 / 上月 / 本月)
 *       + by/lm/cur_amt_diff (差异 2.0 - 1.0)
 *       + match_flag(匹配情况) + adj_flag(是否调整, 取自 1.0 IMPORTO_36)
 *       默认只输出有差异的行(容差 0.01), 看全量则注释掉末尾 WHERE 段
 * ============================================================================*/
WITH params AS (
    SELECT '2026ACT' AS p_scenario,  /* 场景 (年份+场景码) */
           '08'      AS p_periodo    /* 期间, 两位月份码 */
    FROM   dual
),
azi AS (                             /* 公司限制: 查全部公司则去掉各取数段的 IN 限制 */
    SELECT a.cod_azienda
    FROM   tgk_gb_hisense.azienda a
    WHERE  a.cod_azienda IN ('1740')
),
/* 往来项目 ↔ 科目映射 (2.0 / 1.0 账龄表均为精确科目号) */
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
           NVL(LTRIM(a.cust_code, '0'), '(NO_CUST)') cust_code,
           MAX(a.cust_name)                  cust_name,
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
    GROUP  BY a.cod_azienda, i.seq, i.item_name, NVL(LTRIM(a.cust_code, '0'), '(NO_CUST)')
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
       NVL(t20c.seq, t10c.seq)                                   AS seq,
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
ORDER  BY company_code, seq, cust_code;
