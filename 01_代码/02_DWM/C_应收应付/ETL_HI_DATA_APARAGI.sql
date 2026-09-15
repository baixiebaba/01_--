/*
 * 往来账龄表 ZZT003 取数 20231228
 * 6000/6000A/6000B/6000C/6600 合并重分类 add by xiaoyachao.ex 20240409
 * ALTER BY 20250331 XIAOYACHAO.EX 取分户账号
 * 网络科技 '2202000000'、'2202000089' 合并重分类 add by xiaoyachao.ex 20240627
 * 修改错误 20250604 修正 by zhuangxinzhou
 * ALTER BY 20250728 XIAOYACHAO.EX 管报这边往来账龄表和坏账都不取预计负债-保修准备科目 by wangaina
 * ALTER BY 20251117 ZHAOLAN.EX 性质转换改到数据源中处理，新增数据来源字段，性质转换剔除该数据源数据
 * ALTER BY 20260102 XIAOYACHAO.EX 增加新增利润中心映射回旧利润中心
 */
WITH
    /* 公司代码映射 */
    AZI_MAP AS (
        SELECT
            ELEDIM_INPUT1  AS SRC_MANDT
           ,ELEDIM_INPUT2  AS SRC_ENT
           ,ELEDIM_OUTPUT1 AS TAG_ENT
        FROM MAP_REGOLA_TAB_ELEMENTO
        WHERE COD_REGOLA_TAB IN ('MAP_BUKRS_800C')
          AND COD_MAPPATURA = 'HI_DATA_GL'
    )

    /* 往来账龄基础数据 */
   ,ZZT003 AS (
        SELECT
            NVL(AZI_MAP.TAG_ENT, T.BUKRS) AS BUKRS
           ,T.YEARMONTH
           ,T.MANDT
           ,T.HKONT
           ,T.HKONT_T
           ,T.CUSVEN
           ,T.CVCODE
           ,T.NAME1
           ,T.PRCTR
           ,T.KTEXT
           ,T.GSBER
           ,T.HWAER
           ,T.DMBTR0
           ,T.DMBTR1
           ,T.DMBTR2
           ,T.DMBTR3
           ,T.DMBTR4
           ,T.DMBTR5
           ,T.DMBTR6
           ,T.DMBTR7
           ,T.DMBTR8
           ,T.DMBTR9
           ,T.WAERS
           ,T.WRBTR0
           ,T.WRBTR1
           ,T.WRBTR2
           ,T.WRBTR3
           ,T.WRBTR4
           ,T.WRBTR5
           ,T.WRBTR6
           ,T.WRBTR7
           ,T.WRBTR8
           ,T.WRBTR9

            /*
             * 家电本部特殊处理 ADD BY XIAOYACHAO.EX 20240409
             * 网络科技特殊科目合并处理 ADD BY XIAOYACHAO.EX 20240627
             */
           ,SUM(T.DMBTR0) OVER (
                PARTITION BY
                    CASE
                        WHEN NVL(AZI_MAP.TAG_ENT, T.BUKRS) IN (
                                 '6000', '6000A', '6000B', '6000C', '6600'
                             )
                         AND T.HKONT_T IN (
                                 '1131002000', '1133001003', '2181001005', '2121001000'
                             )
                            THEN '6000'
                        ELSE NVL(AZI_MAP.TAG_ENT, T.BUKRS)
                    END
                   ,T.CUSVEN
                   ,NVL(HBCV.CVCODE_HB, T.CVCODE)
                   ,T.HKONT_T
            ) AS DMBTR_REC

            /* 增加利润中心粒度 */
           ,SUM(T.DMBTR0) OVER (
                PARTITION BY
                    CASE
                        WHEN NVL(AZI_MAP.TAG_ENT, T.BUKRS) IN (
                                 '6000', '6000A', '6000B', '6000C', '6600'
                             )
                         AND T.HKONT_T IN (
                                 '1131002000', '1133001003', '2181001005', '2121001000'
                             )
                            THEN '6000'
                        ELSE NVL(AZI_MAP.TAG_ENT, T.BUKRS)
                    END
                   ,T.CUSVEN
                   ,NVL(HBCV.CVCODE_HB, T.CVCODE)
                   ,T.HKONT_T
                   ,T.PRCTR
            ) AS DMBTR_REC_M
           ,HBCV.CVCODE_HB
        FROM (
            SELECT
                TO_CHAR(KEYDAT, 'YYYYMM') AS YEARMONTH
               ,TRIM(DECODE(MANDT, '680', '600', MANDT)) AS MANDT
               ,CASE
                    WHEN BUKRS IN ('4320', '4330')
                        THEN BUKRS || 'A'
                    WHEN MANDT = '700'
                        THEN DECODE(
                                 BUKRS
                                ,'1000', '1730'
                                ,'2000', '1740'
                                ,'3000', '1750'
                                ,'5000', '6240'
                                ,BUKRS
                             )
                    WHEN BUKRS = '6000'
                        THEN DECODE(
                                 GSBER
                                ,'200', '6000A'
                                ,'400', '6000B'
                                ,'500', '6000C'
                                ,BUKRS
                             )
                    WHEN MANDT = '800B'
                     AND BUKRS = '4221'
                        THEN '4220'
                    ELSE BUKRS
                END AS BUKRS
               ,TRIM(HKONT) AS HKONT
               ,CASE
                    WHEN HKONT LIKE '1466%'
                        THEN '1466000000'

                    /* 6500、6510、6515 科目相加后重分类；20180615 更改，20220826 删除 6515 */
                    WHEN BUKRS IN ('6500', '6510')
                     AND HKONT IN ('2241010100', '2241010200', '2241020000', '2241040000')
                        THEN '2241010100'
                    WHEN BUKRS IN ('6500', '6510')
                     AND HKONT IN ('1221010000', '1221020000', '1221040000')
                        THEN '1221010000'

                    /* 信扬公司的 2202 科目相加后再重分类 20201016 */
                    WHEN BUKRS IN ('1007', '1008', '1041')
                     AND HKONT LIKE '2202%'
                        THEN '2202000000'
                    WHEN BUKRS LIKE '66%'
                     AND BUKRS <> '6600'
                     AND HKONT LIKE '1131%'
                     AND HKONT <> '1131999001'
                        THEN '1131002000'
                    WHEN BUKRS LIKE '66%'
                     AND BUKRS <> '6600'
                     AND HKONT LIKE '1133%'
                     AND HKONT <> '1133999001'
                        THEN '1133001003'
                    WHEN BUKRS LIKE '66%'
                     AND BUKRS <> '6600'
                     AND HKONT LIKE '2181%'
                     AND HKONT <> '2181999001'
                        THEN '2181001005'
                    WHEN BUKRS LIKE '66%'
                     AND BUKRS <> '6600'
                     AND HKONT LIKE '2121%'
                     AND HKONT <> '2121999001'
                        THEN '2121001000'
                    WHEN BUKRS IN ('6000', '6600')
                     AND HKONT LIKE '1131%'
                        THEN '1131002000'
                    WHEN BUKRS IN ('6000', '6600')
                     AND HKONT LIKE '1133%'
                        THEN '1133001003'
                    WHEN BUKRS IN ('6000', '6600')
                     AND HKONT LIKE '2181%'
                        THEN '2181001005'
                    WHEN BUKRS IN ('6000', '6600')
                     AND HKONT LIKE '2121%'
                        THEN '2121001000'
                    WHEN BUKRS LIKE '16%'
                     AND BUKRS NOT LIKE '163%'
                     AND BUKRS NOT LIKE '162%'
                     AND HKONT IN ('2202000000', '2202000089')
                        THEN '2202000000'
                    ELSE HKONT
                END AS HKONT_T
               ,DECODE(TRIM(KOART), 'D', 'C', 'V') AS CUSVEN

                /*
                 * ALTER BY 20250331 XIAOYACHAO.EX 取分户账号
                 * 原计划：CASE WHEN {IN-YEARMONTH} >= '202503' THEN NVL(FILKD, OBJECT) ELSE OBJECT END
                 */
               ,OBJECT AS CVCODE
               ,TRIM(NAME1) AS NAME1
               ,CASE
                    WHEN LTRIM(PRCTR, '0') = '1330201'
                        THEN '1300201'
                    ELSE LTRIM(PRCTR, '0')
                END AS PRCTR
               ,CASE
                    WHEN TRIM(KTEXT) = '容声酒柜'
                        THEN '容声冰箱'
                    ELSE TRIM(KTEXT)
                END AS KTEXT
               ,TRIM(GSBER) AS GSBER
               ,TRIM(HWAER) AS HWAER
               ,DMBTR0
               ,DMBTR1
               ,DMBTR2
               ,DMBTR3
               ,DMBTR4
               ,DMBTR5
               ,DMBTR6
               ,DMBTR7
               ,DMBTR8
               ,DMBTR9
               ,TRIM(WAERS) AS WAERS
               ,WRBTR0
               ,WRBTR1
               ,WRBTR2
               ,WRBTR3
               ,WRBTR4
               ,WRBTR5
               ,WRBTR6
               ,WRBTR7
               ,WRBTR8
               ,WRBTR9
            FROM dw.DWFI_TF_ARAP_AGING@FMSLK
            WHERE KEYDAT = LAST_DAY(TO_DATE({IN-YEARMONTH}, 'YYYYMM'))
              AND NOT (
                    MANDT = '800B'
                AND BUKRS = '4220'
              )
              AND NOT (
                    DMBTR0 = 0
                AND DMBTR1 = 0
                AND DMBTR2 = 0
                AND DMBTR3 = 0
                AND DMBTR4 = 0
                AND DMBTR5 = 0
                AND DMBTR6 = 0
                AND DMBTR7 = 0
                AND DMBTR8 = 0
                AND DMBTR9 = 0
              )
              /* ALTER BY 20250728 XIAOYACHAO.EX：剔除预计负债-保修准备科目 by wangaina */
              AND TRIM(HKONT) <> '2801020000'
        ) T

        /* 匹配合并重分类客商 */
        LEFT JOIN (
            SELECT
                COD_AZIENDA
               ,LTRIM(TRIM(TESTO_11), '0') AS CVCODE
               ,TESTO_12 AS CVCODE_HB
            FROM FORM_DATI
            WHERE COD_PROSPETTO = 'ZS_APAR01_IPT04'
              AND COD_CATEGORIA = 'XT02'
              AND LTRIM(TRIM(TESTO_11), '0') IS NOT NULL
              AND LTRIM(TRIM(TESTO_12), '0') IS NOT NULL
              AND {IN-YEARMONTH} BETWEEN NVL(TRIM(TESTO_13), '0')
                                     AND NVL(TRIM(TESTO_13), '999999')
        ) HBCV
            ON HBCV.COD_AZIENDA = T.BUKRS
           AND LTRIM(T.CVCODE, '0') = HBCV.CVCODE

        LEFT JOIN AZI_MAP
            ON T.BUKRS = AZI_MAP.SRC_ENT
           AND T.MANDT = AZI_MAP.SRC_MANDT

        WHERE NVL(AZI_MAP.TAG_ENT, T.BUKRS) IN ({IN-ENTITY})
    )

