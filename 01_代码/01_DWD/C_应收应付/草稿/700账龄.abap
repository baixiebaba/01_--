
*&---------------------------------------------------------------------*
*& Report  ZAGING_TABLE_KUNNR_LIFNR
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

REPORT zaging_table_kunnr_lifnr.

TABLES:sscrfields,bsis,bsik,bsid,skb1,t001."zath_check.
TYPE-POOLS:icon.
DATA: functxt TYPE smp_dyntxt.

TYPE-POOLS: sscr,slis.

DATA: fldct TYPE slis_t_fieldcat_alv,
      slayt TYPE slis_layout_alv,
      varnt LIKE disvariant,
      repid LIKE sy-repid,
      tabix LIKE sy-tabix.

DATA:g_koart LIKE ztzt_003-koart.

DATA:BEGIN OF gt_bskd OCCURS 0,
      koart LIKE ztzt_003-koart,
      bukrs LIKE bsik-bukrs,
      lifnr LIKE bsik-lifnr,
      kunnr LIKE bsid-kunnr,
      umsks LIKE bsik-umsks,
      umskz LIKE bsik-umskz,
      augdt LIKE bsik-augdt,
      augbl LIKE bsik-augbl,
      zuonr LIKE bsik-zuonr,
      gjahr LIKE bsik-gjahr,
      belnr LIKE bsik-belnr,
      buzei LIKE bsik-buzei,
      prctr LIKE bsik-prctr,
      gsber LIKE bsik-gsber,
      hkont LIKE bsik-hkont,
      bldat LIKE bsik-bldat,
      zfbdt LIKE bsik-zfbdt,
      dmbtr LIKE bsik-dmbtr,"本位币金额
      waers LIKE bsik-waers,"交易币币种
      wrbtr LIKE bsik-wrbtr,"交易币金额
      shkzg LIKE bsik-shkzg,

***&&& CHANGGE BY WANGYL 20241223 START{
      filkd LIKE bsik-filkd, "分支机构
      zname1 LIKE kna1-name1, "分支机构名称
***&&& CHANGGE BY WANGYL 20241223 END}
      hwaer LIKE t001-waers, "本位币币种
      tabnam TYPE char10,
      blart LIKE bsik-blart,
  END OF gt_bskd.

DATA:itab LIKE STANDARD TABLE OF zzt003_save WITH HEADER LINE.
DATA:itab_all LIKE STANDARD TABLE OF itab WITH HEADER LINE.

DATA:BEGIN OF gt_bukrs OCCURS 0,
       bukrs LIKE t001-bukrs,
     END OF gt_bukrs.

SELECTION-SCREEN BEGIN OF BLOCK blk1 WITH FRAME TITLE t01.
SELECT-OPTIONS:s_bukrs FOR bsik-bukrs OBLIGATORY MEMORY ID buk,
               s_kunnr FOR bsid-kunnr MODIF ID d,
               s_lifnr FOR bsik-lifnr MODIF ID k,
               s_prctr FOR bsid-prctr,
               s_gsber FOR bsid-gsber.
PARAMETERS:p_keydat LIKE sy-datum OBLIGATORY .
SELECTION-SCREEN END OF BLOCK blk1.
SELECTION-SCREEN BEGIN OF BLOCK blk2 WITH FRAME TITLE t02.
SELECTION-SCREEN : BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(10) FOR FIELD p1.
PARAMETERS p1(4) TYPE n DEFAULT 30.
SELECTION-SCREEN : END OF LINE.
SELECTION-SCREEN : BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(10) FOR FIELD p2.
PARAMETERS p2(4) TYPE n DEFAULT 90.
SELECTION-SCREEN : END OF LINE.
SELECTION-SCREEN : BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(10) FOR FIELD p3.
PARAMETERS p3(4) TYPE n DEFAULT 180.
SELECTION-SCREEN : END OF LINE.
SELECTION-SCREEN : BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(10) FOR FIELD p4.
PARAMETERS p4(4) TYPE n DEFAULT 365.
SELECTION-SCREEN : END OF LINE.
SELECTION-SCREEN : BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(10) FOR FIELD p5.
PARAMETERS p5(4) TYPE n DEFAULT 730.
SELECTION-SCREEN : END OF LINE.
SELECTION-SCREEN : BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(10) FOR FIELD p6.
PARAMETERS p6(4) TYPE n DEFAULT 1095.
SELECTION-SCREEN : END OF LINE.
SELECTION-SCREEN : BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(10) FOR FIELD p7.
PARAMETERS p7(4) TYPE n DEFAULT 1460.
SELECTION-SCREEN : END OF LINE.
SELECTION-SCREEN : BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(10) FOR FIELD p8.
PARAMETERS p8(4) TYPE n DEFAULT 1825.
SELECTION-SCREEN : END OF LINE.
SELECTION-SCREEN END OF BLOCK blk2.
SELECTION-SCREEN BEGIN OF BLOCK blk3 WITH FRAME TITLE t03.
PARAMETERS:p_ys RADIOBUTTON GROUP grp3 DEFAULT 'X' USER-COMMAND y,
           p_yf RADIOBUTTON GROUP grp3.
