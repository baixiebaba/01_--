-- =============================================================================
-- Doris 查询指定表的字段及字段描述
-- 目标: 118 张表 | 输出三列: 表名 / 字段名 / 字段描述
-- 生成日期: 2026-09-29
-- 说明: Doris 元数据在 information_schema.columns, 描述取 COLUMN_COMMENT
-- =============================================================================

-- 【方案1 / 推荐】一条 SQL 搞定, CONCAT 拼接后 IN 过滤, 兼容性最好
SELECT c.table_name                                   AS table_name        -- 表名
     , c.column_name                                  AS column_name       -- 字段名
     , IFNULL(NULLIF(TRIM(c.column_comment), ''), '-') AS column_comment    -- 字段描述(无注释显示 -)
  FROM information_schema.columns c
 WHERE c.table_schema IN ('ods','dim','dw','dws','dwd','ads')
   AND CONCAT(c.table_schema, '.', c.table_name) IN (
           'ods.odss600_knb1',
           'ods.odss700_knb1',
           'ods.odss800_knb1',
           'ods.odss900_knb1',
           'ods.odss610_knb1',
           'ods.odss810_knb1',
           'ods.odss600_t052u',
           'ods.odss700_t052u',
           'ods.odss800_t052u',
           'ods.odss900_t052u',
           'ods.odss610_t052u',
           'ods.odss810_t052u',
           'ods.odsslt_s600_bsid',
           'ods.odsslt_s600_bsad',
           'ods.odsslt_s600_bsik',
           'ods.odsslt_s600_bsak',
           'ods.odss600_lfa1',
           'ods.ods_slt_s600_kna1',
           'ods.odsslt_s610_bsid',
           'ods.odsslt_s610_bsad',
           'ods.odsslt_s610_bsik',
           'ods.odsslt_s610_bsak',
           'ods.odss610_lfa1',
           'ods.ods_slt_s610_kna1',
           'ods.odsslt_s700_bsid',
           'ods.odsslt_s700_bsad',
           'ods.odsslt_s700_bsik',
           'ods.odsslt_s700_bsak',
           'ods.odss700_lfa1',
           'ods.ods_slt_s700_kna1',
           'ods.odsslt_s800_bsid',
           'ods.odsslt_s800_bsad',
           'ods.odss800_bsik',
           'ods.odsslt_s800_bsak',
           'ods.odss800_lfa1',
           'ods.odss800_kna1',
           'ods.odsslt_s810_bsid',
           'ods.odsslt_s810_bsad',
           'ods.odsslt_s810_bsik',
           'ods.odsslt_s810_bsak',
           'ods.odss810_lfa1',
           'ods.ods_slt_s810_kna1',
           'ods.odsslt_s900_bsid',
           'ods.odsslt_s900_bsad',
           'ods.odss900_bsik',
           'ods.odsslt_s900_bsak',
           'ods.odss900_lfa1',
           'ods.ods_slt_s900_kna1',
           'ods.odss600_ztzt_003',
           'ods.odss610_ztzt_003',
           'ods.odss700_ztzt_003',
           'ods.odss800_ztzt_003',
           'ods.odss810_ztzt_003',
           'ods.odss900_ztzt_003',
           'ods.odss600_t001',
           'ods.odss610_t001',
           'ods.odss700_t001',
           'ods.odss800_t001',
           'ods.odss810_t001',
           'ods.odss900_t001',
           'ods.odss600_skb1',
           'ods.odss610_skb1',
           'ods.odss700_skb1',
           'ods.odss800_skb1',
           'ods.odss810_skb1',
           'ods.odss900_skb1',
           'ods.odss600_cepct',
           'ods.odss610_cepct',
           'ods.odss700_cepct',
           'ods.odss800_cepct',
           'ods.odss810_cepct',
           'ods.odss900_cepct',
           'ods.ods_slt_s600_faglflext',
           'ods.ods_slt_s700_faglflext',
           'ods.ods_slt_s800_glfunct',
           'ods.ods_slt_s810_faglflext',
           'ods.ods_slt_s900_glfunct',
           'dw.dim_customer_base_info_dd',
           'dim.dim_rule_fi_mr_acct_mapping',
           'dim.dim_rule_fi_mr_cust2ctp_mapping',
           'dim.dim_rule_fi_mr_ar_onoffline_map',
           'dim.dim_rule_fi_mr_nf_mapping',
           'dim.dim_rule_fi_mr_ar_prctr_map',
           'ods.odsfima_azienda',
           'ods.odsmt_fin_bill_view_data',
           'ods.odsmr_ztab_9000_acct_maping',
           'dws.dws_fi_mr_ar_overdue_mi',
           'ods.odsfipf_tk_hfi_jtb_bjtwtzjtz',
           'dw.dwd_ltc_cem_reportpay_balance_summary_dd',
           'dwd.dwd_mrs_mc_report_reward_account_detail_new_hi',
           'ads.ads_fi_mr_accounts_rec_di',
           'dw.dwsd_im_td_bdr_area_group',
           'dw.dwfi_im_td_product_category',
           'ods.odsmf_cm_tab1065',
           'ods.odsfmfi_t_bd_period',
           'ods.odsfmtss_t_org_org',
           'ods.odsfmfi_t_bd_account',
           'ods.odsfmtss_t_bd_customer',
           'ods.odsfmfi_tk_hifi_cas_profitcenter',
           'ods.odsfmfi_tk_hifi_cas_profitcenter_l',
           'ods.odsfmfi_tk_hifi_cas_bizrange',
           'ods.odsfmfi_tk_hifi_cas_bizrange_l',
           'ods.odsfmfi_tk_hifi_baddebtverify',
           'ods.odsfmfi_tk_hifi_baddebtverifysub',
           'ods.odsfmsecd_tk_hifi_orgs_ref',
           'dim.dim_rule_fi_mr_ar_agingdate',
           'dim.dim_rule_fi_mr_ar_aging_seg',
           'dim.dim_rule_fi_mr_ar_nf_mapping',
           'dim.dim_rule_fi_mr_ar_profit_mapping',
           'dim.dim_rule_fi_mr_ar_busrange_mapping',
           'dim.dim_rule_fi_mr_ar_country_busrange_mapping',
           'dim.dim_rule_fi_mr_ar_busdept_mapping',
           'dim.dim_rule_fi_mr_ar_cust_type',
           'dim.dim_rule_fi_mr_ar_ex_rate_eval_range',
           'dim.dim_rule_fi_mr_ar_aging_range',
           'dim.dim_rule_fi_mr_ar_reclass',
           'dim.dim_rule_fi_mr_ar_tax_rate',
           'dim.dim_rule_fi_mr_ar_nature'
       )
 ORDER BY c.table_schema, c.table_name, c.ordinal_position;


