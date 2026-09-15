CREATE OR REPLACE PROCEDURE TGK_GB_HISENSE.CPM_SP_AG_HZOC(V_SCENARIO IN VARCHAR2,
                                           V_PERIODO  IN VARCHAR2,
                                           V_AZIENDA  IN VARCHAR2,
                                           V_USER     IN VARCHAR2) AS
/*****************************************************************

最后更新时间：20260205 10:04
    用途：用于坏账准备账龄表处理
版本信息：
ALTER BY 20260204 XIAOYACHAO.EX 因为交易对手转为投资B拆分数据导致个别认定重复,增加适用范围
ALTER BY 20260104 XIAOYACHAO.EX 因为交易对手转为投资B拆分数据导致个别认定重复
ALTER BY 20250903 XIAOYACHAO.EX 核销金额取本位币
ALTER BY 20250504 XIAOYAHAO.EX 增加一二三级性质匹配
ALTER BY 20241119 09:53 XIAOYACHAO.EX : 增加TVS公司坏账计算
ALTER BY 20241101 11:04 XIAOYACHAO.EX : 9000&金投公司不进行坏账计算
ALTER BY 20240919 14:07 XIAOYACHAO.EX : 1801,6430公司的应收和合同资产计提逻辑改为（账龄段扣减垫资金额）*计提比例，取消超期
ALTER BY 20240919 10:09 XIAOYACHAO.EX : 增加投保未覆盖比例逻辑
ALTER BY 20240904 10:50 XIAOYACHAO.EX ：取消1170公司 '1170201','1170202','1170203'的特殊逻辑
ALTER BY 20240828 08:56 XIAOYACHAO.EX ：核销金额科目转换汇总
ALTER BY 20240809 10:00 XIAOYACHAO.EX : 增加长期应收科目
ALTER BY 20240808 14:06 XIAOYACHAO.EX ：核销金额科目转换汇总
ALTER BY 20240806 18:19 XIAOYACHAO.EX : 坏账计提增加核销金额字段
ALTER BY 20240724 XIAOYACHAO.EX ：1730,6210 煤改电性质特殊用户 坏账处理
ALTER BY 20240702 XIAOYACHAO.EX ：冰箱：总公司维护比例，分公司同样适用.
ALTER BY 20240626 XIAOYACHAO.EX ：家电公司特殊客商跨公司合并计提坏账
ALTER BY 20240611 XIAOYACHAO.EX ：增加坏账计提方法
ALTER BY 20240604 XIAOYACHAO.EX ：1170增加合同资产科目的'1170201','1170202','1170203'三个产品线 ：各个账龄段的  超期金额*超期坏账比例
ALTER BY 20240602 XIAOYACHAO.EX ：视像坏账计算逻辑修改：不使用超期计算坏账
ALTER BY 20240520 XIAOYACHAO.EX ：视像/空调计提比例统一使用总公司计提比例
ALTER BY 20240517 XIAOYACHAO.EX ：6430坏账计算逻辑优化
ALTER BY 20240513 XIAOYACHAO.EX ：坏账计算增加6008应收特殊处理
ALTER BY 20240511 XIAOYACHAO.EX ：坏账计算增加网能/嘉科特殊处理
ALTER BY 20240508 XIAOYACHAO.EX ：冰箱营销公司判断去除6000A
ALTER BY 20240507 XIAOYACHAO.EX ：日立坏账计算合并到通用程序里面
ALTER BY 20240511 XIAOYACHAO.EX ：保证坏账余额计算结果跟9个账龄段计算结果一致
V2.统计逻辑的完善 ALTER  BY XIAOYACHAO.EX at 20240314
V1.初始版本创建   CREATE BY XIAOYACHAO.EX at 20240312

坏账计算逻辑：
    1.通用逻辑：  <1>有个别认定先取个别认定  <2> 各个账龄段的（应收金额-超期金额）*应收坏账比例  + 超期金额*超期坏账比例
    2.视像科技：  <1>有个别认定先取个别认定  <2> 当呆死金额>0时：取呆死金额。否则：账龄1年以内 * 0.05 + 1-2年 * 0.1 + 2-3年 * 0.2 + 3-4年 * 0.5 + 5年以上 * 1
    3.医疗：      <1>有个别认定先取个别认定  <2> 1170公司下应收账款，合同资产科目的'1170201','1170202','1170203'三个产品线 ：各个账龄段的  超期金额*超期坏账比例   <3> 其余使用通用逻辑
    4.网络能源：  <1>有个别认定先取个别认定  <2> 1801公司下应收账款/合同资产科目：(账龄段-垫资)*计提比例  <3> 其他应收款使用通用逻辑
    5.日立：      <1>有个别认定先取个别认定  <2> 当垫资金额=0时：使用通用逻辑;当垫资金额 >= 本月余额时：坏账为0 ;0<当垫资金额<本月余额时：用垫资抵扣长账龄段金额，然后按照通用逻辑计算坏账
    6.科龙嘉科：  <1>有个别认定先取个别认定  <2> 6430公司下应收账款/合同资产科目：超期金额*分超期计提比例+（应收账款/合同资产金额-超期总金额-垫资金额）*计提比例  <3> 其他应收款使用通用逻辑
    7.6008：      <1>有个别认定先取个别认定  <2> 6008公司下应收账款的双经销商客户：（应收-应付）*计提比例  <3> 其余使用通用逻辑
********************************************************************/
V_YEARMONTH   VARCHAR2(20);   -- 当月
V_LYEARMONTH  VARCHAR2(20);   -- 上月
V_LOCK        NUMBER;         -- 锁状态
V_AZI_LIST    VARCHAR2(4000); -- 冰箱空调营销：此列表判断公司是否营销公司：如果是剔除应收科目，防止重复
V_IS_SX       NUMBER:=0;      -- 是否视像：总公司维护比例，分公司同样适用，根据此标志将分公司转换为总公司编码
V_IS_KT       NUMBER:=0;      -- 是否空调：总公司维护比例，分公司同样适用，根据此标志将分公司转换为总公司编码
V_IS_BX       NUMBER:=0;      -- 是否冰箱：总公司维护比例，分公司同样适用，根据此标志将分公司转换为总公司编码

BEGIN
  /*获取当月和上月*/
  V_YEARMONTH :=SUBSTR(V_SCENARIO,1,4)||V_PERIODO;
  V_LYEARMONTH:=TO_CHAR(ADD_MONTHS(TO_DATE(SUBSTR(V_SCENARIO,1,4)||V_PERIODO,'YYYYMM'),-1),'YYYYMM');

  /*获取账龄表锁定状态*/
  SELECT NVL(SUM(CASE WHEN T.COD_AZIENDA IN ('9000','1013','1014','9002','9004','9005') THEN 1 ELSE T.IMPORTO END),0)   /*ALTER BY 20241101 11：04 9000&金投公司不进行坏账计算*/
    INTO V_LOCK
    FROM TGK_GB_HISENSE.DATI_SALDI_LORDI T
   WHERE T.COD_SCENARIO = V_SCENARIO
     AND T.COD_PERIODO = V_PERIODO
     AND INSTR(V_AZIENDA,T.COD_AZIENDA) > 0
     AND T.COD_CONTO = 'SLK0105';

 --V_LOCK := 0;
 /*获取营销公司*/ /*冰箱营销公司判断去除6000A ALTER BY XIAOYACHAO.EX  at 20240508*/
 SELECT WM_CONCAT(ELEM) INTO V_AZI_LIST FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '10' AND T.NODE IN ('03020','04020') AND T.ELEM NOT IN  ('6000','6000A','6000B','6000C','6600');
 SELECT COUNT(1) INTO V_IS_SX FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01' AND T.NODE = '2000' AND ELEM <> '2910' AND INSTR(V_AZIENDA,T.ELEM) > 0 ;--T.ELEM = V_AZIENDA;
 SELECT COUNT(1) INTO V_IS_KT FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '10' AND T.NODE = '04020' AND T.ELEM NOT IN  ('6000','6000A','6000B','6000C','6600') AND INSTR(V_AZIENDA,T.ELEM) > 0;--T.ELEM = V_AZIENDA;
 SELECT COUNT(1) INTO V_IS_BX FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '10' AND T.NODE = '03020' AND T.ELEM NOT IN  ('6000','6000A','6000B','6000C','6600') AND INSTR(V_AZIENDA,T.ELEM) > 0;--T.ELEM = V_AZIENDA;

IF V_LOCK = 0 THEN
 --记录日志
INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_HZOC', V_SCENARIO, V_PERIODO, '0 SATRT', SYSDATE, V_USER,V_AZIENDA);
COMMIT;

/******************* 1.1 往来账龄坏账计提结果表数据删除 ***************************/

DELETE FROM ZTAB_AG_TF_OC T WHERE T.YEARMONTH = V_YEARMONTH AND INSTR(V_AZIENDA,T.BUKRS) > 0 ;

INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_HZOC', V_SCENARIO, V_PERIODO, '1.1 坏账计提结果表数据删除完成', SYSDATE, V_USER,V_AZIENDA);
COMMIT;

/******************* 1.2 往来账龄坏账计提结果表数据插入 ***************************/