SELECTION-SCREEN END OF BLOCK blk3.
SELECTION-SCREEN BEGIN OF BLOCK blk4 WITH FRAME TITLE t04.
PARAMETERS:p_pzrq RADIOBUTTON GROUP grp4 DEFAULT 'X',
           p_jzrq RADIOBUTTON GROUP grp4.
SELECTION-SCREEN END OF BLOCK blk4.
SELECTION-SCREEN BEGIN OF BLOCK blk5 WITH FRAME TITLE t05.
PARAMETERS:p_save AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK blk5.

SELECTION-SCREEN FUNCTION KEY 1.

INITIALIZATION.
  PERFORM initial_screen.

AT SELECTION-SCREEN . "PAI
  CASE sscrfields-ucomm.
    WHEN 'FC01'.
      PERFORM sm30 USING 'ZTZT_003'.
  ENDCASE.

AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    CASE 'X'.
      WHEN p_ys.
        IF screen-group1 CA 'K'.
          screen-active = 0.
        ENDIF.
      WHEN p_yf.
        IF screen-group1 CA 'D'.
          screen-active = 0.
        ENDIF.
    ENDCASE.
    MODIFY SCREEN.
  ENDLOOP.

START-OF-SELECTION.

  SELECT bukrs INTO TABLE gt_bukrs
    FROM t001
    WHERE bukrs IN s_bukrs.

  LOOP AT gt_bukrs.
    PERFORM get_data.
    PERFORM pro_data.
    PERFORM get_disc.
    PERFORM save_check USING p_save.

    APPEND LINES OF itab TO itab_all.
    FREE:itab.
  ENDLOOP.

  IF p_save = 'X' AND sy-batch = 'X'.
  ELSE.
    PERFORM show_alv.
  ENDIF.
*&---------------------------------------------------------------------*
*&      Form  SM30
*&---------------------------------------------------------------------*

FORM sm30  USING    value(p_viewname).

  CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
    EXPORTING
      action                       = 'S'
      corr_number                  = ''
      view_name                    = p_viewname
*    TABLES
*      dba_sellist                  = act_sellist
    EXCEPTIONS
      client_reference             = 01
      foreign_lock                 = 02
      invalid_action               = 03
      no_clientindependent_auth    = 04
      no_database_function         = 05
      no_editor_function           = 06
      no_show_auth                 = 07
      no_tvdir_entry               = 08
      no_upd_auth                  = 09
      only_show_allowed            = 10
      system_failure               = 11
      unknown_field_in_dba_sellist = 12
      view_not_found               = 13.

ENDFORM.                                                    " SM30
*&---------------------------------------------------------------------*
*&      Form  INITIAL_SCREEN
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM initial_screen .
  t01 = '条件'.
  t02 = '账龄'.
  t03 = '选择功能'.
  t04 = '选择参数'.
  t05 = '存表参数'.

  %_s_bukrs_%_app_%-text = '公司代码'.
  %_s_kunnr_%_app_%-text = '客户'.
  %_s_lifnr_%_app_%-text = '供应商'.
  %_s_prctr_%_app_%-text = '利润中心'.
  %_s_gsber_%_app_%-text = '业务范围'.
  %_p_keydat_%_app_%-text = '关键日期'.

  %_p_ys_%_app_%-text = '应收账龄'.
  %_p_yf_%_app_%-text = '应付账龄'.

  %_p_pzrq_%_app_%-text = '根据凭证日期计算账龄'.
  %_p_jzrq_%_app_%-text = '根据基准日期计算账龄'.

  %_p_save_%_app_%-text = '按照公司存储数据到 ZZT003_SAVE'.

  functxt-icon_id   = icon_wri.
  functxt-quickinfo = '科目维护'.
  functxt-icon_text = '科目维护'.
  sscrfields-functxt_01 = functxt.

  CALL FUNCTION 'LAST_DAY_OF_MONTHS'
    EXPORTING
      day_in            = sy-datum
    IMPORTING
      last_day_of_month = p_keydat
    EXCEPTIONS
      day_in_no_date    = 1
      OTHERS            = 2.
