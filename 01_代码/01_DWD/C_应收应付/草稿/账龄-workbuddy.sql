-- ============================================================
-- 账龄分析底表 — Doris 入湖版 SQL
-- 源系统：SAP（BSID/BSAD/BSIK/BSAK 四张统驭表）
-- 目标库：Apache Doris
-- 仅一个参数 :p_yyyymm（年月，如 '202608'），自动算月末为关键日期
-- ABAP 默认值：p_pzrq='X'（按凭证日期 BLDAT 算账龄）
-- ============================================================


-- ============================================================
-- 一、入湖目标表 DDL（Doris 语法）
-- ============================================================
CREATE TABLE IF NOT EXISTS test.dwd_zzt003_aging (
    bukrs       VARCHAR(4),          -- 公司
    koart       VARCHAR(1),          -- 科目类型 D=应收 K=应付
    object      VARCHAR(10),         -- 客商编码 KUNNR/LIFNR
    name1       VARCHAR(35),         -- 客商名称
    prctr       VARCHAR(10),         -- 利润中心
    ktext       VARCHAR(40),         -- 利润中心描述
    gsber       VARCHAR(4),          -- 业务范围
    hkont       VARCHAR(10),         -- 会计科目
    filkd       VARCHAR(10),         -- 分支机构
    zname1      VARCHAR(35),         -- 分支机构名称
    projk_ext   VARCHAR(24),         -- WBS元素（外部格式）
    hwaer       VARCHAR(5),          -- 本位币币种
    waers       VARCHAR(5),          -- 交易币币种
    bldat       DATE,                -- 凭证日期（改造新增，保留方便下游重算）
    zfbdt       DATE,                -- 基准日期（改造新增）
    aging_date  DATE,                -- 实际用于计算账龄的日期（改造新增）
    dmbtr0      DECIMAL(23,2),       -- 本位币金额合计
    dmbtr1      DECIMAL(23,2),       -- 本位币 ≤30天
    dmbtr2      DECIMAL(23,2),       -- 本位币 31~90天
    dmbtr3      DECIMAL(23,2),       -- 本位币 91~180天
    dmbtr4      DECIMAL(23,2),       -- 本位币 181~365天
    dmbtr5      DECIMAL(23,2),       -- 本位币 366~730天
    dmbtr6      DECIMAL(23,2),       -- 本位币 731~1095天
    dmbtr7      DECIMAL(23,2),       -- 本位币 1096~1460天
    dmbtr8      DECIMAL(23,2),       -- 本位币 1461~1825天
    dmbtr9      DECIMAL(23,2),       -- 本位币 >1825天
    wrbtr0      DECIMAL(23,2),       -- 交易币金额合计
    wrbtr1      DECIMAL(23,2),       -- 交易币 ≤30天
    wrbtr2      DECIMAL(23,2),       -- 交易币 31~90天
    wrbtr3      DECIMAL(23,2),       -- 交易币 91~180天
    wrbtr4      DECIMAL(23,2),       -- 交易币 181~365天
    wrbtr5      DECIMAL(23,2),       -- 交易币 366~730天
    wrbtr6      DECIMAL(23,2),       -- 交易币 731~1095天
    wrbtr7      DECIMAL(23,2),       -- 交易币 1096~1460天
    wrbtr8      DECIMAL(23,2),       -- 交易币 1461~1825天
    wrbtr9      DECIMAL(23,2),       -- 交易币 >1825天
    etl_time    DATETIME,            -- ETL 加工时间
    keydat      DATE,                -- 关键日期（月末，同时作为分区列）
    yyyymm      VARCHAR(6)           -- 年月（如 '202608'），方便筛选
)
ENGINE = OLAP
PARTITION BY RANGE(keydat) ()
DISTRIBUTED BY HASH(bukrs) BUCKETS 10
PROPERTIES (
    "replication_allocation" = "tag.location.default: 1",
    "dynamic_partition.enable" = "true",
    "dynamic_partition.time_unit" = "MONTH",
    "dynamic_partition.start" = "-24",
    "dynamic_partition.end" = "3",
    "dynamic_partition.prefix" = "p",
    "dynamic_partition.buckets" = "10"
);

-- 说明：
-- 1. keydat 既是业务字段（关键日期=月末），也是 Doris 分区列
-- 2. 动态分区自动按月建分区，保留前24个月、预建后3个月
-- 3. replication_allocation 按集群副本数调整（1副本=单机/测试，生产建议3副本）
-- 4. 原 SAP 底表的 ITMNO(行号) 移除，湖表不需要
-- 5. 原 ERDAT/ERZET/ERNAM 合并为 etl_time
-- 6. 如不需要保留 bldat/zfbdt/aging_date，删掉对应列及 SELECT 中的引用即可


