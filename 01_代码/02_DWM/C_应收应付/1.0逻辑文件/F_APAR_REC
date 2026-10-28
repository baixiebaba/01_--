CREATE OR REPLACE FUNCTION TGK_GB_HISENSE.F_APAR_REC(P_YEARMONTH IN VARCHAR2,
                                          P_MANDT     IN VARCHAR2,
                                          P_BUKRS     IN VARCHAR2,
                                          P_HKONT     IN VARCHAR2,
                                          P_CVCODE    IN VARCHAR2,
                                          P_DMBTR     IN NUMBER,
                                          P_FLAG      IN VARCHAR2 )
                                          RETURN      VARCHAR2 AS
   V_RETURN VARCHAR2(4000);
/*
  修改时间：20241205 14:53

ALTER BY 20241205 XIAOYACHAO.EX 增加科目1123009000
ALTER BY 20240919 ZHUANGXINZHOU 停止  因香港海信记账特殊性，1006与1098  相互之间的 1221010000 | 其他应收款 不参与抵消  20240919 停止 20241005 恢复
ALTER BY 20240924 13:42 XIAOYACHAO.EX :三电公司1123%科目不重分类
ALTER BY 20240919 14:00 XIAOYACHAO.EX :2300公司2159761客商的应收不重分类到合同负债
ALTER BY 20240902 11:30 XIAOYACHAO.EX :9002不取SAP系统数
ALTER BY 20240823 XIAOYACHAO.EX ：增加2181%科目重分类逻辑 ;增加金投公司长期应收分类逻辑 ;20240815  : 增加金投公司重分类逻辑 ;20240807 增加长期应收款分类
ALTER BY 20240715 XIAOYACHAO.EX : 增加重分类到其他非流动性资产

T3.CUSVEN,T3.
P_FLAG 1 返回 是否重分类 2 返回 类型
CREATE  BY  ZHUANGXINZHOU  20220330
 往来账龄表重分类逻辑 用于往来账龄表抽数使用
A 应收            1122000000    AR
B 其他应收        122101F       OR
C 预付            1123000000    AS
D 应付            2202000000    AP
E 其他应付        224199F       OP
F 预收            2203000000    AC
I 合同资产        1460000000    CA
J 合同负债        2204000000    CL
K 应收款项融资    1124001000    RF
L 其他流动性资产  1910000A70    A9
M 长期应收款      1531000000    A10

*/

BEGIN
IF P_MANDT = '600' AND  P_BUKRS NOT LIKE '9008' THEN
  V_RETURN:=
 CASE /*特殊科目 设置*/
      WHEN P_BUKRS = '2300' AND P_HKONT LIKE  '1122%' AND LTRIM(P_CVCODE,'0') = '2159761'  /*2300公司特殊客户应收不重分类到合同负债 ALER BY 20240919 XIAOYACHAO.EX*/
         THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
      WHEN P_HKONT =  '1123010000'                                                    /* 600预付账款-长期资产重分类至 其他非流动性资产  ALTER BY 20240715 XIAOYACHAO.EX*/
        THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'A9' END)
      WHEN /*P_YEARMONTH<='202408'  AND*/  P_HKONT LIKE'1221010000' AND P_BUKRS IN ('1006','1098') AND LTRIM(P_CVCODE,'0')  IN('1001785','A01098') /* 20230206因香港海信记账特殊性，1006与1098  相互之间的 1221010000 | 其他应收款 不重分类  20240919 停止 20241005 恢复*/
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
      WHEN P_HKONT='1122000097'                                                   /* 应收账款  其中：汇兑损益不参与重分类*/
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
      WHEN P_HKONT LIKE '112309%'
         THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)                                      /*预付  其中：待摊费用不参与重分类 700 610 810 1123 全部不重分类*/
      WHEN (P_HKONT IN ('2202000087','2202000088','2202000099') OR P_HKONT IN( '2202000089') AND NOT (P_BUKRS IN ('1600','1650'))) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END)
      WHEN P_HKONT LIKE '224108%' OR P_HKONT = '2241000099'                     /*其他应付 负数 预提费用 汇兑损益 不重分类*/
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)
      WHEN P_HKONT LIKE '1531%'                                                   /* 增加长期应收款分类  ALTER BY XIAOAYCHAO.EX 20240807 */
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)
/*标准逻辑*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END) /* 应收账款  其中：汇兑损益不参与重分类*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)  /* 应收账款 负数 重分类到合同负债  */
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END) /* 其他应收账款 负数 重分类到其他应付款  */
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END) /*预付  其中：待摊费用不参与重分类*/
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AP' END)  /*预付  负数 ：重分类到应付*/
       WHEN P_HKONT LIKE  '1124%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END) /*应收款项融资 不重分类*/
       WHEN P_HKONT LIKE  '1460%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)  /*合同资产 不重分类*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END) /*合同结算  正数 合同资产*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)/*合同结算 负数 重分类 合同负债*/
       WHEN P_HKONT LIKE  '2204%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END) /*合同负债 不重分类*/
       WHEN P_HKONT LIKE  '2202%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
       WHEN P_HKONT LIKE  '2202%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AS' END)  /* 应付账款  正数 重分类 预付 */
       WHEN P_HKONT LIKE  '2203%'
         THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)  /*预付 不重分类*/
       WHEN P_HKONT LIKE  '2241%' AND P_DMBTR<=0
         THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END) /*其他应付 负数 预提费用 汇兑损益 不重分类*/
       WHEN P_HKONT LIKE  '2241%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OR' END) /*其他应付 正数 重分类 其他应收*/
       ELSE (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN '' END)
  END;