ENDFORM.                    " INITIAL_SCREEN
*&---------------------------------------------------------------------*
*&      Form  GET_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM get_data .
  DATA:lt_003 LIKE STANDARD TABLE OF ztzt_003 WITH HEADER LINE.

  DATA:tabnam TYPE char20.
  DATA:whrstr TYPE string,
       whrstra TYPE string.
  DATA:lt_bsis LIKE STANDARD TABLE OF gt_bskd WITH HEADER LINE.

  DATA:r_hkonk LIKE RANGE OF ztzt_003-hkont WITH HEADER LINE,"统驭科目
       r_hkond LIKE RANGE OF ztzt_003-hkont WITH HEADER LINE,"统驭科目
       r_hkons LIKE RANGE OF ztzt_003-hkont WITH HEADER LINE."非统驭科目

  SELECT * INTO CORRESPONDING FIELDS OF TABLE lt_003
    FROM ztzt_003
    INNER JOIN t001 ON t001~ktopl = ztzt_003~ktopl
    WHERE t001~bukrs = gt_bukrs-bukrs.

  LOOP AT lt_003.
**判断是否统驭科目，配置表中，同一行不能统驭科目、非统驭科目并存，要拆开
    r_hkonk = r_hkond = r_hkons ='IEQ'.

    SELECT * FROM skb1
      WHERE bukrs = gt_bukrs-bukrs AND
            saknr BETWEEN lt_003-hkonf AND lt_003-hkont.
      IF skb1-mitkz = 'K'.
        r_hkonk-low = skb1-saknr.
        APPEND r_hkonk.
      ELSEIF skb1-mitkz = 'D'.
        r_hkond-low = skb1-saknr.
        APPEND r_hkond.
      ELSEIF skb1-mitkz = ''.
*配置表S类代表应收总账，D类代表应收统驭，K类代表应付总账和应付统驭
        IF lt_003-koart = 'K' AND p_yf = 'X' OR
           lt_003-koart = 'D' AND p_ys = 'X'.
          r_hkons-low = skb1-saknr.
          APPEND r_hkons.
        ENDIF.
      ENDIF.
    ENDSELECT..
  ENDLOOP.

  IF p_ys = 'X'.
    tabnam = 'BSID'.
    whrstr = 'kunnr in s_kunnr and hkont in r_hkond'.
    g_koart = 'D'.
  ELSEIF p_yf = 'X'.
    tabnam = 'BSIK'.
    whrstr = 'lifnr in s_lifnr and hkont in r_hkonk'.
    g_koart = 'K'.
  ENDIF.

*取数范围未清和已经都要求凭证日期和过账日期小于等于关键日期，
*已清凭证另外还要求清账日期大于关键日期

*  IF p_pzrq = 'X'."凭证日期
*    CONCATENATE whrstr ` and bldat <= p_keydat ` INTO whrstr.
*  ELSEIF p_jzrq = 'X'.
*    CONCATENATE whrstr ` and zfbdt <= p_keydat ` INTO whrstr.
*  ENDIF.

  SELECT *
    APPENDING CORRESPONDING FIELDS OF TABLE gt_bskd
    FROM (tabnam)
    WHERE bukrs = gt_bukrs-bukrs AND
          prctr IN s_prctr AND
          gsber IN s_gsber AND
          budat <= p_keydat AND
*          blart <> 'DA' AND "凭证类型为DA的排除掉
         (whrstr).

  tabnam+2(1) = 'A'.
  CONCATENATE whrstr ` and augdt > p_keydat ` INTO whrstr.
  SELECT *
    APPENDING CORRESPONDING FIELDS OF TABLE gt_bskd
    FROM (tabnam)
    WHERE bukrs = gt_bukrs-bukrs AND
          prctr IN s_prctr AND
          gsber IN s_gsber AND
          budat <= p_keydat AND
*          blart <> 'DA' AND "凭证类型为DA的排除掉
         (whrstr).

****非统驭科目数据****
  IF r_hkons[] IS NOT INITIAL.