SELECT
    A.YEARMONTH
   ,A.MANDT
   ,A.BUKRS
   ,A.HKONT
   ,A.HKONT_T
   ,A.CUSVEN
   ,A.CVCODE
   ,A.NAME1
   ,CASE
        WHEN {IN-YEARMONTH} >= '202601'
            THEN COALESCE(MP1.ELEDIM_OUTPUT1, MP.ELEDIM_OUTPUT1, A.PRCTR)
        WHEN {IN-YEARMONTH} >= '202512'
         AND A.PRCTR IN ('101001001', '101001002')
            THEN '1100101'
        WHEN {IN-YEARMONTH} >= '202512'
         AND A.PRCTR IN ('101008002', '190880002')
            THEN '1100104'
        WHEN {IN-YEARMONTH} >= '202512'
         AND A.PRCTR IN ('101056000')
            THEN '1100131'
        ELSE A.PRCTR
    END AS PRCTR
   ,CASE
        WHEN {IN-YEARMONTH} >= '202601'
            THEN COALESCE(MP1.ELEDIM_OUTPUT2, MP.ELEDIM_OUTPUT2, A.KTEXT)
        WHEN {IN-YEARMONTH} >= '202512'
         AND A.PRCTR IN ('101001001', '101001002')
            THEN '平板电视'
        ELSE A.KTEXT
    END AS KTEXT
   ,A.GSBER
   ,A.HWAER
   ,A.DMBTR0
   ,A.DMBTR1
   ,A.DMBTR2
   ,A.DMBTR3
   ,A.DMBTR4
   ,A.DMBTR5
   ,A.DMBTR6
   ,A.DMBTR7
   ,A.DMBTR8
   ,A.DMBTR9
   ,A.WAERS
   ,A.WRBTR0
   ,A.WRBTR1
   ,A.WRBTR2
   ,A.WRBTR3
   ,A.WRBTR4
   ,A.WRBTR5
   ,A.WRBTR6
   ,A.WRBTR7
   ,A.WRBTR8
   ,A.WRBTR9
   ,A.DMBTR_REC
   ,A.DMBTR_REC_M
   ,A.IS_REC
   ,A.LCODE
   ,A.IS_REC_M
   ,A.LCODE_M
   ,A.CTP
   ,A.SHUILV
   ,A.CVCODE_HB

    /*
     * 性质转换改到数据源中处理，新增数据来源字段，性质转换剔除该数据源数据
     * ALTER BY 20251117 ZHAOLAN.EX
     */
   ,CASE
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL6.TESTO_4
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL5.TESTO_4
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL4.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL4.TESTO_4
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL4.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL3.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL3.TESTO_4
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL4.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL3.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL2.ELEDIM_INPUT1, 'NULL') <> 'NULL'
            THEN LEVEL2.ELEDIM_OUTPUT1
        WHEN A.BUKRS IN (
                 SELECT ELEM
                 FROM V_REF_AZIENDA_TV
                 WHERE HIE = '30'
                   AND COD_SCENARIO = SUBSTR({IN-YEARMONTH}, 1, 4) || 'ACT'
                   AND COD_PERIODO = SUBSTR({IN-YEARMONTH}, 5, 2)
                   AND NODE = '2000'
             )
         AND A.BUKRS NOT LIKE '23%'
         AND A.BUKRS NOT LIKE '26%'
            THEN ''
        ELSE A.KVERM
    END AS KVERM
   ,CASE
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL6.TESTO_12
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL5.TESTO_12
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL4.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL4.TESTO_12
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL4.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL3.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL3.TESTO_12
    END AS KVERM_1
   ,CASE
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL6.TESTO_13
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL5.TESTO_13
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL4.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL4.TESTO_13
        WHEN NVL(LEVEL6.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL5.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL4.TESTO_1, 'NULL') = 'NULL'
         AND NVL(LEVEL3.TESTO_1, 'NULL') <> 'NULL'
            THEN LEVEL3.TESTO_13
    END AS KVERM_2
   ,'ZZT003' AS SRC
