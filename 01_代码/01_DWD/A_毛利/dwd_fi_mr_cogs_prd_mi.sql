-- DORIS sql 
-- ******************************************************************** --
-- author: yanghao4.ex{{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}}
-- create time: 2025/12/20 12:10:13 GMT+08:00
-- ******************************************************************** --

/********************************************
修改信息：
ALTER BY 20260617 XIAOYACHAO.EX 修改公司字段
ALTER BY 20260618 XIAOYACHAO.EX FIDATA-502
ALTER BY 20260709 SHIQINGFENG.EX 新增在映射表范围内的公司，且物料在物料大表中，业务范围取物料大表的业务范围
ALTER BY 20260723 SHIQINGFENG.EX 修改格式和新增业务管理单元判断新增业务范围，因为之前只有2000和3000，代码中没写，现在新增了逻辑，需要加上
*********************************************/

set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;

--set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';

/*为确保有分区不会报错，先插入一条数据*/
--INSERT INTO dwd.dwd_fi_mr_cogs_prd_mi (dt_month) VALUES ('202511');

INSERT INTO dwd.dwd_fi_mr_cogs_prd_mi (dt_month) VALUES (LEFT(@year_month_day,6));

/***********************************物料移动明细插入开始*************************************/
INSERT OVERWRITE TABLE dwd.dwd_fi_mr_cogs_prd_mi PARTITION (*)

--INSERT OVERWRITE TABLE dwd.dwd_fi_mr_cogs_prd_mi PARTITION ({{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}})

(year,month,company_code,cust_code,material_code,cust_name,onoffline_code,onoffline_name,
material_name,model_code,model_name,prd_qty,
qcy_code,prd_amt,system_src,ods_src,amt_acct_code,qty_acct_code,load_dt,dt_month,marketing_dept_code,marketing_dept_name,
brand_code,brand_name,material_group_code,bus_range_code,bus_range_name,customer_model,material_group_name,CP_COMPANY_CODE,zcalasset,maktx_s810
,profitcenter_code,product_small_class_code,product_big_class_code,
product_big_class_name,
product_mid_class_code,
product_mid_class_name,
product_small_class_name)


