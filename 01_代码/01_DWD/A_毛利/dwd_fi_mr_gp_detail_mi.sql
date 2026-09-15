
--  调用@year_month_day-- >'20250501'年月日，日固定为01，{{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}}最后一个insert需要修改分区，p2025056，p+年月+6

set @year_month_day = date_format((curdate() - INTERVAL 7 DAY) ,'%Y%m01') ;

-- set @year_month_day = '20260301' ;
-- set @year_month_day = '{{(execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).replace(day=1).strftime('%Y%m01')}}';

/*****************************************************************
  alter by 20260704 xiaoyachao.ex 处理GSMS日立公司编码数位数字格式的问题
  alter by 20260710 xiaoaychao.ex 600系统总账调整销量改为BSEG取数
  alter by 20260714 shiqingfeng.ex 修改对方公司映射逻辑，和本方公司是2%，对方公司是2023的业务范围取物料大表
  alter by 20260811 xiaoyachao.ex 借贷项订单管报不取数量,900逻辑：BSEG来源，凭证的参考码AWKEY=系统发票（系统发票判断：凭证抬头BKPF表里，交易业务GLVOR=SD00），到vbrk系统发票表里查询发票类型FKART=ZL2/ZG2/ZG3，不取数量
  alter by 20260811 xiaoyachao.ex FIDATA-433：销售型号名称逻辑更新
  alter by 20260813 FENGJIANFENG.ex 涉及600系统VBRP&800 900系统取BSEG部分 增加落户纸号字段 + 出库未开&退货未办部分收入，处理成不含税口径
  alter by 20260820FJF_ADD FENGJIANFENG.ex  源表3-销售成本数据【ods.ods_slt_s600_bseg_v】增加电商BU渠道细分、中国区品线标记逻辑
******************************************************************/
/*为确保有分区不会报错，先插入一条数据*/
-- INSERT INTO dwd.dwd_fi_mr_gp_detail_mi (dt_month) VALUES ('202602');

INSERT INTO dwd.dwd_fi_mr_gp_detail_mi (dt_month) VALUES (LEFT(@year_month_day,6));


INSERT OVERWRITE TABLE dwd.dwd_fi_mr_gp_detail_mi PARTITION (*)

-- INSERT OVERWRITE TABLE dwd.dwd_fi_mr_gp_detail_mi PARTITION ({{"p" + (execution_date - macros.dateutil.relativedelta.relativedelta(months=1)).strftime('%Y%m') + "6"}})
(year,month,company_code
,agency_code
,cust_code,material_code,shop_code,agency_name,material_name
,cust_name,cust_unity_name,credit_level_name,cust_nature_name,cust_type_name,channel_l1_code,channel_l1_name,channel_l2_code,channel_l2_name,channel_l3_code,channel_l3_name
,marketing_mode_code
,marketing_mode_name,
channel_big_class_code, 
channel_big_class_name,
channel_small_class_code,
channel_small_class_name,
ind_big_class_code,
ind_big_class_name,
ind_small_class_code,
ind_small_class_name,
onoffline_code,onoffline_name
,product_line_code,product_line_name,sale_model_code,sale_model_name,brand_code,brand_name,spec_section_code,spec_section_name,product_shape_type_code,product_shape_type_name,product_sale_series_code,product_sale_series_name,quarter_method_code,quarter_method_name,product_stage_code,product_stage_name,price_range_code,price_range_name,model_code,model_name,product_series_code,product_series_name,market_pnt_code,market_pnt_name,tech_type_code,tech_type_name
,is_miniled_code
,product_big_class_code,product_big_class_name,product_mid_class_code,product_mid_class_name,product_small_class_code,product_small_class_name,model_lca_code,model_lca_name,product_type_code,product_type_name,shop_name,bill_qty,qcy_code,rev_sale_amt
,discount1_amt,discount3_amt,discount4_amt,discount5_amt,discount6_amt,discount34_amt,tax_rate,exchange_rate,system_src,ods_src,bill_cert_id,bill_cert_item,sold_to_code,sold_to_name,material_group_code,cp_company_code,batch_id,material_pricing_group_code,material_pricing_group_name,sale_cert_id,sale_cert_item,sale_cert_type,reference_cert_id,reference_cert_item,acct_cert_id,ext_order_id,load_dt,dt_month
,acct_src_code,acct_map_code,bill_dt
,cust_mdg_code
,bus_range_code,bus_range_name,marketing_dept_code,marketing_dept_name
,comm_bu_code,comm_bu_name
,cn_class_mark_code,cn_class_mark_name
,material_group_name
,profitcenter_code
,profitcenter_name
,customer_model
,zcalasset
,discount30_amt
,rev_sale_bcy_amt
,ship_fact_code
,asap_dt
,br_company_code
,src_profitcenter_code
,src_bus_range_code
  /*20260520 新增miniled类型字段*/
, miniled_type_code
, miniled_type_name

,invoice_code -- 金税发票号
,file_archive_no -- 落户纸号
)

WITH vbrk AS(
SELECT
    vbrk.vbeln                                  AS vbeln
  , LTRIM(vbrp.posnr, '0')                    AS posnr
  /* 物料编码：2600公司RE凭证且科目6401%时，取分配字段zuonr作为物料号兜底 */
  , CASE
        WHEN vbrk.vkorg LIKE '26%'
         AND bseg.hkont LIKE '6401%'
         AND bkpf.blart = 'RE'
        THEN NVL(TRIM(vbrp.matnr), TRIM(bseg.zuonr))
        ELSE TRIM(vbrp.matnr)
    END                                          AS matnr
  /* 物料组：去掉产品线前缀 BP/DS/TA */
  , REPLACE(REPLACE(REPLACE(mara.prod_line, 'BP', ''), 'DS', ''), 'TA', '') AS matkl
  /* 前置单据：仅凭证类别为 T/J 时保留交货单号 */
  , CASE WHEN vbrp.vgtyp NOT IN ('T', 'J') THEN '' ELSE vbrp.vgbel END  AS vgbel
  , CASE WHEN vbrp.vgtyp NOT IN ('T', 'J') THEN '' ELSE LTRIM(vbrp.vgpos, '0') END AS vgpos
  , vbrp.aubel                                  AS aubel
  , LTRIM(vbrp.aupos, '0')                    AS aupos
  , vbak.auart                                  AS auart
  , vbak.zzextno                                AS zzextno
  /* 发票数量 */
  , CASE
        WHEN vbrk.vkorg = '2600'
         AND vbak.auart IN ('ZCR', 'ZDR', 'ZDR2', 'ZCRY', 'ZDRY')
        THEN 0
        WHEN vbak.auart IN ('ZCR', 'ZCR3', 'ZDR', 'ZDR2', 'ZDR3', 'ZCRY', 'ZDRY')
         AND vbrk.ernam IN ('ECPXUSER', 'ECPJSJS2', 'FUWEIJIE')
         AND vbrk.vkorg IN ('6700', '6800', '1180', '6746', '6847', '1630', '1632')
        THEN 0
        WHEN vbak.auart IN ('ZCR', 'ZCR3', 'ZDR', 'ZDR2', 'ZDR3', 'ZCRY', 'ZDRY')
         AND vbrk.vkorg IN ('6800', '1180', '6847', '1630', '1632')
        THEN 0
        WHEN vbrk.vkorg = '6005'
         AND vbak.auart IN ('ZGCR', 'ZGDR')
        THEN 0
        WHEN zauart.auart IS NOT NULL
        THEN 0
        WHEN vbrk.vbtyp IN ('O', '6', 'N')
        THEN 0 - vbrp.fkimg
        ELSE vbrp.fkimg
    END                                          AS fkimg
  , vbrp.charg                                  AS charg
  /* 不含税金额：冲销凭证取负数 */
  , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - vbrp.netwr ELSE vbrp.netwr END AS netwr
  , vbrk.fkdat                                  AS fkdat
  , vbrk.vkorg                                  AS vkorg
  , vbrk.kunrg                                  AS kunrg
  , vbrp.vkbur                                  AS vkbur
  , tvkbt.bezei                                 AS bezei
  , vbrp.kondm                                  AS kondm
  , t178t.vtext                                 AS vtext
  /* ZK01 直扣(%) */
  , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kbetr_zk01 ELSE konv.kbetr_zk01 END AS kbetr_zk01
  /* ZK05 直扣(%) */
  , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk05 ELSE konv.kwert_zk05 END AS kbetr_zk05
  /* ZK06 直扣(单价) */
  , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk06 ELSE konv.kwert_zk06 END AS kbetr_zk06
  /* ZK04 返利(单价)：6005公司用ZG02，其余用ZK04/ZK02 */
  , CASE
        WHEN vbrk.vbtyp IN ('O', '6', 'N') AND vbrk.vkorg = '6005'
        THEN 0 - IFNULL(konv.kwert_zg02, 0) - IFNULL(konv.kwert_zk17, 0)
        WHEN vbrk.vbtyp NOT IN ('O', '6', 'N') AND vbrk.vkorg = '6005'
        THEN IFNULL(konv.kwert_zg02, 0) + IFNULL(konv.kwert_zk17, 0)
        WHEN vbrk.vbtyp IN ('O', '6', 'N')
        THEN 0 - IFNULL(konv.kwert_zk04, konv.kwert_zk02)
        ELSE IFNULL(konv.kwert_zk04, konv.kwert_zk02)
    END                                          AS kbetr_zk04
  /* ZK03 返利(%) */
  , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk03 ELSE konv.kwert_zk03 END AS kbetr_zk03
  /* ZK34 返利(%) */
  , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk34 ELSE konv.kwert_zk34 END AS kbetr_zk34
  /* 会计凭证号 */
  , bkpf.belnr                                  AS belnr
  , bseg.hkont                                  AS acct_src_code
  , bseg.hkont                                  AS acct_map_code
  , vbrk.fkdat                                  AS bill_dt
  , bseg.gsber                                  AS bus_range_code
  , tgsbt.gtext                                 AS bus_range_name
  , t023t.wgbez                                 AS material_group_name
  , vbrp.prctr                                  AS profitcenter_code
  , ''                                            AS profitcenter_name
  /* 客户型号 */
  , COALESCE(
        IF(UPPER(mara.sale_model_name) = '无', NULL, UPPER(mara.sale_model_name))
      , IF(UPPER(mara.zcusmodel) = '无', NULL, UPPER(mara.zcusmodel))
    )                                           AS customer_model
  , mara.zcalasset                               AS zcalasset
  /* ZK30 返利(单价) */
  , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk30 ELSE konv.kwert_zk30 END AS kbetr_zk30
  /* 本位币金额 */
  , CASE
        WHEN bseg_6012.kursf IS NOT NULL THEN bseg_6012.dmbtr
        ELSE CASE
                WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - vbrp.netwr
                ELSE vbrp.netwr
             END
    END                                          AS dmbtr
  , vbap.werks                                  AS ship_fact_code
  , likp.wadat_ist                              AS asap_dt
  , vbak.bstzd                                  AS br_company_code
  , vbrk.kunag                                  AS sold_to
  , ''                                            AS sold_to_names
  , vbrk.waerk                                  AS waerk
  , CASE WHEN bseg_6012.kursf IS NULL THEN bkpf.kursf ELSE bseg_6012.kursf END AS kursk
  /* 税率：取MWST/MWSI/ZWST任意一个 */
  , COALESCE(konv.kbetr_mwst, konv.kbetr_mwsi, konv.kbetr_zwst) / 1000 AS kbetr_mwsi
  , zltxtbm.tline                               AS zdpbm
  , zltxtmc.tline                               AS zdpmc
  , bkpf.bktxt AS invoice_code -- 金税发票号
  , vbak.bstnk AS file_archive_no -- 落户纸号
FROM (
    /* VBRK - 发票头 */
    SELECT
        vbeln, fkart, rfbsk, vkorg, kunrg, kunag, fkdat, vbtyp, ernam, waerk, knumv
    FROM ods.ods_slt_s600_vbrk
    WHERE fkdat >= @year_month_day
      AND fkdat < DATE_FORMAT(DATE_ADD(CAST(@year_month_day AS DATE), INTERVAL 1 MONTH), '%Y%m%d')
) vbrk
LEFT JOIN (
    /* VBRP - 发票行 */
    SELECT
        vbeln, posnr, matnr, vgtyp, vgbel, vgpos, aubel, aupos, fkimg, netwr, charg, vkbur, kondm, prctr, kursk
    FROM ods.ods_slt_s600_vbrp
) vbrp ON vbrk.vbeln = vbrp.vbeln
LEFT JOIN (
    /* VBAK - 销售订单头 */
    SELECT vbeln, auart, zzextno, bstzd, bstnk
    FROM ods.odsslt_s600_vbak
) vbak ON vbrp.aubel = vbak.vbeln
LEFT JOIN (
    /* ZAUART - 特殊订单类型（数量置0）*/
    SELECT auart FROM ods.ods_s600_zauart
) zauart ON vbak.auart = zauart.auart
LEFT JOIN (
    /* BKPF - 凭证抬头 */
    SELECT bukrs, gjahr, belnr, awkey, awtyp, kursf, blart, bktxt
    FROM ods.ods_slt_s600_bkpf_v
    WHERE awtyp = 'VBRK'
) bkpf ON vbrk.vbeln = bkpf.awkey
LEFT JOIN (
    /* BSEG - 凭证行（6001%/6051% 科目）*/
    SELECT bukrs, gjahr, belnr, matnr, hkont, zuonr, MAX(gsber) AS gsber
    FROM ods.ods_slt_s600_bseg_v
    WHERE (hkont LIKE '6001%' OR hkont LIKE '6051%')
    GROUP BY bukrs, gjahr, belnr, matnr, hkont, zuonr
) bseg
    ON  bkpf.bukrs  = bseg.bukrs
    AND bkpf.gjahr  = bseg.gjahr
    AND bkpf.belnr  = bseg.belnr
    AND CASE
            WHEN vbrk.vkorg LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE'
                THEN NVL(TRIM(vbrp.matnr), TRIM(bseg.zuonr))
            ELSE TRIM(vbrp.matnr)
        END = bseg.matnr
LEFT JOIN (
    /* dim_fi_mr_product_dd - 物料大表 */
    SELECT
        matnr, prod_line, sale_model_name, zcusmodel, zcalasset, matkl, zznxwx, sale_area
    FROM dim.dim_fi_mr_product_dd
) mara
    ON  CASE
            WHEN vbrk.vkorg LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE'
                THEN NVL(TRIM(vbrp.matnr), TRIM(bseg.zuonr))
            ELSE TRIM(vbrp.matnr)
        END = mara.matnr
LEFT JOIN (
    /* T023T - 物料组描述 */
    SELECT matkl, wgbez
    FROM ods.ods_s600_t023t
    WHERE spras = '1'
) t023t ON mara.matkl = t023t.matkl
LEFT JOIN (
    /* T178T - 物料定价组描述 */
    SELECT kondm, vtext
    FROM ods.ods_s600_t178t
    WHERE spras = '1'
) t178t ON vbrp.kondm = t178t.kondm
LEFT JOIN (
SELECT bukrs,gjahr,belnr,matnr,hkont
                    ,(CASE 
                         WHEN a.wrbtr <> 0 
                         THEN a.dmbtr / a.wrbtr  --  反算汇率
                         -- ELSE bkpf.kursf                           --  外币金额为0时直接取bkpf汇率
                     END) AS kursf
                     ,a.dmbtr,a.wrbtr
               FROM 
             (SELECT bukrs,gjahr,belnr,matnr,hkont,SUM(CASE WHEN shkzg = 'S' THEN dmbtr ELSE -1*dmbtr END) AS dmbtr
                    ,SUM(CASE WHEN shkzg = 'S' THEN wrbtr ELSE -1*wrbtr END) AS wrbtr 
    FROM ods.ods_slt_s600_bseg_v
              WHERE (hkont LIKE '6001%' OR hkont LIKE '6051%' )
                -- AND bukrs IN ('6012','2023')
              GROUP BY bukrs,gjahr,belnr,matnr,hkont
            ) a
) bseg_6012
    ON  bkpf.bukrs  = bseg_6012.bukrs
    AND bkpf.gjahr  = bseg_6012.gjahr
    AND bkpf.belnr  = bseg_6012.belnr
    AND CASE
            WHEN vbrk.vkorg LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE'
                THEN NVL(TRIM(vbrp.matnr), TRIM(bseg.zuonr))
            ELSE TRIM(vbrp.matnr)
        END = bseg_6012.matnr
LEFT JOIN (
    /* VBPA - 售达方合作伙伴 */
    SELECT vbeln, kunnr
    FROM ods.ods_slt_s600_vbpa
    WHERE parvw = 'AG'
) vbpa ON vbrp.aubel = vbpa.vbeln
LEFT JOIN (
    /* TVKBT - 办事处描述 */
    SELECT vkbur, bezei
    FROM ods.ods_s600_tvkbt
    WHERE spras = '1'
) tvkbt ON vbrp.vkbur = tvkbt.vkbur
LEFT JOIN (
    /* EKKO - 采购凭证 */
    SELECT ebeln, submi
    FROM ods.ods_s600_ekko
) ekko ON vbrp.aubel = ekko.ebeln
LEFT JOIN (
    /* VBPA1 - 售达方合作伙伴（用于采购订单关联）*/
    SELECT vbeln, kunnr
    FROM ods.ods_slt_s600_vbpa
    WHERE parvw = 'AG'
) vbpa1 ON ekko.submi = vbpa1.vbeln
LEFT JOIN (
    /* VBAP - 销售订单行（取gsber/werks）*/
    SELECT DISTINCT vbeln, posnr, gsber, werks
    FROM ods.ods_slt_s600_vbap
) vbap
    ON  vbrp.aubel = vbap.vbeln
    AND LTRIM(vbrp.aupos, '0') = LTRIM(vbap.posnr, '0')
LEFT JOIN (
    /* TGSBT - 业务范围描述 */
    SELECT gsber, gtext
    FROM ods.ods_s600_tgsbt
    WHERE spras = '1'
) tgsbt ON vbap.gsber = tgsbt.gsber
LEFT JOIN (
    /* ZLTXT - 店铺编码（TDID='0005'）*/
    SELECT tdname, tline
    FROM ods.ods_s600_zltxt
    WHERE tdid = '0005'
) zltxtbm ON vbrp.aubel = zltxtbm.tdname
LEFT JOIN (
    /* ZLTXT - 店铺名称（TDID='0004'）*/
    SELECT tdname, tline
    FROM ods.ods_s600_zltxt
    WHERE tdid = '0004'
) zltxtmc ON vbrp.aubel = zltxtmc.tdname
LEFT JOIN (
    /* LIKP - 实际发货日期（按vgbel聚合）*/
    SELECT MAX(l.wadat_ist) AS wadat_ist, p.vgbel
    FROM (
        SELECT vbeln, wadat_ist
        FROM ods.ods_s600_likp
        WHERE wadat_ist IS NOT NULL
    ) l
    JOIN (
        SELECT DISTINCT vbeln, vgbel
        FROM ods.ods_slt_s600_lips
    ) p ON l.vbeln = p.vbeln
    GROUP BY p.vgbel
) likp ON vbrp.aubel = likp.vgbel
/* ===================== KONV 单表扫描 + 行转列（嵌套子查询）===================== */
LEFT JOIN (
    SELECT
        knumv,
        kposn,
        MAX(CASE WHEN kschl = 'ZK01' AND rn = 1 THEN kbetr END) AS kbetr_zk01,
        MAX(CASE WHEN kschl = 'ZK02' AND rn = 1 THEN kwert END) AS kwert_zk02,
        MAX(CASE WHEN kschl = 'ZK03' AND rn = 1 THEN kwert END) AS kwert_zk03,
        MAX(CASE WHEN kschl = 'ZK04' AND rn = 1 THEN kwert END) AS kwert_zk04,
        MAX(CASE WHEN kschl = 'ZK05' AND rn = 1 THEN kwert END) AS kwert_zk05,
        MAX(CASE WHEN kschl = 'ZK06' AND rn = 1 THEN kwert END) AS kwert_zk06,
        MAX(CASE WHEN kschl = 'MWST' AND rn = 1 THEN kbetr END) AS kbetr_mwst,
        MAX(CASE WHEN kschl = 'MWSI' AND rn = 1 THEN kbetr END) AS kbetr_mwsi,
        MAX(CASE WHEN kschl = 'ZWST' AND rn = 1 THEN kbetr END) AS kbetr_zwst,
        MAX(CASE WHEN kschl = 'ZK34' AND rn = 1 THEN kwert END) AS kwert_zk34,
        MAX(CASE WHEN kschl = 'ZK30' AND rn = 1 THEN kwert END) AS kwert_zk30,
        MAX(CASE WHEN kschl = 'ZG02' AND rn = 1 THEN kwert END) AS kwert_zg02,
        MAX(CASE WHEN kschl = 'ZK17' AND rn = 1 THEN kwert END) AS kwert_zk17
    FROM (
        SELECT
            knumv, kposn, kschl, kbetr, kwert,
            ROW_NUMBER() OVER (
                PARTITION BY knumv, kposn, kschl
                ORDER BY CASE
                    WHEN kschl = 'ZG02' THEN CASE kherk WHEN 'G' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                    ELSE CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                END
            ) AS rn
        FROM (
            SELECT
                kherk, knumv, kposn, kschl,
                SUM(kbetr) AS kbetr,
                SUM(kwert) AS kwert
            FROM ods.odsslt_s600_konv
            WHERE kschl IN ('ZK01','ZK02','ZK03','ZK04','ZK05','ZK06','ZK17',
                            'MWST','MWSI','ZWST','ZK34','ZK30','ZG02')
            GROUP BY kherk, knumv, kposn, kschl
        ) t_base
    ) t_rank
    WHERE rn = 1
    GROUP BY knumv, kposn
) konv
    ON  vbrk.knumv = konv.knumv
    AND vbrp.posnr = konv.kposn
WHERE 1 = 1
  AND vbrk.fkart  <> 'ZG1'
  AND vbrk.rfbsk  = 'C'
  AND (
        EXISTS (
            SELECT 1
            FROM ods.ods_s600_zauarte zauarte
            WHERE zauarte.auart = IFNULL(vbak.auart, zauarte.auart)
              AND vbrk.vkorg <> '6098'
        )
        OR (vbrk.vkorg = '6005' AND vbak.auart IN ('ZG01','ZGCX','ZGCR','ZGDS','ZGGC','ZGXS','ZGHS','ZGDR','ZGMF','ZGPJ','ZGSW','ZGRE','ZGYJ'))
        OR (vbrk.vkorg = '6797' AND vbak.auart IN ('YZRE'))
        OR (vbrk.vkorg = '6098' AND vbak.auart IN ('ZXP1'))
      )
),
 form_dati_ctp AS --  匹配对方公司
 (
 SELECT cust_code AS kunrg --  客商编码
       ,NVL(cp_company_code_mr,cp_company_code) AS ctp --  对方公司编码
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S600'
 ),
  vbrk_m AS 
 (--  匹配物料大表，错误产品线和对方公司
   SELECT
      vbrk.*
     ,CASE WHEN form_dati_ctp.ctp IN ('4330','4320') AND vbrk.vkorg = '6515'  THEN CONCAT(form_dati_ctp.ctp,'A') ELSE form_dati_ctp.ctp END AS ctp --  对方公司
    FROM vbrk 
    LEFT JOIN form_dati_ctp --  匹配对方公司
      ON vbrk.kunrg = form_dati_ctp.kunrg
 ),
  nf_map_1  AS 
(

  SELECT  batch_id --  处理优先级
        , logic_name AS lj --  逻辑处理
        , b.cod_azienda AS vkorg --  公司包含
        , c.cod_azienda AS ctp
        , cust_code AS kunrg --  客商包含
        , cust_ex_code AS kunrg_out
        , sold_to_code AS sold_to --  售达方包含
        , sold_to_ex_code AS sold_to_out
        , product_line_src_code AS org_prctr_before --  处理前利润中心
        , onoffline_src_code AS nf_before
        , onoffline_code AS nf
        , onoffline_name AS nf_name
   FROM dim.dim_rule_fi_mr_nf_mapping a 
   LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
  WHERE valid_fr <= @year_month_day
    AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 

 )

, vbrk_1 AS 
(  --  匹配线上线下
 SELECT
     vbrk_m.*
    ,CASE WHEN COALESCE(form_dati_nf6.nf,form_dati_nf5.nf,form_dati_nf4.nf,form_dati_nf3.nf,form_dati_nf2.nf,form_dati_nf1.nf) IS NULL 
            THEN '020_OFF_002' 
          WHEN COALESCE(form_dati_nf6.nf,form_dati_nf5.nf,form_dati_nf4.nf,form_dati_nf3.nf,form_dati_nf2.nf,form_dati_nf1.nf) = 'NULL'
            THEN NULL 
          ELSE COALESCE(form_dati_nf6.nf,form_dati_nf5.nf,form_dati_nf4.nf,form_dati_nf3.nf,form_dati_nf2.nf,form_dati_nf1.nf)
     END AS nf_1
    ,CASE WHEN COALESCE(form_dati_nf6.nf_name,form_dati_nf5.nf_name,form_dati_nf4.nf_name,form_dati_nf3.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name) IS NULL 
            THEN '零售-传统零售' 
          WHEN COALESCE(form_dati_nf6.nf_name,form_dati_nf5.nf_name,form_dati_nf4.nf_name,form_dati_nf3.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name) = 'NULL'
            THEN NULL 
          ELSE COALESCE(form_dati_nf6.nf_name,form_dati_nf5.nf_name,form_dati_nf4.nf_name,form_dati_nf3.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name)
     END AS nf_1_name
   FROM vbrk_m
   LEFT JOIN nf_map_1 form_dati_nf1--  匹配线上线下映射表 按公司匹配
     ON 1=1
    --  公司包含匹配
    AND form_dati_nf1.batch_id = '1'
    AND vbrk_m.vkorg = form_dati_nf1.vkorg

   LEFT JOIN nf_map_1 form_dati_nf2--  匹配线上线下映射表 按公司+客商匹配
     ON 1=1
    --  公司包含匹配
    AND form_dati_nf2.batch_id = '2'
    AND vbrk_m.vkorg = form_dati_nf2.vkorg
    --  客商匹配
    AND LTRIM(vbrk_m.kunrg, '0') = form_dati_nf2.kunrg

   LEFT JOIN nf_map_1 form_dati_nf3--  匹配线上线下映射表 按公司+客商+售达方匹配
     ON 1=1
    --  公司包含匹配
    AND form_dati_nf3.batch_id = '3'
    AND vbrk_m.vkorg = form_dati_nf3.vkorg
    --  客商匹配
    AND LTRIM(vbrk_m.kunrg, '0') = form_dati_nf3.kunrg
    --  售达方匹配
    AND LTRIM(vbrk_m.sold_to, '0') = form_dati_nf3.sold_to

   LEFT JOIN nf_map_1 form_dati_nf4--  匹配线上线下映射表 按客商+售达方匹配
     ON 1=1
    --  公司包含匹配
    AND form_dati_nf4.batch_id = '4'
    AND LTRIM(vbrk_m.kunrg, '0') = form_dati_nf4.kunrg
    --  售达方匹配
    AND LTRIM(vbrk_m.sold_to, '0') = form_dati_nf4.sold_to

   LEFT JOIN nf_map_1 form_dati_nf5--  匹配线上线下映射表 按公司+对方公司匹配
     ON 1=1
    --  公司匹配
    AND form_dati_nf5.batch_id = '5'
    AND vbrk_m.vkorg = form_dati_nf5.vkorg
    --  对方公司匹配
    AND vbrk_m.ctp = form_dati_nf5.ctp

   LEFT JOIN nf_map_1 form_dati_nf6--  匹配线上线下映射表 按公司+对方公司+售达方
     ON 1=1
    --  公司匹配
    AND form_dati_nf6.batch_id = '6'
    AND vbrk_m.vkorg = form_dati_nf6.vkorg
    --  对方公司匹配
    AND vbrk_m.ctp = form_dati_nf6.ctp
    --  售达方匹配
    AND LTRIM(vbrk_m.sold_to, '0') = form_dati_nf6.sold_to
    )
,
 vbrk_2 AS 
(  --  匹配电商BU渠道细分编码和中国区品类标记编码
 SELECT DISTINCT
     vbrk.*,zzqdb_code,zzqdb,zzqdp_code,zzqdp
     FROM vbrk_1 vbrk
     LEFT JOIN  dim.dim_mrs_s600_vbak_dd vbak
      ON COALESCE(vbrk.aubel,-1) = COALESCE(vbak.vbeln,-1)
      and vbrk.vkorg = vbak.vkorg
      and vbak.audat >= DATE_FORMAT(
                      DATE_ADD(
                          STR_TO_DATE(CAST(vbrk.fkdat AS CHAR(8)), '%Y%m%d'), 
                          INTERVAL -33 MONTH
                      ), 
                      '%Y%m%d')
      -- AND vbak.audat <= vbrk.fkdat
      )
SELECT 
    date_format(vbrk.fkdat,'%Y') AS year --  财务年
  , date_format(vbrk.fkdat,'%m') AS month --  财务月
  , vbrk.vkorg AS company_code --  组织
  , vbrk.vkbur AS agency_code --  办事处编码
  , vbrk.kunrg AS cust_code --  客商编码
  , vbrk.matnr AS material_code --  物料编码
  , vbrk.zdpbm AS shop_code --  门店编码
  , vbrk.bezei AS agency_name --  办事处名称
  , dim_fi_mr_product_dd.product_name AS material_name
  , ods_slt_s600_kna1.name1 AS cust_name --  客商名称
  , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name --  统一客户组
  , dim_customer_base_info_dd.credit_level AS credit_level_name --  信用等级
  , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name --  单位性质
  , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
         AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
         AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
         THEN NULL
         ELSE TRIM(
               REGEXP_REPLACE(
                   CONCAT_WS(',',
                       CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                       CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                       CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                   ),
                   '(^,)|(,$)',  
                   ''            
               )
           )
     END AS cust_type_name  --  客户类型
  , dim_customer_base_info_dd.com_1st_code AS channel_l1_code --  销售渠道一级编码
  , dim_customer_base_info_dd.com_1st_name AS channel_l1_name --  销售渠道一级名称
  , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code --  销售渠道二级编码
  , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name --  销售渠道二级名称
  , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code --  销售渠道三级编码
  , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name --  销售渠道三级名称
  , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code --  销售模式编码
  , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name --  销售模式名称
  , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code --  渠道客户大类编码
  , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name --  渠道客户大类名称
  , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code --  渠道客户小类编码
  , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name --  渠道客户小类名称
  , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code --  行业大类编码
  , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name --  行业大类名称
  , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code --  行业小类编码
  , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name --  行业小类名称
  /*ADD SXX XSJ 20260320中国区特殊逻辑（优先级最高）
  一。当公司IN ('1180','118A','118B','1181')或12%时：
  1.通过物料编码【material_code 】+业务范围【bus_range_code】关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=1的渠道分组编码【onoffline_code】
  2.通过物料编码【material_code】关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=2的渠道分组编码【onoffline_code】
  通过以上逻辑没匹配上的，再按以下逻辑取值：
    1、针对来源为SAP600的销售订单数据，优先使用销售订单上 销售组织/销售办事处的配置表判断线上/线下标识。（其他来源则直接从第二步开始判断）线上的默认为线上-“主站”，线下的默认为线下-“零售-传统零售”
    2、第一步判断不出来的，则通过经分项目收入模块规则映射表维护的内容进行匹配
    3、特殊逻辑：
    ① 品质之家：从26年1月1日起，中国区品质之家销售的全部划为线下。判断逻辑：店铺编码 【shop_code】in（15295336542、DP118005162、DP118005033）未品质之家则为 线下- “零售-传统零售”，否则按整体逻辑处理。
    ②定价组【material_pricing_group_code】 in（工程机、分公司工程机）的默认为线下-“工程“
    ③asko+gorenje（公司为6005、6530）：SAP订单的销售部门【agency_code】=“大客户部-古洛尼”的默认为线下-“工程“
    ④激光2052、2053公司客户【cust_code】是内部公司的就是线下-”内配“，外部的就是线下-”外售“
  */
  , CASE WHEN vbrk.vkorg = '6098' THEN '020_OFF_002' --  2026.04.14 新增 当公司为6098时，线上线下固定为020_OFF_002
         WHEN (vbrk.vkorg IN ('1180','118A','118B','1181') OR vbrk.vkorg LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_code
         WHEN (vbrk.vkorg IN ('1180','118A','118B','1181') OR vbrk.vkorg LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_code
         WHEN vbrk.zdpbm IN ('15295336542','DP118005162','DP118005033') THEN '020_OFF_002'
         WHEN LTRIM(vbrk.kondm,'0') IN ('4','9') THEN '020_OFF_004'
         -- WHEN vbrk.vkorg IN ('6005','6530') AND vbrk.vkbur = 'G005' THEN '020_OFF_004'
         WHEN vbrk.vkorg IN ('2052','2053') AND vbrk.ctp IS NOT NULL THEN '020_OFF_006'
         WHEN vbrk.vkorg IN ('2052','2053') AND vbrk.ctp IS NULL THEN '020_OFF_007'
         ELSE vbrk.nf_1
    END AS onoffline_code --  线上线下编码
  , CASE WHEN vbrk.vkorg = '6098' THEN '零售-传统零售'
         WHEN (vbrk.vkorg IN ('1180','118A','118B','1181') OR vbrk.vkorg LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_name
         WHEN (vbrk.vkorg IN ('1180','118A','118B','1181') OR vbrk.vkorg LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_name
         WHEN vbrk.zdpbm IN ('15295336542','DP118005162','DP118005033') THEN '零售-传统零售'
         WHEN LTRIM(vbrk.kondm,'0') IN ('4','9') THEN '工程'
         -- WHEN vbrk.vkorg IN ('6005','6530') AND vbrk.vkbur = 'G005' THEN '工程'
         WHEN vbrk.vkorg IN ('2052','2053') AND vbrk.ctp IS NOT NULL THEN '内配'
         WHEN vbrk.vkorg IN ('2052','2053') AND vbrk.ctp IS NULL THEN '外售'
         ELSE vbrk.nf_1_name 
    END AS onoffline_name --  线上线下名称
  , '' AS product_line_code --  产品线编码
  , '' AS product_line_name --  产品线名称
  , COALESCE(IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
            ) AS sale_model_code --  销售型号编码
  -- , '' AS sale_model_name --  销售型号名称
  /*alter by 20260811 xiaoyachao.ex 销售型号名称取数逻辑更新*/
  , COALESCE(IF(TRIM(dim_fi_mr_product_dd.sale_model_name)= '',NULL,TRIM(dim_fi_mr_product_dd.sale_model_name))
            ,IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
            ) AS sale_model_name --  销售型号名称
  -- , dim_fi_mr_product_dd.sale_model_code AS sale_model_code --  销售型号编码
  -- , dim_fi_mr_product_dd.sale_model_name AS sale_model_name --  销售型号名称
  , CASE WHEN vbrk.vkorg = '6098' THEN NULL --  2026.04.14 新增 当公司为6098时，品牌放空
         ELSE dim_fi_mr_product_dd.brand
    END AS brand_code --  品牌编码
  , CASE WHEN vbrk.vkorg = '6098' THEN NULL
         ELSE dim_fi_mr_product_dd.brand_name
    END AS brand_name --  品牌名称
  
  , CASE WHEN dim_fi_mr_product_dd.big_class_code = 'P01' THEN dim_fi_mr_product_dd.SCREEN_SIZE_CODE
     WHEN dim_fi_mr_product_dd.big_class_code = 'P02' THEN dim_fi_mr_product_dd.SPEC_RANGE_CODE
     WHEN dim_fi_mr_product_dd.big_class_code = 'P03' THEN dim_fi_mr_product_dd.TOTAL_CAPACITY_CODE
     WHEN dim_fi_mr_product_dd.big_class_code = 'P04' THEN dim_fi_mr_product_dd.WASHING_CAPACITY_CODE
  END AS spec_section_code --  规格段编码
  , CASE WHEN dim_fi_mr_product_dd.big_class_code = 'P01' THEN dim_fi_mr_product_dd.SCREEN_SIZE_NAME
     WHEN dim_fi_mr_product_dd.big_class_code = 'P02' THEN dim_fi_mr_product_dd.SPEC_RANGE_NAME
     WHEN dim_fi_mr_product_dd.big_class_code = 'P03' THEN dim_fi_mr_product_dd.TOTAL_CAPACITY_NAME
     WHEN dim_fi_mr_product_dd.big_class_code = 'P04' THEN dim_fi_mr_product_dd.WASHING_CAPACITY_NAME
  END  AS spec_section_name --  规格段名称
  
  , dim_fi_mr_product_dd.product_spec_code AS product_shape_type_code --  产品形态分类编码
  , dim_fi_mr_product_dd.product_spec_name AS product_shape_type_name --  产品形态分类名称
  , dim_fi_mr_product_dd.prod_suite_code AS product_sale_series_code --  产品套系编码
  , dim_fi_mr_product_dd.prod_suite_name AS product_sale_series_name --  产品套系名称
  , '' AS quarter_method_code --  四分法编码（市场口径）
  , '' AS quarter_method_name --  四分法名称（市场口径）
  , dim_fi_mr_product_dd.prod_stage_code AS product_stage_code --  产品阶段编码
  , dim_fi_mr_product_dd.prod_stage_name AS product_stage_name --  产品阶段名称
  , dim_fi_mr_product_dd.price_range_code AS price_range_code --  价格段编码
  , dim_fi_mr_product_dd.price_range_name AS price_range_name --  价格段名称
  , dim_fi_mr_product_dd.model_code AS model_code --  产品型号编码
  , dim_fi_mr_product_dd.model_name AS model_name --  产品型号名称
  , dim_fi_mr_product_dd.series_code AS product_series_code --  产品系列编码
  , dim_fi_mr_product_dd.series_name AS product_series_name --  产品系列名称
  , dim_fi_mr_product_dd.market_pos_code AS market_pnt_code --  营销定位编码
  , dim_fi_mr_product_dd.market_pos_name AS market_pnt_name --  营销定位名称
  , dim_fi_mr_product_dd.ac_ct_code AS tech_type_code --  技术类型编码
  , dim_fi_mr_product_dd.ac_ct_name AS tech_type_name --  技术类型名称
  , CASE WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013001' THEN '是'
         WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013002' THEN '否'
         ELSE ''
    END AS is_miniled_code --  是否MiniLED编码
  , dim_fi_mr_product_dd.big_class_code AS product_big_class_code --  产品大类编码
  , dim_fi_mr_product_dd.big_class_name AS product_big_class_name --  产品大类名称
  , dim_fi_mr_product_dd.middle_class_code AS product_mid_class_code --  产品中类编码
  , dim_fi_mr_product_dd.middle_class_name AS product_mid_class_name --  产品中类名称
  , dim_fi_mr_product_dd.small_class_code AS product_small_class_code --  产品小类编码
  , dim_fi_mr_product_dd.small_class_name AS product_small_class_name --  产品小类名称
  , dim_fi_mr_product_dd.model_lca AS model_lca_code --  产品型号生命周期编码
  , dim_fi_mr_product_dd.model_lca_name AS model_lca_name --  产品型号生命周期名称
  , ods_mr_aw_rul_revama_000001.product_type_code AS product_type_code --  产品类型编码
  , ods_mr_aw_rul_revama_000001.product_type_name AS product_type_name --  产品类型名称
  , vbrk.zdpmc AS shop_name --  门店名称
  , vbrk.fkimg AS bill_qty --  开票销量
  , vbrk.waerk AS qcy_code --  货币-交易币
  , vbrk.netwr AS rev_sale_amt --  销售收入
  , vbrk.kbetr_zk01 AS discount1_amt --  折扣3
  , vbrk.kbetr_zk03 AS discount3_amt --  折扣3
  , vbrk.kbetr_zk04 AS discount4_amt --  折扣4
  , vbrk.kbetr_zk05 AS discount5_amt --  折扣5
  , vbrk.kbetr_zk06 AS discount6_amt --  折扣6
  , vbrk.kbetr_zk34 AS discount34_amt --  折扣34
  , vbrk.kbetr_mwsi AS tax_rate --  税率
  , vbrk.kursk AS exchange_rate --  汇率
  , 'S600' AS system_src --  源系统
  , 'VBRP' AS ods_src --  源表
  , vbrk.vbeln AS bill_cert_id --  开票凭证
  , vbrk.posnr AS bill_cert_item --  开票凭证行项目
  , vbrk.sold_to AS sold_to_code --  售达方
  , sold_to.name1 AS sold_to_name --  售达方名称
  , vbrk.matkl AS material_group_code --  物料组
  , vbrk.ctp AS cp_company_code --  对方公司
  , vbrk.charg AS batch_id --  批次号
  , vbrk.kondm AS material_pricing_group_code --  物料定价组编码
  , vbrk.vtext AS material_pricing_group_name --  物料定价组名称
  , vbrk.aubel AS sale_cert_id --  销售凭证号
  , vbrk.aupos AS sale_cert_item --  销售凭证行项目
  , vbrk.auart AS sale_cert_type --  销售凭证类型
  , vbrk.vgbel AS reference_cert_id --  参考单据编号
  , vbrk.vgpos AS reference_cert_item --  参考单据项目号
  , vbrk.belnr AS acct_cert_id --  会计凭证号
  , vbrk.zzextno AS ext_order_id --  外部订单号
  , now() AS load_dt --  更新时间
  , date_format(fkdat,'%Y%m') AS dt_month --  年月
  , vbrk.acct_src_code
  , vbrk.acct_map_code
  , vbrk.bill_dt
  , ods_slt_s600_kna1.zkunnr_mdg AS cust_mdg_code
  , CASE WHEN vbrk.vkorg LIKE '2%' AND vbrk.ctp = '2023'
          THEN dim_fi_mr_product_dd.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
         WHEN vbrk.vkorg = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
         WHEN IFNULL(TRIM(vbrk.bus_range_code),'') <> ''
           THEN TRIM(vbrk.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
           THEN TRIM(bus_range_map1.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
           THEN TRIM(bus_range_map2.bus_range_code_order)
         ELSE ''
    END AS bus_range_code
  , '' AS bus_range_name
    , CASE WHEN (SUBSTR(vbrk.vkorg, 1, 2) IN ('62', '68') OR vbrk.vkorg IN ('6012', '6015') 
                 OR ((SUBSTR(vbrk.vkorg, 1, 2) = '12' OR SUBSTR(vbrk.vkorg, 1, 4) IN ('1180','1183')) AND (dim_fi_mr_product_dd.big_class_code = 'P02' OR vbrk.matnr LIKE 'X%'))
                )
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,Mapping_Bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN vbrk.matkl IN ('1209901','1209905','G209901') AND CASE WHEN vbrk.vkorg LIKE '2%' AND vbrk.ctp = '2023'
                                                                                            THEN dim_fi_mr_product_dd.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
                                                                                          WHEN vbrk.vkorg = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
                                                                                          WHEN IFNULL(TRIM(vbrk.bus_range_code),'') <> ''
                                                                                            THEN TRIM(vbrk.bus_range_code)
                                                                                          WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
                                                                                            THEN TRIM(bus_range_map1.bus_range_code)
                                                                                          WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
                                                                                            THEN TRIM(bus_range_map2.bus_range_code_order)
                                                                                          ELSE ''
                                                                                      END NOT IN ('2358','A004','2357')
                                THEN '1209901' ELSE NULL END ,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         vbrk.matkl
                         )
          ELSE '' 
     END AS marketing_dept_code
  , '' AS marketing_dept_name
  , vbrk.zzqdb_code AS comm_bu_code
  , vbrk.zzqdb AS comm_bu_name
  , vbrk.zzqdp_code AS cn_class_mark_code
  , vbrk.zzqdp AS cn_class_mark_name
  , vbrk.material_group_name AS material_group_name
  , CASE WHEN vbrk.vkorg = '6098' THEN vbrk.profitcenter_code
         WHEN mt2bd.profitcenter_code IS NOT NULL 
            THEN mt2bd.profitcenter_code 
         ELSE dim_fi_mr_product_dd.profitcenter_code 
    END AS profitcenter_code
  , CASE WHEN vbrk.vkorg = '6098' THEN NULL
         WHEN mt2bd.profitcenter_name IS NOT NULL 
           THEN mt2bd.profitcenter_name 
         ELSE dim_fi_mr_product_dd.profitcenter_name 
    END AS profitcenter_name
  , COALESCE(if(upper(dim_fi_mr_product_dd.sale_model_name)='无',null,upper(dim_fi_mr_product_dd.sale_model_name)),if(upper(dim_fi_mr_product_dd.zcusmodel)='无',null,upper(dim_fi_mr_product_dd.zcusmodel))) AS customer_model   --  客户型号
  , dim_fi_mr_product_dd.zcalasset AS zcalasset        --  按套统计
  , vbrk.kbetr_zk30 AS discount30_amt --  折扣34
  , vbrk.dmbtr AS rev_sale_bcy_amt --  销售收入-本位币
  , vbrk.ship_fact_code AS ship_fact_code
  , vbrk.asap_dt AS asap_dt
  , vbrk.br_company_code
  , vbrk.profitcenter_code AS src_profitcenter_code
  , vbrk.bus_range_code AS src_bus_range_code
    /*20260520 新增miniled类型字段*/
  , dim_fi_mr_product_dd.miniled_type_code
  , dim_fi_mr_product_dd.miniled_type_name
  , vbrk.invoice_code -- 金税发票号
  , vbrk.file_archive_no AS file_archive_no -- 落户纸号
FROM vbrk_2 AS vbrk
LEFT JOIN (SELECT kunnr,name1,zkunnr_mdg FROM ods.ods_slt_s600_kna1) ods_slt_s600_kna1
  ON vbrk.kunrg = ods_slt_s600_kna1.kunnr
LEFT JOIN dw.dim_customer_base_info_dd --  匹配客商主数据
  ON ods_slt_s600_kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
  ON ods_slt_s600_kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
 AND vbrk.vkorg = dim_customer_trade_info_dd.sale_org
 AND vbrk.matkl = dim_customer_trade_info_dd.material_group_code
LEFT JOIN dim.dim_fi_mr_product_dd --  匹配物料大表
  ON vbrk.matnr = dim_fi_mr_product_dd.matnr
LEFT JOIN ods.ods_slt_s600_kna1 AS sold_to --  匹配售达方数据
  ON vbrk.sold_to = sold_to.kunnr
LEFT JOIN (   SELECT batch,product_type_code,product_type_name,valid_fr,valid_to
                FROM dim.dim_rule_fi_mr_batch2protype_mapping a  
               WHERE valid_fr <= @year_month_day
                 AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
          ) AS ods_mr_aw_rul_revama_000001 --  批次对应产品类型映射表
   ON vbrk.charg = ods_mr_aw_rul_revama_000001.batch
 LEFT JOIN dw.dim_product_base_info_dd
   ON vbrk.matnr = dim_product_base_info_dd.product_code
  LEFT JOIN dim.dim_rule_fi_mr_Revenue_Company_SaleOrg_BUZScope_Mapping bus_range_map1
    ON vbrk.vkorg = bus_range_map1.company_code
   AND vbrk.vkbur = bus_range_map1.agency_code
  LEFT JOIN dim.dim_rule_fi_mr_BusScope_for_Company bus_range_map2
    ON vbrk.vkorg = bus_range_map2.company_code
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus) Mapping_Bus
    ON vbrk.matnr = Mapping_Bus.MATERIAL_CODE 
    LEFT JOIN (SELECT material_code,profitcenter_code,profitcenter_name FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON vbrk.matnr = mt2bd.material_code
    /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus2
    ON vbrk.matnr = Mapping_Bus2.MATERIAL_CODE
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus1
    ON vbrk.matnr = Mapping_Bus1.MATERIAL_CODE
   AND CASE WHEN vbrk.vkorg LIKE '2%' AND vbrk.ctp = '2023'
          THEN dim_fi_mr_product_dd.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
         WHEN vbrk.vkorg = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
         WHEN IFNULL(TRIM(vbrk.bus_range_code),'') <> ''
           THEN TRIM(vbrk.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
           THEN TRIM(bus_range_map1.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
           THEN TRIM(bus_range_map2.bus_range_code_order)
         ELSE ''
    END = Mapping_Bus1.bus_range_code

  -- 新增业务管理单元取数逻辑
    LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON REGEXP_REPLACE(CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE dim_fi_mr_product_dd.profitcenter_code END, '^0+', '') = profit_mapping0.profitcenter_code
   AND CASE WHEN vbrk.vkorg LIKE '2%' AND vbrk.ctp = '2023'
          THEN dim_fi_mr_product_dd.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
         WHEN vbrk.vkorg = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
         WHEN IFNULL(TRIM(vbrk.bus_range_code),'') <> ''
           THEN TRIM(vbrk.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
           THEN TRIM(bus_range_map1.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
           THEN TRIM(bus_range_map2.bus_range_code_order)
         ELSE ''
    END  = profit_mapping0.bus_range_code
  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON TRIM(vbrk.matkl) = TRIM(profit_mapping1.material_group_code)
   AND CASE WHEN vbrk.vkorg LIKE '2%' AND vbrk.ctp = '2023'
          THEN dim_fi_mr_product_dd.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
         WHEN vbrk.vkorg = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
         WHEN IFNULL(TRIM(vbrk.bus_range_code),'') <> ''
           THEN TRIM(vbrk.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
           THEN TRIM(bus_range_map1.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
           THEN TRIM(bus_range_map2.bus_range_code_order)
         ELSE ''
    END  = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON TRIM(vbrk.matkl) = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON REGEXP_REPLACE(CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE dim_fi_mr_product_dd.profitcenter_code END, '^0+', '') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE WHEN vbrk.vkorg LIKE '2%' AND vbrk.ctp = '2023'
          THEN dim_fi_mr_product_dd.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
         WHEN vbrk.vkorg = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
         WHEN IFNULL(TRIM(vbrk.bus_range_code),'') <> ''
           THEN TRIM(vbrk.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
           THEN TRIM(bus_range_map1.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
           THEN TRIM(bus_range_map2.bus_range_code_order)
         ELSE ''
    END = profit_mapping4.bus_range_code                 
   -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=1，物料+业务范围匹配，优先级1）
  LEFT JOIN (
      SELECT material_code, bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '1'
  ) cn_onoffline_map1
    ON vbrk.matnr = cn_onoffline_map1.material_code
   AND (vbrk.vkorg IN ('1180','118A','118B','1181') OR vbrk.vkorg LIKE '12%')
   AND CASE WHEN vbrk.vkorg LIKE '2%' AND vbrk.ctp = '2023'
          THEN dim_fi_mr_product_dd.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
         WHEN vbrk.vkorg = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
         WHEN IFNULL(TRIM(vbrk.bus_range_code),'') <> ''
           THEN TRIM(vbrk.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
           THEN TRIM(bus_range_map1.bus_range_code)
         WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
           THEN TRIM(bus_range_map2.bus_range_code_order)
         ELSE ''
    END = cn_onoffline_map1.bus_range_code
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=2，仅物料匹配，优先级2）
  LEFT JOIN (
      SELECT material_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '2'
  ) cn_onoffline_map2
    ON vbrk.matnr = cn_onoffline_map2.material_code
   AND (vbrk.vkorg IN ('1180','118A','118B','1181') OR vbrk.vkorg LIKE '12%')
;
/***********************************600收入日报插入结束*************************************/


/***********************************退货数据插入开始*************************************/

 INSERT INTO dwd.dwd_fi_mr_gp_detail_mi
 (

   dt_month,  --  年月
   year,  --  财务年
   month,  --  财务月
   company_code,  --  组织
   cust_code,  --  客商编码
   material_code,  --  物料编码
   material_name,  --  物料名称
   cust_name,  --  客商名称
   cust_unity_name,  --  统一客户组
   credit_level_name,  --  信用等级
   cust_nature_name,  --  单位性质
   cust_type_name,  --  客户类型
   channel_l1_code,  --  销售渠道一级编码
   channel_l1_name,  --  销售渠道一级名称
   channel_l2_code,  --  销售渠道二级编码
   channel_l2_name,  --  销售渠道二级名称
   channel_l3_code,  --  销售渠道三级编码
   channel_l3_name,  --  销售渠道三级名称
   marketing_mode_code,  --  销售模式编码
   marketing_mode_name,  --  销售模式名称
   onoffline_code,  --  线上线下编码
   onoffline_name,  --  线上线下名称
   product_line_code,  --  产品线编码
   product_line_name,  --  产品线名称
   sale_model_code,  --  销售型号编码
   sale_model_name,  --  销售型号名称
   brand_code,  --  品牌编码
   brand_name,  --  品牌名称
   spec_section_code,  --  规格段编码
   spec_section_name,  --  规格段名称
   product_shape_type_code,  --  产品形态分类编码
   product_shape_type_name,  --  产品形态分类名称
   product_sale_series_code,  --  产品套系编码
   product_sale_series_name,  --  产品套系名称
   quarter_method_code,  --  四分法编码（市场口径）
   quarter_method_name,  --  四分法名称（市场口径）
   product_stage_code,  --  产品阶段编码
   product_stage_name,  --  产品阶段名称
   price_range_code,  --  价格段编码
   price_range_name,  --  价格段名称
   model_code,  --  产品型号编码
   model_name,  --  产品型号名称
   product_series_code,  --  产品系列编码
   product_series_name,  --  产品系列名称
   market_pnt_code,  --  营销定位编码
   market_pnt_name,  --  营销定位名称
   tech_type_code,  --  技术类型编码
   tech_type_name,  --  技术类型名称
   is_miniled_code,
   product_big_class_code,  --  产品大类编码
   product_big_class_name,  --  产品大类名称
   product_mid_class_code,  --  产品中类编码
   product_mid_class_name,  --  产品中类名称
   product_small_class_code,  --  产品小类编码
   product_small_class_name,  --  产品小类名称
   model_lca_code,  --  产品型号生命周期编码
   model_lca_name,  --  产品型号生命周期名称
   product_type_code,  --  产品类型编码
   product_type_name,  --  产品类型名称
   bill_qty,  --  开票销量
   qcy_code,  --  交易币
   rev_sale_amt,  --  销售收入
   discount5_amt,  --  折扣5
   discount6_amt,  --  折扣6
   tax_rate,  --  税率
   --  price_tax_amt,  --  价税合计金额
   system_src,  --  源系统
   ods_src,  --  源表
   material_group_code,  --  物料组
   material_group_name,  --  物料组名称
   cp_company_code,  --  对方公司
   batch_id,  --  批次号
   bill_dt,  --  发票日期
   asap_dt,  --  ASAP日期
   material_pricing_group_code,  --  物料定价组编码
   material_pricing_group_name,  --  物料定价组名称
   sale_cert_id,  --  销售凭证号
   sale_cert_item,  --  销售凭证行项目
   load_dt,
   cust_mdg_code, --  客商编码mdg
   profitcenter_code, --  利润中心编码
   profitcenter_name,  --  利润中心名称
   customer_model,  --  客户型号
   zcalasset, --  按套统计
   bus_range_code, --  业务范围编码 UPDATE BY LYF 20251226
   bus_range_name, --  业务范围描述 UPDATE BY LYF 20251226
   cogs_amt,        --  销售成本 UPDATE BY LJY 20251231
   agency_code, --  办事处编码
   agency_name,  --  办事处名称
   marketing_dept_code,
   rev_sale_bcy_amt,
   ship_fact_code,
   sold_to_code,
   sold_to_name,
   comm_bu_code,
   comm_bu_name,
   cn_class_mark_code,
   cn_class_mark_name,
   br_company_code,
   src_profitcenter_code,
   src_bus_range_code,

  /*20260518 新增使用客商带出的相关信息字段*/
  channel_big_class_code,
  channel_big_class_name,
  channel_small_class_code,
  channel_small_class_name,
  ind_big_class_code,
  ind_big_class_name,
  ind_small_class_code,
  ind_small_class_name
      /*20260520 新增miniled类型字段*/
    , miniled_type_code
    , miniled_type_name

  )
WITH cust_data AS (
/*映射客商主数据*/
SELECT cust_code,
     cust_name, --  客商名称
     cust_unity_name, --  统一客户组
     credit_level, --  信用等级
     unit_nature_name, --  单位性质
     cust_group_name, --  客户类型
     is_channel_cust_type,
     is_ent_cust_type,
     is_fi_cust_type,
     com_1st_code, --  销售渠道一级编码
     com_1st_name, --  销售渠道一级名称
     com_2nd_code, --  销售渠道二级编码
     com_2nd_name, --  销售渠道二级名称
     com_3rd_code, --  销售渠道三级编码
     com_3rd_name, --  销售渠道三级名称
     channel_big_class_code,
     channel_big_class_name,
     channel_small_class_code,
     channel_small_class_name,
     ind_big_class_code,
     ind_big_class_name,
     ind_small_class_code,
     ind_small_class_name
  FROM dw.dim_customer_base_info_dd
),
yx_data AS (
  /*映射销售模式*/
SELECT DISTINCT LTRIM(cust_code,'0') cust_code,
       sale_org,
       material_group_code,
       market_mode_code, --  销售模式编码
       market_mode_name  --  销售模式名称
  FROM dw.dim_customer_trade_info_dd
  
),
pro_type AS (
  /* 获取产品类型 */
 SELECT * 
  FROM dim.dim_rule_fi_mr_batch2protype_mapping a  
 WHERE valid_fr <= @year_month_day
   AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
),
prod_data AS (
/*映射产品主数据 未入湖*/
SELECT matnr,
       prod_line,
       dim_fi_mr_product_dd.product_name AS maktx_mdm,
       /*product_line_code,*/ --  暂无
       prod_line_name,
       COALESCE(IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
            ) AS sale_model_code,
       -- COALESCE(TRIM(dim_fi_mr_product_dd.zzprdmodel),TRIM(dim_fi_mr_product_dd.zfacmodel),TRIM(dim_fi_mr_product_dd.pmodel_number)) AS sale_model_code,
       -- sale_model_name,
       /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
       COALESCE(IF(TRIM(dim_fi_mr_product_dd.sale_model_name)= '',NULL,TRIM(dim_fi_mr_product_dd.sale_model_name))
              ,IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
              ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
              ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
              ) AS sale_model_name,
       --  brand,
       --  brand_name,
       prod_stage_code,
       prod_stage_name,
       model_code,
       model_name,
       series_code,
       series_name,
       product_pos,
       product_pos_name,
       big_class_code,
       big_class_name,
       middle_class_code,
       middle_class_name,
       small_class_code,
       small_class_name,
       model_lca,
       model_lca_name,
       prod_suite_code, --  0901新增 产品套系编码
       prod_suite_name, --  0901新增 产品套系名称
       market_pos_code,
       market_pos_name,
       ac_ct_code, --  0904新增
       ac_ct_name, --  0904新增
       uled_type_code, --  0904新增
       uled_type_name, --  0904新增
       CASE WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013001' THEN '是'
         WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013002' THEN '否'
         ELSE ''
       END AS is_miniled_code, --  0904新增
       is_miniled_name --  0904新增
      ,profitcenter_code
      ,profitcenter_name
      ,zcusmodel
      ,zcalasset
      ,brand
      ,brand_name
      ,miniled_type_code
      ,miniled_type_name
      ,spec_range_code
      ,spec_range_name
      ,product_spec_code
      ,product_spec_name
      ,price_range_code
      ,price_range_name
    ,SCREEN_SIZE_CODE
    ,TOTAL_CAPACITY_CODE
    ,WASHING_CAPACITY_CODE
    ,SCREEN_SIZE_NAME
    ,TOTAL_CAPACITY_NAME
    ,WASHING_CAPACITY_NAME
    ,bus_range_code
  FROM dim.dim_fi_mr_product_dd
),
onoff_data AS (
/*详细逻辑-线上线下优先级1*/
SELECT batch_id,--  优先级
       b.cod_azienda AS company_code,--  公司
       cust_code,--  客商编码
       cust_ex_code,--  剔除 客商
       sold_to_code,--  售达方
       sold_to_ex_code,--  剔除 售达方
       c.cod_azienda AS cp_company_code,--  CTP
       product_line_src_code,--  映射前利润中心
       CASE WHEN onoffline_code = 'NULL' THEN '' ELSE onoffline_code END AS onoffline_code, --  映射后NF
       onoffline_name
  FROM dim.dim_rule_fi_mr_nf_mapping a
  LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
 WHERE valid_fr <= @year_month_day
   AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m')
 ),
 mrte_ctp AS (
/*映射CTP 交易公司*/
 SELECT LTRIM(cust_code,'0') AS kunnr --  客商编码
       ,NVL(cp_company_code_mr,cp_company_code) AS CTP --  对方公司编码
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S600'
   ),
ztmm018 AS --  订货未办退税报表
 (SELECT vbap.gsber AS bus_range_code,
     tgsbt.gtext AS bus_range_name,
     vbak.kunnr AS sold_to_code,
     kna1.name1 AS sold_to_name,
     vbap.prctr AS profitcenter_code,
     vbak.bstzd AS br_company_code,
     z.*
    FROM ods.ods_s600_ztmm018 Z
  LEFT JOIN ods.ods_slt_s600_vbap vbap
      ON Z.vbeln = vbap.vbeln
      AND Z.posnr = vbap.posnr
    LEFT JOIN (SELECT * FROM ods.ods_s600_tgsbt WHERE spras = 1) tgsbt --  业务范围描述
      ON vbap.gsber = tgsbt.gsber
    LEFT JOIN (SELECT * FROM ods.odsslt_s600_vbak) vbak --  销售凭证
      ON Z.vbeln = vbak.vbeln
    LEFT JOIN ods.ods_slt_s600_kna1 kna1 --  客商主数据
      ON vbak.kunnr = kna1.kunnr
   WHERE 1=1
     AND dt_month = SUBSTR(@year_month_day,1,6) 
     AND Z.matnr IN (SELECT matnr FROM prod_data)
     /*>=  date_format(@year_month_day, '%Y%m')
     AND dt_month < date_format(date_add(CAST(@year_month_day AS DATE), INTERVAL 1 MONTH), '%Y%m')*/
 ),
 ztmm018_1 AS 
(  --  匹配电商BU渠道细分编码和中国区品类标记编码
 SELECT DISTINCT
     ztmm018.*,zzqdb_code,zzqdb,zzqdp_code,zzqdp
     FROM ztmm018 ztmm018
     LEFT JOIN  dim.dim_mrs_s600_vbak_dd vbak
      ON COALESCE(LTRIM(ztmm018.vbeln,'0'),-1) = COALESCE(LTRIM(vbak.vbeln,'0'),-1)
      and ztmm018.vkorg = vbak.vkorg
      and vbak.audat >= DATE_FORMAT(DATE_ADD(ztmm018.erdat,INTERVAL -33 MONTH),'%Y%m%d')
      -- AND vbak.audat <= ztmm018.erdat
      )
 
SELECT 
   dt_month AS dt_month,  --  年月
   LEFT(dt_month,4) AS year,  --  财务年
   RIGHT(dt_month,2) AS month,  --  财务月
   ztmm018.vkorg AS company_code,  --  组织
   ztmm018.kunnr AS cust_code,  --  客商编码
   ztmm018.matnr AS material_code,  --  物料编码
   prod_data.maktx_mdm AS material_name,  --  物料名称
   kna1.name1 AS cust_name,  --  客商名称
   cust_data.cust_unity_name AS cust_unity_name,  --  统一客户组
   cust_data.credit_level AS credit_level_name,  --  信用等级
   cust_data.unit_nature_name AS cust_nature_name,  --  单位性质
   CASE WHEN cust_data.is_channel_cust_type IS NULL
  AND cust_data.is_ent_cust_type IS NULL
  AND cust_data.is_fi_cust_type IS NULL
  THEN NULL
  ELSE TRIM(
        REGEXP_REPLACE(
            CONCAT_WS(',',
                CASE WHEN cust_data.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                CASE WHEN cust_data.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                CASE WHEN cust_data.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
            ),
            '(^,)|(,$)',  
            ''            
        )
    )
    END AS cust_type_name,  --  客户类型
   cust_data.com_1st_code AS channel_l1_code,  --  销售渠道一级编码
   cust_data.com_1st_name AS channel_l1_name,  --  销售渠道一级名称
   cust_data.com_2nd_code AS channel_l2_code,  --  销售渠道二级编码
   cust_data.com_2nd_name AS channel_l2_name,  --  销售渠道二级名称
   cust_data.com_3rd_code AS channel_l3_code,  --  销售渠道三级编码
   cust_data.com_3rd_name AS channel_l3_name,  --  销售渠道三级名称
   yx_data.market_mode_code AS marketing_mode_code,  --  销售模式编码
   yx_data.market_mode_name AS marketing_mode_name,  --  销售模式名称
   CASE  -- ADD SXX XSJ 20260323 中国区特殊逻辑：公司=1180或12%时，先走cn_onoffline_map映射
        WHEN (ztmm018.vkorg IN ('1180','118A','118B','1181') OR ztmm018.vkorg LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_code
        WHEN (ztmm018.vkorg IN ('1180','118A','118B','1181') OR ztmm018.vkorg LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_code      
        WHEN LTRIM(ztmm018.kondm,'0') IN ('4','9') THEN '020_OFF_004'
        WHEN ztmm018.vkorg IN ('2052','2053') AND mrte_ctp.ctp IS NOT NULL THEN '020_OFF_006'
        WHEN ztmm018.vkorg IN ('2052','2053') AND mrte_ctp.ctp IS NULL THEN '020_OFF_007'
        ELSE COALESCE(onoff_data6.onoffline_code,onoff_data5.onoffline_code,onoff_data4.onoffline_code,onoff_data3.onoffline_code,onoff_data2.onoffline_code,onoff_data1.onoffline_code,'020_OFF_002')
   END AS onoffline_code,  --  线上线下编码
   CASE  -- ADD SXX XSJ 20260323 中国区特殊逻辑：公司=1180或12%时，先走cn_onoffline_map映射
        WHEN (ztmm018.vkorg IN ('1180','118A','118B','1181') OR ztmm018.vkorg LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_name
        WHEN (ztmm018.vkorg IN ('1180','118A','118B','1181') OR ztmm018.vkorg LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_name      
         WHEN LTRIM(ztmm018.kondm,'0') IN ('4','9') THEN '工程'
         WHEN ztmm018.vkorg IN ('2052','2053') AND mrte_ctp.ctp IS NOT NULL THEN '内配'
         WHEN ztmm018.vkorg IN ('2052','2053') AND mrte_ctp.ctp IS NULL THEN '外售'
        ELSE COALESCE(onoff_data6.onoffline_code,onoff_data5.onoffline_code,onoff_data4.onoffline_code,onoff_data3.onoffline_code,onoff_data2.onoffline_code,onoff_data1.onoffline_code,'020_OFF_002')
   END AS onoffline_name,  --  线上线下名称
   '' AS product_line_code,  --  产品线编码
   '' AS product_line_name,  --  产品线名称
   prod_data.sale_model_code AS sale_model_code,  --  销售型号编码
   prod_data.sale_model_name AS sale_model_name,  --  销售型号名称
   prod_data.brand AS brand_code,  --  品牌编码
   prod_data.brand_name AS brand_name,  --  品牌名称
   
    CASE WHEN prod_data.big_class_code = 'P01' THEN prod_data.SCREEN_SIZE_CODE
     WHEN prod_data.big_class_code = 'P02' THEN prod_data.SPEC_RANGE_CODE
     WHEN prod_data.big_class_code = 'P03' THEN prod_data.TOTAL_CAPACITY_CODE
     WHEN prod_data.big_class_code = 'P04' THEN prod_data.WASHING_CAPACITY_CODE
  END AS spec_section_code, --  规格段编码
    CASE WHEN prod_data.big_class_code = 'P01' THEN prod_data.SCREEN_SIZE_NAME
     WHEN prod_data.big_class_code = 'P02' THEN prod_data.SPEC_RANGE_NAME
     WHEN prod_data.big_class_code = 'P03' THEN prod_data.TOTAL_CAPACITY_NAME
     WHEN prod_data.big_class_code = 'P04' THEN prod_data.WASHING_CAPACITY_NAME
  END  AS spec_section_name, --  规格段名称
  
   prod_data.product_spec_code AS product_shape_type_code,  --  产品形态分类编码
   prod_data.product_spec_name AS product_shape_type_name,  --  产品形态分类名称
   prod_data.prod_suite_code AS product_sale_series_code,  --  产品套系编码
   prod_data.prod_suite_name AS product_sale_series_name,  --  产品套系名称
   '' AS quarter_method_code,  --  四分法编码（市场口径）
   '' AS quarter_method_name,  --  四分法名称（市场口径）
   prod_data.prod_stage_code AS product_stage_code,  --  产品阶段编码
   prod_data.prod_stage_name AS product_stage_name,  --  产品阶段名称
   prod_data.price_range_code AS price_range_code,  --  价格段编码
   prod_data.price_range_name AS price_range_name,  --  价格段名称
   prod_data.model_code AS model_code,  --  产品型号编码
   prod_data.model_name AS model_name,  --  产品型号名称
   prod_data.series_code AS product_series_code,  --  产品系列编码
   prod_data.series_name AS product_series_name,  --  产品系列名称
   prod_data.market_pos_code AS market_pnt_code,  --  营销定位编码
   prod_data.market_pos_name AS market_pnt_name,  --  营销定位名称
   prod_data.ac_ct_code AS tech_type_code,  --  技术类型编码
   prod_data.ac_ct_name AS tech_type_name,  --  技术类型名称
   prod_data.is_miniled_code AS is_miniled_code,
   prod_data.big_class_code AS product_big_class_code,  --  产品大类编码
   prod_data.big_class_name AS product_big_class_name,  --  产品大类名称
   prod_data.middle_class_code AS product_mid_class_code,  --  产品中类编码
   prod_data.middle_class_name AS product_mid_class_name,  --  产品中类名称
   prod_data.small_class_code AS product_small_class_code,  --  产品小类编码
   prod_data.small_class_name AS product_small_class_name,  --  产品小类名称
   prod_data.model_lca AS model_lca_code,  --  产品型号生命周期编码
   prod_data.model_lca_name AS model_lca_name,  --  产品型号生命周期名称
   pro_type.product_type_code AS product_type_code,  --  产品类型编码
   pro_type.product_type_name AS product_type_name,  --  产品类型名称
   IFNULL(ztmm018.fkimg_t,0) AS bill_qty,  --  开票销量
   '' AS qcy_code,  --  交易币
   IFNULL(ztmm018.kwert,0) / (1 + IFNULL(ztmm018.taxgl,0)) AS rev_sale_amt,  --  销售收入
   IFNULL(ztmm018.zk05,0) AS discount5_amt,  --  折扣5
   IFNULL(ztmm018.zk06,0) AS discount6_amt,  --  折扣6
   IFNULL(ztmm018.taxgl,0) AS tax_rate,  --  税率
   'S600' AS system_src,  --  源系统
   'ZTSO04_TH' AS ods_src,  --  源表
   REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') AS material_group_code,  --  物料组
   t023t.wgbez AS material_group_name,  --  物料组名称
   mrte_ctp.ctp AS cp_company_code,  --  对方公司
   ztmm018.charg AS batch_id,  --  批次号
   ztmm018.erdat AS bill_dt,  --  发票日期
   ztmm018.wadat_ist AS asap_dt,  --  ASAP日期
   ztmm018.kondm AS material_pricing_group_code,  --  物料定价组编码
   ztmm018.zvtext AS material_pricing_group_name,  --  物料定价组名称
   ztmm018.vbeln AS sale_cert_id,  --  销售凭证号
   ztmm018.posnr AS sale_cert_item,  --  销售凭证行项目
   NOW() AS load_dt,
   zkunnr_mdg AS cust_mdg_code, --  客商编码mdg
   CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE prod_data.profitcenter_code END AS profitcenter_code, --  利润中心编码
   CASE WHEN mt2bd.profitcenter_name IS NOT NULL THEN mt2bd.profitcenter_name ELSE prod_data.profitcenter_name END AS profitcenter_name,  --  利润中心名称
   COALESCE(if(upper(prod_data.sale_model_name)='无',null,upper(prod_data.sale_model_name)),if(upper(prod_data.zcusmodel)='无',null,upper(prod_data.zcusmodel))) AS customer_model,  --  客户型号
   prod_data.zcalasset AS zcalasset, --  按套统计
   CASE WHEN ztmm018.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
          THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
        WHEN IFNULL(TRIM(ztmm018.bus_range_code),'') <> ''
          THEN TRIM(ztmm018.bus_range_code)
        /*WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
          THEN TRIM(bus_range_map1.bus_range_code)*/
        WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
          THEN TRIM(bus_range_map2.bus_range_code_order)
        ELSE ''
   END AS bus_range_code, --  业务范围编码 UPDATE BY LYF 20251226
   '' AS bus_range_name, --  业务范围描述 UPDATE BY LYF 20251226
   ztmm018.dmbtr AS cogs_amt,        --  销售成本 UPDATE BY LJY 20251231
   '' AS agency_code, --  办事处编码
   '' AS agency_name,  --  办事处名称
   CASE WHEN (SUBSTR(ztmm018.vkorg, 1, 2) IN ('62', '68') OR ztmm018.vkorg IN ('6012', '6015') 
              OR ((SUBSTR(ztmm018.vkorg, 1, 2) = '12' OR SUBSTR(ztmm018.vkorg, 1, 4) IN ('1180','1183')) AND prod_data.big_class_code = 'P02')
             )
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,Mapping_Bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') IN ('1209901','1209905','G209901') 
                         AND CASE WHEN ztmm018.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
                                    THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
                                  WHEN IFNULL(TRIM(ztmm018.bus_range_code),'') <> ''
                                    THEN TRIM(ztmm018.bus_range_code)
                                  /*WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
                                    THEN TRIM(bus_range_map1.bus_range_code)*/
                                  WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
                                    THEN TRIM(bus_range_map2.bus_range_code_order)
                                  ELSE ''
                            END NOT IN ('2358','A004','2357')
                THEN '1209901' ELSE NULL END ,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','')
                         )
          ELSE '' 
     END AS marketing_dept_code,
   IFNULL(ztmm018.kwert,0) / (1 + IFNULL(ztmm018.taxgl,0)) AS rev_sale_bcy_amt,
   ztmm018.werks AS ship_fact_code,
   ztmm018.sold_to_code AS sold_to_code,
   ztmm018.sold_to_name AS sold_to_name,
   ztmm018.zzqdb_code AS comm_bu_code,
   ztmm018.zzqdb AS comm_bu_name,
   ztmm018.zzqdp_code AS cn_class_mark_code,
   ztmm018.zzqdp AS cn_class_mark_name,
   ztmm018.br_company_code AS br_company_code,
   ztmm018.profitcenter_code AS src_profitcenter_code,
   ztmm018.bus_range_code AS src_bus_range_code,

   cust_data.channel_big_class_code AS channel_big_class_code,
   cust_data.channel_big_class_name AS channel_big_class_name,
   cust_data.channel_small_class_code AS channel_small_class_code,
   cust_data.channel_small_class_name AS channel_small_class_name,
   cust_data.ind_big_class_code AS ind_big_class_code,
   cust_data.ind_big_class_name AS ind_big_class_name,
   cust_data.ind_small_class_code AS ind_small_class_code,
   cust_data.ind_small_class_name AS ind_small_class_name
    /*20260520 新增miniled类型字段*/
  , prod_data.miniled_type_code
  , prod_data.miniled_type_name
FROM ztmm018_1 ztmm018
  LEFT JOIN prod_data prod_data
    ON ztmm018.matnr = prod_data.matnr
  LEFT JOIN (SELECT kunnr,name1,zkunnr_mdg FROM ods.ods_slt_s600_kna1) kna1
    ON ztmm018.kunnr = LTRIM(kna1.kunnr,0)
  LEFT JOIN cust_data cust_data
    ON kna1.zkunnr_mdg = cust_data.cust_code
  LEFT JOIN yx_data yx_data
    ON kna1.zkunnr_mdg = yx_data.cust_code
   AND ztmm018.vkorg = yx_data.sale_org
   AND REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') = yx_data.material_group_code
  LEFT JOIN pro_type pro_type
    ON ztmm018.charg = pro_type.batch
  LEFT JOIN mrte_ctp mrte_ctp --  映射CTP
    ON LTRIM(ztmm018.kunnr,'0') = mrte_ctp.kunnr
  LEFT JOIN onoff_data onoff_data1
    ON ztmm018.vkorg = onoff_data1.company_code
   AND onoff_data1.batch_id = '1'
  LEFT JOIN onoff_data onoff_data2
    ON ztmm018.vkorg = onoff_data2.company_code
   AND (LTRIM(ztmm018.kunnr,'0') = onoff_data2.cust_code
        OR
        onoff_data2.cust_code IS NULL) --  处理 包含客商编码
   AND onoff_data2.batch_id = '2'

  LEFT JOIN onoff_data onoff_data3
    ON ztmm018.vkorg = onoff_data3.company_code
   AND (LTRIM(ztmm018.kunnr,'0') = onoff_data3.cust_code
        OR
        onoff_data3.cust_code IS NULL) --  处理 包含客商编码
   AND (LTRIM(ztmm018.sold_to_code,'0') = onoff_data3.sold_to_code
        OR
        onoff_data3.sold_to_code IS NULL) --  处理 包含售达方
   AND onoff_data3.batch_id = '3'
  LEFT JOIN onoff_data onoff_data4
    ON (LTRIM(ztmm018.kunnr,'0') = onoff_data4.cust_code
        OR
        onoff_data4.cust_code IS NULL) --  处理 包含客商编码
   AND (LTRIM(ztmm018.sold_to_code,'0') = onoff_data4.sold_to_code
        OR
        onoff_data4.sold_to_code IS NULL) --  处理 包含售达方
   AND onoff_data4.batch_id = '4'


  LEFT JOIN onoff_data onoff_data5
    ON ztmm018.vkorg = onoff_data5.company_code
   AND mrte_ctp.ctp = onoff_data5.cp_company_code --  处理对方公司
   AND onoff_data5.batch_id = '5'

   LEFT JOIN onoff_data onoff_data6
    ON ztmm018.vkorg = onoff_data6.company_code
   AND mrte_ctp.ctp = onoff_data6.cp_company_code --  处理对方公司
   AND (LTRIM(ztmm018.sold_to_code,'0') = onoff_data6.sold_to_code
        OR
        onoff_data6.sold_to_code IS NULL) --  处理 包含售达方
   AND onoff_data6.batch_id = '6'
  LEFT JOIN dim.dim_rule_fi_mr_busscope_for_company bus_range_map2
    ON ztmm018.vkorg = bus_range_map2.company_code
    LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON ztmm018.matnr = mt2bd.material_code
   LEFT JOIN ods.ods_s600_t023t t023t --  物料组描述
    ON REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') = t023t.matkl
   AND t023t.spras = '1'
     /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) mapping_bus2
    ON ztmm018.matnr = mapping_bus2.material_code
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) mapping_bus1
    ON ztmm018.matnr = mapping_bus1.material_code
   AND CASE WHEN ztmm018.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
          THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
        WHEN IFNULL(TRIM(ztmm018.bus_range_code),'') <> ''
          THEN TRIM(ztmm018.bus_range_code)
        /*WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
          THEN TRIM(bus_range_map1.bus_range_code)*/
        WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
          THEN TRIM(bus_range_map2.bus_range_code_order)
        ELSE ''
   END = mapping_bus1.bus_range_code

  -- 新增业务管理单元取数逻辑
  LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON REGEXP_REPLACE(CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE prod_data.profitcenter_code END, '^0+', '') = profit_mapping0.profitcenter_code
   AND CASE WHEN ztmm018.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
          THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
        WHEN IFNULL(TRIM(ztmm018.bus_range_code),'') <> ''
          THEN TRIM(ztmm018.bus_range_code)
        /*WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
          THEN TRIM(bus_range_map1.bus_range_code)*/
        WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
          THEN TRIM(bus_range_map2.bus_range_code_order)
        ELSE ''
   END  = profit_mapping0.bus_range_code

  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping1.material_group_code)
   AND CASE WHEN ztmm018.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
          THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
        WHEN IFNULL(TRIM(ztmm018.bus_range_code),'') <> ''
          THEN TRIM(ztmm018.bus_range_code)
        /*WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
          THEN TRIM(bus_range_map1.bus_range_code)*/
        WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
          THEN TRIM(bus_range_map2.bus_range_code_order)
        ELSE ''
   END  = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
               WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON REGEXP_REPLACE(CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE prod_data.profitcenter_code END, '^0+', '') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE WHEN ztmm018.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
          THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
        WHEN IFNULL(TRIM(ztmm018.bus_range_code),'') <> ''
          THEN TRIM(ztmm018.bus_range_code)
        /*WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
          THEN TRIM(bus_range_map1.bus_range_code)*/
        WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
          THEN TRIM(bus_range_map2.bus_range_code_order)
        ELSE ''
   END = profit_mapping4.bus_range_code 
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=1，物料+业务范围匹配，优先级1）
  LEFT JOIN (
      SELECT material_code, bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '1'
  ) cn_onoffline_map1
    ON ztmm018.matnr = cn_onoffline_map1.material_code
   AND (ztmm018.vkorg IN ('1180','118A','118B','1181') OR ztmm018.vkorg LIKE '12%')
   AND CASE WHEN ztmm018.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
          THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
        WHEN IFNULL(TRIM(ztmm018.bus_range_code),'') <> ''
          THEN TRIM(ztmm018.bus_range_code)
        /*WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
          THEN TRIM(bus_range_map1.bus_range_code)*/
        WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
          THEN TRIM(bus_range_map2.bus_range_code_order)
        ELSE ''
   END = cn_onoffline_map1.bus_range_code
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=2，仅物料匹配，优先级2）
  LEFT JOIN (
      SELECT material_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '2'
  ) cn_onoffline_map2
    ON ztmm018.matnr = cn_onoffline_map2.material_code
   AND (ztmm018.vkorg IN ('1180','118A','118B','1181') OR ztmm018.vkorg LIKE '12%')        
   ;
/***********************************退货数据插入结束*************************************/


/***********************************出库数据插入开始*************************************/

INSERT INTO dwd.dwd_fi_mr_gp_detail_mi
(dt_month,  --  年月
 year,  --  财务年
 month, --  财务月
 company_code,  --  组织
 cust_code, --  客商编码
 material_code, --  物料编码
 material_name, --  物料名称
 cust_name, --  客商名称
 cust_unity_name,   --  统一客户组
 credit_level_name, --  信用等级
 cust_nature_name,  --  单位性质
 cust_type_name,    --  客户类型
 channel_l1_code,   --  销售渠道一级编码
 channel_l1_name,   --  销售渠道一级名称
 channel_l2_code,   --  销售渠道二级编码
 channel_l2_name,   --  销售渠道二级名称
 channel_l3_code,   --  销售渠道三级编码
 channel_l3_name,   --  销售渠道三级名称
 marketing_mode_code,   --  销售模式编码
 marketing_mode_name,   --  销售模式名称
 onoffline_code,    --  线上线下编码
 onoffline_name,    --  线上线下名称
 product_line_code, --  产品线编码
 product_line_name, --  产品线名称
 sale_model_code,   --  销售型号编码
 sale_model_name,   --  销售型号名称
 brand_code,    --  品牌编码
 brand_name,    --  品牌名称
 spec_section_code, --  规格段编码
 spec_section_name, --  规格段名称
 product_shape_type_code,   --  产品形态分类编码
 product_shape_type_name,   --  产品形态分类名称
 product_sale_series_code,  --  产品套系编码
 product_sale_series_name,  --  产品套系名称
 quarter_method_code,   --  四分法编码（市场口径）
 quarter_method_name,   --  四分法名称（市场口径）
 product_stage_code,    --  产品阶段编码
 product_stage_name,    --  产品阶段名称
 price_range_code,  --  价格段编码
 price_range_name,  --  价格段名称
 model_code,    --  产品型号编码
 model_name,    --  产品型号名称
 product_series_code,   --  产品系列编码
 product_series_name,   --  产品系列名称
 market_pnt_code,   --  营销定位编码
 market_pnt_name,   --  营销定位名称
 tech_type_code,    --  技术类型编码
 tech_type_name,    --  技术类型名称
 is_miniled_code, --  是否MiniLED编码
 product_big_class_code,    --  产品大类编码
 product_big_class_name,    --  产品大类名称
 product_mid_class_code,    --  产品中类编码
 product_mid_class_name,    --  产品中类名称
 product_small_class_code,  --  产品小类编码
 product_small_class_name,  --  产品小类名称
 model_lca_code,    --  产品型号生命周期编码
 model_lca_name,    --  产品型号生命周期名称
 product_type_code, --  产品类型编码
 product_type_name, --  产品类型名称
 bill_qty,  --  开票销量
 ship_qty,  --  发货数量
 order_qty, --  订单数量
 qcy_code,  --  交易币
 rev_sale_amt,  --  销售收入
 --  kzwi1, --  销售收入原始
 system_src,    --  源系统
 ods_src,   --  源表
 sold_to_code,  --  售达方
 sold_to_name,  --  售达方名称
 material_group_code,   --  物料组
 material_group_name,   --  物料组名称
 cp_company_code,   --  对方公司
 batch_id,  --  批次号
 bill_dt,   --  发票日期
 asap_dt,   --  过账日期
--  delivery_dt, --  交货日期
 material_pricing_group_code,   --  物料定价组编码
 material_pricing_group_name,   --  物料定价组名称
 sale_cert_id,  --  销售凭证号
 sale_cert_item,    --  销售凭证行项目
 sale_cert_type,    --  销售凭证类型
 goods_movement_status, --  货物移动状态
 bill_status,   --  单据状态
 load_dt,--  更新时间
 cust_mdg_code, --  客商编码mdg  
 profitcenter_code, --  利润中心编码
 profitcenter_name,   --  利润中心名称
 customer_model,  --  客户型号
 zcalasset,  --  按套统计
 bus_range_code, --  业务范围编码 UPDATE BY LYF 20251226
 bus_range_name, --  业务范围描述 UPDATE BY LYF 20251226
 agency_code,
 agency_name,
 marketing_dept_code,
 rev_sale_bcy_amt,
 ship_fact_code,
 comm_bu_code,
 comm_bu_name,
 cn_class_mark_code,
 cn_class_mark_name,
 src_profitcenter_code,
 src_bus_range_code,
/*20260518 新增使用客商带出的相关信息字段*/
channel_big_class_code,
channel_big_class_name,
channel_small_class_code,
channel_small_class_name,
ind_big_class_code,
ind_big_class_name,
ind_small_class_code,
ind_small_class_name
    /*20260520 新增miniled类型字段*/
  , miniled_type_code
  , miniled_type_name
 )
WITH cust_data AS (
/*映射客商主数据*/
SELECT cust_code,
     cust_name, --  客商名称
     cust_unity_name, --  统一客户组
     credit_level, --  信用等级
     unit_nature_name, --  单位性质
     cust_group_name, --  客户类型
     is_channel_cust_type,
     is_ent_cust_type,
     is_fi_cust_type,
     com_1st_code, --  销售渠道一级编码
     com_1st_name, --  销售渠道一级名称
     com_2nd_code, --  销售渠道二级编码
     com_2nd_name, --  销售渠道二级名称
     com_3rd_code, --  销售渠道三级编码
     com_3rd_name, --  销售渠道三级名称
     channel_big_class_code,
     channel_big_class_name,
     channel_small_class_code,
     channel_small_class_name,
     ind_big_class_code,
     ind_big_class_name,
     ind_small_class_code,
     ind_small_class_name
  FROM dw.dim_customer_base_info_dd
),
yx_data AS (
  /*映射销售模式*/
SELECT DISTINCT LTRIM(cust_code,'0') cust_code,
       sale_org,
       material_group_code,
       market_mode_code, --  销售模式编码
       market_mode_name  --  销售模式名称
  FROM dw.dim_customer_trade_info_dd
  
),
pro_type AS (
  /* 获取产品类型 */
 SELECT * 
  FROM dim.dim_rule_fi_mr_batch2protype_mapping a  
 WHERE valid_fr <= @year_month_day
   AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
),
prod_data AS (
/*映射产品主数据 未入湖*/
SELECT matnr,
       prod_line,
       dim_fi_mr_product_dd.product_name AS maktx_mdm,
       
       -- COALESCE(TRIM(dim_fi_mr_product_dd.maktx_s600),TRIM(dim_fi_mr_product_dd.maktx_s800),TRIM(dim_fi_mr_product_dd.maktx_s900),TRIM(dim_fi_mr_product_dd.maktx_s810),TRIM(dim_fi_mr_product_dd.maktx_mdm)) AS maktx_mdm,
       /*product_line_code,*/ --  暂无
       prod_line_name,
       COALESCE(IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
            ) AS sale_model_code,
       -- COALESCE(TRIM(dim_fi_mr_product_dd.zzprdmodel),TRIM(dim_fi_mr_product_dd.zfacmodel),TRIM(dim_fi_mr_product_dd.pmodel_number)) AS sale_model_code,
       -- sale_model_name,
       /*alter by 20260811 xiaoaychao.ex 销售型号名称逻辑更新*/
       COALESCE(IF(TRIM(dim_fi_mr_product_dd.sale_model_name)= '',NULL,TRIM(dim_fi_mr_product_dd.sale_model_name))
              ,IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
              ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
              ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
              ) AS sale_model_name,
       --  brand,
       --  brand_name,
       prod_stage_code,
       prod_stage_name,
       model_code,
       model_name,
       series_code,
       series_name,
       product_pos,
       product_pos_name,
       big_class_code,
       big_class_name,
       middle_class_code,
       middle_class_name,
       small_class_code,
       small_class_name,
       model_lca,
       model_lca_name,
       prod_suite_code, --  0901新增 产品套系编码
       prod_suite_name, --  0901新增 产品套系名称
       market_pos_code,
       market_pos_name,
       ac_ct_code, --  0904新增
       ac_ct_name, --  0904新增
       uled_type_code, --  0904新增
       uled_type_name, --  0904新增
       CASE WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013001' THEN '是'
         WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013002' THEN '否'
         ELSE ''
    END AS is_miniled_code, --  0904新增
       is_miniled_name --  0904新增
     ,profitcenter_code
     ,profitcenter_name
     ,zcusmodel
     ,zcalasset
     ,brand
     ,brand_name
     /*20260520 新增miniled类型字段*/
     , miniled_type_code
     , miniled_type_name
      
      ,spec_range_code
      ,spec_range_name
      ,product_spec_code
      ,product_spec_name
      ,price_range_code
      ,price_range_name
    ,SCREEN_SIZE_CODE
    ,TOTAL_CAPACITY_CODE
    ,WASHING_CAPACITY_CODE
    ,SCREEN_SIZE_NAME
    ,TOTAL_CAPACITY_NAME
    ,WASHING_CAPACITY_NAME
    ,bus_range_code
  FROM dim.dim_fi_mr_product_dd
),
brand_data AS(
  /* 品牌主数据 */
SELECT product_code,
       brand,
       brand_name
  FROM dw.dim_product_base_info_dd
),
onoff_data AS (
/*详细逻辑-线上线下优先级1*/
SELECT batch_id,--  优先级
       b.cod_azienda AS company_code,--  公司
       cust_code,--  客商编码
       cust_ex_code,--  剔除 客商
       sold_to_code,--  售达方
       sold_to_ex_code,--  剔除 售达方
       c.cod_azienda AS cp_company_code,--  ctp
       product_line_src_code,--  映射前利润中心
       CASE WHEN onoffline_code = 'NULL' THEN '' ELSE onoffline_code END AS onoffline_code, --  映射后NF
       onoffline_name
  FROM dim.dim_rule_fi_mr_nf_mapping a 
   LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
 WHERE valid_fr <= @year_month_day
   AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m')
 ),
 mrte_ctp AS (
/*映射CTP 交易公司*/
 SELECT LTRIM(cust_code,'0') AS kunnr --  客商编码
       ,NVL(cp_company_code_mr,cp_company_code) AS ctp --  对方公司编码
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S600'
   ),
 zsd020 AS --  已出库未办税
 (SELECT Z.*,
  vbap.netpr, --  净价值
  vbrk.fkdat,
  vbap.gsber AS bus_range_code, --  业务范围编码
  tgsbt.gtext AS bus_range_name, --  业务范围描述
  tvkbt.bezei AS agency_name,
  vbap.prctr AS profitcenter_code
   FROM ods.ods_s600_zsd020z Z
   LEFT JOIN ods.ods_slt_s600_vbap vbap --  获取金额
     ON Z.vbeln = vbap.vbeln
    AND Z.posnr = vbap.posnr
   LEFT JOIN ods.ods_slt_s600_vbrk vbrk
     ON Z.vbeln = vbrk.vbeln
   LEFT JOIN (SELECT * FROM ods.ods_s600_tgsbt WHERE spras = 1) tgsbt --  获取业务范围描述
      ON vbap.gsber = tgsbt.gsber
   LEFT JOIN ods.ods_s600_tvkbt tvkbt --  办事处描述
     ON Z.vkbur = tvkbt.vkbur
    AND tvkbt.spras = '1'
  WHERE Z.dt_month = LEFT(@year_month_day,6)
    AND Z.matnr IN (SELECT matnr FROM prod_data)
 )
,
 zsd020_1 AS 
(  --  匹配电商BU渠道细分编码和中国区品类标记编码
 SELECT DISTINCT
     zsd020.*,zzqdb_code,zzqdb,zzqdp_code,zzqdp
     FROM zsd020 zsd020
     LEFT JOIN  dim.dim_mrs_s600_vbak_dd vbak
      ON COALESCE(LTRIM(zsd020.vbeln,'0'),-1) = COALESCE(LTRIM(vbak.vbeln,'0'),-1)
      and zsd020.vkorg = vbak.vkorg
      and vbak.audat >= DATE_FORMAT(DATE_ADD(zsd020.erdat, INTERVAL -33 MONTH), '%Y%m%d')
      -- AND vbak.audat <= zsd020.erdat
      )

 
SELECT 
  zsd020z.dt_month AS dt_month,  --  年月
  LEFT(zsd020z.dt_month,4) AS year,  --  财务年
  RIGHT(zsd020z.dt_month,2) AS month, --  财务月
  zsd020z.vkorg AS company_code,  --  组织
  zsd020z.kunrg AS cust_code, --  客商编码
  zsd020z.matnr AS material_code, --  物料编码
  prod_data.maktx_mdm AS material_name, --  物料名称
  kna1.name1 AS cust_name, --  客商名称
  cust_data.cust_unity_name AS cust_unity_name,   --  统一客户组
  cust_data.credit_level AS credit_level_name, --  信用等级
  cust_data.unit_nature_name AS cust_nature_name,  --  单位性质
  CASE WHEN cust_data.is_channel_cust_type IS NULL
  AND cust_data.is_ent_cust_type IS NULL
  AND cust_data.is_fi_cust_type IS NULL
  THEN NULL
  ELSE TRIM(
        REGEXP_REPLACE(
            CONCAT_WS(',',
                CASE WHEN cust_data.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                CASE WHEN cust_data.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                CASE WHEN cust_data.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
            ),
            '(^,)|(,$)',  
            ''            
        )
    )
    END AS cust_type_name,  --  客户类型
  cust_data.com_1st_code AS channel_l1_code,   --  销售渠道一级编码
  cust_data.com_1st_name AS channel_l1_name,   --  销售渠道一级名称
  cust_data.com_2nd_code AS channel_l2_code,   --  销售渠道二级编码
  cust_data.com_2nd_name AS channel_l2_name,   --  销售渠道二级名称
  cust_data.com_3rd_code AS channel_l3_code,   --  销售渠道三级编码
  cust_data.com_3rd_name AS channel_l3_name,   --  销售渠道三级名称
  yx_data.market_mode_code AS marketing_mode_code,   --  销售模式编码
  yx_data.market_mode_name AS marketing_mode_name,   --  销售模式名称
  CASE   -- ADD SXX XSJ 20260323 中国区特殊逻辑：公司=1180或12%时，先走cn_onoffline_map映射
         WHEN (zsd020z.vkorg IN ('1180','118A','118B','1181') OR zsd020z.vkorg LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_code
         WHEN (zsd020z.vkorg IN ('1180','118A','118B','1181') OR zsd020z.vkorg LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_code        
         WHEN LTRIM(zsd020z.kondm,'0') IN ('4','9') THEN '020_OFF_004'
         WHEN zsd020z.vkorg IN ('2052','2053') AND mrte_ctp.ctp IS NOT NULL THEN '020_OFF_006'
         WHEN zsd020z.vkorg IN ('2052','2053') AND mrte_ctp.ctp IS NULL THEN '020_OFF_007'
         ELSE COALESCE(onoff_data6.onoffline_code,onoff_data5.onoffline_code,onoff_data4.onoffline_code,onoff_data3.onoffline_code,onoff_data2.onoffline_code,onoff_data1.onoffline_code,'020_OFF_002')
    END AS onoffline_code,    --  线上线下编码
  CASE    -- ADD SXX XSJ 20260323 中国区特殊逻辑：公司=1180或12%时，先走cn_onoffline_map映射
         WHEN (zsd020z.vkorg IN ('1180','118A','118B','1181') OR zsd020z.vkorg LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_name
         WHEN (zsd020z.vkorg IN ('1180','118A','118B','1181') OR zsd020z.vkorg LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_name         
         WHEN LTRIM(zsd020z.kondm,'0') IN ('4','9') THEN '工程'
         WHEN zsd020z.vkorg IN ('2052','2053') AND mrte_ctp.ctp IS NOT NULL THEN '内配'
         WHEN zsd020z.vkorg IN ('2052','2053') AND mrte_ctp.ctp IS NULL THEN '外售'
         ELSE COALESCE(onoff_data6.onoffline_name,onoff_data5.onoffline_name,onoff_data4.onoffline_name,onoff_data3.onoffline_name,onoff_data2.onoffline_name,onoff_data1.onoffline_name,'零售-传统零售')
    END AS onoffline_name,    --  线上线下名称
  '' AS product_line_code, --  产品线编码
  '' AS product_line_name, --  产品线名称
  prod_data.sale_model_code AS sale_model_code,   --  销售型号编码
  prod_data.sale_model_name AS sale_model_name,   --  销售型号名称
  prod_data.brand AS brand_code,    --  品牌编码
  prod_data.brand_name AS brand_name,    --  品牌名称
  CASE WHEN prod_data.big_class_code = 'P01' THEN prod_data.SCREEN_SIZE_CODE
     WHEN prod_data.big_class_code = 'P02' THEN prod_data.SPEC_RANGE_CODE
     WHEN prod_data.big_class_code = 'P03' THEN prod_data.TOTAL_CAPACITY_CODE
     WHEN prod_data.big_class_code = 'P04' THEN prod_data.WASHING_CAPACITY_CODE
  END AS spec_section_code, --  规格段编码
    CASE WHEN prod_data.big_class_code = 'P01' THEN prod_data.SCREEN_SIZE_NAME
     WHEN prod_data.big_class_code = 'P02' THEN prod_data.SPEC_RANGE_NAME
     WHEN prod_data.big_class_code = 'P03' THEN prod_data.TOTAL_CAPACITY_NAME
     WHEN prod_data.big_class_code = 'P04' THEN prod_data.WASHING_CAPACITY_NAME
  END  AS spec_section_name, --  规格段名称
  prod_data.product_spec_code AS product_shape_type_code,   --  产品形态分类编码
  prod_data.product_spec_name AS product_shape_type_name,   --  产品形态分类名称
  prod_data.prod_suite_code AS product_sale_series_code,  --  产品套系编码
  prod_data.prod_suite_name AS product_sale_series_name,  --  产品套系名称
  '' AS quarter_method_code,   --  四分法编码（市场口径）
  '' AS quarter_method_name,   --  四分法名称（市场口径）
  prod_data.prod_stage_code AS product_stage_code,    --  产品阶段编码
  prod_data.prod_stage_name AS product_stage_name,    --  产品阶段名称
  prod_data.price_range_code AS price_range_code,  --  价格段编码
  prod_data.price_range_name AS price_range_name,  --  价格段名称
  prod_data.model_code AS model_code,    --  产品型号编码
  prod_data.model_name AS model_name,    --  产品型号名称
  prod_data.series_code AS product_series_code,   --  产品系列编码
  prod_data.series_name AS product_series_name,   --  产品系列名称
  prod_data.market_pos_code AS market_pnt_code,   --  营销定位编码
  prod_data.market_pos_name AS market_pnt_name,   --  营销定位名称
  prod_data.ac_ct_code AS tech_type_code,    --  技术类型编码
  prod_data.ac_ct_name AS tech_type_name,    --  技术类型名称
  prod_data.is_miniled_code AS is_miniled_code, --  是否MiniLED编码
  prod_data.big_class_code AS product_big_class_code,    --  产品大类编码
  prod_data.big_class_name AS product_big_class_name,    --  产品大类名称
  prod_data.middle_class_code AS product_mid_class_code,    --  产品中类编码
  prod_data.middle_class_name AS product_mid_class_name,    --  产品中类名称
  prod_data.small_class_code  AS product_small_class_code,  --  产品小类编码
  prod_data.small_class_name  AS product_small_class_name,  --  产品小类名称
  prod_data.model_lca AS model_lca_code,    --  产品型号生命周期编码
  prod_data.model_lca_name AS model_lca_name,    --  产品型号生命周期名称
  pro_type.product_type_code AS product_type_code, --  产品类型编码
  pro_type.product_type_name AS product_type_name, --  产品类型名称
  zsd020z.fkimg AS bill_qty,  --  开票销量
  zsd020z.pgimg AS ship_qty,  --  发货数量
  zsd020z.kwmng AS order_qty, --  订单数量
  zsd020z.waerk AS qcy_code,  --  交易币
  ((zsd020z.KZWI1/IF(zsd020z.KWMNG = 0,1,zsd020z.KWMNG))*(zsd020z.PGIMG-zsd020z.FKIMG)) / 1.13 AS rev_sale_amt,--  销售收入
   -- AS kzwi1, --  销售收入原始
  'S600' AS system_src,    --  源系统
  'ZTSO04_CK' AS ods_src,   --  源表
  zsd020z.kunag AS sold_to_code,  --  售达方
  zsd020z.namag AS sold_to_name,  --  售达方名称
  REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') AS material_group_code,   --  物料组
  t023t.wgbez AS material_group_name,   --  物料组名称
  mrte_ctp.ctp AS cp_company_code,   --  对方公司
  zsd020z.charg AS batch_id,  --  批次号
  CAST(zsd020z.erdat AS DATE) AS bill_dt,   --  发票日期
  CAST(zsd020z.wadat AS DATE) AS asap_dt,   --  过账日期
   -- AS delivery_dt, --  交货日期
  zsd020z.kondm AS material_pricing_group_code,   --  物料定价组编码
  t178t.vtext AS material_pricing_group_name,   --  物料定价组名称
  zsd020z.vbeln AS sale_cert_id,  --  销售凭证号
  zsd020z.posnr AS sale_cert_item,    --  销售凭证行项目
  zsd020z.auart AS sale_cert_type,    --  销售凭证类型
  zsd020z.wbsta AS goods_movement_status, --  货物移动状态
  zsd020z.fksta AS bill_status,   --  单据状态
  NOW() AS load_dt,--  更新时间
  zkunnr_mdg AS cust_mdg_code, --  客商编码mdg  
  CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE prod_data.profitcenter_code END AS profitcenter_code, --  利润中心编码
  CASE WHEN mt2bd.profitcenter_name IS NOT NULL THEN mt2bd.profitcenter_name ELSE prod_data.profitcenter_name END AS profitcenter_name,   --  利润中心名称
  COALESCE(if(upper(prod_data.sale_model_name)='无',null,upper(prod_data.sale_model_name)),if(upper(prod_data.zcusmodel)='无',null,upper(prod_data.zcusmodel))) AS customer_model,--  客户型号
  prod_data.zcalasset AS zcalasset,  --  按套统计
  CASE WHEN zsd020z.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
         THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
       WHEN IFNULL(TRIM(zsd020z.bus_range_code),'') <> ''
         THEN TRIM(zsd020z.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
         THEN TRIM(bus_range_map1.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
         THEN TRIM(bus_range_map2.bus_range_code_order)
       ELSE ''
  END AS bus_range_code,--  业务范围编码
  '' AS bus_range_name,--  业务范围描述
    zsd020z.vkbur AS agency_code, --  办事处编码
    tvkbt.bezei AS agency_name,  --  办事处名称
    CASE WHEN (SUBSTR(zsd020z.vkorg, 1, 2) IN ('62', '68') OR zsd020z.vkorg IN ('6012', '6015') 
                OR ((SUBSTR(zsd020z.vkorg, 1, 2) = '12' OR SUBSTR(zsd020z.vkorg, 1, 4) IN ('1180','1183')) AND prod_data.big_class_code = 'P02')
              )
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,Mapping_Bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') IN ('1209901','1209905','G209901') 
                         AND CASE WHEN zsd020z.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
                                    THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
                                  WHEN IFNULL(TRIM(zsd020z.bus_range_code),'') <> ''
                                    THEN TRIM(zsd020z.bus_range_code)
                                  WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
                                    THEN TRIM(bus_range_map1.bus_range_code)
                                  WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
                                    THEN TRIM(bus_range_map2.bus_range_code_order)
                                  ELSE ''
                              END NOT IN ('2358','A004','2357')
                THEN '1209901' ELSE NULL END ,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','')
                         )
          ELSE '' 
     END AS marketing_dept_code,
   (IFNULL(zsd020z.fkimg,0) * IFNULL(zsd020z.netpr,0)) / 1.13 AS rev_sale_bcy_amt,
   zsd020z.werks AS ship_fact_code,
   zsd020z.zzqdb_code AS comm_bu_code,
   zsd020z.zzqdb AS comm_bu_name,
   zsd020z.zzqdp_code AS cn_class_mark_code,
   zsd020z.zzqdp AS cn_class_mark_name,
   zsd020z.profitcenter_code AS src_profitcenter_code,
   zsd020z.bus_range_code AS src_bus_range_code,

   cust_data.channel_big_class_code AS channel_big_class_code,
   cust_data.channel_big_class_name AS channel_big_class_name,
   cust_data.channel_small_class_code AS channel_small_class_code,
   cust_data.channel_small_class_name AS channel_small_class_name,
   cust_data.ind_big_class_code AS ind_big_class_code,
   cust_data.ind_big_class_name AS ind_big_class_name,
   cust_data.ind_small_class_code AS ind_small_class_code,
   cust_data.ind_small_class_name AS ind_small_class_name
   /*20260520 新增miniled类型字段*/
   , prod_data.miniled_type_code
   , prod_data.miniled_type_name
  FROM zsd020_1 zsd020z
  LEFT JOIN dim.dim_rule_fi_mr_Revenue_Company_SaleOrg_BUZScope_Mapping bus_range_map1
    ON zsd020z.vkorg = bus_range_map1.company_code
   AND zsd020z.vkbur = bus_range_map1.agency_code
  LEFT JOIN dim.dim_rule_fi_mr_BusScope_for_Company bus_range_map2
    ON zsd020z.vkorg = bus_range_map2.company_code
  LEFT JOIN (SELECT kunnr,name1,zkunnr_mdg FROM ods.ods_slt_s600_kna1) kna1
    ON zsd020z.kunrg = kna1.kunnr
  LEFT JOIN prod_data prod_data
    ON zsd020z.matnr = prod_data.matnr
  LEFT JOIN cust_data cust_data
    ON kna1.zkunnr_mdg = cust_data.cust_code 
  LEFT JOIN yx_data yx_data
    ON kna1.zkunnr_mdg = yx_data.cust_code
   AND zsd020z.vkorg = yx_data.sale_org
   AND REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') = yx_data.material_group_code
  LEFT JOIN mrte_ctp mrte_ctp --  映射CTP
    ON LTRIM(zsd020z.kunrg,'0') = mrte_ctp.kunnr
  LEFT JOIN pro_type pro_type
    ON zsd020z.charg = pro_type.batch
  LEFT JOIN onoff_data onoff_data1
    ON zsd020z.vkorg = onoff_data1.company_code
   AND onoff_data1.batch_id = '1'
  LEFT JOIN onoff_data onoff_data2
    ON zsd020z.vkorg = onoff_data2.company_code
   AND (LTRIM(zsd020z.kunrg,'0') = onoff_data2.cust_code
        OR
        onoff_data2.cust_code IS NULL) --  处理 包含客商编码
   AND onoff_data2.batch_id = '2'
  LEFT JOIN onoff_data onoff_data3
    ON zsd020z.vkorg = onoff_data3.company_code
   AND (LTRIM(zsd020z.kunrg,'0') = onoff_data3.cust_code
        OR
        onoff_data3.cust_code IS NULL) --  处理 包含客商编码
   AND (LTRIM(zsd020z.kunag,'0') = onoff_data3.sold_to_code
        OR
        onoff_data3.sold_to_code IS NULL) --  处理 包含售达方
   AND onoff_data3.batch_id = '3'
  LEFT JOIN onoff_data onoff_data4
    ON (LTRIM(zsd020z.kunrg,'0') = onoff_data4.cust_code
        OR
        onoff_data4.cust_code IS NULL) --  处理 包含客商编码
   AND (LTRIM(zsd020z.kunag,'0') = onoff_data4.sold_to_code
        OR
        onoff_data4.sold_to_code IS NULL) --  处理 包含售达方
   AND onoff_data4.batch_id = '4'
  LEFT JOIN onoff_data onoff_data5
    ON zsd020z.vkorg = onoff_data5.company_code
   AND mrte_ctp.ctp = onoff_data5.cp_company_code --  处理对方公司
   AND onoff_data5.batch_id = '5'
   LEFT JOIN onoff_data onoff_data6
    ON zsd020z.vkorg = onoff_data6.company_code
   AND mrte_ctp.ctp = onoff_data6.cp_company_code --  处理对方公司
   AND (LTRIM(zsd020z.kunag,'0') = onoff_data6.sold_to_code
        OR
        onoff_data6.sold_to_code IS NULL) --  处理 包含售达方
   AND onoff_data6.batch_id = '6'
    LEFT JOIN (SELECT * 
                 FROM dim.dim_rule_fi_mr_mt2bd_mapping a
                WHERE 1=1
                  AND a.valid_fr <= LEFT(@year_month_day,6)
                  AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
              ) AS mt2bd
     ON zsd020z.matnr = mt2bd.material_code
   LEFT JOIN ods.ods_s600_t023t t023t --  物料组描述
     ON REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') = t023t.matkl
    AND t023t.spras = '1'
   LEFT JOIN ods.ods_slt_s600_vbap vbap
     ON zsd020z.vbeln = vbap.vbeln
    AND zsd020z.posnr = vbap.posnr
   LEFT JOIN (SELECT * FROM ods.ods_s600_tgsbt WHERE spras = 1) tgsbt --  业务范围描述
     ON vbap.gsber = tgsbt.gsber
   LEFT JOIN ods.ods_s600_tvkbt tvkbt --  办事处描述
     ON zsd020z.vkbur = tvkbt.vkbur
    AND tvkbt.spras = '1'
   LEFT JOIN dim.dim_rule_fi_mr_cust_busrange_mappping AS cust_map
     ON zsd020z.kunrg = cust_map.cust_code
   LEFT JOIN ods.ods_s600_t178t t178t --  物料定价组描述
     ON zsd020z.kondm = t178t.kondm
    AND t178t.spras = '1'
   LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code 
                FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
              ) mapping_bus
     ON zsd020z.matnr = mapping_bus.material_code
    /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) mapping_bus2
    ON zsd020z.matnr = mapping_bus2.material_code
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) mapping_bus1
    ON zsd020z.matnr = mapping_bus1.material_code
   AND CASE WHEN zsd020z.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
         THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
       WHEN IFNULL(TRIM(zsd020z.bus_range_code),'') <> ''
         THEN TRIM(zsd020z.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
         THEN TRIM(bus_range_map1.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
         THEN TRIM(bus_range_map2.bus_range_code_order)
       ELSE ''
  END = mapping_bus1.bus_range_code

  -- 新增业务管理单元取数逻辑
  LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON REGEXP_REPLACE(CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE prod_data.profitcenter_code END, '^0+', '') = profit_mapping0.profitcenter_code
   AND CASE WHEN zsd020z.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
         THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
       WHEN IFNULL(TRIM(zsd020z.bus_range_code),'') <> ''
         THEN TRIM(zsd020z.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
         THEN TRIM(bus_range_map1.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
         THEN TRIM(bus_range_map2.bus_range_code_order)
       ELSE ''
  END  = profit_mapping0.bus_range_code
  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping1.material_group_code)
   AND CASE WHEN zsd020z.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
         THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
       WHEN IFNULL(TRIM(zsd020z.bus_range_code),'') <> ''
         THEN TRIM(zsd020z.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
         THEN TRIM(bus_range_map1.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
         THEN TRIM(bus_range_map2.bus_range_code_order)
       ELSE ''
  END  = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON REPLACE(REPLACE(REPLACE(prod_data.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON REGEXP_REPLACE(CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE prod_data.profitcenter_code END, '^0+', '') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE WHEN zsd020z.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
         THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
       WHEN IFNULL(TRIM(zsd020z.bus_range_code),'') <> ''
         THEN TRIM(zsd020z.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
         THEN TRIM(bus_range_map1.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
         THEN TRIM(bus_range_map2.bus_range_code_order)
       ELSE ''
  END = profit_mapping4.bus_range_code  
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=1，物料+业务范围匹配，优先级1）
  LEFT JOIN (
      SELECT material_code, bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '1'
  ) cn_onoffline_map1
    ON zsd020z.matnr = cn_onoffline_map1.material_code
   AND (zsd020z.vkorg IN ('1180','118A','118B','1181') OR zsd020z.vkorg LIKE '12%')
   AND CASE WHEN zsd020z.vkorg LIKE '2%' AND mrte_ctp.ctp = '2023'
         THEN prod_data.bus_range_code  --  2026.07.14 新增 业务范围取值逻辑：当公司为2开头且对方公司为2023时，业务范围取物料大表
       WHEN IFNULL(TRIM(zsd020z.bus_range_code),'') <> ''
         THEN TRIM(zsd020z.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map1.bus_range_code),'') <> ''
         THEN TRIM(bus_range_map1.bus_range_code)
       WHEN IFNULL(TRIM(bus_range_map2.bus_range_code_order),'') <> ''
         THEN TRIM(bus_range_map2.bus_range_code_order)
       ELSE ''
  END = cn_onoffline_map1.bus_range_code
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=2，仅物料匹配，优先级2）
  LEFT JOIN (
            SELECT material_code, onoffline_code, onoffline_name
              FROM dim.dim_rule_fi_mr_cn_onoffline_map
            WHERE lever_flag = '2'
          ) cn_onoffline_map2
    ON zsd020z.matnr = cn_onoffline_map2.material_code
   AND (zsd020z.vkorg IN ('1180','118A','118B','1181') OR zsd020z.vkorg LIKE '12%')
 WHERE dt_month = SUBSTR(@year_month_day,1,6)
 
 
 ;
/***********************************出库数据插入结束*************************************/

/***********************************800,900收入成本取数开始*************************************/

INSERT INTO dwd.dwd_fi_mr_gp_detail_mi
 (
 year
,month
,company_code
,onoffline_code
,onoffline_name
-- ,product_line_code
,bill_qty
,qcy_code
,rev_sale_amt
,cogs_amt
,system_src
,ods_src
,bill_cert_id
,acct_src_code
,acct_map_code
,order_type_code
,load_dt,dt_month
,profitcenter_code
,profitcenter_name
,customer_model
,zcalasset
,bus_range_code
,bus_range_name
,rev_sale_bcy_amt
,marketing_dept_code
,material_code
,material_name
/*20260128 新增使用物料带出的相关信息字段*/
, material_group_code -- 物料组
, sale_model_code -- 销售型号编码
, sale_model_name -- 销售型号名称  /*alter by 20260811 xiaoyacha.ex 增加销售型号名称*/
, product_sale_series_code --  产品套系编码
, product_sale_series_name --  产品套系名称
, product_stage_code --  产品阶段编码
, product_stage_name --  产品阶段名称
, price_range_code --  价格段编码
, price_range_name --  价格段名称
, model_code --  产品型号编码
, model_name --  产品型号名称
, product_series_code --  产品系列编码
, product_series_name --  产品系列名称
, market_pnt_code --  营销定位编码
, market_pnt_name --  营销定位名称
, tech_type_code --  技术类型编码
, tech_type_name --  技术类型名称
, is_miniled_code --  是否MiniLED编码
, product_big_class_code --  产品大类编码
, product_big_class_name --  产品大类名称
, product_mid_class_code --  产品中类编码
, product_mid_class_name --  产品中类名称
, product_small_class_code --  产品小类编码
, product_small_class_name --  产品小类名称
, model_lca_code --  产品型号生命周期编码
, model_lca_name --  产品型号生命周期名称
, brand_code --  品牌编码
, brand_name --  品牌名称
, spec_section_code --  规格段编码
, spec_section_name --  规格段名称
, product_shape_type_code --  产品形态分类编码
, product_shape_type_name --  产品形态分类名称
, src_profitcenter_code
, src_bus_range_code
, comm_bu_code -- 电商BU渠道细分编码
, comm_bu_name -- 电商BU渠道细分描述
, cn_class_mark_code -- 中国区品类标记编码
, cn_class_mark_name -- 中国区品类标记描述
, bus_sce_cat_code -- 业务场景分类编码
, bus_sce_cat_name -- 业务场景分类描述
, transaction_type -- 事务类型
, cust_code --  客商编码
, cust_name --  客商名称
, cp_company_code -- 对方公司
, cust_mdg_code --  客商编码-MDG

/*20260518 新增使用客商带出的相关信息字段*/
, cust_unity_name
, credit_level_name
, cust_nature_name
, cust_type_name
, channel_l1_code
, channel_l1_name
, channel_l2_code
, channel_l2_name
, channel_l3_code
, channel_l3_name
, marketing_mode_code
, marketing_mode_name
, channel_big_class_code
, channel_big_class_name
, channel_small_class_code
, channel_small_class_name
, ind_big_class_code
, ind_big_class_name
, ind_small_class_code
, ind_small_class_name

, miniled_type_code
, miniled_type_name
, file_archive_no -- 落户纸号
)

WITH g_kunnr_s900 AS
(SELECT bseg1.gjahr,bseg1.bukrs,bseg1.belnr ,min(TRIM(bseg1.kunnr)) AS kunnr
   FROM ods.ods_slt_s900_bseg_v bseg1
        ,ods.ods_slt_s900_bkpf_v bkpf1
  WHERE bseg1.belnr = bkpf1.belnr
    AND bseg1.gjahr = bkpf1.gjahr
    AND bseg1.bukrs = bkpf1.bukrs
    AND bkpf1.gjahr = substr(@year_month_day,1,4)
    AND bkpf1.monat = substr(@year_month_day,5,2)
    AND TRIM(bseg1.kunnr) <> ''
  GROUP BY bseg1.gjahr,bseg1.bukrs,bseg1.belnr
having count(distinct TRIM(BSEG1.kunnr))=1
),
g_kunnr_s800 AS
(SELECT bseg1.gjahr,bseg1.bukrs,bseg1.belnr ,min(TRIM(bseg1.kunnr)) AS kunnr
   FROM ods.ods_slt_s800_bseg_v bseg1
       ,ods.ods_slt_s800_bkpf_v bkpf1
 WHERE bseg1.belnr = bkpf1.belnr
   AND bseg1.gjahr = bkpf1.gjahr
   AND bseg1.bukrs = bkpf1.bukrs
   AND bkpf1.gjahr= substr(@year_month_day,1,4) 
   AND bkpf1.monat= substr(@year_month_day,5,2)
   AND TRIM(bseg1.kunnr) <> ''
 GROUP BY bseg1.gjahr,bseg1.bukrs,bseg1.belnr
having count(distinct TRIM(BSEG1.kunnr))=1
),
data_bseg_s900 AS
(SELECT 
      bseg.gjahr
    , bkpf.monat
    , bseg.belnr
    , bseg.buzei 
    , bseg.bukrs 
    , bseg.hkont
    , bseg.gsber
    , bseg.prctr
    , bseg.matnr
    , CASE WHEN bseg.shkzg='S' THEN bseg.menge ELSE -bseg.menge END AS menge
    , CASE WHEN bseg.shkzg='S' THEN bseg.dmbtr ELSE -bseg.dmbtr END AS dmbtr
    , CASE WHEN bseg.shkzg='S' THEN bseg.wrbtr ELSE -bseg.wrbtr END AS wrbtr
    , CASE WHEN LTRIM(TRIM(bseg.kunnr),0) <> '' THEN LTRIM(TRIM(bseg.kunnr),0)
         WHEN LTRIM(TRIM(g_kunnr_s900.kunnr),0) <> '' THEN LTRIM(TRIM(g_kunnr_s900.kunnr),0)
         WHEN LTRIM(TRIM(bseg.xref3),0) LIKE 'A%' then LTRIM(TRIM(bseg.xref3),0)
         WHEN bseg.hkont LIKE '5101%' then LTRIM(TRIM(kna1.kunnr),0)
         WHEN(bseg.hkont LIKE '5401%' OR bseg.hkont = '5508999002' OR bseg.hkont = '5509999002' ) AND LTRIM(TRIM(lfa1.lifnr),0) IS NULL THEN LTRIM(TRIM(kna1.kunnr),0)
      END AS kunnr
    , bseg.vorgn
    , bkpf.waers
    , bkpf.glvor
    , bkpf.AWKEY
    , vbrk.FKART
	, bkpf.xblnr AS file_archive_no
FROM ods.ods_slt_s900_bseg_v bseg
INNER JOIN ods.ods_slt_s900_bkpf_v bkpf on bseg.belnr = bkpf.belnr AND bseg.gjahr = bkpf.gjahr AND bseg.bukrs = bkpf.bukrs
/*alter by 20260811 xiaoyachao.ex 凭证的参考码AWKEY=系统发票（系统发票判断：凭证抬头BKPF表里，交易业务GLVOR=SD00），到vbrk系统发票表里查询发票类型FKART*/
LEFT JOIN ods.odsslt_s900_vbrk vbrk ON bkpf.awkey = vbrk.vbeln 
LEFT JOIN g_kunnr_s900 on bseg.belnr = g_kunnr_s900.belnr AND bseg.gjahr = g_kunnr_s900.gjahr AND bseg.bukrs = g_kunnr_s900.bukrs
LEFT JOIN ods.odss900_kna1 kna1 on LTRIM(TRIM(bseg.xref3),0)=LTRIM(TRIM(kna1.kunnr),0)
LEFT JOIN ods.odss900_lfa1 lfa1 on LTRIM(TRIM(bseg.xref3),0)=LTRIM(TRIM(lfa1.lifnr),0)
WHERE bkpf.gjahr = substr(@year_month_day,1,4) 
AND bkpf.monat= substr(@year_month_day,5,2)
AND (bseg.hkont LIKE '5101%' OR bseg.hkont LIKE '5401%' OR bseg.hkont = '5508999002' OR bseg.hkont = '5509999002' )
),
data_bseg_s800 AS
(SELECT 
      bseg.gjahr
    , bkpf.monat
    , bseg.belnr
    , bseg.buzei 
    , bseg.bukrs 
    , bseg.hkont
    , bseg.gsber
    , bseg.prctr
    , bseg.matnr
    , CASE WHEN bseg.shkzg='S' THEN bseg.menge ELSE -bseg.menge END AS menge
    , CASE WHEN bseg.shkzg='S' THEN bseg.dmbtr ELSE -bseg.dmbtr END AS dmbtr
    , CASE WHEN bseg.shkzg='S' THEN bseg.wrbtr ELSE -bseg.wrbtr END AS wrbtr
    , CASE WHEN LTRIM(TRIM(bseg.kunnr),0) <> '' THEN LTRIM(TRIM(bseg.kunnr),0)
           WHEN LTRIM(TRIM(g_kunnr_s800.kunnr),0) <> '' THEN LTRIM(TRIM(g_kunnr_s800.kunnr),0)
           WHEN LTRIM(TRIM(bseg.xref3),0) LIKE 'A%' then LTRIM(TRIM(bseg.xref3),0)
           WHEN bseg.hkont LIKE '5101%' then LTRIM(TRIM(kna1.kunnr),0)
           WHEN(bseg.hkont LIKE '5401%' OR bseg.hkont = '5508999002' OR bseg.hkont = '5509999002' ) AND LTRIM(TRIM(lfa1.lifnr),0) IS NULL THEN LTRIM(TRIM(kna1.kunnr),0)
      END AS kunnr
    , bseg.vorgn
    , bkpf.waers
    , bkpf.glvor
    , bkpf.AWKEY
    , '' AS FKART
	, bkpf.xblnr AS file_archive_no
FROM ods.ods_slt_s800_bseg_v bseg
INNER JOIN ods.ods_slt_s800_bkpf_v bkpf on bseg.belnr = bkpf.belnr AND bseg.gjahr = bkpf.gjahr AND bseg.bukrs = bkpf.bukrs
LEFT JOIN g_kunnr_s800 on bseg.belnr = g_kunnr_s800.belnr AND bseg.gjahr = g_kunnr_s800.gjahr AND bseg.bukrs = g_kunnr_s800.bukrs
LEFT JOIN ods.odss800_kna1 kna1 on LTRIM(TRIM(bseg.xref3),0)=LTRIM(TRIM(kna1.kunnr),0)
LEFT JOIN ods.odss800_lfa1 lfa1 on LTRIM(TRIM(bseg.xref3),0)=LTRIM(TRIM(lfa1.lifnr),0)
WHERE bkpf.gjahr = substr(@year_month_day,1,4) 
AND bkpf.monat= substr(@year_month_day,5,2)
AND (bseg.hkont LIKE '5101%' OR bseg.hkont LIKE '5401%' OR bseg.hkont = '5508999002' OR bseg.hkont = '5509999002' )
),
bseg_union AS(
SELECT 'S900' AS sap_no,* FROM data_bseg_s900
UNION ALL
SELECT 'S800' AS sap_no,* FROM data_bseg_s800
),
 mara_fert AS --  物料大表
 (
   SELECT matnr,prod_line,prod_line_name,matkl FROM dim.dim_fi_mr_product_dd A
 ),
 form_dati_ctp AS --  匹配对方公司
 (
 SELECT cust_code AS kunrg --  客商编码
       ,NVL(cp_company_code_mr,cp_company_code) AS ctp --  对方公司编码
       ,system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src IN ('S800','S900')
 ),
bseg_temp_m AS 
(
  --  匹配物料大表，错误产品线和对方公司
   SELECT
       bseg_union.*
     , CASE WHEN form_dati_ctp.ctp IN ('4330','4320') AND bseg_union.bukrs = '6515' 
              THEN CONCAT(form_dati_ctp.ctp,'A') ELSE form_dati_ctp.ctp 
       END ctp --  对方公司
     , CASE WHEN bseg_union.sap_no = 'S900' THEN REPLACE(REPLACE(REPLACE(mara_fert.prod_line,'BP',''),'DS',''),'TA','') ELSE mara_fert.matkl END AS material_group_code
    FROM bseg_union
    LEFT JOIN (SELECT * FROM mara_fert) mara_fert--  根据MATNR匹配物料大表EDW.DW_TM_MARA_FERT@FMSLK取PROD_LINE
      ON bseg_union.matnr = mara_fert.matnr
    LEFT JOIN (SELECT * FROM form_dati_ctp) form_dati_ctp--  匹配对方公司
      ON LTRIM(bseg_union.kunnr,0) = LTRIM(form_dati_ctp.kunrg,0)
     AND bseg_union.sap_no = form_dati_ctp.system_src
),
nf_map_1  AS 
(
  SELECT  batch_id AS xh --  处理优先级
        , logic_name AS lj --  逻辑处理
        , b.cod_azienda AS vkorg --  公司包含
        , c.cod_azienda AS ctp
        , cust_code AS kunrg --  客商包含
        , cust_ex_code AS kunrg_out
        , sold_to_code AS sold_to --  售达方包含
        , sold_to_ex_code AS sold_to_out
        , product_line_src_code AS org_prctr_before --  处理前利润中心
        , onoffline_src_code AS nf_before
        , onoffline_code AS nf
        , onoffline_name AS nf_name
   FROM dim.dim_rule_fi_mr_nf_mapping a 
   LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
  WHERE valid_fr <=@year_month_day
    AND NVL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
 ),
bseg_temp_2 AS (
  --  第二次匹配逻辑
 SELECT
     bseg_temp_m.*
    ,CASE WHEN COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf) IS NULL 
            THEN '020_OFF_002' 
          WHEN COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf) = 'NULL'
            THEN NULL 
          ELSE COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf)
     END AS nf_1
    ,CASE WHEN COALESCE(form_dati_nf5.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name) IS NULL 
            THEN '零售-传统零售' 
          WHEN COALESCE(form_dati_nf5.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name) = 'NULL'
            THEN NULL 
          ELSE COALESCE(form_dati_nf5.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name)
     END AS nf_1_name
   FROM bseg_temp_m
   LEFT JOIN nf_map_1 form_dati_nf1--  匹配线上线下映射表 按公司匹配
     ON 1=1
    --  公司包含匹配
    AND bseg_temp_m.bukrs = form_dati_nf1.vkorg
    AND form_dati_nf1.xh = '1'
   LEFT JOIN nf_map_1 form_dati_nf2--  匹配线上线下映射表 按公司+客商匹配
     ON 1=1
    --  公司包含匹配
    AND bseg_temp_m.bukrs = form_dati_nf2.vkorg
    --  客商匹配
    AND LTRIM(bseg_temp_m.kunnr, '0') = form_dati_nf2.kunrg
    AND form_dati_nf2.xh = '2'

   LEFT JOIN nf_map_1 form_dati_nf5--  匹配线上线下映射表 按公司+对方公司匹配
     ON 1=1
    --  公司匹配
    AND bseg_temp_m.bukrs = form_dati_nf5.vkorg
    --  对方公司匹配
    AND bseg_temp_m.ctp = form_dati_nf5.ctp
    AND form_dati_nf5.xh = '5'
)
    SELECT
        bseg.gjahr AS year
      , bseg.monat AS month
      , CASE WHEN bseg.bukrs = '6000' AND bseg.gsber = '200' THEN '6000A' ELSE bseg.bukrs END AS company_code
      /*
      ③asko+gorenje（公司为6005、6530）：SAP订单的销售部门【agency_code】="大客户部-古洛尼"的默认为线下-"工程"
      ④激光2052、2053公司客户【cust_code】是内部公司的就是线下-"内配"，外部的就是线下-"外售"
      */
      , CASE 
            -- ADD SXX XSJ 20260323 中国区特殊逻辑：公司=1180或12%时，先走cn_onoffline_map映射
            WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_code
            WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_code
            ELSE CASE -- WHEN bseg.bukrs IN ('6005','6530') AND bseg.vkbur IN ('G005')  THEN '020_OFF_004' --  线下-工程
                    WHEN bseg.ctp IS NOT NULL AND bseg.bukrs IN ('2052','2053') THEN '020_OFF_006' --  线下-内配
                    WHEN bseg.ctp IS NULL AND bseg.bukrs IN ('2052','2053') THEN '020_OFF_007' --  线下-外售
                    ELSE bseg.nf_1 
                END
        END AS onoffline_code --  线上线下编码
      , CASE 
            -- ADD SXX XSJ 20260323 中国区特殊逻辑：公司=1180或12%时，先走cn_onoffline_map映射
            WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_name
            WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_name
            ELSE CASE -- WHEN bseg.bukrs IN ('6005','6530') AND bseg.vkbur IN ('G005')  THEN '工程' --  线下-工程
                    WHEN bseg.ctp IS NOT NULL AND bseg.bukrs IN ('2052','2053') THEN '内配' --  线下-内配
                    WHEN bseg.ctp IS NULL AND bseg.bukrs IN ('2052','2053') THEN '外售' --  线下-外售
                    ELSE bseg.nf_1_name
                END 
        END AS onoffline_name --  线上线下名称
      -- , bseg.org_prctr_m AS product_line_code --  产品线编码
      --, (CASE WHEN bseg.hkont LIKE '5101%' THEN bseg.menge ELSE 0 END) AS bill_qty
      /*alter by 20260811 xiaoyachao.ex 借贷项订单管报不取数量,900逻辑：BSEG来源，凭证的参考码AWKEY=系统发票（系统发票判断：凭证抬头BKPF表里，交易业务GLVOR=SD00），到vbrk系统发票表里查询发票类型FKART=ZL2/ZG2/ZG3，不取数量*/
      , (CASE WHEN bseg.sap_no = 'S900' AND bseg.glvor = 'SD00' AND bseg.FKART IN ('ZL2','ZG2','ZG3') THEN 0   
              WHEN bseg.hkont LIKE '5101%'  THEN bseg.menge
              ELSE 0 
          END) AS bill_qty
      , bseg.waers AS qcy_code
      , (CASE WHEN bseg.hkont LIKE '5101%' THEN bseg.dmbtr ELSE 0 END) rev_sale_amt
      , (CASE WHEN bseg.hkont LIKE '5401%' OR bseg.hkont IN ('5508999002','5509999002') THEN bseg.dmbtr ELSE 0 END) cogs_amt
      , bseg.sap_no AS system_src
      , 'BSEG' AS ods_src
      , bseg.belnr AS bill_cert_id
      , bseg.hkont AS acct_src_code
      , acct_map.conto_code AS acct_map_code
      , bseg.glvor AS order_type_code
      , NOW() AS load_dt
      , CONCAT(bseg.gjahr,bseg.monat) AS dt_month
      , COALESCE(mt2bd.profitcenter_code,mara.profitcenter_code,bseg.prctr)  AS profitcenter_code
      , '' AS profitcenter_name
      , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model 
      , mara.zcalasset AS zcalasset  
      , CASE WHEN bseg.bukrs LIKE '2%' AND bseg.ctp = '2023' 
              THEN mara.bus_range_code
             WHEN acct_map.conto_code LIKE '6609%' AND mara.bus_range_code IS NOT NULL
               THEN mara.bus_range_code
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') <> ''
               THEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),TRIM(bseg.gsber)), '')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code LIKE '6001%'
               THEN IFNULL(TRIM(dim_rule_fi_mr_BusScope_for_Company.bus_range_code),'')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code NOT LIKE '6001%'
               THEN CASE 
                        WHEN NVL(ZZNXWX,SALE_AREA) IN ('02','外销品') THEN '3000'
                        ELSE '2000' END
             ELSE ''
        END AS bus_range_code

      , '' AS bus_range_name
      , (CASE WHEN bseg.hkont LIKE '5101%' THEN bseg.wrbtr ELSE 0 END) AS rev_sale_bcy_amt
      , CASE WHEN (SUBSTR(bseg.bukrs, 1, 2) IN ('62', '68') OR bseg.bukrs IN ('6012', '6015') 
                OR ((SUBSTR(bseg.bukrs, 1, 2) = '12' OR SUBSTR(bseg.bukrs, 1, 4) IN ('1180','1183')) AND mara.big_class_code = 'P02')
                )
            THEN COALESCE(mapping_bus1.marketing_dept_code,
                         mapping_bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN TRIM(bseg.material_group_code) IN ('1209901','1209905','G209901')
                              AND  CASE WHEN bseg.bukrs LIKE '2%' AND bseg.ctp = '2023'
                                          THEN mara.bus_range_code
                                        WHEN acct_map.conto_code LIKE '6609%' AND mara.bus_range_code IS NOT NULL
                                          THEN mara.bus_range_code
                                        WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') <> ''
                                          THEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),TRIM(bseg.gsber)), '')
                                        WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code LIKE '6001%'
                                          THEN IFNULL(TRIM(dim_rule_fi_mr_BusScope_for_Company.bus_range_code),'')
                                        WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code NOT LIKE '6001%'
                                          THEN CASE 
                                                    WHEN NVL(ZZNXWX,SALE_AREA) IN ('02','外销品') THEN '3000'
                                                    ELSE '2000' END
                                        ELSE ''
                                    END NOT IN ('2358','A004','2357')
                               THEN '1209901'
                               ELSE NULL
                        END,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         bseg.material_group_code
                         )
       ELSE ''
        END AS marketing_dept_code
    , bseg.matnr AS material_code
    , mara.product_name AS material_name
    /*20260128 新增使用物料带出的相关信息字段*/
    , bseg.material_group_code AS material_group_code -- 物料组
    , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
          ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
          ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
        ) AS sale_model_code -- 销售型号编码
    /*alter by 20260811 xiaoaychao.ex 销售型号名称逻辑更新*/
    , COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name
    , mara.prod_suite_code AS product_sale_series_code --  产品套系编码
    , mara.prod_suite_name AS product_sale_series_name --  产品套系名称
    , mara.prod_stage_code AS product_stage_code --  产品阶段编码
    , mara.prod_stage_name AS product_stage_name --  产品阶段名称
    , mara.price_range_code AS price_range_code --  价格段编码
    , mara.price_range_name AS price_range_name --  价格段名称
    , mara.model_code AS model_code --  产品型号编码
    , mara.model_name AS model_name --  产品型号名称
    , mara.series_code AS product_series_code --  产品系列编码
    , mara.series_name AS product_series_name --  产品系列名称
    , mara.market_pos_code AS market_pnt_code --  营销定位编码
    , mara.market_pos_name AS market_pnt_name --  营销定位名称
    , mara.ac_ct_code AS tech_type_code --  技术类型编码
    , mara.ac_ct_name AS tech_type_name --  技术类型名称
    , CASE WHEN mara.is_miniled_code  = 'PC00013001' THEN '是'
           WHEN mara.is_miniled_code  = 'PC00013002' THEN '否'
           ELSE ''
      END AS is_miniled_code --  是否MiniLED编码
    , mara.big_class_code AS product_big_class_code --  产品大类编码
    , mara.big_class_name AS product_big_class_name --  产品大类名称
    , mara.middle_class_code AS product_mid_class_code --  产品中类编码
    , mara.middle_class_name AS product_mid_class_name --  产品中类名称
    , mara.small_class_code AS product_small_class_code --  产品小类编码
    , mara.small_class_name AS product_small_class_name --  产品小类名称
    , mara.model_lca AS model_lca_code --  产品型号生命周期编码
    , mara.model_lca_name AS model_lca_name --  产品型号生命周期名称
    , mara.brand AS brand_code --  品牌编码
    , mara.brand_name AS brand_name --  品牌名称
  ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
  END AS spec_section_code --  规格段编码
    ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
  END  AS spec_section_name --  规格段名称
    , mara.product_spec_code AS product_shape_type_code --  产品形态分类编码
    , mara.product_spec_name AS product_shape_type_name --  产品形态分类名称
    , bseg.prctr AS src_profitcenter_code
    , bseg.gsber AS src_bus_range_code
    , gla_bseg.zzqdb AS comm_bu_code -- 电商BU渠道细分编码
    , '' AS comm_bu_name -- 电商BU渠道细分描述
    , gla_bseg.zzqdp AS cn_class_mark_code -- 中国区品类标记编码
    , CASE WHEN gla_bseg.zzqdp = 'Z1' THEN '中国区' WHEN gla_bseg.zzqdp = 'Z2' THEN '品线' END AS cn_class_mark_name -- 中国区品类标记描述
    , gla_bseg.zbsart AS bus_sce_cat_code -- 业务场景分类编码
    , gla_bseg.zbsart_txt AS bus_sce_cat_name -- 业务场景分类描述
    , bseg.vorgn  AS transaction_type -- 事务类型
    , bseg.kunnr as cust_code --  客商编码
    , kna1.name1 AS cust_name --  客商名称
    , bseg.ctp AS cp_company_code --  对方公司
    , kna1.zkunnr_mdg AS cust_mdg_code --  客商编码-MDG

    , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name
    , dim_customer_base_info_dd.credit_level AS credit_level_name
    , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name
    , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
            AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
            AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
            THEN NULL
            ELSE TRIM(
                  REGEXP_REPLACE(
                      CONCAT_WS(',',
                          CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                          CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                          CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                      ),
                      '(^,)|(,$)',  
                      ''            
                  )
              ) END AS cust_type_name
    , dim_customer_base_info_dd.com_1st_code AS channel_l1_code
    , dim_customer_base_info_dd.com_1st_name AS channel_l1_name
    , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code
    , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name
    , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code
    , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name
    , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code
    , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name
    , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code
    , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name
    , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code
    , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name
    , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code
    , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name
    , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code
    , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name

    , mara.miniled_type_code AS miniled_type_code
    , mara.miniled_type_name AS miniled_type_name
	, bseg.file_archive_no AS file_archive_no
FROM bseg_temp_2 bseg
LEFT JOIN (SELECT 'S900' AS ssrclnt,LTRIM(kunnr,0) AS kunnr,zkunnr_mdg,name1 FROM ods.ods_slt_s900_kna1 WHERE mandt = '900'
            UNION ALL
           SELECT 'S800' AS ssrclnt,LTRIM(kunnr,0) AS kunnr,zkunnr_mdg,name1 FROM ods.odss800_kna1 WHERE mandt = '800'
          ) kna1
  ON LTRIM(bseg.kunnr,0) = kna1.kunnr
 AND bseg.sap_no = kna1.ssrclnt
LEFT JOIN 
  (
    SELECT DISTINCT 'S800' AS ssrclnt,bukrs,belnr,gjahr,buzei,zzqdb,zzqdp,zbsart,zbsart_txt FROM ods.odss800_zfzt_gla_bseg
      UNION ALL 
    SELECT DISTINCT 'S900' AS ssrclnt,bukrs,belnr,gjahr,buzei,zzqdb,zzqdp,zbsart,zbsart_txt FROM ods.odss900_zfzt_gla_bseg
  )gla_bseg
  ON gla_bseg.bukrs = bseg.bukrs
  AND gla_bseg.belnr = bseg.belnr
  AND gla_bseg.gjahr = bseg.gjahr
  AND gla_bseg.buzei = bseg.buzei
  AND gla_bseg.ssrclnt = bseg.sap_no


LEFT JOIN (SELECT * FROM dw.dim_customer_base_info_dd) dim_customer_base_info_dd
  ON kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code
LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_sap2pb_map a
            WHERE 1=1
              AND a.valid_fr <= LEFT(@year_month_day,6)
              AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
              AND sapversion IN ('S800','S900')
          ) AS sap2pb
  ON LTRIM(bseg.belnr,'0') = LTRIM(sap2pb.belnr,'0')
 AND bseg.bukrs = sap2pb.company_code
 AND LTRIM(bseg.buzei,'0') = LTRIM(sap2pb.buzei,'0')
 AND bseg.sap_no = sap2pb.sapversion
 

LEFT JOIN dim.dim_rule_fi_mr_BusScope_for_Company 
    ON bseg.bukrs = dim_rule_fi_mr_BusScope_for_Company.company_code
LEFT JOIN dim.dim_fi_mr_product_dd mara
  ON bseg.matnr = mara.matnr
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
  ON kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
 AND bseg.bukrs = dim_customer_trade_info_dd.sale_org
 AND bseg.material_group_code = dim_customer_trade_info_dd.material_group_code
 LEFT JOIN (
               SELECT acct_src_code AS racct_src_code
                    , acct_map_code AS conto_code
                    , system_src AS system_src
               FROM dim.dim_rule_fi_mr_acct_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= @year_month_day
            ) acct_map
   ON bseg.hkont = acct_map.racct_src_code
  AND bseg.sap_no = acct_map.system_src
 LEFT JOIN dw.dim_product_base_info_dd
   ON bseg.matnr = dim_product_base_info_dd.product_code
 LEFT JOIN (
            SELECT 'S800' AS ssrclnt,gsber,gtext FROM ods.ods_s800_tgsbt WHERE spras = 1
            UNION ALL
            SELECT 'S900' AS ssrclnt,gsber,gtext FROM ods.ods_s900_tgsbt WHERE spras = 1
        ) tgsbt
   ON bseg.gsber = tgsbt.gsber
  AND bseg.sap_no = tgsbt.ssrclnt
 LEFT JOIN (SELECT 'S800' AS ssrclnt,matkl,wgbez FROM ods.ods_s800_t023t WHERE spras = 1
            UNION ALL
           SELECT 'S900' AS ssrclnt,matkl,wgbez FROM ods.ods_s900_t023t WHERE spras = 1
            ) t023t --  物料组名称表
   ON bseg.material_group_code = t023t.matkl
  AND bseg.sap_no = t023t.ssrclnt
  LEFT JOIN (SELECT material_code,profitcenter_code,profitcenter_name
               FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON bseg.matnr = mt2bd.material_code

    /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_AirConditioner_Materials_Mapping_Bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) mapping_bus2
    ON bseg.matnr = mapping_bus2.material_code
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_AirConditioner_Materials_Mapping_Bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) mapping_bus1
    ON bseg.matnr = mapping_bus1.material_code
   AND CASE WHEN bseg.bukrs LIKE '2%' AND bseg.ctp = '2023' 
              THEN mara.bus_range_code
             WHEN acct_map.conto_code LIKE '6609%' AND mara.bus_range_code IS NOT NULL
               THEN mara.bus_range_code
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') <> ''
               THEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),TRIM(bseg.gsber)), '')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code LIKE '6001%'
               THEN IFNULL(TRIM(dim_rule_fi_mr_BusScope_for_Company.bus_range_code),'')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code NOT LIKE '6001%'
               THEN CASE 
                        WHEN NVL(ZZNXWX,SALE_AREA) IN ('02','外销品') THEN '3000'
                        ELSE '2000' END
             ELSE ''
        END = Mapping_Bus1.bus_range_code

  -- 新增业务管理单元取数逻辑
    LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON LTRIM(COALESCE(mt2bd.profitcenter_code,mara.profitcenter_code,bseg.prctr) ,'0') = profit_mapping0.profitcenter_code
   AND CASE WHEN bseg.bukrs LIKE '2%' AND bseg.ctp = '2023' 
              THEN mara.bus_range_code
             WHEN acct_map.conto_code LIKE '6609%' AND mara.bus_range_code IS NOT NULL
               THEN mara.bus_range_code
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') <> ''
               THEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),TRIM(bseg.gsber)), '')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code LIKE '6001%'
               THEN IFNULL(TRIM(dim_rule_fi_mr_BusScope_for_Company.bus_range_code),'')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code NOT LIKE '6001%'
               THEN CASE 
                        WHEN NVL(ZZNXWX,SALE_AREA) IN ('02','外销品') THEN '3000'
                        ELSE '2000' END
             ELSE ''
        END  = profit_mapping0.bus_range_code


  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON TRIM(bseg.material_group_code) = TRIM(profit_mapping1.material_group_code)
   AND CASE WHEN bseg.bukrs LIKE '2%' AND bseg.ctp = '2023' 
              THEN mara.bus_range_code
             WHEN acct_map.conto_code LIKE '6609%' AND mara.bus_range_code IS NOT NULL
               THEN mara.bus_range_code
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') <> ''
               THEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),TRIM(bseg.gsber)), '')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code LIKE '6001%'
               THEN IFNULL(TRIM(dim_rule_fi_mr_BusScope_for_Company.bus_range_code),'')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code NOT LIKE '6001%'
               THEN CASE 
                        WHEN NVL(ZZNXWX,SALE_AREA) IN ('02','外销品') THEN '3000'
                        ELSE '2000' END
             ELSE ''
        END = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON TRIM(bseg.material_group_code) = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON LTRIM(COALESCE(mt2bd.profitcenter_code,mara.profitcenter_code,bseg.prctr) ,'0') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE WHEN bseg.bukrs LIKE '2%' AND bseg.ctp = '2023' 
              THEN mara.bus_range_code
             WHEN acct_map.conto_code LIKE '6609%' AND mara.bus_range_code IS NOT NULL
               THEN mara.bus_range_code
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') <> ''
               THEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),TRIM(bseg.gsber)), '')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code LIKE '6001%'
               THEN IFNULL(TRIM(dim_rule_fi_mr_BusScope_for_Company.bus_range_code),'')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code NOT LIKE '6001%'
               THEN CASE 
                        WHEN NVL(ZZNXWX,SALE_AREA) IN ('02','外销品') THEN '3000'
                        ELSE '2000' END
             ELSE ''
        END = profit_mapping4.bus_range_code
 
 
 --  ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=1，物料+业务范围匹配，优先级1）
  LEFT JOIN (
      SELECT material_code, bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '1'
  ) cn_onoffline_map1
    ON bseg.matnr = cn_onoffline_map1.material_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')
   AND CASE WHEN bseg.bukrs LIKE '2%' AND bseg.ctp = '2023'  
              THEN mara.bus_range_code
             WHEN acct_map.conto_code LIKE '6609%' AND mara.bus_range_code IS NOT NULL
               THEN mara.bus_range_code
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') <> ''
               THEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),TRIM(bseg.gsber)), '')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code LIKE '6001%'
               THEN IFNULL(TRIM(dim_rule_fi_mr_BusScope_for_Company.bus_range_code),'')
             WHEN IFNULL(COALESCE(TRIM(sap2pb.bus_range_code),(TRIM(bseg.gsber))), '') = '' AND acct_map.conto_code NOT LIKE '6001%'
               THEN CASE 
                        WHEN NVL(ZZNXWX,SALE_AREA) IN ('02','外销品') THEN '3000'
                        ELSE '2000' END
             ELSE ''
        END = cn_onoffline_map1.bus_range_code
  --  ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=2，仅物料匹配，优先级2）
  LEFT JOIN (
      SELECT material_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '2'
  ) cn_onoffline_map2
    ON bseg.matnr = cn_onoffline_map2.material_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')
;
/***********************************800,900收入成本取数结束*************************************/



  
  

/***********************************BSEG调整数据&成本数据插入开始*************************************/
 INSERT INTO dwd.dwd_fi_mr_gp_detail_mi 
 (
 year
,month
,company_code
,onoffline_code
,onoffline_name
,product_line_code
,bill_qty
,qcy_code
,rev_sale_amt
,system_src
,ods_src
,bill_cert_id
,acct_src_code
,acct_map_code
,order_type_code
,load_dt,dt_month
,profitcenter_code
,profitcenter_name
,customer_model
,zcalasset
,bus_range_code
,bus_range_name
,rev_sale_bcy_amt
,marketing_dept_code
,material_code
,material_name
/*20260128 新增使用物料带出的相关信息字段*/
, material_group_code -- 物料组
, sale_model_code -- 销售型号编码
, sale_model_name -- 销售型号名称         /*alter by 20260811 xiaoyachao.ex 增加销售型号描述*/
, product_sale_series_code --  产品套系编码
, product_sale_series_name --  产品套系名称
, product_stage_code --  产品阶段编码
, product_stage_name --  产品阶段名称
, price_range_code --  价格段编码
, price_range_name --  价格段名称
, model_code --  产品型号编码
, model_name --  产品型号名称
, product_series_code --  产品系列编码
, product_series_name --  产品系列名称
, market_pnt_code --  营销定位编码
, market_pnt_name --  营销定位名称
, tech_type_code --  技术类型编码
, tech_type_name --  技术类型名称
, is_miniled_code --  是否MiniLED编码
, product_big_class_code --  产品大类编码
, product_big_class_name --  产品大类名称
, product_mid_class_code --  产品中类编码
, product_mid_class_name --  产品中类名称
, product_small_class_code --  产品小类编码
, product_small_class_name --  产品小类名称
, model_lca_code --  产品型号生命周期编码
, model_lca_name --  产品型号生命周期名称
, brand_code --  品牌编码
, brand_name --  品牌名称
, spec_section_code --  规格段编码
, spec_section_name --  规格段名称
, product_shape_type_code --  产品形态分类编码
, product_shape_type_name --  产品形态分类名称
, src_profitcenter_code
, src_bus_range_code
, comm_bu_code -- 电商BU渠道细分编码
, comm_bu_name -- 电商BU渠道细分描述
, cn_class_mark_code -- 中国区品类标记编码
, cn_class_mark_name -- 中国区品类标记描述
, bus_sce_cat_code -- 业务场景分类编码
, bus_sce_cat_name -- 业务场景分类描述
, transaction_type -- 事务类型
, cust_code --  客商编码
, cust_name --  客商名称
, cp_company_code -- 对方公司
, cust_mdg_code --  客商编码-MDG

/*20260518 新增使用客商带出的相关信息字段*/
, cust_unity_name
, credit_level_name
, cust_nature_name
, cust_type_name
, channel_l1_code
, channel_l1_name
, channel_l2_code
, channel_l2_name
, channel_l3_code
, channel_l3_name
, marketing_mode_code
, marketing_mode_name
, channel_big_class_code
, channel_big_class_name
, channel_small_class_code
, channel_small_class_name
, ind_big_class_code
, ind_big_class_name
, ind_small_class_code
, ind_small_class_name

/*20260520 新增miniled类型字段*/
, miniled_type_code
, miniled_type_name

)
WITH nf_map_1  AS 
(

  SELECT  batch_id AS xh --  处理优先级
        , logic_name AS lj --  逻辑处理
        , b.cod_azienda AS vkorg --  公司包含
        , c.cod_azienda AS ctp
        , cust_code AS kunrg --  客商包含
        , cust_ex_code AS kunrg_out
        , sold_to_code AS sold_to --  售达方包含
        , sold_to_ex_code AS sold_to_out
        , product_line_src_code AS org_prctr_before --  处理前利润中心
        , onoffline_src_code AS nf_before
        , onoffline_code AS nf
        , onoffline_name AS nf_name
   FROM dim.dim_rule_fi_mr_nf_mapping a 
   LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
  WHERE valid_fr <= @year_month_day
    AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
 )

/******BSEG调整数据限制科目6001%******/
SELECT  bseg.gjahr AS year
      , bkpf.monat AS month
      , bseg.bukrs AS company_code
      , CASE WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_code
             WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_code
             WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_code
             ELSE COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf,'020_OFF_002') 
        END AS onoffline_code
      , CASE WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_name
             WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_name
       WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_name
             ELSE COALESCE(form_dati_nf5.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name,'零售-传统零售') 
       END AS onoffline_name
      -- , CASE WHEN bseg.bukrs IN ('1630','1632') THEN '020_ON_002' ELSE '020_OFF_002' END AS onoffline_code
      -- , CASE WHEN bseg.bukrs IN ('1630','1632') THEN '主站' ELSE '零售-传统零售' END AS onoffline_name
      , '' AS product_line_code
      --  , 0 AS bill_qty
      -- , bseg.menge AS bill_qty
      , CASE WHEN bseg.shkzg = 'H' THEN bseg.menge ELSE -1*bseg.menge END AS bill_qty /*alter by 20260710 xiaoaychao.ex消除600系统总账调整销量管报未获取 */
      , bseg.pswsl AS qcy_code
      , CASE WHEN bseg.shkzg = 'S' THEN bseg.dmbtr ELSE -1*bseg.dmbtr END AS rev_sale_amt
      , 'S600' AS system_src
      , 'BSEG' AS ods_src
      , bseg.belnr AS bill_cert_id
      , bseg.hkont AS acct_src_code
      , bseg.hkont AS acct_map_code
      , bkpf.glvor AS order_type_code
      , NOW() AS load_dt
      , CONCAT(bseg.gjahr,bkpf.monat) AS dt_month
      , CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END AS profitcenter_code
      , '' AS profitcenter_name
      , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model 
      , mara.zcalasset AS zcalasset  
      , CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order 
             ELSE ''  
        END AS bus_range_code
      , '' AS bus_range_name
      , CASE WHEN bseg.bukrs IN ('6012','2023') THEN CASE WHEN bseg.shkzg = 'S' THEN bseg.dmbtr ELSE -1*bseg.dmbtr END
             ELSE CASE WHEN bseg.shkzg = 'S' THEN bseg.wrbtr ELSE -1*bseg.wrbtr END
        END AS rev_sale_bcy_amt
      , CASE WHEN (SUBSTR(bseg.bukrs, 1, 2) IN ('62', '68') OR bseg.bukrs IN ('6012', '6015') 
                   OR ((SUBSTR(bseg.bukrs, 1, 2) = '12' OR SUBSTR(bseg.bukrs, 1, 4) IN ('1180','1183')) AND (mara.big_class_code = 'P02' OR NVL(TRIM(bseg.matnr),'') = ''))
                  )
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,Mapping_Bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') IN ('1209901','1209905','G209901') 
                         AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
                                    THEN mara.bus_range_code
                                  WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
                                  WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
                                  WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order 
                                  ELSE ''  
                              END NOT IN ('2358','A004','2357')
                THEN '1209901' ELSE NULL END ,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                         )
          ELSE '' 
     END AS marketing_dept_code
    , bseg.matnr AS material_code
    , mara.product_name AS material_name
    /*20260128 新增使用物料带出的相关信息字段*/
    , REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') AS material_group_code -- 物料组
    , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
          ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
          ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
        ) AS sale_model_code -- 销售型号编码
    /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
     ,COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name
    , mara.prod_suite_code AS product_sale_series_code --  产品套系编码
    , mara.prod_suite_name AS product_sale_series_name --  产品套系名称
    , mara.prod_stage_code AS product_stage_code --  产品阶段编码
    , mara.prod_stage_name AS product_stage_name --  产品阶段名称
    , mara.price_range_code AS price_range_code --  价格段编码
    , mara.price_range_name AS price_range_name --  价格段名称
    , mara.model_code AS model_code --  产品型号编码
    , mara.model_name AS model_name --  产品型号名称
    , mara.series_code AS product_series_code --  产品系列编码
    , mara.series_name AS product_series_name --  产品系列名称
    , mara.market_pos_code AS market_pnt_code --  营销定位编码
    , mara.market_pos_name AS market_pnt_name --  营销定位名称
    , mara.ac_ct_code AS tech_type_code --  技术类型编码
    , mara.ac_ct_name AS tech_type_name --  技术类型名称
    , CASE WHEN mara.is_miniled_code  = 'PC00013001' THEN '是'
         WHEN mara.is_miniled_code  = 'PC00013002' THEN '否'
         ELSE ''
      END AS is_miniled_code --  是否MiniLED编码
    , mara.big_class_code AS product_big_class_code --  产品大类编码
    , mara.big_class_name AS product_big_class_name --  产品大类名称
    , mara.middle_class_code AS product_mid_class_code --  产品中类编码
    , mara.middle_class_name AS product_mid_class_name --  产品中类名称
    , mara.small_class_code AS product_small_class_code --  产品小类编码
    , mara.small_class_name AS product_small_class_name --  产品小类名称
    , mara.model_lca AS model_lca_code --  产品型号生命周期编码
    , mara.model_lca_name AS model_lca_name --  产品型号生命周期名称
    , mara.brand AS brand_code --  品牌编码
    , mara.brand_name AS brand_name --  品牌名称
    ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
  END AS spec_section_code --  规格段编码
    ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
  END  AS spec_section_name --  规格段名称
    , mara.product_spec_code AS product_shape_type_code --  产品形态分类编码
    , mara.product_spec_name AS product_shape_type_name --  产品形态分类名称
    , bseg.prctr AS src_profitcenter_code
    , bseg.gsber AS src_bus_range_code
    , gla_bseg.zzqdb AS comm_bu_code -- 电商BU渠道细分编码
    , '' AS comm_bu_name -- 电商BU渠道细分描述
    , gla_bseg.zzqdp AS cn_class_mark_code -- 中国区品类标记编码
    , CASE WHEN gla_bseg.zzqdp = 'Z1' THEN '中国区' WHEN gla_bseg.zzqdp = 'Z2' THEN '品线' END AS cn_class_mark_name -- 中国区品类标记描述
    , zbsart AS bus_sce_cat_code -- 业务场景分类编码
    , zbsart_txt AS bus_sce_cat_name -- 业务场景分类描述
    , bseg.vorgn  AS transaction_type -- 事务类型
    , bseg.xref3 as cust_code --  客商编码
    , kna1.name1 AS cust_name --  客商名称
    , NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) AS cp_company_code --  对方公司
    , kna1.zkunnr_mdg AS cust_mdg_code --  客商编码-MDG

    , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name
    , dim_customer_base_info_dd.credit_level AS credit_level_name
    , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name
    , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
            AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
            AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
            THEN NULL
            ELSE TRIM(
                  REGEXP_REPLACE(
                      CONCAT_WS(',',
                          CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                          CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                          CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                      ),
                      '(^,)|(,$)',  
                      ''            
                  )
              ) END AS cust_type_name
    , dim_customer_base_info_dd.com_1st_code AS channel_l1_code
    , dim_customer_base_info_dd.com_1st_name AS channel_l1_name
    , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code
    , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name
    , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code
    , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name
    , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code
    , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name
    , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code
    , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name
    , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code
    , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name
    , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code
    , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name
    , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code
    , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name
    /*20260520 新增miniled类型字段*/
    , mara.miniled_type_code
    , mara.miniled_type_name
  FROM (SELECT * 
          FROM ods.ods_slt_s600_bseg_v
         WHERE IFNULL(TRIM(aufnr),'') = ''
           AND hkont like '6001%' 
           -- ADD BY CHENJUNTAO.EX  detail取总账调整的部分不排除6098
           -- AND bukrs NOT IN ('6098')
        ) bseg
  INNER JOIN (SELECT * 
               FROM ods.ods_slt_s600_bkpf_v 
              WHERE gjahr = substr(@year_month_day,1,4)
                AND monat = substr(@year_month_day,5,2)
             ) bkpf
    ON bseg.belnr = bkpf.belnr 
   AND bseg.gjahr = bkpf.gjahr 
   AND bseg.bukrs = bkpf.bukrs
LEFT JOIN 
  (
    SELECT DISTINCT bukrs,belnr,gjahr,buzei,zzqdb,zzqdp,zbsart,zbsart_txt FROM ods.odss600_zfzt_gla_bseg
  ) gla_bseg
  ON gla_bseg.bukrs = bseg.bukrs
  AND gla_bseg.belnr = bseg.belnr
  AND gla_bseg.gjahr = bseg.gjahr
  AND gla_bseg.buzei = bseg.buzei
  LEFT JOIN dim.dim_rule_fi_mr_cust2ctp_mapping cust2ctp --  经分项目收入模块规则映射表                                      
    ON LTRIM(BSEG.xref3,0) = LTRIM(cust2ctp.cust_code,0)
  AND cust2ctp.cust_type_code = 'C'
  AND cust2ctp.system_src = 'S600'

   LEFT JOIN nf_map_1 form_dati_nf1--  匹配线上线下映射表 按公司匹配
     ON 1=1
    --  公司包含匹配
    AND bseg.bukrs = form_dati_nf1.vkorg
    AND form_dati_nf1.xh = '1'

   LEFT JOIN nf_map_1 form_dati_nf2--  匹配线上线下映射表 按公司+客商匹配
     ON 1=1
    --  公司包含匹配
    AND bseg.bukrs = form_dati_nf2.vkorg
    --  客商匹配
    AND LTRIM(bseg.xref3, '0') = form_dati_nf2.kunrg
    AND form_dati_nf2.xh = '2'

   LEFT JOIN nf_map_1 form_dati_nf5--  匹配线上线下映射表 按公司+对方公司匹配
     ON 1=1
    --  公司匹配
    AND bseg.bukrs = form_dati_nf5.vkorg
    --  对方公司匹配
    AND NVL(cust2ctp.cp_company_code_mr, cust2ctp.cp_company_code) = form_dati_nf5.ctp
    AND form_dati_nf5.xh = '5'

  LEFT JOIN dim.dim_fi_mr_product_dd mara --  物料大表
    ON bseg.matnr = mara.matnr
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_sap2pb_map a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
                AND sapversion = 'S600'
            ) AS sap2pb
    ON LTRIM(bseg.belnr,'0') = LTRIM(sap2pb.belnr,'0')
   AND bseg.bukrs = sap2pb.company_code
   AND LTRIM(bseg.buzei,'0') = LTRIM(sap2pb.buzei,'0')
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON bseg.matnr = mt2bd.material_code
  LEFT JOIN dim.dim_rule_fi_mr_BusScope_for_Company bus_range_map2
    ON bseg.bukrs = bus_range_map2.company_code
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus) Mapping_Bus
    ON bseg.matnr = Mapping_Bus.MATERIAL_CODE
  LEFT JOIN dw.dim_product_base_info_dd
    ON bseg.matnr = dim_product_base_info_dd.product_code
    /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus2
    ON bseg.matnr = Mapping_Bus2.MATERIAL_CODE
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus1
    ON bseg.matnr = Mapping_Bus1.MATERIAL_CODE
   AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order 
             ELSE ''  
        END = Mapping_Bus1.bus_range_code

  -- 新增业务管理单元取数逻辑
  LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON REGEXP_REPLACE(CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END, '^0+', '') = profit_mapping0.profitcenter_code
   AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order 
             ELSE ''  
        END  = profit_mapping0.bus_range_code
  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping1.material_group_code)
   AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order 
             ELSE ''  
        END  = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON REGEXP_REPLACE(CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END, '^0+', '') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order 
             ELSE ''  
        END = profit_mapping4.bus_range_code                 
   -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=1，物料+业务范围匹配，优先级1）
  LEFT JOIN (
      SELECT material_code, bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '1'
  ) cn_onoffline_map1
    ON bseg.matnr = cn_onoffline_map1.material_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')
   AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order 
             ELSE ''  
        END = cn_onoffline_map1.bus_range_code
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=2，仅物料匹配，优先级2）
  LEFT JOIN (
      SELECT material_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '2'
  ) cn_onoffline_map2
    ON bseg.matnr = cn_onoffline_map2.material_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')                     
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=3，事务类型+业务范围匹配，优先级3）
  LEFT JOIN (
      SELECT umsks,bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '3'
  ) cn_onoffline_map3
    ON bseg.vorgn = cn_onoffline_map3.umsks--  事务类型
    AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order 
             ELSE ''  
        END = cn_onoffline_map3.bus_range_code--  业务范围
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')   
-- ADD ZZS XSJ 20260330ZZS修改：新增客商编码，名称，对方公司取值逻辑
LEFT JOIN ods.ods_slt_s600_kna1 kna1 --  客户主数据
  ON LTRIM(BSEG.xref3,0) = LTRIM(kna1.kunnr,0)
LEFT JOIN dw.dim_customer_base_info_dd --  匹配客商主数据
  ON kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
  ON kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
 AND bseg.bukrs = dim_customer_trade_info_dd.sale_org
 AND REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = dim_customer_trade_info_dd.material_group_code


;



/******BSEG成本数据限制科目6401% '6609%'******/
 INSERT INTO dwd.dwd_fi_mr_gp_detail_mi 
 (
 year
,month
,company_code
,onoffline_code
,onoffline_name
,product_line_code
,qcy_code
,cogs_amt
,system_src
,ods_src
,bill_cert_id
,acct_src_code
,acct_map_code
,order_type_code
,load_dt,dt_month
,material_code
,material_name
,profitcenter_code
,profitcenter_name
,customer_model
,zcalasset
,material_group_name
,bus_range_code
,bus_range_name
,marketing_dept_code
/*20260128 新增使用物料带出的相关信息字段*/
, material_group_code -- 物料组
, sale_model_code -- 销售型号编码
, sale_model_name -- 销售型号名称
, product_sale_series_code --  产品套系编码
, product_sale_series_name --  产品套系名称
, product_stage_code --  产品阶段编码
, product_stage_name --  产品阶段名称
, price_range_code --  价格段编码
, price_range_name --  价格段名称
, model_code --  产品型号编码
, model_name --  产品型号名称
, product_series_code --  产品系列编码
, product_series_name --  产品系列名称
, market_pnt_code --  营销定位编码
, market_pnt_name --  营销定位名称
, tech_type_code --  技术类型编码
, tech_type_name --  技术类型名称
, is_miniled_code --  是否MiniLED编码
, product_big_class_code --  产品大类编码
, product_big_class_name --  产品大类名称
, product_mid_class_code --  产品中类编码
, product_mid_class_name --  产品中类名称
, product_small_class_code --  产品小类编码
, product_small_class_name --  产品小类名称
, model_lca_code --  产品型号生命周期编码
, model_lca_name --  产品型号生命周期名称
, brand_code --  品牌编码
, brand_name --  品牌名称
, spec_section_code --  规格段编码
, spec_section_name --  规格段名称
, product_shape_type_code --  产品形态分类编码
, product_shape_type_name --  产品形态分类名称
, src_profitcenter_code
, src_bus_range_code
, transaction_type --  事务类型
, cust_code --  客商编码
, cust_name --  客商名称
, cp_company_code -- 对方公司
, cust_mdg_code --  客商编码-MDG

/*20260518 新增使用客商带出的相关信息字段*/
, cust_unity_name
, credit_level_name
, cust_nature_name
, cust_type_name
, channel_l1_code
, channel_l1_name
, channel_l2_code
, channel_l2_name
, channel_l3_code
, channel_l3_name
, marketing_mode_code
, marketing_mode_name
, channel_big_class_code
, channel_big_class_name
, channel_small_class_code
, channel_small_class_name
, ind_big_class_code
, ind_big_class_name
, ind_small_class_code
, ind_small_class_name

/*20260520 新增miniled类型字段*/
, miniled_type_code
, miniled_type_name
, bus_sce_cat_code -- 业务场景分类编码
, bus_sce_cat_name -- 业务场景分类描述

--20260820FJF_ADD 
, comm_bu_code -- 电商BU渠道细分编码
, comm_bu_name -- 电商BU渠道细分描述
, cn_class_mark_code -- 中国区品类标记编码
, cn_class_mark_name -- 中国区品类标记描述
)
WITH nf_map_1  AS 
(
  SELECT  batch_id AS xh --  处理优先级
        , logic_name AS lj --  逻辑处理
        , b.cod_azienda AS vkorg --  公司包含
        , c.cod_azienda AS ctp
        , cust_code AS kunrg --  客商包含
        , cust_ex_code AS kunrg_out
        , sold_to_code AS sold_to --  售达方包含
        , sold_to_ex_code AS sold_to_out
        , product_line_src_code AS org_prctr_before --  处理前利润中心
        , onoffline_src_code AS nf_before
        , onoffline_code AS nf
        , onoffline_name AS nf_name
   FROM dim.dim_rule_fi_mr_nf_mapping a 
   LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
  WHERE valid_fr <= @year_month_day
    AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
 )
SELECT  bseg.gjahr AS year
      , bkpf.monat AS month
      , bseg.bukrs AS company_code
      /*ADD SXX XSJ 20260320中国区特殊逻辑（优先级最高）
    一。当公司=1180或12%时：
    1.通过物料编码【material_code 】+业务范围【bus_range_code】关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=1的渠道分组编码【onoffline_code】
    2.通过物料编码【material_code】关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=2的渠道分组编码【onoffline_code】
    3.通过事务类型【VORGN】+业务范围【bus_range_code】关联关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=3的渠道分组编码【onoffline_code】
    通过以上逻辑没匹配上的，再按以下逻辑取值：
    NVL(form_dati_nf1.onoffline_code,'020_OFF_002')*/
      , CASE WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_code
             WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_code
       WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_code
             ELSE COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf,'020_OFF_002') 
      END AS onoffline_code
      , CASE WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_name
             WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_name
       WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_name
             ELSE COALESCE(form_dati_nf5.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name,'零售-传统零售') 
     END AS onoffline_name
      -- , CASE WHEN bseg.bukrs IN ('1630','1632') THEN '020_ON_002' ELSE '020_OFF_002' END AS onoffline_code
      -- , CASE WHEN bseg.bukrs IN ('1630','1632') THEN '主站' ELSE '零售-传统零售' END AS onoffline_name
      -- , '020_OFF_002' AS onoffline_code
      -- , '零售-传统零售' AS onoffline_name
      , '' AS product_line_code
      , bseg.pswsl AS qcy_code
      , CASE WHEN bseg.shkzg = 'S' THEN bseg.dmbtr ELSE -1*bseg.dmbtr END AS cogs_amt
      , 'S600' AS system_src
      , 'BSEG' AS ods_src
      , bseg.belnr AS bill_cert_id
      , bseg.hkont AS acct_src_code
      , bseg.hkont AS acct_map_code
      , bkpf.glvor AS order_type_code
      , NOW() AS load_dt
      , CONCAT(bseg.gjahr,bkpf.monat) AS dt_month
      -- EDIT BY LC 260202 老管报针对冲销的RE凭证物料号在分配字段的，增加了取分配字段物料号的逻辑
      , CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END AS material_code
      , mara.product_name AS material_name
      , CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END AS profitcenter_code
      , '' AS profitcenter_name
      , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model
      , mara.zcalasset AS zcalasset                      
      , t023t.wgbez AS material_group_name
      /*, base.brand AS brand_code --  2026.1.6 yanghao 新增 取品牌编码及名称逻辑
      , base.brand_name AS brand_name*/
      , CASE 
             WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END AS bus_range_code
      , '' AS bus_range_name
      , CASE WHEN (SUBSTR(bseg.bukrs, 1, 2) IN ('62', '68') OR bseg.bukrs IN ('6012', '6015') 
                  OR ((SUBSTR(bseg.bukrs, 1, 2) = '12' OR SUBSTR(bseg.bukrs, 1, 4) IN ('1180','1183')) AND (mara.big_class_code = 'P02'OR NVL(TRIM(CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
                                                                                                                                                        ELSE TRIM(bseg.matnr)
                                                                                                                                                      END),'') = ''))
                  )
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,Mapping_Bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') IN ('1209901','1209905','G209901') 
                         AND  CASE 
                                  WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
                                    THEN mara.bus_range_code
                                  WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
                                  WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
                                  WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
                                  WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
                                  WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
                                  ELSE '2000'
                              END NOT IN ('2358','A004','2357')
                         THEN '1209901' ELSE NULL END,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                         )
          ELSE '' 
     END AS marketing_dept_code
     /*20260128 新增使用物料带出的相关信息字段*/
    , REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') AS material_group_code -- 物料组
    , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
          ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
          ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
        ) AS sale_model_code -- 销售型号编码
    /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
    ,COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name
    , mara.prod_suite_code AS product_sale_series_code --  产品套系编码
    , mara.prod_suite_name AS product_sale_series_name --  产品套系名称
    , mara.prod_stage_code AS product_stage_code --  产品阶段编码
    , mara.prod_stage_name AS product_stage_name --  产品阶段名称
    , mara.price_range_code AS price_range_code --  价格段编码
    , mara.price_range_name AS price_range_name --  价格段名称
    , mara.model_code AS model_code --  产品型号编码
    , mara.model_name AS model_name --  产品型号名称
    , mara.series_code AS product_series_code --  产品系列编码
    , mara.series_name AS product_series_name --  产品系列名称
    , mara.market_pos_code AS market_pnt_code --  营销定位编码
    , mara.market_pos_name AS market_pnt_name --  营销定位名称
    , mara.ac_ct_code AS tech_type_code --  技术类型编码
    , mara.ac_ct_name AS tech_type_name --  技术类型名称
    , CASE WHEN mara.is_miniled_code  = 'PC00013001' THEN '是'
         WHEN mara.is_miniled_code  = 'PC00013002' THEN '否'
         ELSE ''
      END AS is_miniled_code --  是否MiniLED编码
    , mara.big_class_code AS product_big_class_code --  产品大类编码
    , mara.big_class_name AS product_big_class_name --  产品大类名称
    , mara.middle_class_code AS product_mid_class_code --  产品中类编码
    , mara.middle_class_name AS product_mid_class_name --  产品中类名称
    , mara.small_class_code AS product_small_class_code --  产品小类编码
    , mara.small_class_name AS product_small_class_name --  产品小类名称
    , mara.model_lca AS model_lca_code --  产品型号生命周期编码
    , mara.model_lca_name AS model_lca_name --  产品型号生命周期名称
    , mara.brand AS brand_code --  品牌编码
    , mara.brand_name AS brand_name --  品牌名称
    ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
  END AS spec_section_code --  规格段编码
    ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
  END  AS spec_section_name --  规格段名称
    , mara.product_spec_code AS product_shape_type_code --  产品形态分类编码
    , mara.product_spec_name AS product_shape_type_name --  产品形态分类名称
    , bseg.prctr AS src_profitcenter_code
    , bseg.gsber AS src_bus_range_code
    , bseg.vorgn as transaction_type --  事务类型
    , bseg.xref3 as cust_code --  客商编码
    , kna1.name1 AS cust_name --  客商名称
    , NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) AS cp_company_code --  对方公司
    , kna1.zkunnr_mdg AS cust_mdg_code --  客商编码-MDG

    , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name
    , dim_customer_base_info_dd.credit_level AS credit_level_name
    , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name
    , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
            AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
            AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
            THEN NULL
            ELSE TRIM(
                  REGEXP_REPLACE(
                      CONCAT_WS(',',
                          CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                          CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                          CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                      ),
                      '(^,)|(,$)',  
                      ''            
                  )
              ) END AS cust_type_name
    , dim_customer_base_info_dd.com_1st_code AS channel_l1_code
    , dim_customer_base_info_dd.com_1st_name AS channel_l1_name
    , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code
    , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name
    , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code
    , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name
    , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code
    , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name
    , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code
    , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name
    , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code
    , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name
    , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code
    , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name
    , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code
    , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name

    /*20260520 新增miniled类型字段*/
    , mara.miniled_type_code
    , mara.miniled_type_name
  , gla_bseg.zbsart AS bus_sce_cat_code -- 业务场景分类编码
    , gla_bseg.zbsart_txt AS bus_sce_cat_name -- 业务场景分类描述
	
	--20260820FJF_ADD
	, gla_bseg.zzqdb AS comm_bu_code -- 电商BU渠道细分编码
    , '' AS comm_bu_name -- 电商BU渠道细分描述
    , gla_bseg.zzqdp AS cn_class_mark_code -- 中国区品类标记编码
    , CASE WHEN gla_bseg.zzqdp = 'Z1' THEN '中国区' WHEN gla_bseg.zzqdp = 'Z2' THEN '品线' END AS cn_class_mark_name -- 中国区品类标记描述

  FROM (SELECT * 
          FROM ods.ods_slt_s600_bseg_v bseg_inner
         WHERE IFNULL(TRIM(aufnr),'') = ''
           -- AND NOT(  hkont IN ('6609990101',  '6609990102',  '6609990103')AND bukrs IN ('6500' ,'6510','6515') )
           -- AND NOT(  hkont IN ('6609990101',  '6609990102','6609990103','6609990200') AND (bukrs BETWEEN '2300' AND '2330' OR bukrs ='2050') )
           -- 2026.3.2 yanghao新增 逻辑限制条件1.2. DWD_FI_MR_GP_DETAIL_MI取销售成本的逻辑，针对2023公司，限制只取6401000000 6401999900这俩科目；
           -- AND (bukrs = '2023' AND hkont IN ('6401000000',  '6401999900') OR bukrs <> '2023')
          --  原条件1+2：排除特定科目和公司的组合
          -- 如果配置了【剔除科目】，限制6401%，6609%并且剔除【剔除科目】的科目
          
          AND (
          --  改为：通过配置表排除特定科目
           NOT EXISTS (
           -- 排除科目
              SELECT 1 
              FROM dim.dim_rule_fi_mr_cost_account_scope_configuration cfg_exclude
              WHERE cfg_exclude.company_code = bseg_inner.bukrs 
                AND CAST(cfg_exclude.ex_hkont AS STRING) = bseg_inner.hkont
                AND cfg_exclude.ex_hkont IS NOT NULL
          )
          AND EXISTS (
          -- 存在排除科目限制
              SELECT 1 
              FROM dim.dim_rule_fi_mr_cost_account_scope_configuration cfg_exclude
              WHERE cfg_exclude.company_code = bseg_inner.bukrs 
                AND cfg_exclude.ex_hkont IS NOT NULL
          )
          AND NOT EXISTS (
          -- 且不存在包含科目限制
              SELECT 1 
              FROM dim.dim_rule_fi_mr_cost_account_scope_configuration cfg_exclude
              WHERE cfg_exclude.company_code = bseg_inner.bukrs 
                AND cfg_exclude.hkont IS NOT NULL
          )
          AND (bseg_inner.hkont like '6401%' OR bseg_inner.hkont like '6609%')
          
             --  如果公司有包含配置，则hkont必须在包含列表中
             -- 如果在配置表维护了【科目】列，根据【科目】列的配置限制；
              OR  EXISTS (
                  SELECT 1
                  FROM dim.dim_rule_fi_mr_cost_account_scope_configuration cfg_include
                  WHERE cfg_include.company_code = bseg_inner.bukrs 
                    AND bseg_inner.hkont = CAST(cfg_include.hkont AS STRING)
                    AND cfg_include.hkont IS NOT NULL
              )
              
              OR 
              -- 如果没在配置表配的公司，按6401%，6609%限制；
              NOT EXISTS (
                  SELECT 1 
                  FROM dim.dim_rule_fi_mr_cost_account_scope_configuration cfg_check
                  WHERE cfg_check.company_code = bseg_inner.bukrs 
                    AND (cfg_check.hkont IS NOT NULL
                    OR cfg_check.ex_hkont IS NOT NULL
                    )
              )
              AND (bseg_inner.hkont like '6401%' OR bseg_inner.hkont like '6609%')
          )
        ) bseg
  INNER JOIN (SELECT * 
               FROM ods.ods_slt_s600_bkpf_v 
              WHERE gjahr = substr(@year_month_day,1,4)
                AND monat = substr(@year_month_day,5,2)
             ) bkpf
    ON bseg.belnr = bkpf.belnr 
   AND bseg.gjahr = bkpf.gjahr 
   AND bseg.bukrs = bkpf.bukrs
   
LEFT JOIN 
  (
    SELECT DISTINCT bukrs,belnr,gjahr,buzei,zzqdb,zzqdp,zbsart,zbsart_txt FROM ods.odss600_zfzt_gla_bseg
  ) gla_bseg
  ON gla_bseg.bukrs = bseg.bukrs
  AND gla_bseg.belnr = bseg.belnr
  AND gla_bseg.gjahr = bseg.gjahr
  AND gla_bseg.buzei = bseg.buzei
  
  LEFT JOIN dim.dim_rule_fi_mr_cust2ctp_mapping cust2ctp --  经分项目收入模块规则映射表                                      
    ON LTRIM(bseg.xref3,0) = LTRIM(cust2ctp.cust_code,0)
   AND cust2ctp.cust_type_code = 'C'
   AND cust2ctp.system_src = 'S600'

  LEFT JOIN nf_map_1 form_dati_nf1--  匹配线上线下映射表 按公司匹配
     ON 1=1
    --  公司包含匹配
    AND bseg.bukrs = form_dati_nf1.vkorg
    AND form_dati_nf1.xh = '1'
   LEFT JOIN nf_map_1 form_dati_nf2--  匹配线上线下映射表 按公司+客商匹配
     ON 1=1
    --  公司包含匹配
    AND bseg.bukrs = form_dati_nf2.vkorg
    --  客商匹配
    AND LTRIM(bseg.xref3, '0') = form_dati_nf2.kunrg
    AND form_dati_nf2.xh = '2'

   LEFT JOIN nf_map_1 form_dati_nf5--  匹配线上线下映射表 按公司+对方公司匹配
     ON 1=1
    --  公司匹配
    AND bseg.bukrs = form_dati_nf5.vkorg
    --  对方公司匹配
    AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) LIKE form_dati_nf5.ctp
    AND form_dati_nf5.xh = '5'


  LEFT JOIN dim.dim_fi_mr_product_dd mara --  物料大表
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = mara.matnr
  LEFT JOIN ods.ods_s600_t023t t023t --  物料组名称表
    ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = t023t.matkl
   AND t023t.spras = '1'
  --  2026.1.6 yanghao 新增 取品牌编码及名称逻辑
  LEFT JOIN dw.dim_product_base_info_dd base -- 产品主数据基本信息
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = base.product_code
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_sap2pb_map a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
                AND sapversion = 'S600'
            ) AS sap2pb
    ON LTRIM(bseg.belnr,'0') = LTRIM(sap2pb.belnr,'0')
   AND bseg.bukrs = sap2pb.company_code
   AND LTRIM(bseg.buzei,'0') = LTRIM(sap2pb.buzei,'0')
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = mt2bd.material_code
  LEFT JOIN dim.dim_rule_fi_mr_BusScope_for_Company bus_range_map2
    ON bseg.bukrs = bus_range_map2.company_code
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus) Mapping_Bus
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = Mapping_Bus.MATERIAL_CODE
  LEFT JOIN dw.dim_product_base_info_dd
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = dim_product_base_info_dd.product_code
      /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus2
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = Mapping_Bus2.MATERIAL_CODE
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus1
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = Mapping_Bus1.MATERIAL_CODE
   AND  CASE 
             WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = Mapping_Bus1.bus_range_code

  -- 新增业务管理单元取数逻辑
  LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON REGEXP_REPLACE(CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END, '^0+', '') = profit_mapping0.profitcenter_code
    AND CASE 
             WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = profit_mapping0.bus_range_code
  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping1.material_group_code)
   AND CASE 
             WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END  = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON REGEXP_REPLACE(CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END, '^0+', '') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE 
             WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = profit_mapping4.bus_range_code        
     -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=1，物料+业务范围匹配，优先级1）
  LEFT JOIN (
      SELECT material_code, bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '1'
  ) cn_onoffline_map1
   ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = cn_onoffline_map1.material_code
   AND CASE 
             WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = cn_onoffline_map1.bus_range_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=2，仅物料匹配，优先级2）
  LEFT JOIN (
      SELECT material_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '2'
  ) cn_onoffline_map2
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = cn_onoffline_map2.material_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')                     
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=3，事务类型+业务范围匹配，优先级3）
  LEFT JOIN (
      SELECT umsks,bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '3'
  ) cn_onoffline_map3
    ON bseg.vorgn = cn_onoffline_map3.umsks--  事务类型
    AND CASE 
             WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = cn_onoffline_map3.bus_range_code--  业务范围
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')     
 -- ADD ZZS XSJ 20260330ZZS修改：新增客商编码，名称，对方公司取值逻辑
LEFT JOIN ods.ods_slt_s600_kna1 kna1 --  客户主数据
  ON LTRIM(bseg.xref3,0) = LTRIM(kna1.kunnr,0)
LEFT JOIN dw.dim_customer_base_info_dd --  匹配客商主数据
  ON kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
  ON kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
 AND bseg.bukrs = dim_customer_trade_info_dd.sale_org
 AND REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = dim_customer_trade_info_dd.material_group_code


    UNION ALL 
    /*UE凭证扣减数据-成本*/
    SELECT  bseg.gjahr AS year
      , bkpf.monat AS month
      , bseg.bukrs AS company_code
      /*ADD SXX XSJ 20260320中国区特殊逻辑（优先级最高）
    一。当公司=1180或12%时：
    1.通过物料编码【material_code 】+业务范围【bus_range_code】关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=1的渠道分组编码【onoffline_code】
    2.通过物料编码【material_code】关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=2的渠道分组编码【onoffline_code】
    3.通过事务类型【VORGN】+业务范围【bus_range_code】关联关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=3的渠道分组编码【onoffline_code】
    通过以上逻辑没匹配上的，再按以下逻辑取值：
    NVL(form_dati_nf1.onoffline_code,'020_OFF_002')*/
      , CASE WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_code
             WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_code
       WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_code
             ELSE COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf,'020_OFF_002') 
     END AS onoffline_code
      , CASE WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_name
             WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_name
       WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_name
             ELSE COALESCE(form_dati_nf5.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name,'零售-传统零售') 
     END AS onoffline_name
      -- , CASE WHEN bseg.bukrs IN ('1630','1632') THEN '020_ON_002' ELSE '020_OFF_002' END AS onoffline_code
      -- , CASE WHEN bseg.bukrs IN ('1630','1632') THEN '主站' ELSE '零售-传统零售' END AS onoffline_name
      -- , '020_OFF_002' AS onoffline_code
      -- , '零售-传统零售' AS onoffline_name
      , '' AS product_line_code
      , bseg.pswsl AS qcy_code
      , CASE WHEN bseg.shkzg = 'H' THEN bseg.dmbtr ELSE -1*bseg.dmbtr END AS cogs_amt
      , 'S600' AS system_src
      , 'BSEG_UE' AS ods_src
      , bseg.belnr AS bill_cert_id
      , bseg.hkont AS acct_src_code
      , bseg.hkont AS acct_map_code
      , bkpf.glvor AS order_type_code
      , NOW() AS load_dt
      , CONCAT(bseg.gjahr,bkpf.monat) AS dt_month
      , bseg.matnr AS material_code
      , mara.product_name AS material_name
      , CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END AS profitcenter_code
      , '' AS profitcenter_name
      , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model
      , mara.zcalasset AS zcalasset                      
      , t023t.wgbez AS material_group_name
      , CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END AS bus_range_code
      , '' AS bus_range_name
      , CASE WHEN (SUBSTR(bseg.bukrs, 1, 2) IN ('62', '68') OR bseg.bukrs IN ('6012', '6015') 
                  OR ((SUBSTR(bseg.bukrs, 1, 2) = '12' OR SUBSTR(bseg.bukrs, 1, 4) IN ('1180','1183')) AND (mara.big_class_code = 'P02' OR NVL(TRIM(bseg.matnr),'') = ''))
                  )
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,Mapping_Bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') IN ('1209901','1209905','G209901') 
                         AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
                                    THEN mara.bus_range_code
                                  WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
                                  WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
                                  WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
                                  WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
                                  ELSE '2000'
                              END NOT IN ('2358','A004','2357')
                THEN '1209901' ELSE NULL END ,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                         )
          ELSE '' 
     END AS marketing_dept_code
            /*20260128 新增使用物料带出的相关信息字段*/
      , REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') AS material_group_code -- 物料组
      , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
                ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
                ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_code -- 销售型号编码
      /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
      ,COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name 
      , mara.prod_suite_code AS product_sale_series_code --  产品套系编码
      , mara.prod_suite_name AS product_sale_series_name --  产品套系名称
      , mara.prod_stage_code AS product_stage_code --  产品阶段编码
      , mara.prod_stage_name AS product_stage_name --  产品阶段名称
      , mara.price_range_code AS price_range_code --  价格段编码
      , mara.price_range_name AS price_range_name --  价格段名称
      , mara.model_code AS model_code --  产品型号编码
      , mara.model_name AS model_name --  产品型号名称
      , mara.series_code AS product_series_code --  产品系列编码
      , mara.series_name AS product_series_name --  产品系列名称
      , mara.market_pos_code AS market_pnt_code --  营销定位编码
      , mara.market_pos_name AS market_pnt_name --  营销定位名称
      , mara.ac_ct_code AS tech_type_code --  技术类型编码
      , mara.ac_ct_name AS tech_type_name --  技术类型名称
      , CASE WHEN mara.is_miniled_code  = 'PC00013001' THEN '是'
             WHEN mara.is_miniled_code  = 'PC00013002' THEN '否'
             ELSE ''
        END AS is_miniled_code --  是否MiniLED编码
      , mara.big_class_code AS product_big_class_code --  产品大类编码
      , mara.big_class_name AS product_big_class_name --  产品大类名称
      , mara.middle_class_code AS product_mid_class_code --  产品中类编码
      , mara.middle_class_name AS product_mid_class_name --  产品中类名称
      , mara.small_class_code AS product_small_class_code --  产品小类编码
      , mara.small_class_name AS product_small_class_name --  产品小类名称
      , mara.model_lca AS model_lca_code --  产品型号生命周期编码
      , mara.model_lca_name AS model_lca_name --  产品型号生命周期名称
      , mara.brand AS brand_code --  品牌编码
      , mara.brand_name AS brand_name --  品牌名称
    ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
     END AS spec_section_code --  规格段编码
      ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
     END  AS spec_section_name --  规格段名称
      , mara.product_spec_code AS product_shape_type_code --  产品形态分类编码
      , mara.product_spec_name AS product_shape_type_name --  产品形态分类名称
      , bseg.prctr AS src_profitcenter_code
      , bseg.gsber AS src_bus_range_code
      , bseg.vorgn as transaction_type --  事务类型
      , bseg.xref3 as cust_code --  客商编码
      , kna1.name1 AS cust_name --  客商名称
      , NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) AS cp_company_code --  对方公司
      , kna1.zkunnr_mdg AS cust_mdg_code --  客商编码-MDG
      
      , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name
      , dim_customer_base_info_dd.credit_level AS credit_level_name
      , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name
      , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
              AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
              AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
              THEN NULL
              ELSE TRIM(
                    REGEXP_REPLACE(
                        CONCAT_WS(',',
                            CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                            CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                            CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                        ),
                        '(^,)|(,$)',  
                        ''            
                    )
                ) END AS cust_type_name
      , dim_customer_base_info_dd.com_1st_code AS channel_l1_code
      , dim_customer_base_info_dd.com_1st_name AS channel_l1_name
      , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code
      , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name
      , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code
      , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name
      , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code
      , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name
      , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code
      , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name
      , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code
      , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name
      , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code
      , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name
      , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code
      , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name
    
       /*20260520 新增miniled类型字段*/
      , mara.miniled_type_code
      , mara.miniled_type_name
    , gla_bseg.zbsart AS bus_sce_cat_code -- 业务场景分类编码
    , gla_bseg.zbsart_txt AS bus_sce_cat_name -- 业务场景分类描述
	
		--20260820FJF_ADD
	, gla_bseg.zzqdb AS comm_bu_code -- 电商BU渠道细分编码
    , '' AS comm_bu_name -- 电商BU渠道细分描述
    , gla_bseg.zzqdp AS cn_class_mark_code -- 中国区品类标记编码
    , CASE WHEN gla_bseg.zzqdp = 'Z1' THEN '中国区' WHEN gla_bseg.zzqdp = 'Z2' THEN '品线' END AS cn_class_mark_name -- 中国区品类标记描述

  FROM (SELECT * 
          FROM ods.ods_slt_s600_bseg_v
         WHERE IFNULL(TRIM(aufnr),'') = ''
           AND hkont IN ('6401000000','6401000100')
           AND (TRIM(MATNR) = ''  OR bukrs LIKE '2%' and substr(@year_month_day,1,6) = '202605') -- 20260605 因SAP修改问题，临时调整
        ) bseg
  INNER JOIN (SELECT * 
               FROM ods.ods_slt_s600_bkpf_v 
              WHERE gjahr = substr(@year_month_day,1,4)
                AND monat = substr(@year_month_day,5,2)
                AND BLART = 'UE' 
                AND STJAH = '0000' AND XBLNR <> ''
             ) bkpf
    ON bseg.belnr = bkpf.belnr 
   AND bseg.gjahr = bkpf.gjahr 
   AND bseg.bukrs = bkpf.bukrs
   
 LEFT JOIN 
  (
    SELECT DISTINCT bukrs,belnr,gjahr,buzei,zzqdb,zzqdp,zbsart,zbsart_txt FROM ods.odss600_zfzt_gla_bseg
  )gla_bseg
  ON gla_bseg.bukrs = bseg.bukrs
  AND gla_bseg.belnr = bseg.belnr
  AND gla_bseg.gjahr = bseg.gjahr
  AND gla_bseg.buzei = bseg.buzei

  LEFT JOIN dim.dim_rule_fi_mr_cust2ctp_mapping cust2ctp --  经分项目收入模块规则映射表                                      
    ON LTRIM(bseg.xref3,0) = LTRIM(cust2ctp.cust_code,0)
   AND cust2ctp.cust_type_code = 'C'
   AND cust2ctp.system_src = 'S600'

  LEFT JOIN nf_map_1 form_dati_nf1--  匹配线上线下映射表 按公司匹配
     ON 1=1
    --  公司包含匹配
    AND bseg.bukrs = form_dati_nf1.vkorg
    AND form_dati_nf1.xh = '1'
   LEFT JOIN nf_map_1 form_dati_nf2--  匹配线上线下映射表 按公司+客商匹配
     ON 1=1
    --  公司包含匹配
    AND bseg.bukrs = form_dati_nf2.vkorg
    --  客商匹配
    AND LTRIM(bseg.xref3, '0') = form_dati_nf2.kunrg
    AND form_dati_nf2.xh = '2'

   LEFT JOIN nf_map_1 form_dati_nf5--  匹配线上线下映射表 按公司+对方公司匹配
     ON 1=1
    --  公司匹配
    AND bseg.bukrs = form_dati_nf5.vkorg
    --  对方公司匹配
    AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = form_dati_nf5.ctp
    AND form_dati_nf5.xh = '5'
  LEFT JOIN dim.dim_fi_mr_product_dd mara --  物料大表
    ON bseg.matnr = mara.matnr
  LEFT JOIN ods.ods_s600_t023t t023t --  物料组名称表
    ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = t023t.matkl
   AND t023t.spras = '1'
  --  2026.1.6 yanghao 新增 取品牌编码及名称逻辑
  LEFT JOIN dw.dim_product_base_info_dd base -- 产品主数据基本信息
    ON bseg.matnr = base.product_code
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_sap2pb_map a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
                AND sapversion = 'S600'
            ) AS sap2pb
    ON LTRIM(bseg.belnr,'0') = LTRIM(sap2pb.belnr,'0')
   AND bseg.bukrs = sap2pb.company_code
   AND LTRIM(bseg.buzei,'0') = LTRIM(sap2pb.buzei,'0')
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON bseg.matnr = mt2bd.material_code
  LEFT JOIN dim.dim_rule_fi_mr_BusScope_for_Company bus_range_map2
    ON bseg.bukrs = bus_range_map2.company_code
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus) Mapping_Bus
    ON bseg.matnr = Mapping_Bus.MATERIAL_CODE
  LEFT JOIN dw.dim_product_base_info_dd
    ON bseg.matnr = dim_product_base_info_dd.product_code
  /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus2
    ON bseg.matnr = Mapping_Bus2.MATERIAL_CODE
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus1
    ON bseg.matnr = Mapping_Bus1.MATERIAL_CODE
   AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = Mapping_Bus1.bus_range_code

  -- 新增业务管理单元取数逻辑
  LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON REGEXP_REPLACE(CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END, '^0+', '') = profit_mapping0.profitcenter_code
   AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END  = profit_mapping0.bus_range_code
  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping1.material_group_code)
   AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END  = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON REGEXP_REPLACE(CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END, '^0+', '') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = profit_mapping4.bus_range_code        
       -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=1，物料+业务范围匹配，优先级1）
  LEFT JOIN (
      SELECT material_code, bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '1'
  ) cn_onoffline_map1
   ON bseg.matnr = cn_onoffline_map1.material_code
   AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = cn_onoffline_map1.bus_range_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=2，仅物料匹配，优先级2）
  LEFT JOIN (
      SELECT material_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '2'
  ) cn_onoffline_map2
    ON bseg.matnr = cn_onoffline_map2.material_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')                     
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=3，事务类型+业务范围匹配，优先级3）
  LEFT JOIN (
      SELECT umsks,bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '3'
  ) cn_onoffline_map3
    ON bseg.vorgn = cn_onoffline_map3.umsks--  事务类型
    AND CASE WHEN bseg.bukrs LIKE '2%' AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) = '2023' 
              THEN mara.bus_range_code
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = cn_onoffline_map3.bus_range_code--  业务范围
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')  
-- ADD ZZS XSJ 20260330ZZS修改：新增客商编码，名称，对方公司取值逻辑
LEFT JOIN ods.ods_slt_s600_kna1 kna1 --  客户主数据
  ON LTRIM(bseg.xref3,0) = LTRIM(kna1.kunnr,0)
LEFT JOIN dw.dim_customer_base_info_dd --  匹配客商主数据
  ON kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
  ON kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
 AND bseg.bukrs = dim_customer_trade_info_dd.sale_org
 AND REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = dim_customer_trade_info_dd.material_group_code


;
/***********************************BSEG调整数据&成本数据插入结束*************************************/

/*****************************特殊处理：COUE UE凭证 - 取销售方收入作为成本****************************/
/* 此逻辑针对特定类型的成本凭证（科目6401开头，凭证类型UE，物料为空）， */
/* 通过关联销售订单，用销售收入金额作为成本金额 */
/* 需确认是否保留此逻辑 */


 INSERT INTO dwd.dwd_fi_mr_gp_detail_mi 
 (
 year
,month
,company_code
,onoffline_code
,onoffline_name
,product_line_code
,qcy_code
,cogs_amt
,system_src
,ods_src
,bill_cert_id
,acct_src_code
,acct_map_code
,order_type_code
,load_dt,dt_month
,material_code
,material_name
,profitcenter_code
,profitcenter_name
,customer_model
,zcalasset
,material_group_name
,bus_range_code
,bus_range_name
-- ,rev_sale_bcy_amt
,marketing_dept_code
/*20260128 新增使用物料带出的相关信息字段*/
, material_group_code -- 物料组
, sale_model_code -- 销售型号编码
, sale_model_name -- 销售型号名称  /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
, product_sale_series_code --  产品套系编码
, product_sale_series_name --  产品套系名称
, product_stage_code --  产品阶段编码
, product_stage_name --  产品阶段名称
, price_range_code --  价格段编码
, price_range_name --  价格段名称
, model_code --  产品型号编码
, model_name --  产品型号名称
, product_series_code --  产品系列编码
, product_series_name --  产品系列名称
, market_pnt_code --  营销定位编码
, market_pnt_name --  营销定位名称
, tech_type_code --  技术类型编码
, tech_type_name --  技术类型名称
, is_miniled_code --  是否MiniLED编码
, product_big_class_code --  产品大类编码
, product_big_class_name --  产品大类名称
, product_mid_class_code --  产品中类编码
, product_mid_class_name --  产品中类名称
, product_small_class_code --  产品小类编码
, product_small_class_name --  产品小类名称
, model_lca_code --  产品型号生命周期编码
, model_lca_name --  产品型号生命周期名称
, brand_code --  品牌编码
, brand_name --  品牌名称
, spec_section_code --  规格段编码
, spec_section_name --  规格段名称
, product_shape_type_code --  产品形态分类编码
, product_shape_type_name --  产品形态分类名称
, src_profitcenter_code
, src_bus_range_code
, transaction_type --  事务类型

/*20260520 新增miniled类型字段*/
, miniled_type_code
, miniled_type_name
, bus_sce_cat_code -- 业务场景分类编码
, bus_sce_cat_name -- 业务场景分类描述

--20260820FJF_ADD
, comm_bu_code -- 电商BU渠道细分编码
, comm_bu_name -- 电商BU渠道细分描述
, cn_class_mark_code -- 中国区品类标记编码
, cn_class_mark_name -- 中国区品类标记描述

)
WITH nf_map_1  AS 
(
  SELECT  batch_id AS xh --  处理优先级
        , logic_name AS lj --  逻辑处理
        , b.cod_azienda AS vkorg --  公司包含
        , c.cod_azienda AS ctp
        , cust_code AS kunrg --  客商包含
        , cust_ex_code AS kunrg_out
        , sold_to_code AS sold_to --  售达方包含
        , sold_to_ex_code AS sold_to_out
        , product_line_src_code AS org_prctr_before --  处理前利润中心
        , onoffline_src_code AS nf_before
        , onoffline_code AS nf
        , onoffline_name AS nf_name
   FROM dim.dim_rule_fi_mr_nf_mapping a 
   LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
  WHERE valid_fr <= @year_month_day
    AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
 )

select  
     bseg_bkpf.gjahr AS year                     
   , bseg_bkpf.monat AS month     
   , bseg_bkpf.bukrs AS company_code                                 
   ,  CASE WHEN (bseg_bkpf.bukrs IN ('1180','118A','118B','1181') OR bseg_bkpf.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_code
           WHEN (bseg_bkpf.bukrs IN ('1180','118A','118B','1181') OR bseg_bkpf.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_code
       WHEN (bseg_bkpf.bukrs IN ('1180','118A','118B','1181') OR bseg_bkpf.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_code
           ELSE NVL(form_dati_nf1.nf,'020_OFF_002') 
     END AS onoffline_code
   ,  CASE WHEN (bseg_bkpf.bukrs IN ('1180','118A','118B','1181') OR bseg_bkpf.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_name
           WHEN (bseg_bkpf.bukrs IN ('1180','118A','118B','1181') OR bseg_bkpf.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_name
       WHEN (bseg_bkpf.bukrs IN ('1180','118A','118B','1181') OR bseg_bkpf.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_name
           ELSE NVL(form_dati_nf1.nf_name,'零售-传统零售') 
     END AS onoffline_name
   -- , CASE WHEN bseg_bkpf.bukrs IN ('1630','1632') THEN '020_ON_002' ELSE '020_OFF_002' END AS onoffline_code
   -- , CASE WHEN bseg_bkpf.bukrs IN ('1630','1632') THEN '主站' ELSE '零售-传统零售' END AS onoffline_name
   -- , '020_OFF_002' AS onoffline_code                                  --  线上/线下代码：固定为线下
   -- , '零售-传统零售' AS onoffline_name                                --  线上/线下名称：固定为线下
   , '' AS product_line_code                              --  产品线代码：暂为空，可根据业务需求添加
   , 'CNY' AS qcy_code                                       --  质量代码：暂为空
   , B.NETWR AS cogs_amt                              --  成本金额：使用销售订单的收入金额作为成本
   , 'S600' AS system_src                                  --  系统来源：SAP系统
   , 'BSEG_060_COUE' AS ods_src                                  --  数据来源：标记为特殊处理逻辑
   , bseg_bkpf.xblnr AS bill_cert_id                                    --  凭证号：暂为空，可关联获取
   , '6401000000' AS acct_src_code                           --  源科目代码：固定为主营业务成本科目
   , '6401000000' AS acct_map_code                           --  映射科目代码：同上
   , 'UE' AS order_type_code                                --  订单类型：凭证类型UE
   , NOW() AS load_dt                                       --  数据加载时间
   , CONCAT(bseg_bkpf.gjahr,bseg_bkpf.monat) AS dt_month                                   --  年月分区
   , b.matnr AS material_code                             --  物料编码：从销售订单获取
   , mara.product_name AS material_name
   , CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
          WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
          ELSE B.profitcenter_code
    END AS profitcenter_code
   , '' AS profitcenter_name
   , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model                       --  客户型号
   , mara.zcalasset AS zcalasset                            --  按套统计  
   , t023t.wgbez AS material_group_name                              --  物料组名称：暂为空，可关联获取
   , CASE WHEN mt2bd.bus_range_code IS NOT NULL THEN mt2bd.bus_range_code 
          WHEN b.bus_range_code IS NOT NULL THEN b.bus_range_code
          WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order
          ELSE ''
     END AS bus_range_code
   , '' AS bus_range_name
   , b.marketing_dept_code AS marketing_dept_code
   -- , SUM(b.rev_sale_bcy_amt) AS rev_sale_bcy_amt
      /*20260128 新增使用物料带出的相关信息字段*/
   , REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') AS material_group_code -- 物料组
   , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
         ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
         ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
       ) AS sale_model_code -- 销售型号编码
   /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
    ,COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name
   , mara.prod_suite_code AS product_sale_series_code --  产品套系编码
   , mara.prod_suite_name AS product_sale_series_name --  产品套系名称
   , mara.prod_stage_code AS product_stage_code --  产品阶段编码
   , mara.prod_stage_name AS product_stage_name --  产品阶段名称
   , mara.price_range_code AS price_range_code --  价格段编码
   , mara.price_range_name AS price_range_name --  价格段名称
   , mara.model_code AS model_code --  产品型号编码
   , mara.model_name AS model_name --  产品型号名称
   , mara.series_code AS product_series_code --  产品系列编码
   , mara.series_name AS product_series_name --  产品系列名称
   , mara.market_pos_code AS market_pnt_code --  营销定位编码
   , mara.market_pos_name AS market_pnt_name --  营销定位名称
   , mara.ac_ct_code AS tech_type_code --  技术类型编码
   , mara.ac_ct_name AS tech_type_name --  技术类型名称
   , CASE WHEN mara.is_miniled_code  = 'PC00013001' THEN '是'
          WHEN mara.is_miniled_code  = 'PC00013002' THEN '否'
          ELSE ''
     END AS is_miniled_code --  是否MiniLED编码
   , mara.big_class_code AS product_big_class_code --  产品大类编码
   , mara.big_class_name AS product_big_class_name --  产品大类名称
   , mara.middle_class_code AS product_mid_class_code --  产品中类编码
   , mara.middle_class_name AS product_mid_class_name --  产品中类名称
   , mara.small_class_code AS product_small_class_code --  产品小类编码
   , mara.small_class_name AS product_small_class_name --  产品小类名称
   , mara.model_lca AS model_lca_code --  产品型号生命周期编码
   , mara.model_lca_name AS model_lca_name --  产品型号生命周期名称
   , mara.brand AS brand_code --  品牌编码
   , mara.brand_name AS brand_name --  品牌名称
   ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
  END AS spec_section_code --  规格段编码
   ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
  END  AS spec_section_name --  规格段名称
   , mara.product_spec_code AS product_shape_type_code --  产品形态分类编码
   , mara.product_spec_name AS product_shape_type_name --  产品形态分类名称
   , b.src_profitcenter_code
   , b.src_bus_range_code
   , bseg_bkpf.vorgn as transaction_type --  事务类型

   /*20260520 新增miniled类型字段*/
   , miniled_type_code
   , miniled_type_name
   , bseg_bkpf.zbsart AS bus_sce_cat_code -- 业务场景分类编码
   , bseg_bkpf.zbsart_txt AS bus_sce_cat_name -- 业务场景分类描述
   
   	--20260820FJF_ADD
	, bseg_bkpf.zzqdb AS comm_bu_code -- 电商BU渠道细分编码
    , '' AS comm_bu_name -- 电商BU渠道细分描述
    , bseg_bkpf.zzqdp AS cn_class_mark_code -- 中国区品类标记编码
    , CASE WHEN bseg_bkpf.zzqdp = 'Z1' THEN '中国区' WHEN bseg_bkpf.zzqdp = 'Z2' THEN '品线' END AS cn_class_mark_name -- 中国区品类标记描述

   FROM 
    /* 子查询A：筛选需要特殊处理的成本凭证 */
    ( 
    select DISTINCT bseg.gjahr,bkpf.monat,bseg.bukrs,/*bseg.prctr,bseg.pswsl,bseg.belnr,bseg.hkont,bkpf.glvor,bseg.matnr,*/bkpf.xblnr
        ,bseg.vorgn,gla_bseg.zbsart,gla_bseg.zbsart_txt 
		,gla_bseg.zzqdb,gla_bseg.zzqdp
    FROM 
      (SELECT * 
        FROM ods.ods_slt_s600_bseg_v
       WHERE 1=1 --  AND BUKRS IN (SELECT BUKRS FROM ENTITY_LIST)
             AND IFNULL(PRCTR, '|') NOT IN ('0016300104')                      --  排除特定利润中心
                 /* 排除特定公司的物料 */
        AND hkont like '6401%'
      ) bseg    
    INNER JOIN (SELECT * 
           FROM ods.ods_slt_s600_bkpf_v 
          WHERE gjahr = substr(@year_month_day,1,4)
          AND monat = substr(@year_month_day,5,2)
         ) bkpf
    ON bseg.belnr = bkpf.belnr 
    AND bseg.gjahr = bkpf.gjahr 
    AND bseg.bukrs = bkpf.bukrs
    
    LEFT JOIN 
    (
      SELECT DISTINCT bukrs,belnr,gjahr,buzei,zzqdb,zzqdp,zbsart,zbsart_txt FROM ods.odss600_zfzt_gla_bseg
    )gla_bseg
    ON gla_bseg.bukrs = bseg.bukrs
    AND gla_bseg.belnr = bseg.belnr
    AND gla_bseg.gjahr = bseg.gjahr
    AND gla_bseg.buzei = bseg.buzei
    
    WHERE 1=1
      /* 科目筛选条件 */
    and HKONT IN ('6401000000', '6401000100')  --  主营业务成本科目
    AND (TRIM(MATNR) = ''  OR bseg.bukrs LIKE '2%' and substr(@year_month_day,1,6) = '202605')                        --  物料号为空20260605因SAP修改错误，临时调整数据
    AND BLART = 'UE'                            --  凭证类型为UE
    AND STJAH = 0                              --  统计年份为0

      
    ) bseg_bkpf
  
/* 关联销售订单表 */
INNER JOIN 
    (SELECT 
        bill_cert_id AS VBELN,      --  销售订单号
        material_code AS MATNR,      --  物料号
        rev_sale_amt AS NETWR,      --  净销售额
        material_group_code AS MATKL,       --  物料组
        rev_sale_bcy_amt,
        marketing_dept_code,
        bus_range_code,
        bus_range_name,
        profitcenter_code,
        src_profitcenter_code,
        src_bus_range_code
      FROM dwd.dwd_fi_mr_gp_detail_mi 
     WHERE 1=1
       AND dt_month = substr(@year_month_day,1,6)                       
       -- AND company_code IN ('2300', '2600', '6700', '6800', '1630', '1632', '2080')  --  销售组织
       /* 排除特定物料范围 */
       AND (material_code IS NULL OR material_code < 'Y000010' OR material_code > 'Y000065')
) B
    ON bseg_bkpf.xblnr = b.vbeln  --  通过参考凭证号关联销售订单
    LEFT JOIN nf_map_1 form_dati_nf1--  匹配线上线下映射表 按公司匹配
     ON 1=1
    --  公司包含匹配
    AND bseg_bkpf.bukrs = form_dati_nf1.vkorg
    and form_dati_nf1.xh = '1'
  LEFT JOIN dim.dim_fi_mr_product_dd mara --  物料大表
    ON LTRIM(b.matnr,0) = LTRIM(mara.matnr,0)
  LEFT JOIN ods.ods_s600_t023t t023t --  物料组名称表
    ON mara.matkl = t023t.matkl
  AND t023t.spras = '1'
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON LTRIM(b.matnr,0) = LTRIM(mt2bd.material_code,0)
  LEFT JOIN dim.dim_rule_fi_mr_BusScope_for_Company bus_range_map2
    ON bseg_bkpf.bukrs = bus_range_map2.company_code
  LEFT JOIN dw.dim_product_base_info_dd
    ON LTRIM(b.matnr,0) = LTRIM(dim_product_base_info_dd.product_code,0)

  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=1，物料+业务范围匹配，优先级1）
  LEFT JOIN (
      SELECT material_code, bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '1'
  ) cn_onoffline_map1
   ON LTRIM(b.matnr,0) = cn_onoffline_map1.material_code
   AND CASE WHEN mt2bd.bus_range_code IS NOT NULL THEN mt2bd.bus_range_code 
            WHEN b.bus_range_code IS NOT NULL THEN b.bus_range_code
            WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order
            ELSE ''
      END = cn_onoffline_map1.bus_range_code
   AND (bseg_bkpf.bukrs IN ('1180','118A','118B','1181') OR bseg_bkpf.bukrs LIKE '12%')  

 -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=2，仅物料匹配，优先级2）
  LEFT JOIN (
      SELECT material_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '2'
  ) cn_onoffline_map2
    ON LTRIM(b.matnr,0) = cn_onoffline_map2.material_code
   AND (bseg_bkpf.bukrs IN ('1180','118A','118B','1181') OR bseg_bkpf.bukrs LIKE '12%')                     
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=3，事务类型+业务范围匹配，优先级3）
  LEFT JOIN (
      SELECT umsks,bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '3'
  ) cn_onoffline_map3
    ON bseg_bkpf.vorgn = cn_onoffline_map3.umsks--  事务类型
    AND CASE WHEN mt2bd.bus_range_code IS NOT NULL THEN mt2bd.bus_range_code 
          WHEN b.bus_range_code IS NOT NULL THEN b.bus_range_code
          WHEN bus_range_map2.bus_range_code_order IS NOT NULL THEN bus_range_map2.bus_range_code_order
          ELSE ''
     END = cn_onoffline_map3.bus_range_code--  业务范围
   AND (bseg_bkpf.bukrs IN ('1180','118A','118B','1181') OR bseg_bkpf.bukrs LIKE '12%') 

;

/***********************************COUE UE凭证特殊处理结束*************************************/






/****************************************日立相关取数开始****************************************/

/**************日立SAP700收入数据插入开始***************/

INSERT INTO dwd.dwd_fi_mr_gp_detail_mi
(year,month,company_code
,agency_code
,cust_code,material_code,shop_code,agency_name,material_name
,cust_name,cust_unity_name,credit_level_name,cust_nature_name,cust_type_name,channel_l1_code,channel_l1_name,channel_l2_code,channel_l2_name,channel_l3_code,channel_l3_name,
channel_big_class_code, 
channel_big_class_name,
channel_small_class_code,
channel_small_class_name,
ind_big_class_code,
ind_big_class_name,
ind_small_class_code,
ind_small_class_name
,marketing_mode_code
,marketing_mode_name
,onoffline_code,onoffline_name
,product_line_code,product_line_name,sale_model_code,sale_model_name,brand_code,brand_name,spec_section_code,spec_section_name,product_shape_type_code,product_shape_type_name,product_sale_series_code,product_sale_series_name,quarter_method_code,quarter_method_name,product_stage_code,product_stage_name,price_range_code,price_range_name,model_code,model_name,product_series_code,product_series_name,market_pnt_code,market_pnt_name,tech_type_code,tech_type_name
,is_miniled_code
,product_big_class_code,product_big_class_name,product_mid_class_code,product_mid_class_name,product_small_class_code,product_small_class_name,model_lca_code,model_lca_name,product_type_code,product_type_name,shop_name,bill_qty,qcy_code,rev_sale_amt
,discount1_amt,discount3_amt,discount4_amt,discount5_amt,discount6_amt,discount34_amt,tax_rate,exchange_rate,system_src,ods_src,bill_cert_id,bill_cert_item,sold_to_code,sold_to_name,material_group_code,cp_company_code,batch_id,material_pricing_group_code,material_pricing_group_name,sale_cert_id,sale_cert_item,sale_cert_type,reference_cert_id,reference_cert_item,acct_cert_id,ext_order_id,load_dt,dt_month
,acct_src_code,acct_map_code,bill_dt
,cust_mdg_code
,bus_range_code,bus_range_name,marketing_dept_code,marketing_dept_name
,comm_bu_code,comm_bu_name
,cn_class_mark_code,cn_class_mark_name
,material_group_name
,profitcenter_code
,profitcenter_name
,customer_model
,zcalasset
,discount30_amt
,rev_sale_bcy_amt
,cost_center_code   -- 成本中心编码
,cost_center_name -- 成本中心名称
/*20260520 新增miniled类型字段*/
, miniled_type_code
, miniled_type_name
)

WITH vbrk AS(
 SELECT  
      vbrp.vbeln AS vbeln --  系统发票号
    , LTRIM(vbrp.posnr,'0') AS posnr --  项目号
    , vbrp.matnr AS matnr --  物料编码
    , mara.matkl AS matkl --  物料组
    , CASE WHEN vbrp.vgtyp NOT IN ('T','J') THEN '' ELSE vbrp.vgbel END AS vgbel --  交货单
    , CASE WHEN vbrp.vgtyp NOT IN ('T','J') THEN '' ELSE LTRIM(vbrp.vgpos,'0') END AS vgpos --  交货单行号
    , vbrp.aubel AS aubel --  销售订单
    , LTRIM(vbrp.aupos,'0') AS aupos --  订单行号
    , vbak.auart AS auart --  订单类型
    , '' AS zzextno --  外部订单号
    , CASE WHEN vbrk.vbtyp IN ('O','6','N')
             THEN 0-vbrp.fkimg
           ELSE vbrp.fkimg
      END AS fkimg --  发票数量（实际已开发票量）
    , vbrp.charg AS charg --  批次
    , CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-vbrp.netwr ELSE vbrp.netwr END AS netwr --  不含税合计金额
    , vbrk.fkdat AS fkdat --  日期
    , revaaz.cod_azienda AS vkorg --  组织（销售机构）
    , vbrk.kunrg AS kunrg --  客户
    , vbrp.vkbur AS vkbur --  办事处编码
    , tvkbt.bezei AS bezei --  办事处描述
    , vbrp.kondm AS kondm --  物料定价组编码
    , t178t.vtext AS vtext --  物料定价组描述
    , CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-konv_zk01.kbetr ELSE konv_zk01.kbetr END AS kbetr_zk01 --  ZK05直扣(%)
    , CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-konv_zk05.kwert ELSE konv_zk05.kwert END AS kbetr_zk05 --  ZK05直扣(%)
    , CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-konv_zk06.kwert ELSE konv_zk06.kwert END AS kbetr_zk06 --  ZK06直扣单价
    , CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-IFNULL(konv_zk04.kwert,konv_zk02.kwert) ELSE IFNULL(konv_zk04.kwert,konv_zk02.kwert) END AS kbetr_zk04 --  ZK04返利单价
    , CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-konv_zk03.kwert ELSE konv_zk03.kwert END AS kbetr_zk03 --  ZK03返利(%)
    , CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-konv_zk34.kwert ELSE konv_zk34.kwert END AS kbetr_zk34 --  ZK03返利(%)
    , bkpf.belnr AS belnr --  会计凭证
    -- , vbpa.kunnr AS sold_to --  售达方编码
    , vbrk.kunag AS sold_to --  售达方编码
    , ''  AS sold_to_names --  售达方描述
    , vbrk.waerk AS waerk --  凭证货币
    , vbrp.kursk AS kursk --  决定价格的汇率
    , COALESCE(konv_mwst.kbetr,konv_mwsi.kbetr,konv_zwst.kbetr)/1000 AS kbetr_mwsi --  税率
    , '' AS zdpbm --  店铺编码
    , '' AS zdpmc --  店铺名称
    , bseg.hkont AS acct_src_code -- 原始科目编码
    , bseg.hkont AS acct_map_code -- 映射后科目编码
    , vbrk.fkdat AS bill_dt -- 发票日期
    , vbap.gsber AS bus_range_code -- 业务范围编码
    , tgsbt.gtext AS bus_range_name -- 业务范围名称
    , t023t.wgbez AS material_group_name -- 物料组描述
    , mara.profitcenter_code AS profitcenter_code
    , mara.profitcenter_name AS profitcenter_name
    , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model --  客户型号
    , mara.zcalasset AS zcalasset --  按套统计
    , CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-konv_zk30.kwert ELSE konv_zk30.kwert END AS kbetr_zk30
    , CASE WHEN bseg.dmbtr IS NOT NULL THEN bseg.dmbtr 
           ELSE CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-vbrp.netwr ELSE vbrp.netwr END 
      END AS dmbtr
    , vbrp.vkgrp
    --  SELECT *
   FROM(
      SELECT * FROM ods.odsslt_s700_vbrk
      WHERE 1=1
      AND fkdat >= @year_month_day
      AND fkdat < date_format(date_add(CAST(@year_month_day AS DATE), INTERVAL 1 MONTH), '%Y%m%d')
    ) vbrk --  发票头
    -- 日立收入-公司映射
  LEFT JOIN (select ent_sap700_code,cod_azienda FROM ods.odsfima_aw_rul_revaaz_000001 
              UNION ALL 
             SELECT '1745' AS ent_sap700_code,'1745' AS cod_azienda FROM DUAL
            ) revaaz 
  ON vbrk.vkorg = revaaz.ent_sap700_code

  LEFT JOIN (SELECT vbeln,posnr,vgtyp,vgbel,vgpos,aubel,aupos,fkimg,netwr,charg,vkbur,kondm,kursk,matnr,vkgrp,ktgrm FROM ods.ods_slt_s700_vbrp) vbrp --  发票行
    ON vbrk.vbeln = vbrp.vbeln
  LEFT JOIN (SELECT * FROM ods.odss700_vbak) vbak --  销售凭证 VBAK-销售订单类型=“ZCS”（现金销售订单）
    ON vbrp.aubel = vbak.vbeln
  LEFT JOIN dim.dim_fi_mr_product_dd mara --  物料大表
    ON vbrp.matnr = mara.matnr
  LEFT JOIN ods.odss700_t023t t023t --  物料组名称表
    ON mara.matkl = t023t.matkl
  LEFT JOIN ods.odss700_t178t t178t --  物料定价组描述
    ON t178t.kondm = vbrp.kondm
   AND t023t.spras = '1'
  LEFT JOIN (SELECT * FROM ods.ods_slt_s700_bkpf_v WHERE awtyp = 'VBRK') bkpf --  凭证抬头信息
    ON vbrk.vbeln = bkpf.awkey
  LEFT JOIN (SELECT bukrs,gjahr,belnr,matnr,hkont,SUM(CASE WHEN shkzg = 'S' THEN dmbtr ELSE -1*dmbtr END) AS dmbtr 
               FROM ods.ods_slt_s700_bseg_v
              WHERE (hkont LIKE '6001%' OR hkont LIKE '6051%' )
              GROUP BY bukrs,gjahr,belnr,matnr,hkont
            ) bseg
    ON bkpf.bukrs = bseg.bukrs
   AND bkpf.gjahr = bseg.gjahr
   AND bkpf.belnr = bseg.belnr
   AND vbrp.matnr = bseg.matnr
  LEFT JOIN (SELECT * FROM ods.odss700_vbpa WHERE parvw='AG') vbpa --  销售凭证:合作伙伴
    ON vbrp.aubel = vbpa.vbeln
  LEFT JOIN ods.odss700_tvkbt tvkbt --  办事处描述
    ON vbrp.vkbur = tvkbt.vkbur
   AND tvkbt.spras = '1'
  LEFT JOIN ods.odss700_ekko ekko --  采购凭证
    ON vbrp.aubel = ekko.ebeln
  LEFT JOIN (SELECT DISTINCT vbeln,gsber FROM ods.ods_s700_vbap) vbap--  销售订单行项目 VBAP-KTGRM=“01”
    ON vbrp.aubel = vbap.vbeln
  LEFT JOIN (SELECT * FROM ods.ods_s700_tgsbt WHERE spras = 1) tgsbt --  业务范围描述
    ON vbap.gsber = tgsbt.gsber
  LEFT JOIN (SELECT knumv,kposn,SUM(kbetr) AS kbetr
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kbetr) kbetr,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'ZK01'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_zk01
    ON vbrk.knumv = konv_zk01.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_zk01.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kwert) AS kwert
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kwert) kwert,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'ZK02'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_zk02
    ON vbrk.knumv = konv_zk02.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_zk02.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kwert) AS kwert
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kwert) kwert,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'ZK03'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_zk03
    ON vbrk.knumv = konv_zk03.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_zk03.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kwert) AS kwert
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kwert) kwert,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'ZK04'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_zk04
    ON vbrk.knumv = konv_zk04.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_zk04.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kwert) AS kwert
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kwert) kwert,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'ZK05'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_zk05
    ON vbrk.knumv = konv_zk05.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_zk05.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kwert) AS kwert
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kwert) kwert,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'ZK06'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_zk06
    ON vbrk.knumv = konv_zk06.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_zk06.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kbetr) AS kbetr
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kbetr) kbetr,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'MWST'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_mwst
    ON vbrk.knumv = konv_mwst.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_mwst.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kbetr) AS kbetr
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kbetr) kbetr,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'MWSI'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_mwsi
    ON vbrk.knumv = konv_mwsi.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_mwsi.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kbetr) AS kbetr
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kbetr) kbetr,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'ZWST'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_zwst
    ON vbrk.knumv = konv_zwst.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_zwst.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kwert) AS kwert
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kwert) kwert,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'ZK34'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_zk34
    ON vbrk.knumv = konv_zk34.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_zk34.kposn
  LEFT JOIN (SELECT knumv,kposn,SUM(kwert) AS kwert
              FROM (
                  SELECT kherk,knumv,kposn,SUM(kwert) kwert,
                      ROW_NUMBER() OVER (
                          PARTITION BY knumv, kposn 
                          ORDER BY CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                      ) AS rn
                  FROM ods.odsslt_s700_konv o
                  WHERE kschl = 'ZK30'
                  GROUP BY kherk,knumv,kposn
              ) t
              WHERE rn = 1
              GROUP BY knumv,kposn) konv_zk30
    ON vbrk.knumv = konv_zk30.knumv
   AND LTRIM(vbrp.posnr,'0') = konv_zk30.kposn

-- 对匹配结果做筛选
where 1 = 1 
AND vbrk.fkart <> 'ZG1'
AND vbrk.rfbsk = 'C'
and vbak.auart = 'ZCS' --  销售凭证 VBAK-销售订单类型=“ZCS”（现金销售订单）
and vbrp.ktgrm = '01'  --  销售订单行项目 VBRP-KTGRM=“01”
),
 form_dati_ctp AS --  匹配对方公司
 (
 SELECT cust_code AS kunrg --  客商编码
       ,NVL(cp_company_code_mr,cp_company_code) AS ctp
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S700'
 ), 
  vbrk_m AS 
 (--  匹配物料大表，错误产品线和对方公司
   SELECT
      vbrk.*
     ,form_dati_ctp.ctp AS ctp --  对方公司
    FROM vbrk 
    LEFT JOIN form_dati_ctp --  匹配对方公司
      ON vbrk.kunrg = form_dati_ctp.kunrg
 ),
  nf_map_1  AS 
(
  SELECT  batch_id AS xh --  处理优先级
        , logic_name AS lj --  逻辑处理
        , b.cod_azienda AS vkorg --  公司包含
        , c.cod_azienda AS ctp
        , cust_code AS kunrg --  客商包含
        , cust_ex_code AS kunrg_out
        , sold_to_code AS sold_to --  售达方包含
        , sold_to_ex_code AS sold_to_out
        , product_line_src_code AS org_prctr_before --  处理前利润中心
        , onoffline_src_code AS nf_before
        , onoffline_code AS nf
        , onoffline_name AS nf_name
   FROM dim.dim_rule_fi_mr_nf_mapping a 
   LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
  WHERE valid_fr <= @year_month_day
    AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
 ),
 vbrk_1 AS 
(  --  匹配线上线下
 SELECT
     vbrk_m.*
    ,CASE WHEN COALESCE(form_dati_nf6.nf,form_dati_nf5.nf,form_dati_nf4.nf,form_dati_nf3.nf,form_dati_nf2.nf,form_dati_nf1.nf) IS NULL 
            THEN '020_OFF_002' 
          WHEN COALESCE(form_dati_nf6.nf,form_dati_nf5.nf,form_dati_nf4.nf,form_dati_nf3.nf,form_dati_nf2.nf,form_dati_nf1.nf) = 'NULL'
            THEN NULL 
          ELSE COALESCE(form_dati_nf6.nf,form_dati_nf5.nf,form_dati_nf4.nf,form_dati_nf3.nf,form_dati_nf2.nf,form_dati_nf1.nf)
     END AS nf_1
    ,CASE WHEN COALESCE(form_dati_nf6.nf_name,form_dati_nf5.nf_name,form_dati_nf4.nf_name,form_dati_nf3.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name) IS NULL 
            THEN '零售-传统零售' 
          WHEN COALESCE(form_dati_nf6.nf_name,form_dati_nf5.nf_name,form_dati_nf4.nf_name,form_dati_nf3.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name) = 'NULL'
            THEN NULL 
          ELSE COALESCE(form_dati_nf6.nf_name,form_dati_nf5.nf_name,form_dati_nf4.nf_name,form_dati_nf3.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name)
     END AS nf_1_name
   FROM vbrk_m
   LEFT JOIN nf_map_1 form_dati_nf1--  匹配线上线下映射表 按公司匹配
     ON 1=1
    --  公司包含匹配
    AND vbrk_m.vkorg = form_dati_nf1.vkorg
    AND form_dati_nf1.xh = '1'

   LEFT JOIN nf_map_1 form_dati_nf2--  匹配线上线下映射表 按公司+客商匹配
     ON 1=1
    --  公司包含匹配
    AND vbrk_m.vkorg = form_dati_nf2.vkorg
    --  客商剔除匹配
    AND LTRIM(vbrk_m.kunrg, '0') = form_dati_nf2.kunrg
    AND form_dati_nf2.xh = '2'

   LEFT JOIN nf_map_1 form_dati_nf3--  匹配线上线下映射表 按公司+客商+售达方匹配
     ON 1=1
    --  公司包含匹配
    AND vbrk_m.vkorg = form_dati_nf3.vkorg
    --  客商剔除匹配
    AND LTRIM(vbrk_m.kunrg, '0') = form_dati_nf3.kunrg
    --  售达方匹配
    AND LTRIM(vbrk_m.sold_to, '0') = form_dati_nf3.sold_to
    AND form_dati_nf3.xh = '3'

   LEFT JOIN nf_map_1 form_dati_nf4--  匹配线上线下映射表 按客商+售达方匹配
     ON 1=1
    --  公司包含匹配
    AND LTRIM(vbrk_m.kunrg, '0') = form_dati_nf4.kunrg
    --  售达方匹配
    AND LTRIM(vbrk_m.sold_to, '0') = form_dati_nf4.sold_to
    AND form_dati_nf4.xh = '4'

   LEFT JOIN nf_map_1 form_dati_nf5--  匹配线上线下映射表 按公司+对方公司匹配
     ON 1=1
    --  公司匹配
    AND vbrk_m.vkorg = form_dati_nf5.vkorg
    --  对方公司匹配
    AND vbrk_m.ctp = form_dati_nf5.ctp
    AND form_dati_nf5.xh = '5'

   LEFT JOIN nf_map_1 form_dati_nf6--  匹配线上线下映射表 按公司+对方公司+售达方
     ON 1=1
    --  公司匹配
    AND vbrk_m.vkorg = form_dati_nf6.vkorg
    --  对方公司匹配
    AND vbrk_m.ctp = form_dati_nf6.ctp
    --  售达方匹配
    AND LTRIM(vbrk_m.sold_to, '0') = form_dati_nf6.sold_to
    AND form_dati_nf6.xh = '6'
    )

SELECT 
    date_format(vbrk.fkdat,'%Y') AS year --  财务年
  , date_format(vbrk.fkdat,'%m') AS month --  财务月
  , vbrk.vkorg AS company_code --  组织
  , vbrk.vkbur AS agency_code --  办事处编码
  , vbrk.kunrg AS cust_code --  客商编码
  , vbrk.matnr AS material_code --  物料编码
  , vbrk.zdpbm AS shop_code --  门店编码
  , vbrk.bezei AS agency_name --  办事处名称
  , dim_fi_mr_product_dd.product_name AS material_name  --  物料名称
  -- , COALESCE(TRIM(dim_fi_mr_product_dd.maktx_s600),TRIM(dim_fi_mr_product_dd.maktx_s800),TRIM(dim_fi_mr_product_dd.maktx_s900),TRIM(dim_fi_mr_product_dd.maktx_s810),TRIM(dim_fi_mr_product_dd.maktx_mdm)) AS material_name
  , ods_slt_s700_kna1.name1 AS cust_name --  客商名称
  , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name --  统一客户组
  , dim_customer_base_info_dd.credit_level AS credit_level_name --  信用等级
  , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name --  单位性质
  , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
          AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
          AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
          THEN NULL
          ELSE TRIM(
                REGEXP_REPLACE(
                    CONCAT_WS(',',
                        CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                        CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                        CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                    ),
                    '(^,)|(,$)',  
                    ''            
                )
            )
            END AS cust_type_name  --  客户类型
  , dim_customer_base_info_dd.com_1st_code AS channel_l1_code --  销售渠道一级编码
  , dim_customer_base_info_dd.com_1st_name AS channel_l1_name --  销售渠道一级名称
  , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code --  销售渠道二级编码
  , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name --  销售渠道二级名称
  , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code --  销售渠道三级编码
  , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name --  销售渠道三级名称
  , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code --  销售模式编码
  , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name --  销售模式名称
  , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code --  渠道客户大类编码
  , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name --  渠道客户大类名称
  , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code --  渠道客户小类编码
  , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name --  渠道客户小类名称
  , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code --  行业大类编码
  , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name --  行业大类名称
  , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code --  行业小类编码
  , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name --  行业小类名称
  , CASE WHEN LTRIM(vbrk.kondm,'0') IN ('4','9') THEN '020_OFF_004'
         ELSE vbrk.nf_1 
    END AS onoffline_code --  线上线下编码
  , CASE WHEN LTRIM(vbrk.kondm,'0') IN ('4','9') THEN '工程'
         ELSE vbrk.nf_1_name
    END AS onoffline_name --  线上线下名称
  , '' AS product_line_code --  产品线编码
  , '' AS product_line_name --  产品线名称
  , COALESCE(IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
            ) AS sale_model_code --  销售型号编码
  -- , COALESCE(TRIM(dim_fi_mr_product_dd.zzprdmodel),TRIM(dim_fi_mr_product_dd.zfacmodel),TRIM(dim_fi_mr_product_dd.pmodel_number)) AS sale_model_code --  销售型号编码
  -- , '' AS sale_model_name --  销售型号名称
  /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
  , COALESCE(IF(TRIM(dim_fi_mr_product_dd.sale_model_name)= '',NULL,TRIM(dim_fi_mr_product_dd.sale_model_name))
            ,IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
            ) AS sale_model_name --  销售型号名称
  , dim_fi_mr_product_dd.brand AS brand_code --  品牌编码
  , dim_fi_mr_product_dd.brand_name AS brand_name --  品牌名称
  ,CASE WHEN dim_fi_mr_product_dd.big_class_code = 'P01' THEN dim_fi_mr_product_dd.SCREEN_SIZE_CODE
     WHEN dim_fi_mr_product_dd.big_class_code = 'P02' THEN dim_fi_mr_product_dd.SPEC_RANGE_CODE
     WHEN dim_fi_mr_product_dd.big_class_code = 'P03' THEN dim_fi_mr_product_dd.TOTAL_CAPACITY_CODE
     WHEN dim_fi_mr_product_dd.big_class_code = 'P04' THEN dim_fi_mr_product_dd.WASHING_CAPACITY_CODE
  END AS spec_section_code --  规格段编码
    ,CASE WHEN dim_fi_mr_product_dd.big_class_code = 'P01' THEN dim_fi_mr_product_dd.SCREEN_SIZE_NAME
     WHEN dim_fi_mr_product_dd.big_class_code = 'P02' THEN dim_fi_mr_product_dd.SPEC_RANGE_NAME
     WHEN dim_fi_mr_product_dd.big_class_code = 'P03' THEN dim_fi_mr_product_dd.TOTAL_CAPACITY_NAME
     WHEN dim_fi_mr_product_dd.big_class_code = 'P04' THEN dim_fi_mr_product_dd.WASHING_CAPACITY_NAME
  END  AS spec_section_name --  规格段名称
  , dim_fi_mr_product_dd.product_spec_code AS product_shape_type_code --  产品形态分类编码
  , dim_fi_mr_product_dd.product_spec_name AS product_shape_type_name --  产品形态分类名称
  , dim_fi_mr_product_dd.prod_suite_code AS product_sale_series_code --  产品套系编码
  , dim_fi_mr_product_dd.prod_suite_name AS product_sale_series_name --  产品套系名称
  , '' AS quarter_method_code --  四分法编码（市场口径）
  , '' AS quarter_method_name --  四分法名称（市场口径）
  , dim_fi_mr_product_dd.prod_stage_code AS product_stage_code --  产品阶段编码
  , dim_fi_mr_product_dd.prod_stage_name AS product_stage_name --  产品阶段名称
  , dim_fi_mr_product_dd.price_range_code AS price_range_code --  价格段编码
  , dim_fi_mr_product_dd.price_range_name AS price_range_name --  价格段名称
  , dim_fi_mr_product_dd.model_code AS model_code --  产品型号编码
  , dim_fi_mr_product_dd.model_name AS model_name --  产品型号名称
  , dim_fi_mr_product_dd.series_code AS product_series_code --  产品系列编码
  , dim_fi_mr_product_dd.series_name AS product_series_name --  产品系列名称
  , dim_fi_mr_product_dd.market_pos_code AS market_pnt_code --  营销定位编码
  , dim_fi_mr_product_dd.market_pos_name AS market_pnt_name --  营销定位名称
  , dim_fi_mr_product_dd.ac_ct_code AS tech_type_code --  技术类型编码
  , dim_fi_mr_product_dd.ac_ct_name AS tech_type_name --  技术类型名称
  , dim_fi_mr_product_dd.is_miniled_code AS is_miniled_code --  是否MiniLED编码
  , dim_fi_mr_product_dd.big_class_code AS product_big_class_code --  产品大类编码
  , dim_fi_mr_product_dd.big_class_name AS product_big_class_name --  产品大类名称
  , dim_fi_mr_product_dd.middle_class_code AS product_mid_class_code --  产品中类编码
  , dim_fi_mr_product_dd.middle_class_name AS product_mid_class_name --  产品中类名称
  , dim_fi_mr_product_dd.small_class_code AS product_small_class_code --  产品小类编码
  , dim_fi_mr_product_dd.small_class_name AS product_small_class_name --  产品小类名称
  , dim_fi_mr_product_dd.model_lca AS model_lca_code --  产品型号生命周期编码
  , dim_fi_mr_product_dd.model_lca_name AS model_lca_name --  产品型号生命周期名称
  , ods_mr_aw_rul_revama_000001.product_type_code AS product_type_code --  产品类型编码
  , ods_mr_aw_rul_revama_000001.product_type_name AS product_type_name --  产品类型名称
  , vbrk.zdpmc AS shop_name --  门店名称
  , vbrk.fkimg AS bill_qty --  开票销量
  , vbrk.waerk AS qcy_code --  货币-交易币
  , vbrk.netwr AS rev_sale_amt --  销售收入
  , vbrk.kbetr_zk01 AS discount1_amt --  折扣3
  , vbrk.kbetr_zk03 AS discount3_amt --  折扣3
  , vbrk.kbetr_zk04 AS discount4_amt --  折扣4
  , vbrk.kbetr_zk05 AS discount5_amt --  折扣5
  , vbrk.kbetr_zk06 AS discount6_amt --  折扣6
  , vbrk.kbetr_zk34 AS discount34_amt --  折扣34
  , vbrk.kbetr_mwsi AS tax_rate --  税率
  , vbrk.kursk AS exchange_rate --  汇率
  , 'S700' AS system_src --  源系统
  , 'VBRP' AS ods_src --  源表
  , vbrk.vbeln AS bill_cert_id --  开票凭证
  , vbrk.posnr AS bill_cert_item --  开票凭证行项目
  , vbrk.sold_to AS sold_to_code --  售达方
  , sold_to.name1 AS sold_to_name --  售达方名称
  , vbrk.matkl AS material_group_code --  物料组
  , vbrk.ctp AS cp_company_code --  对方公司
  , vbrk.charg AS batch_id --  批次号
  , vbrk.kondm AS material_pricing_group_code --  物料定价组编码
  , vbrk.vtext AS material_pricing_group_name --  物料定价组名称
  , vbrk.aubel AS sale_cert_id --  销售凭证号
  , vbrk.aupos AS sale_cert_item --  销售凭证行项目
  , vbrk.auart AS sale_cert_type --  销售凭证类型
  , vbrk.vgbel AS reference_cert_id --  参考单据编号
  , vbrk.vgpos AS reference_cert_item --  参考单据项目号
  , vbrk.belnr AS acct_cert_id --  会计凭证号
  , vbrk.zzextno AS ext_order_id --  外部订单号
  , now() AS load_dt --  更新时间
  , date_format(fkdat,'%Y%m') AS dt_month --  年月
  , vbrk.acct_src_code
  , vbrk.acct_map_code
  , vbrk.bill_dt
  , ods_slt_s700_kna1.zkunnr_mdg AS cust_mdg_code
  , revabm.cod_dest3 AS bus_range_code
  , tgsbt.gtext AS bus_range_name
  , revasa.d_sale_dept AS marketing_dept_code -- 业务管理单元
  , revasa.d_sale_dept_name AS marketing_dept_name -- 业务管理单元描述
  , '' AS comm_bu_code
  , '' AS comm_bu_name
  , '' AS cn_class_mark_code
  , '' AS cn_class_mark_name
  , vbrk.material_group_name AS material_group_name
  -- , CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE vbrk.profitcenter_code END AS profitcenter_code
  ,CASE WHEN NVL(TRIM(vbrk.matnr), '') <> '' AND dim_fi_mr_product_dd.product_type = 'FERT' THEN dim_fi_mr_product_dd.profitcenter_code
        WHEN NVL(TRIM(vbrk.matnr), '') <> '' AND NVL(dim_fi_mr_product_dd.product_type,'|') <> 'FERT' THEN '109087000'
        WHEN NVL(TRIM(vbrk.matnr), '') = '' THEN '190091000'
   END AS profitcenter_code
  , '' AS profitcenter_name
  , COALESCE(if(upper(dim_fi_mr_product_dd.sale_model_name)='无',null,upper(dim_fi_mr_product_dd.sale_model_name)),if(upper(dim_fi_mr_product_dd.zcusmodel)='无',null,upper(dim_fi_mr_product_dd.zcusmodel))) AS customer_model   --  客户型号
  , dim_fi_mr_product_dd.zcalasset AS zcalasset        --  按套统计
  , vbrk.kbetr_zk30 AS discount30_amt --  折扣34
  , vbrk.dmbtr AS rev_sale_bcy_amt --  销售收入-本位币
  ,CONCAT('S700_',revabs.cost_center_code) AS cost_center_code    -- 成本中心编码
  ,revabs.cost_center_name AS cost_center_name  -- 成本中心名称

  /*20260520 新增miniled类型字段*/
  , dim_fi_mr_product_dd.miniled_type_code
  , dim_fi_mr_product_dd.miniled_type_name
FROM(
    SELECT * FROM vbrk_1 
    WHERE (vkorg LIKE '17%' OR vkorg = '6240') -- 限制日立相关公司
  )vbrk
LEFT JOIN (SELECT * FROM ods.ods_slt_s700_kna1) ods_slt_s700_kna1
ON vbrk.kunrg = ods_slt_s700_kna1.kunnr

LEFT JOIN dw.dim_customer_base_info_dd --  匹配客商主数据
ON ods_slt_s700_kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code

LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
ON ods_slt_s700_kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
AND vbrk.vkorg = dim_customer_trade_info_dd.sale_org
AND vbrk.matkl = dim_customer_trade_info_dd.material_group_code

LEFT JOIN dim.dim_fi_mr_product_dd --  匹配物料大表
ON vbrk.matnr = dim_fi_mr_product_dd.matnr

LEFT JOIN ods.ods_slt_s700_kna1 AS sold_to --  匹配售达方数据
ON vbrk.sold_to = sold_to.kunnr

LEFT JOIN (   SELECT batch, product_type_code, product_type_name
                FROM dim.dim_rule_fi_mr_batch2protype_mapping a  
               WHERE valid_fr <= @year_month_day
                 AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
          ) AS ods_mr_aw_rul_revama_000001 --  批次对应产品类型映射表
   ON vbrk.charg = ods_mr_aw_rul_revama_000001.batch
   
LEFT JOIN dw.dim_product_base_info_dd
ON vbrk.matnr = dim_product_base_info_dd.product_code
-- 营销中心映射业务范围关系表
LEFT JOIN (select distinct gsber,vkbur FROM ods.odss990_zmdgt138) odss990_zmdgt138
ON dim_customer_base_info_dd.market_center_code = odss990_zmdgt138.vkbur

LEFT JOIN dim.dim_rule_fi_mr_cust_busrange_mappping AS cust_map
ON vbrk.kunrg = cust_map.cust_code

LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
            WHERE 1=1
              AND a.valid_fr <= LEFT(@year_month_day,6)
              AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
          ) AS mt2bd
  ON vbrk.matnr = mt2bd.material_code

-- 日立收入-业务管理单元映射
LEFT JOIN 
  (
    select proj_classification,strategic_type,d_sale_dept,d_sale_dept_name 
    FROM ods.odsfima_aw_rul_revasa_000001
  ) revasa
ON revasa.proj_classification = CASE WHEN dim_product_base_info_dd.brand_name in ('Hisense','hisense','OEM品牌') then '海信公建'
                   WHEN dim_product_base_info_dd.brand_name IN ('HITACHI') then '日立公建'
                   WHEN dim_product_base_info_dd.brand_name = 'YORK' then '约克公建'
           WHEN dim_fi_mr_product_dd.brand = '0008' then '科龙公建'
                END
and revasa.strategic_type = '非战略'

-- 日立收入-业务范围映射
LEFT JOIN (select distinct sales_dept,sales_team,cod_dest3 FROM ods.odsfima_aw_rul_revabm_000001) revabm
ON revabm.sales_team = vbrk.vkgrp 
and revabm.sales_dept = vbrk.vkbur
--  业务范围主数据
LEFT JOIN (select distinct gsber,gtext FROM ods.ods_s700_tgsbt where spras = 1) tgsbt 
ON revabm.cod_dest3 = tgsbt.gsber 
-- 公司和业务范围映射成本中心，映射结果放到办事处字段上
LEFT JOIN (select distinct cod_dest3,cod_dest3_name,cost_center_code,cost_center_name FROM ods.odsfima_aw_rul_revabs_000001 where usage_status = '保留') revabs
ON revabs.cod_dest3 = revabm.cod_dest3


;

/**************日立SAP700收入数据插入结束***************/

/**************日立BSEG总账调整数据插入开始*************/

INSERT INTO dwd.dwd_fi_mr_gp_detail_mi 
(
    year             -- 财务年
  , month            -- 财务月
  , company_code       -- 组织
  , agency_code          -- 办事处编码/成本中心编码（销售部门）
  , agency_name          -- 办事处编码/成本中心名称（销售部门名称）
  , onoffline_code     -- 线上/线下代码
  , onoffline_name       -- 线上/线下名称
  , product_line_code    -- 产品线编码
  , bill_qty             -- 开票销量
  , qcy_code             -- 货币-交易币
  , rev_sale_amt         -- 销售收入
  , system_src           -- 源系统
  , ods_src              -- 源表
  , bill_cert_id         -- 开票凭证
  , acct_src_code        -- 原始科目编码
  , acct_map_code        -- 映射后科目编码
  , order_type_code      -- 订单类型
  , load_dt            -- 更新时间
  , dt_month             -- 年月
  , profitcenter_code    -- 利润中心编码
  , profitcenter_name    -- 利润中心描述
  , customer_model       -- 客户型号
  , zcalasset            -- 按套统计
  , bus_range_code     -- 业务范围编码
  , bus_range_name     -- 业务范围描述
  , rev_sale_bcy_amt
  , cost_center_code   -- 成本中心编码
  , cost_center_name   -- 成本中心名称
  , marketing_dept_code  -- 业务管理单元
  , marketing_dept_name  -- 业务管理单元描述
  /*20260128 新增使用物料带出的相关信息字段*/
  , material_group_code -- 物料组
  , sale_model_code -- 销售型号编码
  , sale_model_name -- 销售型号名称           /*alter by 20260811 xiaoyachao.ex */
  , product_sale_series_code --  产品套系编码
  , product_sale_series_name --  产品套系名称
  , product_stage_code --  产品阶段编码
  , product_stage_name --  产品阶段名称
  , price_range_code --  价格段编码
  , price_range_name --  价格段名称
  , model_code --  产品型号编码
  , model_name --  产品型号名称
  , product_series_code --  产品系列编码
  , product_series_name --  产品系列名称
  , market_pnt_code --  营销定位编码
  , market_pnt_name --  营销定位名称
  , tech_type_code --  技术类型编码
  , tech_type_name --  技术类型名称
  , is_miniled_code --  是否MiniLED编码
  , product_big_class_code --  产品大类编码
  , product_big_class_name --  产品大类名称
  , product_mid_class_code --  产品中类编码
  , product_mid_class_name --  产品中类名称
  , product_small_class_code --  产品小类编码
  , product_small_class_name --  产品小类名称
  , model_lca_code --  产品型号生命周期编码
  , model_lca_name --  产品型号生命周期名称
  , brand_code --  品牌编码
  , brand_name --  品牌名称
  , spec_section_code --  规格段编码
  , spec_section_name --  规格段名称
  , product_shape_type_code --  产品形态分类编码
  , product_shape_type_name --  产品形态分类名称
  , material_code               -- 物料编码
  , material_name               -- 物料名称
  /*20260520 新增miniled类型字段*/
  , miniled_type_code
  , miniled_type_name
)

SELECT  bseg.gjahr AS year
  , bseg.monat AS month
  , revaaz.cod_azienda AS company_code
  , '' AS agency_code 
  , '' AS agency_name
  , '020_OFF_001' AS onoffline_code
  , '线下公共' AS onoffline_name
  , '' AS product_line_code
  , bseg.menge AS bill_qty
  , bseg.pswsl AS qcy_code
  , CASE WHEN bseg.shkzg = 'S' THEN -1*bseg.dmbtr ELSE bseg.dmbtr END AS rev_sale_amt
  , 'S700' AS system_src
  , 'BSEG' AS ods_src
  , bseg.belnr AS bill_cert_id
  , bseg.hkont AS acct_src_code
  , bseg.hkont AS acct_map_code
  , bseg.glvor AS order_type_code
  , now() AS load_dt
  , CONCAT(bseg.gjahr,bseg.monat) AS dt_month
  /*, CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code 
         -- WHEN TRIM(bseg.prctr) <> '' THEN TRIM(bseg.prctr)
         WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
         ELSE mara.profitcenter_code
    END AS profitcenter_code*/
  ,CASE WHEN NVL(TRIM(bseg.matnr), '') <> '' AND mara.product_type = 'FERT' THEN mara.profitcenter_code
        WHEN NVL(TRIM(bseg.matnr), '') <> '' AND NVL(mara.product_type,'|') <> 'FERT' THEN '109087000'
        WHEN NVL(TRIM(bseg.matnr), '') = '' THEN '190091000'
   END AS profitcenter_code
  , '' AS profitcenter_name
  , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model
  , mara.zcalasset AS zcalasset
  , CASE WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN mt2bd.bus_range_code IS NOT NULL THEN mt2bd.bus_range_code 
             ELSE CASE WHEN IFNULL(TRIM(bseg.gsber),'') <> '' THEN TRIM(bseg.gsber) ELSE '' END   
    END AS bus_range_code -- 业务范围编码
  , CASE WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN mt2bd.bus_range_code IS NOT NULL THEN mt2bd.bus_range_code 
             ELSE CASE WHEN IFNULL(TRIM(revabs.cod_dest3_name),'') <> '' THEN TRIM(revabs.cod_dest3_name) ELSE '' END  
    END AS bus_range_name -- 业务范围名称
  -- , bseg.gsber AS bus_range_code
  -- , revabs.cod_dest3_name AS bus_range_name
  , CASE WHEN revaaz.cod_azienda IN ('6012','2023')
           THEN CASE WHEN bseg.shkzg = 'S' THEN -1*bseg.wrbtr ELSE bseg.wrbtr END
         ELSE CASE WHEN bseg.shkzg = 'S' THEN -1*bseg.dmbtr ELSE bseg.dmbtr END
    END AS rev_sale_bcy_amt
  ,CONCAT('S700_',revabs.cost_center_code) AS cost_center_code    -- 成本中心编码
  ,revabs.cost_center_name AS cost_center_name  -- 成本中心名称
  
  ,case 
    when revaaz.cod_azienda = '1730' then '1730.S0025'
    when revaaz.cod_azienda = '1740' then '1730.S0061'
    when revaaz.cod_azienda = '1750' then '1730.S0232'
    when revaaz.cod_azienda in ('1735','1745','6240') then '1730.S0232'
  end as marketing_dept_code  -- 业务管理单元
  ,case when revaaz.cod_azienda = '1730' then '全球大客户运营'
    when revaaz.cod_azienda = '1740' then '海外自营-其他'
    when revaaz.cod_azienda = '1750' then '工程营销部-约克普通公建'
    when revaaz.cod_azienda in ('1735','1745','6240') then '工程营销部-日立普通公建'
  end  AS marketing_dept_name -- 业务管理单元描述
      /*20260128 新增使用物料带出的相关信息字段*/
    , mara.matkl AS material_group_code -- 物料组
    , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
          ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
          ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
        ) AS sale_model_code -- 销售型号编码
      /*alter by 20260811 xiaoyachao.ex 销售型号描述逻辑更新*/
     ,COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name
    , mara.prod_suite_code AS product_sale_series_code --  产品套系编码
    , mara.prod_suite_name AS product_sale_series_name --  产品套系名称
    , mara.prod_stage_code AS product_stage_code --  产品阶段编码
    , mara.prod_stage_name AS product_stage_name --  产品阶段名称
    , mara.price_range_code AS price_range_code --  价格段编码
    , mara.price_range_name AS price_range_name --  价格段名称
    , mara.model_code AS model_code --  产品型号编码
    , mara.model_name AS model_name --  产品型号名称
    , mara.series_code AS product_series_code --  产品系列编码
    , mara.series_name AS product_series_name --  产品系列名称
    , mara.market_pos_code AS market_pnt_code --  营销定位编码
    , mara.market_pos_name AS market_pnt_name --  营销定位名称
    , mara.ac_ct_code AS tech_type_code --  技术类型编码
    , mara.ac_ct_name AS tech_type_name --  技术类型名称
    , CASE WHEN mara.is_miniled_code  = 'PC00013001' THEN '是'
         WHEN mara.is_miniled_code  = 'PC00013002' THEN '否'
         ELSE ''
      END AS is_miniled_code --  是否MiniLED编码
    , mara.big_class_code AS product_big_class_code --  产品大类编码
    , mara.big_class_name AS product_big_class_name --  产品大类名称
    , mara.middle_class_code AS product_mid_class_code --  产品中类编码
    , mara.middle_class_name AS product_mid_class_name --  产品中类名称
    , mara.small_class_code AS product_small_class_code --  产品小类编码
    , mara.small_class_name AS product_small_class_name --  产品小类名称
    , mara.model_lca AS model_lca_code --  产品型号生命周期编码
    , mara.model_lca_name AS model_lca_name --  产品型号生命周期名称
    , mara.brand AS brand_code --  品牌编码
    , mara.brand_name AS brand_name --  品牌名称
  ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
    WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
    WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
    WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
   END AS spec_section_code --  规格段编码
    ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
    WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
    WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
    WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
   END  AS spec_section_name --  规格段名称
    , mara.product_spec_code AS product_shape_type_code --  产品形态分类编码
    , mara.product_spec_name AS product_shape_type_name --  产品形态分类名称
    , bseg.matnr AS material_code               -- 物料编码
    , mara.product_name AS material_name

    /*20260520 新增miniled类型字段*/
    , mara.miniled_type_code
    , mara.miniled_type_name
FROM(   
    SELECT bseg.gjahr,bkpf.monat,bseg.bukrs,bseg.prctr,bseg.menge,bseg.pswsl,bseg.shkzg,bseg.wrbtr,bseg.belnr,bseg.hkont,bkpf.glvor,bseg.dmbtr
      ,bseg.matnr,bseg.gsber,bseg.buzei
    FROM ods.ods_slt_s700_bseg_v bseg-- bseg凭证行项目
    INNER JOIN 
      ( -- 凭证抬头信息
        SELECT *
        FROM ods.ods_slt_s700_bkpf_v 
        WHERE 1=1
        AND gjahr = substr(@year_month_day,1,4)
        AND monat = substr(@year_month_day,5,2)
      ) bkpf
    ON bseg.belnr = bkpf.belnr 
    AND bseg.gjahr = bkpf.gjahr 
    AND bseg.bukrs = bkpf.bukrs
    WHERE 1=1
    AND bseg.hkont IN ('6001004000','6001005000','6001006000','6001007000','6001010000') 
    AND bseg.BUKRS = '1735'

    union all
    SELECT bseg.gjahr,bkpf.monat,bseg.bukrs,bseg.prctr,bseg.menge,bseg.pswsl,bseg.shkzg,bseg.wrbtr,bseg.belnr,bseg.hkont,bkpf.glvor,bseg.dmbtr
      ,bseg.matnr,bseg.gsber,bseg.buzei
    FROM ods.ods_slt_s700_bseg_v bseg-- bseg凭证行项目
    INNER JOIN 
      ( -- 凭证抬头信息
        SELECT *
        FROM ods.ods_slt_s700_bkpf_v 
        WHERE 1=1
        AND gjahr = substr(@year_month_day,1,4)
        AND monat = substr(@year_month_day,5,2)
        AND BLART = '7L'
      ) bkpf
    ON bseg.belnr = bkpf.belnr 
    AND bseg.gjahr = bkpf.gjahr 
    AND bseg.bukrs = bkpf.bukrs
    WHERE 1=1
    AND bseg.hkont IN ('6001001000','6001001001','6001002000')
    ) bseg
--  物料大表
LEFT JOIN dim.dim_fi_mr_product_dd mara 
ON bseg.matnr = mara.matnr

-- 公司和业务范围映射成本中心
LEFT JOIN (select distinct cod_dest3,cod_dest3_name,cost_center_code,cost_center_name FROM ods.odsfima_aw_rul_revabs_000001 where usage_status = '保留') revabs
ON revabs.cod_dest3 = NVL(bseg.gsber,'2204') -- 如果为空就按照2204-青岛分公司的业务范围来匹配

-- 日立收入-公司映射
LEFT JOIN (select ent_sap700_code,cod_azienda FROM ods.odsfima_aw_rul_revaaz_000001 UNION ALL SELECT '1745' AS ent_sap700_code,'1745' AS cod_azienda FROM DUAL) revaaz 
ON bseg.bukrs = revaaz.ent_sap700_code

LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_sap2pb_map a
      WHERE 1=1
      AND a.valid_fr <= LEFT(@year_month_day,6)
      AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
      AND sapversion = 'S700'
    ) AS sap2pb
ON LTRIM(bseg.belnr,'0') = LTRIM(sap2pb.belnr,'0')
AND bseg.bukrs = sap2pb.company_code
AND LTRIM(bseg.buzei,'0') = LTRIM(sap2pb.buzei,'0')

LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
      WHERE 1=1
      AND a.valid_fr <= LEFT(@year_month_day,6)
      AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
    ) AS mt2bd
ON bseg.matnr = mt2bd.material_code
LEFT JOIN dw.dim_product_base_info_dd
  ON bseg.matnr = dim_product_base_info_dd.product_code
;

/**************日立BSEG总账调整数据插入结束*************/


/**************日立SMS及GSMS数据插入开始****************/

INSERT INTO dwd.dwd_fi_mr_gp_detail_mi 
(
  year                     -- 财务年
  ,month                       -- 财务月
  ,company_code                -- 组织
  ,agency_code                 -- 办事处编码/成本中心编码（销售部门）
  ,agency_name                 -- 办事处编码/成本中心名称（销售部门名称）
  ,cust_code                   -- 客商编码
  ,material_code               -- 物料编码
  ,cust_name                   -- 客商名称
  ,onoffline_code              -- 线上线下编码
  ,onoffline_name              -- 线上线下名称
  ,material_name               -- 物料名称
  ,sale_model_code           -- 销售型号编码
  ,sale_model_name           -- 销售型号名称
  ,brand_code                  -- 品牌编码
  ,brand_name                  -- 品牌名称
  ,model_code                  -- 产品型号编码
  ,model_name                  -- 产品型号名称
  ,product_series_code         -- 产品系列编码
  ,product_series_name         -- 产品系列名称
  ,market_pnt_code             -- 营销定位编码
  ,market_pnt_name             -- 营销定位名称
  ,tech_type_code              -- 技术类型编码
  ,tech_type_name              -- 技术类型名称
  ,product_big_class_code      -- 产品大类编码
  ,product_big_class_name      -- 产品大类名称
  ,product_mid_class_code      -- 产品中类编码
  ,product_mid_class_name      -- 产品中类名称
  ,product_small_class_code    -- 产品小类编码
  ,product_small_class_name    -- 产品小类名称
  ,bill_qty                    -- 开票销量
  ,qcy_code                    -- 货币-交易币
  ,rev_sale_amt                -- 销售收入
  ,rev_rst_amt                 -- 还原后收入
  ,tax_rate                    -- 税率
  ,price_tax_amt               -- 含税单价
  ,exchange_rate               -- 汇率
  ,system_src                  -- 源系统
  ,ods_src                     -- 源表
  ,bill_cert_id                -- 开票凭证
  ,bill_cert_item              -- 开票凭证行项目
  ,item_type                   -- 项目分类
  ,material_group_code         -- 物料组
  ,material_group_name         -- 物料组描述
  ,bill_dt                     -- 发票日期
  ,create_dt                   -- 创建日期
  ,acct_src_code               -- 原始科目编码
  ,acct_map_code               -- 映射后科目编码
  ,load_dt                     -- 更新时间
  ,dt_month                    -- 年月
  ,bill_type_code              -- 开票类型
  ,order_type_code             -- 订单类型
  ,cust_mdg_code               -- 客商编码-MDG
  ,bus_range_code              -- 业务范围编码
  ,bus_range_name              -- 业务范围名称
  ,marketing_dept_code         -- 所属营销部门编码（业务管理单元编码）
  ,marketing_dept_name         -- 所属营销部门描述（业务管理单元描述）
  ,profitcenter_code           -- 利润中心编码
  ,gfcfy_amount                -- 价差转费用
  ,gfcfl_amount                -- 费用转价差
  ,discount3_amt             -- 折扣3
  ,rev_sale_bcy_amt
  ,cost_center_code       -- 成本中心编码
  ,cost_center_name       -- 成本中心名称
  ,cp_company_code        --  对方公司

  /*20260518 新增使用客商带出的相关信息字段*/
  , cust_unity_name
  , credit_level_name
  , cust_nature_name
  , cust_type_name
  , channel_l1_code
  , channel_l1_name
  , channel_l2_code
  , channel_l2_name
  , channel_l3_code
  , channel_l3_name
  , marketing_mode_code
  , marketing_mode_name
  , channel_big_class_code
  , channel_big_class_name
  , channel_small_class_code
  , channel_small_class_name
  , ind_big_class_code
  , ind_big_class_name
  , ind_small_class_code
  , ind_small_class_name

  /*20260520 新增miniled类型字段*/
  , miniled_type_code
  , miniled_type_name
)
  /* SMS-销售明细取数 */
select sms.year AS year                       -- 财务年
  ,sms.month AS month                         -- 财务月
  ,revaaz.cod_azienda AS company_code               -- 组织
  ,sms.orgcode AS agency_code                       -- 办事处编码/成本中心编码（销售部门）
  ,sms.orgname AS agency_name                       -- 办事处编码/成本中心名称（销售部门名称）
  ,sms.sales_code AS cust_code                      -- 客商编码
  ,sms.product_id AS material_code                  -- 物料编码
  ,sms.sales_name AS cust_name                      -- 客商名称
  ,case when sms.yw_scope = '电商部' then '020_ON_001' else '020_OFF_001' end AS onoffline_code -- 线上线下编码
  ,case when sms.yw_scope = '电商部' then '线上公共' else '线下公共' end AS onoffline_name              -- 线上线下名称
  ,mara.product_name AS material_name  -- 物料名称
  -- ,COALESCE(TRIM(mara.maktx_s600),TRIM(mara.maktx_s800),TRIM(mara.maktx_s900),TRIM(mara.maktx_s810),TRIM(mara.maktx_mdm)) AS material_name                -- 物料名称
  , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
            ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
            ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
            ) AS sale_model_code      -- 销售型号编码
  -- ,COALESCE(TRIM(mara.zzprdmodel),TRIM(mara.zfacmodel),TRIM(mara.pmodel_number)) AS sale_model_code      -- 销售型号编码
 -- ,'' AS sale_model_name      -- 销售型号名称
 /*alter by 20260811 xiaoyachao.ex 销售型号描述逻辑更新*/
 ,COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name
  ,mara.brand AS brand_code                   --  品牌编码
  ,mara.brand_name AS brand_name              --  品牌名称
  ,mara.model_code AS model_code                  -- 产品型号编码
  ,mara.model_name AS model_name                    -- 产品型号名称
  ,mara.series_code AS product_series_code        --  产品系列编码
  ,mara.series_name AS product_series_name        --  产品系列名称
  ,mara.market_pos_code AS market_pnt_code        --  营销定位编码
  ,mara.market_pos_name AS market_pnt_name        --  营销定位名称
  ,mara.ac_ct_code AS tech_type_code              --  技术类型编码
  ,mara.ac_ct_name AS tech_type_name              --  技术类型名称
  ,mara.big_class_code AS product_big_class_code    --  产品大类编码
  ,mara.big_class_name AS product_big_class_name    --  产品大类名称
  ,mara.middle_class_code AS product_mid_class_code   --  产品中类编码
  ,mara.middle_class_name AS product_mid_class_name   --  产品中类名称
  ,mara.small_class_code AS product_small_class_code  --  产品小类编码
  ,mara.small_class_name AS product_small_class_name  --  产品小类名称
  ,sms.order_qty AS bill_qty            -- 开票销量
  ,'CNY' AS qcy_code                -- 货币-交易币
  ,sms.allocate_amount AS rev_sale_amt              -- 销售收入
  ,sms.restore_amount AS rev_rst_amt                -- 还原后收入
  ,0 AS tax_rate
  -- ,sms.tax_rate AS tax_rate                         -- 税率
  ,sms.price AS price_tax_amt                       -- 含税单价
  ,1 AS exchange_rate                             -- 汇率
  ,'SMS' AS system_src                            -- 源系统
  ,'SMS_RL' AS ods_src                        -- 源表
  ,'' AS bill_cert_id                       -- 开票凭证
  ,sms.item_num AS bill_cert_item                   -- 开票凭证行项目
  ,sms.classification AS item_type                  -- 项目分类
  ,sms.matkl AS material_group_code                 -- 物料组
  ,sms.matkl_name AS material_group_name            -- 物料组描述
  ,sms.kinvoice_date AS bill_dt                     -- 发票日期
  ,sms.created_date AS create_dt                    -- 创建日期
  ,'600100' AS acct_src_code                      -- 原始科目编码
  ,'600100' AS acct_map_code                      -- 映射后科目编码
  ,now() AS load_dt                               -- 更新时间
  ,CONCAT(sms.year,sms.month) AS dt_month         -- 年月
  ,'' AS bill_type_code              -- 开票类型
  ,'' AS order_type_code             -- 订单类型
  ,ods_slt_s700_kna1.zkunnr_mdg AS cust_mdg_code    -- 客商编码-mdg
  ,sms.yw_scopecode AS bus_range_code             -- 业务范围编码
  ,tgsbt.gtext AS bus_range_name            -- 业务范围名称
  ,sms.yw_manageunitcode AS marketing_dept_code        -- 所属营销部门编码（业务管理单元编码）
  ,sms.yw_manageunit AS marketing_dept_name   -- 所属营销部门描述（业务管理单元描述）
  ,CASE WHEN NVL(TRIM(sms.product_id), '') <> '' AND mara.product_type = 'FERT' THEN mara.profitcenter_code
        WHEN NVL(TRIM(sms.product_id), '') <> '' AND NVL(mara.product_type,'|') <> 'FERT' THEN '109087000'
        WHEN NVL(TRIM(sms.product_id), '') = '' THEN '190091000'
   END AS profitcenter_code
  ,sms.gfcfy_amount                   -- 价差转费用
  ,sms.gfcfl_amount                   -- 费用转价差
  ,0-sms.fl_notaxamount AS discount3_amt         -- 折扣3
  ,sms.allocate_amount AS rev_sale_bcy_amt      -- 销售收入-本位币
  ,CONCAT('S700_',revabs.cost_center_code) AS cost_center_code    -- 成本中心编码
  ,revabs.cost_center_name AS cost_center_name  -- 成本中心名称
  ,dim_rule_fi_mr_cust2ctp_mapping.ctp AS cp_company_code --  对方公司

  , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name
  , dim_customer_base_info_dd.credit_level AS credit_level_name
  , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name
  , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
          AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
          AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
          THEN NULL
          ELSE TRIM(
                REGEXP_REPLACE(
                    CONCAT_WS(',',
                        CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                        CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                        CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                    ),
                    '(^,)|(,$)',  
                    ''            
                )
            ) END AS cust_type_name
  , dim_customer_base_info_dd.com_1st_code AS channel_l1_code
  , dim_customer_base_info_dd.com_1st_name AS channel_l1_name
  , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code
  , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name
  , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code
  , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name
  , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code
  , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name
  , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code
  , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name
  , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code
  , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name
  , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code
  , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name
  , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code
  , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name
  /*20260520 新增miniled类型字段*/
  , mara.miniled_type_code
  , mara.miniled_type_name

  FROM( -- sms销售明细-月
    select t.*
      ,substring(kinvoice_date, 1, 4) AS year
      ,substring(kinvoice_date, 6, 2) AS month
    FROM ods.odsemp_sms_hac_hise_monthly_report_rl t
    where 1 = 1
    AND kinvoice_date >= STR_TO_DATE(@year_month_day, '%Y%m%d')  --  20251101 → 2025-11-01
    AND kinvoice_date < DATE_ADD(STR_TO_DATE(@year_month_day, '%Y%m%d'), INTERVAL 1 MONTH) 
    )sms
  
LEFT JOIN (select * FROM dim.dim_fi_mr_product_dd) mara --  物料大表
ON sms.product_id = mara.matnr

-- 日立收入-公司映射
LEFT JOIN (select ent_sap700_code,cod_azienda FROM ods.odsfima_aw_rul_revaaz_000001 UNION ALL SELECT '1745' AS ent_sap700_code,'1745' AS cod_azienda FROM DUAL) revaaz 
ON sms.company_code = revaaz.ent_sap700_code

-- 客户主数据
LEFT JOIN (select DISTINCT ltrim(kunnr,'0') AS kunnr,ltrim(zkunnr_mdg,'0') AS zkunnr_mdg FROM ods.ods_slt_s700_kna1) ods_slt_s700_kna1
ON sms.sales_code = ods_slt_s700_kna1.kunnr

-- 客户主数据基本信息
LEFT JOIN (select * FROM dw.dim_customer_base_info_dd) dim_customer_base_info_dd
ON ods_slt_s700_kna1.zkunnr_mdg = ltrim(dim_customer_base_info_dd.cust_code,'0')
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
  ON ods_slt_s700_kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
 AND revaaz.cod_azienda = dim_customer_trade_info_dd.sale_org
 AND sms.matkl = dim_customer_trade_info_dd.material_group_code

LEFT JOIN dim.dim_rule_fi_mr_cust_busrange_mappping AS cust_map
ON sms.sales_code = cust_map.cust_code

-- 营销中心映射业务范围关系表
LEFT JOIN (select distinct gsber,vkbur FROM ods.odss990_zmdgt138) odss990_zmdgt138
ON dim_customer_base_info_dd.market_center_code = odss990_zmdgt138.vkbur

--  业务范围主数据
LEFT JOIN (select distinct gsber,gtext FROM ods.ods_s700_tgsbt where spras = 1) tgsbt 
ON sms.yw_scopecode = tgsbt.gsber 

-- 公司和业务范围映射成本中心
LEFT JOIN (select distinct cod_dest3,cost_center_code,cost_center_name FROM ods.odsfima_aw_rul_revabs_000001 where usage_status = '保留') revabs
ON revabs.cod_dest3 = sms.yw_scopecode

LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
            WHERE 1=1
              AND a.valid_fr <= LEFT(@year_month_day,6)
              AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
          ) AS mt2bd
   ON  sms.product_id = mt2bd.material_code

left join-- 匹配对方公司
 (
 SELECT DISTINCT ltrim(cust_code,'0') AS kunrg --  客商编码
       ,NVL(cp_company_code_mr,cp_company_code) AS ctp --  对方公司编码
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S700'
 )dim_rule_fi_mr_cust2ctp_mapping
ON sms.sales_code = dim_rule_fi_mr_cust2ctp_mapping.kunrg

UNION ALL
  /* GSMS-销售明细取数 */
select gsms.year AS year                      -- 财务年
  ,gsms.month AS month                        -- 财务月
  ,revaaz.cod_azienda AS company_code               -- 组织
  ,gsms.office_id AS agency_code                    -- 办事处编码/成本中心编码（销售部门）
  ,gsms.office_name AS agency_name                  -- 办事处编码/成本中心名称（销售部门名称）
  ,gsms.sales_code AS cust_code                     -- 客商编码
  ,gsms.product_id AS material_code                 -- 物料编码
  ,gsms.sales_name AS cust_name                     -- 客商名称
  ,'020_OFF_001' AS onoffline_code                -- 线上线下编码
  ,'线下公共' AS onoffline_name                       -- 线上线下名称
  , mara.product_name AS material_name  -- 物料名称
  , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
            ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
            ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
            ) AS sale_model_code      -- 销售型号编码
  -- ,'' AS sale_model_name      -- 销售型号名称
  /*alter by 20260811 xiaoyachao.ex 销售型号描述逻辑更新*/
 ,COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name
  ,gsms.brand_code AS brand_code                   --  品牌编码
  ,gsms.brand AS brand_name              --  品牌名称
  ,mara.model_code AS model_code                    -- 产品型号编码
  ,mara.model_name AS model_name                   -- 产品型号名称
  ,mara.series_code AS product_series_code        --  产品系列编码
  ,mara.series_name AS product_series_name        --  产品系列名称
  ,mara.market_pos_code AS market_pnt_code        --  营销定位编码
  ,mara.market_pos_name AS market_pnt_name        --  营销定位名称
  ,mara.ac_ct_code AS tech_type_code              --  技术类型编码
  ,mara.ac_ct_name AS tech_type_name              --  技术类型名称
  ,mara.big_class_code AS product_big_class_code    --  产品大类编码
  ,mara.big_class_name AS product_big_class_name    --  产品大类名称
  ,mara.middle_class_code AS product_mid_class_code   --  产品中类编码
  ,mara.middle_class_name AS product_mid_class_name   --  产品中类名称
  ,mara.small_class_code AS product_small_class_code  --  产品小类编码
  ,mara.small_class_name AS product_small_class_name  --  产品小类名称
  ,gsms.order_qty AS bill_qty             -- 开票销量
  ,'CNY' AS qcy_code                -- 货币-交易币
  ,gsms.order_price_no_tax_rmb AS rev_sale_amt             -- 销售收入
  ,gsms.order_price_no_tax_rmb AS rev_rst_amt                -- 还原后收入
  ,0 AS tax_rate                                  -- 税率
  ,gsms.price AS price_tax_amt                      -- 含税单价
  ,1 AS exchange_rate                             -- 汇率
  ,'GSMS' AS system_src                           -- 源系统
  ,'GSMS_RL' AS ods_src                       -- 源表
  ,gsms.kp_code AS bill_cert_id                     -- 开票凭证
  ,gsms.item_num AS bill_cert_item                  -- 开票凭证行项目
  ,gsms.classification AS item_type                 -- 项目分类
  ,'' AS material_group_code         -- 物料组
  ,'' AS material_group_name         -- 物料组描述
  ,gsms.kinvoice_date AS bill_dt                    -- 发票日期
  ,'' AS create_dt                   -- 创建日期
  ,'600100' AS acct_src_code                     -- 原始科目编码
  ,'600100' AS acct_map_code                     -- 映射后科目编码
  ,now() AS load_dt                             -- 更新时间
  ,CONCAT(gsms.year,gsms.month) AS dt_month       -- 年月
  ,'' AS bill_type_code              -- 开票类型
  ,'' AS order_type_code             -- 订单类型
  ,ods_slt_s700_kna1.zkunnr_mdg AS cust_mdg_code    -- 客商编码-mdg
  ,gsms.business_scope_code as bus_range_code -- 业务范围
  ,gsms.business_scope AS bus_range_name  -- 业务范围描述
  ,gsms.bmu_code /* revasa.d_sale_dept */ AS marketing_dept_code        -- 所属营销部门编码（业务管理单元编码）
  ,gsms.business_unit AS marketing_dept_name      -- 所属营销部门描述（业务管理单元描述）
  ,CASE WHEN NVL(TRIM(gsms.product_id), '') <> '' AND mara.product_type = 'FERT' THEN mara.profitcenter_code
        WHEN NVL(TRIM(gsms.product_id), '') <> '' AND NVL(mara.product_type,'|') <> 'FERT' THEN '109087000'
        WHEN NVL(TRIM(gsms.product_id), '') = '' THEN '190091000'
   END AS profitcenter_code
  -- ,CASE WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code ELSE mara.profitcenter_code END AS profitcenter_code
  ,0 AS gfcfy_amount                  -- 价差转费用
  ,0 AS gfcfl_amount                  -- 费用转价差
  ,0-gsms.fldxrmb AS discount3_amt          -- 折扣3
  ,gsms.allocate_amount AS rev_sale_bcy_amt      -- 销售收入-本位币
  ,CONCAT('S700_',gsms.costcentercode) as cost_center_code-- 成本中心编码
  ,gsms.costcenter AS cost_center_name  -- 成本中心名称
  ,dim_rule_fi_mr_cust2ctp_mapping.ctp AS cp_company_code --  对方公司
  
  , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name
  , dim_customer_base_info_dd.credit_level AS credit_level_name
  , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name
  , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
          AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
          AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
          THEN NULL
          ELSE TRIM(
                REGEXP_REPLACE(
                    CONCAT_WS(',',
                        CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                        CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                        CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                    ),
                    '(^,)|(,$)',  
                    ''            
                )
            ) END AS cust_type_name
  , dim_customer_base_info_dd.com_1st_code AS channel_l1_code
  , dim_customer_base_info_dd.com_1st_name AS channel_l1_name
  , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code
  , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name
  , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code
  , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name
  , '' AS marketing_mode_code
  , '' AS marketing_mode_name
  , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code
  , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name
  , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code
  , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name
  , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code
  , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name
  , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code
  , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name
  /*20260520 新增miniled类型字段*/
  , mara.miniled_type_code
  , mara.miniled_type_name

FROM(-- gsms销售明细
    select t.* 
      ,substring(kinvoice_date, 1, 4) AS year
      ,substring(kinvoice_date, 6, 2) AS month
    FROM ods.odsemp_sms_hac_hhgj_monthly_report t
    where 1 = 1
    AND kinvoice_date >= STR_TO_DATE(@year_month_day, '%Y%m%d')  --  20251101 → 2025-11-01
    AND kinvoice_date < DATE_ADD(STR_TO_DATE(@year_month_day, '%Y%m%d'), INTERVAL 1 MONTH) 
    )gsms

-- 物料大表
LEFT JOIN (select * FROM dim.dim_fi_mr_product_dd) mara 
ON gsms.product_id = mara.matnr

-- 日立收入-业务管理单元映射
LEFT JOIN 
  (
    select distinct d_sale_dept,d_sale_dept_name
    FROM ods.odsfima_aw_rul_revasa_000001
  ) revasa 
ON gsms.business_unit = revasa.d_sale_dept_name

-- 日立收入-公司映射
LEFT JOIN (select ent_sap700_code,cod_azienda FROM ods.odsfima_aw_rul_revaaz_000001 UNION ALL SELECT '1745' AS ent_sap700_code,'1745' AS cod_azienda FROM DUAL) revaaz  
ON cast(cast(gsms.company_code as bigint) as varchar) = revaaz.ent_sap700_code   /*alter by 20260704 xiaoyachao.ex 处理公司编码数位数字格式的问题*/

-- 客户主数据
LEFT JOIN (select ltrim(kunnr,'0') AS kunnr,ltrim(zkunnr_mdg,'0') AS zkunnr_mdg FROM ods.ods_slt_s700_kna1) ods_slt_s700_kna1 
ON gsms.sales_code = ods_slt_s700_kna1.kunnr

LEFT JOIN dw.dim_customer_base_info_dd --  匹配客商主数据
  ON ods_slt_s700_kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code

LEFT JOIN dim.dim_rule_fi_mr_cust_busrange_mappping AS cust_map
ON gsms.sales_code = cust_map.cust_code

-- 客户主数据基本信息
LEFT JOIN (select distinct ltrim(cust_code,'0') AS cust_code,market_center_code FROM dw.dim_customer_base_info_dd where market_center_code is not null) dim_customer_base_info_dd
ON ods_slt_s700_kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code

--  业务范围主数据
LEFT JOIN (select distinct gsber,gtext FROM ods.ods_s700_tgsbt where spras = 1) tgsbt 
ON gsms.business_scope = tgsbt.gtext 

LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
            WHERE 1=1
              AND a.valid_fr <= LEFT(@year_month_day,6)
              AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
          ) AS mt2bd
  ON gsms.product_id = mt2bd.material_code

left join-- 匹配对方公司
 (
 SELECT DISTINCT ltrim(cust_code,'0') AS kunrg --  客商编码
       ,NVL(cp_company_code_mr,cp_company_code) AS ctp --  对方公司编码
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S700'
 )dim_rule_fi_mr_cust2ctp_mapping
ON gsms.sales_code = dim_rule_fi_mr_cust2ctp_mapping.kunrg
;


/**************日立SMS及GSMS数据插入结束****************/

/****************************************日立相关取数结束****************************************/  





/****************************************SAP810****************************************/  

INSERT INTO dwd.dwd_fi_mr_gp_detail_mi
(year,month,company_code
,agency_code
,cust_code,material_code,shop_code,agency_name,material_name
,cust_name,cust_unity_name,credit_level_name,cust_nature_name,cust_type_name,channel_l1_code,channel_l1_name,channel_l2_code,channel_l2_name,channel_l3_code,channel_l3_name
,marketing_mode_code
,marketing_mode_name,
channel_big_class_code, 
channel_big_class_name,
channel_small_class_code,
channel_small_class_name,
ind_big_class_code,
ind_big_class_name,
ind_small_class_code,
ind_small_class_name,
onoffline_code,onoffline_name
,product_line_code,product_line_name,sale_model_code,sale_model_name,brand_code,brand_name,spec_section_code,spec_section_name,product_shape_type_code,product_shape_type_name,product_sale_series_code,product_sale_series_name,quarter_method_code,quarter_method_name,product_stage_code,product_stage_name,price_range_code,price_range_name,model_code,model_name,product_series_code,product_series_name,market_pnt_code,market_pnt_name,tech_type_code,tech_type_name
,is_miniled_code
,product_big_class_code,product_big_class_name,product_mid_class_code,product_mid_class_name,product_small_class_code,product_small_class_name,model_lca_code,model_lca_name,product_type_code,product_type_name,shop_name,bill_qty,qcy_code,rev_sale_amt
,discount1_amt,discount3_amt,discount4_amt,discount5_amt,discount6_amt,discount34_amt,tax_rate,exchange_rate,system_src,ods_src,bill_cert_id,bill_cert_item,sold_to_code,sold_to_name,material_group_code,cp_company_code,batch_id,material_pricing_group_code,material_pricing_group_name,sale_cert_id,sale_cert_item,sale_cert_type,reference_cert_id,reference_cert_item,acct_cert_id,ext_order_id,load_dt,dt_month
,acct_src_code,acct_map_code,bill_dt
,cust_mdg_code
,bus_range_code,bus_range_name,marketing_dept_code,marketing_dept_name
,comm_bu_code,comm_bu_name
,cn_class_mark_code,cn_class_mark_name
,material_group_name
,profitcenter_code
,profitcenter_name
,customer_model
,zcalasset
,discount30_amt
,rev_sale_bcy_amt
,ship_fact_code
,asap_dt
,br_company_code
,src_profitcenter_code
,src_bus_range_code
/*20260520 新增miniled类型字段*/
, miniled_type_code
, miniled_type_name
)

WITH vbrk AS(
 SELECT  
      vbrp.vbeln AS vbeln --  系统发票号
    , LTRIM(vbrp.posnr,'0') AS posnr --  项目号
    -- , vbrp.matnr AS matnr --  物料编码
    -- EDIT BY LC 260129 老管报针对冲销的RE凭证物料号在分配字段的，增加了取分配字段物料号的逻辑
    , TRIM(vbrp.matnr) AS matnr --  物料编码
    , REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') AS matkl --  物料组
    , CASE WHEN vbrp.vgtyp NOT IN ('T','J') THEN '' ELSE vbrp.vgbel END AS vgbel --  交货单
    , CASE WHEN vbrp.vgtyp NOT IN ('T','J') THEN '' ELSE LTRIM(vbrp.vgpos,'0') END AS vgpos --  交货单行号
    , vbrp.aubel AS aubel --  销售订单
    , LTRIM(vbrp.aupos,'0') AS aupos --  订单行号
    , vbak.auart AS auart --  订单类型
    , '' AS zzextno --  外部订单号
    , CASE WHEN vbrk.vbtyp IN ('O','6','N')
             THEN 0-vbrp.fkimg
           ELSE vbrp.fkimg
      END AS fkimg --  发票数量（实际已开发票量）
    , vbrp.charg AS charg --  批次
    , CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-vbrp.netwr ELSE vbrp.netwr END AS netwr --  不含税合计金额
    , vbrk.fkdat AS fkdat --  日期
    , vbrk.vkorg AS vkorg --  组织（销售机构）
    , vbrk.kunrg AS kunrg --  客户
    , vbrp.vkbur AS vkbur --  办事处编码
    , tvkbt.bezei AS bezei --  办事处描述
    , vbrp.kondm AS kondm --  物料定价组编码
    , t178t.vtext AS vtext --  物料定价组描述
    /* ZK01 直扣(%) */
    , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kbetr_zk01 ELSE konv.kbetr_zk01 END AS kbetr_zk01
    /* ZK05 直扣(%) */
    , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk05 ELSE konv.kwert_zk05 END AS kbetr_zk05
    /* ZK06 直扣(单价) */
    , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk06 ELSE konv.kwert_zk06 END AS kbetr_zk06
    /* ZK04 返利(单价)：6005公司用ZG02，其余用ZK04/ZK02 */
    , CASE
          WHEN vbrk.vbtyp IN ('O', '6', 'N') AND vbrk.vkorg = '6005'
          THEN 0 - IFNULL(konv.kwert_zg02, 0)
          WHEN vbrk.vbtyp NOT IN ('O', '6', 'N') AND vbrk.vkorg = '6005'
          THEN IFNULL(konv.kwert_zg02, 0)
          WHEN vbrk.vbtyp IN ('O', '6', 'N')
          THEN 0 - IFNULL(konv.kwert_zk04, konv.kwert_zk02)
          ELSE IFNULL(konv.kwert_zk04, konv.kwert_zk02)
      END                                          AS kbetr_zk04
    /* ZK03 返利(%) */
    , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk03 ELSE konv.kwert_zk03 END AS kbetr_zk03
    /* ZK34 返利(%) */
    , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk34 ELSE konv.kwert_zk34 END AS kbetr_zk34
    , bkpf.belnr AS belnr --  会计凭证
    , vbrk.kunag AS sold_to --  售达方编码
    , ''  AS sold_to_names --  售达方描述
    , vbrk.waerk AS waerk --  凭证货币
    , CASE WHEN bseg_6012.kursf IS NULL THEN bkpf.kursf ELSE bseg_6012.kursf END AS kursk --  决定价格的汇率
    -- , vbrp.kursk AS kursk --  决定价格的汇率
    , COALESCE(konv.kbetr_mwst, konv.kbetr_mwsi, konv.kbetr_zwst) / 1000 AS kbetr_mwsi
    , '' AS zdpbm --  店铺编码
    , '' AS zdpmc --  店铺名称
    -- , zltxtbm.tline AS zdpbm --  店铺编码
    -- , zltxtmc.tline AS zdpmc --  店铺名称
    , bseg.hkont AS acct_src_code
    , bseg.acct_map_code
    , vbrk.fkdat AS bill_dt
    , bseg.gsber AS bus_range_code
    , tgsbt.gtext AS bus_range_name
    , t023t.wgbez AS material_group_name
    , vbrp.prctr AS profitcenter_code
    , '' AS profitcenter_name
    , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model                       --  客户型号
    , mara.zcalasset AS zcalasset                            --  按套统计
    /* ZK30 返利(单价) */
    , CASE WHEN vbrk.vbtyp IN ('O', '6', 'N') THEN 0 - konv.kwert_zk30 ELSE konv.kwert_zk30 END AS kbetr_zk30
    , CASE WHEN bseg_6012.dmbtr IS NOT NULL THEN bseg_6012.dmbtr 
           ELSE CASE WHEN vbrk.vbtyp IN ('O','6','N') THEN 0-vbrp.netwr ELSE vbrp.netwr END
      END AS dmbtr
    , vbap.werks AS ship_fact_code
    , likp.wadat_ist AS asap_dt
    , vbak.bstzd AS br_company_code
    /*20260520 新增miniled类型字段*/
    , mara.miniled_type_code
    , mara.miniled_type_name
    --  SELECT *
   FROM 
  (    /* VBRK - 发票头 */
    SELECT
        vbeln, fkart, rfbsk, vkorg, kunrg, kunag, fkdat, vbtyp, ernam, waerk, knumv
    FROM ods.odsslt_s810_vbrk
    WHERE fkdat >= @year_month_day
      AND fkdat < DATE_FORMAT(DATE_ADD(CAST(@year_month_day AS DATE), INTERVAL 1 MONTH), '%Y%m%d')
  ) vbrk --  发票头
  LEFT JOIN (
        /* VBRP - 发票行 */
    SELECT
        vbeln, posnr, matnr, vgtyp, vgbel, vgpos, aubel, aupos, fkimg, netwr, charg, vkbur, kondm, prctr, kursk
    FROM ods.odsslt_s810_vbrp
    ) vbrp --  发票行
    ON vbrk.vbeln = vbrp.vbeln
  LEFT JOIN (
  -- 蒙特雷6375限制取以下订单类型
  SELECT auart,vbeln,bstzd FROM ods.odsslt_s810_vbak
  WHERE vkorg= '6375' AND auart IN('ZREX','ZSO6','ZOR9') OR vkorg<> '6375'
  ) vbak --  销售凭证
    ON vbrp.aubel = vbak.vbeln
  LEFT JOIN (
        /* BKPF - 凭证抬头 */
    SELECT bukrs, gjahr, belnr, awkey, awtyp, kursf, blart, bktxt
      FROM ods.ods_slt_s810_bkpf_v WHERE awtyp = 'VBRK'
    ) bkpf --  凭证抬头信息
    ON vbrk.vbeln = bkpf.awkey


  LEFT JOIN (SELECT bukrs,gjahr,belnr,matnr,hkont,acc_map.acct_map_code,zuonr,MAX(gsber) AS gsber FROM ods.ods_slt_s810_bseg_v v_bseg
  left join(
  SELECT distinct acct_src_code,acct_map_code 
  FROM dim.dim_rule_fi_mr_acct_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
                AND system_src = 'S810'
  )acc_map
  on acc_map.acct_src_code = v_bseg.hkont
              WHERE (acc_map.acct_map_code LIKE '6001%' OR acc_map.acct_map_code LIKE '6051%' )
              GROUP BY bukrs,gjahr,belnr,matnr,hkont,acc_map.acct_map_code,zuonr
            ) bseg
    ON bkpf.bukrs = bseg.bukrs
   AND bkpf.gjahr = bseg.gjahr
   AND bkpf.belnr = bseg.belnr
   AND TRIM(vbrp.matnr) = bseg.matnr
  LEFT JOIN dim.dim_fi_mr_product_dd mara --  物料大表
    ON TRIM(vbrp.matnr) = mara.matnr
  LEFT JOIN ods.odss810_t023t t023t --  物料组名称表
    ON mara.matkl = t023t.matkl
   AND t023t.spras = '1'
  LEFT JOIN ods.odss810_t178t t178t --  物料定价组描述
    ON t178t.kondm = vbrp.kondm
   AND t178t.spras = '1'
  LEFT JOIN (SELECT bukrs,gjahr,belnr,matnr,hkont
                    ,(CASE 
                         WHEN a.wrbtr <> 0 
                         THEN a.dmbtr / a.wrbtr  --  反算汇率
                         -- ELSE bkpf.kursf                           --  外币金额为0时直接取bkpf汇率
                     END) AS kursf
                     ,a.dmbtr,a.wrbtr
               FROM 
             (SELECT bukrs,gjahr,belnr,matnr,hkont,SUM(CASE WHEN shkzg = 'S' THEN dmbtr ELSE -1*dmbtr END) AS dmbtr
                    ,SUM(CASE WHEN shkzg = 'S' THEN wrbtr ELSE -1*wrbtr END) AS wrbtr 
               FROM ods.ods_slt_s810_bseg_v 
              WHERE (hkont LIKE '6001%' OR hkont LIKE '6051%' )
                -- AND bukrs IN ('6012','2023')
              GROUP BY bukrs,gjahr,belnr,matnr,hkont
            ) a
            ) bseg_6012
    ON bkpf.bukrs = bseg_6012.bukrs
   AND bkpf.gjahr = bseg_6012.gjahr
   AND bkpf.belnr = bseg_6012.belnr
   AND TRIM(vbrp.matnr) = bseg_6012.matnr
  LEFT JOIN ods.odss810_tvkbt tvkbt --  办事处描述
    ON vbrp.vkbur = tvkbt.vkbur
   AND tvkbt.spras = '1'
  LEFT JOIN ods.odss810_ekko ekko --  采购凭证
    ON vbrp.aubel = ekko.ebeln
  LEFT JOIN (SELECT distinct vbeln,posnr,gsber,werks  FROM ods.odsslt_s810_vbap) vbap--  销售订单行项目 20251226 UPDATE BY LYF
    ON vbrp.aubel = vbap.vbeln
   AND LTRIM(vbrp.aupos,'0') = LTRIM(vbap.posnr,'0')
  LEFT JOIN (SELECT * FROM ods.odss810_tgsbt WHERE spras = 1) tgsbt --  业务范围描述
    ON vbap.gsber = tgsbt.gsber
  LEFT JOIN (
    SELECT MAX(a.wadat_ist) AS wadat_ist,b.vgbel 
      FROM ods.odss810_likp a
      LEFT JOIN (
                SELECT DISTINCT vbeln, vgbel FROM ods.odss810_lips
                ) b
        ON a.vbeln = b.vbeln
     WHERE a.wadat_ist IS NOT NULL
     GROUP BY b.vgbel
  ) likp
    ON vbrp.aubel = likp.vgbel

/* ===================== KONV 单表扫描 + 行转列（嵌套子查询）===================== */
LEFT JOIN (
    SELECT
        knumv,
        kposn,
        MAX(CASE WHEN kschl = 'ZK01' AND rn = 1 THEN kbetr END) AS kbetr_zk01,
        MAX(CASE WHEN kschl = 'ZK02' AND rn = 1 THEN kwert END) AS kwert_zk02,
        MAX(CASE WHEN kschl = 'ZK03' AND rn = 1 THEN kwert END) AS kwert_zk03,
        MAX(CASE WHEN kschl = 'ZK04' AND rn = 1 THEN kwert END) AS kwert_zk04,
        MAX(CASE WHEN kschl = 'ZK05' AND rn = 1 THEN kwert END) AS kwert_zk05,
        MAX(CASE WHEN kschl = 'ZK06' AND rn = 1 THEN kwert END) AS kwert_zk06,
        MAX(CASE WHEN kschl = 'MWST' AND rn = 1 THEN kbetr END) AS kbetr_mwst,
        MAX(CASE WHEN kschl = 'MWSI' AND rn = 1 THEN kbetr END) AS kbetr_mwsi,
        MAX(CASE WHEN kschl = 'ZWST' AND rn = 1 THEN kbetr END) AS kbetr_zwst,
        MAX(CASE WHEN kschl = 'ZK34' AND rn = 1 THEN kwert END) AS kwert_zk34,
        MAX(CASE WHEN kschl = 'ZK30' AND rn = 1 THEN kwert END) AS kwert_zk30,
        MAX(CASE WHEN kschl = 'ZG02' AND rn = 1 THEN kwert END) AS kwert_zg02
    FROM (
        SELECT
            knumv, kposn, kschl, kbetr, kwert,
            ROW_NUMBER() OVER (
                PARTITION BY knumv, kposn, kschl
                ORDER BY CASE
                    WHEN kschl = 'ZG02' THEN CASE kherk WHEN 'G' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                    ELSE CASE kherk WHEN 'C' THEN 1 WHEN 'A' THEN 2 ELSE 3 END
                END
            ) AS rn
        FROM (
            SELECT
                kherk, knumv, kposn, kschl,
                SUM(kbetr) AS kbetr,
                SUM(kwert) AS kwert
            FROM ods.odsslt_s810_konv
            WHERE kschl IN ('ZK01','ZK02','ZK03','ZK04','ZK05','ZK06',
                            'MWST','MWSI','ZWST','ZK34','ZK30')
            GROUP BY kherk, knumv, kposn, kschl
        ) t_base
    ) t_rank
    WHERE rn = 1
    GROUP BY knumv, kposn
) konv
    ON  vbrk.knumv = konv.knumv
    AND vbrp.posnr = konv.kposn
 WHERE 1=1
   AND vbrk.fkart <> 'ZG1'
   AND (vbrk.vkorg= '6375' AND vbak.auart IN('ZREX','ZSO6','ZOR9') OR vbrk.vkorg<> '6375')
   AND vbrk.rfbsk = 'C'
),
 form_dati_ctp AS --  匹配对方公司
 (
 SELECT cust_code AS kunrg --  客商编码
       ,NVL(cp_company_code_mr,cp_company_code) AS ctp --  对方公司编码
       ,SUBSTR(system_src,2,3) AS system_src
   FROM dim.dim_rule_fi_mr_cust2ctp_mapping a 
  WHERE cust_type_code = 'C'
    AND system_src = 'S810'
 ),
  vbrk_m AS 
 (--  匹配物料大表，错误产品线和对方公司
   SELECT
      vbrk.*
     ,CASE WHEN form_dati_ctp.ctp IN ('4330','4320') AND vbrk.vkorg = '6515'  THEN CONCAT(form_dati_ctp.ctp,'A') ELSE form_dati_ctp.ctp END ctp --  对方公司
    FROM vbrk 
    LEFT JOIN form_dati_ctp --  匹配对方公司
      ON vbrk.kunrg = form_dati_ctp.kunrg
 )
SELECT 
    date_format(vbrk.fkdat,'%Y') AS year --  财务年
  , date_format(vbrk.fkdat,'%m') AS month --  财务月
  , vbrk.vkorg AS company_code --  组织
  , vbrk.vkbur AS agency_code --  办事处编码
  , vbrk.kunrg AS cust_code --  客商编码
  , vbrk.matnr AS material_code --  物料编码
  , vbrk.zdpbm AS shop_code --  门店编码
  , vbrk.bezei AS agency_name --  办事处名称
  , dim_fi_mr_product_dd.product_name AS material_name
  , ods_slt_s810_kna1.name1 AS cust_name --  客商名称
  , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name --  统一客户组
  , dim_customer_base_info_dd.credit_level AS credit_level_name --  信用等级
  , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name --  单位性质
  , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
  AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
  AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
  THEN NULL
  ELSE TRIM(
        REGEXP_REPLACE(
            CONCAT_WS(',',
                CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
            ),
            '(^,)|(,$)',  
            ''            
        )
    )
    END AS cust_type_name  --  客户类型
  , dim_customer_base_info_dd.com_1st_code AS channel_l1_code --  销售渠道一级编码
  , dim_customer_base_info_dd.com_1st_name AS channel_l1_name --  销售渠道一级名称
  , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code --  销售渠道二级编码
  , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name --  销售渠道二级名称
  , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code --  销售渠道三级编码
  , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name --  销售渠道三级名称
  , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code --  销售模式编码
  , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name --  销售模式名称
  , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code --  渠道客户大类编码
  , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name --  渠道客户大类名称
  , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code --  渠道客户小类编码
  , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name --  渠道客户小类名称
  , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code --  行业大类编码
  , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name --  行业大类名称
  , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code --  行业小类编码
  , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name --  行业小类名称
  , '020_OFF_002' AS onoffline_code --  线上线下编码
  , '零售-传统零售' AS onoffline_name --  线上线下名称
  , '' AS product_line_code --  产品线编码
  , '' AS product_line_name --  产品线名称
  , COALESCE(IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
            ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
            ) AS sale_model_code --  销售型号编码
  -- , '' AS sale_model_name --  销售型号名称
  /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
   ,COALESCE(IF(TRIM(dim_fi_mr_product_dd.sale_model_name)= '',NULL,TRIM(dim_fi_mr_product_dd.sale_model_name))
              ,IF(TRIM(dim_fi_mr_product_dd.zzprdmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zzprdmodel))
              ,IF(TRIM(dim_fi_mr_product_dd.zfacmodel)= '',NULL,TRIM(dim_fi_mr_product_dd.zfacmodel))
              ,IF(TRIM(dim_fi_mr_product_dd.pmodel_number)= '',NULL,TRIM(dim_fi_mr_product_dd.pmodel_number))
              ) AS sale_model_name
  , dim_fi_mr_product_dd.brand AS brand_code --  品牌编码
  , dim_fi_mr_product_dd.brand_name AS brand_name --  品牌名称
  ,CASE WHEN dim_fi_mr_product_dd.big_class_code = 'P01' THEN dim_fi_mr_product_dd.SCREEN_SIZE_CODE
    WHEN dim_fi_mr_product_dd.big_class_code = 'P02' THEN dim_fi_mr_product_dd.SPEC_RANGE_CODE
    WHEN dim_fi_mr_product_dd.big_class_code = 'P03' THEN dim_fi_mr_product_dd.TOTAL_CAPACITY_CODE
    WHEN dim_fi_mr_product_dd.big_class_code = 'P04' THEN dim_fi_mr_product_dd.WASHING_CAPACITY_CODE
   END AS spec_section_code --  规格段编码
    ,CASE WHEN dim_fi_mr_product_dd.big_class_code = 'P01' THEN dim_fi_mr_product_dd.SCREEN_SIZE_NAME
    WHEN dim_fi_mr_product_dd.big_class_code = 'P02' THEN dim_fi_mr_product_dd.SPEC_RANGE_NAME
    WHEN dim_fi_mr_product_dd.big_class_code = 'P03' THEN dim_fi_mr_product_dd.TOTAL_CAPACITY_NAME
    WHEN dim_fi_mr_product_dd.big_class_code = 'P04' THEN dim_fi_mr_product_dd.WASHING_CAPACITY_NAME
   END  AS spec_section_name --  规格段名称
  , dim_fi_mr_product_dd.product_spec_code AS product_shape_type_code --  产品形态分类编码
  , dim_fi_mr_product_dd.product_spec_name AS product_shape_type_name --  产品形态分类名称
  , dim_fi_mr_product_dd.prod_suite_code AS product_sale_series_code --  产品套系编码
  , dim_fi_mr_product_dd.prod_suite_name AS product_sale_series_name --  产品套系名称
  , '' AS quarter_method_code --  四分法编码（市场口径）
  , '' AS quarter_method_name --  四分法名称（市场口径）
  , dim_fi_mr_product_dd.prod_stage_code AS product_stage_code --  产品阶段编码
  , dim_fi_mr_product_dd.prod_stage_name AS product_stage_name --  产品阶段名称
  , dim_fi_mr_product_dd.price_range_code AS price_range_code --  价格段编码
  , dim_fi_mr_product_dd.price_range_name AS price_range_name --  价格段名称
  , dim_fi_mr_product_dd.model_code AS model_code --  产品型号编码
  , dim_fi_mr_product_dd.model_name AS model_name --  产品型号名称
  , dim_fi_mr_product_dd.series_code AS product_series_code --  产品系列编码
  , dim_fi_mr_product_dd.series_name AS product_series_name --  产品系列名称
  , dim_fi_mr_product_dd.market_pos_code AS market_pnt_code --  营销定位编码
  , dim_fi_mr_product_dd.market_pos_name AS market_pnt_name --  营销定位名称
  , dim_fi_mr_product_dd.ac_ct_code AS tech_type_code --  技术类型编码
  , dim_fi_mr_product_dd.ac_ct_name AS tech_type_name --  技术类型名称
  , CASE WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013001' THEN '是'
         WHEN dim_fi_mr_product_dd.is_miniled_code  = 'PC00013002' THEN '否'
         ELSE ''
    END AS is_miniled_code --  是否MiniLED编码
  , dim_fi_mr_product_dd.big_class_code AS product_big_class_code --  产品大类编码
  , dim_fi_mr_product_dd.big_class_name AS product_big_class_name --  产品大类名称
  , dim_fi_mr_product_dd.middle_class_code AS product_mid_class_code --  产品中类编码
  , dim_fi_mr_product_dd.middle_class_name AS product_mid_class_name --  产品中类名称
  , dim_fi_mr_product_dd.small_class_code AS product_small_class_code --  产品小类编码
  , dim_fi_mr_product_dd.small_class_name AS product_small_class_name --  产品小类名称
  , dim_fi_mr_product_dd.model_lca AS model_lca_code --  产品型号生命周期编码
  , dim_fi_mr_product_dd.model_lca_name AS model_lca_name --  产品型号生命周期名称
  , ods_mr_aw_rul_revama_000001.product_type_code AS product_type_code --  产品类型编码
  , ods_mr_aw_rul_revama_000001.product_type_name AS product_type_name --  产品类型名称
  , vbrk.zdpmc AS shop_name --  门店名称
  , vbrk.fkimg AS bill_qty --  开票销量
  , vbrk.waerk AS qcy_code --  货币-交易币
  , vbrk.netwr AS rev_sale_amt --  销售收入
  , vbrk.kbetr_zk01 AS discount1_amt --  折扣3
  , vbrk.kbetr_zk03 AS discount3_amt --  折扣3
  , vbrk.kbetr_zk04 AS discount4_amt --  折扣4
  , vbrk.kbetr_zk05 AS discount5_amt --  折扣5
  , vbrk.kbetr_zk06 AS discount6_amt --  折扣6
  , vbrk.kbetr_zk34 AS discount34_amt --  折扣34
  , vbrk.kbetr_mwsi AS tax_rate --  税率
  , vbrk.kursk AS exchange_rate --  汇率
  , 'S810' AS system_src --  源系统
  , 'VBRP' AS ods_src --  源表
  , vbrk.vbeln AS bill_cert_id --  开票凭证
  , vbrk.posnr AS bill_cert_item --  开票凭证行项目
  , vbrk.sold_to AS sold_to_code --  售达方
  , sold_to.name1 AS sold_to_name --  售达方名称
  , vbrk.matkl AS material_group_code --  物料组
  , vbrk.ctp AS cp_company_code --  对方公司
  , vbrk.charg AS batch_id --  批次号
  , vbrk.kondm AS material_pricing_group_code --  物料定价组编码
  , vbrk.vtext AS material_pricing_group_name --  物料定价组名称
  , vbrk.aubel AS sale_cert_id --  销售凭证号
  , vbrk.aupos AS sale_cert_item --  销售凭证行项目
  , vbrk.auart AS sale_cert_type --  销售凭证类型
  , vbrk.vgbel AS reference_cert_id --  参考单据编号
  , vbrk.vgpos AS reference_cert_item --  参考单据项目号
  , vbrk.belnr AS acct_cert_id --  会计凭证号
  , vbrk.zzextno AS ext_order_id --  外部订单号
  , now() AS load_dt --  更新时间
  , date_format(fkdat,'%Y%m') AS dt_month --  年月
  , vbrk.acct_src_code
  , vbrk.acct_map_code
  , vbrk.bill_dt
  , ods_slt_s810_kna1.zkunnr_mdg AS cust_mdg_code
  , '3001' AS bus_range_code
  , 'North America Public' AS bus_range_name
  , '' AS marketing_dept_code
  , '' AS marketing_dept_name
  , '' AS comm_bu_code
  , '' AS comm_bu_name
  , '' AS cn_class_mark_code
  , '' AS cn_class_mark_name
  , vbrk.material_group_name AS material_group_name
  , CASE WHEN mt2bd.profitcenter_code IS NOT NULL 
            THEN mt2bd.profitcenter_code 
         ELSE dim_fi_mr_product_dd.profitcenter_code 
    END AS profitcenter_code
  , CASE WHEN mt2bd.profitcenter_name IS NOT NULL 
           THEN mt2bd.profitcenter_name 
         ELSE dim_fi_mr_product_dd.profitcenter_name 
    END AS profitcenter_name
  , COALESCE(if(upper(dim_fi_mr_product_dd.sale_model_name)='无',null,upper(dim_fi_mr_product_dd.sale_model_name)),if(upper(dim_fi_mr_product_dd.zcusmodel)='无',null,upper(dim_fi_mr_product_dd.zcusmodel))) AS customer_model   --  客户型号
  , dim_fi_mr_product_dd.zcalasset AS zcalasset        --  按套统计
  , vbrk.kbetr_zk30 AS discount30_amt --  折扣34
  , vbrk.dmbtr AS rev_sale_bcy_amt --  销售收入-本位币
  , vbrk.ship_fact_code AS ship_fact_code
  , vbrk.asap_dt AS asap_dt
  , vbrk.br_company_code
  , vbrk.profitcenter_code AS src_profitcenter_code
  , vbrk.bus_range_code AS src_bus_range_code
  /*20260520 新增miniled类型字段*/
  , dim_fi_mr_product_dd.miniled_type_code
  , dim_fi_mr_product_dd.miniled_type_name
FROM vbrk_m AS vbrk
LEFT JOIN (SELECT * FROM ods.ods_slt_s810_kna1) ods_slt_s810_kna1
  ON vbrk.kunrg = ods_slt_s810_kna1.kunnr
LEFT JOIN dw.dim_customer_base_info_dd --  匹配客商主数据
  ON ods_slt_s810_kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
  ON ods_slt_s810_kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
 AND vbrk.vkorg = dim_customer_trade_info_dd.sale_org
 AND vbrk.matkl = dim_customer_trade_info_dd.material_group_code
LEFT JOIN dim.dim_fi_mr_product_dd --  匹配物料大表
  ON vbrk.matnr = dim_fi_mr_product_dd.matnr
LEFT JOIN ods.ods_slt_s810_kna1 AS sold_to --  匹配售达方数据
  ON vbrk.sold_to = sold_to.kunnr
LEFT JOIN (   SELECT batch, product_type_code, product_type_name
                FROM dim.dim_rule_fi_mr_batch2protype_mapping a  
               WHERE valid_fr <= @year_month_day
                 AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
          ) AS ods_mr_aw_rul_revama_000001 --  批次对应产品类型映射表
   ON vbrk.charg = ods_mr_aw_rul_revama_000001.batch
 LEFT JOIN dw.dim_product_base_info_dd
   ON vbrk.matnr = dim_product_base_info_dd.product_code
LEFT JOIN (  SELECT material_code,profitcenter_code,profitcenter_name
               FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON vbrk.matnr = mt2bd.material_code    
;
/***********************************SAP810插入结束*************************************/

/***********************************SAP810调整数据插入开始*************************************/
INSERT INTO dwd.dwd_fi_mr_gp_detail_mi 
 (
   year,month,company_code,onoffline_code,onoffline_name,product_line_code,bill_qty,qcy_code,rev_sale_amt,system_src,ods_src,bill_cert_id,acct_src_code,acct_map_code,order_type_code,load_dt,dt_month,profitcenter_code,profitcenter_name,customer_model,zcalasset,bus_range_code,bus_range_name,rev_sale_bcy_amt,marketing_dept_code,material_code
  /*20260128 新增使用物料带出的相关信息字段*/
  , material_group_code -- 物料组
  , sale_model_code -- 销售型号编码
  , sale_model_name -- 销售型号名称   /* alter by 20260811 xiaoyachao.ex */
  , product_sale_series_code --  产品套系编码
  , product_sale_series_name --  产品套系名称
  , product_stage_code --  产品阶段编码
  , product_stage_name --  产品阶段名称
  , price_range_code --  价格段编码
  , price_range_name --  价格段名称
  , model_code --  产品型号编码
  , model_name --  产品型号名称
  , product_series_code --  产品系列编码
  , product_series_name --  产品系列名称
  , market_pnt_code --  营销定位编码
  , market_pnt_name --  营销定位名称
  , tech_type_code --  技术类型编码
  , tech_type_name --  技术类型名称
  , is_miniled_code --  是否MiniLED编码
  , product_big_class_code --  产品大类编码
  , product_big_class_name --  产品大类名称
  , product_mid_class_code --  产品中类编码
  , product_mid_class_name --  产品中类名称
  , product_small_class_code --  产品小类编码
  , product_small_class_name --  产品小类名称
  , model_lca_code --  产品型号生命周期编码
  , model_lca_name --  产品型号生命周期名称
  , brand_code --  品牌编码
  , brand_name --  品牌名称
  , spec_section_code --  规格段编码
  , spec_section_name --  规格段名称
  , product_shape_type_code --  产品形态分类编码
  , product_shape_type_name --  产品形态分类名称
  , src_profitcenter_code
  , src_bus_range_code
  , comm_bu_code -- 电商BU渠道细分编码
  , comm_bu_name -- 电商BU渠道细分描述
  , cn_class_mark_code -- 中国区品类标记编码
  , cn_class_mark_name -- 中国区品类标记描述
  , bus_sce_cat_code -- 业务场景分类编码
  , bus_sce_cat_name -- 业务场景分类描述
  , transaction_type -- 事务类型
  , cust_code --  客商编码
  , cust_name --  客商名称
  , cp_company_code -- 对方公司
  , cust_mdg_code --  客商编码-MDG


  /*20260518 新增使用客商带出的相关信息字段*/
  , cust_unity_name
  , credit_level_name
  , cust_nature_name
  , cust_type_name
  , channel_l1_code
  , channel_l1_name
  , channel_l2_code
  , channel_l2_name
  , channel_l3_code
  , channel_l3_name
  , marketing_mode_code
  , marketing_mode_name
  , channel_big_class_code
  , channel_big_class_name
  , channel_small_class_code
  , channel_small_class_name
  , ind_big_class_code
  , ind_big_class_name
  , ind_small_class_code
  , ind_small_class_name

  /*20260520 新增miniled类型字段*/
  , miniled_type_code
  , miniled_type_name



)

/******BSEG调整数据限制科目5001%******/
SELECT  bseg.gjahr AS year
      , bkpf.monat AS month
      , bseg.bukrs AS company_code
      , '020_OFF_002' AS onoffline_code
      , '零售-传统零售' AS onoffline_name
      , bseg.prctr AS product_line_code
      , 0 AS bill_qty
      , bseg.pswsl AS qcy_code
      , CASE WHEN bseg.shkzg = 'S' THEN bseg.dmbtr ELSE -1*bseg.dmbtr END AS rev_sale_amt
      , 'S810' AS system_src
      , 'BSEG' AS ods_src
      , bseg.belnr AS bill_cert_id
      , bseg.hkont AS acct_src_code
      , acc_map.acct_map_code AS acct_map_code
      , bkpf.glvor AS order_type_code
      , NOW() AS load_dt
      , CONCAT(bseg.gjahr,bkpf.monat) AS dt_month
      , CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END AS profitcenter_code
      , '' AS profitcenter_name
      , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model 
      , mara.zcalasset AS zcalasset  
      , '3001' AS bus_range_code
      , 'North America Public' AS bus_range_name
      , CASE WHEN bseg.bukrs IN ('6012','2023') THEN CASE WHEN bseg.shkzg = 'S' THEN bseg.dmbtr ELSE -1*bseg.dmbtr END
             ELSE CASE WHEN bseg.shkzg = 'S' THEN bseg.wrbtr ELSE -1*bseg.wrbtr END
        END AS rev_sale_bcy_amt
      , '' AS marketing_dept_code
      , bseg.matnr AS material_code
      /*20260128 新增使用物料带出的相关信息字段*/
      , REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') AS material_group_code -- 物料组
      , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
            ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
            ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
          ) AS sale_model_code -- 销售型号编码
      /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
      ,COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
                  ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
                  ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
                  ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
                  ) AS sale_model_name
      , mara.prod_suite_code AS product_sale_series_code --  产品套系编码
      , mara.prod_suite_name AS product_sale_series_name --  产品套系名称
      , mara.prod_stage_code AS product_stage_code --  产品阶段编码
      , mara.prod_stage_name AS product_stage_name --  产品阶段名称
      , mara.price_range_code AS price_range_code --  价格段编码
      , mara.price_range_name AS price_range_name --  价格段名称
      , mara.model_code AS model_code --  产品型号编码
      , mara.model_name AS model_name --  产品型号名称
      , mara.series_code AS product_series_code --  产品系列编码
      , mara.series_name AS product_series_name --  产品系列名称
      , mara.market_pos_code AS market_pnt_code --  营销定位编码
      , mara.market_pos_name AS market_pnt_name --  营销定位名称
      , mara.ac_ct_code AS tech_type_code --  技术类型编码
      , mara.ac_ct_name AS tech_type_name --  技术类型名称
      , CASE WHEN mara.is_miniled_code  = 'PC00013001' THEN '是'
           WHEN mara.is_miniled_code  = 'PC00013002' THEN '否'
           ELSE ''
        END AS is_miniled_code --  是否MiniLED编码
      , mara.big_class_code AS product_big_class_code --  产品大类编码
      , mara.big_class_name AS product_big_class_name --  产品大类名称
      , mara.middle_class_code AS product_mid_class_code --  产品中类编码
      , mara.middle_class_name AS product_mid_class_name --  产品中类名称
      , mara.small_class_code AS product_small_class_code --  产品小类编码
      , mara.small_class_name AS product_small_class_name --  产品小类名称
      , mara.model_lca AS model_lca_code --  产品型号生命周期编码
      , mara.model_lca_name AS model_lca_name --  产品型号生命周期名称
      , mara.brand AS brand_code --  品牌编码
      , mara.brand_name AS brand_name --  品牌名称
    ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_CODE
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_CODE
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_CODE
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_CODE
     END AS spec_section_code --  规格段编码
      ,CASE WHEN mara.big_class_code = 'P01' THEN mara.SCREEN_SIZE_NAME
     WHEN mara.big_class_code = 'P02' THEN mara.SPEC_RANGE_NAME
     WHEN mara.big_class_code = 'P03' THEN mara.TOTAL_CAPACITY_NAME
     WHEN mara.big_class_code = 'P04' THEN mara.WASHING_CAPACITY_NAME
     END  AS spec_section_name --  规格段名称
      , mara.product_spec_code AS product_shape_type_code --  产品形态分类编码
      , mara.product_spec_name AS product_shape_type_name --  产品形态分类名称
      , bseg.prctr AS src_profitcenter_code
      , bseg.gsber AS src_bus_range_code
      , '' AS comm_bu_code -- 电商BU渠道细分编码
      , '' AS comm_bu_name -- 电商BU渠道细分描述
      , '' AS cn_class_mark_code -- 中国区品类标记编码
      , '' AS cn_class_mark_name -- 中国区品类标记描述
      , '' AS bus_sce_cat_code -- 业务场景分类编码
      , '' AS bus_sce_cat_name -- 业务场景分类描述
      , bseg.vorgn  AS transaction_type -- 事务类型
      , bseg.xref3 as cust_code --  客商编码
      , kna1.name1 AS cust_name --  客商名称
      , NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) AS cp_company_code --  对方公司
      , kna1.zkunnr_mdg AS cust_mdg_code --  客商编码-MDG

      , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name
      , dim_customer_base_info_dd.credit_level AS credit_level_name
      , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name
      , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
              AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
              AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
              THEN NULL
              ELSE TRIM(
                    REGEXP_REPLACE(
                        CONCAT_WS(',',
                            CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                            CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                            CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                        ),
                        '(^,)|(,$)',  
                        ''            
                    )
                ) END AS cust_type_name
      , dim_customer_base_info_dd.com_1st_code AS channel_l1_code
      , dim_customer_base_info_dd.com_1st_name AS channel_l1_name
      , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code
      , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name
      , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code
      , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name
      , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code
      , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name
      , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code
      , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name
      , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code
      , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name
      , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code
      , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name
      , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code
      , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name
      /*20260520 新增miniled类型字段*/
      , mara.miniled_type_code
      , mara.miniled_type_name

  FROM (SELECT * 
          FROM ods.ods_slt_s810_bseg_v
         WHERE IFNULL(TRIM(aufnr),'') = ''
           AND hkont like '5001%' 
        ) bseg
  INNER JOIN (SELECT * 
               FROM ods.ods_slt_s810_bkpf_v 
              WHERE gjahr = substr(@year_month_day,1,4)
                AND monat = substr(@year_month_day,5,2)
             ) bkpf
    ON bseg.belnr = bkpf.belnr 
   AND bseg.gjahr = bkpf.gjahr 
   AND bseg.bukrs = bkpf.bukrs
  LEFT JOIN dim.dim_rule_fi_mr_cust2ctp_mapping cust2ctp --  经分项目收入模块规则映射表                                      
    ON LTRIM(BSEG.xref3,0) = LTRIM(cust2ctp.cust_code,0)
  AND cust2ctp.cust_type_code = 'C'
  AND cust2ctp.system_src = 'S810'
  LEFT JOIN dim.dim_fi_mr_product_dd mara --  物料大表
    ON bseg.matnr = mara.matnr
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_sap2pb_map a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
                AND sapversion = 'S810'
            ) AS sap2pb
    ON LTRIM(bseg.belnr,'0') = LTRIM(sap2pb.belnr,'0')
   AND bseg.bukrs = sap2pb.company_code
   AND LTRIM(bseg.buzei,'0') = LTRIM(sap2pb.buzei,'0')
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON bseg.matnr = mt2bd.material_code
  LEFT JOIN dw.dim_product_base_info_dd
    ON bseg.matnr = dim_product_base_info_dd.product_code
  -- ADD ZZS XSJ 20260330ZZS修改：新增客商编码，名称，对方公司取值逻辑
  LEFT JOIN ods.ods_slt_s810_kna1 kna1 --  客户主数据
    ON LTRIM(bseg.xref3,0) = LTRIM(kna1.kunnr,0)
  LEFT JOIN dw.dim_customer_base_info_dd --  匹配客商主数据
    ON kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code
  LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
    ON kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
   AND bseg.bukrs = dim_customer_trade_info_dd.sale_org
   AND REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = dim_customer_trade_info_dd.material_group_code
  LEFT JOIN(
              SELECT distinct acct_src_code,acct_map_code 
              FROM dim.dim_rule_fi_mr_acct_mapping a
                          WHERE 1=1
                            AND a.valid_fr <= LEFT(@year_month_day,6)
                            AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
                            AND system_src = 'S810'
              ) acc_map
       ON acc_map.acct_src_code = bseg.hkont

;

/***********************************SAP810调整数据插入结束*************************************/




/******SAP810 BSEG成本数据限制科目 插入开始******/

 INSERT INTO dwd.dwd_fi_mr_gp_detail_mi 
 (
 year
,month
,company_code
,onoffline_code
,onoffline_name
,product_line_code
,qcy_code
,cogs_amt
,system_src
,ods_src
,bill_cert_id
,acct_src_code
,acct_map_code
,order_type_code
,load_dt,dt_month
,material_code
,material_name
,profitcenter_code
,profitcenter_name
,customer_model
,zcalasset
,material_group_name
,bus_range_code
,bus_range_name
,marketing_dept_code
/*20260128 新增使用物料带出的相关信息字段*/
, material_group_code -- 物料组
, sale_model_code -- 销售型号编码
, sale_model_name -- 销售型号名称  /*alter by 20260811 xiaoyachao.ex */
, product_sale_series_code --  产品套系编码
, product_sale_series_name --  产品套系名称
, product_stage_code --  产品阶段编码
, product_stage_name --  产品阶段名称
, price_range_code --  价格段编码
, price_range_name --  价格段名称
, model_code --  产品型号编码
, model_name --  产品型号名称
, product_series_code --  产品系列编码
, product_series_name --  产品系列名称
, market_pnt_code --  营销定位编码
, market_pnt_name --  营销定位名称
, tech_type_code --  技术类型编码
, tech_type_name --  技术类型名称
, is_miniled_code --  是否MiniLED编码
, product_big_class_code --  产品大类编码
, product_big_class_name --  产品大类名称
, product_mid_class_code --  产品中类编码
, product_mid_class_name --  产品中类名称
, product_small_class_code --  产品小类编码
, product_small_class_name --  产品小类名称
, model_lca_code --  产品型号生命周期编码
, model_lca_name --  产品型号生命周期名称
, brand_code --  品牌编码
, brand_name --  品牌名称
, spec_section_code --  规格段编码
, spec_section_name --  规格段名称
, product_shape_type_code --  产品形态分类编码
, product_shape_type_name --  产品形态分类名称
, src_profitcenter_code
, src_bus_range_code
, transaction_type --  事务类型
, cust_code --  客商编码
, cust_name --  客商名称
, cp_company_code -- 对方公司
, cust_mdg_code --  客商编码-MDG

/*20260518 新增使用客商带出的相关信息字段*/
, cust_unity_name
, credit_level_name
, cust_nature_name
, cust_type_name
, channel_l1_code
, channel_l1_name
, channel_l2_code
, channel_l2_name
, channel_l3_code
, channel_l3_name
, marketing_mode_code
, marketing_mode_name
, channel_big_class_code
, channel_big_class_name
, channel_small_class_code
, channel_small_class_name
, ind_big_class_code
, ind_big_class_name
, ind_small_class_code
, ind_small_class_name

/*20260520 新增miniled类型字段*/
, miniled_type_code
, miniled_type_name
, bus_sce_cat_code -- 业务场景分类编码
, bus_sce_cat_name -- 业务场景分类描述
)

WITH nf_map_1  AS 
(
  SELECT  batch_id AS xh --  处理优先级
        , logic_name AS lj --  逻辑处理
        , b.cod_azienda AS vkorg --  公司包含
        , c.cod_azienda AS ctp
        , cust_code AS kunrg --  客商包含
        , cust_ex_code AS kunrg_out
        , sold_to_code AS sold_to --  售达方包含
        , sold_to_ex_code AS sold_to_out
        , product_line_src_code AS org_prctr_before --  处理前利润中心
        , onoffline_src_code AS nf_before
        , onoffline_code AS nf
        , onoffline_name AS nf_name
   FROM dim.dim_rule_fi_mr_nf_mapping a 
   LEFT JOIN ods.odsfima_azienda b
     ON b.cod_azienda LIKE a.company_code
  LEFT JOIN ods.odsfima_azienda c
     ON c.cod_azienda LIKE a.cp_company_code
  WHERE valid_fr <= @year_month_day
    AND IFNULL(valid_to,'999999') >= date_format(CAST(@year_month_day AS DATE), '%Y%m') 
 )
 
SELECT  bseg.gjahr AS year
      , bkpf.monat AS month
      , bseg.bukrs AS company_code
      /*ADD SXX XSJ 20260320中国区特殊逻辑（优先级最高）
    一。当公司=1180或12%时：
    1.通过物料编码【material_code 】+业务范围【bus_range_code】关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=1的渠道分组编码【onoffline_code】
    2.通过物料编码【material_code】关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=2的渠道分组编码【onoffline_code】
    3.通过事务类型【VORGN】+业务范围【bus_range_code】关联关联收入&成本模块-中国区渠道分组映射表，取映射表中规则层级【lever_flag】=3的渠道分组编码【onoffline_code】
    通过以上逻辑没匹配上的，再按以下逻辑取值：
    NVL(form_dati_nf1.onoffline_code,'020_OFF_002')*/
      , CASE WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_code
             WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_code
       WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_code
             ELSE COALESCE(form_dati_nf5.nf,form_dati_nf2.nf,form_dati_nf1.nf,'020_OFF_002') 
      END AS onoffline_code
      , CASE WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map1.onoffline_code IS NOT NULL THEN cn_onoffline_map1.onoffline_name
             WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map2.onoffline_code IS NOT NULL THEN cn_onoffline_map2.onoffline_name
       WHEN (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%') AND cn_onoffline_map3.onoffline_code IS NOT NULL THEN cn_onoffline_map3.onoffline_name
             ELSE COALESCE(form_dati_nf5.nf_name,form_dati_nf2.nf_name,form_dati_nf1.nf_name,'零售-传统零售') 
     END AS onoffline_name
      , '' AS product_line_code
      , bseg.pswsl AS qcy_code
      , CASE WHEN bseg.shkzg = 'S' THEN bseg.dmbtr ELSE -1*bseg.dmbtr END AS cogs_amt
      , 'S810' AS system_src
      , 'BSEG' AS ods_src
      , bseg.belnr AS bill_cert_id
      , bseg.hkont AS acct_src_code
      , acc_map.acct_map_code AS acct_map_code
      , bkpf.glvor AS order_type_code
      , NOW() AS load_dt
      , CONCAT(bseg.gjahr,bkpf.monat) AS dt_month

      , CASE WHEN bseg.hkont IN ('5301030301','5301030310') THEN '' ELSE TRIM(bseg.matnr) END AS material_code
      , mara.product_name AS material_name
    
      , CASE WHEN bseg.hkont IN ('5301030301','5301030310') 
              THEN CASE WHEN mara1.zcpdl = 'HEH-RG' THEN '101185000'
                        WHEN mara1.zcpdl IN ('RF','FF','WM','RAC') THEN '101101000'
                        ELSE ''
                    END 
             WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             WHEN TRIM(bseg.prctr) = '6375000001' THEN '101101000'
             WHEN TRIM(bseg.prctr) = '6375000002' THEN '101185000'
             ELSE TRIM(bseg.prctr)
        END AS profitcenter_code
      , '' AS profitcenter_name
      , COALESCE(if(upper(mara.sale_model_name)='无',null,upper(mara.sale_model_name)),if(upper(mara.zcusmodel)='无',null,upper(mara.zcusmodel))) AS customer_model
      , mara.zcalasset AS zcalasset                      
      , REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') AS material_group_name
      , '3001' AS bus_range_code
      , '' AS bus_range_name
      , CASE WHEN (SUBSTR(bseg.bukrs, 1, 2) IN ('62', '68') OR bseg.bukrs IN ('6012', '6015') 
                  OR ((SUBSTR(bseg.bukrs, 1, 2) = '12' OR SUBSTR(bseg.bukrs, 1, 4) IN ('1180','1183')) AND (mara.big_class_code = 'P02'OR NVL(TRIM(CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
                                                                                                                                                        ELSE TRIM(bseg.matnr)
                                                                                                                                                      END),'') = ''))
                  )
           THEN COALESCE(Mapping_Bus1.marketing_dept_code,Mapping_Bus2.marketing_dept_code,
                         profit_mapping0.marketing_dept_code,
                         profit_mapping1.marketing_dept_code,
                         CASE WHEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') IN ('1209901','1209905','G209901') 
                         AND  CASE 
                                  WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
                                  WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
                                  WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
                                  WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
                                  WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
                                  ELSE '2000'
                              END NOT IN ('2358','A004','2357')
                         THEN '1209901' ELSE NULL END,
                         profit_mapping2.marketing_dept_code,
                         profit_mapping3.marketing_dept_code,
                         profit_mapping4.marketing_dept_code,
                         REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                         )
          ELSE '' 
     END AS marketing_dept_code
     /*20260128 新增使用物料带出的相关信息字段*/
    , REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') AS material_group_code -- 物料组
    , COALESCE(IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
            ) AS sale_model_code -- 销售型号编码
    /*alter by 20260811 xiaoyachao.ex 销售型号名称逻辑更新*/
   ,COALESCE(IF(TRIM(mara.sale_model_name)= '',NULL,TRIM(mara.sale_model_name))
              ,IF(TRIM(mara.zzprdmodel)= '',NULL,TRIM(mara.zzprdmodel))
              ,IF(TRIM(mara.zfacmodel)= '',NULL,TRIM(mara.zfacmodel))
              ,IF(TRIM(mara.pmodel_number)= '',NULL,TRIM(mara.pmodel_number))
              ) AS sale_model_name
    , mara.prod_suite_code AS product_sale_series_code --  产品套系编码
    , mara.prod_suite_name AS product_sale_series_name --  产品套系名称
    , mara.prod_stage_code AS product_stage_code --  产品阶段编码
    , mara.prod_stage_name AS product_stage_name --  产品阶段名称
    , mara.price_range_code AS price_range_code --  价格段编码
    , mara.price_range_name AS price_range_name --  价格段名称
    , mara.model_code AS model_code --  产品型号编码
    , mara.model_name AS model_name --  产品型号名称
    , mara.series_code AS product_series_code --  产品系列编码
    , mara.series_name AS product_series_name --  产品系列名称
    , mara.market_pos_code AS market_pnt_code --  营销定位编码
    , mara.market_pos_name AS market_pnt_name --  营销定位名称
    , mara.ac_ct_code AS tech_type_code --  技术类型编码
    , mara.ac_ct_name AS tech_type_name --  技术类型名称
    , CASE WHEN mara.is_miniled_code  = 'PC00013001' THEN '是'
         WHEN mara.is_miniled_code  = 'PC00013002' THEN '否'
         ELSE ''
      END AS is_miniled_code --  是否MiniLED编码
    , mara.big_class_code AS product_big_class_code --  产品大类编码
    , mara.big_class_name AS product_big_class_name --  产品大类名称
    , mara.middle_class_code AS product_mid_class_code --  产品中类编码
    , mara.middle_class_name AS product_mid_class_name --  产品中类名称
    , mara.small_class_code AS product_small_class_code --  产品小类编码
    , mara.small_class_name AS product_small_class_name --  产品小类名称
    , mara.model_lca AS model_lca_code --  产品型号生命周期编码
    , mara.model_lca_name AS model_lca_name --  产品型号生命周期名称
    , mara.brand AS brand_code --  品牌编码
    , mara.brand_name AS brand_name --  品牌名称
    , CASE WHEN mara.big_class_code = 'P01' THEN mara.screen_size_code
          WHEN mara.big_class_code = 'P02' THEN mara.spec_range_code
          WHEN mara.big_class_code = 'P03' THEN mara.total_capacity_code
          WHEN mara.big_class_code = 'P04' THEN mara.washing_capacity_code
      END AS spec_section_code --  规格段编码
    , CASE WHEN mara.big_class_code = 'P01' THEN mara.screen_size_name
          WHEN mara.big_class_code = 'P02' THEN mara.spec_range_name
          WHEN mara.big_class_code = 'P03' THEN mara.total_capacity_name
          WHEN mara.big_class_code = 'P04' THEN mara.washing_capacity_name
      END  AS spec_section_name --  规格段名称
    , mara.product_spec_code AS product_shape_type_code --  产品形态分类编码
    , mara.product_spec_name AS product_shape_type_name --  产品形态分类名称
    , bseg.prctr AS src_profitcenter_code
    , bseg.gsber AS src_bus_range_code
    , bseg.vorgn as transaction_type --  事务类型
    , bseg.xref3 as cust_code --  客商编码
    , kna1.name1 AS cust_name --  客商名称
    , NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) AS cp_company_code --  对方公司
    , kna1.zkunnr_mdg AS cust_mdg_code --  客商编码-MDG
    , dim_customer_base_info_dd.cust_unity_name AS cust_unity_name
    , dim_customer_base_info_dd.credit_level AS credit_level_name
    , dim_customer_base_info_dd.unit_nature_name AS cust_nature_name
    , CASE WHEN dim_customer_base_info_dd.is_channel_cust_type IS NULL
            AND dim_customer_base_info_dd.is_ent_cust_type IS NULL
            AND dim_customer_base_info_dd.is_fi_cust_type IS NULL
            THEN NULL
            ELSE TRIM(
                  REGEXP_REPLACE(
                      CONCAT_WS(',',
                          CASE WHEN dim_customer_base_info_dd.is_channel_cust_type = 'Y' THEN '渠道客户(经营)' ELSE NULL END,
                          CASE WHEN dim_customer_base_info_dd.is_ent_cust_type = 'Y' THEN '企事业单位(消费)' ELSE NULL END,
                          CASE WHEN dim_customer_base_info_dd.is_fi_cust_type = 'Y' THEN '财务类客户' ELSE NULL END
                      ),
                      '(^,)|(,$)',  
                      ''            
                  )
              ) END AS cust_type_name
    , dim_customer_base_info_dd.com_1st_code AS channel_l1_code
    , dim_customer_base_info_dd.com_1st_name AS channel_l1_name
    , dim_customer_base_info_dd.com_2nd_code AS channel_l2_code
    , dim_customer_base_info_dd.com_2nd_name AS channel_l2_name
    , dim_customer_base_info_dd.com_3rd_code AS channel_l3_code
    , dim_customer_base_info_dd.com_3rd_name AS channel_l3_name
    , dim_customer_trade_info_dd.market_mode_code AS marketing_mode_code
    , dim_customer_trade_info_dd.market_mode_name AS marketing_mode_name
    , dim_customer_base_info_dd.channel_big_class_code AS channel_big_class_code
    , dim_customer_base_info_dd.channel_big_class_name AS channel_big_class_name
    , dim_customer_base_info_dd.channel_small_class_code AS channel_small_class_code
    , dim_customer_base_info_dd.channel_small_class_name AS channel_small_class_name
    , dim_customer_base_info_dd.ind_big_class_code AS ind_big_class_code
    , dim_customer_base_info_dd.ind_big_class_name AS ind_big_class_name
    , dim_customer_base_info_dd.ind_small_class_code AS ind_small_class_code
    , dim_customer_base_info_dd.ind_small_class_name AS ind_small_class_name

    /*20260520 新增miniled类型字段*/
    , mara.miniled_type_code
    , mara.miniled_type_name
    , null AS bus_sce_cat_code -- 业务场景分类编码
    , null AS bus_sce_cat_name -- 业务场景分类描述

  FROM (SELECT * 
          FROM ods.ods_slt_s810_bseg_v bseg_inner
         WHERE IFNULL(TRIM(aufnr),'') = ''
           AND hkont LIKE '5301%'
      AND bukrs = '6375'
        ) bseg
  INNER JOIN (SELECT * 
               FROM ods.ods_slt_s810_bkpf_v 
              WHERE gjahr = substr(@year_month_day,1,4)
                AND monat = substr(@year_month_day,5,2)
        AND bukrs = '6375'
             ) bkpf
    ON bseg.belnr = bkpf.belnr 
   AND bseg.gjahr = bkpf.gjahr 
   AND bseg.bukrs = bkpf.bukrs
 
  LEFT JOIN dim.dim_rule_fi_mr_cust2ctp_mapping cust2ctp --  经分项目收入模块规则映射表                                      
    ON LTRIM(bseg.xref3,0) = LTRIM(cust2ctp.cust_code,0)
   AND cust2ctp.cust_type_code = 'C'
   AND cust2ctp.system_src = 'S810'

  LEFT JOIN nf_map_1 form_dati_nf1--  匹配线上线下映射表 按公司匹配
     ON 1=1
    --  公司包含匹配
    AND bseg.bukrs = form_dati_nf1.vkorg
    AND form_dati_nf1.xh = '1'
   LEFT JOIN nf_map_1 form_dati_nf2--  匹配线上线下映射表 按公司+客商匹配
     ON 1=1
    --  公司包含匹配
    AND bseg.bukrs = form_dati_nf2.vkorg
    --  客商匹配
    AND LTRIM(bseg.xref3, '0') = form_dati_nf2.kunrg
    AND form_dati_nf2.xh = '2'

   LEFT JOIN nf_map_1 form_dati_nf5--  匹配线上线下映射表 按公司+对方公司匹配
     ON 1=1
    --  公司匹配
    AND bseg.bukrs = form_dati_nf5.vkorg
    --  对方公司匹配
    AND NVL(cust2ctp.cp_company_code_mr,cust2ctp.cp_company_code) LIKE form_dati_nf5.ctp
    AND form_dati_nf5.xh = '5'


  LEFT JOIN dim.dim_fi_mr_product_dd mara --  物料大表
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = mara.matnr

  LEFT JOIN ods.odss810_mara mara1 --  物料大表
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = mara1.matnr
  --  2026.1.6 yanghao 新增 取品牌编码及名称逻辑
  LEFT JOIN dw.dim_product_base_info_dd base -- 产品主数据基本信息
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = base.product_code
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_sap2pb_map a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
                AND sapversion = 'S810'
            ) AS sap2pb
    ON LTRIM(bseg.belnr,'0') = LTRIM(sap2pb.belnr,'0')
   AND bseg.bukrs = sap2pb.company_code
   AND LTRIM(bseg.buzei,'0') = LTRIM(sap2pb.buzei,'0')
  LEFT JOIN (SELECT * FROM dim.dim_rule_fi_mr_mt2bd_mapping a
              WHERE 1=1
                AND a.valid_fr <= LEFT(@year_month_day,6)
                AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
            ) AS mt2bd
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = mt2bd.material_code
  LEFT JOIN dim.dim_rule_fi_mr_BusScope_for_Company bus_range_map2
    ON bseg.bukrs = bus_range_map2.company_code
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus) Mapping_Bus
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = Mapping_Bus.MATERIAL_CODE
  LEFT JOIN dw.dim_product_base_info_dd
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = dim_product_base_info_dd.product_code
      /*通过物料匹配 优先级2*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus2
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = Mapping_Bus2.MATERIAL_CODE
    /*通过物料和业务范围匹配 优先级1*/
  LEFT JOIN (SELECT bus_range_code,material_code,marketing_dept_code FROM dim.dim_rule_fi_mr_airconditioner_materials_mapping_bus
            WHERE NULLIF(TRIM(material_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
            ) Mapping_Bus1
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = Mapping_Bus1.MATERIAL_CODE
   AND  CASE 
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = Mapping_Bus1.bus_range_code

  -- 新增业务管理单元取数逻辑
  LEFT JOIN (/*利润中心+业务范围  优先级0*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping0
    ON REGEXP_REPLACE(CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END, '^0+', '') = profit_mapping0.profitcenter_code
    AND CASE 
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = profit_mapping0.bus_range_code
  LEFT JOIN (/*物料组+业务范围  优先级1*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping1
    ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping1.material_group_code)
   AND CASE 
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END  = profit_mapping1.bus_range_code
  LEFT JOIN (/*物料组  优先级2*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NOT NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping2
   ON REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = TRIM(profit_mapping2.material_group_code)
  LEFT JOIN (/*利润中心  优先级3*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NULL AND NULLIF(TRIM(profitcenter_code),'') IS NOT NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping3
    ON REGEXP_REPLACE(CASE WHEN sap2pb.profitcenter_code IS NOT NULL THEN sap2pb.profitcenter_code
             WHEN mt2bd.profitcenter_code IS NOT NULL THEN mt2bd.profitcenter_code 
             WHEN mara.profitcenter_code IS NOT NULL THEN mara.profitcenter_code
             ELSE TRIM(bseg.prctr)
        END, '^0+', '') = profit_mapping3.profitcenter_code
  LEFT JOIN (/*业务范围  优先级4*/
               SELECT material_group_code,bus_range_code,profitcenter_code,marketing_dept_code 
                 FROM dim.dim_rule_fi_mr_ACMatnr_Bus_Profit_Mapping
                WHERE NULLIF(TRIM(material_group_code),'') IS NULL AND NULLIF(TRIM(bus_range_code),'') IS NOT NULL AND NULLIF(TRIM(profitcenter_code),'') IS NULL
            AND VALID_FR <= SUBSTR(@year_month_day,1,6) AND VALID_TO >= SUBSTR(@year_month_day,1,6)
    ) profit_mapping4
    ON CASE 
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = profit_mapping4.bus_range_code        
     -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=1，物料+业务范围匹配，优先级1）
  LEFT JOIN (
      SELECT material_code, bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '1'
  ) cn_onoffline_map1
   ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = cn_onoffline_map1.material_code
   AND CASE 
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = cn_onoffline_map1.bus_range_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=2，仅物料匹配，优先级2）
  LEFT JOIN (
      SELECT material_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '2'
  ) cn_onoffline_map2
    ON CASE WHEN bseg.bukrs LIKE '26%' AND bseg.hkont LIKE '6401%' AND bkpf.blart = 'RE' THEN NVL(TRIM(bseg.matnr),TRIM(bseg.zuonr))
           ELSE TRIM(bseg.matnr)
        END = cn_onoffline_map2.material_code
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')                     
  -- ADD SXX XSJ 20260323 中国区特殊逻辑：新增cn_onoffline_map映射表JOIN（lever_flag=3，事务类型+业务范围匹配，优先级3）
  LEFT JOIN (
      SELECT umsks,bus_range_code, onoffline_code, onoffline_name
        FROM dim.dim_rule_fi_mr_cn_onoffline_map
       WHERE lever_flag = '3'
  ) cn_onoffline_map3
    ON bseg.vorgn = cn_onoffline_map3.umsks--  事务类型
    AND CASE 
             WHEN bseg.bukrs = '6098' THEN '2000' --  2026.04.14 新增 业务范围取值逻辑：当公司为6098时，业务范围取固定值'2000'
             WHEN bseg.hkont LIKE '6609%' AND mara.bus_range_code IS NOT NULL THEN mara.bus_range_code
             WHEN sap2pb.bus_range_code IS NOT NULL THEN sap2pb.bus_range_code 
             WHEN TRIM(bseg.gsber) <> '' THEN TRIM(bseg.gsber)
             WHEN NVL(mara.ZZNXWX,mara.SALE_AREA) IN ('02','外销品') THEN '3000'
             ELSE '2000'
        END = cn_onoffline_map3.bus_range_code--  业务范围
   AND (bseg.bukrs IN ('1180','118A','118B','1181') OR bseg.bukrs LIKE '12%')     
 -- ADD ZZS XSJ 20260330ZZS修改：新增客商编码，名称，对方公司取值逻辑
LEFT JOIN ods.ods_slt_s810_kna1 kna1 --  客户主数据
  ON LTRIM(bseg.xref3,0) = LTRIM(kna1.kunnr,0)
LEFT JOIN dw.dim_customer_base_info_dd --  匹配客商主数据
  ON kna1.zkunnr_mdg = dim_customer_base_info_dd.cust_code
LEFT JOIN (SELECT DISTINCT cust_code,sale_org,material_group_code,market_mode_code,market_mode_name FROM dw.dim_customer_trade_info_dd) dim_customer_trade_info_dd
  ON kna1.zkunnr_mdg = dim_customer_trade_info_dd.cust_code
 AND bseg.bukrs = dim_customer_trade_info_dd.sale_org
 AND REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','') = dim_customer_trade_info_dd.material_group_code
 
 LEFT JOIN(
              SELECT distinct acct_src_code,acct_map_code 
              FROM dim.dim_rule_fi_mr_acct_mapping a
                          WHERE 1=1
                            AND a.valid_fr <= LEFT(@year_month_day,6)
                            AND NVL(a.valid_to,'999999') >= LEFT(@year_month_day,6)
                            AND system_src = 'S810'
              ) acc_map
       ON acc_map.acct_src_code = bseg.hkont
 ;
 
 /******SAP810 BSEG成本数据限制科目 插入结束******/