FROM (
    SELECT
        T3.YEARMONTH
       ,T3.MANDT
       ,T3.BUKRS
       ,T3.HKONT
       ,T3.HKONT_T
       ,T3.CUSVEN
       ,T3.CVCODE
       ,T3.NAME1
       ,T3.PRCTR
       ,T3.KTEXT
       ,T3.GSBER
       ,NVL(T3.HWAER, BZ.COD_VALUTA) AS HWAER
       ,T3.DMBTR0
       ,T3.DMBTR1
       ,T3.DMBTR2
       ,T3.DMBTR3
       ,T3.DMBTR4
       ,T3.DMBTR5
       ,T3.DMBTR6
       ,T3.DMBTR7
       ,T3.DMBTR8
       ,T3.DMBTR9
       ,T3.WAERS
       ,T3.WRBTR0
       ,T3.WRBTR1
       ,T3.WRBTR2
       ,T3.WRBTR3
       ,T3.WRBTR4
       ,T3.WRBTR5
       ,T3.WRBTR6
       ,T3.WRBTR7
       ,T3.WRBTR8
       ,T3.WRBTR9
       ,T3.DMBTR_REC
       ,T3.DMBTR_REC_M
       ,F_APAR_REC(
            T3.YEARMONTH
           ,T3.MANDT
           ,T3.BUKRS
           ,T3.HKONT_T
           ,T3.CVCODE
           ,T3.DMBTR_REC
           ,'1'
        ) AS IS_REC
       ,F_APAR_REC(
            T3.YEARMONTH
           ,T3.MANDT
           ,T3.BUKRS
           ,T3.HKONT_T
           ,T3.CVCODE
           ,T3.DMBTR_REC
           ,'2'
        ) AS LCODE
       ,F_APAR_REC(
            T3.YEARMONTH
           ,T3.MANDT
           ,T3.BUKRS
           ,T3.HKONT_T
           ,T3.CVCODE
           ,T3.DMBTR_REC_M
           ,'1'
        ) AS IS_REC_M
       ,F_APAR_REC(
            T3.YEARMONTH
           ,T3.MANDT
           ,T3.BUKRS
           ,T3.HKONT_T
           ,T3.CVCODE
           ,T3.DMBTR_REC_M
           ,'2'
        ) AS LCODE_M
       ,XINGZHI.KVERM
       ,IC.CTP
       ,NVL(
            NOTAXCV.SHUILV
           ,NVL(
                PRCTRTAX.SHUILV
               ,NVL(TAX.SHUILV, 0.13)
            )
        ) AS SHUILV
       ,T3.CVCODE_HB
    FROM ZZT003 T3

    /* 匹配性质 */
    LEFT JOIN (
        SELECT
            LIFNR AS CVCODE
           ,MAX(KVERM) AS KVERM
           ,BUKRS
           ,'V' AS CUSVEN
        FROM ODS.ODSS600_LFB1@FMSLK
        WHERE TRIM(KVERM) IS NOT NULL
        GROUP BY
            BUKRS
           ,LIFNR

        UNION ALL

        SELECT
            KUNNR AS CVCODE
           ,MAX(KVERM) AS KVERM
           ,BUKRS
           ,'C' AS CUSVEN
        FROM ODS.ODSS600_KNB1@FMSLK
        WHERE TRIM(KVERM) IS NOT NULL
        GROUP BY
            BUKRS
           ,KUNNR
    ) XINGZHI
        ON T3.BUKRS = XINGZHI.BUKRS
       AND T3.CUSVEN = XINGZHI.CUSVEN
       AND T3.CVCODE = XINGZHI.CVCODE

    /* 匹配对方公司 */
    LEFT JOIN (
        SELECT
            CASE LTRIM(ELEDIM_INPUT1, 'ZTCLIENT.')
                WHEN '800B1'
                    THEN '800B'
                ELSE LTRIM(ELEDIM_INPUT1, 'ZTCLIENT.')
            END AS MANDT
           ,LTRIM(ELEDIM_INPUT2, '0') AS CVCODE
           ,ELEDIM_INPUT3 AS CUSVEN
           ,MIN(ELEDIM_OUTPUT1) AS CTP
        FROM MAP_REGOLA_TAB_ELEMENTO
        WHERE COD_MAPPATURA = 'HI_DATA_APARAGI'
          AND COD_REGOLA_TAB = 'MAP_CTP'
        GROUP BY
            ELEDIM_INPUT1
           ,LTRIM(ELEDIM_INPUT2, '0')
           ,ELEDIM_INPUT3
    ) IC
        ON LTRIM(T3.CVCODE, '0') = LTRIM(IC.CVCODE, '0')
       AND T3.CUSVEN = IC.CUSVEN
       AND T3.MANDT = IC.MANDT

    /* 匹配公司税率：202203 起存在 0 税率 */
    LEFT JOIN (
        SELECT
            F1.COD_AZIENDA
           ,NVL(F1.IMPORTO_1, 0) AS SHUILV
        FROM FORM_DATI F1
        WHERE F1.COD_PROSPETTO = 'ZG_IC001_TAXSET'
          AND COD_CATEGORIA = '$AMOUNT'
          AND {IN-YEARMONTH} BETWEEN NVL(F1.TESTO_11, '000000')
                                 AND NVL(F1.TESTO_12, '999999')
          AND COD_AZIENDA IS NOT NULL
          /* AND NVL(F1.IMPORTO_1, 0) <> 0 */
    ) TAX
        ON TAX.COD_AZIENDA = T3.BUKRS

    /* 按利润中心匹配税率 20220908zbz */
    LEFT JOIN (
        SELECT
            F1.COD_AZIENDA
           ,F1.TESTO_16 AS PRCTR_CODE
           ,NVL(F1.IMPORTO_1, 0) AS SHUILV
        FROM FORM_DATI F1
        WHERE F1.COD_PROSPETTO = 'ZG_IC001_TAXSET'
          AND COD_CATEGORIA = '1REC'
          AND {IN-YEARMONTH} BETWEEN NVL(F1.TESTO_11, '000000')
                                 AND NVL(F1.TESTO_12, '999999')
          AND COD_AZIENDA IS NOT NULL
          AND TRIM(F1.TESTO_16) IS NOT NULL
    ) PRCTRTAX
        ON T3.BUKRS = PRCTRTAX.COD_AZIENDA
       AND LTRIM(T3.PRCTR, '0') = LTRIM(PRCTRTAX.PRCTR_CODE, '0')

    /* 客户无税客户：20231228 改为可特殊设置客户税率 */
    LEFT JOIN (
        SELECT
            F1.COD_AZIENDA
           ,F1.TESTO_14 AS CVCODE
           ,NVL(F1.IMPORTO_1, 0) AS SHUILV
        FROM FORM_DATI F1
        WHERE F1.COD_PROSPETTO = 'ZG_IC001_TAXSET'
          AND COD_CATEGORIA = '1ADJ'
          AND {IN-YEARMONTH} BETWEEN NVL(F1.TESTO_11, '000000')
                                 AND NVL(F1.TESTO_12, '999999')
          AND COD_AZIENDA IS NOT NULL
          AND TRIM(F1.TESTO_14) IS NOT NULL
    ) NOTAXCV
        ON T3.BUKRS = NOTAXCV.COD_AZIENDA
       AND LTRIM(T3.CVCODE, '0') = LTRIM(NOTAXCV.CVCODE, '0')

    LEFT JOIN TGK_GB_HISENSE.AZIENDA BZ
        ON T3.BUKRS = BZ.COD_AZIENDA
) A

