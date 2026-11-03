/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261103 11:13
 * 本次修改：ALTER BY 20261103 11:13 SHIQINGFENG.EX 按要求移除维度描述解码函数，保留 F_TGK_GET_DIMNAME 取值逻辑，未修改业务口径。
 * 上次修改：ALTER BY 20261103 11:03 SHIQINGFENG.EX 统一 S 层 Query 文件头、字段排版、参数 IN 写法及维度描述解码，未修改业务口径。
 *
 * 查询名称  ：应收周转展示表-客商-周转展示表-客商
 * 源表      ：AW_MR7_ARPA01_000001、TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT、TGK_FIMA_HISENSE.DEST3_GERARCHIA_FLAT 等，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261103 11:13 SHIQINGFENG.EX 按要求移除维度描述解码函数，保留 F_TGK_GET_DIMNAME 取值逻辑，未修改业务口径。
 *   ALTER BY 20261103 11:03 SHIQINGFENG.EX 统一 S 层 Query 文件头、字段排版、参数 IN 写法及维度描述解码，未修改业务口径。
 *******************************************************************************/
WITH
/* 读取应收周转客商明细及金额、因素字段，供展示层计算期间和累计周转指标。 */
SRC AS (
/* ==================== 维度 + 金额 + 因素：仅取展示表需要的 95 个底表字段 ==================== */
    SELECT T.COD_SCENARIO
         , T.COD_PERIODO
         , T.D_BG
         , T.COD_AZIENDA
         , T.CUST_CODE
         , T.CUST_NAME
         , T.CUST_HEAD_CODE
         , T.CUST_HEAD_NAME
         , T.CUST_BRANCH_CODE
         , T.CUST_BRANCH_NAME
         , T.GRP_SCOPE
         , T.D_CHANNEL
         , T.D_ONOFFLINE
         , T.COD_DEST2
         , T.COD_DEST3
         , T.D_SALE_DEPT
         , T.D_CHANNEL_BU
         , T.D_CC_CUSTGRP
         , T.COUNTRY_NAME
         , T.ACT_LM_OCP_AMT
         , T.ACT_END_OCP_AMT
         , T.ACT_MTD_CSM_AMT
         , T.LY_LM_OCP_AMT
         , T.LY_END_OCP_AMT
         , T.LY_MTD_CSM_AMT
         , T.ACT_END_F1_ODUE_AMT
         , T.ACT_END_F2_EPAY_AMT
         , T.ACT_END_F3_ECR_AMT
         , T.ACT_END_F4_UREB_AMT
         , T.ACT_END_F5_UFEE_AMT
         , T.ACT_END_F6_INVSM_AMT
         , T.ACT_END_F7_GSUB_AMT
         , T.ACT_END_F8_ADJ_AMT
         , T.ACT_LM_F1_ODUE_AMT
         , T.ACT_LM_F2_EPAY_AMT
         , T.ACT_LM_F3_ECR_AMT
         , T.ACT_LM_F4_UREB_AMT
         , T.ACT_LM_F5_UFEE_AMT
         , T.ACT_LM_F6_INVSM_AMT
         , T.ACT_LM_F7_GSUB_AMT
         , T.ACT_LM_F8_ADJ_AMT
         , T.LY_LM_F1_ODUE_AMT
         , T.LY_LM_F2_EPAY_AMT
         , T.LY_LM_F3_ECR_AMT
         , T.LY_LM_F4_UREB_AMT
         , T.LY_LM_F5_UFEE_AMT
         , T.LY_LM_F6_INVSM_AMT
         , T.LY_LM_F7_GSUB_AMT
         , T.LY_LM_F8_ADJ_AMT
         , T.LY_END_F1_ODUE_AMT
         , T.LY_END_F2_EPAY_AMT
         , T.LY_END_F3_ECR_AMT
         , T.LY_END_F4_UREB_AMT
         , T.LY_END_F5_UFEE_AMT
         , T.LY_END_F6_INVSM_AMT
         , T.LY_END_F7_GSUB_AMT
         , T.LY_END_F8_ADJ_AMT
         , T.ACT_BEG_OCP_AMT
         , T.ACT_YTD_OCP_AMT
         , T.ACT_YTD_CSM_AMT
         , T.LY_BEG_OCP_AMT
         , T.LY_YTD_OCP_AMT
         , T.LY_YTD_CSM_AMT
         , T.ACT_BEG_F1_ODUE_AMT
         , T.ACT_BEG_F2_EPAY_AMT
         , T.ACT_BEG_F3_ECR_AMT
         , T.ACT_BEG_F4_UREB_AMT
         , T.ACT_BEG_F5_UFEE_AMT
         , T.ACT_BEG_F6_INVSM_AMT
         , T.ACT_BEG_F7_GSUB_AMT
         , T.ACT_BEG_F8_ADJ_AMT
         , T.ACT_YTD_F1_ODUE_AMT
         , T.ACT_YTD_F2_EPAY_AMT
         , T.ACT_YTD_F3_ECR_AMT
         , T.ACT_YTD_F4_UREB_AMT
         , T.ACT_YTD_F5_UFEE_AMT
         , T.ACT_YTD_F6_INVSM_AMT
         , T.ACT_YTD_F7_GSUB_AMT
         , T.ACT_YTD_F8_ADJ_AMT
         , T.LY_BEG_F1_ODUE_AMT
         , T.LY_BEG_F2_EPAY_AMT
         , T.LY_BEG_F3_ECR_AMT
         , T.LY_BEG_F4_UREB_AMT
         , T.LY_BEG_F5_UFEE_AMT
         , T.LY_BEG_F6_INVSM_AMT
         , T.LY_BEG_F7_GSUB_AMT
         , T.LY_BEG_F8_ADJ_AMT
         , T.LY_YTD_F1_ODUE_AMT
         , T.LY_YTD_F2_EPAY_AMT
         , T.LY_YTD_F3_ECR_AMT
         , T.LY_YTD_F4_UREB_AMT
         , T.LY_YTD_F5_UFEE_AMT
         , T.LY_YTD_F6_INVSM_AMT
         , T.LY_YTD_F7_GSUB_AMT
         , T.LY_YTD_F8_ADJ_AMT
      FROM AW_MR7_ARPA01_000001 T
     /* ALTER BY 20261103 11:13 SHIQINGFENG.EX 按要求移除维度描述解码函数，保留 F_TGK_GET_DIMNAME 取值逻辑，未修改业务口径。 */
     WHERE T.COD_SCENARIO = ${$Scenario.code}
       AND T.COD_PERIODO = ${$Period.code}
       /* 公司和事业部范围由报表参数传入，保留 IN 写法支持多值参数。 */
       AND T.COD_AZIENDA IN (${$Entity.code})
       AND T.D_BG IN (${$ANL_D_BG.code})
       AND T.COD_CATEGORIA = 'ZAMOUNT'
)
SELECT
/* ==================== B ~ AE: 维度区 (30 列) ==================== */
       /* B */ S.COD_SCENARIO AS COD_SCENARIO
     , /* C */ S.COD_PERIODO AS COD_PERIODO
     , /* D */ S.D_BG AS D_BG
     , /* E */ F_TGK_GET_DIMNAME('D_BG', NVL(S.D_BG, 'ZZZZ')) AS D_BG_DESC
     , /* F */ S.COD_AZIENDA AS COD_AZIENDA
     , /* G */ F_TGK_GET_DIMNAME('AZIENDA', NVL(S.COD_AZIENDA, 'ZZZZ')) AS COD_AZIENDA_DESC
     , /* H */ S.CUST_CODE AS CUST_CODE
     , /* I */ S.CUST_NAME AS CUST_NAME
     , /* J */ S.CUST_HEAD_CODE AS CUST_HEAD_CODE
     , /* K */ S.CUST_HEAD_NAME AS CUST_HEAD_NAME
     , /* L */ S.CUST_BRANCH_CODE AS CUST_BRANCH_CODE
     , /* M */ S.CUST_BRANCH_NAME AS CUST_BRANCH_NAME
     , /* N */ S.GRP_SCOPE AS GRP_SCOPE
     , /* O */ G.COD_ELEGER6 AS COD_ELEGER6
     , /* P */ G.COD_ELEGER7 AS COD_ELEGER7
     , /* Q */ S.D_CHANNEL AS D_CHANNEL
     , /* R */ S.D_ONOFFLINE AS D_ONOFFLINE
     , /* S */ F_TGK_GET_DIMNAME('D_ONOFFLINE', NVL(S.D_ONOFFLINE, 'ZZZZ')) AS D_ONOFFLINE_DESC
     , /* T */ S.COD_DEST2 AS COD_DEST2
     , /* U */ F_TGK_GET_DIMNAME('DEST2', NVL(S.COD_DEST2, 'ZZZZ')) AS COD_DEST2_DESC
     , /* V */ S.COD_DEST3 AS COD_DEST3
     , /* W */ F_TGK_GET_DIMNAME('DEST3', NVL(S.COD_DEST3, 'ZZZZ')) AS COD_DEST3_DESC
     , /* X */ S.D_SALE_DEPT AS D_SALE_DEPT
     , /* Y */ F_TGK_GET_DIMNAME('D_SALE_DEPT', NVL(S.D_SALE_DEPT, 'ZZZZ')) AS D_SALE_DEPT_DESC
     , /* Z */ S.D_CHANNEL_BU AS D_CHANNEL_BU
     , /* AA */ F_TGK_GET_DIMNAME('D_CHANNEL_BU', NVL(S.D_CHANNEL_BU, 'ZZZZ')) AS D_TOV_CHAN_DESC
     , /* AB */ S.D_CC_CUSTGRP AS D_CC_CUSTGRP
     , /* AC */ F_TGK_GET_DIMNAME('D_CC_CUSTGRP', NVL(S.D_CC_CUSTGRP, 'ZZZZ')) AS D_CC_CUSTGRP_DESC
     , /* AD */ NVL(D3.DESC_DEST3_ELEGER4, D3.DESC_DEST3_ELEGER5) AS DESC_DEST3_ELEGER4
     , /* AE */ S.COUNTRY_NAME AS COUNTRY_NAME
