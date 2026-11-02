/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261102 17:36
 * 本次修改：ALTER BY 20261102 17:36 SHIQINGFENG.EX 按规范补查询说明文件头（查询名称+源表），未修改业务主体。
 * 上次修改：原文件无修改记录。
 *
 * 查询名称  ：坏账计提结果表-明细校验表
 * 源表      ：TGK_FIMA_DEV.AW_MR9_ARPM02_000001、TGK_GB_HISENSE.ZTAB_AG_TF_OC。
 *
 * 修改历史：
 *   ALTER BY 20261102 17:36 SHIQINGFENG.EX 按规范补查询说明文件头（查询名称+源表），未修改业务主体。
 *   2026-03-12  在T20/T10内部以ITM三科目FULL JOIN补齐缺失科目（原版本记录）。
 *   2026-03-11  简化为T20/T10 FULL JOIN后按ITM补齐三科目（原版本记录）。
 *   2026-03-10  修复ITM/合同资产关联，补齐缺失侧科目行并按0展示（原版本记录）。
 *   2026-03-09  新增坏账客商级差异校验（原版本记录）。
 *******************************************************************************/
WITH
/* 坏账校验科目大类及两套系统对应科目 */
ITM AS (
    SELECT '应收账款'    AS ITEM_NAME
           , 1            AS SEQ
           , '1122000000' AS CONTO20
           , '1122000000' AS CONTO10
    FROM   DUAL
    UNION ALL
    SELECT '其他应收款'  AS ITEM_NAME
           , 2            AS SEQ
           , '122101F'    AS CONTO20
           , '122101F'    AS CONTO10
    FROM   DUAL
    UNION ALL
    SELECT '合同资产'    AS ITEM_NAME
           , 3            AS SEQ
           , '1460000000' AS CONTO20
           , '1460000000' AS CONTO10
    FROM   DUAL
),
/* 2.0原始业务范围内的公司/客商键，空客商统一为占位值 */
T20_BASE AS (
    SELECT A.COD_AZIENDA AS COMPANY_CODE
           , NVL(LTRIM(A.CUST_CODE, '0'), '(NO_CUST)') AS CUST_CODE
           , MAX(A.CUST_NAME) AS CUST_NAME
           , A.COD_CONTO
           , A.BD_0_AMT
    FROM   AW_MR9_ARPM02_000001 A
    WHERE  A.COD_SCENARIO  = ${$Scenario.code}
      AND  A.COD_PERIODO   = ${$Period.code}
      AND  A.COD_CATEGORIA = 'ZAMOUNT'
      AND  A.COD_AZIENDA   IN (${$Entity.code})
      AND  A.COD_CONTO     IN ('1122000000', '122101F', '1460000000')
    GROUP  BY A.COD_AZIENDA
              , NVL(LTRIM(A.CUST_CODE, '0'), '(NO_CUST)')
              , A.COD_CONTO
              , A.BD_0_AMT
),
/* 1.0原始业务范围内的公司/客商键，空客商统一为占位值 */
T10_BASE AS (
    SELECT T.BUKRS AS COMPANY_CODE
           , NVL(LTRIM(T.CVCODE, '0'), '(NO_CUST)') AS CUST_CODE
           , MAX(T.CVNAME) AS CUST_NAME
           , T.HKONT
           , T.HZYE
    FROM   TGK_GB_HISENSE.ZTAB_AG_TF_OC T
    WHERE  T.YEARMONTH = SUBSTR(${$Scenario.code}, 1, 4) || ${$Period.code}
      AND  T.BUKRS     IN (${$Entity.code})
      AND  T.HKONT     IN ('1122000000', '122101F', '1460000000')
    GROUP  BY T.BUKRS
              , NVL(LTRIM(T.CVCODE, '0'), '(NO_CUST)')
              , T.HKONT
              , T.HZYE
),
/* 两套业务数据中的公司/客商并集；ITM无公司/客商字段，不能脱离此范围生成行 */
CUST_DIM AS (
    SELECT COMPANY_CODE
           , CUST_CODE
           , MAX(CUST_NAME) AS CUST_NAME
    FROM   (
               SELECT COMPANY_CODE
                      , CUST_CODE
                      , CUST_NAME
               FROM   T20_BASE
               UNION ALL
               SELECT COMPANY_CODE
                      , CUST_CODE
                      , CUST_NAME
               FROM   T10_BASE
           ) K
    GROUP  BY COMPANY_CODE
              , CUST_CODE
),
/* 公司/客商键分别关联ITM三行，形成T20/T10内部FULL JOIN的补齐侧 */
CUST_ITM AS (
    SELECT C.COMPANY_CODE
           , C.CUST_CODE
           , C.CUST_NAME
           , I.SEQ
           , I.ITEM_NAME
    FROM   CUST_DIM C
           INNER JOIN ITM I
                   ON I.SEQ = 1
    UNION ALL
    SELECT C.COMPANY_CODE
           , C.CUST_CODE
           , C.CUST_NAME
           , I.SEQ
           , I.ITEM_NAME
    FROM   CUST_DIM C
           INNER JOIN ITM I
                   ON I.SEQ = 2
    UNION ALL
    SELECT C.COMPANY_CODE
           , C.CUST_CODE
           , C.CUST_NAME
           , I.SEQ
           , I.ITEM_NAME
    FROM   CUST_DIM C
           INNER JOIN ITM I
                   ON I.SEQ = 3
),
/* 2.0业务金额按公司+科目大类+客商汇总 */
T20_DATA AS (
    SELECT A.COMPANY_CODE
           , I.SEQ       AS ITEM_SEQ
           , I.ITEM_NAME AS ITEM_NAME
           , A.CUST_CODE
           , MAX(A.CUST_NAME) AS CUST_NAME
           , SUM(A.BD_0_AMT) AS AMT_20
    FROM   T20_BASE A
           INNER JOIN ITM I
                   ON I.CONTO20 = A.COD_CONTO
    GROUP  BY A.COMPANY_CODE
              , I.SEQ
              , I.ITEM_NAME
              , A.CUST_CODE
),
/* 2.0内部以ITM三科目为补齐侧；缺失合同资产金额固定为0 */
T20 AS (
    SELECT COALESCE(K.COMPANY_CODE, D.COMPANY_CODE) AS COMPANY_CODE
           , COALESCE(K.SEQ, D.ITEM_SEQ)            AS ITEM_SEQ
           , COALESCE(K.ITEM_NAME, D.ITEM_NAME)     AS ITEM_NAME
           , COALESCE(K.CUST_CODE, D.CUST_CODE)     AS CUST_CODE
           , COALESCE(K.CUST_NAME, D.CUST_NAME)     AS CUST_NAME
           , NVL(D.AMT_20, 0)                        AS AMT_20
    FROM   CUST_ITM K
           FULL JOIN T20_DATA D
                      ON  D.COMPANY_CODE = K.COMPANY_CODE
                      AND D.CUST_CODE    = K.CUST_CODE
                      AND D.ITEM_SEQ     = K.SEQ
),
/* 1.0业务金额按公司+科目大类+客商汇总 */
T10_DATA AS (
    SELECT A.COMPANY_CODE
           , I.SEQ       AS ITEM_SEQ
           , I.ITEM_NAME AS ITEM_NAME
           , A.CUST_CODE
           , MAX(A.CUST_NAME) AS CUST_NAME
           , SUM(A.HZYE) AS AMT_10
    FROM   T10_BASE A
           INNER JOIN ITM I
                   ON I.CONTO10 = A.HKONT
    GROUP  BY A.COMPANY_CODE
              , I.SEQ
              , I.ITEM_NAME
              , A.CUST_CODE
),
/* 1.0内部以ITM三科目为补齐侧；缺失合同资产金额固定为0 */
T10 AS (
    SELECT COALESCE(K.COMPANY_CODE, D.COMPANY_CODE) AS COMPANY_CODE
           , COALESCE(K.SEQ, D.ITEM_SEQ)            AS ITEM_SEQ
           , COALESCE(K.ITEM_NAME, D.ITEM_NAME)     AS ITEM_NAME
           , COALESCE(K.CUST_CODE, D.CUST_CODE)     AS CUST_CODE
           , COALESCE(K.CUST_NAME, D.CUST_NAME)     AS CUST_NAME
           , NVL(D.AMT_10, 0)                        AS AMT_10
    FROM   CUST_ITM K
           FULL JOIN T10_DATA D
                      ON  D.COMPANY_CODE = K.COMPANY_CODE
                      AND D.CUST_CODE    = K.CUST_CODE
                      AND D.ITEM_SEQ     = K.SEQ
),
/* 两套系统按公司+科目大类+客商合并；补齐职责已由各自内部FULL JOIN完成 */
T20_T10 AS (
    SELECT COALESCE(T20.COMPANY_CODE, T10.COMPANY_CODE) AS COMPANY_CODE
           , COALESCE(T20.ITEM_SEQ, T10.ITEM_SEQ)       AS ITEM_SEQ
           , COALESCE(T20.ITEM_NAME, T10.ITEM_NAME)     AS ITEM_NAME
           , COALESCE(T20.CUST_CODE, T10.CUST_CODE)     AS CUST_CODE
           , COALESCE(T20.CUST_NAME, T10.CUST_NAME)     AS CUST_NAME
           , NVL(T20.AMT_20, 0)                         AS AMT_20
           , NVL(T10.AMT_10, 0)                         AS AMT_10
    FROM   T20
           FULL JOIN T10
                      ON  T10.COMPANY_CODE = T20.COMPANY_CODE
                      AND T10.ITEM_SEQ     = T20.ITEM_SEQ
                      AND T10.CUST_CODE    = T20.CUST_CODE
)
SELECT COMPANY_CODE                         AS COMPANY_CODE  /* 公司 */
       , ITEM_NAME                          AS ITEM_NAME     /* 往来项目 */
       , CUST_CODE                          AS CUST_CODE     /* 客商编码 */
       , CUST_NAME                          AS CUST_NAME     /* 客商名称 */
       , AMT_20                             AS AMT_20        /* 2.0坏账计提金额 */
       , AMT_10                             AS AMT_10        /* 1.0坏账余额 */
       , AMT_20 - AMT_10                     AS AMT_DIFF     /* 差异（2.0减1.0） */
FROM   T20_T10
ORDER  BY COMPANY_CODE
          , ITEM_SEQ
          , CUST_CODE