INSERT INTO ZTAB_AG_TF_OC (
    oid            --  id
  , YEARMONTH      --  年月
  , BUKRS          --  公司
  , HKONT          --  科目
  , CVCODE         --  客户编码
  , CVNAME         --  客户名称
  , PRCTR          --  产品线
  , DESC_PRCTR     --  产品线名称
  , YWFW           --  业务范围
  , YWFWMC         --  业务范围名称
  , XZ             --  性质
  , BZ             --  币种
  , ZLJE1          --  账龄金额1个月
  , ZLJE2          --  账龄金额2-3个月
  , ZLJE3          --  账龄金额4-6个月
  , ZLJE4          --  账龄金额7-12个月
  , ZLJE5          --  账龄金额1-2年
  , ZLJE6          --  账龄金额2-3年
  , ZLJE7          --  账龄金额3-4年
  , ZLJE8          --  账龄金额4-5年
  , ZLJE9          --  账龄金额5年以上
  , CQJE           --  当月超期金额
  , CQJE1          --  超期金额1个月
  , CQJE2          --  超期金额2-3个月
  , CQJE3          --  超期金额4-6个月
  , CQJE4          --  超期金额7-12个月
  , CQJE5          --  超期金额1-2年
  , CQJE6          --  超期金额2-3年
  , CQJE7          --  超期金额3-4年
  , CQJE8          --  超期金额4-5年
  , CQJE9          --  超期金额5年以上
  , HZYE           --  坏账余额
  , CQHZYE         --  超期坏账余额
  , BYYE           --  本月余额
  , ZLYE1          --  账龄余额1个月
  , ZLYE2          --  账龄余额2-3个月
  , ZLYE3          --  账龄余额4-6个月
  , ZLYE4          --  账龄余额7-12个月
  , ZLYE5          --  账龄余额1-2年
  , ZLYE6          --  账龄余额2-3年
  , ZLYE7          --  账龄余额3-4年
  , ZLYE8          --  账龄余额4-5年
  , ZLYE9          --  账龄余额5年以上
  , CQYE1          --  超期余额1个月
  , CQYE2          --  超期余额2-3个月
  , CQYE3          --  超期余额4-6个月
  , CQYE4          --  超期余额7-12个月
  , CQYE5          --  超期余额1-2年
  , CQYE6          --  超期余额2-3年
  , CQYE7          --  超期余额3-4年
  , CQYE8          --  超期余额4-5年
  , CQYE9          --  超期余额5年以上
  , HZBL1          --  正常账龄损失率1个月
  , HZBL2          --  正常账龄损失率2-3个月
  , HZBL3          --  正常账龄损失率4-6个月
  , HZBL4          --  正常账龄损失率7-12个月
  , HZBL5          --  正常账龄损失率1-2年
  , HZBL6          --  正常账龄损失率2-3年
  , HZBL7          --  正常账龄损失率3-4年
  , HZBL8          --  正常账龄损失率4-5年
  , HZBL9          --  正常账龄损失率5年以上
  , CQBL1          --  超期账龄损失率1个月
  , CQBL2          --  超期账龄损失率2-3个月
  , CQBL3          --  超期账龄损失率4-6个月
  , CQBL4          --  超期账龄损失率7-12个月
  , CQBL5          --  超期账龄损失率1-2年
  , CQBL6          --  超期账龄损失率2-3年
  , CQBL7          --  超期账龄损失率3-4年
  , CQBL8          --  超期账龄损失率4-5年
  , CQBL9          --  超期账龄损失率5年以上
  , DYJTJE         --  当月计提金额
  , IS_GBRD        --  是否个别认定
  , SYHZYE         --  上月坏账余额
  , SYJTHZ1        --  上月计提坏账1个月
  , SYJTHZ2        --  上月计提坏账2-3个月
  , SYJTHZ3        --  上月计提坏账4-6个月
  , SYJTHZ4        --  上月计提坏账7-12个月
  , SYJTHZ5        --  上月计提坏账1-2年
  , SYJTHZ6        --  上月计提坏账2-3年
  , SYJTHZ7        --  上月计提坏账3-4年
  , SYJTHZ8        --  上月计提坏账4-5年
  , SYJTHZ9        --  上月计提坏账5年以上
  , DATEUPD        --  更新时间
  , USERUPD        --  更新用户
  , BUKRS_HBRZ     --  合并入账公司
)
WITH HZZB AS (
SELECT
       T.OID_FORM_DATI                                         -- id
      ,SUBSTR(T.COD_SCENARIO,1,4)||T.COD_PERIODO AS YEARMONTH  -- 年月
      ,T.COD_AZIENDA AS BUKRS                                  -- 公司
      ,T.COD_CONTO   AS HKONT                                  -- 科目
      ,T.TESTO_14    AS CVCODE                                 -- 客户编码
      ,T.TESTO_15    AS CVNAME                                 -- 客户名称
      ,T.TESTO_2     AS XZ                                     -- 性质
      ,NVL(T.TESTO_21,P.TESTO_21) AS PRCTR                     -- 产品线
      ,NVL(P.TESTO_22,T.TESTO_22) AS PRCTR_DESC                -- 产品线名称
      ,T.TESTO_23    AS YWFW                                   -- 业务范围
      ,T.TESTO_24    AS YWFWMC                                 -- 业务范围名称
      ,T.COD_VALUTA  AS BZ                                     -- 币种
      ,NVL(T.IMPORTO_6,0)   AS ZLJE1                           -- 账龄金额1个月
      ,NVL(T.IMPORTO_7,0)   AS ZLJE2                           -- 账龄金额2-3个月
      ,NVL(T.IMPORTO_8,0)   AS ZLJE3                           -- 账龄金额4-6个月
      ,NVL(T.IMPORTO_9,0)   AS ZLJE4                           -- 账龄金额7-12个月
      ,NVL(T.IMPORTO_10,0)  AS ZLJE5                           -- 账龄金额1-2年
      ,NVL(T.IMPORTO_11,0)  AS ZLJE6                           -- 账龄金额2-3年
      ,NVL(T.IMPORTO_12,0)  AS ZLJE7                           -- 账龄金额3-4年
      ,NVL(T.IMPORTO_22,0)  AS ZLJE8                           -- 账龄金额4-5年
      ,NVL(T.IMPORTO_21,0)  AS ZLJE9                           -- 账龄金额5年以上
      ,NVL(T.IMPORTO_13,0)  AS CQJE                            -- 超期金额
      ,NVL(T.IMPORTO_14,0)  AS CQJE1                           -- 超期金额1个月
      ,NVL(T.IMPORTO_15,0)  AS CQJE2                           -- 超期金额2-3个月
      ,NVL(T.IMPORTO_41,0)  AS CQJE3                           -- 超期金额4-6个月
      ,NVL(T.IMPORTO_42,0)  AS CQJE4                           -- 超期金额7-12个月
      ,NVL(T.IMPORTO_43,0)  AS CQJE5                           -- 超期金额1-2年
      ,NVL(T.IMPORTO_44,0)  AS CQJE6                           -- 超期金额2-3年
      ,NVL(T.IMPORTO_45,0)  AS CQJE7                           -- 超期金额3-4年
      ,NVL(T.IMPORTO_46,0)  AS CQJE8                           -- 超期金额4-5年
      ,NVL(T.IMPORTO_47,0)  AS CQJE9                           -- 超期金额5年以上

      ,CASE
            /*1730,6210煤改电性质特殊用户 坏账处理*/
            WHEN T.COD_AZIENDA IN ('1730','6210') AND MGD.TESTO_12 IS NOT NULL
              THEN MGD.IMPORTO_20
            /*日立：（应收-垫资金额）*计提比例 <2> alter by 20240919 xiaoyachao.ex 增加投保未覆盖比例逻辑 */
            /*tvs,1081网络能源，6430科龙嘉科公司：应收账款、合同资产：（应收-垫资金额）*计提比例;其他应收款：各账龄段金额*计提比例 alter by 20240919 xiaoyachao.ex */
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR T.COD_AZIENDA = '2910' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') )THEN  /*ALTER BY 20241119 XIAOYACHAO.EX 增加TVS的坏账计算*/
              CASE WHEN T.IMPORTO_35<=0
                     THEN T.IMPORTO_21*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0)+
                          T.IMPORTO_22*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0)+
                          T.IMPORTO_12*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0)+
                          T.IMPORTO_11*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0)+
                          T.IMPORTO_10*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
                          T.IMPORTO_9*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)+
                          T.IMPORTO_8*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
                          T.IMPORTO_7*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                          T.IMPORTO_6*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   WHEN T.IMPORTO_35>=T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7 +T.IMPORTO_6
                     THEN 0
                   WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7
                      THEN (-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7 +T.IMPORTO_6)*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8
                      THEN (-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7)*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_6*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9
                      THEN (-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8)*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_7*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_6*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10
                      THEN (-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9)*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_8*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_7*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_6*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11
                      THEN (-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10)*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
                           T.IMPORTO_9*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)+
                           T.IMPORTO_8*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
                           T.IMPORTO_7*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                           T.IMPORTO_6*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12
                      THEN (-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11)*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0)+
                            T.IMPORTO_10*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
                            T.IMPORTO_9*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_8*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_7*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_6*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22
                      THEN (-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12)*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0)+
                            T.IMPORTO_11*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0)+
                            T.IMPORTO_10*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
                            T.IMPORTO_9*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_8*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_7*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_6*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   WHEN T.IMPORTO_35 >= T.IMPORTO_21
                      THEN (-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22)*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0)+
                            T.IMPORTO_12*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0)+
                            T.IMPORTO_11*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0)+
                            T.IMPORTO_10*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
                            T.IMPORTO_9*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_8*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_7*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_6*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   WHEN T.IMPORTO_35 >= 0
                      THEN (-T.IMPORTO_35+T.IMPORTO_21)*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0)+
                            T.IMPORTO_22*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0)+
                            T.IMPORTO_12*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0)+
                            T.IMPORTO_11*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0)+
                            T.IMPORTO_10*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
                            T.IMPORTO_9*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_8*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_7*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                            T.IMPORTO_6*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                   ELSE 0
             END
            /*视像科技除2910外：通用逻辑剔除超期部分 ALTER BY XIAOYACHAO.EX AT 20240602 */
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B') AND T.COD_AZIENDA <> '2910'
              THEN NVL(T.IMPORTO_6 ,0)*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)+
                   NVL(T.IMPORTO_7 ,0)*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
                   NVL(T.IMPORTO_8 ,0)*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
                   NVL(T.IMPORTO_9 ,0)*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)+
                   NVL(T.IMPORTO_10,0)*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
                   NVL(T.IMPORTO_11,0)*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0)+
                   NVL(T.IMPORTO_12,0)*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0)+
                   NVL(T.IMPORTO_22,0)*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0)+
                   NVL(T.IMPORTO_21,0)*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0)
              /*6008公司双经销商坏账计提金额为应收-应付*/
             WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
               THEN  (NVL(T.IMPORTO_6 ,0)+NVL(YF.IMPORTO_6 ,0)-NVL(T.IMPORTO_14,0))*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)+
                     (NVL(T.IMPORTO_7 ,0)+NVL(YF.IMPORTO_7 ,0)-NVL(T.IMPORTO_15,0))*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)+
                     (NVL(T.IMPORTO_8 ,0)+NVL(YF.IMPORTO_8 ,0)-NVL(T.IMPORTO_41,0))*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)+
                     (NVL(T.IMPORTO_9 ,0)+NVL(YF.IMPORTO_9 ,0)-NVL(T.IMPORTO_42,0))*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)+
                     (NVL(T.IMPORTO_10,0)+NVL(YF.IMPORTO_10,0)-NVL(T.IMPORTO_43,0))*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
                     (NVL(T.IMPORTO_11,0)+NVL(YF.IMPORTO_11,0)-NVL(T.IMPORTO_44,0))*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0)+
                     (NVL(T.IMPORTO_12,0)+NVL(YF.IMPORTO_12,0)-NVL(T.IMPORTO_45,0))*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0)+
                     (NVL(T.IMPORTO_22,0)+NVL(YF.IMPORTO_22,0)-NVL(T.IMPORTO_46,0))*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0)+
                     (NVL(T.IMPORTO_21,0)+NVL(YF.IMPORTO_21,0)-NVL(T.IMPORTO_47,0))*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0)+
                     (NVL(T.IMPORTO_14,0)*NVL(CQ.IMPORTO_6,0)) +
                     (NVL(T.IMPORTO_15,0)*NVL(CQ.IMPORTO_7,0)) +
                     (NVL(T.IMPORTO_41,0)*NVL(CQ.IMPORTO_8,0)) +
                     (NVL(T.IMPORTO_42,0)*NVL(CQ.IMPORTO_9,0)) +
                     (NVL(T.IMPORTO_43,0)*NVL(CQ.IMPORTO_10,0))+
                     (NVL(T.IMPORTO_44,0)*NVL(CQ.IMPORTO_11,0))+
                     (NVL(T.IMPORTO_45,0)*NVL(CQ.IMPORTO_12,0))+
                     (NVL(T.IMPORTO_46,0)*NVL(CQ.IMPORTO_22,0))+
                     (NVL(T.IMPORTO_47,0)*NVL(CQ.IMPORTO_21,0))
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN   (NVL(T.IMPORTO_6 ,0)-NVL(T.IMPORTO_14,0)+NVL(JD.IMPORTO_6 ,0))*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)+
                     (NVL(T.IMPORTO_7 ,0)-NVL(T.IMPORTO_15,0)+NVL(JD.IMPORTO_7 ,0))*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)+
                     (NVL(T.IMPORTO_8 ,0)-NVL(T.IMPORTO_41,0)+NVL(JD.IMPORTO_8 ,0))*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)+
                     (NVL(T.IMPORTO_9 ,0)-NVL(T.IMPORTO_42,0)+NVL(JD.IMPORTO_9 ,0))*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)+
                     (NVL(T.IMPORTO_10,0)-NVL(T.IMPORTO_43,0)+NVL(JD.IMPORTO_10 ,0))*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
                     (NVL(T.IMPORTO_11,0)-NVL(T.IMPORTO_44,0)+NVL(JD.IMPORTO_11 ,0))*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0)+
                     (NVL(T.IMPORTO_12,0)-NVL(T.IMPORTO_45,0)+NVL(JD.IMPORTO_12 ,0))*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0)+
                     (NVL(T.IMPORTO_22,0)-NVL(T.IMPORTO_46,0)+NVL(JD.IMPORTO_22 ,0))*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0)+
                     (NVL(T.IMPORTO_21,0)-NVL(T.IMPORTO_47,0)+NVL(JD.IMPORTO_21 ,0))*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0)+
                     (NVL(T.IMPORTO_14,0)*NVL(CQ.IMPORTO_6,0)) +
                     (NVL(T.IMPORTO_15,0)*NVL(CQ.IMPORTO_7,0)) +
                     (NVL(T.IMPORTO_41,0)*NVL(CQ.IMPORTO_8,0)) +
                     (NVL(T.IMPORTO_42,0)*NVL(CQ.IMPORTO_9,0)) +
                     (NVL(T.IMPORTO_43,0)*NVL(CQ.IMPORTO_10,0))+
                     (NVL(T.IMPORTO_44,0)*NVL(CQ.IMPORTO_11,0))+
                     (NVL(T.IMPORTO_45,0)*NVL(CQ.IMPORTO_12,0))+
                     (NVL(T.IMPORTO_46,0)*NVL(CQ.IMPORTO_22,0))+
                     (NVL(T.IMPORTO_47,0)*NVL(CQ.IMPORTO_21,0))

            /*通用 alter by 20240919 xiaoyachao.ex 增加投保未覆盖比例逻辑 */
            ELSE
               (NVL(T.IMPORTO_6 ,0)-NVL(T.IMPORTO_14,0))*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)+
               (NVL(T.IMPORTO_7 ,0)-NVL(T.IMPORTO_15,0))*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)+
               (NVL(T.IMPORTO_8 ,0)-NVL(T.IMPORTO_41,0))*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)+
               (NVL(T.IMPORTO_9 ,0)-NVL(T.IMPORTO_42,0))*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)+
               (NVL(T.IMPORTO_10,0)-NVL(T.IMPORTO_43,0))*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0)+
               (NVL(T.IMPORTO_11,0)-NVL(T.IMPORTO_44,0))*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0)+
               (NVL(T.IMPORTO_12,0)-NVL(T.IMPORTO_45,0))*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0)+
               (NVL(T.IMPORTO_22,0)-NVL(T.IMPORTO_46,0))*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0)+
               (NVL(T.IMPORTO_21,0)-NVL(T.IMPORTO_47,0))*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0)+
               (NVL(T.IMPORTO_14,0)*NVL(CQ.IMPORTO_6,0)) +
               (NVL(T.IMPORTO_15,0)*NVL(CQ.IMPORTO_7,0)) +
               (NVL(T.IMPORTO_41,0)*NVL(CQ.IMPORTO_8,0)) +
               (NVL(T.IMPORTO_42,0)*NVL(CQ.IMPORTO_9,0)) +
               (NVL(T.IMPORTO_43,0)*NVL(CQ.IMPORTO_10,0))+
               (NVL(T.IMPORTO_44,0)*NVL(CQ.IMPORTO_11,0))+
               (NVL(T.IMPORTO_45,0)*NVL(CQ.IMPORTO_12,0))+
               (NVL(T.IMPORTO_46,0)*NVL(CQ.IMPORTO_22,0))+
               (NVL(T.IMPORTO_47,0)*NVL(CQ.IMPORTO_21,0))
       END AS HZYE    /*坏账余额*/
      ,NVL(T.IMPORTO_14*CQ.IMPORTO_6,0) + NVL(T.IMPORTO_15*CQ.IMPORTO_7,0) + NVL(T.IMPORTO_41*CQ.IMPORTO_8,0) + NVL(T.IMPORTO_42*CQ.IMPORTO_9,0) +
       NVL(T.IMPORTO_43*CQ.IMPORTO_10,0) +NVL(T.IMPORTO_44*CQ.IMPORTO_11,0) +NVL(T.IMPORTO_45*CQ.IMPORTO_12,0) + NVL(T.IMPORTO_46*CQ.IMPORTO_22,0) + NVL(T.IMPORTO_47*CQ.IMPORTO_21,0) AS CQHZYE
      ,NVL(T.IMPORTO_3,0)   AS BYYE  /*本月余额*/
      ,CASE
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B' AND ELEM <> '2910')
              THEN (CASE WHEN T.COD_CATEGORIA = '1REC' AND T.IMPORTO_16 <= 0 THEN NVL(T.IMPORTO_6,0)*0.05 ELSE 0 END)
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') )
              THEN (CASE WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7+T.IMPORTO_6 THEN 0
                         WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7
                           THEN (-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7 +T.IMPORTO_6)*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end)
                         ELSE (NVL(T.IMPORTO_6,0)- NVL(CQ.IMPORTO_14,0))*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end) + NVL(T.IMPORTO_14*CQ.IMPORTO_6 ,0)
                    END)
            WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
              THEN (NVL(T.IMPORTO_6,0)+ NVL(YF.IMPORTO_6,0) - NVL(CQ.IMPORTO_14,0))*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0) + NVL(T.IMPORTO_14*CQ.IMPORTO_6 ,0)
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN (NVL(T.IMPORTO_6 ,0)-NVL(T.IMPORTO_14,0)+NVL(JD.IMPORTO_6 ,0))*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)+ (NVL(T.IMPORTO_14,0)*NVL(CQ.IMPORTO_6,0))
            ELSE (NVL(T.IMPORTO_6,0)- NVL(CQ.IMPORTO_14,0))*COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6,BC1.IMPORTO_6,0)*(case when nvl(tb.bzts,0)> 0  then nvl(tb.wfugbl,0) else 1 end) + NVL(T.IMPORTO_14*CQ.IMPORTO_6 ,0)
       END AS ZLYE1    -- 账龄余额1个月
      ,CASE
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B' AND ELEM <> '2910')
              THEN (CASE WHEN T.COD_CATEGORIA = '1REC' AND T.IMPORTO_16 <= 0 THEN NVL(T.IMPORTO_7,0)*0.05 ELSE 0 END)
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') ) THEN
              (CASE WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7+T.IMPORTO_6 THEN 0
                    WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8
                      THEN GREATEST((-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7)*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0),0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end)
                    ELSE (NVL(T.IMPORTO_7,0)- NVL(CQ.IMPORTO_15,0))*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end) + NVL(T.IMPORTO_15*CQ.IMPORTO_7 ,0)
               END)
            WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
              THEN (NVL(T.IMPORTO_7,0)+ NVL(YF.IMPORTO_7,0) - NVL(CQ.IMPORTO_15,0))*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0) + NVL(T.IMPORTO_15*CQ.IMPORTO_7 ,0)
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN (NVL(T.IMPORTO_7,0)- NVL(CQ.IMPORTO_15,0)+NVL(JD.IMPORTO_7,0))*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0) + NVL(T.IMPORTO_15*CQ.IMPORTO_7 ,0)
            ELSE (NVL(T.IMPORTO_7,0)- NVL(CQ.IMPORTO_15,0))*COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7,BC1.IMPORTO_7,0)*(case when nvl(tb.bzts,0)> 30 then nvl(tb.wfugbl,0) else 1 end) + NVL(T.IMPORTO_15*CQ.IMPORTO_7 ,0)
       END AS ZLYE2    -- 账龄余额2-3个月
      ,CASE
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B' AND ELEM <> '2910')
              THEN (CASE WHEN T.COD_CATEGORIA = '1REC' AND T.IMPORTO_16 <= 0 THEN NVL(T.IMPORTO_8,0)*0.05 ELSE 0 END)
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') )THEN
              (CASE WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7+T.IMPORTO_6 THEN 0
                    WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9
                      THEN GREATEST((-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8)*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0),0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end)
                    ELSE (NVL(T.IMPORTO_8,0)- NVL(CQ.IMPORTO_41,0))*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end) + NVL(T.IMPORTO_41*CQ.IMPORTO_8 ,0)
               END)
            WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
              THEN (NVL(T.IMPORTO_8,0)+ NVL(YF.IMPORTO_8,0)-NVL(CQ.IMPORTO_41,0))*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0) + NVL(T.IMPORTO_41*CQ.IMPORTO_8 ,0)
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN (NVL(T.IMPORTO_8,0)- NVL(CQ.IMPORTO_41,0)+NVL(JD.IMPORTO_8,0))*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0) + NVL(T.IMPORTO_41*CQ.IMPORTO_8 ,0)
            ELSE (NVL(T.IMPORTO_8,0)- NVL(CQ.IMPORTO_41,0))*COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8,BC1.IMPORTO_8,0)*(case when nvl(tb.bzts,0)> 90 then nvl(tb.wfugbl,0) else 1 end) + NVL(T.IMPORTO_41*CQ.IMPORTO_8 ,0)
       END AS ZLYE3    -- 账龄余额4-6个月
      ,CASE
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B' AND ELEM <> '2910')
              THEN (CASE WHEN T.COD_CATEGORIA = '1REC' AND T.IMPORTO_16 <= 0 THEN NVL(T.IMPORTO_9,0)*0.05 ELSE 0 END)
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') ) THEN
              (CASE WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7+T.IMPORTO_6 THEN 0
                    WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10
                      THEN GREATEST((-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9)*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0),0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end)
                    ELSE (NVL(T.IMPORTO_9,0)- NVL(CQ.IMPORTO_42,0))*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end) + NVL(T.IMPORTO_42*CQ.IMPORTO_9 ,0)
               END)
            WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
              THEN (NVL(T.IMPORTO_9,0)+ NVL(YF.IMPORTO_9,0)-NVL(CQ.IMPORTO_42,0))*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0) + NVL(T.IMPORTO_42*CQ.IMPORTO_9 ,0)
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN (NVL(T.IMPORTO_9,0)- NVL(CQ.IMPORTO_42,0)+NVL(JD.IMPORTO_9,0))*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0) + NVL(T.IMPORTO_42*CQ.IMPORTO_9 ,0)
            ELSE (NVL(T.IMPORTO_9,0)- NVL(CQ.IMPORTO_42,0))*COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9,BC1.IMPORTO_9,0)*(case when nvl(tb.bzts,0)> 180then nvl(tb.wfugbl,0) else 1 end) + NVL(T.IMPORTO_42*CQ.IMPORTO_9 ,0)
       END AS ZLYE4    -- 账龄余额7-12个月
      ,CASE
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B' AND ELEM <> '2910')
              THEN (CASE WHEN T.COD_CATEGORIA = '1REC' AND T.IMPORTO_16 <= 0  THEN NVL(T.IMPORTO_10,0)*0.1 ELSE 0 END)
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') ) THEN
              (CASE WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7+T.IMPORTO_6 THEN 0
                    WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11
                      THEN GREATEST((-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10)*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0),0)
                    ELSE (NVL(T.IMPORTO_10,0)-NVL(CQ.IMPORTO_43,0))*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0) + NVL(T.IMPORTO_43*CQ.IMPORTO_10,0)
               END)
            WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
              THEN (NVL(T.IMPORTO_10,0)+NVL(YF.IMPORTO_10,0)-NVL(CQ.IMPORTO_43,0))*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0) + NVL(T.IMPORTO_43*CQ.IMPORTO_10,0)
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN (NVL(T.IMPORTO_10,0)-NVL(CQ.IMPORTO_43,0)+NVL(JD.IMPORTO_10,0))*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0) + NVL(T.IMPORTO_43*CQ.IMPORTO_10,0)
            ELSE (NVL(T.IMPORTO_10,0)-NVL(CQ.IMPORTO_43,0))*COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10,BC1.IMPORTO_10,0) + NVL(T.IMPORTO_43*CQ.IMPORTO_10,0)
       END AS ZLYE5    -- 账龄余额1-2年
      ,CASE
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B' AND ELEM <> '2910')
              THEN (CASE WHEN T.COD_CATEGORIA = '1REC' AND T.IMPORTO_16 <= 0  THEN NVL(T.IMPORTO_11,0)*0.2 ELSE 0 END)
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') ) THEN
              (CASE WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7+T.IMPORTO_6 THEN 0
                    WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12
                      THEN GREATEST((-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11)*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0),0)
                    ELSE (NVL(T.IMPORTO_11,0)-NVL(CQ.IMPORTO_44,0))*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0) + NVL(T.IMPORTO_44*CQ.IMPORTO_11,0)
               END)
            WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
              THEN (NVL(T.IMPORTO_11,0)+NVL(YF.IMPORTO_11,0)-NVL(CQ.IMPORTO_44,0))*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0) + NVL(T.IMPORTO_44*CQ.IMPORTO_11,0)
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN (NVL(T.IMPORTO_11,0)-NVL(CQ.IMPORTO_44,0)+NVL(JD.IMPORTO_11,0))*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0) + NVL(T.IMPORTO_44*CQ.IMPORTO_11,0)
            ELSE (NVL(T.IMPORTO_11,0)-NVL(CQ.IMPORTO_44,0))*COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11,BC1.IMPORTO_11,0) + NVL(T.IMPORTO_44*CQ.IMPORTO_11,0)
       END AS ZLYE6    -- 账龄余额2-3年
      ,CASE
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B' AND ELEM <> '2910')
              THEN (CASE WHEN T.COD_CATEGORIA = '1REC' AND T.IMPORTO_16 <= 0  THEN NVL(T.IMPORTO_12,0)*0.5 ELSE 0 END)
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') ) THEN
              (CASE WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7+T.IMPORTO_6 THEN 0
                    WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22
                      THEN GREATEST((-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12)*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0),0)
                    ELSE (NVL(T.IMPORTO_12,0)-NVL(CQ.IMPORTO_45,0))*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0) + NVL(T.IMPORTO_45*CQ.IMPORTO_12,0)
               END)
            WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
              THEN (NVL(T.IMPORTO_12,0)+NVL(YF.IMPORTO_12,0)-NVL(CQ.IMPORTO_45,0))*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0) + NVL(T.IMPORTO_45*CQ.IMPORTO_12,0)
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN (NVL(T.IMPORTO_12,0)-NVL(CQ.IMPORTO_45,0)+NVL(JD.IMPORTO_12,0))*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0) + NVL(T.IMPORTO_45*CQ.IMPORTO_12,0)
            ELSE (NVL(T.IMPORTO_12,0)-NVL(CQ.IMPORTO_45,0))*COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12,BC1.IMPORTO_12,0) + NVL(T.IMPORTO_45*CQ.IMPORTO_12,0)
       END AS ZLYE7    -- 账龄余额3-4年
      ,CASE
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B' AND ELEM <> '2910')
              THEN (CASE WHEN T.COD_CATEGORIA = '1REC' AND T.IMPORTO_16 <= 0  THEN NVL(T.IMPORTO_22,0)*0.5 ELSE 0 END)
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') ) THEN
              (CASE WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7+T.IMPORTO_6 THEN 0
                    WHEN T.IMPORTO_35 >= T.IMPORTO_21
                      THEN GREATEST((-T.IMPORTO_35+T.IMPORTO_21+T.IMPORTO_22)*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0),0)
                    ELSE (NVL(T.IMPORTO_22,0)-NVL(CQ.IMPORTO_46,0))*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0) + NVL(T.IMPORTO_46*CQ.IMPORTO_22,0)
               END)
            WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
              THEN (NVL(T.IMPORTO_22,0)+NVL(YF.IMPORTO_22,0)-NVL(CQ.IMPORTO_46,0))*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0) + NVL(T.IMPORTO_46*CQ.IMPORTO_22,0)
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN (NVL(T.IMPORTO_22,0)-NVL(CQ.IMPORTO_46,0)+NVL(JD.IMPORTO_22,0))*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0) + NVL(T.IMPORTO_46*CQ.IMPORTO_22,0)
            ELSE (NVL(T.IMPORTO_22,0)-NVL(CQ.IMPORTO_46,0))*COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22,BC1.IMPORTO_22,0) + NVL(T.IMPORTO_46*CQ.IMPORTO_22,0)
       END AS ZLYE8    -- 账龄余额4-5年
      ,CASE
            WHEN T.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01'AND T.NODE = '2000B' AND ELEM <> '2910')
              THEN (CASE WHEN T.COD_CATEGORIA = '1REC' AND T.IMPORTO_16 <= 0  THEN NVL(T.IMPORTO_21,0)*1 ELSE 0 END)
            WHEN T.COD_AZIENDA LIKE '17%' OR T.COD_AZIENDA = '6240' OR (T.COD_AZIENDA IN ('1801','6430') AND T.COD_CONTO IN ('1122000000','1460000000') ) THEN
              (CASE WHEN T.IMPORTO_35 >= T.IMPORTO_21+T.IMPORTO_22+T.IMPORTO_12+T.IMPORTO_11+T.IMPORTO_10+T.IMPORTO_9+T.IMPORTO_8+T.IMPORTO_7+T.IMPORTO_6 THEN 0
                    WHEN T.IMPORTO_35 >= T.IMPORTO_21
                     THEN GREATEST((-T.IMPORTO_35+T.IMPORTO_21)*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0),0)
                    ELSE (NVL(T.IMPORTO_21,0)-NVL(CQ.IMPORTO_47,0))*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0) + NVL(T.IMPORTO_47*CQ.IMPORTO_21,0)
               END)
            WHEN T.COD_AZIENDA = '6008' AND T.COD_CONTO = '1122000000'
              THEN (NVL(T.IMPORTO_21,0)+NVL(YF.IMPORTO_21,0)-NVL(CQ.IMPORTO_47,0))*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0) + NVL(T.IMPORTO_47*CQ.IMPORTO_21,0)
            WHEN T.COD_AZIENDA IN ('6000','6000A','6000B','6000C','6600')
              THEN (NVL(T.IMPORTO_21,0)-NVL(CQ.IMPORTO_47,0)+NVL(JD.IMPORTO_21,0))*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0) + NVL(T.IMPORTO_47*CQ.IMPORTO_21,0)
            ELSE (NVL(T.IMPORTO_21,0)-NVL(CQ.IMPORTO_47,0))*COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21,BC1.IMPORTO_21,0) + NVL(T.IMPORTO_47*CQ.IMPORTO_21,0)
       END AS ZLYE9    -- 账龄余额5年以上
      ,NVL(T.IMPORTO_14*CQ.IMPORTO_6 ,0)  AS CQYE1                                                -- 超期余额1个月
      ,NVL(T.IMPORTO_15*CQ.IMPORTO_7 ,0)  AS CQYE2                                                -- 超期余额2-3个月
      ,NVL(T.IMPORTO_41*CQ.IMPORTO_8 ,0)  AS CQYE3                                                -- 超期余额4-6个月
      ,NVL(T.IMPORTO_42*CQ.IMPORTO_9 ,0)  AS CQYE4                                                -- 超期余额7-12个月
      ,NVL(T.IMPORTO_43*CQ.IMPORTO_10,0)  AS CQYE5                                                -- 超期余额1-2年
      ,NVL(T.IMPORTO_44*CQ.IMPORTO_11,0)  AS CQYE6                                                -- 超期余额2-3年
      ,NVL(T.IMPORTO_45*CQ.IMPORTO_12,0)  AS CQYE7                                                -- 超期余额3-4年
      ,NVL(T.IMPORTO_46*CQ.IMPORTO_22,0)  AS CQYE8                                                -- 超期余额4-5年
      ,NVL(T.IMPORTO_47*CQ.IMPORTO_21,0)  AS CQYE9                                                -- 超期余额5年以上
      ,COALESCE(HZ.IMPORTO_6,BC.IMPORTO_6  ,BC1.IMPORTO_6  ,0) AS HZBL1                           -- 坏账损失率1个月
      ,COALESCE(HZ.IMPORTO_7,BC.IMPORTO_7  ,BC1.IMPORTO_7  ,0) AS HZBL2                           -- 坏账损失率2-3个月
      ,COALESCE(HZ.IMPORTO_8,BC.IMPORTO_8  ,BC1.IMPORTO_8  ,0) AS HZBL3                           -- 坏账损失率4-6个月
      ,COALESCE(HZ.IMPORTO_9,BC.IMPORTO_9  ,BC1.IMPORTO_9  ,0) AS HZBL4                           -- 坏账损失率7-12个月
      ,COALESCE(HZ.IMPORTO_10,BC.IMPORTO_10 ,BC1.IMPORTO_10  ,0) AS HZBL5                         -- 坏账损失率1-2年
      ,COALESCE(HZ.IMPORTO_11,BC.IMPORTO_11 ,BC1.IMPORTO_11  ,0) AS HZBL6                         -- 坏账损失率2-3年
      ,COALESCE(HZ.IMPORTO_12,BC.IMPORTO_12 ,BC1.IMPORTO_12  ,0) AS HZBL7                         -- 坏账损失率3-4年
      ,COALESCE(HZ.IMPORTO_22,BC.IMPORTO_22 ,BC1.IMPORTO_22  ,0) AS HZBL8                         -- 坏账损失率4-5年
      ,COALESCE(HZ.IMPORTO_21,BC.IMPORTO_21 ,BC1.IMPORTO_21  ,0) AS HZBL9                         -- 坏账损失率5年以上
      ,NVL(CQ.IMPORTO_6  ,0) AS CQBL1                                                             -- 超期损失率1个月
      ,NVL(CQ.IMPORTO_7  ,0) AS CQBL2                                                             -- 超期损失率2-3个月
      ,NVL(CQ.IMPORTO_8  ,0) AS CQBL3                                                             -- 超期损失率4-6个月
      ,NVL(CQ.IMPORTO_9  ,0) AS CQBL4                                                             -- 超期损失率7-12个月
      ,NVL(CQ.IMPORTO_10 ,0) AS CQBL5                                                             -- 超期损失率1-2年
      ,NVL(CQ.IMPORTO_11 ,0) AS CQBL6                                                             -- 超期损失率2-3年
      ,NVL(CQ.IMPORTO_12 ,0) AS CQBL7                                                             -- 超期损失率3-4年
      ,NVL(CQ.IMPORTO_22 ,0) AS CQBL8                                                             -- 超期损失率4-5年
      ,NVL(CQ.IMPORTO_21 ,0) AS CQBL9                                                             -- 超期损失率5年以上
      ,NVL(M.COD_AZIENDA,T.COD_AZIENDA) AS BUKRS_HBRZ                                             -- 合并入帐公司
      ,NVL(T.IMPORTO_34,0)     AS SYHZYE                                                          -- 上月坏账余额
  FROM TGK_GB_HISENSE.FORM_DATI T
