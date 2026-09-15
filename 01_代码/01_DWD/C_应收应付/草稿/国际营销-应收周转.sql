select z.* from 
(SELECT 

 A1.rgn as 大区
,case when A1.month_dt>='202504' AND (A3.prdln  in ('0207','0403','0401','0402') OR (A3.prdln='01A0' AND A2.grp<>'D0090')) 
         then '产品线大区'
      when A1.month_dt<'202504' AND A3.prdln  in ('0207','01A0','0403','0401','0402') 
         then '产品线大区'
      when (A2.rgn_zh is null and A3.prdln not in ('0207','01A0','0403','0401','0402')) or A1.type ='8002'
         then '欧洲区'
      else A2.rgn_zh 
 end as "大区_zh"
,A1.grp        as 一级区组
,case when A1.type ='8002' then '欧洲海外' 
      else A2.grp_zh 
 end as "一级区组_zh"
,A1.bus_model  as 业务模式
,A1.prdctgy    as 产品大类
,A3.prdctgy_zh as "产品大类_zh"
,A1.prdln      as 产品线
,A3.prdln_zh   as "产品线_zh"
,case when a5.zterm_c is null then '其他' else a5.zterm_c end as 客户账期编码
,A1.kunnr      as 客户
,custfundcode 分户编码
,custfundname 分户名称
,A1.sm as 币种
,A1.extent  as 范围
,A1.end_amt_cny_m  as "实际应收账款（人民币）"
,A1.end_amt_usd_m  as "实际应收账款（美元）"
,A1.end_amt_cod_m  as "实际应收账款（本位币）"
,A1.load_dt  as "load_dt"
 FROM 
(
 SELECT * FROM ads.ads_fi_mr_accounts_rec_di
 where dsource = 'ACT'
 ) A1 
LEFT JOIN
( 
 select RGN,RGN_ZH,RGN_EN,GRP,GRP_ZH
 from dw.dwsd_im_td_bdr_area_group
 group by RGN,RGN_ZH,RGN_EN,GRP,GRP_ZH
)  A2 ON a1.grp=a2.grp
LEFT JOIN 
(
 select prdln,prdln_ZH,prdln_EN,prdln_JP,PRDCTGY,PRDCTGY_ZH,PRDCTGY_EN,PRDCTGY_JP 
 from dw.dwfi_im_td_product_category  
 where  enable_flag='T' 
 group by prdln,prdln_ZH,prdln_EN,prdln_JP,PRDCTGY,PRDCTGY_ZH,PRDCTGY_EN,PRDCTGY_JP
)  A3 ON a1.prdln=a3.prdln 

LEFT JOIN 
(
select KUNNR,MAX(namek) as namek
from ods.odss810_zbi_zfi023b  --客户代码匹客户名称：ods.odss810_zbi_zfi023b表，根据客户代码kunnr，匹客户名称namek
group by KUNNR   
)  K1 ON A1.KUNNR=K1.KUNNR

LEFT join (
 select kunnr,max(kunnrx) as kunnrx,max(zkhjc) as zkhjc from 
(SELECT KUNNR,KUNNRX,KATR1,CASE WHEN NAME1 IS NULL OR TRIM(NAME1)=''
 THEN CASE WHEN TRIM(ZKHJC)='' THEN NULL ELSE ZKHJC END ELSE  NAME1 END as ZKHJC 
FROM dw.dwfi_im_td_customer_master_basic_infor  where kunnrx not like 'G%'
GROUP BY KUNNR ,KUNNRX,KATR1,CASE WHEN NAME1 IS NULL OR TRIM(NAME1)=''
 THEN CASE WHEN TRIM(ZKHJC)='' THEN NULL ELSE ZKHJC END ELSE  NAME1 END) kk
group by kunnr ) K2
ON A1.KUNNR=K2.KUNNR

left join
(select col_zterm zterm,col_ztermc zterm_c 
from ods.odsmf_cm_tab1065 
group by col_zterm,col_ztermc)  A5
on a1.zterm=a5.zterm
) z   
where 日期 >=  DATE_FORMAT(ADD_MONTHS(now(), -24), '%Y%m')
 