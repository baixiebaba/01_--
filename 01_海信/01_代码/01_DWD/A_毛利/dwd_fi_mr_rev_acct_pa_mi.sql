/***************************************************
alter by 20260818 xiaoaychao.ex 销售型号名称逻辑更新
****************************************************/

/**************日立SMS及GSMS数据插入开始****************/

-- 调用@year_month_day-->'20250501'年月日，日固定为01，{{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}}最后一个insert需要修改分区，p2025056，p+年月+6

set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;

/*
analyze table ods.odsemp_sms_hac_hise_monthly_report_rl;
analyze table ods.odsfima_aw_rul_revaaz_000001;
analyze table ods.ods_slt_s700_kna1;
analyze table dw.dim_customer_base_info_dd;
analyze table dw.dim_customer_trade_info_dd;
analyze table ods.odss990_zmdgt138;
analyze table ods.ods_s700_tgsbt;
analyze table dim.dim_fi_mr_product_dd;
analyze table dim.dim_rule_fi_mr_cust_busrange_mappping;
analyze table dim.dim_rule_fi_mr_mt2bd_mapping;
analyze table ods.odsfima_aw_rul_revabs_000001;
analyze table dim.dim_rule_fi_mr_cust2ctp_mapping;
*/
set enable_auto_create_when_overwrite=true;

--set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';
/*为确保有分区不会报错，先插入一条数据*/
--INSERT INTO dwd.dwd_fi_mr_rev_acct_pa_mi (dt_month) VALUES ('202601');

--INSERT INTO dwd.dwd_fi_mr_rev_acct_pa_mi (dt_month) VALUES (LEFT(@year_month_day,6));

INSERT OVERWRITE TABLE dwd.dwd_fi_mr_rev_acct_pa_mi PARTITION (*)

--INSERT OVERWRITE TABLE dwd.dwd_fi_mr_rev_acct_pa_mi PARTITION ({{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}})
(
  year, month, company_code, cust_code, policy_code, cust_name, cust_unity_name, credit_level_name, cust_nature_name, cust_type_name, channel_l1_code, channel_l1_name, channel_l2_code, channel_l2_name, channel_l3_code
	, channel_l3_name, marketing_mode_code, marketing_mode_name, channel_big_class_code, channel_big_class_name, channel_small_class_code, channel_small_class_name, ind_big_class_code, ind_big_class_name, ind_small_class_code
	, ind_small_class_name, onoffline_code, onoffline_name, product_line_code, product_line_name, qcy_code, base_amt, prize_amt, prize_rate, tax_rate, system_src, ods_src, invoice_id, cust_policy_code, data_l1_src, cash_l2_type
	, ledger_status, policy_start_dt, policy_end_dt, contract_code, contract_name, cash_l1_type, load_dt, dt_month,bus_range_code, policy_l1_type_code, policy_l1_type_name, policy_l2_type_code, policy_l2_type_name
	, profitcenter_code, material_code, material_name, customer_model
	, gfcfy_amount          --价差转费用
	, gfcfl_amount          --费用转价差
	
	,marketing_dept_code 	--所属营销部门编码（业务管理单元编码）
	,marketing_dept_name   	--所属营销部门描述（业务管理单元描述）
	,cost_center_code  		--成本中心编码
	,cost_center_name		--成本中心名称
	,cp_company_code 		-- 对方公司
	,brand_code				-- 品牌编码
	,brand_name 			-- 品牌名称
	,	
	market_pnt_code,
	market_pnt_name,
	product_sale_series_code,
	product_sale_series_name,
	spec_section_code,
	spec_section_name,
	product_shape_type_code,
	product_shape_type_name,
	product_stage_code,
	product_stage_name,
	price_range_code,
	price_range_name,
	product_series_code,
	product_series_name,
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
	sale_model_code,
	sale_model_name,
	model_code,
	model_name

    /*20260520 新增miniled类型字段*/
    , miniled_type_code
    , miniled_type_name
)