/* 性质转换改到数据源中处理，对应转换中的各任务及顺序 ALTER BY 20251117 ZHAOLAN.EX */

/* 第二层 90、91：性质-系统级 */
LEFT JOIN (
    SELECT
        ELEDIM_INPUT1
       ,ELEDIM_INPUT2
       ,ELEDIM_INPUT3
       ,ELEDIM_OUTPUT1
    FROM TGK_GB_HISENSE.MAP_REGOLA_TAB_ELEMENTO
    WHERE COD_MAPPATURA = 'HI_DATA_APARAGI'
      AND COD_REGOLA_TAB = 'TYPE'
) LEVEL2
    ON NVL(A.MANDT, '|') LIKE LEVEL2.ELEDIM_INPUT1
   AND NVL(A.HKONT, '|') LIKE LEVEL2.ELEDIM_INPUT2
   AND NVL(A.CVCODE, '|') LIKE LEVEL2.ELEDIM_INPUT3

/* 第三层 92、93：性质-公司级 */
LEFT JOIN (
    SELECT *
    FROM TGK_GB_HISENSE.FORM_DATI
    WHERE COD_PROSPETTO = 'ZS_APAR01_IPT02'
      AND COD_CATEGORIA = 'XT04'

      /* 去重完整关系 */
      AND (
            NVL(TESTO_1, '|')
           ,NVL(TESTO_2, '|')
           ,NVL(COD_AZIENDA, '|')
          ) NOT IN (
            SELECT
                NVL(TESTO_1, '|')
               ,NVL(TESTO_2, '|')
               ,NVL(COD_AZIENDA, '|')
            FROM V_SQL_FORM_DATI
            WHERE COD_PROSPETTO = 'ZS_APAR01_IPT02'
              AND COD_CATEGORIA = 'XT04'
            GROUP BY
                TESTO_1
               ,TESTO_2
               ,COD_AZIENDA
            HAVING COUNT(1) > 1
          )
      AND NVL(TESTO_17, 'N') <> 'Y'
) LEVEL3
    ON A.MANDT = LEVEL3.TESTO_1
   AND A.HKONT = LEVEL3.TESTO_2
   AND A.BUKRS = LEVEL3.COD_AZIENDA

