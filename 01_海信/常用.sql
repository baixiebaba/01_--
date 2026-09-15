
jboss/JB0$$7

https://community.tagetik.com/ 
juntao.chen@epmvenus.com Cjt*123456


create database link PMS connect to EPM_TGKBUDGETODS identified by epm#2022TGKREPODS using '10.0.88.38:1521/EPMODS';

CREATE PUBLIC DATABASE LINK K3_AISHONGKONG
CONNECT TO hb IDENTIFIED BY hb2024hb
USING 'AISHONGKONG';

lsnrctl stop
lsnrctl start
lsnrctl status

--SPM造数据
DECLARE

i NUMBER := 0 ;

BEGIN

FOR i IN 1 .. 2 loop 
  insert INTO DATI_SALDI_LORDI T
      (T.UUID,
       T.ORIGIN,
       T.FLAGS,
       T.CREATOR,
       T.CREATE_TIME,
       T.MODIFIER,
       T.MODIFY_TIME,
       T.COD_SCENARIO,
       T.COD_PERIODO,
       T.COD_AZIENDA,
       T.COD_CONTO,
       T.COD_DEST1,
       T.COD_DEST2,
       T.COD_DEST3,
       T.COD_DEST4,
       T.COD_DEST5,
       T.COD_CATEGORIA,
       T.COD_VALUTA,
       T.IMPORTO,
       T.IMPORTO_VALUTA_ORIGINARIA
         )
         
         SELECT SYS_GUID(),
         '',
         '0',
         '10002',
         SYSDATE,
         '10002',
         SYSDATE,
         '2022BGT',
         '03',
         '11009',
         C.COD_CONTO,
         'V01',
         D.COD_DEST2,
         'ZZZ3',
         'ZZZ4'，
         'ZZZ5',
         'BC_MAN',
         'CNY',
         i+1,
         ''
         FROM 
          (SELECT * FROM DIM_DEST2 WHERE ISNODE = '0') D,DIM_CONTO C
          WHERE C.COD_CONTO LIKE '6%';

END loop ; 

COMMIT ;

END ;

--插入通用任务
INSERT INTO utente_lim_wfm_task_def
SELECT newid(),COD_UTENTE,'LONGIWF_B','B200','','','',0,1,'INSERT_SQL','CBMS_ADMIN1',SYSDATE 
  FROM (SELECT COD_UTENTE FROM UTENTE WHERE COD_UTENTE NOT IN (SELECT COD_UTENTE FROM utente_lim_wfm_task_def) AND TIPO_LIM_AZIENDA = '00')


UNPIVOT (IMPORTO FOR COD_PERIODO IN(
                  IMPORTO_1  AS '01'
                , IMPORTO_2  AS '02'
                , IMPORTO_3  AS '03'
                , IMPORTO_4  AS '04'
                , IMPORTO_5  AS '05'
                , IMPORTO_6  AS '06'
                , IMPORTO_7  AS '07'
                , IMPORTO_8  AS '08'
                , IMPORTO_9  AS '09'
                , IMPORTO_10 AS '10'
                , IMPORTO_11 AS '11'
                , IMPORTO_12 AS '12'))


--月份转列上
PIVOT(SUM(IMPORTO) FOR COD_PERIODO IN (
                              '01' AS IMPORTO_1,
                              '02' AS IMPORTO_2,
                              '03' AS IMPORTO_3,
                              '04' AS IMPORTO_4,
                              '05' AS IMPORTO_5,
                              '06' AS IMPORTO_6,
                              '07' AS IMPORTO_7,
                              '08' AS IMPORTO_8,
                              '09' AS IMPORTO_9,
                              '10' AS IMPORTO_10,
                              '11' AS IMPORTO_11,
                              '12' AS IMPORTO_12
                              ))

