/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261109 18:00
 * 本次修改：ALTER BY 20261109 18:00 SHIQINGFENG.EX 金额全为0的记录不再输出。
 * 上次修改：ALTER BY 20261102 18:56 SHIQINGFENG.EX 按 SQL 编码规范统一右对齐：FROM/JOIN 组关键字右端对齐（CROSS JOIN 顶格）、OR/ON 右对齐、WHERE 嵌套条件分层、CASE 表达式 WHEN/THEN/ELSE/END 分行，未修改业务逻辑。
 *
 * 查询名称  ：坏账计提结果表-坏账计算表（管理口径-事业部）
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
     , CUST_CODE                                                          /* 客商编码 */
     , CUST_NAME                                                          /* 客商名称 */
     , CUST_HEAD_CODE                                                     /* 主户编码 */
     , CUST_HEAD_NAME                                                     /* 主户名称 */
     , CUST_BRANCH_CODE                                                   /* 分户编码 */
     , CUST_BRANCH_NAME                                                   /* 分户名称 */
     , GRP_SCOPE                                                          /* 集团归属范围（子公司/集团内/集团外） */
     , NATURE_L1_NAME                                                     /* 一级性质 */
     , NATURE_L2_NAME                                                     /* 二级性质 */
     , NATURE_L3_NAME                                                     /* 三级性质 */
     , D_ONOFFLINE                                                        /* 渠道分组 */
     , F_TGK_GET_DIMNAME('D_ONOFFLINE', D_ONOFFLINE) AS D_ONOFFLINE_DESC  /* 渠道分组名称 */
     , COD_DEST2                                                          /* 利润中心 */
     , F_TGK_GET_DIMNAME('DEST2', COD_DEST2) AS COD_DEST2_DESC            /* 利润中心名称 */
     , COD_DEST3                                                          /* 业务范围 */
     , F_TGK_GET_DIMNAME('DEST3', COD_DEST3) AS COD_DEST3_DESC            /* 业务范围名称 */
     , D_SALE_DEPT                                                        /* 业务管理单元 */
     , F_TGK_GET_DIMNAME('D_SALE_DEPT', D_SALE_DEPT) AS D_SALE_DEPT_DESC  /* 业务管理单元名称 */
     , BD_BASE_0_AMT                                                      /* 坏账计提基数金额 */
     , BD_BASE_1_AMT                                                      /* 坏账计提基数金额-1个月 */
     , BD_BASE_2_AMT                                                      /* 坏账计提基数金额-2-3个月 */
     , BD_BASE_3_AMT                                                      /* 坏账计提基数金额-4-6个月 */
     , BD_BASE_4_AMT                                                      /* 坏账计提基数金额- 7-12个月 */
     , BD_BASE_5_AMT                                                      /* 坏账计提基数金额- 1-2年 */
     , BD_BASE_6_AMT                                                      /* 坏账计提基数金额-2-3年 */
     , BD_BASE_7_AMT                                                      /* 坏账计提基数金额- 3-4年 */
     , BD_BASE_8_AMT                                                      /* 坏账计提基数金额-4-5年 */
     , BD_BASE_9_AMT                                                      /* 坏账计提基数金额-5年以上 */
     , BD_BASE_10_AMT                                                     /* 坏账计提基数金额-账龄区间段10 */
     , BD_BASE_11_AMT                                                     /* 坏账计提基数金额-账龄区间段11 */
     , BD_BASE_12_AMT                                                     /* 坏账计提基数金额-账龄区间段12 */
     , BD_BASE_13_AMT                                                     /* 坏账计提基数金额-账龄区间段13 */
     , BD_BASE_14_AMT                                                     /* 坏账计提基数金额-账龄区间段14 */
     , BD_BASE_15_AMT                                                     /* 坏账计提基数金额-账龄区间段15 */
     , BD_BASE_0_AMT - BD_BASE_1_AMT - BD_BASE_2_AMT - BD_BASE_3_AMT      /* 坏账计提基数金额 */
       - BD_BASE_4_AMT - BD_BASE_5_AMT - BD_BASE_6_AMT - BD_BASE_7_AMT
       - BD_BASE_8_AMT - BD_BASE_9_AMT - BD_BASE_10_AMT - BD_BASE_11_AMT
       - BD_BASE_12_AMT - BD_BASE_13_AMT - BD_BASE_14_AMT - BD_BASE_15_AMT AS CHECK1  /* 校验：坏账基数总额减各分段合计 */
     , SPID_0_AMT                                                 /* 个别认定 */
     , BD_0_AMT                                   /* 坏账计提金额 */
     , BD_1_AMT                                   /* 坏账计提金额-1个月 */
     , BD_2_AMT                                   /* 坏账计提金额-2-3个月 */
     , BD_3_AMT                                   /* 坏账计提金额-4-6个月 */
     , BD_4_AMT                                   /* 坏账计提金额- 7-12个月 */
     , BD_5_AMT                                   /* 坏账计提金额- 1-2年 */
     , BD_6_AMT                                   /* 坏账计提金额-2-3年 */
     , BD_7_AMT                                   /* 坏账计提金额- 3-4年 */
     , BD_8_AMT                                   /* 坏账计提金额-4-5年 */
     , BD_9_AMT                                   /* 坏账计提金额-5年以上 */
     , BD_10_AMT                                  /* 坏账计提金额-账龄区间段10 */
     , BD_11_AMT                                  /* 坏账计提金额-账龄区间段11 */
     , BD_12_AMT                                  /* 坏账计提金额-账龄区间段12 */
     , BD_13_AMT                                  /* 坏账计提金额-账龄区间段13 */
     , BD_14_AMT                                  /* 坏账计提金额-账龄区间段14 */
     , BD_15_AMT                                  /* 坏账计提金额-账龄区间段15 */
     , BD_0_AMT - BD_1_AMT - BD_2_AMT - BD_3_AMT  /* 坏账计提金额 */
       - BD_4_AMT - BD_5_AMT - BD_6_AMT - BD_7_AMT
       - BD_8_AMT - BD_9_AMT - BD_10_AMT - BD_11_AMT
       - BD_12_AMT - BD_13_AMT - BD_14_AMT - BD_15_AMT AS CHECK2  /* 校验：坏账计提总额减各分段合计 */
     , BD_ALLOC_RATIO                                             /* 坏账分摊比例 */
     , AGE_ALLOC_0_AMT                                            /* 负账龄分摊金额 */
     , AGE_ALLOC_1_AMT                                            /* 负账龄分摊金额-1个月 */
     , AGE_ALLOC_2_AMT                                            /* 负账龄分摊金额-2-3个月 */
     , AGE_ALLOC_3_AMT                                            /* 负账龄分摊金额-4-6个月 */
     , AGE_ALLOC_4_AMT                                            /* 负账龄分摊金额- 7-12个月 */
     , AGE_ALLOC_5_AMT                                            /* 负账龄分摊金额- 1-2年 */
     , AGE_ALLOC_6_AMT                                            /* 负账龄分摊金额-2-3年 */
     , AGE_ALLOC_7_AMT                                            /* 负账龄分摊金额- 3-4年 */
     , AGE_ALLOC_8_AMT                                            /* 负账龄分摊金额-4-5年 */
     , AGE_ALLOC_9_AMT                                            /* 负账龄分摊金额-5年以上 */
     , AGE_ALLOC_10_AMT                                           /* 负账龄分摊金额-账龄区间段10 */
     , AGE_ALLOC_11_AMT                                           /* 负账龄分摊金额-账龄区间段11 */
     , AGE_ALLOC_12_AMT                                           /* 负账龄分摊金额-账龄区间段12 */
     , AGE_ALLOC_13_AMT                                           /* 负账龄分摊金额-账龄区间段13 */
     , AGE_ALLOC_14_AMT                                           /* 负账龄分摊金额-账龄区间段14 */
     , AGE_ALLOC_15_AMT                                           /* 负账龄分摊金额-账龄区间段15 */
     , AGE_ALLOC_0_AMT - AGE_ALLOC_1_AMT - AGE_ALLOC_2_AMT - AGE_ALLOC_3_AMT  /* 负账龄分摊金额 */
       - AGE_ALLOC_4_AMT - AGE_ALLOC_5_AMT - AGE_ALLOC_6_AMT - AGE_ALLOC_7_AMT
       - AGE_ALLOC_8_AMT - AGE_ALLOC_9_AMT - AGE_ALLOC_10_AMT - AGE_ALLOC_11_AMT
       - AGE_ALLOC_12_AMT - AGE_ALLOC_13_AMT - AGE_ALLOC_14_AMT - AGE_ALLOC_15_AMT AS CHECK3  /* 校验：负账龄分摊总额减各分段合计 */
     , BD_AFAL_0_AMT                                                  /* 分摊后坏账金额 */
     , BD_AFAL_1_AMT                                                  /* 分摊后坏账金额-1个月 */
     , BD_AFAL_2_AMT                                                  /* 分摊后坏账金额-2-3个月 */
     , BD_AFAL_3_AMT                                                  /* 分摊后坏账金额-4-6个月 */
     , BD_AFAL_4_AMT                                                  /* 分摊后坏账金额- 7-12个月 */
     , BD_AFAL_5_AMT                                                  /* 分摊后坏账金额- 1-2年 */
     , BD_AFAL_6_AMT                                                  /* 分摊后坏账金额-2-3年 */
     , BD_AFAL_7_AMT                                                  /* 分摊后坏账金额- 3-4年 */
     , BD_AFAL_8_AMT                                                  /* 分摊后坏账金额-4-5年 */
     , BD_AFAL_9_AMT                                                  /* 分摊后坏账金额-5年以上 */
     , BD_AFAL_10_AMT                                                 /* 分摊后坏账金额-账龄区间段10 */
     , BD_AFAL_11_AMT                                                 /* 分摊后坏账金额-账龄区间段11 */
     , BD_AFAL_12_AMT                                                 /* 分摊后坏账金额-账龄区间段12 */
     , BD_AFAL_13_AMT                                                 /* 分摊后坏账金额-账龄区间段13 */
     , BD_AFAL_14_AMT                                                 /* 分摊后坏账金额-账龄区间段14 */
     , BD_AFAL_15_AMT                                                 /* 分摊后坏账金额-账龄区间段15 */
     , BD_AFAL_0_AMT - BD_AFAL_1_AMT - BD_AFAL_2_AMT - BD_AFAL_3_AMT  /* 分摊后坏账金额 */
       - BD_AFAL_4_AMT - BD_AFAL_5_AMT - BD_AFAL_6_AMT - BD_AFAL_7_AMT
       - BD_AFAL_8_AMT - BD_AFAL_9_AMT - BD_AFAL_10_AMT - BD_AFAL_11_AMT
       - BD_AFAL_12_AMT - BD_AFAL_13_AMT - BD_AFAL_14_AMT - BD_AFAL_15_AMT AS CHECK4  /* 校验：分摊后坏账总额减各分段合计 */
     , LM_BD_AFAL_0_AMT      /* 上月-分摊后坏账金额 */
     , WRITEOFF_AMT          /* 核销金额 */
     , MTD_BD_PROV_OCUR_AMT  /* 本月应计提坏账发生额 */
     , A.USERUPD             /* 更新用户 */
     , A.DATEUPD             /* 更新时间 */
  FROM AW_MR9_ARPM02_000001 A
  LEFT JOIN CONTO
    ON A.COD_CONTO = CONTO.COD_CONTO
 WHERE COD_SCENARIO = ${$Scenario.code}
   AND COD_PERIODO = ${$Period.code}
   AND COD_AZIENDA IN (${$Entity.code})
   AND ME_AGE_FLAG IN ('AR', 'OR', 'CA')
   /* 金额全为 0 的记录不输出 */
   AND (
        NVL(A.BD_BASE_0_AMT, 0) <> 0
        OR NVL(A.SPID_0_AMT, 0) <> 0
        OR NVL(A.BD_0_AMT, 0) <> 0
        OR NVL(A.AGE_ALLOC_0_AMT, 0) <> 0
        OR NVL(A.BD_AFAL_0_AMT, 0) <> 0
        OR NVL(A.LM_BD_AFAL_0_AMT, 0) <> 0
        OR NVL(A.WRITEOFF_AMT, 0) <> 0
        OR NVL(A.MTD_BD_PROV_OCUR_AMT, 0) <> 0
       )
   AND COD_CATEGORIA IN ('ZAMOUNT')
 ORDER BY COD_AZIENDA
        , A.COD_CONTO
