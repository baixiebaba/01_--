
CREATE OR REPLACE PROCEDURE TGK_GB_HISENSE.CPM_SP_AG_INSURE(V_SCENARIO IN VARCHAR2,
                                             V_PERIODO  IN VARCHAR2,
                                             V_AZIENDA  IN VARCHAR2,
                                             V_USER     IN VARCHAR2) AS
/*****************************************************************

最后更新时间：20240930 15:25
    用途：用于投保部分应收账款的未覆盖比例的计算
版本信息：

ALTER BY 20240930 14:54 XIAOYACHAO.EX ：转换本位币
ALTER BY 20240829 14:13 XIAOYACHAO.EX ：未覆盖公式优化
V1.初始版本创建   CREATE BY XIAOYACHAO.EX AT 20240822

未覆盖比例计算逻辑：当投保金额 >  相对应的账龄余额时 ：（相对应的账龄余额 * (1-赔付金额) + 免赔额）/相对应的账龄余额
                    当投保金额 <= 相对应的账龄余额时 ：1-（投保金额-免赔额）/相对应的账龄余额
                    备注：明细维度到客商，账龄余额按照客商汇总进行计算
********************************************************************/
V_YEARMONTH   VARCHAR2(20);   -- 当月
--V_LYEARMONTH  VARCHAR2(20);   -- 上月
V_LOCK        NUMBER;         -- 锁状态
BEGIN
  /*获取当月和上月*/
  V_YEARMONTH :=SUBSTR(V_SCENARIO,1,4)||V_PERIODO;
  --V_LYEARMONTH:=TO_CHAR(ADD_MONTHS(TO_DATE(SUBSTR(V_SCENARIO,1,4)||V_PERIODO,'YYYYMM'),-1),'YYYYMM');

  /*获取账龄表锁定状态*/
  SELECT NVL(SUM(T.IMPORTO),0)
    INTO V_LOCK
    FROM TGK_GB_HISENSE.DATI_SALDI_LORDI T
   WHERE T.COD_SCENARIO = V_SCENARIO
     AND T.COD_PERIODO = V_PERIODO
     AND INSTR(V_AZIENDA,T.COD_AZIENDA) > 0
     AND T.COD_CONTO = 'SLK0105';

IF V_LOCK = 0 THEN
 --记录日志
INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_INSURE', V_SCENARIO, V_PERIODO, '0 SATRT', SYSDATE, V_USER,V_AZIENDA);
COMMIT;

/******************* 1.1 投保信息表数据删除 ***************************/

DELETE FROM ZTAB_AG_TF_INSURE T WHERE T.YEARMONTH = V_YEARMONTH AND T.BUKRS = V_AZIENDA ;

INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_INSURE', V_SCENARIO, V_PERIODO, '1.1 坏账计提结果表数据删除完成', SYSDATE, V_USER,V_AZIENDA);
COMMIT;

/******************* 1.2 投保信息表表数据插入 ***************************/