SELECT 
    -- 将每个月份的IMPORTO和IMPORTO_VALUTA_ORIGINARIA映射到目标列名
    m1_imp AS IMPORTO_1, m1_val AS IMPORTO_13,
    m2_imp AS IMPORTO_2, m2_val AS IMPORTO_14,
    m3_imp AS IMPORTO_3, m3_val AS IMPORTO_15,
    m4_imp AS IMPORTO_4, m4_val AS IMPORTO_16,
    m5_imp AS IMPORTO_5, m5_val AS IMPORTO_17,
    m6_imp AS IMPORTO_6, m6_val AS IMPORTO_18,
    m7_imp AS IMPORTO_7, m7_val AS IMPORTO_19,
    m8_imp AS IMPORTO_8, m8_val AS IMPORTO_20,
    m9_imp AS IMPORTO_9, m9_val AS IMPORTO_21,
    m10_imp AS IMPORTO_10, m10_val AS IMPORTO_22,
    m11_imp AS IMPORTO_11, m11_val AS IMPORTO_23,
    m12_imp AS IMPORTO_12, m12_val AS IMPORTO_24
FROM (
    -- 步骤1: 按COD_PERIODO分组，计算每个周期两个字段的总和
    SELECT 
        COD_PERIODO,
        SUM(IMPORTO) AS IMPORTO,
        SUM(IMPORTO_VALUTA_ORIGINARIA) AS IMPORTO_VALUTA_ORIGINARIA
    FROM DATI_SALDI_LORDI
    GROUP BY COD_PERIODO
)
-- 步骤2: 使用PIVOT同时转置两个字段
PIVOT (
    SUM(IMPORTO) AS imp,  -- IMPORTO的聚合值
    SUM(IMPORTO_VALUTA_ORIGINARIA) AS val  -- IMPORTO_VALUTA的聚合值
    FOR COD_PERIODO IN (
        '01' AS m1, '02' AS m2, '03' AS m3,
        '04' AS m4, '05' AS m5, '06' AS m6,
        '07' AS m7, '08' AS m8, '09' AS m9,
        '10' AS m10, '11' AS m11, '12' AS m12
    )
);



--多选或者ALL
AND (INSTR(PI_DEST5,T.COD_DEST5) > 0 OR UPPER(PI_DEST5) = 'ALL')
AND (INSTR(PI_ENTITY,T.COD_AZIENDA) > 0 OR UPPER(PI_ENTITY) = 'ALL')
AND (INSTR(PI_DEST2,T.COD_DEST2) > 0 OR UPPER(PI_DEST2) = 'ALL')

--解码
F_TGK_UNICODE_AS('decode',to_char(NOTE))


--存储过程QUERY文本
SELECT * FROM DBA_SOURCE WHERE OWNER = 'EPM_TGKBUDGET'
AND TYPE = 'PROCEDURE' AND TEXT LIKE '%PI_ENTITY%'

-- 查询矩阵：根据结构元素中的查询内容
SELECT
    p.COD_PROSPETTO,
    F_TGK_UNICODE_AS('decode', p.DESC_PROSPETTO0) AS DESC_PROSPETTO
FROM PROSPETTO p
WHERE EXISTS (
    SELECT 1
    FROM PROSPETTO_STRUTTURA_ELEMENTO e
    WHERE e.COD_PROSPETTO = p.COD_PROSPETTO
      AND EXISTS (
          SELECT 1
          FROM PROSPETTO_STRUTTURA_VALORE v
          WHERE v.ID_PROSP_STRUTTURA_ELEMENTO = e.ID
            AND v.TIPO_VALORE = 'QUERY'
            AND v.VALORE LIKE '%TF_H0100_020%'
            AND v.VALORE LIKE '%ZZZ3%'
      )
);