-- 【方案2】想同时带 Schema 时(推荐用于交付文档)
SELECT CONCAT(c.table_schema, '.', c.table_name)      AS table_full_name   -- 库名.表名
     , c.column_name                                  AS column_name       -- 字段名
     , IFNULL(NULLIF(TRIM(c.column_comment), ''), '-') AS column_comment    -- 字段描述
  FROM information_schema.columns c
 WHERE c.table_schema IN ('ods','dim','dw','dws','dwd','ads')
   AND CONCAT(c.table_schema, '.', c.table_name) IN (
           'ods.odss600_knb1',
           'ods.odss700_knb1',
           'ods.odss800_knb1',
           'ods.odss900_knb1',
           'ods.odss610_knb1',
           'ods.odss810_knb1',
           'ods.odss600_t052u',
           'ods.odss700_t052u',
           'ods.odss800_t052u',
           'ods.odss900_t052u',
           'ods.odss610_t052u',
           'ods.odss810_t052u',
           'ods.odsslt_s600_bsid',
           'ods.odsslt_s600_bsad',
           'ods.odsslt_s600_bsik',
           'ods.odsslt_s600_bsak',
           'ods.odss600_lfa1',
           'ods.ods_slt_s600_kna1',
           'ods.odsslt_s610_bsid',
           'ods.odsslt_s610_bsad',
           'ods.odsslt_s610_bsik',
           'ods.odsslt_s610_bsak',
           'ods.odss610_lfa1',
           'ods.ods_slt_s610_kna1',
           'ods.odsslt_s700_bsid',
           'ods.odsslt_s700_bsad',
           'ods.odsslt_s700_bsik',
           'ods.odsslt_s700_bsak',
           'ods.odss700_lfa1',
           'ods.ods_slt_s700_kna1',
           'ods.odsslt_s800_bsid',
           'ods.odsslt_s800_bsad',
           'ods.odss800_bsik',
           'ods.odsslt_s800_bsak',
           'ods.odss800_lfa1',
           'ods.odss800_kna1',
           'ods.odsslt_s810_bsid',
           'ods.odsslt_s810_bsad',
           'ods.odsslt_s810_bsik',
           'ods.odsslt_s810_bsak',
           'ods.odss810_lfa1',
           'ods.ods_slt_s810_kna1',
           'ods.odsslt_s900_bsid',
           'ods.odsslt_s900_bsad',
           'ods.odss900_bsik',
           'ods.odsslt_s900_bsak',
           'ods.odss900_lfa1',
           'ods.ods_slt_s900_kna1',
           'ods.odss600_ztzt_003',
           'ods.odss610_ztzt_003',
           'ods.odss700_ztzt_003',
           'ods.odss800_ztzt_003',
           'ods.odss810_ztzt_003',
           'ods.odss900_ztzt_003',
           'ods.odss600_t001',
           'ods.odss610_t001',
           'ods.odss700_t001',
           'ods.odss800_t001',
           'ods.odss810_t001',
           'ods.odss900_t001',
           'ods.odss600_skb1',
           'ods.odss610_skb1',
           'ods.odss700_skb1',
           'ods.odss800_skb1',
           'ods.odss810_skb1',
           'ods.odss900_skb1',
           'ods.odss600_cepct',
           'ods.odss610_cepct',
           'ods.odss700_cepct',
           'ods.odss800_cepct',
           'ods.odss810_cepct',
           'ods.odss900_cepct',
           'ods.ods_slt_s600_faglflext',
           'ods.ods_slt_s700_faglflext',
           'ods.ods_slt_s800_glfunct',
           'ods.ods_slt_s810_faglflext',
           'ods.ods_slt_s900_glfunct',
           'dw.dim_customer_base_info_dd',
           'dim.dim_rule_fi_mr_acct_mapping',
           'dim.dim_rule_fi_mr_cust2ctp_mapping',
           'dim.dim_rule_fi_mr_ar_onoffline_map',
           'dim.dim_rule_fi_mr_nf_mapping',
           'dim.dim_rule_fi_mr_ar_prctr_map',
           'ods.odsfima_azienda',
           'ods.odsmt_fin_bill_view_data',
           'ods.odsmr_ztab_9000_acct_maping',
           'dws.dws_fi_mr_ar_overdue_mi',
           'ods.odsfipf_tk_hfi_jtb_bjtwtzjtz',
           'dw.dwd_ltc_cem_reportpay_balance_summary_dd',
           'dwd.dwd_mrs_mc_report_reward_account_detail_new_hi',
           'ads.ads_fi_mr_accounts_rec_di',
           'dw.dwsd_im_td_bdr_area_group',
           'dw.dwfi_im_td_product_category',
           'ods.odsmf_cm_tab1065',
           'ods.odsfmfi_t_bd_period',
           'ods.odsfmtss_t_org_org',
           'ods.odsfmfi_t_bd_account',
           'ods.odsfmtss_t_bd_customer',
           'ods.odsfmfi_tk_hifi_cas_profitcenter',
           'ods.odsfmfi_tk_hifi_cas_profitcenter_l',
           'ods.odsfmfi_tk_hifi_cas_bizrange',
           'ods.odsfmfi_tk_hifi_cas_bizrange_l',
           'ods.odsfmfi_tk_hifi_baddebtverify',
           'ods.odsfmfi_tk_hifi_baddebtverifysub',
           'ods.odsfmsecd_tk_hifi_orgs_ref',
           'dim.dim_rule_fi_mr_ar_agingdate',
           'dim.dim_rule_fi_mr_ar_aging_seg',
           'dim.dim_rule_fi_mr_ar_nf_mapping',
           'dim.dim_rule_fi_mr_ar_profit_mapping',
           'dim.dim_rule_fi_mr_ar_busrange_mapping',
           'dim.dim_rule_fi_mr_ar_country_busrange_mapping',
           'dim.dim_rule_fi_mr_ar_busdept_mapping',
           'dim.dim_rule_fi_mr_ar_cust_type',
           'dim.dim_rule_fi_mr_ar_ex_rate_eval_range',
           'dim.dim_rule_fi_mr_ar_aging_range',
           'dim.dim_rule_fi_mr_ar_reclass',
           'dim.dim_rule_fi_mr_ar_tax_rate',
           'dim.dim_rule_fi_mr_ar_nature'
       )
 ORDER BY c.table_schema, c.table_name, c.ordinal_position;


