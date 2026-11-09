/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261109 18:00
 * 本次修改：ALTER BY 20261109 18:00 SHIQINGFENG.EX 金额全为0的记录不再输出。
 * 上次修改：ALTER BY 20261102 18:56 SHIQINGFENG.EX 按 SQL 编码规范统一右对齐：FROM/JOIN 组关键字右端对齐（CROSS JOIN 顶格）、OR/ON 右对齐、WHERE 嵌套条件分层、CASE 表达式 WHEN/THEN/ELSE/END 分行，未修改业务逻辑。
 *
 * 查询名称  ：坏账计提结果表-坏账计算表（管理口径-分公司）
 * 源表      ：AW_MR9_ARPM02_000001
 *
 * 修改历史：
 *   ALTER BY 20261109 18:00 SHIQINGFENG.EX 金额全为0的记录不再输出。
 *   ALTER BY 20261102 18:56 SHIQINGFENG.EX 按 SQL 编码规范统一右对齐：FROM/JOIN 组关键字右端对齐（CROSS JOIN 顶格）、OR/ON 右对齐、WHERE 嵌套条件分层、CASE 表达式 WHEN/THEN/ELSE/END 分行，未修改业务逻辑。
 *   ALTER BY 20261102 17:35 SHIQINGFENG.EX 精简查询说明文件头：删除功能描述、宿主表、展示逻辑行，改为查询名称+源表版式，未修改业务主体。
 *   ALTER BY 20261102 17:26 SHIQINGFENG.EX 将公司参数筛选由等值判断统一为 IN 写法，并统一 Query 排版，未修改其他逻辑。
 *******************************************************************************/