/*SAP900数据源确认*/
with mseg_900 AS 
(
SELECT TRIM(MATNR) MATNR,TRIM(WERKS) WERKS,TRIM(PPRCTR) PPRCTR,TRIM(m.AUFNR) AUFNR,TRIM(EBELN) EBELN,LTRIM(TRIM(LIFNR),'0') AS  LIFNR,SHKZG,MENGE,DMBTR
,BWART,p.BUKRS,AUART
FROM 
  (
  SELECT * 
    FROM ods.ods_slt_s900_mseg
   WHERE BUDAT_MKPF>LAST_DAY(ADD_MONTHS(TO_DATE(@year_month_day),-1)) 
     AND BUDAT_MKPF<ADD_MONTHS(TO_DATE(@year_month_day),1) 
     AND MJAHR=SUBSTR(@year_month_day,1,4)
     AND TRIM(matnr) IN (SELECT TRIM(matnr) FROM dim.dim_fi_mr_product_dd)
  )  M
LEFT JOIN 
/*工厂匹配公司*/
  (
    SELECT BWKEY,BUKRS FROM ods.ods_s900_t001k 
  ) P 
ON m.WERKS = p.BWKEY
LEFT JOIN 
/*订单匹配移动类型*/
  (
    SELECT AUFNR,AUART FROM  ods.ODSSLT_S900_AUFK
  ) q
ON m.AUFNR = q.AUFNR
),
/*SAP800数据源确认*/
mseg_800 AS 
(
SELECT TRIM(MATNR) MATNR,TRIM(WERKS) WERKS,TRIM(PPRCTR) PPRCTR,TRIM(m.AUFNR) AUFNR,TRIM(EBELN) EBELN,LTRIM(TRIM(LIFNR),'0') AS  LIFNR,SHKZG,MENGE,DMBTR
,BWART,p.BUKRS,q.AUART
FROM 
  (
    SELECT * 
      FROM ods.ods_slt_s800_mseg
    WHERE  BUDAT_MKPF>LAST_DAY(ADD_MONTHS(TO_DATE(@year_month_day),-1)) 
      AND BUDAT_MKPF<ADD_MONTHS(TO_DATE(@year_month_day),1)
      AND WERKS IN ('2001','2900') 
      AND MJAHR=SUBSTR(@year_month_day,1,4)
      AND TRIM(matnr) IN (SELECT TRIM(matnr) FROM dim.dim_fi_mr_product_dd)
  )  M
LEFT JOIN 
/*工厂匹配公司*/
  (
      SELECT BWKEY,BUKRS FROM ods.ods_s800_t001k 
  ) P 
  ON m.WERKS = p.BWKEY
LEFT JOIN 
/*订单匹配移动类型*/
  (
      SELECT AUFNR,AUART FROM  ods.ODSS800_AUFK
  ) q
  ON m.AUFNR = q.AUFNR
),
/*SAP600数据源确认*/
mseg_600 AS 
(
SELECT TRIM(MATNR) MATNR,TRIM(M.WERKS) WERKS,TRIM(PPRCTR) PPRCTR,TRIM(m.AUFNR) AUFNR,TRIM(EBELN) EBELN,LTRIM(TRIM(LIFNR),'0') AS  LIFNR
,SHKZG,MENGE,DMBTR
,BWART,BUKRS,q.AUART,SOBKZ,KZZUG,CHARG
FROM (
  SELECT * 
    FROM ods.ods_slt_s600_mseg 
   WHERE  BUDAT_MKPF>LAST_DAY(ADD_MONTHS(TO_DATE(@year_month_day),-1)) 
     AND BUDAT_MKPF<ADD_MONTHS(TO_DATE(@year_month_day),1)
     AND MJAHR=SUBSTR(@year_month_day,1,4)
     AND TRIM(matnr) IN (SELECT TRIM(matnr) FROM dim.dim_fi_mr_product_dd)
)  M
LEFT JOIN 
/*订单匹配移动类型*/
  (
    SELECT AUFNR,AUART,WERKS FROM ods.ODSSLT_S600_AUFK
  ) q
  ON m.AUFNR = q.AUFNR AND M.WERKS = Q.WERKS
),
/*SAP900数据处理*/
mseg_data_900 AS 
(
SELECT m.*
    ,Coalesce(D.MAKTX_S600,D.MAKTX_S800,D.MAKTX_S900) AS MATXT
    ,D.ZZPRDMODEL,D.PROD_LINE
    ,(CASE WHEN NVL(D.ZZNXWX,D.SALE_AREA) IN ('01','内销品') THEN 'NX' ELSE 'WX' END) AS NW
    ,D.PRODUCT_TYPE,D.EBMOD
FROM (
/*生产数据*/
SELECT /*+ driving_site(T) */TRIM(MATNR) MATNR,TRIM(WERKS) WERKS,TRIM(PPRCTR) PPRCTR,TRIM(AUFNR) AUFNR,TRIM(EBELN) EBELN,LTRIM(TRIM(LIFNR),'0') AS  LIFNR
      ,SUM((CASE WHEN SHKZG = 'H' THEN (-1*MENGE) WHEN SHKZG = 'S' THEN MENGE ELSE 0 END)) AS PSL
      ,SUM((CASE WHEN SHKZG = 'H' THEN (-1*DMBTR) WHEN SHKZG = 'S' THEN DMBTR ELSE 0 END)) AS PJE
      ,BWART,BUKRS,AUART
  FROM mseg_900 T
 WHERE BWART IN ('101','102','261','201','202','291','292','991','992','261','262') 
   AND NVL(TRIM(AUFNR),'') <> ''
   AND MATNR > '1A'
/*原取值范围基础上增加：工单号范围确认：不含PP03、PP05、ZP04（主要是增加800视像排除PP03）*/
/*AND AUFNR NOT IN (SELECT AUFNR FROM  ods.ODSSLT_S900_AUFK
                WHERE AUART IN ('PP03','PP04','ZP04')
               )  */
 GROUP BY MATNR,WERKS,PPRCTR,AUFNR,EBELN,LIFNR,BWART,BUKRS,AUART
UNION ALL
/*采购订单*/
SELECT  /*+ driving_site(T) */TRIM(MATNR) MATNR,TRIM(WERKS) WERKS,TRIM(PPRCTR) PPRCTR,TRIM(AUFNR) AUFNR,TRIM(EBELN) EBELN,LTRIM(TRIM(LIFNR),'0') AS  LIFNR,
        SUM((CASE WHEN SHKZG = 'H' THEN (-1*MENGE) WHEN SHKZG = 'S' THEN MENGE ELSE 0 END))AS PSL,
        SUM((CASE WHEN SHKZG = 'H' THEN (-1*DMBTR) WHEN SHKZG = 'S' THEN DMBTR ELSE 0 END))AS PJE,BWART,BUKRS,AUART
  FROM mseg_900 T
 WHERE ((BWART IN ('101','102')) OR (BWART IN ('105','106','161','162','122') AND BUKRS LIKE '62%'))
   AND MATNR > '1A'
   AND NVL(TRIM(EBELN),'') <> ''
 GROUP BY MATNR,WERKS,PPRCTR,AUFNR,EBELN,LIFNR,BWART,BUKRS,AUART
) m 
LEFT JOIN dim.dim_fi_mr_product_dd D              
  ON m.MATNR = d.MATNR
),
MSEG_ERRLINE AS 
(SELECT M.MATNR,M.BUKRS,M.WERKS,M.PPRCTR,M.AUFNR,M.EBELN,M.PSL,M.PJE,M.MATXT
       ,dim_fi_mr_product_dd.prod_line AS PROD_LINE -- 匹配的第一步利润中心结果
       ,COALESCE(m.nw) AS NW
       ,M.PRODUCT_TYPE,M.EBMOD ,M.ZZPRDMODEL,M.LIFNR,M.BWART,m.AUART
  FROM mseg_data_900 M
  LEFT JOIN dim.dim_fi_mr_product_dd -- 根据MATNR匹配物料大表EDW.DW_TM_MARA_FERT@FMSLK取PROD_LINE
    ON m.matnr = dim_fi_mr_product_dd.matnr
),
/*SQMV000 -- 产量金额  SQPV000 -- 采购金额 SQM0000 -- 产量 SQP0000 -- 采购数量 SQOV000 -- 返包生产金额 SQO0000 -- 返包生产数量*/
/*空调(68,62%)：取MB51移动类型101、261+订单类型是PP03、PP05，各公司合计数（涉及账套：SAP-900）*/
/*冰箱(63,67%)：取MB51移动类型101、102+订单类型是PP03、PP05（涉及账套：SAP-900）*/
SRC_900 AS (
SELECT SUBSTR(@year_month_day,1,6) AS YEARMONTH
,CASE WHEN (NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('101','102') AND AUART IN ('PP03','PP05','ZP07') AND (ENTITY LIKE'62%' OR ENTITY LIKE'63%')) THEN 'SQOV000' 
      WHEN NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('101','102') THEN 'SQMV000' 
      WHEN NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('201','202') THEN 'SQCV000'
      WHEN NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('291','292','991','992') THEN 'SQBV000'
      WHEN NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('261','262') THEN 'SQFV000'
      WHEN NVL(TRIM(EBELN),'') <> '' AND BWART IN ('101','102','105','106','161','162','122') THEN 'SQPV000' 
      ELSE '' 
 END AS ACCOUNT

,CASE WHEN (NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('101','102') AND AUART IN ('PP03','PP05','ZP07') AND (ENTITY LIKE'62%' OR ENTITY LIKE'63%')) THEN 'SQO0000' 
      WHEN NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('101','102') THEN 'SQM0000' 
      WHEN NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('201','202') THEN 'SQC0000'
      WHEN NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('291','292','991','992') THEN 'SQB0000'
      WHEN NVL(TRIM(AUFNR),'') <> '' AND BWART IN ('261','262') THEN 'SQF0000'
      WHEN NVL(TRIM(EBELN),'') <> '' AND BWART IN ('101','102','105','106','161','162','122') THEN 'SQP0000' 
      ELSE '' 
  END AS ACC_SL
, ENTITY
, MATNR,MATXT,ZPRDMODEL
, PSL,MAP_PSL ,PJE,MAP_PJE
, 'ODSS900_MSEG' AS SRC
, CONCAT(SUBSTR(@year_month_day,1,4),'ACT') AS SCENARIO
, SUBSTR(@year_month_day,5,2) AS PERIOD
, '' CTP,LIFNR,BWART,AUFNR,WERKS
FROM (
SELECT MATNR,ZZPRDMODEL AS ZPRDMODEL,AUFNR,EBELN,
       PSL,PSL AS MAP_PSL,
       CASE WHEN NVL(TRIM(AUFNR),'') <> '' THEN 0 WHEN NVL(TRIM(EBELN),'') <> '' THEN PJE ELSE 0 END AS PJE, 
       CASE WHEN NVL(TRIM(AUFNR),'') <> '' THEN 0 WHEN NVL(TRIM(EBELN),'') <> '' THEN PJE ELSE 0 END AS MAP_PJE, 
       BUKRS AS ENTITY,PROD_LINE,
       MATXT,LIFNR,BWART,AUART,WERKS
 FROM MSEG_ERRLINE M
) A
WHERE ENTITY <> '6000'
),
/*SQMV000 -- 产量金额  SQPV000 -- 采购金额 SQM0000 -- 产量 SQP0000 -- 采购数量 SQOV000 -- 返包生产金额 SQO0000 -- 返包生产数量*/
SRC_800 AS (
SELECT MATNR,LIFNR,BUKRS AS ENTITY,'S800' system_src,PSL,PJE
   ,CASE WHEN AUFNR <> '' AND BWART IN ('101','102','161','162') AND AUART IN ('ZP04','PP03','PP05','ZP07') THEN 'SQOV000' 
        WHEN AUFNR <> '' AND BWART IN ('101','102','161','162') THEN 'SQMV000'
        WHEN AUFNR <> '' AND BWART IN ('261','262','961','962') THEN 'SQFV000'
        WHEN BWART IN ('201','202') THEN 'SQCV000'
        WHEN EBELN <> '' AND BWART IN ('101','102','161','162') THEN 'SQPV000' 
        ELSE '' 
     END AS ACCOUNT
   ,CASE WHEN AUFNR <> '' AND BWART IN ('101','102','161','162') AND AUART IN ('ZP04','PP03','PP05','ZP07') THEN 'SQO0000' 
        WHEN AUFNR <> '' AND BWART IN ('101','102','161','162') THEN 'SQM0000' 
        WHEN AUFNR <> '' AND BWART IN ('261','262','961','962') THEN 'SQF0000'
        WHEN BWART IN ('201','202') THEN 'SQC0000'
        WHEN EBELN <> '' AND BWART IN ('101','102','161','162') THEN 'SQP0000' 
        ELSE '' 
     END AS ACC_SL
    ,'ODSS800_MSEG' AS SRC
   FROM (
  
    SELECT TRIM(MATNR) MATNR,TRIM(WERKS) WERKS,TRIM(PPRCTR) PPRCTR,TRIM(AUFNR) AUFNR,TRIM(EBELN) EBELN
          ,SUM((CASE WHEN SHKZG = 'H' THEN (-1*MENGE) WHEN SHKZG = 'S' THEN MENGE ELSE 0 END))AS PSL
          ,0 AS PJE
          ,LTRIM(TRIM(LIFNR),'0') AS LIFNR,BUKRS,BWART,AUART
    FROM mseg_800
    WHERE  BWART IN ('101','102','161','162','261','262','961','962') /* ALTER BY 20251030 XIAOYACHAO.EX 增加161,162*/
    AND (NVL(TRIM(AUFNR),'') <> '')           
    AND MATNR > '1A'
    GROUP BY MATNR,WERKS,PPRCTR,AUFNR,EBELN,LIFNR,BUKRS,BWART,AUART
    
    UNION ALL 
    
    SELECT TRIM(MATNR) MATNR,TRIM(WERKS) WERKS,TRIM(PPRCTR) PPRCTR,TRIM(AUFNR) AUFNR,TRIM(EBELN) EBELN
          , SUM((CASE WHEN SHKZG = 'H' THEN (-1*MENGE) WHEN SHKZG = 'S' THEN MENGE ELSE 0 END))AS PSL
          , SUM((CASE WHEN SHKZG = 'H' THEN (-1*DMBTR) WHEN SHKZG = 'S' THEN DMBTR ELSE 0 END))AS PJE
          , LIFNR,BUKRS,BWART,AUART
     FROM mseg_800 T
    WHERE BWART IN ('101','102','161','162') AND (NVL(TRIM(EBELN),'') <> '')
      AND MATNR > '1A'
    GROUP BY MATNR,WERKS,PPRCTR,AUFNR,EBELN,LIFNR,BUKRS,BWART,AUART

    UNION ALL 

    SELECT TRIM(MATNR) MATNR,TRIM(WERKS) WERKS,TRIM(PPRCTR) PPRCTR,TRIM(AUFNR) AUFNR,TRIM(EBELN) EBELN
          , SUM((CASE WHEN SHKZG = 'H' THEN (-1*MENGE) WHEN SHKZG = 'S' THEN MENGE ELSE 0 END))AS PSL
		      , SUM((CASE WHEN SHKZG = 'H' THEN (-1*DMBTR) WHEN SHKZG = 'S' THEN DMBTR ELSE 0 END))AS PJE
		      , LTRIM(TRIM(LIFNR),'0') AS LIFNR,BUKRS,BWART,AUART
     FROM mseg_800
    WHERE  BWART IN ('201','202') 
      AND MATNR > '1A'
    GROUP BY MATNR,WERKS,PPRCTR,AUFNR,EBELN,LIFNR,BUKRS,BWART,AUART
   ) T
  
  UNION ALL 
  
  SELECT LTRIM(MATNR) MATNR,'' AS LIFNR,/*VKORG*/RBUKRS ENTITY,'S800' system_src /*ALTER BY 20260617 XIAOYACHAO.EX 修改公司字段*/
        , 0 MENGE
        , HSL PJE,'SQDV000' ACCOUNT,'SQD0000' ACC_SL,'ODSS800_GLPCA' SRC
  FROM ods.ods_slt_s800_glpca
  WHERE RBUKRS = '2000'
  AND BLART IN ('WE','RE') AND RACCT IN ('5508999002','5509999002')
  AND RYEAR = SUBSTR(@year_month_day,1,4) 
  AND RIGHT(POPER,'2') = SUBSTR(@year_month_day,5,2)
  
  UNION ALL 
  
  /*商显：手工调整，取自C010_0010表,600系统（SAP底表ZTS600_ZMM045）, 接收工厂2600 2080 23%, 工厂 26% 2050 2080 2082 1630 1632 23%,800系统(ZSD001Z)*/
  SELECT LTRIM(MATNR) MATNR,'' AS LIFNR,VKORG ENTITY,system_src,
  THSL1 MENGE,THJE1 PJE,'SQRV000' ACCOUNT,'SQR0000' ACC_SL,SRC
  FROM (
    /*ZSD001Z退货数量金额*/
    SELECT A.MATNR,0 AS THSL,0 AS THSL1,SUM(-1*NVL(LFIMG,0)) AS THSL2,0 AS THJE,0 AS THJE1,SUM(-1*NVL(WAVWR,0)) AS THJE2,'S800' system_src,'ODSS800_ZSD001Z' SRC,VKORG
      FROM ods.ODSS800_ZSD001Z A
     WHERE DT_MONTH = LEFT(@year_month_day,6)
       AND DATE_FORMAT(ERDAT,'%Y%m')=  LEFT(@year_month_day,6)
       AND VKORG = '2000' AND LEFT(@year_month_day,6) not in('202303','202304')
       AND LTRIM(KUNNR,0) IN
                    ('11168',
                    '20180','20198','20203','20208','20405','20809','25896','25951','25986',
                    '25991','25994','26006','26007','26047','26078','26169','26229','40147',
                    '40167','60184','60251','60267','60269','60270','60280','310310','A02023',
                    'A02052','A02061'
                    /*SELECT LTRIM(ELEDIM_INPUT1,'0') AS KUNNR FROM MAP_REGOLA_TAB_ELEMENTO*/
                    /*WHERE COD_MAPPATURA = 'HI_DATA_IC' AND COD_REGOLA_TAB = 'MAP_CUSVEN_ENTITY_800' AND ELEDIM_INPUT2 = 'C'*/
                    /*AND ELEDIM_OUTPUT1 IN ('2600','2050','2052','2080','2061','2023'\*MGT202406280011*\,'2083','1630','1632')*/
                    )
      GROUP BY A.MATNR,VKORG
  )BB
  ),
