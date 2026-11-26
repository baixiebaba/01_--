/*******************************************************************************
 *                                  脚本说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261126 18:10
 * 本次修改：ALTER BY 20261126 18:10 SHIQINGFENG.EX 新增参数月凭证未清取数，已清与未清分别标记BSEG_AD/BSEG_AK与BSEG_ID/BSEG_IK。
 * 上次修改：ALTER BY 20261126 15:02 SHIQINGFENG.EX 新增BSEG已清凭证行项目落表脚本。
 *
 * 脚本名称  ：dwd_fi_mr_arap_bseg_mi.sql
 * 功能描述  ：装载六套SAP BKPF+BSEG的已清、本月未清与提前回款凭证行项目，供往来账龄明细脚本读取。
 * 源表      ：六套SAP odssap_zs{{600,700,800,900,610,810}}_bkpf_v / _bseg_v，
 *             ods.odsfima_aw_rul_revaaz_000001（S700公司编码映射）。
 * 目标表    ：test.dwd_fi_mr_arap_bseg_mi
 *
 * 修改历史：
 *   ALTER BY 20261126 18:10 SHIQINGFENG.EX 新增参数月凭证未清取数，已清与未清分别标记BSEG_AD/BSEG_AK与BSEG_ID/BSEG_IK。
 *   ALTER BY 20261126 15:02 SHIQINGFENG.EX 新增BSEG已清凭证行项目落表脚本。
 ******************************************************************************/

-- 业务输入：运行月份基准日，须与 dwd_fi_mr_arap_detail_mi.sql 的 @year_month_day 保持一致。
SET @year_month_day = '20260801';
-- 分区月份：YYYYMM，写入 dt_month。
SET @dt_month = LEFT(@year_month_day, 6);
-- SAP日期比较值：参数月月末YYYYMMDD。
SET @key_date = LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d'));
SET @key_date_sap = DATE_FORMAT(@key_date, '%Y%m%d');
-- 以上SET与下方单条INSERT OVERWRITE必须在同一session中依次执行。
set enable_auto_create_when_overwrite=true;

