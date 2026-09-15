
set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;
--set @year_month_day = '20260701' ;


/*****************************************************************
 alter by 20260820 xiaoyachao.ex 销售型号逻辑更新
 alter by 20260814 FENGJIANFENG.ex 新增
 alter by 20260821 shiqingfeng.ex 修改REV_CIS客商描述取客户主数据
******************************************************************/

/* 为确保目标月份分区存在，先插入一条仅含月份分区字段的数据 */
INSERT INTO dwd.dwd_fi_mr_gp_presum_mi (dt_month) VALUES (LEFT(@year_month_day, 6));

/* 销售明细-dwd_fi_mr_gp_detail_mi */
INSERT OVERWRITE TABLE dwd.dwd_fi_mr_gp_presum_mi PARTITION (*)
(
    year, month, company_code, agency_code, agency_name, cust_code, material_code, shop_code, cust_name, cust_unity_name, credit_level_name, cust_nature_name, cust_type_name, channel_l1_code, channel_l1_name, channel_l2_code,
    channel_l2_name, channel_l3_code, channel_l3_name, marketing_mode_code, marketing_mode_name, channel_big_class_code, channel_big_class_name, channel_small_class_code, channel_small_class_name, ind_big_class_code, ind_big_class_name, ind_small_class_code, ind_small_class_name, onoffline_code, onoffline_name, material_name,
    sale_model_code, sale_model_name, brand_code, brand_name, spec_section_code, spec_section_name, product_shape_type_code, product_shape_type_name, product_sale_series_code, product_sale_series_name, quarter_method_code, quarter_method_name, product_stage_code, product_stage_name, price_range_code, price_range_name,
    model_code, model_name, product_series_code, product_series_name, market_pnt_code, market_pnt_name, tech_type_code, tech_type_name, is_miniled_code, product_big_class_code, product_big_class_name, product_mid_class_code, product_mid_class_name, product_small_class_code, product_small_class_name, model_lca_code,
    model_lca_name, product_type_code, product_type_name, shop_name, bill_qty, ship_qty, order_qty, qcy_code, rev_sale_amt, rev_sale_bcy_amt, rev_rst_amt, ship_amt, order_amt, discount1_amt, discount3_amt, discount4_amt,
    discount5_amt, discount6_amt, discount34_amt, discount30_amt, cogs_amt, tax_rate, price_tax_amt, exchange_rate, system_src, ods_src, general_ledger, record_type, init_object_type, bill_cert_id, bill_cert_item, gpm_type,
    item_type, is_strategy, sold_to_code, sold_to_name, material_group_code, material_group_name, cp_company_code, batch_id, bill_dt, asap_dt, create_dt, material_pricing_group_code, material_pricing_group_name, sale_cert_id, sale_cert_item, sale_cert_type,
    reference_cert_id, reference_cert_item, acct_cert_id, ext_order_id, goods_movement_status, bill_status, acct_src_code, acct_map_code, load_dt, dt_month, bill_type_code, order_type_code, cust_mdg_code, bus_range_code, bus_range_name, marketing_dept_code,
    marketing_dept_name, comm_bu_code, comm_bu_name, cn_class_mark_code, cn_class_mark_name, profitcenter_code, customer_model, zcalasset, gfcfy_amount, gfcfl_amount, ship_fact_code, cost_center_code, cost_center_name, br_company_code, src_profitcenter_code, src_bus_range_code,
    bus_sce_cat_code, bus_sce_cat_name, transaction_type, miniled_type_code, miniled_type_name, invoice_code, bus_type_code, bus_type_name, file_archive_no, map_zum_qty, std_qty, map_qty, org_qty, segment_code, consumption_country
	,profitcenter_name,product_line_code,product_line_name
)

