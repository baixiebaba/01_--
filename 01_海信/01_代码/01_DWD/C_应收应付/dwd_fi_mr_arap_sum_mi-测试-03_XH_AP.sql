/*
-- ============================================================================
-- 测试脚本：XH_AP 信汇应付来源窄事实核对
-- 对应来源：dwd_fi_mr_arap_sum_mi.sql 的 XH 应付分支
-- 源表：ods.odsmt_fin_bill_view_data、ODS公司/账户映射表及当月 DETAIL 性质
-- 金额口径：票据 bill_amount 汇总后取负为应付金额，非零过滤
-- 最终输出：xh_ap_fact
-- ============================================================================
*/

-- 运行月份基准日；本脚本与下方最终 SELECT 必须在同一 session 中按顺序执行。
SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);

WITH
-- 依据当月DETAIL按公司和客商去重性质，供XH事实回接，避免明细关联放大金额。
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
-- 读取目标月份有效的信汇账龄段配置，供信汇账龄天数匹配账龄区间。
aging_seg_cfg AS (
    SELECT r.aging_seg_code
         , r.aging_seg_name
         , r.aging_seg_fr
         , r.aging_seg_to
      FROM dim.dim_rule_fi_mr_ar_aging_seg r
     WHERE NVL(r.valid_fr, '202401') <= @dt_month
       AND NVL(r.valid_to, '999999') >= @dt_month
),
-- XH应付：按票据编号、子序号和区间保留最新票据记录，并保留SIGN_DATE作为账龄起算日。
xh_parsed AS (
    SELECT ROW_NUMBER() OVER (
               PARTITION BY SUBSTRING_INDEX(bill_code, '-', 1)
                          , SUBSTRING_INDEX(bill_code, ' ', -1)
               ORDER BY SUBSTRING_INDEX(
                                SUBSTRING_INDEX(bill_code, ' ', 1)
                                , '-'
                                , -1
                            ) DESC
           ) AS rn
         , credit_customer_code
         , credit_customer_account
         , receive_credit_code
         , hold_customer_account
         , hold_customer_name
         , bill_amount
         , bill_status
         , CAST(SIGN_DATE AS DATE) AS sign_date
      FROM ods.odsmt_fin_bill_view_data
     WHERE data_date = DATE_FORMAT(
                           LAST_DAY(STR_TO_DATE(CONCAT(@dt_month, '01'), '%Y%m%d'))
                           , '%Y%m%d'
                       )
       AND @dt_month >= '202607'
),
-- XH应付：将票据两端客户映射为应收/应付公司。
xh_company AS (
    SELECT COALESCE(ap_map.bukrs, ap_azi.cod_azienda) AS ap_bukrs
         , CASE WHEN x.hold_customer_name = '青岛海信商业保理有限公司'
                THEN '9002'
                ELSE COALESCE(ar_map.bukrs, ar_azi.cod_azienda)
            END AS ar_bukrs
         , x.bill_amount
         , x.sign_date
      FROM xh_parsed x
      LEFT JOIN ods.odsmr_ztab_9000_acct_maping ap_map
        ON ap_map.account_no = x.credit_customer_account
      LEFT JOIN ods.odsmr_ztab_9000_acct_maping ar_map
        ON ar_map.account_no = x.hold_customer_account
      LEFT JOIN ods.odsfima_azienda ap_azi
        ON ap_azi.sede_legale = x.credit_customer_code
      LEFT JOIN (SELECT sede_legale,MIN(cod_azienda) AS cod_azienda
                   FROM ods.odsfima_azienda
                  WHERE sede_legale IS NOT NULL GROUP BY sede_legale
                ) ar_azi
        ON ar_azi.sede_legale = x.receive_credit_code
     WHERE x.rn = 1
       AND COALESCE(x.bill_status, '') <> '9999'
),
-- XH应付：按公司对、SIGN_DATE和账龄天数汇总，保留公司排除范围与非零金额过滤。
xh_ap_sum AS (
    SELECT ar_bukrs
         , ap_bukrs
         , sign_date
         , CASE
               WHEN sign_date IS NULL THEN 1
               ELSE DATEDIFF(
                        LAST_DAY(STR_TO_DATE(CONCAT(@dt_month, '01'), '%Y%m%d'))
                      , sign_date
                    ) + 1
           END AS aging_days
         , SUM(COALESCE(bill_amount, 0)) AS bill_amt
      FROM xh_company
     WHERE COALESCE(ar_bukrs, '') <> COALESCE(ap_bukrs, '')
       AND COALESCE(ap_bukrs, '') <> ''
       AND ap_bukrs NOT IN ('9000', '9002', '9003', '9005', '9008')
     GROUP BY ar_bukrs
            , ap_bukrs
            , sign_date
            , CASE
                  WHEN sign_date IS NULL THEN 1
                  ELSE DATEDIFF(
                           LAST_DAY(STR_TO_DATE(CONCAT(@dt_month, '01'), '%Y%m%d'))
                         , sign_date
                       ) + 1
              END
    HAVING SUM(COALESCE(bill_amount, 0)) <> 0
),
-- XH应付：标准化为窄事实接口，按账龄天数匹配账龄段、应付取负并回接性质。
xh_ap_fact AS (
    SELECT @dt_month AS dt_month
         , LEFT(@dt_month, 4) AS `year`
         , RIGHT(@dt_month, 2) AS `month`
         , ap_bukrs AS company_code
         , CONCAT('XH_', COALESCE(ar_bukrs, 'Z001')) AS cust_code
         , '应付账款-信汇' AS cust_name
         , NULL AS cust_head_code
         , NULL AS cust_head_name
         , NULL AS cust_branch_code
         , NULL AS cust_branch_name
         , ar_bukrs AS cp_company_code
         , NULL AS country_code
         , NULL AS country_name
         , 'K' AS acct_type_code
         , '2202000095' AS acct_src_code
         , '2202000095' AS acct_map_code
         , NULL AS channel_l1_code
         , NULL AS channel_l1_name
         , NULL AS channel_l2_code
         , NULL AS channel_l2_name
         , NULL AS channel_l3_code
         , NULL AS channel_l3_name
         , NULL AS onoffline_code
         , NULL AS onoffline_name
         , NULL AS src_profitcenter_code
         , NULL AS src_profitcenter_name
         , NULL AS profitcenter_code
         , NULL AS profitcenter_name
         , NULL AS bus_range_code
         , NULL AS bus_range_name
         , NULL AS marketing_dept_code
         , NULL AS marketing_dept_name
         , NULL AS pay_reason_code
         , 'CNY' AS bcy_code
         , 'CNY' AS qcy_code
         , 'XH' AS system_src
         , 'ORG_XH' AS ods_src
         , NULL AS reb_type
         , NULL AS ufee_ureb_flag
         , NULL AS ecls_flag
         , NULL AS ledger_status
         , NULL AS acct_cert_type
         , NULL AS tax_rate
         , n.nature_l1_name AS nature_l1_name
         , n.nature_l2_name AS nature_l2_name
         , n.nature_l3_name AS nature_l3_name
         , NULL AS exchange_rate_eval_flag
         , NULL AS is_apar_flag
         , COALESCE(NULLIF(TRIM(seg.aging_seg_code), ''), '9') AS aging_seg_code
         , -bill_amt AS bcy_amt
         , -bill_amt AS qcy_amt
      FROM xh_ap_sum x
      LEFT JOIN aging_seg_cfg seg
        ON x.aging_days >= seg.aging_seg_fr
       AND x.aging_days <= seg.aging_seg_to
      LEFT JOIN detail_nature n
        ON n.nature_company_code = x.ap_bukrs
       AND n.nature_cust_code = CONCAT('XH_', COALESCE(x.ar_bukrs, 'Z001'))
),
-- 来源级Sum聚合：按全部非金额字段汇总XH应付账龄金额，结果不是窄事实明细。
xh_ap_fact_sum AS (
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
      FROM xh_ap_fact
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
-- 测试目的：核对XH应付来源级Sum聚合结果，而非窄事实明细。
SELECT *
  FROM xh_ap_fact_sum;