END IF;
IF P_MANDT='610' THEN /*610  全部不重分类*/
   V_RETURN:=
  CASE WHEN P_HKONT LIKE  '1122%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
       WHEN P_HKONT LIKE  '1221%' OR P_HKONT IN ('1411020101')
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
       WHEN P_HKONT LIKE  '1123%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
       WHEN P_HKONT LIKE  '1124%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END)
       WHEN P_HKONT LIKE  '1460%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)
       WHEN P_HKONT LIKE  '1466%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)
       WHEN P_HKONT LIKE  '2204%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END) /*合同负债 不重分类*/
       WHEN P_HKONT LIKE  '2202%' OR  P_HKONT IN ('2241020103','2241020118','2241020201')
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END) /* 应付账款*/
       WHEN P_HKONT LIKE  '2203029901'/*2203029901 预收帐款-集团外部-预收费用 重分类到合同负债 不扣税*/
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END)  /*预收 */
       WHEN P_HKONT LIKE  '2203%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)  /*预收 */
       WHEN P_HKONT LIKE  '2241%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END) /*其他应付 */
       WHEN P_HKONT LIKE '1411%'                                                          /* 增加长期应收款分类  ALTER BY XIAOAYCHAO.EX 20240807 */
            THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)
       ELSE (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN '' END)
  END;
END IF;
IF P_MANDT = '680' THEN
  V_RETURN:=
 CASE /*特殊科目 设置*/
      WHEN P_HKONT = '1123010000'                 /* 600,'680' 预付账款-长期资产重分类至 其他非流动性资产  ALTER BY 20240715 XIAOYACHAO.EX*/
        THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'A9' END)
      WHEN P_HKONT = '1122000097'                 /* 应收账款  其中：汇兑损益不参与重分类*/
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
      WHEN (P_HKONT IN ('2202000087','2202000088','2202000099') OR P_HKONT IN( '2202000089')  AND NOT (P_BUKRS IN ('1600','1650'))) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END)
      WHEN (P_HKONT LIKE '224108%' OR P_HKONT = '2241000099')   /*其他应付 负数 预提费用 汇兑损益 不重分类*/
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)