/* 第四层 94、95：性质-利润中心 */
LEFT JOIN (
    SELECT *
    FROM TGK_GB_HISENSE.FORM_DATI
    WHERE COD_PROSPETTO = 'ZS_APAR01_IPT02'
      AND COD_CATEGORIA = 'XT03'
      AND COD_AZIENDA IS NOT NULL
      AND TESTO_1 IS NOT NULL
      AND TESTO_2 IS NOT NULL
      AND TESTO_7 IS NOT NULL

      /* 去重完整关系 */
      AND (
            TESTO_1
           ,TESTO_2
           ,TESTO_7
           ,COD_AZIENDA
          ) NOT IN (
            SELECT
                TESTO_1
               ,TESTO_2
               ,TESTO_7
               ,COD_AZIENDA
            FROM V_SQL_FORM_DATI
            WHERE COD_PROSPETTO = 'ZS_APAR01_IPT02'
              AND COD_CATEGORIA = 'XT03'
              AND COD_AZIENDA IS NOT NULL
              AND TESTO_1 IS NOT NULL
              AND TESTO_2 IS NOT NULL
              AND TESTO_7 IS NOT NULL
            GROUP BY
                TESTO_1
               ,TESTO_2
               ,TESTO_7
               ,COD_AZIENDA
            HAVING COUNT(1) > 1
          )
      AND NVL(TESTO_17, 'N') <> 'Y'
) LEVEL4
    ON A.MANDT = LEVEL4.TESTO_1
   AND A.HKONT = LEVEL4.TESTO_2
   AND A.PRCTR = LEVEL4.TESTO_7
   AND A.BUKRS = LEVEL4.COD_AZIENDA

