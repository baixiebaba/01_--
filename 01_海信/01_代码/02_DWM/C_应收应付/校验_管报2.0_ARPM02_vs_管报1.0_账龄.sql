/* ============================================================================
 * 账龄表三方校验 —— ①科目级(往来项目粒度, 含单体法人)
 *   数据源A(2.0账龄表)   : TGK_FIMA_DEV.AW_MR9_ARPM02_000001   (管报系统2.0)
 *   数据源B(1.0账龄表)   : TGK_GB_HISENSE.FORM_DATI            (管报系统1.0)
 *   数据源C(1.0单体法人) : TGK_GB_HISENSE.DATI_SALDI_LORDI     (管报系统1.0)
 *
 *   配套文件: 校验_管报2.0_ARPM02_vs_管报1.0_账龄_客商级明细.sql (②客商级, 不含单体法人)
 *
 * 输出: 往来项目粒度, 按固定行序展示; 列别名全部英文
 *   item_name(往来项目)
 *   by/lm/cur_amt_20     = 2.0账龄   年初 / 上月 / 本月
 *   by/lm/cur_amt_10     = 1.0账龄   年初 / 上月 / 本月
 *   by/lm/cur_amt_lordi  = 1.0单体法人 年初 / 上月 / 本月
 *   by/lm/cur_amt_diff   = 差异 (2.0 - 1.0) 年初 / 上月 / 本月
 *
 * 参数(params, 只改这里; 1.0 与 2.0 共用同一组参数):
 *   p_scenario  场景  例: '2026ACT' (年份+场景码)
 *   p_periodo   期间  例: '08'      (两位月份码, 非 YYYYMM)
 *
 * 公司限制(azi CTE): 从公司维度表 TGK_GB_HISENSE.AZIENDA 取, IN 里填公司编码;
 *                   查全部公司则把各取数段的 `AND ... IN (SELECT cod_azienda FROM azi)` 注释掉
 *
 * 期间说明:
 *   2.0账龄 / 1.0账龄: 年初、上月金额已存在本月记录里(BY_BCY_0_AMT / LM_BCY_0_AMT、
 *                     IMPORTO_1 / IMPORTO_2), 只按本月期间取数即可
 *   1.0单体法人: 单期间只有一条 IMPORTO, 需取三个期间快照
 *                本月 = p_scenario + p_periodo
 *                上月 = p_scenario + (p_periodo - 1)  [01月则取上一年场景 + '12']
 *                年初 = (上一年场景) + '12'
 *                注: 若系统中"年初"存的是本年 '00' 期初期间, 把 p_by_scn 改成本年场景、
 *                    p_by 改成 '00' 即可(p3 内已注释)
 *
 * 科目限制:
 *   A/B: 精确科目号 COD_CONTO
 *   C  : 科目层级视图 V_REF_CONTO (HIE='01', NODE=节点编码, ELEM=实际科目)
 *        → DATI_SALDI_LORDI.COD_CONTO 限制在该 NODE 展开出的 ELEM 范围内
 *
 * 单体法人取数: 单期间只有一条 IMPORTO
 *   年初 = 去年12月 IMPORTO, 上月 = 上月 IMPORTO, 本月 = 本月 IMPORTO (三个期间快照)
 * ============================================================================*/