SELECT COD_PROSPETTO,F_TGK_UNICODE_AS('decode',DESC_PROSPETTO0) FROM PROSPETTO WHERE COD_PROSPETTO IN(
SELECT DISTINCT COD_PROSPETTO FROM PROSPETTO_STRUTTURA_ELEMENTO WHERE ID
IN (SELECT ID_PROSP_STRUTTURA_ELEMENTO FROM prospetto_struttura_valore WHERE TIPO_VALORE = 'QUERY' AND VALORE LIKE '%TF_H0100_020%' AND VALORE LIKE '%ZZZ3%')
)
--查询表单中挂的存储过程
SELECT 
      A.COD_PROSPETTO
    , F_TGK_UNICODE_AS('decode',A.DESC_PROSPETTO0) DESC0_PROSPETTO
    , REGEXP_REPLACE(
	  EXTRACT(XMLTYPE(C.VALORE), '//s/text()').getStringVal(),
	  '^[A-Z0-9_]+\.([A-Z0-9_]+)(.*)', '\1'
	  ) PROC_NAME
  FROM PROSPETTO A
  LEFT JOIN PROSPETTO_STRUTTURA_ELEMENTO B
    ON A.COD_PROSPETTO = B.COD_PROSPETTO
  LEFT JOIN PROSPETTO_STRUTTURA_VALORE C
    ON B.ID = C.ID_PROSP_STRUTTURA_ELEMENTO
 WHERE C.TIPO_VALORE = 'ELAB'
 ORDER BY A.COD_PROSPETTO


--查询矩阵
SELECT COD_PROSPETTO,F_TGK_UNICODE_AS('decode',DESC_PROSPETTO0) 
FROM PROSPETTO 
WHERE COD_PROSPETTO IN(
select DISTINCT COD_PROSPETTO from PROSPETTO_STRUTTURA_FILTRO t
where t.cod_filtro='1022')

-- 查询矩阵：根据筛选器
SELECT
    p.COD_PROSPETTO,
    F_TGK_UNICODE_AS('decode', p.DESC_PROSPETTO0) AS DESC_PROSPETTO
FROM PROSPETTO p
WHERE EXISTS (
    SELECT 1
    FROM PROSPETTO_STRUTTURA_FILTRO f
    WHERE f.COD_PROSPETTO = p.COD_PROSPETTO
      AND f.COD_FILTRO = '1022'
);



--矩阵内容查询
SELECT * FROM PROSPETTO_STRUTTURA_FILTRO WHERE COD_PROSPETTO = 'E11_080' AND COD_DIMENSIONE = 'VOC_ACH01'
ORDER BY TO_NUMBER(COD_POSIZIONE)


--query 字典参数
${parameter("CC016").parameterValue}

--重启开发环境服务器
ps -ef|grep wildfly

nohup sh /tagetik/longi/wildfly/bin/standalone.sh &

安装字体库
yum install fontconfig
重启服务

	--累计数
	LEFT JOIN (SELECT COD_PERIODO FROM PERIODO WHERE COD_PERIODO < 13) P
	 ON A.COD_PERIODO <= P.COD_PERIODO

--,转多行
SELECT DISTINCT CONTO_NEW,REGEXP_SUBSTR(CONTO_OLD, '[^,]+', 1, LEVEL, 'i') AS CONTO_OLD  
  FROM (
SELECT 
   '221101' CONTO_NEW,
   '6601010101,6602010101,6605010101,53010102010101,53010103010101,5101010101,5001100101,570102010101,57010106010101,530101011101' CONTO_OLD 
FROM DUAL
UNION ALL
SELECT '221117' CONTO_NEW,  
'6601010102S1,6602010102S1,6605010102S1,53010102010102S1,53010103010102S1,5101010102S1,5001100102S1,570102010102S1,57010106010102S1,530101011102S1,6601010102S2,6602010102S2,6605010102S2,53010102010102S2,53010103010102S2,5101010102S2,5001100102S2,570102010102S2,57010106010102S2,530101011102S2'
CONTO_OLD
FROM DUAL)  T
CONNECT BY LEVEL <=  
           LENGTH(CONTO_OLD) - LENGTH(REGEXP_REPLACE(CONTO_OLD, ',', ''))+1
AND T.CONTO_NEW = PRIOR T.CONTO_NEW AND PRIOR DBMS_RANDOM.value IS NOT NULL;  


