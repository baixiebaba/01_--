/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261120 18:38
 * 本次修改：ALTER BY 20261120 18:38 SHIQINGFENG.EX 新增销售部门层级七/六/五级分类字段，渠道层级分类字段改名前缀。
 * 上次修改：ALTER BY 20261109 18:00 SHIQINGFENG.EX 金额全为0的记录不再输出。
 *
 * 查询名称  ：应收周转展示表-客商-ADS数据查询
 * 源表      ：AW_MR7_ARPA01_000001、TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT、TGK_FIMA_HISENSE.ED_D_SALE_DEPT_GERARCHIA_FLAT，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261120 18:38 SHIQINGFENG.EX 新增销售部门层级七/六/五级分类字段，渠道层级分类字段改名前缀。
 *   ALTER BY 20261109 18:00 SHIQINGFENG.EX 金额全为0的记录不再输出。
 *   ALTER BY 20261103 14:08 SHIQINGFENG.EX 为公司分类层级关联增加 COD_GERARCHIA='01' 限制，未修改业务逻辑。
 *   ALTER BY 20261103 11:49 SHIQINGFENG.EX 补充公司一级、二级分类编码及描述，D_CHANNEL作为公司三级分类，未修改金额和过滤逻辑。
 *******************************************************************************/
/* ==================== 维度及描述（39列） ==================== */
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
     /* ALTER BY 20261120 18:38 SHIQINGFENG.EX 渠道层级分类字段改名前缀CHANNEL_，与销售部门层级字段区分。 */
     , G.COD_ELEGER6 AS CHANNEL_COD_ELEGER6       /* 渠道层级一级分类编码 */
     , G.DESC_ELEGER6 AS CHANNEL_DESC_ELEGER6   /* 渠道层级一级分类描述 */
     , G.COD_ELEGER5 AS CHANNEL_COD_ELEGER5       /* 渠道层级二级分类编码 */
     , G.DESC_ELEGER5 AS CHANNEL_DESC_ELEGER5   /* 渠道层级二级分类描述 */
     , T.D_CHANNEL
     , F_TGK_GET_DIMNAME('D_CHANNEL', NVL(T.D_CHANNEL, 'ZZZZ')) AS D_CHANNEL_DESC
     , T.D_ONOFFLINE
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', NVL(T.D_ONOFFLINE, 'ZZZZ')) AS D_ONOFFLINE_DESC
     , T.COD_DEST2
     , F_TGK_GET_DIMNAME('DEST2', NVL(T.COD_DEST2, 'ZZZZ')) AS COD_DEST2_DESC
     , T.COD_DEST3
     , F_TGK_GET_DIMNAME('DEST3', NVL(T.COD_DEST3, 'ZZZZ')) AS COD_DEST3_DESC
     /* ALTER BY 20261120 18:38 SHIQINGFENG.EX 新增销售部门层级七/六/五级分类编码及描述。 */
     , SD.COD_ELEGER7 AS COD_ELEGER7        /* 销售部门七级分类编码 */
     , SD.DESC_ELEGER7 AS DESC_ELEGER7      /* 销售部门七级分类描述 */
     , SD.COD_ELEGER6 AS COD_ELEGER6        /* 销售部门六级分类编码 */
     , SD.DESC_ELEGER6 AS DESC_ELEGER6      /* 销售部门六级分类描述 */
     , SD.COD_ELEGER5 AS COD_ELEGER5        /* 销售部门五级分类编码 */
     , SD.DESC_ELEGER5 AS DESC_ELEGER5      /* 销售部门五级分类描述 */
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
/* 销售部门层级扁平表：HISDA 切片，COD与业务管理单元一一对应。 */
/* ALTER BY 20261120 18:38 SHIQINGFENG.EX 新增销售部门层级扁平表关联，按D_SALE_DEPT带出上级分类。 */
  LEFT JOIN (
        SELECT COD
             , COD_ELEGER7
             , DESC_ELEGER7
             , COD_ELEGER6
             , DESC_ELEGER6
             , COD_ELEGER5
             , DESC_ELEGER5
          FROM ED_D_SALE_DEPT_GERARCHIA_FLAT
         WHERE COD_GERARCHIA = 'HISDA'
       ) SD
    ON SD.COD = T.D_SALE_DEPT
 WHERE T.COD_SCENARIO = ${$Scenario.code}
   AND T.COD_PERIODO = ${$Period.code}
   AND T.D_GRAN_CAL = 'ARTO_CUST'
   /* 公司和事业部范围由报表参数传入，保留 IN 写法支持多值参数。 */
   /* 金额全为 0 的记录不输出 */
   AND (
        NVL(T.PLN_BEG_OCP_AMT, 0) <> 0
        OR NVL(T.PLN_LM_OCP_AMT, 0) <> 0
        OR NVL(T.PLN_END_OCP_AMT, 0) <> 0
        OR NVL(T.PLN_YTD_OCP_AMT, 0) <> 0
        OR NVL(T.PLN_MTD_CSM_AMT, 0) <> 0
        OR NVL(T.PLN_YTD_CSM_AMT, 0) <> 0
        OR NVL(T.ACT_BEG_OCP_AMT, 0) <> 0
        OR NVL(T.ACT_LM_OCP_AMT, 0) <> 0
        OR NVL(T.ACT_END_OCP_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_OCP_AMT, 0) <> 0
        OR NVL(T.ACT_MTD_CSM_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_CSM_AMT, 0) <> 0
        OR NVL(T.LY_BEG_OCP_AMT, 0) <> 0
        OR NVL(T.LY_LM_OCP_AMT, 0) <> 0
        OR NVL(T.LY_END_OCP_AMT, 0) <> 0
        OR NVL(T.LY_YTD_OCP_AMT, 0) <> 0
        OR NVL(T.LY_MTD_CSM_AMT, 0) <> 0
        OR NVL(T.LY_YTD_CSM_AMT, 0) <> 0
        OR NVL(T.ACT_BEG_F1_ODUE_AMT, 0) <> 0
        OR NVL(T.ACT_LM_F1_ODUE_AMT, 0) <> 0
        OR NVL(T.ACT_END_F1_ODUE_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_F1_ODUE_AMT, 0) <> 0
        OR NVL(T.LY_BEG_F1_ODUE_AMT, 0) <> 0
        OR NVL(T.LY_LM_F1_ODUE_AMT, 0) <> 0
        OR NVL(T.LY_END_F1_ODUE_AMT, 0) <> 0
        OR NVL(T.LY_YTD_F1_ODUE_AMT, 0) <> 0
        OR NVL(T.ACT_BEG_F2_EPAY_AMT, 0) <> 0
        OR NVL(T.ACT_LM_F2_EPAY_AMT, 0) <> 0
        OR NVL(T.ACT_END_F2_EPAY_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_F2_EPAY_AMT, 0) <> 0
        OR NVL(T.LY_BEG_F2_EPAY_AMT, 0) <> 0
        OR NVL(T.LY_LM_F2_EPAY_AMT, 0) <> 0
        OR NVL(T.LY_END_F2_EPAY_AMT, 0) <> 0
        OR NVL(T.LY_YTD_F2_EPAY_AMT, 0) <> 0
        OR NVL(T.ACT_BEG_F3_ECR_AMT, 0) <> 0
        OR NVL(T.ACT_LM_F3_ECR_AMT, 0) <> 0
        OR NVL(T.ACT_END_F3_ECR_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_F3_ECR_AMT, 0) <> 0
        OR NVL(T.LY_BEG_F3_ECR_AMT, 0) <> 0
        OR NVL(T.LY_LM_F3_ECR_AMT, 0) <> 0
        OR NVL(T.LY_END_F3_ECR_AMT, 0) <> 0
        OR NVL(T.LY_YTD_F3_ECR_AMT, 0) <> 0
        OR NVL(T.ACT_BEG_F4_UREB_AMT, 0) <> 0
        OR NVL(T.ACT_LM_F4_UREB_AMT, 0) <> 0
        OR NVL(T.ACT_END_F4_UREB_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_F4_UREB_AMT, 0) <> 0
        OR NVL(T.LY_BEG_F4_UREB_AMT, 0) <> 0
        OR NVL(T.LY_LM_F4_UREB_AMT, 0) <> 0
        OR NVL(T.LY_END_F4_UREB_AMT, 0) <> 0
        OR NVL(T.LY_YTD_F4_UREB_AMT, 0) <> 0
        OR NVL(T.ACT_BEG_F5_UFEE_AMT, 0) <> 0
        OR NVL(T.ACT_LM_F5_UFEE_AMT, 0) <> 0
        OR NVL(T.ACT_END_F5_UFEE_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_F5_UFEE_AMT, 0) <> 0
        OR NVL(T.LY_BEG_F5_UFEE_AMT, 0) <> 0
        OR NVL(T.LY_LM_F5_UFEE_AMT, 0) <> 0
        OR NVL(T.LY_END_F5_UFEE_AMT, 0) <> 0
        OR NVL(T.LY_YTD_F5_UFEE_AMT, 0) <> 0
        OR NVL(T.ACT_BEG_F6_INVSM_AMT, 0) <> 0
        OR NVL(T.ACT_LM_F6_INVSM_AMT, 0) <> 0
        OR NVL(T.ACT_END_F6_INVSM_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_F6_INVSM_AMT, 0) <> 0
        OR NVL(T.LY_BEG_F6_INVSM_AMT, 0) <> 0
        OR NVL(T.LY_LM_F6_INVSM_AMT, 0) <> 0
        OR NVL(T.LY_END_F6_INVSM_AMT, 0) <> 0
        OR NVL(T.LY_YTD_F6_INVSM_AMT, 0) <> 0
        OR NVL(T.ACT_BEG_F7_GSUB_AMT, 0) <> 0
        OR NVL(T.ACT_LM_F7_GSUB_AMT, 0) <> 0
        OR NVL(T.ACT_END_F7_GSUB_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_F7_GSUB_AMT, 0) <> 0
        OR NVL(T.LY_BEG_F7_GSUB_AMT, 0) <> 0
        OR NVL(T.LY_LM_F7_GSUB_AMT, 0) <> 0
        OR NVL(T.LY_END_F7_GSUB_AMT, 0) <> 0
        OR NVL(T.LY_YTD_F7_GSUB_AMT, 0) <> 0
        OR NVL(T.ACT_BEG_F8_ADJ_AMT, 0) <> 0
        OR NVL(T.ACT_LM_F8_ADJ_AMT, 0) <> 0
        OR NVL(T.ACT_END_F8_ADJ_AMT, 0) <> 0
        OR NVL(T.ACT_YTD_F8_ADJ_AMT, 0) <> 0
        OR NVL(T.LY_BEG_F8_ADJ_AMT, 0) <> 0
        OR NVL(T.LY_LM_F8_ADJ_AMT, 0) <> 0
        OR NVL(T.LY_END_F8_ADJ_AMT, 0) <> 0
        OR NVL(T.LY_YTD_F8_ADJ_AMT, 0) <> 0
       )
   AND T.D_BG IN (${$ANL_D_BG.code})
 ORDER BY T.COD_AZIENDA
        , T.CUST_CODE
