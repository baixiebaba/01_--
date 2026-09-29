-- ============================================================================
-- 客户超期款月度明细（Apache Doris）
-- 来源表：dws.dws_fi_mr_wtzjcqkmx_mi
-- 目标表：test.dwd_fi_mr_ar_odue_mi
-- 参数：@year_month_day，格式YYYYMMDD，按参数月份重跑。
-- 注意：本脚本独立写入超期款DWD，不写入应收应付账龄凭证明细表。
-- ============================================================================

SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');

CREATE TABLE IF NOT EXISTS test.dwd_fi_mr_ar_odue_mi (
    `year`                    VARCHAR(4) COMMENT '年份',
    `month`                   VARCHAR(2) COMMENT '月份',
    company_code              VARCHAR(8) COMMENT '组织',
    acct_src_code             VARCHAR(850) COMMENT '科目编码',
    cust_code                 VARCHAR(200) COMMENT '客商编码',
    cust_name                 VARCHAR(200) COMMENT '客商名称',
    src_profitcenter_code     VARCHAR(200) COMMENT '原始利润中心编码',
    src_profitcenter_name     VARCHAR(200) COMMENT '原始利润中心名称',
    profitcenter_code         VARCHAR(200) COMMENT '利润中心编码',
    profitcenter_name         VARCHAR(200) COMMENT '利润中心名称',
    odue_amt                  DECIMALV3(27, 9) COMMENT '超期款金额',
    bill_model_amt            DECIMALV3(27, 9) COMMENT '开票样机金额',
    aging_days                DECIMALV3(27, 9) COMMENT '账龄天数',
    ods_src                   VARCHAR(200) COMMENT '数据来源',
    load_dt                   DATE COMMENT '更新时间'
)
ENGINE = OLAP
DUPLICATE KEY(`year`, `month`, company_code)
COMMENT '客户超期款月度明细表'
DISTRIBUTED BY HASH(company_code) BUCKETS 10
PROPERTIES (
    "replication_allocation" = "tag.location.default: 1"
);

-- 按参数月份删除后重跑，避免重复写入。
DELETE FROM test.dwd_fi_mr_ar_odue_mi
WHERE `year` = LEFT(@year_month_day, 4)
  AND `month` = SUBSTR(@year_month_day, 5, 2);

INSERT INTO test.dwd_fi_mr_ar_odue_mi
(
      `year`                   -- 年份
    , `month`                  -- 月份
    , company_code             -- 组织
    , acct_src_code            -- 原始科目编码
    , cust_code                -- 客商编码
    , cust_name                -- 客商名称
    , src_profitcenter_code    -- 原始利润中心编码
    , src_profitcenter_name    -- 原始利润中心名称
    , profitcenter_code        -- 利润中心编码
    , profitcenter_name        -- 利润中心名称
    , odue_amt                 -- 超期款金额
    , bill_model_amt           -- 开票样机金额
    , aging_days               -- 账龄天数
    , ods_src                  -- 数据来源
    , load_dt                  -- 更新时间
)
WITH overdue_src AS (
    SELECT
        ledge_code,
        gl_account,
        cust_code,
        cust_name,
        profit_center_code,
        profit_center_name,
        overdue_amt,
        inv_sample_amt,
        data_source,
        load_dt
    FROM dws.dws_fi_mr_wtzjcqkmx_mi
    WHERE DATE_FORMAT(CAST(start_dt AS DATE), '%Y%m') = LEFT(@year_month_day, 6)
)
SELECT
    LEFT(@year_month_day, 4) AS `year`,
    SUBSTR(@year_month_day, 5, 2) AS `month`,
    CAST(s.ledge_code AS VARCHAR(8)) AS company_code,
    CAST(s.gl_account AS VARCHAR(850)) AS acct_src_code,
    LTRIM(COALESCE(s.cust_code, ''), '0') AS cust_code,
    CAST(s.cust_name AS VARCHAR(200)) AS cust_name,
    CAST(NULL AS VARCHAR(200)) AS src_profitcenter_code,
    CAST(NULL AS VARCHAR(200)) AS src_profitcenter_name,
    CAST(s.profit_center_code AS VARCHAR(200)) AS profitcenter_code,
    CAST(s.profit_center_name AS VARCHAR(200)) AS profitcenter_name,
    CAST(s.overdue_amt AS DECIMALV3(27, 9)) AS odue_amt,
    CAST(s.inv_sample_amt AS DECIMALV3(27, 9)) AS bill_model_amt,
    CAST(NULL AS DECIMALV3(27, 9)) AS aging_days,
    CAST(
        COALESCE(
            NULLIF(TRIM(s.data_source), ''),
            'dws_fi_mr_wtzjcqkmx_mi'
        ) AS VARCHAR(200)
    ) AS ods_src,
    COALESCE(CAST(s.load_dt AS DATE), CURDATE()) AS load_dt
FROM overdue_src s
;

-- ============================================================================
-- 字段口径说明
-- 1. company_code暂沿用原骨架口径取ledge_code。
-- 2. acct_src_code取gl_account；cust_code去除左侧前导零。
-- 3. 来源字段profit_center_code/name按映射后利润中心写入，原始利润中心暂无来源，置NULL。
-- 4. odue_amt取overdue_amt；bill_model_amt取inv_sample_amt。
-- 5. 来源表只有超期月份桶和金额，没有逐笔精确账龄天数，aging_days暂置NULL，不能由月份桶反推。
-- 6. CREATE TABLE IF NOT EXISTS不会迁移已存在的旧表结构，上线前需核对目标表实际DDL。
-- 7. 来源表schema、start_dt及金额字段类型尚未连接Doris执行验证。
-- ============================================================================