--取当月数

SELECT COD_AZIENDA,COD_PERIODO,SUM(IMPORTO) IMPORTO,COD_DEST5,COD_DEST2,COD_DEST3
  FROM (
SELECT T.COD_AZIENDA,T.COD_DEST2,T.COD_DEST3,LPAD(COD_PERIODO +1,2,'0') COD_PERIODO,
 COD_DEST5,0-T.IMPORTO IMPORTO
  FROM DATI_SALDI_LORDI T
 WHERE 1=1
   AND T.COD_SCENARIO = PI_SCENARIO
   AND T.COD_AZIENDA IN (SELECT DISTINCT SUBSTR(ATTRIBUTO1,0,INSTR(ATTRIBUTO1,'_',1)-1) FROM V_DEST2_REF WHERE NODE = PI_DEST2 AND HIE = 'CCH03')
   AND T.COD_DEST1 = PI_DEST1
   AND T.COD_CONTO IN ('B011_060')
   AND T.COD_DEST3 IN (SELECT ELEM FROM V_DEST3_REF WHERE NODE = '1002')
   AND T.COD_CATEGORIA IN (SELECT ELEM FROM V_CATEGORIA_REF WHERE NODE = 'BC_ORI')
   AND T.COD_DEST2 IN (SELECT ELEM FROM V_DEST2_REF WHERE NODE = PI_DEST2 AND HIE = 'CCH03' AND ATTRIBUTO4 LIKE 'GB%')
   AND LPAD(COD_PERIODO +1,2,'0') IN (SELECT COD_PERIODO FROM PERIODO)

UNION ALL

SELECT T.COD_AZIENDA,T.COD_DEST2,T.COD_DEST3,T.COD_PERIODO,
 COD_DEST5,T.IMPORTO
  FROM DATI_SALDI_LORDI T
 WHERE 1=1
   AND T.COD_SCENARIO = PI_SCENARIO
   AND T.COD_AZIENDA IN (SELECT DISTINCT SUBSTR(ATTRIBUTO1,0,INSTR(ATTRIBUTO1,'_',1)-1) FROM V_DEST2_REF WHERE NODE = PI_DEST2 AND HIE = 'CCH03')
   AND T.COD_DEST1 = PI_DEST1
   AND T.COD_CONTO IN ('B011_060')
   AND T.COD_DEST3 IN (SELECT ELEM FROM V_DEST3_REF WHERE NODE = '1002')
   AND T.COD_CATEGORIA IN (SELECT ELEM FROM V_CATEGORIA_REF WHERE NODE = 'BC_ORI')
   AND T.COD_DEST2 IN (SELECT ELEM FROM V_DEST2_REF WHERE NODE = PI_DEST2 AND HIE = 'CCH03' AND ATTRIBUTO4 LIKE 'GB%')
)
GROUP BY COD_AZIENDA,COD_PERIODO,COD_DEST5,COD_DEST2,COD_DEST3


--日志表
SELECT * FROM SP_RUNLOG ORDER BY DATEUPD DESC

--字典
SELECT COD_ELEDIZ,F_TGK_UNICODE_AS('decode',DESC_ELEDIZ0) WLSM FROM FORM_DIZIONARIO_ELEMENTO WHERE COD_DIZIONARIO='MBSP'



=OFFSET(参考引用!$C$5,MATCH(D8,参考引用!$B$5:$B$99,0)-1,0,COUNTIF(参考引用!$B$5:$B$99,D8),)

=OFFSET(数据引用!$H$8,MATCH(D9,数据引用!$B$8:$B$99,0)-1,0,COUNTIF(数据引用!$B$8:$B$99,D9),)

=OFFSET(数据引用!$H$8,MATCH(E8,数据引用!$E$8:$E$99,0)-1,0,COUNTIF(数据引用!$E$8:$E$99,E8),)

