-- ============================================================================
-- SAP 应收应付账龄月度凭证明细脚本（Apache Doris）
-- 唯一运行参数：@year_month_day，格式 YYYYMMDD，日期固定为当月01日，例如 20260801
-- 关键日：参数月份最后一天；账龄口径：默认按 BLDAT，AB 凭证按 ZFBDT
-- 公司范围：所有在 ZTZT_003 中配置了统驭科目范围的公司
-- 源表：S600 ODS 的 BSID/BSAD/BSIK/BSAK/T001/SKB1/KNA1/LFA1/CEPCT
-- 待入湖配置表：dwd.ztzt_003（当前脚本执行前置条件）
-- 注意：本版按凭证明细输出，不再按账龄区间聚合。
-- ============================================================================

SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');

-- ----------------------------------------------------------------------------
-- 1. 目标表 DDL
-- 若同名表已按旧版汇总结构创建，CREATE TABLE IF NOT EXISTS 不会迁移结构，
-- 上线前需通过 ALTER TABLE 或影子表切换完成结构变更。
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS test.dwd_fi_ar_ap_aging_mi (
    dt_month                   VARCHAR(6) COMMENT '年月YYYYMM',
    `year`                     VARCHAR(4) COMMENT '年份',
    `month`                    VARCHAR(2) COMMENT '月份',
    company_code               VARCHAR(8) COMMENT '组织',
    acct_cert_type             VARCHAR(10) COMMENT '凭证类型',
    acct_cert_no               VARCHAR(20) COMMENT '凭证编号',
    posting_dt                 DATE COMMENT '凭证过账日期',
    baseline_dt                DATE COMMENT '基准日期',
    clearing_dt                DATE COMMENT '清账日期',
    cust_code                  VARCHAR(20) COMMENT '主户编码',
    cust_name                  VARCHAR(200) COMMENT '主户名称',
    branch_code                VARCHAR(20) COMMENT '分户编码',
    branch_name                VARCHAR(200) COMMENT '分户名称',
    cp_company_code            VARCHAR(20) COMMENT '对方公司',
    country_code               VARCHAR(10) COMMENT '国家',
    acct_type_code             VARCHAR(10) COMMENT '科目类型：D应收，K应付',
    acct_src_code              VARCHAR(30) COMMENT '科目编码',
    acct_map_code              VARCHAR(30) COMMENT '映射后科目编码',
    channel_l1_code            VARCHAR(30) COMMENT '一级公司分类编码',
    channel_l1_name            VARCHAR(200) COMMENT '一级公司分类名称',
    channel_l2_code            VARCHAR(30) COMMENT '二级公司分类编码',
    channel_l2_name            VARCHAR(200) COMMENT '二级公司分类名称',
    channel_l3_code            VARCHAR(30) COMMENT '三级公司分类编码',
    channel_l3_name            VARCHAR(200) COMMENT '三级公司分类名称',
    onoffline_code             VARCHAR(30) COMMENT '渠道分组编码',
    onoffline_name             VARCHAR(200) COMMENT '渠道分组名称',
    src_profitcenter_code      VARCHAR(200) COMMENT '原始利润中心编码',
    src_profitcenter_name      VARCHAR(200) COMMENT '原始利润中心名称',
    profitcenter_code          VARCHAR(20) COMMENT '利润中心编码（映射后，待补）',
    profitcenter_name          VARCHAR(200) COMMENT '利润中心名称（映射后，待补）',
    bus_range_code             VARCHAR(20) COMMENT '业务范围编码',
    bus_range_name             VARCHAR(200) COMMENT '业务范围名称',
    marketing_dept_code        VARCHAR(30) COMMENT '业务管理单元编码',
    marketing_dept_name        VARCHAR(200) COMMENT '业务管理单元名称',
    pay_reason_code            VARCHAR(20) COMMENT '付款原因代码',
    bcy_code                   VARCHAR(8) COMMENT '本位币币种',
    qcy_code                   VARCHAR(8) COMMENT '交易币币种',
    bcy_amt                    DECIMAL(23,2) COMMENT '本位币金额',
    qcy_amt                    DECIMAL(23,2) COMMENT '交易币金额',
    closing_rate_bcy_amt       DECIMAL(23,2) COMMENT '期末汇率余额',
    posting_rate_bcy_amt       DECIMAL(23,2) COMMENT '记账汇率余额',
    exchange_rate_eval_flag    VARCHAR(10) COMMENT '汇率评估标识',
    currency_acct_detail       VARCHAR(1000) COMMENT '币种科目构成明细',
    aging_days                 INT COMMENT '账龄天数',
    system_src                 VARCHAR(20) COMMENT 'SAP系统号',
    ods_src                    VARCHAR(100) COMMENT '数据来源',
    load_dt                    DATETIME COMMENT '更新时间'
)
ENGINE = OLAP
DUPLICATE KEY(dt_month, `year`, `month`, company_code, acct_cert_type, acct_cert_no)
COMMENT '应收应付账龄凭证明细表'
AUTO PARTITION BY LIST (dt_month) ()
DISTRIBUTED BY HASH(company_code) BUCKETS 10
PROPERTIES (
    "replication_allocation" = "tag.location.default: 1"
);