INSERT INTO ZTAB_AG_TF_INSURE (
    YEARMONTH   ,-- 年月
    BUKRS       ,-- 公司
    HKONT       ,-- 科目
    CVCODE      ,-- 客商编码
    CVNAME      ,-- 客商名称
    BZ          ,-- 币种
    TOUBAOJE    ,-- 投保金额
    BZTS        ,-- 保障天数
    PEIFBL      ,-- 赔付比例
    MPEIE       ,-- 免赔额
    KAISHRQ     ,-- 开始日期
    JIESHRQ     ,-- 结束日期
    BYHL        ,-- 本月期末汇率
    ZHYE1       ,-- 账龄余额1个月以内
    ZHYE2       ,-- 账龄余额2-3个月
    ZHYE3       ,-- 账龄余额4-6个月
    ZHYE4       ,-- 账龄余额7-12个月
    WFUGBL      ,-- 未覆盖比例
    SRC         ,-- 来源
    USERUPD     ,-- 更新用户
    DATEUPD      -- 更新时间
)
SELECT
    V_YEARMONTH         AS YEARMONTH,       -- 年月
    T.COD_AZIENDA       AS BUKRS,           -- 公司
    '1122000000'        AS HKONT,           -- 科目
    T.TESTO_14          AS CVCODE,          -- 客商编码
    T.TESTO_15          AS CVNAME,          -- 客商名称
    T.TESTO_3           AS BZ,              -- 币种
    T.IMPORTO_1*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE         AS TOUBAOJE,        -- 投保金额
    T.IMPORTO_4         AS BZTS,            -- 保障天数
    T.IMPORTO_2         AS PEIFBL,          -- 赔付比例
    T.IMPORTO_3*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE         AS MPEIE,           -- 免赔额
    T.TESTO_11          AS KAISHRQ,         -- 开始日期
    T.TESTO_12          AS JIESHRQ,         -- 结束日期
    1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE  AS BYHL,            -- 本月期末汇率
    T1.ZHYE1            AS ZLYE1,           -- 账龄余额1个月以内
    T1.ZHYE2            AS ZLYE2,           -- 账龄余额2-3个月
    T1.ZHYE3            AS ZLYE3,           -- 账龄余额4-6个月
    T1.ZHYE4            AS ZLYE4,           -- 账龄余额7-12个月
    (CASE WHEN T.IMPORTO_4 = 30
           THEN CASE WHEN (T.IMPORTO_1*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE) > T1.ZHYE1
                       THEN (CASE WHEN (T1.ZHYE1) = 0 THEN  0 ELSE ( (T1.ZHYE1) * (1-T.IMPORTO_2) + T.IMPORTO_3 * 1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE) / (T1.ZHYE1) END)
                       ELSE 1 - (CASE WHEN (T1.ZHYE1) = 0 THEN 0 ELSE (T.IMPORTO_1 - T.IMPORTO_3)*T.IMPORTO_2*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE / (T1.ZHYE1) END)
                END
         WHEN T.IMPORTO_4 BETWEEN 60 AND 90
           THEN CASE WHEN (T.IMPORTO_1*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE) > T1.ZHYE1+T1.ZHYE2
                       THEN (CASE WHEN (T1.ZHYE1+T1.ZHYE2) = 0 THEN  0 ELSE ( (T1.ZHYE1+T1.ZHYE2) * (1-T.IMPORTO_2) + T.IMPORTO_3 * 1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE) / (T1.ZHYE1+T1.ZHYE2) END)
                       ELSE 1 - (CASE WHEN (T1.ZHYE1+T1.ZHYE2) = 0 THEN 0 ELSE (T.IMPORTO_1 - T.IMPORTO_3)*T.IMPORTO_2*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE / (T1.ZHYE1+T1.ZHYE2) END)
                END
         WHEN  T.IMPORTO_4 BETWEEN 120 AND 180
           THEN CASE WHEN (T.IMPORTO_1*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE) > T1.ZHYE1+T1.ZHYE2+T1.ZHYE3
                       THEN (CASE WHEN (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3) = 0 THEN  0 ELSE ( (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3) * (1-T.IMPORTO_2) + T.IMPORTO_3 * 1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE) / (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3) END)
                       ELSE 1 - (CASE WHEN (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3) = 0 THEN 0 ELSE (T.IMPORTO_1 - T.IMPORTO_3)*T.IMPORTO_2*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE / (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3) END)
                END
         WHEN  T.IMPORTO_4 = 360
           THEN CASE WHEN (T.IMPORTO_1*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE) > T1.ZHYE1+T1.ZHYE2+T1.ZHYE3+T1.ZHYE4
                       THEN (CASE WHEN (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3+T1.ZHYE4) = 0 THEN  0 ELSE ( (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3+T1.ZHYE4) * (1-T.IMPORTO_2) + T.IMPORTO_3 * 1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE) / (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3+T1.ZHYE4) END)
                       ELSE 1 - (CASE WHEN (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3+T1.ZHYE4) = 0 THEN 0 ELSE (T.IMPORTO_1 - T.IMPORTO_3)*T.IMPORTO_2*1/HL.CAMBIO_FINALE*HL1.CAMBIO_FINALE / (T1.ZHYE1+T1.ZHYE2+T1.ZHYE3+T1.ZHYE4) END)
                END
    END) WPEIFBL,                      -- 未覆盖比例
    'CPM_SP_AG_INSURE' AS SRC,        -- 来源
    V_USER  AS USERUPD,               -- 更新用户
    SYSDATE AS DATEUPD                -- 更新时间