SELECT COD_SCENARIO                                                       /* 场景 */
     , COD_PERIODO                                                        /* 期间 */
     , COD_AZIENDA                                                        /* 公司 */
     , A.COD_CONTO                                                        /* 科目 */
     , DESC_CONTO1                                                        /* 科目名称 */
     , CUST_HEAD_CODE                                                     /* 主户编码 */
     , CUST_HEAD_NAME                                                     /* 主户名称 */
     , GRP_SCOPE                                                          /* 集团归属范围（子公司/集团内/集团外） */
     , D_ONOFFLINE                                                        /* 渠道分组 */
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', D_ONOFFLINE) AS D_ONOFFLINE_DESC  /* 渠道分组名称 */
     , COD_DEST2                                                          /* 利润中心 */
     , F_TGK_GET_DIMNAME('DEST2', COD_DEST2) AS COD_DEST2_DESC            /* 利润中心名称 */
     , COD_DEST3                                                          /* 业务范围 */
     , F_TGK_GET_DIMNAME('DEST3', COD_DEST3) AS COD_DEST3_DESC            /* 业务范围名称 */
     , D_SALE_DEPT                                                        /* 业务管理单元 */
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', D_SALE_DEPT) AS D_SALE_DEPT_DESC  /* 业务管理单元名称 */
     , SUM(BD_BASE_0_AMT) AS BD_BASE_0_AMT                                /* 坏账计提基数金额 */
     , SUM(BD_BASE_1_AMT) AS BD_BASE_1_AMT                                /* 坏账计提基数金额-1个月 */
     , SUM(BD_BASE_2_AMT) AS BD_BASE_2_AMT                                /* 坏账计提基数金额-2-3个月 */
     , SUM(BD_BASE_3_AMT) AS BD_BASE_3_AMT                                /* 坏账计提基数金额-4-6个月 */
     , SUM(BD_BASE_4_AMT) AS BD_BASE_4_AMT                                /* 坏账计提基数金额- 7-12个月 */
     , SUM(BD_BASE_5_AMT) AS BD_BASE_5_AMT                                /* 坏账计提基数金额- 1-2年 */
     , SUM(BD_BASE_6_AMT) AS BD_BASE_6_AMT                                /* 坏账计提基数金额-2-3年 */
     , SUM(BD_BASE_7_AMT) AS BD_BASE_7_AMT                                /* 坏账计提基数金额- 3-4年 */
     , SUM(BD_BASE_8_AMT) AS BD_BASE_8_AMT                                /* 坏账计提基数金额-4-5年 */
     , SUM(BD_BASE_9_AMT) AS BD_BASE_9_AMT                                /* 坏账计提基数金额-5年以上 */
     , SUM(BD_BASE_10_AMT) AS BD_BASE_10_AMT                              /* 坏账计提基数金额-账龄区间段10 */
     , SUM(BD_BASE_11_AMT) AS BD_BASE_11_AMT                              /* 坏账计提基数金额-账龄区间段11 */
     , SUM(BD_BASE_12_AMT) AS BD_BASE_12_AMT                              /* 坏账计提基数金额-账龄区间段12 */
     , SUM(BD_BASE_13_AMT) AS BD_BASE_13_AMT                              /* 坏账计提基数金额-账龄区间段13 */
     , SUM(BD_BASE_14_AMT) AS BD_BASE_14_AMT                              /* 坏账计提基数金额-账龄区间段14 */
     , SUM(BD_BASE_15_AMT) AS BD_BASE_15_AMT                              /* 坏账计提基数金额-账龄区间段15 */
     , SUM(BD_BASE_0_AMT) - SUM(BD_BASE_1_AMT) - SUM(BD_BASE_2_AMT) - SUM(BD_BASE_3_AMT)
       - SUM(BD_BASE_4_AMT) - SUM(BD_BASE_5_AMT) - SUM(BD_BASE_6_AMT) - SUM(BD_BASE_7_AMT)
       - SUM(BD_BASE_8_AMT) - SUM(BD_BASE_9_AMT) - SUM(BD_BASE_10_AMT) - SUM(BD_BASE_11_AMT)
       - SUM(BD_BASE_12_AMT) - SUM(BD_BASE_13_AMT) - SUM(BD_BASE_14_AMT) - SUM(BD_BASE_15_AMT) AS CHECK2  /* 校验：坏账基数总额减各分段合计 */
     , SUM(BD_AFAL_0_AMT) AS BD_AFAL_0_AMT    /* 分摊后坏账金额 */
     , SUM(BD_AFAL_1_AMT) AS BD_AFAL_1_AMT    /* 分摊后坏账金额-1个月 */
     , SUM(BD_AFAL_2_AMT) AS BD_AFAL_2_AMT    /* 分摊后坏账金额-2-3个月 */
     , SUM(BD_AFAL_3_AMT) AS BD_AFAL_3_AMT    /* 分摊后坏账金额-4-6个月 */
     , SUM(BD_AFAL_4_AMT) AS BD_AFAL_4_AMT    /* 分摊后坏账金额- 7-12个月 */
     , SUM(BD_AFAL_5_AMT) AS BD_AFAL_5_AMT    /* 分摊后坏账金额- 1-2年 */
     , SUM(BD_AFAL_6_AMT) AS BD_AFAL_6_AMT    /* 分摊后坏账金额-2-3年 */
     , SUM(BD_AFAL_7_AMT) AS BD_AFAL_7_AMT    /* 分摊后坏账金额- 3-4年 */
     , SUM(BD_AFAL_8_AMT) AS BD_AFAL_8_AMT    /* 分摊后坏账金额-4-5年 */
     , SUM(BD_AFAL_9_AMT) AS BD_AFAL_9_AMT    /* 分摊后坏账金额-5年以上 */
     , SUM(BD_AFAL_10_AMT) AS BD_AFAL_10_AMT  /* 分摊后坏账金额-账龄区间段10 */
     , SUM(BD_AFAL_11_AMT) AS BD_AFAL_11_AMT  /* 分摊后坏账金额-账龄区间段11 */
     , SUM(BD_AFAL_12_AMT) AS BD_AFAL_12_AMT  /* 分摊后坏账金额-账龄区间段12 */
     , SUM(BD_AFAL_13_AMT) AS BD_AFAL_13_AMT  /* 分摊后坏账金额-账龄区间段13 */
     , SUM(BD_AFAL_14_AMT) AS BD_AFAL_14_AMT  /* 分摊后坏账金额-账龄区间段14 */
     , SUM(BD_AFAL_15_AMT) AS BD_AFAL_15_AMT  /* 分摊后坏账金额-账龄区间段15 */
     , SUM(BD_AFAL_0_AMT) - SUM(BD_AFAL_1_AMT) - SUM(BD_AFAL_2_AMT) - SUM(BD_AFAL_3_AMT)
       - SUM(BD_AFAL_4_AMT) - SUM(BD_AFAL_5_AMT) - SUM(BD_AFAL_6_AMT) - SUM(BD_AFAL_7_AMT)
       - SUM(BD_AFAL_8_AMT) - SUM(BD_AFAL_9_AMT) - SUM(BD_AFAL_10_AMT) - SUM(BD_AFAL_11_AMT)
       - SUM(BD_AFAL_12_AMT) - SUM(BD_AFAL_13_AMT) - SUM(BD_AFAL_14_AMT) - SUM(BD_AFAL_15_AMT) AS CHECK4  /* 校验：分摊后坏账总额减各分段合计 */
     , SUM(SPID_0_AMT) AS SPID_0_AMT                      /* 个别认定金额 */
     , SUM(LM_BD_AFAL_0_AMT) AS LM_BD_AFAL_0_AMT          /* 上月-分摊后坏账金额 */
     , SUM(WRITEOFF_AMT) AS WRITEOFF_AMT                  /* 核销金额 */
     , SUM(MTD_BD_PROV_OCUR_AMT) AS MTD_BD_PROV_OCUR_AMT  /* 本月应计提坏账发生额 */
     , BD_PROV_METHOD                                     /* 坏账计提方法 */
     , A.USERUPD                                          /* 更新用户 */
     , A.DATEUPD                                          /* 更新时间 */
  FROM AW_MR9_ARPM02_000001 A
  LEFT JOIN CONTO
    ON A.COD_CONTO = CONTO.COD_CONTO
 WHERE COD_SCENARIO = ${$Scenario.code}
   AND COD_PERIODO = ${$Period.code}
   AND COD_AZIENDA IN (${$Entity.code})
   AND MB_AGE_FLAG IN ('AR', 'OR', 'CA')
   AND COD_CATEGORIA IN ('ZAMOUNT')
 GROUP BY COD_SCENARIO
        , COD_PERIODO
        , COD_AZIENDA
        , A.COD_CONTO
        , DESC_CONTO1
        , CUST_HEAD_CODE
        , CUST_HEAD_NAME
        , GRP_SCOPE
        , D_ONOFFLINE
        , F_TGK_GET_DIMNAME('D_ONOFFLINE', D_ONOFFLINE)
        , COD_DEST2
        , F_TGK_GET_DIMNAME('DEST2', COD_DEST2)
        , COD_DEST3
        , F_TGK_GET_DIMNAME('DEST3', COD_DEST3)
        , D_SALE_DEPT
        , F_TGK_GET_DIMNAME('D_SALE_DEPT', D_SALE_DEPT)
        , BD_PROV_METHOD
        , A.USERUPD
        , A.DATEUPD
   /* 金额全为 0 的记录不输出 */
   HAVING SUM(BD_BASE_0_AMT) <> 0
       OR SUM(BD_AFAL_0_AMT) <> 0
       OR SUM(SPID_0_AMT) <> 0
       OR SUM(LM_BD_AFAL_0_AMT) <> 0
       OR SUM(WRITEOFF_AMT) <> 0
       OR SUM(MTD_BD_PROV_OCUR_AMT) <> 0
 ORDER BY COD_AZIENDA
        , A.COD_CONTO
