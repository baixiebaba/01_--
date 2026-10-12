/*
-- ============================================================================
-- 查询客商主数据：SAP客商编码1000077
-- 查询链路：SAP客商编码 → 客商映射表 → MDG客商编码 → 客商主数据
-- 用途：核对客户三级分类、国家、对方公司及商冷客户群等属性
-- 说明：编码匹配时去除前导零，但同时保留原始字段便于核对。
-- ============================================================================
*/

SET @cust_sap_code = '1000077';

WITH
-- 读取指定SAP客商编码的全部客户端和客商类型映射。
cust_map AS (
    SELECT TRIM(m.cust_sap_code) AS cust_sap_code_raw
         , NULLIF(LTRIM(TRIM(m.cust_sap_code), '0'), '') AS cust_sap_code
         , TRIM(m.cust_sap_client) AS cust_sap_client
         , TRIM(m.cust_supp_type) AS cust_supp_type
         , TRIM(m.cust_mdg_code) AS cust_mdg_code_raw
         , NULLIF(LTRIM(TRIM(m.cust_mdg_code), '0'), '') AS cust_mdg_code
      FROM dim.dim_fi_mr_customer_map_dd m
     WHERE NULLIF(LTRIM(TRIM(m.cust_sap_code), '0'), '') = NULLIF(LTRIM(TRIM(@cust_sap_code), '0'), '')
),
-- 通过MDG客商编码匹配统一客商主数据，并保留完整属性。
cust_master AS (
    SELECT TRIM(d.cust_code) AS cust_code_raw
         , NULLIF(LTRIM(TRIM(d.cust_code), '0'), '') AS cust_code
         , d.cust_name
         , d.cust_short_name
         , d.shop_code
         , d.shop_name
         , d.if_exc_shop
         , d.cp_company_code
         , d.cp_company_mr_code
         , d.cp_company_le_code
         , d.credit_level
         , d.unit_nature_code
         , d.unit_nature_name
         , d.cust_group_code
         , d.cust_group_name
         , d.bd_code
         , d.bd_name
         , d.bu_code
         , d.bu_name
         , d.online_code
         , d.online_name
         , d.com_1st_code
         , d.com_1st_name
         , d.com_2nd_code
         , d.com_2nd_name
         , d.com_3rd_code
         , d.com_3rd_name
         , d.cust_unity_code
         , d.cust_unity_name
         , d.cust_group_ccc_code
         , d.cust_group_ccc_name
         , d.online_channel_code
         , d.online_channel_name
         , d.ind_big_class_code
         , d.ind_big_class_name
         , d.ind_small_class_code
         , d.ind_small_class_name
         , d.channel_big_class_code
         , d.channel_big_class_name
         , d.channel_small_class_code
         , d.channel_small_class_name
         , d.is_channel_cust_type
         , d.is_fi_cust_type
         , d.country_code
         , d.country_name
         , d.load_dt
      FROM dim.dim_fi_mr_customer_dd d
),
-- 按映射关系关联统一客商主数据；没有命中时保留映射记录，便于定位断点。
result AS (
    SELECT m.cust_sap_code_raw
         , m.cust_sap_code
         , m.cust_sap_client
         , m.cust_supp_type
         , m.cust_mdg_code_raw
         , m.cust_mdg_code
         , d.cust_code_raw
         , d.cust_code
         , d.cust_name
         , d.cust_short_name
         , d.shop_code
         , d.shop_name
         , d.if_exc_shop
         , d.cp_company_code
         , d.cp_company_mr_code
         , d.cp_company_le_code
         , d.credit_level
         , d.unit_nature_code
         , d.unit_nature_name
         , d.cust_group_code
         , d.cust_group_name
         , d.bd_code
         , d.bd_name
         , d.bu_code
         , d.bu_name
         , d.online_code
         , d.online_name
         , d.com_1st_code
         , d.com_1st_name
         , d.com_2nd_code
         , d.com_2nd_name
         , d.com_3rd_code
         , d.com_3rd_name
         , d.cust_unity_code
         , d.cust_unity_name
         , d.cust_group_ccc_code
         , d.cust_group_ccc_name
         , d.online_channel_code
         , d.online_channel_name
         , d.ind_big_class_code
         , d.ind_big_class_name
         , d.ind_small_class_code
         , d.ind_small_class_name
         , d.channel_big_class_code
         , d.channel_big_class_name
         , d.channel_small_class_code
         , d.channel_small_class_name
         , d.is_channel_cust_type
         , d.is_fi_cust_type
         , d.country_code
         , d.country_name
         , d.load_dt
      FROM cust_map m
      LEFT JOIN cust_master d
        ON d.cust_code = m.cust_mdg_code
)
SELECT *
  FROM result
 ORDER BY cust_sap_client
        , cust_supp_type
        , load_dt DESC
;

-- ============================================================================
-- 可选核对：直接查询统一客商主数据中MDG客商编码的重复情况。
-- 将下方的MDG编码替换为上方查询得到的cust_mdg_code后执行。
-- ============================================================================
-- SELECT d.cust_code
--      , COUNT(*) AS row_cnt
--   FROM dim.dim_fi_mr_customer_dd d
--  WHERE NULLIF(LTRIM(TRIM(d.cust_code), '0'), '') = '<cust_mdg_code>'
--  GROUP BY d.cust_code
-- ;
