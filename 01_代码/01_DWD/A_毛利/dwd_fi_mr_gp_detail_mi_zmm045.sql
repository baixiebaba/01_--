-- ********************************************************************
-- 数据源18：退货未办退税【ods.ODSS600_ZTS600_ZMM045】
-- ==================================================================
-- 来源    ：DWD层整体设计-收入成本.xlsx / 1.2. DWD_FI_MR_GP_DETAIL_MI / FS~FZ列（源表18）
-- 新增时间：2026-07-28
-- 使用方式：本段落追加到 dwd_fi_mr_gp_detail_mi.sql 末尾（最后一段 ";" 之后）即可；
-- 若单独运行调试，直接执行本文件（已自带 set @year_month_day）。
-- 取数口径（FX9 匹配过滤，原文明细）：
-- - wadat_ist(发货过账日期) <= 参数年月
-- - dt_day(统计日期) / keydate(关键日期) = 参数年月的下一个月（年月限制参考PRD程序）
-- - reswk(发出工厂) = 2600
-- - werks(接收工厂) IN (1180, 12**, 1632)
-- - fkivp(发票状态) = 'A'
-- - wbstk(发货状态) = 'C'
-- - retpo(退货项目) = '√'
-- 字段口径：
-- - company_code(组织)/ship_fact_code(发货工厂) = reswk(发出工厂，恒2600)
-- - cp_company_code(对方公司) = werks(接收工厂)
-- - cust_code/sold_to_code：经 dim_rule_fi_mr_cust2ctp_mapping 由 werks(接收工厂)
-- 匹配 cp_company_code_mr(优先)/cp_company_code 取客商编码（映射表字段为 cust_code；
-- Excel 口径称 kunrg，生产 SQL 全文件统一用 cust_code；cust_type_code='C' AND system_src='S600'）
-- - ods_src = 'ZTSO04_TH_045'（FZ98备注：原 ZTMM018，20251209ZZS 修改为 ZTSO04_TH_045）
-- - 客商维度字段：kna1 取 zkunnr_mdg -> dw.dim_customer_base_info_dd 取对应字段
-- - 产品维度字段：dim.dim_fi_mr_product_dd（物料大表）匹配
-- - 物料需在物料大表范围内，不在则不进数（FS15，20260219ZZS）
-- - 营销模式沿用生产统一口径 dw.dim_customer_trade_info_dd.market_mode_code/name
-- （Excel 原设计为 MDG 主数据 mode_code，生产各段落均用交易信息表口径，保持一致）
-- - bus_range_code：20260714 SXX补充（该优先级最高）：本方公司2开头且对方公司2023时取物料大表prod_data.bus_range_code；
-- 否则 ①vbap销售行项目GSBER -> ③公司对应业务范围映射(bus_range_map2) -> ELSE ''（与生产zsd020/vbrk/ztmm018段一致）；
-- Excel②公司+销售组织映射(BUZScope_Mapping)因ZMM045无vkorg/vkbur且agency_code='无'无法匹配，跳过（与生产ztmm018段一致）
-- - 放空字段已全部删除（2026-08-12）：agency_code/agency_name、product_line_code/name、quarter_method_code/name、
-- qcy_code、material_pricing_group_code/name、bus_range_name、marketing_dept_code、comm_bu_code/name、
-- cn_class_mark_code/name、br_company_code、src_profitcenter_code、src_bus_range_code
-- （Excel 定义"无/放空"，无实际取值意义，INSERT/SELECT 两侧同步移除）
-- ********************************************************************

set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;
-- set @year_month_day = '20260301' ;
-- set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';