/* 第五层 96、97：性质-客商 */
LEFT JOIN (
    SELECT *
    FROM TGK_GB_HISENSE.FORM_DATI
    WHERE COD_PROSPETTO = 'ZS_APAR01_IPT02'
      AND COD_CATEGORIA = 'XT02'
      AND COD_AZIENDA IS NOT NULL
      AND TESTO_1 IS NOT NULL
      AND TESTO_3 IS NOT NULL

      /* 去重完整关系 */
      AND (
            TESTO_1
           ,TESTO_3
           ,COD_AZIENDA
          ) NOT IN (
            SELECT
                TESTO_1
               ,TESTO_3
               ,COD_AZIENDA
            FROM V_SQL_FORM_DATI
            WHERE COD_PROSPETTO = 'ZS_APAR01_IPT02'
              AND COD_CATEGORIA = '$XT02'
              AND COD_AZIENDA IS NOT NULL
              AND TESTO_1 IS NOT NULL
              AND TESTO_3 IS NOT NULL
            GROUP BY
                TESTO_1
               ,TESTO_3
               ,COD_AZIENDA
            HAVING COUNT(1) > 1
          )
      AND NVL(TESTO_17, 'N') <> 'Y'
) LEVEL5
    ON A.MANDT = LEVEL5.TESTO_1
   AND A.CVCODE = LEVEL5.TESTO_3
   AND A.BUKRS = LEVEL5.COD_AZIENDA

