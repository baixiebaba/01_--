set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;


--set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';

/*为确保有分区不会报错，先插入一条数据*/
--INSERT INTO dwd.dwd_fi_mr_rev_cis_mi (dt_month) VALUES ('202601');

INSERT INTO dwd.dwd_fi_mr_rev_cis_mi (dt_month) VALUES (LEFT(@year_month_day,6));

INSERT OVERWRITE TABLE dwd.dwd_fi_mr_rev_cis_mi PARTITION (*)

--INSERT OVERWRITE TABLE dwd.dwd_fi_mr_rev_cis_mi PARTITION ({{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}}) 
(dt_month,
    year,
    month,
    bd,bu,spart_code,spart_name,material_group_code,material_group_name,model_code,org_l3_code,org_l3_name,company_code,
	company_name,bus_range_code,bus_range_name,market_center_code,market_center_name,shop_cis_code,shop_mdg_name,
	shop_cis_name,store_cis_code,store_mdg_code,store_cis_name,sales_qty,standard_price_amt,rev_sale_amt,create_dt,shop_mdm_code,
	cust_code,cust_name,material_code,material_name,profitcenter_code,brand_code,brand_name,coproduction_flag,
	load_dt,
	material_pricing_group_code,
	spec_section_code,
	product_shape_type_code,
	product_stage_code,
	price_range_code,
	product_series_code,
	tech_type_code,
	is_miniled_code
      /*20260520 新增miniled类型字段*/
    , miniled_type_code
    , miniled_type_name
)

/* WITH SRC_PC AS 
(
	SELECT B.MATNR
	FROM ods.odscis_base_product_info A
	--JOIN ods.odscis_base_product_info_matnr B ON A.PRODUCT_ID = B.PRODUCT_ID
	WHERE (A.PRODUCT_LABEL_NAME LIKE '%下沉京东专供（XC01）%'
		OR A.PRODUCT_LABEL_NAME LIKE '%下沉-线上苏宁零售云专供（XZ02）%' )
) */

SELECT 
	LEFT(@year_month_day,6) as dt_month,
    LEFT(@year_month_day,4) as year,
    SUBSTR(@year_month_day, 5, 2) as month,
    S1.bd,
    S1.bu,
    S1.spart_code,
    S1.spart_name,
    S1.material_group_code,
    S1.material_group_name,
    S1.model_code,
    S1.org_l3_code,
    S1.org_l3_name,
    S1.company_code,
    S1.company_name,
    S1.bus_range_code,
    S1.bus_range_name,
    S1.market_center_code,
    S1.market_center_name,
    S1.shop_cis_code,
    S1.shop_mdg_name,
    S1.shop_cis_name,
    S1.store_cis_code,
    S1.store_mdg_code,
    S1.store_cis_name,
    S1.sales_qty,
    S1.standard_price_amt,
    S1.rev_sale_amt,
    S1.create_dt,
    S1.shop_mdm_code,
    S1.cust_code,
    S1.cust_name,
    S1.material_code,
    S1.material_name,
    S1.profitcenter_code,
    S1.brand_code,
    S1.brand_name,
    S2.coproduction_flag,
    S1.load_dt,
	'01' AS material_pricing_group_code,
	S1.spec_range_code AS spec_section_code,
	S1.product_spec_code AS product_shape_type_code,
	S1.prod_stage_code AS product_stage_code,
	S1.price_range_code AS price_range_code,
	S1.series_code AS product_series_code,
	S1.ac_ct_code AS tech_type_code,
	S1.is_miniled_code AS is_miniled_code,
    S1.miniled_type_code,
    S1.miniled_type_name