INSERT INTO dwd.dwd_fi_mr_gp_detail_mi
(
  dt_month,  --  年月
  year,  --  财务年
  month,  --  财务月
  company_code,  --  组织（发出工厂reswk）
  cust_code,  --  客商编码（werks反查kunrg）
  material_code,  --  物料编码
  material_name,  --  物料名称
  cust_name,  --  客商名称
  cust_unity_name,  --  统一客户组
  credit_level_name,  --  信用等级
  cust_nature_name,  --  单位性质
  cust_type_name,  --  客户类型
  channel_l1_code,  --  销售渠道一级编码
  channel_l1_name,  --  销售渠道一级名称
  channel_l2_code,  --  销售渠道二级编码
  channel_l2_name,  --  销售渠道二级名称
  channel_l3_code,  --  销售渠道三级编码
  channel_l3_name,  --  销售渠道三级名称
  marketing_mode_code,  --  销售模式编码
  marketing_mode_name,  --  销售模式名称
  onoffline_code,  --  线上线下编码
  onoffline_name,  --  线上线下名称
  sale_model_code,  --  销售型号编码
  sale_model_name,  --  销售型号名称
  brand_code,  --  品牌编码
  brand_name,  --  品牌名称
  spec_section_code,  --  规格段编码
  spec_section_name,  --  规格段名称
  product_shape_type_code,  --  产品形态分类编码
  product_shape_type_name,  --  产品形态分类名称
  product_sale_series_code,  --  产品套系编码
  product_sale_series_name,  --  产品套系名称
  product_stage_code,  --  产品阶段编码
  product_stage_name,  --  产品阶段名称
  price_range_code,  --  价格段编码
  price_range_name,  --  价格段名称
  model_code,  --  产品型号编码
  model_name,  --  产品型号名称
  product_series_code,  --  产品系列编码
  product_series_name,  --  产品系列名称
  market_pnt_code,  --  营销定位编码
  market_pnt_name,  --  营销定位名称
  tech_type_code,  --  技术类型编码
  tech_type_name,  --  技术类型名称
  is_miniled_code,
  product_big_class_code,  --  产品大类编码
  product_big_class_name,  --  产品大类名称
  product_mid_class_code,  --  产品中类编码
  product_mid_class_name,  --  产品中类名称
  product_small_class_code,  --  产品小类编码
  product_small_class_name,  --  产品小类名称
  model_lca_code,  --  产品型号生命周期编码
  model_lca_name,  --  产品型号生命周期名称
  product_type_code,  --  产品类型编码
  product_type_name,  --  产品类型名称
  bill_qty,  --  开票销量（退货数量sjsl）
  rev_sale_amt,  --  销售收入
  tax_rate,  --  税率（默认0）
  system_src,  --  源系统
  ods_src,  --  源表
  material_group_code,  --  物料组
  material_group_name,  --  物料组名称
  cp_company_code,  --  对方公司（接收工厂werks）
  batch_id,  --  批次号
  bill_dt,  --  发票日期
  create_dt,  --  创建日期
  asap_dt,  --  ASAP日期
  load_dt,
  cust_mdg_code,  --  客商编码mdg
  profitcenter_code,  --  利润中心编码
  profitcenter_name,  --  利润中心名称
  customer_model,  --  客户型号
  zcalasset,  --  按套统计
  bus_range_code,  --  业务范围编码
  rev_sale_bcy_amt,  --  销售收入-本位币
  ship_fact_code,  --  发货工厂
  sold_to_code,  --  售达方
  sold_to_name,  --  售达方名称
  channel_big_class_code,
  channel_big_class_name,
  channel_small_class_code,
  channel_small_class_name,
  ind_big_class_code,
  ind_big_class_name,
  ind_small_class_code,
  ind_small_class_name,
  /*20260520 新增miniled类型字段*/
  miniled_type_code,  --  miniled类型编码
  miniled_type_name   --  miniled类型名称
)
WITH cust_data AS (
/*映射客商主数据*/
SELECT cust_code,
     cust_name, --  客商名称
     cust_unity_name, --  统一客户组
     credit_level, --  信用等级
     unit_nature_name, --  单位性质
     cust_group_name, --  客户类型
     is_channel_cust_type,
     is_ent_cust_type,
     is_fi_cust_type,
     com_1st_code, --  销售渠道一级编码
     com_1st_name, --  销售渠道一级名称
     com_2nd_code, --  销售渠道二级编码
     com_2nd_name, --  销售渠道二级名称
     com_3rd_code, --  销售渠道三级编码
     com_3rd_name, --  销售渠道三级名称
     channel_big_class_code,
     channel_big_class_name,
     channel_small_class_code,
     channel_small_class_name,
     ind_big_class_code,
     ind_big_class_name,
     ind_small_class_code,
     ind_small_class_name
  FROM dw.dim_customer_base_info_dd
),
yx_data AS (
  /*映射销售模式*/
SELECT DISTINCT LTRIM(cust_code,'0') cust_code,
       sale_org,
       material_group_code,
       market_mode_code, --  销售模式编码
       market_mode_name  --  销售模式名称
  FROM dw.dim_customer_trade_info_dd
),
pro_type AS (
  /* 获取产品类型 */
 SELECT *
  FROM dim.dim_rule_fi_mr_batch2protype_mapping a
 WHERE valid_fr <= @year_month_day
   AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m')
),
prod_data AS (
/*映射产品主数据 未入湖*/
SELECT matnr,
       prod_line,
       dim_fi_mr_product_dd.product_name AS maktx_mdm,
       prod_line_name,
       COALESCE(IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
            ) AS sale_model_code,
       sale_model_name,
       prod_stage_code,
       prod_stage_name,
       model_code,
       model_name,
       series_code,
       series_name,
       product_pos,
       product_pos_name,
       big_class_code,
       big_class_name,
       middle_class_code,
       middle_class_name,
       small_class_code,
       small_class_name,
       model_lca,
       model_lca_name,
       prod_suite_code, --  产品套系编码
       prod_suite_name, --  产品套系名称
       market_pos_code,
       market_pos_name,
       ac_ct_code,
       ac_ct_name,
       uled_type_code,
       uled_type_name,
       CASE WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013001' THEN '是'
         WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013002' THEN '否'
         ELSE ''
       END AS is_miniled_code,
       is_miniled_name
      ,profitcenter_code
      ,profitcenter_name
      ,zcusmodel
      ,zcalasset
      ,brand
      ,brand_name
      ,miniled_type_code
      ,miniled_type_name
      ,spec_range_code
      ,spec_range_name
      ,product_spec_code
      ,product_spec_name
      ,price_range_code
      ,price_range_name
    ,SCREEN_SIZE_CODE
    ,TOTAL_CAPACITY_CODE
    ,WASHING_CAPACITY_CODE
    ,SCREEN_SIZE_NAME
    ,TOTAL_CAPACITY_NAME
    ,WASHING_CAPACITY_NAME
    ,bus_range_code
  FROM dim.dim_fi_mr_product_dd
),
onoff_data AS (
/*详细逻辑-线上线下优先级1*/
SELECT batch_id,--  优先级
       b.cod_azienda AS company_code,--  公司
       cust_code,--  客商编码
       cust_ex_code,--  剔除 客商
       sold_to_code,--  售达方
       sold_to_ex_code,--  剔除 售达方
       c.cod_azienda AS cp_company_code,--  CTP
       product_line_src_code,--  映射前利润中心
       CASE WHEN onoffline_code = 'NULL' THEN '' ELSE onoffline_code END AS onoffline_code, --  映射后NF
       onoffline_name
  FROM dim.dim_rule_fi_mr_nf_mapping a
  LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
 WHERE valid_fr <= @year_month_day
   AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m')
 ),
 ctp_data AS (
 /*映射客商：对方公司(接收工厂werks) -> 客商编码  --Excel FS14/FS107
   当 cp_company_code_mr(管报)不为空时按 werks 匹配 cp_company_code_mr，
   否则按 werks 匹配 cp_company_code，取客商编码（映射表字段为 cust_code，
   Excel 口径称 kunrg；生产 SQL 全文件统一用 cust_code）*/
 SELECT LTRIM(cust_code,'0') AS cust_code
       ,COALESCE(cp_company_code_mr,cp_company_code) AS cp_company_code
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping
  WHERE cust_type_code = 'C'
    AND system_src = 'S600'
 ),