/*SQMV000 -- 产量金额  SQPV000 -- 采购金额 SQM0000 -- 产量 SQP0000 -- 采购数量 SQOV000 -- 返包生产金额 SQO0000 -- 返包生产数量*/
/*SAP600数据处理*/
SRC_600 AS (
SELECT MATNR,LIFNR,ENTITY,'S600' system_src,MENGE PSL,PJE
    ,CASE WHEN BWART IN ('101','102') AND AUART IN ('ZP04','PP03','PP05','ZP07') THEN 'SQOV000'
          WHEN BWART IN ('201','202') THEN 'SQCV000'
          /*WHEN BWART IN ('101','102') THEN 'SQMV000'*/ 
          ELSE 'SQMV000' 
      END ACCOUNT
    ,CASE WHEN BWART IN ('101','102') AND AUART IN ('ZP04','PP03','PP05','ZP07') THEN 'SQO0000'
          WHEN BWART IN ('201','202') THEN 'SQC0000'
          /*WHEN BWART IN ('101','102') THEN 'SQM0000'*/ 
          ELSE 'SQM0000' 
      END ACC_SL
    ,SRC
  FROM (
  /*生产订单排除返修订单*/
    SELECT MATNR,LIFNR,ENTITY,MENGE,PJE
    ,SRC,A.AUFNR,BWART,AUART
    FROM (
    SELECT 'SQ00' CATEG,'MSEG' SRC,'PRODUCE' NOTE,BUKRS ENTITY,MATNR,LTRIM(TRIM(LIFNR),'0') AS LIFNR
          , (CASE SHKZG WHEN 'H' THEN -1*MENGE ELSE MENGE END) MENGE
          , 0 PJE
          , AUFNR,BWART,AUART
     FROM mseg_600
    WHERE ((BUKRS IN ('2300','4330','2701','6380','6797')) OR ((BUKRS NOT IN ('2023','2050')) OR (BUKRS IN ('2023','2050') AND (AUART NOT IN ('ZP04') OR AUART IS NULL))))
      AND BWART IN ('101','102') 
      AND NVL(TRIM(AUFNR),'') <> ''
    ) A

    UNION ALL

    /*OEM*//*ALTER BY 20251103 WANGHAODE.EX 6700公司OEM取数逻辑修改*/
    SELECT    MATNR,LTRIM(TRIM(LIFNR),'0') AS LIFNR,BUKRS ENTITY
            , NVL(CASE WHEN BWART IN ('101','102') AND NVL(TRIM(SOBKZ),'') = ''          
                       THEN (CASE SHKZG WHEN 'H' THEN -1*MENGE ELSE MENGE END) 
                       ELSE 0 
                   END,0)
              +
              NVL(CASE WHEN BWART IN ('411','412') AND NVL(TRIM(SOBKZ),'') = ''           
                        THEN (CASE SHKZG WHEN 'H' THEN -1*MENGE ELSE MENGE END) 
                        ELSE 0 
                    END,0) AS MENGE
            , NVL(CASE WHEN BWART IN ('101','102') AND NVL(TRIM(SOBKZ),'') = ''          
                      THEN (CASE SHKZG WHEN 'H' THEN -1*DMBTR ELSE DMBTR END) 
                      ELSE 0 
                END,0)
              +
              NVL(CASE WHEN BWART IN ('411','412') AND NVL(TRIM(SOBKZ),'') = ''         
                        THEN (CASE SHKZG WHEN 'H' THEN -1*DMBTR ELSE DMBTR END) 
                        ELSE 0 
                    END,0) AS PJE
            , 'MSEG' AS SRC,AUFNR,BWART,AUART
      FROM mseg_600 A
     WHERE BUKRS IN ('6700')
       AND BWART IN ('101','102','411','412')
       AND LTRIM(LIFNR,'0') IN ('102113','102165','102170','104427','1047979','1049941','1050157','1054464','1054502','1056289','1057143','1059712','1060571','1061001','1065146','1067233','111161','111732','112439','113028','113993','168132','173235','20061788','20221837')

    UNION ALL 

    SELECT MATNR,LIFNR,ENTITY,MENGE,PJE
    ,SRC,A.AUFNR,BWART,AUART
    FROM (
    SELECT  '' CATEG,'MSEG' SRC,'' NOTE,BUKRS ENTITY,MATNR,LTRIM(TRIM(LIFNR),'0') AS LIFNR
          , CASE SHKZG WHEN 'H' THEN -1*MENGE ELSE MENGE END AS MENGE
          , CASE WHEN SHKZG = 'H' THEN (-1*DMBTR) WHEN SHKZG = 'S' THEN DMBTR ELSE 0 END AS PJE
          , AUFNR,BWART,AUART
     FROM mseg_600
     WHERE /*(BUKRS LIKE '2%' OR BUKRS IN ('1630','1632'))
       AND*/ BWART IN ('201','202') 
       AND MATNR NOT LIKE '0000%'
    ) A
   ) S 

  UNION ALL 
  /*采购相关逻辑，整体优化整合*/
  SELECT MATNR,LIFNR,ENTITY,'S600' system_src,MENGE,PJE,ACCOUNT,ACC_SL,SRC
  FROM (
  /*采购订单2300 4330 2701 2023 生产采购数据 2080 2061 101/102并且生产/采购订单不为空且供应商不为空的数据 2050公司kzzug字段为X的数据剔除*/
    SELECT 'SQ00' CATEG,'SQPV000' ACCOUNT,'SQP0000' ACC_SL,'MSEG' SRC
          , CASE WHEN LTRIM(LIFNR,'0')='10001' THEN '6210' 
                WHEN LTRIM(LIFNR,'0') IN ('10145','10508') THEN '6220' 
                WHEN LTRIM(LIFNR,'0')IN ('50798') THEN '6230' 
                WHEN LTRIM(LIFNR,'0')IN ('10366') THEN '6230' 
                WHEN BUKRS IN ('2300','4330','2701','2023','2080','2061','2050') THEN 'PURCHASE' 
                ELSE '' 
            END  NOTE,BUKRS ENTITY,MATNR,LTRIM(TRIM(LIFNR),'0') AS LIFNR
          , CASE SHKZG WHEN 'H' THEN -1*MENGE ELSE MENGE END AS MENGE
          --, 0 PJE
          , CASE SHKZG WHEN 'H' THEN -1*DMBTR ELSE DMBTR END PJE 
          , BWART,AUART
     FROM mseg_600
     WHERE ((((BUKRS IN ('2300','4330','2701','2023') AND BWART IN ('101','102') AND NVL(TRIM(EBELN),'') <> ''))
            OR ((BUKRS IN ('2061') AND NVL(TRIM(LIFNR),'') <> '') AND BWART IN ('101','102') AND NVL(TRIM(EBELN),'') <> ''))
            OR ((BUKRS IN ('2050') AND (KZZUG <> 'X' OR NVL(TRIM(KZZUG),'') = '')) AND BWART IN ('101','102','161','162') AND NVL(TRIM(EBELN),'') <> ''))
            OR ((BUKRS IN ('2080') AND NVL(TRIM(LIFNR),'') <> '') AND BWART IN ('101','102','161','162') AND NVL(TRIM(EBELN),'') <> ''))
            /*OR BUKRS IN ('6800','6851') AND  LTRIM(LIFNR,'0') IN ('10001','10145','50798','10366','10508') AND CHARG = 'H'*/
           )
        AND BWART IN ('101','102','161','162') AND NVL(TRIM(EBELN),'') <> '' )
     
     UNION ALL

     /*OEM取数逻辑新增6380、6797 6370逻辑整合  新增空调逻辑*/
    SELECT 'SQ00' CATEG,'SQPV000' ACCOUNT,'SQP0000' ACC_SL,'MSEG' SRC,'PURCHASE' NOTE
          ,CASE WHEN BUKRS IN ('6370','6797') AND BWART IN ('Y55','Y56')  THEN '6797' ELSE BUKRS END AS ENTITY
          ,MATNR,LTRIM(TRIM(LIFNR),'0') AS LIFNR
          ,CASE SHKZG WHEN 'H' THEN -1*MENGE ELSE MENGE END AS MENGE
          ,CASE SHKZG WHEN 'H' THEN -1*DMBTR ELSE DMBTR END AS PJE
          ,BWART,AUART
     FROM mseg_600
    WHERE (((BUKRS IN ('6380') AND BWART IN ('101','102','411','412') AND MATNR NOT LIKE '000%' AND NVL(TRIM(SOBKZ),'') = ''))
          OR (BUKRS IN ('6370')) /*AND BWART IN ('Y55','Y56')*/ --20260327 YH 取消Y55、Y56移动类型取值逻辑
          OR (BUKRS IN ('6797') AND (BWART IN ('101','102','411','412') AND NVL(TRIM(SOBKZ),'') = '' /*OR BWART IN ('Y55','Y56')*/)) 
          OR (BUKRS IN ('6800','6851') AND (BWART IN ('101','102','411','412') AND NVL(TRIM(SOBKZ),'') = '' AND NVL(TRIM(LIFNR),'') <> ''  )))
    ) A
  UNION ALL 
  /*ALTER BY 20260618 XIAOYACHAO.EX AT FIDATA-502 :2、采购差异取数，取BSEG表，凭证类型的WE/RE/Z1的，6401010000 主营业务成本-差异（剔除内部）*/