LEFT JOIN (SELECT
                 T1.COD_AZIENDA,T1.COD_CONTO,T1.COD_CATEGORIA,T1.TESTO_14
                ,NVL(T1.IMPORTO_6,0) IMPORTO_6 ,NVL(T1.IMPORTO_7,0) IMPORTO_7,NVL(T1.IMPORTO_8,0) IMPORTO_8
                ,NVL(T1.IMPORTO_9,0) IMPORTO_9 ,NVL(T1.IMPORTO_10,0) IMPORTO_10,NVL(T1.IMPORTO_11,0) IMPORTO_11
                ,NVL(T1.IMPORTO_12,0) IMPORTO_12,NVL(T1.IMPORTO_22,0) IMPORTO_22,NVL(T1.IMPORTO_21,0) IMPORTO_21
           FROM TGK_GB_HISENSE.FORM_DATI T1
          WHERE T1.COD_PROSPETTO = 'ZS_AR0001_IPT01'
            AND T1.COD_SCENARIO  = '2013ACT'
            AND T1.COD_PERIODO   = '01'
            AND T1.COD_CONTO     IN ('1122000000','122101F','1460000000','1531000000')
            AND T1.COD_CATEGORIA IN ('$AMOUNT','1ADJ','1REC')
) HZ                                                   -- 正常损失率:特殊客户（因为不计提时用户不录入数据出现NULL值，影响判断）
    ON CASE WHEN V_IS_SX > 0 THEN '2000' WHEN V_IS_KT > 0 THEN '6800' WHEN V_IS_BX > 0 THEN '6700' ELSE T.COD_AZIENDA END  = HZ.COD_AZIENDA               -- ALTER BT 20240702 XIAOYACHAO.EX
   AND T.COD_CONTO    = HZ.COD_CONTO
   AND T.TESTO_14  LIKE HZ.TESTO_14
   AND T.COD_CATEGORIA = HZ.COD_CATEGORIA
