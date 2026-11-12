/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261112 17:38
 * 本次修改：ALTER BY 20261112 17:38 SHIQINGFENG.EX 新建整体口径周转天数检查查询。
 * 上次修改：无（新建）。
 *
 * 查询名称  ：应收周转展示表-整体-指标周转天数检查
 * 源表      ：AW_MR7_ARPA01_000001、TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261112 17:38 SHIQINGFENG.EX 新建整体口径周转天数检查查询。
 *******************************************************************************/
SELECT T.COD_SCENARIO                                                          /* 场景 */
     , T.COD_PERIODO                                                           /* 期间 */
     , T.D_BG                                                                  /* 事业部 */
     , F_TGK_GET_DIMNAME('D_BG', NVL(T.D_BG, 'ZZZZ')) AS D_BG_DESC             /* 事业部名称 */
     , T.COD_CONTO                                                             /* 科目 */
     , T.COD_AZIENDA                                                           /* 公司 */
     , T.D_GRAN_CAL                                                            /* 颗粒度口径 */
     , CASE T.D_GRAN_CAL
            WHEN 'ARTO_ALL'  THEN '整体'
            WHEN 'ARTO_CUST' THEN '客商'
            ELSE T.D_GRAN_CAL
       END AS D_GRAN_CAL_DESC                                                  /* 颗粒度口径名称 */
     , T.COD_CATEGORIA                                                         /* 类别 */
     , G.COD_ELEGER6 AS COD_ELEGER6                                            /* 公司一级分类编码 */
     , G.DESC_ELEGER6 AS DESC_ELEGER6                                          /* 公司一级分类描述 */
     , G.COD_ELEGER5 AS COD_ELEGER5                                            /* 公司二级分类编码 */
     , G.DESC_ELEGER5 AS DESC_ELEGER5                                          /* 公司二级分类描述 */
     , T.D_CHANNEL                                                             /* 公司三级分类 */
     , F_TGK_GET_DIMNAME('D_CHANNEL', T.D_CHANNEL) AS D_CHANNEL_DESC           /* 公司三级分类名称 */
     , T.D_ONOFFLINE                                                           /* 渠道分组 */
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', NVL(T.D_ONOFFLINE, 'ZZZZ')) AS D_ONOFFLINE_DESC  /* 渠道分组名称 */
     , T.COD_DEST2                                                             /* 利润中心 */
     , F_TGK_GET_DIMNAME('DEST2', NVL(T.COD_DEST2, 'ZZZZ')) AS COD_DEST2_DESC  /* 利润中心名称 */
     , T.COD_DEST3                                                             /* 业务范围 */
     , F_TGK_GET_DIMNAME('DEST3', NVL(T.COD_DEST3, 'ZZZZ')) AS COD_DEST3_DESC  /* 业务范围名称 */
     , T.D_SALE_DEPT                                                           /* 业务管理单元 */
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', NVL(T.D_SALE_DEPT, 'ZZZZ')) AS D_SALE_DEPT_DESC  /* 业务管理单元名称 */
     , T.D_CHANNEL_BU                                                          /* 渠道BU */
     , F_TGK_GET_DIMNAME('D_CHANNEL_BU', NVL(T.D_CHANNEL_BU, 'ZZZZ')) AS D_CHANNEL_BU_DESC  /* 渠道BU名称 */
     , T.D_TOV_CHAN                                                            /* 应收周转分析渠道 */
     , F_TGK_GET_DIMNAME('D_TOV_CHAN', NVL(T.D_TOV_CHAN, 'ZZZZ')) AS D_TOV_CHAN_DESC  /* 应收周转分析渠道名称 */
     , T.D_CC_CUSTGRP                                                          /* 商冷客户群 */
     , F_TGK_GET_DIMNAME('D_CC_CUSTGRP', NVL(T.D_CC_CUSTGRP, 'ZZZZ')) AS D_CC_CUSTGRP_DESC  /* 商冷客户群名称 */
     , T.COD_VALUTA                                                            /* 货币 */
