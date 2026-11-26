-- sms返利余额表-月报（Apache Doris）
-- 目标表：test.dwd_fi_mr_arap_sms_balance_mi
-- 表类型：事实表；数据分层：DWD
-- 最后更新：20261126 SHIQINGFENG.EX 按实际库 SHOW CREATE TABLE 全量对齐
--
-- 变更记录：
--   20261126  按实际库 SHOW CREATE TABLE 全量对齐：副本数改为 3；列、类型、KEY、分布、PROPERTIES 全量复核对齐。
--   线上现有分区：p2026086(202608), p2026096(202609), p2026106(202610), p2028066(202806)（AUTO PARTITION 运行时自动创建，建表语句保留空 () 不固化）。
--   20261102  与实际库对齐：补 update_dt DATETIME（实际存在、原文件缺）；分布列由 company_code 改为 dt_month。
--
-- 说明：DUPLICATE KEY 与实际库一致，仅 dt_month 单列。

CREATE TABLE IF NOT EXISTS test.dwd_fi_mr_arap_sms_balance_mi (
      dt_month VARCHAR(6) COMMENT '年月YYYYMM'
    , company_code VARCHAR(8) COMMENT '组织'
    , orgname VARCHAR(20) COMMENT '分公司'
    , sales_code VARCHAR(30) COMMENT '客商编码'
    , sname VARCHAR(500) COMMENT '客商描述'
    , leibie VARCHAR(30) COMMENT '类别'
    , fanlicurfanli DECIMALV3(27, 9) COMMENT '上月余额'
    , curfanli DECIMALV3(27, 9) COMMENT '当月增加'
    , curyearfanli DECIMALV3(27, 9) COMMENT '当年增加'
    , fanli DECIMALV3(27, 9) COMMENT '返利额'
    , yishiyong DECIMALV3(27, 9) COMMENT '已经使用'
    , yue DECIMALV3(27, 9) COMMENT '余额'
    , load_dt DATE COMMENT '更新时间'
    , update_dt DATETIME COMMENT '更新时间'
)
ENGINE = OLAP
DUPLICATE KEY(
      dt_month
)
COMMENT 'sms返利余额表-月报'
AUTO PARTITION BY LIST (dt_month) ()
DISTRIBUTED BY HASH(dt_month) BUCKETS 5
PROPERTIES (
    "replication_allocation" = "tag.location.default: 3",
    "min_load_replica_num" = "-1",
    "is_being_synced" = "false",
    "storage_medium" = "hdd",
    "storage_format" = "V2",
    "inverted_index_storage_format" = "V1",
    "light_schema_change" = "true",
    "disable_auto_compaction" = "false",
    "enable_single_replica_compaction" = "false",
    "group_commit_interval_ms" = "10000",
    "group_commit_data_bytes" = "134217728"
);
