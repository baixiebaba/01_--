WITH
/* 单次扫表: 本年 01~当月 + 上年 01~当月 + 上年 12月
 is_prior 标记该行是否来自上年场景, 后续 CASE 用它代替反复写上年场景表达式 */
base AS (
 SELECT t.COD_SCENARIO, t.COD_PERIODO, t.D_BG, t.COD_AZIENDA,
    t.CUST_CODE, t.CUST_NAME, t.CUST_HEAD_CODE, t.CUST_HEAD_NAME,
    t.CUST_BRANCH_CODE, t.CUST_BRANCH_NAME, t.GRP_SCOPE, t.COD_AZI_CTP,
    t.COUNTRY_NAME, t.NATURE_L2_NAME,
    t.D_CHANNEL, t.D_ONOFFLINE, t.COD_DEST2, t.COD_DEST3, t.D_SALE_DEPT,
    t.D_TOV_CHAN, t.D_CC_CUSTGRP, t.COD_VALUTA,
    t.AR_AMT, t.F1_ODUE_AMT, t.F2_EPAY_AMT, t.F3_ECR_AMT,
    t.F4_UREB_AMT, t.F5_UFEE_AMT, t.F6_INVSM_AMT, t.F7_GSUB_AMT, t.F8_ADJ_AMT,
    t.DATEUPD, t.USERUPD,
    CASE WHEN t.COD_SCENARIO = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code},1,4))-1)
                  || SUBSTR(${$Scenario.code},5)
       THEN 'Y' ELSE 'N' END AS is_prior
 FROM AW_MR9_ARPM03_000001 t
 WHERE t.D_BG     = ${$ANL_D_BG.code}
  AND t.COD_CATEGORIA = 'ZAMOUNT'
  AND (
   (t.COD_SCENARIO = ${$Scenario.code}
   AND t.COD_PERIODO BETWEEN '01' AND ${$Period.code})
   OR
   (t.COD_SCENARIO = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code},1,4))-1)
             || SUBSTR(${$Scenario.code},5)
   AND (t.COD_PERIODO BETWEEN '01' AND ${$Period.code}
      OR t.COD_PERIODO = '12'))
  )
)
SELECT
 /* 场景 / 期间 */
 ${$Scenario.code}                   AS COD_SCENARIO
 ,${$Period.code}                    AS COD_PERIODO
 /* 业务组 */
 ,b.D_BG
 ,f_tgk_get_dimname('D_BG', b.D_BG)           AS D_BG_DESC
 /* 公司 / 客户 */
 ,b.COD_AZIENDA
 ,b.CUST_CODE
 ,MAX(CASE WHEN b.COD_PERIODO = ${$Period.code} THEN b.CUST_NAME    END) AS CUST_NAME
 ,b.CUST_HEAD_CODE
 ,MAX(CASE WHEN b.COD_PERIODO = ${$Period.code} THEN b.CUST_HEAD_NAME  END) AS CUST_HEAD_NAME
 ,b.CUST_BRANCH_CODE
 ,MAX(CASE WHEN b.COD_PERIODO = ${$Period.code} THEN b.CUST_BRANCH_NAME END) AS CUST_BRANCH_NAME
 ,b.GRP_SCOPE
 ,b.COD_AZI_CTP
 ,MAX(CASE WHEN b.COD_PERIODO = ${$Period.code} THEN b.COUNTRY_NAME   END) AS COUNTRY_NAME
 ,MAX(CASE WHEN b.COD_PERIODO = ${$Period.code} THEN b.NATURE_L2_NAME  END) AS NATURE_L2_NAME
 /* 渠道层级: 6级 -> COD_ELEGER6 / DESC_ELEGER6, 7级 -> COD_ELEGER7 / DESC_ELEGER7 */
 ,g.COD_ELEGER6                     AS COD_ELEGER6
 ,g.DESC_ELEGER6                     AS DESC_ELEGER6
 ,g.COD_ELEGER7                     AS COD_ELEGER7
 ,g.DESC_ELEGER7                     AS DESC_ELEGER7
 /* 渠道 */
 ,b.D_CHANNEL
 ,f_tgk_get_dimname('D_CHANNEL', b.D_CHANNEL)      AS D_CHANNEL_DESC
 /* 线上线下 */
 ,b.D_ONOFFLINE
 ,f_tgk_get_dimname('D_ONOFFLINE', b.D_ONOFFLINE)    AS D_ONOFFLINE_DESC
 /* DEST2 */
 ,b.COD_DEST2
 ,f_tgk_get_dimname('DEST2', b.COD_DEST2)        AS COD_DEST2_DESC
 /* DEST3 */
 ,b.COD_DEST3
 ,f_tgk_get_dimname('DEST3', b.COD_DEST3)        AS COD_DEST3_DESC
 /* 销售部门 */
 ,b.D_SALE_DEPT
 ,f_tgk_get_dimname('D_SALE_DEPT', b.D_SALE_DEPT)    AS D_SALE_DEPT_DESC
 /* TOV 渠道 */
 ,b.D_TOV_CHAN
 ,f_tgk_get_dimname('D_TOV_CHAN', b.D_TOV_CHAN)     AS D_TOV_CHAN_DESC
 /* CC 客户组 */
 ,b.D_CC_CUSTGRP
 ,f_tgk_get_dimname('D_CC_CUSTGRP', b.D_CC_CUSTGRP)   AS D_CC_CUSTGRP_DESC
 /* 币种 */
 ,b.COD_VALUTA
 /* DEST3 层级描述: 4级优先, 无则取 5级 */
 ,NVL(DEST3_GERARCHIA_FLAT.DESC_DEST3_ELEGER4,
   DEST3_GERARCHIA_FLAT.DESC_DEST3_ELEGER5)      AS DESC_DEST3_ELEGER4

 /* ================================================================
  第一组: 本期(当月)金额
  顺序与原代码一致: AR -> F1..F8; LY_AR_AMT 紧随 AR
  ================================================================ */
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO = ${$Period.code}
        THEN b.AR_AMT END), 0)           AS AR_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'Y' AND b.COD_PERIODO = ${$Period.code}
        THEN b.AR_AMT END), 0)           AS LY_AR_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO = ${$Period.code}
        THEN b.F1_ODUE_AMT END), 0)        AS F1_ODUE_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO = ${$Period.code}
        THEN b.F2_EPAY_AMT END), 0)        AS F2_EPAY_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO = ${$Period.code}
        THEN b.F3_ECR_AMT END), 0)         AS F3_ECR_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO = ${$Period.code}
        THEN b.F4_UREB_AMT END), 0)        AS F4_UREB_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO = ${$Period.code}
        THEN b.F5_UFEE_AMT END), 0)        AS F5_UFEE_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO = ${$Period.code}
        THEN b.F6_INVSM_AMT END), 0)        AS F6_INVSM_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO = ${$Period.code}
        THEN b.F7_GSUB_AMT END), 0)        AS F7_GSUB_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO = ${$Period.code}
        THEN b.F8_ADJ_AMT END), 0)         AS F8_ADJ_AMT

 /* ================================================================
  第二组: 本年累计金额
  与第一组一一对应
  YTD_AR_AMT = 上年12月/2 + 本年01~当月 SUM - 当月/2
  YTD_其余  = 本年01~当月 SUM
  ================================================================ */
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.AR_AMT END), 0)         AS YTD_AR_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'Y' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.AR_AMT END), 0)           AS YTD_LY_AR_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.F1_ODUE_AMT END), 0)        AS YTD_F1_ODUE_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.F2_EPAY_AMT END), 0)        AS YTD_F2_EPAY_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.F3_ECR_AMT END), 0)         AS YTD_F3_ECR_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.F4_UREB_AMT END), 0)        AS YTD_F4_UREB_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.F5_UFEE_AMT END), 0)        AS YTD_F5_UFEE_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.F6_INVSM_AMT END), 0)        AS YTD_F6_INVSM_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.F7_GSUB_AMT END), 0)        AS YTD_F7_GSUB_AMT
 ,NVL(SUM(CASE WHEN b.is_prior = 'N' AND b.COD_PERIODO BETWEEN '01' AND ${$Period.code}
        THEN b.F8_ADJ_AMT END), 0)         AS YTD_F8_ADJ_AMT
 /* 更新信息 */
 ,MAX(CASE WHEN b.COD_PERIODO = ${$Period.code} THEN b.DATEUPD END) AS DATEUPD
 ,MAX(CASE WHEN b.COD_PERIODO = ${$Period.code} THEN b.USERUPD END) AS USERUPD

