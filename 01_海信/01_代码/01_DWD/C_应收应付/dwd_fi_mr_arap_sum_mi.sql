/*
-- ============================================================================
-- 最新版修改记录：20260915 ADD BY shiqingfeng.ex 新增
-- 上一版修改记录：
-- 目标表：往来账龄汇总表 test.dwd_fi_mr_arap_sum_mi
-- 修改记录：最新修改记录放最上面
--   20260915 ADD BY shiqingfeng.ex 新增
-- ============================================================================
*/

-- 业务输入：运行月份基准日，格式YYYYMMDD，约定为参数月01日。
--SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');
SET @year_month_day = '20260801';
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);
-- 统计截止日期：取参数月份月末，供EPAY基准日期判断。
SET @last_day = LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d'));
-- 以上SET与下方单条INSERT OVERWRITE必须在同一session中依次执行。
set enable_auto_create_when_overwrite=true;

-- ============================================================================
-- 目标表装载：九类来源统一为窄事实接口后合并、汇总并一次覆盖目标分区。
-- DETAIL保留真实账龄段；其余来源无精确账龄，统一写入账龄段1。
-- ============================================================================
INSERT OVERWRITE TABLE test.dwd_fi_mr_arap_sum_mi PARTITION (*)
(
      dt_month                 -- 年月
    , `year`                   -- 年份
    , `month`                  -- 月份
    , company_code             -- 组织
    , cust_code                -- 客商编码
    , cust_name                -- 客商名称
    , cust_head_code           -- 主户编码
    , cust_head_name           -- 主户名称
    , cust_branch_code         -- 分户编码
    , cust_branch_name         -- 分户名称
    , cp_company_code          -- 对方公司
    , country_code             -- 国家编码
    , country_name             -- 国家名称
    , acct_type_code           -- 科目类型：D应收，K应付
    , acct_src_code            -- 原始科目编码
    , acct_map_code            -- 映射后科目编码
    , channel_l1_code          -- 一级公司分类编码
    , channel_l1_name          -- 一级公司分类名称
    , channel_l2_code          -- 二级公司分类编码
    , channel_l2_name          -- 二级公司分类名称
    , channel_l3_code          -- 三级公司分类编码
    , channel_l3_name          -- 三级公司分类名称
    , onoffline_code           -- 线上线下编码
    , onoffline_name           -- 线上线下名称
    , src_profitcenter_code    -- 原始利润中心编码
    , src_profitcenter_name    -- 原始利润中心名称
    , profitcenter_code        -- 映射后利润中心编码
    , profitcenter_name        -- 映射后利润中心名称
    , bus_range_code           -- 业务范围编码
    , bus_range_name           -- 业务范围名称
    , marketing_dept_code      -- 业务管理单元编码
    , marketing_dept_name      -- 业务管理单元名称
    , pay_reason_code          -- 付款原因代码
    , bcy_code                 -- 本位币币种
    , qcy_code                 -- 交易币币种
    , bcy_0_amt                -- 本位币总金额
    , bcy_1_amt                -- 本位币金额-账龄区间段1
    , bcy_2_amt                -- 本位币金额-账龄区间段2
    , bcy_3_amt                -- 本位币金额-账龄区间段3
    , bcy_4_amt                -- 本位币金额-账龄区间段4
    , bcy_5_amt                -- 本位币金额-账龄区间段5
    , bcy_6_amt                -- 本位币金额-账龄区间段6
    , bcy_7_amt                -- 本位币金额-账龄区间段7
    , bcy_8_amt                -- 本位币金额-账龄区间段8
    , bcy_9_amt                -- 本位币金额-账龄区间段9
    , bcy_10_amt               -- 本位币金额-账龄区间段10
    , bcy_11_amt               -- 本位币金额-账龄区间段11
    , bcy_12_amt               -- 本位币金额-账龄区间段12
    , bcy_13_amt               -- 本位币金额-账龄区间段13
    , bcy_14_amt               -- 本位币金额-账龄区间段14
    , bcy_15_amt               -- 本位币金额-账龄区间段15
    , qcy_0_amt                -- 交易币总金额
    , qcy_1_amt                -- 交易币金额-账龄区间段1
    , qcy_2_amt                -- 交易币金额-账龄区间段2
    , qcy_3_amt                -- 交易币金额-账龄区间段3
    , qcy_4_amt                -- 交易币金额-账龄区间段4
    , qcy_5_amt                -- 交易币金额-账龄区间段5
    , qcy_6_amt                -- 交易币金额-账龄区间段6
    , qcy_7_amt                -- 交易币金额-账龄区间段7
    , qcy_8_amt                -- 交易币金额-账龄区间段8
    , qcy_9_amt                -- 交易币金额-账龄区间段9
    , qcy_10_amt               -- 交易币金额-账龄区间段10
    , qcy_11_amt               -- 交易币金额-账龄区间段11
    , qcy_12_amt               -- 交易币金额-账龄区间段12
    , qcy_13_amt               -- 交易币金额-账龄区间段13
    , qcy_14_amt               -- 交易币金额-账龄区间段14
    , qcy_15_amt               -- 交易币金额-账龄区间段15
    , system_src               -- 来源系统
    , ods_src                  -- 数据来源
    , reb_type                 -- 返利性质
    , ufee_ureb_flag           -- 返利/费用标识
    , ecls_flag                -- 电商零售标识
    , ledger_status            -- 台账状态
    , acct_cert_type           -- 凭证类型
    , tax_rate                 -- 税率
    , nature_l1_name           -- 一级性质
    , nature_l2_name           -- 二级性质
    , nature_l3_name           -- 三级性质
    , exchange_rate_eval_flag  -- 汇率评估标识
    , is_apar_flag             -- 账龄是否进数
    , pay_term_code            -- 付款条件代码
    , pay_term_desc            -- 付款条件描述
    , load_dt                  -- 更新时间
)
WITH
-- 按付款条件表实际粒度去重，避免最终关联放大已汇总金额。
cterm_dedup AS (
    SELECT system_src
         , company_code
         , cust_code
         , MAX(pay_term_code) AS pay_term_code
         , MAX(pay_term_desc) AS pay_term_desc
      FROM test.dwd_fi_mr_ar_cterm_md
     GROUP BY system_src
            , company_code
            , cust_code
),
-- 读取税率规则，按公司+主户、公司+利润中心、公司三级优先级准备唯一配置。
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
-- 读取税率规则第二优先级：按公司和映射后利润中心匹配税率。
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
-- 读取税率规则第三优先级：仅按公司匹配税率。
tax_rate_rule_3 AS (
    SELECT company_code
         , MAX(tax_rate) AS tax_rate
      FROM dim.dim_rule_fi_mr_ar_tax_rate
     WHERE batch_id = 3
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY company_code
),
-- 读取汇率评估范围规则，分别准备公司+客商和系统+原始科目匹配键。
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
-- 汇率评估规则第二匹配方式：按SAP系统和原始科目识别M标识。
ex_rate_account_rule AS (
    SELECT CONCAT('S',system_src) AS system_src
         , acct_src_code
         , 1 AS matched
      FROM dim.dim_rule_fi_mr_ar_ex_rate_eval_range
     WHERE logic_name = '按照SAP系统+科目维护'
       AND NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY system_src
            , acct_src_code
),
-- 读取账龄表进数范围规则，EX类型优先输出N，IN1命中时输出Y。
apar_range_rule AS (
    SELECT logic_name
         , CONCAT('S',system_src) AS system_src
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
-- 识别满足金额、基准日期和电商零售范围条件的明细键。
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
       AND d.ods_src <> 'BSAD_EPAY'
     GROUP BY d.acct_map_code
            , d.cust_code
            , d.pays_tran
    HAVING SUM(COALESCE(d.bcy_amt, 0)) > 0
       AND MIN(d.netrcp_dt) > LAST_DAY(STR_TO_DATE(CONCAT(@dt_month, '01'), '%Y%m%d'))
),
-- 在明细事实粒度计算五个新增字段，保留税率、汇率评估和账龄进数的优先级。
detail_rule_base AS (
    SELECT d.*
         , COALESCE(t1.tax_rate, t2.tax_rate, t3.tax_rate,0.13) AS tax_rate
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
               WHEN d.acct_cert_type = 'ZZ'
                AND d.pay_reason_code = '800'
                AND d.acct_map_code LIKE '1122%' THEN 'UFEE'
               WHEN d.acct_cert_type = 'ZZ'
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
       AND d.ods_src <> 'BSAD_EPAY'
),
-- DETAIL：保留明细表真实账龄段，排除由信汇单独构造的两个映射科目。
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
-- XH应收/XH应付：按票据编号、子序号和区间保留最新票据记录，并保留SIGN_DATE作为账龄起算日。
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
-- XH应收/XH应付：将票据两端客户映射为应收/应付公司。
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
      LEFT JOIN (SELECT sede_legale,MIN(cod_azienda) AS cod_azienda
                   FROM ods.odsfima_azienda
                  WHERE sede_legale IS NOT NULL GROUP BY sede_legale
                )  ap_azi
        ON ap_azi.sede_legale = x.credit_customer_code
      LEFT JOIN (SELECT sede_legale,MIN(cod_azienda) AS cod_azienda
                   FROM ods.odsfima_azienda
                  WHERE sede_legale IS NOT NULL GROUP BY sede_legale
                ) ar_azi
        ON ar_azi.sede_legale = x.receive_credit_code
     WHERE x.rn = 1
       AND COALESCE(x.bill_status, '') <> 9999
),
-- XH：按公司对、SIGN_DATE和账龄天数统一汇总，应收、应付事实分别筛选。
xh_sum AS (
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
-- XH应收：标准化为窄事实接口，按账龄天数匹配账龄段并回接性质。
xh_ar_fact AS (
    SELECT @dt_month AS dt_month
         , LEFT(@dt_month, 4) AS `year`
         , RIGHT(@dt_month, 2) AS `month`
         , ar_bukrs AS company_code
         , CONCAT('XH_', COALESCE(ap_bukrs, 'Z001')) AS cust_code
         , '应收账款-信汇' AS cust_name
         , NULL AS cust_head_code
         , NULL AS cust_head_name
         , NULL AS cust_branch_code
         , NULL AS cust_branch_name
         , ap_bukrs AS cp_company_code
         , NULL AS country_code
         , NULL AS country_name
         , 'D' AS acct_type_code
         , '1122000095' AS acct_src_code
         , '1122000095' AS acct_map_code
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
         , NULL AS nature_l1_name
         , NULL AS nature_l2_name
         , NULL AS nature_l3_name
         , NULL AS exchange_rate_eval_flag
         , NULL AS is_apar_flag
         , COALESCE(NULLIF(TRIM(seg.aging_seg_code), ''), '9') AS aging_seg_code
         , bill_amt AS bcy_amt
         , bill_amt AS qcy_amt
      FROM xh_sum x
      LEFT JOIN aging_seg_cfg seg
        ON x.aging_days >= seg.aging_seg_fr
       AND x.aging_days <= seg.aging_seg_to
     WHERE COALESCE(x.ar_bukrs, '') <> COALESCE(x.ap_bukrs, '')
       AND COALESCE(x.ar_bukrs, '') <> ''
       AND x.ar_bukrs NOT IN ('9000', '9002', '9003', '9005', '9008')
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
         , NULL AS nature_l1_name
         , NULL AS nature_l2_name
         , NULL AS nature_l3_name
         , NULL AS exchange_rate_eval_flag
         , NULL AS is_apar_flag
         , COALESCE(NULLIF(TRIM(seg.aging_seg_code), ''), '9') AS aging_seg_code
         , -bill_amt AS bcy_amt
         , -bill_amt AS qcy_amt
      FROM xh_sum x
      LEFT JOIN aging_seg_cfg seg
        ON x.aging_days >= seg.aging_seg_fr
       AND x.aging_days <= seg.aging_seg_to
     WHERE COALESCE(x.ar_bukrs, '') <> COALESCE(x.ap_bukrs, '')
       AND COALESCE(x.ap_bukrs, '') <> ''
       AND x.ap_bukrs NOT IN ('9000', '9002', '9003', '9005', '9008')
),
-- OVERDUE / INV_SAMPLE：直接取原字段金额，不再拆成两个冗余包；同一来源表一次聚合后再分流到两个事实输出。
overdue_sample_src AS (
    SELECT ledge_code AS company_code
         , gl_account AS acct_src_code
         , LTRIM(COALESCE(cust_code, ''), '0') AS cust_code
         , cust_name AS cust_name
         , profit_center_code AS profitcenter_code
         , profit_center_name AS profitcenter_name
         , SUM(COALESCE(overdue_adj_after_amt, 0)) AS overdue_amount
         , SUM(COALESCE(inv_sample_amt, 0)) AS inv_sample_amount
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
    HAVING SUM(COALESCE(overdue_adj_after_amt, 0)) <> 0
        OR SUM(COALESCE(inv_sample_amt, 0)) <> 0
),
-- OVERDUE：标准化为窄事实接口，直接取超期款调整后金额。
overdue_fact AS (
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
         , 'FM_WTZJ' AS system_src, 'OVERDUE' AS ods_src
         , NULL AS reb_type, NULL AS ufee_ureb_flag, NULL AS ecls_flag, NULL AS ledger_status, NULL AS acct_cert_type
         , NULL AS tax_rate
         , NULL AS nature_l1_name, NULL AS nature_l2_name, NULL AS nature_l3_name
         , NULL AS exchange_rate_eval_flag, NULL AS is_apar_flag
         , '1' AS aging_seg_code, overdue_amount AS bcy_amt, overdue_amount AS qcy_amt
      FROM overdue_sample_src s
     WHERE COALESCE(overdue_amount, 0) <> 0
),
-- INV_SAMPLE：标准化为窄事实接口，直接取样机款金额。
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
         , 'FM_WTZJ' AS system_src, 'INV_SAMPLE' AS ods_src
         , NULL AS reb_type, NULL AS ufee_ureb_flag, NULL AS ecls_flag, NULL AS ledger_status, NULL AS acct_cert_type
         , NULL AS tax_rate
         , NULL AS nature_l1_name, NULL AS nature_l2_name, NULL AS nature_l3_name
         , NULL AS exchange_rate_eval_flag, NULL AS is_apar_flag
         , '1' AS aging_seg_code, inv_sample_amount AS bcy_amt, inv_sample_amount AS qcy_amt
      FROM overdue_sample_src s
     WHERE COALESCE(inv_sample_amount, 0) <> 0
),
-- SMS/UREB：按最新装载记录聚合各公司、客商和返利类别的余额。
sms_sum AS (
    SELECT company_code
         , org_map.cod_azienda sales_code
         , sname
         , SUM(yue) AS amount
         , leibie
      FROM test.dwd_fi_mr_arap_sms_balance_mi a 
      LEFT JOIN (
                  SELECT DISTINCT TRIM(ent_sap700_code) AS ent_sap700_code
                       , TRIM(cod_azienda) AS cod_azienda
                    FROM ods.odsfima_aw_rul_revaaz_000001
                   WHERE NULLIF(TRIM(ent_sap700_code), '') IS NOT NULL
                ) org_map
        ON a.company_code = org_map.ent_sap700_code
     WHERE dt_month = @dt_month
     GROUP BY company_code
            , org_map.cod_azienda
            , sname
            , leibie
     HAVING SUM(yue) <> 0
),
-- SMS/UREB：标准化为窄事实接口。
sms_fact AS (
    SELECT @dt_month AS dt_month, LEFT(@dt_month, 4) AS `year`, RIGHT(@dt_month, 2) AS `month`
         , company_code AS company_code, sales_code AS cust_code, sname AS cust_name
         , NULL AS cust_head_code, NULL AS cust_head_name
         , NULL AS cust_branch_code, NULL AS cust_branch_name
         , NULL AS cp_company_code, NULL AS country_code, NULL AS country_name
         , NULL AS acct_type_code, NULL AS acct_src_code, NULL AS acct_map_code
         , NULL AS channel_l1_code, NULL AS channel_l1_name
         , NULL AS channel_l2_code, NULL AS channel_l2_name
         , NULL AS channel_l3_code, NULL AS channel_l3_name
         , NULL AS onoffline_code, NULL AS onoffline_name
         , NULL AS src_profitcenter_code, NULL AS src_profitcenter_name
         , NULL AS profitcenter_code, NULL AS profitcenter_name
         , NULL AS bus_range_code, NULL AS bus_range_name
         , NULL AS marketing_dept_code, NULL AS marketing_dept_name
         , NULL AS pay_reason_code, 'CNY' AS bcy_code, 'CNY' AS qcy_code
         , 'SMS' AS system_src, 'UREB' AS ods_src
         , leibie AS reb_type, NULL AS ufee_ureb_flag, NULL AS ecls_flag, NULL AS ledger_status, NULL AS acct_cert_type
         , NULL AS tax_rate
         , NULL AS nature_l1_name, NULL AS nature_l2_name, NULL AS nature_l3_name
         , NULL AS exchange_rate_eval_flag, NULL AS is_apar_flag
         , '1' AS aging_seg_code, amount AS bcy_amt, amount AS qcy_amt
      FROM sms_sum s
     WHERE amount <> 0
),
-- POLICY：保持政策欠付返利的期间筛选、状态维度及非零过滤。
policy_sum AS (
    SELECT sales_group AS company_code
         , customer_code AS cust_code
         , customer_name AS cust_name
         , profit_center AS profitcenter_code
         , NULL AS profitcenter_name
         , policystatename AS ledger_status
         , SUM(COALESCE(arrears_amount, 0)) AS amount
      FROM dwd.dwd_mrs_mc_report_reward_account_detail_new_hi
     WHERE REPLACE(LEFT(period, 7), '-', '') = @dt_month
     GROUP BY sales_group
            , customer_code
            , customer_name
            , profit_center
            , policystatename
),
-- POLICY：标准化为窄事实接口。
policy_fact AS (
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
         , NULL AS src_profitcenter_code, NULL AS src_profitcenter_name
         , profitcenter_code, profitcenter_name
         , NULL AS bus_range_code, NULL AS bus_range_name
         , NULL AS marketing_dept_code, NULL AS marketing_dept_name
         , NULL AS pay_reason_code, 'CNY' AS bcy_code, 'CNY' AS qcy_code
         , 'POLICY' AS system_src, 'POLICY' AS ods_src
         , NULL AS reb_type, NULL AS ufee_ureb_flag, NULL AS ecls_flag, ledger_status, NULL AS acct_cert_type
         , NULL AS tax_rate
         , NULL AS nature_l1_name, NULL AS nature_l2_name, NULL AS nature_l3_name
         , NULL AS exchange_rate_eval_flag, NULL AS is_apar_flag
         , '1' AS aging_seg_code, amount AS bcy_amt, amount AS qcy_amt
      FROM policy_sum s
     WHERE amount <> 0
),
-- WRITEOFF：保留科目映射有效期、审核状态、SAP凭证号和科目范围过滤。
acct_mapping AS (
    SELECT acct_src_code
         , MAX(acct_map_code) AS acct_map_code
      FROM dim.dim_rule_fi_mr_acct_mapping
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY acct_src_code
),
-- WRITEOFF：按公司、客商、原始科目、利润中心和业务范围汇总核销金额。
writeoff_sum AS (
    SELECT o.fnumber AS company_code
         , LTRIM(SUBSTRING_INDEX(cus.fnumber, '(', 1), '0') AS cust_code
         , cus.fname AS cust_name
         , a.fnumber AS acct_src_code
         , CASE WHEN R.fk_hifi_sap_version = 'SAP600'
                  THEN a.fnumber
                ELSE am.acct_map_code
            END AS acct_map_code
         , LTRIM(pf.fnumber, '0') AS profitcenter_code
         , biz.fnumber AS bus_range_code
         , SUM(COALESCE(s.fk_hifi_local_lossmoneys, 0)) AS bcy_amt
         , SUM(COALESCE(s.fk_hifi_lossmoneys, 0)) AS qcy_amt
      FROM ods.odsfmfi_tk_hifi_baddebtverify v
      LEFT JOIN ods.odsfmtss_t_org_org o
        ON o.fid = v.fk_hifi_accountorg
      LEFT JOIN ods.odsfmsecd_tk_hifi_orgs_ref r
        ON o.fid = r.fk_hifi_org_id
      LEFT JOIN ods.odsfmfi_t_bd_period p
        ON p.fid = v.fk_hifi_accountdate
      INNER JOIN ods.odsfmfi_tk_hifi_baddebtverifysub s
        ON s.fid = v.fid
      LEFT JOIN ods.odsfmfi_t_bd_account a
        ON a.fid = s.fk_hifi_subjects
      LEFT JOIN ods.odsfmfi_tk_hifi_cas_profitcenter pf
        ON pf.fid = s.fk_hifi_profitcenter
      LEFT JOIN ods.odsfmfi_tk_hifi_cas_bizrange biz
        ON biz.fid = s.fk_hifi_businessscope
      LEFT JOIN ods.odsfmtss_t_bd_customer cus
        ON cus.fid = s.fk_hifi_customer
      LEFT JOIN acct_mapping am
        ON am.acct_src_code = a.fnumber
     WHERE p.fnumber = @dt_month
       AND v.fbillstatus = 'C'
       AND NULLIF(TRIM(v.fk_hifi_sapvouchernum), '') IS NOT NULL
       AND (
              a.fnumber LIKE '1122%'
           OR a.fnumber LIKE '1131%'
           OR a.fnumber LIKE '1221%'
           OR a.fnumber LIKE '1133%'
           OR a.fnumber = '1460000000'
           OR a.fnumber LIKE '1531%'
       )
     GROUP BY o.fnumber
            , SUBSTRING_INDEX(cus.fnumber, '(', 1)
            , cus.fname
            , a.fnumber
            , CASE WHEN R.fk_hifi_sap_version = 'SAP600'
                    THEN a.fnumber
                  ELSE am.acct_map_code
              END
            , pf.fnumber
            , biz.fnumber
),
-- WRITEOFF：标准化为窄事实接口。
writeoff_fact AS (
    SELECT @dt_month AS dt_month, LEFT(@dt_month, 4) AS `year`, RIGHT(@dt_month, 2) AS `month`
         , company_code, cust_code, cust_name
         , NULL AS cust_head_code, NULL AS cust_head_name
         , NULL AS cust_branch_code, NULL AS cust_branch_name
         , NULL AS cp_company_code, NULL AS country_code, NULL AS country_name
         , 'D' AS acct_type_code, acct_src_code, acct_map_code
         , NULL AS channel_l1_code, NULL AS channel_l1_name
         , NULL AS channel_l2_code, NULL AS channel_l2_name
         , NULL AS channel_l3_code, NULL AS channel_l3_name
         , NULL AS onoffline_code, NULL AS onoffline_name
         , profitcenter_code AS src_profitcenter_code, NULL AS src_profitcenter_name
         , profitcenter_code, NULL AS profitcenter_name
         , bus_range_code, NULL AS bus_range_name
         , NULL AS marketing_dept_code, NULL AS marketing_dept_name
         , NULL AS pay_reason_code, 'CNY' AS bcy_code, 'CNY' AS qcy_code
         , 'FM' AS system_src, 'WRITEOFF' AS ods_src
         , NULL AS reb_type, NULL AS ufee_ureb_flag, NULL AS ecls_flag, NULL AS ledger_status, NULL AS acct_cert_type
         , NULL AS tax_rate
         , NULL AS nature_l1_name, NULL AS nature_l2_name, NULL AS nature_l3_name
         , NULL AS exchange_rate_eval_flag, NULL AS is_apar_flag
         , '1' AS aging_seg_code, bcy_amt AS bcy_amt, qcy_amt AS qcy_amt
      FROM writeoff_sum s
     WHERE COALESCE(bcy_amt, 0) <> 0
        OR COALESCE(qcy_amt, 0) <> 0
),
-- 九类来源以UNION ALL合并；保留来源标识，禁止跨来源误并。
standard_fact AS (
    SELECT * FROM detail_fact

    UNION ALL

    SELECT * FROM xh_ar_fact

    UNION ALL

    SELECT * FROM xh_ap_fact

    UNION ALL

    SELECT * FROM overdue_fact

    UNION ALL

    SELECT * FROM sample_fact

    UNION ALL

    SELECT * FROM sms_fact

    UNION ALL

    SELECT * FROM policy_fact

    UNION ALL

    SELECT * FROM writeoff_fact
),
-- 读取与DETAIL一致的三级性质规则；规则有效期按目标月份过滤。
ar_nature_rule AS (
    SELECT CAST(batch_id AS INT) AS batch_id
         , company_code
         , cust_code
         , profitcenter_code
         , acct_src_code
         , acct_type
         , MAX(nature_l1_name) AS nature_l1_name
         , MAX(nature_l2_name) AS nature_l2_name
         , MAX(nature_l3_name) AS nature_l3_name
      FROM dim.dim_rule_fi_mr_ar_nature
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY CAST(batch_id AS INT)
            , company_code
            , cust_code
            , profitcenter_code
            , acct_src_code
            , acct_type
),
-- 非DETAIL来源按DETAIL的batch 1→5规则做一次性匹配，并按 batch 优先级取最小命中。
ar_nature_candidate AS (
    SELECT f.system_src
         , f.ods_src
         , f.company_code
         , f.cust_code
         , f.acct_src_code
         , f.acct_type_code
         , f.profitcenter_code
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM standard_fact f
      LEFT JOIN ar_nature_rule r
        ON (
               (r.batch_id = 1
                AND r.company_code = f.company_code
                AND r.acct_src_code = f.acct_src_code
                AND r.acct_type = f.acct_type_code
                AND r.cust_code = f.cust_code)
            OR (r.batch_id = 2
                AND r.company_code = f.company_code
                AND r.cust_code = f.cust_code)
            OR (r.batch_id = 3
                AND r.company_code = f.company_code
                AND r.acct_src_code = f.acct_src_code
                AND r.acct_type = f.acct_type_code
                AND r.profitcenter_code = f.profitcenter_code)
            OR (r.batch_id = 4
                AND r.company_code = f.company_code
                AND r.acct_src_code = f.acct_src_code
                AND r.acct_type = f.acct_type_code)
            OR (r.batch_id = 5
                AND r.acct_src_code = f.acct_src_code
                AND r.acct_type = f.acct_type_code
                AND r.cust_code = f.cust_code)
           )
     WHERE f.system_src NOT IN ('S600', 'S700', 'S800', 'S900', 'S610', 'S810')
       AND r.batch_id IS NOT NULL
),
-- 同一来源事实按 batch 优先级取最小命中，避免重复匹配与重复JOIN。
ar_nature_pick AS (
    SELECT system_src
         , ods_src
         , company_code
         , cust_code
         , acct_src_code
         , acct_type_code
         , profitcenter_code
         , nature_l1_name AS mapped_nature_l1_name
         , nature_l2_name AS mapped_nature_l2_name
         , nature_l3_name AS mapped_nature_l3_name
      FROM (
            SELECT c.system_src
                 , c.ods_src
                 , c.company_code
                 , c.cust_code
                 , c.acct_src_code
                 , c.acct_type_code
                 , c.profitcenter_code
                 , c.nature_l1_name
                 , c.nature_l2_name
                 , c.nature_l3_name
                 , ROW_NUMBER() OVER (
                       PARTITION BY c.system_src
                                  , c.ods_src
                                  , c.company_code
                                  , c.cust_code
                                  , c.acct_src_code
                                  , c.acct_type_code
                                  , c.profitcenter_code
                       ORDER BY c.batch_id
                   ) AS rn
              FROM ar_nature_candidate c
      ) x
     WHERE x.rn = 1
),
-- DETAIL直接沿用明细已计算性质，其他来源使用与DETAIL一致的规则结果。
standard_fact_with_nature AS (
    SELECT f.*
         , n.mapped_nature_l1_name
         , n.mapped_nature_l2_name
         , n.mapped_nature_l3_name
      FROM standard_fact f
      LEFT JOIN ar_nature_pick n
        ON f.system_src NOT IN ('S600', 'S700', 'S800', 'S900', 'S610', 'S810')
       AND COALESCE(n.system_src, '') = COALESCE(f.system_src, '')
       AND COALESCE(n.ods_src, '') = COALESCE(f.ods_src, '')
       AND COALESCE(n.company_code, '') = COALESCE(f.company_code, '')
       AND COALESCE(n.cust_code, '') = COALESCE(f.cust_code, '')
       AND COALESCE(n.acct_src_code, '') = COALESCE(f.acct_src_code, '')
       AND COALESCE(n.acct_type_code, '') = COALESCE(f.acct_type_code, '')
       AND COALESCE(n.profitcenter_code, '') = COALESCE(f.profitcenter_code, '')
),
-- 统一外层按完整报告维度汇总；system_src、ods_src纳入维度，账龄金额在本层统一展开。
report_pivot AS (
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
         , CASE
               WHEN system_src IN ('S600', 'S700', 'S800', 'S900', 'S610', 'S810') THEN nature_l1_name
               ELSE COALESCE(mapped_nature_l1_name, nature_l1_name)
           END AS nature_l1_name
         , CASE
               WHEN system_src IN ('S600', 'S700', 'S800', 'S900', 'S610', 'S810') THEN nature_l2_name
               ELSE COALESCE(mapped_nature_l2_name, nature_l2_name)
           END AS nature_l2_name
         , CASE
               WHEN system_src IN ('S600', 'S700', 'S800', 'S900', 'S610', 'S810') THEN nature_l3_name
               ELSE COALESCE(mapped_nature_l3_name, nature_l3_name)
           END AS nature_l3_name
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
      FROM standard_fact_with_nature
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
            , CASE
                  WHEN system_src IN ('S600', 'S700', 'S800', 'S900', 'S610', 'S810') THEN nature_l1_name
                  ELSE COALESCE(mapped_nature_l1_name, nature_l1_name)
              END
            , CASE
                  WHEN system_src IN ('S600', 'S700', 'S800', 'S900', 'S610', 'S810') THEN nature_l2_name
                  ELSE COALESCE(mapped_nature_l2_name, nature_l2_name)
              END
            , CASE
                  WHEN system_src IN ('S600', 'S700', 'S800', 'S900', 'S610', 'S810') THEN nature_l3_name
                  ELSE COALESCE(mapped_nature_l3_name, nature_l3_name)
              END
            , exchange_rate_eval_flag
            , is_apar_flag
)
SELECT p.dt_month
     , p.`year`
     , p.`month`
     , p.company_code
     , p.cust_code
     , p.cust_name
     , p.cust_head_code
     , p.cust_head_name
     , p.cust_branch_code
     , p.cust_branch_name
     , p.cp_company_code
     , p.country_code
     , p.country_name
     , p.acct_type_code
     , p.acct_src_code
     , p.acct_map_code
     , p.channel_l1_code
     , p.channel_l1_name
     , p.channel_l2_code
     , p.channel_l2_name
     , p.channel_l3_code
     , p.channel_l3_name
     , p.onoffline_code
     , p.onoffline_name
     , p.src_profitcenter_code
     , p.src_profitcenter_name
     , p.profitcenter_code
     , p.profitcenter_name
     , p.bus_range_code
     , p.bus_range_name
     , p.marketing_dept_code
     , p.marketing_dept_name
     , p.pay_reason_code
     , p.bcy_code
     , p.qcy_code
     , p.bcy_0_amt
     , p.bcy_1_amt
     , p.bcy_2_amt
     , p.bcy_3_amt
     , p.bcy_4_amt
     , p.bcy_5_amt
     , p.bcy_6_amt
     , p.bcy_7_amt
     , p.bcy_8_amt
     , p.bcy_9_amt
     , p.bcy_10_amt
     , p.bcy_11_amt
     , p.bcy_12_amt
     , p.bcy_13_amt
     , p.bcy_14_amt
     , p.bcy_15_amt
     , p.qcy_0_amt
     , p.qcy_1_amt
     , p.qcy_2_amt
     , p.qcy_3_amt
     , p.qcy_4_amt
     , p.qcy_5_amt
     , p.qcy_6_amt
     , p.qcy_7_amt
     , p.qcy_8_amt
     , p.qcy_9_amt
     , p.qcy_10_amt
     , p.qcy_11_amt
     , p.qcy_12_amt
     , p.qcy_13_amt
     , p.qcy_14_amt
     , p.qcy_15_amt
     , p.system_src
     , p.ods_src
     , p.reb_type
     , p.ufee_ureb_flag
     , p.ecls_flag
     , p.ledger_status
     , p.acct_cert_type
     , p.tax_rate
     , p.nature_l1_name
     , p.nature_l2_name
     , p.nature_l3_name
     , p.exchange_rate_eval_flag
     , p.is_apar_flag
     , c.pay_term_code
     , c.pay_term_desc
     , NOW() AS load_dt
  FROM report_pivot p
  LEFT JOIN cterm_dedup c
    ON c.system_src = p.system_src
   AND c.company_code = p.company_code
   AND c.cust_code = p.cust_code
