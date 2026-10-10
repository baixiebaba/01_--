/*
-- ============================================================================
-- 最新版修改记录：20261009 MODIFY 修复SAP多格式日期转换
-- 上一版修改记录：20260921 MODIFY 更正净收付日期借贷方向逻辑
-- 上一版修改记录：20260921 ADD 新增净收付日期 netrcp_dt
-- 目标表：往来账龄明细表 test.dwd_fi_mr_arap_detail_mi
-- 修改记录：最新修改记录放最上面
--   20260921 MODIFY 更正净收付日期借贷方向逻辑
--   20260921 ADD 新增净收付日期 netrcp_dt
--   20260910 ADD BY shiqingfeng.ex 新增
-- ============================================================================
*/
-- 业务输入：运行月份基准日，格式YYYYMMDD，约定为参数月01日。
--SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');
SET @year_month_day = '20260801';
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);
-- 账龄关键日期：参数月月末DATE。
SET @key_date = LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d'));
-- SAP日期比较值：参数月月末YYYYMMDD。
SET @key_date_sap = DATE_FORMAT(@key_date, '%Y%m%d');
-- 财年：参数年份YYYY。
SET @fiscal_year = LEFT(@year_month_day, 4);
-- 财月：参数月份MM。
SET @fiscal_month = SUBSTR(@year_month_day, 5, 2);
-- 空基准日期的最小有效日期：用于计算最大账龄段。
SET @min_aging_date_sap = '00010101';
-- 以上SET与下方两段INSERT必须在同一session中依次执行。