*    IF p_pzrq = 'X'."凭证日期
*      whrstr = 'bldat <= p_keydat'.
*    ELSEIF p_jzrq = 'X'.
*      whrstr = 'zfbdt <= p_keydat'.
*    ENDIF.
    CLEAR:whrstr.

    SELECT *
      APPENDING CORRESPONDING FIELDS OF TABLE lt_bsis
      FROM bsis
      WHERE bukrs = gt_bukrs-bukrs AND
            prctr IN s_prctr AND
            gsber IN s_gsber AND
            hkont IN r_hkons AND
            budat <= p_keydat AND
            (whrstr).

    CONCATENATE whrstr ` augdt > p_keydat ` INTO whrstr.

    SELECT *
      APPENDING CORRESPONDING FIELDS OF TABLE lt_bsis
      FROM bsas
      WHERE bukrs = gt_bukrs-bukrs AND
            prctr IN s_prctr AND
            gsber IN s_gsber AND
            hkont IN r_hkons AND
            budat <= p_keydat AND
            (whrstr).

    LOOP AT lt_bsis.
      lt_bsis-tabnam = 'BSIS'.
      APPEND lt_bsis TO gt_bskd.
    ENDLOOP.
  ENDIF.

ENDFORM.                    " GET_DATA
*&---------------------------------------------------------------------*
*&      Form  PRO_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM pro_data .

  DATA:lv_object TYPE char10.

  DATA:lv_datum TYPE bsik-bldat.
  DATA:lv_difdat TYPE numc4.

***&&& CHANGGE BY WANGYL 20241223 START{
  TYPES: BEGIN OF ty_kna1,
    kunnr TYPE kna1-kunnr,
    name1 TYPE kna1-name1,
    END OF ty_kna1.
  DATA: lt_kna1 TYPE TABLE OF ty_kna1,
        ls_kna1 TYPE ty_kna1.

  SELECT kunnr
         name1
    FROM kna1
    INTO TABLE lt_kna1
    FOR ALL ENTRIES IN gt_bskd
    WHERE kunnr = gt_bskd-filkd.
  SORT lt_kna1 BY kunnr.
***&&& CHANGGE BY WANGYL 20241223 END}

  SELECT SINGLE * FROM t001 WHERE bukrs = gt_bukrs-bukrs.

  LOOP AT gt_bskd.
    IF gt_bskd-lifnr IS NOT INITIAL.
      lv_object = gt_bskd-lifnr.
    ELSEIF gt_bskd-kunnr IS NOT INITIAL.
      lv_object = gt_bskd-kunnr.
    ELSE.
      lv_object = gt_bskd-hkont.
    ENDIF.

    IF p_pzrq = 'X'.
      lv_datum = gt_bskd-bldat.
    ELSE.
      lv_datum = gt_bskd-zfbdt.
    ENDIF.

    IF gt_bskd-blart = 'AB'. "AB类凭证基于基准日期计算账龄，其他凭证基选
      lv_datum = gt_bskd-zfbdt.
    ENDIF.

    IF gt_bskd-tabnam = 'BSIS'."总账科目 不计算账龄
      lv_datum = p_keydat.
    ENDIF.

    lv_difdat = p_keydat - lv_datum + 1.

    PERFORM currency_conv_to_external USING t001-waers
                                      CHANGING gt_bskd-dmbtr.
    PERFORM currency_conv_to_external USING gt_bskd-waers
                                      CHANGING gt_bskd-wrbtr.

*    IF p_yf = 'X' AND gt_bskd-shkzg = 'S' OR
*       p_ys = 'X' AND gt_bskd-shkzg = 'H'.
    IF gt_bskd-shkzg = 'H'. "所有贷方金额取负数
      gt_bskd-dmbtr = 0 - gt_bskd-dmbtr.
      gt_bskd-wrbtr = 0 - gt_bskd-wrbtr.
    ENDIF.

    CLEAR:itab.
    READ TABLE itab WITH KEY bukrs = gt_bskd-bukrs
                             koart = g_koart
                             object = lv_object
                             prctr = gt_bskd-prctr
                             gsber = gt_bskd-gsber
                             hkont = gt_bskd-hkont
                             waers = gt_bskd-waers
                             filkd = gt_bskd-filkd.
                             "BINARY SEARCH.
    IF sy-subrc <> 0.
      itab-bukrs = gt_bskd-bukrs.
      itab-koart = g_koart.
      itab-object = lv_object.
      itab-prctr = gt_bskd-prctr.
      itab-gsber = gt_bskd-gsber.
      itab-hkont = gt_bskd-hkont.
      itab-waers = gt_bskd-waers.
