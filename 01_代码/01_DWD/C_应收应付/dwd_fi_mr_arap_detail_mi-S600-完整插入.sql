/*
-- ============================================================================
-- 最新版修改记录：20260910 ADD BY Kiro 新增S600完整明细追加插入脚本
-- 上一版修改记录：
-- 目标表：test.dwd_fi_mr_arap_detail_mi
-- 文件说明：仅处理S600的统驭科目账龄与非统驭科目月末余额，幂等插入目标明细表
-- 执行方式：先DELETE同月S600记录，再INSERT INTO；保留其他系统数据
-- ============================================================================
*/
-- 业务输入：运行月份基准日，格式YYYYMMDD，约定为参数月01日。
SET @year_month_day = '20260801';
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);
-- 账龄关键日期：参数月月末DATE。
SET @key_date = LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d'));
-- SAP日期比较值：参数月月末YYYYMMDD。
SET @key_date_sap = DATE_FORMAT(@key_date, '%Y%m%d');
-- 财年：参数年份YYYY。
SET @fiscal_year = LEFT(@year_month_day, 4);
-- 财月：参数月份MM。
SET @fiscal_month = SUBSTR(@year_month_day, 5, 2);
-- 公司筛选：空字符串表示写入全部S600公司；非空时仅写入指定公司。
SET @company_code = '';
-- 空基准日期的最小有效日期：用于计算最大账龄段。
SET @min_aging_date_sap = '00010101';
-- 以上SET与下方INSERT INTO ... WITH ... SELECT必须在同一session中执行。

-- ============================================================================
-- S600完整明细插入：统驭科目账龄与非统驭科目月末累计余额。
-- 先删除同月份S600已存在记录（保留其他系统），再INSERT INTO实现幂等S600插入。
-- ============================================================================
-- 删除当前月份目标表中system_src='S600'的记录，避免重复。
DELETE FROM test.dwd_fi_mr_arap_detail_mi
 WHERE dt_month = @dt_month
   AND system_src = 'S600';

