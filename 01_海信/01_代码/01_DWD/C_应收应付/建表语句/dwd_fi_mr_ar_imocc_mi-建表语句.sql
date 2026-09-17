-- 国际营销应收占用明细表（Apache Doris）
-- 目标表：dwd.dwd_fi_mr_ar_imocc_mi
-- 表类型：事实表；数据分层：DWD

CREATE TABLE IF NOT EXISTS dwd.dwd_fi_mr_ar_imocc_mi (
      dt_month VARCHAR(6) COMMENT '年月YYYYMM'
    , `year` VARCHAR(4) COMMENT '年份'
    , `month` VARCHAR(2) COMMENT '月份'
    , company_code VARCHAR(8) COMMENT '组织'
    , region_code VARCHAR(30) COMMENT '大区编码'
    , region_name VARCHAR(200) COMMENT '大区名称'
    , region_flag VARCHAR(30) COMMENT '大区标识'
    , area_group_code VARCHAR(30) COMMENT '区组编码'
    , area_group_name VARCHAR(200) COMMENT '区组名称'
    , area_group_flag VARCHAR(30) COMMENT '区组标识'
    , bus_model_code VARCHAR(30) COMMENT '业务模式'
    , product_big_class_code VARCHAR(30) COMMENT '产品大类编码'
    , product_big_class_name VARCHAR(200) COMMENT '产品大类名称'
    , product_line_code VARCHAR(30) COMMENT '产品线编码'
    , product_line_name VARCHAR(200) COMMENT '产品线名称'
    , cust_pay_term VARCHAR(200) COMMENT '客户账期编码/描述'
    , data_scope_code VARCHAR(30) COMMENT '范围'
    , cust_code VARCHAR(30) COMMENT '客商编码'
    , cust_name VARCHAR(200) COMMENT '客商名称'
    , cust_branch_code VARCHAR(20) COMMENT '分户编码'
    , cust_branch_name VARCHAR(200) COMMENT '分户名称'
    , cp_company_code VARCHAR(30) COMMENT '对方公司'
    , country_code VARCHAR(8) COMMENT '国家编码'
    , country_name VARCHAR(200) COMMENT '国家名称'
    , channel_l1_code VARCHAR(30) COMMENT '一级公司分类编码'
    , channel_l1_name VARCHAR(200) COMMENT '一级公司分类名称'
    , channel_l2_code VARCHAR(30) COMMENT '二级公司分类编码'
    , channel_l2_name VARCHAR(200) COMMENT '二级公司分类名称'
    , channel_l3_code VARCHAR(30) COMMENT '三级公司分类编码'
    , channel_l3_name VARCHAR(200) COMMENT '三级公司分类名称'
    , bus_range_code VARCHAR(30) COMMENT '业务范围编码'
    , bus_range_name VARCHAR(200) COMMENT '业务范围名称'
    , src_profitcenter_code VARCHAR(30) COMMENT '原始利润中心编码'
    , src_profitcenter_name VARCHAR(200) COMMENT '原始利润中心名称'
    , profitcenter_code VARCHAR(30) COMMENT '利润中心编码'
    , profitcenter_name VARCHAR(200) COMMENT '利润中心名称'
    , bcy_code VARCHAR(5) COMMENT '本位币币种'
    , qcy_code VARCHAR(5) COMMENT '交易币币种'
    , imocc_cny_amt DECIMALV3(27, 9) COMMENT '国际营销应收占用金额-人民币'
    , imocc_con_amt DECIMALV3(27, 9) COMMENT '国际营销应收占用金额-美元'
    , imocc_usd_amt DECIMALV3(27, 9) COMMENT '国际营销应收占用金额-本位币'
    , ods_src VARCHAR(200) COMMENT '数据来源'
    , load_dt DATE COMMENT '更新时间'
)
ENGINE = OLAP
DUPLICATE KEY(
      dt_month
    , `year`
    , `month`
    , company_code
    , cust_code
    , cust_branch_code
    , product_line_code
)
COMMENT '国际营销应收占用明细表'
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