set enable_auto_create_when_overwrite=true;
-- ============================================================================
-- 第一段：统驭科目凭证行项目。
-- 仅处理六套SAP的BSID/BSAD/BSIK/BSAK；按参数月覆盖目标月份分区。
-- ============================================================================
INSERT OVERWRITE TABLE test.dwd_fi_mr_arap_detail_mi PARTITION (*)
(
      dt_month                 -- 年月
    , `year`                   -- 年份
    , `month`                  -- 月份
    , company_code             -- 组织
    , acct_cert_type           -- 凭证类型
    , acct_cert_status         -- 凭证状态
    , acct_cert_id             -- 凭证号
    , acct_cert_item           -- 凭证行项目
    , voucher_dt               -- 凭证日期
    , posting_dt               -- 凭证过账日期
    , baseline_dt              -- 账龄起算日期
    , netrcp_dt                -- 净收付日期
    , clearing_dt              -- 清账日期
    , cust_code                -- 客商编码
    , cust_name                -- 客商名称
    , cust_head_code           -- 主户编码
    , cust_head_name           -- 主户名称
    , cust_branch_code         -- 分户编码
    , cust_branch_name         -- 分户名称
    , cp_company_code          -- 对方公司
    , country_code             -- 国家编码
    , country_name             -- 国家名称
    , acct_type_code           -- 科目类型
    , acct_src_code            -- 原始科目编码
    , acct_map_code            -- 映射后科目编码
    , channel_l1_code          -- 一级公司分类编码
    , channel_l1_name          -- 一级公司分类名称
    , channel_l2_code          -- 二级公司分类编码
    , channel_l2_name          -- 二级公司分类名称
    , channel_l3_code          -- 三级公司分类编码
    , channel_l3_name          -- 三级公司分类名称
    , tov_channel_code         -- 周转分析渠道编码
    , tov_channel_name         -- 周转分析渠道名称
    , cc_cust_group_code       -- 商冷客户群编码
    , cc_cust_group_name       -- 商冷客户群名称
    , onoffline_code           -- 渠道分组编码
    , onoffline_name           -- 渠道分组名称
    , src_profitcenter_code    -- 原始利润中心编码
    , src_profitcenter_name    -- 原始利润中心名称
    , profitcenter_code        -- 映射后利润中心编码
    , profitcenter_name        -- 映射后利润中心名称
    , bus_range_code           -- 业务范围编码
    , bus_range_name           -- 业务范围名称
    , marketing_dept_code      -- 业务管理单元编码
    , marketing_dept_name      -- 业务管理单元名称
    , nature_l1_name           -- 一级性质
    , nature_l2_name           -- 二级性质
    , nature_l3_name           -- 三级性质
    , pay_method               -- 付款方式
    , pay_reason_code          -- 付款原因代码
    , bcy_code                 -- 本位币币种
    , qcy_code                 -- 交易币币种
    , bcy_amt                  -- 本位币金额
    , qcy_amt                  -- 交易币金额
    , aging_days               -- 账龄天数
    , aging_seg_code           -- 账龄段编码
    , aging_seg_name           -- 账龄段名称
    , pays_tran                -- 付款服务商的付款编号
    , note                     -- 备注
    , system_src               -- 来源系统
    , ods_src                  -- 数据来源
    , load_dt                  -- 更新时间
)
WITH
-- 汇总日立S700原始公司编码与标准公司编码映射，供S700源表取数时转换公司编码。
s700_company_map AS (
    SELECT DISTINCT TRIM(ent_sap700_code) AS ent_sap700_code
         , TRIM(cod_azienda) AS cod_azienda
      FROM ods.odsfima_aw_rul_revaaz_000001
     WHERE NULLIF(TRIM(ent_sap700_code), '') IS NOT NULL
),
-- 汇总六套SAP的应收应付科目范围配置。
src_ztzt_003 AS (
    SELECT 'S600' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss600_ztzt_003

    UNION ALL

    SELECT 'S700' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss700_ztzt_003

    UNION ALL

    SELECT 'S800' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss800_ztzt_003

    UNION ALL

    SELECT 'S900' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss900_ztzt_003

    UNION ALL

    SELECT 'S610' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss610_ztzt_003

    UNION ALL

    SELECT 'S810' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss810_ztzt_003
),
-- 汇总六套SAP公司代码、科目表和本位币配置。
src_t001 AS (
    SELECT 'S600' AS system_src, bukrs, ktopl, waers
      FROM ods.odss600_t001

    UNION ALL

    SELECT 'S700' AS system_src
         , COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), t.bukrs) AS bukrs
         , t.ktopl
         , t.waers
      FROM ods.odss700_t001 t
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(t.bukrs)

    UNION ALL

    SELECT 'S800' AS system_src, bukrs, ktopl, waers
      FROM ods.odss800_t001

    UNION ALL

    SELECT 'S900' AS system_src, bukrs, ktopl, waers
      FROM ods.odss900_t001

     UNION ALL

    SELECT 'S610' AS system_src, bukrs, ktopl, waers
      FROM ods.odss610_t001

    UNION ALL

    SELECT 'S810' AS system_src, bukrs, ktopl, waers
      FROM ods.odss810_t001
),
-- 汇总六套SAP公司科目及统驭标识，用于识别统驭/非统驭科目。
src_skb1 AS (
    SELECT 'S600' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss600_skb1

    UNION ALL

    SELECT 'S700' AS system_src
         , COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), s.bukrs) AS bukrs
         , s.saknr
         , s.mitkz
      FROM ods.odss700_skb1 s
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(s.bukrs)

    UNION ALL

    SELECT 'S800' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss800_skb1

    UNION ALL

    SELECT 'S900' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss900_skb1

    UNION ALL

    SELECT 'S610' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss610_skb1

    UNION ALL

    SELECT 'S810' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss810_skb1
),
-- 汇总SAP客商编码映射，并以MDG客商维度补充统一属性。
cust_sap_map_dim AS (
    SELECT NULLIF(LTRIM(TRIM(m.cust_sap_code), '0'), '') AS cust_sap_code
         , CASE TRIM(m.cust_sap_client)
               WHEN '600' THEN 'S600'
               WHEN '700' THEN 'S700'
               WHEN '800' THEN 'S800'
               WHEN '900' THEN 'S900'
               WHEN '610' THEN 'S610'
               WHEN '810' THEN 'S810'
               ELSE CONCAT('S', TRIM(m.cust_sap_client))
           END AS cust_sap_client
         , TRIM(m.cust_supp_type) AS cust_supp_type
         , NULLIF(LTRIM(TRIM(m.cust_mdg_code), '0'), '') AS cust_mdg_code
      FROM dim.dim_fi_mr_customer_map_dd m
     WHERE TRIM(m.cust_supp_type) IN ('C', 'S')
),
-- 统一匹配客户和供应商SAP编码，关联MDG客商属性并保护空串、全零编码。
customer_supplier_dim AS (
    SELECT m.cust_sap_code
         , m.cust_sap_client
         , m.cust_supp_type
         , d.cust_code AS cust_mdg_code
         , d.cust_name AS name1
         , d.com_1st_code
         , d.com_1st_name
         , d.com_2nd_code
         , d.com_2nd_name
         , d.com_3rd_code
         , d.com_3rd_name
         , d.country_code
         , d.country_name
         , d.cp_company_mr_code
         , d.cp_company_code
         , d.cust_group_ccc_code
         , d.cust_group_ccc_name
      FROM cust_sap_map_dim m
      LEFT JOIN dim.dim_fi_mr_customer_dd d
        ON NULLIF(LTRIM(TRIM(d.cust_code), '0'), '') = m.cust_mdg_code
),
-- 汇总六套SAP公司级客商主数据KVERM，按系统、公司、客商类型和主户编码聚合非空付款条件。
cust_kverm_dim AS (
    SELECT k.system_src
         , k.company_code
         , k.cust_code
         , k.cust_type_code
         , MAX(k.kverm) AS kverm
      FROM (
            SELECT 'S600' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(kunnr), '0'), '') AS cust_code, 'C' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss600_knb1

            UNION ALL

            SELECT 'S600' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(lifnr), '0'), '') AS cust_code, 'V' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss600_lfb1

            UNION ALL

            SELECT 'S700' AS system_src, COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), k.bukrs) AS company_code, LTRIM(k.kunnr, '0') AS cust_code, 'C' AS cust_type_code, NULLIF(TRIM(k.kverm), '') AS kverm
              FROM ods.odss700_knb1 k
              LEFT JOIN s700_company_map hm
                ON hm.ent_sap700_code = TRIM(k.bukrs)

            UNION ALL

            SELECT 'S700' AS system_src, COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), l.bukrs) AS company_code, LTRIM(l.lifnr, '0') AS cust_code, 'V' AS cust_type_code, NULLIF(TRIM(l.kverm), '') AS kverm
              FROM ods.odss700_lfb1 l
              LEFT JOIN s700_company_map hm
                ON hm.ent_sap700_code = TRIM(l.bukrs)

            UNION ALL

            SELECT 'S800' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(kunnr), '0'), '') AS cust_code, 'C' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss800_knb1

            UNION ALL

            SELECT 'S800' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(lifnr), '0'), '') AS cust_code, 'V' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss800_lfb1

            UNION ALL

            SELECT 'S900' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(kunnr), '0'), '') AS cust_code, 'C' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss900_knb1

            UNION ALL

            SELECT 'S900' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(lifnr), '0'), '') AS cust_code, 'V' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss900_lfb1

            UNION ALL

            SELECT 'S610' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(kunnr), '0'), '') AS cust_code, 'C' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss610_knb1

            UNION ALL

            SELECT 'S610' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(lifnr), '0'), '') AS cust_code, 'V' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss610_lfb1

            UNION ALL

            SELECT 'S810' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(kunnr), '0'), '') AS cust_code, 'C' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss810_knb1

            UNION ALL

            SELECT 'S810' AS system_src, bukrs AS company_code, NULLIF(LTRIM(TRIM(lifnr), '0'), '') AS cust_code, 'V' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss810_lfb1
      ) k
     WHERE k.kverm IS NOT NULL
     GROUP BY k.system_src
            , k.company_code
            , k.cust_code
            , k.cust_type_code
),
-- 汇总六套SAP利润中心文本，用于补充利润中心名称。
src_cepct AS (
    SELECT 'S600' AS system_src, prctr, spras, ktext
      FROM ods.odss600_cepct

    UNION ALL

    SELECT 'S700' AS system_src, prctr, spras, ktext
      FROM ods.odss700_cepct

    UNION ALL

    SELECT 'S800' AS system_src, prctr, spras, ktext
      FROM ods.odss800_cepct

    UNION ALL

    SELECT 'S900' AS system_src, prctr, spras, ktext
      FROM ods.odss900_cepct

    UNION ALL

    SELECT 'S610' AS system_src, prctr, spras, ktext
      FROM ods.odss610_cepct

    UNION ALL

    SELECT 'S810' AS system_src, prctr, spras, ktext
      FROM ods.odss810_cepct
),
-- 客户未清项目：仅保留参数月末前已过账且非A/S状态的记录。
src_bsid AS (
    SELECT 'S600' AS system_src, 'BSID' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber AS gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, pays_tran, sgtxt
      FROM ods.odsslt_s600_bsid
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S700' AS system_src, 'BSID' AS ods_src, COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), b.bukrs) AS bukrs, b.kunnr AS cust_head_code, b.hkont, b.prctr, b.gsber, b.filkd, b.waers, b.blart, b.belnr, b.gjahr, b.buzei, b.budat, b.bldat, b.zfbdt, b.zbd1t, b.augdt, b.shkzg, b.dmbtr, b.wrbtr, b.bstat, b.rstgr, b.zlsch, NULL AS pays_tran, b.sgtxt
      FROM ods.odsslt_s700_bsid b
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(b.bukrs)
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S800' AS system_src, 'BSID' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s800_bsid
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S900' AS system_src, 'BSID' AS ods_src, 
           bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch,NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s900_bsid
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S610' AS system_src, 'BSID' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch,NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s810_bsid
     WHERE budat <= @key_date_sap
       AND mandt = '610'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S810' AS system_src, 'BSID' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s810_bsid
     WHERE budat <= @key_date_sap
       AND mandt = '810'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
),
-- 客户已清项目：保留月末前过账、月末后清账的项目，回溯月末未清快照。
src_bsad AS (
    SELECT 'S600' AS system_src, 'BSAD' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber AS gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, pays_tran, sgtxt
      FROM ods.odsslt_s600_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S700' AS system_src, 'BSAD' AS ods_src, COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), b.bukrs) AS bukrs, b.kunnr AS cust_head_code, b.hkont, b.prctr, b.gsber, b.filkd, b.waers, b.blart, b.belnr, b.gjahr, b.buzei, b.budat, b.bldat, b.zfbdt, b.zbd1t, b.augdt, b.shkzg, b.dmbtr, b.wrbtr, b.bstat, b.rstgr, b.zlsch, NULL AS pays_tran, b.sgtxt
      FROM ods.odsslt_s700_bsad b
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(b.bukrs)
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S800' AS system_src, 'BSAD' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s800_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S900' AS system_src, 'BSAD' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s900_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S610' AS system_src, 'BSAD' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s810_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND mandt = '610'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S810' AS system_src, 'BSAD' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s810_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND mandt = '810'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL
    -- 提前回款部分取已清表BSAD，清账日期限制在参数月份首日至月末。
    SELECT 'S600' AS system_src, 'BSAD_EPAY' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber AS gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, pays_tran, sgtxt
      FROM ods.odsslt_s600_bsad
     WHERE augdt >= @year_month_day
       AND augdt <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
       AND COALESCE(rstgr,'|') = '400'

    UNION ALL

    SELECT 'S700' AS system_src, 'BSAD_EPAY' AS ods_src, COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), b.bukrs) AS bukrs, b.kunnr AS cust_head_code, b.hkont, b.prctr, b.gsber, b.filkd, b.waers, b.blart, b.belnr, b.gjahr, b.buzei, b.budat, b.bldat, b.zfbdt, b.zbd1t, b.augdt, b.shkzg, b.dmbtr, b.wrbtr, b.bstat, b.rstgr, b.zlsch, NULL AS pays_tran, b.sgtxt
      FROM ods.odsslt_s700_bsad b
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(b.bukrs)
     WHERE augdt >= @year_month_day
       AND augdt <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
       AND COALESCE(rstgr,'|') = '400'

    UNION ALL

    SELECT 'S800' AS system_src, 'BSAD_EPAY' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s800_bsad
     WHERE augdt >= @year_month_day
       AND augdt <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
       AND COALESCE(rstgr,'|') = '400'

    UNION ALL

    SELECT 'S900' AS system_src, 'BSAD_EPAY' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s900_bsad
     WHERE augdt >= @year_month_day
       AND augdt <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
       AND COALESCE(rstgr,'|') = '400'

    UNION ALL

    SELECT 'S610' AS system_src, 'BSAD_EPAY' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s810_bsad
     WHERE augdt >= @year_month_day
       AND augdt <= @key_date_sap
       AND mandt = '610'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
       AND COALESCE(rstgr,'|') = '400'

    UNION ALL

    SELECT 'S810' AS system_src, 'BSAD_EPAY' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, NULL AS  pays_tran, sgtxt
      FROM ods.odsslt_s810_bsad
     WHERE augdt >= @year_month_day
       AND augdt <= @key_date_sap
       AND mandt = '810'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
       AND COALESCE(rstgr,'|') = '400'

),
-- 供应商未清项目：仅保留参数月末前已过账且非A/S状态的记录。
src_bsik AS (
    SELECT 'S600' AS system_src, 'BSIK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, gsber AS gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s600_bsik
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S700' AS system_src, 'BSIK' AS ods_src, COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), b.bukrs) AS bukrs, b.lifnr AS cust_head_code, b.hkont, b.prctr, b.gsber, b.filkd, b.waers, b.blart, b.belnr, b.gjahr, b.buzei, b.budat, b.bldat, b.zfbdt, b.zbd1t, b.augdt, b.shkzg, b.dmbtr, b.wrbtr, b.bstat, NULL AS rstgr, b.zlsch, NULL AS pays_tran, b.sgtxt
      FROM ods.odsslt_s700_bsik b
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(b.bukrs)
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S800' AS system_src, 'BSIK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odss800_bsik
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S900' AS system_src, 'BSIK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odss900_bsik
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S610' AS system_src, 'BSIK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s810_bsik
     WHERE budat <= @key_date_sap
       AND mandt = '610'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S810' AS system_src, 'BSIK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s810_bsik
     WHERE budat <= @key_date_sap
       AND mandt = '810'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
),
-- 供应商已清项目：保留月末前过账、月末后清账的项目，回溯月末未清快照。
src_bsak AS (
    SELECT 'S600' AS system_src, 'BSAK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, 
            gsber AS gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s600_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S700' AS system_src, 'BSAK' AS ods_src, COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), b.bukrs) AS bukrs, b.lifnr AS cust_head_code, b.hkont, b.prctr, b.gsber, b.filkd, b.waers, b.blart, b.belnr, b.gjahr, b.buzei, b.budat, b.bldat, b.zfbdt, b.zbd1t, b.augdt, b.shkzg, b.dmbtr, b.wrbtr, b.bstat, NULL AS rstgr, b.zlsch, NULL AS pays_tran, b.sgtxt
      FROM ods.odsslt_s700_bsak b
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(b.bukrs)
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S800' AS system_src, 'BSAK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s800_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S900' AS system_src, 'BSAK' AS ods_src,
            bukrs, lifnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s900_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S610' AS system_src, 'BSAK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s810_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND mandt = '610'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)

    UNION ALL

    SELECT 'S810' AS system_src, 'BSAK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, zbd1t, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s810_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND mandt = '810'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
),
-- 按系统、公司和科目区间识别统驭科目，仅保留D应收/K应付。
account_cfg AS (
    SELECT DISTINCT t.system_src
         , t.bukrs AS company_code
         , s.saknr AS acct_code
         , s.mitkz AS acct_type_code
      FROM src_ztzt_003 z
     INNER JOIN src_t001 t
        ON t.system_src = z.system_src
       AND t.ktopl = z.ktopl
     INNER JOIN src_skb1 s
        ON s.system_src = t.system_src
       AND s.bukrs = t.bukrs
       AND s.saknr BETWEEN z.hkonf AND z.hkont
       AND s.mitkz IN ('D', 'K')
),
-- 合并四类稳定同构行项目源，并标记应收/应付及客商类型。
unioned_items AS (
    SELECT 'D' AS acct_type_code
         , 'CUSTOMER' AS object_source
         , b.*
      FROM src_bsid b

    UNION ALL

    SELECT 'D' AS acct_type_code
         , 'CUSTOMER' AS object_source
         , b.*
      FROM src_bsad b

    UNION ALL

    SELECT 'K' AS acct_type_code
         , 'VENDOR' AS object_source
         , b.*
      FROM src_bsik b

    UNION ALL

    SELECT 'K' AS acct_type_code
         , 'VENDOR' AS object_source
         , b.*
      FROM src_bsak b
),
-- 统一投影27字段接口，并一次关联统驭科目配置过滤有效行项目。
all_items AS (
    SELECT b.system_src
         , b.ods_src
         , b.acct_type_code
         , b.object_source
         , b.bukrs
         , b.cust_head_code
         , b.hkont
         , b.prctr
         , b.gsber
         , b.filkd
         , b.waers
         , b.blart
         , b.belnr
         , b.gjahr
         , b.buzei
         , b.budat
         , b.bldat
         , b.zfbdt
         , b.zbd1t
         , b.augdt
         , b.shkzg
         , b.dmbtr
         , b.wrbtr
         , b.bstat
         , b.rstgr
         , b.zlsch
         , b.pays_tran
         , b.sgtxt
      FROM unioned_items b
     INNER JOIN account_cfg c
        ON c.system_src = b.system_src
       AND c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = b.acct_type_code
),
-- 按目标月份筛选有效科目映射，并按原始科目和系统聚合。
acct_mapping AS (
    SELECT a.acct_src_code AS racct_src_code
         , MAX(a.acct_map_code) AS acct_map_code
         , a.system_src
      FROM dim.dim_rule_fi_mr_acct_mapping a
     WHERE NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
     GROUP BY a.acct_src_code
            , a.system_src
),
-- 读取有效月份内的账龄日期规则，并区分公司级与系统级配置。
agingdate_cfg AS (
    SELECT TRIM(r.system_src) AS system_src
         , NULLIF(TRIM(r.company_code), '') AS company_code
      FROM dim.dim_rule_fi_mr_ar_agingdate r
     WHERE NVL(r.valid_fr, '202401') <= @dt_month
       AND NVL(r.valid_to, '999999') >= @dt_month
     GROUP BY TRIM(r.system_src)
            , NULLIF(TRIM(r.company_code), '')
),
-- 按AB、公司级、系统级和默认BLDAT的优先级确定账龄起算字段；基准日期为空时使用最小有效日期。
items_with_aging_date AS (
    SELECT a.*
         , CASE
               WHEN a.blart = 'AB' THEN COALESCE(
                   NULLIF(TRIM(a.zfbdt), '')
                 , @min_aging_date_sap
               )
               WHEN company_cfg.system_src IS NOT NULL THEN COALESCE(
                   NULLIF(TRIM(a.zfbdt), '')
                 , @min_aging_date_sap
               )
               WHEN system_cfg.system_src IS NOT NULL THEN COALESCE(
                   NULLIF(TRIM(a.zfbdt), '')
                 , @min_aging_date_sap
               )
               ELSE NULLIF(TRIM(a.bldat), '')
           END AS aging_date_sap
      FROM all_items a
      LEFT JOIN agingdate_cfg company_cfg
        ON company_cfg.system_src = a.system_src
       AND company_cfg.company_code = a.bukrs
      LEFT JOIN agingdate_cfg system_cfg
        ON system_cfg.system_src = a.system_src
       AND system_cfg.company_code IS NULL
),
-- 转换日期、标准化客商编码、处理借贷方向并计算账龄天数。
normalized_items AS (
    SELECT a.system_src
         , a.ods_src
         , a.object_source
         , CASE
               WHEN TRIM(a.bukrs) = '6000' 
                 THEN CASE TRIM(a.gsber)
                        WHEN '200' THEN '6000A'
                        WHEN '400' THEN '6000B'
                        WHEN '500' THEN '6000C'
                        ELSE TRIM(a.bukrs)
                     END
                 ELSE TRIM(a.bukrs)
           END AS company_code
         , a.bukrs AS org_company_code
         , a.blart AS acct_cert_type
         , a.bstat AS acct_cert_status
         , a.belnr AS acct_cert_id
         , NULLIF(TRIM(a.gjahr), '') AS gjahr
         , a.buzei AS acct_cert_item
         -- SAP日期统一支持YYYYMMDD、YYYY-MM-DD和YYYY-MM-DD HH:MM:SS；空串、00000000及非法值返回NULL。
         , CASE
               WHEN NULLIF(TRIM(CAST(a.bldat AS STRING)), '') IS NULL
                 OR NULLIF(TRIM(CAST(a.bldat AS STRING)), '') = '00000000'
                   THEN NULL
               WHEN TRIM(CAST(a.bldat AS STRING)) REGEXP '^[0-9]{8}$'
                   THEN CAST(STR_TO_DATE(TRIM(CAST(a.bldat AS STRING)), '%Y%m%d') AS DATE)
               WHEN TRIM(CAST(a.bldat AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                   THEN CAST(STR_TO_DATE(TRIM(CAST(a.bldat AS STRING)), '%Y-%m-%d %H:%i:%s') AS DATE)
               WHEN TRIM(CAST(a.bldat AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   THEN CAST(STR_TO_DATE(TRIM(CAST(a.bldat AS STRING)), '%Y-%m-%d') AS DATE)
           END AS voucher_dt
         , CASE
               WHEN NULLIF(TRIM(CAST(a.budat AS STRING)), '') IS NULL
                 OR NULLIF(TRIM(CAST(a.budat AS STRING)), '') = '00000000'
                   THEN NULL
               WHEN TRIM(CAST(a.budat AS STRING)) REGEXP '^[0-9]{8}$'
                   THEN CAST(STR_TO_DATE(TRIM(CAST(a.budat AS STRING)), '%Y%m%d') AS DATE)
               WHEN TRIM(CAST(a.budat AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                   THEN CAST(STR_TO_DATE(TRIM(CAST(a.budat AS STRING)), '%Y-%m-%d %H:%i:%s') AS DATE)
               WHEN TRIM(CAST(a.budat AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   THEN CAST(STR_TO_DATE(TRIM(CAST(a.budat AS STRING)), '%Y-%m-%d') AS DATE)
           END AS posting_dt
         , CASE
               WHEN NULLIF(TRIM(CAST(a.aging_date_sap AS STRING)), '') IS NULL
                 OR NULLIF(TRIM(CAST(a.aging_date_sap AS STRING)), '') = '00000000'
                   THEN NULL
               WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{8}$'
                   THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y%m%d') AS DATE)
               WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                   THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y-%m-%d %H:%i:%s') AS DATE)
               WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                   THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y-%m-%d') AS DATE)
           END AS baseline_dt
         , CASE
               WHEN NULLIF(TRIM(CAST(a.aging_date_sap AS STRING)), '') IS NULL
                 OR NULLIF(TRIM(CAST(a.aging_date_sap AS STRING)), '') = '00000000'
                   THEN NULL
               WHEN a.shkzg = 'H'
                   THEN CASE
                            WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{8}$'
                                THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y%m%d') AS DATE)
                            WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                                THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y-%m-%d %H:%i:%s') AS DATE)
                            WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                                THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y-%m-%d') AS DATE)
                        END
               WHEN NULLIF(TRIM(a.zbd1t), '') IS NOT NULL
                   THEN DATE_ADD(
                            CASE
                                WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{8}$'
                                    THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y%m%d') AS DATE)
                                WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                                    THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y-%m-%d %H:%i:%s') AS DATE)
                                WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                                    THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y-%m-%d') AS DATE)
                            END
                          , INTERVAL CAST(NULLIF(TRIM(a.zbd1t), '') AS INT) DAY
                        )
           END AS netrcp_dt
         , STR_TO_DATE(NULLIF(TRIM(a.augdt), ''), '%Y%m%d') AS clearing_dt
         , NULLIF(LTRIM(TRIM(a.cust_head_code), '0'), '') AS cust_head_code
         , NULLIF(LTRIM(TRIM(a.filkd), '0'), '') AS cust_branch_code
         , a.acct_type_code
         , a.hkont AS acct_src_code
         , CASE WHEN a.system_src = 'S600' THEN a.hkont ELSE am.acct_map_code END AS acct_map_code
         , NULLIF(LTRIM(TRIM(a.prctr), '0'), '') AS src_profitcenter_code
         , COALESCE(a.gsber, '') AS bus_range_code
         , a.zlsch AS pay_method
         , NULLIF(TRIM(a.rstgr), '') AS pay_reason_code
         , COALESCE(a.waers, '') AS qcy_code
         , CASE
               WHEN a.shkzg = 'H'
                   THEN -a.dmbtr
               ELSE a.dmbtr
           END AS bcy_amt
         , CASE
               WHEN a.shkzg = 'H'
                   THEN -a.wrbtr
               ELSE a.wrbtr
           END AS qcy_amt
         , CAST(
               DATEDIFF(
                   @key_date
                    , CASE
                          WHEN NULLIF(TRIM(CAST(a.aging_date_sap AS STRING)), '') IS NULL
                            OR NULLIF(TRIM(CAST(a.aging_date_sap AS STRING)), '') = '00000000'
                              THEN NULL
                          WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{8}$'
                              THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y%m%d') AS DATE)
                          WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
                              THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y-%m-%d %H:%i:%s') AS DATE)
                          WHEN TRIM(CAST(a.aging_date_sap AS STRING)) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                              THEN CAST(STR_TO_DATE(TRIM(CAST(a.aging_date_sap AS STRING)), '%Y-%m-%d') AS DATE)
                      END
               ) + 1 AS DECIMALV3(27, 9)
           ) AS aging_days
         , a.pays_tran
         , a.sgtxt AS note
      FROM items_with_aging_date a
      LEFT JOIN acct_mapping am
        ON am.racct_src_code = a.hkont
       AND am.system_src = a.system_src
),
-- 读取目标月份有效的账龄段配置，并准备账龄天数匹配区间。
aging_seg_cfg AS (
    SELECT r.aging_seg_code
         , r.aging_seg_name
         , CAST(r.aging_seg_fr AS DECIMALV3(27, 9)) AS aging_seg_fr
         , CAST(r.aging_seg_to AS DECIMALV3(27, 9)) AS aging_seg_to
      FROM dim.dim_rule_fi_mr_ar_aging_seg r
     WHERE NVL(r.valid_fr, '202401') <= @dt_month
       AND NVL(r.valid_to, '999999') >= @dt_month
),
-- 读取应收模块渠道分组规则，并展开公司包含关系；同一匹配键的重复配置使用MAX聚合。
ar_nf_rule AS (
    SELECT CAST(a.batch_id AS INT) AS batch_id
         , b.cod_azienda AS company_code
         , a.channel_l1_code
         , a.channel_l3_code
         , MAX(a.onoffline_code) AS onoffline_code
         , MAX(a.onoffline_name) AS onoffline_name
      FROM dim.dim_rule_fi_mr_ar_nf_mapping a
      LEFT JOIN ods.odsfima_azienda b
        ON b.cod_azienda LIKE a.company_code
     WHERE NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
     GROUP BY CAST(a.batch_id AS INT)
            , b.cod_azienda
            , a.channel_l1_code
            , a.channel_l3_code
),
-- 读取收入模块线上线下规则，并展开公司包含关系；同一匹配键的重复配置使用MAX聚合。
rev_nf_rule AS (
    SELECT CAST(a.batch_id AS INT) AS batch_id
         , b.cod_azienda AS company_code
         , c.cod_azienda AS cp_company_code
         , NULLIF(LTRIM(TRIM(a.cust_code), '0'), '') AS cust_code
         , MAX(a.onoffline_code) AS onoffline_code
         , MAX(a.onoffline_name) AS onoffline_name
      FROM dim.dim_rule_fi_mr_nf_mapping a
      LEFT JOIN ods.odsfima_azienda b
        ON b.cod_azienda LIKE a.company_code
      LEFT JOIN ods.odsfima_azienda c
        ON c.cod_azienda LIKE a.cp_company_code
     WHERE NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
       AND CAST(a.batch_id AS INT) IN (1, 2, 5)
     GROUP BY CAST(a.batch_id AS INT)
            , b.cod_azienda
            , c.cod_azienda
            , NULLIF(LTRIM(TRIM(a.cust_code), '0'), '')
),
-- 构造客商和供应商行的渠道匹配上下文；两类客商使用相同规则及默认渠道处理。
nf_match_base AS (
    SELECT MD5(
               CONCAT_WS(
                   '|'
                 , COALESCE(a.system_src, '')
                 , COALESCE(a.ods_src, '')
                 , COALESCE(a.company_code, '')
                 , COALESCE(a.gjahr, '')
                 , COALESCE(a.acct_cert_id, '')
                 , COALESCE(a.acct_cert_item, '')
               )
           ) AS fact_key
         , a.company_code
         , CASE
               WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL
                   THEN a.cust_branch_code
               ELSE a.cust_head_code
           END AS cust_code
         , COALESCE(c.cp_company_mr_code, c.cp_company_code) AS cp_company_code
         , ch.com_1st_code AS channel_l1_code
         , ch.com_3rd_code AS channel_l3_code
      FROM normalized_items a
      LEFT JOIN customer_supplier_dim c
        ON c.cust_sap_code = a.cust_head_code
       AND c.cust_sap_client = a.system_src
       AND c.cust_supp_type = CASE
                                  WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                  ELSE 'S'
                              END
      LEFT JOIN customer_supplier_dim ch
        ON ch.cust_sap_code = CASE
                                  WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL
                                      THEN a.cust_branch_code
                                  ELSE a.cust_head_code
                              END
       AND ch.cust_sap_client = a.system_src
       AND ch.cust_supp_type = CASE
                                  WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                  ELSE 'S'
                              END
),
-- 读取目标月份有效的周转分析渠道规则；客户编码去前导零并按匹配键聚合，避免重复配置放大事实行。
tov_channel_rule AS (
    SELECT CAST(a.batch_id AS INT) AS batch_id
         , b.cod_azienda AS company_code
         , CASE
               WHEN CAST(a.batch_id AS INT) = 1
                   THEN NULLIF(LTRIM(TRIM(a.cust_code), '0'), '')
           END AS cust_code
         , CASE
               WHEN CAST(a.batch_id AS INT) = 2
                   THEN a.channel_l3_code
           END AS channel_l3_code
         , MAX(a.tov_channel_code) AS tov_channel_code
         , MAX(a.tov_channel_name) AS tov_channel_name
      FROM dim.dim_rule_fi_mr_ar_tov_channel_mapping a
      LEFT JOIN ods.odsfima_azienda b
        ON b.cod_azienda LIKE a.company_code
     WHERE NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
       AND CAST(a.batch_id AS INT) IN (1, 2)
     GROUP BY CAST(a.batch_id AS INT)
            , b.cod_azienda
            , CASE
                  WHEN CAST(a.batch_id AS INT) = 1
                      THEN NULLIF(LTRIM(TRIM(a.cust_code), '0'), '')
              END
            , CASE
                  WHEN CAST(a.batch_id AS INT) = 2
                      THEN a.channel_l3_code
              END
),
-- 周转分析渠道按事实键生成候选；batch_id=1按公司+客商，batch_id=2按公司+三级分类。
tov_channel_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.tov_channel_code
         , r.tov_channel_name
      FROM nf_match_base b
     INNER JOIN tov_channel_rule r
        ON r.batch_id = 1
       AND r.company_code = b.company_code
       AND r.cust_code = b.cust_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.tov_channel_code
         , r.tov_channel_name
      FROM nf_match_base b
     INNER JOIN tov_channel_rule r
        ON r.batch_id = 2
       AND r.company_code = b.company_code
       AND r.channel_l3_code = b.channel_l3_code
),
-- 周转分析渠道按最小batch_id取优先级；batch_id=1命中时阻止batch_id=2回退。
tov_channel_pick AS (
    SELECT c.fact_key
         , MAX(c.tov_channel_code) AS tov_channel_code
         , MAX(c.tov_channel_name) AS tov_channel_name
      FROM tov_channel_candidate c
     INNER JOIN (
            SELECT fact_key
                 , MIN(batch_id) AS batch_id
              FROM tov_channel_candidate
             GROUP BY fact_key
     ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 应收模块渠道规则按1（公司+三级）→2（公司+二级）→3（公司）顺序匹配。
ar_nf_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.onoffline_code
         , r.onoffline_name
      FROM nf_match_base b
      INNER JOIN ar_nf_rule r
        ON (
               r.batch_id = 1
           AND r.company_code = b.company_code
           AND r.channel_l3_code = b.channel_l3_code
           )
        OR (
               r.batch_id = 2
           AND r.company_code = b.company_code
           AND r.channel_l1_code = b.channel_l1_code
           )
        OR (
               r.batch_id = 3
           AND r.company_code = b.company_code
           )
),
-- 应收规则按最小batch_id取优先级；同一事实键的重复配置使用MAX聚合。
ar_nf_pick AS (
    SELECT c.fact_key
         , MAX(c.onoffline_code) AS onoffline_code
         , MAX(c.onoffline_name) AS onoffline_name
      FROM ar_nf_candidate c
      INNER JOIN (
            SELECT fact_key
                 , MIN(batch_id) AS batch_id
              FROM ar_nf_candidate
             GROUP BY fact_key
      ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 应收规则未命中时，按收入模块既有5→2→1优先级回退匹配。
rev_nf_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.onoffline_code
         , r.onoffline_name
      FROM nf_match_base b
      INNER JOIN rev_nf_rule r
        ON (
               r.batch_id = 1
           AND r.company_code = b.company_code
           )
        OR (
               r.batch_id = 2
           AND r.company_code = b.company_code
           AND r.cust_code = b.cust_code
           )
        OR (
               r.batch_id = 5
           AND r.company_code = b.company_code
           AND r.cp_company_code = b.cp_company_code
           )
     WHERE NOT EXISTS (
               SELECT 1
                 FROM ar_nf_pick ar
                WHERE ar.fact_key = b.fact_key
           )
),
-- 收入规则按最大batch_id取优先级；同一事实键的重复配置使用MAX聚合。
rev_nf_pick AS (
    SELECT c.fact_key
         , MAX(c.onoffline_code) AS onoffline_code
         , MAX(c.onoffline_name) AS onoffline_name
      FROM rev_nf_candidate c
      INNER JOIN (
            SELECT fact_key
                 , MAX(batch_id) AS batch_id
              FROM rev_nf_candidate
             GROUP BY fact_key
      ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 应收规则优先，未命中才使用收入规则；字符串NULL表示规则显式置空，不再回退默认值。
nf_final AS (
    SELECT fact_key
         , CASE
               WHEN onoffline_code = 'NULL' THEN NULL
               ELSE onoffline_code
           END AS onoffline_code
         , CASE
               WHEN onoffline_name = 'NULL' THEN NULL
               ELSE onoffline_name
           END AS onoffline_name
      FROM ar_nf_pick
    UNION ALL
    SELECT fact_key
         , CASE
               WHEN onoffline_code = 'NULL' THEN NULL
               ELSE onoffline_code
           END AS onoffline_code
         , CASE
               WHEN onoffline_name = 'NULL' THEN NULL
               ELSE onoffline_name
           END AS onoffline_name
      FROM rev_nf_pick
),
-- 读取目标月份有效的利润中心映射规则，并展开公司编码通配配置。
ar_profitcenter_rule AS (
    SELECT CAST(a.batch_id AS INT) AS batch_id
         , NULLIF(LTRIM(TRIM(b.cod_azienda), '0'), '') AS company_code
         , NULLIF(LTRIM(TRIM(a.src_profitcenter_code), '0'), '') AS src_profitcenter_code
         , NULLIF(LTRIM(TRIM(a.acct_src_code), '0'), '') AS acct_src_code
         , NULLIF(LTRIM(TRIM(a.onoffline_code), '0'), '') AS onoffline_code
         , MAX(a.profitcenter_code) AS profitcenter_code
         , MAX(a.profitcenter_name) AS profitcenter_name
      FROM dim.dim_rule_fi_mr_ar_profit_mapping a
      LEFT JOIN ods.odsfima_azienda b
        ON b.cod_azienda LIKE TRIM(a.company_code)
     WHERE NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
       AND CAST(a.batch_id AS INT) IN (1, 3, 4, 5)
     GROUP BY CAST(a.batch_id AS INT)
            , NULLIF(LTRIM(TRIM(b.cod_azienda), '0'), '')
            , NULLIF(LTRIM(TRIM(a.src_profitcenter_code), '0'), '')
            , NULLIF(LTRIM(TRIM(a.acct_src_code), '0'), '')
            , NULLIF(LTRIM(TRIM(a.onoffline_code), '0'), '')
),
-- 按周转渠道、公司、旧利润中心、科目和渠道分组生成利润中心候选。
profitcenter_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.profitcenter_code
         , r.profitcenter_name
      FROM (
            SELECT MD5(
                       CONCAT_WS(
                           '|'
                         , COALESCE(a.system_src, '')
                         , COALESCE(a.ods_src, '')
                         , COALESCE(a.company_code, '')
                         , COALESCE(a.gjahr, '')
                         , COALESCE(a.acct_cert_id, '')
                         , COALESCE(a.acct_cert_item, '')
                       )
                   ) AS fact_key
                 , a.system_src
                 , a.ods_src
                 , a.company_code
                 , a.gjahr
                 , a.acct_cert_id
                 , a.acct_cert_item
                 , a.src_profitcenter_code
                 , a.acct_src_code
                 , tc.tov_channel_code
                 , CASE
                       WHEN nf.fact_key IS NOT NULL THEN nf.onoffline_code
                       ELSE '020_OFF_002'
                   END AS onoffline_code
              FROM normalized_items a
              LEFT JOIN tov_channel_pick tc
                ON tc.fact_key = MD5(
                       CONCAT_WS(
                           '|'
                         , COALESCE(a.system_src, '')
                         , COALESCE(a.ods_src, '')
                         , COALESCE(a.company_code, '')
                         , COALESCE(a.gjahr, '')
                         , COALESCE(a.acct_cert_id, '')
                         , COALESCE(a.acct_cert_item, '')
                       )
                   )
              LEFT JOIN nf_final nf
                ON nf.fact_key = MD5(
                       CONCAT_WS(
                           '|'
                         , COALESCE(a.system_src, '')
                         , COALESCE(a.ods_src, '')
                         , COALESCE(a.company_code, '')
                         , COALESCE(a.gjahr, '')
                         , COALESCE(a.acct_cert_id, '')
                         , COALESCE(a.acct_cert_item, '')
                       )
                   )
      ) b
     INNER JOIN ar_profitcenter_rule r
        ON r.batch_id = 1
       AND b.tov_channel_code LIKE 'ARTA_A_07%'
       AND r.src_profitcenter_code = b.src_profitcenter_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.profitcenter_code
         , r.profitcenter_name
      FROM (
            SELECT MD5(
                       CONCAT_WS(
                           '|'
                         , COALESCE(a.system_src, '')
                         , COALESCE(a.ods_src, '')
                         , COALESCE(a.company_code, '')
                         , COALESCE(a.gjahr, '')
                         , COALESCE(a.acct_cert_id, '')
                         , COALESCE(a.acct_cert_item, '')
                       )
                   ) AS fact_key
                 , a.system_src
                 , a.ods_src
                 , a.company_code
                 , a.gjahr
                 , a.acct_cert_id
                 , a.acct_cert_item
                 , a.acct_src_code
              FROM normalized_items a
      ) b
     INNER JOIN ar_profitcenter_rule r
        ON r.batch_id = 3
       AND r.company_code = NULLIF(LTRIM(TRIM(b.company_code), '0'), '')
       AND NULLIF(LTRIM(TRIM(b.acct_src_code), '0'), '') LIKE r.acct_src_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.profitcenter_code
         , r.profitcenter_name
      FROM (
            SELECT MD5(
                       CONCAT_WS(
                           '|'
                         , COALESCE(a.system_src, '')
                         , COALESCE(a.ods_src, '')
                         , COALESCE(a.company_code, '')
                         , COALESCE(a.gjahr, '')
                         , COALESCE(a.acct_cert_id, '')
                         , COALESCE(a.acct_cert_item, '')
                       )
                   ) AS fact_key
                 , a.system_src
                 , a.ods_src
                 , a.company_code
                 , a.gjahr
                 , a.acct_cert_id
                 , a.acct_cert_item
                 , CASE
                       WHEN nf.fact_key IS NOT NULL THEN nf.onoffline_code
                       ELSE '020_OFF_002'
                   END AS onoffline_code
              FROM normalized_items a
              LEFT JOIN nf_final nf
                ON nf.fact_key = MD5(
                       CONCAT_WS(
                           '|'
                         , COALESCE(a.system_src, '')
                         , COALESCE(a.ods_src, '')
                         , COALESCE(a.company_code, '')
                         , COALESCE(a.gjahr, '')
                         , COALESCE(a.acct_cert_id, '')
                         , COALESCE(a.acct_cert_item, '')
                       )
                   )
      ) b
     INNER JOIN ar_profitcenter_rule r
        ON r.batch_id = 4
       AND r.company_code = NULLIF(LTRIM(TRIM(b.company_code), '0'), '')
       AND r.onoffline_code = NULLIF(LTRIM(TRIM(b.onoffline_code), '0'), '')
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.profitcenter_code
         , r.profitcenter_name
      FROM (
            SELECT MD5(
                       CONCAT_WS(
                           '|'
                         , COALESCE(a.system_src, '')
                         , COALESCE(a.ods_src, '')
                         , COALESCE(a.company_code, '')
                         , COALESCE(a.gjahr, '')
                         , COALESCE(a.acct_cert_id, '')
                         , COALESCE(a.acct_cert_item, '')
                       )
                   ) AS fact_key
                 , a.system_src
                 , a.ods_src
                 , a.company_code
                 , a.gjahr
                 , a.acct_cert_id
                 , a.acct_cert_item
              FROM normalized_items a
      ) b
     INNER JOIN ar_profitcenter_rule r
        ON r.batch_id = 5
       AND r.company_code = NULLIF(LTRIM(TRIM(b.company_code), '0'), '')
),
-- 按1→3→4→5业务优先级选取唯一利润中心，避免规则重复放大事实行。
profitcenter_pick AS (
    SELECT c.fact_key
         , MAX(c.profitcenter_code) AS profitcenter_code
         , MAX(c.profitcenter_name) AS profitcenter_name
      FROM profitcenter_candidate c
     INNER JOIN (
            SELECT fact_key
                 , MIN(batch_id) AS batch_id
              FROM profitcenter_candidate
             GROUP BY fact_key
     ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 公司10架构：01020为商显公司，050为日立公司。
company10_scope AS (
    SELECT TRIM(elem) AS company_code
         , MAX(
               CASE
                   WHEN TRIM(node) = '01020'
                       THEN '商显公司'
                   ELSE '日立公司'
               END
           ) AS company_scope
      FROM ods.odsfima_v_ref_azienda
     WHERE TRIM(hie) = '10'
       AND TRIM(node) IN ('01020', '050')
     GROUP BY TRIM(elem)
),
-- 客户、供应商共用的业务范围、三级性质和业务管理单元映射上下文。
ar_mapping_base AS (
    SELECT MD5(
               CONCAT_WS(
                   '|'
                 , COALESCE(a.system_src, '')
                 , COALESCE(a.ods_src, '')
                 , COALESCE(a.company_code, '')
                 , COALESCE(a.gjahr, '')
                 , COALESCE(a.acct_cert_id, '')
                 , COALESCE(a.acct_cert_item, '')
               )
           ) AS fact_key
         , a.system_src
         , a.company_code
         , a.acct_src_code
         , a.acct_map_code
         , a.acct_type_code
         , a.cust_head_code AS cust_code
         , ch.com_1st_code AS channel_l1_code
         , ch.com_2nd_code AS channel_l2_code
         , ch.country_code
         , pc.profitcenter_code
         , cs.company_scope
         , k.kverm
      FROM normalized_items a
      LEFT JOIN customer_supplier_dim c
        ON c.cust_sap_code = a.cust_head_code
       AND c.cust_sap_client = a.system_src
       AND c.cust_supp_type = CASE
                                  WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                  ELSE 'S'
                              END
      LEFT JOIN customer_supplier_dim ch
        ON ch.cust_sap_code = a.cust_head_code
       AND ch.cust_sap_client = a.system_src
       AND ch.cust_supp_type = CASE
                                  WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                  ELSE 'S'
                              END
      LEFT JOIN cust_kverm_dim k
        ON k.system_src = a.system_src
       AND k.company_code = a.company_code
       AND k.cust_type_code = CASE
                                  WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                  ELSE 'V'
                              END
       AND k.cust_code = a.cust_head_code
      LEFT JOIN profitcenter_pick pc
        ON pc.fact_key = MD5(
               CONCAT_WS(
                   '|'
                 , COALESCE(a.system_src, '')
                 , COALESCE(a.ods_src, '')
                 , COALESCE(a.company_code, '')
                 , COALESCE(a.gjahr, '')
                 , COALESCE(a.acct_cert_id, '')
                 , COALESCE(a.acct_cert_item, '')
               )
           )
      LEFT JOIN company10_scope cs
        ON cs.company_code = a.company_code
),
-- 按有效期聚合三级性质映射规则。
ar_nature_rule AS (
    SELECT CAST(batch_id AS INT) AS batch_id
         , company_code
         , cust_code
         , profitcenter_code
         , acct_src_code AS acct_map_code
         , acct_type
         , MAX(nature_l1_name) AS nature_l1_name
         , MAX(nature_l2_name) AS nature_l2_name
         , MAX(nature_l3_name) AS nature_l3_name
      FROM dim.dim_rule_fi_mr_ar_nature
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY CAST(batch_id AS INT)
            , company_code
            , cust_code
            , profitcenter_code
            , acct_src_code
            , acct_type
),
-- 三级性质按1→2→3→4→5的最小batch优先；每个batch单独关联，避免OR条件。
ar_nature_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 1
       AND r.company_code = b.company_code
       AND r.acct_map_code = b.acct_src_code
       AND r.cust_code = b.cust_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 2
       AND r.company_code = b.company_code
       AND r.cust_code = b.cust_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 3
       AND r.company_code = b.company_code
       AND r.acct_map_code = b.acct_src_code
       AND r.profitcenter_code = b.profitcenter_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 4
       AND r.company_code = b.company_code
       AND r.acct_map_code = b.acct_src_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 5
       AND r.acct_map_code = b.acct_src_code
       AND r.cust_code = b.cust_code
),
-- 按最小批次优先原则确定三级性质。
ar_nature_pick AS (
    SELECT c.fact_key
         , MAX(c.nature_l1_name) AS nature_l1_name
         , MAX(c.nature_l2_name) AS nature_l2_name
         , MAX(c.nature_l3_name) AS nature_l3_name
      FROM ar_nature_candidate c
     INNER JOIN (
            SELECT fact_key
                 , MIN(batch_id) AS batch_id
              FROM ar_nature_candidate
             GROUP BY fact_key
     ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 按有效期聚合业务范围映射规则。
ar_busrange_rule AS (
    SELECT CAST(batch_id AS INT) AS batch_id
         , company_code
         , channel_l2_code
         , nature_l3_name
         , MAX(bus_range_code) AS bus_range_code
         , MAX(bus_range_name) AS bus_range_name
      FROM dim.dim_rule_fi_mr_ar_busrange_mapping
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY CAST(batch_id AS INT)
            , company_code
            , channel_l2_code
            , nature_l3_name
),
-- 非商显、非日立公司按1（公司+二级分类）→2（公司+三级性质）→3（公司）映射。
ar_busrange_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.bus_range_code
         , r.bus_range_name
      FROM ar_mapping_base b
     INNER JOIN ar_busrange_rule r
        ON r.batch_id = 1
       AND b.company_scope IS NULL
       AND r.company_code = b.company_code
       AND r.channel_l2_code = b.channel_l2_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.bus_range_code
         , r.bus_range_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_pick n
        ON n.fact_key = b.fact_key
     INNER JOIN ar_busrange_rule r
        ON r.batch_id = 2
       AND b.company_scope IS NULL
       AND r.company_code = b.company_code
       AND r.nature_l3_name = n.nature_l3_name
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.bus_range_code
         , r.bus_range_name
      FROM ar_mapping_base b
     INNER JOIN ar_busrange_rule r
        ON r.batch_id = 3
       AND b.company_scope IS NULL
       AND r.company_code = b.company_code
),
-- 从业务范围候选中按最小批次选取业务范围映射。
ar_busrange_pick AS (
    SELECT c.fact_key
         , MAX(c.bus_range_code) AS bus_range_code
         , MAX(c.bus_range_name) AS bus_range_name
      FROM ar_busrange_candidate c
     INNER JOIN (
        SELECT fact_key
             , MIN(batch_id) AS batch_id
          FROM ar_busrange_candidate
         GROUP BY fact_key
     ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 聚合有效期内国家与业务范围的映射规则。
ar_country_busrange_rule AS (
    SELECT country_code
         , MAX(bus_range_code) AS bus_range_code
         , MAX(bus_range_name) AS bus_range_name
      FROM dim.dim_rule_fi_mr_ar_country_busrange_mapping
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY country_code
),
-- 聚合有效期内业务管理单元映射规则。
ar_busdept_rule AS (
    SELECT CAST(batch_id AS INT) AS batch_id
         , system_src
         , profitcenter_code
         , nature_l3_name
         , MAX(marketing_dept_code) AS marketing_dept_code
         , MAX(marketing_dept_name) AS marketing_dept_name
      FROM dim.dim_rule_fi_mr_ar_busdept_mapping
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY CAST(batch_id AS INT)
            , system_src
            , profitcenter_code
            , nature_l3_name
),
-- 按1（系统+映射后利润中心）→2（系统+三级性质）生成业务管理单元候选。
ar_busdept_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.marketing_dept_code
         , r.marketing_dept_name
      FROM ar_mapping_base b
     INNER JOIN ar_busdept_rule r
        ON r.batch_id = 1
       AND r.system_src = b.system_src
       AND r.profitcenter_code = b.profitcenter_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.marketing_dept_code
         , r.marketing_dept_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_pick n
        ON n.fact_key = b.fact_key
     INNER JOIN ar_busdept_rule r
        ON r.batch_id = 2
       AND r.system_src = b.system_src
       AND r.nature_l3_name = n.nature_l3_name
),
-- 从业务管理单元候选中按最小批次选取映射结果。
ar_busdept_pick AS (
    SELECT c.fact_key
         , MAX(c.marketing_dept_code) AS marketing_dept_code
         , MAX(c.marketing_dept_name) AS marketing_dept_name
      FROM ar_busdept_candidate c
     INNER JOIN (
        SELECT fact_key
             , MIN(batch_id) AS batch_id
          FROM ar_busdept_candidate
         GROUP BY fact_key
     ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 汇总业务范围与业务管理单元映射结果。
ar_business_mapping AS (
    SELECT b.fact_key
         , CASE WHEN n.fact_key IS NOT NULL THEN n.nature_l1_name ELSE b.kverm END AS nature_l1_name
         , CASE WHEN n.fact_key IS NOT NULL THEN n.nature_l2_name ELSE NULL END AS nature_l2_name
         , CASE WHEN n.fact_key IS NOT NULL THEN n.nature_l3_name ELSE NULL END AS nature_l3_name
         , CASE
               WHEN b.company_scope = '商显公司' AND UPPER(TRIM(b.country_code)) = 'CN'
                   THEN '2000'
               WHEN b.company_scope = '商显公司'
                   THEN '3000'
               WHEN b.company_scope = '日立公司' AND UPPER(TRIM(b.country_code)) = 'CN'
                   THEN '2200'
               WHEN b.company_scope = '日立公司'
                   THEN cr.bus_range_code
               ELSE br.bus_range_code
           END AS bus_range_code
         , CASE
               WHEN b.company_scope = '商显公司' AND UPPER(TRIM(b.country_code)) = 'CN'
                   THEN '中国区公共'
               WHEN b.company_scope = '商显公司'
                   THEN '海外公共'
               WHEN b.company_scope = '日立公司' AND UPPER(TRIM(b.country_code)) = 'CN'
                   THEN '日立国内营销分公司公共'
               WHEN b.company_scope = '日立公司'
                   THEN cr.bus_range_name
               ELSE br.bus_range_name
           END AS bus_range_name
         , bd.marketing_dept_code
         , bd.marketing_dept_name
      FROM ar_mapping_base b
      LEFT JOIN ar_nature_pick n
        ON n.fact_key = b.fact_key
      LEFT JOIN ar_busrange_pick br
        ON br.fact_key = b.fact_key
      LEFT JOIN ar_country_busrange_rule cr
        ON cr.country_code = b.country_code
      LEFT JOIN ar_busdept_pick bd
        ON bd.fact_key = b.fact_key
),
-- 聚合公司本位币配置。
company_dim AS (
    SELECT system_src
         , bukrs
         , MAX(waers) AS waers
      FROM src_t001
     GROUP BY system_src
            , bukrs
),
-- 仅保留语言为1的利润中心文本，并按系统/利润中心聚合。
profitcenter_dim AS (
    SELECT system_src
         , NULLIF(LTRIM(TRIM(prctr), '0'), '') AS prctr
         , MAX(ktext) AS ktext
      FROM src_cepct
     -- 仅使用语言代码1的利润中心文本。
     WHERE spras = '1'
     GROUP BY system_src
            , NULLIF(LTRIM(TRIM(prctr), '0'), '')
)
SELECT @dt_month
     , LEFT(@dt_month, 4) AS `year`
     , RIGHT(@dt_month, 2) AS `month`
     , a.company_code AS company_code 
     , a.acct_cert_type
     , a.acct_cert_status
     , a.acct_cert_id
     , a.acct_cert_item
     , a.voucher_dt
     , a.posting_dt
     , a.baseline_dt
     , a.netrcp_dt
     , a.clearing_dt
     , CASE
           WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL
               THEN a.cust_branch_code
           ELSE a.cust_head_code
       END AS cust_code
     , CASE
           WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL AND a.object_source = 'CUSTOMER'
               THEN COALESCE(bc.name1, '')
           WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL AND a.object_source = 'VENDOR'
               THEN COALESCE(bc.name1, '')
           WHEN a.object_source = 'CUSTOMER'
               THEN COALESCE(c.name1, '')
           ELSE COALESCE(c.name1, '')
       END AS cust_name
     , a.cust_head_code
     , CASE
           WHEN a.object_source = 'CUSTOMER'
               THEN COALESCE(c.name1, '')
           ELSE COALESCE(c.name1, '')
       END AS cust_head_name
     , a.cust_branch_code
     , CASE
           WHEN a.object_source = 'CUSTOMER'
               THEN COALESCE(bc.name1, '')
           ELSE COALESCE(bc.name1, '')
       END AS cust_branch_name
     , COALESCE(c.cp_company_mr_code, c.cp_company_code) AS cp_company_code
     , ci.country_code
     , ci.country_name
     , a.acct_type_code
     , a.acct_src_code
     , a.acct_map_code
     , ch.com_1st_code AS channel_l1_code
     , ch.com_1st_name AS channel_l1_name
     , ch.com_2nd_code AS channel_l2_code
     , ch.com_2nd_name AS channel_l2_name
     , ch.com_3rd_code AS channel_l3_code
     , ch.com_3rd_name AS channel_l3_name
     , tc.tov_channel_code
     , tc.tov_channel_name
     , ch.cust_group_ccc_code AS cc_cust_group_code
     , ch.cust_group_ccc_name AS cc_cust_group_name
     -- 客商和供应商均按应收规则、收入规则、传统零售默认值依次取值。
     , CASE
           WHEN nf.fact_key IS NOT NULL THEN nf.onoffline_code
           ELSE '020_OFF_002'
       END AS onoffline_code
     , CASE
           WHEN nf.fact_key IS NOT NULL THEN nf.onoffline_name
           ELSE '零售-传统零售'
       END AS onoffline_name
     , a.src_profitcenter_code
     , COALESCE(pc.ktext, '') AS src_profitcenter_name
     , COALESCE(NULLIF(TRIM(pc_map.profitcenter_code), ''), a.src_profitcenter_code) AS profitcenter_code
     , COALESCE(NULLIF(TRIM(pc_map.profitcenter_name), ''), COALESCE(pc.ktext, '')) AS profitcenter_name
     , bm.bus_range_code
     , bm.bus_range_name
     , bm.marketing_dept_code
     , bm.marketing_dept_name
     , bm.nature_l1_name
     , bm.nature_l2_name
     , bm.nature_l3_name
     , a.pay_method
     , a.pay_reason_code
     , COALESCE(co.waers, '') AS bcy_code
     , a.qcy_code
     , a.bcy_amt
     , a.qcy_amt
     , a.aging_days
     -- 账龄分段未匹配或配置值为空时，统一归入5年以上。
     , COALESCE(NULLIF(TRIM(seg.aging_seg_code), ''), '9') AS aging_seg_code
     , COALESCE(NULLIF(TRIM(seg.aging_seg_name), ''), '5年以上') AS aging_seg_name
     , a.pays_tran
     , a.note
     , a.system_src
     , a.ods_src
     , NOW() AS load_dt
  FROM normalized_items a
  LEFT JOIN nf_final nf
    ON nf.fact_key = MD5(
           CONCAT_WS(
               '|'
             , COALESCE(a.system_src, '')
             , COALESCE(a.ods_src, '')
             , COALESCE(a.company_code, '')
             , COALESCE(a.gjahr, '')
             , COALESCE(a.acct_cert_id, '')
             , COALESCE(a.acct_cert_item, '')
           )
       )
  LEFT JOIN ar_business_mapping bm
    ON bm.fact_key = MD5(
           CONCAT_WS(
               '|'
             , COALESCE(a.system_src, '')
             , COALESCE(a.ods_src, '')
             , COALESCE(a.company_code, '')
             , COALESCE(a.gjahr, '')
             , COALESCE(a.acct_cert_id, '')
             , COALESCE(a.acct_cert_item, '')
           )
       )
  LEFT JOIN tov_channel_pick tc
    ON tc.fact_key = MD5(
           CONCAT_WS(
               '|'
             , COALESCE(a.system_src, '')
             , COALESCE(a.ods_src, '')
             , COALESCE(a.company_code, '')
             , COALESCE(a.gjahr, '')
             , COALESCE(a.acct_cert_id, '')
             , COALESCE(a.acct_cert_item, '')
           )
       )
  LEFT JOIN profitcenter_pick pc_map
    ON pc_map.fact_key = MD5(
           CONCAT_WS(
               '|'
             , COALESCE(a.system_src, '')
             , COALESCE(a.ods_src, '')
             , COALESCE(a.company_code, '')
             , COALESCE(a.gjahr, '')
             , COALESCE(a.acct_cert_id, '')
             , COALESCE(a.acct_cert_item, '')
           )
       )
  LEFT JOIN aging_seg_cfg seg
    ON a.aging_days >= seg.aging_seg_fr
   AND a.aging_days <= seg.aging_seg_to
      LEFT JOIN customer_supplier_dim c
        ON c.cust_sap_code = a.cust_head_code
       AND c.cust_sap_client = a.system_src
       AND c.cust_supp_type = CASE
                                  WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                  ELSE 'S'
                              END
      LEFT JOIN customer_supplier_dim bc
        ON bc.cust_sap_code = a.cust_branch_code
       AND bc.cust_sap_client = a.system_src
       AND bc.cust_supp_type = CASE
                                   WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                   ELSE 'S'
                               END
      LEFT JOIN customer_supplier_dim ch
        ON ch.cust_sap_code = CASE
                                  WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL
                                      THEN a.cust_branch_code
                                  ELSE a.cust_head_code
                              END
       AND ch.cust_sap_client = a.system_src
       AND ch.cust_supp_type = CASE
                                  WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                  ELSE 'S'
                              END
      LEFT JOIN customer_supplier_dim ci
        ON ci.cust_sap_code = CASE
                                  WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL
                                      THEN a.cust_branch_code
                                  ELSE a.cust_head_code
                              END
       AND ci.cust_sap_client = a.system_src
       AND ci.cust_supp_type = CASE
                                  WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                  ELSE 'S'
                              END
  LEFT JOIN company_dim co
    ON co.system_src = a.system_src
   AND co.bukrs = a.company_code
  LEFT JOIN profitcenter_dim pc
    ON pc.system_src = a.system_src
   AND pc.prctr = a.src_profitcenter_code
;

-- ============================================================================
-- 第二段：非统驭科目月末累计余额。
-- 本段必须在第一段覆盖完成后追加；单独重复执行会产生重复余额行。
-- ============================================================================
INSERT INTO test.dwd_fi_mr_arap_detail_mi
(
      dt_month                 -- 年月
    , `year`                   -- 年份
    , `month`                  -- 月份
    , company_code             -- 组织
    , acct_cert_type           -- 凭证类型
    , acct_cert_status         -- 凭证状态
    , acct_cert_id             -- 凭证号
    , acct_cert_item           -- 凭证行项目
    , voucher_dt               -- 凭证日期
    , posting_dt               -- 凭证过账日期
    , baseline_dt              -- 账龄起算日期
    , netrcp_dt                -- 净收付日期
    , clearing_dt              -- 清账日期
    , cust_code                -- 客商编码
    , cust_name                -- 客商名称
    , cust_head_code           -- 主户编码
    , cust_head_name           -- 主户名称
    , cust_branch_code         -- 分户编码
    , cust_branch_name         -- 分户名称
    , cp_company_code          -- 对方公司
    , country_code             -- 国家编码
    , country_name             -- 国家名称
    , acct_type_code           -- 科目类型
    , acct_src_code            -- 原始科目编码
    , acct_map_code            -- 映射后科目编码
    , channel_l1_code          -- 一级公司分类编码
    , channel_l1_name          -- 一级公司分类名称
    , channel_l2_code          -- 二级公司分类编码
    , channel_l2_name          -- 二级公司分类名称
    , channel_l3_code          -- 三级公司分类编码
    , channel_l3_name          -- 三级公司分类名称
    , tov_channel_code         -- 周转分析渠道编码
    , tov_channel_name         -- 周转分析渠道名称
    , cc_cust_group_code       -- 商冷客户群编码
    , cc_cust_group_name       -- 商冷客户群名称
    , onoffline_code           -- 渠道分组编码
    , onoffline_name           -- 渠道分组名称
    , src_profitcenter_code    -- 原始利润中心编码
    , src_profitcenter_name    -- 原始利润中心名称
    , profitcenter_code        -- 映射后利润中心编码
    , profitcenter_name        -- 映射后利润中心名称
    , bus_range_code           -- 业务范围编码
    , bus_range_name           -- 业务范围名称
    , marketing_dept_code      -- 业务管理单元编码
    , marketing_dept_name      -- 业务管理单元名称
    , nature_l1_name           -- 一级性质
    , nature_l2_name           -- 二级性质
    , nature_l3_name           -- 三级性质
    , pay_method               -- 付款方式
    , pay_reason_code          -- 付款原因代码
    , bcy_code                 -- 本位币币种
    , qcy_code                 -- 交易币币种
    , bcy_amt                  -- 本位币金额
    , qcy_amt                  -- 交易币金额
    , aging_days               -- 账龄天数
    , aging_seg_code           -- 账龄段编码
    , aging_seg_name           -- 账龄段名称
    , pays_tran                -- 付款服务商的付款编号
    , note                     -- 备注
    , system_src               -- 来源系统
    , ods_src                  -- 数据来源
    , load_dt                  -- 更新时间
)
WITH
-- 汇总日立S700原始公司编码与标准公司编码映射，供S700源表取数时转换公司编码。
s700_company_map AS (
    SELECT DISTINCT TRIM(ent_sap700_code) AS ent_sap700_code
         , TRIM(cod_azienda) AS cod_azienda
      FROM ods.odsfima_aw_rul_revaaz_000001
     WHERE NULLIF(TRIM(ent_sap700_code), '') IS NOT NULL
),
-- 汇总六套SAP的应收应付科目范围配置。
src_ztzt_003 AS (
    SELECT 'S600' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss600_ztzt_003

    UNION ALL

    SELECT 'S700' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss700_ztzt_003

    UNION ALL

    SELECT 'S800' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss800_ztzt_003

    UNION ALL

    SELECT 'S900' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss900_ztzt_003

    UNION ALL

    SELECT 'S610' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss610_ztzt_003

    UNION ALL

    SELECT 'S810' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss810_ztzt_003
),
-- 汇总六套SAP公司代码、科目表和本位币配置。
src_t001 AS (
    SELECT 'S600' AS system_src, bukrs, ktopl, waers
      FROM ods.odss600_t001

    UNION ALL

    SELECT 'S700' AS system_src
         , COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), t.bukrs) AS bukrs
         , t.ktopl
         , t.waers
      FROM ods.odss700_t001 t
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(t.bukrs)

    UNION ALL

    SELECT 'S800' AS system_src, bukrs, ktopl, waers
      FROM ods.odss800_t001

    UNION ALL

    SELECT 'S900' AS system_src, bukrs, ktopl, waers
      FROM ods.odss900_t001

    UNION ALL

    SELECT 'S610' AS system_src, bukrs, ktopl, waers
      FROM ods.odss610_t001

    UNION ALL

    SELECT 'S810' AS system_src, bukrs, ktopl, waers
      FROM ods.odss810_t001
),
-- 汇总六套SAP公司科目及统驭标识，用于识别统驭/非统驭科目。
src_skb1 AS (
    SELECT 'S600' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss600_skb1

    UNION ALL

    SELECT 'S700' AS system_src
         , COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), s.bukrs) AS bukrs
         , s.saknr
         , s.mitkz
      FROM ods.odss700_skb1 s
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(s.bukrs)

    UNION ALL

    SELECT 'S800' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss800_skb1

    UNION ALL

    SELECT 'S900' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss900_skb1

    UNION ALL

    SELECT 'S610' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss610_skb1

    UNION ALL

    SELECT 'S810' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss810_skb1
),
-- 汇总六套SAP利润中心文本，用于补充利润中心名称。
src_cepct AS (
    SELECT 'S600' AS system_src, prctr, spras, ktext
      FROM ods.odss600_cepct

    UNION ALL

    SELECT 'S700' AS system_src, prctr, spras, ktext
      FROM ods.odss700_cepct

    UNION ALL

    SELECT 'S800' AS system_src, prctr, spras, ktext
      FROM ods.odss800_cepct

    UNION ALL

    SELECT 'S900' AS system_src, prctr, spras, ktext
      FROM ods.odss900_cepct

    UNION ALL

    SELECT 'S610' AS system_src, prctr, spras, ktext
      FROM ods.odss610_cepct

    UNION ALL

    SELECT 'S810' AS system_src, prctr, spras, ktext
      FROM ods.odss810_cepct
),
-- 识别非统驭科目：SKB1统驭标识为空，但配置对象类型为D/K。
gl_account_cfg AS (
    SELECT DISTINCT t.system_src
         , t.bukrs AS company_code
         , s.saknr AS acct_code
         , TRIM(z.koart) AS acct_type_code
      FROM src_ztzt_003 z
     INNER JOIN src_t001 t
        ON t.system_src = z.system_src
       AND t.ktopl = z.ktopl
     INNER JOIN src_skb1 s
        ON s.system_src = t.system_src
       AND s.bukrs = t.bukrs
       AND s.saknr BETWEEN z.hkonf AND z.hkont
     WHERE COALESCE(TRIM(s.mitkz), '') = ''
       AND TRIM(z.koart) IN ('D', 'K')
),
-- 合并六套SAP总账余额源，并在各物理源处按参数财年过滤。
src_gl_balance AS (
    SELECT CONCAT('S', g.rclnt) AS system_src, g.rbukrs AS company_code, g.racct AS acct_src_code, g.prctr AS src_profitcenter_code, g.rbusa AS bus_range_code, g.rtcur AS qcy_code, 'FAGLFLEXT' AS ods_src, g.hslvt, g.hsl01, g.hsl02, g.hsl03, g.hsl04, g.hsl05, g.hsl06, g.hsl07, g.hsl08, g.hsl09, g.hsl10, g.hsl11, g.hsl12, g.tslvt, g.tsl01, g.tsl02, g.tsl03, g.tsl04, g.tsl05, g.tsl06, g.tsl07, g.tsl08, g.tsl09, g.tsl10, g.tsl11, g.tsl12
      FROM ods.ods_slt_s600_faglflext g
     -- 仅扫描参数财年，避免读取无关年度余额。
     WHERE ryear = @fiscal_year

    UNION ALL

    SELECT CONCAT('S', g.rclnt) AS system_src, COALESCE(NULLIF(TRIM(hm.cod_azienda), ''), g.rbukrs) AS company_code, g.racct AS acct_src_code, g.prctr AS src_profitcenter_code, g.rbusa AS bus_range_code, g.rtcur AS qcy_code, 'FAGLFLEXT' AS ods_src, g.hslvt, g.hsl01, g.hsl02, g.hsl03, g.hsl04, g.hsl05, g.hsl06, g.hsl07, g.hsl08, g.hsl09, g.hsl10, g.hsl11, g.hsl12, g.tslvt, g.tsl01, g.tsl02, g.tsl03, g.tsl04, g.tsl05, g.tsl06, g.tsl07, g.tsl08, g.tsl09, g.tsl10, g.tsl11, g.tsl12
      FROM ods.ods_slt_s700_faglflext g
      LEFT JOIN s700_company_map hm
        ON hm.ent_sap700_code = TRIM(g.rbukrs)
     -- 仅扫描参数财年，避免读取无关年度余额。
     WHERE ryear = @fiscal_year

    UNION ALL

    SELECT CONCAT('S', rclnt) AS system_src, rbukrs AS company_code, racct AS acct_src_code, NULL AS src_profitcenter_code, rbusa AS bus_range_code, rtcur AS qcy_code, 'GLFUNCT' AS ods_src, hslvt, hsl01, hsl02, hsl03, hsl04, hsl05, hsl06, hsl07, hsl08, hsl09, hsl10, hsl11, hsl12, tslvt, tsl01, tsl02, tsl03, tsl04, tsl05, tsl06, tsl07, tsl08, tsl09, tsl10, tsl11, tsl12
      FROM ods.ods_slt_s800_glfunct
     -- 仅扫描参数财年，避免读取无关年度余额。
     WHERE ryear = @fiscal_year

    UNION ALL

    SELECT CONCAT('S', rclnt) AS system_src, rbukrs AS company_code, racct AS acct_src_code, NULL AS src_profitcenter_code, rbusa AS bus_range_code, rtcur AS qcy_code, 'GLFUNCT' AS ods_src, hslvt, hsl01, hsl02, hsl03, hsl04, hsl05, hsl06, hsl07, hsl08, hsl09, hsl10, hsl11, hsl12, tslvt, tsl01, tsl02, tsl03, tsl04, tsl05, tsl06, tsl07, tsl08, tsl09, tsl10, tsl11, tsl12
      FROM ods.ods_slt_s900_glfunct
     -- 仅扫描参数财年，避免读取无关年度余额。
     WHERE ryear = @fiscal_year

    UNION ALL

    SELECT CONCAT('S', rclnt) AS system_src, rbukrs AS company_code, racct AS acct_src_code, prctr AS src_profitcenter_code, rbusa AS bus_range_code, rtcur AS qcy_code, 'FAGLFLEXT' AS ods_src, hslvt, hsl01, hsl02, hsl03, hsl04, hsl05, hsl06, hsl07, hsl08, hsl09, hsl10, hsl11, hsl12, tslvt, tsl01, tsl02, tsl03, tsl04, tsl05, tsl06, tsl07, tsl08, tsl09, tsl10, tsl11, tsl12
      FROM ods.ods_slt_s810_faglflext
     -- 仅扫描参数财年，避免读取无关年度余额。
     WHERE ryear = @fiscal_year
       AND rclnt = '810'

    UNION ALL

    SELECT CONCAT('S', rclnt) AS system_src, rbukrs AS company_code, racct AS acct_src_code, prctr AS src_profitcenter_code, rbusa AS bus_range_code, rtcur AS qcy_code, 'FAGLFLEXT' AS ods_src, hslvt, hsl01, hsl02, hsl03, hsl04, hsl05, hsl06, hsl07, hsl08, hsl09, hsl10, hsl11, hsl12, tslvt, tsl01, tsl02, tsl03, tsl04, tsl05, tsl06, tsl07, tsl08, tsl09, tsl10, tsl11, tsl12
      FROM ods.ods_slt_s810_faglflext
     -- 仅扫描参数财年，避免读取无关年度余额。
     WHERE ryear = @fiscal_year
       AND rclnt = '610'
),
-- 计算非统驭科目本位币/交易币的期初加累计发生额。
balance_detail AS (
    SELECT g.system_src
         , CASE
               WHEN TRIM(g.company_code) = '6000' 
                 THEN CASE TRIM(g.bus_range_code)
                        WHEN '200' THEN '6000A'
                        WHEN '400' THEN '6000B'
                        WHEN '500' THEN '6000C'
                        ELSE TRIM(g.company_code)
                     END 
                 ELSE TRIM(g.company_code)
           END AS company_code
         , c.acct_type_code
         , g.acct_src_code
         , g.src_profitcenter_code
         , g.bus_range_code
         , g.qcy_code
         , g.ods_src
         , (
               IFNULL(g.hslvt, 0)
               + CASE WHEN @fiscal_month >= '01' THEN IFNULL(g.hsl01, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '02' THEN IFNULL(g.hsl02, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '03' THEN IFNULL(g.hsl03, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '04' THEN IFNULL(g.hsl04, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '05' THEN IFNULL(g.hsl05, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '06' THEN IFNULL(g.hsl06, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '07' THEN IFNULL(g.hsl07, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '08' THEN IFNULL(g.hsl08, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '09' THEN IFNULL(g.hsl09, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '10' THEN IFNULL(g.hsl10, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '11' THEN IFNULL(g.hsl11, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '12' THEN IFNULL(g.hsl12, 0) ELSE 0 END
           ) AS bcy_amt
         , (
               IFNULL(g.tslvt, 0)
               + CASE WHEN @fiscal_month >= '01' THEN IFNULL(g.tsl01, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '02' THEN IFNULL(g.tsl02, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '03' THEN IFNULL(g.tsl03, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '04' THEN IFNULL(g.tsl04, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '05' THEN IFNULL(g.tsl05, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '06' THEN IFNULL(g.tsl06, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '07' THEN IFNULL(g.tsl07, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '08' THEN IFNULL(g.tsl08, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '09' THEN IFNULL(g.tsl09, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '10' THEN IFNULL(g.tsl10, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '11' THEN IFNULL(g.tsl11, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '12' THEN IFNULL(g.tsl12, 0) ELSE 0 END
           ) AS qcy_amt
      FROM src_gl_balance g
     INNER JOIN gl_account_cfg c
        ON c.system_src = g.system_src
       AND c.company_code = g.company_code
       AND c.acct_code = g.acct_src_code
),
-- 按余额粒度汇总，并保留至少一个币种非零的余额组合。
balance_agg AS (
    SELECT system_src
         , company_code
         , acct_type_code
         , acct_src_code
         , NULLIF(LTRIM(TRIM(src_profitcenter_code), '0'), '') AS src_profitcenter_code
         , bus_range_code
         , qcy_code
         , ods_src
         , SUM(bcy_amt) AS bcy_amt
         , SUM(qcy_amt) AS qcy_amt
      FROM balance_detail
     GROUP BY system_src
            , company_code
            , acct_type_code
            , acct_src_code
            , NULLIF(LTRIM(TRIM(src_profitcenter_code), '0'), '')
            , bus_range_code
            , qcy_code
            , ods_src
     -- 仅剔除本位币和交易币同时为零的余额组合。
    HAVING SUM(bcy_amt) <> 0 OR SUM(qcy_amt) <> 0
),
-- 读取目标月份有效的账龄段配置，并准备账龄天数匹配区间。
aging_seg_cfg AS (
    SELECT r.aging_seg_code
         , r.aging_seg_name
         , CAST(r.aging_seg_fr AS DECIMALV3(27, 9)) AS aging_seg_fr
         , CAST(r.aging_seg_to AS DECIMALV3(27, 9)) AS aging_seg_to
      FROM dim.dim_rule_fi_mr_ar_aging_seg r
     WHERE NVL(r.valid_fr, '202401') <= @dt_month
       AND NVL(r.valid_to, '999999') >= @dt_month
),
-- 按目标月份筛选有效科目映射，并按原始科目和系统聚合。
acct_mapping AS (
    SELECT a.acct_src_code AS racct_src_code
         , MAX(a.acct_map_code) AS acct_map_code
         , a.system_src
      FROM dim.dim_rule_fi_mr_acct_mapping a
     WHERE NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
     GROUP BY a.acct_src_code
            , a.system_src
),
-- 聚合公司本位币配置。
company_dim AS (
    SELECT system_src
         , bukrs
         , MAX(waers) AS waers
      FROM src_t001
     GROUP BY system_src
            , bukrs
),
-- 仅保留语言为1的利润中心文本，并按系统/利润中心聚合。
profitcenter_dim AS (
    SELECT system_src
         , NULLIF(LTRIM(TRIM(prctr), '0'), '') AS prctr
         , MAX(ktext) AS ktext
      FROM src_cepct
     -- 仅使用语言代码1的利润中心文本。
     WHERE spras = '1'
     GROUP BY system_src
            , NULLIF(LTRIM(TRIM(prctr), '0'), '')
),
-- 读取第二段可用的利润中心规则；非统驭余额仅支持batch 3和batch 5。
ar_profitcenter_balance_rule AS (
    SELECT CAST(a.batch_id AS INT) AS batch_id
         , NULLIF(LTRIM(TRIM(b.cod_azienda), '0'), '') AS company_code
         , NULLIF(LTRIM(TRIM(a.acct_src_code), '0'), '') AS acct_src_code
         , MAX(a.profitcenter_code) AS profitcenter_code
         , MAX(a.profitcenter_name) AS profitcenter_name
      FROM dim.dim_rule_fi_mr_ar_profit_mapping a
      LEFT JOIN ods.odsfima_azienda b
        ON b.cod_azienda LIKE TRIM(a.company_code)
     WHERE NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
       AND CAST(a.batch_id AS INT) IN (3, 5)
     GROUP BY CAST(a.batch_id AS INT)
            , NULLIF(LTRIM(TRIM(b.cod_azienda), '0'), '')
            , NULLIF(LTRIM(TRIM(a.acct_src_code), '0'), '')
),
-- 按公司+科目匹配batch 3，未命中时按公司匹配batch 5。
profitcenter_balance_candidate AS (
    SELECT b.system_src
         , b.company_code
         , b.acct_src_code
         , b.src_profitcenter_code
         , b.bus_range_code
         , b.qcy_code
         , b.ods_src
         , r.batch_id
         , r.profitcenter_code
         , r.profitcenter_name
      FROM balance_agg b
     INNER JOIN ar_profitcenter_balance_rule r
        ON r.batch_id = 3
       AND r.company_code = NULLIF(LTRIM(TRIM(b.company_code), '0'), '')
       AND NULLIF(LTRIM(TRIM(b.acct_src_code), '0'), '') LIKE r.acct_src_code
    UNION ALL
    SELECT b.system_src
         , b.company_code
         , b.acct_src_code
         , b.src_profitcenter_code
         , b.bus_range_code
         , b.qcy_code
         , b.ods_src
         , r.batch_id
         , r.profitcenter_code
         , r.profitcenter_name
      FROM balance_agg b
     INNER JOIN ar_profitcenter_balance_rule r
        ON r.batch_id = 5
       AND r.company_code = NULLIF(LTRIM(TRIM(b.company_code), '0'), '')
),
-- 按余额粒度唯一选取利润中心，batch 3优先于batch 5且不复制余额事实。
profitcenter_balance_pick AS (
    SELECT c.system_src
         , c.company_code
         , c.acct_src_code
         , c.src_profitcenter_code
         , c.bus_range_code
         , c.qcy_code
         , c.ods_src
         , MAX(c.profitcenter_code) AS profitcenter_code
         , MAX(c.profitcenter_name) AS profitcenter_name
      FROM profitcenter_balance_candidate c
     INNER JOIN (
            SELECT system_src
                 , company_code
                 , acct_src_code
                 , src_profitcenter_code
                 , bus_range_code
                 , qcy_code
                 , ods_src
                 , MIN(batch_id) AS batch_id
              FROM profitcenter_balance_candidate
             GROUP BY system_src
                    , company_code
                    , acct_src_code
                    , src_profitcenter_code
                    , bus_range_code
                    , qcy_code
                    , ods_src
     ) p
        ON COALESCE(p.system_src, '') = COALESCE(c.system_src, '')
       AND COALESCE(p.company_code, '') = COALESCE(c.company_code, '')
       AND COALESCE(p.acct_src_code, '') = COALESCE(c.acct_src_code, '')
       AND COALESCE(p.src_profitcenter_code, '') = COALESCE(c.src_profitcenter_code, '')
       AND COALESCE(p.bus_range_code, '') = COALESCE(c.bus_range_code, '')
       AND COALESCE(p.qcy_code, '') = COALESCE(c.qcy_code, '')
       AND COALESCE(p.ods_src, '') = COALESCE(c.ods_src, '')
       AND p.batch_id = c.batch_id
     GROUP BY c.system_src
            , c.company_code
            , c.acct_src_code
            , c.src_profitcenter_code
            , c.bus_range_code
            , c.qcy_code
            , c.ods_src
)
SELECT @dt_month
     , LEFT(@dt_month, 4) AS `year`
     , RIGHT(@dt_month, 2) AS `month`
     , b.company_code AS company_code
     , NULL AS acct_cert_type
     , NULL AS acct_cert_status
     , NULL AS acct_cert_id
     , NULL AS acct_cert_item
     , NULL AS voucher_dt
     , NULL AS posting_dt
     , @key_date AS baseline_dt
     , NULL AS netrcp_dt
     , NULL AS clearing_dt
     , NULL AS cust_code
     , NULL AS cust_name
     , NULL AS cust_head_code
     , NULL AS cust_head_name
     , NULL AS cust_branch_code
     , NULL AS cust_branch_name
     , NULL AS cp_company_code
     , NULL AS country_code
     , NULL AS country_name
     , b.acct_type_code
     , b.acct_src_code
     , CASE WHEN b.system_src = 'S600' THEN b.acct_src_code ELSE am.acct_map_code END AS acct_map_code
     , NULL AS channel_l1_code
     , NULL AS channel_l1_name
     , NULL AS channel_l2_code
     , NULL AS channel_l2_name
     , NULL AS channel_l3_code
     , NULL AS channel_l3_name
     , NULL AS tov_channel_code
     , NULL AS tov_channel_name
     , NULL AS cc_cust_group_code
     , NULL AS cc_cust_group_name
     , NULL AS onoffline_code
     , NULL AS onoffline_name
     , b.src_profitcenter_code
     , COALESCE(pc.ktext, '') AS src_profitcenter_name
     , COALESCE(NULLIF(TRIM(bp.profitcenter_code), ''), b.src_profitcenter_code) AS profitcenter_code
     , COALESCE(NULLIF(TRIM(bp.profitcenter_name), ''), COALESCE(pc.ktext, '')) AS profitcenter_name
     , br.bus_range_code
     , br.bus_range_name
     , NULL AS marketing_dept_code
     , NULL AS marketing_dept_name
     , NULL AS nature_l1_name
     , NULL AS nature_l2_name
     , NULL AS nature_l3_name
     , NULL AS pay_method
     , NULL AS pay_reason_code
     , co.waers AS bcy_code
     , b.qcy_code
     , CAST(b.bcy_amt AS DECIMALV3(27, 9)) AS bcy_amt
     , CAST(b.qcy_amt AS DECIMALV3(27, 9)) AS qcy_amt
     , CAST(1 AS DECIMALV3(27, 9)) AS aging_days
     -- 账龄分段未匹配或配置值为空时，统一归入5年以上。
     , COALESCE(NULLIF(TRIM(seg.aging_seg_code), ''), '9') AS aging_seg_code
     , COALESCE(NULLIF(TRIM(seg.aging_seg_name), ''), '5年以上') AS aging_seg_name
     , NULL AS pays_tran
     , NULL AS note
     , b.system_src
     , b.ods_src
     , NOW() AS load_dt
  FROM balance_agg b
  LEFT JOIN profitcenter_balance_pick bp
    ON COALESCE(bp.system_src, '') = COALESCE(b.system_src, '')
   AND COALESCE(bp.company_code, '') = COALESCE(b.company_code, '')
   AND COALESCE(bp.acct_src_code, '') = COALESCE(b.acct_src_code, '')
   AND COALESCE(bp.src_profitcenter_code, '') = COALESCE(b.src_profitcenter_code, '')
   AND COALESCE(bp.bus_range_code, '') = COALESCE(b.bus_range_code, '')
   AND COALESCE(bp.qcy_code, '') = COALESCE(b.qcy_code, '')
   AND COALESCE(bp.ods_src, '') = COALESCE(b.ods_src, '')
  LEFT JOIN (
        SELECT TRIM(elem) AS company_code
             , MAX(CASE WHEN TRIM(node) = '01020' THEN '商显公司' ELSE '日立公司' END) AS company_scope
          FROM ods.odsfima_v_ref_azienda
         WHERE TRIM(hie) = '10' AND TRIM(node) IN ('01020', '050')
         GROUP BY TRIM(elem)
  ) cs ON cs.company_code = b.company_code
  LEFT JOIN (
        SELECT company_code, MAX(bus_range_code) AS bus_range_code, MAX(bus_range_name) AS bus_range_name
          FROM dim.dim_rule_fi_mr_ar_busrange_mapping
         WHERE CAST(batch_id AS INT) = 3
           AND NVL(valid_fr, '202401') <= @dt_month AND NVL(valid_to, '999999') >= @dt_month
         GROUP BY company_code
  ) br ON cs.company_scope IS NULL AND br.company_code = b.company_code
  LEFT JOIN aging_seg_cfg seg
    ON 1 >= seg.aging_seg_fr
   AND 1 <= seg.aging_seg_to
  LEFT JOIN acct_mapping am
    ON am.racct_src_code = b.acct_src_code
   AND am.system_src = b.system_src
  LEFT JOIN company_dim co
    ON co.system_src = b.system_src
   AND co.bukrs = b.company_code
  LEFT JOIN profitcenter_dim pc
    ON pc.system_src = b.system_src
   AND pc.prctr = b.src_profitcenter_code
;
