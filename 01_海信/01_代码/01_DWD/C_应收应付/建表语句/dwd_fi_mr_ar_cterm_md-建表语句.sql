CREATE TABLE IF NOT EXISTS test.dwd_fi_mr_ar_cterm_md (
      company_code       VARCHAR(8) COMMENT '组织'
    , cust_code          VARCHAR(30) COMMENT '客户编码'
    , pay_term_code      VARCHAR(500) COMMENT '付款条件代码，多个值按代码升序以英文逗号分隔'
    , pay_term_desc      VARCHAR(1000) COMMENT '付款条件描述，顺序与付款条件代码一一对应'
    , system_src         VARCHAR(150) COMMENT '来源系统，S拼接KNB1.MANDT，如S600'
    , load_dt            DATE COMMENT '更新时间'
)
ENGINE = OLAP
DUPLICATE KEY(company_code, cust_code)
COMMENT '客户账期明细表'
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
