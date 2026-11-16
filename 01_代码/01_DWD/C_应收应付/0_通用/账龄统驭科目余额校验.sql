/*******************************************************************************
 *                                  脚本说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261116 14:19
 * 本次修改：ALTER BY 20261116 14:19 SHIQINGFENG.EX 账龄行项目按来源系统集中排列。
 * 上次修改：ALTER BY 20261116 14:08 SHIQINGFENG.EX 账龄侧改为直接读取ODS行项目核对。
 *
 * 脚本名称  ：账龄统驭科目余额校验.sql
 * 功能描述  ：按来源系统、公司、原始科目核对ODS统驭科目未清本位币与ODS总账余额差异，不含提前回款。
 * 源表      ：六套SAP BSID、BSAD、BSIK、BSAK、科目余额表及统驭科目配置。
 * 目标表    ：无（校验查询，不落表）。
 *
 * 修改历史：
 *   ALTER BY 20261116 14:19 SHIQINGFENG.EX 账龄行项目按来源系统集中排列。
 *   ALTER BY 20261116 14:08 SHIQINGFENG.EX 账龄侧改为直接读取ODS行项目核对。
 *   ALTER BY 20261116 11:34 SHIQINGFENG.EX S700公司改为直接使用原始公司代码。
 *   ALTER BY 20261116 11:28 SHIQINGFENG.EX 新增统驭科目账龄与科目余额核对。
 ******************************************************************************/
-- 统计年月，格式 YYYYMM。以下语句必须在同一session中按顺序执行。
SET @dt_month = '202608';
-- 参数月1日，格式 YYYYMMDD。
SET @year_month_day = CONCAT(@dt_month, '01');
-- 参数月月末日期。
SET @key_date = LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d'));
-- 参数月月末，格式 YYYYMMDD。未清行项目和科目余额都截止到该日。
SET @key_date_sap = DATE_FORMAT(@key_date, '%Y%m%d');
-- 财年、财月。
SET @fiscal_year = LEFT(@dt_month, 4);
SET @fiscal_month = RIGHT(@dt_month, 2);