-- ============================================================
-- 二、参数说明
-- ============================================================
-- :p_yyyymm  年月字符串，如 '202608'
-- 账龄分桶天数（ABAP 默认值，固定写死）：
--   p1=30, p2=90, p3=180, p4=365, p5=730, p6=1095, p7=1460, p8=1825
-- 账龄基准日期：按 ABAP 默认 p_pzrq='X'，即凭证日期 BLDAT
--   AB 凭证(BLART='AB')强制用 ZFBDT


-- ============================================================
-- 三、清理旧数据（按当月分区清除后重跑）
-- ============================================================
-- Doris 动态分区命名规则：p + YYYYMM（如 p202608）
-- 方式1：DROP PARTITION（推荐，直接删分区最快）
--   ALTER TABLE test.dwd_zzt003_aging DROP PARTITION IF EXISTS p202608;
-- 方式2：DELETE（分区不连续时用）
DELETE FROM test.dwd_zzt003_aging
WHERE yyyymm = '202608';
-- ★ ETL 调度时将 '202608' 替换为实际 :p_yyyymm 参数值


-- ============================================================
-- 四、抽取+处理+入湖 SQL
-- ============================================================

-- ===== 步骤0: 计算月末关键日期 + 固定参数 =====
WITH params AS (
    SELECT
        '202608' AS yyyymm,
        -- Doris: last_day() 返回当月最后一天
        last_day(cast(
            concat(substr('202608', 1, 4), '-', substr('202608', 5, 2), '-01')
        AS date)) AS keydat,
        -- 账龄分桶天数（ABAP 默认值）
        30    AS p1,
        90    AS p2,
        180   AS p3,
        365   AS p4,
        730   AS p5,
        1095  AS p6,
        1460  AS p7,
        1825  AS p8
),

-- ===== 步骤1: 配置表读取 + 科目分类 =====
-- ZTZT_003 + T001(KTOPL) + SKB1(MITKZ) 确定科目属于客户统驭(D) / 供应商统驭(K)
-- 如入湖时不需按科目范围过滤，删掉此 CTE 及各子查询中的 hkont IN 条件
cfg AS (
    SELECT DISTINCT
        t.bukrs,
        s.saknr AS hkont,
        CASE s.mitkz
            WHEN 'K' THEN 'VENDOR_RECON'
            WHEN 'D' THEN 'CUST_RECON'
        END AS acct_class
    FROM ztzt_003 z
        INNER JOIN t001  t ON t.ktopl = z.ktopl
        INNER JOIN skb1  s ON s.bukrs = t.bukrs
                         AND s.saknr BETWEEN z.hkonf AND z.hkont
    WHERE s.mitkz IN ('K', 'D')
),

-- ===== 步骤2: 取四张统驭表（全公司，无选择条件过滤）=====
-- ABAP WHERE: budat<=keydat AND bstat<>'A' AND bstat<>'S'
-- 已清追加: augdt > keydat
-- BLART='DA' 不排除（ABAP 中已注释）
-- BLDAT/ZFBDT 不过滤（ABAP 中已注释）

-- 应收未清 BSID
ar_open AS (
    SELECT
        b.bukrs, 'D' AS koart, b.kunnr AS object, b.hkont,
        b.prctr, b.gsber, b.filkd, b.projk,
        b.waers, b.blart, b.shkzg,
        b.bldat, b.zfbdt, b.budat,
        b.dmbtr, b.wrbtr
    FROM bsid b, params p
    WHERE b.budat <= p.keydat
      AND b.bstat <> 'A'
      AND b.bstat <> 'S'
      AND b.hkont IN (SELECT hkont FROM cfg WHERE acct_class = 'CUST_RECON')
),

-- 应收已清 BSAD
ar_cleared AS (
    SELECT
        b.bukrs, 'D' AS koart, b.kunnr AS object, b.hkont,
        b.prctr, b.gsber, b.filkd, b.projk,
        b.waers, b.blart, b.shkzg,
        b.bldat, b.zfbdt, b.budat,
        b.dmbtr, b.wrbtr
    FROM bsad b, params p
    WHERE b.budat <= p.keydat
      AND b.bstat <> 'A'
      AND b.bstat <> 'S'
      AND b.augdt > p.keydat
      AND b.hkont IN (SELECT hkont FROM cfg WHERE acct_class = 'CUST_RECON')
),

