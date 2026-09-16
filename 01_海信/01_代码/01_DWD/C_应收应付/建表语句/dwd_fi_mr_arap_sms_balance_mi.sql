-- sms返利余额表-月报（Apache Doris）
-- 目标表：test.dwd_fi_mr_arap_sms_balance_mi
-- 表类型：事实表；数据分层：DWD

CREATE TABLE IF NOT EXISTS test.dwd_fi_mr_arap_sms_balance_mi (
      dt_month VARCHAR(6) COMMENT '年月YYYYMM'
    , company_code VARCHAR(8) COMMENT '组织'
    , orgname VARCHAR(20) COMMENT '分公司'
    , sales_code VARCHAR(30) COMMENT '客商编码'
    , sname VARCHAR(30) COMMENT '客商描述'
    , leibie VARCHAR(30) COMMENT '类别'
    , fanlicurfanli DECIMALV3(27, 9) COMMENT '上月余额'
    , curfanli DECIMALV3(27, 9) COMMENT '当月增加'
    , curyearfanli DECIMALV3(27, 9) COMMENT '当年增加'
    , fanli DECIMALV3(27, 9) COMMENT '返利额'
    , yishiyong DECIMALV3(27, 9) COMMENT '已经使用'
    , yue DECIMALV3(27, 9) COMMENT '余额'
    , load_dt DATE COMMENT '更新时间'
)
ENGINE = OLAP
DUPLICATE KEY(
      dt_month
    , company_code
)
COMMENT 'sms返利余额表-月报'
AUTO PARTITION BY LIST (dt_month) ()
DISTRIBUTED BY HASH(`company_code`) BUCKETS 5
PROPERTIES (
    "replication_allocation" = "tag.location.default: 1",
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
