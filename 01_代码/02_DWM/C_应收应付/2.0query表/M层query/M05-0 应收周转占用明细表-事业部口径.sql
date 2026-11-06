/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261103 14:08
 * 本次修改：ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。
 * 上次修改：ALTER BY 20261103 11:49 SHIQINGFENG.EX 补充公司一级、二级分类编码及描述，D_CHANNEL作为公司三级分类，统一渠道层级视图来源，未修改金额和过滤逻辑。
 *
 * 查询名称  ：应收周转占用明细表-事业部口径
 * 源表      ：AW_MR9_ARPM03_000001、TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT、TGK_FIMA_HISENSE.DEST3_GERARCHIA_FLAT 等，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。
 *   ALTER BY 20261103 11:49 SHIQINGFENG.EX 补充公司一级、二级分类编码及描述，D_CHANNEL作为公司三级分类，统一渠道层级视图来源，未修改金额和过滤逻辑。
 *   ALTER BY 20261102 20:30 SHIQINGFENG.EX 统一字段别名 AS 写法，CASE 按 WHEN/ELSE 同列、THEN 对齐 WHEN 末字母、条件续行 AND 对齐 WHEN 末字母分行，并对齐行尾注释列，未修改业务逻辑。
 *   ALTER BY 20261102 18:56 SHIQINGFENG.EX 按 SQL 编码规范统一右对齐：FROM/JOIN 组关键字右端对齐（CROSS JOIN 顶格）、OR/ON 右对齐、WHERE 嵌套条件分层、CASE 表达式 WHEN/THEN/ELSE/END 分行，未修改业务逻辑。
 *   ALTER BY 20261102 17:36 SHIQINGFENG.EX 按规范补查询说明文件头（查询名称+源表），未修改业务主体。
 *******************************************************************************/
WITH
/* 单次扫表: 本年 01~当月 + 上年 01~当月 + 上年 12月
 is_prior 标记该行是否来自上年场景, 后续 CASE 用它代替反复写上年场景表达式 */