WITH sinking_special_material_rule AS (
    /* 下沉处理①：MODEL_TYPE=02的专供型号及其合格物料 */
    SELECT DISTINCT
        rule_data.profitcenter_code,
        rule_data.company_code,
        rule_data.cust_code,
        rule_data.sold_to_code,
        product_matnr.matnr
    FROM dim.dim_rule_fi_mr_RevenueCost_Sinking rule_data
    INNER JOIN ods.odscis_base_product_info product_info
        ON (
               INSTR(IFNULL(rule_data.supply_type, ''), 'XC01') > 0
               AND (
                      INSTR(IFNULL(product_info.product_label_name, ''), '下沉京东专供（XC01）') > 0
                   OR INSTR(IFNULL(product_info.product_label_name, ''), '下沉京东专供(XC01)') > 0
                   )
           )
        OR (
               INSTR(IFNULL(rule_data.supply_type, ''), 'XZ02') > 0
               AND (
                      INSTR(IFNULL(product_info.product_label_name, ''), '下沉-线上苏宁零售云专供（XZ02）') > 0
                   OR INSTR(IFNULL(product_info.product_label_name, ''), '下沉-线上苏宁零售云专供(XZ02)') > 0
                   )
           )
    INNER JOIN ods.odscis_base_product_info_matnr product_matnr
        ON product_info.product_id = product_matnr.product_id
    WHERE rule_data.model_type = '02'
),
source_with_onoffline_rule AS (--处理线下线下逻辑
    SELECT
        s.*,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM sinking_special_material_rule sinking_rule
                WHERE s.profitcenter_code = sinking_rule.profitcenter_code
                  AND s.company_code = sinking_rule.company_code
                  AND s.cust_code = sinking_rule.cust_code
                  AND s.material_code = sinking_rule.matnr
                  AND (
                        NULLIF(TRIM(sinking_rule.sold_to_code), '') IS NULL
                        OR COALESCE(NULLIF(TRIM(s.sold_to_code), ''), s.cust_code) = sinking_rule.sold_to_code
                      )
            ) THEN 1
            ELSE 0
        END AS is_sinking_special_model, --是否是专供型号
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM dim.dim_rule_fi_mr_RevenueCost_Sinking sinking_rule
                WHERE sinking_rule.model_type = '03'
                  /* 配置中的利润中心组按层级展开为profitcenter_code后，与明细利润中心匹配 */
                  AND s.profitcenter_code = sinking_rule.profitcenter_code
                  AND s.company_code = sinking_rule.company_code
                  AND s.cust_code = sinking_rule.cust_code
                  AND (
                        NULLIF(TRIM(sinking_rule.sold_to_code), '') IS NULL
                        OR COALESCE(NULLIF(TRIM(s.sold_to_code), ''), s.cust_code) = sinking_rule.sold_to_code
                      )
            ) THEN 1
            ELSE 0
        END AS is_sinking_independent_customer --是否是独立客户
    FROM(
        SELECT year, month, 
			CASE WHEN company_code IN ('118A','118B','1181') THEN '1180' ELSE company_code END AS company_code, 
			agency_code, agency_name,
			CASE WHEN REGEXP(LTRIM(cust_code,0), '[一-龥]') THEN NULL ELSE LTRIM(cust_code,0) END AS cust_code,
			material_code, shop_code, cust_name, cust_unity_name, credit_level_name, cust_nature_name, cust_type_name, channel_l1_code, channel_l1_name, channel_l2_code, channel_l2_name, channel_l3_code, channel_l3_name, marketing_mode_code, marketing_mode_name, channel_big_class_code, channel_big_class_name, channel_small_class_code, channel_small_class_name, ind_big_class_code, ind_big_class_name, ind_small_class_code, ind_small_class_name, onoffline_code, onoffline_name,
            material_name, sale_model_code, sale_model_name, brand_code, brand_name, spec_section_code, spec_section_name, product_shape_type_code, product_shape_type_name, product_sale_series_code, product_sale_series_name, quarter_method_code, quarter_method_name, product_stage_code, product_stage_name, price_range_code, price_range_name, model_code, model_name, product_series_code, product_series_name, market_pnt_code, market_pnt_name, 
			tech_type_code, tech_type_name, is_miniled_code, product_big_class_code, product_big_class_name, product_mid_class_code, product_mid_class_name, product_small_class_code, product_small_class_name, model_lca_code, model_lca_name, product_type_code, product_type_name, shop_name,
            bill_qty, ship_qty, order_qty, qcy_code, rev_sale_amt, rev_sale_bcy_amt, rev_rst_amt, ship_amt, order_amt, discount1_amt, discount3_amt, discount4_amt, discount5_amt, discount6_amt, discount34_amt, discount30_amt, cogs_amt, tax_rate, price_tax_amt, exchange_rate, system_src, ods_src, general_ledger, record_type, init_object_type, bill_cert_id, bill_cert_item, gpm_type, item_type, is_strategy, 
			LTRIM(sold_to_code,0) AS sold_to_code, 
			sold_to_name, material_group_code, material_group_name,
            cp_company_code, batch_id, bill_dt, asap_dt, create_dt, material_pricing_group_code, material_pricing_group_name, sale_cert_id, sale_cert_item, sale_cert_type, reference_cert_id, reference_cert_item, acct_cert_id, ext_order_id, goods_movement_status, bill_status, acct_src_code, acct_map_code, dt_month, bill_type_code, order_type_code, cust_mdg_code, bus_range_code, bus_range_name, marketing_dept_code, marketing_dept_name, comm_bu_code, comm_bu_name, cn_class_mark_code, cn_class_mark_name,
            LTRIM(profitcenter_code,0) AS profitcenter_code, 
            customer_model, zcalasset, gfcfy_amount, gfcfl_amount, ship_fact_code, cost_center_code, cost_center_name, br_company_code, src_profitcenter_code, src_bus_range_code, bus_sce_cat_code, bus_sce_cat_name, transaction_type, miniled_type_code, miniled_type_name, invoice_code, file_archive_no, profitcenter_name, product_line_code, product_line_name
        FROM dwd.dwd_fi_mr_gp_detail_mi
        WHERE dt_month = LEFT(@year_month_day, 6)
    ) s
),
channel_l3_rule AS ( --处理销售渠道三级分类
    /*
     * 执行顺序：下沉①/②产出线上线下基础值后，再计算销售渠道三级。
     * 三级渠道优先级：下沉固定客户 > 中国区电商BU映射 > SAP客户转MDG客户。
     */
    SELECT
        base_data.*,
        CASE
            WHEN base_data.sinking_onoffline_code = '020_ON_003'
             AND base_data.company_code IN ('2600', '6746', '6750', '6800', '6847')
             AND base_data.cust_code = '2031242'
            THEN 'E4'
            WHEN base_data.sinking_onoffline_code = '020_ON_003'
             AND base_data.company_code IN ('2600', '6746', '6847')
             AND base_data.cust_code = '2030797'
            THEN 'F4'
            WHEN base_data.sinking_onoffline_code = '020_ON_003'
             AND base_data.company_code IN ('2600', '6746', '6800')
             AND base_data.cust_code = '2018577'
            THEN 'F4'
            WHEN (base_data.company_code = '1180' OR base_data.company_code LIKE '12%')
             AND ecom_map.channel_code_l3 IS NOT NULL
            THEN ecom_map.channel_code_l3
            ELSE COALESCE(mdg_cust.com_3rd_code, base_data.channel_l3_code)
        END AS presum_channel_l3_code,
        CASE
            WHEN base_data.sinking_onoffline_code = '020_ON_003'
             AND base_data.company_code IN ('2600', '6746', '6750', '6800', '6847')
             AND base_data.cust_code = '2031242'
            THEN '京东专卖店'
            WHEN base_data.sinking_onoffline_code = '020_ON_003'
             AND base_data.company_code IN ('2600', '6746', '6847')
             AND base_data.cust_code = '2030797'
            THEN '苏宁零售云线上'
            WHEN base_data.sinking_onoffline_code = '020_ON_003'
             AND base_data.company_code IN ('2600', '6746', '6800')
             AND base_data.cust_code = '2018577'
            THEN '苏宁零售云线上'
            WHEN (base_data.company_code = '1180' OR base_data.company_code LIKE '12%')
             AND ecom_map.channel_code_l3 IS NOT NULL
            THEN ecom_map.channel_name_l3
            ELSE COALESCE(mdg_cust.com_3rd_name, base_data.channel_l3_name)
        END AS presum_channel_l3_name
    FROM (
        SELECT
            source_data.*,
            CASE
                WHEN source_data.is_sinking_special_model = 1
                  OR source_data.is_sinking_independent_customer = 1
                THEN '020_ON_003'
                ELSE source_data.onoffline_code
            END AS sinking_onoffline_code,
            CASE
                WHEN source_data.is_sinking_special_model = 1
                  OR source_data.is_sinking_independent_customer = 1
                THEN '下沉'
                ELSE source_data.onoffline_name
            END AS sinking_onoffline_name
        FROM source_with_onoffline_rule source_data
    ) base_data
    LEFT JOIN (
        SELECT ecom_code,MAX(channel_code_l3) AS channel_code_l3,MAX(channel_name_l3) AS channel_name_l3
        FROM dim.dim_rule_fi_mr_ecom_channel3_mapping
        GROUP BY ecom_code
    ) ecom_map
        ON (base_data.company_code = '1180' OR base_data.company_code LIKE '12%')
       AND base_data.comm_bu_code = ecom_map.ecom_code
    LEFT JOIN (
        SELECT kunnr,MAX(zkunnr_mdg) AS zkunnr_mdg
        FROM ods.ods_slt_s600_kna1
        GROUP BY kunnr
    ) sap_cust
      ON COALESCE(NULLIF(TRIM(base_data.sold_to_code), ''), base_data.cust_code) = sap_cust.kunnr
    LEFT JOIN (
        SELECT cust_code,MAX(com_3rd_code) AS com_3rd_code,MAX(com_3rd_name) AS com_3rd_name
        FROM dw.dim_customer_base_info_dd
        GROUP BY cust_code
    ) mdg_cust
        ON sap_cust.zkunnr_mdg = mdg_cust.cust_code
),
oper_type_mapping_rule AS ( --处理业务分类
    /* 先在小表范围内展开12%等公司配置，避免整月DETAIL执行动态LIKE */
    SELECT DISTINCT
        TRIM(company_data.cod_azienda) AS actual_company_code,
        TRIM(rule_data.onoffline_code) AS onoffline_code,
        TRIM(rule_data.profitcenter_code) AS profitcenter_code,
        TRIM(rule_data.ecom_code) AS ecom_code,
        TRIM(rule_data.oper_type_code) AS bus_type_code,
        rule_data.oper_type_name as bus_type_name
    FROM dim.dim_rule_fi_mr_oper_type_mapping rule_data
    INNER JOIN (
        SELECT DISTINCT cod_azienda
        FROM ods.odsfima_azienda
    ) company_data
        ON company_data.cod_azienda LIKE TRIM(rule_data.company_code)
    WHERE rule_data.valid_fr <= @year_month_day
      AND IFNULL(NULLIF(TRIM(rule_data.valid_to), ''), '999999') >= DATE_FORMAT(CAST(@year_month_day AS DATE), '%Y%m')
      AND NULLIF(TRIM(rule_data.oper_type_code), '') IS NOT NULL
      AND (
             NULLIF(TRIM(rule_data.onoffline_code), '') IS NOT NULL
          OR NULLIF(TRIM(rule_data.profitcenter_code), '') IS NOT NULL
          OR NULLIF(TRIM(rule_data.ecom_code), '') IS NOT NULL
          )
),
oper_type_rule AS ( --处理业务分类
    SELECT
        code_data.*,
        CASE
            WHEN NULLIF(TRIM(code_data.mapping_bus_type_code), '') IS NOT NULL THEN IFNULL(code_data.mapping_bus_type_name, '')
            WHEN code_data.presum_bus_type_code = 'OPTY020' THEN '中国区自营-线下分销国补业务'
            WHEN code_data.presum_bus_type_code = 'OPTY025' THEN '品线挂链'
            WHEN code_data.presum_bus_type_code = 'OPTY021' THEN '中国区自营-小B业务'
            WHEN code_data.presum_bus_type_code = 'OPTY026' THEN '中国区自营-京东超链'
            WHEN code_data.presum_bus_type_code = 'OPTY037' THEN '中国区自营-古洛尼-智能生态业务'
            WHEN code_data.presum_bus_type_code = 'OPTY038' THEN '中国区自营-古洛尼-赠品业务'
            WHEN code_data.presum_bus_type_code = 'OPTY041' THEN '中国区自营-会员店'
            WHEN code_data.presum_bus_type_code = 'OPTY039' THEN '中国区自营-费用转成本'
            WHEN code_data.presum_bus_type_code = 'OPTY040' THEN '中国区自营-品线挂链费用转成本'
            ELSE ''
        END AS presum_bus_type_name
    FROM (
        SELECT
            channel_data.*,
            COALESCE(
                NULLIF(TRIM(map_onoffline.bus_type_code), ''),
                NULLIF(TRIM(map_profitcenter.bus_type_code), ''),
                NULLIF(TRIM(map_ecom.bus_type_code), '')
            ) AS mapping_bus_type_code,
            CASE
                WHEN NULLIF(TRIM(map_onoffline.bus_type_code), '') IS NOT NULL THEN IFNULL(map_onoffline.bus_type_name, '')
                WHEN NULLIF(TRIM(map_profitcenter.bus_type_code), '') IS NOT NULL THEN IFNULL(map_profitcenter.bus_type_name, '')
                WHEN NULLIF(TRIM(map_ecom.bus_type_code), '') IS NOT NULL THEN IFNULL(map_ecom.bus_type_name, '')
                ELSE ''
            END AS mapping_bus_type_name,
            CASE
                /* ⑤ 其他业务配置，最高优先级 */
                WHEN COALESCE(
                         NULLIF(TRIM(map_onoffline.bus_type_code), ''),
                         NULLIF(TRIM(map_profitcenter.bus_type_code), ''),
                         NULLIF(TRIM(map_ecom.bus_type_code), '')
                     ) IS NOT NULL
                    THEN COALESCE(
                         NULLIF(TRIM(map_onoffline.bus_type_code), ''),
                         NULLIF(TRIM(map_profitcenter.bus_type_code), ''),
                         NULLIF(TRIM(map_ecom.bus_type_code), '')
                     )
                /* ⑧ 费用转政策：必须先于通用Z2品线挂链 */
                WHEN (channel_data.company_code = '1180' OR channel_data.company_code LIKE '12%')
                 AND channel_data.bus_sce_cat_code = '026'
                 AND channel_data.acct_map_code LIKE '6401%'
                 AND channel_data.cn_class_mark_code = 'Z1'
                    THEN 'OPTY039'
                WHEN (channel_data.company_code = '1180' OR channel_data.company_code LIKE '12%')
                 AND channel_data.bus_sce_cat_code = '026'
                 AND channel_data.acct_map_code LIKE '6401%'
                 AND channel_data.cn_class_mark_code = 'Z2'
                    THEN 'OPTY040'
                /* ① 线下分销国补 */
                WHEN channel_data.company_code LIKE '12%'
                 AND channel_data.agency_code = '120B'
                 AND channel_data.cust_code = '2040200'
                 AND IFNULL(channel_data.ods_src, '') NOT LIKE 'ZTSO04_CK%'
                 AND IFNULL(channel_data.ods_src, '') NOT LIKE 'ZTSO04_TH%'
                    THEN 'OPTY020'
                /* ④ 京东超链 */
                WHEN channel_data.ods_src = 'VBRP'
                 AND channel_data.company_code = '1180'
                 AND channel_data.cp_company_code LIKE '12%'
                    THEN 'OPTY026'
                /* ⑥ 古洛尼相关 */
                 WHEN /*(channel_data.company_code = '1180' OR channel_data.company_code LIKE '12%')
				AND */ channel_data.agency_code = 'G055' THEN 'OPTY037'
                 WHEN /*(channel_data.company_code = '1180' OR channel_data.company_code LIKE '12%')
                 AND */ channel_data.agency_code = 'G056' THEN 'OPTY038'
                /* ⑦ 会员店（品质之家门店） */
                WHEN (channel_data.company_code = '1180' OR channel_data.company_code LIKE '12%')
                 AND channel_data.shop_code IN ('15295336542', 'DP118005162', 'DP118005033')
                    THEN 'OPTY041'
                /* ② 品线挂链 */
                WHEN (channel_data.company_code = '1180' OR channel_data.company_code LIKE '12%')
                 AND channel_data.cn_class_mark_code = 'Z2'
                 AND IFNULL(channel_data.ods_src, '') NOT LIKE 'ZTSO04_CK%'
                 AND IFNULL(channel_data.ods_src, '') NOT LIKE 'ZTSO04_TH%'
                    THEN 'OPTY025'
                /* ③ 小B业务 */
                WHEN channel_data.company_code LIKE '12%'
                 AND channel_data.sale_cert_type IN ('ZORC', 'ZREC')
                 AND IFNULL(channel_data.ods_src, '') NOT LIKE 'ZTSO04_CK%'
                 AND IFNULL(channel_data.ods_src, '') NOT LIKE 'ZTSO04_TH%'
                    THEN 'OPTY021'
                ELSE ''
            END AS presum_bus_type_code
        FROM channel_l3_rule channel_data
        LEFT JOIN (
            SELECT DISTINCT actual_company_code,onoffline_code,bus_type_code,bus_type_name
            FROM oper_type_mapping_rule
            WHERE NULLIF(onoffline_code, '') IS NOT NULL
        ) map_onoffline
            ON channel_data.company_code = map_onoffline.actual_company_code
           AND channel_data.sinking_onoffline_code = map_onoffline.onoffline_code
        LEFT JOIN (
            SELECT DISTINCT actual_company_code,profitcenter_code,bus_type_code,bus_type_name
            FROM oper_type_mapping_rule
            WHERE NULLIF(profitcenter_code, '') IS NOT NULL
        ) map_profitcenter
            ON channel_data.company_code = map_profitcenter.actual_company_code
           AND channel_data.profitcenter_code = map_profitcenter.profitcenter_code
        LEFT JOIN (
            SELECT DISTINCT actual_company_code,ecom_code,bus_type_code,bus_type_name
            FROM oper_type_mapping_rule
            WHERE NULLIF(ecom_code, '') IS NOT NULL
        ) map_ecom
            ON channel_data.company_code = map_ecom.actual_company_code
           AND channel_data.comm_bu_code = map_ecom.ecom_code
    ) code_data
)