/*标准逻辑*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END) /* 应收账款  其中：汇兑损益不参与重分类*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)  /* 应收账款 负数 重分类到合同负债  */
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END) /* 其他应收账款 负数 重分类到其他应付款  */
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END) /*预付  其中：待摊费用不参与重分类*/
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AP' END)  /*预付  负数 ：重分类到应付*/
       WHEN P_HKONT LIKE  '1124%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END) /*应收款项融资 不重分类*/
       WHEN P_HKONT LIKE  '1460%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)  /*合同资产 不重分类*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END) /*合同结算  正数 合同资产*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)/*合同结算 负数 重分类 合同负债*/
       WHEN P_HKONT LIKE  '2204%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END) /*合同负债 不重分类*/
       WHEN P_HKONT LIKE  '2202%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
       WHEN P_HKONT LIKE  '2202%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AS' END)  /* 应付账款  正数 重分类 预付 */
       WHEN P_HKONT LIKE  '2203%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)  /*预付 不重分类*/
       WHEN P_HKONT LIKE  '2241%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END) /*其他应付 负数 预提费用 汇兑损益 不重分类*/
       WHEN P_HKONT LIKE  '2241%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OR' END) /*其他应付 正数 重分类 其他应收*/
       ELSE (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN '' END)
  END;
END IF;
IF P_MANDT = '700' THEN
  V_RETURN:=
 CASE /*特殊科目 设置*/
       WHEN P_HKONT = '1123030000'                   /* 700 预付账款-长期资产重分类至 其他非流动性资产  ALTER BY 20240715 XIAOYACHAO.EX*/
         THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'A9' END)
       WHEN P_HKONT = '1122099001'
         THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
       WHEN P_HKONT = '1122000097'                  /* 应收账款  其中：汇兑损益不参与重分类*/
         THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
       WHEN P_HKONT LIKE '1123%'                 /*预付  其中：待摊费用不参与重分类 700 610 810 1123 全部不重分类*/
         THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
       WHEN (P_HKONT IN ('2202000087','2202000088','2202000099','2202099001') OR P_HKONT IN( '2202000089')  AND NOT (P_BUKRS IN ('1600','1650'))) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
         THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END)
       WHEN (P_HKONT LIKE '224108%' OR P_HKONT = '2241000099')  /*其他应付 负数 预提费用 汇兑损益 不重分类*/
         THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)
       WHEN P_HKONT LIKE '1531%'                  /* 增加长期应收款分类  ALTER BY XIAOAYCHAO.EX 20240807 */
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)
/*标准逻辑*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END) /* 应收账款  其中：汇兑损益不参与重分类*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)  /* 应收账款 负数 重分类到合同负债  */
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END) /* 其他应收账款 负数 重分类到其他应付款  */
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END) /*预付  其中：待摊费用不参与重分类*/
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AP' END)  /*预付  负数 ：重分类到应付*/
       WHEN P_HKONT LIKE  '1124%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END) /*应收款项融资 不重分类*/
       WHEN P_HKONT LIKE  '1460%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)  /*合同资产 不重分类*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END) /*合同结算  正数 合同资产*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)/*合同结算 负数 重分类 合同负债*/
       WHEN P_HKONT LIKE  '2204%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END) /*合同负债 不重分类*/
       WHEN P_HKONT LIKE  '2202%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
       WHEN P_HKONT LIKE  '2202%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AS' END)  /* 应付账款  正数 重分类 预付 */
       WHEN P_HKONT LIKE  '2203%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)  /*预付 不重分类*/
       WHEN P_HKONT LIKE  '2241%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END) /*其他应付 负数 预提费用 汇兑损益 不重分类*/
       WHEN P_HKONT LIKE  '2241%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OR' END) /*其他应付 正数 重分类 其他应收*/
       ELSE (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN '' END)
  END;
