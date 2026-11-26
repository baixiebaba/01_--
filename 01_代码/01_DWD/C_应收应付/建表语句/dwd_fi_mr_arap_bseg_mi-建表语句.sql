-- 往来BSEG已清与本月未清凭证行项目表（Apache Doris）
-- 目标表：test.dwd_fi_mr_arap_bseg_mi
-- 表类型：事实表（BSEG取数中间落表）；数据分层：DWD
-- 最后更新：20261126 18:10 SHIQINGFENG.EX 新增本月未清两类标识
--
-- 变更记录：
--   20261126  ALTER BY 20261126 18:10 SHIQINGFENG.EX 装载脚本新增本月凭证未清取数，ods_src 取值扩为 BSEG_AD/BSEG_AK/BSEG_ID/BSEG_IK/BSAD_EPAY。
--   20261126  按实际库 SHOW CREATE TABLE 全量对齐：DUPLICATE KEY 改为仅 dt_month 单列；补 2 项 PROPERTIES；分区按约定保留空 ()。
--   线上现有分区：p2026086(202608)（AUTO PARTITION 运行时自动创建，建表语句保留空 () 不固化）。
--
-- 说明：dt_month 按月自动分区，供 dwd_fi_mr_arap_detail_mi.sql 按 @dt_month 读取；
--       DUPLICATE KEY 与实际库一致，仅 dt_month 单列。
--       装载脚本：0.0_Doris脚本/dwd_fi_mr_arap_bseg_mi.sql

CREATE TABLE IF NOT EXISTS test.dwd_fi_mr_arap_bseg_mi (
      dt_month VARCHAR(6) COMMENT '年月YYYYMM，取参数月'
    , system_src VARCHAR(20) COMMENT '来源系统S600/S700/S800/S900/S610/S810'
    , ods_src VARCHAR(30) COMMENT '数据来源BSEG_AD/BSEG_AK/BSEG_ID/BSEG_IK/BSAD_EPAY'
    , bukrs VARCHAR(20) COMMENT '公司编码，S700已按cod_azienda映射'
    , cust_head_code VARCHAR(30) COMMENT '客户/供应商编码，K取lifnr、D取kunnr'
    , hkont VARCHAR(30) COMMENT '总账科目'
    , prctr VARCHAR(30) COMMENT '利润中心'
    , gsber VARCHAR(20) COMMENT '业务范围'
    , filkd VARCHAR(30) COMMENT '分支机构'
    , waers VARCHAR(10) COMMENT '货币'
    , blart VARCHAR(10) COMMENT '凭证类型'
    , belnr VARCHAR(20) COMMENT '凭证编号'
    , gjahr VARCHAR(8) COMMENT '会计年度'
    , buzei VARCHAR(10) COMMENT '凭证行项目'
    , budat VARCHAR(30) COMMENT '过账日期'
    , bldat VARCHAR(30) COMMENT '凭证日期'
    , zfbdt VARCHAR(30) COMMENT '基准日期'
    , zbd1t VARCHAR(30) COMMENT '付款天数'
    , augdt VARCHAR(30) COMMENT '清账日期'
    , shkzg VARCHAR(4) COMMENT '借贷标识'
    , dmbtr DECIMALV3(27, 9) COMMENT '本位币金额'
    , wrbtr DECIMALV3(27, 9) COMMENT '交易币金额'
    , bstat VARCHAR(10) COMMENT '凭证状态'
    , rstgr VARCHAR(10) COMMENT '付款原因代码'
    , zlsch VARCHAR(10) COMMENT '付款方式'
    , pays_tran VARCHAR(100) COMMENT '付款服务商付款编号'
    , sgtxt VARCHAR(2000) COMMENT '行项目文本'
    , load_dt DATETIME COMMENT '数据装载时间'
)
ENGINE = OLAP
DUPLICATE KEY(
      dt_month
)
COMMENT '往来BSEG已清与本月未清凭证行项目表'
AUTO PARTITION BY LIST (dt_month) ()
DISTRIBUTED BY HASH(bukrs) BUCKETS 5
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