LEFT JOIN (SELECT
                 T1.COD_AZIENDA,T1.COD_CONTO,T1.COD_CATEGORIA,T1.TESTO_14,T1.TESTO_2,T1.TESTO_3
                ,NVL(T1.IMPORTO_6,0) IMPORTO_6 ,NVL(T1.IMPORTO_7,0) IMPORTO_7,NVL(T1.IMPORTO_8,0) IMPORTO_8
                ,NVL(T1.IMPORTO_9,0) IMPORTO_9 ,NVL(T1.IMPORTO_10,0) IMPORTO_10,NVL(T1.IMPORTO_11,0) IMPORTO_11
                ,NVL(T1.IMPORTO_12,0) IMPORTO_12,NVL(T1.IMPORTO_22,0) IMPORTO_22,NVL(T1.IMPORTO_21,0) IMPORTO_21
           FROM TGK_GB_HISENSE.FORM_DATI T1
          WHERE T1.COD_PROSPETTO = 'ZS_AR0001_IPT01'
            AND T1.COD_SCENARIO  = '2013ACT'
            AND T1.COD_PERIODO   = '01'
            AND T1.COD_CONTO     IN ('1122000000','122101F','1460000000','1531000000')
            AND T1.COD_CATEGORIA IN ('$AMOUNT','1ADJ','1REC')
) BC                                                   -- 正常损失率:特殊性质（因为不计提时用户不录入数据出现NULL值，影响判断）
    ON CASE WHEN V_IS_SX > 0 THEN '2000' WHEN V_IS_KT > 0 THEN '6800' WHEN V_IS_BX > 0 THEN '6700' ELSE T.COD_AZIENDA END  = BC.COD_AZIENDA               -- ALTER BT 20240702 XIAOYACHAO.EX
   AND T.COD_CONTO    = BC.COD_CONTO
   AND T.COD_CATEGORIA = BC.COD_CATEGORIA
   AND NVL(T.TESTO_2,'NULL') = NVL(BC.TESTO_2,'NULL')
   AND BC.TESTO_14 IS NULL
   AND BC.TESTO_2 IS NOT NULL
