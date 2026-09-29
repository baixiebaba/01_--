

-- 调用'{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}'-->'20250501'年月日，日固定为01，{UDP2}最后一个insert需要修改分区，p2025056，p+年月+6
-- select COUNT(1) from  dwd_fi_mr_exp_balance_mi

set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;


--set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';

/*为确保有分区不会报错，先插入一条数据*/
INSERT INTO dwd.dwd_fi_mr_exp_balance_mi (dt_month) VALUES (LEFT(@year_month_day,6));

--INSERT INTO dwd.dwd_fi_mr_exp_balance_mi (dt_month) VALUES (LEFT(@year_month_day,6));

INSERT OVERWRITE TABLE dwd.dwd_fi_mr_exp_balance_mi PARTITION (*)

--INSERT OVERWRITE TABLE dwd.dwd_fi_mr_exp_balance_mi PARTITION ({{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}})
(
 year -- 财务年
,month -- 财务月
,company_code -- 组织
,agency_code -- 办事处编码/成本中心编码
,product_line_code -- 产品线编码
,bcy_amt -- 本位币金额
,qcy_code -- 交易币
,qcy_amt -- 交易币金额
,system_src -- 源系统
,ods_src -- 源表
,acct_src_code -- 原始科目编码
,acct_map_code -- 映射后科目编码
,load_dt -- 更新时间
,dt_month -- 年月
,functional_area_code -- 功能范围
,bus_range_code -- 业务范围
,activity_type_code
,reference_cert_type
)
SELECT 
    year -- 财务年
  , mt.month AS month -- 财务月
  , (CASE WHEN company_code = '6000' AND bus_range_code = '200' THEN '6000A' ELSE company_code END) AS company_code -- 组织
  , agency_code -- 办事处编码/成本中心编码
  , LTRIM(product_line_code,'0') AS product_line_code-- 产品线编码
  , (CASE mt.month
        WHEN '00' THEN IFNULL(hslvt,0)
        WHEN '01' THEN IFNULL(hsl01,0)
        WHEN '02' THEN IFNULL(hsl02,0)
        WHEN '03' THEN IFNULL(hsl03,0)
        WHEN '04' THEN IFNULL(hsl04,0)
        WHEN '05' THEN IFNULL(hsl05,0)
        WHEN '06' THEN IFNULL(hsl06,0)
        WHEN '07' THEN IFNULL(hsl07,0)
        WHEN '08' THEN IFNULL(hsl08,0)
        WHEN '09' THEN IFNULL(hsl09,0)
        WHEN '10' THEN IFNULL(hsl10,0)
        WHEN '11' THEN IFNULL(hsl11,0)
        WHEN '12' THEN IFNULL(hsl12,0)
    END) AS bcy_amt -- 本位币金额
  ,qcy_code
  , (CASE mt.month
        WHEN '00' THEN IFNULL(tslvt,0)
        WHEN '01' THEN IFNULL(tsl01,0)
        WHEN '02' THEN IFNULL(tsl02,0)
        WHEN '03' THEN IFNULL(tsl03,0)
        WHEN '04' THEN IFNULL(tsl04,0)
        WHEN '05' THEN IFNULL(tsl05,0)
        WHEN '06' THEN IFNULL(tsl06,0)
        WHEN '07' THEN IFNULL(tsl07,0)
        WHEN '08' THEN IFNULL(tsl08,0)
        WHEN '09' THEN IFNULL(tsl09,0)
        WHEN '10' THEN IFNULL(tsl10,0)
        WHEN '11' THEN IFNULL(tsl11,0)
        WHEN '12' THEN IFNULL(tsl12,0)
    END) AS qcy_amt -- 交易币金额
  , CONCAT('S',gl.rclnt) AS system_src -- 源系统
  , ods_src -- 源表
  , acct_src_code -- 原始科目编码
  , CASE WHEN CONCAT('S',gl.rclnt) = 'S600' THEN acct_src_code
        /*销售费用内，遇到800版本下4101001003时  会优先映射到管理科目 6601420700 */
         WHEN NVL(acct_map.conto_code,acct_map.conto_mr_code) LIKE '6601%' AND FUNCTIONAL_AREA_CODE IN ('6601','5501','HH04','1020') AND company_code='800' THEN NVL(acct_map.conto_code,acct_map.conto_mr_code)
         ELSE acct_map.conto_code END AS acct_map_code -- 映射后科目编码
  , NOW() AS load_dt -- 更新时间
  , LEFT(@year_month_day,6) AS dt_month  -- 年月
  , functional_area_code -- 功能范围
  , bus_range_code -- 业务范围编码
  , activity_type_code
  , reference_cert_type