-- ----------------------------------------------------------------------------
-- 2. 月度重跑
-- AUTO PARTITION 会在写入时自动创建月份 LIST 分区。
-- INSERT OVERWRITE PARTITION(*) 覆盖本次 SELECT 涉及的月份分区。
-- ----------------------------------------------------------------------------
INSERT OVERWRITE TABLE test.dwd_fi_ar_ap_aging_mi PARTITION (*)
(
      dt_month                  -- 年月
    , `year`                    -- 年份
    , `month`                   -- 月份
    , company_code              -- 组织
    , acct_cert_type            -- 凭证类型
    , acct_cert_no              -- 凭证编号
    , posting_dt                -- 凭证过账日期
    , baseline_dt               -- 账龄起算日期
    , clearing_dt               -- 清账日期
    , cust_code                 -- 客商编码
    , cust_name                 -- 客商名称
    , branch_code               -- 分户编码
    , branch_name               -- 分户名称
    , cp_company_code           -- 对方公司
    , country_code              -- 国家编码
    , acct_type_code            -- 科目类型
    , acct_src_code             -- 原始科目编码
    , acct_map_code             -- 映射后科目编码
    , channel_l1_code           -- 一级公司分类编码
    , channel_l1_name           -- 一级公司分类名称
    , channel_l2_code           -- 二级公司分类编码
    , channel_l2_name           -- 二级公司分类名称
    , channel_l3_code           -- 三级公司分类编码
    , channel_l3_name           -- 三级公司分类名称
    , onoffline_code            -- 渠道分组编码
    , onoffline_name            -- 渠道分组名称
    , src_profitcenter_code     -- 原始利润中心编码
    , src_profitcenter_name     -- 原始利润中心名称
    , profitcenter_code         -- 映射后利润中心编码
    , profitcenter_name         -- 映射后利润中心名称
    , bus_range_code             -- 业务范围编码
    , bus_range_name             -- 业务范围名称
    , marketing_dept_code        -- 业务管理单元编码
    , marketing_dept_name        -- 业务管理单元名称
    , pay_reason_code            -- 付款原因代码
    , bcy_code                   -- 本位币币种
    , qcy_code                   -- 交易币币种
    , bcy_amt                    -- 本位币金额
    , qcy_amt                    -- 交易币金额
    , closing_rate_bcy_amt       -- 期末汇率本位币金额
    , posting_rate_bcy_amt       -- 记账汇率本位币金额
    , exchange_rate_eval_flag    -- 汇率评估标识
    , currency_acct_detail       -- 币种账务明细
    , aging_days                 -- 账龄天数
    , system_src                -- 来源系统
    , ods_src                   -- 数据来源
    , load_dt                   -- 更新时间
)
WITH
params AS (
    SELECT
        LEFT(@year_month_day, 6) AS dt_month,
        LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d')) AS key_date,
        DATE_FORMAT(
            LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d')),
            '%Y%m%d'
        ) AS key_date_sap
),