SELECT
    s.year, -- 财务年
    s.month, -- 财务月
    s.company_code, -- 组织
    s.agency_code, -- 办事处编码
    s.agency_name, -- 办事处名称
    s.cust_code, -- 客商编码
    s.material_code, -- 物料编码
    s.shop_code, -- 门店编码
    s.cust_name, -- 客商名称
    s.cust_unity_name, -- 统一客户组
    s.credit_level_name, -- 信用等级
    s.cust_nature_name, -- 单位性质
    s.cust_type_name, -- 客户类型
    s.channel_l1_code, -- 销售渠道一级编码
    s.channel_l1_name, -- 销售渠道一级名称
    s.channel_l2_code, -- 销售渠道二级编码
    s.channel_l2_name, -- 销售渠道二级名称
    s.presum_channel_l3_code AS channel_l3_code, -- 销售渠道三级编码
    s.presum_channel_l3_name AS channel_l3_name, -- 销售渠道三级名称
    s.marketing_mode_code, -- 销售模式编码
    s.marketing_mode_name, -- 销售模式名称
    s.channel_big_class_code, -- 渠道客户大类编码
    s.channel_big_class_name, -- 渠道客户大类名称
    s.channel_small_class_code, -- 渠道客户小类编码
    s.channel_small_class_name, -- 渠道客户小类名称
    s.ind_big_class_code, -- 行业大类编码
    s.ind_big_class_name, -- 行业大类名称
    s.ind_small_class_code, -- 行业小类编码
    s.ind_small_class_name, -- 行业小类名称
    CASE WHEN s.sinking_onoffline_code = '020_ON_003' THEN s.sinking_onoffline_code
        WHEN s.presum_channel_l3_code = 'G3' THEN '020_OFF_002'
        WHEN s.presum_bus_type_code IN ('OPTY037', 'OPTY038', 'OPTY021') THEN '020_OFF_002'
        ELSE s.sinking_onoffline_code
    END AS onoffline_code, -- 线上线下编码
    CASE WHEN s.sinking_onoffline_code = '020_ON_003' THEN s.sinking_onoffline_name
        WHEN s.presum_channel_l3_code = 'G3' THEN '零售-传统零售'
        WHEN s.presum_bus_type_code IN ('OPTY037', 'OPTY038', 'OPTY021') THEN '零售-传统零售'
        ELSE s.sinking_onoffline_name
    END AS onoffline_name, -- 线上线下名称
    s.material_name, -- 物料名称
    s.sale_model_code, -- 销售型号编码
    s.sale_model_name, -- 销售型号名称
    s.brand_code, -- 品牌编码
    s.brand_name, -- 品牌名称
    s.spec_section_code, -- 规格段编码
    s.spec_section_name, -- 规格段名称
    s.product_shape_type_code, -- 产品形态分类编码
    s.product_shape_type_name, -- 产品形态分类名称
    s.product_sale_series_code, -- 产品套系编码
    s.product_sale_series_name, -- 产品套系名称
    s.quarter_method_code, -- 四分法编码（市场口径）
    s.quarter_method_name, -- 四分法名称（市场口径）
    s.product_stage_code, -- 产品阶段编码
    s.product_stage_name, -- 产品阶段名称
    s.price_range_code, -- 价格段编码
    s.price_range_name, -- 价格段名称
    s.model_code, -- 产品型号编码
    s.model_name, -- 产品型号名称
    s.product_series_code, -- 产品系列编码
    s.product_series_name, -- 产品系列名称
    s.market_pnt_code, -- 营销定位编码
    s.market_pnt_name, -- 营销定位名称
    s.tech_type_code, -- 技术类型编码
    s.tech_type_name, -- 技术类型名称
    s.is_miniled_code, -- 是否MiniLED编码
    s.product_big_class_code, -- 产品大类编码
    s.product_big_class_name, -- 产品大类名称
    s.product_mid_class_code, -- 产品中类编码
    s.product_mid_class_name, -- 产品中类名称
    s.product_small_class_code, -- 产品小类编码
    s.product_small_class_name, -- 产品小类名称
    s.model_lca_code, -- 产品型号生命周期编码
    s.model_lca_name, -- 产品型号生命周期名称
    s.product_type_code, -- 产品类型编码
    s.product_type_name, -- 产品类型名称
    s.shop_name, -- 门店名称
    s.bill_qty, -- 开票销量
    s.ship_qty, -- 发货数量
    s.order_qty, -- 订单数量
    s.qcy_code, -- 货币-交易币
    s.rev_sale_amt, -- 销售收入
    s.rev_sale_bcy_amt, -- 销售收入-本位币
    s.rev_rst_amt, -- 还原后收入
    s.ship_amt, -- 发货金额
    s.order_amt, -- 订单金额
    s.discount1_amt, -- 折扣1
    s.discount3_amt, -- 折扣3
    s.discount4_amt, -- 折扣4
    s.discount5_amt, -- 折扣5
    s.discount6_amt, -- 折扣6
    s.discount34_amt, -- 折扣34
    s.discount30_amt, -- 折扣30
    s.cogs_amt, -- 销售成本
    s.tax_rate, -- 税率
    s.price_tax_amt, -- 含税单价
    s.exchange_rate, -- 汇率
    s.system_src, -- 源系统
    s.ods_src, -- 源表
    s.general_ledger, -- 总账标识
    s.record_type, -- 记录类型
    s.init_object_type, -- 初始对象类型
    s.bill_cert_id, -- 开票凭证号
    s.bill_cert_item, -- 开票凭证行项目
    s.gpm_type, -- GPM类型
    s.item_type, -- 项目分类
    s.is_strategy, -- 是否战略项目
    s.sold_to_code, -- 售达方编码
    s.sold_to_name, -- 售达方名称
    s.material_group_code, -- 物料组编码
    s.material_group_name, -- 物料组名称
    s.cp_company_code, -- 对方公司编码
    s.batch_id, -- 批次号
    s.bill_dt, -- 发票日期
    s.asap_dt, -- ASAP日期
    s.create_dt, -- 创建日期
    s.material_pricing_group_code, -- 物料定价组编码
    s.material_pricing_group_name, -- 物料定价组名称
    s.sale_cert_id, -- 销售凭证号
    s.sale_cert_item, -- 销售凭证行项目
    s.sale_cert_type, -- 销售凭证类型
    s.reference_cert_id, -- 参考单据编号
    s.reference_cert_item, -- 参考单据项目号
    s.acct_cert_id, -- 会计凭证号
    s.ext_order_id, -- 外部订单号
    s.goods_movement_status, -- 货物移动状态
    s.bill_status, -- 单据状态
    s.acct_src_code, -- 原始科目编码
    s.acct_map_code, -- 映射后科目编码
    NOW() AS load_dt, -- 数据加载时间
    s.dt_month, -- 年月分区
    s.bill_type_code, -- 开票类型
    s.order_type_code, -- 订单类型
    s.cust_mdg_code, -- 客商MDG编码
    s.bus_range_code, -- 业务范围编码
    s.bus_range_name, -- 业务范围名称
    s.marketing_dept_code, -- 所属营销部门编码（业务管理单元编码）
    s.marketing_dept_name, -- 所属营销部门描述（业务管理单元描述）
    s.comm_bu_code, -- 电商BU渠道细分编码
    s.comm_bu_name, -- 电商BU渠道细分描述
    s.cn_class_mark_code, -- 中国区品类标记编码
    s.cn_class_mark_name, -- 中国区品类标记描述
    s.profitcenter_code, -- 利润中心编码
    s.customer_model, -- 客户型号
    s.zcalasset, -- 按套统计
    s.gfcfy_amount, -- 价差转费用
    s.gfcfl_amount, -- 费用转价差
    s.ship_fact_code, -- 发货工厂编码
    s.cost_center_code, -- 成本中心编码
    s.cost_center_name, -- 成本中心名称
    s.br_company_code, -- BR公司编码
    s.src_profitcenter_code, -- 源利润中心编码
    s.src_bus_range_code, -- 源业务范围编码
    s.bus_sce_cat_code, -- 业务场景分类编码
    s.bus_sce_cat_name, -- 业务场景分类描述
    s.transaction_type, -- 事务类型
    s.miniled_type_code, -- MiniLED类型编码
    s.miniled_type_name, -- MiniLED类型名称
    s.invoice_code, -- 金税发票号
    s.presum_bus_type_code AS bus_type_code, -- 业务分类编码
    s.presum_bus_type_name AS bus_type_name, -- 业务分类名称
    s.file_archive_no, -- 落户纸号
    CASE
        WHEN s.ods_src = 'ZTSO04_CK'
        THEN (IFNULL(s.ship_qty, 0) - IFNULL(s.bill_qty, 0)) * IFNULL(product_qty.sale_qty, 1)
        ELSE IFNULL(s.bill_qty, 0) * IFNULL(product_qty.sale_qty, 1)
    END AS map_zum_qty, -- 折算销量-指标口径
    CASE
        WHEN s.ods_src = 'ZTSO04_CK'
        THEN (IFNULL(s.ship_qty, 0) - IFNULL(s.bill_qty, 0)) * IFNULL(product_qty.sale_std_qty, 0)
        ELSE IFNULL(s.bill_qty, 0) * IFNULL(product_qty.sale_std_qty, 0)
    END AS std_qty, -- 折算销量-标准量
    0 AS map_qty, -- 映射后销量，已按规则固定0
    0 AS org_qty, -- 原始销量，已按规则固定0
    '' AS segment_code, -- 区组编码，转换规则待处理
    '' AS consumption_country, -- 消费国家，转换规则待处理
    s.profitcenter_name, -- 利润中心名称
    s.product_line_code, -- 产品线编码
    s.product_line_name -- 产品线名称
