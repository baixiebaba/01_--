/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261103 14:08
 * 本次修改：ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。
 * 上次修改：ALTER BY 20261103 11:49 SHIQINGFENG.EX 补充公司一级、二级分类编码及描述，D_CHANNEL作为公司三级分类，未修改金额和过滤逻辑。
 *
 * 查询名称  ：应收周转展示表-客商-ADS数据查询
 * 源表      ：AW_MR7_ARPA01_000001、TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。
 *   ALTER BY 20261103 11:49 SHIQINGFENG.EX 补充公司一级、二级分类编码及描述，D_CHANNEL作为公司三级分类，未修改金额和过滤逻辑。
 *******************************************************************************/
/* ==================== 维度及描述（33列） ==================== */
/* ALTER BY 20261103 11:49 SHIQINGFENG.EX 补充公司一级、二级分类编码及描述，D_CHANNEL作为公司三级分类，未修改金额和过滤逻辑。 */
SELECT T.COD_SCENARIO
     , T.COD_PERIODO
     , T.D_BG
     , F_TGK_GET_DIMNAME('D_BG', NVL(T.D_BG, 'ZZZZ')) AS D_BG_DESC
     , T.COD_AZIENDA
     , F_TGK_GET_DIMNAME('AZIENDA', NVL(T.COD_AZIENDA, 'ZZZZ')) AS COD_AZIENDA_DESC
     , T.COD_CATEGORIA
     , T.CUST_CODE
     , T.CUST_NAME
     , T.CUST_HEAD_CODE
     , T.CUST_HEAD_NAME
     , T.CUST_BRANCH_CODE
     , T.CUST_BRANCH_NAME
     , T.COD_AZI_CTP
     , G.COD_ELEGER6 AS COD_ELEGER6       /* 公司一级分类编码 */
     , G.DESC_ELEGER6 AS DESC_ELEGER6   /* 公司一级分类描述 */
     , G.COD_ELEGER5 AS COD_ELEGER5       /* 公司二级分类编码 */
     , G.DESC_ELEGER5 AS DESC_ELEGER5   /* 公司二级分类描述 */
     , T.D_CHANNEL
     , F_TGK_GET_DIMNAME('D_CHANNEL', NVL(T.D_CHANNEL, 'ZZZZ')) AS D_CHANNEL_DESC
     , T.D_ONOFFLINE
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', NVL(T.D_ONOFFLINE, 'ZZZZ')) AS D_ONOFFLINE_DESC
     , T.COD_DEST2
     , F_TGK_GET_DIMNAME('DEST2', NVL(T.COD_DEST2, 'ZZZZ')) AS COD_DEST2_DESC
     , T.COD_DEST3
     , F_TGK_GET_DIMNAME('DEST3', NVL(T.COD_DEST3, 'ZZZZ')) AS COD_DEST3_DESC
     , T.D_SALE_DEPT
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', NVL(T.D_SALE_DEPT, 'ZZZZ')) AS D_SALE_DEPT_DESC
     , T.D_CHANNEL_BU
     , F_TGK_GET_DIMNAME('D_CHANNEL_BU', NVL(T.D_CHANNEL_BU, 'ZZZZ')) AS D_TOV_CHAN_DESC
     , T.D_CC_CUSTGRP
     , F_TGK_GET_DIMNAME('D_CC_CUSTGRP', NVL(T.D_CC_CUSTGRP, 'ZZZZ')) AS D_CC_CUSTGRP_DESC
     , T.COD_VALUTA
/* ==================== 计划 PLN（6列） ==================== */
     , T.PLN_BEG_OCP_AMT
     , T.PLN_LM_OCP_AMT
     , T.PLN_END_OCP_AMT
     , T.PLN_YTD_OCP_AMT
     , T.PLN_MTD_CSM_AMT
     , T.PLN_YTD_CSM_AMT
/* ==================== 实际当月 ACT（6列） ==================== */
     , T.ACT_BEG_OCP_AMT
     , T.ACT_LM_OCP_AMT
     , T.ACT_END_OCP_AMT
     , T.ACT_YTD_OCP_AMT
     , T.ACT_MTD_CSM_AMT
     , T.ACT_YTD_CSM_AMT
/* ==================== 同期 LY（6列） ==================== */
     , T.LY_BEG_OCP_AMT
     , T.LY_LM_OCP_AMT
     , T.LY_END_OCP_AMT
     , T.LY_YTD_OCP_AMT
     , T.LY_MTD_CSM_AMT
     , T.LY_YTD_CSM_AMT
/* ==================== 因素1：ODUE超期款（8列=实际/同期、期初/上月/期末/累计） ==================== */
     , T.ACT_BEG_F1_ODUE_AMT
     , T.ACT_LM_F1_ODUE_AMT
     , T.ACT_END_F1_ODUE_AMT
     , T.ACT_YTD_F1_ODUE_AMT
     , T.LY_BEG_F1_ODUE_AMT
     , T.LY_LM_F1_ODUE_AMT
     , T.LY_END_F1_ODUE_AMT
     , T.LY_YTD_F1_ODUE_AMT