END IF;
IF P_MANDT = '800B' THEN
  V_RETURN:=
 CASE /*特殊科目 设置*/
      WHEN P_HKONT IN ('1123004000')                               /* 800B 预付账款-长期资产重分类至 其他非流动性资产  ALTER BY 20240715 XIAOYACHAO.EX*/
        THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'A9' END)
      WHEN P_HKONT IN ('1123009000')  AND P_BUKRS = '4210'         /* ALTER BY XIAOYACHAO 20241205 增加科目1123009000 重分类至其他非流动性资产*/
        THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'A9' END)
      WHEN P_HKONT='1122000097'                 /* 应收账款  其中：汇兑损益不参与重分类*/
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
      WHEN P_HKONT='1122099999'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
      WHEN P_HKONT IN('1123009999','1123099999','1123003001')
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)      /*预付  其中：待摊费用不参与重分类 700 610 810 1123 全部不重分类*/
      WHEN (P_HKONT IN ('2202000087','2202000088','2202000099','2202099999') OR P_HKONT IN( '2202000089')  AND NOT (P_BUKRS IN ('1600','1650')))
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END)     /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
      WHEN (P_HKONT LIKE '224108%' OR P_HKONT IN ('2241000099','2241099001'))
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)          /*其他应付 负数 预提费用 汇兑损益 不重分类*/
      WHEN P_HKONT='2203099001'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)       /*2203099001（汇率重估）不参与重分类*/
      WHEN (P_HKONT LIKE '1531%' OR P_HKONT LIKE '1901%')
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)
/*标准逻辑*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END) /* 应收账款  其中：汇兑损益不参与重分类*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)  /* 应收账款 负数 重分类到合同负债  */
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END) /* 其他应收账款 负数 重分类到其他应付款  */
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END) /*预付  其中：待摊费用不参与重分类*/
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AP' END)  /*预付  负数 ：重分类到应付*/
       WHEN P_HKONT LIKE  '1124%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END) /*应收款项融资 不重分类*/
       WHEN P_HKONT LIKE  '1460%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)  /*合同资产 不重分类*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END) /*合同结算  正数 合同资产*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)/*合同结算 负数 重分类 合同负债*/
       WHEN P_HKONT LIKE  '2204%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END) /*合同负债 不重分类*/
       WHEN P_HKONT LIKE  '2202%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
       WHEN P_HKONT LIKE  '2202%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AS' END)  /* 应付账款  正数 重分类 预付 */
       WHEN P_HKONT LIKE  '2203%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)  /*预付 不重分类*/
       WHEN P_HKONT LIKE  '2241%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END) /*其他应付 负数 预提费用 汇兑损益 不重分类*/
       WHEN P_HKONT LIKE  '2241%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OR' END) /*其他应付 正数 重分类 其他应收*/
       ELSE (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN '' END)
  END;
END IF;
IF P_MANDT = '810' THEN
  V_RETURN:=
 CASE /*特殊科目 设置*/
     WHEN P_HKONT IN ('1123040101','1123040201')
       THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'A9' END) /* 810 预付账款-长期资产重分类至 其他非流动性资产  ALTER BY 20240715 XIAOYACHAO.EX*/
     WHEN P_HKONT = '1122000097'          /* 应收账款  其中：汇兑损益不参与重分类*/
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
     WHEN P_HKONT LIKE '1123%'
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END) /*预付  其中：待摊费用不参与重分类 700 610 810 1123 全部不重分类*/
     WHEN (P_HKONT IN ('2202000087','2202000088','2202000099') OR P_HKONT IN( '2202000089')  AND NOT (P_BUKRS IN ('1600','1650')))
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
     WHEN (P_HKONT LIKE '224108%' OR P_HKONT = '2241000099')
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)         /*其他应付 负数 预提费用 汇兑损益 不重分类*/
     WHEN P_HKONT LIKE  '1126%'
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END) /*810应收款项融资 不重分类*/
     WHEN P_HKONT LIKE  '1124%' AND P_DMBTR >= 0
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)/* 810 应收出口退税为其他应收  */
     WHEN P_HKONT LIKE  '1124%' AND P_DMBTR < 0
       THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END) /* 810 应收出口退税为其他应收  负数 重分类到其他应付款  */
     WHEN P_HKONT LIKE '1411%'
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)
/*标准逻辑*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END) /* 应收账款  其中：汇兑损益不参与重分类*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)  /* 应收账款 负数 重分类到合同负债  */
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END) /* 其他应收账款 负数 重分类到其他应付款  */
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END) /*预付  其中：待摊费用不参与重分类*/
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AP' END)  /*预付  负数 ：重分类到应付*/
       WHEN P_HKONT LIKE  '1124%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END) /*应收款项融资 不重分类*/
       WHEN P_HKONT LIKE  '1460%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)  /*合同资产 不重分类*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END) /*合同结算  正数 合同资产*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)/*合同结算 负数 重分类 合同负债*/
       WHEN P_HKONT LIKE  '2204%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END) /*合同负债 不重分类*/
       WHEN P_HKONT LIKE  '2202%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
       WHEN P_HKONT LIKE  '2202%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AS' END)  /* 应付账款  正数 重分类 预付 */
       WHEN P_HKONT LIKE  '2203%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)  /*预付 不重分类*/
       WHEN P_HKONT LIKE  '2241%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END) /*其他应付 负数 预提费用 汇兑损益 不重分类*/
       WHEN P_HKONT LIKE  '2241%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OR' END) /*其他应付 正数 重分类 其他应收*/
       ELSE (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN '' END)
  END;