-- 公司代码 + 科目必须同时匹配，防止不同公司的科目配置互相污染。
account_cfg AS (
    SELECT DISTINCT
        t.bukrs AS company_code,
        s.saknr AS acct_code,
        s.mitkz AS acct_type_code
    FROM dwd.ztzt_003 z
    INNER JOIN ods.odss600_t001 t
        ON t.ktopl = z.ktopl
    INNER JOIN ods.odss600_skb1 s
        ON s.bukrs = t.bukrs
       AND s.saknr BETWEEN z.hkonf AND z.hkont
       AND s.mitkz IN ('D', 'K')
),

-- ----------------------------------------------------------------------------
-- 3. 还原关键日未清项并保留凭证明细
-- 未清表：过账日不晚于关键日；已清表：另需清账日晚于关键日。
-- ----------------------------------------------------------------------------
ar_open AS (
    SELECT
        b.bukrs, 'D' AS koart, b.kunnr AS cust_code, b.hkont,
        'S600' AS system_src, 'odsslt_s600_bsid' AS ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr
    FROM ods.odsslt_s600_bsid b
    INNER JOIN account_cfg c
        ON c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = 'D'
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
      AND COALESCE(b.bstat, '') NOT IN ('A', 'S')
),
ar_cleared AS (
    SELECT
        b.bukrs, 'D' AS koart, b.kunnr AS cust_code, b.hkont,
        'S600' AS system_src, 'odsslt_s600_bsad' AS ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr
    FROM ods.odsslt_s600_bsad b
    INNER JOIN account_cfg c
        ON c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = 'D'
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
      AND b.augdt > p.key_date_sap
      AND COALESCE(b.bstat, '') NOT IN ('A', 'S')
),
ap_open AS (
    SELECT
        b.bukrs, 'K' AS koart, b.lifnr AS cust_code, b.hkont,
        'S600' AS system_src, 'odsslt_s600_bsik' AS ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr
    FROM ods.odsslt_s600_bsik b
    INNER JOIN account_cfg c
        ON c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = 'K'
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
      AND COALESCE(b.bstat, '') NOT IN ('A', 'S')
),
ap_cleared AS (
    SELECT
        b.bukrs, 'K' AS koart, b.lifnr AS cust_code, b.hkont,
        'S600' AS system_src, 'odsslt_s600_bsak' AS ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr
    FROM ods.odsslt_s600_bsak b
    INNER JOIN account_cfg c
        ON c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = 'K'
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
      AND b.augdt > p.key_date_sap
      AND COALESCE(b.bstat, '') NOT IN ('A', 'S')
),
all_items AS (
    SELECT * FROM ar_open
    UNION ALL
    SELECT * FROM ar_cleared
    UNION ALL
    SELECT * FROM ap_open
    UNION ALL
    SELECT * FROM ap_cleared
),

-- 科目映射按“映射前科目 + SAP系统”匹配。
acct_mapping AS (
    SELECT racct_src_code, acct_map_code, system_src
    FROM (
        SELECT
            a.acct_src_code AS racct_src_code,
            a.acct_map_code,
            a.system_src,
            ROW_NUMBER() OVER (
                PARTITION BY a.acct_src_code, a.system_src
                ORDER BY a.valid_fr DESC,
                         NVL(a.valid_to, '999999') DESC,
                         a.acct_map_code
            ) AS rn
        FROM dim.dim_rule_fi_mr_acct_mapping a
        WHERE a.valid_fr <= LEFT(@year_month_day, 6)
          AND NVL(a.valid_to, '999999') >= LEFT(@year_month_day, 6)
    ) t
    WHERE rn = 1
),

