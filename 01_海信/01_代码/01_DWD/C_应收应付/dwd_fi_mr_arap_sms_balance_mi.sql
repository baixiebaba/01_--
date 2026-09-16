/*
-- ============================================================================
-- 最新版修改记录： 20260916 ADD BY shiqingfeng.ex 新增
-- 上一版修改记录：
-- 目标表：sms返利余额表 test.dwd_fi_mr_arap_sms_balance_mi
-- 修改记录：最新修改记录放最上面
--   20260916 ADD BY shiqingfeng.ex 新增
-- ============================================================================
*/

-- 业务输入：运行月份基准日，格式YYYYMMDD，约定为参数月01日。
SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);
-- 统计截止日期：取参数月份月末，供SMS外围系统SQL使用。
SET @end_date = LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d'));
-- 以上SET与下方单条INSERT OVERWRITE必须在同一session中依次执行。
INSERT INTO test.dwd_fi_mr_arap_sms_balance_mi (dt_month) VALUES (@dt_month);

INSERT OVERWRITE TABLE test.dwd_fi_mr_arap_sms_balance_mi PARTITION (*)
(
      dt_month        --年月YYYYMM
    , company_code    --组织
    , orgname         --分公司
    , sales_code      --客商编码
    , sname           --客商描述
    , leibie          --类别
    , fanlicurfanli   --上月余额
    , curfanli        --当月增加
    , curyearfanli    --当年增加
    , fanli           --返利额
    , yishiyong       --已经使用
    , yue             --余额
    , load_dt         --更新时间
)
--注意：@end_date  -->  '2026-08-31'  (替换时需要携带单引号)
          SELECT
              @dt_month AS dt_month,
              t.company_code,
              t.orgname,
              t.sales_code,
              t.sname,
              t.leibie,
              IFNULL(t.fanli,0) - IFNULL(t.curfanli,0) AS fanliCurfanli,   -- 上月余额
              IFNULL(t.curfanli,0)     AS curfanli,                        -- 当月增加(截止月)
              IFNULL(t.curyearfanli,0) AS curyearfanli,                    -- 当年增加(截止年)
              t.fanli,                                                     -- 返利额(截止累计)
              t.yishiyong,                                                 -- 已经使用(截止累计)
              t.yue,                                                       -- 返利余额(截止累计)
              NOW() AS load_dt                                     
          FROM (
              SELECT
                  biao1.orgname, biao1.sname, biao1.leibie,
                  biao1.fanli, biao1.yishiyong, biao1.yue,
                  biao4.fanli AS curfanli,
                  biao5.fanli AS curyearfanli,
                  s.company_code, s.sales_code
              FROM (
                  -- ============ biao1: 累计返利/已使用/余额（截止到 endDate）============
                  SELECT orgname, sname, leibie, sid,
                        SUM(fanli) AS fanli,
                        SUM(yishiyong) AS yishiyong,
                        SUM(fanli - yishiyong) AS yue
                  FROM (
                      -- 分支1: 费用发生额
                      SELECT s.sales_name sname, v.codename leibie, s.row_id sid, d.orgname orgname,
                            SUM(f.check_fee) fanli, 0 yishiyong
                      FROM ods.ODSEMP_SMS_HAC_HISE_OTHER_FEE f
                      JOIN ods.ODSEMP_SMS_HAC_hise_sales_info s ON f.sales_id = s.row_id
                      LEFT JOIN ods.ODSEMP_SMS_HAC_hise_dept d ON s.office_id = d.row_id
                      JOIN (SELECT codevalue, codename FROM ods.ODSEMP_SMS_HAC_his_codelist WHERE kindvalue='back_fee_type') v
                          ON f.fee_type = v.codevalue
                      WHERE (f.source_id NOT LIKE '%FH%' OR f.source_id IS NULL)
                        AND (f.remrak NOT LIKE '%退换货返还%' OR f.remrak IS NULL)
                        AND f.source_type NOT IN ('12','13','192','193')
                        AND DATE(f.action_date) <= DATE(@end_date)
                      GROUP BY s.sales_name, v.codename, s.row_id, d.orgname

                      UNION ALL
                      -- 分支2: 退换货返还（冲减已使用）
                      SELECT s.sales_name sname, v.codename leibie, s.row_id sid, d.orgname orgname,
                            0 fanli, -SUM(f.check_fee) yishiyong
                      FROM ods.ODSEMP_SMS_HAC_HISE_OTHER_FEE f
                      JOIN ods.ODSEMP_SMS_HAC_hise_sales_info s ON f.sales_id = s.row_id
                      LEFT JOIN ods.ODSEMP_SMS_HAC_hise_dept d ON s.office_id = d.row_id
                      JOIN (SELECT codevalue, codename FROM ods.ODSEMP_SMS_HAC_his_codelist WHERE kindvalue='back_fee_type') v
                          ON f.fee_type = v.codevalue
                      WHERE f.remrak LIKE '%退换货返还%'
                        AND f.source_type NOT IN ('12','13')
                        AND DATE(f.action_date) <= DATE(@end_date)
                      GROUP BY s.sales_name, v.codename, s.row_id, d.orgname

                      UNION ALL
                      -- 分支3: FH 开头（按大类折算已使用）
                      SELECT s.sales_name sname, v.codename leibie, s.row_id sid, d.orgname orgname,
                            0 fanli,
                            SUM(CASE v.codename
                                WHEN '费用款返利' THEN IFNULL(n.FY_ZK,0)
                                WHEN '推广费返利' THEN IFNULL(n.TUIG_ZK,0)
                                WHEN '年终奖返利' THEN IFNULL(n.NYL_ZK,0)
                                WHEN '直销返利'   THEN IFNULL(n.ZXL_ZK,0)
                                WHEN '家装返利'   THEN IFNULL(n.JZ_ZK,0)
                                ELSE 0 END) yishiyong
                      FROM (
                          SELECT DISTINCT h.fee_type, h.sales_id, h.source_id
                          FROM ods.ODSEMP_SMS_HAC_HISE_OTHER_FEE h
                          WHERE h.source_id LIKE 'FH%'
                            AND h.source_type NOT IN ('12','13')
                            AND DATE(h.action_date) <= DATE(@end_date)
                      ) f
                      JOIN ods.ODSEMP_SMS_HAC_hise_sales_info s ON f.sales_id = s.row_id
                      LEFT JOIN ods.ODSEMP_SMS_HAC_hise_dept d ON s.office_id = d.row_id
                      JOIN (SELECT codevalue, codename FROM ods.ODSEMP_SMS_HAC_his_codelist WHERE kindvalue='back_fee_type') v
                          ON f.fee_type = v.codevalue
                      LEFT JOIN ods.ODSEMP_SMS_HAC_hise_tr_notice n ON f.source_id = n.row_id
                      WHERE n.notice_status IN ('2','3','4','5','6','7')
                      GROUP BY s.sales_name, v.codename, s.row_id, d.orgname
                  ) biao1_inner
                  GROUP BY orgname, sname, leibie, sid
              ) biao1
              LEFT JOIN (
                  -- ============ biao4: 当月增加（endDate 所在月）============
                  SELECT s.sales_name sname, v.codename leibie, s.row_id sid, d.orgname orgname,
                        SUM(f.check_fee) fanli
                  FROM ods.ODSEMP_SMS_HAC_HISE_OTHER_FEE f
                  JOIN ods.ODSEMP_SMS_HAC_hise_sales_info s ON f.sales_id = s.row_id
                  LEFT JOIN ods.ODSEMP_SMS_HAC_hise_dept d ON s.office_id = d.row_id
                  JOIN (SELECT codevalue, codename FROM ods.ODSEMP_SMS_HAC_his_codelist WHERE kindvalue='back_fee_type') v
                      ON f.fee_type = v.codevalue
                  WHERE (f.source_id NOT LIKE '%FH%' OR f.source_id IS NULL)
                    AND (f.remrak NOT LIKE '%退换货返还%' OR f.remrak IS NULL)
                    AND f.source_type NOT IN ('12','13','192','193')
                    AND DATE_FORMAT(f.action_date,'%Y-%m') = DATE_FORMAT(@end_date,'%Y-%m')
                  GROUP BY s.sales_name, v.codename, s.row_id, d.orgname
              ) biao4 ON biao1.sid = biao4.sid AND biao1.orgname = biao4.orgname AND biao1.leibie = biao4.leibie
              LEFT JOIN (
                  -- ============ biao5: 当年增加（endDate 所在年）============
                  SELECT s.sales_name sname, v.codename leibie, s.row_id sid, d.orgname orgname,
                        SUM(f.check_fee) fanli
                  FROM ods.ODSEMP_SMS_HAC_HISE_OTHER_FEE f
                  JOIN ods.ODSEMP_SMS_HAC_hise_sales_info s ON f.sales_id = s.row_id
                  LEFT JOIN ods.ODSEMP_SMS_HAC_hise_dept d ON s.office_id = d.row_id
                  JOIN (SELECT codevalue, codename FROM ods.ODSEMP_SMS_HAC_his_codelist WHERE kindvalue='back_fee_type') v
                      ON f.fee_type = v.codevalue
                  WHERE (f.source_id NOT LIKE '%FH%' OR f.source_id IS NULL)
                    AND (f.remrak NOT LIKE '%退换货返还%' OR f.remrak IS NULL)
                    AND f.source_type NOT IN ('12','13','192','193')
                    AND YEAR(f.action_date) = YEAR(@end_date)
                  GROUP BY s.sales_name, v.codename, s.row_id, d.orgname
              ) biao5 ON biao1.sid = biao5.sid AND biao1.orgname = biao5.orgname AND biao1.leibie = biao5.leibie
              JOIN ods.ODSEMP_SMS_HAC_hise_sales_info s ON s.row_id = biao1.sid
          ) t

;