
/*
-- ============================================================================
-- 最新版修改记录： 20260917 ADD BY shiqingfeng.ex 新增
-- 上一版修改记录：
-- 目标表：国际营销应收占用明细表 dwd.dwd_fi_mr_ar_imocc_mi
-- 修改记录：最新修改记录放最上面
--   20260917 ADD BY shiqingfeng.ex 新增
-- ============================================================================
*/
-- 业务输入：运行月份基准日，格式YYYYMMDD，约定为参数月01日。
SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);
-- 以上SET与下方INSERT OVERWRITE必须在同一session中执行。
set enable_auto_create_when_overwrite=true;

INSERT OVERWRITE TABLE dwd.dwd_fi_mr_ar_imocc_mi PARTITION (*)
(
      dt_month                 -- 年月
    , `year`                   -- 年份
    , `month`                  -- 月份
    , company_code             -- 组织
    , region_code              -- 大区编码
    , region_name              -- 大区名称
    , region_flag              -- 大区标识
    , area_group_code          -- 区组编码
    , area_group_name          -- 区组名称
    , area_group_flag          -- 区组标识
    , bus_model_code           -- 业务模式
    , product_big_class_code   -- 产品大类编码
    , product_big_class_name   -- 产品大类名称
    , product_line_code        -- 产品线编码
    , product_line_name        -- 产品线名称
    , cust_pay_term            -- 客户账期编码/描述
    , data_scope_code          -- 范围
    , cust_code                -- 客商编码
    , cust_name                -- 客商名称
    , cust_branch_code         -- 分户编码
    , cust_branch_name         -- 分户名称
    , cp_company_code          -- 对方公司
    , country_code             -- 国家编码
    , country_name             -- 国家名称
    , channel_l1_code          -- 一级公司分类编码
    , channel_l1_name          -- 一级公司分类名称
    , channel_l2_code          -- 二级公司分类编码
    , channel_l2_name          -- 二级公司分类名称
    , channel_l3_code          -- 三级公司分类编码
    , channel_l3_name          -- 三级公司分类名称
    , bus_range_code           -- 业务范围编码
    , bus_range_name           -- 业务范围名称
    , src_profitcenter_code    -- 原始利润中心编码
    , src_profitcenter_name    -- 原始利润中心名称
    , profitcenter_code        -- 利润中心编码
    , profitcenter_name        -- 利润中心名称
    , bcy_code                 -- 本位币币种
    , qcy_code                 -- 交易币币种
    , imocc_cny_amt            -- 国际营销应收占用金额-人民币
    , imocc_con_amt            -- 国际营销应收占用金额-美元
    , imocc_usd_amt            -- 国际营销应收占用金额-本位币
    , ods_src                  -- 数据来源
    , load_dt                  -- 更新时间
)
WITH
-- 汇总区组主数据，按区组编码去重并提供大区、区组名称。
area_group_dim AS (
    SELECT rgn
         , rgn_zh
         , grp
         , grp_zh
      FROM dw.dwsd_im_td_bdr_area_group
     GROUP BY rgn
            , rgn_zh
            , grp
            , grp_zh
),
-- 汇总启用状态的产品线主数据，按产品线编码去重。
product_category_dim AS (
    SELECT prdln
         , prdln_zh
         , prdctgy
         , prdctgy_zh
      FROM dw.dwfi_im_td_product_category
     WHERE enable_flag = 'T'
     GROUP BY prdln
            , prdln_zh
            , prdctgy
            , prdctgy_zh
),
-- 汇总S810客户主数据，取得MDG统一客商编码。
s810_customer_dim AS (
    SELECT kunnr
         , MAX(name1) AS name1
         , MAX(zkunnr_mdg) AS zkunnr_mdg
      FROM ods.odsslt_s810_kna1
     GROUP BY kunnr
),
-- 汇总MDG客商基础信息，提供国家和一至三级公司分类。
customer_base_dim AS (
    SELECT LTRIM(cust_code, '0') AS cust_code
         , MAX(country_code) AS country_code
         , MAX(country_name) AS country_name
         , MAX(com_1st_code) AS com_1st_code
         , MAX(com_1st_name) AS com_1st_name
         , MAX(com_2nd_code) AS com_2nd_code
         , MAX(com_2nd_name) AS com_2nd_name
         , MAX(com_3rd_code) AS com_3rd_code
         , MAX(com_3rd_name) AS com_3rd_name
      FROM dw.dim_customer_base_info_dd
     GROUP BY LTRIM(cust_code, '0')
),
-- 汇总客户账期映射，未匹配到描述时由主查询回退为“其他”。
payment_term_dim AS (
    SELECT col_zterm AS zterm
         , MAX(col_ztermc) AS zterm_c
      FROM ods.odsmf_cm_tab1065
     GROUP BY col_zterm
),
-- 汇总客商对方公司映射，优先使用管理会计对方公司编码。
cp_company_dim AS (
    SELECT LTRIM(cust_code, '0') AS cust_code
         , MAX(
               COALESCE(
                   NULLIF(TRIM(cp_company_code_mr), '')
                 , TRIM(cp_company_code)
               )
           ) AS cp_company_code
      FROM dim.dim_rule_fi_mr_cust2ctp_mapping
     WHERE cust_type_code = 'C'
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY LTRIM(cust_code, '0')
),
-- 读取参数月份ACT国际营销应收占用事实，先清理三类金额均为0的垃圾数据，再按业务维度汇总金额。
imocc_source AS (
    SELECT a.month_dt
         , a.bukrs
         , a.rgn
         , a.grp
         , a.type
         , a.bus_model
         , a.prdctgy
         , a.prdln
         , a.zterm
         , a.kunnr
         , a.custfundcode
         , a.custfundname
         , a.sm
         , a.extent
         , SUM(COALESCE(a.end_amt_cny_m, 0)) AS end_amt_cny_m
         , SUM(COALESCE(a.end_amt_usd_m, 0)) AS end_amt_usd_m
         , SUM(COALESCE(a.end_amt_cod_m, 0)) AS end_amt_cod_m
      FROM ads.ads_fi_mr_accounts_rec_di a
     WHERE a.dsource = 'ACT'
       AND a.month_dt = @dt_month
     GROUP BY a.month_dt
            , a.bukrs
            , a.rgn
            , a.grp
            , a.type
            , a.bus_model
            , a.prdctgy
            , a.prdln
            , a.zterm
            , a.kunnr
            , a.custfundcode
            , a.custfundname
            , a.sm
            , a.extent
     HAVING (
              SUM(COALESCE(a.end_amt_cny_m, 0)) <> 0
           OR SUM(COALESCE(a.end_amt_usd_m, 0)) <> 0
           OR SUM(COALESCE(a.end_amt_cod_m, 0)) <> 0
       )
),
-- 补充国际营销大区、区组、产品线、账期、客商和对方公司属性。
imocc_enriched AS (
    SELECT a.month_dt
         , a.bukrs AS company_code
         , g.rgn_zh AS region_name
         , a.rgn AS region_code
         , CASE WHEN a.type = '8002' THEN '欧洲海外' ELSE g.grp_zh END AS area_group_name
         , a.grp AS area_group_code
         , CASE
               WHEN a.month_dt >= '202504'
                AND (
                       p.prdln IN ('0207', '0403', '0401', '0402')
                    OR (p.prdln = '01A0' AND g.grp <> 'D0090')
                ) THEN '产品线大区'
               WHEN a.month_dt < '202504'
                AND p.prdln IN ('0207', '01A0', '0403', '0401', '0402') THEN '产品线大区'
               WHEN (g.rgn_zh IS NULL AND p.prdln NOT IN ('0207', '01A0', '0403', '0401', '0402'))
                 OR a.type = '8002' THEN '欧洲区'
               ELSE g.rgn_zh
           END AS region_flag
         , CASE WHEN a.type = '8002' THEN '欧洲海外' ELSE g.grp_zh END AS area_group_flag
         , a.bus_model AS bus_model_code
         , a.prdctgy AS product_big_class_code
         , p.prdctgy_zh AS product_big_class_name
         , a.prdln AS product_line_code
         , p.prdln_zh AS product_line_name
         , CASE WHEN pt.zterm_c IS NULL THEN '其他' ELSE pt.zterm_c END AS cust_pay_term
         , a.extent AS data_scope_code
         , LTRIM(a.kunnr, '0') AS cust_code
         , s8.name1 AS cust_name
         , a.custfundcode AS cust_branch_code
         , a.custfundname AS cust_branch_name
         , cp.cp_company_code
         , cb.country_code
         , cb.country_name
         , cb.com_1st_code AS channel_l1_code
         , cb.com_1st_name AS channel_l1_name
         , cb.com_2nd_code AS channel_l2_code
         , cb.com_2nd_name AS channel_l2_name
         , cb.com_3rd_code AS channel_l3_code
         , cb.com_3rd_name AS channel_l3_name
         , NULL AS bus_range_code
         , NULL AS bus_range_name
         , a.prdln AS src_profitcenter_code
         , p.prdctgy_zh AS src_profitcenter_name
         , NULL AS profitcenter_code
         , NULL AS profitcenter_name
         , a.sm AS bcy_code
         , 'CNY' AS qcy_code
         , a.end_amt_cny_m AS imocc_cny_amt
         , a.end_amt_usd_m AS imocc_con_amt
         , a.end_amt_cod_m AS imocc_usd_amt
      FROM imocc_source a
      LEFT JOIN area_group_dim g
        ON g.grp = a.grp
      LEFT JOIN product_category_dim p
        ON p.prdln = a.prdln
      LEFT JOIN s810_customer_dim s8
        ON s8.kunnr = a.kunnr
      LEFT JOIN customer_base_dim cb
        ON cb.cust_code = LTRIM(s8.zkunnr_mdg, '0')
      LEFT JOIN payment_term_dim pt
        ON pt.zterm = a.zterm
      LEFT JOIN cp_company_dim cp
        ON cp.cust_code = LTRIM(a.kunnr, '0')
)
SELECT @dt_month AS dt_month
     , LEFT(@dt_month, 4) AS `year`
     , RIGHT(@dt_month, 2) AS `month`
     , company_code
     , region_code
     , region_name
     , region_flag
     , area_group_code
     , area_group_name
     , area_group_flag
     , bus_model_code
     , product_big_class_code
     , product_big_class_name
     , product_line_code
     , product_line_name
     , cust_pay_term
     , data_scope_code
     , cust_code
     , cust_name
     , cust_branch_code
     , cust_branch_name
     , cp_company_code
     , country_code
     , country_name
     , channel_l1_code
     , channel_l1_name
     , channel_l2_code
     , channel_l2_name
     , channel_l3_code
     , channel_l3_name
     , bus_range_code
     , bus_range_name
     , src_profitcenter_code
     , src_profitcenter_name
     , profitcenter_code
     , profitcenter_name
     , bcy_code
     , qcy_code
     , imocc_cny_amt
     , imocc_con_amt
     , imocc_usd_amt
     , 'ads.ads_fi_mr_accounts_rec_di' AS ods_src
     , NOW() AS load_dt
  FROM imocc_enriched

  ;