FROM(select 
	bd,
	bu,
	spart_code,
	spart_name,
	a.matkl_code as material_group_code,
	a.matkl_name as material_group_name,
	A.zzprdmodel as model_code,
	a.level3_org_code as org_l3_code,
	a.level3_org_name as org_l3_name,
	b.company_code AS company_code,
	b.company_name as company_name,
	b.BIZ_SCOPE_CODE as bus_range_code,
	b.BIZ_SCOPE_name as bus_range_name,
	a.market_center_code,
	a.market_center_name,
	a.cust_cis as shop_cis_code,
	a.cust_mdg as shop_mdg_name,
	a.cust_name as shop_cis_name,
	a.shop_cis as store_cis_code,
	a.shop_mdg as store_mdg_code,
	a.cis_shop_name as store_cis_name,
	a.sales_num as sales_qty,
	a.standard_price as standard_price_amt,
	a.total_standard_price as rev_sale_amt,
	a.create_date as create_dt,
	a.cust_mdm as shop_mdm_code,
	c.sap_cust_code as cust_code,
	c.sap_cust_name as cust_name,
	a.matnr as material_code,
	d.product_name as material_name,
	d.profitcenter_code as profitcenter_code,
	d.brand as brand_code,
	d.brand_name,
	NOW() LOAD_DT, /*更新时间*/
	CASE WHEN D.is_miniled_code = 'PC00013001' THEN '是'
		WHEN D.is_miniled_code = 'PC00013002' THEN '否'
		ELSE ''
	END AS is_miniled_code,
	D.prod_stage_code,
	D.series_code,
	D.ac_ct_code
      /*20260520 新增miniled类型字段*/
    , D.miniled_type_code
    , D.miniled_type_name

    , D.price_range_code
	, CASE WHEN D.big_class_code = 'P01' THEN D.SCREEN_SIZE_CODE
		 WHEN D.big_class_code = 'P02' THEN D.SPEC_RANGE_CODE
		 WHEN D.big_class_code = 'P03' THEN D.TOTAL_CAPACITY_CODE
		 WHEN D.big_class_code = 'P04' THEN D.WASHING_CAPACITY_CODE
	  END AS spec_range_code -- 规格段编码
    , D.product_spec_code

	from (SELECT * FROM ods.odscis_report_cust_standard_sales WHERE LEFT(SALE_DATE,6) = LEFT(@year_month_day,6))A
	-- 经分组织和业务范围编码和名称
	LEFT JOIN dim.dim_rule_fi_mr_CIS_SalesOrg_Company_BizScope_Mapping B
		 ON a.level3_org_code = b.ORG_CIS_CODE
		 AND b.valid_fr <= LEFT(@year_month_day,6)
			AND NVL(b.valid_to,'999999') >= LEFT(@year_month_day,6)
	-- sap客户编码和名称
	LEFT JOIN dim.dim_rule_fi_mr_CIS_MDM_SAPCUST_CODE C
		ON a.cust_mdm=c.CIS_MDM_CUST_CODE
		AND c.valid_fr <= LEFT(@year_month_day,6)
			AND NVL(c.valid_to,'999999') >= LEFT(@year_month_day,6)
	-- 物料大表取matnr,maktx_mdm,profitcenter_code,brand
	LEFT JOIN dim.dim_fi_mr_product_dd D
	  ON a.matnr = d.matnr
	)S1

	LEFT JOIN
	(SELECT DISTINCT  D.PROFITCENTER_CODE,D.CUST_CODE,D.company_code,'Y'AS coproduction_flag
		FROM dim.dim_rule_fi_mr_CIS_SalesOrg_Company_BizScope_Mapping A
			,dim.dim_rule_fi_mr_CIS_MDM_SAPCUST_CODE B
			,dim.dim_fi_mr_product_dd C
			,dim.dim_rule_fi_mr_RevenueCost_Sinking D
		  WHERE ltrim(C.PROFITCENTER_CODE,0)=ltrim(D.PROFITCENTER_CODE,0)
			AND B.sap_cust_code = D.cust_code
			AND a.company_code = D.company_code
			AND D.MODEL_TYPE = '01'
			AND A.valid_fr <= LEFT(@year_month_day,6)
			AND NVL(A.valid_to,'999999') >= LEFT(@year_month_day,6)
			AND B.valid_fr <= LEFT(@year_month_day,6)
			AND NVL(B.valid_to,'999999') >= LEFT(@year_month_day,6)
			AND D.valid_fr <= LEFT(@year_month_day,6)
			AND NVL(D.valid_to,'999999') >= LEFT(@year_month_day,6)
			/* and  c.maktx_mdm NOT IN (
				SELECT B.MATNR
				FROM ods.odscis_base_product_info A
				JOIN ods.odscis_base_product_info_matnr B ON A.PRODUCT_ID = B.PRODUCT_ID
				WHERE (A.PRODUCT_LABEL_NAME LIKE '%下沉京东专供（XC01）%'
					OR A.PRODUCT_LABEL_NAME LIKE '%下沉-线上苏宁零售云专供（XZ02）%' )
			) */
	)S2 ON ltrim(S1.PROFITCENTER_CODE,0)= ltrim(S2.PROFITCENTER_CODE,0)
		AND S1.cust_code = S2.CUST_CODE
		AND S1.company_code = S2.company_code