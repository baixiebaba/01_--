-- ============================================================================
-- SAP 应收应付账龄月度凭证明细脚本（Apache Doris）
-- 唯一运行参数：@year_month_day，格式 YYYYMMDD，日期固定为当月01日，例如 20260801
-- 关键日：参数月份最后一天；统驭项目默认按 BLDAT、AB 凭证按 ZFBDT，BSIS/BSAS 按ABAP固定关键日
-- 公司范围：六套SAP系统中各自ZTZT_003配置的统驭及非统驭科目范围
-- 系统范围：S600/S700/S800/S900/S610/S810
-- 源表：各系统的 ZTZT_003/T001/SKB1/BSID/BSAD/BSIK/BSAK/BSIS/BSAS/KNA1/LFA1/CEPCT
-- 物理表命名约定：ods.odss{系统号}_{表名}；新增BSIS/BSAS物理表名上线前需确认
-- 注意：本版按凭证明细输出，不再按账龄区间聚合。
-- ============================================================================

SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');

-- ----------------------------------------------------------------------------
-- 1. 目标表 DDL
-- 若同名表已按旧版汇总结构创建，CREATE TABLE IF NOT EXISTS 不会迁移结构，
-- 上线前需通过 ALTER TABLE 或影子表切换完成结构变更。
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS test.dwd_fi_mr_arap_detail_mi (
    dt_month                   VARCHAR(6) COMMENT '年月YYYYMM',
    `year`                     VARCHAR(4) COMMENT '年份',
    `month`                    VARCHAR(2) COMMENT '月份',
    company_code               VARCHAR(8) COMMENT '组织',
    acct_cert_type             VARCHAR(10) COMMENT '凭证类型',
    acct_cert_no               VARCHAR(20) COMMENT '凭证编号',
    posting_dt                 DATE COMMENT '凭证过账日期',
    baseline_dt                DATE COMMENT '账龄基准日期：统驭AB取ZFBDT，其他取BLDAT；BSIS/BSAS取关键日',
    clearing_dt                DATE COMMENT '清账日期',
    cust_branch_code           VARCHAR(20) COMMENT '分户编码',
    cust_branch_name           VARCHAR(200) COMMENT '分户名称',
    cust_head_code             VARCHAR(200) COMMENT '主户编码',
    cust_head_name             VARCHAR(200) COMMENT '主户名称',
    cust_code                  VARCHAR(200) COMMENT '客商编码：优先分户，无分户取主户',
    cust_name                  VARCHAR(200) COMMENT '客商名称：优先分户，无分户取主户',
    cp_company_code            VARCHAR(20) COMMENT '对方公司',
    country_code               VARCHAR(10) COMMENT '国家编码',
    county_name                VARCHAR(200) COMMENT '国家名称',
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
    bcy_amt                    DECIMALV3(27, 9) COMMENT '本位币金额',
    qcy_amt                    DECIMALV3(27, 9) COMMENT '交易币金额',
    closing_rate_bcy_amt       DECIMALV3(27, 9) COMMENT '期末汇率余额',
    posting_rate_bcy_amt       DECIMALV3(27, 9) COMMENT '记账汇率余额',
    exchange_rate_eval_flag    VARCHAR(10) COMMENT '汇率评估标识',
    currency_acct_detail       VARCHAR(1000) COMMENT '币种科目构成明细',
    aging_days                 INT COMMENT '账龄天数：统驭按基准日计算；BSIS/BSAS按ABAP固定为1',
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
INSERT OVERWRITE TABLE test.dwd_fi_mr_arap_detail_mi PARTITION (*)
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
    , cust_branch_code          -- 分户编码
    , cust_branch_name          -- 分户名称
    , cust_head_code            -- 主户编码
    , cust_head_name            -- 主户名称
    , cust_code                 -- 客商编码
    , cust_name                 -- 客商名称
    , cp_company_code           -- 对方公司
    , country_code              -- 国家编码
    , county_name               -- 国家名称
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
    , bus_range_code            -- 业务范围编码
    , bus_range_name            -- 业务范围名称
    , marketing_dept_code       -- 业务管理单元编码
    , marketing_dept_name       -- 业务管理单元名称
    , pay_reason_code           -- 付款原因代码
    , bcy_code                  -- 本位币币种
    , qcy_code                  -- 交易币币种
    , bcy_amt                   -- 本位币金额
    , qcy_amt                   -- 交易币金额
    , closing_rate_bcy_amt      -- 期末汇率本位币金额
    , posting_rate_bcy_amt      -- 记账汇率本位币金额
    , exchange_rate_eval_flag   -- 汇率评估标识
    , currency_acct_detail      -- 币种账务明细
    , aging_days                -- 账龄天数
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

-- ----------------------------------------------------------------------------
-- 3. 六套SAP系统源表标准化
-- 每个源CTE显式带出system_src；下游所有事实、配置和维表均按system_src隔离。
-- ----------------------------------------------------------------------------
src_ztzt_003 AS (
    SELECT 'S600' AS system_src, ktopl, hkonf, hkont, koart FROM ods.odss600_ztzt_003
    UNION ALL
    SELECT 'S700', ktopl, hkonf, hkont, koart FROM ods.odss700_ztzt_003
    UNION ALL
    SELECT 'S800', ktopl, hkonf, hkont, koart FROM ods.odss800_ztzt_003
    UNION ALL
    SELECT 'S900', ktopl, hkonf, hkont, koart FROM ods.odss900_ztzt_003
    UNION ALL
    SELECT 'S610', ktopl, hkonf, hkont, koart FROM ods.odss610_ztzt_003
    UNION ALL
    SELECT 'S810', ktopl, hkonf, hkont, koart FROM ods.odss810_ztzt_003
),
src_t001 AS (
    SELECT 'S600' AS system_src, bukrs, ktopl, waers FROM ods.odss600_t001
    UNION ALL
    SELECT 'S700', bukrs, ktopl, waers FROM ods.odss700_t001
    UNION ALL
    SELECT 'S800', bukrs, ktopl, waers FROM ods.odss800_t001
    UNION ALL
    SELECT 'S900', bukrs, ktopl, waers FROM ods.odss900_t001
    UNION ALL
    SELECT 'S610', bukrs, ktopl, waers FROM ods.odss610_t001
    UNION ALL
    SELECT 'S810', bukrs, ktopl, waers FROM ods.odss810_t001
),
src_skb1 AS (
    SELECT 'S600' AS system_src, bukrs, saknr, mitkz FROM ods.odss600_skb1
    UNION ALL
    SELECT 'S700', bukrs, saknr, mitkz FROM ods.odss700_skb1
    UNION ALL
    SELECT 'S800', bukrs, saknr, mitkz FROM ods.odss800_skb1
    UNION ALL
    SELECT 'S900', bukrs, saknr, mitkz FROM ods.odss900_skb1
    UNION ALL
    SELECT 'S610', bukrs, saknr, mitkz FROM ods.odss610_skb1
    UNION ALL
    SELECT 'S810', bukrs, saknr, mitkz FROM ods.odss810_skb1
),
src_bsid AS (
    SELECT 'S600' AS system_src, 'bsid' AS ods_src,
           bukrs, kunnr AS cust_code, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss600_bsid
    UNION ALL
    SELECT 'S700', 'bsid', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss700_bsid
    UNION ALL
    SELECT 'S800', 'bsid', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss800_bsid
    UNION ALL
    SELECT 'S900', 'bsid', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss900_bsid
    UNION ALL
    SELECT 'S610', 'bsid', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss610_bsid
    UNION ALL
    SELECT 'S810', 'bsid', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss810_bsid
),
src_bsad AS (
    SELECT 'S600' AS system_src, 'bsad' AS ods_src,
           bukrs, kunnr AS cust_code, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss600_bsad
    UNION ALL
    SELECT 'S700', 'bsad', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss700_bsad
    UNION ALL
    SELECT 'S800', 'bsad', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss800_bsad
    UNION ALL
    SELECT 'S900', 'bsad', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss900_bsad
    UNION ALL
    SELECT 'S610', 'bsad', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss610_bsad
    UNION ALL
    SELECT 'S810', 'bsad', bukrs, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr
    FROM ods.odss810_bsad
),
src_bsik AS (
    SELECT 'S600' AS system_src, 'bsik' AS ods_src,
           bukrs, lifnr AS cust_code, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss600_bsik
    UNION ALL
    SELECT 'S700', 'bsik', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss700_bsik
    UNION ALL
    SELECT 'S800', 'bsik', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss800_bsik
    UNION ALL
    SELECT 'S900', 'bsik', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss900_bsik
    UNION ALL
    SELECT 'S610', 'bsik', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss610_bsik
    UNION ALL
    SELECT 'S810', 'bsik', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss810_bsik
),
src_bsak AS (
    SELECT 'S600' AS system_src, 'bsak' AS ods_src,
           bukrs, lifnr AS cust_code, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss600_bsak
    UNION ALL
    SELECT 'S700', 'bsak', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss700_bsak
    UNION ALL
    SELECT 'S800', 'bsak', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss800_bsak
    UNION ALL
    SELECT 'S900', 'bsak', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss900_bsak
    UNION ALL
    SELECT 'S610', 'bsak', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss610_bsak
    UNION ALL
    SELECT 'S810', 'bsak', bukrs, lifnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat
    FROM ods.odss810_bsak
),
-- 非统驭总账未清/已清项目；字段按现有ODS命名暂定，上线前需核对六系统真实表结构。
src_bsis AS (
    SELECT 'S600' AS system_src, 'bsis' AS ods_src,
           bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss600_bsis
    UNION ALL
    SELECT 'S700', 'bsis', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss700_bsis
    UNION ALL
    SELECT 'S800', 'bsis', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss800_bsis
    UNION ALL
    SELECT 'S900', 'bsis', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss900_bsis
    UNION ALL
    SELECT 'S610', 'bsis', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss610_bsis
    UNION ALL
    SELECT 'S810', 'bsis', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss810_bsis
),
src_bsas AS (
    SELECT 'S600' AS system_src, 'bsas' AS ods_src,
           bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss600_bsas
    UNION ALL
    SELECT 'S700', 'bsas', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss700_bsas
    UNION ALL
    SELECT 'S800', 'bsas', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss800_bsas
    UNION ALL
    SELECT 'S900', 'bsas', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss900_bsas
    UNION ALL
    SELECT 'S610', 'bsas', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss610_bsas
    UNION ALL
    SELECT 'S810', 'bsas', bukrs, lifnr, kunnr, hkont, prctr, gsber, filkd, waers,
           blart, belnr, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr
    FROM ods.odss810_bsas
),
src_kna1 AS (
    SELECT 'S600' AS system_src, kunnr, name1, zkunnr_mdg FROM ods.odss600_kna1
    UNION ALL
    SELECT 'S700', kunnr, name1, zkunnr_mdg FROM ods.odss700_kna1
    UNION ALL
    SELECT 'S800', kunnr, name1, zkunnr_mdg FROM ods.odss800_kna1
    UNION ALL
    SELECT 'S900', kunnr, name1, zkunnr_mdg FROM ods.odss900_kna1
    UNION ALL
    SELECT 'S610', kunnr, name1, zkunnr_mdg FROM ods.odss610_kna1
    UNION ALL
    SELECT 'S810', kunnr, name1, zkunnr_mdg FROM ods.odss810_kna1
),
src_lfa1 AS (
    SELECT 'S600' AS system_src, lifnr, name1, zlifnr_mdg FROM ods.odss600_lfa1
    UNION ALL
    SELECT 'S700', lifnr, name1, zlifnr_mdg FROM ods.odss700_lfa1
    UNION ALL
    SELECT 'S800', lifnr, name1, zlifnr_mdg FROM ods.odss800_lfa1
    UNION ALL
    SELECT 'S900', lifnr, name1, zlifnr_mdg FROM ods.odss900_lfa1
    UNION ALL
    SELECT 'S610', lifnr, name1, zlifnr_mdg FROM ods.odss610_lfa1
    UNION ALL
    SELECT 'S810', lifnr, name1, zlifnr_mdg FROM ods.odss810_lfa1
),
src_cepct AS (
    SELECT 'S600' AS system_src, prctr, spras, ktext FROM ods.odss600_cepct
    UNION ALL
    SELECT 'S700', prctr, spras, ktext FROM ods.odss700_cepct
    UNION ALL
    SELECT 'S800', prctr, spras, ktext FROM ods.odss800_cepct
    UNION ALL
    SELECT 'S900', prctr, spras, ktext FROM ods.odss900_cepct
    UNION ALL
    SELECT 'S610', prctr, spras, ktext FROM ods.odss610_cepct
    UNION ALL
    SELECT 'S810', prctr, spras, ktext FROM ods.odss810_cepct
),

-- 公司、统驭科目配置和科目主数据必须属于同一SAP系统。
-- MITKZ=D/K仅供四张统驭项目表使用。
account_cfg AS (
    SELECT DISTINCT
        t.system_src,
        t.bukrs AS company_code,
        s.saknr AS acct_code,
        s.mitkz AS acct_type_code
    FROM src_ztzt_003 z
    INNER JOIN src_t001 t
        ON t.system_src = z.system_src
       AND t.ktopl = z.ktopl
    INNER JOIN src_skb1 s
        ON s.system_src = t.system_src
       AND s.bukrs = t.bukrs
       AND s.saknr BETWEEN z.hkonf AND z.hkont
       AND s.mitkz IN ('D', 'K')
),

-- SKB1.MITKZ为空时属于非统驭科目，科目类型由各系统ZTZT_003.KOART决定。
-- DISTINCT用于消除同一类型内配置区间重叠造成的重复，不跨D/K合并相互冲突的配置。
gl_account_cfg AS (
    SELECT DISTINCT
        t.system_src,
        t.bukrs AS company_code,
        s.saknr AS acct_code,
        TRIM(z.koart) AS acct_type_code
    FROM src_ztzt_003 z
    INNER JOIN src_t001 t
        ON t.system_src = z.system_src
       AND t.ktopl = z.ktopl
    INNER JOIN src_skb1 s
        ON s.system_src = t.system_src
       AND s.bukrs = t.bukrs
       AND s.saknr BETWEEN z.hkonf AND z.hkont
    WHERE COALESCE(TRIM(s.mitkz), '') = ''
      AND TRIM(z.koart) IN ('D', 'K')
),

-- 还原关键日未清项：未清表限制过账日；已清表另需清账日晚于关键日。
-- object_source隔离客户、供应商和纯总账科目，防止HKONT误匹配客商维表。
ar_open AS (
    SELECT
        b.bukrs, 'D' AS koart, b.cust_code, 'CUSTOMER' AS object_source, b.hkont,
        b.system_src, b.ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr, b.rstgr
    FROM src_bsid b
    INNER JOIN account_cfg c
        ON c.system_src = b.system_src
       AND c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = 'D'
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
      AND COALESCE(b.bstat, '') NOT IN ('A', 'S')
),
ar_cleared AS (
    SELECT
        b.bukrs, 'D' AS koart, b.cust_code, 'CUSTOMER' AS object_source, b.hkont,
        b.system_src, b.ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr, b.rstgr
    FROM src_bsad b
    INNER JOIN account_cfg c
        ON c.system_src = b.system_src
       AND c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = 'D'
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
      AND b.augdt > p.key_date_sap
      AND COALESCE(b.bstat, '') NOT IN ('A', 'S')
),
ap_open AS (
    SELECT
        b.bukrs, 'K' AS koart, b.cust_code, 'VENDOR' AS object_source, b.hkont,
        b.system_src, b.ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr, CAST(NULL AS VARCHAR(20)) AS rstgr
    FROM src_bsik b
    INNER JOIN account_cfg c
        ON c.system_src = b.system_src
       AND c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = 'K'
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
      AND COALESCE(b.bstat, '') NOT IN ('A', 'S')
),
ap_cleared AS (
    SELECT
        b.bukrs, 'K' AS koart, b.cust_code, 'VENDOR' AS object_source, b.hkont,
        b.system_src, b.ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr, CAST(NULL AS VARCHAR(20)) AS rstgr
    FROM src_bsak b
    INNER JOIN account_cfg c
        ON c.system_src = b.system_src
       AND c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = 'K'
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
      AND b.augdt > p.key_date_sap
      AND COALESCE(b.bstat, '') NOT IN ('A', 'S')
),

-- 非统驭项目按ABAP优先取LIFNR，其次KUNNR，均无值时以HKONT作为对象编码。
-- BSIS/BSAS不追加统驭表的BSTAT过滤条件，付款原因固定为空。
gl_open AS (
    SELECT
        b.bukrs,
        c.acct_type_code AS koart,
        CASE
            WHEN NULLIF(LTRIM(TRIM(COALESCE(b.lifnr, '')), '0'), '') IS NOT NULL THEN b.lifnr
            WHEN NULLIF(LTRIM(TRIM(COALESCE(b.kunnr, '')), '0'), '') IS NOT NULL THEN b.kunnr
            ELSE b.hkont
        END AS cust_code,
        CASE
            WHEN NULLIF(LTRIM(TRIM(COALESCE(b.lifnr, '')), '0'), '') IS NOT NULL THEN 'VENDOR'
            WHEN NULLIF(LTRIM(TRIM(COALESCE(b.kunnr, '')), '0'), '') IS NOT NULL THEN 'CUSTOMER'
            ELSE 'GL_ACCOUNT'
        END AS object_source,
        b.hkont,
        b.system_src, b.ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr, CAST(NULL AS VARCHAR(20)) AS rstgr
    FROM src_bsis b
    INNER JOIN gl_account_cfg c
        ON c.system_src = b.system_src
       AND c.company_code = b.bukrs
       AND c.acct_code = b.hkont
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
),
gl_cleared AS (
    SELECT
        b.bukrs,
        c.acct_type_code AS koart,
        CASE
            WHEN NULLIF(LTRIM(TRIM(COALESCE(b.lifnr, '')), '0'), '') IS NOT NULL THEN b.lifnr
            WHEN NULLIF(LTRIM(TRIM(COALESCE(b.kunnr, '')), '0'), '') IS NOT NULL THEN b.kunnr
            ELSE b.hkont
        END AS cust_code,
        CASE
            WHEN NULLIF(LTRIM(TRIM(COALESCE(b.lifnr, '')), '0'), '') IS NOT NULL THEN 'VENDOR'
            WHEN NULLIF(LTRIM(TRIM(COALESCE(b.kunnr, '')), '0'), '') IS NOT NULL THEN 'CUSTOMER'
            ELSE 'GL_ACCOUNT'
        END AS object_source,
        b.hkont,
        b.system_src, b.ods_src,
        b.prctr, b.gsber, b.filkd, b.waers,
        b.blart, b.belnr, b.budat, b.bldat, b.zfbdt, b.augdt,
        b.shkzg, b.dmbtr, b.wrbtr, CAST(NULL AS VARCHAR(20)) AS rstgr
    FROM src_bsas b
    INNER JOIN gl_account_cfg c
        ON c.system_src = b.system_src
       AND c.company_code = b.bukrs
       AND c.acct_code = b.hkont
    CROSS JOIN params p
    WHERE b.budat <= p.key_date_sap
      AND b.augdt > p.key_date_sap
),
all_items AS (
    SELECT * FROM ar_open
    UNION ALL
    SELECT * FROM ar_cleared
    UNION ALL
    SELECT * FROM ap_open
    UNION ALL
    SELECT * FROM ap_cleared
    UNION ALL
    SELECT * FROM gl_open
    UNION ALL
    SELECT * FROM gl_cleared
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

-- 统驭项目默认按凭证日期BLDAT计算账龄，AB类型改用ZFBDT。
-- ABAP对BSIS/BSAS总账项目强制以关键日为账龄基准，因此aging_days固定为1。
-- SAP借贷标识H为贷方，金额取负。
normalized_items AS (
    SELECT
        a.bukrs AS company_code,
        a.blart AS acct_cert_type,
        a.belnr AS acct_cert_no,
        STR_TO_DATE(NULLIF(NULLIF(TRIM(a.budat), ''), '00000000'), '%Y%m%d') AS posting_dt,
        CASE
            WHEN a.ods_src IN ('bsis', 'bsas') THEN p.key_date
            ELSE STR_TO_DATE(
                NULLIF(
                    NULLIF(TRIM(CASE WHEN a.blart = 'AB' THEN a.zfbdt ELSE a.bldat END), ''),
                    '00000000'
                ),
                '%Y%m%d'
            )
        END AS baseline_dt,
        STR_TO_DATE(NULLIF(NULLIF(TRIM(a.augdt), ''), '00000000'), '%Y%m%d') AS clearing_dt,
        LTRIM(COALESCE(a.cust_code, ''), '0') AS cust_code,
        a.object_source,
        a.koart AS acct_type_code,
        a.hkont AS acct_src_code,
        acct_map.acct_map_code,
        LTRIM(COALESCE(a.filkd, ''), '0') AS branch_code,
        COALESCE(a.prctr, '') AS src_profitcenter_code,
        COALESCE(a.gsber, '') AS bus_range_code,
        COALESCE(a.waers, '') AS qcy_code,
        NULLIF(TRIM(a.rstgr), '') AS pay_reason_code,
        CASE WHEN a.shkzg = 'H' THEN -a.dmbtr ELSE a.dmbtr END AS bcy_amt,
        CASE WHEN a.shkzg = 'H' THEN -a.wrbtr ELSE a.wrbtr END AS qcy_amt,
        CASE
            WHEN a.ods_src IN ('bsis', 'bsas') THEN 1
            ELSE DATEDIFF(
                p.key_date,
                STR_TO_DATE(
                    NULLIF(
                        NULLIF(TRIM(CASE WHEN a.blart = 'AB' THEN a.zfbdt ELSE a.bldat END), ''),
                        '00000000'
                    ),
                    '%Y%m%d'
                )
            ) + 1
        END AS aging_days,
        a.system_src,
        a.ods_src
    FROM all_items a
    CROSS JOIN params p
    LEFT JOIN acct_mapping acct_map
        ON a.hkont = acct_map.racct_src_code
       AND a.system_src = acct_map.system_src
    WHERE a.ods_src IN ('bsis', 'bsas')
       OR STR_TO_DATE(
              NULLIF(
                  NULLIF(TRIM(CASE WHEN a.blart = 'AB' THEN a.zfbdt ELSE a.bldat END), ''),
                  '00000000'
              ),
              '%Y%m%d'
          ) IS NOT NULL
),

-- 客户、供应商及分户编码统一去除前导零；匹配和入表均使用标准化编码。
-- 维表先按“系统号 + 标准化业务键”压成唯一键，避免跨系统串数或重复放大事实。
customer_dim AS (
    SELECT
        system_src,
        LTRIM(kunnr, '0') AS kunnr,
        MAX(name1) AS name1,
        MAX(LTRIM(zkunnr_mdg, '0')) AS zkunnr_mdg
    FROM src_kna1
    GROUP BY system_src, LTRIM(kunnr, '0')
),
-- 公司一二三级分类：各SAP系统客户号 -> MDG客户号 -> 客户基础维表。
-- 仅应收客户使用该链路；应付供应商无对应客户分类时保持NULL。
customer_class_dim AS (
    SELECT
        LTRIM(cust_code, '0') AS cust_code,
        MAX(com_1st_code) AS com_1st_code,
        MAX(com_1st_name) AS com_1st_name,
        MAX(com_2nd_code) AS com_2nd_code,
        MAX(com_2nd_name) AS com_2nd_name,
        MAX(com_3rd_code) AS com_3rd_code,
        MAX(com_3rd_name) AS com_3rd_name,
        MAX(country_code) AS country_code,
        MAX(country_name) AS country_name
    FROM dw.dim_customer_base_info_dd
    GROUP BY LTRIM(cust_code, '0')
),
vendor_dim AS (
    SELECT
        system_src,
        LTRIM(lifnr, '0') AS lifnr,
        MAX(name1) AS name1,
        MAX(LTRIM(zlifnr_mdg, '0')) AS zlifnr_mdg
    FROM src_lfa1
    GROUP BY system_src, LTRIM(lifnr, '0')
),
-- 对方公司映射按“标准化客商编码 + SAP系统 + 客商类型”取当前月份唯一有效记录。
-- 客户对象对应C、供应商对象对应V；纯HKONT对象不参与映射。
cp_company_dim AS (
    SELECT cust_code, cust_type_code, system_src, cp_company_code
    FROM (
        SELECT
            LTRIM(a.cust_code, '0') AS cust_code,
            a.cust_type_code,
            a.system_src,
            COALESCE(
                NULLIF(TRIM(a.cp_company_code_mr), ''),
                TRIM(a.cp_company_code)
            ) AS cp_company_code,
            ROW_NUMBER() OVER (
                PARTITION BY LTRIM(a.cust_code, '0'), a.cust_type_code, a.system_src
                ORDER BY NVL(a.valid_fr, '202401') DESC,
                         NVL(a.valid_to, '999999') DESC,
                         COALESCE(
                             NULLIF(TRIM(a.cp_company_code_mr), ''),
                             TRIM(a.cp_company_code)
                         )
            ) AS rn
        FROM dim.dim_rule_fi_mr_cust2ctp_mapping a
        WHERE a.cust_type_code IN ('C', 'V')
          AND NVL(a.valid_fr, '202401') <= LEFT(@year_month_day, 6)
          AND NVL(a.valid_to, '999999') >= LEFT(@year_month_day, 6)
    ) t
    WHERE rn = 1
),
company_dim AS (
    SELECT system_src, bukrs, MAX(waers) AS waers
    FROM src_t001
    GROUP BY system_src, bukrs
),
profitcenter_dim AS (
    SELECT system_src, prctr, MAX(ktext) AS ktext
    FROM src_cepct
    WHERE spras = '1'
    GROUP BY system_src, prctr
)

-- ----------------------------------------------------------------------------
-- 4. 补充描述并按目标表字段顺序写入当月分区
-- 尚无可靠取数逻辑的字段使用带类型NULL占位。
-- 主户取原客商编码，分户取FILKD；最终cust_code/cust_name优先分户，无分户时回退主户。
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
    a.branch_code AS cust_branch_code,
    COALESCE(bc.name1, '') AS cust_branch_name,
    a.cust_code AS cust_head_code,
    CASE
        WHEN a.object_source = 'CUSTOMER' THEN COALESCE(c.name1, '')
        WHEN a.object_source = 'VENDOR' THEN COALESCE(v.name1, '')
        ELSE ''
    END AS cust_head_name,
    CASE
        WHEN NULLIF(TRIM(a.branch_code), '') IS NOT NULL THEN a.branch_code
        ELSE a.cust_code
    END AS cust_code,
    CASE
        WHEN NULLIF(TRIM(a.branch_code), '') IS NOT NULL THEN COALESCE(bc.name1, '')
        WHEN a.object_source = 'CUSTOMER' THEN COALESCE(c.name1, '')
        WHEN a.object_source = 'VENDOR' THEN COALESCE(v.name1, '')
        ELSE ''
    END AS cust_name,
    ctp.cp_company_code AS cp_company_code,
    ci.country_code AS country_code,
    ci.country_name AS county_name,
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
    a.pay_reason_code,
    COALESCE(co.waers, '') AS bcy_code,
    a.qcy_code,
    a.bcy_amt,
    a.qcy_amt,
    CAST(NULL AS DECIMALV3(27, 9)) AS closing_rate_bcy_amt,
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
    ON a.object_source = 'CUSTOMER'
   AND a.system_src = c.system_src
   AND c.kunnr = a.cust_code
LEFT JOIN customer_class_dim ch
    ON a.object_source = 'CUSTOMER'
   AND ch.cust_code = c.zkunnr_mdg
LEFT JOIN vendor_dim v
    ON a.object_source = 'VENDOR'
   AND a.system_src = v.system_src
   AND v.lifnr = a.cust_code
LEFT JOIN customer_class_dim ci
    ON ci.cust_code = CASE
           WHEN a.object_source = 'CUSTOMER' THEN c.zkunnr_mdg
           WHEN a.object_source = 'VENDOR' THEN v.zlifnr_mdg
       END
LEFT JOIN customer_dim bc
    ON a.system_src = bc.system_src
   AND bc.kunnr = a.branch_code
LEFT JOIN cp_company_dim ctp
    ON ctp.cust_code = a.cust_code
   AND ctp.system_src = a.system_src
   AND ctp.cust_type_code = CASE
           WHEN a.object_source = 'CUSTOMER' THEN 'C'
           WHEN a.object_source = 'VENDOR' THEN 'V'
       END
LEFT JOIN company_dim co
    ON a.system_src = co.system_src
   AND co.bukrs = a.company_code
LEFT JOIN profitcenter_dim pc
    ON a.system_src = pc.system_src
   AND pc.prctr = a.src_profitcenter_code
;

-- ============================================================================
-- 上线前核对项
-- 1. 同名目标表若仍是旧汇总结构，需先完成DDL迁移；IF NOT EXISTS不会自动改列。
-- 2. 核对六套系统的BSID/BSAD/BSIK/BSAK/BSIS/BSAS均已入湖所引用字段，日期格式为YYYYMMDD。
--    新增BSIS/BSAS物理表名当前按ods.odss{系统号}_{表名}暂定，尚未验证线上存在。
-- 3. posting_rate_bcy_amt暂按SAP本位币金额DMBTR取值；期末汇率余额待接入汇率表。
-- 4. 渠道分组/业务范围名称/业务管理单元/汇率评估标识/
--    币种科目明细暂置NULL，待规则确认后补充。
-- 5. 付款原因仅BSID/BSAD取RSTGR；BSIK/BSAK及BSIS/BSAS固定为NULL。
-- 6. 公司一二三级分类仅按客户对象的MDG编码匹配；国家信息同时支持客户和供应商对象：
--    客户通过KNA1.ZKUNNR_MDG、供应商通过LFA1.ZLIFNR_MDG关联dw.dim_customer_base_info_dd，
--    取得country_code和country_name；纯HKONT对象不关联客商维表。
-- 7. 对方公司按去前导零客商编码 + system_src + 客商类型匹配：客户对象匹配C、供应商对象匹配V；
--    优先取cp_company_code_mr，为空时取cp_company_code，纯HKONT对象不参与匹配。
-- 8. 科目映射表不限制system_src取值，事实数据按acct_src_code + system_src双键匹配。
-- 9. 若ODS金额仍是SAP内部币种小数格式，须按TCURX在normalized_items前转换。
-- 10. CEPCT若同时存多个控制范围，应增加KOKRS/DATBI关联，不能只按PRCTR。
-- 11. 非统驭科目仅取SKB1.MITKZ为空且ZTZT_003.KOART为D/K的配置；与四张统驭表科目集合互斥。
-- 12. BSIS/BSAS对象编码按LIFNR -> KUNNR -> HKONT取值；按ABAP口径baseline_dt固定关键日、aging_days=1。
--     若业务最终要求按BSIS/BSAS凭证日期计算账龄，需另行确认后调整该口径。
-- 13. 目标表尚无GJAHR/BUZEI，当前不能形成SAP行项目技术键；需结合后续追溯要求评估是否加列。
-- ============================================================================


-- ============================================================================
-- 5. 信汇票据补充数据
--
-- 【整体目的】
-- 将信汇票据按月末快照还原为公司间应收/应付余额，再补齐账龄明细表的48个字段。
-- 本段不生成逐票据明细：最终业务粒度为“应付公司 + 应收公司 + 签收日期”。
--
-- 【处理链路及各处理包作用】
-- 1. xh_params：根据运行参数生成月份、月末关键日和源表快照日期。
-- 2. xh_bill_ranked：读取月末票据快照，按票据编号和区间识别版本，只保留最新子序号。
-- 3. xh_legal_company_dim：建立“法定总部 -> 公司”回退关系；一个总部多公司时取最小公司号。
-- 4. xh_account_company_dim：建立“内部账户 -> 公司”关系，供公司识别时优先使用。
-- 5. xh_company_system_dim：建立“公司 -> SAP系统”关系，控制结果只进入六套目标SAP系统。
-- 6. xh_bill_company：识别每张票据的应付公司和应收公司，并排除旧版本、指定状态和同公司票据。
-- 7. xh_source：按“应付公司 + 应收公司 + 签收日期”汇总金额，并计算月末账龄。
-- 8. xh_ar_ap：把一组公司间余额拆成应收、应付两行，形成借贷双方对称记录。
-- 9. xh_acct_mapping：按原始科目、SAP系统和有效月份取得唯一的映射后科目。
-- 10. xh_cp_company_dim：按虚拟客商、SAP系统和客商类型取得唯一的对方公司映射。
-- 11. 最终SELECT：适配目标表48个字段，并执行上线月份、目标组织和SAP系统范围限制。
--
-- 【关键限制条件为什么这样设置】
-- 1. DATA_DATE取参数月最后一天：信汇源表是快照表，账龄需要还原指定月末时点的票据余额。
-- 2. RN=1：同一票据编号和区间可能保留多个子序号版本，只取当前排序下的最新版本，防止重复计算。
--    注意：子序号当前按字符串DESC排序，不是转为数值后排序；该规则依赖BILL_CODE格式和子序号定长/补零，
--    若源格式不统一可能导致版本判断偏差，格式约束仍需业务及源系统确认。
-- 3. 公司识别采用“账户映射优先、法定总部回退”：账户能更直接定位实际内部公司；账户未维护时，
--    再使用信用方/接收方代码对应的法定总部关系兜底，避免仅因账户映射缺失而丢票据。
-- 4. 青岛海信商业保理有限公司的应收公司固定为9002：这是原信汇逻辑的明确特殊口径，继续原样保留。
-- 5. BILL_STATUS <> 9999：沿用原信汇排除规则；现有资料未解释9999的具体业务名称，因此不在此推断。
--    SQL三值逻辑下，BILL_STATUS为NULL也不会通过该条件，即NULL状态与9999一样不会进入结果。
-- 6. 应收公司 <> 应付公司：只保留跨公司票据，避免同一公司同时生成应收和应付、虚增双方余额。
--    COALESCE(...,'NULL')用于比较空值：双方都无法识别时会被排除；仅一侧为空时暂时保留，
--    后续空组织一侧会被company_code非空条件剔除，另一侧仍可用XH_Z001表示未知对方。
-- 7. 按公司对和SIGN_DATE汇总：继承原报表口径，使同一双方、同一起算日的票据共用一条账龄记录；
--    因此本段不能用来追溯单张票据，凭证编号也只能置NULL。
-- 8. HAVING SUM(BILL_AMOUNT) <> 0：公司对在同一签收日的净额为0时不影响应收应付余额，无需写入。
--    这里只排除净额为0，不限制源金额必须为正；应收保留汇总金额原符号，应付统一反号。
-- 9. 账龄按“月末 - SIGN_DATE + 1”：加1表示签收当天也计入账龄；SIGN_DATE为空时沿用原逻辑取1天。
--    当前未额外限制SIGN_DATE不能晚于月末，若源数据存在未来日期，可能得到0或负账龄。
-- 10. 应收、应付双边拆分：应收组织记D类科目1122000095，应付组织记K类科目2202000095；
--     应付金额取反，以同一笔公司间余额在双方账龄中形成方向相反、金额对称的记录。
-- 11. 最终INNER JOIN公司系统维：这是硬性准入条件，无法映射到S600/S700/S800/S900/S610/S810的组织不入表；
--     科目和对方公司使用LEFT JOIN则是为了映射缺失时仍保留事实，其中对方公司可回退原公司关系。
-- 12. dt_month >= 202607及排除9000/9002/9003/9005/9008均为原信汇上线范围，代码继续沿用；
--     现有资料未说明202607的生效背景及五家公司被排除的业务原因，不能自行扩大或缩小范围。
--
-- 【数据质量及重跑边界】
-- 1. 主SAP数据先INSERT OVERWRITE覆盖当月，再由本段INSERT INTO追加信汇，完整顺序执行时重跑不会重复。
--    两条写入不是一个原子语句：若信汇追加失败，当月会暂时只有SAP数据；禁止绕过前段单独重复执行本追加段。
-- 2. 账户映射按账号MAX(BUKRS)、系统映射按公司MAX(system_src)的作用是把一对多关系压成一行，
--    防止JOIN放大金额；MAX只是当前确定性取值方式，并不代表公司号或系统号越大业务优先级越高，重复映射需核对。
-- 3. 币种固定CNY是沿用原信汇脚本，并非代码已验证所有源票据均为人民币；非人民币票据是否存在仍需确认。
-- 4. Doris源表暂按以下落地名使用，上线前需核对真实物理表名、字段类型及日期格式：
--      ODS.ODSMT_FIN_BILL_VIEW_DATA@FMSLK -> ods.odsmt_fin_bill_view_data
--      ZTAB_9000_ACCT_MAPING             -> ods.odsfima_ztab_9000_acct_maping
-- ============================================================================
INSERT INTO test.dwd_fi_mr_arap_detail_mi
(
    dt_month, `year`, `month`, company_code,
    acct_cert_type, acct_cert_no, posting_dt, baseline_dt, clearing_dt,
    cust_branch_code, cust_branch_name, cust_head_code, cust_head_name, cust_code, cust_name,
    cp_company_code, country_code, county_name, acct_type_code, acct_src_code, acct_map_code,
    channel_l1_code, channel_l1_name, channel_l2_code, channel_l2_name,
    channel_l3_code, channel_l3_name, onoffline_code, onoffline_name,
    src_profitcenter_code, src_profitcenter_name, profitcenter_code, profitcenter_name,
    bus_range_code, bus_range_name,
    marketing_dept_code, marketing_dept_name, pay_reason_code,
    bcy_code, qcy_code, bcy_amt, qcy_amt,
    closing_rate_bcy_amt, posting_rate_bcy_amt, exchange_rate_eval_flag,
    currency_acct_detail, aging_days, system_src, ods_src, load_dt
)
WITH
xh_params AS (
    SELECT
        LEFT(@year_month_day, 6) AS dt_month,
        LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d')) AS key_date,
        DATE_FORMAT(
            LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d')),
            '%Y%m%d'
        ) AS data_date
),

-- 同一票据编号、区间保留子序号最大的月末快照记录。
xh_bill_ranked AS (
    SELECT
        ROW_NUMBER() OVER (
            PARTITION BY SUBSTR(b.bill_code, 1, LOCATE('-', b.bill_code) - 1),
                         SUBSTR(b.bill_code, LOCATE(' ', b.bill_code) + 1)
            ORDER BY SUBSTR(
                         b.bill_code,
                         LOCATE('-', b.bill_code) + 1,
                         LOCATE(' ', b.bill_code) - LOCATE('-', b.bill_code) - 1
                     ) DESC
        ) AS rn,
        b.hold_customer_name,
        b.credit_customer_code,
        b.credit_customer_account,
        b.receive_credit_code,
        b.hold_customer_account,
        b.bill_status,
        b.bill_amount,
        CAST(b.sign_date AS DATE) AS sign_date
    FROM ods.odsmt_fin_bill_view_data b
    CROSS JOIN xh_params p
    WHERE b.data_date = p.data_date
),

-- 法定总部编码找不到账户映射时，回退到同一法定总部下最小公司编码。
xh_legal_company_dim AS (
    SELECT sede_legale, MIN(cod_azienda) AS company_code
    FROM ods.odsfima_azienda
    WHERE sede_legale IS NOT NULL
    GROUP BY sede_legale
),
xh_account_company_dim AS (
    SELECT account_no, MAX(bukrs) AS company_code
    FROM ods.odsfima_ztab_9000_acct_maping
    GROUP BY account_no
),

-- 公司对应SAP系统沿用账龄项目现有AZIENDA.CITTA_LEGALE口径。
xh_company_system_dim AS (
    SELECT
        cod_azienda AS company_code,
        MAX(CONCAT('S', TRIM(CAST(citta_legale AS STRING)))) AS system_src
    FROM ods.odsfima_azienda
    WHERE cod_azienda IS NOT NULL
      AND citta_legale IS NOT NULL
    GROUP BY cod_azienda
),

xh_bill_company AS (
    SELECT
        COALESCE(ap_acct.company_code, ap_legal.company_code) AS ap_company_code,
        CASE
            WHEN b.hold_customer_name = '青岛海信商业保理有限公司' THEN '9002'
            ELSE COALESCE(ar_acct.company_code, ar_legal.company_code)
        END AS ar_company_code,
        b.bill_amount,
        b.sign_date
    FROM xh_bill_ranked b
    LEFT JOIN xh_legal_company_dim ap_legal
        ON b.credit_customer_code = ap_legal.sede_legale
    LEFT JOIN xh_account_company_dim ap_acct
        ON b.credit_customer_account = ap_acct.account_no
    LEFT JOIN xh_legal_company_dim ar_legal
        ON b.receive_credit_code = ar_legal.sede_legale
    LEFT JOIN xh_account_company_dim ar_acct
        ON b.hold_customer_account = ar_acct.account_no
    WHERE b.rn = 1
      AND b.bill_status <> 9999
      AND COALESCE(ap_acct.company_code, ap_legal.company_code, 'NULL') <>
          COALESCE(
              CASE
                  WHEN b.hold_customer_name = '青岛海信商业保理有限公司' THEN '9002'
                  ELSE COALESCE(ar_acct.company_code, ar_legal.company_code)
              END,
              'NULL'
          )
),

-- 保留原信汇逻辑的“应收公司 + 应付公司 + 签收日期”汇总粒度。
xh_source AS (
    SELECT
        b.ap_company_code,
        b.ar_company_code,
        b.sign_date,
        SUM(b.bill_amount) AS bill_amt,
        CASE
            WHEN b.sign_date IS NULL THEN 1
            ELSE DATEDIFF(p.key_date, b.sign_date) + 1
        END AS aging_days
    FROM xh_bill_company b
    CROSS JOIN xh_params p
    GROUP BY
        b.ap_company_code,
        b.ar_company_code,
        b.sign_date,
        CASE
            WHEN b.sign_date IS NULL THEN 1
            ELSE DATEDIFF(p.key_date, b.sign_date) + 1
        END
    HAVING SUM(b.bill_amount) <> 0
),

-- 一笔信汇公司间余额同时生成应收正数和应付负数。
xh_ar_ap AS (
    SELECT
        s.ar_company_code AS company_code,
        s.ap_company_code AS source_cp_company_code,
        'D' AS acct_type_code,
        '1122000095' AS acct_src_code,
        CONCAT('XH_', COALESCE(s.ap_company_code, 'Z001')) AS cust_code,
        '应收账款-信汇' AS cust_name,
        s.sign_date AS baseline_dt,
        s.aging_days,
        s.bill_amt AS amount
    FROM xh_source s

    UNION ALL

    SELECT
        s.ap_company_code AS company_code,
        s.ar_company_code AS source_cp_company_code,
        'K' AS acct_type_code,
        '2202000095' AS acct_src_code,
        CONCAT('XH_', COALESCE(s.ar_company_code, 'Z001')) AS cust_code,
        '应付账款-信汇' AS cust_name,
        s.sign_date AS baseline_dt,
        s.aging_days,
        -s.bill_amt AS amount
    FROM xh_source s
),

-- 科目映射沿用主账龄逻辑：映射前科目 + SAP系统 + 有效月份。
xh_acct_mapping AS (
    SELECT acct_src_code, acct_map_code, system_src
    FROM (
        SELECT
            a.acct_src_code,
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

-- 对方公司优先沿用主账龄客商映射，未命中时回退到信汇原始公司关系。
xh_cp_company_dim AS (
    SELECT cust_code, cust_type_code, system_src, cp_company_code
    FROM (
        SELECT
            LTRIM(a.cust_code, '0') AS cust_code,
            a.cust_type_code,
            a.system_src,
            COALESCE(
                NULLIF(TRIM(a.cp_company_code_mr), ''),
                TRIM(a.cp_company_code)
            ) AS cp_company_code,
            ROW_NUMBER() OVER (
                PARTITION BY LTRIM(a.cust_code, '0'), a.cust_type_code, a.system_src
                ORDER BY NVL(a.valid_fr, '202401') DESC,
                         NVL(a.valid_to, '999999') DESC,
                         COALESCE(
                             NULLIF(TRIM(a.cp_company_code_mr), ''),
                             TRIM(a.cp_company_code)
                         )
            ) AS rn
        FROM dim.dim_rule_fi_mr_cust2ctp_mapping a
        WHERE a.cust_type_code IN ('C', 'V')
          AND NVL(a.valid_fr, '202401') <= LEFT(@year_month_day, 6)
          AND NVL(a.valid_to, '999999') >= LEFT(@year_month_day, 6)
    ) t
    WHERE rn = 1
)

SELECT
    p.dt_month,
    LEFT(p.dt_month, 4) AS `year`,
    RIGHT(p.dt_month, 2) AS `month`,
    x.company_code,
    'XH' AS acct_cert_type,
    CAST(NULL AS VARCHAR(20)) AS acct_cert_no,
    CAST(NULL AS DATE) AS posting_dt,
    x.baseline_dt,
    CAST(NULL AS DATE) AS clearing_dt,
    CAST(NULL AS VARCHAR(20)) AS cust_branch_code,
    CAST(NULL AS VARCHAR(200)) AS cust_branch_name,
    x.cust_code AS cust_head_code,
    x.cust_name AS cust_head_name,
    x.cust_code AS cust_code,
    x.cust_name AS cust_name,
    COALESCE(cp.cp_company_code, x.source_cp_company_code) AS cp_company_code,
    CAST(NULL AS VARCHAR(10)) AS country_code,
    CAST(NULL AS VARCHAR(200)) AS county_name,
    x.acct_type_code,
    x.acct_src_code,
    am.acct_map_code,
    CAST(NULL AS VARCHAR(30)) AS channel_l1_code,
    CAST(NULL AS VARCHAR(200)) AS channel_l1_name,
    CAST(NULL AS VARCHAR(30)) AS channel_l2_code,
    CAST(NULL AS VARCHAR(200)) AS channel_l2_name,
    CAST(NULL AS VARCHAR(30)) AS channel_l3_code,
    CAST(NULL AS VARCHAR(200)) AS channel_l3_name,
    CAST(NULL AS VARCHAR(30)) AS onoffline_code,
    CAST(NULL AS VARCHAR(200)) AS onoffline_name,
    CAST(NULL AS VARCHAR(200)) AS src_profitcenter_code,
    CAST(NULL AS VARCHAR(200)) AS src_profitcenter_name,
    CAST(NULL AS VARCHAR(20)) AS profitcenter_code,
    CAST(NULL AS VARCHAR(200)) AS profitcenter_name,
    CAST(NULL AS VARCHAR(20)) AS bus_range_code,
    CAST(NULL AS VARCHAR(200)) AS bus_range_name,
    CAST(NULL AS VARCHAR(30)) AS marketing_dept_code,
    CAST(NULL AS VARCHAR(200)) AS marketing_dept_name,
    CAST(NULL AS VARCHAR(20)) AS pay_reason_code,
    'CNY' AS bcy_code,
    'CNY' AS qcy_code,
    CAST(x.amount AS DECIMALV3(27, 9)) AS bcy_amt,
    CAST(x.amount AS DECIMALV3(27, 9)) AS qcy_amt,
    CAST(NULL AS DECIMALV3(27, 9)) AS closing_rate_bcy_amt,
    CAST(x.amount AS DECIMALV3(27, 9)) AS posting_rate_bcy_amt,
    CAST(NULL AS VARCHAR(10)) AS exchange_rate_eval_flag,
    CAST(NULL AS VARCHAR(1000)) AS currency_acct_detail,
    x.aging_days,
    cs.system_src,
    'fin_bill_view_data' AS ods_src,
    NOW() AS load_dt
FROM xh_ar_ap x
CROSS JOIN xh_params p
INNER JOIN xh_company_system_dim cs
    ON cs.company_code = x.company_code
   AND cs.system_src IN ('S600', 'S700', 'S800', 'S900', 'S610', 'S810')
LEFT JOIN xh_acct_mapping am
    ON am.acct_src_code = x.acct_src_code
   AND am.system_src = cs.system_src
LEFT JOIN xh_cp_company_dim cp
    ON cp.cust_code = x.cust_code
   AND cp.system_src = cs.system_src
   AND cp.cust_type_code = CASE
           WHEN x.acct_type_code = 'D' THEN 'C'
           WHEN x.acct_type_code = 'K' THEN 'V'
       END
WHERE p.dt_month >= '202607'
  AND x.company_code IS NOT NULL
  AND x.company_code NOT IN ('9000', '9002', '9003', '9005', '9008')
;

-- 信汇上线前核对项：
-- 1. 确认ods.odsmt_fin_bill_view_data和ods.odsfima_ztab_9000_acct_maping 真实存在及字段一致。
-- 2. 当前按原逻辑汇总到“应收公司 + 应付公司 + SIGN_DATE”，并非逐票据明细。
-- 3. 对方公司先匹配dim_rule_fi_mr_cust2ctp_mapping，未命中才使用信汇公司关系。
-- 4. 信汇原逻辑币种为CNY，因此本位币、交易币及两类金额均按CNY写入。
-- 5. acct_cert_type暂标记XH，凭证编号、过账日、清账日及其他无来源字段暂置NULL。