SELECT
       year                              AS year                      -- 财务年
     , month                             AS month                     -- 财务月
     , revaaz.cod_azienda                AS company_code              -- 组织
     , sms.sales_code                    AS cust_code                 -- 客商编码
     , ''                                AS policy_code               -- 政策编码
     , ods_slt_s700_kna1.name1           AS cust_name                 -- 客商名称
     , dim_customer_base_info_dd.cust_unity_name              AS cust_unity_name           -- 统一客户组
     , dim_customer_base_info_dd.credit_level                 AS credit_level_name         -- 信用等级
     , dim_customer_base_info_dd.unit_nature_name             AS cust_nature_name          -- 单位性质
     , dim_customer_base_info_dd.cust_group_name              AS cust_type_name            -- 客户类型
     , dim_customer_base_info_dd.com_1st_code                 AS channel_l1_code           -- 销售渠道一级编码
     , dim_customer_base_info_dd.com_1st_name                 AS channel_l1_name           -- 销售渠道一级名称
     , dim_customer_base_info_dd.com_2nd_code                 AS channel_l2_code           -- 销售渠道二级编码
     , dim_customer_base_info_dd.com_2nd_name                 AS channel_l2_name           -- 销售渠道二级名称
     , dim_customer_base_info_dd.com_3rd_code                 AS channel_l3_code           -- 销售渠道三级编码（PA无下沉/电商BU，按MDG兜底）
     , dim_customer_base_info_dd.com_3rd_name                 AS channel_l3_name           -- 销售渠道三级名称（PA无下沉/电商BU，按MDG兜底）
     , dim_customer_trade_info_dd.market_mode_code            AS marketing_mode_code       -- 营销模式编码
     , dim_customer_trade_info_dd.market_mode_name            AS marketing_mode_name       -- 营销模式名称
     , dim_customer_base_info_dd.channel_big_class_code       AS channel_big_class_code    -- 渠道客户大类编码
     , dim_customer_base_info_dd.channel_big_class_name       AS channel_big_class_name    -- 渠道客户大类名称
     , dim_customer_base_info_dd.channel_small_class_code     AS channel_small_class_code  -- 渠道客户小类编码
     , dim_customer_base_info_dd.channel_small_class_name     AS channel_small_class_name  -- 渠道客户小类名称
     , dim_customer_base_info_dd.ind_big_class_code           AS ind_big_class_code        -- 行业大类编码
     , dim_customer_base_info_dd.ind_big_class_name           AS ind_big_class_name        -- 行业大类名称
     , dim_customer_base_info_dd.ind_small_class_code         AS ind_small_class_code      -- 行业小类编码
     , dim_customer_base_info_dd.ind_small_class_name         AS ind_small_class_name      -- 行业小类名称
     , case when sms.yw_scope = '电商部' then '020_ON_001' else '020_OFF_001' end as onoffline_code --线上线下编码
	 , case when sms.yw_scope = '电商部' then '线上公共' else '线下公共' end as onoffline_name              --线上线下名称
     , ''  AS product_line_code         -- 产品线编码
     , ''  AS product_line_name         -- 产品线名称
     , ''  AS qcy_code                  -- 货币-交易币
     , ''  AS base_amt                  -- 基数
     , SUM(IFNULL(sms.policy1,0) +IFNULL(sms.policy2,0) +IFNULL(sms.policy3,0) +IFNULL(sms.policy4,0)) AS prize_amt -- 奖励金额
     , ''  AS prize_rate                -- 奖励率
     , 0   AS tax_rate                  -- 税率
     , 'SMS' AS system_src              -- 源系统
     , 'POLICY_YT' AS ods_src              -- 源表
     , ''  AS invoice_id                -- 结算单编号
     , ''  AS cust_policy_code          -- 政策_客户编码
     , ''  AS data_l1_src               -- 一级数据源
     , ''  AS cash_l2_type              -- 二级兑现方式
     , ''  AS ledger_status             -- 台账状态
     , ''  AS policy_start_dt           -- 政策期间开始日期
     , ''  AS policy_end_dt             -- 政策期间结束日期
     , ''  AS contract_code             -- 合同编号
     , ''  AS contract_name             -- 合同名称
     , ''  AS cash_l1_type              -- 一级兑现方式
     , NOW() AS load_dt                 -- 更新时间
     , CONCAT(sms.year,sms.month) 							AS dt_month -- 年月
     , sms.yw_scopecode AS bus_range_code
     , ''  AS policy_l1_type_code       -- 政策一级分类编码
     , ''  AS policy_l1_type_name       -- 政策一级分类描述
     , ''  AS policy_l2_type_code       -- 政策二级分类编码
     , ''  AS policy_l2_type_name       -- 政策二级分类描述
     , CASE WHEN TRIM(sms.product_id) IS NOT NULL AND mara.product_type = 'FERT' THEN mara.profitcenter_code
            WHEN TRIM(sms.product_id) IS NOT NULL AND NVL(mara.product_type,'|') <> 'FERT' THEN '109087000'
            WHEN TRIM(sms.product_id) IS NULL THEN '190091000'
       END AS profitcenter_code       -- 利润中心编码
     --, mara.profitcenter_code AS profitcenter_code       -- 利润中心编码
     , sms.product_id                                		AS material_code  
     , mara.product_name                          				AS material_name
     , mara.zcusmodel                                   	AS customer_model
	 , SUM(sms.gfcfy_amount) as gfcfy_amount                    --价差转费用
	 , SUM(sms.gfcfl_amount) as gfcfl_amount                  --费用转价差
	 