/* ==================== AF ~ AN: 当月周转区 (9 列): 上月占用 / 期末占用 / 当月收入 / 同期 / 较同期 ==================== */
     , /* AF */ S.ACT_LM_OCP_AMT AS ACT_LM_OCP_AMT
     , /* AG */ S.ACT_END_OCP_AMT AS ACT_END_OCP_AMT
     , /* AH */ S.ACT_MTD_CSM_AMT AS ACT_MTD_CSM_AMT
     , /* AI */ ROUND((NVL(S.ACT_LM_OCP_AMT, 0) + NVL(S.ACT_END_OCP_AMT, 0)) / 2 / NULLIF(S.ACT_MTD_CSM_AMT, 0) * 30, 2) AS ACT_MTD_TOV_RATIO
     , /* AJ */ S.LY_LM_OCP_AMT AS LY_LM_OCP_AMT
     , /* AK */ S.LY_END_OCP_AMT AS LY_END_OCP_AMT
     , /* AL */ S.LY_MTD_CSM_AMT AS LY_MTD_CSM_AMT
     , /* AM */ ROUND((NVL(S.LY_LM_OCP_AMT, 0) + NVL(S.LY_END_OCP_AMT, 0)) / 2 / NULLIF(S.LY_MTD_CSM_AMT, 0) * 30, 2) AS LY_MTD_TOV_RATIO
     , /* AN */ ROUND((NVL(S.ACT_LM_OCP_AMT, 0) + NVL(S.ACT_END_OCP_AMT, 0)) / 2 / NULLIF(S.ACT_MTD_CSM_AMT, 0) * 30, 2)
       - ROUND((NVL(S.LY_LM_OCP_AMT, 0) + NVL(S.LY_END_OCP_AMT, 0)) / 2 / NULLIF(S.LY_MTD_CSM_AMT, 0) * 30, 2) AS MTD_TOV_DIFF