FROM (
      SELECT ryear AS year,-- 财务年
             hslvt,hsl01,hsl02,hsl03,hsl04,hsl05,hsl06,hsl07,hsl08,hsl09,hsl10,hsl11,hsl12, -- 本位币金额
             tslvt,tsl01,tsl02,tsl03,tsl04,tsl05,tsl06,tsl07,tsl08,tsl09,tsl10,tsl11,tsl12, -- 交易币金额
             rtcur AS qcy_code, -- 交易币
             rbukrs AS company_code, -- 组织
             rcntr AS agency_code, -- 办事处编码/成本中心编码
             prctr AS product_line_code, -- 产品线编码
             racct AS acct_src_code, -- 原始科目编码
             rfarea AS functional_area_code, -- 功能范围
             rclnt, -- 系统标识
             'FAGLFLEXT' AS ods_src,
             rbusa AS bus_range_code, -- 业务范围编码
             activ AS activity_type_code, -- 活动类型编码
             awtyp AS reference_cert_type    -- 参考凭证类型
        FROM ods.ods_slt_s600_faglflext
      WHERE ryear = LEFT(@year_month_day,4)
    UNION ALL
      SELECT ryear,-- 财务年
             hslvt,hsl01,hsl02,hsl03,hsl04,hsl05,hsl06,hsl07,hsl08,hsl09,hsl10,hsl11,hsl12, -- 本位币金额
             tslvt,tsl01,tsl02,tsl03,tsl04,tsl05,tsl06,tsl07,tsl08,tsl09,tsl10,tsl11,tsl12, -- 交易币金额
             rtcur, -- 交易币
             rbukrs, -- 组织
             NULL AS rcntr, -- 办事处编码/成本中心编码
             rbusa, -- 产品线编码
             racct, -- 原始科目编码
             rfarea, -- 功能范围
             rclnt, -- 系统标识
             'GLFUNCT' AS ods_src,
             rbusa AS bus_range_code, -- 业务范围编码
             '' AS activity_type_code, -- 活动类型编码
             '' AS reference_cert_type    -- 参考凭证类型
        FROM ods.ods_slt_s800_glfunct
      WHERE ryear = LEFT(@year_month_day,4)
    UNION ALL
      SELECT ryear,-- 财务年
             hslvt,hsl01,hsl02,hsl03,hsl04,hsl05,hsl06,hsl07,hsl08,hsl09,hsl10,hsl11,hsl12, -- 本位币金额
             tslvt,tsl01,tsl02,tsl03,tsl04,tsl05,tsl06,tsl07,tsl08,tsl09,tsl10,tsl11,tsl12, -- 交易币金额
             rtcur, -- 交易币
             rbukrs, -- 组织
             rcntr, -- 办事处编码/成本中心编码
             prctr, -- 产品线编码
             racct, -- 原始科目编码
             rfarea, -- 功能范围
             rclnt, -- 系统标识
             'FAGLFLEXT' AS ods_src,
             rbusa AS bus_range_code, -- 业务范围编码
             activ AS activity_type_code, -- 活动类型编码
             awtyp AS reference_cert_type    -- 参考凭证类型
        FROM ods.ods_slt_s810_faglflext
      WHERE ryear = LEFT(@year_month_day,4)
    UNION ALL
      SELECT ryear,-- 财务年
             hslvt,hsl01,hsl02,hsl03,hsl04,hsl05,hsl06,hsl07,hsl08,hsl09,hsl10,hsl11,hsl12, -- 本位币金额
             tslvt,tsl01,tsl02,tsl03,tsl04,tsl05,tsl06,tsl07,tsl08,tsl09,tsl10,tsl11,tsl12, -- 交易币金额
             rtcur, -- 交易币
             rbukrs, -- 组织
             NULL AS rcntr, -- 办事处编码/成本中心编码
             rbusa, -- 产品线编码
             racct, -- 原始科目编码
             rfarea, -- 功能范围
             rclnt, -- 系统标识
             'GLFUNCT' AS ods_src,
             rbusa AS bus_range_code, -- 业务范围编码
             '' AS activity_type_code, -- 活动类型编码
             '' AS reference_cert_type    -- 参考凭证类型
        FROM ods.ods_slt_s900_glfunct
      WHERE ryear = LEFT(@year_month_day,4)
    UNION ALL
      SELECT ryear,-- 财务年
             hslvt,hsl01,hsl02,hsl03,hsl04,hsl05,hsl06,hsl07,hsl08,hsl09,hsl10,hsl11,hsl12, -- 本位币金额
             tslvt,tsl01,tsl02,tsl03,tsl04,tsl05,tsl06,tsl07,tsl08,tsl09,tsl10,tsl11,tsl12, -- 交易币金额
             rtcur, -- 交易币
             rbukrs, -- 组织
             rcntr, -- 办事处编码/成本中心编码
             prctr, -- 产品线编码
             racct, -- 原始科目编码
             rfarea, -- 功能范围
             rclnt, -- 系统标识
             'FAGLFLEXT' AS ods_src,
             rbusa AS bus_range_code, -- 业务范围编码
             activ AS activity_type_code, -- 活动类型编码
             awtyp AS reference_cert_type    -- 参考凭证类型
        FROM ods.ods_s680_faglflext
      WHERE ryear = LEFT(@year_month_day,4)
    UNION ALL
      SELECT ryear,-- 财务年
             hslvt,hsl01,hsl02,hsl03,hsl04,hsl05,hsl06,hsl07,hsl08,hsl09,hsl10,hsl11,hsl12, -- 本位币金额
             tslvt,tsl01,tsl02,tsl03,tsl04,tsl05,tsl06,tsl07,tsl08,tsl09,tsl10,tsl11,tsl12, -- 交易币金额
             rtcur, -- 交易币
             CASE WHEN rbukrs = '1000' AND rclnt = '700' THEN '1730'
                  WHEN rbukrs = '2000' AND rclnt = '700' THEN '1740'
                  WHEN rbukrs = '3000' AND rclnt = '700' THEN '1750'
                  WHEN rbukrs = '5000' AND rclnt = '700' THEN '6240'
              ELSE rbukrs
              END AS rbukrs, -- 组织
             rcntr, -- 办事处编码/成本中心编码
             prctr, -- 产品线编码
             racct, -- 原始科目编码
             rfarea, -- 功能范围
             rclnt, -- 系统标识
             'FAGLFLEXT' AS ods_src,
             rbusa AS bus_range_code, -- 业务范围编码
             activ AS activity_type_code, -- 活动类型编码
             awtyp AS reference_cert_type    -- 参考凭证类型
        FROM ods.ods_slt_s700_faglflext
      WHERE ryear = LEFT(@year_month_day,4)
    ) gl