FROM oper_type_rule s
LEFT JOIN dim.dim_fi_mr_product_dd product_qty --物料大表
    ON s.material_code = product_qty.matnr
;






/* CIS提货明细 dwd_fi_mr_rev_cis_mi */
INSERT INTO dwd.dwd_fi_mr_gp_presum_mi
(
    year, month, company_code, agency_code, agency_name, cust_code, material_code, shop_code, cust_name, cust_unity_name, credit_level_name, cust_nature_name, cust_type_name, channel_l1_code, channel_l1_name, channel_l2_code,
    channel_l2_name, channel_l3_code, channel_l3_name, marketing_mode_code, marketing_mode_name, channel_big_class_code, channel_big_class_name, channel_small_class_code, channel_small_class_name, ind_big_class_code, ind_big_class_name, ind_small_class_code, ind_small_class_name, onoffline_code, onoffline_name, material_name,
    sale_model_code, sale_model_name, brand_code, brand_name, spec_section_code, spec_section_name, product_shape_type_code, product_shape_type_name, product_sale_series_code, product_sale_series_name, quarter_method_code, quarter_method_name, product_stage_code, product_stage_name, price_range_code, price_range_name,
    model_code, model_name, product_series_code, product_series_name, market_pnt_code, market_pnt_name, tech_type_code, tech_type_name, is_miniled_code, product_big_class_code, product_big_class_name, product_mid_class_code, product_mid_class_name, product_small_class_code, product_small_class_name, model_lca_code,
    model_lca_name, product_type_code, product_type_name, shop_name, bill_qty, ship_qty, order_qty, qcy_code, rev_sale_amt, rev_sale_bcy_amt, rev_rst_amt, ship_amt, order_amt, discount1_amt, discount3_amt, discount4_amt,
    discount5_amt, discount6_amt, discount34_amt, discount30_amt, cogs_amt, tax_rate, price_tax_amt, exchange_rate, system_src, ods_src, general_ledger, record_type, init_object_type, bill_cert_id, bill_cert_item, gpm_type,
    item_type, is_strategy, sold_to_code, sold_to_name, material_group_code, material_group_name, cp_company_code, batch_id, bill_dt, asap_dt, create_dt, material_pricing_group_code, material_pricing_group_name, sale_cert_id, sale_cert_item, sale_cert_type,
    reference_cert_id, reference_cert_item, acct_cert_id, ext_order_id, goods_movement_status, bill_status, acct_src_code, acct_map_code, load_dt, dt_month, bill_type_code, order_type_code, cust_mdg_code, bus_range_code, bus_range_name, marketing_dept_code,
    marketing_dept_name, comm_bu_code, comm_bu_name, cn_class_mark_code, cn_class_mark_name, profitcenter_code, customer_model, zcalasset, gfcfy_amount, gfcfl_amount, ship_fact_code, cost_center_code, cost_center_name, br_company_code, src_profitcenter_code, src_bus_range_code,
    bus_sce_cat_code, bus_sce_cat_name, transaction_type, miniled_type_code, miniled_type_name, invoice_code, bus_type_code, bus_type_name, file_archive_no, map_zum_qty, std_qty, map_qty, org_qty, segment_code, consumption_country
	
)
SELECT
    s.year, -- 财务年
    s.month, -- 财务月
    s.company_code, -- 组织
    '' AS agency_code, -- 办事处编码
    '' AS agency_name, -- 办事处名称
    s.cust_code, -- 客商编码
    s.material_code, -- 物料编码
    '' AS shop_code, -- 门店编码
    /*20260821 shiqingfeng.ex 修改REV_CIS客商描述取客户主数据*/
    kna1.name1 AS cust_name, -- 客商名称
    cust_data.cust_unity_name, -- 统一客户组
    cust_data.credit_level AS credit_level_name, -- 信用等级
    cust_data.unit_nature_name AS cust_nature_name, -- 单位性质
    CASE
        WHEN cust_data.is_channel_cust_type IS NULL AND cust_data.is_ent_cust_type IS NULL AND cust_data.is_fi_cust_type IS NULL THEN NULL
        ELSE TRIM(
            REGEXP_REPLACE(
                CONCAT_WS(',',
                    CASE WHEN cust_data.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                    CASE WHEN cust_data.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                    CASE WHEN cust_data.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                ),'(^,)|(,$)',''
            )
        )
    END AS cust_type_name, -- 客户类型
    cust_data.com_1st_code AS channel_l1_code, -- 销售渠道一级编码
    cust_data.com_1st_name AS channel_l1_name, -- 销售渠道一级名称
    cust_data.com_2nd_code AS channel_l2_code, -- 销售渠道二级编码
    cust_data.com_2nd_name AS channel_l2_name, -- 销售渠道二级名称
    CASE
        WHEN s.cis_onoffline_code = '020_ON_003'
         AND s.company_code IN ('2600', '6746', '6750', '6800', '6847')
         AND s.cust_code = '2031242'
        THEN 'E4'
        WHEN s.cis_onoffline_code = '020_ON_003'
         AND s.company_code IN ('2600', '6746', '6847')
         AND s.cust_code = '2030797'
        THEN 'F4'
        WHEN s.cis_onoffline_code = '020_ON_003'
         AND s.company_code IN ('2600', '6746', '6800')
         AND s.cust_code = '2018577'
        THEN 'F4'
        ELSE cust_data.com_3rd_code
    END AS channel_l3_code, -- 销售渠道三级编码
    CASE
        WHEN s.cis_onoffline_code = '020_ON_003'
         AND s.company_code IN ('2600', '6746', '6750', '6800', '6847')
         AND s.cust_code = '2031242'
        THEN '京东专卖店'
        WHEN s.cis_onoffline_code = '020_ON_003'
         AND s.company_code IN ('2600', '6746', '6847')
         AND s.cust_code = '2030797'
        THEN '苏宁零售云线上'
        WHEN s.cis_onoffline_code = '020_ON_003'
         AND s.company_code IN ('2600', '6746', '6800')
         AND s.cust_code = '2018577'
        THEN '苏宁零售云线上'
        ELSE cust_data.com_3rd_name
    END AS channel_l3_name, -- 销售渠道三级名称
    cust_trade.market_mode_code AS marketing_mode_code, -- 销售模式编码
    cust_trade.market_mode_name AS marketing_mode_name, -- 销售模式名称
    cust_data.channel_big_class_code, -- 渠道客户大类编码
    cust_data.channel_big_class_name, -- 渠道客户大类名称
    cust_data.channel_small_class_code, -- 渠道客户小类编码
    cust_data.channel_small_class_name, -- 渠道客户小类名称
    cust_data.ind_big_class_code, -- 行业大类编码
    cust_data.ind_big_class_name, -- 行业大类名称
    cust_data.ind_small_class_code, -- 行业小类编码
    cust_data.ind_small_class_name, -- 行业小类名称
    s.cis_onoffline_code AS onoffline_code, -- 线上线下编码
    s.cis_onoffline_name AS onoffline_name, -- 线上线下名称
    product_data.product_name AS material_name, -- 物料名称
    COALESCE(
        NULLIF(TRIM(product_data.zzprdmodel), ''),
        NULLIF(TRIM(product_data.zfacmodel), ''),
        NULLIF(TRIM(product_data.pmodel_number), '')
    ) AS sale_model_code, -- 销售型号编码
    -- '' AS sale_model_name, -- 销售型号名称
    /*alter by 20260820 xiaoyachao.ex 销售型号逻辑更新*/
    COALESCE(IF(TRIM(product_data.sale_model_name) IN ('0', '无', ''),NULL,TRIM(product_data.sale_model_name))
              ,IF(TRIM(product_data.zzprdmodel)= '',NULL,TRIM(product_data.zzprdmodel))
              ,IF(TRIM(product_data.zfacmodel)= '',NULL,TRIM(product_data.zfacmodel))
              ,IF(TRIM(product_data.pmodel_number)= '',NULL,TRIM(product_data.pmodel_number))
              ) AS	sale_model_name	,	--	销售型号名称
    s.brand_code, -- 品牌编码
    s.brand_name, -- 品牌名称
    CASE
        WHEN product_data.big_class_code = 'P01' THEN product_data.screen_size_code
        WHEN product_data.big_class_code = 'P02' THEN product_data.spec_range_code
        WHEN product_data.big_class_code = 'P03' THEN product_data.total_capacity_code
        WHEN product_data.big_class_code = 'P04' THEN product_data.washing_capacity_code
    END AS spec_section_code, -- 规格段编码
    CASE
        WHEN product_data.big_class_code = 'P01' THEN product_data.screen_size_name
        WHEN product_data.big_class_code = 'P02' THEN product_data.spec_range_name
        WHEN product_data.big_class_code = 'P03' THEN product_data.total_capacity_name
        WHEN product_data.big_class_code = 'P04' THEN product_data.washing_capacity_name
    END AS spec_section_name, -- 规格段名称
    product_data.product_spec_code AS product_shape_type_code, -- 产品形态分类编码
    product_data.product_spec_name AS product_shape_type_name, -- 产品形态分类名称
    product_data.prod_suite_code AS product_sale_series_code, -- 产品套系编码
    product_data.prod_suite_name AS product_sale_series_name, -- 产品套系名称
    '' AS quarter_method_code, -- 四分法编码
    '' AS quarter_method_name, -- 四分法名称
    product_data.prod_stage_code AS product_stage_code, -- 产品阶段编码
    product_data.prod_stage_name AS product_stage_name, -- 产品阶段名称
    product_data.price_range_code AS price_range_code, -- 价格段编码
    product_data.price_range_name AS price_range_name, -- 价格段名称
    product_data.model_code AS model_code, -- 产品型号编码
    product_data.model_name AS model_name, -- 产品型号名称
    product_data.series_code AS product_series_code, -- 产品系列编码
    product_data.series_name AS product_series_name, -- 产品系列名称
    product_data.market_pos_code AS market_pnt_code, -- 营销定位编码
    product_data.market_pos_name AS market_pnt_name, -- 营销定位名称
    product_data.ac_ct_code AS tech_type_code, -- 技术类型编码
    product_data.ac_ct_name AS tech_type_name, -- 技术类型名称
    CASE
        WHEN product_data.is_miniled_code = 'PC00013001' THEN '是'
        WHEN product_data.is_miniled_code = 'PC00013002' THEN '否'
        ELSE ''
    END AS is_miniled_code, -- 是否MiniLED编码
    product_data.big_class_code AS product_big_class_code, -- 产品大类编码
    product_data.big_class_name AS product_big_class_name, -- 产品大类名称
    product_data.middle_class_code AS product_mid_class_code, -- 产品中类编码
    product_data.middle_class_name AS product_mid_class_name, -- 产品中类名称
    product_data.small_class_code AS product_small_class_code, -- 产品小类编码
    product_data.small_class_name AS product_small_class_name, -- 产品小类名称
    product_data.model_lca AS model_lca_code, -- 产品型号生命周期编码
    product_data.model_lca_name AS model_lca_name, -- 产品型号生命周期名称
    '' AS product_type_code, -- 产品类型编码
    '' AS product_type_name, -- 产品类型名称
    s.store_cis_name AS shop_name, -- 门店名称
    s.sales_qty * s.amount_sign AS bill_qty, -- 开票销量
    s.sales_qty * s.amount_sign AS ship_qty, -- 发货数量
    s.sales_qty * s.amount_sign AS order_qty, -- 订单数量
    'CNY' AS qcy_code, -- 货币-交易币
    s.rev_sale_amt * s.amount_sign / 1.13 AS rev_sale_amt, -- 销售收入，不含税
    s.rev_sale_amt * s.amount_sign / 1.13 AS rev_sale_bcy_amt, -- 销售收入-本位币，CIS币种固定为CNY
    0 AS rev_rst_amt, -- 还原后收入
    0 AS ship_amt, -- 发货金额
    0 AS order_amt, -- 订单金额
    0 AS discount1_amt, -- 折扣1
    0 AS discount3_amt, -- 折扣3
    0 AS discount4_amt, -- 折扣4
    0 AS discount5_amt, -- 折扣5
    0 AS discount6_amt, -- 折扣6
    0 AS discount34_amt, -- 折扣34
    0 AS discount30_amt, -- 折扣30
    0 AS cogs_amt, -- 销售成本
    0 AS tax_rate, -- 税率
    s.standard_price_amt AS price_tax_amt, -- 含税单价
    0 AS exchange_rate, -- 汇率
    'CIS' AS system_src, -- 源系统
    'REV_CIS' AS ods_src, -- 源表
    '' AS general_ledger, -- 分类账
    '' AS record_type, -- 记录类型
    '' AS init_object_type, -- 初始对象类型
    '' AS bill_cert_id, -- 开票凭证号
    0 AS bill_cert_item, -- 开票凭证行项目
    '' AS gpm_type, -- GPM类型
    '' AS item_type, -- 项目分类
    '' AS is_strategy, -- 是否战略项目
    '' AS sold_to_code, -- 售达方编码
    '' AS sold_to_name, -- 售达方名称
    s.material_group_code, -- 物料组编码
    s.material_group_name, -- 物料组名称
    COALESCE(
        NULLIF(TRIM(cust2ctp.cp_company_code_mr), ''),
        cust2ctp.cp_company_code
    ) AS cp_company_code, -- 对方公司编码
    '' AS batch_id, -- 批次号
    CAST(NULL AS DATE) AS bill_dt, -- 发票日期
    CAST(NULL AS DATE) AS asap_dt, -- ASAP日期
    s.create_dt, -- 创建日期
    s.material_pricing_group_code, -- 物料定价组编码
    '' AS material_pricing_group_name, -- 物料定价组名称
    '' AS sale_cert_id, -- 销售凭证号
    0 AS sale_cert_item, -- 销售凭证行项目
    '' AS sale_cert_type, -- 销售凭证类型
    '' AS reference_cert_id, -- 参考单据编号
    0 AS reference_cert_item, -- 参考单据项目号
    '' AS acct_cert_id, -- 会计凭证号
    '' AS ext_order_id, -- 外部订单号
    '' AS goods_movement_status, -- 货物移动状态
    '' AS bill_status, -- 单据状态
    '6001000000' AS acct_src_code, -- 原始科目编码
    '6001000000' AS acct_map_code, -- 映射后科目编码
    NOW() AS load_dt, -- 数据加载时间
    s.dt_month, -- 年月分区
    '' AS bill_type_code, -- 开票类型
    '' AS order_type_code, -- 订单类型
    '' AS cust_mdg_code, -- 客商MDG编码
    s.bus_range_code, -- 业务范围编码
    s.bus_range_name, -- 业务范围名称
    '' AS marketing_dept_code, -- 所属营销部门编码
    '' AS marketing_dept_name, -- 所属营销部门描述
    '' AS comm_bu_code, -- 电商BU渠道细分编码
    '' AS comm_bu_name, -- 电商BU渠道细分描述
    '' AS cn_class_mark_code, -- 中国区品类标记编码
    '' AS cn_class_mark_name, -- 中国区品类标记描述
    s.profitcenter_code, -- 利润中心编码
    COALESCE(
        IF(UPPER(product_data.sale_model_name) = '无', NULL, UPPER(product_data.sale_model_name)),
        IF(UPPER(product_data.zcusmodel) = '无', NULL, UPPER(product_data.zcusmodel))
    ) AS customer_model, -- 客户型号
    product_data.zcalasset AS zcalasset, -- 按套统计
    0 AS gfcfy_amount, -- 价差转费用
    0 AS gfcfl_amount, -- 费用转价差
    '' AS ship_fact_code, -- 发货工厂编码
    '' AS cost_center_code, -- 成本中心编码
    '' AS cost_center_name, -- 成本中心名称
    '' AS br_company_code, -- BR公司编码
    '' AS src_profitcenter_code, -- 源利润中心编码
    '' AS src_bus_range_code, -- 源业务范围编码
    '' AS bus_sce_cat_code, -- 业务场景分类编码
    '' AS bus_sce_cat_name, -- 业务场景分类描述
    '' AS transaction_type, -- 事务类型
    s.miniled_type_code, -- MiniLED类型编码
    s.miniled_type_name, -- MiniLED类型名称
    '' AS invoice_code, -- 金税发票号
    '' AS bus_type_code, -- 业务分类编码
    '' AS bus_type_name, -- 业务分类名称
    '' AS file_archive_no, -- 落户纸号
    IFNULL(s.sales_qty, 0) * s.amount_sign * IFNULL(product_data.sale_qty, 1) AS map_zum_qty, -- 折算销量-指标口径
    IFNULL(s.sales_qty, 0) * s.amount_sign * IFNULL(product_data.sale_std_qty, 0) AS std_qty, -- 折算销量-标准量
    0 AS map_qty, -- 映射后销量，CIS固定0
    0 AS org_qty, -- 原始销量，CIS固定0
    '' AS segment_code, -- 区组编码，转换规则待处理
    '' AS consumption_country -- 消费国家，转换规则待处理
