
set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;
--set @year_month_day = '20260301' ;


--set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';

/*为确保有分区不会报错，先插入一条数据*/
--INSERT INTO dwd.dwd_fi_mr_gp_msum_mi (dt_month) VALUES ('202601');

INSERT INTO dwd.dwd_fi_mr_gp_msum_mi (dt_month) VALUES (LEFT(@year_month_day,6));

INSERT OVERWRITE TABLE dwd.dwd_fi_mr_gp_msum_mi PARTITION (*)

--INSERT OVERWRITE TABLE dwd.dwd_fi_mr_gp_msum_mi PARTITION ({{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}})
(   
  dt_month,year,month,company_code,agency_code,agency_name,cust_code,material_code,shop_code,cust_name,cust_unity_name,credit_level_name,cust_nature_name,cust_type_name,channel_l1_code,channel_l1_name,channel_l2_code,channel_l2_name,channel_l3_code,channel_l3_name,marketing_mode_code,marketing_mode_name,channel_big_class_code,channel_big_class_name,channel_small_class_code,channel_small_class_name,ind_big_class_code,ind_big_class_name,ind_small_class_code,ind_small_class_name,onoffline_code,onoffline_name,material_name,product_line_code,product_line_name,sale_model_code,sale_model_name,brand_code,brand_name,spec_section_code,spec_section_name,product_shape_type_code,product_shape_type_name,product_sale_series_code,product_sale_series_name,quarter_method_code,quarter_method_name,product_stage_code,product_stage_name,price_range_code,price_range_name,model_code,model_name,product_series_code,product_series_name,market_pnt_code,market_pnt_name,tech_type_code,tech_type_name,product_big_class_code,product_big_class_name,product_mid_class_code,product_mid_class_name,product_small_class_code,product_small_class_name,model_lca_code,model_lca_name,product_type_code,product_type_name,shop_name,bill_qty,ship_qty,order_qty,qcy_code,rev_sale_amt,rev_rst_amt,ship_amt,order_amt,discount1_amt,discount3_amt,discount4_amt,discount5_amt,discount6_amt,
  discount30_amt,
  discount34_amt,cogs_amt,tax_rate,   price_tax_amt,  exchange_rate,  system_src,ods_src,sold_to_code,sold_to_name,material_group_code,material_group_name,cp_company_code,batch_id,bill_dt,  material_pricing_group_code,material_pricing_group_name,acct_src_code,acct_map_code,load_dt,bill_type_code,order_type_code,general_ledger,record_type,init_object_type,cust_mdg_code,bus_range_code,bus_range_name,marketing_dept_code,marketing_dept_name,is_miniled_code,comm_bu_code,comm_bu_name
,profitcenter_code,profitcenter_name,customer_model,
    zcalasset,
    cn_class_mark_code,
    cn_class_mark_name,
    sale_cert_type,
    rev_sale_bcy_amt
	,cost_center_code  	--成本中心编码
	,cost_center_name	--成本中心名称
    ,gfcfy_amount
	,gfcfl_amount
    ,br_company_code
    ,maktx_s810
    ,src_profitcenter_code
    ,src_bus_range_code
    , bus_sce_cat_code --业务场景分类编码
, bus_sce_cat_name --业务场景分类描述
,transaction_type -- 事务类型
/*20260520 新增miniled类型字段*/
    , miniled_type_code
    , miniled_type_name
	,invoice_code --金税发票号
)
SELECT T1.dt_month,
    year,
    month,
    CASE WHEN T1.company_code IN ('118A','118B','1181') THEN '1180' ELSE T1.company_code END AS company_code,
    agency_code,
    agency_name,
    CASE WHEN REGEXP(LTRIM(T1.cust_code,0), '[一-龥]') THEN NULL ELSE LTRIM(T1.cust_code,0) END AS cust_code,
    T1.material_code,
    shop_code,
    cust_name,
    cust_unity_name,
    credit_level_name,
    cust_nature_name,
    cust_type_name,
    channel_l1_code,
    channel_l1_name,
    channel_l2_code,
    channel_l2_name,
    channel_l3_code,
    channel_l3_name,
    marketing_mode_code,
    marketing_mode_name,
    channel_big_class_code,
    channel_big_class_name,
    channel_small_class_code,
    channel_small_class_name,
    ind_big_class_code,
    ind_big_class_name,
    ind_small_class_code,
    ind_small_class_name,
    CASE WHEN T2.rule_flag = 1 THEN '020_ON_003' ELSE onoffline_code END,
    CASE WHEN T2.rule_flag = 1 THEN '下沉' ELSE onoffline_name END,
    material_name,
    LTRIM(product_line_code,'0') AS product_line_code,
    product_line_name,
    sale_model_code,
    sale_model_name,
    brand_code,
    brand_name,
    spec_section_code,
    spec_section_name,
    product_shape_type_code,
    product_shape_type_name,
    product_sale_series_code,
    product_sale_series_name,
    quarter_method_code,
    quarter_method_name,
    product_stage_code,
    product_stage_name,
    price_range_code,
    price_range_name,
    model_code,
    model_name,
    product_series_code,
    product_series_name,
    market_pnt_code,
    market_pnt_name,
    tech_type_code,
    tech_type_name,
    product_big_class_code,
    product_big_class_name,
    product_mid_class_code,
    product_mid_class_name,
    product_small_class_code,
    product_small_class_name,
    model_lca_code,
    model_lca_name,
    product_type_code,
    product_type_name,
    shop_name,
    SUM(IFNULL(bill_qty,0)) AS bill_qty,
    SUM(IFNULL(ship_qty,0)) AS ship_qty,
    SUM(IFNULL(order_qty,0)) AS order_qty,
    qcy_code,
    SUM(IFNULL(rev_sale_amt,0)) AS rev_sale_amt,
    SUM(IFNULL(rev_rst_amt,0)) AS rev_rst_amt,
    SUM(IFNULL(ship_amt,0)) AS ship_amt,
    SUM(IFNULL(order_amt,0)) AS order_amt,
    SUM(IFNULL(discount1_amt,0)) AS discount1_amt,
    SUM(IFNULL(discount3_amt,0)) AS discount3_amt,
    SUM(IFNULL(discount4_amt,0)) AS discount4_amt,
    SUM(IFNULL(discount5_amt,0)) AS discount5_amt,
    SUM(IFNULL(discount6_amt,0)) AS discount6_amt,
    SUM(IFNULL(discount30_amt,0)) AS discount30_amt,
    SUM(IFNULL(discount34_amt,0)) AS discount34_amt,
    SUM(IFNULL(cogs_amt,0)) AS cogs_amt,
    IFNULL(tax_rate,0) AS tax_rate,   
    IFNULL(price_tax_amt,0) AS price_tax_amt,  
    IFNULL(exchange_rate,0) AS exchange_rate,  
    system_src,
    ods_src,
    LTRIM(T1.sold_to_code,0) AS sold_to_code,
    sold_to_name,
    material_group_code,
    material_group_name,
    cp_company_code,
    batch_id,
    bill_dt,  
    material_pricing_group_code,
    material_pricing_group_name,
    acct_src_code,
    acct_map_code,
    now() load_dt,
    bill_type_code,
    order_type_code,
    general_ledger,
    record_type,
    init_object_type,
    cust_mdg_code,
    bus_range_code,
    bus_range_name,
    marketing_dept_code,
    marketing_dept_name,
    is_miniled_code,
    comm_bu_code,
    comm_bu_name,
    T1.profitcenter_code AS profitcenter_code,
    T1.profitcenter_name AS profitcenter_name,
    customer_model,
    zcalasset,
    cn_class_mark_code,
    cn_class_mark_name,
    sale_cert_type,
    SUM(IFNULL(T1.rev_sale_bcy_amt,0)) AS rev_sale_bcy_amt
	,cost_center_code  	--成本中心编码
	,cost_center_name	--成本中心名称
    ,SUM(IFNULL(t1.gfcfy_amount,0)) AS gfcfy_amount
	,SUM(IFNULL(t1.gfcfl_amount,0)) AS gfcfl_amount
    ,LTRIM(br_company_code,0) AS br_company_code
    ,fi.maktx_s810
    ,LTRIM(T1.src_profitcenter_code,0) AS src_profitcenter_code
    ,LTRIM(T1.src_bus_range_code,0) AS src_bus_range_code
    , bus_sce_cat_code --业务场景分类编码
	, bus_sce_cat_name --业务场景分类描述
	, transaction_type -- 事务类型
	/*20260520 新增miniled类型字段*/
    , miniled_type_code
    , miniled_type_name
    /*20260522如果公司是1180、12**，如果金税发票号存在有ZG的发票号，则放数据源的发票号，否则放空*/
	, CASE WHEN ((t1.company_code = '1180' or t1.company_code like '12%')  and t1.invoice_code like '%ZG%') THEN T1.invoice_code ELSE '' END AS invoice_code
 FROM dwd.dwd_fi_mr_gp_detail_mi T1
 LEFT JOIN (select matnr,maktx_mdm,profitcenter_code,profitcenter_name,maktx_s810,maktx_s600,maktx_s900,maktx_s800 from dim.dim_fi_mr_product_dd) fi on fi.matnr = T1.material_code
 LEFT JOIN (
    SELECT DISTINCT *
    FROM
    (
    SELECT 
        MI_SUB.DT_MONTH, MI_SUB.COMPANY_CODE, MI_SUB.MATERIAL_CODE, 
        MI_SUB.CUST_CODE, MI_SUB.SOLD_TO_CODE, MI_SUB.PROFITCENTER_CODE,
        1 as rule_flag
    FROM dwd.dwd_fi_mr_gp_detail_mi MI_SUB
    INNER JOIN (
        SELECT B.MATNR,CASE WHEN XC_FLAG.AAA LIKE '%下沉京东专供（XC01）%' THEN 'XC01' 
                            WHEN XC_FLAG.AAA LIKE '%下沉-线上苏宁零售云专供（XZ02）%' THEN 'XZ02'
                       ELSE '' END FLAG
        FROM ods.odscis_base_product_info A
        JOIN ods.odscis_base_product_info_matnr B ON A.PRODUCT_ID = B.PRODUCT_ID
        LEFT JOIN (
            SELECT '%下沉京东专供（XC01）%' AAA
            UNION ALL
            SELECT '%下沉-线上苏宁零售云专供（XZ02）%' AAA
        ) XC_FLAG 
        ON A.PRODUCT_LABEL_NAME LIKE XC_FLAG.AAA
        WHERE (A.PRODUCT_LABEL_NAME LIKE '%下沉京东专供（XC01）%' OR A.PRODUCT_LABEL_NAME LIKE '%下沉-线上苏宁零售云专供（XZ02）%')
    ) PROD ON MI_SUB.MATERIAL_CODE = PROD.MATNR
    INNER JOIN (
        SELECT COMPANY_CODE,SOLD_TO_CODE,PROFITCENTER_CODE, CUST_CODE,
               CASE WHEN SUPPLY_TYPE LIKE '%XC01%' THEN 'XC01'  
                    WHEN SUPPLY_TYPE LIKE '%XZ02%' THEN 'XZ02'
               ELSE '' END FLAG
        FROM dim.dim_rule_fi_mr_RevenueCost_Sinking WHERE MODEL_TYPE = '02'
        AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) RULE ON RULE.COMPANY_CODE = MI_SUB.company_code 
        AND RULE.CUST_CODE = ltrim(MI_SUB.CUST_CODE,0) 
        AND LTRIM(IFNULL(MI_SUB.SOLD_TO_CODE, MI_SUB.CUST_CODE),'0') = LTRIM(IFNULL(RULE.SOLD_TO_CODE, 0),'0')
        AND RULE.PROFITCENTER_CODE = ltrim(MI_SUB.PROFITCENTER_CODE,0)
        AND RULE.FLAG = PROD.FLAG
    WHERE MI_SUB.DT_MONTH = LEFT(@year_month_day,6)
    UNION ALL
    SELECT 
        MI_SUB.DT_MONTH, MI_SUB.COMPANY_CODE, MI_SUB.MATERIAL_CODE, 
        MI_SUB.CUST_CODE, MI_SUB.SOLD_TO_CODE, MI_SUB.PROFITCENTER_CODE,
        1 as rule_flag
    FROM dwd.dwd_fi_mr_gp_detail_mi MI_SUB
    INNER JOIN (
        SELECT * FROM dim.dim_rule_fi_mr_RevenueCost_Sinking WHERE MODEL_TYPE = '03'
        AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) RULE ON RULE.COMPANY_CODE = MI_SUB.company_code 
        AND RULE.CUST_CODE = ltrim(MI_SUB.CUST_CODE,0) 
        AND LTRIM(IFNULL(MI_SUB.SOLD_TO_CODE, MI_SUB.CUST_CODE),'0') = LTRIM(IFNULL(RULE.SOLD_TO_CODE, 0),'0')
        AND RULE.PROFITCENTER_CODE = ltrim(MI_SUB.PROFITCENTER_CODE,0)
    WHERE MI_SUB.DT_MONTH = LEFT(@year_month_day,6)
    ) A
 ) T2 ON CASE WHEN T1.company_code IN ('118A','118B','1181') THEN '1180' ELSE T1.company_code END = T2.COMPANY_CODE 
    AND T1.MATERIAL_CODE = T2.MATERIAL_CODE 
    AND T1.CUST_CODE = T2.CUST_CODE 
    AND IFNULL(T1.SOLD_TO_CODE,'') = IFNULL(T2.SOLD_TO_CODE,'')
    AND T1.PROFITCENTER_CODE = T2.PROFITCENTER_CODE