-- =============================================================================
-- 【校验】哪些表在 Doris 里没查到(表名写错/表不存在 时用它核对)
-- 用法: 把上面同一个 IN 列表粘过来, 对比 full_list 与 hit_list 的差集
-- =============================================================================
SELECT t.full_name
  FROM (
           SELECT 'ods.odss600_knb1' AS full_name
           UNION ALL SELECT 'ods.odss700_knb1' AS full_name
           UNION ALL SELECT 'ods.odss800_knb1' AS full_name
           UNION ALL SELECT 'ods.odss900_knb1' AS full_name
           UNION ALL SELECT 'ods.odss610_knb1' AS full_name
           UNION ALL SELECT 'ods.odss810_knb1' AS full_name
           UNION ALL SELECT 'ods.odss600_t052u' AS full_name
           UNION ALL SELECT 'ods.odss700_t052u' AS full_name
           UNION ALL SELECT 'ods.odss800_t052u' AS full_name
           UNION ALL SELECT 'ods.odss900_t052u' AS full_name
           UNION ALL SELECT 'ods.odss610_t052u' AS full_name
           UNION ALL SELECT 'ods.odss810_t052u' AS full_name
           UNION ALL SELECT 'ods.odsslt_s600_bsid' AS full_name
           UNION ALL SELECT 'ods.odsslt_s600_bsad' AS full_name
           UNION ALL SELECT 'ods.odsslt_s600_bsik' AS full_name
           UNION ALL SELECT 'ods.odsslt_s600_bsak' AS full_name
           UNION ALL SELECT 'ods.odss600_lfa1' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s600_kna1' AS full_name
           UNION ALL SELECT 'ods.odsslt_s610_bsid' AS full_name
           UNION ALL SELECT 'ods.odsslt_s610_bsad' AS full_name
           UNION ALL SELECT 'ods.odsslt_s610_bsik' AS full_name
           UNION ALL SELECT 'ods.odsslt_s610_bsak' AS full_name
           UNION ALL SELECT 'ods.odss610_lfa1' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s610_kna1' AS full_name
           UNION ALL SELECT 'ods.odsslt_s700_bsid' AS full_name
           UNION ALL SELECT 'ods.odsslt_s700_bsad' AS full_name
           UNION ALL SELECT 'ods.odsslt_s700_bsik' AS full_name
           UNION ALL SELECT 'ods.odsslt_s700_bsak' AS full_name
           UNION ALL SELECT 'ods.odss700_lfa1' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s700_kna1' AS full_name
           UNION ALL SELECT 'ods.odsslt_s800_bsid' AS full_name
           UNION ALL SELECT 'ods.odsslt_s800_bsad' AS full_name
           UNION ALL SELECT 'ods.odss800_bsik' AS full_name
           UNION ALL SELECT 'ods.odsslt_s800_bsak' AS full_name
           UNION ALL SELECT 'ods.odss800_lfa1' AS full_name
           UNION ALL SELECT 'ods.odss800_kna1' AS full_name
           UNION ALL SELECT 'ods.odsslt_s810_bsid' AS full_name
           UNION ALL SELECT 'ods.odsslt_s810_bsad' AS full_name
           UNION ALL SELECT 'ods.odsslt_s810_bsik' AS full_name
           UNION ALL SELECT 'ods.odsslt_s810_bsak' AS full_name
           UNION ALL SELECT 'ods.odss810_lfa1' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s810_kna1' AS full_name
           UNION ALL SELECT 'ods.odsslt_s900_bsid' AS full_name
           UNION ALL SELECT 'ods.odsslt_s900_bsad' AS full_name
           UNION ALL SELECT 'ods.odss900_bsik' AS full_name
           UNION ALL SELECT 'ods.odsslt_s900_bsak' AS full_name
           UNION ALL SELECT 'ods.odss900_lfa1' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s900_kna1' AS full_name
           UNION ALL SELECT 'ods.odss600_ztzt_003' AS full_name
           UNION ALL SELECT 'ods.odss610_ztzt_003' AS full_name
           UNION ALL SELECT 'ods.odss700_ztzt_003' AS full_name
           UNION ALL SELECT 'ods.odss800_ztzt_003' AS full_name
           UNION ALL SELECT 'ods.odss810_ztzt_003' AS full_name
           UNION ALL SELECT 'ods.odss900_ztzt_003' AS full_name
           UNION ALL SELECT 'ods.odss600_t001' AS full_name
           UNION ALL SELECT 'ods.odss610_t001' AS full_name
           UNION ALL SELECT 'ods.odss700_t001' AS full_name
           UNION ALL SELECT 'ods.odss800_t001' AS full_name
           UNION ALL SELECT 'ods.odss810_t001' AS full_name
           UNION ALL SELECT 'ods.odss900_t001' AS full_name
           UNION ALL SELECT 'ods.odss600_skb1' AS full_name
           UNION ALL SELECT 'ods.odss610_skb1' AS full_name
           UNION ALL SELECT 'ods.odss700_skb1' AS full_name
           UNION ALL SELECT 'ods.odss800_skb1' AS full_name
           UNION ALL SELECT 'ods.odss810_skb1' AS full_name
           UNION ALL SELECT 'ods.odss900_skb1' AS full_name
           UNION ALL SELECT 'ods.odss600_cepct' AS full_name
           UNION ALL SELECT 'ods.odss610_cepct' AS full_name
           UNION ALL SELECT 'ods.odss700_cepct' AS full_name
           UNION ALL SELECT 'ods.odss800_cepct' AS full_name
           UNION ALL SELECT 'ods.odss810_cepct' AS full_name
           UNION ALL SELECT 'ods.odss900_cepct' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s600_faglflext' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s700_faglflext' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s800_glfunct' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s810_faglflext' AS full_name
           UNION ALL SELECT 'ods.ods_slt_s900_glfunct' AS full_name
           UNION ALL SELECT 'dw.dim_customer_base_info_dd' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_acct_mapping' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_cust2ctp_mapping' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_onoffline_map' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_nf_mapping' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_prctr_map' AS full_name
           UNION ALL SELECT 'ods.odsfima_azienda' AS full_name
           UNION ALL SELECT 'ods.odsmt_fin_bill_view_data' AS full_name
           UNION ALL SELECT 'ods.odsmr_ztab_9000_acct_maping' AS full_name
           UNION ALL SELECT 'dws.dws_fi_mr_ar_overdue_mi' AS full_name
           UNION ALL SELECT 'ods.odsfipf_tk_hfi_jtb_bjtwtzjtz' AS full_name
           UNION ALL SELECT 'dw.dwd_ltc_cem_reportpay_balance_summary_dd' AS full_name
           UNION ALL SELECT 'dwd.dwd_mrs_mc_report_reward_account_detail_new_hi' AS full_name
           UNION ALL SELECT 'ads.ads_fi_mr_accounts_rec_di' AS full_name
           UNION ALL SELECT 'dw.dwsd_im_td_bdr_area_group' AS full_name
           UNION ALL SELECT 'dw.dwfi_im_td_product_category' AS full_name
           UNION ALL SELECT 'ods.odsmf_cm_tab1065' AS full_name
           UNION ALL SELECT 'ods.odsfmfi_t_bd_period' AS full_name
           UNION ALL SELECT 'ods.odsfmtss_t_org_org' AS full_name
           UNION ALL SELECT 'ods.odsfmfi_t_bd_account' AS full_name
           UNION ALL SELECT 'ods.odsfmtss_t_bd_customer' AS full_name
           UNION ALL SELECT 'ods.odsfmfi_tk_hifi_cas_profitcenter' AS full_name
           UNION ALL SELECT 'ods.odsfmfi_tk_hifi_cas_profitcenter_l' AS full_name
           UNION ALL SELECT 'ods.odsfmfi_tk_hifi_cas_bizrange' AS full_name
           UNION ALL SELECT 'ods.odsfmfi_tk_hifi_cas_bizrange_l' AS full_name
           UNION ALL SELECT 'ods.odsfmfi_tk_hifi_baddebtverify' AS full_name
           UNION ALL SELECT 'ods.odsfmfi_tk_hifi_baddebtverifysub' AS full_name
           UNION ALL SELECT 'ods.odsfmsecd_tk_hifi_orgs_ref' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_agingdate' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_aging_seg' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_nf_mapping' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_profit_mapping' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_busrange_mapping' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_country_busrange_mapping' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_busdept_mapping' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_cust_type' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_ex_rate_eval_range' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_aging_range' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_reclass' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_tax_rate' AS full_name
           UNION ALL SELECT 'dim.dim_rule_fi_mr_ar_nature' AS full_name
       ) AS t
 WHERE t.full_name NOT IN (
           SELECT CONCAT(c.table_schema, '.', c.table_name)
             FROM information_schema.columns c
            WHERE c.table_schema IN ('ods','dim','dw','dws','dwd','ads')
   AND CONCAT(c.table_schema, '.', c.table_name) IN (
                      'ods.odss600_knb1',
           'ods.odss700_knb1',
           'ods.odss800_knb1',
           'ods.odss900_knb1',
           'ods.odss610_knb1',
           'ods.odss810_knb1',
           'ods.odss600_t052u',
           'ods.odss700_t052u',
           'ods.odss800_t052u',
           'ods.odss900_t052u',
           'ods.odss610_t052u',
           'ods.odss810_t052u',
           'ods.odsslt_s600_bsid',
           'ods.odsslt_s600_bsad',
           'ods.odsslt_s600_bsik',
           'ods.odsslt_s600_bsak',
           'ods.odss600_lfa1',
           'ods.ods_slt_s600_kna1',
           'ods.odsslt_s610_bsid',
           'ods.odsslt_s610_bsad',
           'ods.odsslt_s610_bsik',
           'ods.odsslt_s610_bsak',
           'ods.odss610_lfa1',
           'ods.ods_slt_s610_kna1',
           'ods.odsslt_s700_bsid',
           'ods.odsslt_s700_bsad',
           'ods.odsslt_s700_bsik',
           'ods.odsslt_s700_bsak',
           'ods.odss700_lfa1',
           'ods.ods_slt_s700_kna1',
           'ods.odsslt_s800_bsid',
           'ods.odsslt_s800_bsad',
           'ods.odss800_bsik',
           'ods.odsslt_s800_bsak',
           'ods.odss800_lfa1',
           'ods.odss800_kna1',
           'ods.odsslt_s810_bsid',
           'ods.odsslt_s810_bsad',
           'ods.odsslt_s810_bsik',
           'ods.odsslt_s810_bsak',
           'ods.odss810_lfa1',
           'ods.ods_slt_s810_kna1',
           'ods.odsslt_s900_bsid',
           'ods.odsslt_s900_bsad',
           'ods.odss900_bsik',
           'ods.odsslt_s900_bsak',
           'ods.odss900_lfa1',
           'ods.ods_slt_s900_kna1',
           'ods.odss600_ztzt_003',
           'ods.odss610_ztzt_003',
           'ods.odss700_ztzt_003',
           'ods.odss800_ztzt_003',
           'ods.odss810_ztzt_003',
           'ods.odss900_ztzt_003',
           'ods.odss600_t001',
           'ods.odss610_t001',
           'ods.odss700_t001',
           'ods.odss800_t001',
           'ods.odss810_t001',
           'ods.odss900_t001',
           'ods.odss600_skb1',
           'ods.odss610_skb1',
           'ods.odss700_skb1',
           'ods.odss800_skb1',
           'ods.odss810_skb1',
           'ods.odss900_skb1',
           'ods.odss600_cepct',
           'ods.odss610_cepct',
           'ods.odss700_cepct',
           'ods.odss800_cepct',
           'ods.odss810_cepct',
           'ods.odss900_cepct',
           'ods.ods_slt_s600_faglflext',
           'ods.ods_slt_s700_faglflext',
           'ods.ods_slt_s800_glfunct',
           'ods.ods_slt_s810_faglflext',
           'ods.ods_slt_s900_glfunct',
           'dw.dim_customer_base_info_dd',
           'dim.dim_rule_fi_mr_acct_mapping',
           'dim.dim_rule_fi_mr_cust2ctp_mapping',
           'dim.dim_rule_fi_mr_ar_onoffline_map',
           'dim.dim_rule_fi_mr_nf_mapping',
           'dim.dim_rule_fi_mr_ar_prctr_map',
           'ods.odsfima_azienda',
           'ods.odsmt_fin_bill_view_data',
           'ods.odsmr_ztab_9000_acct_maping',
           'dws.dws_fi_mr_ar_overdue_mi',
           'ods.odsfipf_tk_hfi_jtb_bjtwtzjtz',
           'dw.dwd_ltc_cem_reportpay_balance_summary_dd',
           'dwd.dwd_mrs_mc_report_reward_account_detail_new_hi',
           'ads.ads_fi_mr_accounts_rec_di',
           'dw.dwsd_im_td_bdr_area_group',
           'dw.dwfi_im_td_product_category',
           'ods.odsmf_cm_tab1065',
           'ods.odsfmfi_t_bd_period',
           'ods.odsfmtss_t_org_org',
           'ods.odsfmfi_t_bd_account',
           'ods.odsfmtss_t_bd_customer',
           'ods.odsfmfi_tk_hifi_cas_profitcenter',
           'ods.odsfmfi_tk_hifi_cas_profitcenter_l',
           'ods.odsfmfi_tk_hifi_cas_bizrange',
           'ods.odsfmfi_tk_hifi_cas_bizrange_l',
           'ods.odsfmfi_tk_hifi_baddebtverify',
           'ods.odsfmfi_tk_hifi_baddebtverifysub',
           'ods.odsfmsecd_tk_hifi_orgs_ref',
           'dim.dim_rule_fi_mr_ar_agingdate',
           'dim.dim_rule_fi_mr_ar_aging_seg',
           'dim.dim_rule_fi_mr_ar_nf_mapping',
           'dim.dim_rule_fi_mr_ar_profit_mapping',
           'dim.dim_rule_fi_mr_ar_busrange_mapping',
           'dim.dim_rule_fi_mr_ar_country_busrange_mapping',
           'dim.dim_rule_fi_mr_ar_busdept_mapping',
           'dim.dim_rule_fi_mr_ar_cust_type',
           'dim.dim_rule_fi_mr_ar_ex_rate_eval_range',
           'dim.dim_rule_fi_mr_ar_aging_range',
           'dim.dim_rule_fi_mr_ar_reclass',
           'dim.dim_rule_fi_mr_ar_tax_rate',
           'dim.dim_rule_fi_mr_ar_nature'
                  )
       )
 ORDER BY t.full_name;


