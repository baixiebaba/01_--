-- 调用20251101-->'20250501'年月日，日固定为01{{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}}最后一个insert需要修改分区，p2025056，p+年月+6

set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;


--set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';

/*为确保有分区不会报错，先插入一条数据*/

INSERT INTO dwd.dwd_fi_mr_rev_acct_msum_mi (dt_month) VALUES (LEFT(@year_month_day,6));

INSERT OVERWRITE TABLE dwd.dwd_fi_mr_rev_acct_msum_mi PARTITION (*)
(
      dt_month
    , company_code
    , cust_code
    , cust_name
    , material_code
    , material_name
    , profitcenter_code
    , channel_l3_code
    , marketing_mode_code
    , onoffline_code
    , cust_unity_name
    , credit_level_name
    , cust_nature_name
    , cust_type_name
    , system_src
    , ods_src
    , load_dt
    , prize_amt
    , tax_rate
    , policy_l2_type_code
    , bus_range_code
    , marketing_dept_code
    , cp_company_code
    , product_line_code
    , product_line_name
    , market_pnt_code
    , product_sale_series_code
    , spec_section_code
    , product_shape_type_code
    , product_stage_code
    , price_range_code
    , product_series_code
    , tech_type_code
    , product_small_class_code
    , model_lca_code
    , sale_model_code
    , sale_model_name
    , model_code
    , model_name
    , is_small_b
    , cn_class_mark_code
    , cn_class_mark_name
    , comm_bu_code
    , miniled_type_code
)

SELECT
      dt_month
    , company_code
    , cust_code
    , cust_name
    , material_code
    , material_name
    , profitcenter_code
    , channel_l3_code
    , marketing_mode_code
    , onoffline_code
    , cust_unity_name
    , credit_level_name
    , cust_nature_name
    , cust_type_name
    , system_src
    , ods_src
    , NOW() as load_dt
    , SUM(NVL(prize_amt,0)) as prize_amt
    , NVL(tax_rate,0) as tax_rate
    , policy_l2_type_code
    , bus_range_code
    , marketing_dept_code
    , cp_company_code
    , product_line_code
    , product_line_name
    , market_pnt_code               --  营销定位
    , product_sale_series_code      --  产品套系
    , spec_section_code             --  规格段
    , product_shape_type_code       --  产品形态分类
    , product_stage_code            --  产品阶段
    , price_range_code              --  价格段
    , product_series_code           --  产品系列
    , tech_type_code                --  技术类型
    , product_small_class_code      --  产品类别
    , model_lca_code                --  产品型号生命周期
    , sale_model_code               --  销售型号
    , sale_model_name               --  销售型号描述
    , model_code                    --  产品型号
    , model_name                    --  产品型号描述
    , is_small_b
    , cn_class_mark_code
    , cn_class_mark_name
    , comm_bu_code
    , miniled_type_code             -- miniled类型
 FROM  dwd.DWD_FI_MR_REV_ACCT_MI
WHERE  dt_month = LEFT(@year_month_day,6)
GROUP BY 
      dt_month
    , company_code
    , cust_code
    , cust_name
    , material_code
    , material_name
    , profitcenter_code
    , channel_l3_code
    , marketing_mode_code
    , onoffline_code
    , cust_unity_name
    , credit_level_name
    , cust_nature_name
    , cust_type_name
    , system_src
    , ods_src
    , NVL(tax_rate,0)
    , policy_l2_type_code
    , bus_range_code
    , marketing_dept_code
    , cp_company_code
    , product_line_code
    , product_line_name
    , market_pnt_code               --  营销定位
    , product_sale_series_code      --  产品套系
    , spec_section_code             --  规格段
    , product_shape_type_code       --  产品形态分类
    , product_stage_code            --  产品阶段
    , price_range_code              --  价格段
    , product_series_code           --  产品系列
    , tech_type_code                --  技术类型
    , product_small_class_code      --  产品类别
    , model_lca_code                --  产品型号生命周期
    , sale_model_code               --  销售型号
    , sale_model_name               --  销售型号描述
    , model_code                    --  产品型号
    , model_name                    --  产品型号描述
    , is_small_b
    , cn_class_mark_code
    , cn_class_mark_name
    , comm_bu_code
    , miniled_type_code             -- miniled类型