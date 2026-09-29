-- DORIS sql 
-- ******************************************************************** --
-- author: yanghao4.ex
-- create time: 2025/12/20 11:42:27 GMT+08:00
-- 20260709 新增在映射表范围内的公司，且物料在物料大表中，业务范围取物料大表的业务范围
-- 20260722 新增业务管理单元判断新增业务范围，因为之前只有2000和3000，代码中没写，现在新增了逻辑，需要加上
-- 20260722 修改bseg、bkpf表使用结尾是_v的
-- ******************************************************************** --

-- 调用'{UDP1}'-->'20250501'年月日，日固定为01，{UDP2}最后一个insert需要修改分区，p2025056，p+年月+6

set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;


--set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';

/*为确保有分区不会报错，先插入一条数据*/
--INSERT INTO dwd.dwd_fi_mr_cogs_inv_mi (dt_month) VALUES ('202511');

INSERT INTO dwd.dwd_fi_mr_cogs_inv_mi (dt_month) VALUES (LEFT(@year_month_day,6));

/***********************************库存插入开始*************************************/
 INSERT OVERWRITE TABLE dwd.dwd_fi_mr_cogs_inv_mi PARTITION (*)

--INSERT OVERWRITE TABLE dwd.dwd_fi_mr_cogs_inv_mi PARTITION ({{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}})

(dt_month,year,month,company_code,material_code,onoffline_code,onoffline_name,product_line_code,material_name,
 product_line_name,model_code,model_name,inv_qty,qcy_code,inv_amt,system_src,ods_src,amt_acct_code,qty_acct_code,inv_location,
 marketing_dept_code,marketing_dept_name,brand_code,brand_name,material_group_code,material_group_name,bus_range_code,bus_range_name,customer_model,load_dt,ZCALASSET,MAKTX_S810,
 profitcenter_code,product_big_class_code,
product_big_class_name,
product_mid_class_code,
product_mid_class_name,
product_small_class_code,
product_small_class_name
)