***&&& CHANGGE BY WANGYL 20241223 START{
      itab-filkd = gt_bskd-filkd.
      READ TABLE lt_kna1 INTO ls_kna1 WITH KEY kunnr = gt_bskd-filkd BINARY SEARCH.
      IF sy-subrc = 0.
        itab-zname1 = ls_kna1-name1.
      ENDIF.
***&&& CHANGGE BY WANGYL 20241223 END}
      itab-dmbtr0 = itab-dmbtr0 + gt_bskd-dmbtr.
      itab-wrbtr0 = itab-wrbtr0 + gt_bskd-wrbtr.

      PERFORM assign_field USING lv_difdat.

      INSERT itab INDEX sy-tabix.
    ELSE.
      itab-dmbtr0 = itab-dmbtr0 + gt_bskd-dmbtr.
      itab-wrbtr0 = itab-wrbtr0 + gt_bskd-wrbtr.

      PERFORM assign_field USING lv_difdat.

      MODIFY itab INDEX sy-tabix.
    ENDIF.
  ENDLOOP.

  FREE:gt_bskd.
ENDFORM.                    " PRO_DATA
*&---------------------------------------------------------------------*
*&      Form  ASSIGN_FIELD
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LV_DIFDAT  text
*----------------------------------------------------------------------*
FORM assign_field  USING  lv_difdat.
  IF lv_difdat <= p1.
    itab-dmbtr1 = itab-dmbtr1 + gt_bskd-dmbtr.
    itab-wrbtr1 = itab-wrbtr1 + gt_bskd-wrbtr.
  ELSEIF lv_difdat > p1 AND lv_difdat <= p2.
    itab-dmbtr2 = itab-dmbtr2 + gt_bskd-dmbtr.
    itab-wrbtr2 = itab-wrbtr2 + gt_bskd-wrbtr.
  ELSEIF lv_difdat > p2 AND lv_difdat <= p3.
    itab-dmbtr3 = itab-dmbtr3 + gt_bskd-dmbtr.
    itab-wrbtr3 = itab-wrbtr3 + gt_bskd-wrbtr.
  ELSEIF lv_difdat > p3 AND lv_difdat <= p4.
    itab-dmbtr4 = itab-dmbtr4 + gt_bskd-dmbtr.
    itab-wrbtr4 = itab-wrbtr4 + gt_bskd-wrbtr.
  ELSEIF lv_difdat > p4 AND lv_difdat <= p5.
    itab-dmbtr5 = itab-dmbtr5 + gt_bskd-dmbtr.
    itab-wrbtr5 = itab-wrbtr5 + gt_bskd-wrbtr.
  ELSEIF lv_difdat > p5 AND lv_difdat <= p6.
    itab-dmbtr6 = itab-dmbtr6 + gt_bskd-dmbtr.
    itab-wrbtr6 = itab-wrbtr6 + gt_bskd-wrbtr.
  ELSEIF lv_difdat > p6 AND lv_difdat <= p7.
    itab-dmbtr7 = itab-dmbtr7 + gt_bskd-dmbtr.
    itab-wrbtr7 = itab-wrbtr7 + gt_bskd-wrbtr.
  ELSEIF lv_difdat > p7 AND lv_difdat <= p8.
    itab-dmbtr8 = itab-dmbtr8 + gt_bskd-dmbtr.
    itab-wrbtr8 = itab-wrbtr8 + gt_bskd-wrbtr.
  ELSE.
    itab-dmbtr9 = itab-dmbtr9 + gt_bskd-dmbtr.
    itab-wrbtr9 = itab-wrbtr9 + gt_bskd-wrbtr.
  ENDIF.
ENDFORM.                    " ASSIGN_FIELD
*&---------------------------------------------------------------------*
*&      Form  GET_DISC
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM get_disc .
  DATA:lt_key LIKE STANDARD TABLE OF itab WITH HEADER LINE.
  DATA:BEGIN OF lt_lknam OCCURS 0,
         lknum TYPE lfa1-lifnr,
         name1 TYPE lfa1-name1,
       END OF lt_lknam.
  DATA:lt_skat LIKE STANDARD TABLE OF skat WITH HEADER LINE.

  lt_key[] = itab[].

  SORT lt_key BY object.

  DELETE ADJACENT DUPLICATES FROM lt_key COMPARING object.

  CHECK lt_key[] IS NOT INITIAL.

  IF p_yf = 'X'.
    SELECT lifnr name1
      INTO TABLE lt_lknam
      FROM lfa1
      FOR ALL ENTRIES IN lt_key
      WHERE lifnr = lt_key-object.
  ELSE.
    SELECT kunnr name1
      INTO TABLE lt_lknam
      FROM kna1
      FOR ALL ENTRIES IN lt_key
      WHERE kunnr = lt_key-object.
  ENDIF.

  SELECT * INTO TABLE lt_skat
    FROM skat
    FOR ALL ENTRIES IN lt_key
    WHERE spras = sy-langu AND
          saknr = lt_key-object.

  DATA:lt_cepct LIKE STANDARD TABLE OF cepct WITH HEADER LINE.

  SELECT * INTO TABLE lt_cepct
    FROM cepct
    WHERE spras = sy-langu
    ORDER BY prctr.

  LOOP AT itab.
    READ TABLE lt_lknam WITH KEY lknum = itab-object BINARY SEARCH.
    IF sy-subrc = 0.
      itab-name1 = lt_lknam-name1.
    ELSE.
      READ TABLE lt_skat WITH KEY saknr = itab-object BINARY SEARCH.
      IF sy-subrc = 0.
        itab-name1 = lt_skat-txt50.
      ENDIF.
    ENDIF.

    READ TABLE lt_cepct WITH KEY prctr = itab-prctr BINARY SEARCH.
    IF sy-subrc = 0.
      itab-ktext = lt_cepct-ktext.
    ENDIF.
    itab-keydat = p_keydat.
    itab-hwaer = t001-waers.
    MODIFY itab.
  ENDLOOP.

