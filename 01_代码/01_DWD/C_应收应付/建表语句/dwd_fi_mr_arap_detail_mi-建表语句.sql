-- 往来账龄明细表（Apache Doris）
-- 目标表：test.dwd_fi_mr_arap_detail_mi
-- 表类型：事实表；数据分层：DWD

CREATE TABLE IF NOT EXISTS test.dwd_fi_mr_arap_detail_mi (
      dt_month VARCHAR(6) COMMENT '年月YYYYMM'
    , `year` VARCHAR(4) COMMENT '年份'
    , `month` VARCHAR(2) COMMENT '月份'
    , company_code VARCHAR(8) COMMENT '组织'
    , acct_cert_type VARCHAR(20) COMMENT '凭证类型'
    , acct_cert_status VARCHAR(30) COMMENT '凭证状态'
    , acct_cert_id VARCHAR(30) COMMENT '凭证编号'
    , acct_cert_item VARCHAR(30) COMMENT '凭证行项目'
    , voucher_dt DATE COMMENT '凭证日期'
    , posting_dt DATE COMMENT '过账日期'
    , baseline_dt DATE COMMENT '账龄基准日期'
    , clearing_dt DATE COMMENT '清账日期'
    , cust_code VARCHAR(30) COMMENT '客商编码：优先分户，否则主户'
    , cust_name VARCHAR(200) COMMENT '客商名称：优先分户，否则主户'
    , cust_head_code VARCHAR(30) COMMENT '主户编码'
    , cust_head_name VARCHAR(200) COMMENT '主户名称'
    , cust_branch_code VARCHAR(20) COMMENT '分户编码'
    , cust_branch_name VARCHAR(200) COMMENT '分户名称'
    , cp_company_code VARCHAR(30) COMMENT '对方公司'
    , country_code VARCHAR(8) COMMENT '国家编码'
    , country_name VARCHAR(200) COMMENT '国家名称'
    , acct_type_code VARCHAR(20) COMMENT '科目类型：D应收，K应付'
    , acct_src_code VARCHAR(30) COMMENT '原始科目编码'
    , acct_map_code VARCHAR(30) COMMENT '映射后科目编码'
    , channel_l1_code VARCHAR(30) COMMENT '一级公司分类编码'
    , channel_l1_name VARCHAR(200) COMMENT '一级公司分类名称'
    , channel_l2_code VARCHAR(30) COMMENT '二级公司分类编码'
    , channel_l2_name VARCHAR(200) COMMENT '二级公司分类名称'
    , channel_l3_code VARCHAR(30) COMMENT '三级公司分类编码'
    , channel_l3_name VARCHAR(200) COMMENT '三级公司分类名称'
    , tov_channel_code VARCHAR(30) COMMENT '周转分析渠道编码'
    , tov_channel_name VARCHAR(200) COMMENT '周转分析渠道名称'
    , cc_cust_group_code VARCHAR(30) COMMENT '商冷客户群编码'
    , cc_cust_group_name VARCHAR(200) COMMENT '商冷客户群名称'
    , onoffline_code VARCHAR(30) COMMENT '线上线下编码'
    , onoffline_name VARCHAR(200) COMMENT '线上线下名称'
    , src_profitcenter_code VARCHAR(30) COMMENT '原始利润中心编码'
    , src_profitcenter_name VARCHAR(200) COMMENT '原始利润中心名称'
    , profitcenter_code VARCHAR(30) COMMENT '映射后利润中心编码'
    , profitcenter_name VARCHAR(200) COMMENT '映射后利润中心名称'
    , bus_range_code VARCHAR(30) COMMENT '业务范围编码'
    , bus_range_name VARCHAR(200) COMMENT '业务范围名称'
    , marketing_dept_code VARCHAR(30) COMMENT '业务管理单元编码'
    , marketing_dept_name VARCHAR(200) COMMENT '业务管理单元名称'
    , nature_l1_name VARCHAR(2000) COMMENT '一级性质'
    , nature_l2_name VARCHAR(2000) COMMENT '二级性质'
    , nature_l3_name VARCHAR(2000) COMMENT '三级性质'
    , pay_method VARCHAR(200) COMMENT '付款方式'
    , pay_reason_code VARCHAR(20) COMMENT '付款原因代码'
    , bcy_code VARCHAR(5) COMMENT '本位币币种'
    , qcy_code VARCHAR(200) COMMENT '交易币币种'
    , bcy_amt DECIMALV3(27, 9) COMMENT '本位币金额'
    , qcy_amt DECIMALV3(27, 9) COMMENT '交易币金额'
    , aging_days DECIMALV3(27, 9) COMMENT '账龄天数'
    , aging_seg_code VARCHAR(30) COMMENT '账龄段编码'
    , aging_seg_name VARCHAR(200) COMMENT '账龄段名称'
    , pays_tran VARCHAR(100) COMMENT '付款服务商的付款编号'
    , note VARCHAR(2000) COMMENT '备注'
    , system_src VARCHAR(150) COMMENT '源系统'
    , ods_src VARCHAR(200) COMMENT '源表'
    , load_dt DATE COMMENT '更新时间'
)
ENGINE = OLAP
DUPLICATE KEY(
      dt_month
    , `year`
    , `month`
    , company_code
    , acct_cert_type
    , acct_cert_status
    , acct_cert_id
    , acct_cert_item
)
COMMENT '往来账龄明细表'
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