LEFT JOIN (
  SELECT * 
  FROM (
    SELECT '00' AS month
    UNION ALL SELECT '01'
    UNION ALL SELECT '02'
    UNION ALL SELECT '03'
    UNION ALL SELECT '04'
    UNION ALL SELECT '05'
    UNION ALL SELECT '06'
    UNION ALL SELECT '07'
    UNION ALL SELECT '08'
    UNION ALL SELECT '09'
    UNION ALL SELECT '10'
    UNION ALL SELECT '11'
    UNION ALL SELECT '12'
) a WHERE a.month = SUBSTR(@year_month_day,5,2)
) mt
ON 1=1
 LEFT JOIN (
               SELECT acct_src_code AS racct_src_code
                    , acct_map_code AS conto_code
                    , system_src AS system_src
                    , acct_ma_mr_code AS conto_mr_code
               FROM dim.dim_rule_fi_mr_acct_mapping a
              WHERE valid_fr <= @year_month_day
                AND NVL(valid_to,'999999') >= @year_month_day
            ) acct_map
   ON gl.acct_src_code LIKE acct_map.racct_src_code
  AND CONCAT('S',gl.rclnt) = acct_map.system_src
WHERE 
  (CASE mt.month
        WHEN '00' THEN IFNULL(hslvt,0)
        WHEN '01' THEN IFNULL(hsl01,0)
        WHEN '02' THEN IFNULL(hsl02,0)
        WHEN '03' THEN IFNULL(hsl03,0)
        WHEN '04' THEN IFNULL(hsl04,0)
        WHEN '05' THEN IFNULL(hsl05,0)
        WHEN '06' THEN IFNULL(hsl06,0)
        WHEN '07' THEN IFNULL(hsl07,0)
        WHEN '08' THEN IFNULL(hsl08,0)
        WHEN '09' THEN IFNULL(hsl09,0)
        WHEN '10' THEN IFNULL(hsl10,0)
        WHEN '11' THEN IFNULL(hsl11,0)
        WHEN '12' THEN IFNULL(hsl12,0)
    END) <> 0 OR 
    (CASE mt.month
        WHEN '00' THEN IFNULL(tslvt,0)
        WHEN '01' THEN IFNULL(tsl01,0)
        WHEN '02' THEN IFNULL(tsl02,0)
        WHEN '03' THEN IFNULL(tsl03,0)
        WHEN '04' THEN IFNULL(tsl04,0)
        WHEN '05' THEN IFNULL(tsl05,0)
        WHEN '06' THEN IFNULL(tsl06,0)
        WHEN '07' THEN IFNULL(tsl07,0)
        WHEN '08' THEN IFNULL(tsl08,0)
        WHEN '09' THEN IFNULL(tsl09,0)
        WHEN '10' THEN IFNULL(tsl10,0)
        WHEN '11' THEN IFNULL(tsl11,0)
        WHEN '12' THEN IFNULL(tsl12,0)
    END) <> 0
;