ENDFORM.                    " GET_DISC
*&---------------------------------------------------------------------*
*&      Form  SHOW_ALV
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM show_alv .
  slayt-colwidth_optimize = 'X'. "  colwidth_optimize
  slayt-zebra             = 'X'.
*  SLAYT-BOX_FIELDNAME     = 'SELECT'.
  repid = sy-repid.
  varnt-report = sy-repid.
  varnt-handle = 1.

  DATA:lv_days TYPE numc4.
  DATA:lv_text TYPE char40.

  PERFORM catlg_set TABLES fldct
                    USING:'BUKRS' 'BSIK' 'BUKRS' '公司',
                          'KOART' 'BSIK' 'KOART' '科目类型',
                          'OBJECT' '' '' '客商编码',
                          'NAME1' 'LFA1' 'NAME1' '客商名称',
                          'PRCTR' 'BSIK' 'PRCTR' '利润中心',
                          'KTEXT' 'CEPCT' 'KTEXT' '利润中心描述',
                          'GSBER' 'BSIK' 'GSBER' '业务范围',
                          'HKONT' 'BSIK' 'HKONT' '会计科目',
                          'KEYDAT' '' '' '关键日期',
                          'HWAER' 'T001' 'WAERS' '本位币币种',
                          'WAERS' 'BSIK' 'WAERS' '交易币币种',
***&&& CHANGGE BY WANGYL 20241223 START{
                          'FILKD' 'BSIK' 'FILKD' '分支机构',
                          'ZNAME1' 'KNA1' 'NAME1' '分支机构名称'.
***&&& CHANGGE BY WANGYL 20241223 END}

  PERFORM catlg_set TABLES fldct USING  'DMBTR0' 'BSIK' 'DMBTR' '本位币金额合计'.
  lv_days = p1.
  PERFORM alpha_output CHANGING :lv_days.
  CONCATENATE '本位币账龄'  lv_days '天以内' INTO lv_text.
  PERFORM catlg_set TABLES fldct USING 'DMBTR1' 'BSIK' 'DMBTR' lv_text.

  PERFORM catlg_set_days USING '本位币' 'DMBTR2' 'BSIK' 'DMBTR' p1 p2.
  PERFORM catlg_set_days USING '本位币' 'DMBTR3' 'BSIK' 'DMBTR' p2 p3.
  PERFORM catlg_set_days USING '本位币' 'DMBTR4' 'BSIK' 'DMBTR' p3 p4.
  PERFORM catlg_set_days USING '本位币' 'DMBTR5' 'BSIK' 'DMBTR' p4 p5.
  PERFORM catlg_set_days USING '本位币' 'DMBTR6' 'BSIK' 'DMBTR' p5 p6.
  PERFORM catlg_set_days USING '本位币' 'DMBTR7' 'BSIK' 'DMBTR' p6 p7.
  PERFORM catlg_set_days USING '本位币' 'DMBTR8' 'BSIK' 'DMBTR' p7 p8.

  lv_days = p8.
  PERFORM alpha_output CHANGING :lv_days.
  CONCATENATE '本位币账龄' lv_days  '天以上' INTO lv_text.
  PERFORM catlg_set TABLES fldct USING 'DMBTR9' 'BSIK' 'DMBTR' lv_text.

  PERFORM catlg_set TABLES fldct USING  'WRBTR0' 'BSIK' 'WRBTR' '交易币金额合计'.
  lv_days = p1.
  PERFORM alpha_output CHANGING :lv_days.
  CONCATENATE '交易币账龄' lv_days  '天以内' INTO lv_text.