-- ABAP默认按凭证日期BLDAT计算账龄；AB类型凭证改用基准日期ZFBDT。
-- SAP借贷标识H为贷方，金额取负。
normalized_items AS (
    SELECT
        a.bukrs AS company_code,
        a.blart AS acct_cert_type,
        a.belnr AS acct_cert_no,
        STR_TO_DATE(NULLIF(NULLIF(TRIM(a.budat), ''), '00000000'), '%Y%m%d') AS posting_dt,
        STR_TO_DATE(NULLIF(NULLIF(TRIM(a.zfbdt), ''), '00000000'), '%Y%m%d') AS baseline_dt,
        STR_TO_DATE(NULLIF(NULLIF(TRIM(a.augdt), ''), '00000000'), '%Y%m%d') AS clearing_dt,
        a.cust_code,
        a.koart AS acct_type_code,
        a.hkont AS acct_src_code,
        acct_map.acct_map_code,
        COALESCE(a.filkd, '') AS branch_code,
        COALESCE(a.prctr, '') AS src_profitcenter_code,
        COALESCE(a.gsber, '') AS bus_range_code,
        COALESCE(a.waers, '') AS qcy_code,
        CASE WHEN a.shkzg = 'H' THEN -a.dmbtr ELSE a.dmbtr END AS bcy_amt,
        CASE WHEN a.shkzg = 'H' THEN -a.wrbtr ELSE a.wrbtr END AS qcy_amt,
        DATEDIFF(
            p.key_date,
            STR_TO_DATE(
                NULLIF(
                    NULLIF(TRIM(CASE WHEN a.blart = 'AB' THEN a.zfbdt ELSE a.bldat END), ''),
                    '00000000'
                ),
                '%Y%m%d'
            )
        ) + 1 AS aging_days,
        a.system_src,
        a.ods_src
    FROM all_items a
    CROSS JOIN params p
    LEFT JOIN acct_mapping acct_map
        ON a.hkont = acct_map.racct_src_code
       AND a.system_src = acct_map.system_src
    WHERE STR_TO_DATE(
              NULLIF(
                  NULLIF(TRIM(CASE WHEN a.blart = 'AB' THEN a.zfbdt ELSE a.bldat END), ''),
                  '00000000'
              ),
              '%Y%m%d'
          ) IS NOT NULL
),

-- 维表先压成唯一键，避免主数据重复导致明细金额膨胀。
customer_dim AS (
    SELECT
        LTRIM(kunnr, '0') AS kunnr,
        MAX(name1) AS name1,
        MAX(zkunnr_mdg) AS zkunnr_mdg
    FROM ods.ods_slt_s600_kna1
    GROUP BY LTRIM(kunnr, '0')
),
-- 公司一二三级分类：S600客户号 -> MDG客户号 -> 客户基础维表。
-- 仅应收客户使用该链路；应付供应商无对应客户分类时保持NULL。
customer_class_dim AS (
    SELECT
        cust_code,
        MAX(com_1st_code) AS com_1st_code,
        MAX(com_1st_name) AS com_1st_name,
        MAX(com_2nd_code) AS com_2nd_code,
        MAX(com_2nd_name) AS com_2nd_name,
        MAX(com_3rd_code) AS com_3rd_code,
        MAX(com_3rd_name) AS com_3rd_name
    FROM dw.dim_customer_base_info_dd
    GROUP BY cust_code
),
vendor_dim AS (
    SELECT lifnr, MAX(name1) AS name1
    FROM ods.odsslt_s600_lfa1
    GROUP BY lifnr
),
company_dim AS (
    SELECT bukrs, MAX(waers) AS waers
    FROM ods.odss600_t001
    GROUP BY bukrs
),
profitcenter_dim AS (
    SELECT prctr, MAX(ktext) AS ktext
    FROM ods.odss600_cepct
    WHERE spras = '1'
    GROUP BY prctr
)

