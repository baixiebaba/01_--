/*
-- ============================================================================
-- 测试脚本：DETAIL 来源窄事实核对
-- 对应来源：dwd_fi_mr_arap_sum_mi.sql 的 DETAIL 分支
-- 源表：test.dwd_fi_mr_arap_detail_mi 及税率、汇率、账龄、电商零售规则表
-- 金额口径：保留源明细 bcy_amt/qcy_amt，非零过滤；排除信汇专用映射科目
-- 最终输出：detail_fact
-- ============================================================================
*/

-- 运行月份基准日；本脚本与下方最终 SELECT 必须在同一 session 中按顺序执行。
SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);

WITH
-- 读取税率规则，按公司+主户匹配税率。
tax_rate_rule_1 AS (
    SELECT company_code
         , cust_code
         , MAX(tax_rate) AS tax_rate
      FROM dim.dim_rule_fi_mr_ar_tax_rate
     WHERE batch_id = 1
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY company_code
            , cust_code
),
-- 读取税率规则，按公司+映射后利润中心匹配税率。
tax_rate_rule_2 AS (
    SELECT company_code
         , profitcenter_code
         , MAX(tax_rate) AS tax_rate
      FROM dim.dim_rule_fi_mr_ar_tax_rate
     WHERE batch_id = 2
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY company_code
            , profitcenter_code
),
-- 读取税率规则，仅按公司匹配税率。
tax_rate_rule_3 AS (
    SELECT company_code
         , MAX(tax_rate) AS tax_rate
      FROM dim.dim_rule_fi_mr_ar_tax_rate
     WHERE batch_id = 3
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY company_code
),
-- 读取汇率评估规则，按公司+客商准备S匹配键。
ex_rate_company_rule AS (
    SELECT company_code
         , cust_code
         , 1 AS matched
      FROM dim.dim_rule_fi_mr_ar_ex_rate_eval_range
     WHERE logic_name = '按照公司+客商维护'
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY company_code
            , cust_code
),
-- 读取汇率评估规则，按系统+原始科目准备M匹配键。
ex_rate_account_rule AS (
    SELECT system_src
         , acct_src_code
         , 1 AS matched
      FROM dim.dim_rule_fi_mr_ar_ex_rate_eval_range
     WHERE logic_name = '按照SAP系统+科目维护'
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY system_src
            , acct_src_code
),
-- 读取账龄进数范围规则；logic_name 为真实字段，规则值保留完整中文字符串。
apar_range_rule AS (
    SELECT logic_name
         , system_src
         , company_code
         , acct_src_code
         , cust_code
      FROM dim.dim_rule_fi_mr_ar_aging_range
     WHERE logic_name IN (
                           'EX1-按公司+按客商剔除'
                         , 'EX2-按公司+科目剔除'
                         , 'EX3-按系统号+科目剔除'
                         , 'IN1-按系统号+公司+科目取数'
                       )
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY logic_name
            , system_src
            , company_code
            , acct_src_code
            , cust_code
),
-- 读取电商零售客户范围，供ECLS标识匹配。
ecom_retail_scope AS (
    SELECT LTRIM(cust_code, '0') AS cust_code
      FROM dim.dim_rule_fi_mr_ar_cust_type
     WHERE TRIM(cust_type) = '电商零售类客户'
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY LTRIM(cust_code, '0')
),
-- 识别满足付款原因、科目、金额和基准日期条件的电商零售明细键。
ecls_match AS (
    SELECT d.acct_map_code
         , d.cust_code
         , d.pays_tran
      FROM test.dwd_fi_mr_arap_detail_mi d
      INNER JOIN ecom_retail_scope e
        ON e.cust_code = d.cust_code
     WHERE d.dt_month = @dt_month
       AND d.pay_reason_code = '400'
       AND d.acct_map_code LIKE '1122%'
     GROUP BY d.acct_map_code
            , d.cust_code
            , d.pays_tran
    HAVING SUM(COALESCE(d.bcy_amt, 0)) > 0
       AND MIN(d.baseline_dt) > LAST_DAY(STR_TO_DATE(CONCAT(@dt_month, '01'), '%Y%m%d'))
),
-- 在明细事实粒度计算五个新增标识/规则字段，保留源优先级和匹配口径。
detail_rule_base AS (
    SELECT d.*
         , COALESCE(t1.tax_rate, t2.tax_rate, t3.tax_rate) AS tax_rate
         , CASE
               WHEN erc.matched IS NOT NULL AND era.matched IS NOT NULL THEN 'SM'
               WHEN erc.matched IS NOT NULL THEN 'S'
               WHEN era.matched IS NOT NULL THEN 'M'
           END AS exchange_rate_eval_flag
         , CASE
               WHEN ex1.logic_name IS NOT NULL
                 OR ex2.logic_name IS NOT NULL
                 OR ex3.logic_name IS NOT NULL THEN 'N'
               WHEN in1.logic_name IS NOT NULL THEN 'Y'
           END AS is_apar_flag
         , CASE
               WHEN d.acct_cert_type = 'zz'
                AND d.pay_reason_code = '800'
                AND d.acct_map_code LIKE '1122%' THEN 'UFEE'
               WHEN d.acct_cert_type = 'zz'
                AND d.pay_reason_code = '600'
                AND d.acct_map_code LIKE '1122%' THEN 'UREB'
           END AS ufee_ureb_flag
         , CASE WHEN em.acct_map_code IS NOT NULL THEN 'Y' END AS ecls_flag
      FROM test.dwd_fi_mr_arap_detail_mi d
      LEFT JOIN tax_rate_rule_1 t1
        ON t1.company_code = d.company_code
       AND t1.cust_code = d.cust_head_code
      LEFT JOIN tax_rate_rule_2 t2
        ON t2.company_code = d.company_code
       AND t2.profitcenter_code = d.profitcenter_code
      LEFT JOIN tax_rate_rule_3 t3
        ON t3.company_code = d.company_code
      LEFT JOIN ex_rate_company_rule erc
        ON erc.company_code = d.company_code
       AND erc.cust_code = d.cust_head_code
      LEFT JOIN ex_rate_account_rule era
        ON era.system_src = d.system_src
       AND era.acct_src_code = d.acct_src_code
      LEFT JOIN apar_range_rule ex1
        ON ex1.logic_name = 'EX1-按公司+按客商剔除'
       AND ex1.company_code = d.company_code
       AND ex1.cust_code = d.cust_head_code
      LEFT JOIN apar_range_rule ex2
        ON ex2.logic_name = 'EX2-按公司+科目剔除'
       AND ex2.company_code = d.company_code
       AND ex2.acct_src_code = d.acct_src_code
      LEFT JOIN apar_range_rule ex3
        ON ex3.logic_name = 'EX3-按系统号+科目剔除'
       AND ex3.system_src = d.system_src
       AND ex3.acct_src_code = d.acct_src_code
      LEFT JOIN apar_range_rule in1
        ON in1.logic_name = 'IN1-按系统号+公司+科目取数'
       AND in1.system_src = d.system_src
       AND in1.company_code = d.company_code
       AND in1.acct_src_code = d.acct_src_code
      LEFT JOIN ecls_match em
        ON em.acct_map_code = d.acct_map_code
       AND em.cust_code = d.cust_code
       AND COALESCE(em.pays_tran, '') = COALESCE(d.pays_tran, '')
     WHERE d.dt_month = @dt_month
),
-- DETAIL：输出标准化明细事实，保留真实账龄段并执行源非零过滤。
detail_fact AS (
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
         , NULL AS reb_type
         , ufee_ureb_flag
         , ecls_flag
         , NULL AS ledger_status
         , acct_cert_type
         , tax_rate
         , nature_l1_name AS nature_l1_name
         , nature_l2_name AS nature_l2_name
         , nature_l3_name AS nature_l3_name
         , exchange_rate_eval_flag
         , is_apar_flag
         , aging_seg_code
         , COALESCE(bcy_amt, 0) AS bcy_amt
         , COALESCE(qcy_amt, 0) AS qcy_amt
      FROM detail_rule_base
     WHERE dt_month = @dt_month
       AND acct_map_code NOT IN ('1122000095', '2202000095')
       AND (COALESCE(bcy_amt, 0) <> 0 OR COALESCE(qcy_amt, 0) <> 0)
),
-- 来源级Sum聚合：按全部非金额字段汇总DETAIL账龄金额，结果不是窄事实明细。
detail_fact_sum AS (
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
      FROM detail_fact
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
-- 测试目的：核对DETAIL来源级Sum聚合结果，而非窄事实明细。
SELECT *
  FROM detail_fact_sum
 ORDER BY company_code
        , cust_code
        , acct_map_code;
