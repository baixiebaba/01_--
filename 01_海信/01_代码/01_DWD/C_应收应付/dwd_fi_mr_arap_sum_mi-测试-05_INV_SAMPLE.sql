/*
-- ============================================================================
-- 测试脚本：INV_SAMPLE 开票样机来源窄事实核对
-- 对应来源：dwd_fi_mr_arap_sum_mi.sql 的 INV_SAMPLE 分支
-- 源表：dws.dws_fi_mr_ar_overdue_mi 及当月 DETAIL 性质
-- 金额口径：SUM(inv_sample_amt)，按月份和业务维度聚合并非零过滤
-- 最终输出：sample_fact
-- ============================================================================
*/

-- 运行月份基准日；本脚本与下方最终 SELECT 必须在同一 session 中按顺序执行。
SET @year_month_day = '20260801';
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);

WITH
-- 依据当月DETAIL按公司和客商去重性质，供开票样机事实回接，避免金额放大。
detail_nature AS (
    SELECT company_code AS nature_company_code
         , cust_code AS nature_cust_code
         , MAX(nature_l1_name) AS nature_l1_name
         , MAX(nature_l2_name) AS nature_l2_name
         , MAX(nature_l3_name) AS nature_l3_name
      FROM test.dwd_fi_mr_arap_detail_mi
     WHERE dt_month = @dt_month
       AND (COALESCE(bcy_amt, 0) <> 0 OR COALESCE(qcy_amt, 0) <> 0)
     GROUP BY company_code
            , cust_code
),
-- INV_SAMPLE：start_dt为参数月下月月初，代表参数月数据；按公司、科目、客商和利润中心汇总开票样机额度，并过滤零金额。
sample_src AS (
    SELECT ledge_code AS company_code
         , gl_account AS acct_src_code
         , LTRIM(COALESCE(cust_code, ''), '0') AS cust_code
         , cust_name AS cust_name
         , profit_center_code AS profitcenter_code
         , profit_center_name AS profitcenter_name
         , SUM(COALESCE(inv_sample_amt, 0)) AS amount
      FROM dws.dws_fi_mr_ar_overdue_mi
     WHERE DATE_FORMAT(start_dt, '%Y%m%d') = DATE_FORMAT(
                               DATE_ADD(
                                   STR_TO_DATE(CONCAT(@dt_month, '01'), '%Y%m%d')
                                 , INTERVAL 1 MONTH
                               )
                             , '%Y%m%d'
                         )
     GROUP BY ledge_code
            , gl_account
            , cust_code
            , cust_name
            , profit_center_code
            , profit_center_name
    HAVING SUM(COALESCE(inv_sample_amt, 0)) <> 0
),
-- INV_SAMPLE：标准化为窄事实接口，账龄段固定为1并回接性质。
sample_fact AS (
    SELECT @dt_month AS dt_month, LEFT(@dt_month, 4) AS `year`, RIGHT(@dt_month, 2) AS `month`
         , company_code, cust_code, cust_name
         , NULL AS cust_head_code, NULL AS cust_head_name
         , NULL AS cust_branch_code, NULL AS cust_branch_name
         , NULL AS cp_company_code, NULL AS country_code, NULL AS country_name
         , NULL AS acct_type_code, acct_src_code, acct_src_code AS acct_map_code
         , NULL AS channel_l1_code, NULL AS channel_l1_name
         , NULL AS channel_l2_code, NULL AS channel_l2_name
         , NULL AS channel_l3_code, NULL AS channel_l3_name
         , NULL AS onoffline_code, NULL AS onoffline_name
         , NULL AS src_profitcenter_code, NULL AS src_profitcenter_name
         , profitcenter_code, profitcenter_name
         , NULL AS bus_range_code, NULL AS bus_range_name
         , NULL AS marketing_dept_code, NULL AS marketing_dept_name
         , NULL AS pay_reason_code, 'CNY' AS bcy_code, 'CNY' AS qcy_code
         , 'INV_SAMPLE' AS system_src, 'INV_SAMPLE' AS ods_src
         , NULL AS reb_type, NULL AS ufee_ureb_flag, NULL AS ecls_flag, NULL AS ledger_status, NULL AS acct_cert_type
         , NULL AS tax_rate
         , n.nature_l1_name AS nature_l1_name, n.nature_l2_name AS nature_l2_name, n.nature_l3_name AS nature_l3_name
         , NULL AS exchange_rate_eval_flag, NULL AS is_apar_flag
         , '1' AS aging_seg_code, amount AS bcy_amt, amount AS qcy_amt
      FROM sample_src s
      LEFT JOIN detail_nature n
        ON n.nature_company_code = s.company_code
       AND n.nature_cust_code = s.cust_code
),
-- 来源级Sum聚合：按全部非金额字段汇总INV_SAMPLE账龄金额，结果不是窄事实明细。
sample_fact_sum AS (
    SELECT dt_month
         , `year`
         , `month`
         , company_code
         , cust_code
         , cust_name
         , cust_head_code
         , cust_head_name
         , cust_branch_code
         , cust_branch_name
         , cp_company_code
         , country_code
         , country_name
         , acct_type_code
         , acct_src_code
         , acct_map_code
         , channel_l1_code
         , channel_l1_name
         , channel_l2_code
         , channel_l2_name
         , channel_l3_code
         , channel_l3_name
         , onoffline_code
         , onoffline_name
         , src_profitcenter_code
         , src_profitcenter_name
         , profitcenter_code
         , profitcenter_name
         , bus_range_code
         , bus_range_name
         , marketing_dept_code
         , marketing_dept_name
         , pay_reason_code
         , bcy_code
         , qcy_code
         , system_src
         , ods_src
         , reb_type
         , ufee_ureb_flag
         , ecls_flag
         , ledger_status
         , acct_cert_type
         , tax_rate
         , nature_l1_name
         , nature_l2_name
         , nature_l3_name
         , exchange_rate_eval_flag
         , is_apar_flag
         , SUM(CASE WHEN aging_seg_code IN ('1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15') THEN bcy_amt ELSE 0 END) AS bcy_0_amt
         , SUM(CASE WHEN aging_seg_code = '1' THEN bcy_amt ELSE 0 END) AS bcy_1_amt
         , SUM(CASE WHEN aging_seg_code = '2' THEN bcy_amt ELSE 0 END) AS bcy_2_amt
         , SUM(CASE WHEN aging_seg_code = '3' THEN bcy_amt ELSE 0 END) AS bcy_3_amt
         , SUM(CASE WHEN aging_seg_code = '4' THEN bcy_amt ELSE 0 END) AS bcy_4_amt
         , SUM(CASE WHEN aging_seg_code = '5' THEN bcy_amt ELSE 0 END) AS bcy_5_amt
         , SUM(CASE WHEN aging_seg_code = '6' THEN bcy_amt ELSE 0 END) AS bcy_6_amt
         , SUM(CASE WHEN aging_seg_code = '7' THEN bcy_amt ELSE 0 END) AS bcy_7_amt
         , SUM(CASE WHEN aging_seg_code = '8' THEN bcy_amt ELSE 0 END) AS bcy_8_amt
         , SUM(CASE WHEN aging_seg_code = '9' THEN bcy_amt ELSE 0 END) AS bcy_9_amt
         , SUM(CASE WHEN aging_seg_code = '10' THEN bcy_amt ELSE 0 END) AS bcy_10_amt
         , SUM(CASE WHEN aging_seg_code = '11' THEN bcy_amt ELSE 0 END) AS bcy_11_amt
         , SUM(CASE WHEN aging_seg_code = '12' THEN bcy_amt ELSE 0 END) AS bcy_12_amt
         , SUM(CASE WHEN aging_seg_code = '13' THEN bcy_amt ELSE 0 END) AS bcy_13_amt
         , SUM(CASE WHEN aging_seg_code = '14' THEN bcy_amt ELSE 0 END) AS bcy_14_amt
         , SUM(CASE WHEN aging_seg_code = '15' THEN bcy_amt ELSE 0 END) AS bcy_15_amt
         , SUM(CASE WHEN aging_seg_code IN ('1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15') THEN qcy_amt ELSE 0 END) AS qcy_0_amt
         , SUM(CASE WHEN aging_seg_code = '1' THEN qcy_amt ELSE 0 END) AS qcy_1_amt
         , SUM(CASE WHEN aging_seg_code = '2' THEN qcy_amt ELSE 0 END) AS qcy_2_amt
         , SUM(CASE WHEN aging_seg_code = '3' THEN qcy_amt ELSE 0 END) AS qcy_3_amt
         , SUM(CASE WHEN aging_seg_code = '4' THEN qcy_amt ELSE 0 END) AS qcy_4_amt
         , SUM(CASE WHEN aging_seg_code = '5' THEN qcy_amt ELSE 0 END) AS qcy_5_amt
         , SUM(CASE WHEN aging_seg_code = '6' THEN qcy_amt ELSE 0 END) AS qcy_6_amt
         , SUM(CASE WHEN aging_seg_code = '7' THEN qcy_amt ELSE 0 END) AS qcy_7_amt
         , SUM(CASE WHEN aging_seg_code = '8' THEN qcy_amt ELSE 0 END) AS qcy_8_amt
         , SUM(CASE WHEN aging_seg_code = '9' THEN qcy_amt ELSE 0 END) AS qcy_9_amt
         , SUM(CASE WHEN aging_seg_code = '10' THEN qcy_amt ELSE 0 END) AS qcy_10_amt
         , SUM(CASE WHEN aging_seg_code = '11' THEN qcy_amt ELSE 0 END) AS qcy_11_amt
         , SUM(CASE WHEN aging_seg_code = '12' THEN qcy_amt ELSE 0 END) AS qcy_12_amt
         , SUM(CASE WHEN aging_seg_code = '13' THEN qcy_amt ELSE 0 END) AS qcy_13_amt
         , SUM(CASE WHEN aging_seg_code = '14' THEN qcy_amt ELSE 0 END) AS qcy_14_amt
         , SUM(CASE WHEN aging_seg_code = '15' THEN qcy_amt ELSE 0 END) AS qcy_15_amt
      FROM sample_fact
     GROUP BY dt_month
            , `year`
            , `month`
            , company_code
            , cust_code
            , cust_name
            , cust_head_code
            , cust_head_name
            , cust_branch_code
            , cust_branch_name
            , cp_company_code
            , country_code
            , country_name
            , acct_type_code
            , acct_src_code
            , acct_map_code
            , channel_l1_code
            , channel_l1_name
            , channel_l2_code
            , channel_l2_name
            , channel_l3_code
            , channel_l3_name
            , onoffline_code
            , onoffline_name
            , src_profitcenter_code
            , src_profitcenter_name
            , profitcenter_code
            , profitcenter_name
            , bus_range_code
            , bus_range_name
            , marketing_dept_code
            , marketing_dept_name
            , pay_reason_code
            , bcy_code
            , qcy_code
            , system_src
            , ods_src
            , reb_type
            , ufee_ureb_flag
            , ecls_flag
            , ledger_status
            , acct_cert_type
            , tax_rate
            , nature_l1_name
            , nature_l2_name
            , nature_l3_name
            , exchange_rate_eval_flag
            , is_apar_flag
)
-- 测试目的：核对INV_SAMPLE来源级Sum聚合结果，而非窄事实明细。
SELECT *
  FROM sample_fact_sum;
