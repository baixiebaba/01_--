-- 调用20251101-->'20250501'年月日，日固定为01{{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}}最后一个insert需要修改分区，p2025056，p+年月+6

set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;


--set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';

/*为确保有分区不会报错，先插入一条数据*/
--INSERT INTO dwd.dwd_fi_mr_rev_acct_mi (dt_month) VALUES ('202601');
/***************************************************
alter by 20260818 xiaoaychao.ex 销售型号名称逻辑更新
****************************************************/
INSERT INTO dwd.dwd_fi_mr_rev_acct_mi (dt_month) VALUES (LEFT(@year_month_day,6));

INSERT OVERWRITE TABLE dwd.dwd_fi_mr_rev_acct_mi PARTITION (*)

--INSERT OVERWRITE TABLE dwd.dwd_fi_mr_rev_acct_mi PARTITION ({{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}})
(
  year, month, company_code, cust_code, policy_code, cust_name, cust_unity_name, credit_level_name, cust_nature_name, cust_type_name, channel_l1_code, channel_l1_name, channel_l2_code, channel_l2_name, channel_l3_code, channel_l3_name, marketing_mode_code, marketing_mode_name, channel_big_class_code, channel_big_class_name, channel_small_class_code, channel_small_class_name, ind_big_class_code, ind_big_class_name, ind_small_class_code, ind_small_class_name, onoffline_code, onoffline_name, product_line_code, product_line_name, qcy_code, base_amt, prize_amt, prize_rate, tax_rate, system_src, ods_src, invoice_id, cust_policy_code, data_l1_src, cash_l2_type, ledger_status, policy_start_dt, policy_end_dt, contract_code, contract_name, cash_l1_type, load_dt, dt_month,bus_range_code, policy_l1_type_code, policy_l1_type_name, policy_l2_type_code, policy_l2_type_name
,profitcenter_code, material_code, material_name, customer_model,marketing_dept_code
,cp_company_code,	
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
	model_name,
  comm_bu_code,
  comm_bu_name,
  cn_class_mark_code,
  cn_class_mark_name,
  is_small_b
  /*20260520 新增miniled类型字段*/
  ,miniled_type_code
  ,miniled_type_name
)
WITH  nf_map_1  AS 
(

  SELECT  batch_id AS xh -- 处理优先级
        ,logic_name AS lj -- 逻辑处理
        ,b.cod_azienda AS sales_group -- 公司包含
        ,c.cod_azienda AS ctp
        ,cust_code AS final_customer_code -- 客商包含
        ,cust_ex_code AS final_customer_code_out
        ,sold_to_code AS sold_to -- 售达方包含
        ,sold_to_ex_code AS sold_to_out
        ,product_line_src_code AS org_prctr_before -- 处理前利润中心
        ,onoffline_src_code AS nf_before
        ,onoffline_code AS nf
        ,onoffline_name AS nf_name
   FROM dim.dim_rule_fi_mr_nf_mapping a 
   LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
  WHERE valid_fr <=@year_month_day
    AND NVL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 

 ),
form_dati_ctp AS -- 匹配对方公司
 (
 SELECT cust_code AS kunrg -- 客商编码
       ,cp_company_code AS ctp -- 对方公司编码
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S600'
 )
