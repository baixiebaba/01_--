/*******************************************************************************
 *                                  脚本说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261125 22:30
 * 本次修改：ALTER BY 20261125 22:30 SHIQINGFENG.EX 重构为未清（ID/IK）与已清（BSEG_D/BSEG_K）交叉重复校验。
 * 上次修改：ALTER BY 20261116 11:15 新增
 *
 * 脚本名称  ：账龄重复凭证校验.sql
 * 功能描述  ：按统计年月的期末日检查未清（BSID/BSIK）与已清（BSEG_D/BSEG_K）之间是否存在重复会计凭证行。
 *            背景：明细脚本已将客户/供应商已清项目从 BSAD/BSAK 切换到 BSEG，
 *            但由于清账更新延迟，可能出现同一凭证行既在未清表又在已清表的情况，导致重复装载。
 * 源表      ：ods.odsslt_*_bsid、ods.odsslt_*_bsik、ods.odssap_zs*_bseg_v、ods.odssap_zs*_bkpf_v。
 * 目标表    ：无（校验查询，不落表）。
 *
 * 修改历史：
 *   ALTER BY 20261125 22:30 SHIQINGFENG.EX 重构为未清（ID/IK）与已清（BSEG_D/BSEG_K）交叉重复校验。
 *   ALTER BY 20261116 11:15 新增
 ******************************************************************************/
-- 统计年月，格式 YYYYMM
SET @dt_month = '202608';
-- 根据统计年月计算当月最后一天，格式 YYYYMMDD
SET @key_date = DATE_FORMAT(LAST_DAY(STR_TO_DATE(CONCAT(@dt_month, '01'), '%Y%m%d')), '%Y%m%d');

-- ============================================================================
-- 第一部分：客户未清（BSID）与客户已清（BSEG_D）交叉重复校验
-- 同一凭证行在 BSID（未清）和 BSEG_D（已清）中同时存在，说明清账更新延迟导致重复。
-- ============================================================================
SELECT 'BSID vs BSEG_D'                    AS CHECK_TYPE
     , SYSTEM_SRC                          AS SYSTEM_SRC
     , BUKRS                               AS BUKRS
     , GJAHR                               AS GJAHR
     , BELNR                               AS BELNR
     , BUZEI                               AS BUZEI
     , COUNT(*)                            AS ROW_CNT
     , MAX(OBJECT_SOURCE)                  AS OBJECT_SOURCE
     , MAX(OBJECT_CODE)                    AS OBJECT_CODE
     , MAX(HKONT)                          AS HKONT
     , MAX(SHKZG)                          AS SHKZG
     , ROUND(MAX(DMBTR), 2)                AS DMBTR_ABS
     , ROUND(MAX(CASE WHEN SHKZG = 'H' THEN -DMBTR ELSE DMBTR END), 2) AS AMT_SIGNED
     , MIN(BUDAT)                          AS MIN_BUDAT
     , MIN(AUGDT)                          AS MIN_AUGDT
     , MAX(AUGDT)                          AS MAX_AUGDT
     , GROUP_CONCAT(DISTINCT ODS_SRC)      AS ODS_SRC_LIST
     , GROUP_CONCAT(DISTINCT AUGDT)        AS AUGDT_LIST
     , CASE WHEN MAX(DMBTR) - MIN(DMBTR) > 0.005 THEN 'D_金额不一致'
            ELSE 'C_完全重复装载'
       END                                 AS DUP_TYPE
  FROM (
        /* ---------- BSID：客户未清 ---------- */
        SELECT 'BSID' AS ODS_SRC
             , 'S600' AS SYSTEM_SRC, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, KUNNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odsslt_s600_bsid
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSID' AS ODS_SRC
             , 'S700' AS SYSTEM_SRC, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, KUNNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odsslt_s700_bsid
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSID' AS ODS_SRC
             , 'S800' AS SYSTEM_SRC, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, KUNNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odsslt_s800_bsid
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSID' AS ODS_SRC
             , 'S900' AS SYSTEM_SRC, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, KUNNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odsslt_s900_bsid
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSID' AS ODS_SRC
             , CASE WHEN MANDT = '610' THEN 'S610' ELSE 'S810' END AS SYSTEM_SRC
             , BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, KUNNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odsslt_s810_bsid
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        /* ---------- BSEG_D：客户已清（从BSEG取，koart='D'）---------- */
        SELECT 'BSEG_D' AS ODS_SRC
             , 'S600' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, S.KUNNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs600_bkpf_v H
          JOIN ods.odssap_zs600_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'D'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_D' AS ODS_SRC
             , 'S700' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, S.KUNNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs700_bkpf_v H
          JOIN ods.odssap_zs700_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'D'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_D' AS ODS_SRC
             , 'S800' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, S.KUNNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs800_bkpf_v H
          JOIN ods.odssap_zs800_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'D'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_D' AS ODS_SRC
             , 'S900' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, S.KUNNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs900_bkpf_v H
          JOIN ods.odssap_zs900_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'D'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_D' AS ODS_SRC
             , 'S610' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, S.KUNNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs610_bkpf_v H
          JOIN ods.odssap_zs610_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'D'
           AND S.MANDT = '610'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_D' AS ODS_SRC
             , 'S810' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, S.KUNNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs810_bkpf_v H
          JOIN ods.odssap_zs810_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'D'
           AND S.MANDT = '810'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)
       ) U
 GROUP BY SYSTEM_SRC, BUKRS, GJAHR, BELNR, BUZEI