;

-- ============================================================================
-- 上线前核对项
-- 1. 本脚本仅保留一条 INSERT OVERWRITE TABLE test.dwd_fi_mr_arap_sum_mi PARTITION (*)；完整重跑会一次覆盖写入本次来源覆盖到的目标分区，禁止再执行任何后续追加写入。
-- 2. 执行前须先完成 detail 层；DETAIL排除 acct_map_code 为1122000095、2202000095，两个科目仅由XH应收/XH应付构造。
-- 3. 九类来源均先输出统一窄事实接口，再以 UNION ALL 合并；最终按完整报告维度（含system_src、ods_src）汇总，避免跨来源误并。
-- 4. DETAIL保留真实 aging_seg_code；其他来源统一设置为'1'，最终0桶由1至15桶汇总，保证0桶等于1至15桶之和。
-- 5. 信汇按原票据去重、月末日期、生效月份、失效状态、公司排除清单及9002特殊映射执行；应收为正、应付为负。
-- 6. SMS/UREB使用外围系统 SQL 计算截至参数月末的余额并排除零金额；OVERDUE、INV_SAMPLE均取dws.dws_fi_mr_ar_overdue_mi，POLICY、IMOCC、WRITEOFF的金额、过滤与来源维度均保留原口径。
-- 7. WRITEOFF仍限定已审核、有SAP凭证号及指定科目范围，并按有效期取科目映射；上线前核对其物理表名。另需核对SMS源表dt_month/load_dt及IMOCC month_dt格式。
-- 8. 付款条件在最终金额汇总后，按system_src + company_code + cust_code左关联cterm_dedup，避免关联放大金额。
-- ============================================================================

