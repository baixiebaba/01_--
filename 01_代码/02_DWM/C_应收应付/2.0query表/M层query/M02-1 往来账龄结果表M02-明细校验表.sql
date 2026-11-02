/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:36
 * 本次修改：ALTER BY 20261102 17:36 SHIQINGFENG.EX 按规范补查询说明文件头（查询名称+源表），未修改业务主体。
 * 上次修改：原文件无修改记录。
 *
 * 查询名称  ：往来账龄结果表M02-明细校验表
 * 源表      ：TGK_FIMA_DEV.AW_MR9_ARPM02_000001、TGK_GB_HISENSE.FORM_DATI 等，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261102 17:36 SHIQINGFENG.EX 按规范补查询说明文件头（查询名称+源表），未修改业务主体。
 *******************************************************************************/
WITH PARAMS AS (
    SELECT ${$Scenario.code} AS P_SCENARIO,  /* 场景 (年份+场景码) */
           ${$Period.code}     AS P_PERIODO    /* 期间, 两位月份码 */
    FROM   DUAL
),
/* 公司限制清单: 从公司维度表取, IN 里填要查的公司编码; 查全部公司则去掉各取数段的 IN 限制 */
AZI AS (
    SELECT A.COD_AZIENDA
    FROM   TGK_FIMA_HISENSE.AZIENDA A
    WHERE  A.COD_AZIENDA IN (${$Entity.code})
),
/* 往来项目 ? 科目映射 (2.0 / 1.0 账龄表均为精确科目号) */
ITM AS (
    SELECT '应收账款'     ITEM_NAME,  1 SEQ, '1122000000' CONTO20, '1122000000' CONTO10 FROM DUAL UNION ALL
    SELECT '其他应收款'   ITEM_NAME,  2 SEQ, '122101F'    CONTO20, '122101F'    CONTO10 FROM DUAL UNION ALL
    SELECT '预付账款'     ITEM_NAME,  3 SEQ, '1123000000' CONTO20, '1123000000' CONTO10 FROM DUAL UNION ALL
    SELECT '应收款项融资' ITEM_NAME,  4 SEQ, '1124001000' CONTO20, '1124001000' CONTO10 FROM DUAL UNION ALL
    SELECT '合同资产'     ITEM_NAME,  5 SEQ, '1460000000' CONTO20, '1460000000' CONTO10 FROM DUAL UNION ALL
    SELECT '应付账款'     ITEM_NAME,  6 SEQ, '2202000000' CONTO20, '2202000000' CONTO10 FROM DUAL UNION ALL
    SELECT '其他应付款'   ITEM_NAME,  7 SEQ, '224199F'    CONTO20, '224199F'    CONTO10 FROM DUAL UNION ALL
    SELECT '预收账款'     ITEM_NAME,  8 SEQ, '2203000000' CONTO20, '2203000000' CONTO10 FROM DUAL UNION ALL
    SELECT '合同负债'     ITEM_NAME,  9 SEQ, '2204000000' CONTO20, '2204000000' CONTO10 FROM DUAL UNION ALL
    SELECT '长期应收款'   ITEM_NAME, 10 SEQ, '1531000000' CONTO20, '1531000000' CONTO10 FROM DUAL
),
/* 2.0 账龄表: 公司 + 项目 + 客商 聚合 */
T20C AS (
    SELECT A.COD_AZIENDA                     COMPANY_CODE,
           I.SEQ, I.ITEM_NAME,
           /* 去前导零; LTRIM 对全零编码会返回空串(Oracle 空串=NULL), 统一置为 '(NO_CUST)' 以便配对 */
           NVL(LTRIM(A.CUST_HEAD_CODE, '0'), '(NO_CUST)') CUST_CODE,
           MAX(A.CUST_HEAD_NAME)                  CUST_NAME,
           COUNT(*)                          ROW_CNT,   /* 行数标记, 用于判断该侧是否有数据 */
           SUM(A.BY_BCY_0_AMT)               BY_AMT,   /* 年初 */
           SUM(A.LM_BCY_0_AMT)               LM_AMT,   /* 上月 */
           SUM(A.BCY_0_AMT)                  CUR_AMT   /* 本月 */
    FROM   AW_MR9_ARPM02_000001 A
    CROSS  JOIN PARAMS P
    JOIN   ITM I ON A.COD_CONTO = I.CONTO20
    WHERE  A.COD_PERIODO   = P.P_PERIODO
      AND  A.COD_CATEGORIA = 'ZAMOUNT'
      AND  A.COD_SCENARIO  = P.P_SCENARIO
      AND  A.COD_AZIENDA   IN (SELECT COD_AZIENDA FROM AZI)   /* 公司限制 */
    GROUP  BY A.COD_AZIENDA, I.SEQ, I.ITEM_NAME, NVL(LTRIM(A.CUST_HEAD_CODE, '0'), '(NO_CUST)')
),
/* 1.0 账龄表: 公司 + 项目 + 客商 聚合 (客商编码/名称按科目开头取不同字段) */
T10C AS (
    SELECT F.COD_AZIENDA COMPANY_CODE,
           I.SEQ, I.ITEM_NAME,
           NVL(LTRIM(CASE WHEN SUBSTR(F.COD_CONTO, 1, 1) = '1'
                          THEN F.TESTO_14          /* 1开头科目: 客商编码 */
                          ELSE F.TESTO_5           /* 2开头科目: 客商编码 */
                     END, '0'), '(NO_CUST)')                      CUST_CODE,
           MAX(CASE WHEN SUBSTR(F.COD_CONTO, 1, 1) = '1'
                    THEN F.TESTO_15          /* 1开头科目: 客商名称 */
                    ELSE F.TESTO_6           /* 2开头科目: 客商名称 */
               END)                                             CUST_NAME,
           MAX(F.IMPORTO_36) ADJ_FLAG,       /* 是否调整 (1.0 FORM_DATI.IMPORTO_36) */
           COUNT(*)          ROW_CNT,        /* 行数标记, 用于判断该侧是否有数据 */
           SUM(F.IMPORTO_1) BY_AMT,          /* 年初 */
           SUM(F.IMPORTO_2) LM_AMT,          /* 上月 */
           SUM(F.IMPORTO_3) CUR_AMT          /* 本月 */
    FROM   TGK_GB_HISENSEFORM_DATI F
    CROSS  JOIN PARAMS P
    JOIN   ITM I ON F.COD_CONTO = I.CONTO10
    WHERE  F.COD_PROSPETTO IN ('ZS_AP0001_IPT01', 'ZS_AR0001_IPT01')
      AND  F.COD_CATEGORIA IN ('$AMOUNT', '1ADJ', '1REC')
      AND  F.COD_PERIODO   = P.P_PERIODO
      AND  F.COD_SCENARIO  = P.P_SCENARIO
      AND  F.COD_AZIENDA   IN (SELECT COD_AZIENDA FROM AZI)   /* 公司限制 */
    GROUP  BY F.COD_AZIENDA, I.SEQ, I.ITEM_NAME,
              NVL(LTRIM(CASE WHEN SUBSTR(F.COD_CONTO, 1, 1) = '1'
                             THEN F.TESTO_14 ELSE F.TESTO_5 END, '0'), '(NO_CUST)')
)
SELECT NVL(T20C.COMPANY_CODE, T10C.COMPANY_CODE)                 AS COMPANY_CODE   /* 公司 */,
       NVL(T20C.ITEM_NAME, T10C.ITEM_NAME)                       AS ITEM_NAME      /* 往来项目 */,
       NVL(T20C.CUST_CODE, T10C.CUST_CODE)                       AS CUST_CODE      /* 客商编码 */,
       NVL(T20C.CUST_NAME, T10C.CUST_NAME)                       AS CUST_NAME      /* 客商名称 */,
       /* ===== 2.0账龄 (年初 / 上月 / 本月) ===== */
       NVL(T20C.BY_AMT, 0)                                       AS BY_AMT_20      /* 2.0账龄-年初余额 */,
       NVL(T20C.LM_AMT, 0)                                       AS LM_AMT_20      /* 2.0账龄-上月余额 */,
       NVL(T20C.CUR_AMT, 0)                                      AS CUR_AMT_20     /* 2.0账龄-本月余额 */,
       /* ===== 1.0账龄 (年初 / 上月 / 本月) ===== */
       NVL(T10C.BY_AMT, 0)                                       AS BY_AMT_10      /* 1.0账龄-年初余额 */,
       NVL(T10C.LM_AMT, 0)                                       AS LM_AMT_10      /* 1.0账龄-上月余额 */,
       NVL(T10C.CUR_AMT, 0)                                      AS CUR_AMT_10     /* 1.0账龄-本月余额 */,
       /* ===== 差异 (2.0 - 1.0) ===== */
       NVL(T20C.BY_AMT, 0)  - NVL(T10C.BY_AMT, 0)                AS BY_AMT_DIFF    /* 差异-年初（2.0减1.0） */,
       NVL(T20C.LM_AMT, 0)  - NVL(T10C.LM_AMT, 0)                AS LM_AMT_DIFF    /* 差异-上月（2.0减1.0） */,
       NVL(T20C.CUR_AMT, 0) - NVL(T10C.CUR_AMT, 0)               AS CUR_AMT_DIFF   /* 差异-本期（2.0减1.0） */,
       /* ===== 来源标记(用行数标记判断, 避免客商编码为空导致的误判) ===== */
       CASE WHEN NVL(T20C.ROW_CNT, 0) = 0 THEN '仅1.0有'
            WHEN NVL(T10C.ROW_CNT, 0) = 0 THEN '仅2.0有'
            ELSE '两边都有' END                                  AS MATCH_FLAG     /* 来源标记：仅1.0有/仅2.0有/两边都有 */,
       /* ===== 是否调整 (取自 1.0 FORM_DATI.IMPORTO_36) ===== */
       NVL(T10C.ADJ_FLAG, 0)                                     AS ADJ_FLAG       /* 是否调整（1.0手工调整标识） */
FROM   T20C
FULL   OUTER JOIN T10C
       ON  T20C.COMPANY_CODE = T10C.COMPANY_CODE
       AND T20C.SEQ          = T10C.SEQ
       AND T20C.CUST_CODE    = T10C.CUST_CODE
ORDER  BY NVL(T20C.COMPANY_CODE, T10C.COMPANY_CODE), NVL(T20C.SEQ, T10C.SEQ), NVL(T20C.CUST_CODE, T10C.CUST_CODE)