/* ==================== AO ~ AV: 当月因素 1..8 (期末, 实际) 8 列 ==================== */
     , /* AO */ S.ACT_END_F1_ODUE_AMT AS ACT_END_F1_ODUE_AMT
     , /* AP */ S.ACT_END_F2_EPAY_AMT AS ACT_END_F2_EPAY_AMT
     , /* AQ */ S.ACT_END_F3_ECR_AMT AS ACT_END_F3_ECR_AMT
     , /* AR */ S.ACT_END_F4_UREB_AMT AS ACT_END_F4_UREB_AMT
     , /* AS */ S.ACT_END_F5_UFEE_AMT AS ACT_END_F5_UFEE_AMT
     , /* AT */ S.ACT_END_F6_INVSM_AMT AS ACT_END_F6_INVSM_AMT
     , /* AU */ S.ACT_END_F7_GSUB_AMT AS ACT_END_F7_GSUB_AMT
     , /* AV */ S.ACT_END_F8_ADJ_AMT AS ACT_END_F8_ADJ_AMT
/* ==================== AW ~ BD: 上月因素 1..8 (实际) 8 列 ==================== */
     , /* AW */ S.ACT_LM_F1_ODUE_AMT AS ACT_LM_F1_ODUE_AMT
     , /* AX */ S.ACT_LM_F2_EPAY_AMT AS ACT_LM_F2_EPAY_AMT
     , /* AY */ S.ACT_LM_F3_ECR_AMT AS ACT_LM_F3_ECR_AMT
     , /* AZ */ S.ACT_LM_F4_UREB_AMT AS ACT_LM_F4_UREB_AMT
     , /* BA */ S.ACT_LM_F5_UFEE_AMT AS ACT_LM_F5_UFEE_AMT
     , /* BB */ S.ACT_LM_F6_INVSM_AMT AS ACT_LM_F6_INVSM_AMT
     , /* BC */ S.ACT_LM_F7_GSUB_AMT AS ACT_LM_F7_GSUB_AMT
     , /* BD */ S.ACT_LM_F8_ADJ_AMT AS ACT_LM_F8_ADJ_AMT