SELECT MATNR, LIFNR, ENTITY, 'S600' system_src, MENGE, PJE, ACCOUNT, ACC_SL, SRC
FROM (
  SELECT 'SQ00' CATEG
       , 'SQDV000' ACCOUNT        -- 金额科目：采购金额差异
       , 'SQP0000' ACC_SL         -- 数量科目：采购数量
       , 'BSEG' SRC               -- 来源表
       , 'COST_DIFF' NOTE         -- 标记：成本差异
       , bseg.BUKRS AS ENTITY          -- 公司
       , TRIM(bseg.MATNR) AS MATNR     -- 物料编码
       , LTRIM(TRIM(bseg.LIFNR), '0') AS LIFNR  -- 供应商编码（去前导零）
       , 0 AS MENGE               -- 数量（BSEG无数量，固定为0）
       , SUM(CASE bseg.SHKZG WHEN 'S' THEN bseg.DMBTR ELSE -1 * bseg.DMBTR END) AS PJE  -- 本位币金额（借方正/贷方负）
    FROM ods.ods_slt_s600_bseg_v bseg
    JOIN ods.ods_slt_s600_bkpf_v bkpf
      ON bseg.bukrs = bkpf.bukrs
     AND bseg.gjahr = bkpf.gjahr
     AND bseg.belnr = bkpf.belnr
   WHERE 1 = 1
     -- 期间过滤
     AND bkpf.budat >= @year_month_day
     AND bkpf.budat < DATE_FORMAT(DATE_ADD(CAST(@year_month_day AS DATE), INTERVAL 1 MONTH), '%Y%m%d')
     -- 公司过滤
     AND (bseg.bukrs LIKE '23%' OR bseg.bukrs LIKE '26%' OR bseg.bukrs IN ('2050','2052','2080','2061','2023','2083','1630','1632'))
     -- 凭证类型限制
     AND bkpf.blart IN ('WE', 'RE', 'Z1')
     -- 科目限制：6401010000 主营业务成本-差异
     AND bseg.hkont = '6401010000'
     -- 剔除内部公司交易：供应商在客商匹配对方公司映射表中有对应记录的为内部
    /* AND LTRIM(TRIM(bseg.lifnr), '0') NOT IN (
         SELECT LTRIM(cust_code, '0')
           FROM dim.dim_rule_fi_mr_cust2ctp_mapping
          WHERE cust_type_code = 'V'
            AND system_src = 'S600'
            AND cp_company_code IS NOT NULL
     )*/
   GROUP BY
    bseg.bukrs
  , TRIM(bseg.matnr)
  , LTRIM(TRIM(bseg.LIFNR), '0')
HAVING SUM(CASE WHEN bseg.shkzg = 'S' THEN bseg.dmbtr ELSE -1 * bseg.dmbtr END) <> 0
) A

  UNION ALL 
  
  --商显：手工调整，取自C010_0010表,600系统（SAP底表ZTS600_ZMM045）, 接收工厂2600 2080 23%, 工厂 26% 2050 2080 2082 1630 1632 23%,800系统（ZSD001Z）
  SELECT LTRIM(MATNR) MATNR,'' AS LIFNR,/* RESWK fjf_add*/WERKS ENTITY,system_src,
  THSL1 MENGE,THJE1 PJE,'SQRV000' ACCOUNT,'SQR0000' ACC_SL,SRC
  FROM (
    SELECT A.MATNR,0 AS THSL,SUM(-1*NVL(FHGZSL,0)) AS THSL1,0 AS THSL2,0 AS THJE,SUM(-1*NVL(DMBTR2,0)) AS THJE1,0 AS THJE2,'S600' system_src,'ODSS600_ZMM045' SRC,RESWK,WERKS
      FROM ods.ODSS600_ZTS600_ZMM045 A
      WHERE TRIM(RETPO) IS NOT NULL
      AND ((RESWK IN ('2600'/*,'2050'*/,'2080','2061','2023'/*MGT202406280011*/,'2083') OR RESWK LIKE '23%'))  /*ALTER BY 20250805 14:12 发出工厂增加2050 BY 高彩云, 又取消*/
      AND ((WERKS LIKE '26%' OR WERKS IN ('2050','2052','2080','2061','2023'/*MGT202406280011*/,'2083','2082','1630','1632') OR WERKS LIKE '23%'))
      AND DATE_FORMAT(WADAT_IST,'%Y%m') <= LEFT(@year_month_day,6)
      AND STR_TO_DATE(DT_DAY, '%Y%m%d') = ADD_MONTHS(TO_DATE(@year_month_day),1)
      AND KEYDATE = ADD_MONTHS(TO_DATE(@year_month_day),1)
      GROUP BY A.MATNR,RESWK,WERKS
  )BB
)