FROM (
    SELECT
        cis_data.*,
        sign_data.amount_sign,
        sign_data.cis_onoffline_code,
        sign_data.cis_onoffline_name
    FROM (
        SELECT *
        FROM dwd.dwd_fi_mr_rev_cis_mi
        WHERE dt_month = LEFT(@year_month_day, 6)
        AND coproduction_flag = 'Y'
          /* 收入为0时，对应销量也不进入正反双笔 */
        AND IFNULL(rev_sale_amt, 0) <> 0
    ) cis_data
    CROSS JOIN (
        SELECT 1 AS amount_sign,'020_ON_003' AS cis_onoffline_code,'下沉' AS cis_onoffline_name
        UNION ALL
        SELECT -1 AS amount_sign,'020_ON_002' AS cis_onoffline_code,'主站' AS cis_onoffline_name
    ) sign_data
) s
LEFT JOIN ods.ods_slt_s600_kna1 kna1
    ON s.cust_code = kna1.kunnr
LEFT JOIN dw.dim_customer_base_info_dd cust_data
    ON kna1.zkunnr_mdg = cust_data.cust_code
LEFT JOIN (
    SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name
    FROM dw.dim_customer_trade_info_dd
) cust_trade
    ON kna1.zkunnr_mdg = cust_trade.cust_code
   AND s.company_code = cust_trade.sale_org
   AND s.material_group_code = cust_trade.material_group_code
LEFT JOIN dim.dim_fi_mr_product_dd product_data
    ON s.material_code = product_data.matnr
LEFT JOIN (
    SELECT DISTINCT cust_code,cp_company_code_mr,cp_company_code
    FROM dim.dim_rule_fi_mr_cust2ctp_mapping
    WHERE cust_type_code = 'C'
      AND system_src = 'S600'
) cust2ctp
    ON LTRIM(s.cust_code, '0') = LTRIM(cust2ctp.cust_code, '0')
;