/* 第六层 98、99：性质-科目、客商 */
LEFT JOIN (
    SELECT *
    FROM TGK_GB_HISENSE.FORM_DATI
    WHERE COD_PROSPETTO = 'ZS_APAR01_IPT02'
      AND COD_CATEGORIA = '$AMOUNT'
      AND COD_AZIENDA IS NOT NULL
      AND TESTO_1 IS NOT NULL
      AND TESTO_2 IS NOT NULL
      AND TESTO_3 IS NOT NULL

      /* 去重完整关系 */
      AND (
            TESTO_1
           ,TESTO_2
           ,TESTO_3
           ,COD_AZIENDA
          ) NOT IN (
            SELECT
                TESTO_1
               ,TESTO_2
               ,TESTO_3
               ,COD_AZIENDA
            FROM /* TMP_FORM_DATI_241103 */ V_SQL_FORM_DATI
            WHERE COD_PROSPETTO = 'ZS_APAR01_IPT02'
              AND COD_CATEGORIA = '$AMOUNT'
              AND COD_AZIENDA IS NOT NULL
              AND TESTO_1 IS NOT NULL
              AND TESTO_2 IS NOT NULL
              AND TESTO_3 IS NOT NULL
            GROUP BY
                TESTO_1
               ,TESTO_2
               ,TESTO_3
               ,COD_AZIENDA
            HAVING COUNT(1) > 1
          )
      AND NVL(TESTO_17, 'N') <> 'Y'
) LEVEL6
    ON A.MANDT = LEVEL6.TESTO_1
   AND A.HKONT = LEVEL6.TESTO_2
   AND A.CVCODE = LEVEL6.TESTO_3
   AND A.BUKRS = LEVEL6.COD_AZIENDA

