/*
-- ============================================================================
-- 目标：应收应付重分类规则头表、条件明细表
-- 用途：将 F_APAR_REC 的 CASE/WHEN 逻辑配置化，供 DWD/DWM 多个作业复用。
-- 设计：规则头保存输出、优先级、金额符号和有效期；条件明细按维度维护。
-- 版本：20260920
-- ============================================================================
*/

-- 规则头：一条记录对应 F_APAR_REC 中的一条可命中规则。
CREATE TABLE IF NOT EXISTS dim.dim_rule_fi_mr_ar_reclass (
      rule_id INT COMMENT '规则ID；同一规则只保留一条头记录'
    , rule_code VARCHAR(100) COMMENT '规则编码，便于审计和变更'
    , rule_group VARCHAR(50) COMMENT '规则组；用于区分600、610、总部等路由'
    , rule_priority INT COMMENT '全局匹配优先级，数值越小越先命中'
    , rule_kind VARCHAR(20) COMMENT 'MATCH普通规则；BLOCK阻断规则；DEFAULT兜底规则'
    , amount_sign VARCHAR(20) COMMENT '金额条件：ANY、GE_ZERO、LT_ZERO、LE_ZERO、GT_ZERO、NULL_ONLY'
    , reclass_flag VARCHAR(1) COMMENT '是否重分类：Y/N；未命中保持NULL'
    , reclass_type VARCHAR(10) COMMENT '重分类类别：AR/OR/AS/AP/OP/AC/CA/CL/RF/A9/A10'
    , valid_fr VARCHAR(6) COMMENT '生效月份YYYYMM，含边界'
    , valid_to VARCHAR(6) COMMENT '失效月份YYYYMM，含边界'
    , enabled VARCHAR(1) COMMENT '是否启用：Y/N'
    , remark VARCHAR(1000) COMMENT '业务说明、来源和变更记录'
)
ENGINE = OLAP
DUPLICATE KEY(rule_id)
COMMENT '应收应付重分类规则头表'
DISTRIBUTED BY HASH(rule_id) BUCKETS 3
PROPERTIES (
      "replication_allocation" = "tag.location.default: 1"
    , "min_load_replica_num" = "-1"
    , "storage_medium" = "hdd"
    , "storage_format" = "V2"
    , "light_schema_change" = "true"
);

-- 条件明细：同一 condition_group 内按 condition_logic 计算；不同组之间必须同时满足。
CREATE TABLE IF NOT EXISTS dim.dim_rule_fi_mr_ar_reclass_cond (
      rule_id INT COMMENT '关联规则头表rule_id'
    , condition_group VARCHAR(20) COMMENT '条件维度：MANDT、BUKRS、HKONT、CVCODE'
    , condition_logic VARCHAR(3) COMMENT '组内逻辑：OR表示任一命中；AND表示全部命中'
    , match_type VARCHAR(20) COMMENT 'EQ、PREFIX、RANGE、NOT_EQ、NOT_PREFIX'
    , match_value VARCHAR(50) COMMENT '匹配值；PREFIX填写前缀，RANGE填写起始值'
    , match_value_to VARCHAR(50) COMMENT 'RANGE结束值，其他类型为空'
    , remark VARCHAR(500) COMMENT '条件说明'
)
ENGINE = OLAP
DUPLICATE KEY(rule_id, condition_group, condition_logic, match_type, match_value)
COMMENT '应收应付重分类规则条件明细表'
DISTRIBUTED BY HASH(rule_id) BUCKETS 3
PROPERTIES (
      "replication_allocation" = "tag.location.default: 1"
    , "min_load_replica_num" = "-1"
    , "storage_medium" = "hdd"
    , "storage_format" = "V2"
    , "light_schema_change" = "true"
);