LEFT JOIN TGK_GB_HISENSE.FORM_DATI BC1                -- 正常损失率:通用
    ON CASE WHEN V_IS_SX > 0 THEN '2000' WHEN V_IS_KT > 0 THEN '6800' WHEN V_IS_BX > 0 THEN '6700' ELSE T.COD_AZIENDA END   = BC1.COD_AZIENDA             -- ALTER BT 20240702 XIAOYACHAO.EX
   AND T.COD_CONTO     = BC1.COD_CONTO
   AND T.COD_CATEGORIA = BC1.COD_CATEGORIA
   AND BC1.COD_PROSPETTO = 'ZS_AR0001_IPT01'
   AND BC1.COD_SCENARIO = '2013ACT'
   AND BC1.COD_PERIODO  = '01'
   AND BC1.COD_CONTO     IN ('1122000000','122101F','1460000000','1531000000')
   AND BC1.COD_CATEGORIA IN ('$AMOUNT','1ADJ','1REC')
   AND BC1.TESTO_14 IS NULL
   AND BC1.TESTO_2 IS NULL
LEFT JOIN TGK_GB_HISENSE.FORM_DATI CQ                -- 超期损失率
    ON T.COD_AZIENDA    = CQ.COD_AZIENDA
   AND T.COD_CONTO      = CQ.COD_CONTO
   --AND NVL(T.TESTO_14,'NULL')= NVL(CQ.TESTO_14,'NULL')
   AND CQ.COD_PROSPETTO = 'ZS_AR0001_IPT01'
   AND CQ.COD_SCENARIO  = '2013ACT'
   AND CQ.COD_PERIODO   = '01'
   AND CQ.COD_CONTO     IN ('1122000000')
   AND CQ.COD_CATEGORIA IN ('1ZCF')