/* ==================== BE ~ BL: 同期上月因素 1..8 (同期) 8 列 ==================== */
     , /* BE */ S.LY_LM_F1_ODUE_AMT AS LY_LM_F1_ODUE_AMT
     , /* BF */ S.LY_LM_F2_EPAY_AMT AS LY_LM_F2_EPAY_AMT
     , /* BG */ S.LY_LM_F3_ECR_AMT AS LY_LM_F3_ECR_AMT
     , /* BH */ S.LY_LM_F4_UREB_AMT AS LY_LM_F4_UREB_AMT
     , /* BI */ S.LY_LM_F5_UFEE_AMT AS LY_LM_F5_UFEE_AMT
     , /* BJ */ S.LY_LM_F6_INVSM_AMT AS LY_LM_F6_INVSM_AMT
     , /* BK */ S.LY_LM_F7_GSUB_AMT AS LY_LM_F7_GSUB_AMT
     , /* BL */ S.LY_LM_F8_ADJ_AMT AS LY_LM_F8_ADJ_AMT
/* ==================== BM ~ BT: 同期期末因素 1..8 (同期) 8 列 ==================== */
     , /* BM */ S.LY_END_F1_ODUE_AMT AS LY_END_F1_ODUE_AMT
     , /* BN */ S.LY_END_F2_EPAY_AMT AS LY_END_F2_EPAY_AMT
     , /* BO */ S.LY_END_F3_ECR_AMT AS LY_END_F3_ECR_AMT
     , /* BP */ S.LY_END_F4_UREB_AMT AS LY_END_F4_UREB_AMT
     , /* BQ */ S.LY_END_F5_UFEE_AMT AS LY_END_F5_UFEE_AMT
     , /* BR */ S.LY_END_F6_INVSM_AMT AS LY_END_F6_INVSM_AMT
     , /* BS */ S.LY_END_F7_GSUB_AMT AS LY_END_F7_GSUB_AMT
     , /* BT */ S.LY_END_F8_ADJ_AMT AS LY_END_F8_ADJ_AMT
