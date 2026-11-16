/*******************************************************************************
 *                                  脚本说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261116 11:15
 * 本次修改：20261116 11:15 新增
 * 上次修改：
 *
 * 脚本名称  ：账龄重复凭证校验.sql
 * 功能描述  ：按统计年月的期末日检查已清应收、应付账龄来源表是否存在重复会计凭证行。
 * 源表      ：ods.odsslt_*_bsad、ods.odsslt_*_bsak。
 * 目标表    ：无（校验查询，不落表）。
 *
 * 修改历史：
 *   ALTER BY 20261116 11:15 新增
 ******************************************************************************/
-- 统计年月，格式 YYYYMM
SET @dt_month = '202608';
-- 根据统计年月计算当月最后一天，格式 YYYYMMDD
SET @key_date = DATE_FORMAT(LAST_DAY(STR_TO_DATE(CONCAT(@dt_month, '01'), '%Y%m%d')), '%Y%m%d');

SELECT ODS_SRC AS ODS_SRC
     , SYSTEM_SRC AS SYSTEM_SRC
     , MANDT AS MANDT
     , BUKRS AS BUKRS
     , GJAHR AS GJAHR
     , BELNR AS BELNR
     , BUZEI AS BUZEI
     , COUNT(*)                                                       AS ROW_CNT
     , MAX(OBJECT_SOURCE)                                             AS OBJECT_SOURCE
     , MAX(OBJECT_CODE)                                               AS OBJECT_CODE
     , MAX(HKONT)                                                     AS HKONT
     , MAX(SHKZG)                                                     AS SHKZG
     , ROUND(MAX(DMBTR), 2)                                           AS DMBTR_ABS
     , ROUND(MAX(CASE WHEN SHKZG = 'H' THEN -DMBTR ELSE DMBTR END), 2) AS AMT_SIGNED
     , ROUND(SUM(CASE WHEN SHKZG = 'H' THEN -DMBTR ELSE DMBTR END), 2) AS AMT_SUM_NOW
     , MIN(BUDAT)                                                     AS MIN_BUDAT
     , MIN(AUGDT)                                                     AS MIN_AUGDT
     , MAX(AUGDT)                                                     AS MAX_AUGDT
     , GROUP_CONCAT(AUGDT)                                            AS AUGDT_LIST
     , GROUP_CONCAT(AUGBL)                                            AS AUGBL_LIST
     , ROUND(MAX(DMBTR) - MIN(DMBTR), 2)                               AS AMT_DIFF
     , CASE WHEN MAX(DMBTR) - MIN(DMBTR) > 0.005                THEN 'D_金额不一致'
            WHEN COUNT(DISTINCT AUGDT) > 1                      THEN 'A_同额多清账日'
            WHEN COUNT(DISTINCT COALESCE(AUGBL, ' ')) > 1        THEN 'B_同清账日多凭证'
            ELSE                                                     'C_完全重复装载'
       END                                                            AS DUP_TYPE
  FROM (
        /* ---------- BSAD ---------- */
        SELECT 'BSAD' AS ODS_SRC
             , 'S600' AS SYSTEM_SRC, MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE
             , KUNNR AS OBJECT_CODE
             , HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s600_bsad
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSAD' AS ODS_SRC
             , 'S700' AS SYSTEM_SRC, MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, KUNNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s700_bsad
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSAD' AS ODS_SRC
             , 'S800' AS SYSTEM_SRC, MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, KUNNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s800_bsad
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSAD' AS ODS_SRC
             , 'S900' AS SYSTEM_SRC, MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, KUNNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s900_bsad
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSAD' AS ODS_SRC
             , CASE WHEN MANDT = '610' THEN 'S610' ELSE 'S810' END AS SYSTEM_SRC
             , MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'CUSTOMER' AS OBJECT_SOURCE, KUNNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s810_bsad
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        /* ---------- BSAK ---------- */
        SELECT 'BSAK' AS ODS_SRC
             , 'S600' AS SYSTEM_SRC, MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE
             , LIFNR AS OBJECT_CODE
             , HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s600_bsak
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSAK' AS ODS_SRC, 'S700' AS SYSTEM_SRC, MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, LIFNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s700_bsak
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSAK' AS ODS_SRC, 'S800' AS SYSTEM_SRC, MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, LIFNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s800_bsak
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSAK' AS ODS_SRC, 'S900' AS SYSTEM_SRC, MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, LIFNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s900_bsak
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)

        UNION ALL

        SELECT 'BSAK' AS ODS_SRC, CASE WHEN MANDT = '610' THEN 'S610' ELSE 'S810' END AS SYSTEM_SRC
             , MANDT AS MANDT, BUKRS AS BUKRS, GJAHR AS GJAHR, BELNR AS BELNR, BUZEI AS BUZEI
             , 'VENDOR' AS OBJECT_SOURCE, LIFNR AS OBJECT_CODE, HKONT AS HKONT, SHKZG AS SHKZG, DMBTR AS DMBTR, BUDAT AS BUDAT, AUGDT AS AUGDT, AUGBL AS AUGBL
          FROM ods.odsslt_s810_bsak
         WHERE BUDAT <= @key_date
           AND AUGDT > @key_date
           AND COALESCE(BSTAT, '') NOT IN ('A', 'S')
           AND (COALESCE(DMBTR, 0) <> 0 OR COALESCE(WRBTR, 0) <> 0)
       ) U
 GROUP BY ODS_SRC, SYSTEM_SRC, MANDT, BUKRS, GJAHR, BELNR, BUZEI
HAVING COUNT(*) > 1
 ORDER BY ODS_SRC, SYSTEM_SRC, MANDT, BUKRS, GJAHR, BELNR, BUZEI
 ;