LEFT JOIN  TGK_GB_HISENSE.FORM_DATI M                 -- 合并入账公司
   ON T.COD_AZIENDA   = M.TESTO_14
  AND M.COD_PROSPETTO = 'ZS_AR0001_IPT01'
  AND M.COD_CATEGORIA = '1ZCK'
  AND M.COD_SCENARIO  = '2013ACT'
  AND M.COD_PERIODO   = '01'
LEFT JOIN TGK_GB_HISENSE.FORM_DATI P                  -- 默认产品线
   ON P.COD_AZIENDA   = NVL(M.COD_AZIENDA,T.COD_AZIENDA)
  AND P.COD_PROSPETTO = 'ZS_AR0001_IPT01'
  AND P.COD_CATEGORIA = 'XT01'
  AND P.COD_SCENARIO  = '2013ACT'
  AND P.COD_PERIODO   = '01'
LEFT JOIN TGK_GB_HISENSE.FORM_DATI YS                  -- 6008应收-应付映射关系
   ON YS.COD_AZIENDA   = NVL(M.COD_AZIENDA,T.COD_AZIENDA)
  AND YS.TESTO_17 = T.TESTO_14
  AND YS.COD_PROSPETTO = 'ZS_AR0001_IPT01'
  AND YS.COD_CATEGORIA = 'XT05'
  AND YS.COD_SCENARIO  = '2013ACT'
  AND YS.COD_PERIODO   = '01'
LEFT JOIN TGK_GB_HISENSE.FORM_DATI YF                  -- 6008应付数
   ON YF.COD_AZIENDA   = T.COD_AZIENDA
  AND YS.TESTO_18 = YF.TESTO_5
  AND YF.COD_PROSPETTO = 'ZS_AP0001_IPT01'
  AND YF.COD_CATEGORIA IN ('$AMOUNT','1ADJ','1REC')
  AND YF.COD_CONTO = '2202000000'
  AND YF.COD_SCENARIO  = V_SCENARIO
  AND YF.COD_PERIODO   = V_PERIODO
LEFT JOIN                                               -- 家电公司负数处理 ALTER BY 20240626
(
  SELECT T.*,'6000A' AS BUKRS
    FROM TGK_GB_HISENSE.FORM_DATI T
   WHERE T.COD_PROSPETTO = 'ZS_AR0001_IPT01'
     AND T.COD_SCENARIO = V_SCENARIO
     AND T.COD_PERIODO = V_PERIODO
     AND T.COD_CATEGORIA IN ('$AMOUNT', '1ADJ', '1REC')
     AND T.COD_AZIENDA = '6600'
     AND T.COD_CONTO IN ('1122000000')
     AND T.TESTO_14 IN ('2002514','2000624','2001340')
  UNION ALL
  SELECT T.*,'6000C' AS BUKRS
    FROM TGK_GB_HISENSE.FORM_DATI T
   WHERE T.COD_PROSPETTO = 'ZS_AR0001_IPT01'
     AND T.COD_SCENARIO = V_SCENARIO
     AND T.COD_PERIODO = V_PERIODO
     AND T.COD_CATEGORIA IN ('$AMOUNT', '1ADJ', '1REC')
     AND T.COD_AZIENDA = '6000'
     AND T.COD_CONTO IN ('122101F')
     AND T.TESTO_14 IN ('5001562')
  ) JD
   ON T.COD_AZIENDA = JD.BUKRS
  AND T.COD_CONTO = JD.COD_CONTO
  AND T.TESTO_14 = JD.TESTO_14
LEFT JOIN
 (                                                                         -- 1730,6210 煤改电坏账特殊计算   20240724
  SELECT M.COD_AZIENDA,M.TESTO_18,M.TESTO_12,M.TESTO_2,M.TESTO_28,M.TESTO_29,SUM(M.IMPORTO_20) IMPORTO_20
    FROM TGK_GB_HISENSE.FORM_DATI M
   WHERE M.COD_PROSPETTO = 'ZS_AR0002_IPT01'
     AND M.COD_CONTO = 'SZK5160'
     AND M.COD_SCENARIO = V_SCENARIO
     AND M.COD_PERIODO  = V_PERIODO
    GROUP BY M.COD_AZIENDA,M.TESTO_18,M.TESTO_12,M.TESTO_2,M.TESTO_28,M.TESTO_29
 ) MGD
    ON T.COD_AZIENDA = MGD.COD_AZIENDA
   AND T.COD_CONTO   = MGD.TESTO_18
   AND T.TESTO_14    = LTRIM(MGD.TESTO_12,'0')
   AND NVL(T.TESTO_2,'NULL')     = NVL(MGD.TESTO_2,'NULL')                                             /*ALTER BY 20250504 XIAOYAHAO.EX 增加一二三级性质匹配*/
   AND NVL(T.TESTO_28,'NULL')    = NVL(MGD.TESTO_28,'NULL')
   AND NVL(T.TESTO_29,'NULL')    = NVL(MGD.TESTO_29,'NULL')
LEFT JOIN ZTAB_AG_TF_INSURE TB                                             -- 投保信息表 ：未覆盖比例
  ON T.COD_AZIENDA = TB.BUKRS
 AND T.COD_CONTO = TB.HKONT
 AND T.TESTO_14 = TB.CVCODE
 AND TB.YEARMONTH = V_YEARMONTH
 AND TB.KAISHRQ <= V_YEARMONTH
 AND TB.JIESHRQ > V_YEARMONTH
 WHERE T.COD_PROSPETTO  = 'ZS_AR0001_IPT01'
   AND T.COD_SCENARIO   = V_SCENARIO
   AND T.COD_PERIODO    = V_PERIODO
   AND T.COD_CATEGORIA  IN ('$AMOUNT','1ADJ','1REC')
   AND T.COD_CONTO      IN ('1122000000','122101F','1460000000','1531000000')   -- ALTER BY 20240809 10:00 XIAOYACHAO.EX 增加长期应收科目
   --AND T.COD_AZIENDA    = V_AZIENDA
   AND INSTR(V_AZIENDA,T.COD_AZIENDA) > 0
   AND T.COD_CONTO <> CASE WHEN INSTR(V_AZI_LIST,T.COD_AZIENDA) > 0 THEN '1122000000' ELSE 'NULL' END /*营销公司的应收账款从各个公司的营销表单中取值，这里要去掉避免冲突*/
)