/* 新加字段 */
	 ,sms.yw_manageunitcode AS marketing_dept_code        --所属营销部门编码（业务管理单元编码）
	 ,sms.yw_manageunit AS marketing_dept_name   --所属营销部门描述（业务管理单元描述）
	 ,CONCAT('S700_',revabs.cost_center_code) AS cost_center_code  	--成本中心编码
     ,revabs.cost_center_name AS cost_center_name	--成本中心名称
     ,dim_rule_fi_mr_cust2ctp_mapping.ctp AS cp_company_code -- 对方公司
	 ,mara.brand AS brand_code           				-- 品牌编码
     ,mara.brand_name AS brand_name        			-- 品牌名称
	 ,
    mara.market_pos_code	AS	market_pnt_code	,	--	营销定位编码
	mara.market_pos_name	AS	market_pnt_name	,	--	营销定位名称
	mara.prod_suite_code	AS	product_sale_series_code	,	--	产品套系编码
	mara.prod_suite_name	AS	product_sale_series_name	,	--	产品套系名称
	CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
		 WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
		 WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
		 WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
	END AS spec_section_code, -- 规格段编码
    CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
		 WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
		 WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
		 WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
	END  AS spec_section_name, -- 规格段名称
	mara.product_spec_code	AS	product_shape_type_code	,	--	产品形态分类编码
	mara.product_spec_name	AS	product_shape_type_name	,	--	产品形态分类名称
	mara.prod_stage_code	AS	product_stage_code	,	--	产品阶段编码
	mara.prod_stage_name	AS	product_stage_name	,	--	产品阶段名称
	mara.price_range_code	AS	price_range_code	,	--	价格段编码
	mara.price_range_name	AS	price_range_name	,	--	价格段名称
	mara.series_code	AS	product_series_code	,	--	产品系列编码
	mara.series_name	AS	product_series_name	,	--	产品系列名称
	mara.ac_ct_code	AS	tech_type_code	,	--	技术类型编码
	mara.ac_ct_name	AS	tech_type_name	,	--	技术类型名称
	mara.big_class_code	AS	product_big_class_code	,	--	产品大类编码
	mara.big_class_name	AS	product_big_class_name	,	--	产品大类名称
	mara.middle_class_code	AS	product_mid_class_code	,	--	产品中类编码
	mara.middle_class_name	AS	product_mid_class_name	,	--	产品中类名称
	mara.small_class_code	AS	product_small_class_code	,	--	产品小类编码
	mara.small_class_name	AS	product_small_class_name	,	--	产品小类名称
	mara.model_lca	AS	model_lca_code	,	--	产品型号生命周期编码
	mara.model_lca_name	AS	model_lca_name	,	--	产品型号生命周期名称
	mara.sale_model_code	AS	sale_model_code	,	--	销售型号编码
    /*alter by 20260818 xiaoaychao.ex 销售型号名称逻辑更新*/
	COALESCE(IF(TRIM(mara.sale_model_name) IN ('0', '无', ''),NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name	,	--	销售型号名称
	mara.model_code	AS	model_code	,	--	产品型号编码
	mara.model_name	AS	model_name		--	产品型号名称
        /*20260520 新增miniled类型字段*/
    , mara.miniled_type_code
    , mara.miniled_type_name
from( --sms销售明细-月
		select t.*
		  ,substring(kinvoice_date, 1, 4) as year
		  ,substring(kinvoice_date, 6, 2) as month
		from ods.odsemp_sms_hac_hise_monthly_report_rl t
		where 1 = 1
		AND kinvoice_date >= STR_TO_DATE(@year_month_day, '%Y%m%d')  -- 20251201 → 2025-12-01
		AND kinvoice_date < DATE_ADD(STR_TO_DATE(@year_month_day, '%Y%m%d'), INTERVAL 1 MONTH) 
		AND (policy1 is not null or policy2 is not null or policy3 is not null or policy4 is not null OR GFCFY_AMOUNT IS NOT NULL OR GFCFL_AMOUNT IS NOT NULL)
    )sms
--日立收入-公司映射
left join (select distinct ent_sap700_code,cod_azienda from ods.odsfima_aw_rul_revaaz_000001 UNION ALL SELECT '1745' AS ent_sap700_code,'1745' AS cod_azienda FROM DUAL) revaaz 
on sms.company_code = revaaz.ent_sap700_code
--客户主数据
left join (select DISTINCT ltrim(kunnr,'0') as kunnr,ltrim(zkunnr_mdg,'0') as zkunnr_mdg,name1 from ods.ods_slt_s700_kna1) ods_slt_s700_kna1
on sms.sales_code = ods_slt_s700_kna1.kunnr
--客户主数据基本信息
left join (select * from dw.dim_customer_base_info_dd) dim_customer_base_info_dd
ON ods_slt_s700_kna1.zkunnr_mdg = ltrim(dim_customer_base_info_dd.cust_code,'0')
--客户贸易信息
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
ON LTRIM(dim_customer_trade_info_dd.cust_code,'0') = LTRIM(sms.sales_code,'0')
AND dim_customer_trade_info_dd.sale_org = sms.company_code
--营销中心映射业务范围关系表
left join (select distinct gsber,vkbur from ods.odss990_zmdgt138) odss990_zmdgt138
ON dim_customer_base_info_dd.market_center_code = odss990_zmdgt138.vkbur
-- 业务范围主数据
left join (select distinct gsber,gtext from ods.ods_s700_tgsbt where spras = 1) tgsbt 
on odss990_zmdgt138.gsber = tgsbt.gsber 
-- 物料大表
left join (select * from dim.dim_fi_mr_product_dd) mara 
on sms.product_id = mara.matnr
LEFT JOIN dim.dim_rule_fi_mr_cust_busrange_mappping as cust_map
on sms.sales_code = cust_map.cust_code

LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
            WHERE 1=1
              AND a.valid_fr <= LEFT(@year_month_day,6)
              AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
          ) AS mt2bd
  ON sms.product_id = mt2bd.material_code
  
/* --日立收入-业务管理单元映射
LEFT JOIN 
  ( 
    select DISTINCT d_sale_dept,d_sale_dept_name 
    FROM ods.odsfima_aw_rul_revasa_000001
  ) revasa 
ON sms.yw_manageunit = revasa.d_sale_dept_name */

--公司和业务范围映射成本中心
LEFT JOIN (select distinct cod_dest3,cost_center_code,cost_center_name FROM ods.odsfima_aw_rul_revabs_000001 where usage_status = '保留') revabs
ON revabs.cod_dest3 = sms.yw_scopecode

left join--匹配对方公司
 (
 SELECT DISTINCT ltrim(cust_code,'0') AS kunrg -- 客商编码
       ,cp_company_code AS ctp -- 对方公司编码
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S700'
 )dim_rule_fi_mr_cust2ctp_mapping
ON sms.sales_code = dim_rule_fi_mr_cust2ctp_mapping.kunrg
group by year, month, revaaz.cod_azienda, sms.sales_code, ods_slt_s700_kna1.name1, dim_customer_base_info_dd.cust_unity_name, dim_customer_base_info_dd.credit_level, dim_customer_base_info_dd.unit_nature_name, dim_customer_base_info_dd.cust_group_name, dim_customer_base_info_dd.com_1st_code
     , dim_customer_base_info_dd.com_1st_name, dim_customer_base_info_dd.com_2nd_code, dim_customer_base_info_dd.com_2nd_name, dim_customer_base_info_dd.com_3rd_code, dim_customer_base_info_dd.com_3rd_name, dim_customer_trade_info_dd.market_mode_code
     , dim_customer_trade_info_dd.market_mode_name, dim_customer_base_info_dd.channel_big_class_code, dim_customer_base_info_dd.channel_big_class_name, dim_customer_base_info_dd.channel_small_class_code, dim_customer_base_info_dd.channel_small_class_name
	 , dim_customer_base_info_dd.ind_big_class_code, dim_customer_base_info_dd.ind_big_class_name, dim_customer_base_info_dd.ind_small_class_code, dim_customer_base_info_dd.ind_small_class_name
     , case when sms.yw_scope = '电商部' then '020_ON_001' else '020_OFF_001' end
	 , case when sms.yw_scope = '电商部' then '线上公共' else '线下公共' end
     , CONCAT(sms.year,sms.month)
     , sms.yw_scopecode
     , CASE WHEN TRIM(sms.product_id) IS NOT NULL AND mara.product_type = 'FERT' THEN mara.profitcenter_code
            WHEN TRIM(sms.product_id) IS NOT NULL AND NVL(mara.product_type,'|') <> 'FERT' THEN '109087000'
            WHEN TRIM(sms.product_id) IS NULL THEN '190091000'
       END
     , sms.product_id
     , mara.product_name
     , mara.zcusmodel
	 ,sms.yw_manageunitcode
	 ,sms.yw_manageunit
	 ,CONCAT('S700_',revabs.cost_center_code)
     ,revabs.cost_center_name
     ,dim_rule_fi_mr_cust2ctp_mapping.ctp
	 ,mara.brand
	 ,mara.brand_name,
    mara.market_pos_code	,	--	营销定位编码
	mara.market_pos_name	,	--	营销定位名称
	mara.prod_suite_code	,	--	产品套系编码
	mara.prod_suite_name	,	--	产品套系名称
	CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
		 WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
		 WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
		 WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
	END , -- 规格段编码
    CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
		 WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
		 WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
		 WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
	END , -- 规格段名称
	mara.product_spec_code,	--	产品形态分类编码
	mara.product_spec_name,	--	产品形态分类名称
	mara.prod_stage_code,	--	产品阶段编码
	mara.prod_stage_name,	--	产品阶段名称
	mara.price_range_code,	--	价格段编码
	mara.price_range_name,	--	价格段名称
	mara.series_code,	--	产品系列编码
	mara.series_name,	--	产品系列名称
	mara.ac_ct_code	,	--	技术类型编码
	mara.ac_ct_name,	--	技术类型名称
	mara.big_class_code,	--	产品大类编码
	mara.big_class_name,	--	产品大类名称
	mara.middle_class_code,	--	产品中类编码
	mara.middle_class_name,	--	产品中类名称
	mara.small_class_code,	--	产品小类编码
	mara.small_class_name,	--	产品小类名称
	mara.model_lca	,	--	产品型号生命周期编码
	mara.model_lca_name,	--	产品型号生命周期名称
	mara.sale_model_code,	--	销售型号编码
	COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) ,	--	销售型号名称
	mara.model_code	,	--	产品型号编码
	mara.model_name		--	产品型号名称
    /*20260520 新增miniled类型字段*/
    , mara.miniled_type_code
    , mara.miniled_type_name