/* ==================== BU ~ CC: 累计周转区 (9 列): 年初占用 / 累计占用 / 累计收入 / 累计周转 / 同期 / 较同期 ==================== */
     , /* BU */ S.ACT_BEG_OCP_AMT AS ACT_BEG_OCP_AMT
     , /* BV */ S.ACT_YTD_OCP_AMT AS ACT_YTD_OCP_AMT
     , /* BW */ S.ACT_YTD_CSM_AMT AS ACT_YTD_CSM_AMT
     , /* BX */ ROUND((NVL(S.ACT_BEG_OCP_AMT, 0) / 2 + NVL(S.ACT_YTD_OCP_AMT, 0) - NVL(S.ACT_END_OCP_AMT, 0) / 2) / NULLIF(S.ACT_YTD_CSM_AMT, 0) * 30, 2) AS ACT_YTD_TOV_RATIO
     , /* BY */ S.LY_BEG_OCP_AMT AS LY_BEG_OCP_AMT
     , /* BZ */ S.LY_YTD_OCP_AMT AS LY_YTD_OCP_AMT
     , /* CA */ S.LY_YTD_CSM_AMT AS LY_YTD_CSM_AMT
     , /* CB */ ROUND((NVL(S.LY_BEG_OCP_AMT, 0) / 2 + NVL(S.LY_YTD_OCP_AMT, 0) - NVL(S.LY_END_OCP_AMT, 0) / 2) / NULLIF(S.LY_YTD_CSM_AMT, 0) * 30, 2) AS LY_YTD_TOV_RATIO
     , /* CC */ ROUND((NVL(S.ACT_BEG_OCP_AMT, 0) / 2 + NVL(S.ACT_YTD_OCP_AMT, 0) - NVL(S.ACT_END_OCP_AMT, 0) / 2) / NULLIF(S.ACT_YTD_CSM_AMT, 0) * 30, 2)
       - ROUND((NVL(S.LY_BEG_OCP_AMT, 0) / 2 + NVL(S.LY_YTD_OCP_AMT, 0) - NVL(S.LY_END_OCP_AMT, 0) / 2) / NULLIF(S.LY_YTD_CSM_AMT, 0) * 30, 2) AS YTD_TOV_DIFF
/* ==================== CD ~ CK: 年初因素 1..8 (实际) 8 列  v2 新增 ==================== */
     , /* CD */ S.ACT_BEG_F1_ODUE_AMT AS ACT_BEG_F1_ODUE_AMT
     , /* CE */ S.ACT_BEG_F2_EPAY_AMT AS ACT_BEG_F2_EPAY_AMT
     , /* CF */ S.ACT_BEG_F3_ECR_AMT AS ACT_BEG_F3_ECR_AMT
     , /* CG */ S.ACT_BEG_F4_UREB_AMT AS ACT_BEG_F4_UREB_AMT
     , /* CH */ S.ACT_BEG_F5_UFEE_AMT AS ACT_BEG_F5_UFEE_AMT
     , /* CI */ S.ACT_BEG_F6_INVSM_AMT AS ACT_BEG_F6_INVSM_AMT
     , /* CJ */ S.ACT_BEG_F7_GSUB_AMT AS ACT_BEG_F7_GSUB_AMT
     , /* CK */ S.ACT_BEG_F8_ADJ_AMT AS ACT_BEG_F8_ADJ_AMT