-- =============================================================================
-- 【兜底】若 Doris 版本较老, information_schema.columns 没有 COLUMN_COMMENT 列
--         (报 Unknown column 'column_comment'), 用 SHOW FULL COLUMNS 单表查
--         逐表执行即可, Comment 列就是字段描述
-- =============================================================================
SHOW FULL COLUMNS FROM ods.odss600_knb1;
SHOW FULL COLUMNS FROM ods.odss700_knb1;
SHOW FULL COLUMNS FROM ods.odss800_knb1;
SHOW FULL COLUMNS FROM ods.odss900_knb1;
SHOW FULL COLUMNS FROM ods.odss610_knb1;
SHOW FULL COLUMNS FROM ods.odss810_knb1;
SHOW FULL COLUMNS FROM ods.odss600_t052u;
SHOW FULL COLUMNS FROM ods.odss700_t052u;
SHOW FULL COLUMNS FROM ods.odss800_t052u;
SHOW FULL COLUMNS FROM ods.odss900_t052u;
SHOW FULL COLUMNS FROM ods.odss610_t052u;
SHOW FULL COLUMNS FROM ods.odss810_t052u;
SHOW FULL COLUMNS FROM ods.odsslt_s600_bsid;
SHOW FULL COLUMNS FROM ods.odsslt_s600_bsad;
SHOW FULL COLUMNS FROM ods.odsslt_s600_bsik;
SHOW FULL COLUMNS FROM ods.odsslt_s600_bsak;
SHOW FULL COLUMNS FROM ods.odss600_lfa1;
SHOW FULL COLUMNS FROM ods.ods_slt_s600_kna1;
SHOW FULL COLUMNS FROM ods.odsslt_s610_bsid;
SHOW FULL COLUMNS FROM ods.odsslt_s610_bsad;
SHOW FULL COLUMNS FROM ods.odsslt_s610_bsik;
SHOW FULL COLUMNS FROM ods.odsslt_s610_bsak;
SHOW FULL COLUMNS FROM ods.odss610_lfa1;
SHOW FULL COLUMNS FROM ods.ods_slt_s610_kna1;
SHOW FULL COLUMNS FROM ods.odsslt_s700_bsid;
SHOW FULL COLUMNS FROM ods.odsslt_s700_bsad;
SHOW FULL COLUMNS FROM ods.odsslt_s700_bsik;
SHOW FULL COLUMNS FROM ods.odsslt_s700_bsak;
SHOW FULL COLUMNS FROM ods.odss700_lfa1;
SHOW FULL COLUMNS FROM ods.ods_slt_s700_kna1;
SHOW FULL COLUMNS FROM ods.odsslt_s800_bsid;
SHOW FULL COLUMNS FROM ods.odsslt_s800_bsad;
SHOW FULL COLUMNS FROM ods.odss800_bsik;
SHOW FULL COLUMNS FROM ods.odsslt_s800_bsak;
SHOW FULL COLUMNS FROM ods.odss800_lfa1;
SHOW FULL COLUMNS FROM ods.odss800_kna1;
SHOW FULL COLUMNS FROM ods.odsslt_s810_bsid;
SHOW FULL COLUMNS FROM ods.odsslt_s810_bsad;
SHOW FULL COLUMNS FROM ods.odsslt_s810_bsik;
SHOW FULL COLUMNS FROM ods.odsslt_s810_bsak;
SHOW FULL COLUMNS FROM ods.odss810_lfa1;
SHOW FULL COLUMNS FROM ods.ods_slt_s810_kna1;
SHOW FULL COLUMNS FROM ods.odsslt_s900_bsid;
SHOW FULL COLUMNS FROM ods.odsslt_s900_bsad;
SHOW FULL COLUMNS FROM ods.odss900_bsik;
SHOW FULL COLUMNS FROM ods.odsslt_s900_bsak;
SHOW FULL COLUMNS FROM ods.odss900_lfa1;
SHOW FULL COLUMNS FROM ods.ods_slt_s900_kna1;
SHOW FULL COLUMNS FROM ods.odss600_ztzt_003;
SHOW FULL COLUMNS FROM ods.odss610_ztzt_003;
SHOW FULL COLUMNS FROM ods.odss700_ztzt_003;
SHOW FULL COLUMNS FROM ods.odss800_ztzt_003;
SHOW FULL COLUMNS FROM ods.odss810_ztzt_003;
SHOW FULL COLUMNS FROM ods.odss900_ztzt_003;
SHOW FULL COLUMNS FROM ods.odss600_t001;
SHOW FULL COLUMNS FROM ods.odss610_t001;
SHOW FULL COLUMNS FROM ods.odss700_t001;
SHOW FULL COLUMNS FROM ods.odss800_t001;
SHOW FULL COLUMNS FROM ods.odss810_t001;
SHOW FULL COLUMNS FROM ods.odss900_t001;
SHOW FULL COLUMNS FROM ods.odss600_skb1;
SHOW FULL COLUMNS FROM ods.odss610_skb1;
SHOW FULL COLUMNS FROM ods.odss700_skb1;
SHOW FULL COLUMNS FROM ods.odss800_skb1;
SHOW FULL COLUMNS FROM ods.odss810_skb1;
SHOW FULL COLUMNS FROM ods.odss900_skb1;
SHOW FULL COLUMNS FROM ods.odss600_cepct;
SHOW FULL COLUMNS FROM ods.odss610_cepct;
SHOW FULL COLUMNS FROM ods.odss700_cepct;
SHOW FULL COLUMNS FROM ods.odss800_cepct;
SHOW FULL COLUMNS FROM ods.odss810_cepct;
SHOW FULL COLUMNS FROM ods.odss900_cepct;
SHOW FULL COLUMNS FROM ods.ods_slt_s600_faglflext;
SHOW FULL COLUMNS FROM ods.ods_slt_s700_faglflext;
SHOW FULL COLUMNS FROM ods.ods_slt_s800_glfunct;
SHOW FULL COLUMNS FROM ods.ods_slt_s810_faglflext;
SHOW FULL COLUMNS FROM ods.ods_slt_s900_glfunct;
SHOW FULL COLUMNS FROM dw.dim_customer_base_info_dd;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_acct_mapping;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_cust2ctp_mapping;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_onoffline_map;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_nf_mapping;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_prctr_map;
SHOW FULL COLUMNS FROM ods.odsfima_azienda;
SHOW FULL COLUMNS FROM ods.odsmt_fin_bill_view_data;
SHOW FULL COLUMNS FROM ods.odsmr_ztab_9000_acct_maping;
SHOW FULL COLUMNS FROM dws.dws_fi_mr_ar_overdue_mi;
SHOW FULL COLUMNS FROM ods.odsfipf_tk_hfi_jtb_bjtwtzjtz;
SHOW FULL COLUMNS FROM dw.dwd_ltc_cem_reportpay_balance_summary_dd;
SHOW FULL COLUMNS FROM dwd.dwd_mrs_mc_report_reward_account_detail_new_hi;
SHOW FULL COLUMNS FROM ads.ads_fi_mr_accounts_rec_di;
SHOW FULL COLUMNS FROM dw.dwsd_im_td_bdr_area_group;
SHOW FULL COLUMNS FROM dw.dwfi_im_td_product_category;
SHOW FULL COLUMNS FROM ods.odsmf_cm_tab1065;
SHOW FULL COLUMNS FROM ods.odsfmfi_t_bd_period;
SHOW FULL COLUMNS FROM ods.odsfmtss_t_org_org;
SHOW FULL COLUMNS FROM ods.odsfmfi_t_bd_account;
SHOW FULL COLUMNS FROM ods.odsfmtss_t_bd_customer;
SHOW FULL COLUMNS FROM ods.odsfmfi_tk_hifi_cas_profitcenter;
SHOW FULL COLUMNS FROM ods.odsfmfi_tk_hifi_cas_profitcenter_l;
SHOW FULL COLUMNS FROM ods.odsfmfi_tk_hifi_cas_bizrange;
SHOW FULL COLUMNS FROM ods.odsfmfi_tk_hifi_cas_bizrange_l;
SHOW FULL COLUMNS FROM ods.odsfmfi_tk_hifi_baddebtverify;
SHOW FULL COLUMNS FROM ods.odsfmfi_tk_hifi_baddebtverifysub;
SHOW FULL COLUMNS FROM ods.odsfmsecd_tk_hifi_orgs_ref;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_agingdate;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_aging_seg;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_nf_mapping;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_profit_mapping;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_busrange_mapping;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_country_busrange_mapping;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_busdept_mapping;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_cust_type;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_ex_rate_eval_range;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_aging_range;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_reclass;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_tax_rate;
SHOW FULL COLUMNS FROM dim.dim_rule_fi_mr_ar_nature;