/* ==================== 因素2：EPAY提前回款（8列=实际/同期、期初/上月/期末/累计） ==================== */
     , T.ACT_BEG_F2_EPAY_AMT
     , T.ACT_LM_F2_EPAY_AMT
     , T.ACT_END_F2_EPAY_AMT
     , T.ACT_YTD_F2_EPAY_AMT
     , T.LY_BEG_F2_EPAY_AMT
     , T.LY_LM_F2_EPAY_AMT
     , T.LY_END_F2_EPAY_AMT
     , T.LY_YTD_F2_EPAY_AMT
/* ==================== 因素3：ECR电商零售销售节奏（8列=实际/同期、期初/上月/期末/累计） ==================== */
     , T.ACT_BEG_F3_ECR_AMT
     , T.ACT_LM_F3_ECR_AMT
     , T.ACT_END_F3_ECR_AMT
     , T.ACT_YTD_F3_ECR_AMT
     , T.LY_BEG_F3_ECR_AMT
     , T.LY_LM_F3_ECR_AMT
     , T.LY_END_F3_ECR_AMT
     , T.LY_YTD_F3_ECR_AMT
/* ==================== 因素4：UREB已确认未兑现返利（8列=实际/同期、期初/上月/期末/累计） ==================== */
     , T.ACT_BEG_F4_UREB_AMT
     , T.ACT_LM_F4_UREB_AMT
     , T.ACT_END_F4_UREB_AMT
     , T.ACT_YTD_F4_UREB_AMT
     , T.LY_BEG_F4_UREB_AMT
     , T.LY_LM_F4_UREB_AMT
     , T.LY_END_F4_UREB_AMT
     , T.LY_YTD_F4_UREB_AMT
/* ==================== 因素5：UFEE已账扣未报账欠付费用（8列=实际/同期、期初/上月/期末/累计） ==================== */
     , T.ACT_BEG_F5_UFEE_AMT
     , T.ACT_LM_F5_UFEE_AMT
     , T.ACT_END_F5_UFEE_AMT
     , T.ACT_YTD_F5_UFEE_AMT
     , T.LY_BEG_F5_UFEE_AMT
     , T.LY_LM_F5_UFEE_AMT
     , T.LY_END_F5_UFEE_AMT
     , T.LY_YTD_F5_UFEE_AMT
/* ==================== 因素6：INVSM开票样机额度（8列=实际/同期、期初/上月/期末/累计） ==================== */
     , T.ACT_BEG_F6_INVSM_AMT
     , T.ACT_LM_F6_INVSM_AMT
     , T.ACT_END_F6_INVSM_AMT
     , T.ACT_YTD_F6_INVSM_AMT
     , T.LY_BEG_F6_INVSM_AMT
     , T.LY_LM_F6_INVSM_AMT
     , T.LY_END_F6_INVSM_AMT
     , T.LY_YTD_F6_INVSM_AMT
/* ==================== 因素7：GSUB国补未回款（8列=实际/同期、期初/上月/期末/累计） ==================== */
     , T.ACT_BEG_F7_GSUB_AMT
     , T.ACT_LM_F7_GSUB_AMT
     , T.ACT_END_F7_GSUB_AMT
     , T.ACT_YTD_F7_GSUB_AMT
     , T.LY_BEG_F7_GSUB_AMT
     , T.LY_LM_F7_GSUB_AMT
     , T.LY_END_F7_GSUB_AMT
     , T.LY_YTD_F7_GSUB_AMT
/* ==================== 因素8：ADJ手工导入（8列=实际/同期、期初/上月/期末/累计） ==================== */
     , T.ACT_BEG_F8_ADJ_AMT
     , T.ACT_LM_F8_ADJ_AMT
     , T.ACT_END_F8_ADJ_AMT
     , T.ACT_YTD_F8_ADJ_AMT
     , T.LY_BEG_F8_ADJ_AMT
     , T.LY_LM_F8_ADJ_AMT
     , T.LY_END_F8_ADJ_AMT
     , T.LY_YTD_F8_ADJ_AMT
/* ==================== 审计列（2列） ==================== */
/* ALTER BY ZHOUHONG.EX 20261022 12:02:00 新增更新人/更新时间，输出104列→115列。 */
     , T.DATEUPD
     , T.USERUPD
  FROM AW_MR7_ARPA01_000001 T
/* ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。 */
  LEFT JOIN TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT G
    ON G.COD = T.D_CHANNEL
   AND G.COD_GERARCHIA = '01'
 WHERE T.COD_SCENARIO = ${$Scenario.code}
   AND T.COD_PERIODO = ${$Period.code}
   /* 公司和事业部范围由报表参数传入，保留 IN 写法支持多值参数。 */
   AND T.COD_AZIENDA IN (${$Entity.code})
   AND T.D_BG IN (${$ANL_D_BG.code})
 ORDER BY T.COD_AZIENDA
        , T.CUST_CODE