=OFFSET(数据引用!$E$8,MATCH(E9,数据引用!$B$8:$B$99,0)-1,0,COUNTIF(数据引用!$B$8:$B$99,E9),)

=OFFSET(数据引用!$E$8,MATCH(D9,数据引用!$B$8:$B$99,0)-1,0,COUNTIF(数据引用!$B$8:$B$99,D9),)

=OFFSET(数据引用!$H$8,MATCH(E9,数据引用!$B$8:$B$99,0)-1,0,COUNTIF(数据引用!$B$8:$B$99,E9),)

=OFFSET(数据引用!$E$8,MATCH(D6,数据引用!$B$8:$B$99,0)-1,0,COUNTIF(数据引用!$B$8:$B$99,D6),)

=OFFSET(数据引用!$H$8,MATCH(E6,数据引用!$E$8:$E$99,0)-1,0,COUNTIF(数据引用!$E$8:$E$99,E6),)


SELECT DISTINCT NODE,SUBSTR(ATTRIBUTO1,0,5) COD_AZIEDNA,COD_DEST2_RIFERIMENTO FROM V_DEST2_REF 
WHERE HIE = 'CCH03' AND NODE = ${$Cust_Dim2(HIERARCHY("CCH03")).code}


begin
  
for v in ('','','','','') loop

  dbms_output.put_line(v.elem);
  CPM_SP_60_G00010('2022F0309','V03',V.ELEM,'CD');
  CPM_SP_60_G00011('2022F0309','V03',V.ELEM,'CD');
  CPM_SP_60_G00020('2022F0309','V03',V.ELEM,'CD');
  CPM_SP_60_G00030('2022F0309','V03',V.ELEM,'CD');
  CPM_SP_60_G00040('2022F0309','V03',V.ELEM,'CD');
  CPM_SP_60_G00050('2022F0309','V03',V.ELEM,'CD');
  CPM_SP_60_G00060('2022F0309','V03',V.ELEM,'CD');
  CPM_SP_60_G00070('2022F0309','V03',V.ELEM,'CD');
  commit;
 
end loop;

end;  


--delete 查看数据
select * from FORM_DATI  as of timestamp to_timestamp('2023/03/28 14:31:29','yyyy-mm-dd hh24:mi:ss')
WHERE COD_PROSPETTO = 'TF_O0101_01_020'

--开窗算比例
,RATIO_TO_REPORT(IMPORTO) OVER (PARTITION BY COD_VALUTA,COD_DEST3,COD_PERIODO) BL1


--判断进累计数还是当月数 E、A科目属性字段进累计数
SELECT COD_CONTO,NATURA_CONTO FROM CONTO WHERE NATURA_CONTO IN ('A','E')




SELECT 
--T+18->滚测
SUBSTR(PI_SCENARIO,0,5)||SUBSTR(PI_SCENARIO,-2)||LPAD(12-SUBSTR(PI_SCENARIO,-2),2,0)
 FROM DUAL
 
 
SELECT 
--滚测->T+18
REPLACE(SUBSTR(PI_SCENARIO,0,7),'F','FCT')
FROM DUAL



--程序查询参数
SELECT *  
  FROM ALL_ARGUMENTS A
  JOIN ALL_OBJECTS O
    ON A.OBJECT_ID = O.OBJECT_ID
 WHERE O.OBJECT_TYPE = 'PROCEDURE'
   AND O.OWNER = 'EPM_TGKBUDGET'
   
--linux拷贝文件
scp -r /tqls_system/apps/ tqlsuser@10.7.8.101:/tqls_system/apps/

scp -r /tagetik/longi root@10.0.11.226:/tagetik/longi

--调试
DECLARE
    PI_SCENARIO VARCHAR2(20) :='2023F0606';
    PI_DEST1 VARCHAR2(20) :='V24';
    PI_DEST2 VARCHAR2(20) :='C000552';
    SESSION_USER VARCHAR2(20) :='SQF';
 
BEGIN

--截取第一个-之前的数据
SUBSTR(ATTRIBUTO1,0,INSTR(ATTRIBUTO1,'_',1)-1)