/* ALTER BY 20260102 XIAOYACHAO.EX 增加新增利润中心映射回旧利润中心 */
LEFT JOIN TGK_GB_HISENSE.MAP_REGOLA_TAB_ELEMENTO MP
    ON A.PRCTR = MP.ELEDIM_INPUT1
   AND COD_MAPPATURA = 'HI_DATA_APARAGI'
   AND COD_REGOLA_TAB = 'MAP_PRCTR'

/* ALTER BY 20260102 XIAOYACHAO.EX 增加新增利润中心映射回旧利润中心 */
LEFT JOIN TGK_GB_HISENSE.MAP_REGOLA_TAB_ELEMENTO MP1
    ON A.BUKRS LIKE MP1.ELEDIM_INPUT1
   AND LTRIM(A.CVCODE, '0') LIKE MP1.ELEDIM_INPUT2
   AND A.PRCTR LIKE MP1.ELEDIM_INPUT3
   AND MP1.COD_MAPPATURA = 'HI_DATA_APARAGI'
   AND MP1.COD_REGOLA_TAB = 'MAP_PRCTR1'

/* ALTER BY 20260612 XIAOYACHAO：剔除信汇取数 */
WHERE A.NAME1 NOT IN ('应收账款-信汇', '应付账款-信汇')
