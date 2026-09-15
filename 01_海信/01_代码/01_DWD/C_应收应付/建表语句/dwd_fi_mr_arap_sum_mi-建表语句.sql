-- 往来账龄汇总表（Apache Doris）
-- 目标表：test.dwd_fi_mr_arap_sum_mi
-- 表类型：汇总事实表；数据分层：DWD

CREATE TABLE IF NOT EXISTS test.dwd_fi_mr_arap_sum_mi (
      dt_month VARCHAR(6) COMMENT '年月YYYYMM'
    , `year` VARCHAR(4) COMMENT '年份'
    , `month` VARCHAR(2) COMMENT '月份'
    , company_code VARCHAR(8) COMMENT '组织'
    , cust_code VARCHAR(30) COMMENT '客商编码'
    , cust_name VARCHAR(200) COMMENT '客商名称'
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
    , onoffline_code VARCHAR(30) COMMENT '渠道分组编码'
    , onoffline_name VARCHAR(200) COMMENT '渠道分组名称'
    , src_profitcenter_code VARCHAR(30) COMMENT '原始利润中心编码'
    , src_profitcenter_name VARCHAR(200) COMMENT '原始利润中心名称'
    , profitcenter_code VARCHAR(30) COMMENT '映射后利润中心编码'
    , profitcenter_name VARCHAR(200) COMMENT '映射后利润中心名称'
    , bus_range_code VARCHAR(30) COMMENT '业务范围编码'
    , bus_range_name VARCHAR(200) COMMENT '业务范围名称'
    , marketing_dept_code VARCHAR(30) COMMENT '业务管理单元编码'
    , marketing_dept_name VARCHAR(200) COMMENT '业务管理单元名称'
    , pay_reason_code VARCHAR(20) COMMENT '付款原因代码'
    , bcy_code VARCHAR(5) COMMENT '本位币币种'
    , qcy_code VARCHAR(200) COMMENT '交易币币种'
    , bcy_0_amt DECIMALV3(27, 9) COMMENT '本位币金额-总金额，等于bcy_1_amt至bcy_15_amt之和'
    , bcy_1_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段1'
    , bcy_2_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段2'
    , bcy_3_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段3'
    , bcy_4_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段4'
    , bcy_5_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段5'
    , bcy_6_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段6'
    , bcy_7_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段7'
    , bcy_8_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段8'
    , bcy_9_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段9'
    , bcy_10_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段10'
    , bcy_11_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段11'
    , bcy_12_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段12'
    , bcy_13_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段13'
    , bcy_14_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段14'
    , bcy_15_amt DECIMALV3(27, 9) COMMENT '本位币金额-账龄区间段15'
    , qcy_0_amt DECIMALV3(27, 9) COMMENT '交易币金额-总金额，等于qcy_1_amt至qcy_15_amt之和'
    , qcy_1_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段1'
    , qcy_2_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段2'
    , qcy_3_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段3'
    , qcy_4_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段4'
    , qcy_5_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段5'
    , qcy_6_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段6'
    , qcy_7_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段7'
    , qcy_8_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段8'
    , qcy_9_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段9'
    , qcy_10_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段10'
    , qcy_11_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段11'
    , qcy_12_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段12'
    , qcy_13_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段13'
    , qcy_14_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段14'
    , qcy_15_amt DECIMALV3(27, 9) COMMENT '交易币金额-账龄区间段15'
    , pays_tran VARCHAR(100) COMMENT '付款服务商的付款编号'
    , system_src VARCHAR(150) COMMENT '来源系统'
    , ods_src VARCHAR(200) COMMENT '数据来源'
    , reb_type VARCHAR(50) COMMENT '返利性质'
    , ufee_ureb_flag VARCHAR(30) COMMENT '返利/费用标识'
    , ecls_flag VARCHAR(30) COMMENT '电商零售标识'
    , ledger_status VARCHAR(4) COMMENT '台账状态'
    , acct_cert_type VARCHAR(20) COMMENT '凭证类型'
    , tax_rate DECIMALV3(27, 9) COMMENT '税率'
    , nature_l1_name VARCHAR(30) COMMENT '一级性质名称'
    , nature_l2_name VARCHAR(30) COMMENT '二级性质名称'
    , nature_l3_name VARCHAR(30) COMMENT '三级性质名称'
    , exchange_rate_eval_flag VARCHAR(200) COMMENT '汇率评估标识'
    , is_apar_flag VARCHAR(30) COMMENT '账龄是否进数'
    , pay_term_code VARCHAR(24) COMMENT '付款条件代码'
    , pay_term_desc VARCHAR(300) COMMENT '付款条件描述'
    , load_dt DATE COMMENT '更新时间'
)
ENGINE = OLAP
DUPLICATE KEY(
      dt_month
    , `year`
    , `month`
    , company_code
    , cust_code
)
COMMENT '往来账龄汇总表'
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