-- 应付未清 BSIK
ap_open AS (
    SELECT
        b.bukrs, 'K' AS koart, b.lifnr AS object, b.hkont,
        b.prctr, b.gsber, b.filkd, b.projk,
        b.waers, b.blart, b.shkzg,
        b.bldat, b.zfbdt, b.budat,
        b.dmbtr, b.wrbtr
    FROM bsik b, params p
    WHERE b.budat <= p.keydat
      AND b.bstat <> 'A'
      AND b.bstat <> 'S'
      AND b.hkont IN (SELECT hkont FROM cfg WHERE acct_class = 'VENDOR_RECON')
),

-- 应付已清 BSAK
ap_cleared AS (
    SELECT
        b.bukrs, 'K' AS koart, b.lifnr AS object, b.hkont,
        b.prctr, b.gsber, b.filkd, b.projk,
        b.waers, b.blart, b.shkzg,
        b.bldat, b.zfbdt, b.budat,
        b.dmbtr, b.wrbtr
    FROM bsak b, params p
    WHERE b.budat <= p.keydat
      AND b.bstat <> 'A'
      AND b.bstat <> 'S'
      AND b.augdt > p.keydat
      AND b.hkont IN (SELECT hkont FROM cfg WHERE acct_class = 'VENDOR_RECON')
),

-- ===== 步骤3: 合并四张表 =====
all_items AS (
    SELECT * FROM ar_open
    UNION ALL SELECT * FROM ar_cleared
    UNION ALL SELECT * FROM ap_open
    UNION ALL SELECT * FROM ap_cleared
),

-- ===== 步骤4: 数据处理（ABAP PRO_DATA L445~L471）=====
-- 4a. 账龄基准日期（ABAP 默认 p_pzrq='X' → 凭证日期 BLDAT）
--     BLART='AB' → 强制 ZFBDT
-- 4b. 贷方取反: SHKZG='H' → 金额取负
-- 4c. 天数差 = keydat - aging_date + 1
-- 4d. 币种转换: 如 ODS 层已完成可直接用原值，否则 JOIN tcurx
items_final AS (
    SELECT
        a.bukrs,
        a.koart,
        a.object,
        a.prctr,
        a.gsber,
        a.hkont,
        a.filkd,
        a.projk,
        a.waers,
        a.bldat,
        a.zfbdt,
        -- 4a. 账龄基准日期：默认 BLDAT，AB 凭证强制 ZFBDT
        CASE
            WHEN a.blart = 'AB' THEN a.zfbdt
            ELSE                     a.bldat
        END AS aging_date,
        -- 4b. 贷方取反
        CASE WHEN a.shkzg = 'H' THEN -a.dmbtr ELSE a.dmbtr END AS dmbtr,
        CASE WHEN a.shkzg = 'H' THEN -a.wrbtr ELSE a.wrbtr END AS wrbtr,
        -- 4c. 天数差 = keydat - aging_date + 1
        -- Doris datediff(end, start) 返回天数
        datediff(p.keydat,
            CASE
                WHEN a.blart = 'AB' THEN a.zfbdt
                ELSE                     a.bldat
            END
        ) + 1 AS age_days
    FROM all_items a, params p
),