BASE AS (
 SELECT T.COD_SCENARIO, T.COD_PERIODO, T.D_BG, T.COD_AZIENDA,
    T.CUST_CODE, T.CUST_NAME, T.CUST_HEAD_CODE, T.CUST_HEAD_NAME,
    T.CUST_BRANCH_CODE, T.CUST_BRANCH_NAME, T.GRP_SCOPE, T.COD_AZI_CTP,
    T.COUNTRY_NAME, T.NATURE_L2_NAME,
    T.D_CHANNEL, T.D_ONOFFLINE, T.COD_DEST2, T.COD_DEST3, T.D_SALE_DEPT,
    T.D_CHANNEL_BU, T.D_CC_CUSTGRP, T.COD_VALUTA,
    T.AR_AMT, T.F1_ODUE_AMT, T.F2_EPAY_AMT, T.F3_ECR_AMT,
    T.F4_UREB_AMT, T.F5_UFEE_AMT, T.F6_INVSM_AMT, T.F7_GSUB_AMT, T.F8_ADJ_AMT,
    T.DATEUPD, T.USERUPD,
    CASE
      WHEN T.COD_SCENARIO = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code},1,4))-1) || SUBSTR(${$Scenario.code},5)
        THEN 'Y'
      ELSE 'N'
    END AS IS_PRIOR
   FROM AW_MR9_ARPM03_000001 T
  WHERE T.D_BG = ${$ANL_D_BG.code}
    AND T.COD_CATEGORIA = 'ZAMOUNT'
    AND (
          (T.COD_SCENARIO = ${$Scenario.code}
           AND T.COD_PERIODO BETWEEN '01' AND ${$Period.code})
          OR
          (T.COD_SCENARIO = TO_CHAR(TO_NUMBER(SUBSTR(${$Scenario.code},1,4))-1)
           || SUBSTR(${$Scenario.code},5)
           AND (T.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                 OR T.COD_PERIODO = '12'))
        )
)
SELECT
 /* 场景 / 期间 */
       ${$Scenario.code}                   AS COD_SCENARIO                       /* 场景 */
     , ${$Period.code}                    AS COD_PERIODO                         /* 期间 */
 /* 业务组 */
     , B.D_BG                                                                    /* 事业部编码 */
     , F_TGK_GET_DIMNAME('D_BG', B.D_BG)           AS D_BG_DESC                  /* 事业部名称 */
 /* 公司 / 客户 */
     , B.COD_AZIENDA                                                             /* 公司 */
     , B.CUST_CODE                                                               /* 客商编码 */
     , MAX(CASE WHEN B.COD_PERIODO = ${$Period.code} THEN B.CUST_NAME    END) AS CUST_NAME  /* 客商名称 */
     , B.CUST_HEAD_CODE                                                          /* 主户编码 */
     , MAX(CASE WHEN B.COD_PERIODO = ${$Period.code} THEN B.CUST_HEAD_NAME  END) AS CUST_HEAD_NAME  /* 主户名称 */
     , B.CUST_BRANCH_CODE                                                        /* 分户编码 */
     , MAX(CASE WHEN B.COD_PERIODO = ${$Period.code} THEN B.CUST_BRANCH_NAME END) AS CUST_BRANCH_NAME  /* 分户名称 */
     , B.GRP_SCOPE                                                               /* 集团归属范围 */
     , B.COD_AZI_CTP                                                             /* 对方公司 */
     , MAX(CASE WHEN B.COD_PERIODO = ${$Period.code} THEN B.COUNTRY_NAME   END) AS COUNTRY_NAME  /* 国家名称 */
     , MAX(CASE WHEN B.COD_PERIODO = ${$Period.code} THEN B.NATURE_L2_NAME  END) AS NATURE_L2_NAME  /* 二级性质 */
 /* ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。 */
 /* 公司分类层级: D_CHANNEL为公司三级分类，E6为一级分类，E5为二级分类。 */
     , G.COD_ELEGER6                     AS COD_ELEGER6                          /* 公司一级分类编码 */
     , G.DESC_ELEGER6                   AS DESC_ELEGER6                        /* 公司一级分类描述 */
     , G.COD_ELEGER5                     AS COD_ELEGER5                          /* 公司二级分类编码 */
     , G.DESC_ELEGER5                   AS DESC_ELEGER5                        /* 公司二级分类描述 */
     , G.COD_ELEGER7                     AS COD_ELEGER7                          /* 渠道7级编码 */
     , G.DESC_ELEGER7                   AS DESC_ELEGER7                        /* 渠道7级名称 */
 /* 渠道 */
     , B.D_CHANNEL                                                               /* 三级公司分类编码 */
     , F_TGK_GET_DIMNAME('D_CHANNEL', B.D_CHANNEL)      AS D_CHANNEL_DESC        /* 三级公司分类名称 */
 /* 线上线下 */
     , B.D_ONOFFLINE                                                             /* 渠道分组编码 */
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', B.D_ONOFFLINE)    AS D_ONOFFLINE_DESC    /* 渠道分组名称 */
 /* DEST2 */
     , B.COD_DEST2                                                               /* 利润中心编码 */
     , F_TGK_GET_DIMNAME('DEST2', B.COD_DEST2)        AS COD_DEST2_DESC          /* 利润中心名称 */
 /* DEST3 */
     , B.COD_DEST3                                                               /* 业务范围编码 */
     , F_TGK_GET_DIMNAME('DEST3', B.COD_DEST3)        AS COD_DEST3_DESC          /* 业务范围名称 */
 /* 销售部门 */
     , B.D_SALE_DEPT                                                             /* 业务管理单元编码 */
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', B.D_SALE_DEPT)    AS D_SALE_DEPT_DESC    /* 业务管理单元名称 */
 /* 渠道BU */
     , B.D_CHANNEL_BU                                                            /* 渠道BU编码 */
     , F_TGK_GET_DIMNAME('D_CHANNEL_BU', B.D_CHANNEL_BU)     AS D_TOV_CHAN_DESC  /* 渠道BU名称 */
 /* CC 客户组 */
     , B.D_CC_CUSTGRP                                                            /* 商冷客户群 */
     , F_TGK_GET_DIMNAME('D_CC_CUSTGRP', B.D_CC_CUSTGRP)   AS D_CC_CUSTGRP_DESC  /* 商冷客户群名称 */
 /* 币种 */
     , B.COD_VALUTA                                                              /* 本位币币种 */
 /* DEST3 层级描述: 4级优先, 无则取 5级 */
     , NVL(DEST3_GERARCHIA_FLAT.DESC_DEST3_ELEGER4,
   DEST3_GERARCHIA_FLAT.DESC_DEST3_ELEGER5)      AS DESC_DEST3_ELEGER4           /* 业务范围4级名称 */

 /* ================================================================
  第一组: 本期(当月)金额
  顺序与原代码一致: AR -> F1..F8; LY_AR_AMT 紧随 AR
  ================================================================ */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.AR_AMT
               END), 0)           AS AR_AMT                                      /* 期末应收账款占用 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'Y' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.AR_AMT
               END), 0)           AS LY_AR_AMT                                   /* 上年同期期末应收占用 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.F1_ODUE_AMT
               END), 0)        AS F1_ODUE_AMT                                    /* 因素1-超期款金额 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.F2_EPAY_AMT
               END), 0)        AS F2_EPAY_AMT                                    /* 因素2-提前回款金额 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.F3_ECR_AMT
               END), 0)         AS F3_ECR_AMT                                    /* 因素3-电商零售销售节奏 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.F4_UREB_AMT
               END), 0)        AS F4_UREB_AMT                                    /* 因素4-已确认未兑现返利余额 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.F5_UFEE_AMT
               END), 0)        AS F5_UFEE_AMT                                    /* 因素5-已账扣未报账的欠付费用 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.F6_INVSM_AMT
               END), 0)        AS F6_INVSM_AMT                                   /* 因素6-开票样机额度 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.F7_GSUB_AMT
               END), 0)        AS F7_GSUB_AMT                                    /* 因素7-国补未回款影响金额 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO = ${$Period.code}
                   THEN B.F8_ADJ_AMT
               END), 0)         AS F8_ADJ_AMT                                    /* 因素8手工导入因素 */

 /* ================================================================
  第二组: 本年累计金额
  与第一组一一对应
  YTD_AR_AMT = 本年01~当月 SUM
  YTD_其余  = 本年01~当月 SUM
  ================================================================ */
     , NVL(SUM(CASE
             WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
               THEN B.AR_AMT
           END), 0)              AS YTD_AR_AMT                                   /* 本年累计期末应收占用 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'Y' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                   THEN B.AR_AMT
               END), 0)           AS YTD_LY_AR_AMT                               /* 上年同期累计应收占用 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                   THEN B.F1_ODUE_AMT
               END), 0)        AS YTD_F1_ODUE_AMT                                /* 累计因素1-超期款 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                   THEN B.F2_EPAY_AMT
               END), 0)        AS YTD_F2_EPAY_AMT                                /* 累计因素2-提前回款 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                   THEN B.F3_ECR_AMT
               END), 0)         AS YTD_F3_ECR_AMT                                /* 累计因素3-电商零售节奏 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                   THEN B.F4_UREB_AMT
               END), 0)        AS YTD_F4_UREB_AMT                                /* 累计因素4-未兑现返利余额 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                   THEN B.F5_UFEE_AMT
               END), 0)        AS YTD_F5_UFEE_AMT                                /* 累计因素5-欠付费用 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                   THEN B.F6_INVSM_AMT
               END), 0)        AS YTD_F6_INVSM_AMT                               /* 累计因素6-开票样机额度 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                   THEN B.F7_GSUB_AMT
               END), 0)        AS YTD_F7_GSUB_AMT                                /* 累计因素7-国补未回款 */
     , NVL(SUM(CASE
                 WHEN B.IS_PRIOR = 'N' AND B.COD_PERIODO BETWEEN '01' AND ${$Period.code}
                   THEN B.F8_ADJ_AMT
               END), 0)         AS YTD_F8_ADJ_AMT                                /* 累计因素8-手工导入 */
 /* 更新信息 */
     , MAX(CASE WHEN B.COD_PERIODO = ${$Period.code} THEN B.DATEUPD END) AS DATEUPD /* 更新时间 */
     , MAX(CASE WHEN B.COD_PERIODO = ${$Period.code} THEN B.USERUPD END) AS USERUPD /* 更新用户 */

  FROM BASE B