-- ============================================================================
-- 按参数月覆盖写入BSEG已清凭证行项目分区，load_dt 取当前时间。
-- ============================================================================
INSERT OVERWRITE TABLE test.dwd_fi_mr_arap_bseg_mi PARTITION (*)
(
      dt_month
    , system_src
    , ods_src
    , bukrs
    , cust_head_code
    , hkont
    , prctr
    , gsber
    , filkd
    , waers
    , blart
    , belnr
    , gjahr
    , buzei
    , budat
    , bldat
    , zfbdt
    , zbd1t
    , augdt
    , shkzg
    , dmbtr
    , wrbtr
    , bstat
    , rstgr
    , zlsch
    , pays_tran
    , sgtxt
    , load_dt
)
WITH
-- 汇总日立S700原始公司编码与标准公司编码映射，S700已清与未清项目按同一口径转换公司编码。
s700_company_map AS (
    SELECT DISTINCT TRIM(ent_sap700_code) AS ent_sap700_code
         , TRIM(cod_azienda) AS cod_azienda
      FROM ods.odsfima_aw_rul_revaaz_000001
     WHERE NULLIF(TRIM(ent_sap700_code), '') IS NOT NULL
),
-- ALTER BY 20261126 18:10 SHIQINGFENG.EX 六套SAP BKPF+BSEG已清、本月未清与提前回款凭证行项目，每套只扫一次BSEG同时产出已清和未清两类。
-- 已清口径：月末后清账（augdt>月末），用于回溯月末未清快照；未清口径：至今未清（augdt=00000000）且为参数月凭证。
src_bseg AS (
    SELECT 'S600' AS system_src
         , CASE WHEN s.koart = 'K' AND s.augdt > @key_date_sap THEN 'BSEG_AK'
                WHEN s.koart = 'K' THEN 'BSEG_IK'
                WHEN s.augdt > @key_date_sap THEN 'BSEG_AD'
                ELSE 'BSEG_ID'
           END AS ods_src
         , s.bukrs AS bukrs
         , CASE WHEN s.koart = 'K' THEN s.lifnr ELSE s.kunnr END AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , CASE WHEN s.koart = 'K' THEN NULL ELSE s.rstgr END AS rstgr
         , s.zlsch AS zlsch
         , CASE WHEN s.koart = 'K' THEN NULL ELSE s.pays_tran END AS pays_tran   -- 仅S600的BSEG视图有此字段
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs600_bkpf_v h
      JOIN ods.odssap_zs600_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE h.budat <= @key_date_sap
       AND s.koart IN ('D', 'K')
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND (
               s.augdt > @key_date_sap                     -- 月末后清账：回溯月末未清
               OR (
                   COALESCE(NULLIF(TRIM(s.augdt), ''), '00000000') = '00000000'
                   AND h.budat >= @year_month_day          -- 至今未清且为参数月凭证
               )
           )

    UNION ALL

    SELECT 'S700' AS system_src
         , CASE WHEN s.koart = 'K' AND s.augdt > @key_date_sap THEN 'BSEG_AK'
                WHEN s.koart = 'K' THEN 'BSEG_IK'
                WHEN s.augdt > @key_date_sap THEN 'BSEG_AD'
                ELSE 'BSEG_ID'
           END AS ods_src
         , COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), s.bukrs) AS bukrs
         , CASE WHEN s.koart = 'K' THEN s.lifnr ELSE s.kunnr END AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , CASE WHEN s.koart = 'K' THEN NULL ELSE s.rstgr END AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs700_bkpf_v h
      JOIN ods.odssap_zs700_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(s.bukrs)
     WHERE h.budat <= @key_date_sap
       AND s.koart IN ('D', 'K')
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND (
               s.augdt > @key_date_sap                     -- 月末后清账：回溯月末未清
               OR (
                   COALESCE(NULLIF(TRIM(s.augdt), ''), '00000000') = '00000000'
                   AND h.budat >= @year_month_day          -- 至今未清且为参数月凭证
               )
           )

    UNION ALL

    SELECT 'S800' AS system_src
         , CASE WHEN s.koart = 'K' AND s.augdt > @key_date_sap THEN 'BSEG_AK'
                WHEN s.koart = 'K' THEN 'BSEG_IK'
                WHEN s.augdt > @key_date_sap THEN 'BSEG_AD'
                ELSE 'BSEG_ID'
           END AS ods_src
         , s.bukrs AS bukrs
         , CASE WHEN s.koart = 'K' THEN s.lifnr ELSE s.kunnr END AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , CASE WHEN s.koart = 'K' THEN NULL ELSE s.rstgr END AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs800_bkpf_v h
      JOIN ods.odssap_zs800_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE h.budat <= @key_date_sap
       AND s.koart IN ('D', 'K')
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND (
               s.augdt > @key_date_sap                     -- 月末后清账：回溯月末未清
               OR (
                   COALESCE(NULLIF(TRIM(s.augdt), ''), '00000000') = '00000000'
                   AND h.budat >= @year_month_day          -- 至今未清且为参数月凭证
               )
           )

    UNION ALL

    SELECT 'S900' AS system_src
         , CASE WHEN s.koart = 'K' AND s.augdt > @key_date_sap THEN 'BSEG_AK'
                WHEN s.koart = 'K' THEN 'BSEG_IK'
                WHEN s.augdt > @key_date_sap THEN 'BSEG_AD'
                ELSE 'BSEG_ID'
           END AS ods_src
         , s.bukrs AS bukrs
         , CASE WHEN s.koart = 'K' THEN s.lifnr ELSE s.kunnr END AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , CASE WHEN s.koart = 'K' THEN NULL ELSE s.rstgr END AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs900_bkpf_v h
      JOIN ods.odssap_zs900_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE h.budat <= @key_date_sap
       AND s.koart IN ('D', 'K')
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND (
               s.augdt > @key_date_sap                     -- 月末后清账：回溯月末未清
               OR (
                   COALESCE(NULLIF(TRIM(s.augdt), ''), '00000000') = '00000000'
                   AND h.budat >= @year_month_day          -- 至今未清且为参数月凭证
               )
           )

    UNION ALL

    SELECT 'S610' AS system_src
         , CASE WHEN s.koart = 'K' AND s.augdt > @key_date_sap THEN 'BSEG_AK'
                WHEN s.koart = 'K' THEN 'BSEG_IK'
                WHEN s.augdt > @key_date_sap THEN 'BSEG_AD'
                ELSE 'BSEG_ID'
           END AS ods_src
         , s.bukrs AS bukrs
         , CASE WHEN s.koart = 'K' THEN s.lifnr ELSE s.kunnr END AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , CASE WHEN s.koart = 'K' THEN NULL ELSE s.rstgr END AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs610_bkpf_v h
      JOIN ods.odssap_zs610_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE h.budat <= @key_date_sap
       AND s.koart IN ('D', 'K')
       AND s.mandt = '610'                        -- 视图含610与810两套，按系统取数
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND (
               s.augdt > @key_date_sap                     -- 月末后清账：回溯月末未清
               OR (
                   COALESCE(NULLIF(TRIM(s.augdt), ''), '00000000') = '00000000'
                   AND h.budat >= @year_month_day          -- 至今未清且为参数月凭证
               )
           )

    UNION ALL

    SELECT 'S810' AS system_src
         , CASE WHEN s.koart = 'K' AND s.augdt > @key_date_sap THEN 'BSEG_AK'
                WHEN s.koart = 'K' THEN 'BSEG_IK'
                WHEN s.augdt > @key_date_sap THEN 'BSEG_AD'
                ELSE 'BSEG_ID'
           END AS ods_src
         , s.bukrs AS bukrs
         , CASE WHEN s.koart = 'K' THEN s.lifnr ELSE s.kunnr END AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , CASE WHEN s.koart = 'K' THEN NULL ELSE s.rstgr END AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs810_bkpf_v h
      JOIN ods.odssap_zs810_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE h.budat <= @key_date_sap
       AND s.koart IN ('D', 'K')
       AND s.mandt = '810'                        -- 视图含610与810两套，按系统取数
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND (
               s.augdt > @key_date_sap                     -- 月末后清账：回溯月末未清
               OR (
                   COALESCE(NULLIF(TRIM(s.augdt), ''), '00000000') = '00000000'
                   AND h.budat >= @year_month_day          -- 至今未清且为参数月凭证
               )
           )

    UNION ALL

    SELECT 'S600' AS system_src
         , 'BSAD_EPAY' AS ods_src
         , s.bukrs AS bukrs
         , s.kunnr AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , s.rstgr AS rstgr
         , s.zlsch AS zlsch
         , s.pays_tran AS pays_tran                -- 仅S600的BSEG视图有此字段
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs600_bkpf_v h
      JOIN ods.odssap_zs600_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE s.augdt >= @year_month_day             -- 当月清账
       AND s.augdt <= @key_date_sap
       AND s.koart = 'D'
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND COALESCE(s.rstgr, '|') = '400'

    UNION ALL

    SELECT 'S700' AS system_src
         , 'BSAD_EPAY' AS ods_src
         , COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), s.bukrs) AS bukrs
         , s.kunnr AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , s.rstgr AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran                       -- BSEG无此字段，与其余提前回款分支保持一致
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs700_bkpf_v h
      JOIN ods.odssap_zs700_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(s.bukrs)
     WHERE s.augdt >= @year_month_day             -- 当月清账
       AND s.augdt <= @key_date_sap
       AND s.koart = 'D'
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND COALESCE(s.rstgr, '|') = '400'

    UNION ALL

    SELECT 'S800' AS system_src
         , 'BSAD_EPAY' AS ods_src
         , s.bukrs AS bukrs
         , s.kunnr AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , s.rstgr AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran                       -- BSEG无此字段，与其余提前回款分支保持一致
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs800_bkpf_v h
      JOIN ods.odssap_zs800_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE s.augdt >= @year_month_day             -- 当月清账
       AND s.augdt <= @key_date_sap
       AND s.koart = 'D'
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND COALESCE(s.rstgr, '|') = '400'

    UNION ALL

    SELECT 'S900' AS system_src
         , 'BSAD_EPAY' AS ods_src
         , s.bukrs AS bukrs
         , s.kunnr AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , s.rstgr AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran                       -- BSEG无此字段，与其余提前回款分支保持一致
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs900_bkpf_v h
      JOIN ods.odssap_zs900_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE s.augdt >= @year_month_day             -- 当月清账
       AND s.augdt <= @key_date_sap
       AND s.koart = 'D'
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND COALESCE(s.rstgr, '|') = '400'

    UNION ALL

    SELECT 'S610' AS system_src
         , 'BSAD_EPAY' AS ods_src
         , s.bukrs AS bukrs
         , s.kunnr AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , s.rstgr AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran                       -- BSEG无此字段，与其余提前回款分支保持一致
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs610_bkpf_v h
      JOIN ods.odssap_zs610_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE s.augdt >= @year_month_day             -- 当月清账
       AND s.augdt <= @key_date_sap
       AND s.koart = 'D'
       AND s.mandt = '610'                        -- 视图含610与810两套，按系统取数
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND COALESCE(s.rstgr, '|') = '400'

    UNION ALL

    SELECT 'S810' AS system_src
         , 'BSAD_EPAY' AS ods_src
         , s.bukrs AS bukrs
         , s.kunnr AS cust_head_code
         , s.hkont AS hkont
         , s.prctr AS prctr
         , s.gsber AS gsber
         , s.filkd AS filkd
         , h.waers AS waers
         , h.blart AS blart
         , s.belnr AS belnr
         , s.gjahr AS gjahr
         , s.buzei AS buzei
         , h.budat AS budat
         , h.bldat AS bldat
         , s.zfbdt AS zfbdt
         , s.zbd1t AS zbd1t
         , s.augdt AS augdt
         , s.shkzg AS shkzg
         , s.dmbtr AS dmbtr
         , s.wrbtr AS wrbtr
         , h.bstat AS bstat
         , s.rstgr AS rstgr
         , s.zlsch AS zlsch
         , NULL AS pays_tran                       -- BSEG无此字段，与其余提前回款分支保持一致
         , s.sgtxt AS sgtxt
      FROM ods.odssap_zs810_bkpf_v h
      JOIN ods.odssap_zs810_bseg_v s
        ON h.bukrs = s.bukrs
       AND h.belnr = s.belnr
       AND h.gjahr = s.gjahr
     WHERE s.augdt >= @year_month_day             -- 当月清账
       AND s.augdt <= @key_date_sap
       AND s.koart = 'D'
       AND s.mandt = '810'                        -- 视图含610与810两套，按系统取数
       AND COALESCE(h.bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(s.dmbtr, 0) <> 0 OR COALESCE(s.wrbtr, 0) <> 0)
       AND COALESCE(s.rstgr, '|') = '400'
)
SELECT @dt_month AS dt_month
     , s.system_src
     , s.ods_src
     , s.bukrs
     , s.cust_head_code
     , s.hkont
     , s.prctr
     , s.gsber
     , s.filkd
     , s.waers
     , s.blart
     , s.belnr
     , s.gjahr
     , s.buzei
     , s.budat
     , s.bldat
     , s.zfbdt
     , s.zbd1t
     , s.augdt
     , s.shkzg
     , s.dmbtr
     , s.wrbtr
     , s.bstat
     , s.rstgr
     , s.zlsch
     , s.pays_tran
     , s.sgtxt
     , NOW() AS load_dt
  FROM src_bseg s
;