/* ==================== 周转天数：计划 / 实际 / 同期 ==================== */
     , T.PLN_MTD_TDAYS AS PLN_MTD_TDAYS                                        /* 计划当月周转天数 */
     , T.PLN_YTD_TDAYS AS PLN_YTD_TDAYS                                        /* 计划累计周转天数 */
     , T.ACT_MTD_TDAYS AS ACT_MTD_TDAYS                                        /* 实际当月周转天数 */
     , T.ACT_YTD_TDAYS AS ACT_YTD_TDAYS                                        /* 实际累计周转天数 */
     , T.LY_MTD_TDAYS AS LY_MTD_TDAYS                                          /* 同期当月周转天数 */
     , T.LY_YTD_TDAYS AS LY_YTD_TDAYS                                          /* 同期累计周转天数 */
/* ==================== 计划占用与耗用 ==================== */
     , T.PLN_BEG_OCP_AMT AS PLN_BEG_OCP_AMT                                    /* 计划-期初占用金额 */
     , T.PLN_LM_OCP_AMT AS PLN_LM_OCP_AMT                                      /* 计划-上月占用金额 */
     , T.PLN_END_OCP_AMT AS PLN_END_OCP_AMT                                    /* 计划-期末占用金额 */
     , T.PLN_YTD_OCP_AMT AS PLN_YTD_OCP_AMT                                    /* 计划-累计占用金额 */
     , T.PLN_MTD_CSM_AMT AS PLN_MTD_CSM_AMT                                    /* 计划-本月耗用金额 */
     , T.PLN_YTD_CSM_AMT AS PLN_YTD_CSM_AMT                                    /* 计划-累计耗用金额 */
/* ==================== 实际占用与耗用 ==================== */
     , T.ACT_BEG_OCP_AMT AS ACT_BEG_OCP_AMT                                    /* 实际-期初占用金额 */
     , T.ACT_LM_OCP_AMT AS ACT_LM_OCP_AMT                                      /* 实际-上月占用金额 */
     , T.ACT_END_OCP_AMT AS ACT_END_OCP_AMT                                    /* 实际-期末占用金额 */
     , T.ACT_YTD_OCP_AMT AS ACT_YTD_OCP_AMT                                    /* 实际-累计占用金额 */
     , T.ACT_MTD_CSM_AMT AS ACT_MTD_CSM_AMT                                    /* 实际-本月耗用金额 */
     , T.ACT_YTD_CSM_AMT AS ACT_YTD_CSM_AMT                                    /* 实际-累计耗用金额 */
/* ==================== 同期占用与耗用 ==================== */
     , T.LY_BEG_OCP_AMT AS LY_BEG_OCP_AMT                                      /* 同期-期初占用金额 */
     , T.LY_LM_OCP_AMT AS LY_LM_OCP_AMT                                        /* 同期-上月占用金额 */
     , T.LY_END_OCP_AMT AS LY_END_OCP_AMT                                      /* 同期-期末占用金额 */
     , T.LY_YTD_OCP_AMT AS LY_YTD_OCP_AMT                                      /* 同期-累计占用金额 */
     , T.LY_MTD_CSM_AMT AS LY_MTD_CSM_AMT                                      /* 同期-本月耗用金额 */
     , T.LY_YTD_CSM_AMT AS LY_YTD_CSM_AMT                                      /* 同期-累计耗用金额 */
  FROM AW_MR7_ARPA01_000001 T
/* 渠道层级扁平视图：按公司三级分类带出公司一级/二级分类编码及描述。 */
  LEFT JOIN TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT G
    ON G.COD = T.D_CHANNEL
   AND G.COD_GERARCHIA = '01'
 WHERE T.COD_SCENARIO = ${$Scenario.code}
   AND T.COD_PERIODO = ${$Period.code}
   /* 事业部由报表参数传入，多值参数保留 IN 写法。 */
   AND T.D_BG IN (${$ANL_D_BG.code})
   /* 只取整体口径：ARTO_ALL 由周转计算配置汇总后单独写入，与客商口径 ARTO_CUST 分行存放。 */
   AND T.D_GRAN_CAL = 'ARTO_ALL'
 ORDER BY T.COD_AZIENDA
        , T.COD_CONTO
        , T.COD_CATEGORIA
