/*
-- ============================================================================
-- 用途：应收应付重分类配置表通用匹配模板
-- 输入：base_fact CTE必须提供 fact_id、yearmonth、mandt、bukrs、hkont、cvcode、dmbtr。
-- 输出：reclass_flag、reclass_type、matched_rule_id、matched_rule_code。
-- 说明：替换 base_fact 后可复用于DWD明细、DWD汇总或旧账龄中间结果。
-- ============================================================================
*/

WITH
-- 基础事实：先统一字段格式；cvcode_norm复刻原函数LTRIM(P_CVCODE, '0')。
base_fact AS (
    SELECT fact_id
         , yearmonth
         , TRIM(mandt) AS mandt
         , TRIM(bukrs) AS bukrs
         , TRIM(hkont) AS hkont
         , LTRIM(TRIM(cvcode), '0') AS cvcode_norm
         , dmbtr
      FROM source_fact
),
-- 读取生效规则；优先级必须在同一规则组内稳定维护。
active_rule AS (
    SELECT rule_id
         , rule_code
         , rule_group
         , rule_priority
         , rule_kind
         , amount_sign
         , reclass_flag
         , reclass_type
         , valid_fr
         , valid_to
         FROM dim.dim_rule_fi_mr_ar_reclass
     WHERE enabled = 'Y'
),
-- 读取生效条件；不同condition_group之间是AND，同组由condition_logic决定OR/AND。
active_cond AS (
    SELECT c.rule_id
         , c.condition_group
         , c.condition_logic
         , c.match_type
         , c.match_value
         , c.match_value_to
      FROM dim.dim_rule_fi_mr_ar_reclass_cond c
      INNER JOIN active_rule r
        ON r.rule_id = c.rule_id
),
-- 计算每个事实对每条规则的条件组命中情况。
condition_eval AS (
    SELECT b.fact_id
         , r.rule_id
         , r.rule_code
         , r.rule_group
         , r.rule_priority
         , r.rule_kind
         , r.reclass_flag
         , r.reclass_type
         , c.condition_group
         , c.condition_logic
         , COUNT(c.rule_id) AS condition_count
         , SUM(
               CASE
                   WHEN c.condition_group IS NULL THEN 0
                   WHEN c.condition_group = 'MANDT'
                    AND c.match_type = 'EQ'
                    AND b.mandt = c.match_value THEN 1
                   WHEN c.condition_group = 'MANDT'
                    AND c.match_type = 'PREFIX'
                    AND b.mandt LIKE CONCAT(c.match_value, '%') THEN 1
                   WHEN c.condition_group = 'MANDT'
                    AND c.match_type = 'NOT_EQ'
                    AND b.mandt <> c.match_value THEN 1
                   WHEN c.condition_group = 'BUKRS'
                    AND c.match_type = 'EQ'
                    AND b.bukrs = c.match_value THEN 1
                   WHEN c.condition_group = 'BUKRS'
                    AND c.match_type = 'PREFIX'
                    AND b.bukrs LIKE CONCAT(c.match_value, '%') THEN 1
                   WHEN c.condition_group = 'BUKRS'
                    AND c.match_type = 'RANGE'
                    AND b.bukrs BETWEEN c.match_value AND c.match_value_to THEN 1
                   WHEN c.condition_group = 'BUKRS'
                    AND c.match_type = 'NOT_EQ'
                    AND b.bukrs <> c.match_value THEN 1
                   WHEN c.condition_group = 'BUKRS'
                    AND c.match_type = 'NOT_PREFIX'
                    AND b.bukrs NOT LIKE CONCAT(c.match_value, '%') THEN 1
                   WHEN c.condition_group = 'HKONT'
                    AND c.match_type = 'EQ'
                    AND b.hkont = c.match_value THEN 1
                   WHEN c.condition_group = 'HKONT'
                    AND c.match_type = 'PREFIX'
                    AND b.hkont LIKE CONCAT(c.match_value, '%') THEN 1
                   WHEN c.condition_group = 'HKONT'
                    AND c.match_type = 'RANGE'
                    AND b.hkont BETWEEN c.match_value AND c.match_value_to THEN 1
                   WHEN c.condition_group = 'HKONT'
                    AND c.match_type = 'NOT_EQ'
                    AND b.hkont <> c.match_value THEN 1
                   WHEN c.condition_group = 'CVCODE'
                    AND c.match_type = 'EQ'
                    AND b.cvcode_norm = LTRIM(c.match_value, '0') THEN 1
                   WHEN c.condition_group = 'CVCODE'
                    AND c.match_type = 'PREFIX'
                    AND b.cvcode_norm LIKE CONCAT(LTRIM(c.match_value, '0'), '%') THEN 1
                   WHEN c.condition_group = 'CVCODE'
                    AND c.match_type = 'RANGE'
                    AND b.cvcode_norm BETWEEN LTRIM(c.match_value, '0')
                                            AND LTRIM(c.match_value_to, '0') THEN 1
                   WHEN c.condition_group = 'CVCODE'
                    AND c.match_type = 'NOT_EQ'
                    AND b.cvcode_norm <> LTRIM(c.match_value, '0') THEN 1
                   WHEN c.condition_group = 'CVCODE'
                    AND c.match_type = 'NOT_PREFIX'
                    AND b.cvcode_norm NOT LIKE CONCAT(LTRIM(c.match_value, '0'), '%') THEN 1
                   ELSE 0
               END
           ) AS matched_count
      FROM base_fact b
      INNER JOIN active_rule r
        ON NVL(r.valid_fr, '190001') <= b.yearmonth
       AND NVL(r.valid_to, '999912') >= b.yearmonth
       AND (
              r.amount_sign = 'ANY'
           OR (r.amount_sign = 'GE_ZERO' AND b.dmbtr >= 0)
           OR (r.amount_sign = 'LT_ZERO' AND b.dmbtr < 0)
           OR (r.amount_sign = 'LE_ZERO' AND b.dmbtr <= 0)
           OR (r.amount_sign = 'GT_ZERO' AND b.dmbtr > 0)
           OR (r.amount_sign = 'NULL_ONLY' AND b.dmbtr IS NULL)
       )
      LEFT JOIN active_cond c
        ON c.rule_id = r.rule_id
     GROUP BY b.fact_id
            , r.rule_id
            , r.rule_code
            , r.rule_group
            , r.rule_priority
            , r.rule_kind
            , r.reclass_flag
            , r.reclass_type
            , c.condition_group
            , c.condition_logic
),
-- 只有所有条件组都满足时，规则才算完整命中；无条件规则自动命中。
rule_match AS (
    SELECT fact_id
         , rule_id
         , rule_code
         , rule_group
         , rule_priority
         , rule_kind
         , reclass_flag
         , reclass_type
      FROM condition_eval
     GROUP BY fact_id
            , rule_id
            , rule_code
            , rule_group
            , rule_priority
            , rule_kind
            , reclass_flag
            , reclass_type
     HAVING SUM(
                CASE
                    WHEN condition_group IS NULL THEN 0
                    WHEN condition_logic = 'OR' AND matched_count > 0 THEN 0
                    WHEN condition_logic = 'AND' AND matched_count = condition_count THEN 0
                    ELSE 1
                END
            ) = 0
),
-- 每个事实只取最先命中的规则；rule_id作为同优先级的稳定排序键。
rule_pick AS (
    SELECT fact_id
         , rule_id AS matched_rule_id
         , rule_code AS matched_rule_code
         , reclass_flag
         , reclass_type
      FROM (
            SELECT m.*
                 , ROW_NUMBER() OVER (
                       PARTITION BY m.fact_id
                       ORDER BY m.rule_priority, m.rule_id
                   ) AS rn
              FROM rule_match m
      ) x
     WHERE rn = 1
)
SELECT b.fact_id
     , p.reclass_flag
     , p.reclass_type
     , p.matched_rule_id
     , p.matched_rule_code
  FROM base_fact b
  LEFT JOIN rule_pick p
    ON p.fact_id = b.fact_id;

-- 集成注意事项：
-- 1. fact_id必须在本次事实集内唯一；若不是唯一键，请用完整业务粒度拼接哈希或先生成行号。
-- 2. 规则头表中同一事实可能命中多条规则，最终只由rule_priority、rule_id决定首条。
-- 3. 规则组内多条条件默认以condition_group聚合；同组OR适合IN，多条AND适合NOT_IN。
-- 4. 不要在配置中维护逗号分隔的IN字符串；每个值单独一行，便于增删和审计。
-- 5. 若要复刻旧函数的DMBTR_REC与DMBTR_REC_M两种口径，应先分别聚合后各生成fact_id，再执行本模板。
