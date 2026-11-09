/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261106 14:25
 * 本次修改：ALTER BY 20261106 14:25 SHIQINGFENG.EX 匹配情况改为按金额判断，并排除两侧金额全为0的空壳行。
 * 上次修改：ALTER BY 20261102 18:20 SHIQINGFENG.EX 字段列表逐行排版；修复 FROM 缺失 schema 点号。
 *
 * 查询名称  ：往来账龄结果表M02-明细校验表
 * 源表      ：TGK_FIMA_DEV.AW_MR9_ARPM02_000001、TGK_GB_HISENSE.FORM_DATI 等，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261106 14:25 SHIQINGFENG.EX 匹配情况改为按金额判断，并排除两侧金额全为0的空壳行。
 *   ALTER BY 20261102 18:20 SHIQINGFENG.EX 字段列表逐行排版；修复 FROM 缺失 schema 点号。
 *   ALTER BY 20261102 17:36 SHIQINGFENG.EX 补查询说明文件头。
 *******************************************************************************/
WITH PARAMS AS (
    SELECT ${$Scenario.code} AS P_SCENARIO    /* 场景（年份+场景码） */
         , ${$Period.code}   AS P_PERIODO     /* 期间，两位月份码 */
      FROM DUAL
),
/* 公司限制：${$Entity.code} 传公司编码清单 */
AZI AS (
    SELECT A.COD_AZIENDA
      FROM TGK_FIMA_HISENSE.AZIENDA A
     WHERE A.COD_AZIENDA IN (${$Entity.code})
),
/* 往来项目与科目映射，2.0/1.0 科目号一致 */
ITM AS (
    SELECT '应收账款' AS ITEM_NAME, 1 AS SEQ, '1122000000' AS CONTO20, '1122000000' AS CONTO10 FROM DUAL UNION ALL
    SELECT '其他应收款' AS ITEM_NAME, 2 AS SEQ, '122101F' AS CONTO20, '122101F' AS CONTO10 FROM DUAL UNION ALL
    SELECT '预付账款' AS ITEM_NAME, 3 AS SEQ, '1123000000' AS CONTO20, '1123000000' AS CONTO10 FROM DUAL UNION ALL
    SELECT '应收款项融资' AS ITEM_NAME, 4 AS SEQ, '1124001000' AS CONTO20, '1124001000' AS CONTO10 FROM DUAL UNION ALL
    SELECT '合同资产' AS ITEM_NAME, 5 AS SEQ, '1460000000' AS CONTO20, '1460000000' AS CONTO10 FROM DUAL UNION ALL
    SELECT '应付账款' AS ITEM_NAME, 6 AS SEQ, '2202000000' AS CONTO20, '2202000000' AS CONTO10 FROM DUAL UNION ALL
    SELECT '其他应付款' AS ITEM_NAME, 7 AS SEQ, '224199F' AS CONTO20, '224199F' AS CONTO10 FROM DUAL UNION ALL
    SELECT '预收账款' AS ITEM_NAME, 8 AS SEQ, '2203000000' AS CONTO20, '2203000000' AS CONTO10 FROM DUAL UNION ALL
    SELECT '合同负债' AS ITEM_NAME, 9 AS SEQ, '2204000000' AS CONTO20, '2204000000' AS CONTO10 FROM DUAL UNION ALL
    SELECT '长期应收款' AS ITEM_NAME, 10 AS SEQ, '1531000000' AS CONTO20, '1531000000' AS CONTO10 FROM DUAL
),
/* 2.0 账龄表：公司+项目+客商 聚合 */
T20C AS (
    SELECT A.COD_AZIENDA AS COMPANY_CODE
         , I.SEQ AS SEQ
         , I.ITEM_NAME AS ITEM_NAME
         /* 全零编码 LTRIM 后为空串(=NULL)，统一置 (NO_CUST) 才能与 1.0 侧配对 */
         , NVL(LTRIM(A.CUST_HEAD_CODE, '0'), '(NO_CUST)') AS CUST_CODE
         , MAX(A.CUST_HEAD_NAME) AS CUST_NAME
         , SUM(A.BY_BCY_0_AMT) AS BY_AMT/* 年初，AG 过程未赋值，当前恒为 0 */
         , SUM(A.LM_BCY_0_AMT) AS LM_AMT/* 上月，同上 */
         , SUM(A.BCY_0_AMT) AS CUR_AMT  /* 本月 */
      FROM AW_MR9_ARPM02_000001 A
     CROSS JOIN PARAMS P
      JOIN ITM I ON A.COD_CONTO = I.CONTO20
     WHERE A.COD_PERIODO = P.P_PERIODO
       AND A.COD_CATEGORIA = 'ZAMOUNT'
       AND A.COD_SCENARIO = P.P_SCENARIO
       AND A.COD_AZIENDA IN (SELECT COD_AZIENDA FROM AZI)   /* 公司限制 */
     GROUP BY A.COD_AZIENDA, I.SEQ, I.ITEM_NAME, NVL(LTRIM(A.CUST_HEAD_CODE, '0'), '(NO_CUST)')
),
/* 1.0 账龄表：1开头科目取 TESTO_14/15，2开头取 TESTO_5/6 */
T10C AS (
    SELECT F.COD_AZIENDA AS COMPANY_CODE
         , I.SEQ AS SEQ
         , I.ITEM_NAME AS ITEM_NAME
         , NVL(LTRIM(CASE
                       WHEN SUBSTR(F.COD_CONTO, 1, 1) = '1'
                         THEN F.TESTO_14                   /* 客商编码 */
                       ELSE F.TESTO_5                      /* 客商编码 */
                     END, '0'), '(NO_CUST)')                CUST_CODE
         , MAX(CASE
                 WHEN SUBSTR(F.COD_CONTO, 1, 1) = '1'
                   THEN F.TESTO_15                         /* 客商名称 */
                 ELSE F.TESTO_6                            /* 客商名称 */
               END) AS CUST_NAME
         , MAX(F.IMPORTO_36)                                ADJ_FLAG  /* 1.0 手工调整标识 */
         , SUM(F.IMPORTO_1)                                 BY_AMT    /* 年初 */
         , SUM(F.IMPORTO_2)                                 LM_AMT    /* 上月 */
         , SUM(F.IMPORTO_3)                                 CUR_AMT   /* 本月 */
      FROM TGK_GB_HISENSE.FORM_DATI F
     CROSS JOIN PARAMS P
      JOIN ITM I ON F.COD_CONTO = I.CONTO10
     WHERE F.COD_PROSPETTO IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
       AND F.COD_CATEGORIA IN ('$AMOUNT', '1ADJ', '1REC')
       AND F.COD_PERIODO = P.P_PERIODO
       AND F.COD_SCENARIO = P.P_SCENARIO
       AND F.COD_AZIENDA IN (SELECT COD_AZIENDA FROM AZI)   /* 公司限制 */
     GROUP BY F.COD_AZIENDA, I.SEQ, I.ITEM_NAME,
            NVL(LTRIM(CASE
                        WHEN SUBSTR(F.COD_CONTO, 1, 1) = '1'
                          THEN F.TESTO_14
                        ELSE F.TESTO_5
                      END, '0'), '(NO_CUST)')
)
SELECT NVL(T20C.COMPANY_CODE, T10C.COMPANY_CODE)            AS COMPANY_CODE   /* 公司 */
     , NVL(T20C.ITEM_NAME, T10C.ITEM_NAME)                  AS ITEM_NAME      /* 往来项目 */
     , NVL(T20C.CUST_CODE, T10C.CUST_CODE)                  AS CUST_CODE      /* 客商编码 */
     , NVL(T20C.CUST_NAME, T10C.CUST_NAME)                  AS CUST_NAME      /* 客商名称 */
       /* 2.0 账龄 */
     , NVL(T20C.BY_AMT, 0)                                  AS BY_AMT_20      /* 年初 */
     , NVL(T20C.LM_AMT, 0)                                  AS LM_AMT_20      /* 上月 */
     , NVL(T20C.CUR_AMT, 0)                                 AS CUR_AMT_20     /* 本月 */
       /* 1.0 账龄 */
     , NVL(T10C.BY_AMT, 0)                                  AS BY_AMT_10      /* 年初 */
     , NVL(T10C.LM_AMT, 0)                                  AS LM_AMT_10      /* 上月 */
     , NVL(T10C.CUR_AMT, 0)                                 AS CUR_AMT_10     /* 本月 */
       /* 差异 = 2.0 - 1.0 */
     , NVL(T20C.BY_AMT, 0)  - NVL(T10C.BY_AMT, 0)           AS BY_AMT_DIFF    /* 年初 */
     , NVL(T20C.LM_AMT, 0)  - NVL(T10C.LM_AMT, 0)           AS LM_AMT_DIFF    /* 上月 */
     , NVL(T20C.CUR_AMT, 0) - NVL(T10C.CUR_AMT, 0)          AS CUR_AMT_DIFF   /* 本期 */
       /* 按金额判断该侧是否有数，两侧金额全为 0 的行已在 WHERE 排除 */
     , CASE
         WHEN (   NVL(T20C.BY_AMT, 0) <> 0
               OR NVL(T20C.LM_AMT, 0) <> 0
               OR NVL(T20C.CUR_AMT, 0) <> 0)
          AND (   NVL(T10C.BY_AMT, 0) <> 0
               OR NVL(T10C.LM_AMT, 0) <> 0
               OR NVL(T10C.CUR_AMT, 0) <> 0)
           THEN '两边都有'
         WHEN (   NVL(T20C.BY_AMT, 0) <> 0
               OR NVL(T20C.LM_AMT, 0) <> 0
               OR NVL(T20C.CUR_AMT, 0) <> 0)
           THEN '仅2.0有'
         ELSE '仅1.0有'
       END AS MATCH_FLAG
     , NVL(T10C.ADJ_FLAG, 0)                                AS ADJ_FLAG       /* 1.0 手工调整标识 */
  FROM T20C
  FULL OUTER JOIN T10C
    ON T20C.COMPANY_CODE = T10C.COMPANY_CODE
   AND T20C.SEQ = T10C.SEQ
   AND T20C.CUST_CODE = T10C.CUST_CODE
 /* 两侧金额全为 0 的空壳行不展示 */
 WHERE NVL(T20C.BY_AMT, 0) <> 0
    OR NVL(T20C.LM_AMT, 0) <> 0
    OR NVL(T20C.CUR_AMT, 0) <> 0
    OR NVL(T10C.BY_AMT, 0) <> 0
    OR NVL(T10C.LM_AMT, 0) <> 0
    OR NVL(T10C.CUR_AMT, 0) <> 0
 ORDER BY NVL(T20C.COMPANY_CODE, T10C.COMPANY_CODE), NVL(T20C.SEQ, T10C.SEQ), NVL(T20C.CUST_CODE, T10C.CUST_CODE)