HAVING SUM(IFNULL(sms.policy1,0) +IFNULL(sms.policy2,0) +IFNULL(sms.policy3,0) +IFNULL(sms.policy4,0)) <> 0 
		or SUM(sms.gfcfy_amount) <> 0 
		or SUM(sms.gfcfl_amount) <> 0 

UNION ALL
SELECT
       year                              AS year                      -- 财务年
     , month                             AS month                     -- 财务月
     , revaaz.cod_azienda                AS company_code              -- 组织
     , gsms.sales_code                    AS cust_code                 -- 客商编码
     , ''                                AS policy_code               -- 政策编码
     , ods_slt_s700_kna1.name1           AS cust_name                 -- 客商名称
     , dim_customer_base_info_dd.cust_unity_name              AS cust_unity_name           -- 统一客户组
     , dim_customer_base_info_dd.credit_level                 AS credit_level_name         -- 信用等级
     , dim_customer_base_info_dd.unit_nature_name             AS cust_nature_name          -- 单位性质
     , dim_customer_base_info_dd.cust_group_name              AS cust_type_name            -- 客户类型
     , dim_customer_base_info_dd.com_1st_code                 AS channel_l1_code           -- 销售渠道一级编码
     , dim_customer_base_info_dd.com_1st_name                 AS channel_l1_name           -- 销售渠道一级名称
     , dim_customer_base_info_dd.com_2nd_code                 AS channel_l2_code           -- 销售渠道二级编码
     , dim_customer_base_info_dd.com_2nd_name                 AS channel_l2_name           -- 销售渠道二级名称
     , dim_customer_base_info_dd.com_3rd_code                 AS channel_l3_code           -- 销售渠道三级编码（PA无下沉/电商BU，按MDG兜底）
     , dim_customer_base_info_dd.com_3rd_name                 AS channel_l3_name           -- 销售渠道三级名称（PA无下沉/电商BU，按MDG兜底）
     , dim_customer_trade_info_dd.market_mode_code            AS marketing_mode_code       -- 营销模式编码
     , dim_customer_trade_info_dd.market_mode_name            AS marketing_mode_name       -- 营销模式名称
     , dim_customer_base_info_dd.channel_big_class_code       AS channel_big_class_code    -- 渠道客户大类编码
     , dim_customer_base_info_dd.channel_big_class_name       AS channel_big_class_name    -- 渠道客户大类名称
     , dim_customer_base_info_dd.channel_small_class_code     AS channel_small_class_code  -- 渠道客户小类编码
     , dim_customer_base_info_dd.channel_small_class_name     AS channel_small_class_name  -- 渠道客户小类名称
     , dim_customer_base_info_dd.ind_big_class_code           AS ind_big_class_code        -- 行业大类编码
     , dim_customer_base_info_dd.ind_big_class_name           AS ind_big_class_name        -- 行业大类名称
     , dim_customer_base_info_dd.ind_small_class_code         AS ind_small_class_code      -- 行业小类编码
     , dim_customer_base_info_dd.ind_small_class_name         AS ind_small_class_name      -- 行业小类名称
     , '020_OFF_001' 										  AS onoffline_code --线上线下编码
	 , '线下公共'  												  AS onoffline_name              --线上线下名称
     , ''  AS product_line_code         -- 产品线编码
     , ''  AS product_line_name         -- 产品线名称
     , ''  AS qcy_code                  -- 货币-交易币
     , ''  AS base_amt                  -- 基数
     , SUM(IFNULL(gsms.fljtrmb,0)) AS prize_amt -- 奖励金额
     , ''  AS prize_rate                -- 奖励率
     , 0   AS tax_rate                  -- 税率
     , 'GSMS' AS system_src              -- 源系统
     , 'POLICY_YT' AS ods_src              -- 源表
     , ''  AS invoice_id                -- 结算单编号
     , ''  AS cust_policy_code          -- 政策_客户编码
     , ''  AS data_l1_src               -- 一级数据源
     , ''  AS cash_l2_type              -- 二级兑现方式
     , ''  AS ledger_status             -- 台账状态
     , ''  AS policy_start_dt           -- 政策期间开始日期
     , ''  AS policy_end_dt             -- 政策期间结束日期
     , ''  AS contract_code             -- 合同编号
     , ''  AS contract_name             -- 合同名称
     , ''  AS cash_l1_type              -- 一级兑现方式
     , NOW() AS load_dt                 -- 更新时间
     , CONCAT(gsms.year,gsms.month) 							AS dt_month -- 年月
	 
	   , gsms.business_scope_code as bus_range_code  -- 业务范围编码
	
     , ''  AS policy_l1_type_code       -- 政策一级分类编码
     , ''  AS policy_l1_type_name       -- 政策一级分类描述
     , ''  AS policy_l2_type_code       -- 政策二级分类编码
     , ''  AS policy_l2_type_name       -- 政策二级分类描述
     , CASE WHEN NVL(TRIM(gsms.product_id), '') <> '' AND mara.product_type = 'FERT' THEN mara.profitcenter_code
            WHEN NVL(TRIM(gsms.product_id), '') <> '' AND NVL(mara.product_type,'|') <> 'FERT' THEN '109087000'
            WHEN NVL(TRIM(gsms.product_id), '') = '' THEN '190091000'
       END AS profitcenter_code       -- 利润中心编码
     --, mara.profitcenter_code AS profitcenter_code       -- 利润中心编码
     , gsms.product_id                                		AS material_code  
     , mara.product_name                          				AS material_name
     , mara.zcusmodel                                   	AS customer_model
	 , SUM(IFNULL(gsms.trans_fee,0)) as gfcfy_amount                  --价差转费用
	 , SUM(IFNULL(gsms.trans_fee_rmb,0)) as gfcfl_amount                  --费用转价差
	 
