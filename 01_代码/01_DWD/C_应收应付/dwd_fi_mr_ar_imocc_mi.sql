/*******************************************************************************
 *                                  脚本说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261113 17:20
 * 本次修改：ALTER BY 20261113 17:20 SHIQINGFENG.EX 客商信息改取SAP客户主数据与MDG客户主数据，不再使用客户大表。
 * 上次修改：ALTER BY 20261113 17:05 SHIQINGFENG.EX 业务范围编码与名称改为按公司与国家映射表取值，国家取不到时用S810客户主数据兜底。
 *
 * 脚本名称  ：dwd_fi_mr_ar_imocc_mi.sql
 * 功能描述  ：装载国际营销应收占用明细。
 * 源表      ：详见脚本正文（区组、产品、客商、组织等DW、DIM、ODS主数据及业务数据）。
 * 目标表    ：test.dwd_fi_mr_ar_imocc_mi
 *
 * 修改历史：
 *   ALTER BY 20261113 17:20 SHIQINGFENG.EX 客商信息改取SAP客户主数据与MDG客户主数据，不再使用客户大表。
 *   ALTER BY 20261113 17:05 SHIQINGFENG.EX 业务范围编码与名称改为按公司与国家映射表取值，国家取不到时用S810客户主数据兜底。
 *   ALTER BY 20261112 16:22 SHIQINGFENG.EX 新增业务管理单元编码与名称字段，按公司及119项目客户打标。
 *   ALTER BY 20261027 18:46 SHIQINGFENG.EX 新增统一DWD脚本文件头，未修改业务主体。
 *   20261014 MODIFY 替换MDG客户主数据及对方公司映射表为客商大表
 *   20260917 ADD BY shiqingfeng.ex 新增
 ******************************************************************************/
-- 业务输入：运行月份基准日，格式YYYYMMDD，约定为参数月01日。
--SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');
SET @year_month_day = '20260801';
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);
-- 以上SET与下方INSERT OVERWRITE必须在同一session中执行。
set enable_auto_create_when_overwrite=true;