-- ============================================================================
-- EPAY：提前回款来源。
-- 使用DETAIL已装载的BSID/BSAD数据，按付款原因、科目、基准日期和正负金额计算提前回款。
-- 本段必须在前面的Sum覆盖装载完成后执行。
-- ============================================================================
INSERT INTO test.dwd_fi_mr_arap_sum_mi
(
      dt_month                 -- 年月
    , `year`                   -- 年份
    , `month`                  -- 月份
    , company_code             -- 组织
    , cust_code                -- 客商编码
    , cust_name                -- 客商名称
    , acct_src_code            -- 原始科目编码
    , acct_map_code            -- 映射后科目编码
    , src_profitcenter_code    -- 原始利润中心编码
    , src_profitcenter_name    -- 原始利润中心名称
    , profitcenter_code        -- 映射后利润中心编码
    , profitcenter_name        -- 映射后利润中心名称
    , bus_range_code           -- 业务范围编码
    , bus_range_name           -- 业务范围名称
    , marketing_dept_code      -- 业务管理单元编码
    , marketing_dept_name      -- 业务管理单元名称
    , pay_reason_code          -- 付款原因代码
    , bcy_code                 -- 本位币币种
    , qcy_code                 -- 交易币币种
    , bcy_0_amt                -- 本位币提前回款净额
    , bcy_1_amt                -- 本位币金额-账龄区间段1
    , bcy_2_amt                -- 本位币金额-账龄区间段2
    , bcy_3_amt                -- 本位币金额-账龄区间段3
    , bcy_4_amt                -- 本位币金额-账龄区间段4
    , bcy_5_amt                -- 本位币金额-账龄区间段5
    , bcy_6_amt                -- 本位币金额-账龄区间段6
    , bcy_7_amt                -- 本位币金额-账龄区间段7
    , bcy_8_amt                -- 本位币金额-账龄区间段8
    , bcy_9_amt                -- 本位币金额-账龄区间段9
    , bcy_10_amt               -- 本位币金额-账龄区间段10
    , bcy_11_amt               -- 本位币金额-账龄区间段11
    , bcy_12_amt               -- 本位币金额-账龄区间段12
    , bcy_13_amt               -- 本位币金额-账龄区间段13
    , bcy_14_amt               -- 本位币金额-账龄区间段14
    , bcy_15_amt               -- 本位币金额-账龄区间段15
    , qcy_0_amt                -- 交易币提前回款净额
    , qcy_1_amt                -- 交易币金额-账龄区间段1
    , qcy_2_amt                -- 交易币金额-账龄区间段2
    , qcy_3_amt                -- 交易币金额-账龄区间段3
    , qcy_4_amt                -- 交易币金额-账龄区间段4
    , qcy_5_amt                -- 交易币金额-账龄区间段5
    , qcy_6_amt                -- 交易币金额-账龄区间段6
    , qcy_7_amt                -- 交易币金额-账龄区间段7
    , qcy_8_amt                -- 交易币金额-账龄区间段8
    , qcy_9_amt                -- 交易币金额-账龄区间段9
    , qcy_10_amt               -- 交易币金额-账龄区间段10
    , qcy_11_amt               -- 交易币金额-账龄区间段11
    , qcy_12_amt               -- 交易币金额-账龄区间段12
    , qcy_13_amt               -- 交易币金额-账龄区间段13
    , qcy_14_amt               -- 交易币金额-账龄区间段14
    , qcy_15_amt               -- 交易币金额-账龄区间段15
    , system_src               -- 来源系统
    , ods_src                  -- 数据来源
    , reb_type                 -- 返利性质
    , ufee_ureb_flag           -- 返利/费用标识
    , ecls_flag                -- 电商零售标识
    , ledger_status            -- 台账状态
    , acct_cert_type           -- 凭证类型
    , tax_rate                 -- 税率
    , nature_l1_name           -- 一级性质
    , nature_l2_name           -- 二级性质
    , nature_l3_name           -- 三级性质
    , exchange_rate_eval_flag  -- 汇率评估标识
    , is_apar_flag             -- 账龄是否进数
    , pay_term_code            -- 付款条件代码
    , pay_term_desc            -- 付款条件描述
    , load_dt                  -- 更新时间
)
WITH
-- EPAY：从Detail读取BSID/BSAD数据，按付款原因、科目和月末基准日期筛选。
epay_detail AS (
    SELECT  d.dt_month,d.year,d.month,d.company_code,d.cust_code,d.cust_name
          , d.acct_src_code,d.acct_map_code,d.src_profitcenter_code,d.src_profitcenter_name,d.profitcenter_code,d.profitcenter_name
          , SUM(COALESCE(bcy_amt, 0)) AS bcy_amt
          , system_src
      FROM test.dwd_fi_mr_arap_detail_mi d
     WHERE d.dt_month = @dt_month
       AND d.ods_src IN ('BSID', 'BSAD', 'BSAD_EPAY')
       AND d.pay_reason_code = '400'
       AND d.acct_map_code LIKE '1122%'
       AND d.netrcp_dt <= @last_day
     GROUP BY d.dt_month,d.year,d.month,d.company_code,d.cust_code,d.cust_name
            , d.acct_src_code,d.acct_map_code,d.src_profitcenter_code,d.src_profitcenter_name,d.profitcenter_code,d.profitcenter_name
            , system_src
     HAVING SUM(COALESCE(bcy_amt, 0)) > 0

    UNION ALL

    SELECT d.dt_month,d.year,d.month,d.company_code,d.cust_code,d.cust_name
          , d.acct_src_code,d.acct_map_code,d.src_profitcenter_code,d.src_profitcenter_name,d.profitcenter_code,d.profitcenter_name
          , SUM(COALESCE(bcy_amt, 0)) AS bcy_amt
          , system_src
      FROM test.dwd_fi_mr_arap_detail_mi d
     WHERE d.dt_month = @dt_month
       AND d.ods_src IN ('BSID', 'BSAD', 'BSAD_EPAY')
       AND d.pay_reason_code = '400'
       AND d.acct_map_code LIKE '1122%'
     GROUP BY d.dt_month,d.year,d.month,d.company_code,d.cust_code,d.cust_name
            , d.acct_src_code,d.acct_map_code,d.src_profitcenter_code,d.src_profitcenter_name,d.profitcenter_code,d.profitcenter_name
            , system_src
     HAVING SUM(COALESCE(bcy_amt, 0)) < 0
),
-- EPAY：按当前需要的业务维度汇总正负金额，计算提前回款净额。
epay_sum AS (
    SELECT dt_month
         , `year`
         , `month`
         , company_code
         , cust_code
         , cust_name
         , acct_src_code
         , acct_map_code
         , src_profitcenter_code
         , src_profitcenter_name
         , profitcenter_code
         , profitcenter_name
         , SUM(COALESCE(bcy_amt, 0)) AS bcy_net_amt
         , system_src
      FROM epay_detail
     GROUP BY dt_month
            , `year`
            , `month`
            , company_code
            , cust_code
            , cust_name
            , acct_src_code
            , acct_map_code
            , src_profitcenter_code
            , src_profitcenter_name
            , profitcenter_code
            , profitcenter_name
            , system_src
    HAVING SUM(COALESCE(bcy_amt, 0)) < 0
)
SELECT dt_month
     , `year`
     , `month`
     , company_code
     , cust_code
     , cust_name
     , acct_src_code
     , acct_map_code
     , src_profitcenter_code
     , src_profitcenter_name
     , profitcenter_code
     , profitcenter_name
     , NULL AS bus_range_code
     , NULL AS bus_range_name
     , NULL AS marketing_dept_code
     , NULL AS marketing_dept_name
     , '400' AS pay_reason_code
     , 'CNY' AS bcy_code
     , 'CNY' AS qcy_code
     , bcy_net_amt AS bcy_0_amt
     , bcy_net_amt AS bcy_1_amt
     , 0 AS bcy_2_amt
     , 0 AS bcy_3_amt
     , 0 AS bcy_4_amt
     , 0 AS bcy_5_amt
     , 0 AS bcy_6_amt
     , 0 AS bcy_7_amt
     , 0 AS bcy_8_amt
     , 0 AS bcy_9_amt
     , 0 AS bcy_10_amt
     , 0 AS bcy_11_amt
     , 0 AS bcy_12_amt
     , 0 AS bcy_13_amt
     , 0 AS bcy_14_amt
     , 0 AS bcy_15_amt
     , bcy_net_amt AS qcy_0_amt
     , bcy_net_amt AS qcy_1_amt
     , 0 AS qcy_2_amt
     , 0 AS qcy_3_amt
     , 0 AS qcy_4_amt
     , 0 AS qcy_5_amt
     , 0 AS qcy_6_amt
     , 0 AS qcy_7_amt
     , 0 AS qcy_8_amt
     , 0 AS qcy_9_amt
     , 0 AS qcy_10_amt
     , 0 AS qcy_11_amt
     , 0 AS qcy_12_amt
     , 0 AS qcy_13_amt
     , 0 AS qcy_14_amt
     , 0 AS qcy_15_amt
     , system_src AS system_src
     , 'EPAY' AS ods_src
     , NULL AS reb_type
     , NULL AS ufee_ureb_flag
     , NULL AS ecls_flag
     , NULL AS ledger_status
     , NULL AS acct_cert_type
     , NULL AS tax_rate
     , NULL AS nature_l1_name
     , NULL AS nature_l2_name
     , NULL AS nature_l3_name
     , NULL AS exchange_rate_eval_flag
     , NULL AS is_apar_flag
     , NULL AS pay_term_code
     , NULL AS pay_term_desc
     , NOW() AS load_dt
  FROM epay_sum;