WITH
-- 六套SAP应收应付科目范围。
src_ztzt_003 AS (
    SELECT 'S600' AS system_src, ktopl, hkonf, hkont
      FROM ods.odss600_ztzt_003
    UNION ALL
    SELECT 'S700' AS system_src, ktopl, hkonf, hkont
      FROM ods.odss700_ztzt_003
    UNION ALL
    SELECT 'S800' AS system_src, ktopl, hkonf, hkont
      FROM ods.odss800_ztzt_003
    UNION ALL
    SELECT 'S900' AS system_src, ktopl, hkonf, hkont
      FROM ods.odss900_ztzt_003
    UNION ALL
    SELECT 'S610' AS system_src, ktopl, hkonf, hkont
      FROM ods.odss610_ztzt_003
    UNION ALL
    SELECT 'S810' AS system_src, ktopl, hkonf, hkont
      FROM ods.odss810_ztzt_003
),
-- 公司代码、科目表和本位币。S700保留原始公司代码。
src_t001 AS (
    SELECT 'S600' AS system_src, bukrs, ktopl, waers
      FROM ods.odss600_t001
    UNION ALL
    SELECT 'S700' AS system_src, bukrs, ktopl, waers
      FROM ods.odss700_t001
    UNION ALL
    SELECT 'S800' AS system_src, bukrs, ktopl, waers
      FROM ods.odss800_t001
    UNION ALL
    SELECT 'S900' AS system_src, bukrs, ktopl, waers
      FROM ods.odss900_t001
    UNION ALL
    SELECT 'S610' AS system_src, bukrs, ktopl, waers
      FROM ods.odss610_t001
    UNION ALL
    SELECT 'S810' AS system_src, bukrs, ktopl, waers
      FROM ods.odss810_t001
),
-- 公司科目及统驭标识。S700保留原始公司代码。
src_skb1 AS (
    SELECT 'S600' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss600_skb1
    UNION ALL
    SELECT 'S700' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss700_skb1
    UNION ALL
    SELECT 'S800' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss800_skb1
    UNION ALL
    SELECT 'S900' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss900_skb1
    UNION ALL
    SELECT 'S610' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss610_skb1
    UNION ALL
    SELECT 'S810' AS system_src, bukrs, saknr, mitkz
      FROM ods.odss810_skb1
),
-- 公司本位币，供S610金额换算。
company_dim AS (
    SELECT system_src
         , TRIM(bukrs) AS bukrs
         , MAX(waers) AS waers
      FROM src_t001
     GROUP BY system_src
            , TRIM(bukrs)
),
-- S610按币种小数位计算转换因子，缺失时按1处理。
s610_tcurx_factor AS (
    SELECT UPPER(TRIM(tx.currkey)) AS currkey
         , CASE
               WHEN MAX(CASE
                            WHEN tx.currdec IS NOT NULL
                             AND tx.currdec >= 0
                             AND tx.currdec <= 9
                                THEN CAST(tx.currdec AS INT)
                        END) IS NULL
                   THEN 1
               ELSE POW(
                        10
                      , 2 - MAX(CASE
                                    WHEN tx.currdec IS NOT NULL
                                     AND tx.currdec >= 0
                                     AND tx.currdec <= 9
                                        THEN CAST(tx.currdec AS INT)
                                END)
                    )
           END AS conversion_factor
      FROM ods.odss810_tcurx tx
     GROUP BY UPPER(TRIM(tx.currkey))
),
-- 统驭科目：科目范围命中且SKB1统驭标识为D或K。一个科目只保留一个统驭标识，避免余额重复。
recon_acct AS (
    SELECT system_src
         , company_code
         , acct_code
         , MAX(acct_type_code) AS acct_type_code
      FROM (
            SELECT DISTINCT t.system_src AS system_src
                 , TRIM(t.bukrs) AS company_code
                 , TRIM(s.saknr) AS acct_code
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
           ) c
     GROUP BY system_src
            , company_code
            , acct_code
),
-- ODS未清与月末后清账的行项目。同一来源系统的四张表放在一起，提前回款不取BSAD_EPAY。
aging_item AS (
    SELECT 'S600' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s600_bsid
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S600' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s600_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S600' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s600_bsik
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S600' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s600_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S700' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s700_bsid
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S700' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s700_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S700' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s700_bsik
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S700' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s700_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S800' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s800_bsid
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S800' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s800_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S800' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odss800_bsik
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S800' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s800_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S900' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s900_bsid
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S900' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s900_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S900' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odss900_bsik
     WHERE budat <= @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S900' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s900_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S610' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s810_bsid
     WHERE budat <= @key_date_sap
       AND mandt = '610'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S610' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s810_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND mandt = '610'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S610' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s810_bsik
     WHERE budat <= @key_date_sap
       AND mandt = '610'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S610' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s810_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND mandt = '610'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S810' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s810_bsid
     WHERE budat <= @key_date_sap
       AND mandt = '810'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S810' AS system_src, 'D' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s810_bsad
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND mandt = '810'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S810' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s810_bsik
     WHERE budat <= @key_date_sap
       AND mandt = '810'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
    UNION ALL
    SELECT 'S810' AS system_src, 'K' AS acct_type_code, bukrs AS company_code, hkont AS acct_src_code, shkzg, dmbtr
      FROM ods.odsslt_s810_bsak
     WHERE budat <= @key_date_sap
       AND augdt > @key_date_sap
       AND mandt = '810'
       AND COALESCE(bstat, '') NOT IN ('A', 'S')
       AND (COALESCE(dmbtr, 0) <> 0 OR COALESCE(wrbtr, 0) <> 0)
),
-- 只保留统驭科目，贷方金额取负，并按系统、公司、科目汇总。
aging_acct AS (
    SELECT a.system_src AS system_src
         , TRIM(a.company_code) AS company_code
         , TRIM(a.acct_src_code) AS acct_src_code
         , ROUND(SUM(
               CASE
                   WHEN a.shkzg = 'H' THEN -a.dmbtr
                   ELSE a.dmbtr
               END
               * CASE
                     WHEN a.system_src = 'S610' THEN COALESCE(cf.conversion_factor, 1)
                     ELSE 1
                 END
           ), 2) AS aging_bcy_amt
         , COUNT(*) AS aging_row_cnt
      FROM aging_item a
     INNER JOIN recon_acct c
        ON c.system_src = a.system_src
       AND c.company_code = TRIM(a.company_code)
       AND c.acct_code = TRIM(a.acct_src_code)
       AND c.acct_type_code = a.acct_type_code
      LEFT JOIN company_dim co
        ON co.system_src = a.system_src
       AND co.bukrs = TRIM(a.company_code)
      LEFT JOIN s610_tcurx_factor cf
        ON a.system_src = 'S610'
       AND cf.currkey = UPPER(TRIM(co.waers))
     GROUP BY a.system_src
            , TRIM(a.company_code)
            , TRIM(a.acct_src_code)
),
-- ODS科目余额按参数财年读取。S700保留原始公司代码。
src_gl_balance AS (
    SELECT CONCAT('S', g.rclnt) AS system_src
         , g.rbukrs AS company_code
         , g.racct AS acct_src_code
         , g.hslvt AS hslvt
         , g.hsl01 AS hsl01
         , g.hsl02 AS hsl02
         , g.hsl03 AS hsl03
         , g.hsl04 AS hsl04
         , g.hsl05 AS hsl05
         , g.hsl06 AS hsl06
         , g.hsl07 AS hsl07
         , g.hsl08 AS hsl08
         , g.hsl09 AS hsl09
         , g.hsl10 AS hsl10
         , g.hsl11 AS hsl11
         , g.hsl12 AS hsl12
      FROM ods.ods_slt_s600_faglflext g
     WHERE g.ryear = @fiscal_year
    UNION ALL
    SELECT CONCAT('S', g.rclnt) AS system_src
         , g.rbukrs AS company_code
         , g.racct AS acct_src_code
         , g.hslvt AS hslvt
         , g.hsl01 AS hsl01
         , g.hsl02 AS hsl02
         , g.hsl03 AS hsl03
         , g.hsl04 AS hsl04
         , g.hsl05 AS hsl05
         , g.hsl06 AS hsl06
         , g.hsl07 AS hsl07
         , g.hsl08 AS hsl08
         , g.hsl09 AS hsl09
         , g.hsl10 AS hsl10
         , g.hsl11 AS hsl11
         , g.hsl12 AS hsl12
      FROM ods.ods_slt_s700_faglflext g
     WHERE g.ryear = @fiscal_year
    UNION ALL
    SELECT CONCAT('S', g.rclnt) AS system_src
         , g.rbukrs AS company_code
         , g.racct AS acct_src_code
         , g.hslvt AS hslvt
         , g.hsl01 AS hsl01
         , g.hsl02 AS hsl02
         , g.hsl03 AS hsl03
         , g.hsl04 AS hsl04
         , g.hsl05 AS hsl05
         , g.hsl06 AS hsl06
         , g.hsl07 AS hsl07
         , g.hsl08 AS hsl08
         , g.hsl09 AS hsl09
         , g.hsl10 AS hsl10
         , g.hsl11 AS hsl11
         , g.hsl12 AS hsl12
      FROM ods.ods_slt_s800_glfunct g
     WHERE g.ryear = @fiscal_year
    UNION ALL
    SELECT CONCAT('S', g.rclnt) AS system_src
         , g.rbukrs AS company_code
         , g.racct AS acct_src_code
         , g.hslvt AS hslvt
         , g.hsl01 AS hsl01
         , g.hsl02 AS hsl02
         , g.hsl03 AS hsl03
         , g.hsl04 AS hsl04
         , g.hsl05 AS hsl05
         , g.hsl06 AS hsl06
         , g.hsl07 AS hsl07
         , g.hsl08 AS hsl08
         , g.hsl09 AS hsl09
         , g.hsl10 AS hsl10
         , g.hsl11 AS hsl11
         , g.hsl12 AS hsl12
      FROM ods.ods_slt_s900_glfunct g
     WHERE g.ryear = @fiscal_year
    UNION ALL
    SELECT CONCAT('S', g.rclnt) AS system_src
         , g.rbukrs AS company_code
         , g.racct AS acct_src_code
         , g.hslvt AS hslvt
         , g.hsl01 AS hsl01
         , g.hsl02 AS hsl02
         , g.hsl03 AS hsl03
         , g.hsl04 AS hsl04
         , g.hsl05 AS hsl05
         , g.hsl06 AS hsl06
         , g.hsl07 AS hsl07
         , g.hsl08 AS hsl08
         , g.hsl09 AS hsl09
         , g.hsl10 AS hsl10
         , g.hsl11 AS hsl11
         , g.hsl12 AS hsl12
      FROM ods.ods_slt_s810_faglflext g
     WHERE g.ryear = @fiscal_year
       AND g.rclnt = '810'
    UNION ALL
    SELECT CONCAT('S', g.rclnt) AS system_src
         , g.rbukrs AS company_code
         , g.racct AS acct_src_code
         , g.hslvt AS hslvt
         , g.hsl01 AS hsl01
         , g.hsl02 AS hsl02
         , g.hsl03 AS hsl03
         , g.hsl04 AS hsl04
         , g.hsl05 AS hsl05
         , g.hsl06 AS hsl06
         , g.hsl07 AS hsl07
         , g.hsl08 AS hsl08
         , g.hsl09 AS hsl09
         , g.hsl10 AS hsl10
         , g.hsl11 AS hsl11
         , g.hsl12 AS hsl12
      FROM ods.ods_slt_s810_faglflext g
     WHERE g.ryear = @fiscal_year
       AND g.rclnt = '610'
),
-- 统驭科目余额取期初加累计至参数月的本位币发生额。
balance_acct AS (
    SELECT g.system_src AS system_src
         , TRIM(g.company_code) AS company_code
         , TRIM(g.acct_src_code) AS acct_src_code
         , ROUND(SUM(
               (ROUND(IFNULL(g.hslvt, 0), 2)
              + CASE WHEN @fiscal_month >= '01' THEN ROUND(IFNULL(g.hsl01, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '02' THEN ROUND(IFNULL(g.hsl02, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '03' THEN ROUND(IFNULL(g.hsl03, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '04' THEN ROUND(IFNULL(g.hsl04, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '05' THEN ROUND(IFNULL(g.hsl05, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '06' THEN ROUND(IFNULL(g.hsl06, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '07' THEN ROUND(IFNULL(g.hsl07, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '08' THEN ROUND(IFNULL(g.hsl08, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '09' THEN ROUND(IFNULL(g.hsl09, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '10' THEN ROUND(IFNULL(g.hsl10, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '11' THEN ROUND(IFNULL(g.hsl11, 0), 2) ELSE 0 END
              + CASE WHEN @fiscal_month >= '12' THEN ROUND(IFNULL(g.hsl12, 0), 2) ELSE 0 END)
              * CASE
                    WHEN g.system_src = 'S610' THEN COALESCE(cf.conversion_factor, 1)
                    ELSE 1
                END
           ), 2) AS balance_bcy_amt
      FROM src_gl_balance g
     INNER JOIN recon_acct c
        ON c.system_src = g.system_src
       AND c.company_code = TRIM(g.company_code)
       AND c.acct_code = TRIM(g.acct_src_code)
      LEFT JOIN company_dim co
        ON co.system_src = g.system_src
       AND co.bukrs = TRIM(g.company_code)
      LEFT JOIN s610_tcurx_factor cf
        ON g.system_src = 'S610'
       AND cf.currkey = UPPER(TRIM(co.waers))
     GROUP BY g.system_src
            , TRIM(g.company_code)
            , TRIM(g.acct_src_code)
)
SELECT COALESCE(a.system_src, b.system_src) AS system_src
     , COALESCE(a.company_code, b.company_code) AS company_code
     , c.acct_type_code AS acct_type_code
     , COALESCE(a.acct_src_code, b.acct_src_code) AS acct_src_code
     , ROUND(COALESCE(a.aging_bcy_amt, 0), 2) AS aging_bcy_amt
     , ROUND(COALESCE(b.balance_bcy_amt, 0), 2) AS balance_bcy_amt
     , ROUND(COALESCE(a.aging_bcy_amt, 0) - COALESCE(b.balance_bcy_amt, 0), 2) AS diff_bcy_amt
     , COALESCE(a.aging_row_cnt, 0) AS aging_row_cnt
     , CASE
           WHEN a.acct_src_code IS NULL THEN '仅科目余额'
           WHEN b.acct_src_code IS NULL THEN '仅账龄'
           ELSE '金额不一致'
       END AS diff_type
  FROM aging_acct a
  FULL OUTER JOIN balance_acct b
    ON b.system_src = a.system_src
   AND b.company_code = a.company_code
   AND b.acct_src_code = a.acct_src_code
  LEFT JOIN recon_acct c
    ON c.system_src = COALESCE(a.system_src, b.system_src)
   AND c.company_code = COALESCE(a.company_code, b.company_code)
   AND c.acct_code = COALESCE(a.acct_src_code, b.acct_src_code)
 WHERE ABS(COALESCE(a.aging_bcy_amt, 0) - COALESCE(b.balance_bcy_amt, 0)) > 0.005
 ORDER BY system_src
        , company_code
        , acct_src_code;