END IF;
IF P_MANDT = '880' THEN
  V_RETURN:=
 CASE /*特殊科目 设置*/
     WHEN P_HKONT LIKE '1221990000'             /*880 1221990000J（汇兑调整）不参与重分类，直接为其他应收OR*/
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
     WHEN P_HKONT='1122000097'             /* 应收账款  其中：汇兑损益不参与重分类*/
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
     WHEN P_HKONT='1122990000'                  /*880 1122990000J(汇兑调整)不参与重分类，直接应收AR*/
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
     WHEN P_HKONT LIKE '1123%'
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END) /*预付  其中：待摊费用不参与重分类 700 610 810 1123 全部不重分类*/
     WHEN (P_HKONT IN ('2202000087','2202000088','2202000099', '2202990000','2202970000','2202960000') OR P_HKONT IN( '2202000089')  AND NOT (P_BUKRS IN ('1600','1650')))
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
     WHEN (P_HKONT LIKE '224108%' OR P_HKONT = '2241000099' OR (P_HKONT='2241990000' OR P_HKONT BETWEEN '2241190100' AND '2241199800') )
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)         /*其他应付 负数 预提费用 汇兑损益 不重分类*/
     WHEN P_BUKRS BETWEEN '6950' AND '6960' AND P_HKONT LIKE '1123%'
       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)         /*三电公司预付不重分类 ALTER BY 20240924 13:42 XIAOYACHAO.EX */
/*标准逻辑*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END) /* 应收账款  其中：汇兑损益不参与重分类*/
       WHEN P_HKONT LIKE  '1122%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)  /* 应收账款 负数 重分类到合同负债  */
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
       WHEN P_HKONT LIKE  '1221%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END) /* 其他应收账款 负数 重分类到其他应付款  */
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END) /*预付  其中：待摊费用不参与重分类*/
       WHEN P_HKONT LIKE  '1123%'  AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AP' END)  /*预付  负数 ：重分类到应付*/
       WHEN P_HKONT LIKE  '1124%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END) /*应收款项融资 不重分类*/
       WHEN P_HKONT LIKE  '1460%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)  /*合同资产 不重分类*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR>=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END) /*合同结算  正数 合同资产*/
       WHEN P_HKONT LIKE  '1466%' AND P_DMBTR<0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)/*合同结算 负数 重分类 合同负债*/
       WHEN P_HKONT LIKE  '2204%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END) /*合同负债 不重分类*/
       WHEN P_HKONT LIKE  '2202%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END) /* 应付账款  其中：暂估 、汇兑损益 不参与重分类*/
       WHEN P_HKONT LIKE  '2202%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AS' END)  /* 应付账款  正数 重分类 预付 */
       WHEN P_HKONT LIKE  '2203%'
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)  /*预付 不重分类*/
       WHEN P_HKONT LIKE  '2241%' AND P_DMBTR<=0
            THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END) /*其他应付 负数 预提费用 汇兑损益 不重分类*/
       WHEN P_HKONT LIKE  '2241%'  AND P_DMBTR>0
            THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OR' END) /*其他应付 正数 重分类 其他应收*/
       ELSE (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN '' END)
  END;