-- ----------------------------------------------------------------------------
-- 4. 补充描述并按目标表字段顺序写入当月分区
-- 尚无可靠取数逻辑的字段使用带类型NULL占位。
-- ----------------------------------------------------------------------------
SELECT
    p.dt_month,
    LEFT(p.dt_month, 4) AS `year`,
    RIGHT(p.dt_month, 2) AS `month`,
    a.company_code,
    a.acct_cert_type,
    a.acct_cert_no,
    a.posting_dt,
    a.baseline_dt,
    a.clearing_dt,
    a.cust_code,
    CASE
        WHEN a.acct_type_code = 'D' THEN COALESCE(c.name1, '')
        WHEN a.acct_type_code = 'K' THEN COALESCE(v.name1, '')
        ELSE ''
    END AS cust_name,
    a.branch_code,
    COALESCE(bc.name1, '') AS branch_name,
    CAST(NULL AS VARCHAR(20)) AS cp_company_code,
    CAST(NULL AS VARCHAR(10)) AS country_code,
    a.acct_type_code,
    a.acct_src_code,
    a.acct_map_code,
    ch.com_1st_code AS channel_l1_code,
    ch.com_1st_name AS channel_l1_name,
    ch.com_2nd_code AS channel_l2_code,
    ch.com_2nd_name AS channel_l2_name,
    ch.com_3rd_code AS channel_l3_code,
    ch.com_3rd_name AS channel_l3_name,
    CAST(NULL AS VARCHAR(30)) AS onoffline_code,
    CAST(NULL AS VARCHAR(200)) AS onoffline_name,
    a.src_profitcenter_code,
    COALESCE(pc.ktext, '') AS src_profitcenter_name,
    CAST(NULL AS VARCHAR(20)) AS profitcenter_code,
    CAST(NULL AS VARCHAR(200)) AS profitcenter_name,
    a.bus_range_code,
    CAST(NULL AS VARCHAR(200)) AS bus_range_name,
    CAST(NULL AS VARCHAR(30)) AS marketing_dept_code,
    CAST(NULL AS VARCHAR(200)) AS marketing_dept_name,
    CAST(NULL AS VARCHAR(20)) AS pay_reason_code,
    COALESCE(co.waers, '') AS bcy_code,
    a.qcy_code,
    a.bcy_amt,
    a.qcy_amt,
    CAST(NULL AS DECIMAL(23,2)) AS closing_rate_bcy_amt,
    a.bcy_amt AS posting_rate_bcy_amt,
    CAST(NULL AS VARCHAR(10)) AS exchange_rate_eval_flag,
    CAST(NULL AS VARCHAR(1000)) AS currency_acct_detail,
    a.aging_days,
    a.system_src,
    a.ods_src,
    NOW() AS load_dt
FROM normalized_items a
CROSS JOIN params p
LEFT JOIN customer_dim c
    ON a.acct_type_code = 'D'
   AND c.kunnr = LTRIM(a.cust_code, '0')
LEFT JOIN customer_class_dim ch
    ON a.acct_type_code = 'D'
   AND ch.cust_code = c.zkunnr_mdg
LEFT JOIN vendor_dim v
    ON a.acct_type_code = 'K'
   AND v.lifnr = a.cust_code
LEFT JOIN customer_dim bc
    ON bc.kunnr = LTRIM(a.branch_code, '0')
LEFT JOIN company_dim co
    ON co.bukrs = a.company_code
LEFT JOIN profitcenter_dim pc
    ON pc.prctr = a.src_profitcenter_code
;

-- ============================================================================
-- 上线前核对项
-- 1. 同名目标表若仍是旧汇总结构，需先完成DDL迁移；IF NOT EXISTS不会自动改列。
-- 2. 核对四张ODS表均已入湖BELNR/BUDAT/AUGDT字段，且日期格式为YYYYMMDD。
-- 3. posting_rate_bcy_amt暂按SAP本位币金额DMBTR取值；期末汇率余额待接入汇率表。
-- 4. cp_company_code/country_code/渠道分组/业务范围名称/业务管理单元/
--    付款原因/汇率评估标识/币种科目明细暂置NULL，待规则确认后补充。
-- 5. 公司一二三级分类仅按应收主户匹配：KUNNR去前导零后取ZKUNNR_MDG，
--    再关联dw.dim_customer_base_info_dd；应付供应商分类暂为NULL。
-- 6. 科目映射表不限制system_src取值，事实数据按acct_src_code + system_src双键匹配。
-- 7. 若ODS金额仍是SAP内部币种小数格式，须按TCURX在normalized_items前转换。
-- 8. CEPCT若同时存多个控制范围，应增加KOKRS/DATBI关联，不能只按PRCTR。
-- 9. 当前仅覆盖客户/供应商统驭科目；非统驭科目BSIS/BSAS待规则确认后并入。
-- ============================================================================