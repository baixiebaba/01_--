/*
-- ============================================================================
-- 测试脚本：IMOCC 其他应收来源窄事实核对
-- 对应来源：dwd_fi_mr_arap_sum_mi.sql 的 IMOCC 分支
-- 源表：ads.ads_fi_mr_accounts_rec_di 及当月 DETAIL 性质
-- 金额口径：仅取 dsource='ACT'，分别汇总 end_amt_cod_m 本位币和 end_amt_cny_m 交易币，非零过滤
-- 最终输出：imocc_fact
-- ============================================================================
*/

-- 运行月份基准日；本脚本与下方最终 SELECT 必须在同一 session 中按顺序执行。
SET @year_month_day = '20260801';
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);

WITH
-- 依据当月DETAIL按公司和客商去重性质，供IMOCC事实回接，避免金额放大。
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
-- IMOCC：按月和业务维度筛选ACT数据并分别汇总本位币、交易币金额。
imocc_sum AS (
    SELECT bukrs AS company_code
         , kunnr AS cust_code
         , cust_name AS cust_name
         , prdln AS bus_range_code
         , sm AS marketing_dept_code
         , custfundcode AS src_profitcenter_code
         , custfundname AS src_profitcenter_name
         , custfundcode AS profitcenter_code
         , custfundname AS profitcenter_name
         , SUM(COALESCE(end_amt_cod_m, 0)) AS bcy_amt
         , SUM(COALESCE(end_amt_cny_m, 0)) AS qcy_amt
      FROM ads.ads_fi_mr_accounts_rec_di
     WHERE REPLACE(LEFT(month_dt, 7), '-', '') = @dt_month
       AND dsource = 'ACT'
     GROUP BY bukrs
            , kunnr
            , cust_name
            , prdln
            , sm
            , custfundcode
            , custfundname
),
-- IMOCC：标准化为窄事实接口，账龄段固定为1并过滤本位币/交易币均为零的记录。
imocc_fact AS (
    SELECT @dt_month AS dt_month, LEFT(@dt_month, 4) AS `year`, RIGHT(@dt_month, 2) AS `month`
         , company_code, cust_code, cust_name
         , NULL AS cust_head_code, NULL AS cust_head_name
         , NULL AS cust_branch_code, NULL AS cust_branch_name
         , NULL AS cp_company_code, NULL AS country_code, NULL AS country_name
         , NULL AS acct_type_code, NULL AS acct_src_code, NULL AS acct_map_code
         , NULL AS channel_l1_code, NULL AS channel_l1_name
         , NULL AS channel_l2_code, NULL AS channel_l2_name
         , NULL AS channel_l3_code, NULL AS channel_l3_name
         , NULL AS onoffline_code, NULL AS onoffline_name
         , src_profitcenter_code, src_profitcenter_name, profitcenter_code, profitcenter_name
         , bus_range_code, NULL AS bus_range_name
         , marketing_dept_code, NULL AS marketing_dept_name
         , NULL AS pay_reason_code, 'CNY' AS bcy_code, 'CNY' AS qcy_code
         , 'XS' AS system_src, 'IMOCC' AS ods_src
         , NULL AS reb_type, NULL AS ufee_ureb_flag, NULL AS ecls_flag, NULL AS ledger_status, NULL AS acct_cert_type
         , NULL AS tax_rate
         , n.nature_l1_name AS nature_l1_name, n.nature_l2_name AS nature_l2_name, n.nature_l3_name AS nature_l3_name
         , NULL AS exchange_rate_eval_flag, NULL AS is_apar_flag
         , '1' AS aging_seg_code, bcy_amt AS bcy_amt, qcy_amt AS qcy_amt
      FROM imocc_sum s
      LEFT JOIN detail_nature n
        ON n.nature_company_code = s.company_code
       AND n.nature_cust_code = s.cust_code
     WHERE COALESCE(bcy_amt, 0) <> 0
        OR COALESCE(qcy_amt, 0) <> 0
),
-- 来源级Sum聚合：按全部非金额字段汇总IMOCC账龄金额，结果不是窄事实明细。
imocc_fact_sum AS (
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
      FROM imocc_fact
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
-- 测试目的：核对IMOCC来源级Sum聚合结果，而非窄事实明细。
SELECT *
  FROM imocc_fact_sum;