END IF;
IF P_MANDT ='800' AND  P_BUKRS NOT LIKE '9%' THEN
  V_RETURN:=
     CASE  /*家电总部 部分客商不参与重分类，直接记其他应收*/
        WHEN  (P_BUKRS LIKE '6000%'  OR P_BUKRS='6600' ) AND (LTRIM(P_CVCODE,'0') BETWEEN '4000276' AND '4000283'  OR LTRIM(P_CVCODE,'0') IN ('4000285','4000295','4000310','4000296','4000297','5001618','5001617','500255','500256') )
              THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
       /*特殊科目 设置*/
      WHEN P_HKONT  = '1151005000' AND P_BUKRS NOT IN ('1013','1014')
        THEN  (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'A9' END)  /*  预付账款-长期资产重分类至 其他非流动性资产  ALTER BY 20240715 XIAOYACHAO.EX*/
      /*金投公司 1013 1014  ALTER BY XIAOYACHAO.EX 20240815*/
      WHEN P_BUKRS IN ('1013','1014') AND P_HKONT  = '1131015007'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)                     /*不重分类，直接到应付 ALTER BY 20240815 XIAOYACHAO.EX*/
      WHEN P_BUKRS IN ('1013','1014') AND P_HKONT LIKE '1151%' AND P_DMBTR >= 0          /*1151预付账款 重分类 ALTER BY 20240815 XIAOYACHAO.EX*/
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
      WHEN P_BUKRS IN ('1013','1014') AND P_HKONT LIKE '1151%' AND P_DMBTR < 0
        THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AP' END)
      WHEN P_BUKRS IN ('1013','1014') AND P_HKONT LIKE '2131%' AND P_DMBTR <= 0          /*2131 预付账款 重分类 ALTER BY 20240815 XIAOYACHAO.EX*/
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)
      WHEN P_BUKRS IN ('1013','1014') AND P_HKONT LIKE '2131%' AND P_DMBTR > 0
        THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AR' END)

      WHEN P_HKONT='2181999001'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)
      WHEN P_HKONT IN ('2121999001' ,'2121098000','2121098001')
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END)
      WHEN P_HKONT =  '1131999001'
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
      WHEN P_HKONT =  '1133999001'
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
      WHEN P_HKONT  IN ('1151006000','1151001000','1151007099','1151007006','1151007007') OR P_HKONT LIKE '1151%' AND P_MANDT = '900'/*预付模具费 1151001000 20230803ADD*/
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
      WHEN P_HKONT  LIKE '1151%'  AND P_MANDT='800'                                               /*预付模具费 1151007000 20230904 ADD   20231104 放开1151 如果需剔除科目 使用 前端表维护剔除科目*/
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
      WHEN P_HKONT  LIKE '1301%'         /*待摊费用 放预付*/
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
      WHEN P_MANDT = '800' AND (P_HKONT IN ('1131017002','1131017003','1131018002','1131018003','1131018004','1131018005','1131018006') OR P_HKONT LIKE '1816%')   /* 800 & 900 增加长期应收款分类  ALTER BY XIAOAYCHAO.EX 20240807 */
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)
      WHEN P_MANDT = '900' AND P_HKONT LIKE '1468%'
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)

 /*标准逻辑*/
      WHEN P_HKONT LIKE  '2181%' AND P_DMBTR<=0
             THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)
      WHEN P_HKONT LIKE  '2181%' AND P_DMBTR>0
             THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OR' END)
      WHEN P_HKONT LIKE  '2121%' AND P_DMBTR<=0
             THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END)
      WHEN P_HKONT LIKE  '2121%' AND P_DMBTR>0
             THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AS' END)
      WHEN P_HKONT  LIKE '2191%' AND P_BUKRS<>'8910' /*预提费用不参与重分类*/
             THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)
      /*应收类科目重分类*/
      WHEN P_HKONT LIKE  '1131%' AND P_DMBTR>=0
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
      WHEN P_HKONT LIKE  '1131%' AND P_DMBTR<0
        THEN  (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)
      WHEN P_HKONT LIKE  '1133%' AND P_DMBTR>=0
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
      WHEN P_HKONT LIKE  '1133%' AND P_DMBTR<0
        THEN  (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END)
      WHEN P_HKONT LIKE  '1466%' AND P_DMBTR>=0
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)
      WHEN P_HKONT LIKE  '1466%' AND P_DMBTR<0
        THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)
      WHEN P_HKONT LIKE '1460%'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)
      WHEN P_HKONT LIKE '1124%'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END)
      WHEN P_HKONT LIKE '2131%'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)
      WHEN P_HKONT LIKE '2204%'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END)
      ELSE ''  END
        ;