zmm045 AS --  退货未办退税报表
 (SELECT SUBSTR(@year_month_day,0,6) dt_month
       ,Z.werks
       ,Z.reswk
       ,Z.matnr
       ,Z.charg
       ,Z.sjsl
       ,Z.dmbtr2
       ,Z.aedat
       ,Z.wadat_ist
       ,Z.wgbez --  物料组名称（Excel R110 直接对应）
    FROM ods.ODSS600_ZTS600_ZMM045 Z
   WHERE 1=1
     /*FX9 限制条件：wadat_ist<=参数年月；dt_day/keydate=参数年月的下一个月*/
     AND DATE_FORMAT(WADAT_IST,'%Y%m') <= LEFT(@year_month_day,6)
     AND STR_TO_DATE(DT_DAY, '%Y%m%d') = ADD_MONTHS(TO_DATE(@year_month_day),1)
     AND KEYDATE = ADD_MONTHS(TO_DATE(@year_month_day),1)
     AND Z.reswk = '2600' --  发出工厂
     AND (Z.werks IN ('1180','1632') OR Z.werks LIKE '12%') --  接收工厂
     AND Z.fkivp = 'A' --  发票状态
     AND Z.wbstk = 'C' --  发货状态
     AND Z.retpo = 'X' --  退货项目
     /*FS15 物料须在物料大表范围内，否则不进数*/
     AND Z.matnr IN (SELECT matnr FROM prod_data)
 )