WHERE T1.dt_month = LEFT(@year_month_day,6)
  AND (T1.acct_map_code NOT LIKE '6051%' OR T1.acct_map_code IS NULL)
  /* AND ((t1.company_code not in (select elem from ods.odsfima_v_ref_azienda where hie= '10' and node = '200'))
		or (t1.company_code in (select elem from ods.odsfima_v_ref_azienda where hie= '10' and node = '200') and t1.invoice_code not like '%ZG%') 
	  )*/
GROUP BY
    T1.dt_month,
    year,
    month,
    CASE WHEN T1.company_code IN ('118A','118B','1181') THEN '1180' ELSE T1.company_code END,
    agency_code,
    agency_name,
    CASE WHEN REGEXP(LTRIM(T1.cust_code,0), '[一-龥]') THEN NULL ELSE LTRIM(T1.cust_code,0) END,
    material_code,
    shop_code,
    cust_name,
    cust_unity_name,
    credit_level_name,
    cust_nature_name,
    cust_type_name,
    channel_l1_code,
    channel_l1_name,
    channel_l2_code,
    channel_l2_name,
    channel_l3_code,
    channel_l3_name,
    marketing_mode_code,
    marketing_mode_name,
    channel_big_class_code,
    channel_big_class_name,
    channel_small_class_code,
    channel_small_class_name,
    ind_big_class_code,
    ind_big_class_name,
    ind_small_class_code,
    ind_small_class_name,
   CASE WHEN T2.rule_flag = 1 THEN '020_ON_003' ELSE onoffline_code END,
   CASE WHEN T2.rule_flag = 1 THEN '下沉' ELSE onoffline_name END,
    material_name,
    LTRIM(product_line_code,'0'),
    product_line_name,
    sale_model_code,
    sale_model_name,
    brand_code,
    brand_name,
    spec_section_code,
    spec_section_name,
    product_shape_type_code,
    product_shape_type_name,
    product_sale_series_code,
    product_sale_series_name,
    quarter_method_code,
    quarter_method_name,
    product_stage_code,
    product_stage_name,
    price_range_code,
    price_range_name,
    model_code,
    model_name,
    product_series_code,
    product_series_name,
    market_pnt_code,
    market_pnt_name,
    tech_type_code,
    tech_type_name,
    product_big_class_code,
    product_big_class_name,
    product_mid_class_code,
    product_mid_class_name,
    product_small_class_code,
    product_small_class_name,
    model_lca_code,
    model_lca_name,
    product_type_code,
    product_type_name,
    shop_name,
    qcy_code,
    IFNULL(tax_rate,0),   
    IFNULL(price_tax_amt,0),  
    IFNULL(exchange_rate,0),  
    system_src,
    ods_src,
    LTRIM(T1.sold_to_code,0),
    sold_to_name,
    material_group_code,
    material_group_name,
    cp_company_code,
    batch_id,
    bill_dt,  
    material_pricing_group_code,
    material_pricing_group_name,
    acct_src_code,
    acct_map_code,
    bill_type_code,
    order_type_code,
    general_ledger,
    record_type,
    init_object_type,
    cust_mdg_code,
    bus_range_code,
    bus_range_name,
    marketing_dept_code,
    marketing_dept_name,
    is_miniled_code,
    comm_bu_code,
    comm_bu_name,
    T1.profitcenter_code,
    T1.profitcenter_name,
    customer_model,
    zcalasset,
    cn_class_mark_code,
    cn_class_mark_name,
    sale_cert_type
    ,cost_center_code  	--成本中心编码
	,cost_center_name	--成本中心名称
    ,LTRIM(br_company_code,0)
    ,fi.maktx_s810
    ,LTRIM(T1.src_profitcenter_code,0)
    ,LTRIM(T1.src_bus_range_code,0)
    , bus_sce_cat_code --业务场景分类编码
, bus_sce_cat_name --业务场景分类描述
, transaction_type -- 事务类型
/*20260520 新增miniled类型字段*/
    , miniled_type_code
    , miniled_type_name
	, CASE WHEN ((t1.company_code = '1180' or t1.company_code like '12%')  and t1.invoice_code like '%ZG%') THEN T1.invoice_code ELSE '' END
    ;