*{ -------------------------------------------202505 mod
*  PERFORM catlg_set TABLES fldct USING 'DMBTR1' 'BSIK' 'DMBTR' lv_text.
  PERFORM catlg_set TABLES fldct USING 'WRBTR1' 'BSIK' 'WRBTR' lv_text.
*} -------------------------------------------202505mod

  PERFORM catlg_set_days USING '交易币' 'WRBTR2' 'BSIK' 'WRBTR' p1 p2.
  PERFORM catlg_set_days USING '交易币' 'WRBTR3' 'BSIK' 'WRBTR' p2 p3.
  PERFORM catlg_set_days USING '交易币' 'WRBTR4' 'BSIK' 'WRBTR' p3 p4.
  PERFORM catlg_set_days USING '交易币' 'WRBTR5' 'BSIK' 'WRBTR' p4 p5.
  PERFORM catlg_set_days USING '交易币' 'WRBTR6' 'BSIK' 'WRBTR' p5 p6.
  PERFORM catlg_set_days USING '交易币' 'WRBTR7' 'BSIK' 'WRBTR' p6 p7.
  PERFORM catlg_set_days USING '交易币' 'WRBTR8' 'BSIK' 'WRBTR' p7 p8.

  lv_days = p8.
  PERFORM alpha_output CHANGING :lv_days.
  CONCATENATE '交易币账龄' lv_days '天以上' INTO lv_text.
  PERFORM catlg_set TABLES fldct USING 'WRBTR9' 'BSIK' 'WRBTR' lv_text.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
    EXPORTING
      i_callback_program       = repid
      it_fieldcat              = fldct[]
      i_save                   = 'A'
      is_variant               = varnt
      is_layout                = slayt
      i_callback_user_command  = 'USER_COMMAND'
      i_callback_pf_status_set = 'SET_STATUS'
    TABLES
      t_outtab                 = itab_all
    EXCEPTIONS
      program_error            = 1
      OTHERS                   = 2.
ENDFORM.                    " SHOW_ALV
*---------------------------------------------------------------------*
*       FORM frm_catlg_set                                            *
*---------------------------------------------------------------------*
FORM catlg_set TABLES fldcattab
               USING p_field p_reftab p_reffld p_text.
  DATA: ls_fldct TYPE slis_fieldcat_alv.

  ls_fldct-fieldname     =  p_field.
  ls_fldct-seltext_l     =  p_text.
  ls_fldct-ddictxt       =  'L'.
  ls_fldct-ref_fieldname =  p_reffld.
  ls_fldct-ref_tabname   =  p_reftab.

  CASE ls_fldct-fieldname.
    WHEN 'YXJSL' OR 'BZWCS' OR 'MENGE'.
      ls_fldct-qfieldname = 'MEINS'.
      ls_fldct-no_zero = 'X'.
*    WHEN 'DMBTR' .
*      ls_fldct-cfieldname = 'WAERB'.
*    WHEN 'WRBTR'.
*      ls_fldct-cfieldname = 'WAERS'.
*      ls_fldct-no_zero = 'X'.
    WHEN 'KUNNR' OR 'OBJECT'.
      ls_fldct-edit_mask = '==ALPHA'.
    WHEN 'MATNR' .
      ls_fldct-edit_mask = '==MATN1'.
      ls_fldct-intlen = 18.
    WHEN 'BSTME' OR 'MEINS' .
      ls_fldct-edit_mask = '==CUNIT'.
    WHEN OTHERS.
  ENDCASE.

  CASE ls_fldct-fieldname.
    WHEN 'EBELN' OR 'RTYPE' OR 'RTMSG' OR
         'MBLPO' OR 'FRGKE'.
      ls_fldct-emphasize = 'C110'.
    WHEN 'KUNNR'.
      ls_fldct-edit = 'X'.
  ENDCASE.

  APPEND ls_fldct TO fldcattab .
  CLEAR ls_fldct .
ENDFORM.                    "catlg_set

*&--------------------------------------------------------------------*
*&      Form  set_status
*&--------------------------------------------------------------------*
FORM set_status USING rt_extab TYPE slis_t_extab.
*  data: wa_extab type line of slis_t_extab.
  CLEAR rt_extab.
  REFRESH rt_extab.

  SET PF-STATUS 'STANDARD' EXCLUDING rt_extab .
ENDFORM.                    "set_status