--抛出异常
RAISE_APPLICATION_ERROR(-20999,DBMS_UTILITY.FORMAT_ERROR_BACKTRACE||ERROR_COD||ERROR_MSG);

--oracle 调用sqlserver存储过程
DECLARE
  c PLS_INTEGER;
  v_sql VARCHAR2(4000);
  nr VARCHAR2(4000);
  param1 VARCHAR2(100); -- 假设存储过程的参数是一个VARCHAR类型的参数
BEGIN
  param1 := '2021'; -- 设置存储过程的参数值
  
  v_sql := 'EXEC GETFORMDATA_2 ''' || param1 || ''''; -- 调用SQL Server的存储过程并传递参数
  c := DBMS_HS_PASSTHROUGH.OPEN_CURSOR@MAO;
  DBMS_HS_PASSTHROUGH.PARSE@MAO(c, v_sql);
  nr := DBMS_HS_PASSTHROUGH.execute_non_query@MAO(c);
  DBMS_HS_PASSTHROUGH.CLOSE_CURSOR@MAO(c);
  
  DBMS_OUTPUT.put_line(nr); -- 输出执行结果
  COMMIT;
END;



数据验证：
1、去除空格信息
=OFFSET(科目节点信息!$B$8,,,COUNTA(科目节点信息!$B$8:$B$999))

Application.Run "Tgkrmacro.xlam!launchElabs", "ELABORATION00"
If Application.Run("Tgkrmacro.xlam!TGK_isDataEntry", ThisWorkbook) Then
    ThisWorkbook.Save
	
    Application.Run "Tgkrmacro.xlam!launchElabs", "ELABORATION00"
	
	Application.run("Tgkrmacro.xlam!TGK_Refresh")
  Else
    MsgBox ("请在数据分录模式下点击此按钮")
  End If
  
ThisWorkbook.Save

Application.run("Tgkrmacro.xlam!TGK_Refresh")
  
IF(IF({1}="",2,COUNTIF(J:J,{9})+COUNTIF(K:K,{10}))=2,"TRUE","FALSE")




=IF(AND(COUNTIFS(A:A, A2, C:C, "<>"&C2) = 0,COUNTIFS(C:C, C2, A:A, "<>"&A2) = 0),"通过", "不通过")

=IF(AND(COUNTIFS(A:A, A2, C:C, "<>"&C2) = 0,COUNTIFS(C:C, C2, A:A, "<>"&A2) = 0,COUNTIFS(A:A, A2, B:B, B2, C:C, C2, D:D, D2) = 1),"通过", "不通过")




CREATE VIEW DATI_SALDI_LORDI_SQF AS 
SELECT T.OID_DATI_SALDI_LORDI,
       T.COD_SCENARIO,
       T.COD_PERIODO,
       T.COD_AZIENDA,
       T.COD_CONTO,
       T.COD_DEST1,
       T.COD_DEST2,
       T.COD_DEST3,
       T.COD_DEST4,
       T.COD_DEST5,
       T.COD_CATEGORIA,
       CASE WHEN CO.NATURA_CONTO IN ('A','E') THEN IMPORTO - COALESCE(LAG(IMPORTO, 1)
                          OVER(PARTITION BY T.COD_AZIENDA,
                               T.COD_CONTO,
                               T.COD_DEST1,
                               T.COD_DEST3,
                               T.COD_DEST2,
                               T.COD_DEST4,
                               T.COD_DEST5,
                               T.COD_VALUTA,
                               T.COD_CATEGORIA,
                               T.COD_VALUTA_ORIGINARIA ORDER BY T.COD_PERIODO),
                          0) 
       ELSE IMPORTO END AS IMPORTO,
       T.COD_VALUTA,
       CASE WHEN CO.NATURA_CONTO IN ('A','E') THEN T.IMPORTO_VALUTA_ORIGINARIA -
       COALESCE(LAG(IMPORTO_VALUTA_ORIGINARIA, 1)
                OVER(PARTITION BY T.COD_AZIENDA,
                     T.COD_CONTO,
                     T.COD_DEST1,
                     T.COD_DEST3,
                     T.COD_DEST2,
                     T.COD_DEST4,
                     T.COD_DEST5,
                     T.COD_VALUTA,
                     T.COD_CATEGORIA,
                     T.COD_VALUTA_ORIGINARIA ORDER BY COD_PERIODO),
                0) 
       ELSE IMPORTO END AS IMPORTO_VALUTA_ORIGINARIA,
       T.COD_VALUTA_ORIGINARIA,
       T.PROVENIENZA,
       T.USERUPD,
       T.DATEUPD,
       T.NOTE
  FROM DATI_SALDI_LORDI T
  LEFT JOIN CONTO CO
  ON T.COD_CONTO = CO.COD_CONTO
 WHERE 1 = 1
;



SELECT
  t.TABLE_NAME AS `查询表名`,
  t.TABLE_COMMENT AS `查询表描述`,
  c.COLUMN_NAME AS `查询列名`,
  c.COLUMN_COMMENT AS `查询列描述`
FROM
  information_schema.TABLES t
JOIN
  information_schema.COLUMNS c
ON
  t.TABLE_SCHEMA = c.TABLE_SCHEMA
  AND t.TABLE_NAME = c.TABLE_NAME
WHERE
  t.TABLE_SCHEMA = '你的数据库名'  -- 替换为实际数据库名
  -- 如需指定特定表，可添加：AND t.TABLE_NAME IN ('表1', '表2', ...)
ORDER BY
  t.TABLE_NAME,
  c.ORDINAL_POSITION;
  
  
  
  python3 /app_media/bin/etl/main.py -f ds_fima/src/dwd/exp/dwd_fi_mr_exp_base_mi.sql  -s "%%GP_START_DT" -p DS --env product --udp-list "20250601","p2025066"
  
  python3 /app_media/bin/etl/main.py -f ds_fima/src/dwd/exp/dwd_fi_mr_exp_base_mi.sql  -s "%%GP_START_DT" -p DS --env test --udp-list "$(date -d 'last month' +%Y%m01)","p$(date -d 'last month' +%Y%m)6"
  
  
python /appbin/swapdata.py -sid DS_DORISD_EXPORT -tid O_FIMAD_APPREAD -st dim.dim_mk_shop_detail_dd -tt tgk_fima_hisense.dim_mk_shop_detail_dd -sw "1=1" -tw "'1'='1'"

alter table dwd_fi_mr_exp_base_mi add column acct_map_code varchar(85) comment '映射后科目编码' after ACCOUNT_NAME;

alter table DWD_FI_MR_GP_GLPCA_MI add column profitcenter_name varchar(200) comment '利润中心名称' after comm_bu_name;
alter table DWD_FI_MR_GP_GLPCA_MI add column profitcenter_code varchar(20) comment '利润中心编码' after comm_bu_name;


alter table DWD_FI_MR_GP_DETAIL_MI add column discount30_amt decimalv3(27, 9) comment '折扣30' after discount6_amt;


alter table DWD_FI_MR_GP_DETAIL_MI add column rev_sale_bcy_amt decimalv3(27, 9) comment '销售收入-本位币';
alter table DWD_FI_MR_GP_MSUM_MI add column rev_sale_bcy_amt decimalv3(27, 9) comment '销售收入-本位币';

alter table DWD_FI_MR_GP_MSUM_MI add column profitcenter_code varchar(20) comment '利润中心编码' after comm_bu_name;

线上线下编码	onoffline_code	varchar(20)
内外销编码	sale_inout_code	varchar(20)

alter table DWD_FI_MR_GP_DETAIL_MI add column bus_sce_cat_code varchar(90) comment '业务场景分类' ;
alter table DWD_FI_MR_GP_DETAIL_MI add column bus_sce_cat_name varchar(150) comment '业务场景分类描述';

alter table DWD_FI_MR_GP_MSUM_MI add column bus_sce_cat_code varchar(90) comment '业务场景分类' ;
alter table DWD_FI_MR_GP_MSUM_MI add column bus_sce_cat_name varchar(150) comment '业务场景分类描述';




alter table DWD_FI_MR_EXP_OTHER_MI add column cp_company_code varchar(8) comment '对方公司' ;

bus_sce_cat_code	varchar(90)
bus_sce_cat_name	varchar(150)



alter table test.dwd_fi_mr_exp_balance_mi add column rev_sale_bcy_amt varchar(36) comment '活动类型编码' ;
alter table test.dwd_fi_mr_exp_balance_mi add column reference_cert_type varchar(500) comment '参考凭证类型' ;

alter table test.dwd_fi_mr_rev_acct_mi add column br_company_code varchar(20) comment '对方公司编码' ;

rev_sale_bcy_amt

alter table DWD_FI_MR_GP_GLPCA_MI add column rev_sale_bcy_amt decimalv3(27, 9) comment '销售收入-本位币';

alter table DWD_FI_MR_GP_DETAIL_MI add column br_company_code varchar(20) comment '分公司';

alter table DWD_FI_MR_GP_MSUM_MI add column br_company_code varchar(20) comment '分公司';

alter table DWD_FI_MR_GP_MSUM_MI add column maktx_s810 varchar(500) comment 'S810物料描述';

alter table DWD_FI_MR_GP_GLPCA_MI add column src_profitcenter_code varchar(20) comment '原始利润中心';
alter table DWD_FI_MR_GP_GLPCA_MI add column src_bus_range_code varchar(20) comment '原始业务范围';

alter table DWD_FI_MR_GP_DETAIL_MI add column src_profitcenter_code varchar(20) comment '原始利润中心';
alter table DWD_FI_MR_GP_DETAIL_MI add column src_bus_range_code varchar(20) comment '原始业务范围';

alter table DWD_FI_MR_GP_MSUM_MI add column src_profitcenter_code varchar(20) comment '原始利润中心';
alter table DWD_FI_MR_GP_MSUM_MI add column src_bus_range_code varchar(20) comment '原始业务范围';

原始利润中心	src_profitcenter_code	varchar(20)
原始业务范围	src_bus_range_code	varchar(20)


DWD_FI_MR_EXP_OTHER_MI
-- 一次性添加所有列
ALTER TABLE dwd_fi_mr_gae_base_mi ADD (
    onoffline_name VARCHAR2(200),
    onoffline_code VARCHAR2(50),
    exp_attr_name VARCHAR2(500),
    exp_attr_code VARCHAR2(100),
    sharing_type_name VARCHAR2(500),
    sharing_type_code VARCHAR2(100),
    sap_version VARCHAR2(20)
);

-- 分别添加注释
COMMENT ON COLUMN dwd_fi_mr_gae_base_mi.onoffline_name IS '线上线下描述';
COMMENT ON COLUMN dwd_fi_mr_gae_base_mi.onoffline_code IS '线上线下编码';
COMMENT ON COLUMN dwd_fi_mr_gae_base_mi.exp_attr_name IS '分摊类型描述';
COMMENT ON COLUMN dwd_fi_mr_gae_base_mi.exp_attr_code IS '费用属性编码';
COMMENT ON COLUMN dwd_fi_mr_gae_base_mi.sharing_type_name IS '分摊类型描述';
COMMENT ON COLUMN dwd_fi_mr_gae_base_mi.sharing_type_code IS '分摊类型编码';
COMMENT ON COLUMN dwd_fi_mr_gae_base_mi.sap_version IS 'SAP版本';


{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}


{{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}}

$(date -d 'last month' +%Y%m)


ods.odss800_GLPCA@FMSLK


DW.DW_TM_MARA_FERT@FMSLK


grant all on test.aw_rul_p2bmap_000001 to ds_gpload_ods;