-- S600明细插入，写入system_src='S600'的记录。
INSERT INTO test.dwd_fi_mr_arap_detail_mi
(
      dt_month                 -- 年月
    , `year`                   -- 年份
    , `month`                  -- 月份
    , company_code             -- 组织
    , acct_cert_type           -- 凭证类型
    , acct_cert_status         -- 凭证状态
    , acct_cert_id             -- 凭证号
    , acct_cert_item           -- 凭证行项目
    , voucher_dt               -- 凭证日期
    , posting_dt               -- 凭证过账日期
    , baseline_dt              -- 账龄起算日期
    , clearing_dt              -- 清账日期
    , cust_code                -- 客商编码
    , cust_name                -- 客商名称
    , cust_head_code           -- 主户编码
    , cust_head_name           -- 主户名称
    , cust_branch_code         -- 分户编码
    , cust_branch_name         -- 分户名称
    , cp_company_code          -- 对方公司
    , country_code             -- 国家编码
    , country_name             -- 国家名称
    , acct_type_code           -- 科目类型
    , acct_src_code            -- 原始科目编码
    , acct_map_code            -- 映射后科目编码
    , channel_l1_code          -- 一级公司分类编码
    , channel_l1_name          -- 一级公司分类名称
    , channel_l2_code          -- 二级公司分类编码
    , channel_l2_name          -- 二级公司分类名称
    , channel_l3_code          -- 三级公司分类编码
    , channel_l3_name          -- 三级公司分类名称
    , tov_channel_code         -- 周转分析渠道编码
    , tov_channel_name         -- 周转分析渠道名称
    , cc_cust_group_code       -- 商冷客户群编码
    , cc_cust_group_name       -- 商冷客户群名称
    , onoffline_code           -- 渠道分组编码
    , onoffline_name           -- 渠道分组名称
    , src_profitcenter_code    -- 原始利润中心编码
    , src_profitcenter_name    -- 原始利润中心名称
    , profitcenter_code        -- 映射后利润中心编码
    , profitcenter_name        -- 映射后利润中心名称
    , bus_range_code           -- 业务范围编码
    , bus_range_name           -- 业务范围名称
    , marketing_dept_code      -- 业务管理单元编码
    , marketing_dept_name      -- 业务管理单元名称
    , nature_l1_name           -- 一级性质
    , nature_l2_name           -- 二级性质
    , nature_l3_name           -- 三级性质
    , pay_method               -- 付款方式
    , pay_reason_code          -- 付款原因代码
    , bcy_code                 -- 本位币币种
    , qcy_code                 -- 交易币币种
    , bcy_amt                  -- 本位币金额
    , qcy_amt                  -- 交易币金额
    , aging_days               -- 账龄天数
    , aging_seg_code           -- 账龄段编码
    , aging_seg_name           -- 账龄段名称
    , pays_tran                -- 付款服务商的付款编号
    , note                     -- 备注
    , system_src               -- 来源系统
    , ods_src                  -- 数据来源
    , load_dt                  -- 更新时间
)
WITH
-- 汇总S600应收应付科目范围配置。
src_ztzt_003 AS (
    SELECT 'S600' AS system_src, ktopl, hkonf, hkont, koart
      FROM ods.odss600_ztzt_003
),
-- 汇总S600公司代码、科目表和本位币配置。
src_t001 AS (
    SELECT 'S600' AS system_src, bukrs, ktopl, waers
      FROM ods.odss600_t001
),
-- 汇总S600公司科目及统驭标识，用于识别统驭/非统驭科目。
src_skb1 AS (
    SELECT 'S600' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss600_skb1
),
-- 汇总S600客户主数据，提供客户名称和MDG编码。
src_kna1 AS (
    SELECT 'S600' AS system_src, kunnr, name1, zkunnr_mdg
      FROM ods.odss600_kna1
),
-- 汇总S600供应商主数据，提供供应商名称和MDG编码。
src_lfa1 AS (
    SELECT 'S600' AS system_src, lifnr, name1, zlifnr_mdg
      FROM ods.odss600_lfa1
),
-- 汇总S600公司级客商主数据KVERM，按系统、公司、客商类型和主户编码聚合非空付款条件。
cust_kverm_dim AS (
    SELECT k.system_src
         , k.company_code
         , k.cust_code
         , k.cust_type_code
         , MAX(k.kverm) AS kverm
      FROM (
            SELECT 'S600' AS system_src, bukrs AS company_code, LTRIM(kunnr, '0') AS cust_code, 'C' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss600_knb1

            UNION ALL

            SELECT 'S600' AS system_src, bukrs AS company_code, LTRIM(lifnr, '0') AS cust_code, 'V' AS cust_type_code, NULLIF(TRIM(kverm), '') AS kverm FROM ods.odss600_lfb1
      ) k
     WHERE k.kverm IS NOT NULL
     GROUP BY k.system_src
            , k.company_code
            , k.cust_code
            , k.cust_type_code
),
-- 汇总S600利润中心文本，用于补充利润中心名称。
src_cepct AS (
    SELECT 'S600' AS system_src, prctr, spras, ktext
      FROM ods.odss600_cepct
),
-- 客户未清项目：仅保留参数月末前已过账且非A/S状态的记录。
src_bsid AS (
    SELECT 'S600' AS system_src, 'BSID' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, CASE
           WHEN TRIM(bukrs) = '6000' THEN CASE TRIM(gsber)
               WHEN '200' THEN '6000A'
               WHEN '400' THEN '6000B'
               WHEN '500' THEN '6000C'
               ELSE TRIM(bukrs)
           END
           ELSE gsber
       END AS gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, pays_tran, sgtxt
      FROM ods.odsslt_s600_bsid
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
),
-- 客户已清项目：保留月末前过账、月末后清账的项目，回溯月末未清快照。
src_bsad AS (
    SELECT 'S600' AS system_src, 'BSAD' AS ods_src, bukrs, kunnr AS cust_head_code, hkont, prctr, CASE
           WHEN TRIM(bukrs) = '6000' THEN CASE TRIM(gsber)
               WHEN '200' THEN '6000A'
               WHEN '400' THEN '6000B'
               WHEN '500' THEN '6000C'
               ELSE TRIM(bukrs)
           END
           ELSE gsber
       END AS gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, rstgr, zlsch, pays_tran, sgtxt
      FROM ods.odsslt_s600_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
),
-- 供应商未清项目：仅保留参数月末前已过账且非A/S状态的记录。
src_bsik AS (
    SELECT 'S600' AS system_src, 'BSIK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, CASE
           WHEN TRIM(bukrs) = '6000' THEN CASE TRIM(gsber)
               WHEN '200' THEN '6000A'
               WHEN '400' THEN '6000B'
               WHEN '500' THEN '6000C'
               ELSE TRIM(bukrs)
           END
           ELSE gsber
       END AS gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s600_bsik
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
),
-- 供应商已清项目：保留月末前过账、月末后清账的项目，回溯月末未清快照。
src_bsak AS (
    SELECT 'S600' AS system_src, 'BSAK' AS ods_src, bukrs, lifnr AS cust_head_code, hkont, prctr, CASE
           WHEN TRIM(bukrs) = '6000' THEN CASE TRIM(gsber)
               WHEN '200' THEN '6000A'
               WHEN '400' THEN '6000B'
               WHEN '500' THEN '6000C'
               ELSE TRIM(bukrs)
           END
           ELSE gsber
       END AS gsber, filkd, waers, blart, belnr, gjahr, buzei, budat, bldat, zfbdt, augdt, shkzg, dmbtr, wrbtr, bstat, NULL AS rstgr, zlsch, NULL AS pays_tran, sgtxt
      FROM ods.odsslt_s600_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
),
-- 按系统、公司和科目区间识别统驭科目，仅保留D应收/K应付。
account_cfg AS (
    SELECT DISTINCT t.system_src
         , t.bukrs AS company_code
         , s.saknr AS acct_code
         , s.mitkz AS acct_type_code
      FROM src_ztzt_003 z
     INNER JOIN src_t001 t
        ON t.system_src = z.system_src
       AND t.ktopl = z.ktopl
     INNER JOIN src_skb1 s
        ON s.system_src = t.system_src
       AND s.bukrs = t.bukrs
       AND s.saknr BETWEEN z.hkonf AND z.hkont
       AND s.mitkz IN ('D', 'K')
),
-- 合并四类稳定同构行项目源，并标记应收/应付及客商类型。
unioned_items AS (
    SELECT 'D' AS acct_type_code
         , 'CUSTOMER' AS object_source
         , b.*
      FROM src_bsid b

    UNION ALL

    SELECT 'D' AS acct_type_code
         , 'CUSTOMER' AS object_source
         , b.*
      FROM src_bsad b

    UNION ALL

    SELECT 'K' AS acct_type_code
         , 'VENDOR' AS object_source
         , b.*
      FROM src_bsik b

    UNION ALL

    SELECT 'K' AS acct_type_code
         , 'VENDOR' AS object_source
         , b.*
      FROM src_bsak b
),
-- 统一投影27字段接口，并一次关联统驭科目配置过滤有效行项目。
all_items AS (
    SELECT b.system_src
         , b.ods_src
         , b.acct_type_code
         , b.object_source
         , b.bukrs
         , b.cust_head_code
         , b.hkont
         , b.prctr
         , b.gsber
         , b.filkd
         , b.waers
         , b.blart
         , b.belnr
         , b.gjahr
         , b.buzei
         , b.budat
         , b.bldat
         , b.zfbdt
         , b.augdt
         , b.shkzg
         , b.dmbtr
         , b.wrbtr
         , b.bstat
         , b.rstgr
         , b.zlsch
         , b.pays_tran
         , b.sgtxt
      FROM unioned_items b
     INNER JOIN account_cfg c
        ON c.system_src = b.system_src
       AND c.company_code = b.bukrs
       AND c.acct_code = b.hkont
       AND c.acct_type_code = b.acct_type_code
),
-- 按目标月份筛选有效科目映射，并按原始科目和系统聚合。
acct_mapping AS (
    SELECT a.acct_src_code AS racct_src_code
         , MAX(a.acct_map_code) AS acct_map_code
         , a.system_src
      FROM dim.dim_rule_fi_mr_acct_mapping a
     WHERE NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
     GROUP BY a.acct_src_code
            , a.system_src
),
-- 读取有效月份内的账龄日期规则，并区分公司级与系统级配置。
agingdate_cfg AS (
    SELECT TRIM(r.system_src) AS system_src
         , NULLIF(TRIM(r.company_code), '') AS company_code
      FROM dim.dim_rule_fi_mr_ar_agingdate r
     WHERE NVL(r.valid_fr, '202401') <= @dt_month
       AND NVL(r.valid_to, '999999') >= @dt_month
     GROUP BY TRIM(r.system_src)
            , NULLIF(TRIM(r.company_code), '')
),
-- 按AB、公司级、系统级和默认BLDAT的优先级确定账龄起算字段；基准日期为空时使用最小有效日期。
items_with_aging_date AS (
    SELECT a.*
         , CASE
               WHEN a.blart = 'AB' THEN COALESCE(
                   NULLIF(TRIM(a.zfbdt), '')
                 , @min_aging_date_sap
               )
               WHEN company_cfg.system_src IS NOT NULL THEN COALESCE(
                   NULLIF(TRIM(a.zfbdt), '')
                 , @min_aging_date_sap
               )
               WHEN system_cfg.system_src IS NOT NULL THEN COALESCE(
                   NULLIF(TRIM(a.zfbdt), '')
                 , @min_aging_date_sap
               )
               ELSE NULLIF(TRIM(a.bldat), '')
           END AS aging_date_sap
      FROM all_items a
      LEFT JOIN agingdate_cfg company_cfg
        ON company_cfg.system_src = a.system_src
       AND company_cfg.company_code = a.bukrs
      LEFT JOIN agingdate_cfg system_cfg
        ON system_cfg.system_src = a.system_src
       AND system_cfg.company_code IS NULL
),
-- 转换日期、标准化客商编码、处理借贷方向并计算账龄天数。
normalized_items AS (
    SELECT a.system_src
         , a.ods_src
         , a.object_source
         , a.bukrs AS company_code
         , a.blart AS acct_cert_type
         , a.bstat AS acct_cert_status
         , a.belnr AS acct_cert_id
         , NULLIF(TRIM(a.gjahr), '') AS gjahr
         , a.buzei AS acct_cert_item
         , STR_TO_DATE(NULLIF(TRIM(a.bldat), ''), '%Y%m%d') AS voucher_dt
         , STR_TO_DATE(NULLIF(TRIM(a.budat), ''), '%Y%m%d') AS posting_dt
         , STR_TO_DATE(NULLIF(TRIM(a.aging_date_sap), ''), '%Y%m%d') AS baseline_dt
         , STR_TO_DATE(NULLIF(TRIM(a.augdt), ''), '%Y%m%d') AS clearing_dt
         , LTRIM(COALESCE(a.cust_head_code, ''), '0') AS cust_head_code
         , LTRIM(COALESCE(a.filkd, ''), '0') AS cust_branch_code
         , a.acct_type_code
         , a.hkont AS acct_src_code
         , CASE WHEN a.system_src = 'S600' THEN a.hkont ELSE am.acct_map_code END AS acct_map_code
         , COALESCE(a.prctr, '') AS src_profitcenter_code
         , COALESCE(a.gsber, '') AS bus_range_code
         , a.zlsch AS pay_method
         , NULLIF(TRIM(a.rstgr), '') AS pay_reason_code
         , COALESCE(a.waers, '') AS qcy_code
         , CASE
               WHEN a.shkzg = 'H'
                   THEN -a.dmbtr
               ELSE a.dmbtr
           END AS bcy_amt
         , CASE
               WHEN a.shkzg = 'H'
                   THEN -a.wrbtr
               ELSE a.wrbtr
           END AS qcy_amt
         , CAST(
               DATEDIFF(
                   @key_date
                    , STR_TO_DATE(NULLIF(TRIM(a.aging_date_sap), ''), '%Y%m%d')
               ) + 1 AS DECIMALV3(27, 9)
           ) AS aging_days
         , a.pays_tran
         , a.sgtxt AS note
      FROM items_with_aging_date a
      LEFT JOIN acct_mapping am
        ON am.racct_src_code = a.hkont
       AND am.system_src = a.system_src
),
-- 读取目标月份有效的账龄段配置，并准备账龄天数匹配区间。
aging_seg_cfg AS (
    SELECT r.aging_seg_code
         , r.aging_seg_name
         , CAST(r.aging_seg_fr AS DECIMALV3(27, 9)) AS aging_seg_fr
         , CAST(r.aging_seg_to AS DECIMALV3(27, 9)) AS aging_seg_to
      FROM dim.dim_rule_fi_mr_ar_aging_seg r
     WHERE NVL(r.valid_fr, '202401') <= @dt_month
       AND NVL(r.valid_to, '999999') >= @dt_month
),
-- 按系统和去前导零后的客户编码聚合客户名称及MDG编码。
customer_dim AS (
    SELECT system_src
         , LTRIM(kunnr, '0') AS kunnr
         , MAX(name1) AS name1
         , MAX(LTRIM(zkunnr_mdg, '0')) AS zkunnr_mdg
      FROM src_kna1
     GROUP BY system_src
            , LTRIM(kunnr, '0')
),
-- 按系统和去前导零后的供应商编码聚合供应商名称及MDG编码。
vendor_dim AS (
    SELECT system_src
         , LTRIM(lifnr, '0') AS lifnr
         , MAX(name1) AS name1
         , MAX(LTRIM(zlifnr_mdg, '0')) AS zlifnr_mdg
      FROM src_lfa1
     GROUP BY system_src
            , LTRIM(lifnr, '0')
),
-- 聚合客户分类和国家维度，供MDG客商编码关联。
customer_class_dim AS (
    SELECT LTRIM(cust_code, '0') AS cust_code
         , MAX(com_1st_code) AS com_1st_code
         , MAX(com_1st_name) AS com_1st_name
         , MAX(com_2nd_code) AS com_2nd_code
         , MAX(com_2nd_name) AS com_2nd_name
         , MAX(com_3rd_code) AS com_3rd_code
         , MAX(com_3rd_name) AS com_3rd_name
         , MAX(country_code) AS country_code
         , MAX(country_name) AS country_name
      FROM dw.dim_customer_base_info_dd
     GROUP BY LTRIM(cust_code, '0')
),
-- 筛选有效的客商对方公司映射，并按客商、类型和系统聚合。
cp_company_dim AS (
    SELECT LTRIM(a.cust_code, '0') AS cust_code
         , a.cust_type_code
         , a.system_src
         , MAX(
               COALESCE(
                   NULLIF(TRIM(a.cp_company_code_mr), '')
                 , TRIM(a.cp_company_code)
               )
           ) AS cp_company_code
      FROM dim.dim_rule_fi_mr_cust2ctp_mapping a
     WHERE a.cust_type_code IN ('C', 'V')
       AND NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
     GROUP BY LTRIM(a.cust_code, '0')
            , a.cust_type_code
            , a.system_src
),
-- 读取目标月份有效的电商零售类客户范围。
ecom_retail_cust AS (
    SELECT LTRIM(r.cust_code, '0') AS cust_code
      FROM dim.dim_rule_fi_mr_ar_cust_type r
     WHERE TRIM(r.cust_type) = '电商零售类客户'
       AND NVL(r.valid_fr, '202401') <= @dt_month
       AND NVL(r.valid_to, '999999') >= @dt_month
     GROUP BY LTRIM(r.cust_code, '0')
),
-- 读取目标月份有效的新旧利润中心映射；同一原始利润中心重复配置使用MAX聚合。
ar_profit_mapping AS (
    SELECT r.src_profitcenter_code
         , MAX(r.profitcenter_code) AS profitcenter_code
         , MAX(r.profitcenter_name) AS profitcenter_name
      FROM dim.dim_rule_fi_mr_ar_profit_mapping r
     WHERE TRIM(r.logic_name) = '新旧利润中心映射'
       AND NVL(r.valid_fr, '202401') <= @dt_month
       AND NVL(r.valid_to, '999999') >= @dt_month
     GROUP BY r.src_profitcenter_code
),
-- 读取应收模块渠道分组规则；同一匹配键的重复配置使用MAX聚合，避免窗口排序开销。
ar_nf_rule AS (
    SELECT CAST(r.batch_id AS INT) AS batch_id
         , r.company_code
         , r.channel_l2_code
         , r.channel_l3_code
         , MAX(r.onoffline_code) AS onoffline_code
         , MAX(r.onoffline_name) AS onoffline_name
      FROM dim.dim_rule_fi_mr_ar_nf_mapping r
     WHERE NVL(r.valid_fr, '202401') <= @dt_month
       AND NVL(r.valid_to, '999999') >= @dt_month
     GROUP BY CAST(r.batch_id AS INT)
            , r.company_code
            , r.channel_l2_code
            , r.channel_l3_code
),
-- 读取收入模块线上线下规则，并展开公司包含关系；同一匹配键的重复配置使用MAX聚合。
rev_nf_rule AS (
    SELECT CAST(a.batch_id AS INT) AS batch_id
         , b.cod_azienda AS company_code
         , c.cod_azienda AS cp_company_code
         , LTRIM(NULLIF(TRIM(a.cust_code), ''), '0') AS cust_code
         , MAX(a.onoffline_code) AS onoffline_code
         , MAX(a.onoffline_name) AS onoffline_name
      FROM dim.dim_rule_fi_mr_nf_mapping a
      LEFT JOIN ods.odsfima_azienda b
        ON b.cod_azienda LIKE a.company_code
      LEFT JOIN ods.odsfima_azienda c
        ON c.cod_azienda LIKE a.cp_company_code
     WHERE NVL(a.valid_fr, '202401') <= @dt_month
       AND NVL(a.valid_to, '999999') >= @dt_month
       AND CAST(a.batch_id AS INT) IN (1, 2, 5)
     GROUP BY CAST(a.batch_id AS INT)
            , b.cod_azienda
            , c.cod_azienda
            , LTRIM(NULLIF(TRIM(a.cust_code), ''), '0')
),
-- 构造客商和供应商行的渠道匹配上下文；两类客商使用相同规则及默认渠道处理。
nf_match_base AS (
    SELECT MD5(
               CONCAT_WS(
                   '|'
                 , COALESCE(a.system_src, '')
                 , COALESCE(a.ods_src, '')
                 , COALESCE(a.company_code, '')
                 , COALESCE(a.gjahr, '')
                 , COALESCE(a.acct_cert_id, '')
                 , COALESCE(a.acct_cert_item, '')
               )
           ) AS fact_key
         , a.company_code
         , CASE
               WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL
                   THEN a.cust_branch_code
               ELSE a.cust_head_code
           END AS cust_code
         , ctp.cp_company_code
         , ch.com_2nd_code AS channel_l2_code
         , ch.com_3rd_code AS channel_l3_code
      FROM normalized_items a
      LEFT JOIN customer_dim c
        ON a.object_source = 'CUSTOMER'
       AND c.system_src = a.system_src
       AND c.kunnr = a.cust_head_code
      LEFT JOIN vendor_dim v
        ON a.object_source = 'VENDOR'
       AND v.system_src = a.system_src
       AND v.lifnr = a.cust_head_code
      LEFT JOIN customer_class_dim ch
        ON ch.cust_code = CASE
                               WHEN a.object_source = 'CUSTOMER' THEN c.zkunnr_mdg
                               ELSE v.zlifnr_mdg
                           END
      LEFT JOIN cp_company_dim ctp
        ON ctp.cust_code = a.cust_head_code
       AND ctp.system_src = a.system_src
       AND ctp.cust_type_code = CASE
                                    WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                    ELSE 'V'
                                END
),
-- 应收模块渠道规则按1（公司+三级）→2（公司+二级）→3（公司）顺序匹配。
ar_nf_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.onoffline_code
         , r.onoffline_name
      FROM nf_match_base b
      INNER JOIN ar_nf_rule r
        ON (
               r.batch_id = 1
           AND r.company_code = b.company_code
           AND r.channel_l3_code = b.channel_l3_code
           )
        OR (
               r.batch_id = 2
           AND r.company_code = b.company_code
           AND r.channel_l2_code = b.channel_l2_code
           )
        OR (
               r.batch_id = 3
           AND r.company_code = b.company_code
           )
),
-- 应收规则按最小batch_id取优先级；同一事实键的重复配置使用MAX聚合。
ar_nf_pick AS (
    SELECT c.fact_key
         , MAX(c.onoffline_code) AS onoffline_code
         , MAX(c.onoffline_name) AS onoffline_name
      FROM ar_nf_candidate c
      INNER JOIN (
            SELECT fact_key
                 , MIN(batch_id) AS batch_id
              FROM ar_nf_candidate
             GROUP BY fact_key
      ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 应收规则未命中时，按收入模块既有5→2→1优先级回退匹配。
rev_nf_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.onoffline_code
         , r.onoffline_name
      FROM nf_match_base b
      INNER JOIN rev_nf_rule r
        ON (
               r.batch_id = 1
           AND r.company_code = b.company_code
           )
        OR (
               r.batch_id = 2
           AND r.company_code = b.company_code
           AND r.cust_code = b.cust_code
           )
        OR (
               r.batch_id = 5
           AND r.company_code = b.company_code
           AND r.cp_company_code = b.cp_company_code
           )
     WHERE NOT EXISTS (
               SELECT 1
                 FROM ar_nf_pick ar
                WHERE ar.fact_key = b.fact_key
           )
),
-- 收入规则按最大batch_id取优先级；同一事实键的重复配置使用MAX聚合。
rev_nf_pick AS (
    SELECT c.fact_key
         , MAX(c.onoffline_code) AS onoffline_code
         , MAX(c.onoffline_name) AS onoffline_name
      FROM rev_nf_candidate c
      INNER JOIN (
            SELECT fact_key
                 , MAX(batch_id) AS batch_id
              FROM rev_nf_candidate
             GROUP BY fact_key
      ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 应收规则优先，未命中才使用收入规则；字符串NULL表示规则显式置空，不再回退默认值。
nf_final AS (
    SELECT fact_key
         , CASE WHEN onoffline_code = 'NULL' THEN NULL ELSE onoffline_code END AS onoffline_code
         , CASE WHEN onoffline_name = 'NULL' THEN NULL ELSE onoffline_name END AS onoffline_name
      FROM ar_nf_pick
    UNION ALL
    SELECT fact_key
         , CASE WHEN onoffline_code = 'NULL' THEN NULL ELSE onoffline_code END AS onoffline_code
         , CASE WHEN onoffline_name = 'NULL' THEN NULL ELSE onoffline_name END AS onoffline_name
      FROM rev_nf_pick
),
-- 公司10架构：01020为商显公司，050为日立公司。
company10_scope AS (
    SELECT TRIM(elem) AS company_code
         , MAX(
               CASE
                   WHEN TRIM(node) = '01020'
                       THEN '商显公司'
                   ELSE '日立公司'
               END
           ) AS company_scope
      FROM ods.odsfima_v_ref_azienda
     WHERE TRIM(hie) = '10'
       AND TRIM(node) IN ('01020', '050')
     GROUP BY TRIM(elem)
),
-- 客户、供应商共用的业务范围、三级性质和业务管理单元映射上下文。
ar_mapping_base AS (
    SELECT MD5(
               CONCAT_WS(
                   '|'
                 , COALESCE(a.system_src, '')
                 , COALESCE(a.ods_src, '')
                 , COALESCE(a.company_code, '')
                 , COALESCE(a.gjahr, '')
                 , COALESCE(a.acct_cert_id, '')
                 , COALESCE(a.acct_cert_item, '')
               )
           ) AS fact_key
         , a.system_src
         , a.company_code
         , a.acct_src_code
         , a.acct_map_code
         , a.acct_type_code
         , a.cust_head_code AS cust_code
         , ch.com_2nd_code AS channel_l2_code
         , ch.country_code
         , pm.profitcenter_code
         , cs.company_scope
         , k.kverm
      FROM normalized_items a
      LEFT JOIN customer_dim c
        ON a.object_source = 'CUSTOMER'
       AND c.system_src = a.system_src
       AND c.kunnr = a.cust_head_code
      LEFT JOIN vendor_dim v
        ON a.object_source = 'VENDOR'
       AND v.system_src = a.system_src
       AND v.lifnr = a.cust_head_code
      LEFT JOIN customer_class_dim ch
        ON ch.cust_code = CASE
                               WHEN a.object_source = 'CUSTOMER'
                                   THEN c.zkunnr_mdg
                               ELSE v.zlifnr_mdg
                           END
      LEFT JOIN cust_kverm_dim k
        ON k.system_src = a.system_src
       AND k.company_code = a.company_code
       AND k.cust_type_code = CASE
                                  WHEN a.object_source = 'CUSTOMER' THEN 'C'
                                  ELSE 'V'
                              END
       AND k.cust_code = a.cust_head_code
      LEFT JOIN ecom_retail_cust er
        ON a.object_source = 'CUSTOMER'
       AND er.cust_code = CASE
                              WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL
                                  THEN a.cust_branch_code
                              ELSE a.cust_head_code
                          END
      LEFT JOIN ar_profit_mapping pm
        ON er.cust_code IS NOT NULL
       AND pm.src_profitcenter_code = a.src_profitcenter_code
      LEFT JOIN company10_scope cs
        ON cs.company_code = a.company_code
),
-- 按有效期聚合三级性质映射规则。
ar_nature_rule AS (
    SELECT CAST(batch_id AS INT) AS batch_id
         , company_code
         , cust_code
         , profitcenter_code
         , acct_src_code AS acct_map_code
         , acct_type
         , MAX(nature_l1_name) AS nature_l1_name
         , MAX(nature_l2_name) AS nature_l2_name
         , MAX(nature_l3_name) AS nature_l3_name
      FROM dim.dim_rule_fi_mr_ar_nature
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY CAST(batch_id AS INT)
            , company_code
            , cust_code
            , profitcenter_code
            , acct_src_code
            , acct_type
),
-- 三级性质按1→2→3→4→5的最小batch优先；每个batch单独关联，避免OR条件。
ar_nature_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 1
       AND r.company_code = b.company_code
       AND r.acct_map_code = b.acct_src_code
       AND r.acct_type = b.acct_type_code
       AND r.cust_code = b.cust_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 2
       AND r.company_code = b.company_code
       AND r.cust_code = b.cust_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 3
       AND r.company_code = b.company_code
       AND r.acct_map_code = b.acct_src_code
       AND r.acct_type = b.acct_type_code
       AND r.profitcenter_code = b.profitcenter_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 4
       AND r.company_code = b.company_code
       AND r.acct_map_code = b.acct_src_code
       AND r.acct_type = b.acct_type_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.nature_l1_name
         , r.nature_l2_name
         , r.nature_l3_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_rule r
        ON r.batch_id = 5
       AND r.acct_map_code = b.acct_src_code
       AND r.acct_type = b.acct_type_code
       AND r.cust_code = b.cust_code
),
-- 按最小批次优先原则确定三级性质。
ar_nature_pick AS (
    SELECT c.fact_key
         , MAX(c.nature_l1_name) AS nature_l1_name
         , MAX(c.nature_l2_name) AS nature_l2_name
         , MAX(c.nature_l3_name) AS nature_l3_name
      FROM ar_nature_candidate c
     INNER JOIN (
            SELECT fact_key
                 , MIN(batch_id) AS batch_id
              FROM ar_nature_candidate
             GROUP BY fact_key
     ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 按有效期聚合业务范围映射规则。
ar_busrange_rule AS (
    SELECT CAST(batch_id AS INT) AS batch_id
         , company_code
         , channel_l2_code
         , nature_l3_name
         , MAX(bus_range_code) AS bus_range_code
         , MAX(bus_range_name) AS bus_range_name
      FROM dim.dim_rule_fi_mr_ar_busrange_mapping
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY CAST(batch_id AS INT)
            , company_code
            , channel_l2_code
            , nature_l3_name
),
-- 非商显、非日立公司按1（公司+二级分类）→2（公司+三级性质）→3（公司）映射。
ar_busrange_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.bus_range_code
         , r.bus_range_name
      FROM ar_mapping_base b
     INNER JOIN ar_busrange_rule r
        ON r.batch_id = 1
       AND b.company_scope IS NULL
       AND r.company_code = b.company_code
       AND r.channel_l2_code = b.channel_l2_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.bus_range_code
         , r.bus_range_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_pick n
        ON n.fact_key = b.fact_key
     INNER JOIN ar_busrange_rule r
        ON r.batch_id = 2
       AND b.company_scope IS NULL
       AND r.company_code = b.company_code
       AND r.nature_l3_name = n.nature_l3_name
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.bus_range_code
         , r.bus_range_name
      FROM ar_mapping_base b
     INNER JOIN ar_busrange_rule r
        ON r.batch_id = 3
       AND b.company_scope IS NULL
       AND r.company_code = b.company_code
),
-- 从业务范围候选中按最小批次选取业务范围映射。
ar_busrange_pick AS (
    SELECT c.fact_key
         , MAX(c.bus_range_code) AS bus_range_code
         , MAX(c.bus_range_name) AS bus_range_name
      FROM ar_busrange_candidate c
     INNER JOIN (
        SELECT fact_key
             , MIN(batch_id) AS batch_id
          FROM ar_busrange_candidate
         GROUP BY fact_key
     ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 聚合有效期内国家与业务范围的映射规则。
ar_country_busrange_rule AS (
    SELECT country_code
         , MAX(bus_range_code) AS bus_range_code
         , MAX(bus_range_name) AS bus_range_name
      FROM dim.dim_rule_fi_mr_ar_country_busrange_mapping
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY country_code
),
-- 聚合有效期内业务管理单元映射规则。
ar_busdept_rule AS (
    SELECT CAST(batch_id AS INT) AS batch_id
         , system_src
         , profitcenter_code
         , nature_l3_name
         , MAX(marketing_dept_code) AS marketing_dept_code
         , MAX(marketing_dept_name) AS marketing_dept_name
      FROM dim.dim_rule_fi_mr_ar_busdept_mapping
     WHERE NVL(valid_fr, '202401') <= @dt_month
       AND NVL(valid_to, '999999') >= @dt_month
     GROUP BY CAST(batch_id AS INT)
            , system_src
            , profitcenter_code
            , nature_l3_name
),
-- 按1（系统+映射后利润中心）→2（系统+三级性质）生成业务管理单元候选。
ar_busdept_candidate AS (
    SELECT b.fact_key
         , r.batch_id
         , r.marketing_dept_code
         , r.marketing_dept_name
      FROM ar_mapping_base b
     INNER JOIN ar_busdept_rule r
        ON r.batch_id = 1
       AND r.system_src = b.system_src
       AND r.profitcenter_code = b.profitcenter_code
    UNION ALL
    SELECT b.fact_key
         , r.batch_id
         , r.marketing_dept_code
         , r.marketing_dept_name
      FROM ar_mapping_base b
     INNER JOIN ar_nature_pick n
        ON n.fact_key = b.fact_key
     INNER JOIN ar_busdept_rule r
        ON r.batch_id = 2
       AND r.system_src = b.system_src
       AND r.nature_l3_name = n.nature_l3_name
),
-- 从业务管理单元候选中按最小批次选取映射结果。
ar_busdept_pick AS (
    SELECT c.fact_key
         , MAX(c.marketing_dept_code) AS marketing_dept_code
         , MAX(c.marketing_dept_name) AS marketing_dept_name
      FROM ar_busdept_candidate c
     INNER JOIN (
        SELECT fact_key
             , MIN(batch_id) AS batch_id
          FROM ar_busdept_candidate
         GROUP BY fact_key
     ) p
        ON p.fact_key = c.fact_key
       AND p.batch_id = c.batch_id
     GROUP BY c.fact_key
),
-- 汇总业务范围与业务管理单元映射结果。
ar_business_mapping AS (
    SELECT b.fact_key
         , CASE WHEN n.fact_key IS NOT NULL THEN n.nature_l1_name ELSE b.kverm END AS nature_l1_name
         , CASE WHEN n.fact_key IS NOT NULL THEN n.nature_l2_name ELSE NULL END AS nature_l2_name
         , CASE WHEN n.fact_key IS NOT NULL THEN n.nature_l3_name ELSE NULL END AS nature_l3_name
         , CASE
               WHEN b.company_scope = '商显公司' AND UPPER(TRIM(b.country_code)) = 'CN'
                   THEN '2000'
               WHEN b.company_scope = '商显公司'
                   THEN '3000'
               WHEN b.company_scope = '日立公司' AND UPPER(TRIM(b.country_code)) = 'CN'
                   THEN '2200'
               WHEN b.company_scope = '日立公司'
                   THEN cr.bus_range_code
               ELSE br.bus_range_code
           END AS bus_range_code
         , CASE
               WHEN b.company_scope = '商显公司' AND UPPER(TRIM(b.country_code)) = 'CN'
                   THEN '中国区公共'
               WHEN b.company_scope = '商显公司'
                   THEN '海外公共'
               WHEN b.company_scope = '日立公司' AND UPPER(TRIM(b.country_code)) = 'CN'
                   THEN '日立国内营销分公司公共'
               WHEN b.company_scope = '日立公司'
                   THEN cr.bus_range_name
               ELSE br.bus_range_name
           END AS bus_range_name
         , bd.marketing_dept_code
         , bd.marketing_dept_name
      FROM ar_mapping_base b
      LEFT JOIN ar_nature_pick n
        ON n.fact_key = b.fact_key
      LEFT JOIN ar_busrange_pick br
        ON br.fact_key = b.fact_key
      LEFT JOIN ar_country_busrange_rule cr
        ON cr.country_code = b.country_code
      LEFT JOIN ar_busdept_pick bd
        ON bd.fact_key = b.fact_key
),
-- 聚合公司本位币配置。
company_dim AS (
    SELECT system_src
         , bukrs
         , MAX(waers) AS waers
      FROM src_t001
     GROUP BY system_src
            , bukrs
),
-- 仅保留语言为1的利润中心文本，并按系统/利润中心聚合。
profitcenter_dim AS (
    SELECT system_src
         , prctr
         , MAX(ktext) AS ktext
      FROM src_cepct
     -- 仅使用语言代码1的利润中心文本。
     WHERE spras = '1'
     GROUP BY system_src
            , prctr
),
-- 识别非统驭科目：SKB1统驭标识为空，但配置对象类型为D/K。
gl_account_cfg AS (
    SELECT DISTINCT t.system_src
         , t.bukrs AS company_code
         , s.saknr AS acct_code
         , TRIM(z.koart) AS acct_type_code
      FROM src_ztzt_003 z
     INNER JOIN src_t001 t
        ON t.system_src = z.system_src
       AND t.ktopl = z.ktopl
     INNER JOIN src_skb1 s
        ON s.system_src = t.system_src
       AND s.bukrs = t.bukrs
       AND s.saknr BETWEEN z.hkonf AND z.hkont
     WHERE COALESCE(TRIM(s.mitkz), '') = ''
       AND TRIM(z.koart) IN ('D', 'K')
),
-- 汇总S600总账余额源，并在物理源处按参数财年过滤。
src_gl_balance AS (
    SELECT CONCAT('S', g.rclnt) AS system_src, g.rbukrs AS company_code, g.racct AS acct_src_code, g.prctr AS src_profitcenter_code, CASE
           WHEN TRIM(g.rbukrs) = '6000' THEN CASE TRIM(g.rbusa)
               WHEN '200' THEN '6000A'
               WHEN '400' THEN '6000B'
               WHEN '500' THEN '6000C'
               ELSE TRIM(g.rbukrs)
           END
           ELSE g.rbusa
       END AS bus_range_code, g.rtcur AS qcy_code, 'FAGLFLEXT' AS ods_src, g.hslvt, g.hsl01, g.hsl02, g.hsl03, g.hsl04, g.hsl05, g.hsl06, g.hsl07, g.hsl08, g.hsl09, g.hsl10, g.hsl11, g.hsl12, g.tslvt, g.tsl01, g.tsl02, g.tsl03, g.tsl04, g.tsl05, g.tsl06, g.tsl07, g.tsl08, g.tsl09, g.tsl10, g.tsl11, g.tsl12
      FROM ods.ods_slt_s600_faglflext g
     -- 仅扫描参数财年，避免读取无关年度余额。
     WHERE ryear = @fiscal_year
),
-- 计算非统驭科目本位币/交易币的期初加累计发生额。
balance_detail AS (
    SELECT g.system_src
         , g.company_code
         , c.acct_type_code
         , g.acct_src_code
         , g.src_profitcenter_code
         , g.bus_range_code
         , g.qcy_code
         , g.ods_src
         , (
               IFNULL(g.hslvt, 0)
               + CASE WHEN @fiscal_month >= '01' THEN IFNULL(g.hsl01, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '02' THEN IFNULL(g.hsl02, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '03' THEN IFNULL(g.hsl03, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '04' THEN IFNULL(g.hsl04, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '05' THEN IFNULL(g.hsl05, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '06' THEN IFNULL(g.hsl06, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '07' THEN IFNULL(g.hsl07, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '08' THEN IFNULL(g.hsl08, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '09' THEN IFNULL(g.hsl09, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '10' THEN IFNULL(g.hsl10, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '11' THEN IFNULL(g.hsl11, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '12' THEN IFNULL(g.hsl12, 0) ELSE 0 END
           ) AS bcy_amt
         , (
               IFNULL(g.tslvt, 0)
               + CASE WHEN @fiscal_month >= '01' THEN IFNULL(g.tsl01, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '02' THEN IFNULL(g.tsl02, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '03' THEN IFNULL(g.tsl03, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '04' THEN IFNULL(g.tsl04, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '05' THEN IFNULL(g.tsl05, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '06' THEN IFNULL(g.tsl06, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '07' THEN IFNULL(g.tsl07, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '08' THEN IFNULL(g.tsl08, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '09' THEN IFNULL(g.tsl09, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '10' THEN IFNULL(g.tsl10, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '11' THEN IFNULL(g.tsl11, 0) ELSE 0 END
               + CASE WHEN @fiscal_month >= '12' THEN IFNULL(g.tsl12, 0) ELSE 0 END
           ) AS qcy_amt
      FROM src_gl_balance g
     INNER JOIN gl_account_cfg c
        ON c.system_src = g.system_src
       AND c.company_code = g.company_code
       AND c.acct_code = g.acct_src_code
),
-- 按余额粒度汇总，并保留至少一个币种非零的余额组合。
balance_agg AS (
    SELECT system_src
         , company_code
         , acct_type_code
         , acct_src_code
         , src_profitcenter_code
         , bus_range_code
         , qcy_code
         , ods_src
         , SUM(bcy_amt) AS bcy_amt
         , SUM(qcy_amt) AS qcy_amt
      FROM balance_detail
     GROUP BY system_src
            , company_code
            , acct_type_code
            , acct_src_code
            , src_profitcenter_code
            , bus_range_code
            , qcy_code
            , ods_src
     -- 仅剔除本位币和交易币同时为零的余额组合。
    HAVING SUM(bcy_amt) <> 0 OR SUM(qcy_amt) <> 0
)
SELECT *
  FROM (
SELECT @dt_month
     , LEFT(@dt_month, 4) AS `year`
     , RIGHT(@dt_month, 2) AS `month`
     , a.company_code
     , a.acct_cert_type
     , a.acct_cert_status
     , a.acct_cert_id
     , a.acct_cert_item
     , a.voucher_dt
     , a.posting_dt
     , a.baseline_dt
     , a.clearing_dt
     , CASE
           WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL
               THEN a.cust_branch_code
           ELSE a.cust_head_code
       END AS cust_code
     , CASE
           WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL AND a.object_source = 'CUSTOMER'
               THEN COALESCE(bc.name1, '')
           WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL AND a.object_source = 'VENDOR'
               THEN COALESCE(bv.name1, '')
           WHEN a.object_source = 'CUSTOMER'
               THEN COALESCE(c.name1, '')
           ELSE COALESCE(v.name1, '')
       END AS cust_name
     , a.cust_head_code
     , CASE
           WHEN a.object_source = 'CUSTOMER'
               THEN COALESCE(c.name1, '')
           ELSE COALESCE(v.name1, '')
       END AS cust_head_name
     , a.cust_branch_code
     , CASE
           WHEN a.object_source = 'CUSTOMER'
               THEN COALESCE(bc.name1, '')
           ELSE COALESCE(bv.name1, '')
       END AS cust_branch_name
     , ctp.cp_company_code
     , ci.country_code
     , ci.country_name
     , a.acct_type_code
     , a.acct_src_code
     , a.acct_map_code
     , ch.com_1st_code AS channel_l1_code
     , ch.com_1st_name AS channel_l1_name
     , ch.com_2nd_code AS channel_l2_code
     , ch.com_2nd_name AS channel_l2_name
     , ch.com_3rd_code AS channel_l3_code
     , ch.com_3rd_name AS channel_l3_name
     , NULL AS tov_channel_code
     , NULL AS tov_channel_name
     , NULL AS cc_cust_group_code
     , NULL AS cc_cust_group_name
     -- 客商和供应商均按应收规则、收入规则、传统零售默认值依次取值。
     , CASE
           WHEN nf.fact_key IS NOT NULL THEN nf.onoffline_code
           ELSE '020_OFF_002'
       END AS onoffline_code
     , CASE
           WHEN nf.fact_key IS NOT NULL THEN nf.onoffline_name
           ELSE '零售-传统零售'
       END AS onoffline_name
     , a.src_profitcenter_code
     , COALESCE(pc.ktext, '') AS src_profitcenter_name
     , pm.profitcenter_code
     , pm.profitcenter_name
     , bm.bus_range_code
     , bm.bus_range_name
     , bm.marketing_dept_code
     , bm.marketing_dept_name
     , bm.nature_l1_name
     , bm.nature_l2_name
     , bm.nature_l3_name
     , a.pay_method
     , a.pay_reason_code
     , COALESCE(co.waers, '') AS bcy_code
     , a.qcy_code
     , a.bcy_amt
     , a.qcy_amt
     , a.aging_days
     -- 账龄分段未匹配或配置值为空时，统一归入5年以上。
     , COALESCE(NULLIF(TRIM(seg.aging_seg_code), ''), '9') AS aging_seg_code
     , COALESCE(NULLIF(TRIM(seg.aging_seg_name), ''), '5年以上') AS aging_seg_name
     , a.pays_tran
     , a.note
     , a.system_src
     , a.ods_src
     , NOW() AS load_dt
  FROM normalized_items a
  LEFT JOIN nf_final nf
    ON nf.fact_key = MD5(
           CONCAT_WS(
               '|'
             , COALESCE(a.system_src, '')
             , COALESCE(a.ods_src, '')
             , COALESCE(a.company_code, '')
             , COALESCE(a.gjahr, '')
             , COALESCE(a.acct_cert_id, '')
             , COALESCE(a.acct_cert_item, '')
           )
       )
  LEFT JOIN ar_business_mapping bm
    ON bm.fact_key = MD5(
           CONCAT_WS(
               '|'
             , COALESCE(a.system_src, '')
             , COALESCE(a.ods_src, '')
             , COALESCE(a.company_code, '')
             , COALESCE(a.gjahr, '')
             , COALESCE(a.acct_cert_id, '')
             , COALESCE(a.acct_cert_item, '')
           )
       )
  LEFT JOIN aging_seg_cfg seg
    ON a.aging_days >= seg.aging_seg_fr
   AND a.aging_days <= seg.aging_seg_to
  LEFT JOIN customer_dim c
    ON a.object_source = 'CUSTOMER'
   AND c.system_src = a.system_src
   AND c.kunnr = a.cust_head_code
  LEFT JOIN vendor_dim v
    ON a.object_source = 'VENDOR'
   AND v.system_src = a.system_src
   AND v.lifnr = a.cust_head_code
  LEFT JOIN customer_dim bc
    ON a.object_source = 'CUSTOMER'
   AND bc.system_src = a.system_src
   AND bc.kunnr = a.cust_branch_code
  LEFT JOIN vendor_dim bv
    ON a.object_source = 'VENDOR'
   AND bv.system_src = a.system_src
   AND bv.lifnr = a.cust_branch_code
  LEFT JOIN customer_class_dim ch
    ON ch.cust_code = CASE
                           WHEN a.object_source = 'CUSTOMER' THEN c.zkunnr_mdg
                           ELSE v.zlifnr_mdg
                       END
  LEFT JOIN customer_class_dim ci
    ON ci.cust_code = CASE WHEN a.object_source = 'CUSTOMER' THEN c.zkunnr_mdg ELSE v.zlifnr_mdg END
  LEFT JOIN cp_company_dim ctp
    ON ctp.cust_code = a.cust_head_code
   AND ctp.system_src = a.system_src
   AND ctp.cust_type_code = CASE WHEN a.object_source = 'CUSTOMER' THEN 'C' ELSE 'V' END
  -- 仅电商零售类客户进入新旧利润中心映射。
  LEFT JOIN ecom_retail_cust er
    ON a.object_source = 'CUSTOMER'
   AND er.cust_code = CASE
                          WHEN NULLIF(TRIM(a.cust_branch_code), '') IS NOT NULL
                              THEN a.cust_branch_code
                          ELSE a.cust_head_code
                      END
  LEFT JOIN ar_profit_mapping pm
    ON er.cust_code IS NOT NULL
   AND pm.src_profitcenter_code = a.src_profitcenter_code
  LEFT JOIN company_dim co
    ON co.system_src = a.system_src
   AND co.bukrs = a.company_code
  LEFT JOIN profitcenter_dim pc
    ON pc.system_src = a.system_src
   AND pc.prctr = a.src_profitcenter_code

-- ==========================================================================
-- 第二段：非统驭科目月末累计余额。
-- 余额粒度不包含客户、客户分类或对方公司，仅对非公司10架构公司应用业务范围batch 3。
-- ==========================================================================
UNION ALL
SELECT @dt_month
     , LEFT(@dt_month, 4) AS `year`
     , RIGHT(@dt_month, 2) AS `month`
     , a.company_code
     , NULL AS acct_cert_type
     , NULL AS acct_cert_status
     , NULL AS acct_cert_id
     , NULL AS acct_cert_item
     , NULL AS voucher_dt
     , NULL AS posting_dt
     , @key_date AS baseline_dt
     , NULL AS clearing_dt
     , NULL AS cust_code
     , NULL AS cust_name
     , NULL AS cust_head_code
     , NULL AS cust_head_name
     , NULL AS cust_branch_code
     , NULL AS cust_branch_name
     , NULL AS cp_company_code
     , NULL AS country_code
     , NULL AS country_name
     , a.acct_type_code
     , a.acct_src_code
     , CASE WHEN a.system_src = 'S600' THEN a.acct_src_code ELSE am.acct_map_code END AS acct_map_code
     , NULL AS channel_l1_code
     , NULL AS channel_l1_name
     , NULL AS channel_l2_code
     , NULL AS channel_l2_name
     , NULL AS channel_l3_code
     , NULL AS channel_l3_name
     , NULL AS tov_channel_code
     , NULL AS tov_channel_name
     , NULL AS cc_cust_group_code
     , NULL AS cc_cust_group_name
     , NULL AS onoffline_code
     , NULL AS onoffline_name
     , a.src_profitcenter_code
     , COALESCE(pc.ktext, '') AS src_profitcenter_name
     , NULL AS profitcenter_code
     , NULL AS profitcenter_name
     , br.bus_range_code
     , br.bus_range_name
     , NULL AS marketing_dept_code
     , NULL AS marketing_dept_name
     , NULL AS nature_l1_name
     , NULL AS nature_l2_name
     , NULL AS nature_l3_name
     , NULL AS pay_method
     , NULL AS pay_reason_code
     , co.waers AS bcy_code
     , a.qcy_code
     , CAST(a.bcy_amt AS DECIMALV3(27, 9)) AS bcy_amt
     , CAST(a.qcy_amt AS DECIMALV3(27, 9)) AS qcy_amt
     , CAST(1 AS DECIMALV3(27, 9)) AS aging_days
     -- 账龄分段未匹配或配置值为空时，统一归入5年以上。
     , COALESCE(NULLIF(TRIM(seg.aging_seg_code), ''), '9') AS aging_seg_code
     , COALESCE(NULLIF(TRIM(seg.aging_seg_name), ''), '5年以上') AS aging_seg_name
     , NULL AS pays_tran
     , NULL AS note
     , a.system_src
     , a.ods_src
     , NOW() AS load_dt
  FROM balance_agg a
  -- 识别公司10架构中的商显公司和日立公司。
  LEFT JOIN (
        SELECT TRIM(elem) AS company_code
             , MAX(
                   CASE
                       WHEN TRIM(node) = '01020'
                           THEN '商显公司'
                       ELSE '日立公司'
                   END
               ) AS company_scope
          FROM ods.odsfima_v_ref_azienda
         WHERE TRIM(hie) = '10'
           AND TRIM(node) IN ('01020', '050')
         GROUP BY TRIM(elem)
  ) cs
    ON cs.company_code = a.company_code
  -- 非公司10架构按公司级业务范围规则匹配。
  LEFT JOIN (
        SELECT company_code
             , MAX(bus_range_code) AS bus_range_code
             , MAX(bus_range_name) AS bus_range_name
          FROM dim.dim_rule_fi_mr_ar_busrange_mapping
         WHERE CAST(batch_id AS INT) = 3
           AND NVL(valid_fr, '202401') <= @dt_month
           AND NVL(valid_to, '999999') >= @dt_month
         GROUP BY company_code
  ) br
    ON cs.company_scope IS NULL
   AND br.company_code = a.company_code
  LEFT JOIN aging_seg_cfg seg
    ON 1 >= seg.aging_seg_fr
   AND 1 <= seg.aging_seg_to
  LEFT JOIN acct_mapping am
    ON am.racct_src_code = a.acct_src_code
   AND am.system_src = a.system_src
  LEFT JOIN company_dim co
    ON co.system_src = a.system_src
   AND co.bukrs = a.company_code
  LEFT JOIN profitcenter_dim pc
    ON pc.system_src = a.system_src
   AND pc.prctr = a.src_profitcenter_code
) a
WHERE NULLIF(@company_code, '') IS NULL
   OR a.company_code = @company_code
;

-- ============================================================================
-- 本脚本只处理S600，先DELETE同月S600记录，再INSERT INTO，保留其他系统数据。
-- ============================================================================