*&--------------------------------------------------------------------*
*&      Form  user_command
*&--------------------------------------------------------------------*
FORM user_command USING r_ucomm LIKE sy-ucomm
                    rs_selfield TYPE slis_selfield.
  DATA: lr_grid TYPE REF TO cl_gui_alv_grid.
  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = lr_grid.

  CALL METHOD lr_grid->check_changed_data.

  CASE r_ucomm.
    WHEN '&IC1'. "双击
      CHECK rs_selfield-tabindex <> 0 . "小计行总计行什么的忽略
      READ TABLE itab INDEX rs_selfield-tabindex.
      CASE rs_selfield-fieldname.
        WHEN 'CKBOX'.

        WHEN OTHERS.
      ENDCASE.
*    WHEN 'MAPP'.
*      PERFORM MAPPING_KUNNR. "此部分功能在接口实现
    WHEN 'POST'.

  ENDCASE.
  rs_selfield-row_stable = 'X'.
  rs_selfield-col_stable = 'X'.
  rs_selfield-refresh    = 'X'.
ENDFORM.                    "user_command
*&---------------------------------------------------------------------*
*&      Form  ALPHA_OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_LV_DAYS1  text
*      <--P_LV_DAYS2  text
*----------------------------------------------------------------------*
FORM alpha_output  CHANGING p_days.
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
    EXPORTING
      input  = p_days
    IMPORTING
      output = p_days.
ENDFORM.                    " ALPHA_OUTPUT
*&---------------------------------------------------------------------*
*&      Form  CATLG_SET_DAYS
*&---------------------------------------------------------------------*
FORM catlg_set_days  USING    value(p_text1)
                              value(p_fldnam)
                              value(p_reftab)
                              value(p_reffld)
                              p_days1
                              p_days2.
  DATA:lv_text TYPE char40.
  DATA:lv_days1 TYPE numc4,
       lv_days2 TYPE numc4.

  lv_days1 = p_days1 + 1.
  lv_days2 = p_days2.
  PERFORM alpha_output CHANGING :lv_days1, lv_days2.
  CONCATENATE p_text1 '账龄从' lv_days1 '到' lv_days2  '天' INTO lv_text.

  PERFORM catlg_set TABLES fldct USING p_fldnam p_reftab p_reffld lv_text.

ENDFORM.                    " CATLG_SET_DAYS
*&---------------------------------------------------------------------*
*&      Form  SAVE_ZZT003
*&---------------------------------------------------------------------*
FORM save_zzt003 .
  DATA:lt_zzt003 LIKE STANDARD TABLE OF zzt003_save WITH HEADER LINE.
  DATA:lv_itmno LIKE zzt003_save-itmno.

  LOOP AT itab.
    lv_itmno = lv_itmno + 1.
    MOVE-CORRESPONDING itab TO lt_zzt003.
    lt_zzt003-itmno = lv_itmno.
    lt_zzt003-keydat = p_keydat.
    lt_zzt003-erdat = sy-datum.
    lt_zzt003-erzet = sy-uzeit.
    lt_zzt003-ernam = sy-uname.
    APPEND lt_zzt003.
  ENDLOOP.

  DELETE FROM zzt003_save WHERE bukrs = gt_bukrs-bukrs AND koart = g_koart AND keydat = p_keydat.

  INSERT zzt003_save FROM TABLE lt_zzt003.
  COMMIT WORK.

ENDFORM.                    " SAVE_ZZT003
*&---------------------------------------------------------------------*
*&      Form  SAVE_ZZT003
*&---------------------------------------------------------------------*
FORM currency_conv_to_external  USING    p_waers
                                CHANGING p_dmbtr.
  DATA: lv_amount LIKE bapicurr-bapicurr.
  CALL FUNCTION 'BAPI_CURRENCY_CONV_TO_EXTERNAL'
    EXPORTING
      currency        = p_waers
      amount_internal = p_dmbtr
    IMPORTING
      amount_external = lv_amount.
  p_dmbtr = lv_amount.
ENDFORM.                    "currency_conv_to_external
*&---------------------------------------------------------------------*
*&      Form  SAVE_CHECK
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_0512   text
*----------------------------------------------------------------------*
FORM save_check  USING    value(pv_save).
*  SELECT SINGLE * FROM zath_check
*    WHERE pname = sy-repid AND
*          uname = sy-uname.
*  IF sy-subrc = 0 AND pv_save = 'X'.
*    PERFORM save_zzt003.
*  ELSE.
*    MESSAGE '无ZCHECK事务代码配置的存表权限.' TYPE 'S' DISPLAY LIKE 'E'.
*  ENDIF.
  IF pv_save = 'X'.
    PERFORM save_zzt003.
  ENDIF.
ENDFORM.                    " SAVE_CHECK