-- ===== 步骤5: 聚合 + 账龄分桶 =====
-- 聚合键: bukrs, koart, object, prctr, gsber, hkont, waers, projk, filkd
final_agg AS (
    SELECT
        f.bukrs,
        f.koart,
        f.object,
        f.prctr,
        f.gsber,
        f.hkont,
        f.filkd,
        f.projk AS projk_ext,
        f.waers,
        -- 保留原始日期（同组内取 MIN，方便下游重算）
        MIN(f.bldat) AS bldat,
        MIN(f.zfbdt) AS zfbdt,
        MIN(f.aging_date) AS aging_date,

        -- 本位币
        SUM(f.dmbtr) AS dmbtr0,
        SUM(CASE WHEN f.age_days <= p.p1                         THEN f.dmbtr ELSE 0 END) AS dmbtr1,
        SUM(CASE WHEN f.age_days >  p.p1 AND f.age_days <= p.p2   THEN f.dmbtr ELSE 0 END) AS dmbtr2,
        SUM(CASE WHEN f.age_days >  p.p2 AND f.age_days <= p.p3   THEN f.dmbtr ELSE 0 END) AS dmbtr3,
        SUM(CASE WHEN f.age_days >  p.p3 AND f.age_days <= p.p4   THEN f.dmbtr ELSE 0 END) AS dmbtr4,
        SUM(CASE WHEN f.age_days >  p.p4 AND f.age_days <= p.p5   THEN f.dmbtr ELSE 0 END) AS dmbtr5,
        SUM(CASE WHEN f.age_days >  p.p5 AND f.age_days <= p.p6   THEN f.dmbtr ELSE 0 END) AS dmbtr6,
        SUM(CASE WHEN f.age_days >  p.p6 AND f.age_days <= p.p7   THEN f.dmbtr ELSE 0 END) AS dmbtr7,
        SUM(CASE WHEN f.age_days >  p.p7 AND f.age_days <= p.p8   THEN f.dmbtr ELSE 0 END) AS dmbtr8,
        SUM(CASE WHEN f.age_days >  p.p8                         THEN f.dmbtr ELSE 0 END) AS dmbtr9,

        -- 交易币
        SUM(f.wrbtr) AS wrbtr0,
        SUM(CASE WHEN f.age_days <= p.p1                         THEN f.wrbtr ELSE 0 END) AS wrbtr1,
        SUM(CASE WHEN f.age_days >  p.p1 AND f.age_days <= p.p2   THEN f.wrbtr ELSE 0 END) AS wrbtr2,
        SUM(CASE WHEN f.age_days >  p.p2 AND f.age_days <= p.p3   THEN f.wrbtr ELSE 0 END) AS wrbtr3,
        SUM(CASE WHEN f.age_days >  p.p3 AND f.age_days <= p.p4   THEN f.wrbtr ELSE 0 END) AS wrbtr4,
        SUM(CASE WHEN f.age_days >  p.p4 AND f.age_days <= p.p5   THEN f.wrbtr ELSE 0 END) AS wrbtr5,
        SUM(CASE WHEN f.age_days >  p.p5 AND f.age_days <= p.p6   THEN f.wrbtr ELSE 0 END) AS wrbtr6,
        SUM(CASE WHEN f.age_days >  p.p6 AND f.age_days <= p.p7   THEN f.wrbtr ELSE 0 END) AS wrbtr7,
        SUM(CASE WHEN f.age_days >  p.p7 AND f.age_days <= p.p8   THEN f.wrbtr ELSE 0 END) AS wrbtr8,
        SUM(CASE WHEN f.age_days >  p.p8                         THEN f.wrbtr ELSE 0 END) AS wrbtr9
    FROM items_final f, params p
    GROUP BY
        f.bukrs, f.koart, f.object, f.prctr, f.gsber,
        f.hkont, f.filkd, f.projk, f.waers
),

-- ===== 步骤6: 补充描述信息（ABAP GET_DISC）=====
result_final AS (
    SELECT
        f.bukrs,
        f.koart,
        f.object,
        -- 客商名称: K→LFA1, D→KNA1
        CASE
            WHEN f.koart = 'K'
                THEN (SELECT name1 FROM lfa1 WHERE lifnr = f.object LIMIT 1)
            WHEN f.koart = 'D'
                THEN (SELECT name1 FROM kna1 WHERE kunnr = f.object LIMIT 1)
        END AS name1,
        f.prctr,
        -- 利润中心描述（spras='1' 中文）
        (SELECT ktext FROM cepct
          WHERE prctr = f.prctr AND spras = '1' LIMIT 1) AS ktext,
        f.gsber,
        f.hkont,
        f.filkd,
        -- 分支机构名称
        (SELECT name1 FROM kna1 WHERE kunnr = f.filkd LIMIT 1) AS zname1,
        f.projk_ext,
        -- 本位币币种
        (SELECT waers FROM t001 WHERE bukrs = f.bukrs LIMIT 1) AS hwaer,
        f.waers,
        -- 原始日期
        f.bldat,
        f.zfbdt,
        f.aging_date,
        -- 金额
        f.dmbtr0, f.dmbtr1, f.dmbtr2, f.dmbtr3, f.dmbtr4,
        f.dmbtr5, f.dmbtr6, f.dmbtr7, f.dmbtr8, f.dmbtr9,
        f.wrbtr0, f.wrbtr1, f.wrbtr2, f.wrbtr3, f.wrbtr4,
        f.wrbtr5, f.wrbtr6, f.wrbtr7, f.wrbtr8, f.wrbtr9,
        -- ETL 元数据
        now() AS etl_time,
        -- 分区字段 + 年月
        p.keydat,
        p.yyyymm
    FROM final_agg f, params p
)