FROM TGK_GB_HISENSE.FORM_DATI T                                                     /*投保信息录入表*/
LEFT JOIN TGK_GB_HISENSE.DATI_CAMBIO HL                                             /*汇率表 - 转人民币*/
   ON T.TESTO_3 = HL.COD_VALUTA
  AND HL.COD_SCENARIO = V_SCENARIO
  AND HL.COD_PERIODO  = V_PERIODO
LEFT JOIN (                                                                         /*账龄余额表*/
  SELECT
    T.COD_AZIENDA,
    T.COD_VALUTA,
    T.TESTO_14,
    T.TESTO_15,
    SUM(T.IMPORTO_6) ZHYE1,
    SUM(T.IMPORTO_7) ZHYE2,
    SUM(T.IMPORTO_8) ZHYE3,
    SUM(T.IMPORTO_9) ZHYE4
  FROM TGK_GB_HISENSE.V_SQL_FORM_DATI T
  LEFT JOIN TGK_GB_HISENSE.DATI_CAMBIO T1
     ON T.COD_VALUTA = T1.COD_VALUTA
    AND T1.COD_SCENARIO = V_SCENARIO
    AND T1.COD_PERIODO = V_PERIODO
  WHERE T.COD_PROSPETTO = 'ZS_AR0001_IPT01'
    AND T.COD_SCENARIO = V_SCENARIO
    AND T.COD_PERIODO = V_PERIODO
    AND T.COD_CATEGORIA IN ('$AMOUNT', '1ADJ', '1REC')
    AND T.COD_AZIENDA = V_AZIENDA
    AND T.COD_CONTO IN ('1122000000')
  GROUP BY T.COD_AZIENDA,T.COD_VALUTA,T.TESTO_14,T.TESTO_15
) T1
   ON T.COD_AZIENDA = T1.COD_AZIENDA
  AND T.TESTO_14    = T1.TESTO_14
LEFT JOIN TGK_GB_HISENSE.DATI_CAMBIO HL1                                             /*汇率表 - 本位币*/
   ON T1.COD_VALUTA = HL1.COD_VALUTA
  AND HL1.COD_SCENARIO = V_SCENARIO
  AND HL1.COD_PERIODO  = V_PERIODO
WHERE T.COD_PROSPETTO = 'ZS_AR0001_IPT06'
  AND T.COD_SCENARIO  = V_SCENARIO
  AND T.COD_PERIODO   = V_PERIODO
  AND T.COD_AZIENDA   = V_AZIENDA
  AND T.COD_CONTO     ='1122000000'
  AND T.COD_CATEGORIA = 'XT01'
  AND V_YEARMONTH BETWEEN T.TESTO_11 AND T.TESTO_12
;

INSERT INTO ZTAB_CPM_LOG(CPM, COD_SCENARIO, COD_PERIODO, STEP, EXECTIME, CREATEBY,COD_AZIENDA)VALUES('CPM_SP_AG_INSURE', V_SCENARIO, V_PERIODO, '1.2 投保信息表数据插入完成', SYSDATE, V_USER,V_AZIENDA);
COMMIT;

END IF;

END;