SELECT
    H.OID_FORM_DATI            --  ID
  , H.YEARMONTH                --  年月
  , H.BUKRS                    --  公司
  , H.HKONT                    --  科目
  , H.CVCODE                   --  客户编码
  , H.CVNAME                   --  客户名称
  , H.PRCTR                    --  产品线
  , H.PRCTR_DESC               --  产品线名称
  , H.YWFW                     --  业务范围
  , H.YWFWMC                   --  业务范围名称
  , H.XZ                       --  性质
  , H.BZ                       --  币种
  , H.ZLJE1                    --  账龄金额1个月
  , H.ZLJE2                    --  账龄金额2-3个月
  , H.ZLJE3                    --  账龄金额4-6个月
  , H.ZLJE4                    --  账龄金额7-12个月
  , H.ZLJE5                    --  账龄金额1-2年
  , H.ZLJE6                    --  账龄金额2-3年
  , H.ZLJE7                    --  账龄金额3-4年
  , H.ZLJE8                    --  账龄金额4-5年
  , H.ZLJE9                    --  账龄金额5年以上
  , H.CQJE                     --  当月超期金额
  , H.CQJE1                    --  超期金额1个月
  , H.CQJE2                    --  超期金额2-3个月
  , H.CQJE3                    --  超期金额4-6个月
  , H.CQJE4                    --  超期金额7-12个月
  , H.CQJE5                    --  超期金额1-2年
  , H.CQJE6                    --  超期金额2-3年
  , H.CQJE7                    --  超期金额3-4年
  , H.CQJE8                    --  超期金额4-5年
  , H.CQJE9                    --  超期金额5年以上
  , ROUND(CASE WHEN H.BUKRS IN (SELECT  ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA_TV T WHERE T.COD_SCENARIO = V_SCENARIO AND T.COD_PERIODO = V_PERIODO AND T.HIE = '30' AND T.NODE = '1600A')
                    AND LENGTH(RD.TESTO_48) > 0 AND (H.ZLJE1+H.ZLJE2+H.ZLJE3+H.ZLJE4+H.ZLJE5+H.ZLJE6+H.ZLJE7+H.ZLJE8+H.ZLJE9) <> 0
                 THEN NVL(RD.IMPORTO_19,0)
               WHEN LENGTH(RD.TESTO_48) > 0
                 THEN NVL(RD.IMPORTO_19,0)
               ELSE H.HZYE END,2)  --  坏账余额:重新计算  /*ALTER BY 20260204 XIAOYACHAO.EX 因为交易对手转为投资B拆分数据导致个别认定重复,增加适用范围*/
  , H.CQHZYE                   --  超期坏账余额：重新计算
  , H.BYYE                     --  本月账龄余额
  , H.ZLYE1                    --  账龄余额1个月
  , H.ZLYE2                    --  账龄余额2-3个月
  , H.ZLYE3                    --  账龄余额4-6个月
  , H.ZLYE4                    --  账龄余额7-12个月
  , H.ZLYE5                    --  账龄余额1-2年
  , H.ZLYE6                    --  账龄余额2-3年
  , H.ZLYE7                    --  账龄余额3-4年
  , H.ZLYE8                    --  账龄余额4-5年
  , H.ZLYE9                    --  账龄余额5年以上
  , H.CQYE1                    --  超期余额1个月
  , H.CQYE2                    --  超期余额2-3个月
  , H.CQYE3                    --  超期余额4-6个月
  , H.CQYE4                    --  超期余额7-12个月
  , H.CQYE5                    --  超期余额1-2年
  , H.CQYE6                    --  超期余额2-3年
  , H.CQYE7                    --  超期余额3-4年
  , H.CQYE8                    --  超期余额4-5年
  , H.CQYE9                    --  超期余额5年以上
  , H.HZBL1                    --  正常账龄损失率1个月
  , H.HZBL2                    --  正常账龄损失率2-3个月
  , H.HZBL3                    --  正常账龄损失率4-6个月
  , H.HZBL4                    --  正常账龄损失率7-12个月
  , H.HZBL5                    --  正常账龄损失率1-2年
  , H.HZBL6                    --  正常账龄损失率2-3年
  , H.HZBL7                    --  正常账龄损失率3-4年
  , H.HZBL8                    --  正常账龄损失率4-5年
  , H.HZBL9                    --  正常账龄损失率5年以上
  , H.CQBL1                    --  超期账龄损失率1个月
  , H.CQBL2                    --  超期账龄损失率2-3个月
  , H.CQBL3                    --  超期账龄损失率4-6个月
  , H.CQBL4                    --  超期账龄损失率7-12个月
  , H.CQBL5                    --  超期账龄损失率1-2年
  , H.CQBL6                    --  超期账龄损失率2-3年
  , H.CQBL7                    --  超期账龄损失率3-4年
  , H.CQBL8                    --  超期账龄损失率4-5年
  , H.CQBL9                    --  超期账龄损失率5年以上
  , NVL(H.HZYE,0) - NVL(H.SYHZYE,0)                                   --  当月计提金额
  , CASE WHEN H.BUKRS IN (SELECT  ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA_TV T WHERE T.COD_SCENARIO = V_SCENARIO AND T.COD_PERIODO = V_PERIODO AND T.HIE = '30' AND T.NODE = '1600A')
                  AND LENGTH(RD.TESTO_48) > 0 AND (H.ZLJE1+H.ZLJE2+H.ZLJE3+H.ZLJE4+H.ZLJE5+H.ZLJE6+H.ZLJE7+H.ZLJE8+H.ZLJE9) <> 0
           THEN 'Y'
          WHEN LENGTH(RD.TESTO_48) > 0  THEN 'Y'
          ELSE 'N' END IS_GBRD   --  是否个别认定 /*ALTER BY 20260204 XIAOYACHAO.EX 因为交易对手转为投资B拆分数据导致个别认定重复*/
  , H.SYHZYE                                                          --  上月坏账余额
  , NVL(H1.ZLYE1,0)                                                   --  上月计提坏账1个月
  , NVL(H1.ZLYE2,0)                                                   --  上月计提坏账2-3个月
  , NVL(H1.ZLYE3,0)                                                   --  上月计提坏账4-6个月
  , NVL(H1.ZLYE4,0)                                                   --  上月计提坏账7-12个月
  , NVL(H1.ZLYE5,0)                                                   --  上月计提坏账1-2年
  , NVL(H1.ZLYE6,0)                                                   --  上月计提坏账2-3年
  , NVL(H1.ZLYE7,0)                                                   --  上月计提坏账3-4年
  , NVL(H1.ZLYE8,0)                                                   --  上月计提坏账4-5年
  , NVL(H1.ZLYE9,0)                                                   --  上月计提坏账5年以上
  , SYSDATE                                                           --  更新时间
  , V_USER                                                            --  更新用户
  , H.BUKRS_HBRZ                                                      --  合并入帐公司
  FROM HZZB H
LEFT JOIN TGK_GB_HISENSE.FORM_DATI RD    /* 个别认定 */
   ON H.BUKRS  = RD.COD_AZIENDA
  AND H.HKONT  = RD.COD_CONTO
  AND H.CVCODE = RD.TESTO_14
  AND NVL(H.PRCTR,'NULL') = NVL(RD.TESTO_21,'NULL')
  AND NVL(H.YWFW,'NULL')  = NVL(RD.TESTO_23,'NULL')
  AND NVL(H.XZ,'NULL')    = NVL(RD.TESTO_2,'NULL')
  AND RD.COD_PROSPETTO    = 'ZS_AR0001_IPT01'
  AND RD.COD_SCENARIO     = V_SCENARIO
  AND RD.COD_PERIODO      = V_PERIODO
  AND RD.COD_CONTO        IN ('1122000000','122101F','1460000000','1531000000')
  AND RD.COD_CATEGORIA    = '1SPA'
LEFT JOIN
( SELECT BUKRS, HKONT,CVCODE,PRCTR,YWFW,XZ
         ,SUM(ZLYE1) ZLYE1,SUM(ZLYE2) ZLYE2,SUM(ZLYE3) ZLYE3
         ,SUM(ZLYE4) ZLYE4,SUM(ZLYE5) ZLYE5,SUM(ZLYE6) ZLYE6,SUM(ZLYE7) ZLYE7
         ,SUM(ZLYE8) ZLYE8,SUM(ZLYE9) ZLYE9
    FROM ZTAB_AG_TF_OC
  WHERE YEARMONTH = V_LYEARMONTH
  GROUP BY BUKRS, HKONT,CVCODE,PRCTR,YWFW,XZ
  ) H1                                /* 上月各个账龄段计提余额 */
   ON H.BUKRS  = H1.BUKRS
  AND H.HKONT  = H1.HKONT
  AND H.CVCODE = H1.CVCODE
  AND H.PRCTR  = H1.PRCTR
  AND NVL(H.XZ,'NULL') = NVL(H1.XZ,'NULL')
  AND NVL(H.YWFW,'NULL')= NVL(H1.YWFW,'NULL')
;


INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_HZOC', V_SCENARIO, V_PERIODO, '1.2 往来账龄坏账计提结果表更新完成', SYSDATE, V_USER,V_AZIENDA);
COMMIT;

/******************* 赛维更新映射中台产品线  ***************************/

IF V_AZIENDA LIKE '15%' AND V_AZIENDA <> '1592' THEN

UPDATE ZTAB_AG_TF_OC T  SET T.PRCTR = (
  SELECT TESTO_21 FROM TGK_GB_HISENSE.FORM_DATI T1
   WHERE T1.COD_PROSPETTO = 'ZS_AR0001_IPT01'
     AND T1.COD_SCENARIO = '2013ACT'
     AND T1.COD_PERIODO = '01'
     AND T1.COD_CATEGORIA = 'XT03'
     AND T1.COD_CONTO IN ('1122000000','122101F','1460000000','1531000000')
     AND T1.COD_AZIENDA = T.BUKRS
     AND T1.COD_CONTO = T.HKONT
     AND T1.TESTO_14 = T.CVCODE
 )
 WHERE T.YEARMONTH = V_YEARMONTH
  -- AND T.BUKRS = V_AZIENDA;
   AND INSTR(V_AZIENDA,T.BUKRS) > 0;

INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_HZOC', V_SCENARIO, V_PERIODO, '2.1 赛维产品线个更新完成',SYSDATE, V_USER,V_AZIENDA);
COMMIT;

END IF;

/******************* 非视像科技坏账余额小于0处理 ***************************/

UPDATE ZTAB_AG_TF_OC T SET T.HZYE = GREATEST(T.HZYE,0)
WHERE --T.BUKRS = V_AZIENDA
      INSTR(V_AZIENDA,T.BUKRS) > 0
  AND T.YEARMONTH = V_YEARMONTH
  AND T.BUKRS NOT IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01' AND T.NODE = '2000B')
  ;
INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_HZOC', V_SCENARIO, V_PERIODO, '2.2 非视像公司坏账小于0处理完成',SYSDATE, V_USER,V_AZIENDA);
COMMIT;
/******************** 核销金额更新 *****************************************/
-- ALTER BY 20240806 18:19 XIAOYACHAO.EX
MERGE INTO (SELECT * FROM ZTAB_AG_TF_OC T WHERE T.YEARMONTH = V_YEARMONTH AND INSTR(V_AZIENDA,T.BUKRS) > 0) A
USING(
SELECT
    o.FNumber AS bukrs, -- 公司
    p.fnumber AS yearmonth, -- 期间
    case when a.fnumber LIKE '1122%' OR a.fnumber LIKE '1131%' then '1122000000'
         when a.fnumber LIKE '1221%' OR a.fnumber LIKE '1133%' then '122101F'
         when a.fnumber = '1460000000' then '1460000000'
         when a.fnumber LIKE '1531%' then '1531000000' END AS hkont, -- 科目编码
    --a.fname AS accountName, -- 科目名称
    ltrim(pf.fnumber,'0') AS prctr, -- 利润中心编码
    -- pfl.fname AS ktext, -- 利润中心名称
    biz.fnumber AS ywfw, -- 业务范围编码
    --bizl.fname AS ywffwmc, -- 业务范围名称
    SUBSTR(cus.fnumber,1,INSTR(cus.fnumber,'(')-1) AS cvcode, -- 客户编码
    cus.fname AS cvname, -- 客户名称
   -- sum(s.fk_hifi_lossmoneys) AS je -- 金额
    sum(s.FK_HIFI_LOCAL_LOSSMONEYS) as je             /* ALTER BY 20250903 XIAOYACHAO.EX 取本位币*/
FROM
    ods.ODSFMFI_TK_HIFI_BADDEBTVERIFY@FMSLK v
LEFT JOIN
    ods.ODSFMTSS_T_ORG_ORG@FMSLK o ON o.fid = v.fk_hifi_accountorg
LEFT JOIN
    ods.ODSFMFI_T_BD_PERIOD@FMSLK p ON p.fid = v.fk_hifi_accountdate
JOIN
    ods.ODSFMFI_TK_HIFI_BADDEBTVERIFYSUB@FMSLK s ON s.fid = v.fid
LEFT JOIN
    ods.ODSFMFI_T_BD_ACCOUNT@FMSLK a ON a.fid = s.fk_hifi_subjects
LEFT JOIN
    ods.ODSFMFI_TK_HIFI_CAS_PROFITCENTER@FMSLK pf ON pf.fid = s.fk_hifi_profitcenter
LEFT JOIN
    ods.ODSFMFI_TK_HIFI_CAS_PROFITCENTER_L@FMSLK pfl ON pfl.fid = pf.fid AND pfl.Flocaleid = 'zh_CN'
LEFT JOIN
    ods.ODSFMFI_TK_HIFI_CAS_BIZRANGE@FMSLK biz ON biz.fid = s.fk_hifi_businessscope
LEFT JOIN
    ods.ODSFMFI_TK_HIFI_CAS_BIZRANGE_L@FMSLK bizl ON bizl.fid = biz.fid AND bizl.Flocaleid = 'zh_CN'
LEFT JOIN
    ods.ODSFMTSS_T_BD_CUSTOMER@FMSLK cus ON cus.fid = s.fk_hifi_customer
LEFT JOIN
    ods.ODSFMSECD_TK_HIFI_ORGS_REF@FMSLK R ON r.fk_hifi_org_id  = o.fid
WHERE
    p.fnumber = V_YEARMONTH
    AND INSTR(V_AZIENDA,O.FNumber) > 0
    and v.fbillstatus = 'C'
    AND v.fk_hifi_sapvouchernum IS NOT NULL
    AND (
             (r.fk_hifi_sap_version = 'SAP600' AND (a.fnumber LIKE '1122%' OR a.fnumber LIKE '1221%' OR a.fnumber LIKE '1531%' OR a.fnumber = '1460000000'))
          OR (r.fk_hifi_sap_version = 'SAP700' AND (a.fnumber LIKE '1122%' OR a.fnumber LIKE '1221%' OR a.fnumber = '1460000000'))
          OR (r.fk_hifi_sap_version = 'SAP900' AND (a.fnumber LIKE '1131%' OR a.fnumber LIKE '1133%' OR a.fnumber = '1460000000'))
          OR (r.fk_hifi_sap_version = 'SAP800B'AND (a.fnumber LIKE '1122%' OR a.fnumber LIKE '1221%' OR a.fnumber = '1460000000'))
          OR (r.fk_hifi_sap_version = 'SAP800' AND (a.fnumber LIKE '1131%' OR a.fnumber LIKE '1133%' OR a.fnumber = '1460000000'))
          OR (r.fk_hifi_sap_version = 'SAP810' AND (a.fnumber LIKE '1122%' OR a.fnumber LIKE '1221%'))
        ) /*科目转换汇总 alter by 20240828 08:56 xiaoyachao.ex*/
  group by  o.FNumber,p.fnumber,case when a.fnumber LIKE '1122%' OR a.fnumber LIKE '1131%' then '1122000000'
                                     when a.fnumber LIKE '1221%' OR a.fnumber LIKE '1133%' then '122101F'
                                     when a.fnumber = '1460000000' then '1460000000'
                                     when a.fnumber LIKE '1531%' then '1531000000' END,pf.fnumber,biz.fnumber,cus.fnumber,cus.fname
) B
ON (A.BUKRS = B.BUKRS AND A.HKONT = B.HKONT AND NVL(A.PRCTR,'|') = NVL(B.PRCTR,'|') AND NVL(A.YWFW,'|') = NVL(B.YWFW,'|') AND A.CVCODE = B.CVCODE)
WHEN MATCHED THEN UPDATE SET A.HXJE = B.JE;
commit;


/******************* 更新往来账龄表  ***************************/
/*ALTER BT 20240611 XIAOYACHAO.EX 增加坏账计提方法*/
MERGE INTO (SELECT * FROM FORM_DATI T1
             WHERE T1.COD_PROSPETTO = 'ZS_AR0001_IPT01'
               AND T1.COD_SCENARIO = V_SCENARIO
               AND T1.COD_PERIODO = V_PERIODO
               --AND T1.COD_AZIENDA = V_AZIENDA
               AND INSTR(V_AZIENDA,T1.COD_AZIENDA) > 0
               AND T1.COD_CONTO IN ('1122000000','122101F','1460000000','1531000000')
               AND T1.COD_CATEGORIA IN ('$AMOUNT','1ADJ','1REC')
            ) C
USING (SELECT T.*,CASE WHEN T.IS_GBRD = 'Y' THEN T.HZYE ELSE 0 END GBRD FROM ZTAB_AG_TF_OC T WHERE T.YEARMONTH = V_YEARMONTH AND INSTR(V_AZIENDA,T.BUKRS) > 0 /*T.BUKRS = V_AZIENDA*/) Z
--ON (Z.BUKRS = C.COD_AZIENDA AND Z.CVCODE = C.TESTO_14 AND NVL(Z.PRCTR,'NULL') = NVL(C.TESTO_21,'NULL') AND NVL(Z.YWFW,'NULL') = NVL(C.TESTO_23,'NULL'))
ON (Z.OID = C.OID_FORM_DATI)
WHEN MATCHED THEN UPDATE SET
  C.IMPORTO_27 = Z.HZYE,
  C.IMPORTO_19 = Z.HZYE,
  C.IMPORTO_48 = Z.GBRD,
  C.IMPORTO_49 = nvl(Z.HXJE,0),
  C.TESTO_35   = CASE WHEN Z.IS_GBRD = 'Y' THEN '按单项计提'
                      WHEN C.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01' AND T.NODE = '2910')
                        THEN (CASE WHEN C.COD_AZI_CTP IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01' AND T.NODE = '2000B') THEN '视像合并组合'
                                   WHEN C.COD_AZI_CTP IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01' AND T.NODE = '1000') THEN '关联方组合'
                                   ELSE 'TVS组合'
                              END)
                      WHEN C.COD_AZIENDA IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01' AND T.NODE = '2000')
                        THEN (CASE WHEN C.COD_AZI_CTP IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01' AND T.NODE = '2000B') THEN '视像合并组合'
                                   WHEN C.COD_AZI_CTP IN (SELECT ELEM FROM TGK_GB_HISENSE.V_REF_AZIENDA T WHERE T.HIE = '01' AND T.NODE = '1000') THEN '关联方组合'
                                   ELSE '账龄组合'
                              END)
                  END

;

INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_HZOC', V_SCENARIO, V_PERIODO, '2.3 坏账计算结果更新往来账龄表完成', SYSDATE, V_USER,V_AZIENDA);
COMMIT;

ELSE
  INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_HZOC', V_SCENARIO, V_PERIODO, '0 账龄表已锁定！无法更新', SYSDATE, V_USER,V_AZIENDA);
  COMMIT;
END IF;

END;