SELECT 
  LEFT(@year_month_day,4) year,  /*财务年*/
  SUBSTR(@year_month_day,5,2) month,  /*财务月*/
  mseg.ENTITY company_code,  /*组织*/
  mseg.lifnr cust_code,  /*客商编码*/
  mseg.matnr material_code,  /*物料编码*/
  cust.cust_name cust_name,  /*客商名称*/
  (CASE WHEN PROD.PRODUCT_TYPE = '电子商务机' THEN '020_ON_002' ELSE '020_OFF_002' END) ONOFFLINE_CODE, /*线上线下编码*/
  (CASE WHEN (CASE WHEN PROD.PRODUCT_TYPE = '电子商务机' THEN '020_ON_002' ELSE '020_OFF_002' END) = '020_ON_002' THEN '主站' 
      ELSE '零售-传统零售' END) ONOFFLINE_NAME, /*线上线下名称*/
  PROD.product_name AS material_name, /*物料名称*/
  COALESCE(IF(TRIM(PROD.zzprdmodel)= '',NULL,TRIM(PROD.zzprdmodel))
            ,IF(TRIM(PROD.zfacmodel)= '',NULL,TRIM(PROD.zfacmodel))
            ,IF(TRIM(PROD.pmodel_number)= '',NULL,TRIM(PROD.pmodel_number))
            ) AS model_code, /*产品型号编码*/
  prod.model_name model_name, /*产品型号名称*/
  CASE WHEN mseg.ACCOUNT IN ('SQBV000','SQCV000','SQFV000') THEN -1*mseg.PSL 
       ELSE mseg.PSL 
  END prd_qty,  /*物料移动数量*/
  AZI.COD_VALUTA qcy_code,  /*货币-交易币*/
  CASE WHEN mseg.ACCOUNT IN ('SQBV000','SQCV000','SQFV000') THEN -1*mseg.PJE 
       WHEN mseg.ACCOUNT = 'SQPV000' AND mseg.system_src = 'S900' AND mseg.ENTITY LIKE '62%' AND mseg.ENTITY <> '6200' THEN mseg.PSL * VERPR
       ELSE mseg.PJE 
  END prd_amt,  /*物料移动金额*/
  mseg.system_src,  /*源系统*/
  mseg.SRC ods_src,  /*源表*/
  CASE WHEN mseg.system_src <> 'HIS' 
            AND ((mseg.ENTITY LIKE '63%') OR (mseg.ENTITY LIKE '67%') OR (mseg.ENTITY IN ('2000','2900')))
            AND mseg.lifnr  <> ''
            AND CONCAT(mseg.system_src,mseg.lifnr) NOT IN (SELECT CONCAT('S',RIGHT(system_src,3),LTRIM(CUST_CODE,0))
                                                             FROM dim.dim_rule_fi_mr_cust2ctp_mapping
                                                            WHERE CUST_TYPE_CODE = 'V'
                                                              AND SYSTEM_SRC IN('S600','S800' ,'S900','SAP600')
                                                              AND CP_COMPANY_CODE IS NOT NULL
                                                            ) 
      THEN 'SQSV000' 
      ELSE mseg.ACCOUNT 
  END AS amt_acct_code,  /*金额科目编码*/
  CASE WHEN mseg.system_src <> 'HIS' 
            AND ((mseg.ENTITY LIKE '63%') OR (mseg.ENTITY LIKE '67%') OR (mseg.ENTITY IN ('2000','2900')))
            AND mseg.lifnr  <> ''
            AND CONCAT(mseg.system_src,mseg.lifnr) NOT IN (SELECT CONCAT('S',RIGHT(system_src,3),LTRIM(CUST_CODE,0))
                                                             FROM dim.dim_rule_fi_mr_cust2ctp_mapping
                                                            WHERE CUST_TYPE_CODE = 'V'
                                                              AND SYSTEM_SRC IN('S600','S800' ,'S900','SAP600')
                                                              AND CP_COMPANY_CODE IS NOT NULL
                                                            ) 
      THEN 'SQS0000' 
      ELSE mseg.ACC_SL 
  END AS qty_acct_code,  /*数量科目编码*/
  now() load_dt,  /*更新时间*/
  LEFT(@year_month_day,6) dt_month,  /*年月*/  
  
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
  CASE WHEN (SUBSTR(mseg.ENTITY,1,2) IN ('62','68') OR mseg.ENTITY IN ('6012','6015'))
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,Mapping_Bus2.marketing_dept_code ,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN CASE WHEN mseg.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
                                        WHEN mseg.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
                                        ELSE '' END IN ('1209901','1209905','G209901')
                                   AND CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
                                            WHEN NULLIF(TRIM(mseg.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
                                            WHEN NULLIF(TRIM(mseg.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
                                            ELSE '3000' 
                                        END NOT IN ('2358','A004','2357')
                         THEN '1209901'
                         ELSE NULL END ,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         CASE WHEN mseg.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
                              WHEN mseg.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
                              ELSE '' END 
                         )
          ELSE '' 
     END
  AS MARKETING_DEPT_CODE,/*所属营销部门编码（业务管理单元编码）*/
  
  '' AS marketing_dept_name,  /*所属营销部门描述（业务管理单元描述）*/
  PROD.brand AS BRAND_CODE,/*品牌编码*/
  PROD.brand_name AS BRAND_NAME,/*品牌名称*/
  CASE WHEN mseg.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
       WHEN mseg.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
       ELSE '' 
   END AS material_group_code,  /*物料组*/
  CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' 
   END AS BUS_RANGE_CODE,/*业务范围编码*/  
  CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_NAME
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '中国区公共' 
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '海外公共' 
   END AS BUS_RANGE_NAME,/*业务范围名称*/ 
  prod.zcusmodel AS CUSTOMER_MODEL,/*客户型号*/ 
  CASE WHEN MSEG.SYSTEM_SRC = 'S600' THEN S600.WGBEZ
       WHEN MSEG.SYSTEM_SRC = 'S800' THEN S800.WGBEZ
       WHEN MSEG.SYSTEM_SRC = 'S900' THEN S900.WGBEZ
   END AS material_group_name,  /*物料组描述 */  
  CP_COMPANY_CODE AS CP_COMPANY_CODE /*对方公司字段*/
  ,zcalasset /*按套统计*/
  ,maktx_s810
  ,CASE WHEN NVL(TRIM(PROFIT_MAPING.profitcenter_code),'') = '' THEN PROD.profitcenter_code ELSE PROFIT_MAPING.profitcenter_code END AS profitcenter_code  --利润中心编码
  ,small_class_code--产品小类编码
  ,BIG_CLASS_CODE AS product_big_class_code,  --产品大类编码
   BIG_CLASS_NAME AS product_big_class_name,   --产品大类名称
   MIDDLE_CLASS_CODE AS product_mid_class_code,  --产品中类编码
   MIDDLE_CLASS_NAME AS product_mid_class_name,  --产品中类名称
   SMALL_CLASS_NAME AS product_small_class_name  --产品小类名称
FROM 
(
/*SAP900结果*/
SELECT  m.MATNR,m.LIFNR,m.ENTITY,'S900' system_src,m.PSL,m.PJE,m.ACCOUNT,m.ACC_SL,m.SRC,M.WERKS
  FROM (
    SELECT  YEARMONTH,ACCOUNT,ACC_SL,ENTITY, MATNR
          , SUM(PSL) PSL,SUM(PJE) PJE
          , SRC, SCENARIO,PERIOD
          , CTP, LIFNR, WERKS
      FROM SRC_900 
     WHERE MATNR NOT LIKE '000%'
     GROUP BY  YEARMONTH,ACCOUNT,ACC_SL,ENTITY, MATNR , SRC, SCENARIO,PERIOD , CTP, LIFNR, WERKS
 ) M
UNION ALL 
/*SAP800结果*/
SELECT  n.MATNR,n.LIFNR,n.ENTITY,n.system_src,n.PSL,n.PJE,n.ACCOUNT,n.ACC_SL,n.SRC,'' AS WERKS
FROM (
      SELECT  SUBSTR(@year_month_day,1,6) AS YEARMONTH
            , ACCOUNT,ACC_SL,ENTITY, MATNR,system_src
            , SUM(PSL) PSL,SUM(PJE) PJE
            , SRC
            , LIFNR
      FROM SRC_800 
      WHERE MATNR NOT LIKE '000%'
      GROUP BY ACCOUNT,ACC_SL,ENTITY, MATNR,system_src,SRC,LIFNR
    ) n
UNION ALL 

/*SAP600结果*/
SELECT  o.MATNR,o.LIFNR,o.ENTITY,o.system_src,o.PSL,o.PJE,o.ACCOUNT,o.ACC_SL,o.SRC,'' AS WERKS
FROM (
  SELECT  SUBSTR(@year_month_day,1,6) AS YEARMONTH, ACCOUNT,ACC_SL,ENTITY, MATNR,system_src
        , SUM(PSL) PSL
        , SUM(PJE) PJE
        , SRC
        , LIFNR
  FROM SRC_600 
  WHERE MATNR NOT LIKE '000%'
  GROUP BY ACCOUNT,ACC_SL,ENTITY, MATNR,system_src,SRC,LIFNR
  ) o
) mseg
/*客商表*/
LEFT JOIN 
(
  SELECT cust_code,cust_name FROM dw.dim_customer_base_info_dd
) cust ON mseg.lifnr = cust.cust_code
/*物料大表*/
LEFT JOIN (SELECT maktx_s600,maktx_s800,maktx_s900,zzprdmodel,zfacmodel,ZZNXWX,profitcenter_code,matnr,maktx_mdm,pmodel_number,prod_line,prod_line_name,model_code,model_name,product_type,matkl,INOUT_SALE_NAME,zcusmodel,sale_area,zcalasset,maktx_s810,small_class_code,
            BIG_CLASS_CODE,BIG_CLASS_NAME,MIDDLE_CLASS_CODE,MIDDLE_CLASS_NAME,SMALL_CLASS_NAME,brand,brand_name,product_name,BUS_RANGE_CODE,BUS_RANGE_NAME
             FROM dim.dim_fi_mr_product_dd
          ) PROD 
  ON mseg.matnr = PROD.matnr
/*20260709 此配置表中的公司业务范围取物料大表*/
LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_prd_bus_company_configuration) comp_confin
  ON comp_confin.company_code = mseg.ENTITY
/*匹配公司主数据*/
LEFT JOIN (SELECT COD_AZIENDA,COD_VALUTA FROM ods.odsfima_azienda) AZI
  ON AZI.COD_AZIENDA = mseg.ENTITY
/*匹配S600物料组名称*/
LEFT JOIN (SELECT MATKL,WGBEZ FROM ods.ODS_S600_T023T) S600
  ON PROD.MATKL = S600.MATKL
 AND MSEG.SYSTEM_SRC = 'S600'
/*匹配S800物料组名称*/
LEFT JOIN (SELECT MATKL,WGBEZ FROM ods.ODS_S800_T023T) S800
  ON PROD.MATKL = S800.MATKL
 AND MSEG.SYSTEM_SRC = 'S800'
/*匹配S900物料组名称*/
LEFT JOIN (SELECT MATKL,WGBEZ FROM ods.ODS_S900_T023T) S900
  ON PROD.MATKL = S900.MATKL
 AND MSEG.SYSTEM_SRC = 'S900'
LEFT JOIN  
(
  SELECT (CASE WHEN SYSTEM_SRC = 'SAP600' THEN 'S600' ELSE SYSTEM_SRC END) system_src,LTRIM(CUST_CODE,0) CUST_CODE,CP_COMPANY_CODE
    FROM dim.dim_rule_fi_mr_cust2ctp_mapping
   WHERE CUST_TYPE_CODE = 'V'
     AND SYSTEM_SRC IN('S600','SAP600','S800','S900')
     AND CP_COMPANY_CODE IS NOT NULL
) CP 
  ON mseg.system_src = cp.system_src 
 AND mseg.lifnr = CP.CUST_CODE

/*匹配利润中心,优先取映射表中的利润中心,否则取物料大表中的利润中心*/
LEFT JOIN (
           SELECT material_code,profitcenter_code FROM dim.dim_rule_fi_mr_mt2bd_mapping
          ) PROFIT_MAPING
  ON mseg.matnr = PROFIT_MAPING.material_code

/*业务范围兜底逻辑,匹配映射表取业务范围*/
LEFT JOIN (SELECT COMPANY_CODE,BUS_RANGE_CODE FROM dim.dim_rule_fi_mr_BusScope_for_Company
            WHERE VALID_FR <= @year_month_day
            AND VALID_TO >= @year_month_day
           ) for_Company
  ON mseg.ENTITY = for_Company.COMPANY_CODE 


    /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_AirConditioner_Materials_Mapping_Bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus2
    ON mseg.matnr = Mapping_Bus2.MATERIAL_CODE
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_AirConditioner_Materials_Mapping_Bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus1
    ON mseg.matnr = Mapping_Bus1.MATERIAL_CODE
   AND   CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' END = Mapping_Bus1.bus_range_code



    --新增业务管理单元取数逻辑
  LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON REGEXP_REPLACE(CASE WHEN NVL(TRIM(PROFIT_MAPING.profitcenter_code),'') = '' THEN PROD.profitcenter_code ELSE PROFIT_MAPING.profitcenter_code END, '^0+', '') = profit_mapping0.profitcenter_code
    AND  CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' END = profit_mapping0.bus_range_code

  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON CASE WHEN  mseg.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
       WHEN mseg.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
       ELSE '' END = TRIM(profit_mapping1.material_group_code)
    AND CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' END = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON CASE WHEN mseg.SYSTEM_SRC IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(PROD.prod_line,'BP',''),'DS',''),'TA','')
       WHEN mseg.SYSTEM_SRC IN ('S800') THEN PROD.MATKL 
       ELSE '' END = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON REGEXP_REPLACE(CASE WHEN NVL(TRIM(PROFIT_MAPING.profitcenter_code),'') = '' THEN PROD.profitcenter_code ELSE PROFIT_MAPING.profitcenter_code END, '^0+', '') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE WHEN comp_confin.company_code IS NOT NULL AND PROD.MATNR IS NOT NULL THEN PROD.BUS_RANGE_CODE
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NOT NULL AND NVL(PROD.ZZNXWX,PROD.SALE_AREA) IN ('内销','中国','内销品','01') THEN '2000' 
       WHEN NULLIF(TRIM(mseg.MATNR),'') IS NULL THEN for_Company.BUS_RANGE_CODE  
       ELSE '3000' END = profit_mapping4.bus_range_code     

LEFT JOIN 
(
  SELECT MANDT,MATNR,BWKEY,LFGJA,LFMON,VERPR / PEINH AS VERPR
  FROM ods.ODSSLT_S900_MBEWH
  WHERE MANDT = '900'
  AND BWKEY LIKE '62%'
  AND BWKEY <> '6200'
  AND LFGJA = SUBSTR(@year_month_day,1,4)
  AND LFMON = SUBSTR(@year_month_day,5,2)
) S900_MBEWH
 ON mseg.WERKS = S900_MBEWH.BWKEY
AND mseg.matnr = S900_MBEWH.MATNR
AND mseg.system_src = 'S900'

where not (mseg.PSL = 0 AND mseg.PJE = 0)

;