FROM base b
/* 渠道层级扁平表 */
LEFT JOIN ED_D_CHANNEL_GERARCHIA_FLAT g
 ON g.COD = b.D_CHANNEL
/* DEST3 层级扁平表 (hie = '01' 切片) */
LEFT JOIN (
 SELECT COD_DEST3, DESC_DEST3_ELEGER3, DESC_DEST3_ELEGER4, DESC_DEST3_ELEGER5
 FROM  DEST3_GERARCHIA_FLAT
 WHERE COD_DEST3_GERARCHIA = '01'
) DEST3_GERARCHIA_FLAT
 ON DEST3_GERARCHIA_FLAT.COD_DEST3 = b.COD_DEST3
GROUP BY
  b.COD_AZIENDA, b.D_BG, b.CUST_CODE, b.CUST_HEAD_CODE, b.CUST_BRANCH_CODE
 ,b.GRP_SCOPE, b.COD_AZI_CTP
 ,b.D_CHANNEL, b.D_ONOFFLINE, b.COD_DEST2, b.COD_DEST3, b.D_SALE_DEPT
 ,b.D_TOV_CHAN, b.D_CC_CUSTGRP, b.COD_VALUTA
 ,g.COD_ELEGER6, g.DESC_ELEGER6, g.COD_ELEGER7, g.DESC_ELEGER7
 ,DEST3_GERARCHIA_FLAT.DESC_DEST3_ELEGER4, DEST3_GERARCHIA_FLAT.DESC_DEST3_ELEGER5
