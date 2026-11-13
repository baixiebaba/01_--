/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261113 15:58
 * 本次修改：ALTER BY 20261113 15:58 SHIQINGFENG.EX 新建周转计算配置表查询。
 * 上次修改：无（新建）。
 *
 * 查询名称  ：应收周转配置表-周转计算配置查询
 * 源表      ：AW_RUL_TOVCAL_000001，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261113 15:58 SHIQINGFENG.EX 新建周转计算配置表查询。
 *******************************************************************************/
SELECT T.VALID_FR                                                             /* 开始时间 */
     , T.VALID_TO                                                             /* 结束时间 */
     , T.IS_MTR_FLAG                                                          /* 是否进指标表 */
     , T.EXP_TYPE                                                             /* 模块分类 */
     , T.TARGET_TABLE                                                         /* 目标表-表名 */
     , T.TARGET_AMT                                                           /* 目标表-金额字段 */
     , T.D_GRAN_CAL                                                           /* 颗粒度口径 */
     , T.D_BG                                                                 /* 事业部 */
     , F_TGK_GET_DIMNAME('D_BG', T.D_BG) AS D_BG_DESC                         /* 事业部名称 */
     , T.COD_CONTO                                                            /* 科目 */
     , F_TGK_GET_DIMNAME('CONTO', T.COD_CONTO) AS COD_CONTO_DESC              /* 科目名称 */
     , T.COD_AZIENDA                                                          /* 公司 */
     , F_TGK_GET_DIMNAME('AZIENDA', T.COD_AZIENDA) AS COD_AZIENDA_DESC        /* 公司名称 */
     , T.COD_DEST2                                                            /* 利润中心 */
     , F_TGK_GET_DIMNAME('DEST2', T.COD_DEST2) AS COD_DEST2_DESC              /* 利润中心名称 */
     , T.COD_DEST3                                                            /* 业务范围 */
     , F_TGK_GET_DIMNAME('DEST3', T.COD_DEST3) AS COD_DEST3_DESC              /* 业务范围名称 */
     , T.D_ONOFFLINE                                                          /* 渠道分组 */
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', T.D_ONOFFLINE) AS D_ONOFFLINE_DESC    /* 渠道分组名称 */
     , T.D_SALE_DEPT                                                          /* 业务管理单元 */
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', T.D_SALE_DEPT) AS D_SALE_DEPT_DESC    /* 业务管理单元名称 */
     , T.D_CHANNEL                                                            /* 公司三级分类 */
     , F_TGK_GET_DIMNAME('D_CHANNEL', T.D_CHANNEL) AS D_CHANNEL_DESC          /* 公司三级分类名称 */
     , T.D_CC_CUSTGRP                                                         /* 商冷客户群 */
     , F_TGK_GET_DIMNAME('D_CC_CUSTGRP', T.D_CC_CUSTGRP) AS D_CC_CUSTGRP_DESC  /* 商冷客户群名称 */
     , T.SOURCE_TABLE                                                         /* 取数源表单 */
/* ==================== 字段1～10：动态过滤条件（字段名 / 筛选规则 / 筛选值） ==================== */
     , T.COLUMN_NAME_1                                                        /* 字段1_字段名编码 */
     , T.COLUMN_FILTER_1                                                      /* 字段1_筛选规则 */
     , T.COLUMN_VALUE_1                                                       /* 字段1_筛选值 */
     , T.COLUMN_NAME_2                                                        /* 字段2_字段名编码 */
     , T.COLUMN_FILTER_2                                                      /* 字段2_筛选规则 */
     , T.COLUMN_VALUE_2                                                       /* 字段2_筛选值 */
     , T.COLUMN_NAME_3                                                        /* 字段3_字段名编码 */
     , T.COLUMN_FILTER_3                                                      /* 字段3_筛选规则 */
     , T.COLUMN_VALUE_3                                                       /* 字段3_筛选值 */
     , T.COLUMN_NAME_4                                                        /* 字段4_字段名编码 */
     , T.COLUMN_FILTER_4                                                      /* 字段4_筛选规则 */
     , T.COLUMN_VALUE_4                                                       /* 字段4_筛选值 */
     , T.COLUMN_NAME_5                                                        /* 字段5_字段名编码 */
     , T.COLUMN_FILTER_5                                                      /* 字段5_筛选规则 */
     , T.COLUMN_VALUE_5                                                       /* 字段5_筛选值 */
     , T.COLUMN_NAME_6                                                        /* 字段6_字段名编码 */
     , T.COLUMN_FILTER_6                                                      /* 字段6_筛选规则 */
     , T.COLUMN_VALUE_6                                                       /* 字段6_筛选值 */
     , T.COLUMN_NAME_7                                                        /* 字段7_字段名编码 */
     , T.COLUMN_FILTER_7                                                      /* 字段7_筛选规则 */
     , T.COLUMN_VALUE_7                                                       /* 字段7_筛选值 */
     , T.COLUMN_NAME_8                                                        /* 字段8_字段名编码 */
     , T.COLUMN_FILTER_8                                                      /* 字段8_筛选规则 */
     , T.COLUMN_VALUE_8                                                       /* 字段8_筛选值 */
     , T.COLUMN_NAME_9                                                        /* 字段9_字段名编码 */
     , T.COLUMN_FILTER_9                                                      /* 字段9_筛选规则 */
     , T.COLUMN_VALUE_9                                                       /* 字段9_筛选值 */
     , T.COLUMN_NAME_10                                                       /* 字段10_字段名编码 */
     , T.COLUMN_FILTER_10                                                     /* 字段10_筛选规则 */
     , T.COLUMN_VALUE_10                                                      /* 字段10_筛选值 */
     , T.DATEUPD
     , T.USERUPD
  FROM AW_RUL_TOVCAL_000001 T
/* 场景期间限定规则有效期：场景取前4位年份拼期间成6位年月，与过程 CPM_SP_S2S_TDAYS_M_PHASE2 的 V_YEARMONTH 口径一致。 */
 WHERE TRIM(T.VALID_FR) <= SUBSTR(${$Scenario.code}, 1, 4) || ${$Period.code}
   AND NVL(TRIM(T.VALID_TO), '999999') >= SUBSTR(${$Scenario.code}, 1, 4) || ${$Period.code}
   /* 事业部由报表参数传入，多值参数保留 IN 写法。 */
   AND TRIM(T.D_BG) IN (${$ANL_D_BG.code})
   AND EXP_TYPE = 'ARP1'
 ORDER BY T.EXP_TYPE
        , T.D_BG
        , T.COD_AZIENDA
        , T.COD_DEST2
        , T.VALID_FR
