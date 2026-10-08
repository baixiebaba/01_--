/*
-- ============================================================================
-- 最新版修改记录：20260910 ADD BY shiqingfeng.ex 新增
-- 上一版修改记录：
-- 目标表：客户账期明细表 test.dwd_fi_mr_ar_cterm_md
-- 修改记录：最新修改记录放最上面
--   20260910 ADD BY shiqingfeng.ex 新增
-- ============================================================================
*/
 
-- ============================================================================
-- 全量覆盖写入客户账期明细。
-- 代码和描述分别排序拼接，保证付款条件代码与描述一一对应。
-- ============================================================================
INSERT OVERWRITE TABLE test.dwd_fi_mr_ar_cterm_md
(
      company_code             -- 组织
    , cust_code                -- 客户编码
    , pay_term_code            -- 付款条件代码
    , pay_term_desc            -- 付款条件描述
    , system_src               -- 来源系统
    , load_dt                  -- 更新时间
)
WITH
-- 汇总六套SAP客户公司数据，提供组织、客户和付款条件代码。
src_knb1 AS (
    SELECT 'S600' AS sap_system, mandt, bukrs, kunnr, zterm FROM ods.odss600_knb1

    UNION ALL

    SELECT 'S700' AS sap_system, mandt, bukrs, kunnr, zterm FROM ods.odss700_knb1

    UNION ALL

    SELECT 'S800' AS sap_system, mandt, bukrs, kunnr, zterm FROM ods.odss800_knb1

    UNION ALL

    SELECT 'S900' AS sap_system, mandt, bukrs, kunnr, zterm FROM ods.odss900_knb1

    UNION ALL

    SELECT 'S610' AS sap_system, mandt, bukrs, kunnr, zterm FROM ods.odss610_knb1

    UNION ALL

    SELECT 'S810' AS sap_system, mandt, bukrs, kunnr, zterm FROM ods.odss810_knb1
),
-- 汇总六套SAP付款条件文本，仅保留语言代码1。
src_t052u AS (
    SELECT 'S600' AS sap_system, zterm, text1 FROM ods.odss600_t052u WHERE spras = '1'

    UNION ALL

    SELECT 'S700' AS sap_system, zterm, text1 FROM ods.odss700_t052u WHERE spras = '1'

    UNION ALL

    SELECT 'S800' AS sap_system, zterm, text1 FROM ods.odss800_t052u WHERE spras = '1'

    UNION ALL

    SELECT 'S900' AS sap_system, zterm, text1 FROM ods.odss900_t052u WHERE spras = '1'

    UNION ALL

    SELECT 'S610' AS sap_system, zterm, text1 FROM ods.odss610_t052u WHERE spras = '1'

    UNION ALL

    SELECT 'S810' AS sap_system, zterm, text1 FROM ods.odss810_t052u WHERE spras = '1'
),
-- 关联客户付款条件与文本，并统一转换目标字段类型。
joined_detail AS (
    SELECT k.bukrs AS company_code
         , LTRIM(k.kunnr, '0') AS cust_code
         , k.zterm AS pay_term_code
         , t.text1 AS pay_term_desc
         , CONCAT('S', k.mandt) AS system_src
      FROM src_knb1 k
      LEFT JOIN src_t052u t
        ON k.sap_system = t.sap_system
       AND k.zterm = t.zterm
     WHERE k.zterm IS NOT NULL
       AND TRIM(k.zterm) <> ''
),
-- 按组织、客户、付款条件和来源系统去重，避免源数据重复拼接。
dedup_pay_term AS (
    SELECT company_code
         , cust_code
         , pay_term_code
         , MAX(pay_term_desc) AS pay_term_desc
         , system_src
      FROM joined_detail
     GROUP BY company_code
            , cust_code
            , pay_term_code
            , system_src
)
SELECT company_code
     , cust_code
     , CONCAT_WS(
           ','
         , ARRAY_SORT(COLLECT_LIST(COALESCE(pay_term_code, '')))
       ) AS pay_term_code
     , CONCAT_WS(
           ','
         , ARRAY_SORTBY(
               COLLECT_LIST(COALESCE(pay_term_desc, ''))
             , COLLECT_LIST(COALESCE(pay_term_code, ''))
           )
       ) AS pay_term_desc
     , system_src
     , NOW() AS load_dt
  FROM dedup_pay_term
 GROUP BY company_code
        , cust_code
        , system_src
;