WITH params AS (
    SELECT '2026ACT' AS p_scenario,  /* 场景 (年份+场景码) */
           '08'      AS p_periodo    /* 期间, 两位月份码 */
    FROM   dual
),
/* 公司限制清单: 从公司维度表取, IN 里填要查的公司编码; 查全部公司则去掉各取数段的 IN 限制 */
azi AS (
    SELECT a.cod_azienda
    FROM   tgk_gb_hisense.azienda a
    WHERE  a.cod_azienda IN ('1740')
),
p3 AS (
    SELECT p_scenario, p_periodo,
           /* 上一年场景: 2026ACT → 2025ACT */
           TO_CHAR(TO_NUMBER(SUBSTR(p_scenario, 1, 4)) - 1) || SUBSTR(p_scenario, 5) AS p_by_scn,
           /* 上月: 01 月则取上一年场景的 12 月, 否则同场景月份 -1 */
           CASE WHEN p_periodo = '01' THEN '12'
                ELSE LPAD(TO_NUMBER(p_periodo) - 1, 2, '0') END                      AS p_lm,
           CASE WHEN p_periodo = '01'
                THEN TO_CHAR(TO_NUMBER(SUBSTR(p_scenario, 1, 4)) - 1) || SUBSTR(p_scenario, 5)
                ELSE p_scenario END                                                   AS p_lm_scn,
           '12'                                                                       AS p_by   /* 年初期间(去年12月); 若用本年期初, 改 '00' */
    FROM   params
),
/* 往来项目 ↔ 科目映射 (2.0/1.0 账龄表: 精确科目号; 单体法人: V_REF_CONTO 节点编码) */
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
/* 2.0 账龄表: 按往来项目汇总 */
t20 AS (
    SELECT i.seq, i.item_name,
           SUM(a.by_bcy_0_amt) by_amt,    /* 年初 */
           SUM(a.lm_bcy_0_amt) lm_amt,    /* 上月 */
           SUM(a.bcy_0_amt)    cur_amt    /* 本月 */
    FROM   tgk_fima_dev.aw_mr9_arpm02_000001 a
    CROSS  JOIN p3
    JOIN   itm_dedup i ON a.cod_conto = i.conto20
    WHERE  a.cod_periodo   = p3.p_periodo
      AND  a.cod_categoria = 'ZAMOUNT'
      AND  a.cod_scenario  = p3.p_scenario
      AND  a.cod_azienda   IN (SELECT cod_azienda FROM azi)   /* 公司限制 */
    GROUP  BY i.seq, i.item_name
),
/* 1.0 账龄表: 按往来项目汇总 (客商不参与汇总, 仅科目维度) */
t10 AS (
    SELECT i.seq, i.item_name,
           SUM(f.importo_1) by_amt,       /* 年初 */
           SUM(f.importo_2) lm_amt,       /* 上月 */
           SUM(f.importo_3) cur_amt       /* 本月 */
    FROM   tgk_gb_hisense.form_dati f
    CROSS  JOIN p3
    JOIN   itm_dedup i ON f.cod_conto = i.conto10
    WHERE  f.cod_prospetto IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
      AND  f.cod_categoria IN ('$AMOUNT', '1ADJ', '1REC')
      AND  f.cod_periodo   = p3.p_periodo
      AND  f.cod_scenario  = p3.p_scenario
      AND  f.cod_azienda   IN (SELECT cod_azienda FROM azi)   /* 公司限制 */
    GROUP  BY i.seq, i.item_name
),
/* 科目层级视图: HIE='01' 下 NODE → ELEM 全量映射 */
node_elem AS (
    SELECT rc.node, rc.elem
    FROM   tgk_gb_hisense.v_ref_conto rc
    WHERE  rc.hie = '01'
),
/* 1.0 单体法人: 三个月份快照各取 IMPORTO, 科目经 V_REF_CONTO 按 NODE 展开后限制 */
tsd AS (
    SELECT i.seq, i.item_name,
           /* 年初: 上一年场景 + 12月 */
           SUM(CASE WHEN s.cod_scenario = p3.p_by_scn AND s.cod_periodo = p3.p_by THEN s.importo END) by_amt,
           /* 上月: 上月场景 + 上月期间 */
           SUM(CASE WHEN s.cod_scenario = p3.p_lm_scn AND s.cod_periodo = p3.p_lm THEN s.importo END) lm_amt,
           /* 本月 */
           SUM(CASE WHEN s.cod_scenario = p3.p_scenario AND s.cod_periodo = p3.p_periodo THEN s.importo END) cur_amt
    FROM   tgk_gb_hisense.dati_saldi_lordi s
    CROSS  JOIN p3
    JOIN   node_elem ne ON ne.elem      = s.cod_conto
    JOIN   itm      i  ON i.node_code = ne.node
    WHERE  (   (s.cod_scenario = p3.p_by_scn   AND s.cod_periodo = p3.p_by)      /* 年初(去年12月) */
            OR (s.cod_scenario = p3.p_lm_scn   AND s.cod_periodo = p3.p_lm)      /* 上月 */
            OR (s.cod_scenario = p3.p_scenario  AND s.cod_periodo = p3.p_periodo)) /* 本月 */
      AND  s.cod_categoria IN ('$AMOUNT', '1ADJ', '1SPA', '1REC', '2ADJ_CF', '2ADJ_OB')
      AND  s.cod_azienda   IN (SELECT cod_azienda FROM azi)   /* 公司限制 */
    GROUP  BY i.seq, i.item_name
)
SELECT i.item_name                                                            AS item_name,
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
FROM   itm_dedup i                                   /* 以往来项目清单为主表, 10 行固定输出 */
LEFT   JOIN t20  ON t20.seq  = i.seq
LEFT   JOIN t10  ON t10.seq  = i.seq
LEFT   JOIN tsd  ON tsd.seq  = i.seq
ORDER  BY i.seq;