/* 新加字段 */
	,gsms.bmu_code /* revasa.d_sale_dept */ AS marketing_dept_code        --所属营销部门编码（业务管理单元编码）
	,gsms.business_unit AS marketing_dept_name      --所属营销部门描述（业务管理单元描述）
	,CONCAT('S700_',gsms.costcentercode) as cost_center_code--成本中心编码
	,revabs.cost_center_name AS cost_center_name	--成本中心名称
	,dim_rule_fi_mr_cust2ctp_mapping.ctp AS cp_company_code -- 对方公司
	,gsms.brand_code AS brand_code           				-- 品牌编码
	,gsms.brand AS brand_name        			-- 品牌名称
	,
    mara.market_pos_code	AS	market_pnt_code	,	--	营销定位编码
	mara.market_pos_name	AS	market_pnt_name	,	--	营销定位名称
	mara.prod_suite_code	AS	product_sale_series_code	,	--	产品套系编码
	mara.prod_suite_name	AS	product_sale_series_name	,	--	产品套系名称
	CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
		 WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
		 WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
		 WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
	END AS spec_section_code, -- 规格段编码
    CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
		 WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
		 WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
		 WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
	END  AS spec_section_name, -- 规格段名称
	mara.product_spec_code	AS	product_shape_type_code	,	--	产品形态分类编码
	mara.product_spec_name	AS	product_shape_type_name	,	--	产品形态分类名称
	mara.prod_stage_code	AS	product_stage_code	,	--	产品阶段编码
	mara.prod_stage_name	AS	product_stage_name	,	--	产品阶段名称
	mara.price_range_code	AS	price_range_code	,	--	价格段编码
	mara.price_range_name	AS	price_range_name	,	--	价格段名称
	mara.series_code	AS	product_series_code	,	--	产品系列编码
	mara.series_name	AS	product_series_name	,	--	产品系列名称
	mara.ac_ct_code	AS	tech_type_code	,	--	技术类型编码
	mara.ac_ct_name	AS	tech_type_name	,	--	技术类型名称
	mara.big_class_code	AS	product_big_class_code	,	--	产品大类编码
	mara.big_class_name	AS	product_big_class_name	,	--	产品大类名称
	mara.middle_class_code	AS	product_mid_class_code	,	--	产品中类编码
	mara.middle_class_name	AS	product_mid_class_name	,	--	产品中类名称
	mara.small_class_code	AS	product_small_class_code	,	--	产品小类编码
	mara.small_class_name	AS	product_small_class_name	,	--	产品小类名称
	mara.model_lca	AS	model_lca_code	,	--	产品型号生命周期编码
	mara.model_lca_name	AS	model_lca_name	,	--	产品型号生命周期名称
	mara.sale_model_code	AS	sale_model_code	,	--	销售型号编码
	/*alter by 20260818 xiaoaychao.ex 销售型号名称逻辑更新*/
	COALESCE(IF(TRIM(mara.sale_model_name) IN ('0', '无', ''),NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS	sale_model_name	,	--	销售型号名称
	mara.model_code	AS	model_code	,	--	产品型号编码
	mara.model_name	AS	model_name		--	产品型号名称
    /*20260520 新增miniled类型字段*/
    , mara.miniled_type_code
    , mara.miniled_type_name
from( --gsms销售明细
	select t.* 
      ,substring(kinvoice_date, 1, 4) as year
      ,substring(kinvoice_date, 6, 2) as month
    from ods.odsemp_sms_hac_hhgj_monthly_report t
    where 1 = 1
    AND kinvoice_date >= STR_TO_DATE(@year_month_day, '%Y%m%d')  -- 20251201 → 2025-12-01
    AND kinvoice_date < DATE_ADD(STR_TO_DATE(@year_month_day, '%Y%m%d'), INTERVAL 1 MONTH)
	AND (fljtrmb is not null)
    )gsms
--日立收入-公司映射
LEFT JOIN (select DISTINCT ent_sap700_code,cod_azienda FROM ods.odsfima_aw_rul_revaaz_000001 UNION ALL SELECT '1745' AS ent_sap700_code,'1745' AS cod_azienda FROM DUAL) revaaz  
ON gsms.company_code = revaaz.ent_sap700_code
--客户主数据
left join (select DISTINCT ltrim(kunnr,'0') as kunnr,ltrim(zkunnr_mdg,'0') as zkunnr_mdg,name1 from ods.ods_slt_s700_kna1) ods_slt_s700_kna1
on gsms.sales_code = ods_slt_s700_kna1.kunnr
--客户主数据基本信息
left join (select * from dw.dim_customer_base_info_dd) dim_customer_base_info_dd
ON ods_slt_s700_kna1.zkunnr_mdg = ltrim(dim_customer_base_info_dd.cust_code,'0')
--客户贸易信息
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
ON LTRIM(dim_customer_trade_info_dd.cust_code,'0') = LTRIM(gsms.sales_code,'0')
AND dim_customer_trade_info_dd.sale_org = gsms.company_code
/* --营销中心映射业务范围关系表
left join (select distinct gsber,vkbur from ods.odss990_zmdgt138) odss990_zmdgt138
ON dim_customer_base_info_dd.market_center_code = odss990_zmdgt138.vkbur */
-- 业务范围主数据
LEFT JOIN (select distinct gsber,gtext FROM ods.ods_s700_tgsbt where spras = 1) tgsbt 
ON gsms.business_scope = tgsbt.gtext 
-- 物料大表
left join (select * from dim.dim_fi_mr_product_dd) mara 
on gsms.product_id = mara.matnr
LEFT JOIN dim.dim_rule_fi_mr_cust_busrange_mappping as cust_map
on gsms.sales_code = cust_map.cust_code

--日立收入-业务管理单元映射
LEFT JOIN 
  (
    select distinct d_sale_dept,d_sale_dept_name
    FROM ods.odsfima_aw_rul_revasa_000001
  ) revasa 
ON gsms.business_unit = revasa.d_sale_dept_name

--公司和业务范围映射成本中心
LEFT JOIN (select DISTINCT cost_center_code,cost_center_name FROM ods.odsfima_aw_rul_revabs_000001 where usage_status = '保留') revabs
ON revabs.cost_center_code = gsms.costcentercode

left join--匹配对方公司
 (
 SELECT DISTINCT ltrim(cust_code,'0') AS kunrg -- 客商编码
       ,cp_company_code AS ctp -- 对方公司编码
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S700'
 )dim_rule_fi_mr_cust2ctp_mapping
ON gsms.sales_code = dim_rule_fi_mr_cust2ctp_mapping.kunrg
group by year, month, revaaz.cod_azienda, gsms.sales_code, ods_slt_s700_kna1.name1, dim_customer_base_info_dd.cust_unity_name, dim_customer_base_info_dd.credit_level, dim_customer_base_info_dd.unit_nature_name, dim_customer_base_info_dd.cust_group_name, dim_customer_base_info_dd.com_1st_code
     , dim_customer_base_info_dd.com_1st_name, dim_customer_base_info_dd.com_2nd_code, dim_customer_base_info_dd.com_2nd_name, dim_customer_base_info_dd.com_3rd_code, dim_customer_base_info_dd.com_3rd_name, dim_customer_trade_info_dd.market_mode_code
     , dim_customer_trade_info_dd.market_mode_name, dim_customer_base_info_dd.channel_big_class_code, dim_customer_base_info_dd.channel_big_class_name, dim_customer_base_info_dd.channel_small_class_code, dim_customer_base_info_dd.channel_small_class_name
	 , dim_customer_base_info_dd.ind_big_class_code, dim_customer_base_info_dd.ind_big_class_name, dim_customer_base_info_dd.ind_small_class_code, dim_customer_base_info_dd.ind_small_class_name
     , CONCAT(gsms.year,gsms.month)
     , gsms.business_scope_code
     , CASE WHEN NVL(TRIM(gsms.product_id), '') <> '' AND mara.product_type = 'FERT' THEN mara.profitcenter_code
            WHEN NVL(TRIM(gsms.product_id), '') <> '' AND NVL(mara.product_type,'|') <> 'FERT' THEN '109087000'
            WHEN NVL(TRIM(gsms.product_id), '') = '' THEN '190091000'
       END
     , gsms.product_id
     , mara.product_name
     , mara.zcusmodel
	 
	 ,gsms.bmu_code /* revasa.d_sale_dept */
	 ,gsms.business_unit
	 ,CONCAT('S700_',gsms.costcentercode) 
	 ,revabs.cost_center_name
	 ,dim_rule_fi_mr_cust2ctp_mapping.ctp
	 ,gsms.brand_code
	 ,gsms.brand,
    mara.market_pos_code	,	--	营销定位编码
	mara.market_pos_name	,	--	营销定位名称
	mara.prod_suite_code	,	--	产品套系编码
	mara.prod_suite_name	,	--	产品套系名称
	CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
		 WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
		 WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
		 WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
	END , -- 规格段编码
    CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
		 WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
		 WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
		 WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
	END , -- 规格段名称
	mara.product_spec_code,	--	产品形态分类编码
	mara.product_spec_name,	--	产品形态分类名称
	mara.prod_stage_code,	--	产品阶段编码
	mara.prod_stage_name,	--	产品阶段名称
	mara.price_range_code,	--	价格段编码
	mara.price_range_name,	--	价格段名称
	mara.series_code,	--	产品系列编码
	mara.series_name,	--	产品系列名称
	mara.ac_ct_code	,	--	技术类型编码
	mara.ac_ct_name,	--	技术类型名称
	mara.big_class_code,	--	产品大类编码
	mara.big_class_name,	--	产品大类名称
	mara.middle_class_code,	--	产品中类编码
	mara.middle_class_name,	--	产品中类名称
	mara.small_class_code,	--	产品小类编码
	mara.small_class_name,	--	产品小类名称
	mara.model_lca	,	--	产品型号生命周期编码
	mara.model_lca_name,	--	产品型号生命周期名称
	mara.sale_model_code,	--	销售型号编码
	COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) 	,	--	销售型号名称
	mara.model_code	,	--	产品型号编码
	mara.model_name		--	产品型号名称
    /*20260520 新增miniled类型字段*/
    , mara.miniled_type_code
    , mara.miniled_type_name
HAVING SUM(IFNULL(gsms.fljtrmb,0)) <> 0 or SUM(IFNULL(gsms.trans_fee,0)) <> 0 or SUM(IFNULL(gsms.trans_fee_rmb,0)) <> 0

;

/**************日立SMS及GSMS数据插入结束****************/