HAVING COUNT(*) > 1
   AND COUNT(DISTINCT ODS_SRC) > 1  -- 必须跨两个来源（BSID + BSEG_D）才算重复
 ORDER BY SYSTEM_SRC, BUKRS, GJAHR, BELNR, BUZEI

 UNION ALL

-- ============================================================================
-- 第二部分：供应商未清（BSIK）与供应商已清（BSEG_K）交叉重复校验
-- 同一凭证行在 BSIK（未清）和 BSEG_K（已清）中同时存在，说明清账更新延迟导致重复。
-- ============================================================================
SELECT 'BSIK vs BSEG_K'                    AS CHECK_TYPE
     , SYSTEM_SRC                          AS SYSTEM_SRC
     , BUKRS                               AS BUKRS
     , GJAHR                               AS GJAHR
     , BELNR                               AS BELNR
     , BUZEI                               AS BUZEI
     , COUNT(*)                            AS ROW_CNT
     , MAX(OBJECT_SOURCE)                  AS OBJECT_SOURCE
     , MAX(OBJECT_CODE)                    AS OBJECT_CODE
     , MAX(HKONT)                          AS HKONT
     , MAX(SHKZG)                          AS SHKZG
     , ROUND(MAX(DMBTR), 2)                AS DMBTR_ABS
     , ROUND(MAX(CASE WHEN SHKZG = 'H' THEN -DMBTR ELSE DMBTR END), 2) AS AMT_SIGNED
     , MIN(BUDAT)                          AS MIN_BUDAT
     , MIN(AUGDT)                          AS MIN_AUGDT
     , MAX(AUGDT)                          AS MAX_AUGDT
     , GROUP_CONCAT(DISTINCT ODS_SRC)      AS ODS_SRC_LIST
     , GROUP_CONCAT(DISTINCT AUGDT)        AS AUGDT_LIST
     , CASE WHEN MAX(DMBTR) - MIN(DMBTR) > 0.005 THEN 'D_金额不一致'
            ELSE 'C_完全重复装载'
       END                                 AS DUP_TYPE
  FROM (
        /* ---------- BSIK：供应商未清 ---------- */
        SELECT 'BSIK' AS ODS_SRC
             , 'S600' AS SYSTEM_SRC, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, LIFNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odsslt_s600_bsik
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSIK' AS ODS_SRC
             , 'S700' AS SYSTEM_SRC, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, LIFNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odsslt_s700_bsik
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSIK' AS ODS_SRC
             , 'S800' AS SYSTEM_SRC, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, LIFNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odss800_bsik
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSIK' AS ODS_SRC
             , 'S900' AS SYSTEM_SRC, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, LIFNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odss900_bsik
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSIK' AS ODS_SRC
             , CASE WHEN MANDT = '610' THEN 'S610' ELSE 'S810' END AS SYSTEM_SRC
             , BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, LIFNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG
             , DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT
          FROM ods.odsslt_s810_bsik
         WHERE BUDAT <= @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        /* ---------- BSEG_K：供应商已清（从BSEG取，koart='K'）---------- */
        SELECT 'BSEG_K' AS ODS_SRC
             , 'S600' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, S.LIFNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs600_bkpf_v H
          JOIN ods.odssap_zs600_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'K'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_K' AS ODS_SRC
             , 'S700' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, S.LIFNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs700_bkpf_v H
          JOIN ods.odssap_zs700_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'K'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_K' AS ODS_SRC
             , 'S800' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, S.LIFNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs800_bkpf_v H
          JOIN ods.odssap_zs800_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'K'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_K' AS ODS_SRC
             , 'S900' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, S.LIFNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs900_bkpf_v H
          JOIN ods.odssap_zs900_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'K'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_K' AS ODS_SRC
             , 'S610' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, S.LIFNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs610_bkpf_v H
          JOIN ods.odssap_zs610_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'K'
           AND S.MANDT = '610'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSEG_K' AS ODS_SRC
             , 'S810' AS SYSTEM_SRC, S.BUKRS AS BUKRS, S.GJAHR AS GJAHR, S.BELNR AS BELNR, S.BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, S.LIFNR AS OBJECT_CODE, S.HKONT AS HKONT, S.SHKZG AS SHKZG
             , S.DMBTR AS DMBTR, H.BUDAT AS BUDAT, S.AUGDT AS AUGDT
          FROM ods.odssap_zs810_bkpf_v H
          JOIN ods.odssap_zs810_bseg_v S
            ON H.BUKRS = S.BUKRS
           AND H.BELNR = S.BELNR
           AND H.GJAHR = S.GJAHR
         WHERE S.AUGDT > @key_date
           AND H.BUDAT <= @key_date
           AND S.KOART = 'K'
           AND S.MANDT = '810'
           AND COALESCE(H.BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(S.DMBTR, 0) <> 0 OR COALESCE(S.WRBTR, 0) <> 0)
       ) U
 GROUP BY SYSTEM_SRC, BUKRS, GJAHR, BELNR, BUZEI
HAVING COUNT(*) > 1
   AND COUNT(DISTINCT ODS_SRC) > 1  -- 必须跨两个来源（BSIK + BSEG_K）才算重复
 ORDER BY SYSTEM_SRC, BUKRS, GJAHR, BELNR, BUZEI
;