SELECT 
       LEFT(yt_detail.period,4)                               AS year                      -- 财务年
     , RIGHT(yt_detail.period,2)                              AS month                     -- 财务月
     , yt_detail.sales_group                                  AS company_code              -- 组织
     , yt_detail.final_customer_code                          AS cust_code                 -- 客商编码
     , yt_detail.subject_code                                 AS policy_code               -- 政策编码
     , dim_customer_base_info_dd.cust_name                    AS cust_name                 -- 客商名称
     , dim_customer_base_info_dd.cust_unity_name              AS cust_unity_name           -- 统一客户组
     , dim_customer_base_info_dd.credit_level                 AS credit_level_name         -- 信用等级
     , dim_customer_base_info_dd.unit_nature_name             AS cust_nature_name          -- 单位性质
     , dim_customer_base_info_dd.cust_group_name              AS cust_type_name            -- 客户类型
     , dim_customer_base_info_dd.com_1st_code                 AS channel_l1_code           -- 销售渠道一级编码
     , dim_customer_base_info_dd.com_1st_name                 AS channel_l1_name           -- 销售渠道一级名称
     , dim_customer_base_info_dd.com_2nd_code                 AS channel_l2_code           -- 销售渠道二级编码
     , dim_customer_base_info_dd.com_2nd_name                 AS channel_l2_name           -- 销售渠道二级名称
     , CASE
           WHEN (CASE WHEN yt_detail.template_type = '1' AND yt_detail.policy_category_level2code = 'ZCLV0103'
                           THEN '020_ON_003'
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) IS NULL
                           THEN CASE WHEN yt_detail.template_type = '1' THEN '020_ON_002'
                                     WHEN yt_detail.template_type = '0' THEN '020_OFF_002'
                                     ELSE '' END
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) = 'NULL'
                           THEN NULL
                      ELSE COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf)
                 END) = '020_ON_003'
            AND yt_detail.sales_group IN ('2600', '6746', '6750', '6800', '6847')
            AND yt_detail.final_customer_code = '2031242'
           THEN 'E4'
           WHEN (CASE WHEN yt_detail.template_type = '1' AND yt_detail.policy_category_level2code = 'ZCLV0103'
                           THEN '020_ON_003'
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) IS NULL
                           THEN CASE WHEN yt_detail.template_type = '1' THEN '020_ON_002'
                                     WHEN yt_detail.template_type = '0' THEN '020_OFF_002'
                                     ELSE '' END
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) = 'NULL'
                           THEN NULL
                      ELSE COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf)
                 END) = '020_ON_003'
            AND yt_detail.sales_group IN ('2600', '6746', '6847')
            AND yt_detail.final_customer_code = '2030797'
           THEN 'F4'
           WHEN (CASE WHEN yt_detail.template_type = '1' AND yt_detail.policy_category_level2code = 'ZCLV0103'
                           THEN '020_ON_003'
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) IS NULL
                           THEN CASE WHEN yt_detail.template_type = '1' THEN '020_ON_002'
                                     WHEN yt_detail.template_type = '0' THEN '020_OFF_002'
                                     ELSE '' END
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) = 'NULL'
                           THEN NULL
                      ELSE COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf)
                 END) = '020_ON_003'
            AND yt_detail.sales_group IN ('2600', '6746', '6800')
            AND yt_detail.final_customer_code = '2018577'
           THEN 'F4'
           WHEN (yt_detail.sales_group IN ('1180', '118A', '118B', '1181') OR yt_detail.sales_group LIKE '12%')
            AND ecom_map.channel_code_l3 IS NOT NULL
           THEN ecom_map.channel_code_l3
           ELSE dim_customer_base_info_dd.com_3rd_code
       END                                                     AS channel_l3_code           -- 销售渠道三级编码
     , CASE
           WHEN (CASE WHEN yt_detail.template_type = '1' AND yt_detail.policy_category_level2code = 'ZCLV0103'
                           THEN '020_ON_003'
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) IS NULL
                           THEN CASE WHEN yt_detail.template_type = '1' THEN '020_ON_002'
                                     WHEN yt_detail.template_type = '0' THEN '020_OFF_002'
                                     ELSE '' END
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) = 'NULL'
                           THEN NULL
                      ELSE COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf)
                 END) = '020_ON_003'
            AND yt_detail.sales_group IN ('2600', '6746', '6750', '6800', '6847')
            AND yt_detail.final_customer_code = '2031242'
           THEN '京东专卖店'
           WHEN (CASE WHEN yt_detail.template_type = '1' AND yt_detail.policy_category_level2code = 'ZCLV0103'
                           THEN '020_ON_003'
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) IS NULL
                           THEN CASE WHEN yt_detail.template_type = '1' THEN '020_ON_002'
                                     WHEN yt_detail.template_type = '0' THEN '020_OFF_002'
                                     ELSE '' END
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) = 'NULL'
                           THEN NULL
                      ELSE COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf)
                 END) = '020_ON_003'
            AND yt_detail.sales_group IN ('2600', '6746', '6847')
            AND yt_detail.final_customer_code = '2030797'
           THEN '苏宁零售云线上'
           WHEN (CASE WHEN yt_detail.template_type = '1' AND yt_detail.policy_category_level2code = 'ZCLV0103'
                           THEN '020_ON_003'
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) IS NULL
                           THEN CASE WHEN yt_detail.template_type = '1' THEN '020_ON_002'
                                     WHEN yt_detail.template_type = '0' THEN '020_OFF_002'
                                     ELSE '' END
                      WHEN COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf) = 'NULL'
                           THEN NULL
                      ELSE COALESCE(form_dati_nf5.nf, form_dati_nf2.nf, form_dati_nf1.nf)
                 END) = '020_ON_003'
            AND yt_detail.sales_group IN ('2600', '6746', '6800')
            AND yt_detail.final_customer_code = '2018577'
           THEN '苏宁零售云线上'
           WHEN (yt_detail.sales_group IN ('1180', '118A', '118B', '1181') OR yt_detail.sales_group LIKE '12%')
            AND ecom_map.channel_code_l3 IS NOT NULL
           THEN ecom_map.channel_name_l3
           ELSE dim_customer_base_info_dd.com_3rd_name
       END                                                     AS channel_l3_name           -- 销售渠道三级名称
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
     , CASE WHEN yt_detail.template_type = '1'  AND yt_detail.policy_category_level2code = 'ZCLV0103'    
                        THEN '020_ON_003'       
            WHEN COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf) IS NULL 
              THEN (CASE WHEN yt_detail.template_type = '1'      
                        THEN '020_ON_002'
                      WHEN yt_detail.template_type = '0'      
                        THEN '020_OFF_002'
                      ELSE ''       
                  END)
          WHEN COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf) = 'NULL'
            THEN NULL 
          ELSE COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf)
     END                                                      AS onoffline_code            -- 线上线下编码
     , ''                                                     AS onoffline_name            -- 线上线下名称
     , yt_detail.product_category                             AS product_line_code         -- 产品线编码
     , yt_detail.product_category_name                        AS product_line_name         -- 产品线名称
     , ''                                                     AS qcy_code                  -- 货币-交易币
     , (IFNULL(yt_detail.base_money,0))                    AS base_amt                  -- 基数
     , (IFNULL(yt_detail.prize_money,0))                   AS prize_amt                 -- 奖励金额
     , yt_detail.prize_rate                                   AS prize_rate                -- 奖励率
     , yt_detail.tax_rate                                     AS tax_rate                  -- 税率
     , 'POLICY'                                               AS system_src                -- 源系统
     , 'POLICY_YT'                                            AS ods_src                   -- 源表
     , yt_detail.clearing_sheet_no                            AS invoice_id                -- 结算单编号
     , yt_detail.final_customer_code                             AS cust_policy_code          -- 政策_客户编码
     , ''                                                     AS data_l1_src               -- 一级数据源
     , ''                                                     AS cash_l2_type              -- 二级兑现方式
     , ''                                                     AS ledger_status             -- 台账状态
     , yt_detail.prize_begin                                  AS policy_start_dt           -- 政策期间开始日期
     , yt_detail.prize_end                                    AS policy_end_dt             -- 政策期间结束日期
     , yt_detail.contract_no                                  AS contract_code             -- 合同编号
     , yt_detail.activity_name                                AS contract_name             -- 合同名称
     , ''                                                     AS cash_l1_type              -- 一级兑现方式
     , NOW()                                                  AS load_dt                   -- 更新时间
     , yt_detail.period                                       AS dt_month                  -- 年月
	   , CASE WHEN IFNULL(TRIM(mt2bd.bus_range_code),'') <> ''
              THEN IFNULL(TRIM(mt2bd.bus_range_code),'')
            WHEN IFNULL(TRIM(yt_detail.business_scope),'') <> ''
              THEN TRIM(yt_detail.business_scope)
            ELSE ''
       END                                                    AS bus_range_code            -- 业务范围编码
     -- , yt_detail.business_scope                               AS bus_range_code            -- 业务范围编码
     , yt_detail.policy_category_level1code                   AS policy_l1_type_code       -- 政策一级分类编码
     , yt_detail.policy_category_level1                       AS policy_l1_type_name       -- 政策一级分类描述
     , yt_detail.policy_category_level2code                   AS policy_l2_type_code       -- 政策二级分类编码
     , yt_detail.policy_category_level2                       AS policy_l2_type_name       -- 政策二级分类描述
     , CASE WHEN IFNULL(mt2bd.profitcenter_code,mara.profitcenter_code) IS NULL 
               THEN yt_detail.profit_center 
            ELSE IFNULL(mt2bd.profitcenter_code,mara.profitcenter_code)
       END AS profitcenter_code         -- 利润中心编码
     , yt_detail.material_code                                AS material_code  
     , yt_detail.material_descrition                          AS material_name
     , mara.zcusmodel                                         AS customer_model
	   , CASE WHEN (SUBSTR(yt_detail.sales_group, 1, 2) IN ('62', '68') OR SUBSTR(yt_detail.sales_group, 1, 4) IN ('6012', '6015') 
                  OR ((SUBSTR(yt_detail.sales_group, 1, 2) = '12' OR SUBSTR(yt_detail.sales_group, 1, 4) IN ('1180','1183')) AND (mara.big_class_code = 'P02' OR yt_detail.material_code IS NULL))
                )
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,
                         Mapping_Bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN TRIM(yt_detail.product_category) IN ('1209901','1209905','G209901')
                              AND CASE WHEN IFNULL(TRIM(mt2bd.bus_range_code),'') <> ''
                                         THEN IFNULL(TRIM(mt2bd.bus_range_code),'')
                                       WHEN IFNULL(TRIM(yt_detail.business_scope),'') <> ''
                                         THEN TRIM(yt_detail.business_scope)
                                       ELSE ''
                                  END NOT IN ('2358','A004','2357')
                              THEN '1209901'
                              ELSE NULL
                         END,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA',''),
                         yt_detail.product_category
                         )
          ELSE '' 
     END AS marketing_dept_code
   , CASE WHEN form_dati_ctp.ctp IN ('4330','4320') AND yt_detail.sales_group = '6515' THEN CONCAT(form_dati_ctp.ctp,'A') ELSE form_dati_ctp.ctp END AS cp_company_code,
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
	mara.model_name	AS	model_name	,--	产品型号名称
    yt_detail.channel_segment AS comm_bu_code, -- 电商BU渠道细分编码
    yt_detail.channel_segment_name AS comm_bu_name, -- 电商BU渠道细分描述
    yt_detail.cn_category_code AS cn_class_mark_code,-- 中国区品类标记编码
    yt_detail.cn_category_name AS cn_class_mark_name,-- 中国区品类标记描述
    yt_detail.is_little_b_name AS is_small_b -- 是否小B业务
    /*20260520 新增miniled类型字段*/
    ,mara.miniled_type_code
    ,mara.miniled_type_name
 FROM (SELECT yt_detail.period
             ,yt_detail.sales_group
             ,LTRIM(yt_detail.final_customer_code,0) AS final_customer_code
             ,yt_detail.subject_code
             ,yt_detail.template_type
             ,yt_detail.product_category
             ,yt_detail.product_category_name
             ,SUM(IFNULL(yt_detail.base_money,0)) base_money
             ,SUM(IFNULL(yt_detail.prize_money,0)) prize_money
             ,yt_detail.prize_rate
             ,yt_detail.tax_rate
             ,yt_detail.clearing_sheet_no
             ,yt_detail.prize_begin
             ,yt_detail.prize_end
             ,yt_detail.contract_no
             ,yt_detail.activity_name
             ,yt_detail.business_scope
             ,yt_detail.policy_category_level1code
             ,yt_detail.policy_category_level1
             ,yt_detail.policy_category_level2code
             ,yt_detail.policy_category_level2
             ,yt_detail.profit_center
             ,yt_detail.material_code
             ,yt_detail.material_descrition
             ,yt_detail.channel_segment
             ,yt_detail.channel_segment_name
             ,yt_detail.cn_category_code
             ,yt_detail.cn_category_name
             ,yt_detail.is_little_b_name
         FROM ods.odsplc_v_hpms_yt_detail_gb yt_detail
        WHERE period = SUBSTR(@year_month_day,1,6)
          AND yt_detail.delete_flag <> 1
          AND NOT (yt_detail.sales_group = '6005' AND yt_detail.POLICY_LEVEL_FOUR_NAME LIKE '古洛尼费用%')
      GROUP BY yt_detail.period,yt_detail.sales_group,yt_detail.subject_code,yt_detail.template_type,yt_detail.product_category,yt_detail.product_category_name,yt_detail.prize_rate,yt_detail.tax_rate,yt_detail.clearing_sheet_no,LTRIM(yt_detail.final_customer_code,0),yt_detail.prize_begin,yt_detail.prize_end,yt_detail.contract_no,yt_detail.activity_name,yt_detail.business_scope,yt_detail.policy_category_level1code,yt_detail.policy_category_level1,yt_detail.policy_category_level2code,yt_detail.policy_category_level2,yt_detail.profit_center,yt_detail.material_code,yt_detail.material_descrition 
              ,yt_detail.channel_segment
              ,yt_detail.channel_segment_name
              ,yt_detail.cn_category_code
              ,yt_detail.cn_category_name
              ,yt_detail.is_little_b_name
      ) yt_detail
  LEFT JOIN (
        SELECT
            LTRIM(kunnr, 0) AS kunnr,
            MAX(zkunnr_mdg) AS zkunnr_mdg
        FROM ods.ods_slt_s600_kna1
        GROUP BY LTRIM(kunnr, 0)
      ) kna1
    ON yt_detail.final_customer_code = kna1.kunnr
 LEFT JOIN dw.dim_customer_base_info_dd 
   ON dim_customer_base_info_dd.cust_code = kna1.zkunnr_mdg
 LEFT JOIN (
        SELECT
            ecom_code,
            MAX(channel_code_l3) AS channel_code_l3,
            MAX(channel_name_l3) AS channel_name_l3
        FROM dim.dim_rule_fi_mr_ecom_channel3_mapping
        GROUP BY ecom_code
      ) ecom_map
   ON (yt_detail.sales_group IN ('1180', '118A', '118B', '1181') OR yt_detail.sales_group LIKE '12%')
  AND yt_detail.channel_segment = ecom_map.ecom_code
 LEFT JOIN (SELECT DISTINCT cust_code
                  ,sale_org
                  ,material_group_code
                  ,market_mode_code
                  ,market_mode_name 
              FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
   ON dim_customer_trade_info_dd.cust_code = kna1.zkunnr_mdg
  AND dim_customer_trade_info_dd.sale_org = yt_detail.sales_group
  AND dim_customer_trade_info_dd.material_group_code = yt_detail.product_category
 LEFT JOIN form_dati_ctp AS form_dati_ctp-- 匹配对方公司
   ON LTRIM(yt_detail.final_customer_code, '0') = LTRIM(form_dati_ctp.kunrg, '0')

 LEFT JOIN nf_map_1 form_dati_nf1-- 匹配线上线下映射表 按公司匹配
   ON 1=1
   -- 公司包含匹配
  AND yt_detail.sales_group = form_dati_nf1.sales_group
  AND form_dati_nf1.xh = '1'

 LEFT JOIN nf_map_1 form_dati_nf2-- 匹配线上线下映射表 按公司+客商匹配
   ON 1=1
  -- 公司包含匹配
  AND yt_detail.sales_group = form_dati_nf2.sales_group
  -- 客商匹配
  AND LTRIM(yt_detail.final_customer_code, '0') = form_dati_nf2.final_customer_code
  AND form_dati_nf2.xh = '2'
  LEFT JOIN nf_map_1 form_dati_nf5-- 匹配线上线下映射表 按公司+对方公司匹配
     ON 1=1
    -- 公司匹配
    AND yt_detail.sales_group = form_dati_nf5.sales_group
    -- 对方公司匹配
    AND form_dati_ctp.ctp = form_dati_nf5.ctp
    AND form_dati_nf5.xh = '5'
 LEFT JOIN dim.dim_fi_mr_product_dd mara -- 物料大表
   ON  yt_detail.material_code = mara.matnr
 LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
            WHERE 1=1
              AND a.valid_fr <= LEFT(@year_month_day,6)
              AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
          ) AS mt2bd
  ON yt_detail.material_code = mt2bd.material_code

    /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_AirConditioner_Materials_Mapping_Bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
			      AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus2
    ON yt_detail.material_code = Mapping_Bus2.MATERIAL_CODE
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_AirConditioner_Materials_Mapping_Bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
			      AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus1
    ON yt_detail.material_code = Mapping_Bus1.MATERIAL_CODE
   AND CASE WHEN IFNULL(TRIM(mt2bd.bus_range_code),'') <> ''
              THEN IFNULL(TRIM(mt2bd.bus_range_code),'')
            WHEN IFNULL(TRIM(yt_detail.business_scope),'') <> ''
              THEN TRIM(yt_detail.business_scope)
            ELSE ''
       END = Mapping_Bus1.bus_range_code

	--新增业务管理单元取数逻辑
  LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
			      AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON LTRIM(CASE WHEN IFNULL(mt2bd.profitcenter_code,mara.profitcenter_code) IS NULL 
               THEN yt_detail.profit_center 
            ELSE IFNULL(mt2bd.profitcenter_code,mara.profitcenter_code)
       END,'0') = profit_mapping0.profitcenter_code
   AND CASE WHEN IFNULL(TRIM(mt2bd.bus_range_code),'') <> ''
              THEN IFNULL(TRIM(mt2bd.bus_range_code),'')
            WHEN IFNULL(TRIM(yt_detail.business_scope),'') <> ''
              THEN TRIM(yt_detail.business_scope)
            ELSE ''
       END  = profit_mapping0.bus_range_code
  
  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
			      AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON TRIM(yt_detail.product_category) = TRIM(profit_mapping1.material_group_code)
   AND CASE WHEN IFNULL(TRIM(mt2bd.bus_range_code),'') <> ''
              THEN IFNULL(TRIM(mt2bd.bus_range_code),'')
            WHEN IFNULL(TRIM(yt_detail.business_scope),'') <> ''
              THEN TRIM(yt_detail.business_scope)
            ELSE ''
       END  = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
			      AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON TRIM(yt_detail.product_category) = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
			      AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON LTRIM(CASE WHEN IFNULL(mt2bd.profitcenter_code,mara.profitcenter_code) IS NULL 
               THEN yt_detail.profit_center 
            ELSE IFNULL(mt2bd.profitcenter_code,mara.profitcenter_code)
       END,'0') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
			      AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE WHEN IFNULL(TRIM(mt2bd.bus_range_code),'') <> ''
              THEN IFNULL(TRIM(mt2bd.bus_range_code),'')
            WHEN IFNULL(TRIM(yt_detail.business_scope),'') <> ''
              THEN TRIM(yt_detail.business_scope)
            ELSE ''
       END = profit_mapping4.bus_range_code
;


analyze table ods.odsplc_v_hpms_yt_detail_gb ;
analyze table dwd.dwd_fi_mr_rev_acct_mi ;
analyze table dim.dim_rule_fi_mr_nf_mapping ;
analyze table dim.dim_rule_fi_mr_cust2ctp_mapping ;
analyze table ods.ods_slt_s600_kna1 ;
analyze table dw.dim_customer_base_info_dd ;
analyze table dw.dim_customer_trade_info_dd ;
analyze table dim.dim_rule_fi_mr_mt2bd_mapping ;
analyze table dim.dim_rule_fi_mr_AirConditioner_Materials_Mapping_Bus ;
analyze table dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping ;