/* 渠道层级扁平表 */
  LEFT JOIN TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT G
    ON G.COD = B.D_CHANNEL
   AND G.COD_GERARCHIA = '01'
/* DEST3 层级扁平表 (hie = '01' 切片) */
  LEFT JOIN (
 SELECT COD_DEST3, DESC_DEST3_ELEGER3, DESC_DEST3_ELEGER4, DESC_DEST3_ELEGER5
   FROM DEST3_GERARCHIA_FLAT
  WHERE COD_DEST3_GERARCHIA = '01'
) DEST3_GERARCHIA_FLAT
    ON DEST3_GERARCHIA_FLAT.COD_DEST3 = B.COD_DEST3
 GROUP BY
        B.COD_AZIENDA, B.D_BG, B.CUST_CODE, B.CUST_HEAD_CODE, B.CUST_BRANCH_CODE
        , B.GRP_SCOPE, B.COD_AZI_CTP
        , B.D_CHANNEL, B.D_ONOFFLINE, B.COD_DEST2, B.COD_DEST3, B.D_SALE_DEPT
        , B.D_CHANNEL_BU, B.D_CC_CUSTGRP, B.COD_VALUTA
        , G.COD_ELEGER6, G.DESC_ELEGER6, G.COD_ELEGER5, G.DESC_ELEGER5
        , G.COD_ELEGER7, G.DESC_ELEGER7
        , DEST3_GERARCHIA_FLAT.DESC_DEST3_ELEGER4, DEST3_GERARCHIA_FLAT.DESC_DEST3_ELEGER5