SELECT
   zmm045.dt_month AS dt_month,  --  年月
   LEFT(zmm045.dt_month,4) AS year,  --  财务年
   RIGHT(zmm045.dt_month,2) AS month,  --  财务月
   zmm045.reswk AS company_code,  --  组织（发出工厂）
   ctp_data.cust_code AS cust_code,  --  客商编码（werks反查kunrg）
   zmm045.matnr AS material_code,  --  物料编码
   prod_data.maktx_mdm AS material_name,  --  物料名称
   kna1.name1 AS cust_name,  --  客商名称
   cust_data.cust_unity_name AS cust_unity_name,  --  统一客户组
   cust_data.credit_level AS credit_level_name,  --  信用等级
   cust_data.unit_nature_name AS cust_nature_name,  --  单位性质
   CASE WHEN cust_data.is_channel_cust_type IS NULL
        AND cust_data.is_ent_cust_type IS NULL
        AND cust_data.is_fi_cust_type IS NULL
        THEN NULL
        ELSE TRIM(
             REGEXP_REPLACE(
                 CONCAT_WS(',',
                          CASE WHEN cust_data.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                          CASE WHEN cust_data.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                          CASE WHEN cust_data.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                 ),
                 '(^,)|(,$)',
                 ''
             )
        )
   END AS cust_type_name,  --  客户类型
   cust_data.com_1st_code AS channel_l1_code,  --  销售渠道一级编码
   cust_data.com_1st_name AS channel_l1_name,  --  销售渠道一级名称
   cust_data.com_2nd_code AS channel_l2_code,  --  销售渠道二级编码
   cust_data.com_2nd_name AS channel_l2_name,  --  销售渠道二级名称
   cust_data.com_3rd_code AS channel_l3_code,  --  销售渠道三级编码
   cust_data.com_3rd_name AS channel_l3_name,  --  销售渠道三级名称
   yx_data.market_mode_code AS marketing_mode_code,  --  销售模式编码
   yx_data.market_mode_name AS marketing_mode_name,  --  销售模式名称
   /*线上线下：Excel 中国区(cn_onoffline_map)/工程(kondm)/内配外售(2052,2053)等特殊分支
   仅适用 1180/12*、2052/2053 等公司且有定价组字段的场景；本数据源发出工厂恒2600、
   无 vkorg/kondm，故仅保留经分项目收入模块规则映射表(nf_mapping)1~6级匹配+兜底020_OFF_002*/
   COALESCE(onoff_data6.onoffline_code,onoff_data5.onoffline_code,onoff_data4.onoffline_code,onoff_data3.onoffline_code,onoff_data2.onoffline_code,onoff_data1.onoffline_code,'020_OFF_002') AS onoffline_code,  --  线上线下编码
   COALESCE(onoff_data6.onoffline_name,onoff_data5.onoffline_name,onoff_data4.onoffline_name,onoff_data3.onoffline_name,onoff_data2.onoffline_name,onoff_data1.onoffline_name,'020_OFF_002') AS onoffline_name,  --  线上线下名称
   prod_data.sale_model_code AS sale_model_code,  --  销售型号编码
   prod_data.sale_model_name AS sale_model_name,  --  销售型号名称
   prod_data.brand AS brand_code,  --  品牌编码
   prod_data.brand_name AS brand_name,  --  品牌名称
   CASE WHEN prod_data.big_class_code = 'P01' THEN prod_data.SCREEN_SIZE_CODE
        WHEN prod_data.big_class_code = 'P02' THEN prod_data.SPEC_RANGE_CODE
        WHEN prod_data.big_class_code = 'P03' THEN prod_data.TOTAL_CAPACITY_CODE
        WHEN prod_data.big_class_code = 'P04' THEN prod_data.WASHING_CAPACITY_CODE
   END AS spec_section_code,  --  规格段编码
   CASE WHEN prod_data.big_class_code = 'P01' THEN prod_data.SCREEN_SIZE_NAME
        WHEN prod_data.big_class_code = 'P02' THEN prod_data.SPEC_RANGE_NAME
        WHEN prod_data.big_class_code = 'P03' THEN prod_data.TOTAL_CAPACITY_NAME
        WHEN prod_data.big_class_code = 'P04' THEN prod_data.WASHING_CAPACITY_NAME
   END AS spec_section_name,  --  规格段名称
   prod_data.product_spec_code AS product_shape_type_code,  --  产品形态分类编码
   prod_data.product_spec_name AS product_shape_type_name,  --  产品形态分类名称
   prod_data.prod_suite_code AS product_sale_series_code,  --  产品套系编码
   prod_data.prod_suite_name AS product_sale_series_name,  --  产品套系名称
   prod_data.prod_stage_code AS product_stage_code,  --  产品阶段编码
   prod_data.prod_stage_name AS product_stage_name,  --  产品阶段名称
   prod_data.price_range_code AS price_range_code,  --  价格段编码
   prod_data.price_range_name AS price_range_name,  --  价格段名称
   prod_data.model_code AS model_code,  --  产品型号编码
   prod_data.model_name AS model_name,  --  产品型号名称
   prod_data.series_code AS product_series_code,  --  产品系列编码
   prod_data.series_name AS product_series_name,  --  产品系列名称
   prod_data.market_pos_code AS market_pnt_code,  --  营销定位编码
   prod_data.market_pos_name AS market_pnt_name,  --  营销定位名称
   prod_data.ac_ct_code AS tech_type_code,  --  技术类型编码
   prod_data.ac_ct_name AS tech_type_name,  --  技术类型名称
   prod_data.is_miniled_code AS is_miniled_code,
   prod_data.big_class_code AS product_big_class_code,  --  产品大类编码
   prod_data.big_class_name AS product_big_class_name,  --  产品大类名称
   prod_data.middle_class_code AS product_mid_class_code,  --  产品中类编码
   prod_data.middle_class_name AS product_mid_class_name,  --  产品中类名称
   prod_data.small_class_code AS product_small_class_code,  --  产品小类编码
   prod_data.small_class_name AS product_small_class_name,  --  产品小类名称
   prod_data.model_lca AS model_lca_code,  --  产品型号生命周期编码
   prod_data.model_lca_name AS model_lca_name,  --  产品型号生命周期名称
   pro_type.product_type_code AS product_type_code,  --  产品类型编码
   pro_type.product_type_name AS product_type_name,  --  产品类型名称
   IFNULL(zmm045.sjsl,0) AS bill_qty,  --  开票销量（退货数量）
   IFNULL(zmm045.dmbtr2,0) AS rev_sale_amt,  --  销售收入
   0 AS tax_rate,  --  税率（默认0）
   'S600' AS system_src,  --  源系统
   'ZTSO04_TH_045' AS ods_src,  --  源表（原ZTMM018，20251209起更名）
   REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') AS material_group_code,  --  物料组
   zmm045.wgbez AS material_group_name,  --  物料组名称
   zmm045.werks AS cp_company_code,  --  对方公司（接收工厂）
   zmm045.charg AS batch_id,  --  批次号
   zmm045.aedat AS bill_dt,  --  发票日期
   zmm045.aedat AS create_dt,  --  创建日期
   zmm045.wadat_ist AS asap_dt,  --  ASAP日期
   NOW() AS load_dt,
   kna1.zkunnr_mdg AS cust_mdg_code,  --  客商编码mdg
   CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE prod_data.profitcenter_code END AS profitcenter_code,  --  利润中心编码
   CASE WHEN mt2bd.profitcenter_name IS NOT NULL THEN mt2bd.profitcenter_name ELSE prod_data.profitcenter_name END AS profitcenter_name,  --  利润中心名称
   COALESCE(if(upper(prod_data.sale_model_name)='无',null,upper(prod_data.sale_model_name)),if(upper(prod_data.zcusmodel)='无',null,upper(prod_data.zcusmodel))) AS customer_model,  --  客户型号
   prod_data.zcalasset AS zcalasset,  --  按套统计
   CASE WHEN zmm045.reswk LIKE '2%' AND zmm045.werks = '2023'
        THEN prod_data.bus_range_code  --  20260714 SXX补充（该优先级最高）：本方公司2开头且对方公司2023，业务范围取物料大表
        WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> '' THEN TRIM(bus_range_map2.bus_range_code_order) --  ③公司对应业务范围映射（Excel②公司+销售组织映射因无vkorg/vkbur、agency_code='无'无法匹配，跳过，与生产ztmm018段一致）
        ELSE '' --  与生产 zsd020/vbrk/ztmm018 段一致（20260128SXX 修改后不再默认 2000）
   END AS bus_range_code,  --  业务范围编码
   IFNULL(zmm045.dmbtr2,0) AS rev_sale_bcy_amt,  --  销售收入-本位币
   zmm045.reswk AS ship_fact_code,  --  发货工厂
   ctp_data.cust_code AS sold_to_code,  --  售达方
   kna1.name1 AS sold_to_name,  --  售达方名称
   cust_data.channel_big_class_code AS channel_big_class_code,
   cust_data.channel_big_class_name AS channel_big_class_name,
   cust_data.channel_small_class_code AS channel_small_class_code,
   cust_data.channel_small_class_name AS channel_small_class_name,
   cust_data.ind_big_class_code AS ind_big_class_code,
   cust_data.ind_big_class_name AS ind_big_class_name,
   cust_data.ind_small_class_code AS ind_small_class_code,
   cust_data.ind_small_class_name AS ind_small_class_name,
   prod_data.miniled_type_code,  --  miniled类型编码
   prod_data.miniled_type_name   --  miniled类型名称