-- =============================================================================
-- 【概览】每张表多少字段 / 有多少字段没写注释(用于检查元数据完整度)
-- =============================================================================
SELECT CONCAT(c.table_schema, '.', c.table_name)  AS table_full_name
     , COUNT(*)                                   AS col_cnt
     , SUM(CASE WHEN IFNULL(TRIM(c.column_comment), '') = '' THEN 1 ELSE 0 END) AS no_comment_cnt
  FROM information_schema.columns c
 WHERE c.table_schema IN ('ods','dim','dw','dws','dwd','ads')
   AND CONCAT(c.table_schema, '.', c.table_name) IN (
           'ods.odss600_knb1',
           'ods.odss700_knb1',
           'ods.odss800_knb1',
           'ods.odss900_knb1',
           'ods.odss610_knb1',
           'ods.odss810_knb1',
           'ods.odss600_t052u',
           'ods.odss700_t052u',
           'ods.odss800_t052u',
           'ods.odss900_t052u',
           'ods.odss610_t052u',
           'ods.odss810_t052u',
           'ods.odsslt_s600_bsid',
           'ods.odsslt_s600_bsad',
           'ods.odsslt_s600_bsik',
           'ods.odsslt_s600_bsak',
           'ods.odss600_lfa1',
           'ods.ods_slt_s600_kna1',
           'ods.odsslt_s610_bsid',
           'ods.odsslt_s610_bsad',
           'ods.odsslt_s610_bsik',
           'ods.odsslt_s610_bsak',
           'ods.odss610_lfa1',
           'ods.ods_slt_s610_kna1',
           'ods.odsslt_s700_bsid',
           'ods.odsslt_s700_bsad',
           'ods.odsslt_s700_bsik',
           'ods.odsslt_s700_bsak',
           'ods.odss700_lfa1',
           'ods.ods_slt_s700_kna1',
           'ods.odsslt_s800_bsid',
           'ods.odsslt_s800_bsad',
           'ods.odss800_bsik',
           'ods.odsslt_s800_bsak',
           'ods.odss800_lfa1',
           'ods.odss800_kna1',
           'ods.odsslt_s810_bsid',
           'ods.odsslt_s810_bsad',
           'ods.odsslt_s810_bsik',
           'ods.odsslt_s810_bsak',
           'ods.odss810_lfa1',
           'ods.ods_slt_s810_kna1',
           'ods.odsslt_s900_bsid',
           'ods.odsslt_s900_bsad',
           'ods.odss900_bsik',
           'ods.odsslt_s900_bsak',
           'ods.odss900_lfa1',
           'ods.ods_slt_s900_kna1',
           'ods.odss600_ztzt_003',
           'ods.odss610_ztzt_003',
           'ods.odss700_ztzt_003',
           'ods.odss800_ztzt_003',
           'ods.odss810_ztzt_003',
           'ods.odss900_ztzt_003',
           'ods.odss600_t001',
           'ods.odss610_t001',
           'ods.odss700_t001',
           'ods.odss800_t001',
           'ods.odss810_t001',
           'ods.odss900_t001',
           'ods.odss600_skb1',
           'ods.odss610_skb1',
           'ods.odss700_skb1',
           'ods.odss800_skb1',
           'ods.odss810_skb1',
           'ods.odss900_skb1',
           'ods.odss600_cepct',
           'ods.odss610_cepct',
           'ods.odss700_cepct',
           'ods.odss800_cepct',
           'ods.odss810_cepct',
           'ods.odss900_cepct',
           'ods.ods_slt_s600_faglflext',
           'ods.ods_slt_s700_faglflext',
           'ods.ods_slt_s800_glfunct',
           'ods.ods_slt_s810_faglflext',
           'ods.ods_slt_s900_glfunct',
           'dw.dim_customer_base_info_dd',
           'dim.dim_rule_fi_mr_acct_mapping',
           'dim.dim_rule_fi_mr_cust2ctp_mapping',
           'dim.dim_rule_fi_mr_ar_onoffline_map',
           'dim.dim_rule_fi_mr_nf_mapping',
           'dim.dim_rule_fi_mr_ar_prctr_map',
           'ods.odsfima_azienda',
           'ods.odsmt_fin_bill_view_data',
           'ods.odsmr_ztab_9000_acct_maping',
           'dws.dws_fi_mr_ar_overdue_mi',
           'ods.odsfipf_tk_hfi_jtb_bjtwtzjtz',
           'dw.dwd_ltc_cem_reportpay_balance_summary_dd',
           'dwd.dwd_mrs_mc_report_reward_account_detail_new_hi',
           'ads.ads_fi_mr_accounts_rec_di',
           'dw.dwsd_im_td_bdr_area_group',
           'dw.dwfi_im_td_product_category',
           'ods.odsmf_cm_tab1065',
           'ods.odsfmfi_t_bd_period',
           'ods.odsfmtss_t_org_org',
           'ods.odsfmfi_t_bd_account',
           'ods.odsfmtss_t_bd_customer',
           'ods.odsfmfi_tk_hifi_cas_profitcenter',
           'ods.odsfmfi_tk_hifi_cas_profitcenter_l',
           'ods.odsfmfi_tk_hifi_cas_bizrange',
           'ods.odsfmfi_tk_hifi_cas_bizrange_l',
           'ods.odsfmfi_tk_hifi_baddebtverify',
           'ods.odsfmfi_tk_hifi_baddebtverifysub',
           'ods.odsfmsecd_tk_hifi_orgs_ref',
           'dim.dim_rule_fi_mr_ar_agingdate',
           'dim.dim_rule_fi_mr_ar_aging_seg',
           'dim.dim_rule_fi_mr_ar_nf_mapping',
           'dim.dim_rule_fi_mr_ar_profit_mapping',
           'dim.dim_rule_fi_mr_ar_busrange_mapping',
           'dim.dim_rule_fi_mr_ar_country_busrange_mapping',
           'dim.dim_rule_fi_mr_ar_busdept_mapping',
           'dim.dim_rule_fi_mr_ar_cust_type',
           'dim.dim_rule_fi_mr_ar_ex_rate_eval_range',
           'dim.dim_rule_fi_mr_ar_aging_range',
           'dim.dim_rule_fi_mr_ar_reclass',
           'dim.dim_rule_fi_mr_ar_tax_rate',
           'dim.dim_rule_fi_mr_ar_nature'
       )
 GROUP BY CONCAT(c.table_schema, '.', c.table_name)
 ORDER BY no_comment_cnt DESC, col_cnt DESC;