END IF;
/*9003 不从SAP 取数 20220621 王清*/
IF P_MANDT = '800' AND P_BUKRS LIKE '9%' AND  P_BUKRS NOT LIKE '9003'  THEN
  V_RETURN:=
  /*'1151' 预付账款'1221'其他应收款 '2241' 其他应付款*/
      CASE
           WHEN P_HKONT =  '1151005000' AND P_BUKRS NOT IN ('9002','9004')
             THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'A9' END) /*  预付账款-长期资产 重分类至 其他非流动性资产  ALTER BY 20240715 XIAOYACHAO.EX*/
               /*金投公司 9002 9004 9005  ALTER BY XIAOYACHAO.EX 20240815*/
           WHEN P_BUKRS IN ('9002','9004') THEN
               (CASE WHEN P_HKONT  IN ( '1131015007' ,'1131098000')                                    /*不重分类，增加1131098000 科目 ALTER BY 20240822 XIAOYACHAO.EX*/
                       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)                     /*不重分类，直接到应收 ALTER BY 20240815 XIAOYACHAO.EX*/
                     WHEN  P_BUKRS = '9002' AND P_HKONT LIKE '1131%'                                   /*9002 不取SAP系统数  ALTER BY 20240902 11:30 XIAOYACHAO.EX*/
                       THEN ''
                     WHEN P_HKONT LIKE '1816%'
                       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)                    /*不重分类，直接到长期应收 ALTER BY 20240823 XIAOYACHAO.EX*/
                     WHEN P_HKONT LIKE '1151%' AND P_DMBTR >= 0                                        /*1151预付账款 重分类 ALTER BY 20240815 XIAOYACHAO.EX*/
                       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
                     WHEN P_HKONT LIKE '1151%' AND P_DMBTR < 0
                       THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AP' END)
                     WHEN P_HKONT LIKE '2131%' AND P_DMBTR <= 0                                        /*2131 预付账款 重分类 ALTER BY 20240815 XIAOYACHAO.EX*/
                       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)
                     WHEN P_HKONT LIKE '2131%' AND P_DMBTR > 0
                       THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AR' END)
                     WHEN P_HKONT LIKE  '2121%' AND P_DMBTR<=0
                       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END)
                     WHEN P_HKONT LIKE  '2121%' AND P_DMBTR>0
                       THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AS' END)
                     WHEN P_HKONT LIKE  '1131%' AND P_DMBTR>=0
                       THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
                     WHEN P_HKONT LIKE  '1131%' AND P_DMBTR<0
                       THEN  (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)
                     WHEN P_HKONT LIKE  '1133%' AND P_DMBTR>=0
                       THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
                     WHEN P_HKONT LIKE  '1133%' AND P_DMBTR<0
                       THEN  (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END)
                     WHEN P_HKONT  LIKE '1301%'                                        /*待摊费用 放预付*/
                       THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
                     WHEN P_HKONT LIKE '2204%'
                       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END)
                     WHEN P_HKONT LIKE  '2181%' AND P_DMBTR>=0                                         /*增加2181%科目重分类逻辑  ALTER BY 20240823 XIAOYACHAO.EX*/
                       THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
                     WHEN P_HKONT LIKE  '2181%' AND P_DMBTR<0
                       THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END)
                 END)
              WHEN P_HKONT LIKE  '1151%'
                THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
              WHEN P_HKONT LIKE  '2241%' AND P_DMBTR<=0
                THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)
              WHEN P_HKONT LIKE  '2241%' AND P_DMBTR>0
                THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OR' END)
              WHEN P_HKONT LIKE  '1221%' AND P_DMBTR>=0
                THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
              WHEN P_HKONT LIKE  '1221%' AND P_DMBTR<0
                THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END)
              WHEN P_BUKRS = '9005' AND P_HKONT LIKE  '1801%' AND P_DMBTR>0    /*9005 的1801科目 放预付  ALTER BY XIAOYACHAO.EX 20240815*/
                THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
              WHEN (P_HKONT IN ('1131017002','1131017003','1131018002','1131018003','1131018004','1131018005','1131018006') OR P_HKONT LIKE '1816%')   /* 增加长期应收款分类  ALTER BY XIAOAYCHAO.EX 20240807 */
                THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)
              ELSE ''  END
        ;