INSERT OVERWRITE TABLE test.dwd_fi_mr_ar_imocc_mi PARTITION (*)
(
      dt_month                 -- 年月
    , `year`                   -- 年份
    , `month`                  -- 月份
    , company_src_code         -- 原始组织
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
    , profitcenter_code        -- 利润中心编码
    , profitcenter_name        -- 利润中心名称
    , marketing_dept_code      -- 业务管理单元编码
    , marketing_dept_name      -- 业务管理单元名称
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
-- SAP客户主数据（S810），提供客商名称、国家及MDG客户编码。
sap_customer_dim AS (
    SELECT kunnr
         , MAX(name1) AS name1
         , MAX(land1) AS country_code
         , MAX(NULLIF(TRIM(zkunnr_mdg), '')) AS mdg_cust_code
      FROM ods.ods_slt_s810_kna1
     WHERE mandt = '810'
     GROUP BY kunnr
),
-- MDG客户主数据基本信息，提供名称、国家和公司一至三级分类。
mdg_customer_dim AS (
    SELECT cust_code AS mdg_cust_code
         , MAX(cust_name) AS cust_name
         , MAX(country_code) AS country_code
         , MAX(country_name) AS country_name
         , MAX(com_1st_code) AS com_1st_code
         , MAX(com_1st_name) AS com_1st_name
         , MAX(com_2nd_code) AS com_2nd_code
         , MAX(com_2nd_name) AS com_2nd_name
         , MAX(com_3rd_code) AS com_3rd_code
         , MAX(com_3rd_name) AS com_3rd_name
      FROM dw.dim_customer_base_info_dd
     GROUP BY cust_code
),
-- 汇总S810科目文本，SAP客户主数据未匹配时的名称兜底。
s810_account_name_dim AS (
    SELECT NULLIF(LTRIM(TRIM(saknr), '0'), '') AS cust_s810_code
         , MAX(txt20) AS name1
      FROM ods.odsslt_s810_skat
     WHERE mandt = '810'
       AND spras = '1'
     GROUP BY NULLIF(LTRIM(TRIM(saknr), '0'), '')
),
-- 汇总客户账期映射，未匹配到描述时由主查询回退为“其他”。
payment_term_dim AS (
    SELECT col_zterm AS zterm
         , MAX(col_ztermc) AS zterm_c
      FROM ods.odsmf_cm_tab1065
     GROUP BY col_zterm
),
-- 业务范围主数据，按编码取名称；国家映射表只给编码、不带名称。
bus_range_dim AS (
    SELECT dim_code AS map_bus_range_code
         , MAX(dim_name) AS map_bus_range_name
      FROM ods.odsfima_v_dim_fi_mr_bus_range
     GROUP BY dim_code
),
-- 国家业务范围映射，取参数月有效记录。
country_busrange_dim AS (
    SELECT country_code AS map_country_code
         , MAX(bus_range_code) AS map_bus_range_code
      FROM dim.dim_rule_fi_mr_ar_country_busrange_mapping
     WHERE valid_fr <= @dt_month
       AND COALESCE(valid_to, '999999') >= @dt_month
     GROUP BY country_code
),
-- 按公司映射的业务范围，作为国家匹配不到时的兜底。
company_busrange_dim AS (
    SELECT company_code AS map_company_code
         , MAX(bus_range_code) AS map_bus_range_code
         , MAX(bus_range_name) AS map_bus_range_name
      FROM dim.dim_rule_fi_mr_ar_busrange_mapping
     WHERE batch_id = '3'
       AND valid_fr <= @dt_month
       AND COALESCE(valid_to, '999999') >= @dt_month
     GROUP BY company_code
),
-- 国家编码对应中文名称。
country_name_dim AS (
    SELECT land1 AS country_code
         , MAX(landx) AS country_name
      FROM ods.odss810_t005t
     WHERE spras = '1'
     GROUP BY land1
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
         , a.bukrs AS company_src_code
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
         , COALESCE(mc.cust_name, kc.name1, s8.name1) AS cust_name
         , a.custfundcode AS cust_branch_code
         , a.custfundname AS cust_branch_name
         -- MDG主数据无对方公司字段，客户大表停用后该列暂不赋值。
         , NULL AS cp_company_code
         -- ALTER BY 20261113 17:20 SHIQINGFENG.EX 客商信息改取SAP客户主数据与MDG主数据
         , COALESCE(mc.country_code, kc.country_code) AS country_code
         , COALESCE(mc.country_name, kn.country_name) AS country_name
         , mc.com_1st_code AS channel_l1_code
         , mc.com_1st_name AS channel_l1_name
         , mc.com_2nd_code AS channel_l2_code
         , mc.com_2nd_name AS channel_l2_name
         , mc.com_3rd_code AS channel_l3_code
         , mc.com_3rd_name AS channel_l3_name
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
      LEFT JOIN sap_customer_dim kc
        ON kc.kunnr = a.kunnr
      LEFT JOIN mdg_customer_dim mc
        ON mc.mdg_cust_code = kc.mdg_cust_code
      LEFT JOIN s810_account_name_dim s8
        ON s8.cust_s810_code = NULLIF(LTRIM(TRIM(a.kunnr), '0'), '')
      LEFT JOIN country_name_dim kn
        ON kn.country_code = COALESCE(mc.country_code, kc.country_code)
      LEFT JOIN payment_term_dim pt
        ON pt.zterm = a.zterm
),
-- 按产品线与大区规则确定承接公司编码，供业务范围和业务管理单元共用。
imocc_company AS (
    SELECT e.*
         , CASE WHEN e.product_line_code = '01A0' OR e.region_flag = 'B2B业务拓展部'
                  THEN '2080'
                WHEN e.product_line_code = '0207' AND e.region_flag = '产品线大区'
                  THEN '1740'
                ELSE '8010'
           END AS company_code
      FROM imocc_enriched e
)
SELECT @dt_month AS dt_month
     , LEFT(@dt_month, 4) AS `year`
     , RIGHT(@dt_month, 2) AS `month`
     , company_src_code
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
     -- 业务范围：2080固定海外公共；1740本国用日立国内营销分公司公共，
     -- 其余国家按国家业务范围映射取值，映射不到再回退按公司映射。
     -- ALTER BY 20261113 17:05 SHIQINGFENG.EX 业务范围按公司与国家映射表取值
     , CASE WHEN company_code = '2080'
              THEN '3000'
            WHEN company_code = '1740' AND country_code = 'CN'
              THEN '2200'
            WHEN company_code = '1740'
              THEN COALESCE(cb.map_bus_range_code, bc.map_bus_range_code)
            ELSE bc.map_bus_range_code
       END AS bus_range_code
     , CASE WHEN company_code = '2080'
              THEN '海外公共'
            WHEN company_code = '1740' AND country_code = 'CN'
              THEN '日立国内营销分公司公共'
            WHEN company_code = '1740'
              THEN COALESCE(br.map_bus_range_name, bc.map_bus_range_name)
            ELSE bc.map_bus_range_name
       END AS bus_range_name
     , CASE WHEN company_code = '2080' AND cust_name LIKE '%119项目%'
              THEN 'X00000002'
            WHEN company_code = '2080'
              THEN '101008002'
            ELSE 'ZZZZ'
        END AS profitcenter_code
     , CASE WHEN company_code = '2080' AND cust_name LIKE '%119项目%'
              THEN '商显大项目'
            WHEN company_code = '2080'
              THEN '海信商用显示-触控平板-会议'
            ELSE '缺省'
        END profitcenter_name
     -- 业务管理单元：2080按119项目客户细分，其余公司（1740/8010）缺省。
     -- ALTER BY 20261112 16:22 SHIQINGFENG.EX 新增业务管理单元编码与名称
     , CASE WHEN company_code = '2080' AND cust_name LIKE '%119项目%'
              THEN 'BIPD2600.0135'
            WHEN company_code = '2080'
              THEN 'BIPD2600.0539'
            ELSE 'ZZZZ'
        END AS marketing_dept_code
     , CASE WHEN company_code = '2080' AND cust_name LIKE '%119项目%'
              THEN '商显大项目'
            WHEN company_code = '2080'
              THEN '会议产品'
            ELSE '缺省'
        END AS marketing_dept_name
     , bcy_code
     , qcy_code
     , imocc_cny_amt
     , imocc_con_amt
     , imocc_usd_amt
     , 'IMOCC' AS ods_src
     , NOW() AS load_dt
  FROM imocc_company c
  LEFT JOIN country_busrange_dim cb
    ON cb.map_country_code = c.country_code
  LEFT JOIN company_busrange_dim bc
    ON bc.map_company_code = c.company_code
  LEFT JOIN bus_range_dim br
    ON br.map_bus_range_code = cb.map_bus_range_code
  ;