/* ==================== CL ~ CS: 累计因素 1..8 (实际) 8 列 ==================== */
     , /* CL */ S.ACT_YTD_F1_ODUE_AMT AS ACT_YTD_F1_ODUE_AMT
     , /* CM */ S.ACT_YTD_F2_EPAY_AMT AS ACT_YTD_F2_EPAY_AMT
     , /* CN */ S.ACT_YTD_F3_ECR_AMT AS ACT_YTD_F3_ECR_AMT
     , /* CO */ S.ACT_YTD_F4_UREB_AMT AS ACT_YTD_F4_UREB_AMT
     , /* CP */ S.ACT_YTD_F5_UFEE_AMT AS ACT_YTD_F5_UFEE_AMT
     , /* CQ */ S.ACT_YTD_F6_INVSM_AMT AS ACT_YTD_F6_INVSM_AMT
     , /* CR */ S.ACT_YTD_F7_GSUB_AMT AS ACT_YTD_F7_GSUB_AMT
     , /* CS */ S.ACT_YTD_F8_ADJ_AMT AS ACT_YTD_F8_ADJ_AMT
/* ==================== CT ~ DA: 同期年初因素 1..8  v2 新增 ==================== */
     , /* CT */ S.LY_BEG_F1_ODUE_AMT AS LY_BEG_F1_ODUE_AMT
     , /* CU */ S.LY_BEG_F2_EPAY_AMT AS LY_BEG_F2_EPAY_AMT
     , /* CV */ S.LY_BEG_F3_ECR_AMT AS LY_BEG_F3_ECR_AMT
     , /* CW */ S.LY_BEG_F4_UREB_AMT AS LY_BEG_F4_UREB_AMT
     , /* CX */ S.LY_BEG_F5_UFEE_AMT AS LY_BEG_F5_UFEE_AMT
     , /* CY */ S.LY_BEG_F6_INVSM_AMT AS LY_BEG_F6_INVSM_AMT
     , /* CZ */ S.LY_BEG_F7_GSUB_AMT AS LY_BEG_F7_GSUB_AMT
     , /* DA */ S.LY_BEG_F8_ADJ_AMT AS LY_BEG_F8_ADJ_AMT
/* ==================== DB ~ DI: 同期累计因素 1..8 (同期) 8 列 ==================== */
     , /* DB */ S.LY_YTD_F1_ODUE_AMT AS LY_YTD_F1_ODUE_AMT
     , /* DC */ S.LY_YTD_F2_EPAY_AMT AS LY_YTD_F2_EPAY_AMT
     , /* DD */ S.LY_YTD_F3_ECR_AMT AS LY_YTD_F3_ECR_AMT
     , /* DE */ S.LY_YTD_F4_UREB_AMT AS LY_YTD_F4_UREB_AMT
     , /* DF */ S.LY_YTD_F5_UFEE_AMT AS LY_YTD_F5_UFEE_AMT
     , /* DG */ S.LY_YTD_F6_INVSM_AMT AS LY_YTD_F6_INVSM_AMT
     , /* DH */ S.LY_YTD_F7_GSUB_AMT AS LY_YTD_F7_GSUB_AMT
     , /* DI */ S.LY_YTD_F8_ADJ_AMT AS LY_YTD_F8_ADJ_AMT
  FROM SRC S
/* 渠道层级扁平视图：用 D_CHANNEL 匹配 COD，带出一级/二级公司分类（第 6/7 级编码）。 */
/* ALTER BY ZHOUHONG.EX 20261022 11:49:36 原表 ED_D_CHANNEL_GERARCHIA_FLAT 不可用，改 V_ED_D_CHANNEL_FLAT。 */
  LEFT JOIN TGK_FIMA_HISENSE.V_ED_D_CHANNEL_FLAT G
    ON G.COD = S.D_CHANNEL
/* 业务范围层级扁平表：取 HIE='01' 的 4 级 / 5 级描述，4 级优先作为「大区」。 */
  LEFT JOIN (
        SELECT COD_DEST3
             , DESC_DEST3_ELEGER3
             , DESC_DEST3_ELEGER4
             , DESC_DEST3_ELEGER5
          FROM TGK_FIMA_HISENSE.DEST3_GERARCHIA_FLAT
         WHERE COD_DEST3_GERARCHIA = '01'
       ) D3
    ON D3.COD_DEST3 = S.COD_DEST3
 ORDER BY S.COD_AZIENDA
        , S.CUST_CODE