END IF;
IF P_MANDT = '900' AND P_BUKRS NOT LIKE '9%' THEN
  V_RETURN:=
     CASE  /*家电总部 部分客商不参与重分类，直接记其他应收*/
        WHEN (P_BUKRS LIKE '6000%'  OR P_BUKRS='6600') AND (LTRIM(P_CVCODE,'0') BETWEEN '4000276' AND '4000283' OR LTRIM(P_CVCODE,'0') IN ('4000285','4000295','4000310','4000296','4000297','5001618','5001617','500255','500256') )
          THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
       /*特殊科目 设置*/
      WHEN P_HKONT  = '1151005000' AND P_BUKRS NOT IN ('1013','1014')
        THEN  (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'A9' END)  /*  预付账款-长期资产重分类至 其他非流动性资产  ALTER BY 20240715 XIAOYACHAO.EX*/
      WHEN P_HKONT='2181999001'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)
      WHEN P_HKONT IN ('2121999001' ,'2121098000','2121098001')
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END)
      WHEN P_HKONT =  '1131999001'
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
      WHEN P_HKONT =  '1133999001'
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
      WHEN P_HKONT  IN ('1151006000','1151001000','1151007099','1151007006','1151007007') OR P_HKONT LIKE '1151%' AND P_MANDT='900'/*预付模具费 1151001000 20230803ADD*/
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
      WHEN P_HKONT  LIKE '1151%'  AND P_MANDT='800'/*预付模具费 1151007000 20230904 ADD   20231104 放开1151 如果需剔除科目 使用 前端表维护剔除科目*/
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
      WHEN P_HKONT  LIKE '1301%' /*待摊费用 放预付*/
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AS' END)
      WHEN P_HKONT LIKE '1816%'   /* 900 增加长期应收款分类  ALTER BY XIAOAYCHAO.EX 20240807 */
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)
      WHEN P_MANDT = '900' AND P_HKONT LIKE '1468%'
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'A10' END)

 /*标准逻辑*/
      WHEN P_HKONT LIKE  '2181%' AND P_DMBTR<=0
             THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)
      WHEN P_HKONT LIKE  '2181%' AND P_DMBTR>0
             THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OR' END)
      WHEN P_HKONT LIKE  '2121%' AND P_DMBTR<=0
             THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AP' END)
      WHEN P_HKONT LIKE  '2121%' AND P_DMBTR>0
             THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'AS' END)
      WHEN P_HKONT  LIKE '2191%' AND P_BUKRS<>'8910' /*预提费用不参与重分类*/
             THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OP' END)
      /*应收类科目重分类*/
      WHEN P_HKONT LIKE  '1131%' AND P_DMBTR>=0
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AR' END)
      WHEN P_HKONT LIKE  '1131%' AND P_DMBTR<0
        THEN  (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)
      WHEN P_HKONT LIKE  '1133%' AND P_DMBTR>=0
        THEN  (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'OR' END)
      WHEN P_HKONT LIKE  '1133%' AND P_DMBTR<0
        THEN  (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'OP' END)
      WHEN P_HKONT LIKE  '1466%' AND P_DMBTR>=0
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)
      WHEN P_HKONT LIKE  '1466%' AND P_DMBTR<0
        THEN (CASE P_FLAG WHEN '1' THEN 'Y' WHEN '2' THEN 'CL' END)
      WHEN P_HKONT LIKE '1460%'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CA' END)
      WHEN P_HKONT LIKE '1124%'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'RF' END)
      WHEN P_HKONT LIKE '2131%'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'AC' END)
      WHEN P_HKONT LIKE '2204%'
        THEN (CASE P_FLAG WHEN '1' THEN 'N' WHEN '2' THEN 'CL' END)
      ELSE ''  END
        ;
END IF;

    RETURN V_RETURN;
END;