-- ===== 步骤7: 写入 Doris 表 =====
INSERT INTO test.dwd_zzt003_aging
SELECT
      bukrs                  -- 公司代码
    , koart                  -- 科目类型
    , object                 -- 对象类型
    , name1                  -- 客户/供应商名称
    , prctr                  -- 利润中心编码
    , ktext                  -- 利润中心名称
    , gsber                  -- 业务范围编码
    , hkont                  -- 科目编码
    , filkd                  -- 分户编码
    , zname1                 -- 分户名称
    , projk_ext              -- 项目扩展字段
    , hwaer                  -- 本位币币种
    , waers                  -- 交易币币种
    , bldat                  -- 凭证日期
    , zfbdt                  -- 基准日期
    , aging_date             -- 账龄起算日期
    , dmbtr0                 -- 本位币账龄0金额
    , dmbtr1                 -- 本位币账龄1金额
    , dmbtr2                 -- 本位币账龄2金额
    , dmbtr3                 -- 本位币账龄3金额
    , dmbtr4                 -- 本位币账龄4金额
    , dmbtr5                 -- 本位币账龄5金额
    , dmbtr6                 -- 本位币账龄6金额
    , dmbtr7                 -- 本位币账龄7金额
    , dmbtr8                 -- 本位币账龄8金额
    , dmbtr9                 -- 本位币账龄9金额
    , wrbtr0                 -- 交易币账龄0金额
    , wrbtr1                 -- 交易币账龄1金额
    , wrbtr2                 -- 交易币账龄2金额
    , wrbtr3                 -- 交易币账龄3金额
    , wrbtr4                 -- 交易币账龄4金额
    , wrbtr5                 -- 交易币账龄5金额
    , wrbtr6                 -- 交易币账龄6金额
    , wrbtr7                 -- 交易币账龄7金额
    , wrbtr8                 -- 交易币账龄8金额
    , wrbtr9                 -- 交易币账龄9金额
    , etl_time               -- ETL时间
    , keydat                 -- 基准日期
    , yyyymm                 -- 年月
FROM result_final;


-- ============================================================
-- 五、Doris 使用备注
-- ============================================================
-- 1. 参数替换：
--    SQL 中所有 '202608' 需替换为实际年月参数
--    建议用 ETL 调度工具（DolphinScheduler/Airflow 等）做变量替换
--    如用 Doris SQL 变量：SET @yyyymm = '202608';
--
-- 2. 分区管理：
--    动态分区自动按月建分区，无需手动建分区
--    如分区不存在可手动补建：
--      ALTER TABLE test.dwd_zzt003_aging ADD PARTITION p202608
--      VALUES LESS THAN ('2026-09-01');
--
-- 3. 重跑某月数据：
--    先 DELETE FROM test.dwd_zzt003_aging WHERE yyyymm = '202608';
--    再执行 INSERT INTO ...（即上面 SQL）
--    或：ALTER TABLE ... DROP PARTITION p202608; 再 INSERT
--
-- 4. 币种小数位转换：
--    ABAP 用 BAPI_CURRENCY_CONV_TO_EXTERNAL 查 TCURX 表转换
--    如 ODS 层已转换，dmbtr/wrbtr 直接用原值
--    如需在此转换，在 items_final 中 JOIN tcurx：
--      LEFT JOIN tcurx tx ON tx.currkey = f.waers
--      然后: dmbtr / POWER(10, 2 - IFNULL(tx.currdec, 2))
--
-- 5. WBS 元素外部格式：
--    ABAP: CONVERSION_EXIT_ABPSP_OUTPUT（内码→外码）
--    如湖中有 UDF 则调用，否则保留 projk 原值
--
-- 6. 表名前缀：
--    源表 bsid/bsad/bsik/bsak/ztzt_003/t001/skb1/kna1/lfa1/cepct
--    如 ODS 层有前缀如 ods_sap_bsid，按实际命名替换


-- ============================================================
-- 六、与 SAP ABAP 的差异总结
-- ============================================================
-- 维度              ABAP 原程序                    Doris 入湖版
-- ─────────────────────────────────────────────────────────────
-- 参数              p_ys/p_yf/p_pzrq/p_jzrq/      仅 p_yyyymm
--                  s_bukrs/s_kunnr/s_lifnr/
--                  s_prctr/s_gsber/p1~p8
-- 公司范围          按选择屏幕过滤                 全量
-- 应收/应付          分模式运行                     一次跑完
-- 账龄基准日期       p_pzrq='X' 默认 BLDAT          BLDAT（与 ABAP 默认一致）
-- 账龄分桶天数       选择屏幕输入                   固定默认值
-- 存表方式          DELETE+INSERT                  DELETE+INSERT（或 DROP PARTITION）
-- 分区              无                             keydat 按月动态分区
-- ITMNO 行号        有                             移除
-- 原始日期保留       无                             新增 bldat/zfbdt/aging_date
-- 权限校验          ZATH_CHECK                     移除
-- 币种转换          BAPI_CURRENCY_CONV             ODS 层完成或 JOIN TCURX