FROM zmm045 zmm045
  LEFT JOIN ctp_data ctp_data --  对方公司映射客商（werks->kunrg）
    ON zmm045.werks = ctp_data.cp_company_code
  LEFT JOIN (SELECT kunnr,name1,zkunnr_mdg FROM ods.ods_slt_s600_kna1) kna1 --  客户主数据
    ON ctp_data.cust_code = LTRIM(kna1.kunnr,0)
  LEFT JOIN cust_data cust_data
    ON kna1.zkunnr_mdg = cust_data.cust_code
  LEFT JOIN prod_data prod_data
    ON zmm045.matnr = prod_data.matnr
  LEFT JOIN yx_data yx_data
    ON kna1.zkunnr_mdg = yx_data.cust_code
   AND zmm045.reswk = yx_data.sale_org
   AND REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') = yx_data.material_group_code

  LEFT JOIN pro_type pro_type --  批次映射产品类型
    ON zmm045.charg = pro_type.batch
  LEFT JOIN onoff_data onoff_data1
    ON zmm045.reswk = onoff_data1.company_code
   AND onoff_data1.batch_id = '1'
  LEFT JOIN onoff_data onoff_data2
    ON zmm045.reswk = onoff_data2.company_code
   AND (LTRIM(ctp_data.cust_code,'0') = onoff_data2.cust_code
        OR
        onoff_data2.cust_code IS NULL) --  处理 包含客商编码
   AND onoff_data2.batch_id = '2'
  LEFT JOIN onoff_data onoff_data3
    ON zmm045.reswk = onoff_data3.company_code
   AND (LTRIM(ctp_data.cust_code,'0') = onoff_data3.cust_code
        OR
        onoff_data3.cust_code IS NULL) --  处理 包含客商编码
   AND (LTRIM(ctp_data.cust_code,'0') = onoff_data3.sold_to_code
        OR
        onoff_data3.sold_to_code IS NULL) --  处理 包含售达方
   AND onoff_data3.batch_id = '3'
  LEFT JOIN onoff_data onoff_data4
    ON (LTRIM(ctp_data.cust_code,'0') = onoff_data4.cust_code
        OR
        onoff_data4.cust_code IS NULL) --  处理 包含客商编码
   AND (LTRIM(ctp_data.cust_code,'0') = onoff_data4.sold_to_code
        OR
        onoff_data4.sold_to_code IS NULL) --  处理 包含售达方
   AND onoff_data4.batch_id = '4'
  LEFT JOIN onoff_data onoff_data5
    ON zmm045.reswk = onoff_data5.company_code
   AND zmm045.werks = onoff_data5.cp_company_code --  处理对方公司
   AND onoff_data5.batch_id = '5'
  LEFT JOIN onoff_data onoff_data6
    ON zmm045.reswk = onoff_data6.company_code
   AND zmm045.werks = onoff_data6.cp_company_code --  处理对方公司
   AND (LTRIM(ctp_data.cust_code,'0') = onoff_data6.sold_to_code
        OR
        onoff_data6.sold_to_code IS NULL) --  处理 包含售达方
   AND onoff_data6.batch_id = '6'
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd --  物料映射利润中心及业务范围
    ON zmm045.matnr = mt2bd.material_code
  LEFT JOIN dim.dim_rule_fi_mr_BusScope_for_Company bus_range_map2 --  公司对应业务范围
    ON zmm045.reswk = bus_range_map2.company_code
;