SELECT 
  LEFT(@year_month_day,6) DT_MONTH, /* 年月*/
  LEFT(@year_month_day,4) YEAR, /*财务年*/
  SUBSTR(@year_month_day,5,2) MONTH, /*财务月*/
  A.ENTITY COMPANY_CODE, /*组织*/
  A.MATNR MATERIAL_CODE, /*物料编码*/
  (CASE WHEN PROD.PRODUCT_TYPE = '电子商务机' THEN '020_ON_002' ELSE '020_OFF_002' END) ONOFFLINE_CODE, /*线上线下编码*/
  (CASE WHEN (CASE WHEN PROD.PRODUCT_TYPE = '电子商务机' THEN '020_ON_002' ELSE '020_OFF_002' END) = '020_ON_002' THEN '主站' 
      ELSE '零售-传统零售' END) ONOFFLINE_NAME, /*线上线下名称*/
  '' PRODUCT_LINE_CODE, /*产品线编码*/
  PROD.product_name AS MATERIAL_NAME, /*物料名称*/
  PROD.PROD_LINE_NAME PRODUCT_LINE_NAME, /*产品线名称*/
  COALESCE(IF(TRIM(PROD.zzprdmodel)= '',NULL,TRIM(PROD.zzprdmodel))
            ,IF(TRIM(PROD.zfacmodel)= '',NULL,TRIM(PROD.zfacmodel))
            ,IF(TRIM(PROD.pmodel_number)= '',NULL,TRIM(PROD.pmodel_number))
            ) AS MODEL_CODE, /*产品型号编码*/
  PROD.MODEL_NAME MODEL_NAME, /*产品型号名称*/
  A.INVSL INV_QTY, /*库存数量*/
  AZI.COD_VALUTA QCY_CODE, /*货币-交易币*/
  A.INVJE INV_AMT, /*库存金额*/
  A.SYSTEM_SRC,/*源系统*/
  A.ODS_SRC, /*源表*/
  A.ACCOUNT amt_acct_code,/*金额科目编码*/
  A.ACC_SL qty_acct_code, /*数量科目编码*/
  A.LGORT INV_LOCATION,/*库位*/
  /*
  20260127ZZS修改：
  优先级1：映射表有维护业务范围的，通过业务范围+物料匹配映射表对应字段，取业务管理单元；（优先级更高）；没有业务范围的，通过物料匹配映射表对应字段，取业务管理单元
  优先级2：20260128ZZS修改：匹配空调物料组、业务范围、利润中心映射业务管理单元（见本文件业务管理单元sheet），对符合条件的数据，映射业务管理单元；
  其中物料组为1209901、1209905、G209901，且业务范围不为2358、A004、2357的数据，固定输出1209901，不通过配置表进行映射。
  ①物料组+业务范围
  ②物料组
  ③利润中心
  ④业务范围
  优先级3：直接对应
  20251222ZZS修改：限制【组织
  company_code】为62、68开头的公司
  */
  CASE WHEN SUBSTR(A.ENTITY, 1, 2) IN ('62', '68') OR A.ENTITY IN ('6012','6015')
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,
                         Mapping_Bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                        CASE WHEN 
                              CASE WHEN  A.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
                                    WHEN  A.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
                                    ELSE '' 
                              END IN ('1209901','1209905','G209901')
                             AND 
                             CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
                                  WHEN NULLIF(TRIM(A.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
                                  WHEN NULLIF(TRIM(A.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
                                  ELSE '3000' 
                             END NOT IN ('2358','A004','2357')
                          THEN '1209901' 
                          ELSE NULL 
                        END ,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         CASE WHEN  A.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
                WHEN  A.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
                ELSE '' END 
                         )
          ELSE '' 
     END
  AS MARKETING_DEPT_CODE,/*所属营销部门编码（业务管理单元编码）*/
  
  ''/* CASE WHEN A.SYSTEM_SRC = 'S600' THEN S600.WGBEZ
     WHEN A.SYSTEM_SRC = 'S800' THEN S800.WGBEZ
     WHEN A.SYSTEM_SRC = 'S900' THEN S900.WGBEZ
  END */ MARKETING_DEPT_NAME,/*所属营销部门描述（业务管理单元描述）*/
  PROD.brand BRAND_CODE,/*品牌编码*/
  PROD.brand_name BRAND_NAME,/*品牌名称*/
  /*CASE WHEN (SUBSTR(A.ENTITY,1,2) IN ('62','68') OR A.ENTITY IN ('6012','6015')) AND A.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
     WHEN (SUBSTR(A.ENTITY,1,2) IN ('62','68') OR A.ENTITY IN ('6012','6015')) AND A.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
     ELSE '' END AS material_group_code,*/
     CASE WHEN A.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
     WHEN A.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
     ELSE '' END AS material_group_code,
     /*物料组*/
  CASE WHEN A.SYSTEM_SRC = 'S600' THEN S600.WGBEZ
     WHEN A.SYSTEM_SRC = 'S800' THEN S800.WGBEZ
     WHEN A.SYSTEM_SRC = 'S900' THEN S900.WGBEZ
  END material_group_name,/*物料组描述*/
  CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(A.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(A.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' 
  END BUS_RANGE_CODE,/*业务范围编码*/ 
  CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_NAME
     WHEN CASE WHEN NULLIF(TRIM(A.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
     WHEN NULLIF(TRIM(A.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
     ELSE '3000' END = '2000' THEN '中国区公共'
       WHEN CASE WHEN NULLIF(TRIM(A.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
     WHEN NULLIF(TRIM(A.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
     ELSE '3000' END = '3000' THEN '海外公共'
    ELSE ''
  END BUS_RANGE_NAME,/*业务范围名称*/ 
  PROD.zcusmodel customer_model,/*客户型号*/ 
  NOW() LOAD_DT, /*更新时间*/
  PROD.ZCALASSET,
  PROD.MAKTX_S810,
  CASE WHEN NVL(TRIM(PROFIT_MAPING.profitcenter_code),'') = '' THEN PROD.profitcenter_code ELSE PROFIT_MAPING.profitcenter_code END AS profitcenter_code,  --利润中心编码
  PROD.BIG_CLASS_CODE AS product_big_class_code, 	--产品大类编码
  PROD.BIG_CLASS_NAME AS product_big_class_name,		--产品大类名称
  PROD.MIDDLE_CLASS_CODE AS product_mid_class_code,	--产品中类编码
  PROD.MIDDLE_CLASS_NAME AS product_mid_class_name,	--产品中类名称
  PROD.SMALL_CLASS_CODE AS product_small_class_code,	--产品小类编码
  PROD.SMALL_CLASS_NAME AS product_small_class_name	--产品小类名称
FROM 
(
  /*S600取数*/
  SELECT BWKEY ENTITY,MATNR,SUM(MBWBEST) INVSL,SUM(WBWBEST) INVJE,LGORT,'S600' SYSTEM_SRC,'SQIV000' ACCOUNT,'SQI0000' ACC_SL,'MC.9' ODS_SRC
  FROM ods.ODSS600_S039 S039
  /*关联取出公司*/
  INNER JOIN
  (SELECT BWKEY,BUKRS FROM ods.ODS_S600_T001K) ENT
  ON S039.WERKS = ENT.BWKEY
  WHERE SPMON = LEFT(@year_month_day,6)
  AND MATNR NOT LIKE '0000%' 
  /* 剔除冰箱公司，1340101、1340201这俩物料组的物料库存  MODIFY BY WANGXIAOYU 20220330 */
  AND NOT (WERKS ='6700' AND (MATKL ='1340101' OR MATKL ='1340201'))
  /*AND MATNR NOT LIKE 'Z%' */
  /*越南工厂 2023 20241101 只取 7920 */
  AND  (WERKS LIKE '2023' AND BKLAS='7920'
     OR WERKS NOT IN ('2023')
    )  
  GROUP BY BWKEY,MATNR,LGORT
  
  UNION ALL 
  
  
  
/*1405030000,1405990000余额不包含电器公司*/
  SELECT 
    t.RBUKRS AS ENTITY,
    '' AS MATNR,
    0 AS INVSL,
    CASE m.MON
        WHEN 'HSLVT' THEN t.HSLVT
        WHEN 'HSL01' THEN t.HSLVT+t.HSL01
        WHEN 'HSL02' THEN t.HSLVT+t.HSL01+t.HSL02
        WHEN 'HSL03' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03
        WHEN 'HSL04' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04
        WHEN 'HSL05' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05
        WHEN 'HSL06' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06
        WHEN 'HSL07' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07
        WHEN 'HSL08' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08
        WHEN 'HSL09' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09
        WHEN 'HSL10' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10
        WHEN 'HSL11' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10+t.HSL11
        WHEN 'HSL12' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10+t.HSL11+t.HSL12
    END AS INVJE,
    NULL AS LGORT,'S600' SYSTEM_SRC,
    'SQIV00A' AS ACCOUNT,
    'SQI000A' AS ACC_SL,
    CONCAT('GL',t.RACCT) AS ODS_SRC
  FROM ods.ods_slt_s600_faglflext t
  CROSS JOIN (
    SELECT 'HSLVT' AS MON UNION ALL
    SELECT 'HSL01' UNION ALL
    SELECT 'HSL02' UNION ALL
    SELECT 'HSL03' UNION ALL
    SELECT 'HSL04' UNION ALL
    SELECT 'HSL05' UNION ALL
    SELECT 'HSL06' UNION ALL
    SELECT 'HSL07' UNION ALL
    SELECT 'HSL08' UNION ALL
    SELECT 'HSL09' UNION ALL
    SELECT 'HSL10' UNION ALL
    SELECT 'HSL11' UNION ALL
    SELECT 'HSL12'
  ) m
  WHERE t.RYEAR = SUBSTR(@year_month_day, 1, 4)
    AND t.RACCT IN ('1405030000', '1405990000')
    AND (m.MON = CONCAT('HSL', SUBSTR(@year_month_day, 5, 2)))
    AND (t.RBUKRS NOT IN ('2082', '2050', '2080', '2023', '1630', '1632') 
       AND t.RBUKRS NOT LIKE '26%' 
       AND (t.RBUKRS < '2300' OR t.RBUKRS > '2310'))
    AND NOT (t.RBUKRS = '6800' AND t.RACCT IN ('1405990000'))
  HAVING INVJE <> 0
  
  UNION ALL

/*股份RETURN STOCK*/
SELECT RBUKRS ENTITY,'' MATNR,0 SDSL,
CASE m.MON
        WHEN 'HSLVT' THEN t.HSLVT
        WHEN 'HSL01' THEN t.HSLVT+t.HSL01
        WHEN 'HSL02' THEN t.HSLVT+t.HSL01+t.HSL02
        WHEN 'HSL03' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03
        WHEN 'HSL04' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04
        WHEN 'HSL05' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05
        WHEN 'HSL06' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06
        WHEN 'HSL07' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07
        WHEN 'HSL08' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08
        WHEN 'HSL09' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09
        WHEN 'HSL10' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10
        WHEN 'HSL11' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10+t.HSL11
        WHEN 'HSL12' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10+t.HSL11+t.HSL12
    END AS INVJE,NULL AS LGORT,'S600' SYSTEM_SRC
    ,'SQIV00R' ACCOUNT,'SQI000R' ACC_SL,CONCAT('GL',RACCT) SRC

  FROM ods.ods_slt_s600_faglflext t
  CROSS JOIN (
    SELECT 'HSLVT' AS MON UNION ALL
    SELECT 'HSL01' UNION ALL
    SELECT 'HSL02' UNION ALL
    SELECT 'HSL03' UNION ALL
    SELECT 'HSL04' UNION ALL
    SELECT 'HSL05' UNION ALL
    SELECT 'HSL06' UNION ALL
    SELECT 'HSL07' UNION ALL
    SELECT 'HSL08' UNION ALL
    SELECT 'HSL09' UNION ALL
    SELECT 'HSL10' UNION ALL
    SELECT 'HSL11' UNION ALL
    SELECT 'HSL12'
  ) m
WHERE t.RYEAR = SUBSTR(@year_month_day, 1, 4)
AND (RBUKRS LIKE '2%' OR RBUKRS IN ('1630','1632') AND LTRIM(PRCTR,0)  in ('16300307','1100126','1100106','1100127','16300303','1820401','16300305','1100130','104001001','104051000','101001001','104003002')) /*1630公司只取16300307产品线 modify by lijunyu 20200702*/
AND RACCT IN ('1405010000','1405020000')
--AND (m.MON = 'HSLVT' OR m.MON <= CONCAT('HSL', SUBSTR(@year_month_day, 5, 2)))
AND (m.MON = CONCAT('HSL', SUBSTR(@year_month_day, 5, 2)))
    UNION ALL 
  
  
  
 /*1405040000余额-电器公司MODIFY BY ZHOUHONG 20190624*/
  SELECT 
    t.RBUKRS AS ENTITY,
    '' AS MATNR,
    0 AS INVSL,
    CASE m.MON
        WHEN 'HSLVT' THEN t.HSLVT
        WHEN 'HSL01' THEN t.HSLVT+t.HSL01
        WHEN 'HSL02' THEN t.HSLVT+t.HSL01+t.HSL02
        WHEN 'HSL03' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03
        WHEN 'HSL04' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04
        WHEN 'HSL05' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05
        WHEN 'HSL06' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06
        WHEN 'HSL07' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07
        WHEN 'HSL08' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08
        WHEN 'HSL09' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09
        WHEN 'HSL10' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10
        WHEN 'HSL11' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10+t.HSL11
        WHEN 'HSL12' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10+t.HSL11+t.HSL12
    END AS INVJE,
    NULL AS LGORT,'S600' SYSTEM_SRC,
    'SQIV00A' AS ACCOUNT,
    'SQI000A' AS ACC_SL,
    CONCAT('GL',t.RACCT) AS ODS_SRC
  FROM ods.ods_slt_s600_faglflext t
  CROSS JOIN (
    SELECT 'HSLVT' AS MON UNION ALL
    SELECT 'HSL01' AS MON UNION ALL
    SELECT 'HSL02' UNION ALL
    SELECT 'HSL03' UNION ALL
    SELECT 'HSL04' UNION ALL
    SELECT 'HSL05' UNION ALL
    SELECT 'HSL06' UNION ALL
    SELECT 'HSL07' UNION ALL
    SELECT 'HSL08' UNION ALL
    SELECT 'HSL09' UNION ALL
    SELECT 'HSL10' UNION ALL
    SELECT 'HSL11' UNION ALL
    SELECT 'HSL12'
  ) m
  WHERE t.RYEAR = SUBSTR(@year_month_day, 1, 4)
  AND t.RACCT IN (/*'1405030000',*/'1405040000'/*,'1405990000'*/)
  AND m.MON = CONCAT('HSL',SUBSTR(@year_month_day,5,2))
  AND (t.RBUKRS IN ('2082','2050','2080','2023','1630','1632') OR t.RBUKRS LIKE '26%' OR t.RBUKRS BETWEEN '2300' AND '2310')
  HAVING INVJE <> 0
  
  
    UNION ALL 
  
  
  
 /*1405040000余额不含电器公司MODIFY BY ZHOUHONG 20190624*/
  SELECT 
    t.RBUKRS AS ENTITY,
    '' AS MATNR,
    0 AS INVSL,
    CASE m.MON
        WHEN 'HSLVT' THEN t.HSLVT
        WHEN 'HSL01' THEN t.HSLVT+t.HSL01
        WHEN 'HSL02' THEN t.HSLVT+t.HSL01+t.HSL02
        WHEN 'HSL03' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03
        WHEN 'HSL04' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04
        WHEN 'HSL05' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05
        WHEN 'HSL06' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06
        WHEN 'HSL07' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07
        WHEN 'HSL08' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08
        WHEN 'HSL09' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09
        WHEN 'HSL10' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10
        WHEN 'HSL11' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10+t.HSL11
        WHEN 'HSL12' THEN t.HSLVT+t.HSL01+t.HSL02+t.HSL03+t.HSL04+t.HSL05+t.HSL06+t.HSL07+t.HSL08+t.HSL09+t.HSL10+t.HSL11+t.HSL12
    END AS INVJE,
    NULL AS LGORT,'S600' SYSTEM_SRC,
    'SQIV00A' AS ACCOUNT,
    'SQI000A' AS ACC_SL,
    CONCAT('GL',t.RACCT) AS ODS_SRC
  FROM ods.ods_slt_s600_faglflext t
  CROSS JOIN (
    SELECT 'HSLVT' AS MON UNION ALL
    SELECT 'HSL01' UNION ALL
    SELECT 'HSL02' UNION ALL
    SELECT 'HSL03' UNION ALL
    SELECT 'HSL04' UNION ALL
    SELECT 'HSL05' UNION ALL
    SELECT 'HSL06' UNION ALL
    SELECT 'HSL07' UNION ALL
    SELECT 'HSL08' UNION ALL
    SELECT 'HSL09' UNION ALL
    SELECT 'HSL10' UNION ALL
    SELECT 'HSL11' UNION ALL
    SELECT 'HSL12'
  ) m
  WHERE t.RYEAR = SUBSTR(@year_month_day, 1, 4)
   AND t.RACCT IN (/*'1405030000',*/'1405040000'/*,'1405990000'*/)
  AND (m.MON = CONCAT('HSL',SUBSTR(@year_month_day,5,2)))
  AND (t.RBUKRS NOT  IN ('2082','2050','2080','2023','1630','1632') AND t.RBUKRS NOT LIKE '26%' AND t.RBUKRS NOT BETWEEN '2300' AND '2310')
  HAVING INVJE <> 0
  

  UNION ALL 
  /*发出商品当月凭证 BSEG*/
  SELECT BSEG.BUKRS ENTITY,BSEG.MATNR,SUM(CASE WHEN BSEG.SHKZG ='H' THEN -1 * BSEG.MENGE ELSE MENGE END) AS INVSL,
  SUM(CASE WHEN BSEG.SHKZG = 'H' THEN -1*BSEG.DMBTR ELSE BSEG.DMBTR END) AS INVJE,NULL AS LGORT,'S600' SYSTEM_SRC,'SQIV00F' ACCOUNT
  ,'SQI000F' ACC_SL,CONCAT('BSEG',HKONT) ODS_SRC
  FROM ods.ods_slt_s600_bseg_v BSEG
  INNER JOIN (SELECT * 
               FROM ods.ods_slt_s600_bkpf_v 
              WHERE GJAHR = SUBSTR(@year_month_day,1,4)
                AND MONAT = SUBSTR(@year_month_day,5,2)
             ) BKPF
    ON BSEG.BELNR = BKPF.BELNR 
    AND BSEG.GJAHR = BKPF.GJAHR 
    AND BSEG.BUKRS = BKPF.BUKRS
  
  WHERE 1 = 1
  AND BSEG.GJAHR = LEFT(@year_month_day,4)
  AND BKPF.MONAT = SUBSTR(@year_month_day,5,2)  
  AND HKONT = '1405050000'
  AND ((BSEG.BUKRS IN ('6380','6797') AND MATNR NOT LIKE '0%') OR BSEG.BUKRS NOT IN ('6380','6797'))  /*20251121 WANGHAODE 新增6797公司*/
  GROUP BY BSEG.BUKRS,BSEG.MATNR,CONCAT('BSEG',HKONT)

  UNION ALL
  /*1405030000,1405990000电器公司本期发生额*/
  SELECT BSEG.BUKRS ENTITY,BSEG.MATNR,SUM(CASE WHEN SHKZG ='H' THEN -1*MENGE ELSE MENGE END) AS INVSL,
  SUM(CASE WHEN SHKZG = 'H' THEN -1*DMBTR ELSE DMBTR END) AS INVJE,NULL AS LGORT,'S600' SYSTEM_SRC,'SQIV00A' ACCOUNT,
  'SQI000A' ACC_SL,CONCAT('BSEG',HKONT) SRC
  FROM ods.ods_slt_s600_bseg_v  BSEG
  INNER JOIN (SELECT * 
               FROM ods.ods_slt_s600_bkpf_v 
              WHERE GJAHR = SUBSTR(@year_month_day,1,4)
                AND MONAT = SUBSTR(@year_month_day,5,2)
             ) BKPF
    ON BSEG.BELNR = BKPF.BELNR 
    AND BSEG.GJAHR = BKPF.GJAHR 
    AND BSEG.BUKRS = BKPF.BUKRS
    
  WHERE ((HKONT IN ('1405030000','1405990000')) OR (HKONT = '1405999900' AND @year_month_day >= '201807'))
  AND (BSEG.BUKRS  IN ('2082','2050','2080','2023','1630','1632') OR BSEG.BUKRS  LIKE '26%' OR BSEG.BUKRS  BETWEEN '2300' AND '2310') 
  GROUP BY MATNR,BSEG.BUKRS,CONCAT('BSEG',HKONT)
  HAVING SUM(CASE WHEN SHKZG ='H' THEN -1*MENGE ELSE MENGE END) <> 0
  OR SUM(CASE WHEN SHKZG = 'H' THEN -1*DMBTR ELSE DMBTR END) <> 0
  
  UNION ALL 
  
  /*ZSD060Z*/
  SELECT BUKRS ENTITY,MATNR,SUM(THMNG) INVSL,SUM(THDMB) INVJE,NULL AS LGORT,'S600' SYSTEM_SRC,'SQIV00R' ACCOUNT,'SQI000R' ACC_SL,'ZSD060Z' ODS_SRC
  FROM ods.ODSS600_ZSD060Z
  WHERE 1 = 1
  AND GJAHR = LEFT(@year_month_day,4)
  AND MONAT = SUBSTR(@year_month_day,5,2)
  AND BUKRS NOT LIKE '2%' AND BUKRS <> '1630' and BUKRS <> '1632'
  GROUP BY BUKRS,MATNR
  
  UNION ALL 
  
  /*STOCK ON THE WAY*/
  SELECT BUKRS ENTITY,MATNR,SUM(ZTMNG) INVSL,SUM(ZTDMB) INVJE,NULL AS LGORT,'S600' SYSTEM_SRC,'SQIV00Z' ACCOUNT,'SQI000Z' ACC_SL,'ZSD060Z' ODS_SRC
  FROM ods.ODSS600_ZSD060Z
  WHERE 1 = 1
  AND GJAHR = LEFT(@year_month_day,4)
  AND MONAT = SUBSTR(@year_month_day,5,2)
  GROUP BY BUKRS,MATNR
  
  UNION ALL 
  /*S800取数*/
  SELECT P.BUKRS ENTITY,TRIM(MATNR) MATNR
        ,SUM(GSBEST) INVSL
        ,SUM(WBWBEST) INVJE
        ,LGORT,'S800' SYSTEM_SRC,'SQIV000' ACCOUNT,'SQI0000' ACC_SL,'MC.9' ODS_SRC
  FROM ods.ODSS800_S039 S 
  INNER JOIN (SELECT BWKEY,BUKRS FROM ods.ODS_S800_T001K) P 
  ON S.WERKS=P.BWKEY
  WHERE SPMON = LEFT(@year_month_day,6)
  AND MATNR NOT LIKE '0000%' 
  AND S.WERKS IN('2001','2900') 
  AND MTART='FERT'
  GROUP BY P.BUKRS,TRIM(MATNR),LGORT

  UNION ALL 

  SELECT BSEG.BUKRS AS ENTITY,TRIM(MATNR) MATNR
        ,SUM(CASE WHEN SHKZG ='H' THEN -1*MENGE ELSE MENGE END) AS INVSL
        ,SUM(CASE WHEN SHKZG = 'H' THEN -1*DMBTR ELSE DMBTR END) AS INVJE
        ,NULL LGORT,'S800' SYSTEM_SRC,'SQIV00A' ACCOUNT,'SQI000A' ACC_SL,CONCAT('BSEG',HKONT) ODS_SRC
  FROM ods.ods_slt_s800_bseg_v  BSEG 
    INNER JOIN (SELECT * 
                  FROM ods.ods_slt_s800_bkpf_v 
                 WHERE GJAHR = SUBSTR(@year_month_day,1,4)
                   AND MONAT = SUBSTR(@year_month_day,5,2)
             ) BKPF
    ON BSEG.BELNR = BKPF.BELNR 
    AND BSEG.GJAHR = BKPF.GJAHR 
    AND BSEG.BUKRS = BKPF.BUKRS 
  WHERE HKONT IN ('1232999201','1243999900','1243009000') 
  AND BSEG.BUKRS  IN ('2000','2900')
  GROUP BY MATNR,BSEG.BUKRS,CONCAT('BSEG',HKONT)
  
  UNION ALL 
  /*S900取数*/
  
  SELECT P.BUKRS ENTITY,MATNR
        ,SUM(GSBEST) INVSL
        ,SUM(WBWBEST) INVJE
        ,LGORT,'S900' SYSTEM_SRC,'SQIV000' ACCOUNT,'SQI0000' ACC_SL,'MC.9' ODS_SRC
  FROM ods.ODSS900_S039 S 
  INNER JOIN (SELECT BWKEY,BUKRS FROM ods.ODS_S900_T001K) P 
  ON S.WERKS=P.BWKEY
  WHERE SPMON = LEFT(@year_month_day,6)
  AND MATNR NOT LIKE '0000%' 
  GROUP BY P.BUKRS,MATNR,LGORT
  
  UNION ALL 
  
  /*1243001011科目余额*/
  /*SELECT  RBUKRS AS ENTITY,'' AS MATNR,0 AS INVSL,
  CASE  WHEN SUBSTR(@year_month_day,5,2) = '01'  THEN TSLVT+TSL01
      WHEN SUBSTR(@year_month_day,5,2) = '02'  THEN TSLVT+TSL01+TSL02
      WHEN SUBSTR(@year_month_day,5,2) = '03'  THEN TSLVT+TSL01+TSL02+TSL03
      WHEN SUBSTR(@year_month_day,5,2) = '04'  THEN TSLVT+TSL01+TSL02+TSL03+TSL04
      WHEN SUBSTR(@year_month_day,5,2) = '05'  THEN TSLVT+TSL01+TSL02+TSL03+TSL04+TSL05
      WHEN SUBSTR(@year_month_day,5,2) = '06'  THEN TSLVT+TSL01+TSL02+TSL03+TSL04+TSL05+TSL06
      WHEN SUBSTR(@year_month_day,5,2) = '07'  THEN TSLVT+TSL01+TSL02+TSL03+TSL04+TSL05+TSL06+TSL07
      WHEN SUBSTR(@year_month_day,5,2) = '08'  THEN TSLVT+TSL01+TSL02+TSL03+TSL04+TSL05+TSL06+TSL07+TSL08
      WHEN SUBSTR(@year_month_day,5,2) = '09'  THEN TSLVT+TSL01+TSL02+TSL03+TSL04+TSL05+TSL06+TSL07+TSL08+TSL09
      WHEN SUBSTR(@year_month_day,5,2) = '10'  THEN TSLVT+TSL01+TSL02+TSL03+TSL04+TSL05+TSL06+TSL07+TSL08+TSL09+TSL10
      WHEN SUBSTR(@year_month_day,5,2) = '11'  THEN TSLVT+TSL01+TSL02+TSL03+TSL04+TSL05+TSL06+TSL07+TSL08+TSL09+TSL10+TSL11
      WHEN SUBSTR(@year_month_day,5,2) = '12'  THEN TSLVT+TSL01+TSL02+TSL03+TSL04+TSL05+TSL06+TSL07+TSL08+TSL09+TSL10+TSL11+TSL12 
      ELSE 0 END AS INVJE,
      NULL AS LGORT,'S900' SYSTEM_SRC,'SQIV00A' ACCOUNT,'SQI000A' ACC_SL,'900GLFUNCT' ODS_SRC
  FROM ods.ODS_SLT_S900_GLFUNCT
  WHERE RYEAR = SUBSTR(@year_month_day,1,4)
  AND RACCT  IN('1243001011','1243009100','1243009000')*/

  SELECT BSEG.BUKRS AS ENTITY,TRIM(MATNR) MATNR
        ,SUM(CASE WHEN SHKZG ='H' THEN -1*MENGE ELSE MENGE END) AS INVSL
        ,SUM(CASE WHEN SHKZG = 'H' THEN -1*DMBTR ELSE DMBTR END) AS INVJE
        ,NULL LGORT,'S900' SYSTEM_SRC,'SQIV00A' ACCOUNT,'SQI000A' ACC_SL,CONCAT('BSEG',HKONT) ODS_SRC
  FROM ods.ods_slt_s900_bseg_v  BSEG 
    INNER JOIN (SELECT * 
          FROM ods.ods_slt_s900_bkpf_v
          WHERE GJAHR = SUBSTR(@year_month_day,1,4)
                  AND MONAT = SUBSTR(@year_month_day,5,2)
             ) BKPF
    ON BSEG.BELNR = BKPF.BELNR 
    AND BSEG.GJAHR = BKPF.GJAHR 
    AND BSEG.BUKRS = BKPF.BUKRS 
  WHERE HKONT IN('1243001011','1243009100','1243009000')
  GROUP BY MATNR,BSEG.BUKRS,CONCAT('BSEG',HKONT)
  

    UNION ALL 
  
    SELECT BSEG.BUKRS AS ENTITY,MATNR
          , SUM(CASE WHEN SHKZG ='H' THEN -1*MENGE ELSE MENGE END ) AS INVSL
          , SUM(CASE WHEN SHKZG = 'H' THEN -1*DMBTR ELSE DMBTR END) AS INVJE
          , NULL AS LGORT,'S900' SYSTEM_SRC,'SQIV00F' ACCOUNT,'SQI000F' ACC_SL,CONCAT('FCSP_BSEG',HKONT) ODS_SRC
    FROM ods.ods_slt_s900_bseg_v  BSEG 
    INNER JOIN (SELECT * 
          FROM ods.ods_slt_s900_bkpf_v 
          WHERE GJAHR = SUBSTR(@year_month_day,1,4)
                  AND MONAT = SUBSTR(@year_month_day,5,2)
             ) BKPF
    ON BSEG.BELNR = BKPF.BELNR 
    AND BSEG.GJAHR = BKPF.GJAHR 
    AND BSEG.BUKRS = BKPF.BUKRS 
    WHERE HKONT = '1243010000' 
    GROUP BY MATNR,BSEG.BUKRS,CONCAT('FCSP_BSEG',HKONT)
    
    UNION ALL 
    
    SELECT BSEG.BUKRS AS ENTITY,MATNR
        , SUM(CASE WHEN SHKZG ='H' THEN -1*MENGE ELSE MENGE END ) AS INVSL
        , SUM(CASE WHEN SHKZG = 'H' THEN -1*DMBTR ELSE DMBTR END) AS INVJE
        , NULL AS LGORT,'S900' SYSTEM_SRC,'SQIV00R' ACCOUNT,'SQI000R' ACC_SL,CONCAT('RETURN',HKONT) ODS_SRC
    FROM ods.ods_slt_s900_bseg_v BSEG 
    INNER JOIN (SELECT * 
          FROM ods.ods_slt_s900_bkpf_v 
          WHERE GJAHR = SUBSTR(@year_month_day,1,4)
                  AND MONAT = SUBSTR(@year_month_day,5,2)
             ) BKPF
    ON BSEG.BELNR = BKPF.BELNR 
    AND BSEG.GJAHR = BKPF.GJAHR 
    AND BSEG.BUKRS = BKPF.BUKRS 
    WHERE HKONT = '1243999001'
    GROUP BY MATNR,BSEG.BUKRS,CONCAT('RETURN',HKONT)
    
    
  
) A
/*物料大表*/
LEFT JOIN (SELECT maktx_s600,maktx_s800,maktx_s900,zzprdmodel,zfacmodel,ZZNXWX,profitcenter_code,MATNR,MAKTX_MDM,PMODEL_NUMBER,PROD_LINE,PROD_LINE_NAME,MODEL_CODE,MODEL_NAME,
            PRODUCT_TYPE,MATKL,SALE_AREA,ZCUSMODEL,ZCALASSET,MAKTX_S810,
            BIG_CLASS_CODE,BIG_CLASS_NAME,MIDDLE_CLASS_CODE,MIDDLE_CLASS_NAME,SMALL_CLASS_CODE,SMALL_CLASS_NAME,brand,brand_name
            ,product_name,BUS_RANGE_CODE,BUS_RANGE_NAME
            FROM dim.dim_fi_mr_product_dd) PROD 
ON A.MATNR = PROD.MATNR

-- removed unused join to dw.dim_product_base_info_dd to reduce cost

/*匹配公司主数据*/
LEFT JOIN (SELECT COD_AZIENDA,COD_VALUTA FROM ods.odsfima_azienda) AZI
ON AZI.COD_AZIENDA = A.ENTITY

/*匹配S600物料组名称*/
LEFT JOIN (SELECT MATKL,WGBEZ FROM ods.ODS_S600_T023T) S600
ON CASE WHEN A.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
     WHEN A.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
     ELSE '' END = S600.MATKL
AND A.SYSTEM_SRC = 'S600'

/*匹配S800物料组名称*/
LEFT JOIN (SELECT MATKL,WGBEZ FROM ods.ODS_S800_T023T) S800
ON CASE WHEN A.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
     WHEN A.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
     ELSE '' END = S800.MATKL
AND A.SYSTEM_SRC = 'S800'

/*匹配S900物料组名称*/
LEFT JOIN (SELECT MATKL,WGBEZ FROM ods.ODS_S900_T023T) S900
ON CASE WHEN A.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
     WHEN A.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
     ELSE '' END = S900.MATKL
AND A.SYSTEM_SRC = 'S900'

/*匹配利润中心,优先取映射表中的利润中心,否则取物料大表中的利润中心*/
LEFT JOIN (SELECT material_code,profitcenter_code FROM dim.dim_rule_fi_mr_mt2bd_mapping) PROFIT_MAPING
ON A.MATNR = PROFIT_MAPING.material_code
/*20260709 此配置表中的公司业务范围取物料大表*/
LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_prd_bus_company_configuration) comp_confin
  ON comp_confin.company_code = A.ENTITY

  /*业务范围兜底逻辑,匹配映射表取业务范围*/
    LEFT JOIN (SELECT COMPANY_CODE,BUS_RANGE_CODE FROM dim.dim_rule_fi_mr_BusScope_for_Company
        WHERE VALID_FR <= @year_month_day
        AND VALID_TO >= @year_month_day
  ) for_Company
  ON A.ENTITY = for_Company.COMPANY_CODE 

    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_AirConditioner_Materials_Mapping_Bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
			AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus1
    ON A.matnr = Mapping_Bus1.MATERIAL_CODE
   AND CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(A.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(A.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' 
  END = Mapping_Bus1.bus_range_code

    /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_AirConditioner_Materials_Mapping_Bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
			AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus2
    ON A.matnr = Mapping_Bus2.MATERIAL_CODE

    --新增业务管理单元取数逻辑
  LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
			      AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON REGEXP_REPLACE(CASE WHEN NVL(TRIM(PROFIT_MAPING.profitcenter_code),'') = '' THEN PROD.profitcenter_code ELSE PROFIT_MAPING.profitcenter_code END, '^0+', '') = profit_mapping0.profitcenter_code
    AND CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(A.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(A.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' 
  END = profit_mapping0.bus_range_code


  --新增业务管理单元取数逻辑
  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
				AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON CASE WHEN A.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
     WHEN  A.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
     ELSE '' END = TRIM(profit_mapping1.material_group_code)
    AND CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(A.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(A.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' 
  END = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
				AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON CASE WHEN A.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
     WHEN  A.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
     ELSE '' END = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
				AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON REGEXP_REPLACE(CASE WHEN NVL(LTRIM(PROFIT_MAPING.profitcenter_code,0),'') = '' THEN LTRIM(PROD.profitcenter_code,0) ELSE LTRIM(PROFIT_MAPING.profitcenter_code,0) END, '^0+', '') = LTRIM(profit_mapping3.profitcenter_code,0)
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
				AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(A.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(A.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' 
  END = profit_mapping4.bus_range_code   

WHERE 1 = 1
AND NOT (A.INVSL = 0 AND A.INVJE = 0)
AND (TRIM(NVL(PROD.MATNR,'')) = TRIM(NVL(A.MATNR,'')) /*or A.MATNR in('ZM230324WK01','ZM230424TD01')*/)
--AND A.MATNR IN (SELECT MATNR FROM dim_fi_mr_product_dd)
;
