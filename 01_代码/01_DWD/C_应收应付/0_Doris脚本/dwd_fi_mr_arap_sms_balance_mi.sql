/*******************************************************************************
 *                                  脚本说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261027 18:46
 * 本次修改：ALTER BY 20261027 18:46 SHIQINGFENG.EX 新增统一DWD脚本文件头，未修改业务主体。
 * 上次修改：20260916 ADD BY shiqingfeng.ex 新增
 *
 * 脚本名称  ：dwd_fi_mr_arap_sms_balance_mi.sql
 * 功能描述  ：装载SMS返利余额数据。
 * 源表      ：dw.dwd_ltc_cem_reportpay_balance_summary_dd。
 * 目标表    ：test.dwd_fi_mr_arap_sms_balance_mi
 *
 * 修改历史：
 *   ALTER BY 20261027 18:46 SHIQINGFENG.EX 新增统一DWD脚本文件头，未修改业务主体。
 *   20260916 ADD BY shiqingfeng.ex 新增
 ******************************************************************************/

-- 业务输入：运行月份基准日，格式YYYYMMDD，约定为参数月01日。
SET @year_month_day = DATE_FORMAT((CURDATE() - INTERVAL 7 DAY), '%Y%m01');
--SET @year_month_day = '20260801';
-- 分区月份：YYYYMM。
SET @dt_month = LEFT(@year_month_day, 6);
-- 统计截止日期：取参数月份月末，供SMS外围系统SQL使用。
SET @end_date = LAST_DAY(STR_TO_DATE(@year_month_day, '%Y%m%d'));
-- 以上SET与下方单条INSERT OVERWRITE必须在同一session中依次执行。
set enable_auto_create_when_overwrite=true;

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
    , update_dt       --sms更新时间
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
              t.fanli_curfanli,   -- 上月余额
              t.curfanli,                        -- 当月增加(截止月)
              t.curyearfanli,                    -- 当年增加(截止年)
              t.fanli,                                                     -- 返利额(截止累计)
              t.yishiyong,                                                 -- 已经使用(截止累计)
              t.yue,                                                       -- 返利余额(截止累计)
              t.load_dt AS update_dt,
              NOW() AS load_dt                                     
          FROM dw.dwd_ltc_cem_reportpay_balance_summary_dd t

;