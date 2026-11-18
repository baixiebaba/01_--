CREATE OR REPLACE PROCEDURE CPM_SP_D2M_REV_M(P_SCENARIO IN varchar2,
                                             P_PERIODO  IN varchar2,
                                             P_AZIENDA IN varchar2,
                                             P_ORG_FLAG IN varchar2, --P_ORG_FLAG标识，1-正常数据抽取，2-调整数据抽取，
                                             SESSION_USER  IN varchar2)
AS

  /***************************************************
  最后更新时间：V7.5  20261117  20:20  更新人：LICHENG.EX
  上一版本信息：V7.4  20261117  20:10  更新人：LICHENG.EX

  名        称：CPM_SP_D2M_REV_M-DWM->DWS
  用        途：DWD->DWM数据抽取
  源        表：DWD_FI_MR_GP_MSUM_MI_LCTEST
  目   标   表：AW_MR9_REVM01_000001
  逻辑文档地址: https://hisenseex.feishu.cn/file/MzDzbm8u8o53zMxhpg6cEeo7n5e?office_edit=1
  特  殊 逻 辑：P_ORG_FLAG标识，1-正常数据抽取，2-调整数据抽取，

  版  本 信 息：修改记录最新的放到最上面
  ALTER BY LICHENG.EX 20261117 20:20 【R5 修复·日立外机拆分跨库读生产】
    改动位置：REV001_STEP_11(成本聚合处理-日立) 两处 FROM/JOIN 的 schema 前缀
      ① L3983 「INSERT INTO ZTAB_HITACH_ZXSLR_FINALLY_TEMP ... FROM TGK_FIMA_HISENSE.ZTAB_HITACH_ZXSLR_FINALLY」→ 去掉 TGK_FIMA_HISENSE.
      ② L4153 「INNER JOIN TGK_FIMA_HISENSE.ZTAB_HITACH_ZXSLR_FINALLY_TEMP」→ 去掉 TGK_FIMA_HISENSE.
    原因：本段是一条自洽链 L3945(GB库→本地 FINALLY) → L3978(本地 FINALLY 聚合→本地 _TEMP) → L4153(JOIN _TEMP 做拆分)。
          但 ① 的源、② 的 JOIN 目标都写死 TGK_FIMA_HISENSE，等于「往本地灌、却去生产读」：
          · ① 读生产 FINALLY —— 生产当期该表 0 行（数据只从 GB 库灌到本地），聚合必然 0 行；
          · ② 读生产 _TEMP —— 10,757 行，是生产上一次跑批的残留快照，与本地当期不同源。
          2026ACT/10 对账表现为 GB_ZXSLR 少 3,516 行 / -1.45 亿（1740 -2,633 行/-8,956 万、1730 -883 行/-5,583 万）。
          注：同段 L3962/L3988 的 AW_RUL_REVAAZ_000001 保持读生产（主数据一致，不动）。
    目标成果：日立拆分完全走 DEV 本地数据，与生产口径可比；成本端 S640100 差额 -1.45 亿归零。
    回退：把两处前缀 TGK_FIMA_HISENSE. 加回即可（行内有 20:20 注释定位）。
    影响面：仅日立公司（BUKRS 1700/1730/1735/1745/1760 经 REVAAZ 映射的公司），不动非日立成本。
  ALTER BY LICHENG.EX 20261117 20:10 【R3 修复·6002 科目串位】
    改动位置：REV001_STEP_1(收入聚合处理) 的 BSEG 段科目映射 CASE —— SELECT 端（约 L1485）与 GROUP BY 端（约 L1695）两处同步。
    原因：V6 补 S810 白名单时（L1671 取数条件 + L1693 映射分支），映射 CASE 里「SYSTEM_SRC IN ('S800','S900','S610','S810') → S600100」
          排在「COMPANY_CODE='6002' → S600110」之前。6002 的 BSEG 凭证 ACCT_SRC_CODE 是 5001 开头（ACCT_MAP_CODE=6001000000），
          既不在 6001000000/6001010000 等白名单、也不是 6001020000，只剩 S810 分支可落 → 被截胡成 S600100，
          6002 兜底分支永远不生效。2026ACT/10 对账表现为 6002 的 S600100 多 984 万、S600110 少 984 万（纯串科目，总额不变）。
          生产脚本无 S810 分支，所以走兜底落 S600110 —— 本次改后与生产口径一致。
    改动：把「COMPANY_CODE='6002' → S600110」整行前移到 S810 分支之前（放在 ACCT_SRC_CODE 白名单之后再之前，不影响 S600111 判断）。
    目标成果：6002 的 BSEG 恢复落 S600110；S600100/S600110 各回正 984 万；不影响 6001020000 走 S600111 的既有口径。
    回退：把该行移回 S810 分支之后即可（GROUP BY 端同步回退）。
  ALTER BY LICHENG.EX 20261117 16:46 【海外公司收入汇率修正】STEP_100 两处：
    ① 「更新收入-人民币」UPDATE（现 L10145）的 CASE，在 020 节点分支后加一档：
       WHEN NVL(T.COD_VALUTA_ORIGINARIA,'X')='CNY' AND T.COD_CONTO<>'S600100' THEN T.BCY_REV
       原因：D 02 新口径 qcy_code 取 bkpf.waers，6015/80N0/8080 等 10 家海外公司凭证抬头是 CNY
       （BSEG 行 pswsl 仍是 USD），BCY_REV（=ORG_REV 原币）装的就是人民币；再除本位币汇率会虚增
       6.72 倍（USD 本位币）或 1.08 倍（HKD）。6015 的 S600110 因此从 22.0M 虚增到 148.5M，公司合计由负转正。
       必须排除 S600100：该科目在 STEP_8 已按 EXCHANGE_RATE 折成本位币，仍要走 BCY_REV/CAMBIO 还原。
    ② 其后新增一个 UPDATE：原币=CNY 且本位币<>CNY 的行，BCY_REV = ROUND(ORG_REV×CAMBIO,2)（同样排除 S600100）。
       否则「收入-本位币」列仍是人民币值（6015：22,080,809 vs 生产 3,278,559）。
    不改：L9946（BCY_REV=ORG_REV）保持原样；注释块 L9955-10098 仍未启用。
    影响面：6015/80N0/8080/8060/80Q0/80B0/1008/9003/9008/8050 共 10 家；中国区 CAMBIO(CNY)=1，结果不变。
    回退：删新增的 WHEN 行与新增 UPDATE 段（两处行首均有 2026-11-17 注释）。
  ALTER BY LICHENG.EX 20261116 22:05 【V7.2 C-042 补丁：交易币同步翻转】出库未开段与退货未办段的 REV_SALE_AMT 取负方向一起翻，
    与各自的本位币同向。原因：STEP_7(金额还原-税率) 的 ORG_REV 更新末尾是 ELSE SALE_REV —— 凡不满足「6012/2023/2910」「BSEG」「外币」三个分支的行，
    本位币都会被交易币覆盖；ZTSO04_CK/TH 正好落在这个 ELSE 里，所以只翻本位币不起作用，表现为改完重跑数值一模一样的。
    改后：退货段「本月取负」、出库段「本月直传」，与本位币一致；STEP_7 再覆盖也不会错。

  ALTER BY LICHENG.EX 20261116 20:30 【V7.1 C-042 出库/退货符号回正】REV001_STEP_1 出库未开段与退货未办段的本位币取负一起翻转：
    退货未办段（ODS_SRC=ZTSO04_TH / TH_045）由「本月直传、上月取负」改为「本月取负、上月直传」；
    出库未开段（ODS_SRC=ZTSO04_CK）由「本月取负、上月直传」改为「本月直传、上月取负」。
    口径：D 表对 ZTSO04 三类来源已统一取负（负数代表收入增加），D 侧是对的、不改；本层各翻一次，
          得到管报口径（退货正数冲减收入、出库负数增加收入）。原两段 CASE 是按旧 D 的正数口径写的。
    不动：数量列（MAP_ZUM_QTY / STD_QTY）与 COGS_AMT 两边一致。
    回退：两段各自改回原来的方向即可（行首有 2026-11-16 注释）。
    ① STEP_2 之后「2023 金额 ×100」停用（块注释包住，代码保留）—— D 的 02 已对 2023 乘 100，M 再乘会放大 1 万倍。
    ② STEP_1 的 BSEG 段 4 处「S800/S900 取负」分支停用（BILL_QTY / SALE_REV / ORG_REV / MAP_ZUM）—— D 已按借正贷负出数；与 ③ 在 800/900 上重叠，须同时改。
    ③ STEP_9 按来源拆符号：D 来源不再取负、MAP_REV 改为 ORG_REV + 各折扣；AD 及非 D 来源仍按「录入正数 + M 取负」。
    ④ STEP_7 删掉「BSEG 且 S800/S900 取 SALE_REV」分支，BSEG 统一取 ORG_REV —— 新 D 已修正交易币/本位币两列含义。
    回退：代码均未删 —— ① 去掉外层块注释；②③④ 按各行行首「2026-11-16」注释恢复；整版回退把 6 处 _LCTEST 后缀去掉。

  ALTER BY LICHENG.EX 20261116 15:09 REV001_STEP_1(聚合处理)第4段(BSEG总账调整)补蒙特雷 S810 进数（V6.9）：来源白名单与 COD_CONTO 科目映射的 S800/S900/S610 判断统一增加 'S810'，共 5 处（1 处 WHERE + 2 组 CASE）；现象：S810 的蒙特雷体系用 5001 科目表，原始科目不在 6001 白名单、又不在 S800/S900/S610 分支，整块落空 —— 202610 实测 211 家范围内 3 家对不上（6377 8,969.7 万、6376 1,198.3 万、2021 1.3 万）；已验证 S810 的 BSEG 行中 ACCT_MAP_CODE LIKE '6001%' 的全部为「5 个白名单科目 + RFBU」，不会误收开票凭证。
  ALTER BY LC 20261105 22:41 TVS 2910 销量折算特殊逻辑，如果不在物料大表的物料，折算为0
  ALTER BY LC 20261105 09:40 费用转政策还原无需限制产品公司范围
  ALTER BY 20261104  17:13 XIAOYACHAO.EX AW_MR9_ADJM01_000001 手工调整表取数增加 D_BUS_SCE_S(业务场景分类)：S600100AD/S600101AD/S600102AD/S640100AD/S640102AD/S6001G5AD 六块 + STEP_17(GA00_CN_REV、REV_01_401)两块 + STEP_24(GA00_REV_KH)两块，共 10 处 INSERT 的列清单/SELECT 补齐；聚合块同步补 GROUP BY（含修复 S600100AD 块已有 MI.D_BUS_SCE_S 未入 GROUP BY 的 ORA-00979 隐患）
  ALTER BY 20261102  11:16 LICHENG.EX 费用转政策业务分类被覆盖问题修改
  ALTER BY 20261102  09:46 LICHENG.EX TVS销量分摊规则库开始结束时间判断截取前6位
  ALTER BY 20261101  15:42 LICHENG.EX 取消TVS销量分摊规则库开始时间
  ALTER BY 20261030  16:17 LICHENG.EX 修复块注释嵌套（V6.2）：①文件头版本记录里写到注释符本身，会让 banner 注释在记录行处提前闭合、其后的版本记录被当成代码（编译报错）+ 编辑器整片识别为注释，现统一改称「块注释/起始符/结束符」；②REV001_STEP_17-10 停用块内原先把结束符拆成带空格写法，嵌套式编辑器会认为注释没闭合，现段内说明块改用 -- 注释、两处 INSERT 去掉并行提示符，整块只剩首尾一对注释符。逻辑代码零改动
  ALTER BY 20261030  16:12 LICHENG.EX 中国区自营成本本月不上线（补充口径，V6.1）：ZTSO04_TH 也纳入不进数范围 —— REV001_STEP_11 四段 UNION ALL 的 ods_src 排除名单由 6 个来源扩为 7 个（ECPX/VBRP_O2O/VBRP_O2O_TH/VBRP_O2O_ZR/VBRP_O2O_TC/POLICY_COST/ZTSO04_TH）；3 处 NODE='200' 白名单原只注释前 6 个、保留 ZTSO04_TH，现整行停用（含 ZTSO04_TH），与 NOT IN 同口径
  ALTER BY 20261030  16:12 LICHENG.EX 复核 REV001_STEP_17-10 注释范围（V6.1）：仅 17-10 本身的冲销段(L9323–9505)与还原段(L9507–9697) 被块注释包住（起始符 L9304、结束符 L9699，为 V6.2 行号），段末 COMMIT 之后即闭合，其后 REV001_STEP_18/STEP_99/STEP_999 与正式表 INSERT 均在注释外、照常执行；代码未删除
  ALTER BY 20261030 16:04 LICHENG.EX 中国区自营成本本月不上线（REV001_STEP_11 成本聚合处理）：4 段 UNION ALL 各自启用 ods_src 来源排除 —— ods_src 为 ECPX / VBRP_O2O / VBRP_O2O_TH / VBRP_O2O_ZR / VBRP_O2O_TC / POLICY_COST 时不进数（恢复 20260930fjf_add 口径，原为 -- 注释）；同时把 3 处 NODE='200' 白名单里这 6 个来源用块注释停用（V6.1 起整行停用、含 ZTSO04_TH）。未删除任何代码，恢复时把 4 行排除改回 -- 注释、去掉白名单的注释符即可
  ALTER BY 20261030 16:04 LICHENG.EX 中国区自营成本本月不上线（REV001_STEP_17-10 会员店-产品公司冲销）：整段用块注释停用，第一段冲销(REV_01_225)/第二段还原(REV_01_226) 均不再生成，含各自的 ZTAB_CPM_LOG 与 COMMIT；代码全部保留未删除。V6.2 起段内说明块改为 -- 注释、两处 INSERT 去掉并行提示符，整块只剩首尾一对注释符
  ALTER BY 20261029 14:34 LICHENG.EX 新增 REV001_STEP_16_1(中国区-智能生态销量处理)：中国区公司（COD_AZIENDA=1180 或 LIKE '12%'）业务分类 D_OPER_TYPE='OPTY036' 的数据，中国区销量 CN_MAP_ZUM 更新为 0；位置在 2.2.16.1(中国区-业务分类补充) 之后、STEP_17-1 冲销还原之前，使后续冲销/还原按已归零的销量生成，避免净值不为 0
  ALTER BY 20261028 17:20 LICHENG.EX 新增 REV001_STEP_19_1(供应商返利相关维度更新)：公司 2000 的供应商返利数据（管法差异项 D_DIFF_TYPE='110304002'、源明细 SRC_DETAIL='ADJ_DI_MAG'）客商 CUST_CODE 统一更新为 310308；限制为公司 COD_AZIENDA=2000 且公司参数含 2000（EXISTS SESSION_AZIENDA_LIST ELEM='2000'，与 20261021 平板电视调整同一门控），位置置于 STEP_999 之前，使 D_TOV_CHAN / D_CC_CUSTGRP 按更新后的客商重新取值
  ALTER BY LICHENG.EX 20261027 REV001_STEP_11(成本聚合处理)制造费用段排除 2910：SRC_DETAIL='MFEX' 的取数（科目固定 S640190 制费转成本）最外层 NOT IN 名单由 ('2023','6376','6377','6098','6012') 增加 '2910'，2910 不再生成这笔成本；该过滤在 GROUP BY 之前，两段 UNION ALL（非SAP600 / SAP600）共用，只改一处；MFEX 无其它生成点，STEP_18 的 MERGE 按 SRC_DETAIL='MFEX' 更新业务范围，2910 无该行即不参与，无需另改
  ALTER BY LIYIFAN1.EX 20261027 修改为当参数有2000时运行 但不限制源公司
  20261027 FENGJIANFENG.ex 20261027fjf_add REV005_STEP_999 二期新增维度处理
  ALTER BY 20261026 XIAOAYCHAO.EX 2910公司增加管法差不变号
  20261023 ALTER BY LIYIFAN1.EX 新增ods_src ZTSO04_TH
  20261021 ALTER BY LIYIFAN1.EX 平板电视出口收入调减显示器出口收入调增
  ALTER BY LICHENG.EX 20261019 17:56 REV001_STEP_9(金额还原-数据处理)修正取负口径（目标：2910+BSEG 不变号、2910+313A 变号）：V5.1 原改法三处偏差 —— ① COD_AZIENDA 名单加 '2910' 把 2910 整体排除，313A 也不再变号；② SRC_DETAIL 只排除 'BSEG'，漏 'BSEG_FLJC'/'BSEG_REVM'（块④ 的 BSEG 会派生这三种值，且 L10662 已有同样口径先例）；③ 非 2910 公司的 BSEG 被一并排除，改变了中国区原逻辑。现改为：保留原条件 SRC_DETAIL NOT IN ('GLPCA') AND COD_AZIENDA NOT IN ('6012','2023')，仅追加 AND NOT (COD_AZIENDA='2910' AND SRC_DETAIL IN ('BSEG','BSEG_FLJC','BSEG_REVM'))，只豁免 2910 的 BSEG 家族
  ALTER BY LIYIFAN 20261016 ⑤事业部对中国区出库未开
  ALTER BY 20261015  18:19 LICHENG.EX REV001_STEP_1(收入聚合处理)主聚合块 DISCOUNT_1：2910-TVS 分组改为「rebate7/8/9/11/12/13/14/15/19_amt 九项合计」直接进数，去掉原「合计 ÷ DATI_CAMBIO.CAMBIO_PERIODO 期间平均汇率折算人民币」的汇率处理；非 2910 分组取值不变
  ALTER BY 20261015 18:12 LICHENG.EX REV001_STEP_10(政策分摊)第1段(源 dwd_fi_mr_rev_acct_msum_mi)新增 SHOP_CODE、D_PRC_GRP 两列：SHOP_CODE=COALESCE(shop_code,'ZZZZ')、D_PRC_GRP=material_pricing_group_code（对应 DWD 20261015 17:26 新增字段，直接对应；SHOP_NAME 源表暂无 shop_name 字段，本次未加）；同步 目标列清单/SELECT/GROUP BY 三处
  ALTER BY 20261015 14:09 XIAOYACHAO.EX REV001_STEP_11(成本聚合处理)修复 6000A 成本漏数：第3段(物料为空且映射后科目=6401000000)公司名单增加 6000A
  ALTER BY 20261014 19:08 LICHENG.EX REV001_STEP_1(聚合处理)第4段(BSEG总账调整)新增 S600114 映射：ODS_SRC=BSEG 且凭证类型 document_type='ZL' 且映射前科目 ACCT_SRC_CODE='5001080102' 输出 S600114-主营业务收入-TVS返利价差（SELECT 与 GROUP BY 同步）
  ALTER BY 20261014 15:17 LICHENG.EX REV001_STEP_11(成本聚合处理)修复 TVS 成本漏数：第3段(物料为空且映射后科目=6401000000)公司名单增加 2910；原第2段(物料为空)以 ACCT_MAP_CODE<>6401000000 排除、第3段公司名单不含 2910，导致 2910(ZTFIBU001) 物料为空且 6401000000 的成本两段都进不来
  ALTER BY 20261013 17:32 LICHENG.EX 全 SP 落值端 ODS_SRC 统一大写：将所有从 ODS_SRC 派生的插入值（SRC_DETAIL / ODS_SRC 输出列，含 CASE WHEN ... THEN ODS_SRC ELSE ODS_SRC||'_LM' END 形式）统一改为 UPPER(ODS_SRC)，并同步其 GROUP BY 配对项（共 21 行代码（16 个直取 ODS_SRC + 5 个 CASE 型派生），SELECT 与 GROUP BY 逐字一致）；避免 TVS 等来源在 DWD 落小写 ods_src 时透传给下游按大写判断的步骤（如 STEP_7/STEP_8 判断 SRC_DETAIL='BSEG'）漏行
  ALTER BY 20261013 17:27 LICHENG.EX REV001_STEP_1(聚合处理)第4段(BSEG总账调整)SRC_DETAIL 落值统一大写：CASE 的 ELSE 分支由 ODS_SRC 改为 UPPER(ODS_SRC)（SELECT 与 GROUP BY 同步），避免 TVS 源表24/25 的小写 'bseg' 透传为 SRC_DETAIL，导致 STEP_7/STEP_8 按 SRC_DETAIL='BSEG' 判断时漏行
  ALTER BY 20261013 17:11 LICHENG.EX REV001_STEP_1(聚合处理)第4段(BSEG总账调整)修复 TVS 进数：①ODS_SRC 大小写统一改为 UPPER(ODS_SRC) 比较（DWD 对源表24/25 落小写 'bseg'，原按大写 'BSEG' 比较导致命中 0 行）；②来源白名单与 COD_CONTO 科目映射的 S800/S900 判断增加 'S610'（TVS system_src=S610），使 S610+BSEG+ACCT_MAP_CODE LIKE '6001%' 的行可进数并映射 S600100/S600111
  ALTER BY 20261012 19:14 LICHENG.EX REV001_STEP_17-10(会员店-产品公司冲销)还原数客商固定为 2105159（CUST_CODE/SOLD_TO_CODE 及 SOLD_TO_NAME 均按该客商取）；总公司/分公司集合均新增 6515——6515 既是总公司也是分公司，还原时切换为自身（6515→6515）
  ALTER BY 20261012 10:56 LICHENG.EX REV001_STEP_17-10(会员店-产品公司冲销)修复：取成本作为收入金额时，冲销无需变号
  ALTER BY 20261010 20:41 LICHENG.EX REV001_STEP_17-10(会员店-产品公司冲销)修复还原数重复：还原段 CTE SESSION_COMPANY 增加 DISTINCT 去重——SESSION_AZIENDA_LIST 存在重复行时，JOIN 会把每条源行放大成多行还原（表现为还原金额 = 冲销的 2 倍且总公司也出行）；冲销段用 IN 子查询天然去重、不受影响，代码未改
  ALTER BY 20261010 20:20 LICHENG.EX REV001_STEP_17-10(会员店-产品公司冲销)修正还原数生成逻辑：还原行改为「仅当会话公司为分公司(6734/2601/6834)时生成」，总公司(6700/2600/6800)会话只生成冲销；还原以切换后的总公司匹配利润中心（取总公司利润中心数据），输出公司仍落回分公司
  ALTER BY 20261010 19:40 LICHENG.EX REV001_STEP_17-10(会员店-产品公司冲销)不再直接使用 P_AZIENDA 参数：输出公司改取 SESSION_AZIENDA_LIST（会话解析后的公司，已含公司范围 ZAW_D2M_IN 与锁定 ZAW_D2M_LOCK 过滤）；第一段冲销用会话公司匹配 AW_RUL_PTAMAP_000001 并输出匹配到的产品公司，第二段还原先做 6734→6700/2601→2600/6834→6800 切换再匹配、输出保留切换前公司；支持参数为公司节点或逗号分隔多公司
  ALTER BY 20261010 14:12 LICHENG.EX 版本记录清理：修正 V3.4 记录中已被 V3.5 删除的「有效产品公司范围过滤」表述，避免与最终实现矛盾；代码无改动（该过滤仅 17-10 使用，17-9 与 STEP_25 保持不动）
  ALTER BY 20261010 14:05 LICHENG.EX REV001_STEP_17-10(会员店-产品公司冲销)删除 AW_RUL_CKTHAZ_000001 有效产品公司范围过滤（设计稿取数限制未含该表，产品公司已硬编码 6700/2600/6800）；利润中心仅按 AW_RUL_PTAMAP_000001 匹配
  ALTER BY 20261010 11:52 LICHENG.EX REV001_STEP_17-10(会员店-产品公司冲销)改为两段执行：第一段 INSERT 冲销数(D_ADJ_TYPE='REV_01_225'，收入/数量类×-1)、第二段 INSERT 还原数(D_ADJ_TYPE='REV_01_226'，取原值)；两段均加 NVL(D_ADJ_TYPE,'|') NOT IN ('REV_01_225','REV_01_226') 防重过滤，避免第二段吃到第一段刚提交的行
  ALTER BY 20261010 11:45 LICHENG.EX REV001_STEP_17-10(会员店-产品公司冲销)取数限制精简为三条(公司 1180/12**、科目 S6001/S6401 开头、D_OPER_TYPE=OPTY041)，去掉 P_ORG_FLAG 门控与 225/226 防重过滤；数字类字段(SALE_COGS/CN_MAP_ZUM/CN_ORG_REV/MAP_DIS1/3/4/5/6/30/34/POLICY_AMT/AVG_UNIT_COST/BCY_COGS/CN_SALE_COGS)由 NULL 改为 0
  ALTER BY 20261010 11:35 LICHENG.EX 新增REV001_STEP_17-10(会员店-产品公司冲销)：REV_01_225 冲销行(原字段×-1)/REV_01_226 还原行(原字段原值)；源行=中国区 1180/12** 且科目 S6001/S6401 开头 且 D_OPER_TYPE=OPTY041(中国区自营-会员店)；输出公司=参数公司、收入类字段取源表 SALE_COGS，利润中心按 AW_RUL_PTAMAP_000001 匹配(冲销直接用参数公司、还原先按 6734→6700/2601→2600/6834→6800 切换后匹配，产品公司限 6700/2600/6800)；客商：1180→1001200、12**→按 dim_rule_fi_mr_cust2ctp_mapping(cust_type_code='C'/system_src='S600') 取，优先 A012**
  ALTER BY 20261009 20:27 LICHENG.EX REV001_STEP_12_1(TVS销量收入分摊) D_ADJ_TYPE 编号变更：冲销行由 REV_01_223 改为 REV_01_227、分摊行由 REV_01_224 改为 REV_01_228
  ALTER BY 20261009 LICHENG.EX REV001_STEP_1(聚合处理)主聚合块 DISCOUNT_1：2910-TVS 分组改为取 rebate7/8/9/11/12/13/14/15/19_amt 九项合计，按公司编码取公司主数据币种、再到 DATI_CAMBIO 按参数年月取该币种期间平均汇率 CAMBIO_PERIODO 折算人民币（金额/汇率）；非 2910 分组取值不变
  ALTER BY 20261009 LICHENG.EX REV001_STEP_1(聚合处理)科目映射：新增 S600114-主营业务收入-TVS返利价差（ODS_SRC=ZTFI313A 且 ORDER_TYPE_CODE IN ('ZRCR','ZRDR') 且映射后科目 6001 开头）；S600111 取数来源由 GLPCA 扩为 GLPCA/ZTFI313A；该块 WHERE 放行 ZTFI313A
  ALTER BY 20261009 18:31 LICHENG.EX 成本分摊修改：①调用6401前按实际P_ORG_FLAG将本次刷新成本的SALE_COGS写入SH_BF_SALE_COGS；②调用CPM_SP_M2M_REV_6401_M并固定传入FLAG=1，使后续成本分摊完整重算
  ALTER BY 20261009 18:21 LICHENG.EX 新增TVS取数
  ALTER BY XIAOYACHAO.EX 2026-10-03 17:03 REV001_STEP_11(成本聚合处理) 4 个 UNION 分支中物料 FU8MUP001MCH 的剔除条件改为仅对 1180/12% 公司生效
  alter by zhuangxinzhou  20261002 6012 物料号置为空 剔除 剔除5001030700
  EDIT BY LC 20260930 21:55 当来源不为出库未开ZTSO04_CK%,退货未办ZTSO04_TH%,【D_OPER_TYPE-业务分类】为"OPTY021中国区自营-小B业务、OPTY025中国区自营-品线挂链、OPTY039中国区自营=费用转成本,OPTY040中国区自营-品线挂链费用转成本"时赋值为0,否则取SALE_COGS
  ALTER BY 20260930 19：13 FENGJIANFENG.EX 20260930fjf_add ①注释17-5、17-6品线挂链冲销还原逻辑②修改中国区成本里面来源的限制
  ALTER BY 20260930 08：37 FENGJIANFENG.EX 20260930fjf_add REV001_STEP_11(成本聚合处理1)因中国区成本不上线，当ods_src是ECPX/VBRP_O2O/VBRP_O2O_TH/VBRP_O2O_ZR/VBRP_O2O_TC/POLICY_COST时不进数
  20260929lc_add REV001_STEP_17-5（品线挂链-产品公司冲销还原）修改冲销、还原收入取值逻辑还原，本月不上线，中国区新增取数来源限制还原，本月不上，线REV001_STEP_16(中国区-成本字段更新)去掉中国区品线标记编码为Z2时的取数逻辑

  ALTER BY 20260928 20：20 FENGJIANFENG.EX 20260928fjf_add REV001_STEP_16(中国区-成本字段更新)新增来源ADJM01
  ALTER BY 20260928 XIAOYACHAO.EX 从 DWD_FI_MR_GP_MSUM_MI_LCTEST / DWD_FI_MR_GP_MSUM_CKTH_MI 聚合取数的收入/成本/出库未开/退货未办等7个块，SELECT输出与GROUP BY的物料组 MATERIAL_GROUP_CODE 改取 product_line_code、MATERIAL_GROUP_NAME 改取 product_line_name（INSERT目标列名及非GP_MSUM来源块未改）
  ALTER BY 20260928 14：38 FENGJIANFENG.EX 20260928fjf_add REV001_STEP_17-5（品线挂链-产品公司冲销还原）修改冲销、还原收入取值逻辑
  EDIT BY LC 260924 14:39 渠道分组限制为线上020-ON
  ALTER BY 20260922 18:51 FENGJIANFENG.EX 20260922fjf_add REV001_STEP_14(中国区-挂链) 管法差异项
  ALTER BY 20260921 10:05 FENGJIANFENG.EX 20260921FJF_ADD 中国区新增取数来源限制，费用转政策还原产品公司统一客户组放中国区
  ALTER BY 20260918 18.35 CHENDONG3.EX 20260918 修改17-5 17-6 D_DIFF_TYPE 为默认值
  ALTER BY 20260917 16.35 FENGJIANFENG.EX 20260917FJF_ADD 二期新增字段
  ALTER BY 20260917 13.49 SHIQINGFENG.EX 20260917 补充逻辑说明：空调通过按照产品大类(product_big_class_code)为P02（这是产品类别【D_PRO_CLASS】字段的层级）来判断，（不是通过有业务管理单元按照业务管理单元分摊，没业务管理单元按照利润中心的规则进行）并排除为金额为0
  ALTER BY 20260916 15.45 FENGJIANFENG.EX 20260916FJF_ADD REV001_STEP_16(中国区-成本字段更新)去掉中国区品线标记编码为Z1时的取数逻辑
  ALTER BY 20260915 17.25 FENGJIANFENG.EX 20260915FJF_ADD REV001_STEP_17-5（品线挂链-产品公司冲销还原）中国区销量字段、中国区收入字段放空
  ALTER BY 20260915 10：14 shiqingfeng.ex 修改使用生产环境公司主数据
  ALTER BY 20260914 FENGJIANFENG.EX 20260914FJF_ADD 成本聚合业务场景分类为026的要取数
  ALTER BY 20260910 FENGJIANFENG.EX 20260910FJF_ADD 取消REV001_STEP_13国补相关处理
       20260910 FJF_ADD REV001_STEP_17-2(中国区小B国补业务冲销）①取数限制修改：不取OPTY020 ②备注修改：中国区公司小B业务冲销


  ALTER BY 20260908 SHIQINGFENG.EX 取消注释STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 开始测试


                V1.初始版本的创建 CREATE BY SHAOFANGZE   AT 20250812
                V1.1 新增ORDER_TYPE_CODE 订单类型字段 liyifan 20251229
                ALTER BY 20260616 XIAOYACHAO.EX 1632新增利润中心104053001Vidda家庭影院音响-智能投影 BY : FIDATA-418
                ALTER BY 20260623 XIAOYACHAO.EX '1630','1632'取消利润中心限制
                ALTER BY 20260721 SHIQINGFENG.EX 【REV001_STEP_25(出库未开退货未办冲销)】 业务场景分类限制条件新增024，025
                ALTER BY 20260721 SHIQINGFENG.EX 修改为冲销不更新
                ALTER BY 20260724-1 SHIQINGFENG.EX 优先级最高 当映射前科目为 5101099006 时输出 S600113-主营业务收入-总账调整-返利价差-OEM
                ALTER BY 20260724-2 SHIQINGFENG.EX【REV001_STEP_25(出库未开退货未办冲销)】 业务场景分类限制条件新增024，025只有62，68开头的公司需要限制
                ALTER BY 202060728-1 shiqingfeng.ex 修改去除中国区-ZG发票剔除逻辑
                ALTER BY 202060728-2 shiqingfeng.ex 2090/2091/4006，默认业务范围修改为2000（原逻辑默认2018）
                ALTER BY 20260807-1 shiqingfeng.ex 6515出库未开成本拆分为当月成本和上月冲回两个INSERT，并增加分段执行日志
                ALTER BY 20260807-2 shiqingfeng.ex 6515成本仅在SESSION_AZIENDA_LIST包含6515时执行
                ALTER BY 20260807-3 shiqingfeng.ex SESSION_AZIENDA_LIST不包含6515时记录跳过日志
                ALTER BY 20260813-1 fengjianfeng.ex REV001_STEP_7（金额还原-税率 取消出库未开退货未办税率处理逻辑，该部分还原到D表进行，把M表的逻辑取消
                ALTER BY 20260813-2 fengjianfeng.ex 收入聚合、成本聚合中，根据ods_src为/不为ZTSO04_TH判断的地方，都要加上ZTSO04_TH_045
                ALTER BY 20260817-1 shiqingfeng.ex 新增REV001_STEP_17-4 O2O-产品公司冲销还原
                ALTER BY 20260817-2 shiqingfeng.ex 新增REV001_STEP_17-5 品线挂链-产品公司冲销还原
                ALTER BY 20260817-3 shiqingfeng.ex 新增REV001_STEP_17-6 品线挂链-中国区冲销
                ALTER BY 20260817-4 shiqingfeng.ex 新增REV001_STEP_17-7 费用转政策-中国区冲销
                ALTER BY 20260817-5 shiqingfeng.ex 新增REV001_STEP_17-8 费用转政策-中国区分摊
                ALTER BY 20260817-6 shiqingfeng.ex 新增REV001_STEP_17-9 费用转政策-还原至产品公司
                ALTER BY 20260818-1 shiqingfeng.ex REV001_STEP_17-4/17-5客商逻辑调整：1180默认1001200，12开头公司按MR/非MR公司编码映射，多客商优先取六位A012开头客商
                ALTER BY 20260819-1 fengjianfeng.ex REV001_REV001_STEP_1(收入聚合处理)REV001_STEP_11(成本聚合处理)1增加业务分类取数字段
                ALTER BY 20260820-1 SHIQINGFENG.EX 新增政策手工调整电商BU渠道细分
                ALTER BY 20260820-2 SHIQINGFENG.EX 新增公司三级分类更新逻辑与D表一致
                ALTER BY 20260820-3 SHIQINGFENG.EX CIS逻辑放到D层做，此处取消逻辑
                ALTER BY 20260820-4 取消折算销量-标准量逻辑，直接去D表字段
                ALTER BY 20260820-5 fengjianfeng.ex REV001_STEP_16(中国区-业务分类补充) 20260820FJF_ADD STEP_13/14/15仅更新类别不为ZAMOUNT的数据。20260820FJF_ADD
                ALTER BY 20260820-6 SHIQINGFENG.EX 新增REV_CIS来源
                ALTER BY 20260821-1 CEHNDONG3.EX 修改step17限制条件；新增step11字段cn_class_mark_code,cn_class_mark_name
                ALTER BY 20260821-2 SHIQINGFENG.EX 成本调整数新增D_ECOM_BU字段
                ALTER BY 20260824 XIAOYACHAO.EX 增加6001050000主营业务收入-土地租赁&6001002000主营-软件服务
                ALTER BY 20260824-1 SHIQINGFENG.EX  REV001_STEP_17-8费用转政策-中国区分摊：原因子无法分摊时，回退至所有有效电商BU渠道分摊，并排除REV_01_219冲销行
                ALTER BY 20260825-1 SHIQINGFENG.EX  REV001_STEP_12(销量&收入特殊处理) ①针对于日立折算部分，增加一个规则，当DIM_TYPE=MATERIAL时，折算后销量处理成0 ②除了日立外的公司，折算规则取消，直接取D表的折算销量 注意，只动折算销量这个字段【MAP_ZUM】
                ALTER BY 20260825-2 SHIQINGFENG.EX  新增 落户纸号 Shipping_Order
                ALTER BY 20260825-2 fengjianfeng.EX  STEP_17-4/STEP_17-5 修改取数限制 20260825FJF_ADD
                ALTER BY 20260826 XIAOYACHAO.EX 公司增加6002万高
                ALTER BY 20260826-1 SHIQINGFENG.EX 出库退货新增折算销量-指标口径，折算销量-标准量 业务分类字段
                ALTER BY 20260826-2 SHIQINGFENG.EX STEP_17-4/STEP_17-5 修改对方公司字段取源表公司字段
                ALTER BY 20260826-3 FENGJIANFENG.EX STEP_17-5 D_CHANNEL销售渠道字段放空 20260826FJF_ADD
                ALTER BY 20260827 SHIQINGFENG.EX 新增STEP_17-4/STEP_17-5/STEP_17-6字段
                ALTER BY 20260828 lijunyu.EX 新增原始科目判断，及6012公司部分科目直接重置物料编码为空，取消6515分摊逻辑，改为配置表运行，新增6230特殊分摊程序及成本分摊配置程序
                ALTER BY 20260828 FENGJIANFENG.EX ①通过物料匹配物料大表，若匹配上，如果类别是GA00开头，折算后数量取该物料对应物料大表【SALE_QTY-折算销量系数】*【MAP_QTY-销量2】
                                                  ②若物料不在物料大表内，如果类别是GA00开头，则折算后数量取【MAP_QTY-销量2】 20260828FJF_ADD
                ALTER BY 20260830-1 shexuanxuan.EX 新增ADJM01类别为GA00_BF
                ALTER BY 20260830-2 shexuanxuan.EX ODS_SRC=BSEG 部分，新增MAP_ZUM取数
                ALTER BY LC 20260830 LICHENG.EX DIM_FI_PRODUCT全部修改为DIM_FI_MR_PRODUCT_DD,S600101AD/S600102AD新增类别字段插入
                ALTER BY 20260831 shiqingfeng.ex 取消STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 月结不上
                ALTER BY 20260831-1 shiqingfeng.ex 取消特殊成本分摊 月结不上
                ALTER BY 20260903 XIAOYACHAO.EX 万高增加bseg取数

                EDIT BY LC 20260905 补充中国区其他业务成本取数
                EDIT BY LC 20260905 中国区成本 费用转政策部分 8月月结临时不取数
ALTER BY 20261009 LICHENG.EX 新增REV001_STEP_12_1(TVS销量收入分摊)：2910+科目S6001开头+客商在dim_rule_fi_mr_cust_onoff_ratio(TVS客商对应渠道分组分摊比例配置表)且期间在有效期内的行，先按原行插入等额负值冲销行(D_ADJ_TYPE=REV_01_227)、再按配置渠道分组ratio生成分摊行(D_ADJ_TYPE=REV_01_228，D_ONOFFLINE取配置onoffline_code，销量/收入类字段×ratio)，原行保持不动不删除；客商不在配置表内的行不处理


  手  工 执 行：call CPM_SP_D2M_REV_M('2025ACT','09','6700','1','LICHENG.EX');

  ***************************************************/
    V_SCENARIO        varchar2(30);--传入场景
    V_PERIODO         varchar2(30);--传入期间
    V_SCENARIO_PRE    varchar2(10);--传入场景上期
    V_PERIODO_PRE     varchar2(10);--传入期间上期
    V_YEARMONTH       varchar2(10);--统计年月
    V_YEAR            varchar2(20);--当前年份
    V_MONTH           varchar2(20);--当前月份
    V_AZIENDA         VARCHAR2(4000);--当前组织
    V_SESSION_ID      NUMBER;
    V_6515_COUNT      NUMBER; -- 当前会话组织范围内6515公司数量
BEGIN
-- 获取当前 Session ID
    V_SESSION_ID := SYS_CONTEXT('USERENV', 'SESSIONID');
-- 插入本 Session 数据
    INSERT INTO SESSION_V_REF_AZIENDA (SESSION_ID, HIE, NODE, ELEM)
    SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_AZIENDA
    ;
    INSERT INTO SESSION_V_REF_DEST3_NONAME (SESSION_ID, HIE, NODE, ELEM)
    SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_DEST3_NONAME
    ;
    INSERT INTO SESSION_V_REF_ED_D_ONOFFLINE (SESSION_ID, HIE, NODE, ELEM)
    SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_ED_D_ONOFFLINE
    ;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','0 START',SYSDATE,SESSION_USER,P_SCENARIO,P_PERIODO,P_AZIENDA);
COMMIT;


/*1.1 时间参数初始化*/
V_SCENARIO    := P_SCENARIO;
V_PERIODO     := P_PERIODO;
V_YEAR        := TO_CHAR(SYSDATE+2/24/60,'YYYY');
V_MONTH       := TO_CHAR(SYSDATE+2/24/60,'MM');

IF V_SCENARIO = '1900ACT' AND V_PERIODO='00' THEN
  IF V_MONTH='01' THEN
     V_SCENARIO := (TO_NUMBER(V_YEAR)-1)||'ACT';
     V_PERIODO  := '12';
  ELSE
     V_SCENARIO := V_YEAR||'ACT';
     V_PERIODO  := LPAD((TO_NUMBER(V_MONTH)-1)||'',2,'0');
  END IF;
END IF;

SELECT CASE WHEN V_PERIODO =1 THEN TO_CHAR(TO_NUMBER(SUBSTR(V_SCENARIO,1,4))-1)||'ACT'
         ELSE V_SCENARIO END,
       CASE WHEN V_PERIODO =1 THEN '12' ELSE SUBSTR(100 + TO_NUMBER(V_PERIODO)-1,-2) END
         INTO V_SCENARIO_PRE,V_PERIODO_PRE
 FROM DUAL;
V_YEARMONTH:= SUBSTR(V_SCENARIO,1,4)||V_PERIODO;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','1.1 时间参数初始化完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*1.2 组织参数初始化*/
INSERT INTO SESSION_AZIENDA_LIST(SESSION_ID, ELEM)
SELECT DISTINCT V_SESSION_ID,ELEM
    FROM SESSION_V_REF_AZIENDA
        WHERE ( INSTR(','||P_AZIENDA||',',','||ELEM||',') > 0
                     OR INSTR(','||P_AZIENDA||',',','||NODE||',') > 0
                     )
        AND HIE = '10'
        AND SESSION_ID = V_SESSION_ID
        /*20260127 新增抽取一期公司范围*/
        AND ELEM IN (SELECT COD_AZIENDA
                       FROM AW_RUL_DWMCRS_000001
                      WHERE VALID_FR <= V_YEARMONTH
                        AND NVL(VALID_TO,'999999') >= V_YEARMONTH
                        AND REV_FLAG = 'Y'
                        AND COD_CONTO = 'ZAW_D2M_IN'
                      )
        /*20260226 新增排除锁定公司*/
        AND ELEM NOT IN (SELECT COD_AZIENDA
                       FROM AW_RUL_DWMCRS_000001 T
                      WHERE REV_FLAG = 'Y'
                        AND T.COD_SCENARIO = P_SCENARIO
                        AND T.COD_PERIODO = P_PERIODO
                        AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                        )
        ;


SELECT LISTAGG(ELEM,',') INTO V_AZIENDA
  FROM (SELECT DISTINCT ELEM
    FROM TGK_FIMA_HISENSE.V_REF_AZIENDA
        WHERE ( INSTR(','||P_AZIENDA||',',','||ELEM||',') > 0
                     OR INSTR(','||P_AZIENDA||',',','||NODE||',') > 0
                     )
        AND HIE = '10'
        /*20260127 新增抽取一期公司范围*/
        AND ELEM IN (SELECT COD_AZIENDA
                       FROM AW_RUL_DWMCRS_000001
                      WHERE VALID_FR <= V_YEARMONTH
                        AND NVL(VALID_TO,'999999') >= V_YEARMONTH
                        AND REV_FLAG = 'Y'
                        AND COD_CONTO = 'ZAW_D2M_IN'
                      )
        /*20260226 新增排除锁定公司*/
        AND ELEM NOT IN (SELECT COD_AZIENDA
                       FROM AW_RUL_DWMCRS_000001 T
                      WHERE REV_FLAG = 'Y'
                        AND T.COD_SCENARIO = P_SCENARIO
                        AND T.COD_PERIODO = P_PERIODO
                        AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                        )
        );




INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','1.2 组织参数初始化完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*清空临时表数据*/
 DELETE FROM AW_MR9_REVM01_000001_TEMP ps
  WHERE 1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )
    ;



INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.1 当期数据删除完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

--IF P_ORG_FLAG IN (1,3) THEN
  CPM_SP_A2M_REV_M(p_scenario,P_PERIODO,P_AZIENDA,'A',SESSION_USER);
--END IF;

/*2.2.1 REV001_STEP_1(聚合处理)*/
INSERT  /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP(
    OID
   ,COD_SCENARIO -- 场景
   ,COD_PERIODO -- 期间
   ,COD_AZIENDA -- 公司
   ,COD_CONTO -- 科目
   ,CUST_CODE -- 客商
   ,CUST_NAME -- 客商描述
   ,MATERIAL_CODE -- 物料
   ,MATERIAL_NAME -- 物料描述
   ,COD_DEST1 -- 成本中心
   ,COD_DEST2 -- 产品线
   ,D_CHANNEL -- 销售渠道
   ,D_MODE -- 销售模式
   ,D_ONOFFLINE -- 线上线下
   ,SALE_MODEL_CODE -- 销售型号
   ,MODEL_CODE -- 产品型号
   ,SHOP_CODE -- 门店
   ,SRC_SYSTEM -- 源系统
   ,SOLD_TO_CODE -- 售达方
   ,SOLD_TO_NAME -- 售达方名称
   ,MATERIAL_GROUP_CODE -- 物料组
   ,COD_AZI_CTP -- 对方公司
   ,BATCH_ID -- 批次号
   ,D_PRC_GRP -- 物料定价组
   ,COD_VALUTA -- 货币
   ,COD_VALUTA_ORIGINARIA -- 货币
   ,SRC_DETAIL -- 来源
   ,USERUPD -- 更新用户
   ,DATEUPD -- 更新日期
   ,PROVENIENZA -- 来源系统
   ,BILL_QTY -- 开票数量
   ,SHIP_QTY -- 发货数量
   ,ORDER_QTY -- 订单数量
   ,SALE_REV -- 收入金额
   ,DISCOUNT_1 -- 收入折扣1(含税)
   ,DISCOUNT_3 -- 收入折扣3(含税)
   ,DISCOUNT_4 -- 收入折扣4(含税)
   ,DISCOUNT_5 -- 收入折扣5(含税)
   ,DISCOUNT_6 -- 收入折扣6(含税)
   ,DISCOUNT_30 -- 收入折扣30(含税)
   ,DISCOUNT_34 -- 收入折扣34(含税)
   ,TAX_RATE -- 税率
   ,EXCHANGE_RATE -- 汇率
   ,COD_DEST4 -- 品牌
   ,D_SPEC_SEC -- 规格段
   ,D_PRO_TYPE_S -- 产品形态分类
   ,D_PRO_SSER -- 产品套系
   ,D_QUA_METHOD -- 奥维产品四分法
   ,D_PRO_STAGE -- 产品阶段
   ,D_PRI_RANGE -- 价格段
   ,D_PRO_SERIES -- 产品系列
   ,D_MARKET_PNT -- 营销定位
   ,D_TECH_TYPE -- 技术类型
   ,D_PRO_CLASS -- 产品类别
   ,D_MODEL_LCA -- 产品型号生命周期
   ,D_PRO_TYPE -- 产品类型
   ,CUST_UNITY_NAME -- 统一客户组
   ,CREDIT_LEVEL_NAME -- 信用等级
   ,CUST_NATURE_NAME -- 单位性质
   ,CUST_TYPE_NAME -- 客户类型
   ,SHOP_NAME -- 门店名称
   ,SALE_MODEL_NAME -- 销售型号描述
   ,MODEL_NAME -- 产品线型号描述
   ,D_CNL_C_TYPE -- 渠道客户大类小类
   ,D_IND_C_TYPE -- 行业客户大类小类
   ,D_ECOM_BU -- 电商BU渠道细分
   ,D_SALE_DEPT -- 业务管理单元
   ,COD_DEST3 -- 业务范围
   ,AGENCY_CODE -- 销售部门编码
   ,AGENCY_NAME -- 销售部门描述
   ,IS_MINILED_CODE -- 是否MiniLED编码
   ,D_BU_TRAN -- 事业部内外标识
   ,CUSTOMER_MODEL -- 客户型号
   ,ORDER_TYPE_CODE -- 订单类型
   ,zcalasset --按套统计
   ,CN_CLASS_MARK_CODE --中国区品类标记编码
   ,CN_CLASS_MARK_NAME --中国区品类标记描述
   ,SALE_CERT_TYPE --销售凭证类型
   ,D_ADJ_TYPE --调整类型
   ,ORG_REV
   ,MATERIAL_GROUP_NAME
   ,BAC_SRC_AZIENDA
   ,maktx_s810
   ,D_BUS_SCE_S --业务场景分类
   ,D_MINILED --MiniLED类型
   ,invoice_code --金税发票号
   ,D_OPER_TYPE --业务分类
   ,STD_QTY
   ,MAP_ZUM
   ,Shipping_Order
   --20260917FJF_ADD 二期新增字段
   ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP
)

SELECT
      NEWID() AS OID
    , P_SCENARIO AS COD_SCENARIO
    , MONTH AS COD_PERIODO
    , COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA
    , CASE
         /*20260724-1 优先级最高 当映射前科目为 5101099006 时输出 S600113-主营业务收入-总账调整-返利价差-OEM*/
         WHEN ACCT_SRC_CODE = '5101099006' THEN 'S600113'
         /*EDIT BY LC 20261009 当ods_src为ZTFI313A且order_type_code为ZRCR/ZRDR且映射后科目为6001开头则输出‘S600114-主营业务收入-TVS返利价差’*/
         WHEN ODS_SRC = 'ZTFI313A' AND ORDER_TYPE_CODE IN ('ZRCR','ZRDR') AND ACCT_MAP_CODE LIKE '6001%' THEN 'S600114'
         WHEN COMPANY_CODE = '6098' AND ACCT_SRC_CODE IN ('6001000000','6001010000') THEN 'S600100'
         /*EDIT BY LC 20261009 来源由 GLPCA 扩展为 ZTFI313A，映射后科目为 6001 开头且 ACCT_MAP_CODE = '6001020000'，输出 S600111-主营业务收入-总账调整-返利价差*/
         WHEN ODS_SRC IN ('GLPCA','ZTFI313A') AND ACCT_MAP_CODE LIKE '6001%' AND ACCT_MAP_CODE = '6001020000' THEN 'S600111'
         WHEN ACCT_MAP_CODE LIKE '6001%' AND ACCT_SRC_CODE = '5101030000'THEN 'S600111'
         WHEN ACCT_MAP_CODE LIKE '6001%' THEN 'S600100' ELSE 'S605100'
       END AS COD_CONTO
    , CUST_CODE
    , CUST_NAME
    , MATERIAL_CODE
    , MATERIAL_NAME
    , NVL(COST_CENTER_CODE,'ZZZZ') AS COD_DEST1
    , NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') AS COD_DEST2
    , COALESCE(CHANNEL_L3_CODE, 'ZZZZ') AS D_CHANNEL
    , COALESCE(MARKETING_MODE_CODE, 'ZZZZ') AS D_MODE
    , COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE
    , COALESCE(SALE_MODEL_CODE, 'ZZZZ') AS SALE_MODEL_CODE
    , COALESCE(MODEL_CODE, 'ZZZZ') AS MODEL_CODE
    , COALESCE(SHOP_CODE, 'ZZZZ') AS SHOP_CODE
    , SYSTEM_SRC AS SRC_SYSTEM
    , SOLD_TO_CODE
    , SOLD_TO_NAME
    -- , MATERIAL_GROUP_CODE
    -- ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line
    , product_line_code AS MATERIAL_GROUP_CODE
    , CP_COMPANY_CODE
    , BATCH_ID
    , MATERIAL_PRICING_GROUP_CODE AS D_PRC_GRP
    , COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA
    , COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA_ORIGINARIA
    , UPPER(ODS_SRC) AS SRC_DETAIL
    , SESSION_USER AS USERUPD
    , SYSDATE AS DATEUPD
    , 'CPM_SP_D2M_REV_M' AS PROVENIENZA
    , SUM(CASE WHEN BILL_TYPE_CODE IN ('ZG2','ZL2') AND ODS_SRC IN ('GLPCA') THEN 0
              WHEN ODS_SRC IN ('GLPCA') THEN 0-NVL(BILL_QTY,0) ELSE NVL(BILL_QTY,0) END) AS BILL_QTY
    , SUM(NVL(SHIP_QTY,0)) AS SHIP_QTY
    , SUM(NVL(ORDER_QTY,0)) AS ORDER_QTY
    , SUM(NVL(REV_SALE_AMT,0)) AS SALE_REV
    /*EDIT BY LC 20261015 2910-TVS 的 DISCOUNT_1 取 rebate7/8/9/11/12/13/14/15/19_amt 九项合计，直接进数（不再按 DATI_CAMBIO.CAMBIO_PERIODO 折算人民币）*/
    , CASE WHEN COALESCE(COMPANY_CODE, 'ZZZZ') = '2910'
           THEN NVL(SUM(NVL(rebate7_amt,0)+NVL(rebate8_amt,0)+NVL(rebate9_amt,0)+NVL(rebate11_amt,0)+NVL(rebate12_amt,0)+NVL(rebate13_amt,0)+NVL(rebate14_amt,0)+NVL(rebate15_amt,0)+NVL(rebate19_amt,0)), 0)
           ELSE SUM(NVL(DISCOUNT1_AMT,0))
       END AS DISCOUNT_1
    , SUM(NVL(DISCOUNT3_AMT,0)) AS DISCOUNT_3
    , SUM(NVL(DISCOUNT4_AMT,0)) AS DISCOUNT_4
    , SUM(NVL(DISCOUNT5_AMT,0)) AS DISCOUNT_5
    , SUM(NVL(DISCOUNT6_AMT,0)) AS DISCOUNT_6
    , SUM(NVL(DISCOUNT30_AMT,0)) AS DISCOUNT_30
    , SUM(NVL(DISCOUNT34_AMT,0)) AS DISCOUNT_34
    , TAX_RATE
    , EXCHANGE_RATE
    , COALESCE(BRAND_CODE, 'ZZZZ') AS COD_DEST4
    , COALESCE(SPEC_SECTION_CODE, 'ZZZZ') AS D_SPEC_SEC
    , COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE_S
    , COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') AS D_PRO_SSER
    , COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') AS D_QUA_METHOD
    , COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') AS D_PRO_STAGE
    , COALESCE(PRICE_RANGE_CODE, 'ZZZZ') AS D_PRI_RANGE
    , COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') AS D_PRO_SERIES
    , COALESCE(MARKET_PNT_CODE, 'ZZZZ') AS D_MARKET_PNT
    , COALESCE(TECH_TYPE_CODE, 'ZZZZ') AS D_TECH_TYPE
    , COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') AS D_PRO_CLASS
    , COALESCE(MODEL_LCA_CODE, 'ZZZZ') AS D_MODEL_LCA
    , COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE
    , CUST_UNITY_NAME
    , CREDIT_LEVEL_NAME
    , CUST_NATURE_NAME
    , CUST_TYPE_NAME
    , SHOP_NAME
    , SALE_MODEL_NAME
    , MODEL_NAME
    , COALESCE(channel_small_class_code, 'ZZZZ') AS D_CNL_C_TYPE
    , COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') AS D_IND_C_TYPE
    , COALESCE(COMM_BU_CODE, 'ZZZZ') AS D_ECOM_BU
    , COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') AS D_SALE_DEPT
    , COALESCE(BUS_RANGE_CODE, 'ZZZZ') AS COD_DEST3
    , AGENCY_CODE
    , AGENCY_NAME
    , IS_MINILED_CODE
    , 'ZZZZ' AS D_BU_TRAN
    , CUSTOMER_MODEL
    , ORDER_TYPE_CODE
    , zcalasset
    , CN_CLASS_MARK_CODE
    , CN_CLASS_MARK_NAME
    , SALE_CERT_TYPE
    , 'ZZZZ' AS D_ADJ_TYPE  --调整类型
    , SUM(NVL(rev_sale_bcy_amt,0)) AS ORG_REV
    -- , MATERIAL_GROUP_NAME
    -- ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line
    , product_line_name AS MATERIAL_GROUP_NAME
    , BR_COMPANY_CODE AS BAC_SRC_AZIENDA
    , maktx_s810
    , bus_sce_cat_code AS D_BUS_SCE_S --业务场景分类
    , miniled_type_code AS D_MINILED-- MiniLED类型
    , invoice_code --金税发票号
    , bus_type_code as D_OPER_TYPE --业务分类
    , SUM(STD_QTY) AS STD_QTY
    , SUM(MAP_ZUM_QTY) AS MAP_ZUM
    ,Shipping_Order

   --20260917FJF_ADD 二期新增字段
    ,ee_level_code AS D_EFF_CLASS   --能效等级
    ,bu_code AS D_BU_SHOP     --门店所属BU
    ,niche_ec_store_code AS D_EC_STORE    --电商细分店铺
    ,map_channel_l3_code AS MAP_D_CHANNEL --映射公司三级分类编码
    ,map_comm_bu_code AS MAP_D_ECOM_BU --映射电商BU渠道细分编码
    ,CUST_UNITY_CODE AS D_UNICUSTGRP  --统一客户组编码
 FROM  DWD_FI_MR_GP_MSUM_MI_LCTEST MI
WHERE 1 = P_ORG_FLAG
  AND DT_MONTH = V_YEARMONTH
  AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST S1 WHERE SESSION_ID = V_SESSION_ID
                         AND NOT EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S2
                                         WHERE S1.SESSION_ID =S2.SESSION_ID AND S2.ELEM =S1.ELEM
                                         AND S2.HIE = '10'  AND S2.NODE IN ('020')
                                        )
                                        )
  --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
  AND COMPANY_CODE NOT IN ('80J0')  -- 该公司从国际营销管报环境获取
  --EDIT BY LC 20260606 剔除国际营销公司取数
  /*AND COMPANY_CODE NOT IN (SELECT ELEM
                           FROM SESSION_V_REF_AZIENDA
                           WHERE SESSION_ID = V_SESSION_ID
                             AND HIE = '10'
                             AND NODE IN ('020')
                          )*/
  AND (
  /*20260820-6 SHIQINGFENG.EX 新增REV_CIS来源*/
       /*20260318 SXX修改 新增：TVS 销售明细来源 ZTFI313A 放行*/
       (ODS_SRC IN ('VBRP','SMS_RL','GSMS_RL','REV_CIS','ZTFI313A') OR ODS_SRC IN ('GLPCA')
       AND GENERAL_LEDGER = '8A'AND RECORD_TYPE = 0 AND INIT_OBJECT_TYPE IN ('01','05','14','45') AND ACCT_SRC_CODE LIKE '5101%'
       )
       /*20260414ZZS新增：对于6098公司，限制只取6001000000、6001010000科目的数据，放S600100-主营业务收入
       20260422  取消6098特殊逻辑
       */
       --OR (COMPANY_CODE = '6098' AND ACCT_SRC_CODE IN ('6001000000','6001010000'))
       )

GROUP BY
   CONCAT(YEAR,'ACT')
  ,MONTH
  ,COALESCE(COMPANY_CODE, 'ZZZZ')
    , CASE
         /*20260724-1 优先级最高 当映射前科目为 5101099006 时输出 S600113-主营业务收入-总账调整-返利价差-OEM*/
         WHEN ACCT_SRC_CODE = '5101099006' THEN 'S600113'
         /*EDIT BY LC 20261009 当ods_src为ZTFI313A且order_type_code为ZRCR/ZRDR且映射后科目为6001开头则输出‘S600114-主营业务收入-TVS返利价差’*/
         WHEN ODS_SRC = 'ZTFI313A' AND ORDER_TYPE_CODE IN ('ZRCR','ZRDR') AND ACCT_MAP_CODE LIKE '6001%' THEN 'S600114'
         WHEN COMPANY_CODE = '6098' AND ACCT_SRC_CODE IN ('6001000000','6001010000') THEN 'S600100'
         /*EDIT BY LC 20261009 来源由 GLPCA 扩展为 ZTFI313A，映射后科目为 6001 开头且 ACCT_MAP_CODE = '6001020000'，输出 S600111-主营业务收入-总账调整-返利价差*/
         WHEN ODS_SRC IN ('GLPCA','ZTFI313A') AND ACCT_MAP_CODE LIKE '6001%' AND ACCT_MAP_CODE = '6001020000' THEN 'S600111'
         WHEN ACCT_MAP_CODE LIKE '6001%' AND ACCT_SRC_CODE = '5101030000'THEN 'S600111'
         WHEN ACCT_MAP_CODE LIKE '6001%' THEN 'S600100' ELSE 'S605100'
       END
  ,CUST_CODE
  ,CUST_NAME
  ,MATERIAL_CODE
  ,MATERIAL_NAME
  ,NVL(COST_CENTER_CODE,'ZZZZ')
  ,NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ')
  ,COALESCE(CHANNEL_L3_CODE, 'ZZZZ')
  ,COALESCE(MARKETING_MODE_CODE, 'ZZZZ')
  ,COALESCE(ONOFFLINE_CODE, 'ZZZZ')
  ,COALESCE(SALE_MODEL_CODE, 'ZZZZ')
  ,COALESCE(MODEL_CODE, 'ZZZZ')
  ,COALESCE(SHOP_CODE, 'ZZZZ')
  ,SYSTEM_SRC
  ,SOLD_TO_CODE
  ,SOLD_TO_NAME
  -- ,MATERIAL_GROUP_CODE
  -- ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line
  ,product_line_code
  ,CP_COMPANY_CODE
  ,BATCH_ID
  ,MATERIAL_PRICING_GROUP_CODE
  ,COALESCE(QCY_CODE, 'ZZZZ')
  ,COALESCE(QCY_CODE, 'ZZZZ')
  ,UPPER(ODS_SRC)
  ,TAX_RATE
  ,EXCHANGE_RATE
  ,COALESCE(BRAND_CODE, 'ZZZZ')
  ,COALESCE(SPEC_SECTION_CODE, 'ZZZZ')
  ,COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ')
  ,COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ')
  ,COALESCE(QUARTER_METHOD_CODE, 'ZZZZ')
  ,COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ')
  ,COALESCE(PRICE_RANGE_CODE, 'ZZZZ')
  ,COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ')
  ,COALESCE(MARKET_PNT_CODE, 'ZZZZ')
  ,COALESCE(TECH_TYPE_CODE, 'ZZZZ')
  ,COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ')
  ,COALESCE(MODEL_LCA_CODE, 'ZZZZ')
  ,COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ')
  ,CUST_UNITY_NAME
  ,CREDIT_LEVEL_NAME
  ,CUST_NATURE_NAME
  ,CUST_TYPE_NAME
  ,SHOP_NAME
  ,SALE_MODEL_NAME
  ,MODEL_NAME
  ,COALESCE(channel_small_class_code, 'ZZZZ')
  ,COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ')
  ,COALESCE(COMM_BU_CODE, 'ZZZZ')
  ,COALESCE(MARKETING_DEPT_CODE, 'ZZZZ')
  ,COALESCE(BUS_RANGE_CODE, 'ZZZZ')
  ,AGENCY_CODE
  ,AGENCY_NAME
  ,IS_MINILED_CODE
  ,CUSTOMER_MODEL
  ,ORDER_TYPE_CODE
  ,zcalasset
  ,CN_CLASS_MARK_CODE
  ,CN_CLASS_MARK_NAME
  ,SALE_CERT_TYPE
  -- ,MATERIAL_GROUP_NAME
  -- ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line
  ,product_line_name
  ,BR_COMPANY_CODE
  ,maktx_s810
  ,bus_sce_cat_code
  ,miniled_type_code
  ,invoice_code
  , bus_type_code
  ,Shipping_Order
  --20260917FJF_ADD 二期新增字段
  ,ee_level_code,bu_code,niche_ec_store_code,map_channel_l3_code,map_comm_bu_code,CUST_UNITY_CODE
HAVING SUM(CASE WHEN BILL_TYPE_CODE IN ('ZG2','ZL2') AND ODS_SRC IN ('GLPCA') THEN 0
              WHEN ODS_SRC IN ('GLPCA') THEN 0-NVL(BILL_QTY,0) ELSE NVL(BILL_QTY,0) END) <> 0
    OR SUM(NVL(SHIP_QTY,0)) <> 0
    OR SUM(NVL(ORDER_QTY,0)) <> 0
    OR SUM(NVL(REV_SALE_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT1_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT3_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT4_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT5_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT6_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT30_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT34_AMT,0)) <> 0
    ;

INSERT /*+ PARALLEL(2) */  INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_MODE, -- 销售模式
    D_ONOFFLINE, -- 线上线下
    SALE_MODEL_CODE, -- 销售型号
    MODEL_CODE, -- 产品型号
    SHOP_CODE, -- 门店
    SRC_SYSTEM, -- 源系统
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    MATERIAL_GROUP_CODE, -- 物料组
    COD_AZI_CTP, -- 对方公司
    BATCH_ID, -- 批次号
    D_PRC_GRP, -- 物料定价组
    COD_VALUTA, -- 货币
    COD_VALUTA_ORIGINARIA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    BILL_QTY, -- 开票数量
    SHIP_QTY, -- 发货数量
    ORDER_QTY, -- 订单数量
    SALE_REV, -- 收入金额
    DISCOUNT_1, -- 收入折扣1(含税)
    DISCOUNT_3, -- 收入折扣3(含税)
    DISCOUNT_4, -- 收入折扣4(含税)
    DISCOUNT_5, -- 收入折扣5(含税)
    DISCOUNT_6, -- 收入折扣6(含税)
    DISCOUNT_30, -- 收入折扣30(含税)
    DISCOUNT_34, -- 收入折扣34(含税)
    TAX_RATE, -- 税率
    EXCHANGE_RATE, -- 汇率
    COD_DEST4, -- 品牌
    D_SPEC_SEC, -- 规格段
    D_PRO_TYPE_S, -- 产品形态分类
    D_PRO_SSER, -- 产品套系
    D_QUA_METHOD, -- 奥维产品四分法
    D_PRO_STAGE, -- 产品阶段
    D_PRI_RANGE, -- 价格段
    D_PRO_SERIES, -- 产品系列
    D_MARKET_PNT, -- 营销定位
    D_TECH_TYPE, -- 技术类型
    D_PRO_CLASS, -- 产品类别
    D_MODEL_LCA, -- 产品型号生命周期
    D_PRO_TYPE, -- 产品类型
    CUST_UNITY_NAME, -- 统一客户组
    CREDIT_LEVEL_NAME, -- 信用等级
    CUST_NATURE_NAME, -- 单位性质
    CUST_TYPE_NAME, -- 客户类型
    SHOP_NAME, -- 门店名称
    SALE_MODEL_NAME, -- 销售型号描述
    MODEL_NAME, -- 产品线型号描述
    D_CNL_C_TYPE, -- 渠道客户大类小类
    D_IND_C_TYPE, -- 行业客户大类小类
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    AGENCY_CODE, -- 销售部门编码
    AGENCY_NAME, -- 销售部门描述
    IS_MINILED_CODE, -- 是否MiniLED编码
    D_BU_TRAN, -- 事业部内外标识
    CUSTOMER_MODEL, -- 客户型号
    ORDER_TYPE_CODE -- 订单类型
    ,zcalasset,  --按套统计
    CN_CLASS_MARK_CODE,  --中国区品类标记编码
    CN_CLASS_MARK_NAME,  --中国区品类标记描述
    SALE_CERT_TYPE,  --销售凭证类型
    D_ADJ_TYPE,  --调整类型
    ORG_REV
    ,MATERIAL_GROUP_NAME
    ,maktx_s810
    ,BAC_SRC_AZIENDA
    ,D_BUS_SCE_S --业务场景分类
    ,D_MINILED-- MiniLED类型
    ,Shipping_Order
    ,MAP_ZUM
    ,STD_QTY
    ,D_OPER_TYPE
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP
)

 SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     P_PERIODO AS COD_PERIODO,
     COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA,
     'S600102' AS COD_CONTO,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     NVL(COST_CENTER_CODE,'ZZZZ') AS COD_DEST1,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') AS COD_DEST2,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') AS D_CHANNEL,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') AS D_MODE,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE,
     /* COALESCE( 'ZZZZ') AS D_SALEINOUT, */
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') AS SALE_MODEL_CODE,
     COALESCE(MODEL_CODE, 'ZZZZ') AS MODEL_CODE,
     COALESCE(SHOP_CODE, 'ZZZZ') AS SHOP_CODE,
     SYSTEM_SRC AS SRC_SYSTEM,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE AS D_PRC_GRP,
      /* MATERIAL_PRICING_GROUP_NAME AS MPG_NAME, */
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA,
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA_ORIGINARIA,
     UPPER(ODS_SRC) AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(BILL_QTY,0)) AS BILL_QTY,
     SUM(NVL(SHIP_QTY,0)) AS SHIP_QTY,
     SUM(NVL(ORDER_QTY,0)) AS ORDER_QTY,
     SUM(NVL(REV_SALE_AMT,0)) AS SALE_REV,
     SUM(NVL(DISCOUNT1_AMT,0)) AS DISCOUNT_1,
     SUM(NVL(DISCOUNT3_AMT,0)) AS DISCOUNT_3,
     SUM(NVL(DISCOUNT4_AMT,0)) AS DISCOUNT_4,
     SUM(NVL(DISCOUNT5_AMT,0)) AS DISCOUNT_5,
     SUM(NVL(DISCOUNT6_AMT,0)) AS DISCOUNT_6,
     SUM(NVL(DISCOUNT30_AMT,0)) AS DISCOUNT_30,
     SUM(NVL(DISCOUNT34_AMT,0)) AS DISCOUNT_34,
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') AS COD_DEST4,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') AS D_SPEC_SEC,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE_S,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') AS D_PRO_SSER,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') AS D_QUA_METHOD,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') AS D_PRO_STAGE,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') AS D_PRI_RANGE,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') AS D_PRO_SERIES,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') AS D_MARKET_PNT,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') AS D_TECH_TYPE,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') AS D_PRO_CLASS,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') AS D_MODEL_LCA,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') AS D_CNL_C_TYPE,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') AS D_IND_C_TYPE,
     COALESCE(COMM_BU_CODE, 'ZZZZ') AS D_ECOM_BU,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') AS D_SALE_DEPT,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') AS COD_DEST3,
      AGENCY_CODE,
      AGENCY_NAME,
      IS_MINILED_CODE,
      D_BU_TRAN, -- 事业部内外标识
      CUSTOMER_MODEL, -- 客户型号
      ORDER_TYPE_CODE,
      zcalasset,
      CN_CLASS_MARK_CODE,
      CN_CLASS_MARK_NAME,
      SALE_CERT_TYPE,
      '' AS D_ADJ_TYPE,  --调整类型
     SUM(NVL(rev_sale_bcy_amt,0)) AS ORG_REV
     ,MATERIAL_GROUP_NAME
     ,maktx_s810
     ,BAC_SRC_AZIENDA
     ,bus_sce_cat_code AS D_BUS_SCE_S --业务场景分类
     ,miniled_type_code AS D_MINILED-- MiniLED类型
     ,Shipping_Order
     ,SUM(NVL(MAP_ZUM_QTY,0)) AS MAP_ZUM_QTY
      ,SUM(NVL(STD_QTY,0)) AS STD_QTY
      ,BUS_TYPE_CODE
      --,BUS_TYPE_NAME
      --20260917FJF_ADD 二期新增字段
      ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP
  FROM(
       SELECT
       YEAR, MONTH, COMPANY_CODE, CUST_CODE, CUST_NAME, MATERIAL_CODE,
       MATERIAL_NAME , PROFITCENTER_CODE, CHANNEL_L3_CODE, MARKETING_MODE_CODE, ONOFFLINE_CODE,
        SALE_MODEL_CODE, MODEL_CODE, SHOP_CODE, SYSTEM_SRC,
       -- SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, CP_COMPANY_CODE, BATCH_ID,
       SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, CP_COMPANY_CODE, BATCH_ID,
       MATERIAL_PRICING_GROUP_CODE, MATERIAL_PRICING_GROUP_NAME, QCY_CODE,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN  UPPER(ODS_SRC) ELSE UPPER(ODS_SRC)||'_LM' END AS ODS_SRC,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN -BILL_QTY ELSE BILL_QTY END AS BILL_QTY,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN -SHIP_QTY ELSE SHIP_QTY END AS SHIP_QTY,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN -ORDER_QTY ELSE ORDER_QTY END AS ORDER_QTY,
       /* 2026-11-16 V7.2（C-042）：交易币同本位币一起翻（CKTH 为贷方为负；且 STEP_7 的 ELSE SALE_REV 会用本列覆盖 ORG_REV，两列必须同向） */
       CASE WHEN DT_MONTH = V_YEARMONTH THEN -REV_SALE_AMT ELSE REV_SALE_AMT END AS REV_SALE_AMT,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN DISCOUNT1_AMT ELSE -DISCOUNT1_AMT END AS DISCOUNT1_AMT,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN DISCOUNT3_AMT ELSE -DISCOUNT3_AMT END AS DISCOUNT3_AMT,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN DISCOUNT4_AMT ELSE -DISCOUNT4_AMT END AS DISCOUNT4_AMT,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN DISCOUNT5_AMT ELSE -DISCOUNT5_AMT END AS DISCOUNT5_AMT,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN DISCOUNT6_AMT ELSE -DISCOUNT6_AMT END AS DISCOUNT6_AMT,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN -DISCOUNT30_AMT ELSE DISCOUNT30_AMT END AS DISCOUNT30_AMT,
       CASE WHEN DT_MONTH = V_YEARMONTH THEN -DISCOUNT34_AMT ELSE DISCOUNT34_AMT END AS DISCOUNT34_AMT,
       TAX_RATE, EXCHANGE_RATE,BRAND_CODE, SPEC_SECTION_CODE, PRODUCT_SHAPE_TYPE_CODE, PRODUCT_SALE_SERIES_CODE,
       QUARTER_METHOD_CODE, PRODUCT_STAGE_CODE, PRICE_RANGE_CODE, PRODUCT_SERIES_CODE,
       PRODUCT_SMALL_CLASS_CODE, MARKET_PNT_CODE, TECH_TYPE_CODE, MODEL_LCA_CODE, PRODUCT_TYPE_CODE,
       CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SHOP_NAME,
       SALE_MODEL_NAME, MODEL_NAME, channel_small_class_code,IND_SMALL_CLASS_CODE,COMM_BU_CODE,
       MARKETING_DEPT_CODE,BUS_RANGE_CODE,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,
       '' AS D_BU_TRAN
      , CUSTOMER_MODEL,ORDER_TYPE_CODE
      , zcalasset,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE
      , /* 2026-11-16 V7.1（C-042）：CKTH 的 rev_sale_bcy_amt 是「贷方为负」，退货本月必须输出正值
           （S600102 以正数冲减收入），故本月取负、上月直传。数量列与生产一致，不动；
           出库未开段方向相反、同批改（见下）。 */
        CASE WHEN DT_MONTH = V_YEARMONTH THEN -NVL(rev_sale_bcy_amt,0) ELSE NVL(rev_sale_bcy_amt,0) END AS rev_sale_bcy_amt
      , MATERIAL_GROUP_NAME
      , COST_CENTER_CODE
      , maktx_s810
      , BR_COMPANY_CODE AS BAC_SRC_AZIENDA
      , bus_sce_cat_code
      , bus_sce_cat_name
      , miniled_type_code
      ,Shipping_Order
      ,CASE WHEN DT_MONTH = V_YEARMONTH THEN -MAP_ZUM_QTY ELSE MAP_ZUM_QTY END AS MAP_ZUM_QTY
      ,CASE WHEN DT_MONTH = V_YEARMONTH THEN -STD_QTY ELSE STD_QTY END AS STD_QTY
      ,BUS_TYPE_CODE
     -- ,BUS_TYPE_NAME
     --20260917FJF_ADD 二期新增字段
      ,ee_level_code AS D_EFF_CLASS   --能效等级
      ,bu_code AS D_BU_SHOP     --门店所属BU
      ,niche_ec_store_code AS D_EC_STORE    --电商细分店铺
      ,map_channel_l3_code AS MAP_D_CHANNEL --映射公司三级分类编码
      ,map_comm_bu_code AS MAP_D_ECOM_BU --映射电商BU渠道细分编码
      ,CUST_UNITY_CODE AS D_UNICUSTGRP  --统一客户组编码
     FROM DWD_FI_MR_GP_MSUM_CKTH_MI MI
    WHERE 1=P_ORG_FLAG
      AND (
            DT_MONTH = V_YEARMONTH OR DT_MONTH = TO_CHAR(ADD_MONTHS(TO_DATE(V_YEARMONTH,'YYYYMM'), -1), 'YYYYMM')
          )
      AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
      --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
      AND COMPANY_CODE NOT IN ('80J0')  -- 该公司从国际营销管报环境获取
      AND ODS_SRC in ('ZTSO04_TH', 'ZTSO04_TH_045')
)T1
GROUP BY
     COALESCE(COMPANY_CODE, 'ZZZZ') ,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     NVL(COST_CENTER_CODE,'ZZZZ') ,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') ,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') ,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') ,
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') ,
     COALESCE(MODEL_CODE, 'ZZZZ') ,
     COALESCE(SHOP_CODE, 'ZZZZ') ,
     SYSTEM_SRC ,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE ,
     COALESCE(QCY_CODE, 'ZZZZ') ,
     COALESCE(QCY_CODE, 'ZZZZ') ,
     UPPER(ODS_SRC) ,
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') ,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') ,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') ,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') ,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') ,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') ,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') ,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(COMM_BU_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') ,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') ,
      AGENCY_CODE,
      AGENCY_NAME,
      IS_MINILED_CODE,
      D_BU_TRAN, -- 事业部内外标识
      CUSTOMER_MODEL, -- 客户型号
      ORDER_TYPE_CODE,
      zcalasset,
      CN_CLASS_MARK_CODE,
      CN_CLASS_MARK_NAME,
      SALE_CERT_TYPE,
      MATERIAL_GROUP_NAME
      ,maktx_s810
      ,BAC_SRC_AZIENDA
      ,bus_sce_cat_code
      ,miniled_type_code
      ,Shipping_Order
      ,BUS_TYPE_CODE
      --,BUS_TYPE_NAME
      --20260917FJF_ADD 二期新增字段
      ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP
HAVING SUM(NVL(BILL_QTY,0)) <> 0
    OR SUM(NVL(SHIP_QTY,0)) <> 0
    OR SUM(NVL(ORDER_QTY,0)) <> 0
    OR SUM(NVL(REV_SALE_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT1_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT3_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT4_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT5_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT6_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT30_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT34_AMT,0)) <> 0
    OR SUM(NVL(rev_sale_bcy_amt,0)) <> 0
    OR SUM(NVL(MAP_ZUM_QTY,0)) <> 0
    OR SUM(NVL(STD_QTY,0)) <> 0
;
COMMIT;

INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_MODE, -- 销售模式
    D_ONOFFLINE, -- 线上线下
    SALE_MODEL_CODE, -- 销售型号
    MODEL_CODE, -- 产品型号
    SHOP_CODE, -- 门店
    SRC_SYSTEM, -- 源系统
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    MATERIAL_GROUP_CODE, -- 物料组
    COD_AZI_CTP, -- 对方公司
    BATCH_ID, -- 批次号
    D_PRC_GRP, -- 物料定价组
    COD_VALUTA, -- 货币
    COD_VALUTA_ORIGINARIA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    BILL_QTY, -- 开票数量
    SHIP_QTY, -- 发货数量
    ORDER_QTY, -- 订单数量
    SALE_REV, -- 收入金额
    DISCOUNT_1, -- 收入折扣1(含税)
    DISCOUNT_3, -- 收入折扣3(含税)
    DISCOUNT_4, -- 收入折扣4(含税)
    DISCOUNT_5, -- 收入折扣5(含税)
    DISCOUNT_6, -- 收入折扣6(含税)
    DISCOUNT_30, -- 收入折扣30(含税)
    DISCOUNT_34, -- 收入折扣34(含税)
    TAX_RATE, -- 税率
    EXCHANGE_RATE, -- 汇率
    COD_DEST4, -- 品牌
    D_SPEC_SEC, -- 规格段
    D_PRO_TYPE_S, -- 产品形态分类
    D_PRO_SSER, -- 产品套系
    D_QUA_METHOD, -- 奥维产品四分法
    D_PRO_STAGE, -- 产品阶段
    D_PRI_RANGE, -- 价格段
    D_PRO_SERIES, -- 产品系列
    D_MARKET_PNT, -- 营销定位
    D_TECH_TYPE, -- 技术类型
    D_PRO_CLASS, -- 产品类别
    D_MODEL_LCA, -- 产品型号生命周期
    D_PRO_TYPE, -- 产品类型
    CUST_UNITY_NAME, -- 统一客户组
    CREDIT_LEVEL_NAME, -- 信用等级
    CUST_NATURE_NAME, -- 单位性质
    CUST_TYPE_NAME, -- 客户类型
    SHOP_NAME, -- 门店名称
    SALE_MODEL_NAME, -- 销售型号描述
    MODEL_NAME, -- 产品线型号描述
    D_CNL_C_TYPE, -- 渠道客户大类小类
    D_IND_C_TYPE, -- 行业客户大类小类
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    AGENCY_CODE, -- 销售部门编码
    AGENCY_NAME, -- 销售部门描述
    IS_MINILED_CODE, -- 是否MiniLED编码
    D_BU_TRAN, -- 事业部内外标识
    CUSTOMER_MODEL, -- 客户型号
    ORDER_TYPE_CODE -- 订单类型
  ,zcalasset,  --按套统计
  CN_CLASS_MARK_CODE,  --中国区品类标记编码
  CN_CLASS_MARK_NAME,  --中国区品类标记描述
  SALE_CERT_TYPE,  --销售凭证类型
  D_ADJ_TYPE,  --调整类型
  ORG_REV
   ,BCY_REV --销售收入-本位币（调整进）
  --,GFCFY_AMOUNT --价差转费用(日立专用)
  --,GFCFL_AMOUNT --费用转价差(日立专用)
  ,MATERIAL_GROUP_NAME
  ,maktx_s810
  ,D_BUS_SCE_S --业务场景分类
  ,D_MINILED-- MiniLED类型
  ,invoice_code --金税发票号
   ,Shipping_Order
   ,MAP_ZUM
      ,STD_QTY
      ,D_OPER_TYPE
      --,BUS_TYPE_NAME
      --20260917FJF_ADD 二期新增字段
      ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP
)

SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     P_PERIODO AS COD_PERIODO,
     COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA,
     'S600101' AS COD_CONTO,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     NVL(COST_CENTER_CODE,'ZZZZ') AS COD_DEST1,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') AS COD_DEST2,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') AS D_CHANNEL,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') AS D_MODE,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE,
     /* COALESCE( 'ZZZZ') AS D_SALEINOUT, */
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') AS SALE_MODEL_CODE,
     COALESCE(MODEL_CODE, 'ZZZZ') AS MODEL_CODE,
     COALESCE(SHOP_CODE, 'ZZZZ') AS SHOP_CODE,
     SYSTEM_SRC AS SRC_SYSTEM,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE AS D_PRC_GRP,
      /* MATERIAL_PRICING_GROUP_NAME AS MPG_NAME, */
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA,
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA_ORIGINARIA,
     UPPER(ODS_SRC) AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(BILL_QTY,0)) AS BILL_QTY,
     SUM(NVL(SHIP_QTY,0)) AS SHIP_QTY,
     SUM(NVL(ORDER_QTY,0)) AS ORDER_QTY,
     SUM(NVL(REV_SALE_AMT,0)) AS SALE_REV,
     /*CASE WHEN MATERIAL_CODE IN (SELECT material_code FROM AW_RUL_REVEMA_000001 WHERE COD_CONTO = 'ZAW_DWD_LIST_ZHEKOU'
       AND V_YEARMONTH between valid_fr AND valid_to) THEN SUM(NVL(rev_sale_amt,0)) ELSE SUM(NVL(DISCOUNT1_AMT,0)) END AS DISCOUNT_1,*/
     SUM(NVL(DISCOUNT1_AMT,0)) AS DISCOUNT_1,
     SUM(NVL(DISCOUNT3_AMT,0)) AS DISCOUNT_3,
     SUM(NVL(DISCOUNT4_AMT,0)) AS DISCOUNT_4,
     SUM(NVL(DISCOUNT5_AMT,0)) AS DISCOUNT_5,
     SUM(NVL(DISCOUNT6_AMT,0)) AS DISCOUNT_6,
   SUM(NVL(DISCOUNT30_AMT,0)) AS DISCOUNT_30,
     SUM(NVL(DISCOUNT34_AMT,0)) AS DISCOUNT_34,
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') AS COD_DEST4,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') AS D_SPEC_SEC,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE_S,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') AS D_PRO_SSER,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') AS D_QUA_METHOD,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') AS D_PRO_STAGE,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') AS D_PRI_RANGE,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') AS D_PRO_SERIES,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') AS D_MARKET_PNT,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') AS D_TECH_TYPE,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') AS D_PRO_CLASS,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') AS D_MODEL_LCA,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') AS D_CNL_C_TYPE,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') AS D_IND_C_TYPE,
     COALESCE(COMM_BU_CODE, 'ZZZZ') AS D_ECOM_BU,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') AS D_SALE_DEPT,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') AS COD_DEST3,
     AGENCY_CODE,
     AGENCY_NAME,
     IS_MINILED_CODE,
     D_BU_TRAN, -- 事业部内外标识
     CUSTOMER_MODEL, -- 客户型号
     ORDER_TYPE_CODE
   ,zcalasset,
     CN_CLASS_MARK_CODE,
     CN_CLASS_MARK_NAME,
     SALE_CERT_TYPE,
     '' AS D_ADJ_TYPE,  --调整类型
     SUM(NVL(rev_sale_bcy_amt,0)) AS ORG_REV
     ,0 AS BCY_REV --销售收入-本位币（调整进）
     --,SUM(NVL(GFCFY_AMOUNT,0)) AS GFCFY_AMOUNT
     --,SUM(NVL(GFCFL_AMOUNT,0)) AS GFCFL_AMOUNT
     ,MATERIAL_GROUP_NAME
     ,maktx_s810
     ,bus_sce_cat_code AS D_BUS_SCE_S --业务场景分类
     ,miniled_type_code AS D_MINILED-- MiniLED类型
     ,invoice_code --金税发票号
      ,Shipping_Order
      ,SUM(NVL(MAP_ZUM_QTY,0)) AS MAP_ZUM_QTY
      ,SUM(NVL(STD_QTY,0)) AS STD_QTY
      ,BUS_TYPE_CODE
      --,BUS_TYPE_NAME
      --20260917FJF_ADD 二期新增字段
      ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP
FROM(
      SELECT
      YEAR, MONTH, COMPANY_CODE, CUST_CODE, CUST_NAME, MATERIAL_CODE,
      MATERIAL_NAME, PROFITCENTER_CODE, CHANNEL_L3_CODE, MARKETING_MODE_CODE, ONOFFLINE_CODE,
       SALE_MODEL_CODE, MODEL_CODE, SHOP_CODE, SYSTEM_SRC,
      -- SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, CP_COMPANY_CODE, BATCH_ID,
      SOLD_TO_CODE, SOLD_TO_NAME,  MATERIAL_GROUP_CODE, CP_COMPANY_CODE, BATCH_ID,
      MATERIAL_PRICING_GROUP_CODE, MATERIAL_PRICING_GROUP_NAME, QCY_CODE,
      CASE WHEN MONTH = P_PERIODO THEN  UPPER(ODS_SRC) ELSE UPPER(ODS_SRC)||'_LM' END AS ODS_SRC,
      CASE WHEN MONTH = P_PERIODO THEN BILL_QTY ELSE -BILL_QTY END AS BILL_QTY,
      CASE WHEN MONTH = P_PERIODO THEN SHIP_QTY ELSE -SHIP_QTY END AS SHIP_QTY,
      CASE WHEN MONTH = P_PERIODO THEN ORDER_QTY ELSE -ORDER_QTY END AS ORDER_QTY,
      /* 2026-11-16 V7.2（C-042）：交易币同本位币一起翻（同上，STEP_7 会用本列覆盖 ORG_REV） */
      CASE WHEN MONTH = P_PERIODO THEN REV_SALE_AMT ELSE -REV_SALE_AMT END AS REV_SALE_AMT,
      CASE WHEN MONTH = P_PERIODO THEN -DISCOUNT1_AMT ELSE DISCOUNT1_AMT END AS DISCOUNT1_AMT,
      CASE WHEN MONTH = P_PERIODO THEN -DISCOUNT3_AMT ELSE DISCOUNT3_AMT END AS DISCOUNT3_AMT,
      CASE WHEN MONTH = P_PERIODO THEN -DISCOUNT4_AMT ELSE DISCOUNT4_AMT END AS DISCOUNT4_AMT,
      CASE WHEN MONTH = P_PERIODO THEN -DISCOUNT5_AMT ELSE DISCOUNT5_AMT END AS DISCOUNT5_AMT,
      CASE WHEN MONTH = P_PERIODO THEN -DISCOUNT6_AMT ELSE DISCOUNT6_AMT END AS DISCOUNT6_AMT,
      CASE WHEN MONTH = P_PERIODO THEN -DISCOUNT30_AMT ELSE DISCOUNT30_AMT END AS DISCOUNT30_AMT,
      CASE WHEN MONTH = P_PERIODO THEN -DISCOUNT34_AMT ELSE DISCOUNT34_AMT END AS DISCOUNT34_AMT,
      TAX_RATE, EXCHANGE_RATE,PRODUCT_SMALL_CLASS_CODE,
      BRAND_CODE,SPEC_SECTION_CODE,PRODUCT_SHAPE_TYPE_CODE,PRODUCT_SALE_SERIES_CODE,
      QUARTER_METHOD_CODE,PRODUCT_STAGE_CODE,PRICE_RANGE_CODE,PRODUCT_SERIES_CODE,
      MARKET_PNT_CODE,TECH_TYPE_CODE,MODEL_LCA_CODE,PRODUCT_TYPE_CODE,
      CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,SHOP_NAME,
      SALE_MODEL_NAME, MODEL_NAME, channel_small_class_code,IND_SMALL_CLASS_CODE,COMM_BU_CODE,
      MARKETING_DEPT_CODE,BUS_RANGE_CODE,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,
      ''AS D_BU_TRAN,
      CUSTOMER_MODEL,ORDER_TYPE_CODE
    ,zcalasset,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE
    , /* 2026-11-16 V7.1（C-042）：CKTH 的 rev_sale_bcy_amt 是「贷方为负」，出库本月必须输出负值
         （S600101 以负数增加收入），故本月直传、上月取负。与退货段方向相反，两段一起才能与管报口径对齐。 */
      CASE WHEN MONTH = P_PERIODO THEN NVL(rev_sale_bcy_amt,0) ELSE -NVL(rev_sale_bcy_amt,0) END AS rev_sale_bcy_amt
    ,MATERIAL_GROUP_NAME
    ,COST_CENTER_CODE
    ,maktx_s810
    ,bus_sce_cat_code
    ,bus_sce_cat_name
    ,miniled_type_code
    ,'' AS invoice_code --金税发票号
     ,Shipping_Order
     ,CASE WHEN DT_MONTH = V_YEARMONTH THEN MAP_ZUM_QTY ELSE -MAP_ZUM_QTY END AS MAP_ZUM_QTY
      ,CASE WHEN DT_MONTH = V_YEARMONTH THEN STD_QTY ELSE -STD_QTY END AS STD_QTY
      ,BUS_TYPE_CODE
      --,BUS_TYPE_NAME
      --20260917FJF_ADD 二期新增字段
      ,ee_level_code AS D_EFF_CLASS   --能效等级
      ,bu_code AS D_BU_SHOP     --门店所属BU
      ,niche_ec_store_code AS D_EC_STORE    --电商细分店铺
      ,map_channel_l3_code AS MAP_D_CHANNEL --映射公司三级分类编码
      ,map_comm_bu_code AS MAP_D_ECOM_BU --映射电商BU渠道细分编码
      ,CUST_UNITY_CODE AS D_UNICUSTGRP  --统一客户组编码
    FROM  DWD_FI_MR_GP_MSUM_CKTH_MI MI
      WHERE  1=P_ORG_FLAG
        AND (
            DT_MONTH = V_YEARMONTH OR DT_MONTH = TO_CHAR(ADD_MONTHS(TO_DATE(V_YEARMONTH,'YYYYMM'), -1), 'YYYYMM')
          )
        AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
        --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
        AND COMPANY_CODE NOT IN ('80J0')  -- 该公司从国际营销管报环境获取
        AND ODS_SRC = 'ZTSO04_CK'
        AND COMPANY_CODE NOT LIKE '12%'
        AND COMPANY_CODE NOT LIKE '1180'
       )T1
 GROUP BY
     COALESCE(COMPANY_CODE, 'ZZZZ') ,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     NVL(COST_CENTER_CODE,'ZZZZ') ,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') ,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') ,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') ,
     /* COALESCE( 'ZZZZ') AS D_SALEINOUT, */
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') ,
     COALESCE(MODEL_CODE, 'ZZZZ') ,
     COALESCE(SHOP_CODE, 'ZZZZ') ,
     SYSTEM_SRC ,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE ,
      /* MATERIAL_PRICING_GROUP_NAME AS MPG_NAME, */
     COALESCE(QCY_CODE, 'ZZZZ') ,
     COALESCE(QCY_CODE, 'ZZZZ') ,
     UPPER(ODS_SRC) ,
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') ,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') ,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') ,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') ,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') ,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') ,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') ,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(COMM_BU_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') ,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') ,
     AGENCY_CODE,
     AGENCY_NAME,
     IS_MINILED_CODE,
     D_BU_TRAN, -- 事业部内外标识
     CUSTOMER_MODEL, -- 客户型号
     ORDER_TYPE_CODE
   ,zcalasset,
     CN_CLASS_MARK_CODE,
     CN_CLASS_MARK_NAME,
     SALE_CERT_TYPE,
     MATERIAL_GROUP_NAME
     ,maktx_s810
     ,bus_sce_cat_code
   ,miniled_type_code -- MiniLED类型
    ,Shipping_Order

      ,BUS_TYPE_CODE
      --,BUS_TYPE_NAME
      --20260917FJF_ADD 二期新增字段
      ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP

HAVING SUM(NVL(BILL_QTY,0)) <> 0 OR SUM(NVL(SHIP_QTY,0)) <> 0 OR SUM(NVL(ORDER_QTY,0)) <> 0 OR SUM(NVL(REV_SALE_AMT,0)) <> 0 OR SUM(NVL(DISCOUNT1_AMT,0)) <> 0
  OR SUM(NVL(DISCOUNT3_AMT,0)) <> 0 OR SUM(NVL(DISCOUNT4_AMT,0)) <> 0 OR SUM(NVL(DISCOUNT5_AMT,0)) <> 0 OR SUM(NVL(DISCOUNT6_AMT,0)) <> 0
    OR SUM(NVL(DISCOUNT30_AMT,0)) <> 0  OR SUM(NVL(DISCOUNT34_AMT,0)) <> 0
    OR SUM(NVL(MAP_ZUM_QTY,0)) <> 0
    OR SUM(NVL(STD_QTY,0)) <> 0

;
COMMIT;

INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_MODE, -- 销售模式
    D_ONOFFLINE, -- 线上线下
    SALE_MODEL_CODE, -- 销售型号
    MODEL_CODE, -- 产品型号
    SHOP_CODE, -- 门店
    SRC_SYSTEM, -- 源系统
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    MATERIAL_GROUP_CODE, -- 物料组
    COD_AZI_CTP, -- 对方公司
    BATCH_ID, -- 批次号
    D_PRC_GRP, -- 物料定价组
    COD_VALUTA, -- 货币
    COD_VALUTA_ORIGINARIA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    BILL_QTY, -- 开票数量
    SHIP_QTY, -- 发货数量
    ORDER_QTY, -- 订单数量
    SALE_REV, -- 收入金额
    DISCOUNT_1, -- 收入折扣1(含税)
    DISCOUNT_3, -- 收入折扣3(含税)
    DISCOUNT_4, -- 收入折扣4(含税)
    DISCOUNT_5, -- 收入折扣5(含税)
    DISCOUNT_6, -- 收入折扣6(含税)
    DISCOUNT_30, -- 收入折扣30(含税)
    DISCOUNT_34, -- 收入折扣34(含税)
    TAX_RATE, -- 税率
    EXCHANGE_RATE, -- 汇率
    COD_DEST4, -- 品牌
    D_SPEC_SEC, -- 规格段
    D_PRO_TYPE_S, -- 产品形态分类
    D_PRO_SSER, -- 产品套系
    D_QUA_METHOD, -- 奥维产品四分法
    D_PRO_STAGE, -- 产品阶段
    D_PRI_RANGE, -- 价格段
    D_PRO_SERIES, -- 产品系列
    D_MARKET_PNT, -- 营销定位
    D_TECH_TYPE, -- 技术类型
    D_PRO_CLASS, -- 产品类别
    D_MODEL_LCA, -- 产品型号生命周期
    D_PRO_TYPE, -- 产品类型
    CUST_UNITY_NAME, -- 统一客户组
    CREDIT_LEVEL_NAME, -- 信用等级
    CUST_NATURE_NAME, -- 单位性质
    CUST_TYPE_NAME, -- 客户类型
    SHOP_NAME, -- 门店名称
    SALE_MODEL_NAME, -- 销售型号描述
    MODEL_NAME, -- 产品线型号描述
    D_CNL_C_TYPE, -- 渠道客户大类小类
    D_IND_C_TYPE, -- 行业客户大类小类
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    AGENCY_CODE, -- 销售部门编码
    AGENCY_NAME, -- 销售部门描述
    IS_MINILED_CODE, -- 是否MiniLED编码
    D_BU_TRAN, -- 事业部内外标识
    CUSTOMER_MODEL, -- 客户型号
    ORDER_TYPE_CODE -- 订单类型
  ,zcalasset,  --按套统计
  CN_CLASS_MARK_CODE,  --中国区品类标记编码
  CN_CLASS_MARK_NAME,  --中国区品类标记描述
  SALE_CERT_TYPE,  --销售凭证类型
  D_ADJ_TYPE,  --调整类型
  ORG_REV
   ,BCY_REV --销售收入-本位币（调整进）
  --,GFCFY_AMOUNT --价差转费用(日立专用)
  --,GFCFL_AMOUNT --费用转价差(日立专用)
  ,MATERIAL_GROUP_NAME
  ,maktx_s810
  ,D_BUS_SCE_S --业务场景分类
  ,D_MINILED-- MiniLED类型
  ,invoice_code --金税发票号
  ,D_OPER_TYPE --业务分类
   ,Shipping_Order
   ,MAP_ZUM --折算销量 --20260830-2 shexuanxuan.EX ODS_SRC=BSEG 部分，新增MAP_ZUM取数
   --20260917FJF_ADD 二期新增字段
   ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP
)


SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     MONTH AS COD_PERIODO,
     COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA,
     /*CASE WHEN ODS_SRC = 'BSEG' AND ACCT_SRC_CODE IN('6001000000','6001020000') AND (ORDER_TYPE_CODE = 'RFBU' OR ORDER_TYPE_CODE IS NULL) THEN 'S600110'
          WHEN ODS_SRC = 'BSEG' AND ACCT_SRC_CODE IN('6001010000') THEN 'S600110'
          ELSE 'ZZZZ' END AS COD_CONTO,*/
     CASE
         /*20260724-1 优先级最高 当映射前科目为 5101099006 时输出 S600113-主营业务收入-总账调整-返利价差-OEM*/
          WHEN ACCT_SRC_CODE = '5101099006' THEN 'S600113'
         /*EDIT BY LC 20261014 2910-TVS：BSEG 来源且凭证类型 document_type='ZL' 且映射前科目 ACCT_SRC_CODE='5001080102'，输出 S600114-主营业务收入-TVS返利价差*/
          WHEN UPPER(ODS_SRC) = 'BSEG' AND document_type = 'ZL' AND ACCT_SRC_CODE = '5001080102' THEN 'S600114'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND COMPANY_CODE = '1735' AND ACCT_SRC_CODE IN('6001004000','6001005000','6001006000','6001007000','6001010000') THEN 'S600100'--fjf日立总账调整科目处理
          WHEN UPPER(ODS_SRC) = 'BSEG' AND (COMPANY_CODE LIKE'17%' OR COMPANY_CODE = '6240' ) THEN 'S600112' --fjf日立总账调整科目处理
          WHEN UPPER(ODS_SRC) = 'BSEG' AND SYSTEM_SRC IN ('S800','S900','S610','S810')  AND ACCT_MAP_CODE IN('6001020000') THEN 'S600111'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND ACCT_SRC_CODE IN('6001020000') THEN 'S600111'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND ACCT_SRC_CODE IN('6001010000','6001000000','6001050000','6001002000') THEN 'S600110'
          /*ALTER BY LC 20261117 20:10 【R3 修复·6002 科目串位】6002 兜底分支前移到 S810 分支之前。
            原因：原顺序 S810→S600100 在 6002→S600110 之前，6002 的 BSEG 凭证是 5001 开头（映射后 6001000000），
                  既不在 6001000000 等 ACCT_SRC_CODE 白名单、也不是 6001020000，只能落到 S810 分支 → 被截胡成 S600100，
                  导致 S600110 永远取不到 6002 的数（2026ACT/10 表现为 S600100 +984 万、S600110 -984 万）。
            目标：6002 的 BSEG 恢复落 S600110，与生产（无 S810 分支时的口径）一致。
            回退：把本行移回 S810 分支之后即可。GROUP BY 内的同名 CASE 已同步。*/
          WHEN UPPER(ODS_SRC) = 'BSEG' AND COMPANY_CODE = '6002' THEN 'S600110'    /*ALTER BY 20260904 XIAOYACHAO.EX 调整映射科目跟S600一致*/
          WHEN UPPER(ODS_SRC) = 'BSEG' AND SYSTEM_SRC IN ('S800','S900','S610','S810') THEN 'S600100'
          ELSE 'ZZZZ' END AS COD_CONTO,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     NVL(COST_CENTER_CODE,'ZZZZ') AS COD_DEST1,
     --DECODE(LTRIM(PROFITCENTER_CODE,0),NULL,LTRIM(PRODUCT_LINE_CODE,0),'ZZZZ',LTRIM(PRODUCT_LINE_CODE,0),LTRIM(PROFITCENTER_CODE,0)) AS COD_DEST2,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') AS COD_DEST2,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') AS D_CHANNEL,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') AS D_MODE,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE,
     /* COALESCE( 'ZZZZ') AS D_SALEINOUT, */
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') AS SALE_MODEL_CODE,
     COALESCE(MODEL_CODE, 'ZZZZ') AS MODEL_CODE,
     COALESCE(SHOP_CODE, 'ZZZZ') AS SHOP_CODE,
     SYSTEM_SRC AS SRC_SYSTEM,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     -- MATERIAL_GROUP_CODE,
     -- ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line
     product_line_code AS MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE AS D_PRC_GRP,
      /* MATERIAL_PRICING_GROUP_NAME AS MPG_NAME, */
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA,
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA_ORIGINARIA,
     CASE WHEN UPPER(ODS_SRC) = 'BSEG' AND SYSTEM_SRC IN ('S800','S900')  AND ACCT_MAP_CODE IN('6001020000') THEN 'BSEG_FLJC'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND ACCT_SRC_CODE IN('6001020000') THEN 'BSEG_FLJC'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND ACCT_SRC_CODE IN('6001010000','6001000000') THEN 'BSEG_REVM'
          ELSE UPPER(ODS_SRC) END AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(CASE WHEN SYSTEM_SRC IN ('S800','S900') AND ACCT_MAP_CODE IN('6001020000') THEN NVL(BILL_QTY,0)
              /* 2026-11-16 停用（C-036）：D 02 已按「借正贷负」出数，用户 11-12 确认 D 侧正确，M 不再二次取负：WHEN SYSTEM_SRC IN ('S800','S900') THEN 0-NVL(BILL_QTY,0) */
              ELSE NVL(BILL_QTY,0)
         END) AS BILL_QTY,
     SUM(NVL(SHIP_QTY,0))  AS SHIP_QTY,
     SUM(NVL(ORDER_QTY,0)) AS ORDER_QTY,
     SUM(CASE WHEN SYSTEM_SRC IN ('S800','S900') AND ACCT_MAP_CODE IN('6001020000') THEN NVL(REV_SALE_AMT,0)
              /* 2026-11-16 停用（C-036）：D 02 已按「借正贷负」出数，用户 11-12 确认 D 侧正确，M 不再二次取负：WHEN SYSTEM_SRC IN ('S800','S900') THEN 0-NVL(REV_SALE_AMT,0) */
              ELSE NVL(REV_SALE_AMT,0)
         END) AS SALE_REV,
     /*CASE WHEN MATERIAL_CODE IN (SELECT material_code FROM AW_RUL_REVEMA_000001 WHERE COD_CONTO = 'ZAW_DWD_LIST_ZHEKOU'
       AND V_YEARMONTH between valid_fr AND valid_to) THEN SUM(NVL(rev_sale_amt,0)) ELSE SUM(NVL(DISCOUNT1_AMT,0)) END AS DISCOUNT_1,*/
     SUM(NVL(DISCOUNT1_AMT,0)) AS DISCOUNT_1,
     SUM(NVL(DISCOUNT3_AMT,0)) AS DISCOUNT_3,
     SUM(NVL(DISCOUNT4_AMT,0)) AS DISCOUNT_4,
     SUM(NVL(DISCOUNT5_AMT,0)) AS DISCOUNT_5,
     SUM(NVL(DISCOUNT6_AMT,0)) AS DISCOUNT_6,
     SUM(NVL(DISCOUNT30_AMT,0)) AS DISCOUNT_30,
     SUM(NVL(DISCOUNT34_AMT,0)) AS DISCOUNT_34,
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') AS COD_DEST4,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') AS D_SPEC_SEC,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE_S,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') AS D_PRO_SSER,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') AS D_QUA_METHOD,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') AS D_PRO_STAGE,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') AS D_PRI_RANGE,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') AS D_PRO_SERIES,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') AS D_MARKET_PNT,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') AS D_TECH_TYPE,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') AS D_PRO_CLASS,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') AS D_MODEL_LCA,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') AS D_CNL_C_TYPE,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') AS D_IND_C_TYPE,
     COALESCE(COMM_BU_CODE, 'ZZZZ') AS D_ECOM_BU,
     /*新增日立特殊逻辑
       ①当目标表科目为S600100，找到表单AW_RUL_REVASA_000001中【PROJ_CLASSIFICATION-项目分类】为“日立公建”，【STRATEGIC_TYPE-战略供应商类型】为“非战略”行对应的【D_SALE_DEPT-业务管理单元】
      ②当目标表科目不为S600100，【COD_DEST3-业务范围】在HN节点下，【COD_AZIENDA-公司】为1750时，放1730.S0232
      ③当目标表科目不为S600100，【COD_DEST3-业务范围】在HN节点下，【COD_AZIENDA-公司】不为1750时，放1730.S0212
      ④当目标表科目不为S600100，【COD_DEST3-业务范围】在HW节点下，【COD_AZIENDA-公司】为1730时，放1730.S0060
      ⑤当目标表科目不为S600100，【COD_DEST3-业务范围】在HW节点下，【COD_AZIENDA-公司】为1740时，放1730.S0061


    */
    CASE WHEN (COMPANY_CODE LIKE '17%' OR COMPANY_CODE = '6240')
             /*判断日立科目为S600100*/
           AND UPPER(ODS_SRC) = 'BSEG' AND COMPANY_CODE = '1735' AND ACCT_SRC_CODE IN('6001004000','6001005000','6001006000','6001007000')
          THEN A1.D_SALE_DEPT
        WHEN COMPANY_CODE = '1750' AND D3.NODE = 'HN'
          THEN '1730.S0232'
        WHEN (COMPANY_CODE LIKE '17%' OR COMPANY_CODE = '6240') AND COMPANY_CODE <> '1750' AND D3.NODE = 'HN'
          THEN '1730.S0212'
        WHEN COMPANY_CODE = '1730' AND D3.NODE = 'HW'
          THEN '1730.S0060'
        WHEN COMPANY_CODE = '1740' AND D3.NODE = 'HW'
          THEN '1730.S0061'
         ELSE COALESCE(MARKETING_DEPT_CODE, 'ZZZZ')
     END AS D_SALE_DEPT,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') AS COD_DEST3,
      AGENCY_CODE,
      AGENCY_NAME,
     IS_MINILED_CODE,
     '' AS D_BU_TRAN,
     CUSTOMER_MODEL,
     ORDER_TYPE_CODE
   ,zcalasset,
     CN_CLASS_MARK_CODE,
     CN_CLASS_MARK_NAME,
     SALE_CERT_TYPE,
     '' AS D_ADJ_TYPE,  --调整类型
     SUM(CASE WHEN SYSTEM_SRC IN ('S800','S900') AND ACCT_MAP_CODE IN('6001020000') THEN NVL(rev_sale_bcy_amt,0)
              /* 2026-11-16 停用（C-036）：D 02 已按「借正贷负」出数，用户 11-12 确认 D 侧正确，M 不再二次取负：WHEN SYSTEM_SRC IN ('S800','S900') THEN 0-NVL(rev_sale_bcy_amt,0) */
              ELSE NVL(rev_sale_bcy_amt,0)
         END) AS ORG_REV
    ,0 AS BCY_REV --销售收入-本位币（调整进）
    --,SUM(NVL(GFCFY_AMOUNT,0)) AS GFCFY_AMOUNT
    --,SUM(NVL(GFCFL_AMOUNT,0)) AS GFCFL_AMOUNT
    -- ,MATERIAL_GROUP_NAME
    -- ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line
    ,product_line_name AS MATERIAL_GROUP_NAME
    ,maktx_s810
    ,bus_sce_cat_code AS D_BUS_SCE_S --业务场景分类
    ,miniled_type_code AS D_MINILED-- MiniLED类型
    ,invoice_code --金税发票号
    , bus_type_code as D_OPER_TYPE --业务分类
    ,Shipping_Order
    ,SUM(CASE WHEN SYSTEM_SRC IN ('S800','S900') AND ACCT_MAP_CODE IN('6001020000') THEN NVL(MAP_ZUM_QTY,0)
          /* 2026-11-16 停用（C-036）：D 02 已按「借正贷负」出数，用户 11-12 确认 D 侧正确，M 不再二次取负：WHEN SYSTEM_SRC IN ('S800','S900') THEN 0-NVL(MAP_ZUM_QTY,0) */
          ELSE NVL(MAP_ZUM_QTY,0)
     END) AS MAP_ZUM --20260830-2 shexuanxuan.EX ODS_SRC=BSEG 部分，新增MAP_ZUM取数
  --20260917FJF_ADD 二期新增字段
    ,ee_level_code AS D_EFF_CLASS   --能效等级
    ,bu_code AS D_BU_SHOP     --门店所属BU
    ,niche_ec_store_code AS D_EC_STORE    --电商细分店铺
    ,map_channel_l3_code AS MAP_D_CHANNEL --映射公司三级分类编码
    ,map_comm_bu_code AS MAP_D_ECOM_BU --映射电商BU渠道细分编码
    ,CUST_UNITY_CODE AS D_UNICUSTGRP  --统一客户组编码
FROM  DWD_FI_MR_GP_MSUM_MI_LCTEST MI
LEFT JOIN (SELECT MAX(D_SALE_DEPT) AS D_SALE_DEPT FROM TGK_FIMA_HISENSE.AW_RUL_REVASA_000001 WHERE PROJ_CLASSIFICATION = '日立公建' AND STRATEGIC_TYPE = '非战略') A1
 ON (COMPANY_CODE LIKE '17%' OR COMPANY_CODE = '6240')
LEFT JOIN (SELECT NODE,ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE SESSION_ID = V_SESSION_ID AND HIE = '01' AND NODE IN ('HN','HW')) D3
 ON (COMPANY_CODE LIKE '17%' OR COMPANY_CODE = '6240')
AND COALESCE(BUS_RANGE_CODE, 'ZZZZ') = D3.ELEM
/*LEFT JOIN TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A2 ON A2.COD_AZIENDA = MI.CP_COMPANY_CODE*/
WHERE 1=P_ORG_FLAG
AND DT_MONTH = V_YEARMONTH
AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST S1 WHERE SESSION_ID = V_SESSION_ID
                         AND NOT EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S2
                                         WHERE S1.SESSION_ID =S2.SESSION_ID AND S2.ELEM =S1.ELEM
                                         AND S2.HIE = '10'  AND S2.NODE IN ('020')
                                        )
                                        )
--AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
AND COMPANY_CODE NOT IN ('80J0')  -- 该公司从国际营销管报环境获取
  --EDIT BY LC 20260606 剔除国际营销公司取数
/*  AND COMPANY_CODE NOT IN (SELECT ELEM
                             FROM SESSION_V_REF_AZIENDA
                            WHERE SESSION_ID = V_SESSION_ID
                              AND HIE = '10'
                              AND NODE IN ('020')
                            )*/
AND UPPER(ODS_SRC) IN ('BSEG')
AND (
  (
    (
      (ACCT_SRC_CODE IN('6001000000','6001020000') AND (ORDER_TYPE_CODE = 'RFBU' OR ORDER_TYPE_CODE IS NULL)) 
      OR ACCT_SRC_CODE IN('6001010000','6001050000','6001002000'))   /*alter by 20260824 xiaoyachao.ex 增加6001050000主营业务收入-土地租赁&6001002000主营-软件服务*/
      AND (COMPANY_CODE NOT IN ('1630','1632')
     OR (COMPANY_CODE IN ('1630','1632')
       /*AND LTRIM(PROFITCENTER_CODE,0) IN ('16300307','16300303','16300305','1100114','1100105','1100103'
       \*20260203 add by shqingfeng.ex zhangxuan 新增利润中心*\
      ,'104001001','104001002','104001003','104012001','104012002','104012003','104012004','104051000','104003001','104003002','104023000','190030000','100051000','190025000','104999000'
      \*20260518 add by shiqingfeng.ex 1632 4月新增业务，需要在总账取利润中心范围内加上104053000Vidda家庭影院音响、190063000非氛围音响公共*\
      \* ALTER BY 20260616 XIAOYACHAO.EX 1632新增利润中心104053001Vidda家庭影院音响-智能投影 BY : FIDATA-418*\
      ,'104053000','190063000','104053001'
      -- ,'104001001','104001002','104001003','104012001','104012002','104012003','104012004','104051000','104003001','104003002','104053000','16300101','16300102','16300104','16300110','16300114','104023000','190030000','100051000','190063000','190025000','104999000'
       )*/ /*ALTER BY 20260623 XIAOYACHAO.EX '1630','1632'取消利润限制*/
       ) )
     ) OR (COMPANY_CODE LIKE '17%' OR COMPANY_CODE = '6240')-- 新增日立总账取数FJF

     OR (SYSTEM_SRC IN ('S800','S900','S610','S810') AND ACCT_MAP_CODE LIKE '6001%') -- 新增800,900,TVS,蒙特雷取数（S810 20261116 补）
     /*ALTER BY 20260903 XIAOYACHAO.EX 万高增加bseg取数*/
     OR (COMPANY_CODE = '6002' and ACCT_SRC_CODE LIKE '%5001%'  AND (ORDER_TYPE_CODE = 'RFBU' OR ORDER_TYPE_CODE IS NULL) )
   )

GROUP BY
     CONCAT(YEAR,'ACT') ,
     MONTH ,
     COALESCE(COMPANY_CODE, 'ZZZZ') ,
     /*CASE WHEN ODS_SRC = 'BSEG' AND ACCT_SRC_CODE IN('6001000000','6001020000') AND (ORDER_TYPE_CODE = 'RFBU' OR ORDER_TYPE_CODE IS NULL) THEN 'S600110'
          WHEN ODS_SRC = 'BSEG' AND ACCT_SRC_CODE IN('6001010000') THEN 'S600110'
          ELSE 'ZZZZ' END AS COD_CONTO,*/
      CASE
         /*20260724-1 优先级最高 当映射前科目为 5101099006 时输出 S600113-主营业务收入-总账调整-返利价差-OEM*/
          WHEN ACCT_SRC_CODE = '5101099006' THEN 'S600113'
         /*EDIT BY LC 20261014 2910-TVS：BSEG 来源且凭证类型 document_type='ZL' 且映射前科目 ACCT_SRC_CODE='5001080102'，输出 S600114-主营业务收入-TVS返利价差*/
          WHEN UPPER(ODS_SRC) = 'BSEG' AND document_type = 'ZL' AND ACCT_SRC_CODE = '5001080102' THEN 'S600114'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND COMPANY_CODE = '1735' AND ACCT_SRC_CODE IN('6001004000','6001005000','6001006000','6001007000','6001010000') THEN 'S600100'--fjf日立总账调整科目处理
          WHEN UPPER(ODS_SRC) = 'BSEG' AND (COMPANY_CODE LIKE'17%' OR COMPANY_CODE = '6240' ) THEN 'S600112' --fjf日立总账调整科目处理
          WHEN UPPER(ODS_SRC) = 'BSEG' AND SYSTEM_SRC IN ('S800','S900','S610','S810')  AND ACCT_MAP_CODE IN('6001020000') THEN 'S600111'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND ACCT_SRC_CODE IN('6001020000') THEN 'S600111'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND ACCT_SRC_CODE IN('6001010000','6001000000','6001050000','6001002000') THEN 'S600110'
          /*ALTER BY LC 20261117 20:10 【R3 修复】与 SELECT 端同名 CASE 逐字一致，见该处注释*/
          WHEN UPPER(ODS_SRC) = 'BSEG' AND COMPANY_CODE = '6002' THEN 'S600110'    /*ALTER BY 20260904 XIAOYACHAO.EX 调整映射科目跟S600一致*/
          WHEN UPPER(ODS_SRC) = 'BSEG' AND SYSTEM_SRC IN ('S800','S900','S610','S810') THEN 'S600100'
          ELSE 'ZZZZ' END ,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     NVL(COST_CENTER_CODE,'ZZZZ') ,
     --DECODE(LTRIM(PROFITCENTER_CODE,0),NULL,LTRIM(PRODUCT_LINE_CODE,0),'ZZZZ',LTRIM(PRODUCT_LINE_CODE,0),LTRIM(PROFITCENTER_CODE,0)) AS COD_DEST2,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') ,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') ,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') ,
     /* COALESCE( 'ZZZZ') AS D_SALEINOUT, */
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') ,
     COALESCE(MODEL_CODE, 'ZZZZ') ,
     COALESCE(SHOP_CODE, 'ZZZZ') ,
     SYSTEM_SRC ,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     -- MATERIAL_GROUP_CODE,
     -- ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line
     product_line_code,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE ,
      /* MATERIAL_PRICING_GROUP_NAME AS MPG_NAME, */
     COALESCE(QCY_CODE, 'ZZZZ') ,
     COALESCE(QCY_CODE, 'ZZZZ') ,
     CASE WHEN UPPER(ODS_SRC) = 'BSEG' AND SYSTEM_SRC IN ('S800','S900')  AND ACCT_MAP_CODE IN('6001020000') THEN 'BSEG_FLJC'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND ACCT_SRC_CODE IN('6001020000') THEN 'BSEG_FLJC'
          WHEN UPPER(ODS_SRC) = 'BSEG' AND ACCT_SRC_CODE IN('6001010000','6001000000') THEN 'BSEG_REVM'
          ELSE UPPER(ODS_SRC) END ,
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') ,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') ,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') ,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') ,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') ,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') ,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') ,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(COMM_BU_CODE, 'ZZZZ') ,
     CASE WHEN (COMPANY_CODE LIKE '17%' OR COMPANY_CODE = '6240')
             /*判断日立科目为S600100*/
           AND UPPER(ODS_SRC) = 'BSEG' AND COMPANY_CODE = '1735' AND ACCT_SRC_CODE IN('6001004000','6001005000','6001006000','6001007000')
          THEN A1.D_SALE_DEPT
        WHEN COMPANY_CODE = '1750' AND D3.NODE = 'HN'
          THEN '1730.S0232'
        WHEN (COMPANY_CODE LIKE '17%' OR COMPANY_CODE = '6240') AND COMPANY_CODE <> '1750' AND D3.NODE = 'HN'
          THEN '1730.S0212'
        WHEN COMPANY_CODE = '1730' AND D3.NODE = 'HW'
          THEN '1730.S0060'
        WHEN COMPANY_CODE = '1740' AND D3.NODE = 'HW'
          THEN '1730.S0061'
         ELSE COALESCE(MARKETING_DEPT_CODE, 'ZZZZ')
     END ,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') ,
      AGENCY_CODE,
      AGENCY_NAME,
     IS_MINILED_CODE,
     CUSTOMER_MODEL,
     ORDER_TYPE_CODE
    ,zcalasset,
     CN_CLASS_MARK_CODE,
     CN_CLASS_MARK_NAME,
     SALE_CERT_TYPE,
     -- MATERIAL_GROUP_NAME
     -- ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line
     product_line_name
     ,maktx_s810
     ,bus_sce_cat_code
    ,miniled_type_code -- MiniLED类型
    ,invoice_code --金税发票号
    , bus_type_code --业务分类
    ,Shipping_Order
    --20260917FJF_ADD 二期新增字段
    ,ee_level_code,bu_code,niche_ec_store_code,map_channel_l3_code,map_comm_bu_code,CUST_UNITY_CODE
HAVING SUM(NVL(BILL_QTY,0)) <> 0 OR SUM(NVL(SHIP_QTY,0)) <> 0 OR SUM(NVL(ORDER_QTY,0)) <> 0 OR SUM(NVL(REV_SALE_AMT,0)) <> 0 OR SUM(NVL(DISCOUNT1_AMT,0)) <> 0
  OR SUM(NVL(DISCOUNT3_AMT,0)) <> 0 OR SUM(NVL(DISCOUNT4_AMT,0)) <> 0 OR SUM(NVL(DISCOUNT5_AMT,0)) <> 0 OR SUM(NVL(DISCOUNT6_AMT,0)) <> 0
  OR SUM(NVL(DISCOUNT30_AMT,0)) <> 0  OR SUM(NVL(DISCOUNT34_AMT,0)) <> 0

;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_19(日立业务管理单元更新) ',SYSDATE,SESSION_USER,P_SCENARIO,P_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.19.1 REV001_STEP_19_1(供应商返利相关维度更新)*/
/*EDIT BY LICHENG.EX 20261028 新增：公司 2000 供应商返利数据（管法差异项 D_DIFF_TYPE='110304002'、源明细 SRC_DETAIL='ADJ_DI_MAG'）客商 CUST_CODE 统一更新为 310308。
  限制：公司 COD_AZIENDA=2000；且公司参数含 2000 时才更新（门控写法与 20261021 平板电视调整一致：EXISTS SESSION_AZIENDA_LIST ELEM='2000'）。
  位置放在 STEP_999 之前，使 D_TOV_CHAN / D_CC_CUSTGRP 按更新后的客商重新取值。*/
UPDATE AW_MR9_REVM01_000001_TEMP T
   SET T.CUST_CODE = '310308'
 WHERE T.COD_SCENARIO = P_SCENARIO
   AND T.COD_PERIODO  = P_PERIODO
   AND T.COD_AZIENDA  = '2000'
   AND T.D_DIFF_TYPE  = '110304002'
   AND T.SRC_DETAIL   = 'ADJ_DI_MAG'
   AND EXISTS (SELECT 1
                 FROM SESSION_AZIENDA_LIST
                WHERE SESSION_ID = V_SESSION_ID
                  AND ELEM = '2000')
;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_19_1 供应商返利相关维度更新',SYSDATE,SESSION_USER,P_SCENARIO,P_PERIODO,P_AZIENDA);
COMMIT;

INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    COD_CATEGORIA, --20260830-1 shexuanxuan.EX 新增ADJM01类别为GA00_BF
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_ONOFFLINE, -- 线上线下
    MODEL_CODE, -- 产品型号
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    COD_AZI_CTP, -- 对方公司
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    BILL_QTY, -- 开票数量
    SALE_REV, -- 收入金额
    DISCOUNT_1, -- 收入折扣1(含税)
    COD_DEST4, -- 品牌
    D_MARKET_PNT, -- 营销定位
    MODEL_NAME, -- 产品线型号描述
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
     COD_DEST3,
   CN_CLASS_MARK_CODE,  --中国区品类标记编码
   CN_CLASS_MARK_NAME,  --中国区品类标记描述
   D_ADJ_TYPE,  --调整类型
   BCY_REV --销售收入-本位币（调整进）
  --,GFCFY_AMOUNT --价差转费用(日立专用)
  --,GFCFL_AMOUNT --费用转价差(日立专用)
  --,MATERIAL_GROUP_NAME
  --20260917FJF_ADD 二期新增字段
  , D_EC_STORE --电商细分店铺
  ,D_BUS_SCE_S
)


SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     SUBSTR(year_month,5,2) AS COD_PERIODO,
     COALESCE(MI.COD_AZIENDA, 'ZZZZ') AS COD_AZIENDA,
     'S600100AD' AS COD_CONTO,--主营业务收入TA手工调整
     'GA00_BF' AS COD_CATEGORIA,--20260830-1 shexuanxuan.EX 新增ADJM01类别为GA00_BF
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
     COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ') AS COD_DEST2,
     NVL(D_CHANNEL,'ZZZZ') AS D_CHANNEL,
     COALESCE(d_onoffline, 'ZZZZ') AS D_ONOFFLINE,
     MODEL_CODE,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     cod_azi_ctp,
     'ADJM01' AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(map_qty,0)) AS BILL_QTY,
     SUM(NVL(org_rev,0)) AS SALE_REV,
     SUM(NVL(DISCOUNT_1,0)) AS DISCOUNT_1,
     COD_DEST4 AS COD_DEST4,
     D_MARKET_PNT,
     MODEL_NAME,
     COALESCE(D_ECOM_BU, 'ZZZZ') AS D_ECOM_BU,
     D_SALE_DEPT AS D_SALE_DEPT,
     COD_DEST3 AS COD_DEST3,
     COALESCE(CN_CLASS_MARK_CODE, 'ZZZZ') AS CN_CLASS_MARK_CODE,
     COALESCE(CN_CLASS_MARK_NAME, 'ZZZZ') AS CN_CLASS_MARK_NAME,
     CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END D_ADJ_TYPE,  --调整类型
     SUM(MI.ORG_REV * CA.CAMBIO_PERIODO) AS BCY_REV -- 销售收入-本位币（调整进）
     --20260917FJF_ADD 二期新增字段
     ,D_EC_STORE as D_EC_STORE --电商细分店铺
     ,MI.D_BUS_SCE_S           /*ALTER BY 20261104 17:09 XIAOYACHAO.EX 增加业务场景分类*/
FROM  TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001 MI
LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
ON MI.COD_AZIENDA = AZ.COD_AZIENDA
LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
ON CONCAT(SUBSTR(year_month,1,4),'ACT') = CA.COD_SCENARIO
AND SUBSTR(year_month,5,2) = CA.COD_PERIODO
AND AZ.COD_VALUTA = CA.COD_VALUTA
/*LEFT JOIN TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A1 ON A1.COD_AZIENDA = MI.COMPANY_CODE
LEFT JOIN TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A2 ON A2.COD_AZIENDA = MI.CP_COMPANY_CODE*/
WHERE 1=1
  AND year_month = V_YEARMONTH
  AND MI.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, MI.COD_AZIENDA) > 0
  AND COD_CATEGORIA = 'ZFAMOUNT'
  AND COD_CONTO = 'ZAW_DWM_REV_STAN'
  AND D_ADJ_TYPE = 'REV_01_201'
GROUP BY
     CONCAT(SUBSTR(year_month,1,4),'ACT') ,
     NVL(D_CHANNEL,'ZZZZ'),
     SUBSTR(year_month,5,2) ,
     COALESCE(MI.COD_AZIENDA, 'ZZZZ') ,
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END,
     CUST_CODE,
     CUST_NAME,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     D_MARKET_PNT,
     MATERIAL_CODE,
     MATERIAL_NAME,
     COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ'),
     COALESCE(d_onoffline, 'ZZZZ'),
     cod_azi_ctp,
     COD_DEST4 ,
     D_SALE_DEPT ,
     COD_DEST3,
     MODEL_CODE,
     MODEL_NAME,
     CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END,  --调整类型
     COALESCE(D_ECOM_BU, 'ZZZZ'),
     COALESCE(CN_CLASS_MARK_CODE, 'ZZZZ'),
     COALESCE(CN_CLASS_MARK_NAME, 'ZZZZ')
     ,D_EC_STORE --电商细分店铺
     ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 补齐 GROUP BY（S600100AD 块 SELECT 已取 MI.D_BUS_SCE_S，非聚合列必须入 GROUP BY）
HAVING SUM(NVL(map_qty,0)) <> 0 OR SUM(NVL(org_rev,0)) <> 0 OR SUM(NVL(DISCOUNT_1,0)) <> 0


;
COMMIT;

INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    COD_CATEGORIA,--类别
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_ONOFFLINE, -- 线上线下
    MODEL_CODE, -- 产品型号
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    COD_AZI_CTP, -- 对方公司
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    BILL_QTY, -- 订单数量
    SALE_REV, -- 收入金额
    COD_DEST4, -- 品牌
    D_MARKET_PNT, -- 营销定位
    MODEL_NAME, -- 产品线型号描述
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    CN_CLASS_MARK_CODE,  --中国区品类标记编码
    CN_CLASS_MARK_NAME,  --中国区品类标记描述
    D_ADJ_TYPE,  --调整类型
    BCY_REV --销售收入-本位币（调整进）
    --20260917FJF_ADD 二期新增字段
     ,D_EC_STORE --电商细分店铺
     ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
)


SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     SUBSTR(year_month,5,2) AS COD_PERIODO,
     COALESCE(MI.COD_AZIENDA, 'ZZZZ') AS COD_AZIENDA,
     'S600101AD' AS COD_CONTO,--出库未开TA手工调整
     'GA00_BF' AS COD_CATEGORIA,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
     COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ') AS COD_DEST2,
     NVL(D_CHANNEL,'ZZZZ') AS D_CHANNEL,
     COALESCE(d_onoffline, 'ZZZZ') AS D_ONOFFLINE,
     MODEL_CODE,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     cod_azi_ctp,
     'ADJM01' AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(ck_qty,0)) AS BILL_QTY,
     -1*SUM(NVL(ck_rev,0)) AS SALE_REV,
     COD_DEST4 AS COD_DEST4,
     D_MARKET_PNT,
     MODEL_NAME,
     COALESCE(D_ECOM_BU, 'ZZZZ') AS D_ECOM_BU,
     D_SALE_DEPT AS D_SALE_DEPT,
     COD_DEST3 AS COD_DEST3,
     COALESCE(CN_CLASS_MARK_CODE, 'ZZZZ') AS CN_CLASS_MARK_CODE,
     COALESCE(CN_CLASS_MARK_NAME, 'ZZZZ') AS CN_CLASS_MARK_NAME,
     CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END D_ADJ_TYPE,  --调整类型
     SUM(MI.ORG_REV * CA.CAMBIO_PERIODO) AS BCY_REV -- 销售收入-本位币（调整进）
     --20260917FJF_ADD 二期新增字段
     ,D_EC_STORE as D_EC_STORE --电商细分店铺
     ,MI.D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
FROM  TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001 MI
LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
ON MI.COD_AZIENDA = AZ.COD_AZIENDA
LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
ON CONCAT(SUBSTR(year_month,1,4),'ACT') = CA.COD_SCENARIO
AND SUBSTR(year_month,5,2) = CA.COD_PERIODO
AND AZ.COD_VALUTA = CA.COD_VALUTA
/*LEFT JOIN TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A1 ON A1.COD_AZIENDA = MI.COMPANY_CODE
LEFT JOIN TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A2 ON A2.COD_AZIENDA = MI.CP_COMPANY_CODE*/
WHERE 1=1
  AND year_month = V_YEARMONTH
  AND MI.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, MI.COD_AZIENDA) > 0
  AND COD_CATEGORIA = 'ZFAMOUNT'
  AND COD_CONTO = 'ZAW_DWM_REV_STAN'
  AND D_ADJ_TYPE = 'REV_01_201'
GROUP BY
     year_month,
   NVL(D_CHANNEL,'ZZZZ'),
     COALESCE(MI.COD_AZIENDA, 'ZZZZ'),
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END,
     CUST_CODE,
     CUST_NAME,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ'),
     COALESCE(d_onoffline, 'ZZZZ'),
     cod_azi_ctp,
     D_MARKET_PNT,
     COD_DEST3,
     COD_DEST4,
     MODEL_CODE,
     MODEL_NAME,
     D_SALE_DEPT,
     CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END,  --调整类型
     COALESCE(D_ECOM_BU, 'ZZZZ'),
     COALESCE(CN_CLASS_MARK_CODE, 'ZZZZ'),
     COALESCE(CN_CLASS_MARK_NAME, 'ZZZZ')
     --20260917FJF_ADD 二期新增字段
     ,D_EC_STORE  --电商细分店铺
     ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
HAVING SUM(NVL(ck_qty,0)) <> 0 OR SUM(NVL(ck_rev,0)) <> 0

;
COMMIT;

INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    COD_CATEGORIA,--类别
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_ONOFFLINE, -- 线上线下
    MODEL_CODE, -- 产品型号
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    COD_AZI_CTP, -- 对方公司
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    BILL_QTY, -- 开票数量
    SALE_REV, -- 收入金额
    COD_DEST4, -- 品牌
    D_MARKET_PNT, -- 营销定位
    MODEL_NAME, -- 产品线型号描述
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    CN_CLASS_MARK_CODE,  --中国区品类标记编码
    CN_CLASS_MARK_NAME,  --中国区品类标记描述
    D_ADJ_TYPE,  --调整类型
    BCY_REV --销售收入-本位币（调整进）
    --20260917FJF_ADD 二期新增字段
    ,D_EC_STORE --电商细分店铺
    ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类

)


SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     SUBSTR(year_month,5,2) AS COD_PERIODO,
     COALESCE(MI.COD_AZIENDA, 'ZZZZ') AS COD_AZIENDA,
     'S600102AD' AS COD_CONTO,--退货未办TA手工调整
     'GA00_BF' AS COD_CATEGORIA,--类别
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
  COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ') AS COD_DEST2,
     NVL(D_CHANNEL,'ZZZZ') AS D_CHANNEL,
     COALESCE(d_onoffline, 'ZZZZ') AS D_ONOFFLINE,
     MODEL_CODE,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     cod_azi_ctp,
     'ADJM01' AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(th_qty,0)) AS BILL_QTY,
     -1*SUM(NVL(th_rev,0)) AS SALE_REV,
     COD_DEST4 AS COD_DEST4,
     D_MARKET_PNT,
     MODEL_NAME,
     COALESCE(D_ECOM_BU, 'ZZZZ') AS D_ECOM_BU,
     D_SALE_DEPT AS D_SALE_DEPT,
     COD_DEST3 AS COD_DEST3,
     COALESCE(CN_CLASS_MARK_CODE, 'ZZZZ') AS CN_CLASS_MARK_CODE,
     COALESCE(CN_CLASS_MARK_NAME, 'ZZZZ') AS CN_CLASS_MARK_NAME,
     CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END D_ADJ_TYPE,  --调整类型
     SUM(MI.ORG_REV * CA.CAMBIO_PERIODO) AS BCY_REV -- 销售收入-本位币（调整进）
     --20260917FJF_ADD 二期新增字段
     ,D_EC_STORE as D_EC_STORE --电商细分店铺
     ,MI.D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
FROM  TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001 MI
LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
ON MI.COD_AZIENDA = AZ.COD_AZIENDA
LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
ON CONCAT(SUBSTR(year_month,1,4),'ACT') = CA.COD_SCENARIO
AND SUBSTR(year_month,5,2) = CA.COD_PERIODO
AND AZ.COD_VALUTA = CA.COD_VALUTA
/*LEFT JOIN TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A1 ON A1.COD_AZIENDA = MI.COMPANY_CODE
LEFT JOIN TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A2 ON A2.COD_AZIENDA = MI.CP_COMPANY_CODE*/
WHERE 1=1
  AND year_month = V_YEARMONTH
  AND MI.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, MI.COD_AZIENDA) > 0
  AND COD_CATEGORIA = 'ZFAMOUNT'
  AND COD_CONTO = 'ZAW_DWM_REV_STAN'
  AND D_ADJ_TYPE = 'REV_01_201'
GROUP BY
     year_month,
     NVL(D_CHANNEL,'ZZZZ'),
     COALESCE(MI.COD_AZIENDA, 'ZZZZ'),
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ'),
     COALESCE(d_onoffline, 'ZZZZ'),
     cod_azi_ctp,
     COD_DEST3,
     MODEL_CODE,
     MODEL_NAME,
     D_MARKET_PNT,
     D_SALE_DEPT,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END,  --调整类型
     COALESCE(D_ECOM_BU, 'ZZZZ'),
     COALESCE(CN_CLASS_MARK_CODE, 'ZZZZ'),
     COALESCE(CN_CLASS_MARK_NAME, 'ZZZZ'),
     COD_DEST4
     --20260917FJF_ADD 二期新增字段
     ,D_EC_STORE --电商细分店铺
     ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
HAVING SUM(NVL(th_rev,0)) <> 0 OR SUM(NVL(th_rev,0)) <>0

;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.1 REV001_STEP_1(聚合处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*2.2.11 REV001_STEP_11(成本聚合处理)*/

INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_MODE, -- 销售模式
    D_ONOFFLINE, -- 线上线下
    SALE_MODEL_CODE, -- 销售型号
    MODEL_CODE, -- 产品型号
    SHOP_CODE, -- 门店
    SRC_SYSTEM, -- 源系统
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    MATERIAL_GROUP_CODE, -- 物料组
    COD_AZI_CTP, -- 对方公司
    BATCH_ID, -- 批次号
    D_PRC_GRP, -- 物料定价组
    COD_VALUTA, -- 货币
    COD_VALUTA_ORIGINARIA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    SALE_COGS, -- 成本金额
    TAX_RATE, -- 税率
    EXCHANGE_RATE, -- 汇率
    COD_DEST4, -- 品牌
    D_SPEC_SEC, -- 规格段
    D_PRO_TYPE_S, -- 产品形态分类
    D_PRO_SSER, -- 产品套系
    D_QUA_METHOD, -- 奥维产品四分法
    D_PRO_STAGE, -- 产品阶段
    D_PRI_RANGE, -- 价格段
    D_PRO_SERIES, -- 产品系列
    D_MARKET_PNT, -- 营销定位
    D_TECH_TYPE, -- 技术类型
    D_PRO_CLASS, -- 产品类别
    D_MODEL_LCA, -- 产品型号生命周期
    D_PRO_TYPE, -- 产品类型
    CUST_UNITY_NAME, -- 统一客户组
    CREDIT_LEVEL_NAME, -- 信用等级
    CUST_NATURE_NAME, -- 单位性质
    CUST_TYPE_NAME, -- 客户类型
    SHOP_NAME, -- 门店名称
    SALE_MODEL_NAME, -- 销售型号描述
    MODEL_NAME, -- 产品线型号描述
    D_CNL_C_TYPE, -- 渠道客户大类小类
    D_IND_C_TYPE, -- 行业客户大类小类
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    AGENCY_CODE, -- 销售部门编码
    AGENCY_NAME, -- 销售部门描述
    IS_MINILED_CODE, -- 是否MiniLED编码
    CUSTOMER_MODEL, -- 客户型号
    MATERIAL_GROUP_NAME
    ,maktx_s810
    ,D_BUS_SCE_S --业务场景分类
    ,D_MINILED-- MiniLED类型
    , D_OPER_TYPE --业务分类
    , CN_CLASS_MARK_CODE
    , CN_CLASS_MARK_NAME
    ,Shipping_Order
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)

SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     MONTH AS COD_PERIODO,
     COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA,
     CASE WHEN (ACCT_MAP_CODE LIKE '5001%' AND COMPANY_CODE  = '6012') THEN 'S640190' ELSE 'S640100' END AS COD_CONTO,   ---- 主营业务成本
     CUST_CODE,
     CUST_NAME,
     CASE WHEN TRIM(MATERIAL_CODE) LIKE 'FPRZW%' THEN ''
      WHEN COMPANY_CODE IN ('6098','6012') AND (ACCT_SRC_CODE LIKE '500103%' AND ACCT_SRC_CODE<>'5001030700'/*20261002 zhuangxinzhou 剔除5001030700*/ OR ACCT_SRC_CODE IN ('6609990200','6609990101')) THEN ''
      ELSE TRIM(MATERIAL_CODE) END MATERIAL_CODE,
     MATERIAL_NAME,
     --'ZZZZ' AS COD_DEST1,
     NVL(COST_CENTER_CODE,'ZZZZ') AS COD_DEST1,
     --DECODE(LTRIM(PROFITCENTER_CODE,0),NULL,LTRIM(PRODUCT_LINE_CODE,0),'ZZZZ',LTRIM(PRODUCT_LINE_CODE,0),LTRIM(PROFITCENTER_CODE,0)) AS COD_DEST2,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') AS COD_DEST2,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') AS D_CHANNEL,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') AS D_MODE,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE,
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') AS SALE_MODEL_CODE,
     COALESCE(MODEL_CODE, 'ZZZZ') AS MODEL_CODE,
     COALESCE(SHOP_CODE, 'ZZZZ') AS SHOP_CODE,
     SYSTEM_SRC AS SRC_SYSTEM,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE AS D_PRC_GRP,
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA,
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA_ORIGINARIA,
     UPPER(ODS_SRC) AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(COGS_AMT,0))  AS SALE_COGS, -- 成本金额
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') AS COD_DEST4,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') AS D_SPEC_SEC,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE_S,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') AS D_PRO_SSER,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') AS D_QUA_METHOD,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') AS D_PRO_STAGE,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') AS D_PRI_RANGE,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') AS D_PRO_SERIES,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') AS D_MARKET_PNT,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') AS D_TECH_TYPE,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') AS D_PRO_CLASS,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') AS D_MODEL_LCA,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') AS D_CNL_C_TYPE,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') AS D_IND_C_TYPE,
     COALESCE(COMM_BU_CODE, 'ZZZZ') AS D_ECOM_BU,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') AS D_SALE_DEPT,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') AS COD_DEST3,
      AGENCY_CODE,
      AGENCY_NAME,
     IS_MINILED_CODE,
    CUSTOMER_MODEL,
    MATERIAL_GROUP_NAME
    ,maktx_s810
    ,bus_sce_cat_code AS D_BUS_SCE_S --业务场景分类
    ,miniled_type_code AS D_MINILED-- MiniLED类型
    , D_OPER_TYPE --业务分类
    , CN_CLASS_MARK_CODE
    , CN_CLASS_MARK_NAME
    ,Shipping_Order
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
FROM  (
  SELECT  YEAR,MONTH,COMPANY_CODE,CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COST_CENTER_CODE,PROFITCENTER_CODE,CHANNEL_L3_CODE,MARKETING_MODE_CODE,ONOFFLINE_CODE,SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SYSTEM_SRC,SOLD_TO_CODE,SOLD_TO_NAME,product_line_code AS MATERIAL_GROUP_CODE/*ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line*/,CP_COMPANY_CODE,BATCH_ID,MATERIAL_PRICING_GROUP_CODE,QCY_CODE,ODS_SRC,COGS_AMT,TAX_RATE,EXCHANGE_RATE,BRAND_CODE,SPEC_SECTION_CODE,PRODUCT_SHAPE_TYPE_CODE,PRODUCT_SALE_SERIES_CODE,QUARTER_METHOD_CODE,PRODUCT_STAGE_CODE,PRICE_RANGE_CODE,PRODUCT_SERIES_CODE,MARKET_PNT_CODE,TECH_TYPE_CODE,PRODUCT_SMALL_CLASS_CODE,MODEL_LCA_CODE,PRODUCT_TYPE_CODE,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,CHANNEL_SMALL_CLASS_CODE,IND_SMALL_CLASS_CODE,COMM_BU_CODE,MARKETING_DEPT_CODE,BUS_RANGE_CODE,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,CUSTOMER_MODEL,product_line_name AS MATERIAL_GROUP_NAME/*ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line*/,MAKTX_S810,BUS_SCE_CAT_CODE,MINILED_TYPE_CODE
    ,ACCT_MAP_CODE,ACCT_SRC_CODE
    , bus_type_code as D_OPER_TYPE --业务分类
    , CN_CLASS_MARK_CODE
    , CN_CLASS_MARK_NAME
    ,Shipping_Order
   --20260917FJF_ADD 二期新增字段
    ,ee_level_code AS D_EFF_CLASS     --能效等级
    ,bu_code AS D_BU_SHOP             --门店所属BU
    ,niche_ec_store_code AS D_EC_STORE --电商细分店铺
    ,CUST_UNITY_CODE AS D_UNICUSTGRP     --统一客户组编码
FROM DWD_FI_MR_GP_MSUM_MI_LCTEST
WHERE 1=P_ORG_FLAG
  AND YEAR = SUBSTR(V_YEARMONTH, 1, 4)
  AND MONTH = SUBSTR(V_YEARMONTH, 5, 2)
  AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST S1 WHERE SESSION_ID = V_SESSION_ID
                         AND NOT EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S2
                                         WHERE S1.SESSION_ID =S2.SESSION_ID AND S2.ELEM =S1.ELEM
                                         AND S2.HIE = '10'  AND S2.NODE IN ('020')
                                        )
                                        )
  --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
  AND COMPANY_CODE NOT IN ('80J0')  -- 该公司从国际营销管报环境获取
    --EDIT BY LC 20260606 剔除国际营销公司取数
/*  AND COMPANY_CODE NOT IN (SELECT ELEM
                             FROM SESSION_V_REF_AZIENDA
                            WHERE SESSION_ID = V_SESSION_ID
                              AND HIE = '10'
                              AND NODE IN ('020')
                            )*/
  AND /*(TRIM(MATERIAL_CODE) NOT LIKE '000%')*/TRIM(MATERIAL_CODE) IS NOT NULL
  AND NOT (COMPANY_CODE IN ('6380','6797') AND ACCT_MAP_CODE IN ('6609990101','6609990300'))
  AND NOT (COMPANY_CODE IN ('6515') AND ACCT_MAP_CODE IN ('6609990200'))
  AND (ACCT_MAP_CODE LIKE '6401%'
      OR ACCT_MAP_CODE LIKE '6609%' AND SYSTEM_SRC <> 'SAP600'
      OR Acct_src_code in  ('5508999002','5509999002')
    OR (ACCT_MAP_CODE LIKE '5001%' AND COMPANY_CODE  = '6012')
    )
  AND (COMPANY_CODE <> '6515' OR COMPANY_CODE = '6515' AND MATERIAL_CODE NOT IN ('Y000327','Y000219','Y000120'))
  AND (ACCT_MAP_CODE NOT LIKE '6609%' OR ACCT_MAP_CODE LIKE '6609%' AND TRIM(MATERIAL_CODE) IS NOT NULL)
  /*AND (ACCT_MAP_CODE <> '6401000000' OR ACCT_MAP_CODE = '6401000000' AND TRIM(MATERIAL_CODE) IS NOT NULL)*/
  /*AND (ACCT_MAP_CODE NOT IN ('6401000000','6401000100') OR ACCT_MAP_CODE IN ('6401000000','6401000100') AND TRIM(MATERIAL_CODE) IS NULL AND order_type_code <> 'UE')*/
  AND ((COMPANY_CODE NOT IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA
                            WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200')
                            )
    OR (COMPANY_CODE IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA
                            WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200')
      AND (TRIM(MATERIAL_CODE) LIKE 'F%' OR LTRIM(PROFITCENTER_CODE,0) IN ('8801002','8807002','790026000')
      OR ONOFFLINE_CODE IN ('030_AGY_002','030_AGY_003')
    --20260914FJF_ADD 成本聚合业务场景分类为026的要取数
      OR bus_sce_cat_code IN ('026') --EDIT BY LC 20260905 中国区成本 费用转政策部分 8月月结临时不取数
    --20260921FJF_ADD 中国区新增取数来源限制
    --20260929LC 中国区新增取数来源限制还原，本月不上线
    --20261023 LYF 新增ods_src ZTSO04_TH
    /*20261030 中国区自营成本本月不上线：本行整体停用（7 个来源含 ZTSO04_TH 均不进数，与下方 NOT IN 同口径）*/
    /* OR ods_src IN ('ECPX','VBRP_O2O','VBRP_O2O_TH','VBRP_O2O_ZR','VBRP_O2O_TC','POLICY_COST','ZTSO04_TH') */
          )
      )
    )
  --20260930fjf_add REV001_STEP_11(成本聚合处理1)因中国区成本不上线，当ods_src是ECPX/VBRP_O2O/VBRP_O2O_TH/VBRP_O2O_ZR/VBRP_O2O_TC/POLICY_COST时不进数
  /*20261030 中国区自营成本本月不上线：ods_src 来源排除启用（原为 -- 注释，代码未删）*/
  AND ods_src NOT IN ('ECPX','VBRP_O2O','VBRP_O2O_TH','VBRP_O2O_ZR','VBRP_O2O_TC','POLICY_COST','ZTSO04_TH')
  -- ALTER BY XIAOYACHAO.EX 2026-10-03 17:03  物料 FU8MUP001MCH 剔除仅针对 1180/12% 公司，其他公司照常取数
  --AND nvl(MATERIAL_CODE,'NULL') <> 'FU8MUP001MCH'
  AND NOT ((COMPANY_CODE = '1180' OR COMPANY_CODE LIKE '12%') AND nvl(MATERIAL_CODE,'NULL') = 'FU8MUP001MCH')

  UNION ALL

  SELECT YEAR,MONTH,COMPANY_CODE,CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COST_CENTER_CODE,PROFITCENTER_CODE,CHANNEL_L3_CODE,MARKETING_MODE_CODE,ONOFFLINE_CODE,SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SYSTEM_SRC,SOLD_TO_CODE,SOLD_TO_NAME,product_line_code AS MATERIAL_GROUP_CODE/*ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line*/,CP_COMPANY_CODE,BATCH_ID,MATERIAL_PRICING_GROUP_CODE,QCY_CODE,ODS_SRC,COGS_AMT,TAX_RATE,EXCHANGE_RATE,BRAND_CODE,SPEC_SECTION_CODE,PRODUCT_SHAPE_TYPE_CODE,PRODUCT_SALE_SERIES_CODE,QUARTER_METHOD_CODE,PRODUCT_STAGE_CODE,PRICE_RANGE_CODE,PRODUCT_SERIES_CODE,MARKET_PNT_CODE,TECH_TYPE_CODE,PRODUCT_SMALL_CLASS_CODE,MODEL_LCA_CODE,PRODUCT_TYPE_CODE,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,CHANNEL_SMALL_CLASS_CODE,IND_SMALL_CLASS_CODE,COMM_BU_CODE,MARKETING_DEPT_CODE,BUS_RANGE_CODE,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,CUSTOMER_MODEL,product_line_name AS MATERIAL_GROUP_NAME/*ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line*/,MAKTX_S810,BUS_SCE_CAT_CODE,MINILED_TYPE_CODE
    ,ACCT_MAP_CODE,ACCT_SRC_CODE
    , bus_type_code as D_OPER_TYPE --业务分类
    , CN_CLASS_MARK_CODE
    , CN_CLASS_MARK_NAME
    ,Shipping_Order
      --20260917FJF_ADD 二期新增字段
    ,ee_level_code AS D_EFF_CLASS     --能效等级
    ,bu_code AS D_BU_SHOP             --门店所属BU
    ,niche_ec_store_code AS D_EC_STORE --电商细分店铺
    ,CUST_UNITY_CODE AS D_UNICUSTGRP     --统一客户组编码
  FROM DWD_FI_MR_GP_MSUM_MI_LCTEST
  WHERE 1=P_ORG_FLAG
  AND YEAR = SUBSTR(V_YEARMONTH, 1, 4)
  AND MONTH = SUBSTR(V_YEARMONTH, 5, 2)
  AND COMPANY_CODE IN  (SELECT ELEM FROM SESSION_AZIENDA_LIST S1 WHERE SESSION_ID = V_SESSION_ID
                         AND NOT EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S2
                                         WHERE S1.SESSION_ID =S2.SESSION_ID AND S2.ELEM =S1.ELEM
                                         AND S2.HIE = '10'  AND S2.NODE IN ('020')
                                        )
                                        )
  --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
  AND COMPANY_CODE NOT IN ('80J0')  -- 该公司从国际营销管报环境获取
    --EDIT BY LC 20260606 剔除国际营销公司取数
/*  AND COMPANY_CODE NOT IN (SELECT ELEM
                           FROM SESSION_V_REF_AZIENDA
                           WHERE SESSION_ID = V_SESSION_ID
                           AND HIE = '10'
                           AND NODE IN ('020'))*/
  AND TRIM(MATERIAL_CODE) IS NULL
  AND (ACCT_MAP_CODE LIKE '6401%'
      /*OR ACCT_MAP_CODE LIKE '6609%' AND SYSTEM_SRC <> 'SAP600' */
      OR Acct_src_code in  ('5508999002','5509999002'))
  AND NOT (COMPANY_CODE IN ('6380','6797') AND ACCT_MAP_CODE IN ('6609990101','6609990300'))
  AND NOT (COMPANY_CODE IN ('6515') AND ACCT_MAP_CODE IN ('6609990200'))
  AND (ACCT_MAP_CODE NOT IN ('6401000100')  OR (ACCT_MAP_CODE IN ('6401000100') AND order_type_code <> 'UE'))
  --2026.01.26 BY YANGHAO 修改 如果公司不为12或1180开头，则限制映射后科目不包含6401000000
  AND (
        (
          (COMPANY_CODE NOT LIKE '12%' OR COMPANY_CODE NOT LIKE '1180%') AND ACCT_MAP_CODE <> '6401000000'
          )
          OR COMPANY_CODE LIKE '12%'
      )
  AND ((COMPANY_CODE NOT IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200'))
    OR (COMPANY_CODE IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200')
      AND (TRIM(MATERIAL_CODE) LIKE 'F%' OR LTRIM(PROFITCENTER_CODE,0) IN ('8801002','8807002','790026000')
      OR ONOFFLINE_CODE IN ('030_AGY_002','030_AGY_003')
      --20260914FJF_ADD 成本聚合业务场景分类为026的要取数
      OR bus_sce_cat_code IN ('026') --EDIT BY LC 20260905 中国区成本 费用转政策部分 8月月结临时不取数
    --20260921FJF_ADD 中国区新增取数来源限制
    --20260929LC 中国区新增取数来源限制还原，本月不上线
    /*20261030 中国区自营成本本月不上线：本行整体停用（7 个来源含 ZTSO04_TH 均不进数，与下方 NOT IN 同口径）*/
    /* OR ods_src IN ('ECPX','VBRP_O2O','VBRP_O2O_TH','VBRP_O2O_ZR','VBRP_O2O_TC','POLICY_COST','ZTSO04_TH') */
          )
      )
    )
  -- 20260930fjf_add REV001_STEP_11(成本聚合处理1)因中国区成本不上线，当ods_src是ECPX/VBRP_O2O/VBRP_O2O_TH/VBRP_O2O_ZR/VBRP_O2O_TC/POLICY_COST时不进数
  /*20261030 中国区自营成本本月不上线：ods_src 来源排除启用（原为 -- 注释，代码未删）*/
  AND ods_src NOT IN ('ECPX','VBRP_O2O','VBRP_O2O_TH','VBRP_O2O_ZR','VBRP_O2O_TC','POLICY_COST','ZTSO04_TH')
   -- ALTER BY XIAOYACHAO.EX 2026-10-03 17:03  物料 FU8MUP001MCH 剔除仅针对 1180/12% 公司，其他公司照常取数
   -- AND nvl(MATERIAL_CODE,'NULL') <> 'FU8MUP001MCH'
   AND NOT ((COMPANY_CODE = '1180' OR COMPANY_CODE LIKE '12%') AND nvl(MATERIAL_CODE,'NULL') = 'FU8MUP001MCH')

  UNION ALL

  SELECT YEAR,MONTH,COMPANY_CODE,CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COST_CENTER_CODE,PROFITCENTER_CODE,CHANNEL_L3_CODE,MARKETING_MODE_CODE,ONOFFLINE_CODE,SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SYSTEM_SRC,SOLD_TO_CODE,SOLD_TO_NAME,product_line_code AS MATERIAL_GROUP_CODE/*ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line*/,CP_COMPANY_CODE,BATCH_ID,MATERIAL_PRICING_GROUP_CODE,QCY_CODE,ODS_SRC,COGS_AMT,TAX_RATE,EXCHANGE_RATE,BRAND_CODE,SPEC_SECTION_CODE,PRODUCT_SHAPE_TYPE_CODE,PRODUCT_SALE_SERIES_CODE,QUARTER_METHOD_CODE,PRODUCT_STAGE_CODE,PRICE_RANGE_CODE,PRODUCT_SERIES_CODE,MARKET_PNT_CODE,TECH_TYPE_CODE,PRODUCT_SMALL_CLASS_CODE,MODEL_LCA_CODE,PRODUCT_TYPE_CODE,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,CHANNEL_SMALL_CLASS_CODE,IND_SMALL_CLASS_CODE,COMM_BU_CODE,MARKETING_DEPT_CODE,BUS_RANGE_CODE,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,CUSTOMER_MODEL,product_line_name AS MATERIAL_GROUP_NAME/*ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line*/,MAKTX_S810,BUS_SCE_CAT_CODE,MINILED_TYPE_CODE
    ,ACCT_MAP_CODE,ACCT_SRC_CODE
    , bus_type_code as D_OPER_TYPE --业务分类
    , CN_CLASS_MARK_CODE
    , CN_CLASS_MARK_NAME
    ,Shipping_Order
      --20260917FJF_ADD 二期新增字段
    ,ee_level_code AS D_EFF_CLASS     --能效等级
    ,bu_code AS D_BU_SHOP             --门店所属BU
    ,niche_ec_store_code AS D_EC_STORE --电商细分店铺
    ,CUST_UNITY_CODE AS D_UNICUSTGRP     --统一客户组编码
  FROM DWD_FI_MR_GP_MSUM_MI_LCTEST
  WHERE 1=P_ORG_FLAG
  AND YEAR = SUBSTR(V_YEARMONTH, 1, 4)
  AND MONTH = SUBSTR(V_YEARMONTH, 5, 2)
  AND COMPANY_CODE IN  (SELECT ELEM FROM SESSION_AZIENDA_LIST S1 WHERE SESSION_ID = V_SESSION_ID
                         AND NOT EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S2
                                         WHERE S1.SESSION_ID =S2.SESSION_ID AND S2.ELEM =S1.ELEM
                                         AND S2.HIE = '10'  AND S2.NODE IN ('020')
                                        )
                                        )
  --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
  AND COMPANY_CODE NOT IN ('80J0')  -- 该公司从国际营销管报环境获取
    --EDIT BY LC 20260606 剔除国际营销公司取数
/*  AND COMPANY_CODE NOT IN (SELECT ELEM
                           FROM SESSION_V_REF_AZIENDA
                           WHERE SESSION_ID = V_SESSION_ID
                           AND HIE = '10'
                           AND NODE IN ('020'))*/
  AND TRIM(MATERIAL_CODE) IS NULL
  AND NOT (COMPANY_CODE IN ('6380','6797') AND ACCT_MAP_CODE IN ('6609990101','6609990300'))
  AND NOT (COMPANY_CODE IN ('6515') AND ACCT_MAP_CODE IN ('6609990200'))
   AND (ACCT_MAP_CODE = '6401000000' OR ACCT_MAP_CODE LIKE '6609990300%' OR (COMPANY_CODE = '6375' and ACCT_MAP_CODE LIKE '6609990200%'))
  --EDIT BY LC 20261014 增加 2910：TVS 物料为空且映射后科目=6401000000 的成本进数（段B 已排除 6401000000，原公司名单不含 2910 导致该批漏数）
  --EDIT BY XIAYACHAO 20261015 增加 6000A 物料为空且映射后科目=6401000000 的成本进数
  AND (COMPANY_CODE IN ('2300','2050','2080','6700','2900','6380','6515','6002','2910','6000A')  OR COMPANY_CODE LIKE '62%' OR COMPANY_CODE LIKE '63%'  /*ALTER BY 20260826 XIAOYACHAO.EX 公司增加6002万高*/
       OR COMPANY_CODE IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AZIENDA WHERE CITTA_LEGALE = '600'))
  --20260404 取BSEG_UE部分重复，排除中国区的公司  20260405 修改不止UE的凭证还有其他重复，将上一段代码现在放下来放not
  AND NOT (
            (ACCT_MAP_CODE LIKE '6401%'
                /*OR ACCT_MAP_CODE LIKE '6609%' AND SYSTEM_SRC <> 'SAP600' */
                OR Acct_src_code in  ('5508999002','5509999002'))
            AND NOT (COMPANY_CODE IN ('6380','6797') AND ACCT_MAP_CODE IN ('6609990101','6609990300'))
            AND NOT (COMPANY_CODE IN ('6515') AND ACCT_MAP_CODE IN ('6609990200'))
            AND (ACCT_MAP_CODE NOT IN ('6401000100')  OR (ACCT_MAP_CODE IN ('6401000100') AND order_type_code <> 'UE'))
            --2026.01.26 BY YANGHAO 修改 如果公司不为12或1180开头，则限制映射后科目不包含6401000000
            AND (
                  (
                    (COMPANY_CODE NOT LIKE '12%' OR COMPANY_CODE NOT LIKE '1180%') AND ACCT_MAP_CODE <> '6401000000'
                    )
                    OR COMPANY_CODE LIKE '12%'
                ))
  AND ((COMPANY_CODE NOT IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200'))
    OR (COMPANY_CODE IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200')
      AND (TRIM(MATERIAL_CODE) LIKE 'F%' OR LTRIM(PROFITCENTER_CODE,0) IN ('8801002','8807002','790026000')
      OR ONOFFLINE_CODE IN ('030_AGY_002','030_AGY_003')
    --20260914FJF_ADD 成本聚合业务场景分类为026的要取数
      OR bus_sce_cat_code IN ('026') --EDIT BY LC 20260905 中国区成本 费用转政策部分 8月月结临时不取数
    --20260921FJF_ADD 中国区新增取数来源限制
    --20260929LC 中国区新增取数来源限制还原，本月不上线
    /*20261030 中国区自营成本本月不上线：本行整体停用（7 个来源含 ZTSO04_TH 均不进数，与下方 NOT IN 同口径）*/
    /* OR ods_src IN ('ECPX','VBRP_O2O','VBRP_O2O_TH','VBRP_O2O_ZR','VBRP_O2O_TC','POLICY_COST','ZTSO04_TH') */
          )
      )
    )
  -- 20260930fjf_add REV001_STEP_11(成本聚合处理1)因中国区成本不上线，当ods_src是ECPX/VBRP_O2O/VBRP_O2O_TH/VBRP_O2O_ZR/VBRP_O2O_TC/POLICY_COST时不进数
  /*20261030 中国区自营成本本月不上线：ods_src 来源排除启用（原为 -- 注释，代码未删）*/
  AND ods_src NOT IN ('ECPX','VBRP_O2O','VBRP_O2O_TH','VBRP_O2O_ZR','VBRP_O2O_TC','POLICY_COST','ZTSO04_TH')
   -- ALTER BY XIAOYACHAO.EX 2026-10-03 17:03  物料 FU8MUP001MCH 剔除仅针对 1180/12% 公司，其他公司照常取数
   -- AND nvl(MATERIAL_CODE,'NULL') <> 'FU8MUP001MCH'
   AND NOT ((COMPANY_CODE = '1180' OR COMPANY_CODE LIKE '12%') AND nvl(MATERIAL_CODE,'NULL') = 'FU8MUP001MCH')

  UNION ALL

  SELECT YEAR,MONTH,COMPANY_CODE,CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COST_CENTER_CODE,PROFITCENTER_CODE,CHANNEL_L3_CODE,MARKETING_MODE_CODE,ONOFFLINE_CODE,SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SYSTEM_SRC,SOLD_TO_CODE,SOLD_TO_NAME,product_line_code AS MATERIAL_GROUP_CODE/*ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line*/,CP_COMPANY_CODE,BATCH_ID,MATERIAL_PRICING_GROUP_CODE,QCY_CODE,ODS_SRC,COGS_AMT,TAX_RATE,EXCHANGE_RATE,BRAND_CODE,SPEC_SECTION_CODE,PRODUCT_SHAPE_TYPE_CODE,PRODUCT_SALE_SERIES_CODE,QUARTER_METHOD_CODE,PRODUCT_STAGE_CODE,PRICE_RANGE_CODE,PRODUCT_SERIES_CODE,MARKET_PNT_CODE,TECH_TYPE_CODE,PRODUCT_SMALL_CLASS_CODE,MODEL_LCA_CODE,PRODUCT_TYPE_CODE,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,CHANNEL_SMALL_CLASS_CODE,IND_SMALL_CLASS_CODE,COMM_BU_CODE,MARKETING_DEPT_CODE,BUS_RANGE_CODE,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,CUSTOMER_MODEL,product_line_name AS MATERIAL_GROUP_NAME/*ALTER BY 20260928 XIAOYACHAO.EX 物料组改取product_line*/,MAKTX_S810,BUS_SCE_CAT_CODE,MINILED_TYPE_CODE
    ,ACCT_MAP_CODE,ACCT_SRC_CODE
    , bus_type_code as D_OPER_TYPE --业务分类
    , CN_CLASS_MARK_CODE
    , CN_CLASS_MARK_NAME
    ,Shipping_Order
      --20260917FJF_ADD 二期新增字段
    ,ee_level_code AS D_EFF_CLASS     --能效等级
    ,bu_code AS D_BU_SHOP             --门店所属BU
    ,niche_ec_store_code AS D_EC_STORE --电商细分店铺
    ,CUST_UNITY_CODE AS D_UNICUSTGRP     --统一客户组编码
  FROM DWD_FI_MR_GP_MSUM_MI_LCTEST
  WHERE 1=P_ORG_FLAG
  AND YEAR = SUBSTR(V_YEARMONTH, 1, 4)
  AND MONTH = SUBSTR(V_YEARMONTH, 5, 2)
  AND COMPANY_CODE IN  (SELECT ELEM FROM SESSION_AZIENDA_LIST S1 WHERE SESSION_ID = V_SESSION_ID
                         AND NOT EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S2
                                         WHERE S1.SESSION_ID =S2.SESSION_ID AND S2.ELEM =S1.ELEM
                                         AND S2.HIE = '10'  AND S2.NODE IN ('020')
                                        )
                                        )
  --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
  AND COMPANY_CODE NOT IN ('80J0')  -- 该公司从国际营销管报环境获取
    --EDIT BY LC 20260606 剔除国际营销公司取数
/*  AND COMPANY_CODE NOT IN (SELECT ELEM
                           FROM SESSION_V_REF_AZIENDA
                           WHERE SESSION_ID = V_SESSION_ID
                           AND HIE = '10'
                           AND NODE IN ('020'))*/
  AND (COMPANY_CODE IN ('6098') AND ACCT_MAP_CODE like '5001%' )
  -- 20260930fjf_add REV001_STEP_11(成本聚合处理1)因中国区成本不上线，当ods_src是ECPX/VBRP_O2O/VBRP_O2O_TH/VBRP_O2O_ZR/VBRP_O2O_TC/POLICY_COST时不进数
  /*20261030 中国区自营成本本月不上线：ods_src 来源排除启用（原为 -- 注释，代码未删）*/
  AND ods_src NOT IN ('ECPX','VBRP_O2O','VBRP_O2O_TH','VBRP_O2O_ZR','VBRP_O2O_TC','POLICY_COST','ZTSO04_TH')
  -- ALTER BY XIAOYACHAO.EX 2026-10-03 17:03  物料 FU8MUP001MCH 剔除仅针对 1180/12% 公司，其他公司照常取数
  -- AND nvl(MATERIAL_CODE,'NULL') <> 'FU8MUP001MCH'
  AND NOT ((COMPANY_CODE = '1180' OR COMPANY_CODE LIKE '12%') AND nvl(MATERIAL_CODE,'NULL') = 'FU8MUP001MCH')

  )
GROUP BY
     CONCAT(YEAR,'ACT') ,
     MONTH ,
     COALESCE(COMPANY_CODE, 'ZZZZ'),
     CUST_CODE,
     CUST_NAME,
     CASE WHEN TRIM(MATERIAL_CODE) LIKE 'FPRZW%' THEN ''
      WHEN COMPANY_CODE IN ('6098','6012') AND (ACCT_SRC_CODE LIKE '500103%' AND ACCT_SRC_CODE<>'5001030700'/*20261002 zhuangxinzhou 剔除5001030700*/OR ACCT_SRC_CODE IN ('6609990200','6609990101')) THEN ''
      ELSE TRIM(MATERIAL_CODE) END,
     MATERIAL_NAME,
     --'ZZZZ' AS COD_DEST1,
     NVL(COST_CENTER_CODE,'ZZZZ') ,
     --DECODE(LTRIM(PROFITCENTER_CODE,0),NULL,LTRIM(PRODUCT_LINE_CODE,0),'ZZZZ',LTRIM(PRODUCT_LINE_CODE,0),LTRIM(PROFITCENTER_CODE,0)) AS COD_DEST2,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') ,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') ,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') ,
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') ,
     COALESCE(MODEL_CODE, 'ZZZZ') ,
     COALESCE(SHOP_CODE, 'ZZZZ') ,
     SYSTEM_SRC ,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE ,
     COALESCE(QCY_CODE, 'ZZZZ') ,
     COALESCE(QCY_CODE, 'ZZZZ') ,
     UPPER(ODS_SRC) ,
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') ,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') ,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') ,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') ,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') ,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') ,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') ,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(COMM_BU_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') ,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') ,
      AGENCY_CODE,
      AGENCY_NAME,
     IS_MINILED_CODE,
   CUSTOMER_MODEL,
   MATERIAL_GROUP_NAME
   ,maktx_s810
   ,bus_sce_cat_code
   ,miniled_type_code-- MiniLED类型
   ,CASE WHEN (ACCT_MAP_CODE LIKE '5001%' AND COMPANY_CODE  = '6012') THEN 'S640190' ELSE 'S640100' END
   , D_OPER_TYPE --业务分类
   , CN_CLASS_MARK_CODE
   , CN_CLASS_MARK_NAME
    ,Shipping_Order
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
HAVING SUM(NVL(COGS_AMT,0)) <> 0
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','主营业务成本聚合处理完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_MODE, -- 销售模式
    D_ONOFFLINE, -- 线上线下
    SALE_MODEL_CODE, -- 销售型号
    MODEL_CODE, -- 产品型号
    SHOP_CODE, -- 门店
    SRC_SYSTEM, -- 源系统
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    MATERIAL_GROUP_CODE, -- 物料组
    COD_AZI_CTP, -- 对方公司
    BATCH_ID, -- 批次号
    D_PRC_GRP, -- 物料定价组
    COD_VALUTA, -- 货币
    COD_VALUTA_ORIGINARIA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    SALE_COGS, -- 成本金额
    TAX_RATE, -- 税率
    EXCHANGE_RATE, -- 汇率
    COD_DEST4, -- 品牌
    D_SPEC_SEC, -- 规格段
    D_PRO_TYPE_S, -- 产品形态分类
    D_PRO_SSER, -- 产品套系
    D_QUA_METHOD, -- 奥维产品四分法
    D_PRO_STAGE, -- 产品阶段
    D_PRI_RANGE, -- 价格段
    D_PRO_SERIES, -- 产品系列
    D_MARKET_PNT, -- 营销定位
    D_TECH_TYPE, -- 技术类型
    D_PRO_CLASS, -- 产品类别
    D_MODEL_LCA, -- 产品型号生命周期
    D_PRO_TYPE, -- 产品类型
    CUST_UNITY_NAME, -- 统一客户组
    CREDIT_LEVEL_NAME, -- 信用等级
    CUST_NATURE_NAME, -- 单位性质
    CUST_TYPE_NAME, -- 客户类型
    SHOP_NAME, -- 门店名称
    SALE_MODEL_NAME, -- 销售型号描述
    MODEL_NAME, -- 产品线型号描述
    D_CNL_C_TYPE, -- 渠道客户大类小类
    D_IND_C_TYPE, -- 行业客户大类小类
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    AGENCY_CODE, -- 销售部门编码
    AGENCY_NAME, -- 销售部门描述
    IS_MINILED_CODE, -- 是否MiniLED编码
    CUSTOMER_MODEL, -- 客户型号
    MATERIAL_GROUP_NAME
    ,maktx_s810
    ,D_MINILED-- MiniLED类型
    ,Shipping_Order
    ,D_OPER_TYPE
    --,BUS_TYPE_NAME
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)


SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     P_PERIODO AS COD_PERIODO,
     COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA,
    'S640102' AS COD_CONTO,                  --- 退货未办成本
     CUST_CODE,
     CUST_NAME,
     CASE WHEN TRIM(MATERIAL_CODE) LIKE ('FPRZW%') THEN '' ELSE TRIM(MATERIAL_CODE) END MATERIAL_CODE,
     MATERIAL_NAME,
     --'ZZZZ' AS COD_DEST1,
   NVL(COST_CENTER_CODE,'ZZZZ') AS COD_DEST1,
     --DECODE(LTRIM(PROFITCENTER_CODE,0),NULL,LTRIM(PRODUCT_LINE_CODE,0),'ZZZZ',LTRIM(PRODUCT_LINE_CODE,0),LTRIM(PROFITCENTER_CODE,0)) AS COD_DEST2,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') AS COD_DEST2,
   COALESCE(CHANNEL_L3_CODE, 'ZZZZ') AS D_CHANNEL,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') AS D_MODE,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE,
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') AS SALE_MODEL_CODE,
     COALESCE(MODEL_CODE, 'ZZZZ') AS MODEL_CODE,
     COALESCE(SHOP_CODE, 'ZZZZ') AS SHOP_CODE,
     SYSTEM_SRC AS SRC_SYSTEM,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE AS D_PRC_GRP,
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA,
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA_ORIGINARIA,
     CASE WHEN MONTH = P_PERIODO THEN  UPPER(ODS_SRC) ELSE UPPER(ODS_SRC)||'_LM' END AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(CASE WHEN MONTH = P_PERIODO THEN -COGS_AMT ELSE COGS_AMT END) AS SALE_COGS, -- 成本金额
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') AS COD_DEST4,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') AS D_SPEC_SEC,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE_S,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') AS D_PRO_SSER,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') AS D_QUA_METHOD,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') AS D_PRO_STAGE,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') AS D_PRI_RANGE,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') AS D_PRO_SERIES,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') AS D_MARKET_PNT,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') AS D_TECH_TYPE,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') AS D_PRO_CLASS,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') AS D_MODEL_LCA,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') AS D_CNL_C_TYPE,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') AS D_IND_C_TYPE,
     COALESCE(COMM_BU_CODE, 'ZZZZ') AS D_ECOM_BU,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') AS D_SALE_DEPT,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') AS COD_DEST3,
      AGENCY_CODE,
      AGENCY_NAME,
     IS_MINILED_CODE,
    CUSTOMER_MODEL,
     MATERIAL_GROUP_NAME
    ,maktx_s810
    ,miniled_type_code AS D_MINILED-- MiniLED类型
    ,Shipping_Order
    ,BUS_TYPE_CODE
    --,BUS_TYPE_NAME
    --20260917FJF_ADD 二期新增字段
    ,ee_level_code AS D_EFF_CLASS   --能效等级
    ,bu_code AS D_BU_SHOP     --门店所属BU
    ,niche_ec_store_code AS D_EC_STORE    --电商细分店铺
    ,CUST_UNITY_CODE AS D_UNICUSTGRP  --统一客户组编码
FROM  DWD_FI_MR_GP_MSUM_CKTH_MI
WHERE 1=P_ORG_FLAG
   AND (DT_MONTH = V_YEARMONTH OR DT_MONTH = TO_CHAR(ADD_MONTHS(TO_DATE(V_YEARMONTH,'YYYYMM'), -1), 'YYYYMM')
        )
  AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
  AND COMPANY_CODE NOT IN ('80J0')  -- 该公司从国际营销管报环境获取
  AND (MATERIAL_CODE NOT LIKE '000%' OR MATERIAL_CODE IS NULL)
  AND  ods_src in ('ZTSO04_TH', 'ZTSO04_TH_045')

  AND (COMPANY_CODE <> '6515' OR COMPANY_CODE = '6515' AND MATERIAL_CODE NOT IN ('Y000327','Y000219','Y000120'))
  AND ((COMPANY_CODE NOT IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200'))
    OR (COMPANY_CODE IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200')
      AND (TRIM(MATERIAL_CODE) LIKE 'F%' OR LTRIM(PROFITCENTER_CODE,0) IN ('8801002','8807002','790026000')
      OR ONOFFLINE_CODE IN ('030_AGY_002','030_AGY_003')
    --20260914FJF_ADD 成本聚合业务场景分类为026的要取数
    OR bus_sce_cat_code IN ('026') --EDIT BY LC 20260905 中国区成本 费用转政策部分 8月月结临时不取数
          )
      )
    )
GROUP BY
     CONCAT(YEAR,'ACT') ,
     P_PERIODO ,
     COALESCE(COMPANY_CODE, 'ZZZZ') ,
     CUST_CODE,
     CUST_NAME,
     CASE WHEN TRIM(MATERIAL_CODE) LIKE ('FPRZW%') THEN '' ELSE TRIM(MATERIAL_CODE) END ,
     MATERIAL_NAME,
     --'ZZZZ' AS COD_DEST1,
   NVL(COST_CENTER_CODE,'ZZZZ') ,
     --DECODE(LTRIM(PROFITCENTER_CODE,0),NULL,LTRIM(PRODUCT_LINE_CODE,0),'ZZZZ',LTRIM(PRODUCT_LINE_CODE,0),LTRIM(PROFITCENTER_CODE,0)) AS COD_DEST2,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') ,
   COALESCE(CHANNEL_L3_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') ,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') ,
     COALESCE(SALE_MODEL_CODE, 'ZZZZ'),
     COALESCE(MODEL_CODE, 'ZZZZ') ,
     COALESCE(SHOP_CODE, 'ZZZZ') ,
     SYSTEM_SRC ,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE ,
     COALESCE(QCY_CODE, 'ZZZZ') ,
     COALESCE(QCY_CODE, 'ZZZZ') ,
     CASE WHEN MONTH = P_PERIODO THEN  UPPER(ODS_SRC) ELSE UPPER(ODS_SRC)||'_LM' END  ,
     TAX_RATE,
     EXCHANGE_RATE,
     COALESCE(BRAND_CODE, 'ZZZZ') ,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') ,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') ,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') ,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') ,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') ,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') ,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(COMM_BU_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') ,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') ,
      AGENCY_CODE,
      AGENCY_NAME,
     IS_MINILED_CODE,
    CUSTOMER_MODEL,
    MATERIAL_GROUP_NAME
    ,maktx_s810
    ,miniled_type_code-- MiniLED类型
    ,Shipping_Order
    ,BUS_TYPE_CODE
    --,BUS_TYPE_NAME
    --20260917FJF_ADD 二期新增字段
    ,ee_level_code,bu_code,niche_ec_store_code,CUST_UNITY_CODE
HAVING SUM(NVL(COGS_AMT,0)) <> 0
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','退货未办成本聚合处理完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;



INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_ONOFFLINE, -- 线上线下
    MODEL_CODE, -- 产品型号
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    COD_AZI_CTP, -- 对方公司
    COD_VALUTA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    SALE_COGS, -- 成本金额
    COD_DEST4, -- 品牌
    D_MARKET_PNT,
    MODEL_NAME, -- 产品线型号描述
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    D_ADJ_TYPE
    ,CN_CLASS_MARK_CODE
    ,CN_CLASS_MARK_NAME
    ,BCY_COGS --成本金额-本位币（调整用）
    /*alter by 20260821-2 shiqingfeng.ex 成本调整数新增D_ECOM_BU字段*/
    ,D_ECOM_BU
    --20260917FJF_ADD 二期新增字段
    ,D_EC_STORE --电商细分店铺
    ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
)

SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     SUBSTR(year_month, 5, 2) AS COD_PERIODO,
     COALESCE(MI.COD_AZIENDA, 'ZZZZ') AS COD_AZIENDA,
    'S640100AD' AS COD_CONTO,--主营业务成本TA手工调整
     CUST_CODE AS CUST_CODE,
     CUST_NAME AS CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
     COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ') AS COD_DEST2,
     NVL(D_CHANNEL,'ZZZZ') AS D_CHANNEL,
     COALESCE(d_onoffline, 'ZZZZ') AS D_ONOFFLINE,
     COALESCE(MODEL_CODE, 'ZZZZ') AS MODEL_CODE,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     COD_AZI_CTP AS CP_COMPANY_CODE,
     'CNY' AS COD_VALUTA,
     'ADJM01' AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(sale_cogs,0))  AS SALE_COGS, -- 成本金额
     COD_DEST4 AS COD_DEST4,
     D_MARKET_PNT,
     MODEL_NAME AS MODEL_NAME,
     D_SALE_DEPT AS D_SALE_DEPT,
     COALESCE(COD_DEST3, 'ZZZZ') AS COD_DEST3,
     CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END
    ,CN_CLASS_MARK_CODE
    ,CN_CLASS_MARK_NAME
    ,SUM(MI.SALE_COGS * CA.CAMBIO_PERIODO) AS  BCY_COGS --成本金额-本位币（调整用）
    ,D_ECOM_BU
    --20260917FJF_ADD 二期新增字段
    ,D_EC_STORE as D_EC_STORE --电商细分店铺
    ,MI.D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
FROM TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001 MI
   LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
    ON MI.COD_AZIENDA = AZ.COD_AZIENDA
   LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
    ON CONCAT(SUBSTR(year_month,1,4),'ACT') = CA.COD_SCENARIO
   AND SUBSTR(year_month,5,2) = CA.COD_PERIODO
   AND AZ.COD_VALUTA = CA.COD_VALUTA
WHERE 1=1
  AND year_month = V_YEARMONTH
  AND MI.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, MI.COD_AZIENDA) > 0
  AND COD_CATEGORIA = 'ZFAMOUNT'
  AND COD_CONTO = 'ZAW_DWM_REV_STAN'
  AND D_ADJ_TYPE = 'REV_01_201'
GROUP BY
     year_month,
   NVL(D_CHANNEL,'ZZZZ'),
     COALESCE(MI.COD_AZIENDA, 'ZZZZ'),
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END,
     MATERIAL_CODE,
     MATERIAL_NAME,
     COD_DEST4,
     CUST_CODE,
     D_MARKET_PNT,
     CUST_NAME,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ'),
     COALESCE(d_onoffline, 'ZZZZ'),
     COALESCE(COD_DEST3, 'ZZZZ')
     ,D_SALE_DEPT
     ,COALESCE(MODEL_CODE, 'ZZZZ')
     ,MODEL_NAME
     ,COD_AZI_CTP
     ,CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END
     ,CN_CLASS_MARK_CODE
     ,CN_CLASS_MARK_NAME
     ,D_ECOM_BU
     --20260917FJF_ADD 二期新增字段
     ,D_EC_STORE --电商细分店铺
     ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
HAVING  SUM(NVL(sale_cogs,0)) !=0
;
COMMIT;
INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','主营业务成本TA手工调整成本聚合处理完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;



INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_ONOFFLINE, -- 线上线下
    MODEL_CODE, -- 产品型号
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    COD_AZI_CTP, -- 对方公司
    COD_VALUTA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    SALE_COGS, -- 汇率
    COD_DEST4, -- 品牌
    D_MARKET_PNT, -- 营销定位
    MODEL_NAME, -- 产品线型号描述
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    D_ADJ_TYPE
    ,CN_CLASS_MARK_CODE
    ,CN_CLASS_MARK_NAME
  ,BCY_COGS --成本金额-本位币（调整用）
  ,D_ECOM_BU
  --20260917FJF_ADD 二期新增字段
  ,D_EC_STORE --电商细分店铺
  ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
)

SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     SUBSTR(year_month, 5, 2) AS COD_PERIODO,
     COALESCE(MI.COD_AZIENDA, 'ZZZZ') AS COD_AZIENDA,
    'S640102AD' AS COD_CONTO,--退货未办成本TA手工调整
     CUST_CODE AS CUST_CODE,
     CUST_NAME AS CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
     COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ') AS COD_DEST2,
     NVL(D_CHANNEL,'ZZZZ') AS D_CHANNEL,
     COALESCE(d_onoffline, 'ZZZZ') AS D_ONOFFLINE,
     COALESCE(MODEL_CODE, 'ZZZZ') AS MODEL_CODE,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     COD_AZI_CTP AS CP_COMPANY_CODE,
     'CNY' AS COD_VALUTA,
     'ADJM01' AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(th_cogs,0))  AS SALE_COGS, -- 成本金额
     COD_DEST4 AS COD_DEST4,
     D_MARKET_PNT,
     MODEL_NAME AS MODEL_NAME,
     D_SALE_DEPT AS D_SALE_DEPT,
     COALESCE(COD_DEST3, 'ZZZZ') AS COD_DEST3,
     CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END
     ,CN_CLASS_MARK_CODE
     ,CN_CLASS_MARK_NAME
    ,SUM(MI.SALE_COGS * CA.CAMBIO_PERIODO) AS  BCY_COGS --成本金额-本位币（调整用）
    ,D_ECOM_BU
    --20260917FJF_ADD 二期新增字段
    ,D_EC_STORE --电商细分店铺
    ,MI.D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
FROM TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001 MI
   LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
    ON MI.COD_AZIENDA = AZ.COD_AZIENDA
   LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
    ON CONCAT(SUBSTR(year_month,1,4),'ACT') = CA.COD_SCENARIO
   AND SUBSTR(year_month,5,2) = CA.COD_PERIODO
   AND AZ.COD_VALUTA = CA.COD_VALUTA
WHERE 1=1
  AND year_month = V_YEARMONTH
  AND MI.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, MI.COD_AZIENDA) > 0
  AND COD_CATEGORIA = 'ZFAMOUNT'
  AND COD_CONTO = 'ZAW_DWM_REV_STAN'
  AND D_ADJ_TYPE = 'REV_01_201'
GROUP BY
     year_month,
     NVL(D_CHANNEL,'ZZZZ'),
     COALESCE(MI.COD_AZIENDA, 'ZZZZ'),
     CASE WHEN MI.COD_AZIENDA LIKE '17%' OR MI.COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END,
     MATERIAL_CODE,
     MATERIAL_NAME,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     COD_DEST4,
     CUST_CODE,
     CUST_NAME,
     D_MARKET_PNT,
     COD_AZI_CTP,
     D_SALE_DEPT,
     COALESCE(LTRIM(COD_DEST2,0), 'ZZZZ'),
     COALESCE(d_onoffline, 'ZZZZ'),
     COALESCE(COD_DEST3, 'ZZZZ'),
     COALESCE(MODEL_CODE, 'ZZZZ'),
     MODEL_NAME,
     CASE WHEN IMPORT_MARK = 'C' THEN 'REV_01_203' ELSE D_ADJ_TYPE END
    ,CN_CLASS_MARK_CODE
    ,CN_CLASS_MARK_NAME
    ,D_ECOM_BU
    --20260917FJF_ADD 二期新增字段
    ,D_EC_STORE --电商细分店铺
    ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
HAVING  SUM(NVL(th_cogs,0)) !=0
;
COMMIT;
INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','退货未办成本TA手工调整成本聚合处理完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;



INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    COD_VALUTA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    SALE_COGS -- 成本金额
)
   /*制造费用*/
   SELECT
     NEWID() AS OID,
     COD_SCENARIO,
     COD_PERIODO,
     COALESCE(COD_AZIENDA, 'ZZZZ') AS COD_AZIENDA,
     'S640190' AS COD_CONTO,
     'ZZZZ' AS COD_DEST1,
     'ZZZZ' AS COD_DEST2,
     COD_VALUTA AS COD_VALUTA,
     'MFEX' AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(MAP_SDJE,0))  AS SALE_COGS -- 成本金额


FROM (
/*非SAP600取数逻辑*/
   SELECT COD_SCENARIO,P_PERIODO COD_PERIODO
   ,SUBSTR(COD_AZIENDA,1,4) AS COD_AZIENDA
      ,SUM(DECODE(COD_PERIODO,P_PERIODO,1,-1)*IMPORTO) AS MAP_SDJE
      ,COD_VALUTA
FROM TGK_GB_HISENSE.DATI_SALDI_LORDI
WHERE 1=P_ORG_FLAG
  AND COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO BETWEEN  LPAD(P_PERIODO-1,2,'0') AND P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
  AND (COD_CATEGORIA IN ('$AMOUNT') OR COD_CATEGORIA LIKE '1%' OR  COD_CATEGORIA LIKE '2%')
  AND ((COD_CONTO LIKE'500101%'
       OR COD_CONTO LIKE'500102%'
       OR (COD_CONTO LIKE'500103%' AND COD_AZIENDA = '6515')
       OR COD_CONTO LIKE'500104%'
         OR COD_CONTO BETWEEN '6609990101' AND '6609990200' AND (COD_AZIENDA LIKE '18%' OR COD_AZIENDA = '6515')) AND LENGTH(COD_CONTO) = 10
          OR COD_CONTO LIKE '%M'
       )
AND (COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AZIENDA WHERE CITTA_LEGALE <> '600') OR   COD_AZIENDA = '6515')
AND COD_AZIENDA NOT IN (/* '6375', */'2021')--欧洲电子2021主体是通过手工导入录入的收入和成本
GROUP BY COD_AZIENDA,COD_SCENARIO,COD_VALUTA
HAVING SUM(DECODE(COD_PERIODO,P_PERIODO,1,-1)*IMPORTO)<>0

UNION ALL
/*SAP600取数逻辑*/
 SELECT COD_SCENARIO,P_PERIODO COD_PERIODO
   ,SUBSTR(COD_AZIENDA,1,4) AS COD_AZIENDA
      ,SUM(DECODE(COD_PERIODO,P_PERIODO,1,-1)*IMPORTO) AS MAP_SDJE
      ,COD_VALUTA
FROM TGK_GB_HISENSE.DATI_SALDI_LORDI
WHERE 1=P_ORG_FLAG
  AND COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO BETWEEN  LPAD(P_PERIODO-1,2,'0') AND P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
  AND COD_CATEGORIA IN ('$AMOUNT','1REC')
  AND ((COD_CONTO BETWEEN '5001010100' AND '5001029999'
         OR COD_CONTO BETWEEN '5001040000' AND '5001040900'
         OR COD_CONTO BETWEEN '5001030000' AND '5001039999' AND COD_AZIENDA NOT LIKE '23%' AND COD_AZIENDA NOT LIKE '208%' AND COD_AZIENDA NOT IN ('2050')
         OR COD_CONTO BETWEEN '6609990101' AND '6609990200' AND COD_AZIENDA LIKE '18%') AND LENGTH(COD_CONTO) = 10
       OR COD_CONTO LIKE '6601%M'
       )
  AND NOT (COD_CONTO IN ('5001030100','5001030700') AND COD_AZIENDA IN ('6380','6797'))
AND COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AZIENDA WHERE CITTA_LEGALE = '600')
AND COD_AZIENDA <> '6515'
AND COD_AZIENDA NOT IN (/* '6375', */'2021')--欧洲电子2021主体是通过手工导入录入的收入和成本
GROUP BY COD_AZIENDA,COD_SCENARIO,COD_VALUTA
HAVING SUM(DECODE(COD_PERIODO,P_PERIODO,1,-1)*IMPORTO)<>0
)
WHERE COALESCE(COD_AZIENDA, 'ZZZZ') NOT IN  ('2023' ,'6376','6377' ,'6098','6012','2910')  /*EDIT BY LC 20261027 2910 不生成 MFEX 制费转成本这笔数*/
GROUP BY COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_VALUTA

;

COMMIT;
INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','制造费用聚合处理完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*
  20260302 ADD BY shiqingfeng.ex 新增6515出库未开成本
  20260807-1 ALTER BY shiqingfeng.ex 6515出库未开成本拆分为当月成本和上月冲回两个INSERT，并增加分段执行日志
  20260807-2 ALTER BY shiqingfeng.ex 6515成本仅在SESSION_AZIENDA_LIST包含6515时执行
  20260807-3 ALTER BY shiqingfeng.ex SESSION_AZIENDA_LIST不包含6515时记录跳过日志
*/

SELECT COUNT(1)
  INTO V_6515_COUNT
  FROM SESSION_AZIENDA_LIST
 WHERE SESSION_ID = V_SESSION_ID
   AND ELEM = '6515';

IF V_6515_COUNT > 0 THEN

INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_MODE, -- 销售模式
    D_ONOFFLINE, -- 线上线下
    SALE_MODEL_CODE, -- 销售型号
    MODEL_CODE, -- 产品型号
    SHOP_CODE, -- 门店
    SRC_SYSTEM, -- 源系统
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    MATERIAL_GROUP_CODE, -- 物料组
    COD_AZI_CTP, -- 对方公司
    BATCH_ID, -- 批次号
    D_PRC_GRP, -- 物料定价组
    COD_VALUTA, -- 货币
    COD_VALUTA_ORIGINARIA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    SALE_COGS, -- 成本金额
    COD_DEST4, -- 品牌
    D_SPEC_SEC, -- 规格段
    D_PRO_TYPE_S, -- 产品形态分类
    D_PRO_SSER, -- 产品套系
    D_QUA_METHOD, -- 奥维产品四分法
    D_PRO_STAGE, -- 产品阶段
    D_PRI_RANGE, -- 价格段
    D_PRO_SERIES, -- 产品系列
    D_MARKET_PNT, -- 营销定位
    D_TECH_TYPE, -- 技术类型
    D_PRO_CLASS, -- 产品类别
    D_MODEL_LCA, -- 产品型号生命周期
    D_PRO_TYPE, -- 产品类型
    CUST_UNITY_NAME, -- 统一客户组
    CREDIT_LEVEL_NAME, -- 信用等级
    CUST_NATURE_NAME, -- 单位性质
    CUST_TYPE_NAME, -- 客户类型
    SHOP_NAME, -- 门店名称
    SALE_MODEL_NAME, -- 销售型号描述
    MODEL_NAME, -- 产品线型号描述
    D_CNL_C_TYPE, -- 渠道客户大类小类
    D_IND_C_TYPE, -- 行业客户大类小类
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    AGENCY_CODE, -- 销售部门编码
    AGENCY_NAME, -- 销售部门描述
    IS_MINILED_CODE, -- 是否MiniLED编码
    D_BU_TRAN, -- 事业部内外标识
    CUSTOMER_MODEL, -- 客户型号
    ORDER_TYPE_CODE, -- 订单类型
    zcalasset,  --按套统计
    CN_CLASS_MARK_CODE,  --中国区品类标记编码
    CN_CLASS_MARK_NAME,  --中国区品类标记描述
    SALE_CERT_TYPE,  --销售凭证类型
    D_ADJ_TYPE,  --调整类型
    MATERIAL_GROUP_NAME,
    maktx_s810
    ,D_MINILED-- MiniLED类型
    ,Shipping_Order
    ,D_OPER_TYPE
    --,BUS_TYPE_NAME
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)

SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     P_PERIODO AS COD_PERIODO,
     COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA,
     'S640101' AS COD_CONTO,
     CUST_CODE,
     CUST_NAME,
     CASE WHEN TRIM(MATERIAL_CODE) LIKE 'FPRZW%' THEN '' ELSE TRIM(MATERIAL_CODE) END AS MATERIAL_CODE,
     MATERIAL_NAME,
     NVL(COST_CENTER_CODE,'ZZZZ') AS COD_DEST1,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') AS COD_DEST2,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') AS D_CHANNEL,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') AS D_MODE,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE,
     /* COALESCE( 'ZZZZ') AS D_SALEINOUT, */
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') AS SALE_MODEL_CODE,
     COALESCE(MODEL_CODE, 'ZZZZ') AS MODEL_CODE,
     COALESCE(SHOP_CODE, 'ZZZZ') AS SHOP_CODE,
     SYSTEM_SRC AS SRC_SYSTEM,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE AS COD_AZI_CTP,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE AS D_PRC_GRP,
      /* MATERIAL_PRICING_GROUP_NAME AS MPG_NAME, */
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA,
     COALESCE(QCY_CODE, 'ZZZZ') AS COD_VALUTA_ORIGINARIA,
     UPPER(ODS_SRC) AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(NVL(SALE_COGS,0)) AS SALE_COGS,
     COALESCE(BRAND_CODE, 'ZZZZ') AS COD_DEST4,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') AS D_SPEC_SEC,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE_S,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') AS D_PRO_SSER,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') AS D_QUA_METHOD,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') AS D_PRO_STAGE,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') AS D_PRI_RANGE,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') AS D_PRO_SERIES,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') AS D_MARKET_PNT,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') AS D_TECH_TYPE,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') AS D_PRO_CLASS,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') AS D_MODEL_LCA,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') AS D_PRO_TYPE,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') AS D_CNL_C_TYPE,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') AS D_IND_C_TYPE,
     COALESCE(COMM_BU_CODE, 'ZZZZ') AS D_ECOM_BU,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') AS D_SALE_DEPT,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') AS COD_DEST3,
     AGENCY_CODE,
     AGENCY_NAME,
     IS_MINILED_CODE,
     D_BU_TRAN, -- 事业部内外标识
     CUSTOMER_MODEL, -- 客户型号
     ORDER_TYPE_CODE
    ,zcalasset,
     CN_CLASS_MARK_CODE,
     CN_CLASS_MARK_NAME,
     SALE_CERT_TYPE,
     '' AS D_ADJ_TYPE,  --调整类型
     MATERIAL_GROUP_NAME,
     maktx_s810
    ,miniled_type_code AS D_MINILED-- MiniLED类型
    ,Shipping_Order
    ,BUS_TYPE_CODE
    --,BUS_TYPE_NAME
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
FROM(
      SELECT
          YEAR, MONTH, MI.COMPANY_CODE, CUST_CODE, CUST_NAME, MI.MATERIAL_CODE,
          MATERIAL_NAME, PROFITCENTER_CODE, CHANNEL_L3_CODE, MARKETING_MODE_CODE, ONOFFLINE_CODE,
          SALE_MODEL_CODE, MODEL_CODE, SHOP_CODE, SYSTEM_SRC,
          -- SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, CP_COMPANY_CODE, BATCH_ID,
          SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, CP_COMPANY_CODE, BATCH_ID,
          MATERIAL_PRICING_GROUP_CODE, MATERIAL_PRICING_GROUP_NAME, QCY_CODE,
          CASE WHEN MONTH = P_PERIODO THEN UPPER(ODS_SRC) ELSE UPPER(ODS_SRC)||'_LM' END AS ODS_SRC,
          CASE WHEN MONTH = P_PERIODO THEN BILL_QTY ELSE -BILL_QTY END AS BILL_QTY,
          CASE WHEN MONTH = P_PERIODO THEN SHIP_QTY ELSE -SHIP_QTY END AS SHIP_QTY,
          CASE WHEN MONTH = P_PERIODO THEN ORDER_QTY ELSE -ORDER_QTY END AS ORDER_QTY,
          CASE WHEN MONTH = P_PERIODO THEN (NVL(SHIP_QTY,0)-NVL(BILL_QTY,0))*NVL(PRICE.MON_MV_PRICE,0) ELSE -(NVL(SHIP_QTY,0)-NVL(BILL_QTY,0))*NVL(PRICE.MON_MV_PRICE,0) END AS SALE_COGS,
          TAX_RATE, EXCHANGE_RATE,PRODUCT_SMALL_CLASS_CODE,
          BRAND_CODE,SPEC_SECTION_CODE,PRODUCT_SHAPE_TYPE_CODE,PRODUCT_SALE_SERIES_CODE,
          QUARTER_METHOD_CODE,PRODUCT_STAGE_CODE,PRICE_RANGE_CODE,PRODUCT_SERIES_CODE,
          MARKET_PNT_CODE,TECH_TYPE_CODE,MODEL_LCA_CODE,PRODUCT_TYPE_CODE,
          CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,SHOP_NAME,
          SALE_MODEL_NAME, MODEL_NAME, channel_small_class_code,IND_SMALL_CLASS_CODE,COMM_BU_CODE,
          MARKETING_DEPT_CODE,BUS_RANGE_CODE,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,
          ''AS D_BU_TRAN,
          CUSTOMER_MODEL,ORDER_TYPE_CODE
          ,zcalasset,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE
          ,MATERIAL_GROUP_NAME
          ,COST_CENTER_CODE
          ,maktx_s810
          ,miniled_type_code
          ,Shipping_Order
          ,BUS_TYPE_CODE
          ,BUS_TYPE_NAME
          --20260917FJF_ADD 二期新增字段
          ,ee_level_code AS D_EFF_CLASS     --能效等级
          ,bu_code AS D_BU_SHOP             --门店所属BU
          ,niche_ec_store_code AS D_EC_STORE --电商细分店铺
          ,CUST_UNITY_CODE AS D_UNICUSTGRP     --统一客户组编码
      FROM  DWD_FI_MR_GP_MSUM_CKTH_MI MI
      LEFT JOIN TGK_FIMA_HISENSE.ZTAB_MON_ST_PRICE PRICE
      ON MI.DT_MONTH = PRICE.DT_MONTH
      AND MI.MATERIAL_CODE = PRICE.MATERIAL_CODE
      AND MI.COMPANY_CODE = PRICE.COMPANY_CODE
      WHERE  1=P_ORG_FLAG
      AND MI.DT_MONTH = V_YEARMONTH
      AND MI.COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
      --AND INSTR(V_AZIENDA, MI.COMPANY_CODE) > 0
      /* AND MI.COMPANY_CODE NOT IN ('80J0') */  -- 该公司从国际营销管报环境获取
      AND MI.ODS_SRC = 'ZTSO04_CK'
      /* AND MI.COMPANY_CODE NOT LIKE '12%'
      AND MI.COMPANY_CODE NOT LIKE '1180' */
      AND MI.COMPANY_CODE = '6515'
       )T1
 GROUP BY
     COALESCE(COMPANY_CODE, 'ZZZZ') ,
     CUST_CODE,
     CUST_NAME,
     CASE WHEN TRIM(MATERIAL_CODE) LIKE 'FPRZW%' THEN '' ELSE TRIM(MATERIAL_CODE) END,
     MATERIAL_NAME,
     NVL(COST_CENTER_CODE,'ZZZZ') ,
     NVL(LTRIM(PROFITCENTER_CODE,0),'ZZZZ') ,
     COALESCE(CHANNEL_L3_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_MODE_CODE, 'ZZZZ') ,
     COALESCE(ONOFFLINE_CODE, 'ZZZZ') ,
     /* COALESCE( 'ZZZZ') AS D_SALEINOUT, */
     COALESCE(SALE_MODEL_CODE, 'ZZZZ') ,
     COALESCE(MODEL_CODE, 'ZZZZ') ,
     COALESCE(SHOP_CODE, 'ZZZZ') ,
     SYSTEM_SRC ,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     CP_COMPANY_CODE,
     BATCH_ID,
     MATERIAL_PRICING_GROUP_CODE ,
      /* MATERIAL_PRICING_GROUP_NAME AS MPG_NAME, */
     COALESCE(QCY_CODE, 'ZZZZ') ,
     COALESCE(QCY_CODE, 'ZZZZ') ,
     UPPER(ODS_SRC) ,
     COALESCE(BRAND_CODE, 'ZZZZ') ,
     COALESCE(SPEC_SECTION_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SHAPE_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SALE_SERIES_CODE, 'ZZZZ') ,
     COALESCE(QUARTER_METHOD_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_STAGE_CODE, 'ZZZZ') ,
     COALESCE(PRICE_RANGE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SERIES_CODE, 'ZZZZ') ,
     COALESCE(MARKET_PNT_CODE, 'ZZZZ') ,
     COALESCE(TECH_TYPE_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(MODEL_LCA_CODE, 'ZZZZ') ,
     COALESCE(PRODUCT_TYPE_CODE, 'ZZZZ') ,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     COALESCE(channel_small_class_code, 'ZZZZ') ,
     COALESCE(IND_SMALL_CLASS_CODE, 'ZZZZ') ,
     COALESCE(COMM_BU_CODE, 'ZZZZ') ,
     COALESCE(MARKETING_DEPT_CODE, 'ZZZZ') ,
     COALESCE(BUS_RANGE_CODE, 'ZZZZ') ,
     AGENCY_CODE,
     AGENCY_NAME,
     IS_MINILED_CODE,
     D_BU_TRAN, -- 事业部内外标识
     CUSTOMER_MODEL, -- 客户型号
     ORDER_TYPE_CODE
    ,zcalasset,
     CN_CLASS_MARK_CODE,
     CN_CLASS_MARK_NAME,
     SALE_CERT_TYPE,
     MATERIAL_GROUP_NAME
     ,maktx_s810
    ,miniled_type_code-- MiniLED类型
    ,Shipping_Order
    ,BUS_TYPE_CODE
    -- ,BUS_TYPE_NAME
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
HAVING SUM(NVL(SALE_COGS,0)) <> 0
;

COMMIT;
INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','6515当月出库未开成本处理完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/* 6515上月出库未开成本冲回 */
INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    CUST_CODE, -- 客商
    CUST_NAME, -- 客商描述
    MATERIAL_CODE, -- 物料
    MATERIAL_NAME, -- 物料描述
    COD_DEST1, -- 成本中心
    COD_DEST2, -- 产品线
    D_CHANNEL, -- 销售渠道
    D_MODE, -- 销售模式
    D_ONOFFLINE, -- 线上线下
    SALE_MODEL_CODE, -- 销售型号
    MODEL_CODE, -- 产品型号
    SHOP_CODE, -- 门店
    SRC_SYSTEM, -- 源系统
    SOLD_TO_CODE, -- 售达方
    SOLD_TO_NAME, -- 售达方名称
    MATERIAL_GROUP_CODE, -- 物料组
    COD_AZI_CTP, -- 对方公司
    BATCH_ID, -- 批次号
    D_PRC_GRP, -- 物料定价组
    COD_VALUTA, -- 货币
    COD_VALUTA_ORIGINARIA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    SALE_COGS, -- 成本金额
    COD_DEST4, -- 品牌
    D_SPEC_SEC, -- 规格段
    D_PRO_TYPE_S, -- 产品形态分类
    D_PRO_SSER, -- 产品套系
    D_QUA_METHOD, -- 奥维产品四分法
    D_PRO_STAGE, -- 产品阶段
    D_PRI_RANGE, -- 价格段
    D_PRO_SERIES, -- 产品系列
    D_MARKET_PNT, -- 营销定位
    D_TECH_TYPE, -- 技术类型
    D_PRO_CLASS, -- 产品类别
    D_MODEL_LCA, -- 产品型号生命周期
    D_PRO_TYPE, -- 产品类型
    CUST_UNITY_NAME, -- 统一客户组
    CREDIT_LEVEL_NAME, -- 信用等级
    CUST_NATURE_NAME, -- 单位性质
    CUST_TYPE_NAME, -- 客户类型
    SHOP_NAME, -- 门店名称
    SALE_MODEL_NAME, -- 销售型号描述
    MODEL_NAME, -- 产品线型号描述
    D_CNL_C_TYPE, -- 渠道客户大类小类
    D_IND_C_TYPE, -- 行业客户大类小类
    D_ECOM_BU, -- 电商BU渠道细分
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    AGENCY_CODE, -- 销售部门编码
    AGENCY_NAME, -- 销售部门描述
    IS_MINILED_CODE, -- 是否MiniLED编码
    D_BU_TRAN, -- 事业部内外标识
    CUSTOMER_MODEL, -- 客户型号
    ORDER_TYPE_CODE, -- 订单类型
    zcalasset,  --按套统计
    CN_CLASS_MARK_CODE,  --中国区品类标记编码
    CN_CLASS_MARK_NAME,  --中国区品类标记描述
    SALE_CERT_TYPE,  --销售凭证类型
    D_ADJ_TYPE,  --调整类型
    MATERIAL_GROUP_NAME,
    maktx_s810
    ,D_MINILED-- MiniLED类型
    --,Shipping_Order
    ,D_OPER_TYPE
)

/*20260318 ADD BY SHIQINGFENG.EX 6515出库未开成本上月数据取M层*/
SELECT
     NEWID() AS OID,
     P_SCENARIO AS COD_SCENARIO,
     P_PERIODO AS COD_PERIODO,
     COD_AZIENDA,
     'S640101' AS COD_CONTO,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     COD_DEST1,
     COD_DEST2,
     D_CHANNEL,
     D_MODE,
     D_ONOFFLINE,
     SALE_MODEL_CODE,
     MODEL_CODE,
     SHOP_CODE,
     SRC_SYSTEM,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     COD_AZI_CTP,
     BATCH_ID,
     D_PRC_GRP,
      /* MATERIAL_PRICING_GROUP_NAME AS MPG_NAME, */
     COD_VALUTA,
     COD_VALUTA_ORIGINARIA,
     SRC_DETAIL||'_LM' AS SRC_DETAIL,
     SESSION_USER AS USERUPD,
     SYSDATE AS DATEUPD,
     'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     0-SUM(NVL(SALE_COGS,0)) AS SALE_COGS,
     COD_DEST4,
     D_SPEC_SEC,
     D_PRO_TYPE_S,
     D_PRO_SSER,
     D_QUA_METHOD,
     D_PRO_STAGE,
     D_PRI_RANGE,
     D_PRO_SERIES,
     D_MARKET_PNT,
     D_TECH_TYPE,
     D_PRO_CLASS,
     D_MODEL_LCA,
     D_PRO_TYPE,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     D_CNL_C_TYPE,
     D_IND_C_TYPE,
     D_ECOM_BU,
     D_SALE_DEPT,
     COD_DEST3,
     AGENCY_CODE,
     AGENCY_NAME,
     IS_MINILED_CODE,
     D_BU_TRAN, -- 事业部内外标识
     CUSTOMER_MODEL, -- 客户型号
     ORDER_TYPE_CODE,
     zcalasset,
     CN_CLASS_MARK_CODE,
     CN_CLASS_MARK_NAME,
     SALE_CERT_TYPE,
     D_ADJ_TYPE,  --调整类型
     MATERIAL_GROUP_NAME,
     maktx_s810
    ,'' AS D_MINILED-- MiniLED类型
    --,Shipping_Order
    ,D_OPER_TYPE
FROM ZTAB_6401_FTQ MI--TGK_FIMA_HISENSE.AW_MR9_REVM01_000001 MI modify by ljy 调整数据来源表 20260503
WHERE  1=P_ORG_FLAG
AND MI.COD_SCENARIO = V_SCENARIO_PRE
AND MI.COD_PERIODO = V_PERIODO_PRE
AND MI.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, MI.COD_AZIENDA) > 0
/* AND MI.COD_AZIENDA NOT IN ('80J0') */  -- 该公司从国际营销管报环境获取
AND MI.SRC_DETAIL = 'ZTSO04_CK'
/* AND MI.COD_AZIENDA NOT LIKE '12%'
AND MI.COD_AZIENDA NOT LIKE '1180' */
AND MI.COD_AZIENDA = '6515'
AND MI.COD_CONTO = 'S640101'
AND MI.PROVENIENZA = 'CPM_SP_D2M_REV_M'
 GROUP BY
     COD_AZIENDA,
     CUST_CODE,
     CUST_NAME,
     MATERIAL_CODE,
     MATERIAL_NAME,
     COD_DEST1,
     COD_DEST2,
     D_CHANNEL,
     D_MODE,
     D_ONOFFLINE,
     SALE_MODEL_CODE,
     MODEL_CODE,
     SHOP_CODE,
     SRC_SYSTEM,
     SOLD_TO_CODE,
     SOLD_TO_NAME,
     MATERIAL_GROUP_CODE,
     COD_AZI_CTP,
     BATCH_ID,
     D_PRC_GRP,
      /* MATERIAL_PRICING_GROUP_NAME AS MPG_NAME, */
     COD_VALUTA,
     COD_VALUTA_ORIGINARIA,
     SRC_DETAIL||'_LM',
     COD_DEST4,
     D_SPEC_SEC,
     D_PRO_TYPE_S,
     D_PRO_SSER,
     D_QUA_METHOD,
     D_PRO_STAGE,
     D_PRI_RANGE,
     D_PRO_SERIES,
     D_MARKET_PNT,
     D_TECH_TYPE,
     D_PRO_CLASS,
     D_MODEL_LCA,
     D_PRO_TYPE,
     CUST_UNITY_NAME,
     CREDIT_LEVEL_NAME,
     CUST_NATURE_NAME,
     CUST_TYPE_NAME,
     SHOP_NAME,
     SALE_MODEL_NAME,
     MODEL_NAME,
     D_CNL_C_TYPE,
     D_IND_C_TYPE,
     D_ECOM_BU,
     D_SALE_DEPT,
     COD_DEST3,
     AGENCY_CODE,
     AGENCY_NAME,
     IS_MINILED_CODE,
     D_BU_TRAN, -- 事业部内外标识
     CUSTOMER_MODEL, -- 客户型号
     ORDER_TYPE_CODE,
     zcalasset,
     CN_CLASS_MARK_CODE,
     CN_CLASS_MARK_NAME,
     SALE_CERT_TYPE,
     D_ADJ_TYPE,  --调整类型
     MATERIAL_GROUP_NAME,
     maktx_s810
     --,Shipping_Order
  ,D_OPER_TYPE
HAVING SUM(NVL(SALE_COGS,0)) <> 0
;

COMMIT;
INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','6515成本处理完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

ELSE
  INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
  VALUES('CPM_SP_D2M_REV_M','6515成本处理跳过-组织范围不含6515',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
  COMMIT;
END IF; -- SESSION_AZIENDA_LIST包含6515时执行


/*20260624 ADD BY SHIQINGFENG.EX 中国区代理费费用转主营业务成本 */
INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
    OID,
    COD_SCENARIO, -- 场景
    COD_PERIODO, -- 期间
    COD_AZIENDA, -- 公司
    COD_CONTO, -- 科目
    COD_CATEGORIA,
    COD_DEST2, -- 产品线
    D_ONOFFLINE, -- 线上线下
    SRC_SYSTEM, -- 源系统
    COD_VALUTA_ORIGINARIA, -- 货币
    SRC_DETAIL, -- 来源
    USERUPD, -- 更新用户
    DATEUPD, -- 更新日期
    PROVENIENZA, -- 来源系统
    SALE_COGS, -- 成本金额
    COD_DEST4, -- 品牌
    D_SALE_DEPT, -- 业务管理单元
    COD_DEST3, -- 业务范围
    BCY_COGS,  --成本金额-本位币（调整用）
    D_OPER_TYPE, --业务分类
    CN_SALE_COGS --管报成本（中国区）
)


SELECT
    NEWID() AS OID,
    P_SCENARIO AS COD_SCENARIO, -- 场景
    P_PERIODO AS COD_PERIODO, -- 期间
    CON3.COD_AZIENDA, -- 公司
    'S640100' AS COD_CONTO, -- 科目
    'ZAMOUNT' AS COD_CATEGORIA,
    '990999000' AS COD_DEST2, -- 产品线
    CASE WHEN CON3.COD_DEST5 = 'OFF' THEN '030_AGY_003'
         WHEN CON3.COD_DEST5 = 'ON' THEN '030_AGY_002'
    END AS D_ONOFFLINE, -- 线上线下
    'TA' AS SRC_SYSTEM, -- 源系统
    COD_VALUTA AS COD_VALUTA_ORIGINARIA, -- 货币
    'GB_RIGA' AS SRC_DETAIL, -- 来源
    SESSION_USER AS USERUPD, -- 更新用户
    SYSDATE AS DATEUPD, -- 更新日期
    'CPM_SP_D2M_REV_M' AS PROVENIENZA, -- 来源系统
    SUM(CASE WHEN COD_PERIODO = V_PERIODO THEN IMPORTO
             WHEN COD_PERIODO = V_PERIODO_PRE THEN 0-IMPORTO
        END) AS SALE_COGS, -- 成本金额
    'ZZZZ' AS COD_DEST4, -- 品牌
    'ZZZZ' AS D_SALE_DEPT, -- 业务管理单元
    CASE WHEN CON3.COD_DEST5 = 'OFF' THEN '2000'
         WHEN CON3.COD_DEST5 = 'ON' THEN '2300'
    END AS COD_DEST3, -- 业务范围
    SUM(CASE WHEN COD_PERIODO = V_PERIODO THEN IMPORTO
             WHEN COD_PERIODO = V_PERIODO_PRE THEN 0-IMPORTO
        END) BCY_COGS,  --成本金额-本位币（调整用）
    CASE WHEN CON3.COD_DEST5 = 'OFF' THEN 'OPTY028'
         WHEN CON3.COD_DEST5 = 'ON' THEN 'OPTY027'
    END AS D_OPER_TYPE, --业务分类
    SUM(CASE WHEN COD_PERIODO = V_PERIODO THEN IMPORTO
             WHEN COD_PERIODO = V_PERIODO_PRE THEN 0-IMPORTO
        END) CN_SALE_COGS --管报成本（中国区）
FROM  TGK_GB_HISENSE.DATI_RETT_RIGA_CONS_3 CON3
WHERE 1=P_ORG_FLAG
AND CON3.COD_SCENARIO IN (SUBSTR(V_SCENARIO,0,4)||'LC_ZT2',SUBSTR(V_SCENARIO_PRE,0,4)||'LC_ZT2')
AND CON3.COD_PERIODO IN (V_PERIODO,V_PERIODO_PRE)
AND CON3.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID AND (ELEM = '1180' OR ELEM LIKE '12%'))
AND CON3.COD_CONTO LIKE '6401%'
AND CON3.COD_CATEGORIA = '3ADJ'
AND CON3.COD_AZI_CTP_SEGMENT = '1202'
AND CON3.NUM_RETTIFICA LIKE '%DKFYHY%'
GROUP BY
    CON3.COD_AZIENDA, -- 公司
    CASE WHEN CON3.COD_DEST5 = 'OFF' THEN '030_AGY_003'
         WHEN CON3.COD_DEST5 = 'ON' THEN '030_AGY_002'
    END , -- 线上线下
    COD_VALUTA, -- 货币
    CASE WHEN CON3.COD_DEST5 = 'OFF' THEN '2000'
         WHEN CON3.COD_DEST5 = 'ON' THEN '2300'
    END , -- 业务范围
    CASE WHEN CON3.COD_DEST5 = 'OFF' THEN 'OPTY028'
         WHEN CON3.COD_DEST5 = 'ON' THEN 'OPTY027'
    END  --业务分类
HAVING SUM(CASE WHEN COD_PERIODO = V_PERIODO THEN IMPORTO
             WHEN COD_PERIODO = V_PERIODO_PRE THEN 0-IMPORTO
        END) <> 0
;



INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.11 REV001_STEP_11(成本聚合处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/* 2.2.11.1 REV001_STEP_11(成本聚合处理-日立) */
DELETE FROM ZTAB_HITACH_ZXSLR_FINALLY T
 WHERE 1 = P_ORG_FLAG
   AND T.GJAHR = SUBSTR(V_YEARMONTH, 1, 4)
   AND T.POPER = P_PERIODO
;
COMMIT;

INSERT INTO ZTAB_HITACH_ZXSLR_FINALLY
SELECT GJAHR, POPER, BUKRS, MATNR, MVGR2, BEZEI, BISMT, MAKTX, MEINS, MNG_BE,
       BTR_BE, MNG_SEND_BE, BTR_SEND_BE, MNG_PRODUCT_SAP, BTR_PRODUCT_SAP,
       MNG_BUY, BTR_BUY, MNG_CHG, BTR_CHG, FKIMG_MON, INCOM_MON, COST_MON,
       MNG_CST, BTR_CST, MNG_FIX, BTR_FIX, MNG_OTHER_SALE, BTR_OTHER_SALE,
       MNG_CASH_SALE_EXCHANGE, BTR_CASH_SALE_EXCHANGE, MNG_OUT_OTHER,
       BTR_OUT_OTHER, MNG_STOCK_EN, BTR_STOCK_EN, MNG_DLV, BTR_DLV,
       MNG_BALANCE_EN, BTR_BALANCE_EN, BTR_FACE_ZHENGJI, MNG_FACE_OUT,
       BTR_FACE_OUT, MNG_MATNR_IN, BTR_MATNR_IN, MNG_CASH_SALE, MNG_EXCHANGE,
       MNG_OUT_OTHER2, BTR_OUT_OTHER2, FREIGHT, DIF2, DIF, MNG_CHEAK,
       BTR_CHEAK, DATA_MONTH, SRC_MARK, USERUPD, DATEUPD
  FROM TGK_GB_HISENSE.ZTAB_HITACH_ZXSLR_FINALLY T
 WHERE 1 = P_ORG_FLAG
   AND T.GJAHR = SUBSTR(V_YEARMONTH, 1, 4)
   AND T.POPER = P_PERIODO
   AND EXISTS (
      SELECT 1
      FROM TGK_FIMA_HISENSE.AW_RUL_REVAAZ_000001 REVAAZ
      WHERE EXISTS (SELECT 1 FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID AND (ELEM LIKE '17%' OR ELEM = '6240') AND ELEM = COD_AZIENDA)
        AND T.BUKRS = REVAAZ.ENT_SAP700_CODE
   )
   ;
COMMIT;

DELETE FROM ZTAB_HITACH_ZXSLR_FINALLY_TEMP T
 WHERE EXISTS (SELECT 1
                             FROM SESSION_AZIENDA_LIST
                            WHERE SESSION_ID = V_SESSION_ID
                              AND (ELEM LIKE '17%' OR ELEM = '6240')
                              AND ELEM = BUKRS)
                              ;
COMMIT;

INSERT INTO ZTAB_HITACH_ZXSLR_FINALLY_TEMP
  (GJAHR, POPER, BUKRS, MATNR, MEINS, BISMT, COST_MON, FKIMG_MON, DWCB)
SELECT GJAHR,POPER,REVAAZ.COD_AZIENDA AS BUKRS,MATNR,MAX(MEINS) AS MEINS,MAX(BISMT) AS BISMT
      ,SUM(COST_MON) AS COST_MON,SUM(FKIMG_MON) AS FKIMG_MON
      ,DECODE(SUM(FKIMG_MON),0,0,SUM(COST_MON)/SUM(FKIMG_MON)) AS DWCB
    FROM ZTAB_HITACH_ZXSLR_FINALLY T   /*ALTER BY LC 20261117 20:20 【R5】改读本地表：上方 L3945 刚把当期数据从 GB 库灌进本地 FINALLY，
                                          原写 TGK_FIMA_HISENSE 会读到生产那张空表（生产 FINALLY 当期 0 行），聚合结果必然 0 行*/
   --日立收入-公司映射
   INNER JOIN
   (
      SELECT ENT_SAP700_CODE,COD_AZIENDA
      FROM TGK_FIMA_HISENSE.AW_RUL_REVAAZ_000001
      WHERE EXISTS (SELECT 1 FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID AND (ELEM LIKE '17%' OR ELEM = '6240') AND ELEM = COD_AZIENDA)
   ) REVAAZ
   ON T.BUKRS = REVAAZ.ENT_SAP700_CODE
    WHERE 1 = P_ORG_FLAG
    AND T.GJAHR = SUBSTR(V_YEARMONTH ,1 ,4)
    AND T.POPER = P_PERIODO
    --AND REVAAZ.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID AND (ELEM LIKE '17%' OR ELEM = '6240'))
    --AND INSTR(V_AZIENDA ,REVAAZ.COD_AZIENDA) > 0
    --AND (REVAAZ.COD_AZIENDA LIKE '17%' OR REVAAZ.COD_AZIENDA = '6240') --限制日立相关公司
    GROUP BY GJAHR,POPER,REVAAZ.COD_AZIENDA,MATNR
    HAVING SUM(FKIMG_MON) <> 0
    ;

COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.11.1.1 REV001_STEP_11(成本聚合处理-日立)管报取数中间表更新完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

INSERT INTO AW_MR9_REVM01_000001_TEMP
(
  OID
  ,COD_SCENARIO            --场景
  ,COD_PERIODO             --期间
  ,COD_AZIENDA             --公司
  ,COD_CONTO               --科目
  ,CUST_CODE               --客商
  ,CUST_NAME               --客商描述
  ,MATERIAL_CODE           --物料
  ,MATERIAL_NAME           --物料描述
  ,COD_DEST2               --产品线（利润中心）
  ,D_CHANNEL               --销售渠道（公司三级分类）
  ,D_MODE                  --销售模式（营销模式）
  ,D_ONOFFLINE             --线上线下（渠道分组）
  ,SALE_MODEL_CODE         --销售型号
  ,MODEL_CODE              --产品型号
  ,SHOP_CODE               --门店
  ,SRC_SYSTEM              --源系统
  ,SOLD_TO_CODE            --售达方
  ,SOLD_TO_NAME            --售达方名称
  ,MATERIAL_GROUP_CODE     --物料组
  ,COD_AZI_CTP             --对方公司
  ,BATCH_ID                --批次号
  ,D_PRC_GRP               --定价组
  ,COD_VALUTA        --货币
  ,COD_VALUTA_ORIGINARIA   --货币
  ,SRC_DETAIL              --来源
  ,USERUPD                 --更新用户
  ,DATEUPD                 --更新日期
  ,PROVENIENZA       --来源系统
  ,SALE_COGS               --成本金额
  ,TAX_RATE                --税率
  ,EXCHANGE_RATE           --汇率
  ,COD_DEST1               --成本中心（区域）
  ,COD_DEST4               --品牌
  ,D_SPEC_SEC              --规格段
  ,D_PRO_TYPE_S            --产品形态分类
  ,D_PRO_SSER              --产品套系
  ,D_QUA_METHOD            --奥维产品四分法
  ,D_PRO_STAGE             --产品阶段
  ,D_PRI_RANGE             --价格段
  ,D_PRO_SERIES            --产品系列
  ,D_MARKET_PNT            --营销定位
  ,D_TECH_TYPE             --技术类型
  ,D_PRO_CLASS             --产品类别
  ,D_MODEL_LCA             --产品型号生命周期
  ,D_PRO_TYPE              --产品类型
  ,CUST_UNITY_NAME         --统一客户组
  ,CREDIT_LEVEL_NAME       --信用等级
  ,CUST_NATURE_NAME        --单位性质
  ,CUST_TYPE_NAME          --客户类型
  ,SHOP_NAME               --门店名称
  ,SALE_MODEL_NAME         --销售型号描述
  ,MODEL_NAME              --产品线型号描述
  ,D_CNL_C_TYPE            --渠道客户大类小类
  ,D_IND_C_TYPE            --行业客户大类小类
  ,D_ECOM_BU               --电商BU渠道细分
  ,D_SALE_DEPT             --业务管理单元
  ,COD_DEST3               --业务范围
  ,AGENCY_CODE             --销售部门编码
  ,AGENCY_NAME             --销售部门描述
  ,IS_MINILED_CODE         --是否MINILED编码
  ,CUSTOMER_MODEL          --客户型号
  ,AVG_UNIT_COST       --平均单位成本
  ,D_MINILED-- MiniLED类型
)
SELECT
  NEWID() AS OID
  ,P_SCENARIO  AS COD_SCENARIO            --场景
  ,P_PERIODO AS COD_PERIODO             --期间
  ,T.BUKRS AS COD_AZIENDA             --公司
  ,'S640100' AS COD_CONTO               --科目
  ,A.CUST_CODE AS CUST_CODE               --客商
  ,A.CUST_NAME AS CUST_NAME               --客商描述
  ,T.MATNR AS MATERIAL_CODE           --物料
  ,T.MEINS AS MATERIAL_NAME           --物料描述
  ,A.COD_DEST2 AS COD_DEST2               --产品线（利润中心）
  ,A.D_CHANNEL      AS D_CHANNEL               --销售渠道（公司三级分类）
  ,A.D_MODE       AS D_MODE                  --销售模式（营销模式）
  ,A.D_ONOFFLINE    AS D_ONOFFLINE             --线上线下（渠道分组）
  ,DFP.SALE_MODEL_CODE  AS SALE_MODEL_CODE         --销售型号
  ,DFP.MODEL_CODE     AS MODEL_CODE              --产品型号
  ,A.SHOP_CODE      AS SHOP_CODE               --门店
  ,'TA'         AS SRC_SYSTEM              --源系统
  ,A.SOLD_TO_CODE     AS SOLD_TO_CODE            --售达方
  ,A.SOLD_TO_NAME     AS SOLD_TO_NAME            --售达方名称
  ,T.BISMT        AS MATERIAL_GROUP_CODE     --物料组
  ,A.COD_AZI_CTP    AS COD_AZI_CTP             --对方公司
  ,A.BATCH_ID       AS BATCH_ID                --批次号
  ,A.D_PRC_GRP      AS D_PRC_GRP               --定价组
  ,A.COD_VALUTA     AS COD_VALUTA           --货币
  ,A.COD_VALUTA_ORIGINARIA AS COD_VALUTA_ORIGINARIA --货币
  ,'GB_ZXSLR'       AS SRC_DETAIL              --来源
  ,SESSION_USER     AS USERUPD                 --更新用户
  ,SYSDATE        AS DATEUPD                 --更新日期
  ,'CPM_SP_D2M_REV_M'   AS PROVENIENZA           --来源系统
  ,T.DWCB * BILL_QTY  AS SALE_COGS               --成本金额
  ,A.TAX_RATE       AS TAX_RATE                --税率
  ,A.EXCHANGE_RATE    AS EXCHANGE_RATE           --汇率
  ,A.COD_DEST1      AS COD_DEST1               --成本中心（区域）
  ,COALESCE(DFP.BRAND, 'ZZZZ')      AS COD_DEST4               --品牌
  ,A.D_SPEC_SEC     AS D_SPEC_SEC              --规格段
  ,A.D_PRO_TYPE_S     AS D_PRO_TYPE_S            --产品形态分类
  ,DFP.PROD_SUITE_CODE  AS D_PRO_SSER              --产品套系
  ,A.D_QUA_METHOD     AS D_QUA_METHOD            --奥维产品四分法
  ,A.D_PRO_STAGE    AS D_PRO_STAGE             --产品阶段
  ,A.D_PRI_RANGE    AS D_PRI_RANGE             --价格段
  ,DFP.SERIES_CODE    AS D_PRO_SERIES            --产品系列
  ,DFP.MARKET_POS_CODE  AS D_MARKET_PNT            --营销定位
  ,DFP.AC_CT_CODE     AS D_TECH_TYPE             --技术类型
  ,A.D_PRO_CLASS        AS D_PRO_CLASS             --产品类别
  ,A.D_MODEL_LCA        AS D_MODEL_LCA             --产品型号生命周期
  ,A.D_PRO_TYPE         AS D_PRO_TYPE              --产品类型
  ,A.CUST_UNITY_NAME    AS CUST_UNITY_NAME         --统一客户组
  ,A.CREDIT_LEVEL_NAME  AS CREDIT_LEVEL_NAME       --信用等级
  ,A.CUST_NATURE_NAME   AS CUST_NATURE_NAME        --单位性质
  ,A.CUST_TYPE_NAME     AS CUST_TYPE_NAME          --客户类型
  ,A.SHOP_NAME          AS SHOP_NAME               --门店名称
  ,A.SALE_MODEL_NAME    AS SALE_MODEL_NAME         --销售型号描述
  ,A.MODEL_NAME         AS MODEL_NAME              --产品线型号描述
  ,A.D_CNL_C_TYPE       AS D_CNL_C_TYPE            --渠道客户大类小类
  ,A.D_IND_C_TYPE       AS D_IND_C_TYPE            --行业客户大类小类
  ,A.D_ECOM_BU        AS D_ECOM_BU              --电商BU渠道细分
  ,A.D_SALE_DEPT        AS D_SALE_DEPT             --业务管理单元
  ,A.COD_DEST3          AS COD_DEST3               --业务范围
  ,A.AGENCY_CODE        AS AGENCY_CODE             --销售部门编码
  ,A.AGENCY_NAME        AS AGENCY_NAME             --销售部门描述
  ,A.IS_MINILED_CODE    AS IS_MINILED_CODE         --是否MINILED编码
  ,A.CUSTOMER_MODEL     AS CUSTOMER_MODEL          --客户型号
  ,T.DWCB       AS AVG_UNIT_COST          --平均单位成本
  ,A.D_MINILED-- MiniLED类型
FROM
  (
    SELECT *
    FROM AW_MR9_REVM01_000001_TEMP
    WHERE 1 = 1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND EXISTS (SELECT 1 FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID AND (ELEM LIKE '17%' OR ELEM = '6240') AND ELEM = COD_AZIENDA)
    --AND INSTR(V_AZIENDA ,COD_AZIENDA) > 0
    --AND (COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240') --限制日立相关公司
    AND COD_CONTO = 'S600100'
    AND NVL(SALE_REV,0) <> 0
  )A
INNER JOIN ZTAB_HITACH_ZXSLR_FINALLY_TEMP T   /*ALTER BY LC 20261117 20:20 【R5】改读本地表：与 L3978 灌入的 TEMP 配对，
                                                  原写 TGK_FIMA_HISENSE 读的是生产上一次跑批的快照（10,757 行），
                                                  与本地当期数据不同源，日立拆分必然对不上（1740 少 2,633 行、1730 少 883 行）*/
ON T.BUKRS = A.COD_AZIENDA
AND T.MATNR = A.MATERIAL_CODE
LEFT JOIN TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD DFP
ON DFP.MATNR = T.MATNR
;
COMMIT;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.11.1 REV001_STEP_11(成本聚合处理-日立)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.10 REV001_STEP_10(政策分摊)*/


INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
  OID,
  COD_SCENARIO, -- 场景
  COD_PERIODO, -- 期间
  COD_AZIENDA, -- 公司
  COD_CONTO, -- 科目
  CUST_CODE, -- 客商
  CUST_NAME, -- 客商描述
  MATERIAL_CODE, -- 物料
  MATERIAL_NAME, -- 物料描述
  COD_DEST2, -- 产品线
  D_CHANNEL, -- 销售渠道（公司三级分类）
  D_MODE, -- 销售模式
  D_ONOFFLINE, -- 线上线下
  CUST_UNITY_NAME, -- 统一客户组
  CREDIT_LEVEL_NAME, -- 信用等级
  CUST_NATURE_NAME, -- 单位性质
  CUST_TYPE_NAME, -- 客户类型
  SRC_SYSTEM, -- 源系统
  SRC_DETAIL, -- 来源
  USERUPD, -- 更新用户
  DATEUPD, -- 更新日期
  PROVENIENZA, -- 来源系统
  POLICY_AMT, -- 政策金额
  D_POL_CLASS --政策二级分类
  ,COD_DEST3
  ,d_Sale_Dept
  ,cod_dest1
  ,COD_AZI_CTP
  ,cod_dest4 --品牌
  ,MATERIAL_GROUP_CODE
  ,MATERIAL_GROUP_NAME
  ,D_MARKET_PNT
  ,D_PRO_SSER
  ,D_SPEC_SEC
  ,D_PRO_TYPE_S
  ,D_PRO_STAGE
  ,D_PRI_RANGE
  ,D_PRO_SERIES
  ,D_TECH_TYPE
  ,D_PRO_CLASS
  ,D_MODEL_LCA
  ,SALE_MODEL_CODE
  ,SALE_MODEL_NAME
  ,MODEL_CODE
  ,MODEL_NAME
  ,IS_SMALL_B
  ,CN_CLASS_MARK_CODE
  ,CN_CLASS_MARK_NAME
  ,D_ECOM_BU
  ,D_OPER_TYPE
  ,D_MINILED-- MiniLED类型
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
  ,SHOP_CODE
  ,D_PRC_GRP
)
SELECT
    NEWID() AS OID,
    P_SCENARIO AS COD_SCENARIO,
    P_PERIODO AS COD_PERIODO,
    COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA,
    'S6001G5' AS COD_CONTO,
    CUST_CODE,
    CUST_NAME,
    MATERIAL_CODE,
    MATERIAL_NAME,
    NVL(LTRIM(profitcenter_code,0),'ZZZZ') AS COD_DEST2,
    COALESCE(channel_l3_code, 'ZZZZ') AS D_CHANNEL,
    COALESCE(marketing_mode_code, 'ZZZZ') AS D_MODE,
    COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE,
    CUST_UNITY_NAME,
    CREDIT_LEVEL_NAME,
    CUST_NATURE_NAME,
    CUST_TYPE_NAME,
    SYSTEM_SRC,
    UPPER(ODS_SRC) AS SRC_DETAIL,
    SESSION_USER AS USERUPD,
    SYSDATE AS DATEUPD,
    'CPM_SP_D2M_REV_M' AS PROVENIENZA,
    SUM(NVL(PRIZE_AMT,0) / NULLIF((1 + NVL(tax_rate,0)), 0)) AS POLICY_AMT,
    policy_l2_type_code AS D_POL_CLASS,
    bus_range_code AS COD_DEST3,
    marketing_dept_code AS d_Sale_Dept,
    'ZZZZ' as cod_dest1,
    cp_company_code as COD_AZI_CTP,
    'ZZZZ' AS cod_dest4, --品牌
    product_line_code MATERIAL_GROUP_CODE,
    product_line_NAME MATERIAL_GROUP_CODE,
    market_pnt_code AS  D_MARKET_PNT  , --  营销定位
    product_sale_series_code  AS  D_PRO_SSER  , --  产品套系
    spec_section_code AS  D_SPEC_SEC  , --  规格段
    product_shape_type_code AS  D_PRO_TYPE_S  , --  产品形态分类
    product_stage_code  AS  D_PRO_STAGE , --  产品阶段
    price_range_code  AS  D_PRI_RANGE , --  价格段
    product_series_code AS  D_PRO_SERIES  , --  产品系列
    tech_type_code  AS  D_TECH_TYPE , --  技术类型
    product_small_class_code  AS  D_PRO_CLASS , --  产品类别
    model_lca_code  AS  D_MODEL_LCA , --  产品型号生命周期
    sale_model_code AS  SALE_MODEL_CODE , --  销售型号
    sale_model_name AS  SALE_MODEL_NAME , --  销售型号描述
    model_code  AS  MODEL_CODE  , --  产品型号
    model_name  AS  MODEL_NAME  ,  --  产品型号描述
     IS_SMALL_B AS IS_SMALL_B,
    CN_CLASS_MARK_CODE AS CN_CLASS_MARK_CODE,
    CN_CLASS_MARK_NAME AS CN_CLASS_MARK_NAME,
    COMM_BU_CODE AS D_ECOM_BU,
    CASE WHEN IS_SMALL_B = '1' THEN 'OPTY021' ELSE bus_type_code END as D_OPER_TYPE
    ,miniled_type_code AS D_MINILED-- MiniLED类型
    --20260917FJF_ADD 二期新增字段
    ,ee_level_code AS D_EFF_CLASS     --能效等级
    ,bu_code AS D_BU_SHOP             --门店所属BU
    ,niche_ec_store_code AS D_EC_STORE --电商细分店铺
    ,CUST_UNITY_CODE AS D_UNICUSTGRP     --统一客户组编码
    ,COALESCE(shop_code, 'ZZZZ') AS SHOP_CODE  --门店
    ,material_pricing_group_code AS D_PRC_GRP  --物料定价组
FROM dwd_fi_mr_rev_acct_msum_mi
WHERE 1=P_ORG_FLAG
AND dt_month = V_YEARMONTH
AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
AND NOT (COMPANY_CODE='6515' AND SUBSTR(dt_month, 1, 4)='2026' AND SUBSTR(dt_month, 5, 2) <='02')
GROUP BY
    COALESCE(COMPANY_CODE, 'ZZZZ') ,
    CUST_CODE,
    CUST_NAME,
    MATERIAL_CODE,
    MATERIAL_NAME,
    NVL(LTRIM(profitcenter_code,0),'ZZZZ') ,
    COALESCE(channel_l3_code, 'ZZZZ') ,
    COALESCE(marketing_mode_code, 'ZZZZ') ,
    COALESCE(ONOFFLINE_CODE, 'ZZZZ') ,
    CUST_UNITY_NAME,
    CREDIT_LEVEL_NAME,
    CUST_NATURE_NAME,
    CUST_TYPE_NAME,
    SYSTEM_SRC,
    UPPER(ODS_SRC) ,
    policy_l2_type_code ,
    bus_range_code ,
    marketing_dept_code ,
    cp_company_code
    ,product_line_code,
    product_line_NAME
    ,market_pnt_code
    ,product_sale_series_code
    ,spec_section_code
    ,product_shape_type_code
    ,product_stage_code
    ,price_range_code
    ,product_series_code
    ,tech_type_code
    ,product_small_class_code
    ,model_lca_code
    ,sale_model_code
    ,sale_model_name
    ,model_code
    ,model_name
    ,IS_SMALL_B
    ,CN_CLASS_MARK_CODE
    ,CN_CLASS_MARK_NAME
    ,COMM_BU_CODE
    ,CASE WHEN IS_SMALL_B = '1' THEN 'OPTY021' ELSE bus_type_code END
    ,miniled_type_code -- MiniLED类型
    --20260917FJF_ADD 二期新增字段
    ,ee_level_code,bu_code,niche_ec_store_code,CUST_UNITY_CODE
    ,COALESCE(shop_code, 'ZZZZ')  -- 门店
    ,material_pricing_group_code  -- 物料定价组
having SUM(NVL(PRIZE_AMT,0) / NULLIF((1 + NVL(tax_rate,0)), 0)) <> 0
;
COMMIT;


INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
  OID,
  COD_SCENARIO, -- 场景
  COD_PERIODO, -- 期间
  COD_AZIENDA, -- 公司
  COD_CONTO, -- 科目
  CUST_CODE, -- 客商
  CUST_NAME, -- 客商描述
  MATERIAL_CODE, -- 物料
  MATERIAL_NAME, -- 物料描述
  COD_DEST2, -- 产品线
  D_CHANNEL, -- 销售渠道（公司三级分类）
  D_MODE, -- 销售模式
  D_ONOFFLINE, -- 线上线下
  CUST_UNITY_NAME, -- 统一客户组
  CREDIT_LEVEL_NAME, -- 信用等级
  CUST_NATURE_NAME, -- 单位性质
  CUST_TYPE_NAME, -- 客户类型
  SRC_SYSTEM, -- 源系统
  SRC_DETAIL, -- 来源
  USERUPD, -- 更新用户
  DATEUPD, -- 更新日期
  PROVENIENZA, -- 来源系统
  POLICY_AMT, -- 政策金额
  D_POL_CLASS --政策二级分类
  ,COD_DEST3
  ,d_Sale_Dept
  ,cod_dest1
  ,COD_AZI_CTP
  ,cod_dest4 --品牌
  ,D_MARKET_PNT
  ,D_PRO_SSER
  ,D_SPEC_SEC
  ,D_PRO_TYPE_S
  ,D_PRO_STAGE
  ,D_PRI_RANGE
  ,D_PRO_SERIES
  ,D_TECH_TYPE
  ,D_PRO_CLASS
  ,D_MODEL_LCA
  ,SALE_MODEL_CODE
  ,SALE_MODEL_NAME
  ,MODEL_CODE
  ,MODEL_NAME
  ,D_MINILED-- MiniLED类型
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
--日立政策数据来源于DWD_FI_MR_REV_ACCT_PA_MI-政策计提数据-日立专用，所以需要新增加该段逻辑处理
SELECT
    NEWID() AS OID,
    P_SCENARIO AS COD_SCENARIO,
    P_PERIODO AS COD_PERIODO,
    COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA,
    'S6001G5' AS COD_CONTO,
    CUST_CODE,
    CUST_NAME,
    MATERIAL_CODE,
    MATERIAL_NAME,
    NVL(LTRIM(profitcenter_code,0),'ZZZZ') AS COD_DEST2,
    COALESCE(channel_l3_code, 'ZZZZ') AS D_CHANNEL,
    COALESCE(marketing_mode_code, 'ZZZZ') AS D_MODE,
    COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE,
    CUST_UNITY_NAME,
    CREDIT_LEVEL_NAME,
    CUST_NATURE_NAME,
    CUST_TYPE_NAME,
    SYSTEM_SRC,
    UPPER(ODS_SRC) AS SRC_DETAIL,
    SESSION_USER AS USERUPD,
    SYSDATE AS DATEUPD,
    'CPM_SP_D2M_REV_M' AS PROVENIENZA,
     SUM(CASE WHEN system_src = 'SMS' THEN NVL(prize_amt,0) - NVL(gfcfy_amount,0) + NVL(gfcfl_amount,0)
     ELSE NVL(PRIZE_AMT,0) / NULLIF((1 + NVL(tax_rate,0)), 0)
    END) AS POLICY_AMT,
    policy_l2_type_code AS D_POL_CLASS,
     COALESCE(bus_range_code, 'ZZZZ') AS COD_DEST3,
    marketing_dept_code AS marketing_dept_code,
     COALESCE(cost_center_code, 'ZZZZ') as cod_dest1,
    cp_company_code as COD_AZI_CTP,
    COALESCE(BRAND_CODE, 'ZZZZ') AS COD_DEST4,
    market_pnt_code AS  D_MARKET_PNT  , --  营销定位
    product_sale_series_code  AS  D_PRO_SSER  , --  产品套系
    spec_section_code AS  D_SPEC_SEC  , --  规格段
    product_shape_type_code AS  D_PRO_TYPE_S  , --  产品形态分类
    product_stage_code  AS  D_PRO_STAGE , --  产品阶段
    price_range_code  AS  D_PRI_RANGE , --  价格段
    product_series_code AS  D_PRO_SERIES  , --  产品系列
    tech_type_code  AS  D_TECH_TYPE , --  技术类型
    product_small_class_code  AS  D_PRO_CLASS , --  产品类别
    model_lca_code  AS  D_MODEL_LCA , --  产品型号生命周期
    sale_model_code AS  SALE_MODEL_CODE , --  销售型号
    sale_model_name AS  SALE_MODEL_NAME , --  销售型号描述
    model_code  AS  MODEL_CODE  , --  产品型号
    model_name  AS  MODEL_NAME    --  产品型号描述
    ,miniled_type_code AS D_MINILED-- MiniLED类型
    --20260917FJF_ADD 二期新增字段
    ,ee_level_code AS D_EFF_CLASS     --能效等级
    ,bu_code AS D_BU_SHOP             --门店所属BU
    ,niche_ec_store_code AS D_EC_STORE --电商细分店铺
    ,CUST_UNITY_CODE AS D_UNICUSTGRP     --统一客户组编码
FROM DWD_FI_MR_REV_ACCT_PA_MI
WHERE 1=P_ORG_FLAG
AND DT_MONTH = V_YEARMONTH
AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
GROUP BY
    COALESCE(COMPANY_CODE, 'ZZZZ') ,
    CUST_CODE,
    CUST_NAME,
    MATERIAL_CODE,
    MATERIAL_NAME,
    NVL(LTRIM(profitcenter_code,0),'ZZZZ') ,
    COALESCE(channel_l3_code, 'ZZZZ') ,
    COALESCE(marketing_mode_code, 'ZZZZ') ,
    COALESCE(ONOFFLINE_CODE, 'ZZZZ') ,
    CUST_UNITY_NAME,
    CREDIT_LEVEL_NAME,
    CUST_NATURE_NAME,
    CUST_TYPE_NAME,
    SYSTEM_SRC,
    UPPER(ODS_SRC) ,
    policy_l2_type_code ,
    COALESCE(bus_range_code, 'ZZZZ'),
    marketing_dept_code,
    COALESCE(cost_center_code, 'ZZZZ'),
    cp_company_code,
    COALESCE(BRAND_CODE, 'ZZZZ')
    ,market_pnt_code
    ,product_sale_series_code
    ,spec_section_code
    ,product_shape_type_code
    ,product_stage_code
    ,price_range_code
    ,product_series_code
    ,tech_type_code
    ,product_small_class_code
    ,model_lca_code
    ,sale_model_code
    ,sale_model_name
    ,model_code
    ,model_name
    ,miniled_type_code
    --20260917FJF_ADD 二期新增字段
    ,ee_level_code,bu_code,niche_ec_store_code,CUST_UNITY_CODE
HAVING  SUM(CASE WHEN system_src = 'SMS' THEN NVL(prize_amt,0) - NVL(gfcfy_amount,0) + NVL(gfcfl_amount,0)
     ELSE NVL(PRIZE_AMT,0) / NULLIF((1 + NVL(tax_rate,0)), 0)
  END) <> 0

UNION ALL
--日立管法差数据进政策金额字段

SELECT
    NEWID() AS OID,
    P_SCENARIO AS COD_SCENARIO,
    P_PERIODO AS COD_PERIODO,
    COALESCE(COMPANY_CODE, 'ZZZZ') AS COD_AZIENDA,
    CASE WHEN FLAG = 'GFCFY' THEN 'S6001G2' WHEN FLAG = 'GFCFL' THEN 'S6001G3' END AS COD_CONTO,
    CUST_CODE,
    CUST_NAME,
    MATERIAL_CODE,
    MATERIAL_NAME,
    NVL(LTRIM(profitcenter_code,0),'ZZZZ') AS COD_DEST2,
    COALESCE(channel_l3_code, 'ZZZZ') AS D_CHANNEL,
    COALESCE(marketing_mode_code, 'ZZZZ') AS D_MODE,
    COALESCE(ONOFFLINE_CODE, 'ZZZZ') AS D_ONOFFLINE,
    CUST_UNITY_NAME,
    CREDIT_LEVEL_NAME,
    CUST_NATURE_NAME,
    CUST_TYPE_NAME,
    SYSTEM_SRC,
    UPPER(ODS_SRC) AS SRC_DETAIL,
    SESSION_USER AS USERUPD,
    SYSDATE AS DATEUPD,
    'CPM_SP_D2M_REV_M' AS PROVENIENZA,
    SUM(NVL(IMPORTO,0)) AS POLICY_AMT,
    policy_l2_type_code as D_POL_CLASS,
    COALESCE(bus_range_code, 'ZZZZ') AS COD_DEST3,
    marketing_dept_code AS marketing_dept_code,
    COALESCE(cost_center_code, 'ZZZZ') as cod_dest1,
    cp_company_code as COD_AZI_CTP,
    COALESCE(BRAND_CODE, 'ZZZZ') AS COD_DEST4,
    market_pnt_code AS  D_MARKET_PNT  , --  营销定位
    product_sale_series_code  AS  D_PRO_SSER  , --  产品套系
    spec_section_code AS  D_SPEC_SEC  , --  规格段
    product_shape_type_code AS  D_PRO_TYPE_S  , --  产品形态分类
    product_stage_code  AS  D_PRO_STAGE , --  产品阶段
    price_range_code  AS  D_PRI_RANGE , --  价格段
    product_series_code AS  D_PRO_SERIES  , --  产品系列
    tech_type_code  AS  D_TECH_TYPE , --  技术类型
    product_small_class_code  AS  D_PRO_CLASS , --  产品类别
    model_lca_code  AS  D_MODEL_LCA , --  产品型号生命周期
    sale_model_code AS  SALE_MODEL_CODE , --  销售型号
    sale_model_name AS  SALE_MODEL_NAME , --  销售型号描述
    model_code  AS  MODEL_CODE  , --  产品型号
    model_name  AS  MODEL_NAME    --  产品型号描述
    ,miniled_type_code AS D_MINILED-- MiniLED类型
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
FROM(
    SELECT 'GFCFY' AS FLAG,YEAR,MONTH,COMPANY_CODE,CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME
      ,PROFITCENTER_CODE,CHANNEL_L3_CODE,MARKETING_MODE_CODE,ONOFFLINE_CODE,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,
      CUST_NATURE_NAME,CUST_TYPE_NAME,
      SYSTEM_SRC,ODS_SRC,policy_l2_type_code,bus_range_code,
       marketing_dept_code,
       cost_center_code,
       cp_company_code,
       BRAND_CODE
      ,GFCFY_AMOUNT AS IMPORTO --价差转费用
      ,market_pnt_code
      ,product_sale_series_code
      ,spec_section_code
      ,product_shape_type_code
      ,product_stage_code
      ,price_range_code
      ,product_series_code
      ,tech_type_code
      ,product_small_class_code
      ,model_lca_code
      ,sale_model_code
      ,sale_model_name
      ,model_code
      ,model_name
      ,miniled_type_code
      --20260917FJF_ADD 二期新增字段
      ,ee_level_code AS D_EFF_CLASS     --能效等级
      ,bu_code AS D_BU_SHOP             --门店所属BU
      ,niche_ec_store_code AS D_EC_STORE --电商细分店铺
      ,CUST_UNITY_CODE AS D_UNICUSTGRP     --统一客户组编码
    FROM DWD_FI_MR_REV_ACCT_PA_MI MI
    WHERE 1=P_ORG_FLAG
    AND DT_MONTH = V_YEARMONTH
    AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
    AND ODS_SRC IN ('POLICY_YT')
    AND GFCFY_AMOUNT IS NOT NULL

    UNION ALL
    SELECT 'GFCFL' AS FLAG,YEAR,MONTH,COMPANY_CODE,CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME
      ,PROFITCENTER_CODE,CHANNEL_L3_CODE,MARKETING_MODE_CODE,ONOFFLINE_CODE,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,
      CUST_NATURE_NAME,CUST_TYPE_NAME,SYSTEM_SRC,
      ODS_SRC,policy_l2_type_code,bus_range_code,
       marketing_dept_code,
       cost_center_code,
       cp_company_code,
       BRAND_CODE
      ,0-NVL(GFCFL_AMOUNT,0) AS IMPORTO --费用转价差
      ,market_pnt_code
      ,product_sale_series_code
      ,spec_section_code
      ,product_shape_type_code
      ,product_stage_code
      ,price_range_code
      ,product_series_code
      ,tech_type_code
      ,product_small_class_code
      ,model_lca_code
      ,sale_model_code
      ,sale_model_name
      ,model_code
      ,model_name
      ,miniled_type_code
        --20260917FJF_ADD 二期新增字段
      ,ee_level_code AS D_EFF_CLASS     --能效等级
      ,bu_code AS D_BU_SHOP             --门店所属BU
      ,niche_ec_store_code AS D_EC_STORE --电商细分店铺
      ,CUST_UNITY_CODE AS D_UNICUSTGRP     --统一客户组编码
    FROM DWD_FI_MR_REV_ACCT_PA_MI MI
    WHERE 1=P_ORG_FLAG
    AND DT_MONTH = V_YEARMONTH
    AND COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COMPANY_CODE) > 0
    AND ODS_SRC IN ('POLICY_YT')
    AND GFCFL_AMOUNT IS NOT NULL
  )T
GROUP BY
    COALESCE(COMPANY_CODE, 'ZZZZ') ,
    CASE WHEN FLAG = 'GFCFY' THEN 'S6001G2' WHEN FLAG = 'GFCFL' THEN 'S6001G3' END ,
    CUST_CODE,
    CUST_NAME,
    MATERIAL_CODE,
    MATERIAL_NAME,
    NVL(LTRIM(profitcenter_code,0),'ZZZZ') ,
    COALESCE(channel_l3_code, 'ZZZZ') ,
    COALESCE(marketing_mode_code, 'ZZZZ') ,
    COALESCE(ONOFFLINE_CODE, 'ZZZZ') ,
    CUST_UNITY_NAME,
    CREDIT_LEVEL_NAME,
    CUST_NATURE_NAME,
    CUST_TYPE_NAME,
    SYSTEM_SRC,
    UPPER(ODS_SRC) ,
    policy_l2_type_code ,
    COALESCE(bus_range_code, 'ZZZZ'),
    marketing_dept_code,
    COALESCE(cost_center_code, 'ZZZZ'),
    cp_company_code,
    COALESCE(BRAND_CODE, 'ZZZZ')
    ,market_pnt_code
    ,product_sale_series_code
    ,spec_section_code
    ,product_shape_type_code
    ,product_stage_code
    ,price_range_code
    ,product_series_code
    ,tech_type_code
    ,product_small_class_code
    ,model_lca_code
    ,sale_model_code
    ,sale_model_name
    ,model_code
    ,model_name
    ,miniled_type_code-- MiniLED类型
    --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
HAVING SUM(NVL(IMPORTO,0)) <> 0
;
COMMIT;


INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
  OID,
  COD_SCENARIO, -- 场景
  COD_PERIODO, -- 期间
  COD_AZIENDA, -- 公司
  COD_CONTO, -- 科目
  CUST_CODE, -- 客商
  CUST_NAME, -- 客商描述
  MATERIAL_CODE, -- 物料
  MATERIAL_NAME, -- 物料描述
  COD_DEST2, -- 产品线
  D_CHANNEL, -- 销售渠道（公司三级分类）
  D_ONOFFLINE, -- 线上线下
  SRC_DETAIL, -- 来源
  USERUPD, -- 更新用户
  DATEUPD, -- 更新日期
  PROVENIENZA, -- 来源系统
  POLICY_AMT, -- 政策金额
  COD_DEST3
  ,d_Sale_Dept
  ,COD_CATEGORIA
  ,cod_dest1
  ,COD_AZI_CTP
  ,cod_dest4 --品牌
  ,D_MARKET_PNT
  ,D_PRO_SSER
  ,D_SPEC_SEC
  ,D_PRO_TYPE_S
  ,D_PRO_STAGE
  ,D_PRI_RANGE
  ,D_PRO_SERIES
  ,D_TECH_TYPE
  ,D_PRO_CLASS
  ,D_MODEL_LCA
  ,MODEL_CODE
  ,MODEL_NAME
  ,CN_CLASS_MARK_CODE
  ,CN_CLASS_MARK_NAME
  ,D_ADJ_TYPE
  ,D_ECOM_BU
  --20260917FJF_ADD 二期新增字段
  ,D_EC_STORE --电商细分店铺
  ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
)
SELECT
    NEWID() AS OID,
    P_SCENARIO AS COD_SCENARIO,
    P_PERIODO AS COD_PERIODO,
    COD_AZIENDA,
    'S6001G5AD' AS COD_CONTO,--政策计提-TA手工调整
    CUST_CODE,
    CUST_NAME,
    MATERIAL_CODE,
    MATERIAL_NAME,
    COD_DEST2,
    NVL(D_CHANNEL,'ZZZZ') AS D_CHANNEL,
    D_ONOFFLINE,
    'ADJM01' AS SRC_DETAIL,
    SESSION_USER AS USERUPD,
    SYSDATE AS DATEUPD,
    'CPM_SP_D2M_REV_M' AS PROVENIENZA,
    SUM(POLICY_AMT) AS POLICY_AMT,
    COD_DEST3,
    D_SALE_DEPT,
    'GA00_BF' AS COD_CATEGORIA,
     CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
    COD_AZI_CTP as COD_AZI_CTP,
    NVL(COD_DEST4,'ZZZZ') AS COD_DEST4,
    D_MARKET_PNT  , --  营销定位
    D_PRO_SSER  , --  产品套系
    D_SPEC_SEC  , --  规格段
    D_PRO_TYPE_S  , --  产品形态分类
    D_PRO_STAGE , --  产品阶段
    D_PRI_RANGE , --  价格段
    D_PRO_SERIES  , --  产品系列
    D_TECH_TYPE , --  技术类型
    D_PRO_CLASS , --  产品类别
    D_MODEL_LCA , --  产品型号生命周期
    MODEL_CODE  , --  产品型号
    MODEL_NAME    --  产品型号描述
    ,CN_CLASS_MARK_CODE
    ,CN_CLASS_MARK_NAME
    ,D_ADJ_TYPE
    /*20260820-1 SHIQINGFENG.EX 新增政策手工调整电商BU渠道细分*/
    ,D_ECOM_BU
    --20260917FJF_ADD 二期新增字段
    ,D_EC_STORE --电商细分店铺
    ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
FROM TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001
WHERE 1=1
  AND year_month = V_YEARMONTH
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
  --EDIT BY LC 260309 增加限制
  AND COD_CATEGORIA = 'ZFAMOUNT'
  AND COD_CONTO = 'ZAW_DWM_REV_STAN'
  AND D_ADJ_TYPE = 'REV_01_201'
GROUP BY
    CUST_CODE,
    NVL(D_CHANNEL,'ZZZZ'),
    COD_AZIENDA,
    CUST_NAME,
    MATERIAL_CODE,
    MATERIAL_NAME,
    COD_DEST2,
    D_ONOFFLINE,
    COD_DEST3,
    D_SALE_DEPT,
     CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END,
    COD_AZI_CTP,
    D_MARKET_PNT  , --  营销定位
    D_PRO_SSER  , --  产品套系
    D_SPEC_SEC  , --  规格段
    D_PRO_TYPE_S  , --  产品形态分类
    D_PRO_STAGE , --  产品阶段
    D_PRI_RANGE , --  价格段
    D_PRO_SERIES  , --  产品系列
    D_TECH_TYPE , --  技术类型
    D_PRO_CLASS , --  产品类别
    D_MODEL_LCA , --  产品型号生命周期
    MODEL_CODE  , --  产品型号
    MODEL_NAME ,   --  产品型号描述
    NVL(COD_DEST4,'ZZZZ')
    ,CN_CLASS_MARK_CODE
    ,CN_CLASS_MARK_NAME
    ,D_ADJ_TYPE
    ,D_ECOM_BU
    --20260917FJF_ADD 二期新增字段
    ,D_EC_STORE --电商细分店铺
    ,D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
HAVING SUM(POLICY_AMT) <>0
    ;

COMMIT;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.10 REV001_STEP_10(政策分摊)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*删除6515公司收入成本为其他*/
DELETE FROM AW_MR9_REVM01_000001_TEMP
WHERE COD_SCENARIO IN (P_SCENARIO)
AND COD_PERIODO IN (P_PERIODO)
AND COD_AZIENDA = '6515'
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
AND MATERIAL_CODE IN (SELECT MATNR FROM TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD MARA WHERE MARA.ACCOUNT_TYPE = '2'/*1为主营，2为其他*/)
;
COMMIT;

--20260203 ADD BY SHIQINGFENG.EX 删除物料是0开头的，不删除手动调整
DELETE FROM AW_MR9_REVM01_000001_TEMP ps WHERE 1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND MATERIAL_CODE like '0%'
    AND COD_AZIENDA = '2080'
    AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
    AND COD_CONTO NOT like '%AD'
    ;
  COMMIT;



/*2.2.2 REV001_STEP_2(本位币字段更新)*/

UPDATE AW_MR9_REVM01_000001_TEMP ss
   SET COD_VALUTA =
 (SELECT COD_VALUTA FROM TGK_FIMA_HISENSE.AZIENDA WHERE AZIENDA.COD_AZIENDA = ss.COD_AZIENDA)
 WHERE  1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )
    ;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.2 RREV001_STEP_2(本位币字段更新)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*2023公司越南盾金额需要乘以100*/
/* 2026-11-16 停用（变更 C-035）：D 表 02 已对 2023 做 14 处 ×100（rev_sale_amt / rev_sale_bcy_amt /
   cogs_amt / discount* / tax_amt / price_amt），M 层再乘一次会放大 1 万倍。
   代码保留不删，恢复时去掉本注释即可。
UPDATE AW_MR9_REVM01_000001_TEMP
SET SALE_REV = SALE_REV*100,ORG_REV = ORG_REV*100,SALE_COGS = SALE_COGS*100
WHERE COD_SCENARIO IN (P_SCENARIO)
AND COD_PERIODO IN (P_PERIODO)
AND COD_AZIENDA = '2023'
AND COD_CONTO NOT LIKE '%AD'
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
AND (COD_CONTO LIKE 'S6001%' OR COD_CONTO LIKE 'S6401%' )
AND COD_CONTO <> 'S640190'
AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )
;
COMMIT;
*/


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.3 REV001_STEP_9(调整类型更新)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.5 REV001_STEP_5(折扣物料销量处理) */


UPDATE AW_MR9_REVM01_000001_TEMP ss
   SET ORG_QTY =
   CASE
      WHEN SRC_DETAIL IN ('GLPCA') THEN /*-1* 20260503fjf_add*/BILL_QTY
     WHEN MATERIAL_CODE IN
   (SELECT MATERIAL_CODE FROM TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 WHERE
   COD_CONTO = 'ZAW_DWM_LIST_ZHEKOU' AND VALID_FR <= V_YEARMONTH AND NVL(VALID_TO,'999999') >= V_YEARMONTH ) THEN 0 ELSE BILL_QTY
         END
 WHERE  1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )
  ;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.5 RREV001_STEP_5(折扣物料销量处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.5.1 REV001_STEP_5.1(日立-折扣物料销量处理) */
UPDATE AW_MR9_REVM01_000001_TEMP SS
SET ORG_QTY = (
    SELECT CASE
        WHEN B.MIDDLE_CLASS_CODE = 'P0205' THEN 0
        ELSE SS.BILL_QTY
    END
    FROM TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD B
    WHERE B.MATNR = SS.MATERIAL_CODE
)
WHERE SS.COD_SCENARIO = P_SCENARIO
  AND SS.COD_PERIODO = P_PERIODO
  AND SS.COD_AZIENDA IN (
      SELECT ELEM FROM SESSION_AZIENDA_LIST
      WHERE SESSION_ID = V_SESSION_ID AND (ELEM LIKE '17%' OR ELEM = '6240')
  )
  AND SS.PROVENIENZA IN ('CPM_SP_D2M_REV_M')
  -- 只更新能匹配上 DIM_FI_MR_PRODUCT_DD 的行（保持与原 MERGE INNER JOIN 相同行为）
  AND EXISTS (
      SELECT 1
      FROM TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD B
      WHERE B.MATNR = SS.MATERIAL_CODE
  );

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.5.1 REV001_STEP_5.1(日立-折扣物料销量处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.6 REV001_STEP_6(销售口径调整) */
UPDATE AW_MR9_REVM01_000001_TEMP T
SET
    T.MAP_QTY = CASE
                    WHEN T.COD_CONTO IN ('S600100', 'S600100AD') THEN T.ORG_QTY        /*开票收入*/
                    WHEN T.COD_CONTO = 'S600101'                 THEN T.SHIP_QTY - T.BILL_QTY  /*出库未开*/
                    WHEN T.COD_CONTO = 'S600102'                 THEN T.ORG_QTY        /*退货未办税*/
                    ELSE T.ORG_QTY
                END,
    T.ORG_QTY = CASE
                    WHEN T.SRC_DETAIL LIKE '%ZTSO04_TH%'
                      OR T.SRC_DETAIL LIKE '%ZTSO04_CK%' THEN 0
                    ELSE T.ORG_QTY
                END
WHERE T.COD_SCENARIO = P_SCENARIO
  AND T.COD_PERIODO  = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
  AND T.PROVENIENZA = 'CPM_SP_D2M_REV_M'
  ;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.6 REV001_STEP_6(销售口径调整) 完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

UPDATE AW_MR9_REVM01_000001_TEMP ss
   SET MAP_DIS1 = DISCOUNT_1/(1+TAX_RATE),
       MAP_DIS3 = DISCOUNT_3/(1+TAX_RATE),
       MAP_DIS4 = DISCOUNT_4/(1+TAX_RATE),
       MAP_DIS5 = DISCOUNT_5/(1+TAX_RATE),
       MAP_DIS6 = DISCOUNT_6/(1+TAX_RATE),
       MAP_DIS30 = DISCOUNT_30/(1+TAX_RATE),
       MAP_DIS34 = DISCOUNT_34/(1+TAX_RATE),
       ORG_REV =
  CASE
       --edit by lc 20261013 2910不参与金额还原-税率
       WHEN COD_AZIENDA IN ('6012','2023','2910') AND COD_CONTO LIKE '%AD' --SRC_DETAIL = 'ADJM01'
                           THEN -1*SALE_REV
       --edit by lc 20261013 2910不参与金额还原-税率
       WHEN COD_AZIENDA IN ('6012','2023','2910') THEN ORG_REV
       /* 2026-11-16 变更 C-038：旧 D 把 DMBTR（本位币）装进 rev_sale_amt，两列相反；M 原有一条专用分支
          「BSEG 且 SRC_SYSTEM IN (S800,S900) 取 SALE_REV」，把交易币当本位币用，正好抵消了旧 D 的错位，
          所以生产一直是对的。新 D 已修正列含义（rev_sale_amt=WRBTR 交易币、rev_sale_bcy_amt=DMBTR 本位币），
          再取 SALE_REV 就会丢汇率（2900 差 3.29 倍、2000 差 1.086 倍）。现删除该专用分支，BSEG 统一取 ORG_REV。 */
       WHEN SRC_DETAIL = 'BSEG' THEN ORG_REV
       /* WHEN COD_CONTO IN ('S600102') THEN  SALE_REV/(1+TAX_RATE)
       WHEN COD_CONTO IN ('S600101') THEN  SALE_REV/1.13 */ --20260813_fjf_add:REV001_STEP_7（金额还原-税率）取消出库未开退货未办税率处理逻辑，该部分还原到D表进行，把M表的逻辑取消
       ELSE  SALE_REV END
 WHERE  1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )

  ;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.7 REV001_STEP_7(金额还原-税率)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*2.2.5 REV001_STEP_8(金额还原-汇率)*/

UPDATE AW_MR9_REVM01_000001_TEMP ss
   SET ORG_REV =
   ROUND(CASE
   --edit by lc 20261013 2910不参与金额还原-税率
   WHEN COD_AZIENDA IN ('6012','2023','2910')
     THEN ORG_REV
   WHEN SRC_DETAIL = 'BSEG' THEN ORG_REV
   WHEN COD_VALUTA_ORIGINARIA <>  COD_VALUTA AND COD_VALUTA_ORIGINARIA <> 'ZZZZ'
     THEN SALE_REV*EXCHANGE_RATE

   ELSE SALE_REV END,2)
 WHERE  1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND COD_CONTO = 'S600100'
    --EDIT BY LC 260821 增加REV_CIS限制
    AND SRC_DETAIL <> 'REV_CIS'
    AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )
  ;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.8 REV001_STEP_8(金额还原-汇率)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;



/*新增利润中心映射品牌*/
MERGE /*+ USE_HASH(T C) */ INTO AW_MR9_REVM01_000001_TEMP T
USING (
    SELECT COD_DEST2 AS DEST2_RUL, ATTRIBUTO1 AS COD_DEST4
    FROM DEST2
) C
ON (    T.COD_DEST2        = C.DEST2_RUL
    AND T.COD_SCENARIO     = P_SCENARIO
    AND T.COD_PERIODO      = P_PERIODO
    AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, T.COD_AZIENDA) > 0
    AND T.SRC_SYSTEM NOT IN ('GSMS', 'SMS')
    AND T.COD_CONTO NOT LIKE '%AD'
    AND (NVL(LTRIM(T.COD_DEST4), '') = '' OR T.COD_DEST4 = 'ZZZZ')

)
WHEN MATCHED THEN UPDATE
SET T.COD_DEST4 = NVL(C.COD_DEST4, 'ZZZZ')
;



INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.11.3 REV001_STEP_11(新增利润中心映射品牌)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

--20260206 新增手工调整数据客商信息和物料信息补充更新
MERGE /*+ USE_HASH(T C) */ INTO AW_MR9_REVM01_000001_TEMP T
USING (
SELECT distinct
      CASE WHEN nvl(aw.D_MARKET_PNT,'|') = '|' OR aw.D_MARKET_PNT = 'ZZZZ' OR MARA.market_pos_code <> aw.D_MARKET_PNT
           THEN MARA.market_pos_code
           ELSE aw.D_MARKET_PNT
      END AS D_MARKET_PNT -- 营销定位编码
    , CASE WHEN nvl(aw.D_CNL_C_TYPE,'|') = '|' OR aw.D_CNL_C_TYPE = 'ZZZZ' OR CUST_INFO.channel_small_class_code <> aw.D_CNL_C_TYPE
           THEN CUST_INFO.channel_small_class_code
           ELSE aw.D_CNL_C_TYPE
      END AS D_CNL_C_TYPE -- 渠道客户小类编码
    , CASE WHEN NVL(LTRIM(AW.D_CHANNEL),'ZZZZ') = 'ZZZZ'
            /* ALTER BY 20260820-2 SHIQINGFENG.EX 新增公司三级分类更新逻辑与D表一致*/
            THEN CASE
                      WHEN AW.D_ONOFFLINE = '020_ON_003'
                       AND AW.COD_AZIENDA IN ('2600', '6746', '6750', '6800', '6847')
                       AND AW.cust_code = '2031242'
                      THEN 'E4'
                      WHEN AW.D_ONOFFLINE = '020_ON_003'
                       AND AW.COD_AZIENDA IN ('2600', '6746', '6847')
                       AND AW.cust_code = '2030797'
                      THEN 'F4'
                      WHEN AW.D_ONOFFLINE = '020_ON_003'
                       AND AW.COD_AZIENDA IN ('2600', '6746', '6800')
                       AND AW.cust_code = '2018577'
                      THEN 'F4'
                      WHEN (AW.COD_AZIENDA = '1180' OR AW.COD_AZIENDA LIKE '12%')
                       AND ecom_map.channel_code_l3 IS NOT NULL
                      THEN ecom_map.channel_code_l3
                      ELSE nvl(CUST_INFO_sold.com_3rd_code,CUST_INFO.com_3rd_code)
                  END
            ELSE AW.D_CHANNEL
       END AS D_CHANNEL

    /*, CASE WHEN nvl(AW.D_CHANNEL,'|') = '|' OR AW.D_CHANNEL = 'ZZZZ' OR CUST_INFO.com_3rd_code <> AW.D_CHANNEL
           THEN CUST_INFO.com_3rd_code
           ELSE AW.D_CHANNEL
      END AS D_CHANNEL*/ -- 销售渠道三级编码
    , CASE WHEN nvl(aw.D_PRO_CLASS,'|') = '|' OR aw.D_PRO_CLASS = 'ZZZZ' OR MARA.small_class_code <> aw.D_PRO_CLASS
           THEN MARA.small_class_code
           ELSE aw.D_PRO_CLASS
      END AS D_PRO_CLASS -- 产品小类编码
    , CASE WHEN nvl(aw.MATERIAL_GROUP_CODE,'|') = '|' OR aw.MATERIAL_GROUP_CODE = 'ZZZZ' OR CASE WHEN AZ.SAP_VERSION IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                                                                                            ELSE LTRIM(mara.matkl,'0')
                                                                                            END <> aw.MATERIAL_GROUP_CODE
           THEN CASE WHEN AZ.SAP_VERSION IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                ELSE LTRIM(mara.matkl,'0')
                END
           ELSE aw.MATERIAL_GROUP_CODE
      END AS MATERIAL_GROUP_CODE --物料组
    , CASE WHEN nvl(aw.model_code,'|') = '|' OR aw.model_code = 'ZZZZ' OR MARA.model_code <> aw.model_code
           THEN MARA.model_code
           ELSE aw.model_code
      END AS model_code
    , CASE WHEN nvl(aw.model_name,'|') = '|' OR aw.model_name = 'ZZZZ' OR MARA.model_name <> aw.model_name
           THEN MARA.model_name
           ELSE aw.model_name
      END AS model_name
    , CASE WHEN nvl(aw.COD_AZI_CTP,'|') = '|' OR aw.COD_AZI_CTP = 'ZZZZ' OR CTP.COD_AZI_CTP <> aw.COD_AZI_CTP
           THEN CTP.COD_AZI_CTP
           ELSE aw.COD_AZI_CTP
      END AS COD_AZI_CTP
    , AW.OID

      --20260917FJF_ADD 二期新增字段
    , CASE WHEN nvl(aw.D_EFF_CLASS,'|') = '|' OR aw.D_EFF_CLASS = 'ZZZZ' OR MARA.ee_level_code <> aw.D_EFF_CLASS
           THEN MARA.ee_level_code
           ELSE aw.D_EFF_CLASS
      END AS D_EFF_CLASS
    , CASE WHEN nvl(aw.D_BU_SHOP,'|') = '|' OR aw.D_BU_SHOP = 'ZZZZ' OR CUST_INFO.bu_code <> aw.D_BU_SHOP
           THEN CUST_INFO.bu_code
           ELSE aw.D_BU_SHOP
      END AS D_BU_SHOP

     , CASE WHEN nvl(aw.D_UNICUSTGRP,'|') = '|' OR aw.D_UNICUSTGRP = 'ZZZZ' OR CUST_INFO.cust_unity_code <> aw.D_UNICUSTGRP
           THEN CUST_INFO.cust_unity_code
           ELSE aw.D_UNICUSTGRP
      END AS D_UNICUSTGRP
FROM(
      SELECT OID,COD_AZIENDA,CUST_CODE,MATERIAL_CODE,D_MARKET_PNT
          ,D_CNL_C_TYPE,D_CHANNEL,D_PRO_CLASS,MATERIAL_GROUP_CODE,model_code,model_name,COD_AZI_CTP
          ,D_ECOM_BU,sold_to_code,D_ONOFFLINE
          --20260917FJF_ADD 二期新增字段
          ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
      FROM AW_MR9_REVM01_000001_TEMP PS
      WHERE 1=1
      AND COD_SCENARIO = P_SCENARIO
      AND COD_PERIODO = P_PERIODO
      AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
      --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
      AND (
              (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
              OR
              (
                (PROVENIENZA = 'CPM_SP_D2M_REV_M'
                  AND COD_CONTO LIKE '%AD'
                  AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
                  AND P_ORG_FLAG = 2
                )
              )
            OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
            OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
            )
      AND (COD_CONTO LIKE '%AD' OR SRC_SYSTEM = 'TA_GJYX')
    ) AW
LEFT JOIN (SELECT COD_AZIENDA,'S'||CITTA_LEGALE SAP_VERSION FROM TGK_FIMA_HISENSE.AZIENDA) AZ
ON AW.COD_AZIENDA = AZ.COD_AZIENDA
LEFT JOIN
(
SELECT 'S'||MANDT AS SAP_VERSION,KUNNR,zkunnr_mdg,name1 FROM TGK_FIMA_HISENSE.DS_DWD_SAP_KNA1
) KNA1
ON AZ.SAP_VERSION = KNA1.SAP_VERSION
AND LTRIM(KNA1.kunnr,'0') = AW.CUST_CODE
LEFT JOIN TGK_FIMA_HISENSE.DIM_CUSTOMER_BASE_INFO_DD CUST_INFO
ON LTRIM(KNA1.zkunnr_mdg,'0') = LTRIM(CUST_INFO.cust_code,'0')
LEFT JOIN
(
SELECT 'S'||MANDT AS SAP_VERSION,KUNNR,zkunnr_mdg,name1 FROM TGK_FIMA_HISENSE.DS_DWD_SAP_KNA1
) KNA1_sold
  ON AZ.SAP_VERSION = KNA1_sold.SAP_VERSION
 AND LTRIM(KNA1_sold.kunnr,'0') = AW.sold_to_code

LEFT JOIN TGK_FIMA_HISENSE.DIM_CUSTOMER_BASE_INFO_DD CUST_INFO_sold
  ON LTRIM(KNA1_sold.zkunnr_mdg,'0') = LTRIM(CUST_INFO_sold.cust_code,'0')


LEFT JOIN TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD MARA
ON MARA.matnr = AW.MATERIAL_CODE
LEFT JOIN (
SELECT cust_code AS kunrg
      ,cp_company_code AS COD_AZI_CTP
      ,system_src AS system_src
  FROM TGK_FIMA_HISENSE.dim_rule_fi_mr_cust2ctp_mapping a
 WHERE cust_type_code = 'C'
   AND NVL(valid_fr,'202401') <= V_YEARMONTH
   AND NVL(valid_to,'999999') >= V_YEARMONTH
) CTP
ON CTP.kunrg = AW.CUST_CODE
AND CTP.system_src = AZ.SAP_VERSION
LEFT JOIN (SELECT ecom_code,MAX(channel_code_l3) AS channel_code_l3,MAX(channel_name_l3) AS channel_name_l3
             FROM TGK_FIMA_HISENSE.dim_rule_fi_mr_ecom_channel3_mapping
            GROUP BY ecom_code
          ) ecom_map
ON (AW.COD_AZIENDA = '1180' OR AW.COD_AZIENDA LIKE '12%')
AND AW.D_ECOM_BU = ecom_map.ecom_code
) C
ON( T.OID = C.OID )
WHEN MATCHED THEN
UPDATE SET  T.D_MARKET_PNT = C.D_MARKET_PNT
      , T.D_CNL_C_TYPE = C.D_CNL_C_TYPE
      , T.D_CHANNEL = C.D_CHANNEL
      , T.D_PRO_CLASS = C.D_PRO_CLASS
      , T.MATERIAL_GROUP_CODE = C.MATERIAL_GROUP_CODE
      , T.model_code = C.model_code
      , T.COD_AZI_CTP = C.COD_AZI_CTP
      , t.model_name = c.model_name
        --20260917FJF_ADD 二期新增字段
      , T.D_EFF_CLASS = C.D_EFF_CLASS
      , T.D_BU_SHOP = C.D_BU_SHOP
      , T.D_UNICUSTGRP = C.D_UNICUSTGRP
      ;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.11.4 REV001_STEP_11(手工调整数据客商信息和物料信息补充更新)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*2.2.12 REV001_STEP_12(销量收入特殊处理)*/

MERGE INTO AW_MR9_REVM01_000001_TEMP T
USING
(
    SELECT AW.OID,
           AW.COD_AZIENDA,
           AW.MATERIAL_CODE,
           AW.D_SALE_DEPT,
           AW.MODEL_CODE,
           --NVL(XS.CHANGE_COEFFICIENT,0) AS CHANGE_COEFFICIENT,
           CASE
        --新增日立公司配件折为0
                WHEN AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '050')
                     AND AW.D_PRO_CLASS IN (SELECT ABBI.COD FROM TGK_FIMA_HISENSE.ED_D_PRO_CLASS_GERARCHIA_ABBI ABBI WHERE COD_GERARCHIA = '01' AND ABBI.COD_ELEGER IN (SELECT A.D_PRO_CLASS FROM TGK_FIMA_HISENSE.AW_RUL_PROCLS_000001 A))
                    THEN 0
                /*
                ALTER BY 20260825-1 SHIQINGFENG.EX  REV001_STEP_12(销量&收入特殊处理)
                ①针对于日立折算部分，增加一个规则，当DIM_TYPE=MATERIAL时，折算后销量处理成0
                ②除了日立外的公司，折算规则取消，直接取D表的折算销量 注意，只动折算销量这个字段【MAP_ZUM】
                */
                WHEN MARA.DIM_TYPE= 'MATERIAL' AND AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '050')
                    THEN 0
                WHEN AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '050')
                    THEN MAP_QTY
                 /*WHEN NOT (\* AW.COD_AZIENDA = '6012' OR AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%'
              OR AW.COD_AZIENDA = '1180' OR AW.COD_AZIENDA LIKE '12%' OR *\ --FJF_ADD_20260717 空调及中国区等公司都走物料大表折算
                  \*新增日立公司不走物料大表*\
                  AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '050')
                 ) THEN AW.MAP_QTY*NVL(SALE_QTY,1)*/
         
        --EDIT BY LC 20261105 TVS 2910 销量折算特殊逻辑，如果不在物料大表的物料，折算为0
        WHEN AW.COD_AZIENDA IN ('2910') AND MARA.MATNR IS NULL 
          THEN 0
      
        WHEN NOT(AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '050')
            ) /* 日立公司不走物料大表 */
          AND COD_CATEGORIA LIKE 'GA00%'
          THEN NVL(AW.MAP_QTY * SALE_QTY,AW.MAP_QTY)  --20260828FJF_ADD
      
      
               ELSE AW.MAP_ZUM

           END AS MAP_ZUM,
           CASE
             --20260114ZZS修改：26**、12**、208*、1098、1180、1632、2000、2050

                WHEN (AW.COD_AZIENDA LIKE '23%' OR AW.COD_AZIENDA LIKE '26%' OR AW.COD_AZIENDA LIKE '12%' OR AW.COD_AZIENDA LIKE '208%' OR AW.COD_AZIENDA IN ('1098','1180','1632','2000','2050')) AND AW.MATERIAL_GROUP_CODE IN ('1100105','1100107')
                    THEN AW.ORG_REV

                /*公司为：26**、23**、12**、2000、1632、1180（显示、激光、中国区）
                 2、①【MATERIAL_CODE 物料】开头5销量处理为0，但是物料编码开头5且【COD_DEST2 利润中心】父层级为耳机（利润中心编码：0104003）的销量和收入不处理
                    ②当【MATERIAL_CODE 物料】不是5开头，但是为外销，且通过物料大表匹配出来的【ZCALASSET 按套系统计】为2或者为空时,不计入销量，收入不处理
                     判断外销的逻辑：【COD_DEST3 业务范围】节点在HW-海外节点下的所有要素的条目
                    ③物料开头为G的销量处理为0，收入不处理
                 ①情况1：MAP_ZUM=0；ORG_REV不变 情况2：MAP_ZUM=MAP_QTY；ORG_REV不变
                 ②MAP_ZUM=0；ORG_REV不变
                 ③MAP_ZUM=0；ORG_REV不变
                */
                WHEN (AW.COD_AZIENDA LIKE '23%' OR AW.COD_AZIENDA LIKE '26%' OR AW.COD_AZIENDA LIKE '12%' OR AW.COD_AZIENDA LIKE '208%' OR AW.COD_AZIENDA IN ('2000','1632','1180','2000','2050'))
                     AND AW.MATERIAL_CODE LIKE '5%' AND AW.COD_DEST2 IN (SELECT ABBI.COD_DEST2 FROM TGK_FIMA_HISENSE.DEST2_GERARCHIA_ABBI ABBI WHERE ABBI.COD_DEST2_GERARCHIA = '01' AND COD_DEST2_ELEGER = '0104003')
                    THEN AW.ORG_REV
                WHEN (AW.COD_AZIENDA LIKE '23%' OR AW.COD_AZIENDA LIKE '26%' OR AW.COD_AZIENDA LIKE '12%' OR AW.COD_AZIENDA LIKE '208%' OR AW.COD_AZIENDA IN ('2000','1632','1180','2000','2050'))
                     AND AW.MATERIAL_CODE LIKE '5%'
                    THEN AW.ORG_REV

                /*1、型号包含“折扣”或“折让”的数据销量处理为0，收入不处理
                  2、 ①产品中类为配件的销量变为0： 判断产品中类为配件的逻辑：即销量和收入对应的【D_PRO_CLASS-产品类别】的父层级若在配置表AW_RUL_PROCLS_000001的【D_PRO_CLASS】内，则为配件；
                      ②特殊处理：当【D_PRO_CLASS-产品类别】的父层级为P0404，且【MATERIAL_GROUP_CODE 物料组】=1301004（ASKO其他洗衣房）/1301017（Gorenje其他洗衣房），仍计算销量；
                  1、①MAP_ZUM=0；ORG_REV不变
                  2、①MAP_ZUM=0；ORG_REV不变
                     ②MAP_ZUM=MAP_QTY；ORG_REV不变
                */
                WHEN AW.MODEL_CODE LIKE '%折扣%' OR AW.MODEL_CODE LIKE '%折让%'
                    THEN AW.ORG_REV
                WHEN AW.D_PRO_CLASS IN (SELECT ABBI.COD FROM TGK_FIMA_HISENSE.ED_D_PRO_CLASS_GERARCHIA_ABBI ABBI WHERE COD_GERARCHIA = '01' AND ABBI.COD_ELEGER IN (SELECT A.D_PRO_CLASS FROM TGK_FIMA_HISENSE.AW_RUL_PROCLS_000001 A))
                    THEN AW.ORG_REV
                WHEN AW.D_PRO_CLASS IN (SELECT ABBI.COD FROM TGK_FIMA_HISENSE.ED_D_PRO_CLASS_GERARCHIA_ABBI ABBI WHERE COD_GERARCHIA = '01' AND ABBI.COD_ELEGER IN ('P0404')) AND AW.MATERIAL_GROUP_CODE IN ('1301004','1301017')
                    THEN AW.ORG_REV
            ELSE AW.ORG_REV
            END AS ORG_REV

      FROM (SELECT A.OID,A.COD_AZIENDA,A.MATERIAL_CODE,A.D_SALE_DEPT,A.MODEL_CODE,NVL(A.MAP_QTY,0) AS MAP_QTY,NVL(A.ORG_REV,0) AS ORG_REV
                   ,A.MATERIAL_GROUP_CODE
                   ,A.D_PRO_CLASS
                   ,A.ZCALASSET
                   ,A.COD_DEST3
                   ,A.COD_DEST2
                   ,A.MODEL_NAME
                   ,A.MAKTX_S810
                   ,A.SRC_SYSTEM
                   ,MAP_ZUM
           ,COD_CATEGORIA
              FROM AW_MR9_REVM01_000001_TEMP A
             WHERE  1=1
               AND COD_SCENARIO = P_SCENARIO
               AND COD_PERIODO = P_PERIODO
               AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
               --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
               --AND COD_DEST3 NOT IN (SELECT ELEM FROM TGK_FIMA_HISENSE.V_REF_DEST3_NONAME WHERE HIE = '01' AND NODE = 'HW')
               AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
            ) AW
      LEFT JOIN (SELECT MATNR,SALE_QTY,DIM_TYPE FROM TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD M

                  ) MARA --IS_SALE
                  ON AW.MATERIAL_CODE = MARA.MATNR
) C
ON (
C.OID = T.OID
)
WHEN MATCHED THEN
  UPDATE SET T.MAP_ZUM = C.MAP_ZUM,
             T.ORG_REV = C.ORG_REV
             --,T.CHANGE_COEFFICIENT = C.CHANGE_COEFFICIENT
             --,T.MAP_QTY = C.MAP_QTY
;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','销量收入特殊处理完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

update AW_MR9_REVM01_000001_TEMP AW
set SALE_COGS = 0, MAP_QTY = 0, ORG_REV = 0
WHERE  1=1
  AND COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  /* AND (AW.COD_AZIENDA = '6012' OR AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%')
  AND AW.COD_DEST3 IN (SELECT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE SESSION_ID = V_SESSION_ID AND HIE = '01' AND NODE = 'HN')
  AND AW.D_PRO_CLASS IN (SELECT ABBI.COD FROM TGK_FIMA_HISENSE.ED_D_PRO_CLASS_GERARCHIA_ABBI ABBI WHERE COD_GERARCHIA = '01' AND ABBI.COD IN ('P020527'))*/--20260720
  AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
  AND (
        /*20260721 modified by shiqingfeng.ex 修改为冲销不更新*/
        /*(SRC_DETAIL LIKE 'BSEG%' AND D_BUS_SCE_S IN ('024','025')
        )
        OR */
        ( D_PRO_CLASS IN (SELECT COD FROM TGK_FIMA_HISENSE.ED_D_PRO_CLASS_GERARCHIA_ABBI WHERE COD_GERARCHIA = '01' AND COD = 'P020527')
        )
    ) --20260720ZZS新增：对于展示机，需要将销量2、收入和成本金额折算为0 fjf_add

;
COMMIT;


update AW_MR9_REVM01_000001_TEMP AW
set SALE_COGS = 0
WHERE  1=1
  AND COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  AND AW.COD_AZIENDA = '6515'
  AND AW.MATERIAL_CODE IN (SELECT MATNR FROM TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD M WHERE ACCOUNT_TYPE = '2')
  AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
;
COMMIT;




INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.12 REV001_STEP_12(销量收入特殊处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.12.1 REV001_STEP_12_1(TVS销量收入分摊)
  20261009 LICHENG.EX 新增
  ------------------------------------------------------------------
  待分摊范围（下列条件取交集）：
    ①【COD_AZIENDA-公司】= '2910'（TVS）
    ②【COD_CONTO-科目】以 S6001 开头
    ③【CUST_CODE-客商】在 <dim_rule_fi_mr_cust_onoff_ratio-TVS客商对应渠道分组分摊比例配置表> 的 cust_code 范围内
    ④【场景期间】在配置表 valid_fr / valid_to 范围内
  处理方式（原行一律不动，D_ONOFFLINE 保留原值，不删除任何行）：
    ① 先冲销：按原行插入 1 条等额【负值】冲销行（28 个销量/收入类字段 × -1，
       其余字段原值透传），D_ONOFFLINE = 原行值，D_ADJ_TYPE = 'REV_01_227'
    ② 再分摊：按配置表该客商的每条渠道分组插入 1 条分摊行（N = 该客商有效配置行数），
       28 个销量/收入类字段 = 原值 × 该份 RATIO，D_ONOFFLINE = 该份 ONOFFLINE_CODE，
       D_ADJ_TYPE = 'REV_01_228'
    ③ 客商不在配置表范围内的行 → 完全不处理（不冲销、不分摊、行数不变）
    ④ 原行保留，其 D_ONOFFLINE 不被替换；冲销行与原行在原渠道分组内自动抵消，
       分摊行落在配置的各渠道分组上
  净效果：原渠道分组的金额归零，同一笔金额按配置比例重分类到各渠道分组（ΣRATIO=1 时合计守恒）
  ? ORG_QTY 按字段本义取 ratio*ORG_QTY（设计稿写 BILL_QTY 系笔误，已确认）。
  ? 设计稿字段清单之外的字段（成本类等）这里按原值透传；若 2910 的 S6001 行这些字段
    有非 0 值且也需要按比例分摊，需一并加入上面的比例字段清单（冲销行同步取负）。
*/
/*2.2.12.1.1 冲销原行（插入等额负值行；原行保留、D_ONOFFLINE 保持原值）*/
INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP
(
  OID, COD_SCENARIO, COD_PERIODO, SHOP_CODE
  ,COD_AZIENDA, COD_DEST1, COD_AZI_CTP, D_PRC_GRP
  ,COD_CONTO, D_SALE_DEPT, COD_DEST3, COD_CATEGORIA
  ,D_PRO_CLASS, D_DATA_BLOCK, D_DIFF_TYPE, MATERIAL_CODE
  ,MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT
  ,D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_QUA_METHOD
  ,D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE
  ,D_MODEL_LCA, D_PRO_TYPE, SALE_MODEL_NAME, D_POL_CLASS
  ,MODEL_NAME, CUST_CODE, MODEL_CODE, SALE_MODEL_CODE
  ,CUST_NAME, D_CHANNEL, D_MODE, D_ONOFFLINE
  ,D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME
  ,CUST_TYPE_NAME, D_IND_C_TYPE, D_CNL_C_TYPE, COD_VALUTA
  ,SHIP_QTY, COD_VALUTA_ORIGINARIA, ORDER_QTY, BILL_QTY
  ,SALE_REV, DISCOUNT_3, DISCOUNT_4, DISCOUNT_5
  ,DISCOUNT_6, TAX_RATE, EXCHANGE_RATE, ORG_QTY
  ,MAP_QTY, ORG_REV, MAP_REV, MAP_REV1
  ,MAP_DIS3, MAP_DIS4, MAP_DIS5, MAP_DIS6
  ,POLICY_AMT, BATCH_ID, SOLD_TO_CODE, SOLD_TO_NAME
  ,MATERIAL_GROUP_CODE, SRC_SYSTEM, SRC_DETAIL, SHOP_NAME
  ,AGENCY_CODE, AGENCY_NAME, IS_MINILED_CODE, PROVENIENZA
  ,USERUPD, DATEUPD, EN_VERSION, SALE_COGS
  ,DISCOUNT_1, MAP_DIS1, DISCOUNT_30, DISCOUNT_34
  ,MAP_DIS30, MAP_DIS34, NOTE, D_BU_TRAN
  ,CUSTOMER_MODEL, ORDER_TYPE_CODE, ZCALASSET, CALC_RULE
  ,STATUTORY_ACCT_CODE, MAP_ZUM, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME
  ,SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM
  ,D_ADJ_TYPE, CHANGE_COEFFICIENT, GFCFY_AMOUNT, GFCFL_AMOUNT
  ,D_OPER_TYPE, BCY_REV, BCY_COGE, BCY_COGS
  ,MATERIAL_GROUP_NAME, ORG_GP, AVG_UNIT_COST, BAC_AZIENDA
  ,BAC_SRC_AZIENDA, MAKTX_S810, BUS_SCE_CAT_CODE, BUS_SCE_CAT_NAME
  ,IS_SMALL_B, INVOICE_CODE, D_MINILED, D_BUS_SCE_S
  ,STD_QTY, ZA_SALE_COGS, AD_SALE_COGS, MA_SALE_COGS
  ,CALC_RULE_1, SH_BF_SALE_COGS, SHIPPING_ORDER, D_EFF_CLASS
  ,D_BU_SHOP, D_EC_STORE, MAP_D_CHANNEL, MAP_D_ECOM_BU
  ,D_UNICUSTGRP
)
SELECT
  NEWID() AS OID
  ,AW.COD_SCENARIO
  ,AW.COD_PERIODO
  ,AW.SHOP_CODE
  ,AW.COD_AZIENDA
  ,AW.COD_DEST1
  ,AW.COD_AZI_CTP
  ,AW.D_PRC_GRP
  ,AW.COD_CONTO
  ,AW.D_SALE_DEPT
  ,AW.COD_DEST3
  ,AW.COD_CATEGORIA
  ,AW.D_PRO_CLASS
  ,AW.D_DATA_BLOCK
  ,AW.D_DIFF_TYPE
  ,AW.MATERIAL_CODE
  ,AW.MATERIAL_NAME
  ,AW.COD_DEST2
  ,AW.COD_DEST4
  ,AW.D_MARKET_PNT
  ,AW.D_PRO_SSER
  ,AW.D_SPEC_SEC
  ,AW.D_PRO_TYPE_S
  ,AW.D_QUA_METHOD
  ,AW.D_PRO_STAGE
  ,AW.D_PRI_RANGE
  ,AW.D_PRO_SERIES
  ,AW.D_TECH_TYPE
  ,AW.D_MODEL_LCA
  ,AW.D_PRO_TYPE
  ,AW.SALE_MODEL_NAME
  ,AW.D_POL_CLASS
  ,AW.MODEL_NAME
  ,AW.CUST_CODE
  ,AW.MODEL_CODE
  ,AW.SALE_MODEL_CODE
  ,AW.CUST_NAME
  ,AW.D_CHANNEL
  ,AW.D_MODE
  ,AW.D_ONOFFLINE
  ,AW.D_ECOM_BU
  ,AW.CUST_UNITY_NAME
  ,AW.CREDIT_LEVEL_NAME
  ,AW.CUST_NATURE_NAME
  ,AW.CUST_TYPE_NAME
  ,AW.D_IND_C_TYPE
  ,AW.D_CNL_C_TYPE
  ,AW.COD_VALUTA
  ,-1*AW.SHIP_QTY AS SHIP_QTY
  ,AW.COD_VALUTA_ORIGINARIA
  ,-1*AW.ORDER_QTY AS ORDER_QTY
  ,-1*AW.BILL_QTY AS BILL_QTY
  ,-1*AW.SALE_REV AS SALE_REV
  ,-1*AW.DISCOUNT_3 AS DISCOUNT_3
  ,-1*AW.DISCOUNT_4 AS DISCOUNT_4
  ,-1*AW.DISCOUNT_5 AS DISCOUNT_5
  ,-1*AW.DISCOUNT_6 AS DISCOUNT_6
  ,AW.TAX_RATE
  ,AW.EXCHANGE_RATE
  ,-1*AW.ORG_QTY AS ORG_QTY
  ,-1*AW.MAP_QTY AS MAP_QTY
  ,-1*AW.ORG_REV AS ORG_REV
  ,-1*AW.MAP_REV AS MAP_REV
  ,-1*AW.MAP_REV1 AS MAP_REV1
  ,-1*AW.MAP_DIS3 AS MAP_DIS3
  ,-1*AW.MAP_DIS4 AS MAP_DIS4
  ,-1*AW.MAP_DIS5 AS MAP_DIS5
  ,-1*AW.MAP_DIS6 AS MAP_DIS6
  ,AW.POLICY_AMT
  ,AW.BATCH_ID
  ,AW.SOLD_TO_CODE
  ,AW.SOLD_TO_NAME
  ,AW.MATERIAL_GROUP_CODE
  ,AW.SRC_SYSTEM
  ,AW.SRC_DETAIL
  ,AW.SHOP_NAME
  ,AW.AGENCY_CODE
  ,AW.AGENCY_NAME
  ,AW.IS_MINILED_CODE
  ,AW.PROVENIENZA
  ,AW.USERUPD
  ,AW.DATEUPD
  ,AW.EN_VERSION
  ,AW.SALE_COGS
  ,-1*AW.DISCOUNT_1 AS DISCOUNT_1
  ,-1*AW.MAP_DIS1 AS MAP_DIS1
  ,-1*AW.DISCOUNT_30 AS DISCOUNT_30
  ,-1*AW.DISCOUNT_34 AS DISCOUNT_34
  ,-1*AW.MAP_DIS30 AS MAP_DIS30
  ,-1*AW.MAP_DIS34 AS MAP_DIS34
  ,AW.NOTE
  ,AW.D_BU_TRAN
  ,AW.CUSTOMER_MODEL
  ,AW.ORDER_TYPE_CODE
  ,AW.ZCALASSET
  ,AW.CALC_RULE
  ,AW.STATUTORY_ACCT_CODE
  ,-1*AW.MAP_ZUM AS MAP_ZUM
  ,AW.CN_CLASS_MARK_CODE
  ,AW.CN_CLASS_MARK_NAME
  ,AW.SALE_CERT_TYPE
  ,AW.CN_SALE_COGS
  ,-1*AW.CN_ORG_REV AS CN_ORG_REV
  ,-1*AW.CN_MAP_ZUM AS CN_MAP_ZUM
  ,'REV_01_227' AS D_ADJ_TYPE
  ,AW.CHANGE_COEFFICIENT
  ,AW.GFCFY_AMOUNT
  ,AW.GFCFL_AMOUNT
  ,AW.D_OPER_TYPE
  ,-1*AW.BCY_REV AS BCY_REV
  ,AW.BCY_COGE
  ,AW.BCY_COGS
  ,AW.MATERIAL_GROUP_NAME
  ,AW.ORG_GP
  ,AW.AVG_UNIT_COST
  ,AW.BAC_AZIENDA
  ,AW.BAC_SRC_AZIENDA
  ,AW.MAKTX_S810
  ,AW.BUS_SCE_CAT_CODE
  ,AW.BUS_SCE_CAT_NAME
  ,AW.IS_SMALL_B
  ,AW.INVOICE_CODE
  ,AW.D_MINILED
  ,AW.D_BUS_SCE_S
  ,-1*AW.STD_QTY AS STD_QTY
  ,AW.ZA_SALE_COGS
  ,AW.AD_SALE_COGS
  ,AW.MA_SALE_COGS
  ,AW.CALC_RULE_1
  ,AW.SH_BF_SALE_COGS
  ,AW.SHIPPING_ORDER
  ,AW.D_EFF_CLASS
  ,AW.D_BU_SHOP
  ,AW.D_EC_STORE
  ,AW.MAP_D_CHANNEL
  ,AW.MAP_D_ECOM_BU
  ,AW.D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
WHERE 1=1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO  = P_PERIODO
  AND AW.COD_AZIENDA  = '2910'
  AND AW.COD_CONTO LIKE 'S6001%'
  AND NVL(AW.D_ADJ_TYPE,'|') NOT IN ('REV_01_227','REV_01_228')   --排除本步骤已生成的行，防重复处理
  AND EXISTS (SELECT 1
                FROM DIM_RULE_FI_MR_CUST_ONOFF_RATIO R
               WHERE R.CUST_CODE = AW.CUST_CODE
                 AND NVL(SUBSTR(VALID_FR,1,6),'202401') <= V_YEARMONTH
                 AND NVL(SUBSTR(VALID_TO,1,6),'999999') >= V_YEARMONTH
                 )      --客商不在配置表内的行不处理
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.12.1.1 REV001_STEP_12_1(TVS销量收入分摊)-冲销完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.12.1.2 生成分摊数据（按配置渠道分组，金额 × RATIO，D_ONOFFLINE 取配置 ONOFFLINE_CODE）*/
INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP
(
  OID, COD_SCENARIO, COD_PERIODO, SHOP_CODE
  ,COD_AZIENDA, COD_DEST1, COD_AZI_CTP, D_PRC_GRP
  ,COD_CONTO, D_SALE_DEPT, COD_DEST3, COD_CATEGORIA
  ,D_PRO_CLASS, D_DATA_BLOCK, D_DIFF_TYPE, MATERIAL_CODE
  ,MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT
  ,D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_QUA_METHOD
  ,D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE
  ,D_MODEL_LCA, D_PRO_TYPE, SALE_MODEL_NAME, D_POL_CLASS
  ,MODEL_NAME, CUST_CODE, MODEL_CODE, SALE_MODEL_CODE
  ,CUST_NAME, D_CHANNEL, D_MODE, D_ONOFFLINE
  ,D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME
  ,CUST_TYPE_NAME, D_IND_C_TYPE, D_CNL_C_TYPE, COD_VALUTA
  ,SHIP_QTY, COD_VALUTA_ORIGINARIA, ORDER_QTY, BILL_QTY
  ,SALE_REV, DISCOUNT_3, DISCOUNT_4, DISCOUNT_5
  ,DISCOUNT_6, TAX_RATE, EXCHANGE_RATE, ORG_QTY
  ,MAP_QTY, ORG_REV, MAP_REV, MAP_REV1
  ,MAP_DIS3, MAP_DIS4, MAP_DIS5, MAP_DIS6
  ,POLICY_AMT, BATCH_ID, SOLD_TO_CODE, SOLD_TO_NAME
  ,MATERIAL_GROUP_CODE, SRC_SYSTEM, SRC_DETAIL, SHOP_NAME
  ,AGENCY_CODE, AGENCY_NAME, IS_MINILED_CODE, PROVENIENZA
  ,USERUPD, DATEUPD, EN_VERSION, SALE_COGS
  ,DISCOUNT_1, MAP_DIS1, DISCOUNT_30, DISCOUNT_34
  ,MAP_DIS30, MAP_DIS34, NOTE, D_BU_TRAN
  ,CUSTOMER_MODEL, ORDER_TYPE_CODE, ZCALASSET, CALC_RULE
  ,STATUTORY_ACCT_CODE, MAP_ZUM, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME
  ,SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM
  ,D_ADJ_TYPE, CHANGE_COEFFICIENT, GFCFY_AMOUNT, GFCFL_AMOUNT
  ,D_OPER_TYPE, BCY_REV, BCY_COGE, BCY_COGS
  ,MATERIAL_GROUP_NAME, ORG_GP, AVG_UNIT_COST, BAC_AZIENDA
  ,BAC_SRC_AZIENDA, MAKTX_S810, BUS_SCE_CAT_CODE, BUS_SCE_CAT_NAME
  ,IS_SMALL_B, INVOICE_CODE, D_MINILED, D_BUS_SCE_S
  ,STD_QTY, ZA_SALE_COGS, AD_SALE_COGS, MA_SALE_COGS
  ,CALC_RULE_1, SH_BF_SALE_COGS, SHIPPING_ORDER, D_EFF_CLASS
  ,D_BU_SHOP, D_EC_STORE, MAP_D_CHANNEL, MAP_D_ECOM_BU
  ,D_UNICUSTGRP
)
SELECT
  NEWID() AS OID
  ,AW.COD_SCENARIO
  ,AW.COD_PERIODO
  ,AW.SHOP_CODE
  ,AW.COD_AZIENDA
  ,AW.COD_DEST1
  ,AW.COD_AZI_CTP
  ,AW.D_PRC_GRP
  ,AW.COD_CONTO
  ,AW.D_SALE_DEPT
  ,AW.COD_DEST3
  ,AW.COD_CATEGORIA
  ,AW.D_PRO_CLASS
  ,AW.D_DATA_BLOCK
  ,AW.D_DIFF_TYPE
  ,AW.MATERIAL_CODE
  ,AW.MATERIAL_NAME
  ,AW.COD_DEST2
  ,AW.COD_DEST4
  ,AW.D_MARKET_PNT
  ,AW.D_PRO_SSER
  ,AW.D_SPEC_SEC
  ,AW.D_PRO_TYPE_S
  ,AW.D_QUA_METHOD
  ,AW.D_PRO_STAGE
  ,AW.D_PRI_RANGE
  ,AW.D_PRO_SERIES
  ,AW.D_TECH_TYPE
  ,AW.D_MODEL_LCA
  ,AW.D_PRO_TYPE
  ,AW.SALE_MODEL_NAME
  ,AW.D_POL_CLASS
  ,AW.MODEL_NAME
  ,AW.CUST_CODE
  ,AW.MODEL_CODE
  ,AW.SALE_MODEL_CODE
  ,AW.CUST_NAME
  ,AW.D_CHANNEL
  ,AW.D_MODE
  ,R.ONOFFLINE_CODE AS D_ONOFFLINE
  ,AW.D_ECOM_BU
  ,AW.CUST_UNITY_NAME
  ,AW.CREDIT_LEVEL_NAME
  ,AW.CUST_NATURE_NAME
  ,AW.CUST_TYPE_NAME
  ,AW.D_IND_C_TYPE
  ,AW.D_CNL_C_TYPE
  ,AW.COD_VALUTA
  ,AW.SHIP_QTY * R.RATIO AS SHIP_QTY
  ,AW.COD_VALUTA_ORIGINARIA
  ,AW.ORDER_QTY * R.RATIO AS ORDER_QTY
  ,AW.BILL_QTY * R.RATIO AS BILL_QTY
  ,AW.SALE_REV * R.RATIO AS SALE_REV
  ,AW.DISCOUNT_3 * R.RATIO AS DISCOUNT_3
  ,AW.DISCOUNT_4 * R.RATIO AS DISCOUNT_4
  ,AW.DISCOUNT_5 * R.RATIO AS DISCOUNT_5
  ,AW.DISCOUNT_6 * R.RATIO AS DISCOUNT_6
  ,AW.TAX_RATE
  ,AW.EXCHANGE_RATE
  ,AW.ORG_QTY * R.RATIO AS ORG_QTY
  ,AW.MAP_QTY * R.RATIO AS MAP_QTY
  ,AW.ORG_REV * R.RATIO AS ORG_REV
  ,AW.MAP_REV * R.RATIO AS MAP_REV
  ,AW.MAP_REV1 * R.RATIO AS MAP_REV1
  ,AW.MAP_DIS3 * R.RATIO AS MAP_DIS3
  ,AW.MAP_DIS4 * R.RATIO AS MAP_DIS4
  ,AW.MAP_DIS5 * R.RATIO AS MAP_DIS5
  ,AW.MAP_DIS6 * R.RATIO AS MAP_DIS6
  ,AW.POLICY_AMT
  ,AW.BATCH_ID
  ,AW.SOLD_TO_CODE
  ,AW.SOLD_TO_NAME
  ,AW.MATERIAL_GROUP_CODE
  ,AW.SRC_SYSTEM
  ,AW.SRC_DETAIL
  ,AW.SHOP_NAME
  ,AW.AGENCY_CODE
  ,AW.AGENCY_NAME
  ,AW.IS_MINILED_CODE
  ,AW.PROVENIENZA
  ,AW.USERUPD
  ,AW.DATEUPD
  ,AW.EN_VERSION
  ,AW.SALE_COGS
  ,AW.DISCOUNT_1 * R.RATIO AS DISCOUNT_1
  ,AW.MAP_DIS1 * R.RATIO AS MAP_DIS1
  ,AW.DISCOUNT_30 * R.RATIO AS DISCOUNT_30
  ,AW.DISCOUNT_34 * R.RATIO AS DISCOUNT_34
  ,AW.MAP_DIS30 * R.RATIO AS MAP_DIS30
  ,AW.MAP_DIS34 * R.RATIO AS MAP_DIS34
  ,AW.NOTE
  ,AW.D_BU_TRAN
  ,AW.CUSTOMER_MODEL
  ,AW.ORDER_TYPE_CODE
  ,AW.ZCALASSET
  ,AW.CALC_RULE
  ,AW.STATUTORY_ACCT_CODE
  ,AW.MAP_ZUM * R.RATIO AS MAP_ZUM
  ,AW.CN_CLASS_MARK_CODE
  ,AW.CN_CLASS_MARK_NAME
  ,AW.SALE_CERT_TYPE
  ,AW.CN_SALE_COGS
  ,AW.CN_ORG_REV * R.RATIO AS CN_ORG_REV
  ,AW.CN_MAP_ZUM * R.RATIO AS CN_MAP_ZUM
  ,'REV_01_228' AS D_ADJ_TYPE
  ,AW.CHANGE_COEFFICIENT
  ,AW.GFCFY_AMOUNT
  ,AW.GFCFL_AMOUNT
  ,AW.D_OPER_TYPE
  ,AW.BCY_REV * R.RATIO AS BCY_REV
  ,AW.BCY_COGE
  ,AW.BCY_COGS
  ,AW.MATERIAL_GROUP_NAME
  ,AW.ORG_GP
  ,AW.AVG_UNIT_COST
  ,AW.BAC_AZIENDA
  ,AW.BAC_SRC_AZIENDA
  ,AW.MAKTX_S810
  ,AW.BUS_SCE_CAT_CODE
  ,AW.BUS_SCE_CAT_NAME
  ,AW.IS_SMALL_B
  ,AW.INVOICE_CODE
  ,AW.D_MINILED
  ,AW.D_BUS_SCE_S
  ,AW.STD_QTY * R.RATIO AS STD_QTY
  ,AW.ZA_SALE_COGS
  ,AW.AD_SALE_COGS
  ,AW.MA_SALE_COGS
  ,AW.CALC_RULE_1
  ,AW.SH_BF_SALE_COGS
  ,AW.SHIPPING_ORDER
  ,AW.D_EFF_CLASS
  ,AW.D_BU_SHOP
  ,AW.D_EC_STORE
  ,AW.MAP_D_CHANNEL
  ,AW.MAP_D_ECOM_BU
  ,AW.D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
JOIN (SELECT CUST_CODE
            ,ONOFFLINE_CODE
            ,RATIO
        FROM DIM_RULE_FI_MR_CUST_ONOFF_RATIO
       WHERE 1=1
         AND NVL(SUBSTR(VALID_FR,1,6),'202401') <= V_YEARMONTH
         AND NVL(SUBSTR(VALID_TO,1,6),'999999') >= V_YEARMONTH) R
  ON R.CUST_CODE = AW.CUST_CODE
WHERE 1=1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO  = P_PERIODO
  AND AW.COD_AZIENDA  = '2910'
  AND AW.COD_CONTO LIKE 'S6001%'
  AND NVL(AW.D_ADJ_TYPE,'|') NOT IN ('REV_01_227','REV_01_228')   --排除本步骤已生成的行，防重复处理
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.12.1 REV001_STEP_12_1(TVS销量收入分摊)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.9 REV001_STEP_9(金额还原-数据处理))*/

UPDATE AW_MR9_REVM01_000001_TEMP ss
--EDIT BY LC 20261019 修正：2910+BSEG 家族(SRC_DETAIL IN BSEG/BSEG_FLJC/BSEG_REVM) 不变号，2910+313A 变号；其余公司维持原逻辑
--ALTER BY 20261026 XIAOAYCHAO.EX 2910公司增加管法差不变号
   /* 2026-11-16 变更 C-037：D 来源（VBRP/SMS/BSEG 等）收入已由 D 表取负（贷方为负），本段不再二次取负；
      AD 及非 D 来源（ADJM01 / ADJ_DI / REVM01 等）不在 D 表，仍按「录入正数 + M 取负」原逻辑。
      D 来源的 MAP_REV 改为 ORG_REV + 各折扣（等价于 -(收入-折扣)，负号沿用 D 的口径）。 */
   SET MAP_REV = CASE
                   WHEN COD_CONTO IN ('S600100','S600100AD','S600112','S600114') AND SRC_DETAIL NOT IN ('GLPCA') AND COD_AZIENDA NOT IN ('6012','2023') AND NOT (COD_AZIENDA = '2910' AND SRC_DETAIL IN ('BSEG','BSEG_FLJC','BSEG_REVM','ADJ_DI_MAG','ADJ_DI')) AND NVL(SRC_DETAIL,'|') IN ('VBRP','SMS_RL','GSMS_RL','REV_CIS','ZTFI313A','GLPCA','BSEG','BSEG_FLJC','BSEG_REVM')
                        THEN ORG_REV+MAP_DIS1+MAP_DIS3+MAP_DIS4+MAP_DIS5+MAP_DIS6+MAP_DIS30+MAP_DIS34
                   WHEN COD_CONTO IN ('S600100','S600100AD','S600112','S600114') AND SRC_DETAIL NOT IN ('GLPCA') AND COD_AZIENDA NOT IN ('6012','2023') AND NOT (COD_AZIENDA = '2910' AND SRC_DETAIL IN ('BSEG','BSEG_FLJC','BSEG_REVM','ADJ_DI_MAG','ADJ_DI'))
                        THEN 0-(ORG_REV-MAP_DIS1-MAP_DIS3-MAP_DIS4-MAP_DIS5-MAP_DIS6-MAP_DIS30-MAP_DIS34)
                   ELSE ORG_REV END,
       MAP_REV1 = CASE
                   WHEN COD_CONTO IN ('S600100','S600100AD','S600112','S600114') AND SRC_DETAIL NOT IN ('GLPCA') AND COD_AZIENDA NOT IN ('6012','2023') AND NOT (COD_AZIENDA = '2910' AND SRC_DETAIL IN ('BSEG','BSEG_FLJC','BSEG_REVM','ADJ_DI_MAG','ADJ_DI')) AND NVL(SRC_DETAIL,'|') IN ('VBRP','SMS_RL','GSMS_RL','REV_CIS','ZTFI313A','GLPCA','BSEG','BSEG_FLJC','BSEG_REVM')
                        THEN ORG_REV+MAP_DIS1+MAP_DIS3+MAP_DIS4+MAP_DIS30+MAP_DIS34
                   WHEN COD_CONTO IN ('S600100','S600100AD','S600112','S600114') AND SRC_DETAIL NOT IN ('GLPCA') AND COD_AZIENDA NOT IN ('6012','2023') AND NOT (COD_AZIENDA = '2910' AND SRC_DETAIL IN ('BSEG','BSEG_FLJC','BSEG_REVM','ADJ_DI_MAG','ADJ_DI'))
                        THEN 0-(ORG_REV-MAP_DIS1-MAP_DIS3-MAP_DIS4-MAP_DIS30-MAP_DIS34)
                   ELSE  ORG_REV END,
       ORG_REV = CASE
                   WHEN COD_CONTO IN ('S600100','S600100AD','S600112','S600114') AND SRC_DETAIL NOT IN ('GLPCA') AND COD_AZIENDA NOT IN ('6012','2023') AND NOT (COD_AZIENDA = '2910' AND SRC_DETAIL IN ('BSEG','BSEG_FLJC','BSEG_REVM','ADJ_DI_MAG','ADJ_DI')) AND NVL(SRC_DETAIL,'|') NOT IN ('VBRP','SMS_RL','GSMS_RL','REV_CIS','ZTFI313A','GLPCA','BSEG','BSEG_FLJC','BSEG_REVM')
                        THEN -1*ORG_REV
                   ELSE ORG_REV END,
       MAP_DIS1 = CASE WHEN COD_CONTO IN ('S600100') THEN -1*MAP_DIS1 ELSE MAP_DIS1 END,
       MAP_DIS3 = CASE WHEN COD_CONTO IN ('S600100') THEN -1*MAP_DIS3 ELSE MAP_DIS3 END,
       MAP_DIS4 = CASE WHEN COD_CONTO IN ('S600100') THEN -1*MAP_DIS4 ELSE MAP_DIS4 END,
       MAP_DIS5 = CASE WHEN COD_CONTO IN ('S600100') THEN -1*MAP_DIS5 ELSE MAP_DIS5 END,
       MAP_DIS6 = CASE WHEN COD_CONTO IN ('S600100') THEN -1*MAP_DIS6 ELSE MAP_DIS6 END,
       MAP_DIS30 = CASE WHEN COD_CONTO IN ('S600100') THEN -1*MAP_DIS30 ELSE MAP_DIS30 END,
       MAP_DIS34 = CASE WHEN COD_CONTO IN ('S600100') THEN -1*MAP_DIS34 ELSE MAP_DIS34 END
 WHERE  1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND (
            (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
            OR
            (
              (PROVENIENZA = 'CPM_SP_D2M_REV_M'
                AND COD_CONTO LIKE '%AD'
                AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
                AND P_ORG_FLAG = 2
              )
            )
          OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
          OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
          )
  ;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.9 REV001_STEP_9(金额还原-数据处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.13 REV001_STEP_13(中国区-线下分销国补业务处理)*/
/*2.2.14 REV001_STEP_14(中国区-品线天猫挂链)*/
/*2.2.15 REV001_STEP_15(中国区-小B业务)*/
/*
MERGE INTO AW_MR9_REVM01_000001_TEMP T
USING (
    SELECT T.OID,
           S.COD_AZIENDA AS S_COD_AZIENDA
    FROM AW_MR9_REVM01_000001_TEMP T
    LEFT JOIN TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 S
         ON T.COD_AZIENDA = S.COD_AZIENDA
        AND S.COD_BG = 'BG012_BU'
    WHERE T.COD_SCENARIO = P_SCENARIO
      AND T.COD_PERIODO  = P_PERIODO
      AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
      --AND INSTR(V_AZIENDA, T.COD_AZIENDA) > 0
      AND T.PROVENIENZA IN ('CPM_SP_D2M_REV_M')
) C
ON (T.OID = C.OID)
WHEN MATCHED THEN UPDATE SET
    CN_MAP_ZUM =
        CASE
          WHEN T.SRC_DETAIL LIKE 'ZTSO04_CK%' OR T.SRC_DETAIL LIKE 'ZTSO04_TH%'
              THEN T.MAP_ZUM
          WHEN C.S_COD_AZIENDA IS NOT NULL
               AND T.AGENCY_CODE = '120B'
               AND T.CUST_CODE = '2040200'
              THEN 0
          WHEN C.S_COD_AZIENDA IS NOT NULL
               AND T.CN_CLASS_MARK_CODE = 'Z2'
              THEN 0
          WHEN C.S_COD_AZIENDA IS NOT NULL
               AND T.SALE_CERT_TYPE IN ('ZORC','ZREC')
              THEN 0
          WHEN C.S_COD_AZIENDA IS NULL
              THEN 0
          ELSE T.MAP_ZUM
        END,
    CN_ORG_REV =
        CASE
          WHEN T.SRC_DETAIL LIKE 'ZTSO04_CK%' OR T.SRC_DETAIL LIKE 'ZTSO04_TH%'
              THEN T.ORG_REV
          WHEN C.S_COD_AZIENDA IS NOT NULL
               AND T.AGENCY_CODE = '120B'
               AND T.CUST_CODE = '2040200'
              THEN 0
          WHEN C.S_COD_AZIENDA IS NOT NULL
               AND T.CN_CLASS_MARK_CODE = 'Z2'
              THEN 0
          WHEN C.S_COD_AZIENDA IS NOT NULL
               AND T.SALE_CERT_TYPE IN ('ZORC','ZREC')
              THEN 0
          WHEN C.S_COD_AZIENDA IS NULL
              THEN 0
          ELSE T.ORG_REV
        END,
    D_OPER_TYPE =
        CASE
          WHEN T.COD_AZIENDA LIKE '12%'
               AND T.AGENCY_CODE = '120B'
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
               AND T.CUST_CODE = '2040200'
              THEN 'OPTY020'
          WHEN T.COD_AZIENDA LIKE '12%'
               AND T.SALE_CERT_TYPE IN ('ZORC', 'ZREC')
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
              THEN 'OPTY021'
          WHEN T.COD_AZIENDA LIKE '12%'
               AND T.AGENCY_CODE = '120B'
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
               AND T.CUST_CODE = '2040200'
               AND T.SALE_CERT_TYPE IN ('ZORC', 'ZREC')
              THEN 'OPTY020,OPTY021'
          WHEN C.S_COD_AZIENDA IS NOT NULL
               AND T.CN_CLASS_MARK_CODE = 'Z2'
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
              THEN 'OPTY025'
          WHEN T.SRC_DETAIL = 'VBRP'
               AND T.COD_AZIENDA = '1180'
               AND T.COD_AZI_CTP LIKE '12%'
              THEN 'OPTY026'
          ELSE T.D_OPER_TYPE
        END,
    D_ONOFFLINE =
        CASE
          WHEN T.COD_AZIENDA LIKE '12%'
               AND T.SALE_CERT_TYPE IN ('ZORC', 'ZREC')
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
               AND T.SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
              THEN '020_OFF_002'
          ELSE T.D_ONOFFLINE
        END
;
*/
/*
UPDATE AW_MR9_REVM01_000001_TEMP
SET
    --销量-特殊处理后-中国区
    CN_MAP_ZUM =
        CASE
          WHEN SRC_DETAIL LIKE 'ZTSO04_CK%' OR SRC_DETAIL LIKE 'ZTSO04_TH%'
              THEN MAP_ZUM
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND AGENCY_CODE = '120B'
                 AND CUST_CODE = '2040200'
                 AND COD_SCENARIO = P_SCENARIO
                 AND COD_PERIODO = P_PERIODO
                 THEN 0
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND CN_CLASS_MARK_CODE = 'Z2'
                 --AND D_ECOM_BU IN ('TM0101','TM0102') TAOANZHE20260207删除--
                 AND COD_SCENARIO = P_SCENARIO
                 AND COD_PERIODO = P_PERIODO
                 THEN 0
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND SALE_CERT_TYPE IN ('ZORC','ZREC')
                 AND COD_SCENARIO = P_SCENARIO
                 AND COD_PERIODO = P_PERIODO
                 THEN 0
            WHEN COD_AZIENDA NOT IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND COD_SCENARIO = P_SCENARIO
                 AND COD_PERIODO = P_PERIODO
            THEN 0
            ELSE MAP_ZUM
        END,
    --收入金额(折扣后不含税)-本位币-中国区
    CN_ORG_REV =
        CASE
          WHEN SRC_DETAIL LIKE 'ZTSO04_CK%' OR SRC_DETAIL LIKE 'ZTSO04_TH%'
              THEN ORG_REV
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND AGENCY_CODE = '120B'
                 AND CUST_CODE = '2040200'
                 AND COD_SCENARIO = P_SCENARIO
                 AND COD_PERIODO = P_PERIODO
                 THEN 0
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND CN_CLASS_MARK_CODE = 'Z2'
                 --AND D_ECOM_BU IN ('TM0101','TM0102') TAOANZHE20260207删除--
                 AND COD_SCENARIO = P_SCENARIO
                 AND COD_PERIODO = P_PERIODO
                 THEN 0
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND SALE_CERT_TYPE IN ('ZORC','ZREC')
                 AND COD_SCENARIO = P_SCENARIO
                 AND COD_PERIODO = P_PERIODO
            THEN 0
            WHEN COD_AZIENDA NOT IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND COD_SCENARIO = P_SCENARIO
                 AND COD_PERIODO = P_PERIODO
            THEN 0
            ELSE ORG_REV
        END,
    --业务分类（REV001_STEP_13/15）
    D_OPER_TYPE =
    CASE
        WHEN COD_AZIENDA like '12%'
          --COD_AZIENDA BETWEEN '1201' AND '1233'
             AND AGENCY_CODE = '120B'
          AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
             AND CUST_CODE = '2040200'
             AND COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
        THEN 'OPTY020'
        WHEN COD_AZIENDA like '12%'
          --COD_AZIENDA BETWEEN '1201' AND '1233'
             AND SALE_CERT_TYPE IN ('ZORC', 'ZREC')
             AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
             AND COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
        THEN 'OPTY021'
        WHEN COD_AZIENDA like '12%'
          --COD_AZIENDA BETWEEN '1201' AND '1233'
             AND AGENCY_CODE = '120B'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
             AND CUST_CODE = '2040200'
             AND SALE_CERT_TYPE IN ('ZORC', 'ZREC')
             AND COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
        THEN 'OPTY020,OPTY021'
    \*REV001_STEP_14(中国区-挂链)*\
    WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
             AND CN_CLASS_MARK_CODE = 'Z2'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
             AND COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
        THEN 'OPTY025'
    \*REV001_STEP_16(中国区-京东超链)*\
    WHEN SRC_DETAIL = 'VBRP'
       AND COD_AZIENDA = '1180'
       AND COD_AZI_CTP LIKE '12%'
             AND COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
        THEN 'OPTY026'
        ELSE D_OPER_TYPE
    END,
  D_ONOFFLINE = CASE WHEN COD_AZIENDA like '12%'
       --COD_AZIENDA BETWEEN '1201' AND '1233'
             AND SALE_CERT_TYPE IN ('ZORC', 'ZREC')
             AND COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
          AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
        THEN '020_OFF_002'
        ELSE D_ONOFFLINE
    END
 WHERE  1=1
   AND COD_SCENARIO = SUBSTR(V_YEARMONTH, 1, 4) ||'ACT'
   AND COD_PERIODO = SUBSTR(V_YEARMONTH, 5, 2)
   --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND PROVENIENZA = 'CPM_SP_D2M_REV_M'

;
*/

-- ===================================================================
-- REVM01 中国区字段拆分 UPDATE（原单个UPDATE拆为3个）
-- 原表：AW_MR9_REVM01_000001_TEMP
-- 拆分原则：按业务逻辑独立性拆分，CN_MAP_ZUM + CN_ORG_REV 条件一致合并
-- ===================================================================

-- ███████████████████████████████████████████████████████████████████
-- 第1步：CN_MAP_ZUM（销量-特殊处理后-中国区） + CN_ORG_REV（收入-中国区）
-- 两条 CASE WHEN 条件完全一致，仅 ELSE 取值不同，合并为一个 UPDATE
-- ███████████████████████████████████████████████████████████████████
UPDATE AW_MR9_REVM01_000001_TEMP
SET
    CN_MAP_ZUM =
        CASE
            WHEN SRC_DETAIL LIKE 'ZTSO04_CK%' OR SRC_DETAIL LIKE 'ZTSO04_TH%'
                THEN MAP_ZUM
            /* WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND AGENCY_CODE = '120B'
                 AND CUST_CODE = '2040200'
                THEN 0 */ --20260910FJF_ADD 取消REV001_STEP_13国补相关处理
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND CN_CLASS_MARK_CODE = 'Z2'
                THEN 0
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND SALE_CERT_TYPE IN ('ZORC','ZREC')
                THEN 0
            WHEN COD_AZIENDA NOT IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                THEN 0
            ELSE MAP_ZUM
        END,
    CN_ORG_REV =
        CASE
            WHEN SRC_DETAIL LIKE 'ZTSO04_CK%' OR SRC_DETAIL LIKE 'ZTSO04_TH%'
                THEN ORG_REV
            /* WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND AGENCY_CODE = '120B'
                 AND CUST_CODE = '2040200'
                THEN 0 */ --20260910FJF_ADD 取消REV001_STEP_13国补相关处理
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND CN_CLASS_MARK_CODE = 'Z2'
                THEN 0
            WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND SALE_CERT_TYPE IN ('ZORC','ZREC')
                THEN 0
            WHEN COD_AZIENDA NOT IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                THEN 0
            ELSE ORG_REV
        END
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = SUBSTR(V_YEARMONTH, 5, 2)
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  AND PROVENIENZA = 'CPM_SP_D2M_REV_M';

-- ███████████████████████████████████████████████████████████████████
-- 第2步：D_OPER_TYPE（业务分类 REV001_STEP_13/14/15/16）
-- 逻辑独立，单独 UPDATE
-- ███████████████████████████████████████████████████████████████████
UPDATE AW_MR9_REVM01_000001_TEMP
SET D_OPER_TYPE =
    CASE
        /* REV001_STEP_13: 京东自营(120B) → OPTY020 */
       /*  WHEN COD_AZIENDA LIKE '12%'
             AND AGENCY_CODE = '120B'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
             AND CUST_CODE = '2040200'
            THEN 'OPTY020' */ --20260910FJF_ADD 取消REV001_STEP_13国补相关处理
        /* REV001_STEP_15: 中国区-小B业务 → OPTY021 */
        WHEN COD_AZIENDA LIKE '12%'
             AND SALE_CERT_TYPE IN ('ZORC', 'ZREC')
            THEN 'OPTY021'
        /* REV001_STEP_13+15 重叠: 京东自营+零售 → OPTY020,OPTY021 */
        WHEN COD_AZIENDA LIKE '12%'
             AND AGENCY_CODE = '120B'
             AND CUST_CODE = '2040200'
             AND SALE_CERT_TYPE IN ('ZORC', 'ZREC')
            THEN 'OPTY020,OPTY021'
        /* REV001_STEP_14: 中国区-挂链 → OPTY025 */
        WHEN COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
             AND CN_CLASS_MARK_CODE = 'Z2'
            THEN 'OPTY025'
        /* REV001_STEP_16: 中国区-京东超链 → OPTY026
        WHEN SRC_DETAIL = 'VBRP'
             AND COD_AZIENDA = '1180'
             AND COD_AZI_CTP LIKE '12%'
            THEN 'OPTY026'
        */
        ELSE D_OPER_TYPE
    END
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = SUBSTR(V_YEARMONTH, 5, 2)
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
  --AND NVL(COD_CATEGORIA,'|') <> 'ZAMOUNT' --仅更新类别不为ZAMOUNT的数据。20260820FJF_ADD
  --EDIT BY LC 20261102 费用转政策业务分类被覆盖问题修改
  AND SRC_DETAIL IN ('ADJM01','ADJ_DI')
  AND D_OPER_TYPE IS NULL
  ;

--20260922fjf_add REV001_STEP_14(中国区-挂链) 管法差异项
UPDATE AW_MR9_REVM01_000001_TEMP
SET D_DIFF_TYPE = '150102006'
WHERE COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = SUBSTR(V_YEARMONTH, 5, 2)
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
AND NVL(COD_CATEGORIA,'|') <> 'ZAMOUNT' --仅更新类别不为ZAMOUNT的数据。20260820FJF_ADD
AND COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
AND CN_CLASS_MARK_CODE = 'Z2'
AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
  ;

-- ███████████████████████████████████████████████████████████████████
-- 第3步：D_ONOFFLINE（线上/线下标记）
-- 简单逻辑，单独 UPDATE
-- ███████████████████████████████████████████████████████████████████
UPDATE AW_MR9_REVM01_000001_TEMP
SET D_ONOFFLINE =
    CASE
        WHEN COD_AZIENDA LIKE '12%'
             AND SALE_CERT_TYPE IN ('ZORC', 'ZREC')
             AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
             AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
            THEN '020_OFF_002'
        ELSE D_ONOFFLINE
    END
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = SUBSTR(V_YEARMONTH, 5, 2)
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  AND PROVENIENZA = 'CPM_SP_D2M_REV_M';





INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.13/14/15 REV001_STEP_13/14/15_数据处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*2.2.16 REV001_STEP_16(中国区-成本字段更新)*/  --20260928fjf_add REV001_STEP_16(中国区-成本字段更新)


/*2.2.16 REV001_STEP_16(中国区-成本字段更新)*/
MERGE /*+ USE_HASH(T C) */ INTO AW_MR9_REVM01_000001_TEMP T
USING (
    SELECT T2.OID,
           CASE
             --EDIT BY LC 20260905 补充中国区其他业务成本取数
             WHEN T2.D_OPER_TYPE IN ('OPTY033','OPTY036','OPTY034','OPTY035','OPTY028','OPTY027')
                 THEN T2.SALE_COGS
         --20260928fjf_add REV001_STEP_16(中国区-成本字段更新) 新增来源ADJM01
     --20260930fjf_add 9月不上线不发版 去掉ADJM01
             WHEN T2.SRC_DETAIL LIKE 'ZTSO04_CK%' OR T2.SRC_DETAIL LIKE 'ZTSO04_TH%' OR T2.SRC_DETAIL IN (/* 'ADJM01', */'ECPX','VBRP_O2O','VBRP_O2O_TH','VBRP_O2O_ZR','VBRP_O2O_TC','POLICY_COST')
                 THEN T2.SALE_COGS
      --20260916FJF_ADD REV001_STEP_16(中国区-成本字段更新)去掉中国区品线标记编码为Z1时的取数逻辑
             /* WHEN S.COD_AZIENDA IS NOT NULL
                  AND T2.CN_CLASS_MARK_CODE = 'Z1'
                  AND B.SUPPLY_PRICE IS NOT NULL
                 THEN B.SUPPLY_PRICE / 1.13 * T2.CN_MAP_ZUM
             WHEN S.COD_AZIENDA IS NOT NULL
                  AND T2.CN_CLASS_MARK_CODE = 'Z1'
                  AND C.SETTLEMENT_POINT IS NOT NULL
                 THEN -1 * T2.CN_ORG_REV * (1 - C.SETTLEMENT_POINT) */
       --20260929LC_ADD REV001_STEP_16(中国区-成本字段更新)去掉中国区品线标记编码为Z2时的取数逻辑
             /*WHEN S.COD_AZIENDA IS NOT NULL
                  AND T2.CN_CLASS_MARK_CODE = 'Z2'
                 THEN -1 * T2.CN_ORG_REV*/
             WHEN S.COD_AZIENDA IS NOT NULL
                  AND T2.CN_CLASS_MARK_CODE IS NULL
                 THEN T2.SALE_COGS
             WHEN S.COD_AZIENDA IS NULL
                 THEN 0
             ELSE 0
           END AS NEW_CN_SALE_COGS
    FROM AW_MR9_REVM01_000001_TEMP T2
    LEFT JOIN TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 S
         ON T2.COD_AZIENDA = S.COD_AZIENDA
        AND S.COD_BG = 'BG012_BU'
    LEFT JOIN (
        SELECT DISTINCT
               COD_DEST2, MATERIAL_CODE,
               FIRST_VALUE(SUPPLY_PRICE) OVER(
                   PARTITION BY COD_DEST2, MATERIAL_CODE
                   ORDER BY VALID_TO DESC
               ) AS SUPPLY_PRICE
        FROM TGK_FIMA_HISENSE.AW_MR6_REVR03_000001
        WHERE TO_DATE(V_YEARMONTH, 'YYYYMM')
              BETWEEN TO_DATE(VALID_FR, 'YYYYMM')
              AND TO_DATE(NVL(VALID_TO,'999912'), 'YYYYMM')
    ) B
         ON B.COD_DEST2 = T2.COD_DEST2
        AND B.MATERIAL_CODE = T2.MATERIAL_CODE
    LEFT JOIN (
        SELECT DISTINCT
               COD_DEST2, D_MARKET_PNT, D_ECOM_BU,
               FIRST_VALUE(SETTLEMENT_POINT) OVER(
                   PARTITION BY COD_DEST2, D_MARKET_PNT, D_ECOM_BU
                   ORDER BY VALID_TO DESC
               ) AS SETTLEMENT_POINT
        FROM TGK_FIMA_HISENSE.AW_MR6_REVR02_000001
        WHERE TO_DATE(V_YEARMONTH, 'YYYYMM')
              BETWEEN TO_DATE(VALID_FR, 'YYYYMM')
              AND TO_DATE(NVL(VALID_TO,'999912'), 'YYYYMM')
    ) C
         ON C.COD_DEST2 = T2.COD_DEST2
        AND C.D_MARKET_PNT = T2.D_MARKET_PNT
        AND C.D_ECOM_BU = T2.D_ECOM_BU
    WHERE T2.COD_SCENARIO = P_SCENARIO
      AND T2.COD_PERIODO  = P_PERIODO
      AND T2.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
      --AND INSTR(V_AZIENDA, T2.COD_AZIENDA) > 0
      AND (
            (T2.PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
            OR (T2.PROVENIENZA = 'CPM_SP_D2M_REV_M'
                AND T2.COD_CONTO LIKE '%AD'
                AND NVL(T2.SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
                AND P_ORG_FLAG = 2)
            OR (T2.NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
            OR T2.PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M')
          )
) C
ON (T.OID = C.OID)
WHEN MATCHED THEN UPDATE SET
    T.CN_SALE_COGS = C.NEW_CN_SALE_COGS
;





/*
UPDATE AW_MR9_REVM01_000001_TEMP TARGET
SET TARGET.CN_SALE_COGS = (
    SELECT
        CASE
          WHEN TARGET.SRC_DETAIL LIKE 'ZTSO04_CK%' OR TARGET.SRC_DETAIL LIKE 'ZTSO04_TH%'
              THEN TARGET.SALE_COGS
            WHEN TARGET.COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND TARGET.CN_CLASS_MARK_CODE = 'Z1'
                 AND B.SUPPLY_PRICE IS NOT NULL
                 AND TO_DATE(SUBSTR(TARGET.COD_SCENARIO, 1, 4) || TARGET.COD_PERIODO, 'YYYYMM')
                     BETWEEN TO_DATE(B.VALID_FR, 'YYYYMM')
                     AND TO_DATE(NVL(B.VALID_TO, '999912'), 'YYYYMM')
            THEN B.SUPPLY_PRICE / 1.13 * TARGET.CN_MAP_ZUM

            WHEN TARGET.COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND TARGET.CN_CLASS_MARK_CODE = 'Z1'
                 AND C.SETTLEMENT_POINT IS NOT NULL
                 AND TO_DATE(SUBSTR(TARGET.COD_SCENARIO, 1, 4) || TARGET.COD_PERIODO, 'YYYYMM')
                     BETWEEN TO_DATE(C.VALID_FR, 'YYYYMM')
                     AND TO_DATE(NVL(C.VALID_TO, '999912'), 'YYYYMM')
            THEN -1*TARGET.CN_ORG_REV * (1 - C.SETTLEMENT_POINT)

            WHEN TARGET.COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND TARGET.CN_CLASS_MARK_CODE = 'Z2'
            THEN -1*TARGET.CN_ORG_REV

            WHEN TARGET.COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
                 AND TARGET.CN_CLASS_MARK_CODE IS NULL
            THEN TARGET.SALE_COGS

            WHEN TARGET.COD_AZIENDA NOT IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
            THEN 0

            ELSE 0--TARGET.SALE_COGS
        END AS CN_SALE_COGS
    FROM DUAL
    LEFT JOIN (
        SELECT
            COD_DEST2, SUPPLY_PRICE, MATERIAL_CODE, VALID_FR, VALID_TO
        FROM TGK_FIMA_HISENSE.AW_MR6_REVR03_000001
        WHERE TO_DATE(SUBSTR(TARGET.COD_SCENARIO, 1, 4) || TARGET.COD_PERIODO, 'YYYYMM')
              BETWEEN TO_DATE(VALID_FR, 'YYYYMM')
              AND TO_DATE(NVL(VALID_TO, '999912'), 'YYYYMM')
              AND ROWID = (
                  SELECT MAX(ROWID)
                  FROM TGK_FIMA_HISENSE.AW_MR6_REVR03_000001
                  WHERE COD_DEST2 = TARGET.COD_DEST2
                  AND MATERIAL_CODE = TARGET.MATERIAL_CODE
              )
    ) B ON B.COD_DEST2 = TARGET.COD_DEST2
        AND B.MATERIAL_CODE = TARGET.MATERIAL_CODE
    LEFT JOIN (
        SELECT
            COD_DEST2, D_MARKET_PNT, D_ECOM_BU, SETTLEMENT_POINT, VALID_FR, VALID_TO
        FROM TGK_FIMA_HISENSE.AW_MR6_REVR02_000001
        WHERE TO_DATE(SUBSTR(TARGET.COD_SCENARIO, 1, 4) || TARGET.COD_PERIODO, 'YYYYMM')
              BETWEEN TO_DATE(VALID_FR, 'YYYYMM')
              AND TO_DATE(NVL(VALID_TO, '999912'), 'YYYYMM')
              AND ROWID = (
                  SELECT MAX(ROWID)
                  FROM TGK_FIMA_HISENSE.AW_MR6_REVR02_000001
                  WHERE COD_DEST2 = TARGET.COD_DEST2
                        AND D_MARKET_PNT = TARGET.D_MARKET_PNT
                        AND D_ECOM_BU = TARGET.D_ECOM_BU
              )
    ) C ON C.COD_DEST2 = TARGET.COD_DEST2
          AND C.D_MARKET_PNT = TARGET.D_MARKET_PNT
          AND C.D_ECOM_BU = TARGET.D_ECOM_BU
)
WHERE COD_SCENARIO = SUBSTR(V_YEARMONTH, 1, 4) ||'ACT'
   AND COD_PERIODO = SUBSTR(V_YEARMONTH, 5, 2)
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
   ;
*/


--EDIT BY LC 20260930 21:55 当来源不为出库未开ZTSO04_CK%,退货未办ZTSO04_TH%,【D_OPER_TYPE-业务分类】为"OPTY021中国区自营-小B业务、OPTY025中国区自营-品线挂链、OPTY039中国区自营=费用转成本,OPTY040中国区自营-品线挂链费用转成本"时赋值为0,否则取SALE_COGS

UPDATE AW_MR9_REVM01_000001_TEMP ss
   SET CN_SALE_COGS = 0
 WHERE  1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200')
    AND D_OPER_TYPE IN ('OPTY021','OPTY025','OPTY039','OPTY040')
    AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
    AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
    ;
COMMIT;
UPDATE AW_MR9_REVM01_000001_TEMP ss
   SET CN_SALE_COGS = SALE_COGS
 WHERE  1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND HIE = '10' AND NODE = '200')
    AND NVL(D_OPER_TYPE,'NULL') NOT IN ('OPTY021','OPTY025','OPTY039','OPTY040')
    AND SRC_DETAIL NOT LIKE 'ZTSO04_CK%'
    AND SRC_DETAIL NOT LIKE 'ZTSO04_TH%'
    ;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.16 REV001_STEP_16(中国区-成本字段更新)_数据处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;




/*REV001_STEP_16(中国区-其他业务)SXX */

/*将中国区公司下，其他业务部分的业务分类进行调整
限制条件：根据AW_RUL_CNMECL_000001-中国区-其他业务收入范围配置表中限制对应的公司【COMPANY_SCOPE】、渠道分组【D_ONOFFLINE】、利润中心【COD_DEST2】，将这部分数据取出后，更新业务分类【D_OPER_TYPE】
备注：公司可能维护12%，另外渠道分组、利润中心，可能只维护一列，只要满足一个就可以。注意限制起止时间
业务分类取数字段：D_OPER_TYPE
20260325 YH新增*/
/*
MERGE \*+ USE_HASH(T C) *\ INTO AW_MR9_REVM01_000001_TEMP T
USING (
SELECT
    T.OID,
    T.COD_AZIENDA,
    T.D_ONOFFLINE,
    T.COD_DEST2,
    C.D_OPER_TYPE
FROM AW_MR9_REVM01_000001_TEMP T
JOIN (select distinct COMPANY_SCOPE,D_ONOFFLINE,COD_DEST2,D_OPER_TYPE
  from TGK_FIMA_HISENSE.AW_RUL_CNMECL_000001 c
  where C.D_OPER_TYPE IS NOT NULL
AND NVL(C.VALID_FR,'202501') <= SUBSTR(V_SCENARIO,1,4) || V_PERIODO
AND NVL(C.VALID_TO,'999999') >= SUBSTR(V_SCENARIO,1,4) || V_PERIODO
  ) C
  ON (C.COMPANY_SCOPE IS NULL OR T.COD_AZIENDA LIKE C.COMPANY_SCOPE)
  AND (C.D_ONOFFLINE IS NULL OR T.D_ONOFFLINE = C.D_ONOFFLINE)
  AND (C.COD_DEST2 IS NULL OR T.COD_DEST2 = C.COD_DEST2)
WHERE 1=1
AND T.COD_SCENARIO = V_SCENARIO
AND T.COD_PERIODO = V_PERIODO
AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, T.COD_AZIENDA) > 0
) C
ON (
   T.OID = C.OID
)
WHEN MATCHED THEN
    UPDATE SET T.D_OPER_TYPE = C.D_OPER_TYPE;*/

/* UPDATE AW_MR9_REVM01_000001_TEMP T
   SET T.D_OPER_TYPE = (
           SELECT C.D_OPER_TYPE
             FROM TGK_FIMA_HISENSE.AW_RUL_CNMECL_000001 C
            WHERE C.D_OPER_TYPE IS NOT NULL
              AND NVL(C.VALID_FR, '202501') <= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
              AND NVL(C.VALID_TO, '999999') >= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
              AND (C.COMPANY_SCOPE IS NULL OR T.COD_AZIENDA LIKE C.COMPANY_SCOPE)
              AND (C.D_ONOFFLINE  IS NULL OR T.D_ONOFFLINE   = C.D_ONOFFLINE)
              AND (C.COD_DEST2     IS NULL OR T.COD_DEST2      = C.COD_DEST2)
              AND ROWNUM = 1
       )
 WHERE T.COD_SCENARIO = V_SCENARIO
   AND T.COD_PERIODO  = V_PERIODO
   AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND EXISTS (
           SELECT 1
             FROM TGK_FIMA_HISENSE.AW_RUL_CNMECL_000001 C
            WHERE C.D_OPER_TYPE IS NOT NULL
              AND NVL(C.VALID_FR, '202501') <= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
              AND NVL(C.VALID_TO, '999999') >= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
              AND (C.COMPANY_SCOPE IS NULL OR T.COD_AZIENDA LIKE C.COMPANY_SCOPE)
              AND (C.D_ONOFFLINE  IS NULL OR T.D_ONOFFLINE   = C.D_ONOFFLINE)
              AND (C.COD_DEST2     IS NULL OR T.COD_DEST2      = C.COD_DEST2)
       ); */ --20260820FJF_ADD 注释原逻辑


/*2.2.17 REV001_STEP_17(中国区自营收入成本调整)*/
INSERT /*+ PARALLEL(2) */  INTO AW_MR9_REVM01_000001_TEMP(
OID,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
COD_CONTO,
CUST_CODE,
CUST_NAME,
MATERIAL_CODE,
MATERIAL_NAME,
COD_DEST2,
D_CHANNEL,
D_MODE,
D_ONOFFLINE,
SALE_MODEL_CODE,
MODEL_CODE,
SHOP_CODE,
SRC_SYSTEM,
SOLD_TO_CODE,
SOLD_TO_NAME,
MATERIAL_GROUP_CODE,
COD_AZI_CTP,
BATCH_ID,
D_PRC_GRP,
COD_VALUTA_ORIGINARIA,
SRC_DETAIL,
USERUPD,
DATEUPD,
BILL_QTY,
SHIP_QTY,
ORDER_QTY,
SALE_REV,
DISCOUNT_1,
DISCOUNT_3,
DISCOUNT_4,
DISCOUNT_5,
DISCOUNT_6,
DISCOUNT_30,
DISCOUNT_34,
TAX_RATE,
EXCHANGE_RATE,
COD_DEST1,
COD_DEST4,
D_SPEC_SEC,
D_PRO_TYPE_S,
D_PRO_SSER,
D_QUA_METHOD,
D_PRO_STAGE,
D_PRI_RANGE,
D_PRO_SERIES,
D_MARKET_PNT,
D_TECH_TYPE,
D_PRO_CLASS,
D_MODEL_LCA,
D_PRO_TYPE,
CUST_UNITY_NAME,
CREDIT_LEVEL_NAME,
CUST_NATURE_NAME,
CUST_TYPE_NAME,
SHOP_NAME,
SALE_MODEL_NAME,
MODEL_NAME,
D_CNL_C_TYPE,
D_IND_C_TYPE,
D_ECOM_BU,
D_SALE_DEPT,
COD_DEST3,
AGENCY_CODE,
AGENCY_NAME,
IS_MINILED_CODE,
CUSTOMER_MODEL,
ORDER_TYPE_CODE,
ZCALASSET,
CN_CLASS_MARK_CODE,
CN_CLASS_MARK_NAME,
SALE_CERT_TYPE,
D_ADJ_TYPE,
CN_SALE_COGS,
CN_MAP_ZUM,
CN_ORG_REV,
PROVENIENZA,
D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
)

SELECT
NEWID() AS OID,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
'S600100AD' AS COD_CONTO,
CUST_CODE,
CUST_NAME,
MATERIAL_CODE,
MATERIAL_NAME,
COD_DEST2,
D_CHANNEL AS D_CHANNEL,
'ZZZZ' AS D_MODE,
D_ONOFFLINE,
'' AS SALE_MODEL_CODE,
'' AS MODEL_CODE,
'' AS SHOP_CODE,
'' AS SRC_SYSTEM,
'' AS SOLD_TO_CODE,
'' AS SOLD_TO_NAME,
'' AS MATERIAL_GROUP_CODE,
COD_AZI_CTP,
'' AS BATCH_ID,
'ZZZZ' AS D_PRC_GRP,
'' AS COD_VALUTE_ORIGINARIA,
'ADJM01' AS SRC_DETAIL,
SESSION_USER AS USERUPD,
SYSDATE AS DATEUPD,
0 AS BILL_QTY,
0 AS SHIP_QTY,
0 AS ORDER_QTY,
0 AS SALE_REV,
0 AS DISCOUNT_1,
0 AS DISCOUNT_3,
0 AS DISCOUNT_4,
0 AS DISCOUNT_5,
0 AS DISCOUNT_6,
0 AS DISCOUNT_30,
0 AS DISCOUNT_34,
0 AS TAX_RATE,
0 AS EXCHANGE_RATE,
CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
COD_DEST4,
'ZZZZ' AS D_SPEC_SEC,
'ZZZZ' AS D_PRO_TYPE_S,
'ZZZZ' AS D_PRO_SSER,
'ZZZZ' AS D_QUA_METHOD,
'ZZZZ' AS D_PRO_STAGE,
'ZZZZ' AS D_PRI_RANGE,
'ZZZZ' AS D_PRO_SERIES,
D_MARKET_PNT AS D_MARKET_PNT,
'ZZZZ' AS D_TECH_TYPE,
'ZZZZ' AS D_PRO_CLASS,
'ZZZZ' AS D_MODEL_LCA,
'ZZZZ' AS D_PRO_TYPE,
'' AS CUST_UNITY_NAME,
'' AS CREDIT_LEVEL_NAME,
'' AS CUST_NATURE_NAME,
'' AS CUST_TYPE_NAME,
'' AS SHOP_NAME,
'' AS SALE_MODEL_NAME,
'' AS MODEL_NAME,
'ZZZZ' AS D_CNL_C_TYPE,
'ZZZZ' AS D_IND_C_TYPE,
D_ECOM_BU,
D_SALE_DEPT,
COD_DEST3,
'' AS AGENCY_CODE,
'' AS AGENCY_NAME,
'' AS IS_MINILED_CODE,
'' AS CUSTOMER_MODEL,
'' AS ORDER_TYPE_CODE,
'' AS ZCALASSET,
CN_CLASS_MARK_CODE,
CN_CLASS_MARK_NAME,
'' AS SALE_CERT_TYPE,
D_ADJ_TYPE,
0 AS CN_SALE_COGS,
MAP_QTY AS CN_MAP_ZUM,
0 - ORG_REV AS CN_ORG_REV,
'CPM_SP_D2M_REV_M' PROVENIENZA,
D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
FROM TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001
WHERE 1=1
AND COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
/*20260526 shqingfeng.ex 修改限制条件*/
AND COD_CATEGORIA = 'GA00_CN_REV'
;
COMMIT;


INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
OID,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
COD_CONTO,
CUST_CODE,
CUST_NAME,
MATERIAL_CODE,
MATERIAL_NAME,
COD_DEST2,
D_CHANNEL,
D_MODE,
D_ONOFFLINE,
SALE_MODEL_CODE,
MODEL_CODE,
SHOP_CODE,
SRC_SYSTEM,
SOLD_TO_CODE,
SOLD_TO_NAME,
MATERIAL_GROUP_CODE,
COD_AZI_CTP,
BATCH_ID,
D_PRC_GRP,
COD_VALUTA_ORIGINARIA,
SRC_DETAIL,
USERUPD,
DATEUPD,
BILL_QTY,
SHIP_QTY,
ORDER_QTY,
SALE_REV,
DISCOUNT_1,
DISCOUNT_3,
DISCOUNT_4,
DISCOUNT_5,
DISCOUNT_6,
DISCOUNT_30,
DISCOUNT_34,
TAX_RATE,
EXCHANGE_RATE,
COD_DEST1,
COD_DEST4,
D_SPEC_SEC,
D_PRO_TYPE_S,
D_PRO_SSER,
D_QUA_METHOD,
D_PRO_STAGE,
D_PRI_RANGE,
D_PRO_SERIES,
D_MARKET_PNT,
D_TECH_TYPE,
D_PRO_CLASS,
D_MODEL_LCA,
D_PRO_TYPE,
CUST_UNITY_NAME,
CREDIT_LEVEL_NAME,
CUST_NATURE_NAME,
CUST_TYPE_NAME,
SHOP_NAME,
SALE_MODEL_NAME,
MODEL_NAME,
D_CNL_C_TYPE,
D_IND_C_TYPE,
D_ECOM_BU,
D_SALE_DEPT,
COD_DEST3,
AGENCY_CODE,
AGENCY_NAME,
IS_MINILED_CODE,
CUSTOMER_MODEL,
ORDER_TYPE_CODE,
ZCALASSET,
CN_CLASS_MARK_CODE,
CN_CLASS_MARK_NAME,
SALE_CERT_TYPE,
D_ADJ_TYPE,
CN_SALE_COGS,
CN_MAP_ZUM,
CN_ORG_REV,
PROVENIENZA,
D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
)

SELECT
NEWID() AS OID,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
'S640100AD' AS COD_CONTO,
CUST_CODE,
CUST_NAME,
MATERIAL_CODE,
MATERIAL_NAME,
COD_DEST2,
D_CHANNEL AS D_CHANNEL,
'ZZZZ' AS D_MODE,
D_ONOFFLINE,
'' AS SALE_MODEL_CODE,
'' AS MODEL_CODE,
'' AS SHOP_CODE,
'' AS SRC_SYSTEM,
'' AS SOLD_TO_CODE,
'' AS SOLD_TO_NAME,
'' AS MATERIAL_GROUP_CODE,
COD_AZI_CTP,
'' AS BATCH_ID,
'ZZZZ' AS D_PRC_GRP,
'' AS COD_VALUTE_ORIGINARIA,
'ADJM01' AS SRC_DETAIL,
SESSION_USER AS USERUPD,
SYSDATE AS DATEUPD,
0 AS BILL_QTY,
0 AS SHIP_QTY,
0 AS ORDER_QTY,
0 AS SALE_REV,
0 AS DISCOUNT_1,
0 AS DISCOUNT_3,
0 AS DISCOUNT_4,
0 AS DISCOUNT_5,
0 AS DISCOUNT_6,
0 AS DISCOUNT_30,
0 AS DISCOUNT_34,
0 AS TAX_RATE,
0 AS EXCHANGE_RATE,
CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
COD_DEST4,
'ZZZZ' AS D_SPEC_SEC,
'ZZZZ' AS D_PRO_TYPE_S,
'ZZZZ' AS D_PRO_SSER,
'ZZZZ' AS D_QUA_METHOD,
'ZZZZ' AS D_PRO_STAGE,
'ZZZZ' AS D_PRI_RANGE,
'ZZZZ' AS D_PRO_SERIES,
D_MARKET_PNT AS D_MARKET_PNT,
'ZZZZ' AS D_TECH_TYPE,
'ZZZZ' AS D_PRO_CLASS,
'ZZZZ' AS D_MODEL_LCA,
'ZZZZ' AS D_PRO_TYPE,
'' AS CUST_UNITY_NAME,
'' AS CREDIT_LEVEL_NAME,
'' AS CUST_NATURE_NAME,
'' AS CUST_TYPE_NAME,
'' AS SHOP_NAME,
'' AS SALE_MODEL_NAME,
'' AS MODEL_NAME,
'ZZZZ' AS D_CNL_C_TYPE,
'ZZZZ' AS D_IND_C_TYPE,
D_ECOM_BU,
D_SALE_DEPT,
COD_DEST3,
'' AS AGENCY_CODE,
'' AS AGENCY_NAME,
'' AS IS_MINILED_CODE,
'' AS CUSTOMER_MODEL,
'' AS ORDER_TYPE_CODE,
'' AS ZCALASSET,
CN_CLASS_MARK_CODE,
CN_CLASS_MARK_NAME,
'' AS SALE_CERT_TYPE,
D_ADJ_TYPE,
SALE_COGS AS CN_SALE_COGS,
0 AS CN_MAP_ZUM,
0 AS CN_ORG_REV,
'CPM_SP_D2M_REV_M' PROVENIENZA,
D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
FROM TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001
WHERE COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
AND COD_CATEGORIA = 'ZFAMOUNT'
AND D_ADJ_TYPE = 'REV_01_401'
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.17 REV001_STEP_17(中国区自营收入成本调整)_数据处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/* REV001_STEP_16(中国区-业务分类补充) 20260820FJF_ADD
 * 仅更新类别不为ZAMOUNT的数据。20260820FJF_ADD
 * 优先级：其他业务配置 > 古洛尼相关 > 会员店 > 费用转政策。
 */
UPDATE AW_MR9_REVM01_000001_TEMP T
   SET T.D_OPER_TYPE =
       CASE /* ① 其他业务配置：公司必须匹配，渠道/利润中心/电商BU任意一项匹配即可 */
           WHEN EXISTS (
                    SELECT 1
                      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_OPER_TYPE_MAPPING C
                     WHERE C.OPER_TYPE_CODE IS NOT NULL
                       AND NVL(C.VALID_FR, '202501') <= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
                       AND NVL(C.VALID_TO, '999999') >= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
                       AND T.COD_AZIENDA LIKE C.COMPANY_CODE
                       AND (
                              (C.ONOFFLINE_CODE IS NOT NULL AND T.D_ONOFFLINE = C.ONOFFLINE_CODE)
                           OR (C.PROFITCENTER_CODE IS NOT NULL AND T.COD_DEST2 = C.PROFITCENTER_CODE)
                           OR (C.ECOM_CODE IS NOT NULL AND T.D_ECOM_BU = C.ECOM_CODE)
                           )
                )
           THEN (
                    SELECT C.OPER_TYPE_CODE
                      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_OPER_TYPE_MAPPING C
                     WHERE C.OPER_TYPE_CODE IS NOT NULL
                       AND NVL(C.VALID_FR, '202501') <= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
                       AND NVL(C.VALID_TO, '999999') >= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
                       AND T.COD_AZIENDA LIKE C.COMPANY_CODE
                       AND (
                              (C.ONOFFLINE_CODE IS NOT NULL AND T.D_ONOFFLINE = C.ONOFFLINE_CODE)
                           OR (C.PROFITCENTER_CODE IS NOT NULL AND T.COD_DEST2 = C.PROFITCENTER_CODE)
                           OR (C.ECOM_CODE IS NOT NULL AND T.D_ECOM_BU = C.ECOM_CODE)
                           )
                       AND ROWNUM = 1
                )
           /* ② 古洛尼相关 */
           WHEN T.AGENCY_CODE = 'G055' THEN 'OPTY037'
           WHEN T.AGENCY_CODE = 'G056' THEN 'OPTY038'
           /* ③ 会员店（品质之家门店） */
           WHEN (T.COD_AZIENDA = '1180' OR T.COD_AZIENDA LIKE '12%')
            AND T.SHOP_CODE IN ('15295336542', 'DP118005162', 'DP118005033')
           THEN 'OPTY041'
           /* ④ 费用转政策 */
           WHEN (T.COD_AZIENDA = '1180' OR T.COD_AZIENDA LIKE '12%') AND T.D_BUS_SCE_S = '026'
            AND T.COD_CONTO LIKE '6401%' AND T.CN_CLASS_MARK_CODE = 'Z1'
           THEN 'OPTY039'
           WHEN (T.COD_AZIENDA = '1180' OR T.COD_AZIENDA LIKE '12%') AND T.D_BUS_SCE_S = '026'
         AND T.COD_CONTO LIKE '6401%' AND T.CN_CLASS_MARK_CODE = 'Z2'
           THEN 'OPTY040'
           WHEN (T.COD_AZI_CTP = '1180' OR T.COD_AZI_CTP LIKE '12%') AND T.COD_CONTO = 'S600101AD' AND D_ADJ_TYPE IN ('REV_01_201','REV_01_203')
           THEN 'OPTY061' -- ALTER BY LIYIFAN 20261016 ⑤事业部对中国区出库未开
           ELSE T.D_OPER_TYPE
       END
 WHERE T.COD_SCENARIO = V_SCENARIO
   AND T.COD_PERIODO = V_PERIODO
   AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND NVL(T.COD_CATEGORIA,'|') <> 'ZAMOUNT'
   AND (EXISTS (
               SELECT 1
                 FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_OPER_TYPE_MAPPING C
                WHERE C.OPER_TYPE_CODE IS NOT NULL
                  AND NVL(C.VALID_FR, '202501') <= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
                  AND NVL(C.VALID_TO, '999999') >= SUBSTR(V_SCENARIO, 1, 4) || V_PERIODO
                  AND T.COD_AZIENDA LIKE C.COMPANY_CODE
                  AND (
                         (C.ONOFFLINE_CODE IS NOT NULL AND T.D_ONOFFLINE = C.ONOFFLINE_CODE)
                      OR (C.PROFITCENTER_CODE IS NOT NULL AND T.COD_DEST2 = C.PROFITCENTER_CODE)
                      OR (C.ECOM_CODE IS NOT NULL AND T.D_ECOM_BU = C.ECOM_CODE)
                      )
           )
        OR (
               (T.COD_AZIENDA = '1180' OR T.COD_AZIENDA LIKE '12%')
           AND (
                  T.AGENCY_CODE IN ('G055', 'G056')
               OR T.SHOP_CODE IN ('15295336542', 'DP118005162', 'DP118005033')
               OR (
                      T.D_BUS_SCE_S = '026'
                  AND T.COD_CONTO LIKE '6401%'
                  AND T.CN_CLASS_MARK_CODE IN ('Z1', 'Z2')
                  )
               )
           )
        OR (  -- ALTER BY LIYIFAN 20261016 ⑤事业部对中国区出库未开
               (T.COD_AZI_CTP = '1180' OR T.COD_AZI_CTP LIKE '12%')
           AND T.COD_CONTO = 'S600101AD'
           AND T.D_ADJ_TYPE IN ('REV_01_201', 'REV_01_203')
           )
       );

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.16.1 REV001_STEP_16(中国区-其他业务)_数据处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*2.2.16.2 REV001_STEP_16_1(中国区-智能生态销量处理)*/
/*EDIT BY LICHENG.EX 20261029 新增：中国区公司（COD_AZIENDA=1180 或 LIKE '12%'）业务分类为智能生态（D_OPER_TYPE='OPTY036'）的数据，中国区销量 CN_MAP_ZUM 置 0。
  位置：2.2.16.1(中国区-其他业务/业务分类补充) 之后、STEP_17-1 冲销还原之前，保证后续冲销/还原取到的中国区销量已归零，净值不为非零。*/
UPDATE AW_MR9_REVM01_000001_TEMP T
   SET T.CN_MAP_ZUM = 0
 WHERE T.COD_SCENARIO = P_SCENARIO
   AND T.COD_PERIODO  = P_PERIODO
   AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND (T.COD_AZIENDA = '1180' OR T.COD_AZIENDA LIKE '12%')
   AND T.D_OPER_TYPE = 'OPTY036'
;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.16.2 REV001_STEP_16_1(中国区-智能生态销量处理)_数据处理完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*REV001_STEP_16(中国区-ZG发票剔除) SXX */
/*202060728-1 shiqingfeng.ex 修改去除中国区-ZG发票剔除逻辑*/
/*UPDATE AW_MR9_REVM01_000001_TEMP T
   SET T.CN_MAP_ZUM = 0,
       T.CN_ORG_REV = 0
 WHERE T.COD_SCENARIO = V_SCENARIO
   AND T.COD_PERIODO  = V_PERIODO
   AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND T.COD_AZIENDA IN (SELECT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG012_BU')
   AND (T.INVOICE_CODE LIKE 'ZG%' OR T.INVOICE_CODE LIKE '%:ZG%');*/



INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.16.1 REV001_STEP_16(中国区-ZG发票剔除)_数据处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;



/*2.2.17 REV001_STEP_24(单体考核收入调整)*/
INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
OID,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
COD_CONTO,
CUST_CODE,
CUST_NAME,
MATERIAL_CODE,
MATERIAL_NAME,
COD_DEST2,
D_CHANNEL,
D_MODE,
D_ONOFFLINE,
SALE_MODEL_CODE,
MODEL_CODE,
SHOP_CODE,
SRC_SYSTEM,
SOLD_TO_CODE,
SOLD_TO_NAME,
MATERIAL_GROUP_CODE,
COD_AZI_CTP,
BATCH_ID,
D_PRC_GRP,
COD_VALUTA_ORIGINARIA,
SRC_DETAIL,
USERUPD,
DATEUPD,
BILL_QTY,
SHIP_QTY,
ORDER_QTY,
SALE_REV,
DISCOUNT_1,
DISCOUNT_3,
DISCOUNT_4,
DISCOUNT_5,
DISCOUNT_6,
DISCOUNT_30,
DISCOUNT_34,
TAX_RATE,
EXCHANGE_RATE,
COD_DEST1,
COD_DEST4,
D_SPEC_SEC,
D_PRO_TYPE_S,
D_PRO_SSER,
D_QUA_METHOD,
D_PRO_STAGE,
D_PRI_RANGE,
D_PRO_SERIES,
D_MARKET_PNT,
D_TECH_TYPE,
D_PRO_CLASS,
D_MODEL_LCA,
D_PRO_TYPE,
CUST_UNITY_NAME,
CREDIT_LEVEL_NAME,
CUST_NATURE_NAME,
CUST_TYPE_NAME,
SHOP_NAME,
SALE_MODEL_NAME,
MODEL_NAME,
D_CNL_C_TYPE,
D_IND_C_TYPE,
D_ECOM_BU,
D_SALE_DEPT,
COD_DEST3,
AGENCY_CODE,
AGENCY_NAME,
IS_MINILED_CODE,
CUSTOMER_MODEL,
ORDER_TYPE_CODE,
ZCALASSET,
CN_CLASS_MARK_CODE,
CN_CLASS_MARK_NAME,
SALE_CERT_TYPE,
D_ADJ_TYPE,
SALE_COGS,
MAP_QTY,
ORG_REV,
PROVENIENZA,
COD_CATEGORIA,
D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
)

SELECT
NEWID() AS OID,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
'S600100AD' AS COD_CONTO,
CUST_CODE,
CUST_NAME,
MATERIAL_CODE,
MATERIAL_NAME,
COD_DEST2,
D_CHANNEL AS D_CHANNEL,
'ZZZZ' AS D_MODE,
D_ONOFFLINE,
'' AS SALE_MODEL_CODE,
'' AS MODEL_CODE,
'' AS SHOP_CODE,
'' AS SRC_SYSTEM,
'' AS SOLD_TO_CODE,
'' AS SOLD_TO_NAME,
'' AS MATERIAL_GROUP_CODE,
COD_AZI_CTP,
'' AS BATCH_ID,
'ZZZZ' AS D_PRC_GRP,
'' AS COD_VALUTE_ORIGINARIA,
'ADJM01_KH' AS SRC_DETAIL,
SESSION_USER AS USERUPD,
SYSDATE AS DATEUPD,
0 AS BILL_QTY,
0 AS SHIP_QTY,
0 AS ORDER_QTY,
0 AS SALE_REV,
0 AS DISCOUNT_1,
0 AS DISCOUNT_3,
0 AS DISCOUNT_4,
0 AS DISCOUNT_5,
0 AS DISCOUNT_6,
0 AS DISCOUNT_30,
0 AS DISCOUNT_34,
0 AS TAX_RATE,
0 AS EXCHANGE_RATE,
CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
COD_DEST4,
'ZZZZ' AS D_SPEC_SEC,
'ZZZZ' AS D_PRO_TYPE_S,
'ZZZZ' AS D_PRO_SSER,
'ZZZZ' AS D_QUA_METHOD,
'ZZZZ' AS D_PRO_STAGE,
'ZZZZ' AS D_PRI_RANGE,
'ZZZZ' AS D_PRO_SERIES,
D_MARKET_PNT AS D_MARKET_PNT,
'ZZZZ' AS D_TECH_TYPE,
'ZZZZ' AS D_PRO_CLASS,
'ZZZZ' AS D_MODEL_LCA,
'ZZZZ' AS D_PRO_TYPE,
'' AS CUST_UNITY_NAME,
'' AS CREDIT_LEVEL_NAME,
'' AS CUST_NATURE_NAME,
'' AS CUST_TYPE_NAME,
'' AS SHOP_NAME,
'' AS SALE_MODEL_NAME,
'' AS MODEL_NAME,
'ZZZZ' AS D_CNL_C_TYPE,
'ZZZZ' AS D_IND_C_TYPE,
D_ECOM_BU,
D_SALE_DEPT,
COD_DEST3,
'' AS AGENCY_CODE,
'' AS AGENCY_NAME,
'' AS IS_MINILED_CODE,
'' AS CUSTOMER_MODEL,
'' AS ORDER_TYPE_CODE,
'' AS ZCALASSET,
CN_CLASS_MARK_CODE,
CN_CLASS_MARK_NAME,
'' AS SALE_CERT_TYPE,
D_ADJ_TYPE,
0 AS CN_SALE_COGS,
MAP_QTY AS MAP_QTY,
ORG_REV AS ORG_REV,
'CPM_SP_D2M_REV_M' PROVENIENZA,
COD_CATEGORIA,
D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
FROM TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001
WHERE COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
AND COD_CATEGORIA = 'GA00_REV_KH'
AND D_ADJ_TYPE = 'REV_01_201'
;
COMMIT;


INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP(
OID,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
COD_CONTO,
CUST_CODE,
CUST_NAME,
MATERIAL_CODE,
MATERIAL_NAME,
COD_DEST2,
D_CHANNEL,
D_MODE,
D_ONOFFLINE,
SALE_MODEL_CODE,
MODEL_CODE,
SHOP_CODE,
SRC_SYSTEM,
SOLD_TO_CODE,
SOLD_TO_NAME,
MATERIAL_GROUP_CODE,
COD_AZI_CTP,
BATCH_ID,
D_PRC_GRP,
COD_VALUTA_ORIGINARIA,
SRC_DETAIL,
USERUPD,
DATEUPD,
BILL_QTY,
SHIP_QTY,
ORDER_QTY,
SALE_REV,
DISCOUNT_1,
DISCOUNT_3,
DISCOUNT_4,
DISCOUNT_5,
DISCOUNT_6,
DISCOUNT_30,
DISCOUNT_34,
TAX_RATE,
EXCHANGE_RATE,
COD_DEST1,
COD_DEST4,
D_SPEC_SEC,
D_PRO_TYPE_S,
D_PRO_SSER,
D_QUA_METHOD,
D_PRO_STAGE,
D_PRI_RANGE,
D_PRO_SERIES,
D_MARKET_PNT,
D_TECH_TYPE,
D_PRO_CLASS,
D_MODEL_LCA,
D_PRO_TYPE,
CUST_UNITY_NAME,
CREDIT_LEVEL_NAME,
CUST_NATURE_NAME,
CUST_TYPE_NAME,
SHOP_NAME,
SALE_MODEL_NAME,
MODEL_NAME,
D_CNL_C_TYPE,
D_IND_C_TYPE,
D_ECOM_BU,
D_SALE_DEPT,
COD_DEST3,
AGENCY_CODE,
AGENCY_NAME,
IS_MINILED_CODE,
CUSTOMER_MODEL,
ORDER_TYPE_CODE,
ZCALASSET,
CN_CLASS_MARK_CODE,
CN_CLASS_MARK_NAME,
SALE_CERT_TYPE,
D_ADJ_TYPE,
SALE_COGS,
MAP_QTY,
ORG_REV,
PROVENIENZA,
COD_CATEGORIA,
D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
)

SELECT
NEWID() AS OID,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
'S640100AD' AS COD_CONTO,
CUST_CODE,
CUST_NAME,
MATERIAL_CODE,
MATERIAL_NAME,
COD_DEST2,
D_CHANNEL AS D_CHANNEL,
'ZZZZ' AS D_MODE,
D_ONOFFLINE,
'' AS SALE_MODEL_CODE,
'' AS MODEL_CODE,
'' AS SHOP_CODE,
'' AS SRC_SYSTEM,
'' AS SOLD_TO_CODE,
'' AS SOLD_TO_NAME,
'' AS MATERIAL_GROUP_CODE,
COD_AZI_CTP,
'' AS BATCH_ID,
'ZZZZ' AS D_PRC_GRP,
'' AS COD_VALUTE_ORIGINARIA,
'ADJM01_KH' AS SRC_DETAIL,
SESSION_USER AS USERUPD,
SYSDATE AS DATEUPD,
0 AS BILL_QTY,
0 AS SHIP_QTY,
0 AS ORDER_QTY,
0 AS SALE_REV,
0 AS DISCOUNT_1,
0 AS DISCOUNT_3,
0 AS DISCOUNT_4,
0 AS DISCOUNT_5,
0 AS DISCOUNT_6,
0 AS DISCOUNT_30,
0 AS DISCOUNT_34,
0 AS TAX_RATE,
0 AS EXCHANGE_RATE,
CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1,
COD_DEST4,
'ZZZZ' AS D_SPEC_SEC,
'ZZZZ' AS D_PRO_TYPE_S,
'ZZZZ' AS D_PRO_SSER,
'ZZZZ' AS D_QUA_METHOD,
'ZZZZ' AS D_PRO_STAGE,
'ZZZZ' AS D_PRI_RANGE,
'ZZZZ' AS D_PRO_SERIES,
D_MARKET_PNT AS D_MARKET_PNT,
'ZZZZ' AS D_TECH_TYPE,
'ZZZZ' AS D_PRO_CLASS,
'ZZZZ' AS D_MODEL_LCA,
'ZZZZ' AS D_PRO_TYPE,
'' AS CUST_UNITY_NAME,
'' AS CREDIT_LEVEL_NAME,
'' AS CUST_NATURE_NAME,
'' AS CUST_TYPE_NAME,
'' AS SHOP_NAME,
'' AS SALE_MODEL_NAME,
'' AS MODEL_NAME,
'ZZZZ' AS D_CNL_C_TYPE,
'ZZZZ' AS D_IND_C_TYPE,
D_ECOM_BU,
D_SALE_DEPT,
COD_DEST3,
'' AS AGENCY_CODE,
'' AS AGENCY_NAME,
'' AS IS_MINILED_CODE,
'' AS CUSTOMER_MODEL,
'' AS ORDER_TYPE_CODE,
'' AS ZCALASSET,
CN_CLASS_MARK_CODE,
CN_CLASS_MARK_NAME,
'' AS SALE_CERT_TYPE,
D_ADJ_TYPE,
SALE_COGS AS SALE_COGS,
0 AS CN_MAP_ZUM,
0 AS CN_ORG_REV,
'CPM_SP_D2M_REV_M' PROVENIENZA,
COD_CATEGORIA,
D_BUS_SCE_S -- ALTER BY 20261104 17:13 XIAOYACHAO.EX 增加业务场景分类
FROM TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001
WHERE COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
AND COD_CATEGORIA = 'GA00_REV_KH'
AND D_ADJ_TYPE = 'REV_01_201'
;
COMMIT;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.18 REV001_STEP_24(单体考核收入调整)数据处理)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*REV001_STEP_17-1(产品公司小B国补冲销）*/
INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP
(
OID,COD_SCENARIO,COD_PERIODO,BAC_AZIENDA,SHOP_CODE,COD_AZIENDA,COD_DEST1,COD_AZI_CTP,D_PRC_GRP,COD_CONTO,D_SALE_DEPT,COD_DEST3,D_OPER_TYPE,COD_CATEGORIA,D_PRO_CLASS,D_DATA_BLOCK,D_DIFF_TYPE,D_ADJ_TYPE,MATERIAL_CODE,MATERIAL_NAME,CUSTOMER_MODEL,COD_DEST2,COD_DEST4,D_MARKET_PNT,D_PRO_SSER,D_SPEC_SEC,D_PRO_TYPE_S,D_QUA_METHOD,D_PRO_STAGE,D_PRI_RANGE,D_PRO_SERIES,D_TECH_TYPE,D_MODEL_LCA,D_PRO_TYPE,SALE_MODEL_NAME,D_POL_CLASS,MODEL_NAME,CUST_CODE,MODEL_CODE,SALE_MODEL_CODE,BAC_SRC_AZIENDA,CUST_NAME,D_CHANNEL,D_MODE,D_ONOFFLINE,D_ECOM_BU,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,D_CNL_C_TYPE,IS_SMALL_B,SHIP_QTY,COD_VALUTA,D_IND_C_TYPE,SALE_CERT_TYPE,ORDER_TYPE_CODE
,D_BUS_SCE_S --业务场景分类
--,BUS_SCE_CAT_NAME
,ORDER_QTY,COD_VALUTA_ORIGINARIA,BILL_QTY,SALE_REV,TAX_RATE,EXCHANGE_RATE,ORG_QTY,MAP_QTY,ORG_REV,BCY_REV,MAP_REV,MAP_ZUM,MAP_REV1,MAP_DIS3,MAP_DIS4,MAP_DIS1,MAP_DIS5,MAP_DIS6,MAP_DIS30,POLICY_AMT,MAP_DIS34,BATCH_ID,SOLD_TO_CODE,SOLD_TO_NAME,MATERIAL_GROUP_CODE,SRC_SYSTEM,MATERIAL_GROUP_NAME,SRC_DETAIL,SHOP_NAME,NOTE,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,ZCALASSET,CALC_RULE,STATUTORY_ACCT_CODE,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,MAKTX_S810,CHANGE_COEFFICIENT,PROVENIENZA,DATEUPD,USERUPD,D_MINILED
--20260917FJF_ADD 二期新增字段
,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
SELECT
    NEWID() AS OID,COD_SCENARIO,COD_PERIODO,BAC_AZIENDA,SHOP_CODE,COD_AZIENDA,COD_DEST1,COD_AZI_CTP,D_PRC_GRP,COD_CONTO,D_SALE_DEPT,COD_DEST3,D_OPER_TYPE
   ,'GA00_BF' AS COD_CATEGORIA
   ,D_PRO_CLASS
   ,D_DATA_BLOCK
   ,'150102003' AS D_DIFF_TYPE
   ,'REV_01_210' AS D_ADJ_TYPE
   ,MATERIAL_CODE,MATERIAL_NAME,CUSTOMER_MODEL,COD_DEST2,COD_DEST4,D_MARKET_PNT,D_PRO_SSER,D_SPEC_SEC,D_PRO_TYPE_S,D_QUA_METHOD,D_PRO_STAGE,D_PRI_RANGE,D_PRO_SERIES,D_TECH_TYPE,D_MODEL_LCA,D_PRO_TYPE,SALE_MODEL_NAME,D_POL_CLASS,MODEL_NAME,CUST_CODE,MODEL_CODE,SALE_MODEL_CODE,BAC_SRC_AZIENDA,CUST_NAME,D_CHANNEL,D_MODE,D_ONOFFLINE,D_ECOM_BU,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,D_CNL_C_TYPE,IS_SMALL_B,SHIP_QTY,COD_VALUTA,D_IND_C_TYPE,SALE_CERT_TYPE,ORDER_TYPE_CODE
   ,D_BUS_SCE_S --业务场景分类
   --,BUS_SCE_CAT_NAME
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-ORDER_QTY ELSE 0 END AS ORDER_QTY
   ,COD_VALUTA_ORIGINARIA
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-BILL_QTY ELSE 0 END AS BILL_QTY
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-SALE_REV ELSE 0 END AS SALE_REV
   ,TAX_RATE
   ,EXCHANGE_RATE
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-ORG_QTY ELSE 0 END AS ORG_QTY
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_QTY ELSE 0 END AS MAP_QTY
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-ORG_REV ELSE 0 END AS ORG_REV
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-BCY_REV ELSE 0 END AS BCY_REV
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_REV ELSE 0 END AS MAP_REV
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_ZUM ELSE 0 END AS MAP_ZUM
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_REV1 ELSE 0 END AS MAP_REV1
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_DIS3 ELSE 0 END AS MAP_DIS3
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_DIS4 ELSE 0 END AS MAP_DIS4
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_DIS1 ELSE 0 END AS MAP_DIS1
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_DIS5 ELSE 0 END AS MAP_DIS5
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_DIS6 ELSE 0 END AS MAP_DIS6
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_DIS30 ELSE 0 END AS MAP_DIS30
   ,CASE WHEN SRC_DETAIL = 'POLICY_YT' THEN 0-POLICY_AMT ELSE 0 END AS POLICY_AMT
   ,CASE WHEN SRC_DETAIL = 'VBRP' THEN 0-MAP_DIS34 ELSE 0 END AS MAP_DIS34
   ,BATCH_ID
   ,SOLD_TO_CODE
   ,SOLD_TO_NAME
   ,MATERIAL_GROUP_CODE
   ,SRC_SYSTEM
   ,MATERIAL_GROUP_NAME
   ,'REVM01' SRC_DETAIL
   ,SHOP_NAME
   ,'产品公司小B国补冲销' AS NOTE
   ,AGENCY_CODE
   ,AGENCY_NAME
   ,IS_MINILED_CODE
   ,ZCALASSET
   ,CALC_RULE
   ,STATUTORY_ACCT_CODE
   ,CN_CLASS_MARK_CODE
   ,CN_CLASS_MARK_NAME
   ,MAKTX_S810
   ,CHANGE_COEFFICIENT
   ,'CPM_SP_D2M_REV_M' AS PROVENIENZA
   ,SYSDATE AS DATEUPD
   ,SESSION_USER AS USERUPD
   ,D_MINILED
   --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP
WHERE 1=P_ORG_FLAG
AND COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    /*
       ①公司限制：
      67%、68%、26%、23%、6515（排除6700、2800、2600、2300、【6746、6750、6751、6752、6847】线上公司）
      ②对方公司限制：
      12%
      ③线上线下维度【D_ONOFFLINE】：取节点【020_ON】【020_OFF】
      ④科目限制：S6001%
      ⑤来源限制：只取VBRP
    */
AND (COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%'
        OR (COD_AZIENDA = '6515' AND D_ONOFFLINE IN (SELECT ELEM FROM TGK_FIMA_HISENSE.V_REF_ED_D_ONOFFLINE t WHERE HIE = 'HION' AND NODE IN ('020_OFF'))))
AND COD_AZIENDA NOT IN ('6746','6750','6751','6752','6847','6700','6800','2600','2300')
AND COD_AZI_CTP LIKE '12%'
AND D_ONOFFLINE IN (SELECT ELEM FROM TGK_FIMA_HISENSE.V_REF_ED_D_ONOFFLINE t WHERE HIE = 'HION' AND NODE IN ('020_OFF'))
AND COD_CONTO LIKE 'S6001%'
AND (SRC_DETAIL = 'VBRP' OR (SRC_DETAIL = 'POLICY_YT' AND IS_SMALL_B = '1'))
AND (
      (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
      OR
      (
        (PROVENIENZA = 'CPM_SP_D2M_REV_M'
          AND COD_CONTO LIKE '%AD'
          AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
          AND P_ORG_FLAG = 2
          )
      )
      OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
      OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
    )
;

COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-1(产品公司小B国补冲销)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*REV001_STEP_17-2(中国区小B国补业务冲销）*/


INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP
(
OID
,COD_SCENARIO
,COD_PERIODO
,BAC_AZIENDA
,SHOP_CODE
,COD_AZIENDA
,COD_DEST1
,COD_AZI_CTP
,D_PRC_GRP
,COD_CONTO
,D_SALE_DEPT
,COD_DEST3
,D_OPER_TYPE
,COD_CATEGORIA
,D_PRO_CLASS
,D_DATA_BLOCK
,D_DIFF_TYPE
,D_ADJ_TYPE
,MATERIAL_CODE
,MATERIAL_NAME
,CUSTOMER_MODEL
,COD_DEST2
,COD_DEST4
,D_MARKET_PNT
,D_PRO_SSER
,D_SPEC_SEC
,D_PRO_TYPE_S
,D_QUA_METHOD
,D_PRO_STAGE
,D_PRI_RANGE
,D_PRO_SERIES
,D_TECH_TYPE
,D_MODEL_LCA
,D_PRO_TYPE
,SALE_MODEL_NAME
,D_POL_CLASS
,MODEL_NAME
,CUST_CODE
,MODEL_CODE
,SALE_MODEL_CODE
,BAC_SRC_AZIENDA
,CUST_NAME
,D_CHANNEL
,D_MODE
,D_ONOFFLINE
,D_ECOM_BU
,CUST_UNITY_NAME
,CREDIT_LEVEL_NAME
,CUST_NATURE_NAME
,CUST_TYPE_NAME
,D_CNL_C_TYPE
,IS_SMALL_B
,SHIP_QTY
,COD_VALUTA
,D_IND_C_TYPE
,SALE_CERT_TYPE
,ORDER_TYPE_CODE
,D_BUS_SCE_S --业务场景分类
,ORDER_QTY
,COD_VALUTA_ORIGINARIA
,BILL_QTY
,SALE_REV
,TAX_RATE
,EXCHANGE_RATE
,ORG_QTY
,MAP_QTY
,ORG_REV
,BCY_REV
,MAP_REV
,MAP_ZUM
,MAP_REV1
,MAP_DIS3
,MAP_DIS4
,MAP_DIS1
,MAP_DIS5
,MAP_DIS6
,MAP_DIS30
,POLICY_AMT
,MAP_DIS34
,BATCH_ID
,SOLD_TO_CODE
,SOLD_TO_NAME
,MATERIAL_GROUP_CODE
,SRC_SYSTEM
,MATERIAL_GROUP_NAME
,SRC_DETAIL
,SHOP_NAME
,NOTE
,AGENCY_CODE
,AGENCY_NAME
,IS_MINILED_CODE
,ZCALASSET
,CALC_RULE
,STATUTORY_ACCT_CODE
,CN_CLASS_MARK_CODE
,CN_CLASS_MARK_NAME
,MAKTX_S810
,CHANGE_COEFFICIENT
,PROVENIENZA
,DATEUPD
,USERUPD
,D_MINILED
--20260917FJF_ADD 二期新增字段
,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
SELECT
    NEWID() AS OID
   ,COD_SCENARIO
   ,COD_PERIODO
   ,BAC_AZIENDA
   ,SHOP_CODE
   ,COD_AZIENDA
   ,COD_DEST1
   ,COD_AZI_CTP
   ,D_PRC_GRP
   ,COD_CONTO
   ,D_SALE_DEPT
   ,COD_DEST3
   ,D_OPER_TYPE
   ,'GA00_BF' AS COD_CATEGORIA
   ,D_PRO_CLASS
   ,D_DATA_BLOCK
   ,D_DIFF_TYPE
   ,'REV_01_211' AS D_ADJ_TYPE
   ,MATERIAL_CODE
   ,MATERIAL_NAME
   ,CUSTOMER_MODEL
   ,COD_DEST2
   ,COD_DEST4
   ,D_MARKET_PNT
   ,D_PRO_SSER
   ,D_SPEC_SEC
   ,D_PRO_TYPE_S
   ,D_QUA_METHOD
   ,D_PRO_STAGE
   ,D_PRI_RANGE
   ,D_PRO_SERIES
   ,D_TECH_TYPE
   ,D_MODEL_LCA
   ,D_PRO_TYPE
   ,SALE_MODEL_NAME
   ,D_POL_CLASS
   ,MODEL_NAME
   ,CUST_CODE
   ,MODEL_CODE
   ,SALE_MODEL_CODE
   ,BAC_SRC_AZIENDA
   ,CUST_NAME
   ,D_CHANNEL
   ,D_MODE
   ,D_ONOFFLINE
   ,D_ECOM_BU
   ,CUST_UNITY_NAME
   ,CREDIT_LEVEL_NAME
   ,CUST_NATURE_NAME
   ,CUST_TYPE_NAME
   ,D_CNL_C_TYPE
   ,IS_SMALL_B
   ,SHIP_QTY
   ,COD_VALUTA
   ,D_IND_C_TYPE
   ,SALE_CERT_TYPE
   ,ORDER_TYPE_CODE
   ,D_BUS_SCE_S --业务场景分类
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-ORDER_QTY ELSE 0 END AS ORDER_QTY
   ,COD_VALUTA_ORIGINARIA
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-BILL_QTY ELSE 0 END AS BILL_QTY
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-SALE_REV ELSE 0 END AS SALE_REV
   ,TAX_RATE
   ,EXCHANGE_RATE
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-ORG_QTY ELSE 0 END AS ORG_QTY
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_QTY ELSE 0 END AS MAP_QTY
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-ORG_REV ELSE 0 END AS ORG_REV
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-BCY_REV ELSE 0 END AS BCY_REV
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_REV ELSE 0 END AS MAP_REV
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_ZUM ELSE 0 END AS MAP_ZUM
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_REV1 ELSE 0 END AS MAP_REV1
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_DIS3 ELSE 0 END AS MAP_DIS3
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_DIS4 ELSE 0 END AS MAP_DIS4
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_DIS1 ELSE 0 END AS MAP_DIS1
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_DIS5 ELSE 0 END AS MAP_DIS5
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_DIS6 ELSE 0 END AS MAP_DIS6
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_DIS30 ELSE 0 END AS MAP_DIS30
   ,CASE WHEN NVL(SRC_DETAIL,'|') = 'POLICY_YT' THEN 0-POLICY_AMT ELSE 0 END AS POLICY_AMT
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN 0-MAP_DIS34 ELSE 0 END AS MAP_DIS34
   ,BATCH_ID
   ,SOLD_TO_CODE
   ,SOLD_TO_NAME
   ,MATERIAL_GROUP_CODE
   ,SRC_SYSTEM
   ,MATERIAL_GROUP_NAME
   ,'REVM01' AS SRC_DETAIL
   ,SHOP_NAME
   --20260910FJF_ADD REV001_STEP_17-2(中国区小B国补业务冲销） ②备注修改：中国区公司小B业务冲销
   --,'中国区公司小B国补业务数据冲销' AS NOTE
   ,'中国区公司小B业务冲销' AS NOTE
   ,AGENCY_CODE
   ,AGENCY_NAME
   ,IS_MINILED_CODE
   ,ZCALASSET
   ,CALC_RULE
   ,STATUTORY_ACCT_CODE
   ,CN_CLASS_MARK_CODE
   ,CN_CLASS_MARK_NAME
   ,MAKTX_S810
   ,CHANGE_COEFFICIENT
   ,'CPM_SP_D2M_REV_M' AS PROVENIENZA
   ,SYSDATE AS DATEUPD
   ,SESSION_USER AS USERUPD
   ,D_MINILED
   --20260917FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP
WHERE 1=P_ORG_FLAG
AND COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
AND (COD_AZIENDA like '12%' OR COD_AZIENDA IN ('1180'))
/*
  ①业务分类【D_OPER_TYPE】为
  OPTY020、OPTY021 （国补业务、小B业务）
  ②是否小B【IS_SMALL_B】：只取1
  ③来源限制【SOURCE_DETAIL】：只取POLICY_YT
*/
AND D_OPER_TYPE IN (/* 'OPTY020', */'OPTY021') --20260910FJF_ADD REV001_STEP_17-2(中国区小B国补业务冲销）①取数限制修改：不取OPTY020
AND (NVL(SRC_DETAIL,'|') <> 'POLICY_YT' OR (SRC_DETAIL = 'POLICY_YT' AND IS_SMALL_B = '1'))
AND (
      (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
      OR
      (
        (PROVENIENZA = 'CPM_SP_D2M_REV_M'
          AND COD_CONTO LIKE '%AD'
          AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
          AND P_ORG_FLAG = 2
          )
      )
      OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
      OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
    )
;

COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-2(中国区小B国补业务冲销）完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*REV001_STEP_17-3(小B国补数据还原到产品公司)*/

INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP
(
OID
,COD_SCENARIO
,COD_PERIODO
,BAC_AZIENDA
,SHOP_CODE
,COD_AZIENDA
,COD_DEST1
,COD_AZI_CTP
,D_PRC_GRP
,COD_CONTO
,D_SALE_DEPT
,COD_DEST3
,D_OPER_TYPE
,COD_CATEGORIA
,D_PRO_CLASS
,D_DATA_BLOCK
,D_DIFF_TYPE
,D_ADJ_TYPE
,MATERIAL_CODE
,MATERIAL_NAME
,CUSTOMER_MODEL
,COD_DEST2
,COD_DEST4
,D_MARKET_PNT
,D_PRO_SSER
,D_SPEC_SEC
,D_PRO_TYPE_S
,D_QUA_METHOD
,D_PRO_STAGE
,D_PRI_RANGE
,D_PRO_SERIES
,D_TECH_TYPE
,D_MODEL_LCA
,D_PRO_TYPE
,SALE_MODEL_NAME
,D_POL_CLASS
,MODEL_NAME
,CUST_CODE
,MODEL_CODE
,SALE_MODEL_CODE
,BAC_SRC_AZIENDA
,CUST_NAME
,D_CHANNEL
,D_MODE
,D_ONOFFLINE
,D_ECOM_BU
,CUST_UNITY_NAME
,CREDIT_LEVEL_NAME
,CUST_NATURE_NAME
,CUST_TYPE_NAME
,D_CNL_C_TYPE
,IS_SMALL_B
,SHIP_QTY
,COD_VALUTA
,D_IND_C_TYPE
,SALE_CERT_TYPE
,ORDER_TYPE_CODE
,D_BUS_SCE_S --业务场景分类
,ORDER_QTY
,COD_VALUTA_ORIGINARIA
,BILL_QTY
,SALE_REV
,TAX_RATE
,EXCHANGE_RATE
,ORG_QTY
,MAP_QTY
,ORG_REV
,BCY_REV
,MAP_REV
,MAP_ZUM
,MAP_REV1
,MAP_DIS3
,MAP_DIS4
,MAP_DIS1
,MAP_DIS5
,MAP_DIS6
,MAP_DIS30
,POLICY_AMT
,MAP_DIS34
,BATCH_ID
,SOLD_TO_CODE
,SOLD_TO_NAME
,MATERIAL_GROUP_CODE
,SRC_SYSTEM
,MATERIAL_GROUP_NAME
,SRC_DETAIL
,SHOP_NAME
,NOTE
,AGENCY_CODE
,AGENCY_NAME
,IS_MINILED_CODE
,ZCALASSET
,CALC_RULE
,STATUTORY_ACCT_CODE
,CN_CLASS_MARK_CODE
,CN_CLASS_MARK_NAME
,MAKTX_S810
,CHANGE_COEFFICIENT
,PROVENIENZA
,DATEUPD
,USERUPD
,D_MINILED
--20260917FJF_ADD 二期新增字段
,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
SELECT
    NEWID() AS OID
   ,COD_SCENARIO
   ,COD_PERIODO
   ,BAC_AZIENDA
   ,SHOP_CODE
   ,B.FAC_COMPANY_CODE AS COD_AZIENDA
   ,COD_DEST1
   ,COD_AZI_CTP
   ,D_PRC_GRP
   ,COD_CONTO
   ,D_SALE_DEPT
   ,COD_DEST3
   ,D_OPER_TYPE
   ,'GA00_BF' AS COD_CATEGORIA
   ,D_PRO_CLASS
   ,D_DATA_BLOCK
   ,'150102003' AS D_DIFF_TYPE
   ,'REV_01_212' AS D_ADJ_TYPE
   ,MATERIAL_CODE
   ,MATERIAL_NAME
   ,CUSTOMER_MODEL
   ,A.COD_DEST2
   ,COD_DEST4
   ,D_MARKET_PNT
   ,D_PRO_SSER
   ,D_SPEC_SEC
   ,D_PRO_TYPE_S
   ,D_QUA_METHOD
   ,D_PRO_STAGE
   ,D_PRI_RANGE
   ,D_PRO_SERIES
   ,D_TECH_TYPE
   ,D_MODEL_LCA
   ,D_PRO_TYPE
   ,SALE_MODEL_NAME
   ,D_POL_CLASS
   ,MODEL_NAME
   ,CUST_CODE
   ,MODEL_CODE
   ,SALE_MODEL_CODE
   ,BAC_SRC_AZIENDA
   ,CUST_NAME
   ,D_CHANNEL
   ,D_MODE
   ,CASE WHEN NVL(SRC_DETAIL,'|') = 'POLICY_YT' THEN '020_OFF_002' ELSE D_ONOFFLINE END AS D_ONOFFLINE
   ,D_ECOM_BU
   ,CUST_UNITY_NAME
   ,CREDIT_LEVEL_NAME
   ,CUST_NATURE_NAME
   ,CUST_TYPE_NAME
   ,D_CNL_C_TYPE
   ,IS_SMALL_B
   ,SHIP_QTY
   ,COD_VALUTA
   ,D_IND_C_TYPE
   ,SALE_CERT_TYPE
   ,ORDER_TYPE_CODE
   ,D_BUS_SCE_S --业务场景分类
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN ORDER_QTY ELSE 0 END AS ORDER_QTY
   ,COD_VALUTA_ORIGINARIA
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN BILL_QTY ELSE 0 END AS BILL_QTY
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN SALE_REV ELSE 0 END AS SALE_REV
   ,TAX_RATE
   ,EXCHANGE_RATE
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN ORG_QTY ELSE 0 END AS ORG_QTY
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_QTY ELSE 0 END AS MAP_QTY
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN ORG_REV ELSE 0 END AS ORG_REV
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN BCY_REV ELSE 0 END AS BCY_REV
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_REV ELSE 0 END AS MAP_REV
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_ZUM ELSE 0 END AS MAP_ZUM
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_REV1 ELSE 0 END AS MAP_REV1
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_DIS3 ELSE 0 END AS MAP_DIS3
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_DIS4 ELSE 0 END AS MAP_DIS4
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_DIS1 ELSE 0 END AS MAP_DIS1
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_DIS5 ELSE 0 END AS MAP_DIS5
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_DIS6 ELSE 0 END AS MAP_DIS6
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_DIS30 ELSE 0 END AS MAP_DIS30
   ,CASE WHEN NVL(SRC_DETAIL,'|') = 'POLICY_YT' THEN POLICY_AMT ELSE 0 END AS POLICY_AMT
   ,CASE WHEN NVL(SRC_DETAIL,'|') <> 'POLICY_YT' THEN MAP_DIS34 ELSE 0 END AS MAP_DIS34
   ,BATCH_ID
   ,SOLD_TO_CODE
   ,SOLD_TO_NAME
   ,MATERIAL_GROUP_CODE
   ,SRC_SYSTEM
   ,MATERIAL_GROUP_NAME
   ,'REVM01' AS SRC_DETAIL
   ,SHOP_NAME
   ,'中国区公司小B国补业务数据还原到产品公司' AS NOTE
   ,AGENCY_CODE
   ,AGENCY_NAME
   ,IS_MINILED_CODE
   ,ZCALASSET
   ,CALC_RULE
   ,STATUTORY_ACCT_CODE
   ,CN_CLASS_MARK_CODE
   ,CN_CLASS_MARK_NAME
   ,MAKTX_S810
   ,CHANGE_COEFFICIENT
   ,'CPM_SP_D2M_REV_M' AS PROVENIENZA
   ,SYSDATE AS DATEUPD
   ,SESSION_USER AS USERUPD
   ,A.D_MINILED
   --20260917FJF_ADD 二期新增字段
  ,A.D_EFF_CLASS,A.D_BU_SHOP,A.D_EC_STORE,A.D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP A
--  FROM AW_MR9_REVM01_000001_TEMP A  SXX20260606修改，将跨公司取中国区公司数据表数据源改为AW表结果表，不用临时表，因为临时表被清理。
  /*
    公司对应关系：【CN_COMPANY_CODE】+【COD_DEST2】-->【FAC_COMPANY_CODE】
    参数公司为FAC_COMPANY_CODE，取数需要限制CN_COMPANY_CODE，COD_DEST2，进表公司为FAC_COMPANY_CODE
  */
INNER JOIN (SELECT CN_COMPANY_CODE,COD_DEST2,FAC_COMPANY_CODE
            FROM TGK_FIMA_HISENSE.AW_RUL_REVCPC_000001 T
            WHERE FAC_COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
            --INSTR(V_AZIENDA, FAC_COMPANY_CODE) > 0
        ) B
ON A.COD_AZIENDA = B.CN_COMPANY_CODE
AND A.COD_DEST2 = B.COD_DEST2

WHERE 1=P_ORG_FLAG
AND A.COD_SCENARIO = P_SCENARIO
AND A.COD_PERIODO = P_PERIODO
AND (A.COD_AZIENDA like '12%' OR A.COD_AZIENDA IN ('1180'))
/*
  ①业务分类【D_OPER_TYPE】为
  OPTY020、OPTY021 （国补业务、小B业务）--合并收入字段要放出来
  映射表：AW_RUL_REVCPC_000001
  公司对应关系：【CN_COMPANY_CODE】+【COD_DEST2】-->【FAC_COMPANY_CODE】
  ②是否小B【IS_SMALL_B】：只取1
  ③来源限制【SOURCE_DETAIL】：只取POLICY_YT
*/
AND D_OPER_TYPE IN ('OPTY020','OPTY021')
AND NVL(D_ADJ_TYPE,'|') NOT IN ('REV_01_211')
AND (NVL(SRC_DETAIL,'|') <> 'POLICY_YT' OR (SRC_DETAIL = 'POLICY_YT' AND IS_SMALL_B = '1'))
AND (
      (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
      OR
      (
        (
          PROVENIENZA = 'CPM_SP_D2M_REV_M'
          AND COD_CONTO LIKE '%AD'
          AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
          AND P_ORG_FLAG = 2
          )
      )
      OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
      OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
    )

;
COMMIT;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-3(小B国补数据还原到产品公司)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*REV001_STEP_17-4(O2O-产品公司冲销还原)
  REV_01_214：将中国区O2O成本转为产品公司收入并冲销
  REV_01_215：按原终端客户及原维度还原产品公司收入
*/
INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP
(
  OID,COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_CATEGORIA,COD_CONTO,
  CUST_CODE,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,D_CHANNEL,D_ONOFFLINE,
  SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SRC_SYSTEM,SOLD_TO_CODE,
  MATERIAL_GROUP_CODE,COD_AZI_CTP,BATCH_ID,D_PRC_GRP,COD_VALUTA,COD_VALUTA_ORIGINARIA,
  SRC_DETAIL,PROVENIENZA,USERUPD,DATEUPD,
  BILL_QTY,SHIP_QTY,ORDER_QTY,SALE_REV,SALE_COGS,TAX_RATE,EXCHANGE_RATE,
  COD_DEST1,COD_DEST4,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_SSER,D_QUA_METHOD,D_PRO_STAGE,
  D_PRI_RANGE,D_PRO_SERIES,D_MARKET_PNT,D_TECH_TYPE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,
  SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,D_ECOM_BU,D_SALE_DEPT,COD_DEST3,D_BUS_SCE_S,
  AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,CUSTOMER_MODEL,ORDER_TYPE_CODE,ZCALASSET,
  CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,D_ADJ_TYPE,ORG_REV,
  MATERIAL_GROUP_NAME,BAC_SRC_AZIENDA,MAKTX_S810,
  BCY_REV,MAP_REV,MAP_REV1,ORG_QTY,MAP_QTY,MAP_ZUM,CN_MAP_ZUM,CN_ORG_REV,
  MAP_DIS1,MAP_DIS3,MAP_DIS4,MAP_DIS5,MAP_DIS6,MAP_DIS30,MAP_DIS34,
  POLICY_AMT,AVG_UNIT_COST,BCY_COGS,CN_SALE_COGS,D_POL_CLASS,D_MINILED
  --,D_BUS_SCE_S
  ,D_DIFF_TYPE
  ,INVOICE_CODE
  ,D_OPER_TYPE
  ,SHIPPING_ORDER
  ,STD_QTY
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
WITH PROFIT_CENTER_MAP AS
(
  SELECT DISTINCT COD_AZIENDA,COD_DEST2
    FROM TGK_FIMA_HISENSE.AW_RUL_PTAMAP_000001
   WHERE VALID_FR <= V_YEARMONTH
     AND NVL(VALID_TO,'999999') >= V_YEARMONTH
     AND COD_AZIENDA IN
         (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
),
CUSTOMER_MAP_RAW AS
(
  SELECT NVL(TRIM(CP_COMPANY_CODE_MR),TRIM(CP_COMPANY_CODE)) AS SOURCE_AZIENDA,
         NVL(
           MAX(CASE WHEN CUST_CODE LIKE 'A012__' THEN CUST_CODE END),
           MAX(CUST_CODE)
         ) AS CUST_CODE
    FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_CUST2CTP_MAPPING
   WHERE CUST_TYPE_CODE = 'C'
     AND SYSTEM_SRC = 'S600'
     AND VALID_FR <= V_YEARMONTH
     AND NVL(VALID_TO,'999999') >= V_YEARMONTH
     AND NVL(TRIM(CP_COMPANY_CODE_MR),TRIM(CP_COMPANY_CODE)) IS NOT NULL
   GROUP BY NVL(TRIM(CP_COMPANY_CODE_MR),TRIM(CP_COMPANY_CODE))
),
ADJUST_TYPE AS
(
  SELECT 'REV_01_214' AS D_ADJ_TYPE,-1 AS AMT_SIGN FROM DUAL
  UNION ALL
  SELECT 'REV_01_215' AS D_ADJ_TYPE, 1 AS AMT_SIGN FROM DUAL
)
SELECT
  NEWID() AS OID,
  P_SCENARIO AS COD_SCENARIO,
  P_PERIODO AS COD_PERIODO,
  PT.COD_AZIENDA,
  'GA00_BF' AS COD_CATEGORIA,
  'S600100' AS COD_CONTO,
   CASE WHEN AW.COD_AZIENDA = '1180' THEN '1001200' ELSE CM.CUST_CODE END AS CUST_CODE,
  AW.MATERIAL_CODE,
  AW.MATERIAL_NAME,
  AW.COD_DEST2,
  CASE WHEN ADJ.D_ADJ_TYPE = 'REV_01_214' THEN NULL ELSE AW.D_CHANNEL END AS D_CHANNEL,
  CASE WHEN ADJ.D_ADJ_TYPE = 'REV_01_214' THEN '020_ON_002' ELSE AW.D_ONOFFLINE END AS D_ONOFFLINE,
  AW.SALE_MODEL_CODE,
  AW.MODEL_CODE,
  AW.SHOP_CODE,
  'TA' AS SRC_SYSTEM,
  CASE
    WHEN ADJ.AMT_SIGN = -1 THEN
      CASE WHEN AW.COD_AZIENDA = '1180' THEN '1001200' ELSE CM.CUST_CODE END
    ELSE AW.CUST_CODE
  END AS SOLD_TO_CODE,
  AW.MATERIAL_GROUP_CODE,
  AW.COD_AZIENDA AS COD_AZI_CTP,
  AW.BATCH_ID,
  AW.D_PRC_GRP,
  AW.COD_VALUTA,
  AW.COD_VALUTA_ORIGINARIA,
  'REVM01' AS SRC_DETAIL,
  'CPM_SP_D2M_REV_M' AS PROVENIENZA,
  SESSION_USER AS USERUPD,
  SYSDATE AS DATEUPD,
  ADJ.AMT_SIGN * AW.BILL_QTY AS BILL_QTY,
  ADJ.AMT_SIGN * AW.SHIP_QTY AS SHIP_QTY,
  ADJ.AMT_SIGN * AW.ORDER_QTY AS ORDER_QTY,
  CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.SALE_COGS ELSE -1 * AW.SALE_COGS END AS SALE_REV,
  0 AS SALE_COGS,
  AW.TAX_RATE,
  AW.EXCHANGE_RATE,
  AW.COD_DEST1,
  AW.COD_DEST4,
  AW.D_SPEC_SEC,
  AW.D_PRO_TYPE_S,
  AW.D_PRO_SSER,
  AW.D_QUA_METHOD,
  AW.D_PRO_STAGE,
  AW.D_PRI_RANGE,
  AW.D_PRO_SERIES,
  AW.D_MARKET_PNT,
  AW.D_TECH_TYPE,
  AW.D_PRO_CLASS,
  AW.D_MODEL_LCA,
  AW.D_PRO_TYPE,
  AW.SHOP_NAME,
  AW.SALE_MODEL_NAME,
  AW.MODEL_NAME,
  CASE WHEN ADJ.AMT_SIGN = -1 THEN NULL ELSE AW.D_ECOM_BU END AS D_ECOM_BU,
  AW.D_SALE_DEPT,
  AW.COD_DEST3,
  AW.D_BUS_SCE_S,
  AW.AGENCY_CODE,
  AW.AGENCY_NAME,
  AW.IS_MINILED_CODE,
  AW.CUSTOMER_MODEL,
  AW.ORDER_TYPE_CODE,
  AW.ZCALASSET,
  AW.CN_CLASS_MARK_CODE,
  AW.CN_CLASS_MARK_NAME,
  AW.SALE_CERT_TYPE,
  ADJ.D_ADJ_TYPE,
  CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.SALE_COGS ELSE -1 * AW.SALE_COGS END AS ORG_REV,
  AW.MATERIAL_GROUP_NAME,
  AW.BAC_SRC_AZIENDA,
  AW.MAKTX_S810,
  CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.SALE_COGS ELSE -1 * AW.SALE_COGS END AS BCY_REV,
  CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.SALE_COGS ELSE -1 * AW.SALE_COGS END AS MAP_REV,
  CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.SALE_COGS ELSE -1 * AW.SALE_COGS END AS MAP_REV1,
  ADJ.AMT_SIGN * AW.ORG_QTY AS ORG_QTY,
  ADJ.AMT_SIGN * AW.MAP_QTY AS MAP_QTY,
  ADJ.AMT_SIGN * AW.MAP_ZUM AS MAP_ZUM,
  ADJ.AMT_SIGN * AW.CN_MAP_ZUM AS CN_MAP_ZUM,
  CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.SALE_COGS ELSE -1 * AW.SALE_COGS END AS CN_ORG_REV,
  0 AS MAP_DIS1,
  0 AS MAP_DIS3,
  0 AS MAP_DIS4,
  0 AS MAP_DIS5,
  0 AS MAP_DIS6,
  0 AS MAP_DIS30,
  0 AS MAP_DIS34,
  0 AS POLICY_AMT,
  0 AS AVG_UNIT_COST,
  0 AS BCY_COGS,
  0 AS CN_SALE_COGS,
  AW.D_POL_CLASS,
  AW.D_MINILED
  --,D_BUS_SCE_S
  ,D_DIFF_TYPE
  ,INVOICE_CODE
  ,D_OPER_TYPE
  ,SHIPPING_ORDER
  ,CASE WHEN ADJ.D_ADJ_TYPE = 'REV_01_214' THEN -AW.STD_QTY ELSE AW.STD_QTY END AS STD_QTY
  --20260917FJF_ADD 二期新增字段
  ,AW.D_EFF_CLASS,AW.D_BU_SHOP,AW.D_EC_STORE,AW.D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
JOIN PROFIT_CENTER_MAP PT
  ON PT.COD_DEST2 = AW.COD_DEST2
LEFT JOIN CUSTOMER_MAP_RAW CM
  ON CM.SOURCE_AZIENDA = AW.COD_AZIENDA
CROSS JOIN ADJUST_TYPE ADJ
WHERE 1=1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN
      (SELECT ELEM
         FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID
          AND HIE = '10'
          AND (ELEM = '1180' OR ELEM LIKE '12%'))
  --AND AW.COD_CONTO IN ('S600100','S640100','S600100AD','S640100AD')
  AND (AW.COD_CONTO LIKE 'S6001%' OR AW.COD_CONTO LIKE 'S6401%') --20260825FJF_ADD
  AND AW.D_OPER_TYPE = 'OPTY042' --20260825FJF_ADD
  --AND AW.D_CHANNEL = 'G3'
  AND NVL(AW.D_ADJ_TYPE,'|') NOT IN ('REV_01_214','REV_01_215')
  AND (
        (AW.PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
        OR
        (
          AW.PROVENIENZA = 'CPM_SP_D2M_REV_M'
          AND AW.COD_CONTO LIKE '%AD'
          AND NVL(AW.SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
          AND P_ORG_FLAG = 2
        )
        OR (AW.NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
        OR AW.PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
      )
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-4(O2O-产品公司冲销还原)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*
  REV001_STEP_17-5(品线挂链-产品公司冲销还原)
  REV_01_216：将中国区品线挂链成本转为产品公司收入并冲销
  REV_01_217：按原终端客户及原维度还原产品公司品线挂链收入
  ALTER BY 20260831 shiqingfeng.ex 取消STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 月结不上
  ALTER BY 20260908 SHIQINGFENG.EX 取消注释STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 开始测试
*/
--20260930fjf_add 9月不上线不发版
/*
INSERT \*+ PARALLEL(2) *\ INTO AW_MR9_REVM01_000001_TEMP
(
  OID,COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_CATEGORIA,COD_CONTO,
  CUST_CODE,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,D_CHANNEL,D_ONOFFLINE,
  SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SRC_SYSTEM,SOLD_TO_CODE,
  MATERIAL_GROUP_CODE,COD_AZI_CTP,BATCH_ID,D_PRC_GRP,COD_VALUTA,COD_VALUTA_ORIGINARIA,
  SRC_DETAIL,PROVENIENZA,USERUPD,DATEUPD,
  BILL_QTY,SHIP_QTY,ORDER_QTY,SALE_REV,SALE_COGS,TAX_RATE,EXCHANGE_RATE,
  COD_DEST1,COD_DEST4,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_SSER,D_QUA_METHOD,D_PRO_STAGE,
  D_PRI_RANGE,D_PRO_SERIES,D_MARKET_PNT,D_TECH_TYPE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,
  SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,D_ECOM_BU,D_SALE_DEPT,COD_DEST3,D_BUS_SCE_S,
  AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,CUSTOMER_MODEL,ORDER_TYPE_CODE,ZCALASSET,
  CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,D_ADJ_TYPE,ORG_REV,
  MATERIAL_GROUP_NAME,BAC_SRC_AZIENDA,MAKTX_S810,
  BCY_REV,MAP_REV,MAP_REV1,ORG_QTY,MAP_QTY,MAP_ZUM,CN_MAP_ZUM,CN_ORG_REV,
  MAP_DIS1,MAP_DIS3,MAP_DIS4,MAP_DIS5,MAP_DIS6,MAP_DIS30,MAP_DIS34,
  POLICY_AMT,AVG_UNIT_COST,BCY_COGS,CN_SALE_COGS,D_POL_CLASS,D_MINILED
  --,D_BUS_SCE_S
  ,D_DIFF_TYPE
  ,INVOICE_CODE
  ,D_OPER_TYPE
  ,SHIPPING_ORDER
  ,STD_QTY
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
WITH PROFIT_CENTER_MAP AS
(
  SELECT DISTINCT COD_AZIENDA,COD_DEST2
    FROM TGK_FIMA_HISENSE.AW_RUL_PTAMAP_000001
   WHERE VALID_FR <= V_YEARMONTH
     AND NVL(VALID_TO,'999999') >= V_YEARMONTH
     AND COD_AZIENDA IN
         (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
),
CUSTOMER_MAP_RAW AS
(
  SELECT NVL(TRIM(CP_COMPANY_CODE_MR),TRIM(CP_COMPANY_CODE)) AS SOURCE_AZIENDA,
         NVL(
           MAX(CASE WHEN CUST_CODE LIKE 'A012__' THEN CUST_CODE END),
           MAX(CUST_CODE)
         ) AS CUST_CODE
    FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_CUST2CTP_MAPPING
   WHERE CUST_TYPE_CODE = 'C'
     AND SYSTEM_SRC = 'S600'
     AND VALID_FR <= V_YEARMONTH
     AND NVL(VALID_TO,'999999') >= V_YEARMONTH
     AND NVL(TRIM(CP_COMPANY_CODE_MR),TRIM(CP_COMPANY_CODE)) IS NOT NULL
   GROUP BY NVL(TRIM(CP_COMPANY_CODE_MR),TRIM(CP_COMPANY_CODE))
),
ADJUST_TYPE AS
(
  SELECT 'REV_01_216' AS D_ADJ_TYPE,-1 AS AMT_SIGN FROM DUAL
  UNION ALL
  SELECT 'REV_01_217' AS D_ADJ_TYPE, 1 AS AMT_SIGN FROM DUAL
)
SELECT
  NEWID() AS OID,
  P_SCENARIO AS COD_SCENARIO,
  P_PERIODO AS COD_PERIODO,
  PT.COD_AZIENDA,
  'GA00_BF' AS COD_CATEGORIA,
  'S600100' AS COD_CONTO,
  CASE
    WHEN ADJ.AMT_SIGN = -1 THEN
      CASE WHEN AW.COD_AZIENDA = '1180' THEN '1001200' ELSE CM.CUST_CODE END
    ELSE AW.CUST_CODE
  END AS CUST_CODE,
  AW.MATERIAL_CODE,
  AW.MATERIAL_NAME,
  AW.COD_DEST2,
  --AW.D_CHANNEL, --20260826FJF_ADD
  CASE WHEN ADJ.AMT_SIGN = 1 THEN AW.D_CHANNEL ELSE '' END AS D_CHANNEL,
  AW.D_ONOFFLINE,
  AW.SALE_MODEL_CODE,
  AW.MODEL_CODE,
  AW.SHOP_CODE,
  'TA' AS SRC_SYSTEM,
  CASE
    WHEN ADJ.AMT_SIGN = -1 THEN
      CASE WHEN AW.COD_AZIENDA = '1180' THEN '1001200' ELSE CM.CUST_CODE END
    ELSE AW.CUST_CODE
  END AS SOLD_TO_CODE,
  AW.MATERIAL_GROUP_CODE,
  CASE
    WHEN ADJ.AMT_SIGN = -1 THEN AW.COD_AZIENDA
    ELSE AW.COD_AZI_CTP
  END AS COD_AZI_CTP,
  AW.BATCH_ID,
  AW.D_PRC_GRP,
  AW.COD_VALUTA,
  AW.COD_VALUTA_ORIGINARIA,
  'REVM01' AS SRC_DETAIL,
  'CPM_SP_D2M_REV_M' AS PROVENIENZA,
  SESSION_USER AS USERUPD,
  SYSDATE AS DATEUPD,
  ADJ.AMT_SIGN * AW.BILL_QTY AS BILL_QTY,
  ADJ.AMT_SIGN * AW.SHIP_QTY AS SHIP_QTY,
  ADJ.AMT_SIGN * AW.ORDER_QTY AS ORDER_QTY,
  --20260928fjf_add REV001_STEP_17-5（品线挂链-产品公司冲销还原）修改冲销、还原收入取值逻辑
  --CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.ORG_REV ELSE -1 * AW.ORG_REV END AS SALE_REV,
  --20260929lc_add REV001_STEP_17-5（品线挂链-产品公司冲销还原）修改冲销、还原收入取值逻辑还原，本月不上线
  CASE WHEN ADJ.AMT_SIGN = -1 THEN -1 * AW.ORG_REV ELSE AW.ORG_REV END AS SALE_REV,
  0 AS SALE_COGS,
  AW.TAX_RATE,
  AW.EXCHANGE_RATE,
  AW.COD_DEST1,
  AW.COD_DEST4,
  AW.D_SPEC_SEC,
  AW.D_PRO_TYPE_S,
  AW.D_PRO_SSER,
  AW.D_QUA_METHOD,
  AW.D_PRO_STAGE,
  AW.D_PRI_RANGE,
  AW.D_PRO_SERIES,
  AW.D_MARKET_PNT,
  AW.D_TECH_TYPE,
  AW.D_PRO_CLASS,
  AW.D_MODEL_LCA,
  AW.D_PRO_TYPE,
  AW.SHOP_NAME,
  AW.SALE_MODEL_NAME,
  AW.MODEL_NAME,
  --20260928fjf_add REV001_STEP_17-5（品线挂链-产品公司冲销还原）修改冲销、还原收入取值逻辑
  CASE WHEN ADJ.AMT_SIGN = -1 THEN NULL ELSE AW.D_ECOM_BU END AS D_ECOM_BU,
  AW.D_SALE_DEPT,
  AW.COD_DEST3,
  AW.D_BUS_SCE_S,
  AW.AGENCY_CODE,
  AW.AGENCY_NAME,
  AW.IS_MINILED_CODE,
  AW.CUSTOMER_MODEL,
  AW.ORDER_TYPE_CODE,
  AW.ZCALASSET,
  AW.CN_CLASS_MARK_CODE,
  AW.CN_CLASS_MARK_NAME,
  AW.SALE_CERT_TYPE,
  ADJ.D_ADJ_TYPE,
  --CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.ORG_REV ELSE -1 * AW.ORG_REV END AS ORG_REV,
  --20260929lc_add REV001_STEP_17-5（品线挂链-产品公司冲销还原）修改冲销、还原收入取值逻辑还原，本月不上线
  CASE WHEN ADJ.AMT_SIGN = -1 THEN -1 * AW.ORG_REV ELSE AW.ORG_REV END AS ORG_REV,
  AW.MATERIAL_GROUP_NAME,
  AW.BAC_SRC_AZIENDA,
  AW.MAKTX_S810,
  --20260928fjf_add REV001_STEP_17-5（品线挂链-产品公司冲销还原）修改冲销、还原收入取值逻辑
  --CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.ORG_REV ELSE -1 * AW.ORG_REV END AS BCY_REV,
  --CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.ORG_REV ELSE -1 * AW.ORG_REV END AS MAP_REV,
  --CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.ORG_REV ELSE -1 * AW.ORG_REV END AS MAP_REV1,
  --20260929lc_add REV001_STEP_17-5（品线挂链-产品公司冲销还原）修改冲销、还原收入取值逻辑还原，本月不上线
  CASE WHEN ADJ.AMT_SIGN = -1 THEN -1 * AW.ORG_REV ELSE AW.ORG_REV END AS BCY_REV,
  CASE WHEN ADJ.AMT_SIGN = -1 THEN -1 * AW.ORG_REV ELSE AW.ORG_REV END AS MAP_REV,
  CASE WHEN ADJ.AMT_SIGN = -1 THEN -1 * AW.ORG_REV ELSE AW.ORG_REV END AS MAP_REV1,
  ADJ.AMT_SIGN * AW.ORG_QTY AS ORG_QTY,
  ADJ.AMT_SIGN * AW.MAP_QTY AS MAP_QTY,
  ADJ.AMT_SIGN * AW.MAP_ZUM AS MAP_ZUM,

  --20260915FJF_ADD REV001_STEP_17-5（品线挂链-产品公司冲销还原）中国区销量字段、中国区收入字段放空
  --ADJ.AMT_SIGN * AW.CN_MAP_ZUM AS CN_MAP_ZUM,
  --CASE WHEN ADJ.AMT_SIGN = -1 THEN AW.SALE_COGS ELSE -1 * AW.SALE_COGS END AS CN_ORG_REV,
  0 AS CN_MAP_ZUM,
  0 AS CN_ORG_REV,
  0 AS MAP_DIS1,
  0 AS MAP_DIS3,
  0 AS MAP_DIS4,
  0 AS MAP_DIS5,
  0 AS MAP_DIS6,
  0 AS MAP_DIS30,
  0 AS MAP_DIS34,
  0 AS POLICY_AMT,
  0 AS AVG_UNIT_COST,
  0 AS BCY_COGS,
  0 AS CN_SALE_COGS,
  AW.D_POL_CLASS,
  AW.D_MINILED
  --,D_BUS_SCE_S
  -- 20260918 CD 修改为默认值
  ,'150102006' D_DIFF_TYPE
  --,D_DIFF_TYPE
  ,INVOICE_CODE
  ,D_OPER_TYPE
  ,SHIPPING_ORDER
  ,CASE WHEN ADJ.D_ADJ_TYPE = 'REV_01_216' THEN -AW.STD_QTY ELSE AW.STD_QTY END AS STD_QTY
  --20260917FJF_ADD 二期新增字段
  ,AW.D_EFF_CLASS,AW.D_BU_SHOP,AW.D_EC_STORE,AW.D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
JOIN PROFIT_CENTER_MAP PT
  ON PT.COD_DEST2 = AW.COD_DEST2
LEFT JOIN CUSTOMER_MAP_RAW CM
  ON CM.SOURCE_AZIENDA = AW.COD_AZIENDA
CROSS JOIN ADJUST_TYPE ADJ
WHERE 1=1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN
      (SELECT ELEM
         FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID
          AND HIE = '10'
          AND (ELEM = '1180' OR ELEM LIKE '12%'))
  --AND AW.COD_CONTO IN ('S600100','S640100','S600100AD','S640100AD')
  AND (AW.COD_CONTO LIKE 'S6001%' OR AW.COD_CONTO LIKE 'S6401%')--20260825FJF_ADD
  AND AW.D_OPER_TYPE = 'OPTY025'
  AND NVL(AW.D_ADJ_TYPE,'|') NOT IN ('REV_01_216','REV_01_217','REV_01_218')
  AND (
        (AW.PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
        OR
        (
          AW.PROVENIENZA = 'CPM_SP_D2M_REV_M'
          AND AW.COD_CONTO LIKE '%AD'
          AND NVL(AW.SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
          AND P_ORG_FLAG = 2
        )
        OR (AW.NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
        OR AW.PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
      )
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-5(品线挂链-产品公司冲销还原)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT; */


/*REV001_STEP_17-6(品线挂链-中国区冲销)
  REV_01_218：将中国区品线挂链数据按原科目、原维度全量冲销
  ALTER BY 20260831 shiqingfeng.ex 取消STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 月结不上
  ALTER BY 20260908 SHIQINGFENG.EX 取消注释STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 开始测试
*/

--20260930fjf_add 9月不上线不发版
/*
INSERT \*+ PARALLEL(2) *\ INTO AW_MR9_REVM01_000001_TEMP
(
  OID,COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_CATEGORIA,COD_CONTO,
  CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,D_CHANNEL,D_MODE,D_ONOFFLINE,
  SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SRC_SYSTEM,SOLD_TO_CODE,SOLD_TO_NAME,
  MATERIAL_GROUP_CODE,COD_AZI_CTP,BATCH_ID,D_PRC_GRP,COD_VALUTA,COD_VALUTA_ORIGINARIA,
  SRC_DETAIL,PROVENIENZA,USERUPD,DATEUPD,
  BILL_QTY,SHIP_QTY,ORDER_QTY,SALE_REV,SALE_COGS,TAX_RATE,EXCHANGE_RATE,
  COD_DEST1,COD_DEST4,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_SSER,D_QUA_METHOD,D_PRO_STAGE,
  D_PRI_RANGE,D_PRO_SERIES,D_MARKET_PNT,D_TECH_TYPE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,
  CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,
  SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,D_CNL_C_TYPE,D_IND_C_TYPE,D_ECOM_BU,
  D_SALE_DEPT,COD_DEST3,D_BUS_SCE_S,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,
  CUSTOMER_MODEL,ORDER_TYPE_CODE,ZCALASSET,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,
  SALE_CERT_TYPE,D_ADJ_TYPE,ORG_REV,MATERIAL_GROUP_NAME,BAC_SRC_AZIENDA,MAKTX_S810,
  BCY_REV,MAP_REV,MAP_REV1,ORG_QTY,MAP_QTY,MAP_ZUM,CN_MAP_ZUM,CN_ORG_REV,
  MAP_DIS1,MAP_DIS3,MAP_DIS4,MAP_DIS5,MAP_DIS6,MAP_DIS30,MAP_DIS34,
  POLICY_AMT,AVG_UNIT_COST,BCY_COGS,CN_SALE_COGS,D_POL_CLASS,D_MINILED,D_OPER_TYPE,NOTE
   --,D_BUS_SCE_S
   ,D_DIFF_TYPE
   ,INVOICE_CODE
   --,D_OPER_TYPE
   ,SHIPPING_ORDER
   ,STD_QTY
   ,DISCOUNT_1
   ,DISCOUNT_3
   ,DISCOUNT_4
   ,DISCOUNT_5
   ,DISCOUNT_6
   ,DISCOUNT_30
   ,DISCOUNT_34
    --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
SELECT
  NEWID() AS OID,
  P_SCENARIO AS COD_SCENARIO,
  P_PERIODO AS COD_PERIODO,
  AW.COD_AZIENDA,
  'GA00_BF' AS COD_CATEGORIA,
  AW.COD_CONTO,
  AW.CUST_CODE,
  AW.CUST_NAME,
  AW.MATERIAL_CODE,
  AW.MATERIAL_NAME,
  AW.COD_DEST2,
  AW.D_CHANNEL,
  AW.D_MODE,
  AW.D_ONOFFLINE,
  AW.SALE_MODEL_CODE,
  AW.MODEL_CODE,
  AW.SHOP_CODE,
  'TA' AS SRC_SYSTEM,
  AW.SOLD_TO_CODE,
  AW.SOLD_TO_NAME,
  AW.MATERIAL_GROUP_CODE,
  AW.COD_AZI_CTP,
  AW.BATCH_ID,
  AW.D_PRC_GRP,
  AW.COD_VALUTA,
  AW.COD_VALUTA_ORIGINARIA,
  'REVM01' AS SRC_DETAIL,
  'CPM_SP_D2M_REV_M' AS PROVENIENZA,
  SESSION_USER AS USERUPD,
  SYSDATE AS DATEUPD,
  -1 * AW.BILL_QTY AS BILL_QTY,
  -1 * AW.SHIP_QTY AS SHIP_QTY,
  -1 * AW.ORDER_QTY AS ORDER_QTY,
  -1 * AW.SALE_COGS AS SALE_REV,
  -1 * AW.SALE_COGS AS SALE_COGS,
  AW.TAX_RATE,
  AW.EXCHANGE_RATE,
  AW.COD_DEST1,
  AW.COD_DEST4,
  AW.D_SPEC_SEC,
  AW.D_PRO_TYPE_S,
  AW.D_PRO_SSER,
  AW.D_QUA_METHOD,
  AW.D_PRO_STAGE,
  AW.D_PRI_RANGE,
  AW.D_PRO_SERIES,
  AW.D_MARKET_PNT,
  AW.D_TECH_TYPE,
  AW.D_PRO_CLASS,
  AW.D_MODEL_LCA,
  AW.D_PRO_TYPE,
  AW.CUST_UNITY_NAME,
  AW.CREDIT_LEVEL_NAME,
  AW.CUST_NATURE_NAME,
  AW.CUST_TYPE_NAME,
  AW.SHOP_NAME,
  AW.SALE_MODEL_NAME,
  AW.MODEL_NAME,
  AW.D_CNL_C_TYPE,
  AW.D_IND_C_TYPE,
  AW.D_ECOM_BU,
  AW.D_SALE_DEPT,
  AW.COD_DEST3,
  AW.D_BUS_SCE_S,
  AW.AGENCY_CODE,
  AW.AGENCY_NAME,
  AW.IS_MINILED_CODE,
  AW.CUSTOMER_MODEL,
  AW.ORDER_TYPE_CODE,
  AW.ZCALASSET,
  AW.CN_CLASS_MARK_CODE,
  AW.CN_CLASS_MARK_NAME,
  AW.SALE_CERT_TYPE,
  'REV_01_218' AS D_ADJ_TYPE,
  -1 * AW.ORG_REV AS ORG_REV,
  AW.MATERIAL_GROUP_NAME,
  AW.BAC_SRC_AZIENDA,
  AW.MAKTX_S810,
  -1 * AW.BCY_REV AS BCY_REV,
  -1 * AW.MAP_REV AS MAP_REV,
  -1 * AW.MAP_REV1 AS MAP_REV1,
  -1 * AW.ORG_QTY AS ORG_QTY,
  -1 * AW.MAP_QTY AS MAP_QTY,
  -1 * AW.MAP_ZUM AS MAP_ZUM,
  -1 * AW.CN_MAP_ZUM AS CN_MAP_ZUM,
  -1 * AW.CN_ORG_REV AS CN_ORG_REV,
  -1 * AW.MAP_DIS1 AS MAP_DIS1,
  -1 * AW.MAP_DIS3 AS MAP_DIS3,
  -1 * AW.MAP_DIS4 AS MAP_DIS4,
  -1 * AW.MAP_DIS5 AS MAP_DIS5,
  -1 * AW.MAP_DIS6 AS MAP_DIS6,
  -1 * AW.MAP_DIS30 AS MAP_DIS30,
  -1 * AW.MAP_DIS34 AS MAP_DIS34,
  -1 * AW.POLICY_AMT AS POLICY_AMT,
  -1 * AW.AVG_UNIT_COST AS AVG_UNIT_COST,
  -1 * AW.BCY_COGS AS BCY_COGS,
  -1 * AW.CN_SALE_COGS AS CN_SALE_COGS,
  AW.D_POL_CLASS,
  AW.D_MINILED,
  AW.D_OPER_TYPE,
  AW.NOTE
   --,D_BUS_SCE_S
   -- 20260918 CD 修改为默认值
   ,'150102006' D_DIFF_TYPE
   --,D_DIFF_TYPE
   ,INVOICE_CODE
   --,D_OPER_TYPE
   ,SHIPPING_ORDER
   ,0-STD_QTY
   ,0-DISCOUNT_1
   ,0-DISCOUNT_3
   ,0-DISCOUNT_4
   ,0-DISCOUNT_5
   ,0-DISCOUNT_6
   ,0-DISCOUNT_30
   ,0-DISCOUNT_34
   --20260917FJF_ADD 二期新增字段
  ,AW.D_EFF_CLASS,AW.D_BU_SHOP,AW.D_EC_STORE,AW.D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
WHERE 1=1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN
      (SELECT ELEM
         FROM SESSION_AZIENDA_LIST
        WHERE SESSION_ID = V_SESSION_ID
          AND (ELEM = '1180' OR ELEM LIKE '12%'))
  AND AW.COD_CONTO IN ('S600100','S640100','S600100AD','S640100AD')
  AND AW.D_OPER_TYPE = 'OPTY025'
  AND NVL(AW.D_ADJ_TYPE,'|') <> 'REV_01_218'
  AND (
        (AW.PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
        OR
        (
          AW.PROVENIENZA = 'CPM_SP_D2M_REV_M'
          AND AW.COD_CONTO LIKE '%AD'
          AND NVL(AW.SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
          AND P_ORG_FLAG = 2
        )
        OR (AW.NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
        OR AW.PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
      )
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-6(品线挂链-中国区冲销)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT; */


/*REV001_STEP_17-7(费用转政策-中国区冲销)
  REV_01_219：将中国区费用转政策对应的主营业务成本冲销
  ALTER BY 20260831 shiqingfeng.ex 取消STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 月结不上
ALTER BY 20260908 SHIQINGFENG.EX 取消注释STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 开始测试
*/
INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP
(
  OID,COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_CATEGORIA,COD_CONTO,
  CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,D_CHANNEL,D_MODE,D_ONOFFLINE,
  SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SRC_SYSTEM,SOLD_TO_CODE,SOLD_TO_NAME,
  MATERIAL_GROUP_CODE,COD_AZI_CTP,BATCH_ID,D_PRC_GRP,COD_VALUTA,COD_VALUTA_ORIGINARIA,
  SRC_DETAIL,PROVENIENZA,USERUPD,DATEUPD,
  BILL_QTY,SHIP_QTY,ORDER_QTY,SALE_REV,SALE_COGS,TAX_RATE,EXCHANGE_RATE,
  COD_DEST1,COD_DEST4,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_SSER,D_QUA_METHOD,D_PRO_STAGE,
  D_PRI_RANGE,D_PRO_SERIES,D_MARKET_PNT,D_TECH_TYPE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,
  CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,
  SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,D_CNL_C_TYPE,D_IND_C_TYPE,D_ECOM_BU,
  D_SALE_DEPT,COD_DEST3,D_BUS_SCE_S,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,
  CUSTOMER_MODEL,ORDER_TYPE_CODE,ZCALASSET,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,
  SALE_CERT_TYPE,D_ADJ_TYPE,ORG_REV,MATERIAL_GROUP_NAME,BAC_SRC_AZIENDA,MAKTX_S810,
  BCY_REV,MAP_REV,MAP_REV1,ORG_QTY,MAP_QTY,MAP_ZUM,CN_MAP_ZUM,CN_ORG_REV,
  MAP_DIS1,MAP_DIS3,MAP_DIS4,MAP_DIS5,MAP_DIS6,MAP_DIS30,MAP_DIS34,
  POLICY_AMT,AVG_UNIT_COST,BCY_COGS,CN_SALE_COGS,D_POL_CLASS,D_MINILED,D_OPER_TYPE,NOTE
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
SELECT
  NEWID() AS OID,
  P_SCENARIO AS COD_SCENARIO,
  P_PERIODO AS COD_PERIODO,
  AW.COD_AZIENDA,
  'GA00_BF' AS COD_CATEGORIA,
  AW.COD_CONTO,
  AW.CUST_CODE,
  AW.CUST_NAME,
  AW.MATERIAL_CODE,
  AW.MATERIAL_NAME,
  AW.COD_DEST2,
  AW.D_CHANNEL,
  AW.D_MODE,
  AW.D_ONOFFLINE,
  AW.SALE_MODEL_CODE,
  AW.MODEL_CODE,
  AW.SHOP_CODE,
  'TA' AS SRC_SYSTEM,
  AW.SOLD_TO_CODE,
  AW.SOLD_TO_NAME,
  AW.MATERIAL_GROUP_CODE,
  AW.COD_AZI_CTP,
  AW.BATCH_ID,
  AW.D_PRC_GRP,
  AW.COD_VALUTA,
  AW.COD_VALUTA_ORIGINARIA,
  'REVM01' AS SRC_DETAIL,
  'CPM_SP_D2M_REV_M' AS PROVENIENZA,
  SESSION_USER AS USERUPD,
  SYSDATE AS DATEUPD,
  AW.BILL_QTY,
  AW.SHIP_QTY,
  AW.ORDER_QTY,
  0 AS SALE_REV,
  -1 * AW.SALE_COGS AS SALE_COGS,
  AW.TAX_RATE,
  AW.EXCHANGE_RATE,
  AW.COD_DEST1,
  AW.COD_DEST4,
  AW.D_SPEC_SEC,
  AW.D_PRO_TYPE_S,
  AW.D_PRO_SSER,
  AW.D_QUA_METHOD,
  AW.D_PRO_STAGE,
  AW.D_PRI_RANGE,
  AW.D_PRO_SERIES,
  AW.D_MARKET_PNT,
  AW.D_TECH_TYPE,
  AW.D_PRO_CLASS,
  AW.D_MODEL_LCA,
  AW.D_PRO_TYPE,
  AW.CUST_UNITY_NAME,
  AW.CREDIT_LEVEL_NAME,
  AW.CUST_NATURE_NAME,
  AW.CUST_TYPE_NAME,
  AW.SHOP_NAME,
  AW.SALE_MODEL_NAME,
  AW.MODEL_NAME,
  AW.D_CNL_C_TYPE,
  AW.D_IND_C_TYPE,
  AW.D_ECOM_BU,
  AW.D_SALE_DEPT,
  AW.COD_DEST3,
  AW.D_BUS_SCE_S,
  AW.AGENCY_CODE,
  AW.AGENCY_NAME,
  AW.IS_MINILED_CODE,
  AW.CUSTOMER_MODEL,
  AW.ORDER_TYPE_CODE,
  AW.ZCALASSET,
  AW.CN_CLASS_MARK_CODE,
  AW.CN_CLASS_MARK_NAME,
  AW.SALE_CERT_TYPE,
  'REV_01_219' AS D_ADJ_TYPE,
  AW.ORG_REV,
  AW.MATERIAL_GROUP_NAME,
  AW.BAC_SRC_AZIENDA,
  AW.MAKTX_S810,
  AW.BCY_REV,
  AW.MAP_REV,
  AW.MAP_REV1,
  AW.ORG_QTY,
  AW.MAP_QTY,
  AW.MAP_ZUM,
  AW.CN_MAP_ZUM,
  AW.CN_ORG_REV,
  AW.MAP_DIS1,
  AW.MAP_DIS3,
  AW.MAP_DIS4,
  AW.MAP_DIS5,
  AW.MAP_DIS6,
  AW.MAP_DIS30,
  AW.MAP_DIS34,
  AW.POLICY_AMT,
  AW.AVG_UNIT_COST,
  AW.BCY_COGS,
  AW.CN_SALE_COGS,
  AW.D_POL_CLASS,
  AW.D_MINILED,
  AW.D_OPER_TYPE,
  AW.NOTE
  --20260917FJF_ADD 二期新增字段
  ,AW.D_EFF_CLASS,AW.D_BU_SHOP,AW.D_EC_STORE,AW.D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
WHERE 1=1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN
      (SELECT ELEM
         FROM SESSION_AZIENDA_LIST
        WHERE SESSION_ID = V_SESSION_ID
          AND (ELEM = '1180' OR ELEM LIKE '12%'))
  AND AW.COD_CONTO = 'S640100'
  AND AW.D_OPER_TYPE IN ('OPTY039','OPTY040')
  AND NVL(AW.D_ADJ_TYPE,'|') <> 'REV_01_219'
  AND (
        (AW.PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
        OR
        (
          AW.PROVENIENZA = 'CPM_SP_D2M_REV_M'
          AND AW.COD_CONTO LIKE '%AD'
          AND NVL(AW.SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
          AND P_ORG_FLAG = 2
        )
        OR (AW.NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
        OR AW.PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
      )
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-7(费用转政策-中国区冲销)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*REV001_STEP_17-8(费用转政策-中国区分摊)
  REV_01_220：中国区费用转政策按管理口径收入分摊到具体型号
  TM0101/TM0102在中国区公司间分摊，其他渠道仅在本账套内分摊
  ALTER BY 20260824-1 SHIQINGFENG.EX  REV001_STEP_17-8费用转政策-中国区分摊：原因子无法分摊时，回退至所有有效电商BU渠道分摊，并排除REV_01_219冲销行
  ALTER BY 20260831 shiqingfeng.ex 取消STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 月结不上
  ALTER BY 20260908 SHIQINGFENG.EX 取消注释STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 开始测试
*/
INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP
(
  OID,COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_CATEGORIA,COD_CONTO,
  CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,D_CHANNEL,D_MODE,D_ONOFFLINE,
  SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SRC_SYSTEM,SOLD_TO_CODE,SOLD_TO_NAME,
  MATERIAL_GROUP_CODE,COD_AZI_CTP,BATCH_ID,D_PRC_GRP,COD_VALUTA,COD_VALUTA_ORIGINARIA,
  SRC_DETAIL,PROVENIENZA,USERUPD,DATEUPD,
  BILL_QTY,SHIP_QTY,ORDER_QTY,SALE_REV,SALE_COGS,TAX_RATE,EXCHANGE_RATE,
  COD_DEST1,COD_DEST4,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_SSER,D_QUA_METHOD,D_PRO_STAGE,
  D_PRI_RANGE,D_PRO_SERIES,D_MARKET_PNT,D_TECH_TYPE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,
  CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,
  SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,D_CNL_C_TYPE,D_IND_C_TYPE,D_ECOM_BU,
  D_SALE_DEPT,COD_DEST3,D_BUS_SCE_S,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,
  CUSTOMER_MODEL,ORDER_TYPE_CODE,ZCALASSET,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,
  SALE_CERT_TYPE,D_ADJ_TYPE,ORG_REV,MATERIAL_GROUP_NAME,BAC_SRC_AZIENDA,MAKTX_S810,
  BCY_REV,MAP_REV,MAP_REV1,ORG_QTY,MAP_QTY,MAP_ZUM,CN_MAP_ZUM,CN_ORG_REV,
  MAP_DIS1,MAP_DIS3,MAP_DIS4,MAP_DIS5,MAP_DIS6,MAP_DIS30,MAP_DIS34,
  POLICY_AMT,AVG_UNIT_COST,BCY_COGS,CN_SALE_COGS,D_POL_CLASS,D_MINILED,D_OPER_TYPE,NOTE
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
WITH ALLOC_SOURCE AS
(
  SELECT
    CASE WHEN AW.D_ECOM_BU IN ('TM0101','TM0102')
         THEN 'ALL_CN' ELSE AW.COD_AZIENDA END AS MATCH_AZIENDA,
    --ALTER BY 20260917 13.49 SHIQINGFENG.EX 20260917 补充逻辑说明：空调通过按照产品大类(product_big_class_code)为P02（这是产品类别【D_PRO_CLASS】字段的层级）来判断，（不是通过有业务管理单元按照业务管理单元分摊，没业务管理单元按照利润中心的规则进行）并排除为金额为0
    CASE WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%'
              AND PRO.COD IS NOT NULL
           THEN COALESCE(NULLIF(TRIM(AW.D_SALE_DEPT),'ZZZZ'),AW.COD_DEST2)
         ELSE AW.COD_DEST2
    END AS PRODUCT_KEY,
    --COALESCE(NULLIF(TRIM(AW.D_SALE_DEPT),'ZZZZ'),AW.COD_DEST2) AS PRODUCT_KEY,
    NVL(AW.D_ECOM_BU,'ZZZZ') AS D_ECOM_BU_KEY,
    NVL(AW.CN_CLASS_MARK_CODE,'ZZZZ') AS CN_CLASS_MARK_KEY,
    AW.COD_CONTO,
    AW.D_OPER_TYPE,
    SUM(NVL(AW.SALE_COGS,0)) AS ALLOC_AMT
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
  FROM AW_MR9_REVM01_000001_TEMP AW
  LEFT JOIN (SELECT COD,COD_ELEGER FROM ED_D_PRO_CLASS_GERARCHIA_ABBI WHERE COD_GERARCHIA = '01' AND COD_ELEGER = 'P02') PRO
    ON PRO.COD = AW.D_PRO_CLASS
  WHERE 1=1
    AND AW.COD_SCENARIO = P_SCENARIO
    AND AW.COD_PERIODO = P_PERIODO
    AND AW.COD_AZIENDA IN
        (SELECT ELEM
           FROM SESSION_AZIENDA_LIST
          WHERE SESSION_ID = V_SESSION_ID
            AND (ELEM = '1180' OR ELEM LIKE '12%'))
    AND AW.COD_CONTO = 'S640100'
    AND AW.D_OPER_TYPE IN ('OPTY039','OPTY040')
    -- 排除STEP_17-7冲销及本步骤已分摊数据，避免源金额被冲销为0或重复分摊
    AND NVL(AW.D_ADJ_TYPE,'|') NOT IN ('REV_01_219','REV_01_220')
    AND (
          (AW.PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            AW.PROVENIENZA = 'CPM_SP_D2M_REV_M'
            AND AW.COD_CONTO LIKE '%AD'
            AND NVL(AW.SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
            AND P_ORG_FLAG = 2
          )
          OR (AW.NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
          OR AW.PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )
  GROUP BY
    CASE WHEN AW.D_ECOM_BU IN ('TM0101','TM0102')
         THEN 'ALL_CN' ELSE AW.COD_AZIENDA END,
    CASE WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%'
              AND PRO.COD IS NOT NULL
           THEN COALESCE(NULLIF(TRIM(AW.D_SALE_DEPT),'ZZZZ'),AW.COD_DEST2)
         ELSE AW.COD_DEST2
    END,
    NVL(AW.D_ECOM_BU,'ZZZZ'),
    NVL(AW.CN_CLASS_MARK_CODE,'ZZZZ'),
    AW.COD_CONTO,
    AW.D_OPER_TYPE
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
  HAVING SUM(NVL(AW.SALE_COGS,0)) <> 0
),
FACTOR_BASE AS
(
  SELECT
    AW.*,
    CASE WHEN AW.D_ECOM_BU IN ('TM0101','TM0102')
         THEN 'ALL_CN' ELSE AW.COD_AZIENDA END AS MATCH_AZIENDA,
    --ALTER BY 20260917 13.49 SHIQINGFENG.EX 20260917 补充逻辑说明：空调通过按照产品大类(product_big_class_code)为P02（这是产品类别【D_PRO_CLASS】字段的层级）来判断，（不是通过有业务管理单元按照业务管理单元分摊，没业务管理单元按照利润中心的规则进行）并排除为金额为0
    CASE WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%'
              AND (SELECT COD_ELEGER FROM ED_D_PRO_CLASS_GERARCHIA_ABBI WHERE COD_GERARCHIA = '01' AND COD = AW.D_PRO_CLASS) IN ('P02')
           THEN COALESCE(NULLIF(TRIM(AW.D_SALE_DEPT),'ZZZZ'),AW.COD_DEST2)
         ELSE AW.COD_DEST2
    END AS PRODUCT_KEY,
    --COALESCE(NULLIF(TRIM(AW.D_SALE_DEPT),'ZZZZ'),AW.COD_DEST2) AS PRODUCT_KEY,
    NVL(AW.D_ECOM_BU,'ZZZZ') AS D_ECOM_BU_KEY,
    NVL(AW.CN_CLASS_MARK_CODE,'ZZZZ') AS CN_CLASS_MARK_KEY,
    -1 * (
           NVL(AW.ORG_REV,0)
           - NVL(AW.POLICY_AMT,0)
           - (
               NVL(AW.MAP_DIS1,0)
               + NVL(AW.MAP_DIS3,0)
               + NVL(AW.MAP_DIS4,0)
               + NVL(AW.MAP_DIS30,0)
               + NVL(AW.MAP_DIS34,0)
             )
         ) AS FACTOR_AMT
  FROM AW_MR9_REVM01_000001_TEMP AW
  WHERE 1=1
    AND AW.COD_SCENARIO = P_SCENARIO
    AND AW.COD_PERIODO = P_PERIODO
    AND AW.COD_AZIENDA IN
        (SELECT ELEM
           FROM SESSION_AZIENDA_LIST
          WHERE SESSION_ID = V_SESSION_ID
            AND (ELEM = '1180' OR ELEM LIKE '12%'))
    AND AW.SRC_DETAIL = 'VBRP'
    --EDIT BY LC 260924 渠道分组限制为线上020-ON
    AND AW.D_ONOFFLINE IN (SELECT COD FROM V_ED_D_ONOFFLINE_FLAT WHERE COD_ELEGER5 = '020_ON')
    AND AW.PROVENIENZA = 'CPM_SP_D2M_REV_M'
),
FACTOR_DETAIL AS
(
  SELECT
    FB.*,

    SUM(FB.FACTOR_AMT) OVER
    (
      PARTITION BY FB.MATCH_AZIENDA,FB.PRODUCT_KEY,
                   FB.D_ECOM_BU_KEY,FB.CN_CLASS_MARK_KEY
    ) AS TOTAL_FACTOR_AMT
  FROM FACTOR_BASE FB
  WHERE FB.FACTOR_AMT <> 0
),
/*原四维因子可以分摊的源组，仅进入主分摊*/
PRIMARY_FACTOR AS
(
  SELECT
    F.*,
    NULL AS FALLBACK_SCOPE,
    A.MATCH_AZIENDA AS SOURCE_MATCH_AZIENDA,
    A.PRODUCT_KEY AS SOURCE_PRODUCT_KEY,
    A.D_ECOM_BU_KEY AS SOURCE_D_ECOM_BU_KEY,
    A.CN_CLASS_MARK_KEY AS SOURCE_CN_CLASS_MARK_KEY,
    A.COD_CONTO AS SOURCE_COD_CONTO,
    A.D_OPER_TYPE AS SOURCE_D_OPER_TYPE
  FROM ALLOC_SOURCE A
  JOIN FACTOR_DETAIL F
    ON F.MATCH_AZIENDA = A.MATCH_AZIENDA
   AND F.PRODUCT_KEY = A.PRODUCT_KEY
   AND F.D_ECOM_BU_KEY = A.D_ECOM_BU_KEY
   AND F.CN_CLASS_MARK_KEY = A.CN_CLASS_MARK_KEY
  WHERE NVL(F.TOTAL_FACTOR_AMT,0) <> 0
),
/*无四维匹配、因子全为0或分母为0的源组进入回退分摊*/
FAILED_SOURCE AS
(
  SELECT A.*
  FROM ALLOC_SOURCE A
  WHERE NOT EXISTS
        (
          SELECT 1
          FROM FACTOR_DETAIL F
          WHERE F.MATCH_AZIENDA = A.MATCH_AZIENDA
            AND F.PRODUCT_KEY = A.PRODUCT_KEY
            AND F.D_ECOM_BU_KEY = A.D_ECOM_BU_KEY
            AND F.CN_CLASS_MARK_KEY = A.CN_CLASS_MARK_KEY
            AND NVL(F.TOTAL_FACTOR_AMT,0) <> 0
        )
),
/*
  回退范围仅放宽电商BU：
  TM0101/TM0102沿用ALL_CN跨中国区公司，其他渠道仍限制在本账套
*/
FALLBACK_SCOPE AS
(
  SELECT FB.OID,FB.COD_AZIENDA AS FALLBACK_SCOPE
  FROM FACTOR_BASE FB
  WHERE FB.FACTOR_AMT <> 0
    AND NVL(TRIM(FB.D_ECOM_BU),'ZZZZ') <> 'ZZZZ'
  UNION ALL
  SELECT FB.OID,'ALL_CN' AS FALLBACK_SCOPE
  FROM FACTOR_BASE FB
  WHERE FB.FACTOR_AMT <> 0
    AND NVL(TRIM(FB.D_ECOM_BU),'ZZZZ') <> 'ZZZZ'
),
FALLBACK_FACTOR_DETAIL AS
(
  SELECT
    FB.*,
    SUM(FB.FACTOR_AMT) OVER
    (
      PARTITION BY FS.FALLBACK_SCOPE,FB.PRODUCT_KEY,FB.CN_CLASS_MARK_KEY
    ) AS TOTAL_FACTOR_AMT,
    FS.FALLBACK_SCOPE
  FROM FACTOR_BASE FB
  JOIN FALLBACK_SCOPE FS
    ON FS.OID = FB.OID
),
FALLBACK_FACTOR AS
(
  SELECT
    F.*,
    A.MATCH_AZIENDA AS SOURCE_MATCH_AZIENDA,
    A.PRODUCT_KEY AS SOURCE_PRODUCT_KEY,
    A.D_ECOM_BU_KEY AS SOURCE_D_ECOM_BU_KEY,
    A.CN_CLASS_MARK_KEY AS SOURCE_CN_CLASS_MARK_KEY,
    A.COD_CONTO AS SOURCE_COD_CONTO,
    A.D_OPER_TYPE AS SOURCE_D_OPER_TYPE
  FROM FAILED_SOURCE A
  JOIN FALLBACK_FACTOR_DETAIL F
    ON F.FALLBACK_SCOPE = A.MATCH_AZIENDA
   AND F.PRODUCT_KEY = A.PRODUCT_KEY
   AND F.CN_CLASS_MARK_KEY = A.CN_CLASS_MARK_KEY
  WHERE NVL(F.TOTAL_FACTOR_AMT,0) <> 0
),
EFFECTIVE_FACTOR AS
(
  SELECT * FROM PRIMARY_FACTOR
  UNION ALL
  SELECT * FROM FALLBACK_FACTOR
)
SELECT
  NEWID() AS OID,
  P_SCENARIO AS COD_SCENARIO,
  P_PERIODO AS COD_PERIODO,
  F.COD_AZIENDA,
  'GA00_ALC_CN' AS COD_CATEGORIA,
  A.COD_CONTO,
  NULL AS CUST_CODE,
  NULL AS CUST_NAME,
  F.MATERIAL_CODE,
  F.MATERIAL_NAME,
  F.COD_DEST2,
  F.D_CHANNEL,
  F.D_MODE,
  F.D_ONOFFLINE,
  F.SALE_MODEL_CODE,
  F.MODEL_CODE,
  F.SHOP_CODE,
  'TA' AS SRC_SYSTEM,
  F.SOLD_TO_CODE,
  F.SOLD_TO_NAME,
  F.MATERIAL_GROUP_CODE,
  F.COD_AZI_CTP,
  F.BATCH_ID,
  F.D_PRC_GRP,
  F.COD_VALUTA,
  F.COD_VALUTA_ORIGINARIA,
  'REVM01' AS SRC_DETAIL,
  'CPM_SP_D2M_REV_M' AS PROVENIENZA,
  SESSION_USER AS USERUPD,
  SYSDATE AS DATEUPD,
  0 AS BILL_QTY,
  0 AS SHIP_QTY,
  0 AS ORDER_QTY,
  0 AS SALE_REV,
  SUM(A.ALLOC_AMT * F.FACTOR_AMT / NULLIF(F.TOTAL_FACTOR_AMT,0)) AS SALE_COGS,
  0 AS TAX_RATE,
  0 AS EXCHANGE_RATE,
  F.COD_DEST1,
  F.COD_DEST4,
  F.D_SPEC_SEC,
  F.D_PRO_TYPE_S,
  F.D_PRO_SSER,
  F.D_QUA_METHOD,
  F.D_PRO_STAGE,
  F.D_PRI_RANGE,
  F.D_PRO_SERIES,
  F.D_MARKET_PNT,
  F.D_TECH_TYPE,
  F.D_PRO_CLASS,
  F.D_MODEL_LCA,
  F.D_PRO_TYPE,
  F.CUST_UNITY_NAME,
  F.CREDIT_LEVEL_NAME,
  F.CUST_NATURE_NAME,
  F.CUST_TYPE_NAME,
  F.SHOP_NAME,
  F.SALE_MODEL_NAME,
  F.MODEL_NAME,
  F.D_CNL_C_TYPE,
  F.D_IND_C_TYPE,
  F.D_ECOM_BU,
  F.D_SALE_DEPT,
  F.COD_DEST3,
  F.D_BUS_SCE_S,
  F.AGENCY_CODE,
  F.AGENCY_NAME,
  F.IS_MINILED_CODE,
  F.CUSTOMER_MODEL,
  F.ORDER_TYPE_CODE,
  F.ZCALASSET,
  F.CN_CLASS_MARK_CODE,
  F.CN_CLASS_MARK_NAME,
  F.SALE_CERT_TYPE,
  'REV_01_220' AS D_ADJ_TYPE,
  0 AS ORG_REV,
  F.MATERIAL_GROUP_NAME,
  F.BAC_SRC_AZIENDA,
  F.MAKTX_S810,
  0 AS BCY_REV,
  0 AS MAP_REV,
  0 AS MAP_REV1,
  0 AS ORG_QTY,
  0 AS MAP_QTY,
  0 AS MAP_ZUM,
  0 AS CN_MAP_ZUM,
  0 AS CN_ORG_REV,
  0 AS MAP_DIS1,
  0 AS MAP_DIS3,
  0 AS MAP_DIS4,
  0 AS MAP_DIS5,
  0 AS MAP_DIS6,
  0 AS MAP_DIS30,
  0 AS MAP_DIS34,
  0 AS POLICY_AMT,
  0 AS AVG_UNIT_COST,
  SUM(A.ALLOC_AMT * F.FACTOR_AMT / NULLIF(F.TOTAL_FACTOR_AMT,0)) AS BCY_COGS,
  0 AS CN_SALE_COGS,
  F.D_POL_CLASS,
  F.D_MINILED,
  A.D_OPER_TYPE,
  F.NOTE
  --20260917FJF_ADD 二期新增字段
  ,F.D_EFF_CLASS,F.D_BU_SHOP,F.D_EC_STORE,F.D_UNICUSTGRP
FROM ALLOC_SOURCE A
JOIN EFFECTIVE_FACTOR F
  ON F.SOURCE_MATCH_AZIENDA = A.MATCH_AZIENDA
 AND F.SOURCE_PRODUCT_KEY = A.PRODUCT_KEY
 AND F.SOURCE_D_ECOM_BU_KEY = A.D_ECOM_BU_KEY
 AND F.SOURCE_CN_CLASS_MARK_KEY = A.CN_CLASS_MARK_KEY
 AND F.SOURCE_COD_CONTO = A.COD_CONTO
 AND F.SOURCE_D_OPER_TYPE = A.D_OPER_TYPE
--ALTER BY 20260917 13.49 SHIQINGFENG.EX 20260917 补充逻辑说明：空调通过按照产品大类(product_big_class_code)为P02（这是产品类别【D_PRO_CLASS】字段的层级）来判断，（不是通过有业务管理单元按照业务管理单元分摊，没业务管理单元按照利润中心的规则进行）并排除为金额为0
GROUP BY
  F.COD_AZIENDA,
  A.COD_CONTO,
  F.MATERIAL_CODE,
  F.MATERIAL_NAME,
  F.COD_DEST2,
  F.D_CHANNEL,
  F.D_MODE,
  F.D_ONOFFLINE,
  F.SALE_MODEL_CODE,
  F.MODEL_CODE,
  F.SHOP_CODE,
  F.SOLD_TO_CODE,
  F.SOLD_TO_NAME,
  F.MATERIAL_GROUP_CODE,
  F.COD_AZI_CTP,
  F.BATCH_ID,
  F.D_PRC_GRP,
  F.COD_VALUTA,
  F.COD_VALUTA_ORIGINARIA,
  F.COD_DEST1,
  F.COD_DEST4,
  F.D_SPEC_SEC,
  F.D_PRO_TYPE_S,
  F.D_PRO_SSER,
  F.D_QUA_METHOD,
  F.D_PRO_STAGE,
  F.D_PRI_RANGE,
  F.D_PRO_SERIES,
  F.D_MARKET_PNT,
  F.D_TECH_TYPE,
  F.D_PRO_CLASS,
  F.D_MODEL_LCA,
  F.D_PRO_TYPE,
  F.CUST_UNITY_NAME,
  F.CREDIT_LEVEL_NAME,
  F.CUST_NATURE_NAME,
  F.CUST_TYPE_NAME,
  F.SHOP_NAME,
  F.SALE_MODEL_NAME,
  F.MODEL_NAME,
  F.D_CNL_C_TYPE,
  F.D_IND_C_TYPE,
  F.D_ECOM_BU,
  F.D_SALE_DEPT,
  F.COD_DEST3,
  F.D_BUS_SCE_S,
  F.AGENCY_CODE,
  F.AGENCY_NAME,
  F.IS_MINILED_CODE,
  F.CUSTOMER_MODEL,
  F.ORDER_TYPE_CODE,
  F.ZCALASSET,
  F.CN_CLASS_MARK_CODE,
  F.CN_CLASS_MARK_NAME,
  F.SALE_CERT_TYPE,
  F.MATERIAL_GROUP_NAME,
  F.BAC_SRC_AZIENDA,
  F.MAKTX_S810,
  F.D_POL_CLASS,
  F.D_MINILED,
  A.D_OPER_TYPE,
  F.NOTE
  --20260917FJF_ADD 二期新增字段
  ,F.D_EFF_CLASS,F.D_BU_SHOP,F.D_EC_STORE,F.D_UNICUSTGRP
  HAVING SUM(A.ALLOC_AMT * F.FACTOR_AMT / NULLIF(F.TOTAL_FACTOR_AMT,0)) <> 0
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-8(费用转政策-中国区分摊)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*REV001_STEP_17-9(费用转政策-还原至产品公司)
  REV_01_221：中国区公司费用转政策分摊数还原到产品公司
  REV_01_222：产品公司费用转政策分摊数冲销
  AW_RUL_CKTHAZ_000001用于限制有效产品公司范围，利润中心明细取AW_RUL_PTAMAP_000001
  ALTER BY 20260831 shiqingfeng.ex 取消STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 月结不上
  ALTER BY 20260908 SHIQINGFENG.EX 取消注释STEP_17-5/STEP_17-6/STEP_17-7/STEP_17-8/STEP_17-9逻辑 开始测试
*/
INSERT /*+ PARALLEL(2) */ INTO AW_MR9_REVM01_000001_TEMP
(
  OID,COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_CATEGORIA,COD_CONTO,
  CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,D_CHANNEL,D_MODE,D_ONOFFLINE,
  SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SRC_SYSTEM,SOLD_TO_CODE,SOLD_TO_NAME,
  MATERIAL_GROUP_CODE,COD_AZI_CTP,BATCH_ID,D_PRC_GRP,COD_VALUTA,COD_VALUTA_ORIGINARIA,
  SRC_DETAIL,PROVENIENZA,USERUPD,DATEUPD,
  BILL_QTY,SHIP_QTY,ORDER_QTY,SALE_REV,SALE_COGS,TAX_RATE,EXCHANGE_RATE,
  COD_DEST1,COD_DEST4,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_SSER,D_QUA_METHOD,D_PRO_STAGE,
  D_PRI_RANGE,D_PRO_SERIES,D_MARKET_PNT,D_TECH_TYPE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,
  CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,
  SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,D_CNL_C_TYPE,D_IND_C_TYPE,D_ECOM_BU,
  D_SALE_DEPT,COD_DEST3,D_BUS_SCE_S,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,
  CUSTOMER_MODEL,ORDER_TYPE_CODE,ZCALASSET,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,
  SALE_CERT_TYPE,D_ADJ_TYPE,ORG_REV,MATERIAL_GROUP_NAME,BAC_SRC_AZIENDA,MAKTX_S810,
  BCY_REV,MAP_REV,MAP_REV1,ORG_QTY,MAP_QTY,MAP_ZUM,CN_MAP_ZUM,CN_ORG_REV,
  MAP_DIS1,MAP_DIS3,MAP_DIS4,MAP_DIS5,MAP_DIS6,MAP_DIS30,MAP_DIS34,
  POLICY_AMT,AVG_UNIT_COST,BCY_COGS,CN_SALE_COGS,D_POL_CLASS,D_MINILED,D_OPER_TYPE,NOTE
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
WITH PRODUCT_COMPANY_MAP AS
(
  SELECT DISTINCT PT.COD_AZIENDA,PT.COD_DEST2
    FROM TGK_FIMA_HISENSE.AW_RUL_PTAMAP_000001 PT
   WHERE PT.VALID_FR <= V_YEARMONTH
     AND NVL(PT.VALID_TO,'999999') >= V_YEARMONTH
     AND PT.COD_AZIENDA IN
         (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
     --EDIT BY LC 20261105 费用转政策还原无需限制产品公司范围
     /*AND EXISTS
         (
           SELECT 1
             FROM TGK_FIMA_HISENSE.AW_RUL_CKTHAZ_000001 CK
            WHERE CK.VALID_FR <= V_YEARMONTH
              AND NVL(CK.VALID_TO,'999999') >= V_YEARMONTH
              AND PT.COD_AZIENDA LIKE CK.AZI_RANGE
         )*/
),
ADJUST_TYPE AS
(
  SELECT 'REV_01_221' AS D_ADJ_TYPE, 1 AS AMT_SIGN FROM DUAL
  UNION ALL
  SELECT 'REV_01_222' AS D_ADJ_TYPE,-1 AS AMT_SIGN FROM DUAL
)
SELECT
  NEWID() AS OID,
  P_SCENARIO AS COD_SCENARIO,
  P_PERIODO AS COD_PERIODO,
  PT.COD_AZIENDA,
  'GA00_BF' AS COD_CATEGORIA,
  'S6001G5AD' AS COD_CONTO,
  '1001200' AS CUST_CODE,
  NULL AS CUST_NAME,
  AW.MATERIAL_CODE,
  AW.MATERIAL_NAME,
  AW.COD_DEST2,
  NULL AS D_CHANNEL,
  NULL AS D_MODE,
  AW.D_ONOFFLINE,
  AW.SALE_MODEL_CODE,
  AW.MODEL_CODE,
  AW.SHOP_CODE,
  'TA' AS SRC_SYSTEM,
  AW.SOLD_TO_CODE,
  AW.SOLD_TO_NAME,
  AW.MATERIAL_GROUP_CODE,
  '1180' AS COD_AZI_CTP,
  AW.BATCH_ID,
  AW.D_PRC_GRP,
  AW.COD_VALUTA,
  AW.COD_VALUTA_ORIGINARIA,
  'REVM01' AS SRC_DETAIL,
  'CPM_SP_D2M_REV_M' AS PROVENIENZA,
  SESSION_USER AS USERUPD,
  SYSDATE AS DATEUPD,
  0 AS BILL_QTY,
  0 AS SHIP_QTY,
  0 AS ORDER_QTY,
  0 AS SALE_REV,
  0 AS SALE_COGS,
  0 AS TAX_RATE,
  0 AS EXCHANGE_RATE,
  AW.COD_DEST1,
  AW.COD_DEST4,
  AW.D_SPEC_SEC,
  AW.D_PRO_TYPE_S,
  AW.D_PRO_SSER,
  AW.D_QUA_METHOD,
  AW.D_PRO_STAGE,
  AW.D_PRI_RANGE,
  AW.D_PRO_SERIES,
  AW.D_MARKET_PNT,
  AW.D_TECH_TYPE,
  AW.D_PRO_CLASS,
  AW.D_MODEL_LCA,
  AW.D_PRO_TYPE,
  '中国区' AS CUST_UNITY_NAME,--20260931 FJF_EDIT 中国区费用转政策还原产品公司统一客户组放中国区
  NULL AS CREDIT_LEVEL_NAME,
  NULL AS CUST_NATURE_NAME,
  NULL AS CUST_TYPE_NAME,
  AW.SHOP_NAME,
  AW.SALE_MODEL_NAME,
  AW.MODEL_NAME,
  NULL AS D_CNL_C_TYPE,
  NULL AS D_IND_C_TYPE,
  AW.D_ECOM_BU,
  AW.D_SALE_DEPT,
  AW.COD_DEST3,
  AW.D_BUS_SCE_S,
  AW.AGENCY_CODE,
  AW.AGENCY_NAME,
  AW.IS_MINILED_CODE,
  AW.CUSTOMER_MODEL,
  AW.ORDER_TYPE_CODE,
  AW.ZCALASSET,
  AW.CN_CLASS_MARK_CODE,
  AW.CN_CLASS_MARK_NAME,
  AW.SALE_CERT_TYPE,
  ADJ.D_ADJ_TYPE,
  AW.ORG_REV,
  AW.MATERIAL_GROUP_NAME,
  AW.BAC_SRC_AZIENDA,
  AW.MAKTX_S810,
  0 AS BCY_REV,
  0 AS MAP_REV,
  0 AS MAP_REV1,
  0 AS ORG_QTY,
  0 AS MAP_QTY,
  0 AS MAP_ZUM,
  0 AS CN_MAP_ZUM,
  0 AS CN_ORG_REV,
  0 AS MAP_DIS1,
  0 AS MAP_DIS3,
  0 AS MAP_DIS4,
  0 AS MAP_DIS5,
  0 AS MAP_DIS6,
  0 AS MAP_DIS30,
  0 AS MAP_DIS34,
  ADJ.AMT_SIGN * NVL(AW.SALE_COGS,0) AS POLICY_AMT,
  AW.AVG_UNIT_COST,
  0 AS BCY_COGS,
  0 AS CN_SALE_COGS,
  AW.D_POL_CLASS,
  AW.D_MINILED,
  AW.D_OPER_TYPE,
  AW.NOTE
  --20260917FJF_ADD 二期新增字段
  ,AW.D_EFF_CLASS,AW.D_BU_SHOP,AW.D_EC_STORE,AW.D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
JOIN PRODUCT_COMPANY_MAP PT
  ON PT.COD_DEST2 = AW.COD_DEST2
CROSS JOIN ADJUST_TYPE ADJ

WHERE 1=1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN
      (SELECT ELEM
         FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID
          AND HIE = '10'
          AND (ELEM = '1180' OR ELEM LIKE '12%'))
  AND AW.D_ADJ_TYPE = 'REV_01_220'
  AND (
        (AW.PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
        OR
        (
          AW.PROVENIENZA = 'CPM_SP_D2M_REV_M'
          AND AW.COD_CONTO LIKE '%AD'
          AND NVL(AW.SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
          AND P_ORG_FLAG = 2
        )
        OR (AW.NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
        OR AW.PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
      )
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-9(费用转政策-还原至产品公司)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


-- ALTER BY 20261030 LICHENG.EX 中国区自营成本本月不上线：REV001_STEP_17-10(会员店-产品公司冲销)整体注释停用，冲销数 REV_01_225 / 还原数 REV_01_226 不再生成；代码全部保留（未删除）。
-- 恢复方式：删除下面这一行块注释起始符、删除段末尾的块注释结束符那一行；段内说明块已改为 -- 注释，两处 INSERT 的并行提示符 PARALLEL(2) 未保留，恢复时按需自行加回
/*
-- REV001_STEP_17-10(会员店-产品公司冲销)
  REV_01_225：单体收入成本表-产品公司会员店链收入冲销（按成本转收入后原字段 × -1）
  REV_01_226：单体收入成本表-产品公司会员店收入还原（按成本转收入，原字段原值）
  本步骤拆两段执行：
    第一段 INSERT：冲销数（D_ADJ_TYPE='REV_01_225'，收入/数量类字段 × -1）
    第二段 INSERT：还原数（D_ADJ_TYPE='REV_01_226'，收入/数量类字段取原值）
  取数限制（两段相同）：
    ①【COD_AZIENDA-公司】源行取 1180、12**；任务输出行的公司取自 SESSION_AZIENDA_LIST（会话解析结果，已含公司范围/锁定过滤），不再直接使用 P_AZIENDA 参数
    ②【COD_CONTO-科目】S6001 开头、S6401 开头
    ③【D_OPER_TYPE-业务分类】OPTY041-中国区自营-会员店
    ④【COD_DEST2-利润中心】按 AW_RUL_PTAMAP_000001 匹配（映射表须在有效期内，产品公司限 6700/2600/6800/6515）：
        · 冲销段：仅当会话公司为总公司（6700/2600/6800/6515）时生成——用会话公司匹配映射表，输出公司取匹配到的产品公司
        · 还原段：仅当会话公司为分公司（6734/2601/6834/6515）时生成——先切换为总公司（6734→6700 / 2601→2600 / 6834→6800；6515→6515），
          用总公司匹配利润中心（即取总公司名下利润中心的数据），输出公司仍落回分公司；还原数客商固定为 2105159
    ⑤【组织标旗 P_ORG_FLAG】不加门控：1/2/3 均按上述①②③三条限制取数
    ? 两段均排除本步骤已生成的 D_ADJ_TYPE(REV_01_225/REV_01_226) 行，防止第二段吃到第一段刚提交的冲销行
  新增：20261010 LICHENG.EX ／ 20261010 拆为「冲销/还原」两段、取数限制精简、数字类字段置 0、利润中心仅按 AW_RUL_PTAMAP_000001 匹配 ／ 20261010 组织范围统一改用 SESSION_AZIENDA_LIST，不再直接使用 P_AZIENDA 参数 ／ 20261010 还原段改为仅分公司会话生成：总公司(6700/2600/6800)只生成冲销，分公司(6734/2601/6834)生成还原（以切换后总公司匹配利润中心，输出落回分公司） ／ 20261010 还原段 SESSION_COMPANY 增加 DISTINCT 去重，避免 SESSION_AZIENDA_LIST 重复行导致 JOIN 1:N 放大（冲销段用 IN 不受影响） ／ 20261012 还原数客商固定为 2105159；总公司/分公司集合均新增 6515（6515 既是总公司也是分公司，切换为自身）
-- （17-10 说明块结束）

-- 第一段：冲销数（REV_01_225，原字段 × -1）
INSERT INTO AW_MR9_REVM01_000001_TEMP
(
  OID,COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_CATEGORIA,COD_CONTO,
  CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,D_CHANNEL,D_MODE,D_ONOFFLINE,
  SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SRC_SYSTEM,SOLD_TO_CODE,SOLD_TO_NAME,
  MATERIAL_GROUP_CODE,COD_AZI_CTP,BATCH_ID,D_PRC_GRP,COD_VALUTA,COD_VALUTA_ORIGINARIA,
  SRC_DETAIL,PROVENIENZA,USERUPD,DATEUPD,
  BILL_QTY,SHIP_QTY,ORDER_QTY,SALE_REV,SALE_COGS,TAX_RATE,EXCHANGE_RATE,
  COD_DEST1,COD_DEST4,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_SSER,D_QUA_METHOD,D_PRO_STAGE,
  D_PRI_RANGE,D_PRO_SERIES,D_MARKET_PNT,D_TECH_TYPE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,
  CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,
  SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,D_CNL_C_TYPE,D_IND_C_TYPE,D_ECOM_BU,
  D_SALE_DEPT,COD_DEST3,BUS_SCE_CAT_CODE,BUS_SCE_CAT_NAME,
  AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,CUSTOMER_MODEL,ORDER_TYPE_CODE,ZCALASSET,
  CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,D_ADJ_TYPE,ORG_REV,
  MATERIAL_GROUP_NAME,BAC_SRC_AZIENDA,MAKTX_S810,
  BCY_REV,MAP_REV,MAP_REV1,ORG_QTY,MAP_QTY,MAP_ZUM,CN_MAP_ZUM,CN_ORG_REV,
  MAP_DIS1,MAP_DIS3,MAP_DIS4,MAP_DIS5,MAP_DIS6,MAP_DIS30,MAP_DIS34,
  POLICY_AMT,AVG_UNIT_COST,BCY_COGS,CN_SALE_COGS,D_POL_CLASS,D_MINILED,
  D_BUS_SCE_S,D_DIFF_TYPE,INVOICE_CODE,D_OPER_TYPE,SHIPPING_ORDER,STD_QTY,
  --20260917FJF_ADD 二期新增字段
  D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
WITH PROFIT_CENTER_MAP AS
(
  SELECT DISTINCT PT.COD_AZIENDA,PT.COD_DEST2
    FROM TGK_FIMA_HISENSE.AW_RUL_PTAMAP_000001 PT
   WHERE PT.VALID_FR <= V_YEARMONTH
     AND NVL(PT.VALID_TO,'999999') >= V_YEARMONTH
     AND PT.COD_AZIENDA IN ('6700','2600','6800','6515')   --④ 限制产品公司范围
),
CUSTOMER_MAP_RAW AS
(
  SELECT NVL(TRIM(CP_COMPANY_CODE_MR),TRIM(CP_COMPANY_CODE)) AS SOURCE_AZIENDA,
         NVL(
           MAX(CASE WHEN CUST_CODE LIKE 'A012__' THEN CUST_CODE END),
           MAX(CUST_CODE)
         ) AS CUST_CODE
    FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_CUST2CTP_MAPPING
   WHERE CUST_TYPE_CODE = 'C'
     AND SYSTEM_SRC = 'S600'
     AND VALID_FR <= V_YEARMONTH
     AND NVL(VALID_TO,'999999') >= V_YEARMONTH
     AND NVL(TRIM(CP_COMPANY_CODE_MR),TRIM(CP_COMPANY_CODE)) IS NOT NULL
   GROUP BY NVL(TRIM(CP_COMPANY_CODE_MR),TRIM(CP_COMPANY_CODE))
)
SELECT
  NEWID() AS OID,
  P_SCENARIO AS COD_SCENARIO,
  P_PERIODO AS COD_PERIODO,
  PT.COD_AZIENDA AS COD_AZIENDA,                              --与参数一致（会话解析后的产品公司）
  'GA00_BF' AS COD_CATEGORIA,
  'S600100' AS COD_CONTO,
  CASE WHEN AW.COD_AZIENDA = '1180' THEN '1001200' ELSE CM.CUST_CODE END AS CUST_CODE,
  NULL AS CUST_NAME,                                          --放空（后续按统一规则刷新）
  AW.MATERIAL_CODE AS MATERIAL_CODE,
  AW.MATERIAL_NAME AS MATERIAL_NAME,
  AW.COD_DEST2 AS COD_DEST2,
  NULL AS D_CHANNEL,
  NULL AS D_MODE,                                             --放空
  '020_ON_002' AS D_ONOFFLINE,
  AW.SALE_MODEL_CODE AS SALE_MODEL_CODE,
  AW.MODEL_CODE AS MODEL_CODE,
  AW.SHOP_CODE AS SHOP_CODE,
  'TA' AS SRC_SYSTEM,
  CASE WHEN AW.COD_AZIENDA = '1180' THEN '1001200' ELSE CM.CUST_CODE END AS SOLD_TO_CODE,
  NULL AS SOLD_TO_NAME,
  AW.MATERIAL_GROUP_CODE AS MATERIAL_GROUP_CODE,
  AW.COD_AZIENDA AS COD_AZI_CTP,
  AW.BATCH_ID AS BATCH_ID,
  AW.D_PRC_GRP AS D_PRC_GRP,
  AW.COD_VALUTA AS COD_VALUTA,
  AW.COD_VALUTA_ORIGINARIA AS COD_VALUTA_ORIGINARIA,
  'REVM01' AS SRC_DETAIL,
  'CPM_SP_D2M_REV_M' AS PROVENIENZA,
  SESSION_USER AS USERUPD,
  SYSDATE AS DATEUPD,
  -1 * AW.BILL_QTY AS BILL_QTY,
  -1 * AW.SHIP_QTY AS SHIP_QTY,
  -1 * AW.ORDER_QTY AS ORDER_QTY,
  --EDIT BY LC 20261012 10:55 取成本作为收入金额时，冲销无需变号
  AW.SALE_COGS AS SALE_REV,                              --收入金额：取源表成本金额
  0 AS SALE_COGS,                                             --置0
  AW.TAX_RATE AS TAX_RATE,
  AW.EXCHANGE_RATE AS EXCHANGE_RATE,
  AW.COD_DEST1 AS COD_DEST1,
  AW.COD_DEST4 AS COD_DEST4,
  AW.D_SPEC_SEC AS D_SPEC_SEC,
  AW.D_PRO_TYPE_S AS D_PRO_TYPE_S,
  AW.D_PRO_SSER AS D_PRO_SSER,
  AW.D_QUA_METHOD AS D_QUA_METHOD,
  AW.D_PRO_STAGE AS D_PRO_STAGE,
  AW.D_PRI_RANGE AS D_PRI_RANGE,
  AW.D_PRO_SERIES AS D_PRO_SERIES,
  AW.D_MARKET_PNT AS D_MARKET_PNT,
  AW.D_TECH_TYPE AS D_TECH_TYPE,
  AW.D_PRO_CLASS AS D_PRO_CLASS,
  AW.D_MODEL_LCA AS D_MODEL_LCA,
  AW.D_PRO_TYPE AS D_PRO_TYPE,
  NULL AS CUST_UNITY_NAME,                                    --放空
  NULL AS CREDIT_LEVEL_NAME,                                  --放空
  NULL AS CUST_NATURE_NAME,                                   --放空
  NULL AS CUST_TYPE_NAME,                                     --放空
  AW.SHOP_NAME AS SHOP_NAME,
  AW.SALE_MODEL_NAME AS SALE_MODEL_NAME,
  AW.MODEL_NAME AS MODEL_NAME,
  NULL AS D_CNL_C_TYPE,                                       --放空
  NULL AS D_IND_C_TYPE,                                       --放空
  NULL AS D_ECOM_BU,
  AW.D_SALE_DEPT AS D_SALE_DEPT,
  AW.COD_DEST3 AS COD_DEST3,
  AW.BUS_SCE_CAT_CODE AS BUS_SCE_CAT_CODE,
  AW.BUS_SCE_CAT_NAME AS BUS_SCE_CAT_NAME,
  AW.AGENCY_CODE AS AGENCY_CODE,
  AW.AGENCY_NAME AS AGENCY_NAME,
  AW.IS_MINILED_CODE AS IS_MINILED_CODE,
  AW.CUSTOMER_MODEL AS CUSTOMER_MODEL,
  AW.ORDER_TYPE_CODE AS ORDER_TYPE_CODE,
  AW.ZCALASSET AS ZCALASSET,
  AW.CN_CLASS_MARK_CODE AS CN_CLASS_MARK_CODE,
  AW.CN_CLASS_MARK_NAME AS CN_CLASS_MARK_NAME,
  AW.SALE_CERT_TYPE AS SALE_CERT_TYPE,
  'REV_01_225' AS D_ADJ_TYPE,
  AW.SALE_COGS AS ORG_REV,
  AW.MATERIAL_GROUP_NAME AS MATERIAL_GROUP_NAME,
  AW.BAC_SRC_AZIENDA AS BAC_SRC_AZIENDA,
  AW.MAKTX_S810 AS MAKTX_S810,
  AW.SALE_COGS AS BCY_REV,
  AW.SALE_COGS AS MAP_REV,
  AW.SALE_COGS AS MAP_REV1,
  -1 * AW.ORG_QTY AS ORG_QTY,
  -1 * AW.MAP_QTY AS MAP_QTY,
  -1 * AW.MAP_ZUM AS MAP_ZUM,
  0 AS CN_MAP_ZUM,
  0 AS CN_ORG_REV,
  0 AS MAP_DIS1,
  0 AS MAP_DIS3,
  0 AS MAP_DIS4,
  0 AS MAP_DIS5,
  0 AS MAP_DIS6,
  0 AS MAP_DIS30,
  0 AS MAP_DIS34,
  0 AS POLICY_AMT,
  0 AS AVG_UNIT_COST,
  0 AS BCY_COGS,
  0 AS CN_SALE_COGS,
  AW.D_POL_CLASS AS D_POL_CLASS,
  AW.D_MINILED AS D_MINILED,
  AW.D_BUS_SCE_S AS D_BUS_SCE_S,
  '150701001' AS D_DIFF_TYPE,                                 --默认值
  AW.INVOICE_CODE AS INVOICE_CODE,
  AW.D_OPER_TYPE AS D_OPER_TYPE,
  AW.SHIPPING_ORDER AS SHIPPING_ORDER,
  -1 * AW.STD_QTY AS STD_QTY,
  AW.D_EFF_CLASS AS D_EFF_CLASS,
  AW.D_BU_SHOP AS D_BU_SHOP,
  AW.D_EC_STORE AS D_EC_STORE,
  AW.D_UNICUSTGRP AS D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
JOIN PROFIT_CENTER_MAP PT
  ON PT.COD_DEST2 = AW.COD_DEST2
LEFT JOIN CUSTOMER_MAP_RAW CM
  ON CM.SOURCE_AZIENDA = AW.COD_AZIENDA
WHERE 1=1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN
      (SELECT ELEM
         FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID
          AND HIE = '10'
          AND (ELEM = '1180' OR ELEM LIKE '12%'))                       --① 公司
  AND (AW.COD_CONTO LIKE 'S6001%' OR AW.COD_CONTO LIKE 'S6401%')     --② 科目
  AND AW.D_OPER_TYPE = 'OPTY041'                                     --③ 中国区自营-会员店
  AND NVL(AW.D_ADJ_TYPE,'|') NOT IN ('REV_01_225','REV_01_226')      --排除本步骤已生成的行，防重复处理
  AND PT.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)   --冲销：用会话公司（含范围/锁定过滤）匹配
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-10(会员店-产品公司冲销)冲销数完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

-- 第二段：还原数（REV_01_226，原字段原值）
INSERT INTO AW_MR9_REVM01_000001_TEMP
(
  OID,COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_CATEGORIA,COD_CONTO,
  CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,D_CHANNEL,D_MODE,D_ONOFFLINE,
  SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SRC_SYSTEM,SOLD_TO_CODE,SOLD_TO_NAME,
  MATERIAL_GROUP_CODE,COD_AZI_CTP,BATCH_ID,D_PRC_GRP,COD_VALUTA,COD_VALUTA_ORIGINARIA,
  SRC_DETAIL,PROVENIENZA,USERUPD,DATEUPD,
  BILL_QTY,SHIP_QTY,ORDER_QTY,SALE_REV,SALE_COGS,TAX_RATE,EXCHANGE_RATE,
  COD_DEST1,COD_DEST4,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_SSER,D_QUA_METHOD,D_PRO_STAGE,
  D_PRI_RANGE,D_PRO_SERIES,D_MARKET_PNT,D_TECH_TYPE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,
  CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,
  SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,D_CNL_C_TYPE,D_IND_C_TYPE,D_ECOM_BU,
  D_SALE_DEPT,COD_DEST3,BUS_SCE_CAT_CODE,BUS_SCE_CAT_NAME,
  AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,CUSTOMER_MODEL,ORDER_TYPE_CODE,ZCALASSET,
  CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,D_ADJ_TYPE,ORG_REV,
  MATERIAL_GROUP_NAME,BAC_SRC_AZIENDA,MAKTX_S810,
  BCY_REV,MAP_REV,MAP_REV1,ORG_QTY,MAP_QTY,MAP_ZUM,CN_MAP_ZUM,CN_ORG_REV,
  MAP_DIS1,MAP_DIS3,MAP_DIS4,MAP_DIS5,MAP_DIS6,MAP_DIS30,MAP_DIS34,
  POLICY_AMT,AVG_UNIT_COST,BCY_COGS,CN_SALE_COGS,D_POL_CLASS,D_MINILED,
  D_BUS_SCE_S,D_DIFF_TYPE,INVOICE_CODE,D_OPER_TYPE,SHIPPING_ORDER,STD_QTY,
  --20260917FJF_ADD 二期新增字段
  D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
WITH PROFIT_CENTER_MAP AS
(
  SELECT DISTINCT PT.COD_AZIENDA,PT.COD_DEST2
    FROM TGK_FIMA_HISENSE.AW_RUL_PTAMAP_000001 PT
   WHERE PT.VALID_FR <= V_YEARMONTH
     AND NVL(PT.VALID_TO,'999999') >= V_YEARMONTH
     AND PT.COD_AZIENDA IN ('6700','2600','6800','6515')   --④ 限制产品公司范围
),
SESSION_COMPANY AS
(
  --④ 仅「分公司」会话：还原行只在分公司运行时生成（总公司只生成冲销）
  --   DISTINCT 必须保留：SESSION_AZIENDA_LIST 可能含重复行，JOIN 会把还原数放大成 N 倍
  --   分公司 → 其总公司：CASE 切换 6734→6700 / 2601→2600 / 6834→6800；6515 既是总公司也是分公司，切换为自身（6515→6515）
  SELECT DISTINCT ELEM AS COD_AZIENDA,
         CASE ELEM WHEN '6734' THEN '6700'
                   WHEN '2601' THEN '2600'
                   WHEN '6834' THEN '6800'
                   WHEN '6515' THEN '6515'
                   ELSE ELEM END AS COD_AZIENDA_MAP
    FROM SESSION_AZIENDA_LIST
   WHERE SESSION_ID = V_SESSION_ID
     AND ELEM IN ('6734','2601','6834','6515')   --仅分公司(含6515)：总公司(6700/2600/6800)会话不生成还原
),
SOLD_TO_NAME_MAP AS
(
  SELECT LTRIM(KUNNR,'0') AS KUNNR,MAX(name1) AS name1   --按 kunnr 归并，避免 1:N 扇出
    FROM TGK_FIMA_HISENSE.DS_DWD_SAP_KNA1
   WHERE ('S'||MANDT) = 'S600'
   GROUP BY LTRIM(KUNNR,'0')
)
SELECT
  NEWID() AS OID,
  P_SCENARIO AS COD_SCENARIO,
  P_PERIODO AS COD_PERIODO,
  SC.COD_AZIENDA AS COD_AZIENDA,                              --与参数一致（切换前的会话公司）
  'GA00_BF' AS COD_CATEGORIA,
  'S600100' AS COD_CONTO,
  '2105159' AS CUST_CODE,                                     --还原数客商固定为 2105159
  NULL AS CUST_NAME,                                          --放空（后续按统一规则刷新）
  AW.MATERIAL_CODE AS MATERIAL_CODE,
  AW.MATERIAL_NAME AS MATERIAL_NAME,
  AW.COD_DEST2 AS COD_DEST2,
  AW.D_CHANNEL AS D_CHANNEL,
  NULL AS D_MODE,                                             --放空
  AW.D_ONOFFLINE AS D_ONOFFLINE,
  AW.SALE_MODEL_CODE AS SALE_MODEL_CODE,
  AW.MODEL_CODE AS MODEL_CODE,
  AW.SHOP_CODE AS SHOP_CODE,
  'TA' AS SRC_SYSTEM,
  '2105159' AS SOLD_TO_CODE,                                  --还原数客商固定为 2105159
  SOLDTO.name1 AS SOLD_TO_NAME,
  AW.MATERIAL_GROUP_CODE AS MATERIAL_GROUP_CODE,
  AW.COD_AZI_CTP AS COD_AZI_CTP,
  AW.BATCH_ID AS BATCH_ID,
  AW.D_PRC_GRP AS D_PRC_GRP,
  AW.COD_VALUTA AS COD_VALUTA,
  AW.COD_VALUTA_ORIGINARIA AS COD_VALUTA_ORIGINARIA,
  'REVM01' AS SRC_DETAIL,
  'CPM_SP_D2M_REV_M' AS PROVENIENZA,
  SESSION_USER AS USERUPD,
  SYSDATE AS DATEUPD,
  AW.BILL_QTY AS BILL_QTY,
  AW.SHIP_QTY AS SHIP_QTY,
  AW.ORDER_QTY AS ORDER_QTY,
  --EDIT BY LC 20261012 10:55 取成本作为收入金额时，还原需变号
  -1 * AW.SALE_COGS AS SALE_REV,                                   --收入金额：取源表成本金额
  0 AS SALE_COGS,                                             --置0
  AW.TAX_RATE AS TAX_RATE,
  AW.EXCHANGE_RATE AS EXCHANGE_RATE,
  AW.COD_DEST1 AS COD_DEST1,
  AW.COD_DEST4 AS COD_DEST4,
  AW.D_SPEC_SEC AS D_SPEC_SEC,
  AW.D_PRO_TYPE_S AS D_PRO_TYPE_S,
  AW.D_PRO_SSER AS D_PRO_SSER,
  AW.D_QUA_METHOD AS D_QUA_METHOD,
  AW.D_PRO_STAGE AS D_PRO_STAGE,
  AW.D_PRI_RANGE AS D_PRI_RANGE,
  AW.D_PRO_SERIES AS D_PRO_SERIES,
  AW.D_MARKET_PNT AS D_MARKET_PNT,
  AW.D_TECH_TYPE AS D_TECH_TYPE,
  AW.D_PRO_CLASS AS D_PRO_CLASS,
  AW.D_MODEL_LCA AS D_MODEL_LCA,
  AW.D_PRO_TYPE AS D_PRO_TYPE,
  NULL AS CUST_UNITY_NAME,                                    --放空
  NULL AS CREDIT_LEVEL_NAME,                                  --放空
  NULL AS CUST_NATURE_NAME,                                   --放空
  NULL AS CUST_TYPE_NAME,                                     --放空
  AW.SHOP_NAME AS SHOP_NAME,
  AW.SALE_MODEL_NAME AS SALE_MODEL_NAME,
  AW.MODEL_NAME AS MODEL_NAME,
  NULL AS D_CNL_C_TYPE,                                       --放空
  NULL AS D_IND_C_TYPE,                                       --放空
  AW.D_ECOM_BU AS D_ECOM_BU,
  AW.D_SALE_DEPT AS D_SALE_DEPT,
  AW.COD_DEST3 AS COD_DEST3,
  AW.BUS_SCE_CAT_CODE AS BUS_SCE_CAT_CODE,
  AW.BUS_SCE_CAT_NAME AS BUS_SCE_CAT_NAME,
  AW.AGENCY_CODE AS AGENCY_CODE,
  AW.AGENCY_NAME AS AGENCY_NAME,
  AW.IS_MINILED_CODE AS IS_MINILED_CODE,
  AW.CUSTOMER_MODEL AS CUSTOMER_MODEL,
  AW.ORDER_TYPE_CODE AS ORDER_TYPE_CODE,
  AW.ZCALASSET AS ZCALASSET,
  AW.CN_CLASS_MARK_CODE AS CN_CLASS_MARK_CODE,
  AW.CN_CLASS_MARK_NAME AS CN_CLASS_MARK_NAME,
  AW.SALE_CERT_TYPE AS SALE_CERT_TYPE,
  'REV_01_226' AS D_ADJ_TYPE,
  -1 * AW.SALE_COGS AS ORG_REV,
  AW.MATERIAL_GROUP_NAME AS MATERIAL_GROUP_NAME,
  AW.BAC_SRC_AZIENDA AS BAC_SRC_AZIENDA,
  AW.MAKTX_S810 AS MAKTX_S810,
  -1 * AW.SALE_COGS AS BCY_REV,
  -1 * AW.SALE_COGS AS MAP_REV,
  -1 * AW.SALE_COGS AS MAP_REV1,
  AW.ORG_QTY AS ORG_QTY,
  AW.MAP_QTY AS MAP_QTY,
  AW.MAP_ZUM AS MAP_ZUM,
  0 AS CN_MAP_ZUM,
  0 AS CN_ORG_REV,
  0 AS MAP_DIS1,
  0 AS MAP_DIS3,
  0 AS MAP_DIS4,
  0 AS MAP_DIS5,
  0 AS MAP_DIS6,
  0 AS MAP_DIS30,
  0 AS MAP_DIS34,
  0 AS POLICY_AMT,
  0 AS AVG_UNIT_COST,
  0 AS BCY_COGS,
  0 AS CN_SALE_COGS,
  AW.D_POL_CLASS AS D_POL_CLASS,
  AW.D_MINILED AS D_MINILED,
  AW.D_BUS_SCE_S AS D_BUS_SCE_S,
  '150701001' AS D_DIFF_TYPE,                                 --默认值
  AW.INVOICE_CODE AS INVOICE_CODE,
  AW.D_OPER_TYPE AS D_OPER_TYPE,
  AW.SHIPPING_ORDER AS SHIPPING_ORDER,
  AW.STD_QTY AS STD_QTY,
  AW.D_EFF_CLASS AS D_EFF_CLASS,
  AW.D_BU_SHOP AS D_BU_SHOP,
  AW.D_EC_STORE AS D_EC_STORE,
  AW.D_UNICUSTGRP AS D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
JOIN PROFIT_CENTER_MAP PT
  ON PT.COD_DEST2 = AW.COD_DEST2
JOIN SESSION_COMPANY SC
  ON SC.COD_AZIENDA_MAP = PT.COD_AZIENDA                            --④ 还原：公司先切换再匹配
LEFT JOIN SOLD_TO_NAME_MAP SOLDTO
  ON SOLDTO.KUNNR = LTRIM('2105159','0')                            --客商固定 2105159，名称按其 kunnr 取
WHERE 1=1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN
      (SELECT ELEM
         FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID
          AND HIE = '10'
          AND (ELEM = '1180' OR ELEM LIKE '12%'))                       --① 公司
  AND (AW.COD_CONTO LIKE 'S6001%' OR AW.COD_CONTO LIKE 'S6401%')     --② 科目
  AND AW.D_OPER_TYPE = 'OPTY041'                                     --③ 中国区自营-会员店
  AND NVL(AW.D_ADJ_TYPE,'|') NOT IN ('REV_01_225','REV_01_226')      --排除本步骤已生成的行，防重复处理
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','REV001_STEP_17-10(会员店-产品公司冲销)还原数完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;
*/
-- ==== REV001_STEP_17-10(会员店-产品公司冲销) 停用结束（20261030 中国区自营成本本月不上线）====

/*REV001_STEP_18(制费转成本-业务范围更新)*/
MERGE  /*+ USE_HASH(T C) */ INTO AW_MR9_REVM01_000001_TEMP T
USING (
     SELECT COMPANY_CODE, BUS_RANGE_CODE_ORDER
       FROM  TGK_FIMA_HISENSE.dim_rule_fi_mr_BusScope_for_Company
      WHERE COMPANY_CODE IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
      --INSTR(V_AZIENDA, COMPANY_CODE) > 0
        AND VALID_FR <= V_YEARMONTH
        AND NVL(VALID_TO, '999999') >= V_YEARMONTH
) MAPPING
ON (T.COD_AZIENDA = MAPPING.COMPANY_CODE
    AND T.SRC_DETAIL = 'MFEX'
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
)
WHEN MATCHED THEN
    UPDATE
    SET T.COD_DEST3 = MAPPING.BUS_RANGE_CODE_ORDER
;


/*2.2.99 REV001_STEP_99 国际营销取数先数据删除*/
DELETE FROM AW_MR9_REVM01_000001_TEMP T
WHERE 1=P_ORG_FLAG
   AND COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT DISTINCT ELEM
          FROM SESSION_V_REF_AZIENDA
              WHERE SESSION_ID = V_SESSION_ID
              AND NODE = '020'
              AND HIE = '10') --- 取国际营销节点下公司
   AND D_ONOFFLINE = '020_OFF_001'
   AND SRC_DETAIL = 'ZTAB_IM_ZB'
   AND  SRC_SYSTEM ='TA_GJYX'
   AND COD_DEST1 ='2300030600'
   AND D_DIFF_TYPE ='ZZZZ'
   AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )
   ;

/*2.2.99 REV001_STEP_99(国际营销取数)*/
INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP
(
     OID,
     COD_SCENARIO,
     COD_PERIODO,
     COD_AZIENDA,
     COD_CONTO,
     CUST_CODE,
     MATERIAL_CODE,
     COD_DEST2,
     D_ONOFFLINE,
     COD_AZI_CTP,
     COD_VALUTA_ORIGINARIA,
     SRC_DETAIL,
     SRC_SYSTEM,
     USERUPD,
     DATEUPD,
     MAP_QTY,
     MAP_ZUM,
     SALE_REV,
     ORG_REV,
     MAP_REV,
     COD_DEST1,
     COD_DEST4,
     COD_DEST3,
     CUSTOMER_MODEL,
     COD_CATEGORIA,
     SALE_COGS,
     D_DIFF_TYPE,
     PROVENIENZA

)
SELECT
     NEWID() OID,
     COD_SCENARIO,
     COD_PERIODO,
     COD_AZIENDA,
     CASE WHEN MAPPED_ACCOUNT_CODE LIKE '6001%' THEN 'S600100'
          WHEN MAPPED_ACCOUNT_CODE LIKE '6401%' THEN 'S640100'
          /*20260115 ADD BY SHIQINGFENG.EX 新增销量科目取数*/
          WHEN COD_CONTO_IM = 'SQ0000' THEN 'S600100'
          ELSE MAPPED_ACCOUNT_CODE
     END COD_CONTO,
     KUNRG_IM CUST_CODE,
     MATNR_IM MATERIAL_CODE,
     MAPPED_PROFIT_CENTER COD_DEST2,
     '020_OFF_001' D_ONOFFLINE,
     MAP_KUNRG_IM COD_AZI_CTP,
     COD_VALUTA_IM COD_VALUTA_ORIGINARIA,
     'ZTAB_IM_ZB' SRC_DETAIL,
     'TA_GJYX' SRC_SYSTEM,
     SESSION_USER USERUPD,
     SYSDATE DATEUPD,
     SUM(CASE WHEN COD_CONTO_IM = 'SQ0000' THEN IMPORTO_IM ELSE 0 END) MAP_QTY,
     SUM(CASE WHEN COD_CONTO_IM = 'SQ0000' THEN IMPORTO_IM ELSE 0 END) MAP_ZUM,
     /*20260115 MODIFIED BY SHIQINGFENG.EX 去除负号处理*/
     SUM(CASE WHEN SUBSTR(MAPPED_ACCOUNT_CODE,1,4) = '6001'  THEN IMPORTO_IM ELSE 0 END) SALE_REV,
     SUM(CASE WHEN SUBSTR(MAPPED_ACCOUNT_CODE,1,4) = '6001'  THEN IMPORTO_IM ELSE 0 END) ORG_REV,
     SUM(CASE WHEN SUBSTR(MAPPED_ACCOUNT_CODE,1,4) = '6001'  THEN IMPORTO_IM ELSE 0 END) MAP_REV,
     '2300030600' COD_DEST1,
     COD_DEST51_IM AS COD_DEST4,
     MAPPED_BUSINESS_AREA COD_DEST3,
     ZCUSMODEL_IM CUSTOMER_MODEL,
     'ZAMOUNT' COD_CATEGORIA,
     SUM(CASE WHEN SUBSTR(MAPPED_ACCOUNT_CODE,1,4) = '6401' OR MAPPED_ACCOUNT_CODE = 'S640110' THEN IMPORTO_IM ELSE 0 END) SALE_COGS,
     'ZZZZ' D_DIFF_TYPE,
     'CPM_SP_D2M_REV_M' PROVENIENZA
FROM TGK_FIMA_HISENSE.ZTAB_IM_SYNC_ZB_MAP M
WHERE 1=P_ORG_FLAG
AND (SUBSTR(MAPPED_ACCOUNT_CODE,1,4) IN ('6001','6401') OR COD_CONTO_IM = 'SQ0000' OR MAPPED_ACCOUNT_CODE = 'S640110')
AND COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN  (SELECT ELEM FROM SESSION_AZIENDA_LIST S1 WHERE SESSION_ID = V_SESSION_ID
                         AND EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S2
                                         WHERE S1.SESSION_ID =S2.SESSION_ID AND S2.ELEM =S1.ELEM
                                         AND S2.HIE = '10'  AND S2.NODE IN ('020')
                                        )
                                        )
--AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
/*AND COD_AZIENDA IN (SELECT DISTINCT ELEM
    FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID
        AND NODE = '020'
        AND HIE = '10') --- 取国际营销节点下公司
        */
--对FLAG为N进行过滤
AND NVL(FLAG,'|') NOT LIKE 'N%'
GROUP BY COD_SCENARIO, COD_PERIODO, COD_AZIENDA,
CASE WHEN MAPPED_ACCOUNT_CODE LIKE '6001%' THEN 'S600100'
          WHEN MAPPED_ACCOUNT_CODE LIKE '6401%' THEN 'S640100'
          /*20260115 ADD BY SHIQINGFENG.EX 新增销量科目取数*/
          WHEN COD_CONTO_IM = 'SQ0000' THEN 'S600100'
          ELSE MAPPED_ACCOUNT_CODE
     END, KUNRG_IM, MATNR_IM, MAPPED_PROFIT_CENTER, MAP_KUNRG_IM, COD_VALUTA_IM, COD_DEST51_IM, MAPPED_BUSINESS_AREA, ZCUSMODEL_IM;

COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','2.2.99 REV001_STEP_99(国际营销取数)完成',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*REV001_STEP_100(收入成本人民币处理)*/
--更新收入-本位币金额

UPDATE AW_MR9_REVM01_000001_TEMP
SET BCY_REV = ORG_REV,BCY_COGS = SALE_COGS
WHERE COD_SCENARIO = P_SCENARIO
      AND COD_PERIODO = P_PERIODO
      AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
      --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
      AND COD_CONTO NOT LIKE '%AD'
       ;
COMMIT ;
/*
--更新手工调整数据收入-本位币金额
MERGE  \*+ USE_HASH(T C) *\ INTO AW_MR9_REVM01_000001_TEMP T
USING (
SELECT AW.OID, CASE WHEN AW.COD_AZIENDA IN (SELECT DISTINCT ELEM
                                           FROM SESSION_V_REF_AZIENDA
                                          WHERE SESSION_ID = V_SESSION_ID AND NODE = '020' AND HIE = '10')
                      THEN ORG_REV
                      ELSE DECODE(NVL(CAMBIO_PERIODO,0),0,0,ORG_REV*NVL(CAMBIO_PERIODO,0))
               END BCY_REV
  FROM AW_MR9_REVM01_000001_TEMP AW
  LEFT JOIN AZIENDA AZ
    ON AW.COD_AZIENDA = AZ.COD_AZIENDA
  LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
    ON AW.COD_SCENARIO = CA.COD_SCENARIO
   AND AW.COD_PERIODO = CA.COD_PERIODO
   AND AZ.COD_VALUTA = CA.COD_VALUTA
WHERE AW.COD_SCENARIO = P_SCENARIO
      AND AW.COD_PERIODO = P_PERIODO
      AND AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
      --AND INSTR(V_AZIENDA, AW.COD_AZIENDA) > 0
      AND COD_CONTO LIKE '%AD'
)
C
ON (T.OID = C.OID
  AND T.COD_SCENARIO = P_SCENARIO
  AND T.COD_PERIODO = P_PERIODO
  AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, T.COD_AZIENDA) > 0
  AND T.COD_CONTO LIKE '%AD'
)
WHEN MATCHED THEN UPDATE SET T.BCY_REV = C.BCY_REV
  ;
COMMIT ;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','更新手工调整数据收入-本位币金额',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

--更新收入-人民币金额  国际营销不需要更新
MERGE  \*+ USE_HASH(T C) *\ INTO AW_MR9_REVM01_000001_TEMP T
USING (
SELECT AW.OID, CASE WHEN AW.COD_AZIENDA IN (SELECT DISTINCT ELEM
                                           FROM SESSION_V_REF_AZIENDA
                                          WHERE SESSION_ID = V_SESSION_ID AND NODE = '020' AND HIE = '10')
                      THEN BCY_REV
                      ELSE DECODE(NVL(CAMBIO_PERIODO,0),0,0,BCY_REV/NVL(CAMBIO_PERIODO,0))
               END ORG_REV
  FROM AW_MR9_REVM01_000001_TEMP AW
  LEFT JOIN AZIENDA AZ
    ON AW.COD_AZIENDA = AZ.COD_AZIENDA
  LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
    ON AW.COD_SCENARIO = CA.COD_SCENARIO
   AND AW.COD_PERIODO = CA.COD_PERIODO
   AND AZ.COD_VALUTA = CA.COD_VALUTA
WHERE AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, AW.COD_AZIENDA) > 0
  AND AW.COD_CONTO NOT LIKE '%AD'
)
C
ON (T.OID = C.OID
  AND T.COD_SCENARIO = P_SCENARIO
  AND T.COD_PERIODO = P_PERIODO
  AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, T.COD_AZIENDA) > 0
  AND T.COD_CONTO NOT LIKE '%AD'
  )
WHEN MATCHED THEN UPDATE SET T.ORG_REV = C.ORG_REV
  ;

COMMIT ;
INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','更新金额字段',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

--更新手工调整数据成本-本位币金额
MERGE  \*+ USE_HASH(T C) *\ INTO AW_MR9_REVM01_000001_TEMP T
USING (
SELECT AW.OID, CASE WHEN AW.COD_AZIENDA IN (SELECT DISTINCT ELEM
                                           FROM SESSION_V_REF_AZIENDA
                                          WHERE SESSION_ID = V_SESSION_ID AND NODE = '020' AND HIE = '10')
                      THEN SALE_COGS
                      ELSE DECODE(NVL(CAMBIO_PERIODO,0),0,0,SALE_COGS*NVL(CAMBIO_PERIODO,0))
               END BCY_COGS
  FROM AW_MR9_REVM01_000001_TEMP AW
  LEFT JOIN AZIENDA AZ
    ON AW.COD_AZIENDA = AZ.COD_AZIENDA
  LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
    ON AW.COD_SCENARIO = CA.COD_SCENARIO
   AND AW.COD_PERIODO = CA.COD_PERIODO
   AND AZ.COD_VALUTA = CA.COD_VALUTA
WHERE AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, AW.COD_AZIENDA) > 0
  AND AW.COD_CONTO LIKE '%AD'
)
C
ON (T.OID = C.OID
  AND T.COD_SCENARIO = P_SCENARIO
  AND T.COD_PERIODO = P_PERIODO
  AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, T.COD_AZIENDA) > 0
  AND T.COD_CONTO LIKE '%AD'
)
WHEN MATCHED THEN UPDATE SET T.BCY_COGS = C.BCY_COGS
  ;
COMMIT ;

--更新成本-人民币金额  国际营销不需要更新
MERGE  \*+ USE_HASH(T C) *\ INTO AW_MR9_REVM01_000001_TEMP T
USING (
SELECT AW.OID, CASE WHEN AW.COD_AZIENDA IN (SELECT DISTINCT ELEM
                                           FROM SESSION_V_REF_AZIENDA
                                          WHERE SESSION_ID = V_SESSION_ID AND NODE = '020' AND HIE = '10')
                      THEN BCY_COGS
                      ELSE DECODE(NVL(CAMBIO_PERIODO,0),0,0,BCY_COGS/NVL(CAMBIO_PERIODO,0))
               END SALE_COGS
  FROM AW_MR9_REVM01_000001_TEMP AW
  LEFT JOIN AZIENDA AZ
    ON AW.COD_AZIENDA = AZ.COD_AZIENDA
  LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
    ON AW.COD_SCENARIO = CA.COD_SCENARIO
   AND AW.COD_PERIODO = CA.COD_PERIODO
   AND AZ.COD_VALUTA = CA.COD_VALUTA
WHERE AW.COD_SCENARIO = P_SCENARIO
      AND AW.COD_PERIODO = P_PERIODO
      AND AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
      --AND INSTR(V_AZIENDA, AW.COD_AZIENDA) > 0
      AND AW.COD_CONTO NOT LIKE '%AD'
)
C
ON (T.OID = C.OID
    AND T.COD_SCENARIO = P_SCENARIO
    AND T.COD_PERIODO = P_PERIODO
    AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, T.COD_AZIENDA) > 0
    AND T.COD_CONTO NOT LIKE '%AD'
)
WHEN MATCHED THEN UPDATE SET T.SALE_COGS = C.SALE_COGS
  ;
COMMIT ;*/

UPDATE AW_MR9_REVM01_000001_TEMP T
   SET (T.BCY_REV, T.BCY_COGS) = (
           SELECT CASE
                       WHEN T.COD_AZIENDA IN (
                                SELECT DISTINCT ELEM
                                  FROM SESSION_V_REF_AZIENDA
                                 WHERE SESSION_ID = V_SESSION_ID
                                   AND NODE = '020'
                                   AND HIE  = '10'
                            ) THEN T.ORG_REV
                       ELSE DECODE(NVL(CA.CAMBIO_PERIODO, 0),
                                   0, 0,
                                   T.ORG_REV * NVL(CA.CAMBIO_PERIODO, 0))
                   END,
                  CASE
                       WHEN T.COD_AZIENDA IN (
                                SELECT DISTINCT ELEM
                                  FROM SESSION_V_REF_AZIENDA
                                 WHERE SESSION_ID = V_SESSION_ID
                                   AND NODE = '020'
                                   AND HIE  = '10'
                            ) THEN T.SALE_COGS
                       ELSE DECODE(NVL(CA.CAMBIO_PERIODO, 0),
                                   0, 0,
                                   T.SALE_COGS * NVL(CA.CAMBIO_PERIODO, 0))
                   END
                   /*20260915 10：14 shiqingfeng.ex 修改使用生产环境公司主数据*/
             FROM TGK_FIMA_HISENSE.AZIENDA AZ
             LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
               ON T.COD_SCENARIO = CA.COD_SCENARIO
              AND T.COD_PERIODO  = CA.COD_PERIODO
              AND AZ.COD_VALUTA  = CA.COD_VALUTA
            WHERE AZ.COD_AZIENDA = T.COD_AZIENDA
       )
 WHERE T.COD_SCENARIO = P_SCENARIO
   AND T.COD_PERIODO  = P_PERIODO
   AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND T.COD_CONTO LIKE '%AD';

COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M', '更新手工调整数据收入/成本-本位币金额', SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO, P_AZIENDA);
COMMIT;

UPDATE AW_MR9_REVM01_000001_TEMP T
   SET (T.ORG_REV, T.SALE_COGS) = (
           SELECT CASE
                       WHEN T.COD_AZIENDA IN (
                                SELECT DISTINCT ELEM
                                  FROM SESSION_V_REF_AZIENDA
                                 WHERE SESSION_ID = V_SESSION_ID
                                   AND NODE = '020'
                                   AND HIE  = '10'
                            ) THEN T.BCY_REV
                        /* ALTER BY LICHENG.EX 20261117 1646 原币=人民币时不再除汇率（S600100 除外）
                           变更原因：02 新口径 qcy_code 取 bkpf.waers，6015/80N0/8080 等 10 家海外公司的
                                    凭证抬头是 CNY（BSEG 行 pswsl 仍是 USD），BCY_REV 装的就是 CNY 金额；
                                    再除本位币汇率会虚增 —— USD 本位币约 6.72 倍、HKD 约 1.08 倍。
                                    6015 单公司 202610 的 S600110 虚增 1.28 亿（148,481,297 vs 22,046,503）。
                           目标成果：原币=CNY 的非 S600100 科目 ORG_REV 直接取 BCY_REV。
                           排除 S600100 的原因：该科目在 STEP_8（L5004 起）已按 EXCHANGE_RATE 折成本位币，
                                    ORG_REV 必须继续走「BCY_REV / CAMBIO」还原成人民币，不能直取。
                           中国区公司 CAMBIO(CNY)=1，结果与改前一致。 */
                        WHEN NVL(T.COD_VALUTA_ORIGINARIA, 'X') = 'CNY'
                         AND T.COD_CONTO <> 'S600100' THEN T.BCY_REV
                        ELSE DECODE(NVL(CA.CAMBIO_PERIODO, 0),
                                    0, 0,
                                    T.BCY_REV / NVL(CA.CAMBIO_PERIODO, 0))
                    END,
                  CASE
                       WHEN T.COD_AZIENDA IN (
                                SELECT DISTINCT ELEM
                                  FROM SESSION_V_REF_AZIENDA
                                 WHERE SESSION_ID = V_SESSION_ID
                                   AND NODE = '020'
                                   AND HIE  = '10'
                            ) THEN T.BCY_COGS
                       ELSE DECODE(NVL(CA.CAMBIO_PERIODO, 0),
                                   0, 0,
                                   T.BCY_COGS / NVL(CA.CAMBIO_PERIODO, 0))
                   END
                   /*20260915 10：14 shiqingfeng.ex 修改使用生产环境公司主数据*/
             FROM TGK_FIMA_HISENSE.AZIENDA AZ
             LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
               ON T.COD_SCENARIO = CA.COD_SCENARIO
              AND T.COD_PERIODO  = CA.COD_PERIODO
              AND AZ.COD_VALUTA  = CA.COD_VALUTA
            WHERE AZ.COD_AZIENDA = T.COD_AZIENDA
       )
 WHERE T.COD_SCENARIO = P_SCENARIO
   AND T.COD_PERIODO  = P_PERIODO
   AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND T.COD_CONTO NOT LIKE '%AD';

COMMIT;

/* ALTER BY LICHENG.EX 20261117 1646 补正本位币金额（原币=人民币、本位币为外币的公司）
   变更原因：L9946 统一 SET BCY_REV = ORG_REV，装的是原币金额。中国区公司原币=本位币=CNY，没问题；
            但 6015/80N0/8080 等 10 家海外公司的凭证抬头是 CNY（bkpf.waers），BCY_REV 就成了 CNY 金额，
            与「收入-本位币」口径（USD/HKD）不符。6015 202610：BCY_REV 22,080,809 vs 生产 3,278,559。
   目标成果：原币=CNY 且本位币<>CNY 的行，BCY_REV = ORG_REV × 本位币汇率（CAMBIO_PERIODO）；
            其余行保持原值。只扫这 10 家，不影响中国区。 */
UPDATE AW_MR9_REVM01_000001_TEMP T
   SET T.BCY_REV = (
           SELECT ROUND(T.ORG_REV * NVL(CA.CAMBIO_PERIODO, 0), 2)
             FROM TGK_FIMA_HISENSE.AZIENDA AZ
             LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO CA
               ON T.COD_SCENARIO = CA.COD_SCENARIO
              AND T.COD_PERIODO  = CA.COD_PERIODO
              AND AZ.COD_VALUTA  = CA.COD_VALUTA
            WHERE AZ.COD_AZIENDA = T.COD_AZIENDA
       )
 WHERE T.COD_SCENARIO = P_SCENARIO
   AND T.COD_PERIODO  = P_PERIODO
   AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND T.COD_CONTO NOT LIKE '%AD'
   AND T.COD_CONTO <> 'S600100'      /* S600100 的 BCY_REV 在 STEP_8 后已是本位币，不能再折 */
   AND NVL(T.COD_VALUTA_ORIGINARIA, 'X') = 'CNY'
   AND NVL(T.COD_VALUTA, 'X') <> 'CNY';

COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M', '更新金额字段', SYSDATE, SESSION_USER, V_SCENARIO, V_PERIODO, P_AZIENDA);
COMMIT;



--2026.1.24新增逻辑AW_MR9_ADJM01_000001来源的类别更新为'GA00_BF'
UPDATE AW_MR9_REVM01_000001_TEMP SET
COD_CATEGORIA = 'GA00_BF'
WHERE COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
--AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
AND SRC_DETAIL IN ('ADJM01','AW_MR9_ADJM01_000001')
;
COMMIT ;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','插入ODSS600_EKKO开始',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


INSERT INTO AW_MR9_REVM01_000001_TEMP(
OID
,COD_SCENARIO,COD_PERIODO
, SHOP_CODE,COD_AZIENDA
, COD_DEST1
, D_PRC_GRP
, COD_CONTO
, D_SALE_DEPT
, COD_DEST3
, COD_CATEGORIA
, D_PRO_CLASS, D_DATA_BLOCK
, D_DIFF_TYPE
, MATERIAL_CODE
, COD_DEST2
, COD_DEST4
, D_MARKET_PNT
, D_PRO_SSER
, D_SPEC_SEC
, D_PRO_TYPE_S
, D_QUA_METHOD , D_PRO_STAGE , D_PRI_RANGE , D_PRO_SERIES
, D_TECH_TYPE , D_MODEL_LCA , D_PRO_TYPE
, D_POL_CLASS ,MODEL_NAME
, CUST_CODE
,MODEL_CODE
, D_CHANNEL
, D_MODE
, D_ONOFFLINE , D_ECOM_BU
, D_IND_C_TYPE
, D_CNL_C_TYPE
,  COD_VALUTA
, COD_VALUTA_ORIGINARIA
, MAP_QTY
, ORG_REV, MAP_REV , MAP_REV1
, MATERIAL_GROUP_CODE , SRC_SYSTEM , SRC_DETAIL
, PROVENIENZA
, USERUPD
, DATEUPD
, D_BU_TRAN
, D_ADJ_TYPE
,  D_OPER_TYPE

)

SELECT
NEWID() AS OID
,COD_SCENARIO,COD_PERIODO
,'' SHOP_CODE,COD_AZIENDA
,'ZZZZ' COD_DEST1
,'ZZZZ' D_PRC_GRP
,'S600100AD' COD_CONTO
,'ZZZZ' D_SALE_DEPT
,'' COD_DEST3
,'GA00_DI_IN' COD_CATEGORIA
,'ZZZZ' D_PRO_CLASS,'ZZZZ' D_DATA_BLOCK
,'' D_DIFF_TYPE
,A.MATNR MATERIAL_CODE
,PROD_LINE COD_DEST2
,BRAND_CODE COD_DEST4
,'ZZZZ' D_MARKET_PNT
,'ZZZZ' D_PRO_SSER
,'ZZZZ' D_SPEC_SEC
,'ZZZZ' D_PRO_TYPE_S
,'ZZZZ' D_QUA_METHOD ,'ZZZZ' D_PRO_STAGE ,'ZZZZ' D_PRI_RANGE ,'ZZZZ' D_PRO_SERIES
,'ZZZZ' D_TECH_TYPE ,'ZZZZ' D_MODEL_LCA ,'ZZZZ' D_PRO_TYPE
,'ZZZZ' D_POL_CLASS ,''MODEL_NAME
,KUNNR CUST_CODE
,''MODEL_CODE
,'ZZZZ' D_CHANNEL
,'ZZZZ' D_MODE
,'ZZZZ' D_ONOFFLINE ,'ZZZZ' D_ECOM_BU
,'ZZZZ' D_IND_C_TYPE
,'ZZZZ' D_CNL_C_TYPE
,'CNY'  COD_VALUTA
,'CNY' COD_VALUTA_ORIGINARIA
,MENGE MAP_QTY
,BRTWR ORG_REV,BRTWR MAP_REV ,BRTWR MAP_REV1
,'' MATERIAL_GROUP_CODE ,'S600' SRC_SYSTEM ,'EKKO' SRC_DETAIL
,'CPM_SP_D2M_REV_M' PROVENIENZA
,SESSION_USER USERUPD
,SYSDATE DATEUPD
,'ZZZZ' D_BU_TRAN
,'ZZZZ' D_ADJ_TYPE
,'ZZZZ'  D_OPER_TYPE
FROM (
SELECT P_SCENARIO AS COD_SCENARIO,P_PERIODO AS COD_PERIODO,BUKRS COD_AZIENDA,MATNR,XH,-1*MENGE MENGE,-1*BRTWR BRTWR
      , KUNNR, ZMM045.CHARG
  FROM (
  SELECT BUKRS,EBELN,MATNR,EMATN,MATKL,MENGE,NETPR,BRTWR,BYGJ,(BYGJ/1.16) CB
              ,(CASE WHEN KUNNR IS NULL THEN LTRIM(C.LIFNR,0) ELSE LTRIM(KUNNR,0) END) KUNNR,NJMS AS XH,EBELP
         FROM(
              SELECT BUKRS,A.EBELN,LIFNR,MATNR,EMATN,MATKL,MENGE,NETPR,BRTWR,EBELP
                FROM (
                      SELECT BUKRS,EBELN,LIFNR,LPONR
                      FROM ODS.ODSS600_EKKO@FMSLK
                      WHERE BUKRS IN (SELECT COD_AZIENDA FROM TGK_GB_HISENSE.AZIENDA_GERARCHIA_ABBI WHERE COD_AZIENDA_ELEGER = '0302610')
                      AND BSART = 'ZNB' AND AEDAT >= TRUNC(TO_DATE(SUBSTR(P_SCENARIO,1,4)||P_PERIODO,'YYYYMM'))
                      AND AEDAT <= LAST_DAY(TO_DATE(SUBSTR(P_SCENARIO,1,4)||P_PERIODO,'YYYYMM'))
                      AND LIFNR NOT IN ('0000010238')/*南京有内部公司徐州老户的回购，这部分是不能取的 YANGLILI 202P_PERIODO109*/
                     ) A
               INNER JOIN
         (SELECT EBELN,MATNR,EMATN,MATKL,MENGE,NETPR,BRTWR,EBELP
         FROM ODS.ODSS600_EKPO@FMSLK
        WHERE (TRIM(LOEKZ) IS NULL AND BUKRS IN (SELECT COD_AZIENDA FROM TGK_GB_HISENSE.AZIENDA_GERARCHIA_ABBI WHERE COD_AZIENDA_ELEGER='0302610'))
           OR EBELN IN ('4201028541','4201028542')/*这两个订单5月份时已删除，这里加上是为了对4月份数据用*/
         ) B ON A.EBELN = B.EBELN
  )C
         LEFT JOIN (
                     SELECT XH,BYGJ, NJMS
                     FROM TGK_GB_HISENSE.ZTAB_600_WZPHB
                     WHERE YEARMONTH IN (SUBSTR(P_SCENARIO,1,4)||P_PERIODO) AND RBUKRS = '6700'
                    ) D ON D.XH = C.MATNR
         LEFT JOIN (
                    SELECT LIFNR,NAME1,KUNNR FROM TGK_FIMA_HISENSE.ODSS600_LFA1
                   ) E ON E.LIFNR = C.LIFNR
        ) S
LEFT JOIN (
     SELECT CHARG, EBELN, EBELP
     FROM ODS.ODSS600_EKBE@FMSLK
     WHERE TO_CHAR(VGABE)='1'
     GROUP BY CHARG, EBELN, EBELP
) ZMM045
ON S.EBELN=ZMM045.EBELN AND S.EBELP=ZMM045.EBELP
) A

LEFT JOIN
(SELECT *FROM TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD ) MA
ON A.MATNR = MA.MATNR
WHERE 1=P_ORG_FLAG
;
COMMIT;


 INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','业绩调拨开始',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

INSERT INTO AW_MR9_REVM01_000001_TEMP
(OID, COD_SCENARIO, COD_PERIODO, SHOP_CODE, COD_AZIENDA, COD_DEST1, COD_AZI_CTP, D_PRC_GRP, COD_CONTO, D_SALE_DEPT, COD_DEST3, COD_CATEGORIA, D_PRO_CLASS
, D_DATA_BLOCK, D_DIFF_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_QUA_METHOD
, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_MODEL_LCA, D_PRO_TYPE, SALE_MODEL_NAME, D_POL_CLASS, MODEL_NAME, CUST_CODE, MODEL_CODE, SALE_MODEL_CODE
, CUST_NAME, D_CHANNEL, D_MODE, D_ONOFFLINE, D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, D_IND_C_TYPE, D_CNL_C_TYPE, COD_VALUTA
, SHIP_QTY, COD_VALUTA_ORIGINARIA, ORDER_QTY, BILL_QTY, SALE_REV, DISCOUNT_3, DISCOUNT_4, DISCOUNT_5, DISCOUNT_6, TAX_RATE, EXCHANGE_RATE, ORG_QTY, MAP_QTY
, ORG_REV, MAP_REV, MAP_REV1, MAP_DIS3, MAP_DIS4, MAP_DIS5, MAP_DIS6, POLICY_AMT, BATCH_ID, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, SRC_SYSTEM
, SRC_DETAIL, SHOP_NAME, AGENCY_CODE, AGENCY_NAME, IS_MINILED_CODE, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, SALE_COGS, DISCOUNT_1, MAP_DIS1, DISCOUNT_30
, DISCOUNT_34, MAP_DIS30, MAP_DIS34, NOTE, D_BU_TRAN, CUSTOMER_MODEL, ORDER_TYPE_CODE, ZCALASSET, CALC_RULE, STATUTORY_ACCT_CODE, MAP_ZUM, CN_CLASS_MARK_CODE
, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, D_ADJ_TYPE, CHANGE_COEFFICIENT, GFCFY_AMOUNT, GFCFL_AMOUNT, D_OPER_TYPE, BCY_REV, BCY_COGE
, BCY_COGS, MATERIAL_GROUP_NAME, ORG_GP, AVG_UNIT_COST, BAC_AZIENDA
,D_MINILED
)
SELECT
    NEWID() AS OID
  , COD_SCENARIO
  , COD_PERIODO
  , SHOP_CODE
  , COD_AZIENDA
  , COD_DEST1
  , COD_AZI_CTP
  , D_PRC_GRP
  , COD_CONTO
  , D_SALE_DEPT
  , COD_DEST3
  , 'GA00_PA_OUT' AS COD_CATEGORIA
  , D_PRO_CLASS
  , D_DATA_BLOCK
  , '100604001' AS D_DIFF_TYPE
  , MATERIAL_CODE
  , MATERIAL_NAME
  , COD_DEST2
  , COD_DEST4
  , D_MARKET_PNT
  , D_PRO_SSER
  , D_SPEC_SEC
  , D_PRO_TYPE_S
  , D_QUA_METHOD
  , D_PRO_STAGE
  , D_PRI_RANGE
  , D_PRO_SERIES
  , D_TECH_TYPE
  , D_MODEL_LCA
  , D_PRO_TYPE
  , SALE_MODEL_NAME
  , D_POL_CLASS
  , MODEL_NAME
  , CUST_CODE
  , MODEL_CODE
  , SALE_MODEL_CODE
  , CUST_NAME
  , D_CHANNEL
  , D_MODE
  , D_ONOFFLINE
  , D_ECOM_BU
  , CUST_UNITY_NAME
  , CREDIT_LEVEL_NAME
  , CUST_NATURE_NAME
  , CUST_TYPE_NAME
  , D_IND_C_TYPE
  , D_CNL_C_TYPE
  , COD_VALUTA
  , 0-SHIP_QTY
  , COD_VALUTA_ORIGINARIA
  , 0-ORDER_QTY
  , 0-BILL_QTY
  , 0-SALE_REV
  , 0-DISCOUNT_3
  , 0-DISCOUNT_4
  , 0-DISCOUNT_5
  , 0-DISCOUNT_6
  , TAX_RATE
  , EXCHANGE_RATE
  , 0-ORG_QTY
  , 0-MAP_QTY
  , 0-ORG_REV
  , 0-MAP_REV
  , 0-MAP_REV1
  , 0-MAP_DIS3
  , 0-MAP_DIS4
  , 0-MAP_DIS5
  , 0-MAP_DIS6
  , 0-POLICY_AMT
  , BATCH_ID
  , SOLD_TO_CODE
  , SOLD_TO_NAME
  , MATERIAL_GROUP_CODE
  , SRC_SYSTEM
  , SRC_DETAIL
  , SHOP_NAME
  , AGENCY_CODE
  , AGENCY_NAME
  , IS_MINILED_CODE
  , PROVENIENZA
  , SESSION_USER AS USERUPD
  , SYSDATE DATEUPD
  , EN_VERSION
  , 0-SALE_COGS
  , 0-DISCOUNT_1
  , 0-MAP_DIS1
  , 0-DISCOUNT_30
  , 0-DISCOUNT_34
  , 0-MAP_DIS30
  , 0-MAP_DIS34
  , NOTE
  , D_BU_TRAN
  , CUSTOMER_MODEL
  , ORDER_TYPE_CODE
  , ZCALASSET
  , CALC_RULE
  , STATUTORY_ACCT_CODE
  , 0-MAP_ZUM
  , CN_CLASS_MARK_CODE
  , CN_CLASS_MARK_NAME
  , SALE_CERT_TYPE
  , 0-CN_SALE_COGS
  , 0-CN_ORG_REV
  , 0-CN_MAP_ZUM
  , D_ADJ_TYPE
  , CHANGE_COEFFICIENT
  , 0-GFCFY_AMOUNT
  , 0-GFCFL_AMOUNT
  , D_OPER_TYPE
  , 0-BCY_REV
  , 0-BCY_COGE
  , 0-BCY_COGS
  , MATERIAL_GROUP_NAME
  , 0-ORG_GP
  , 0-AVG_UNIT_COST
  , BAC_SRC_AZIENDA AS BAC_AZIENDA
  ,D_MINILED
  FROM AW_MR9_REVM01_000001_TEMP AW
 WHERE  1=P_ORG_FLAG
   AND COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
   AND NVL(COD_AZIENDA,'|') <> NVL(BAC_SRC_AZIENDA,'|')
   AND COD_AZIENDA IN ('6800','6700','2600','2300')
   AND BAC_SRC_AZIENDA NOT IN ('6847','6746','6750','6751','6752')
   AND ((COD_AZIENDA IN ('6800') AND BAC_SRC_AZIENDA LIKE '68%')
     OR (COD_AZIENDA IN ('6700') AND BAC_SRC_AZIENDA LIKE '67%')
     /*
       20260416 MODIFIED BY SHQIINGFENG.EX 修改集采公司，2600对应26**和23**，2300不涉及集采
     */
     OR (aw.COD_AZIENDA IN ('2600') AND (BAC_SRC_AZIENDA LIKE '26%' OR BAC_SRC_AZIENDA LIKE '23%'))
     --OR (COD_AZIENDA IN ('2300') AND BAC_SRC_AZIENDA LIKE '23%')
   )
   AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
   AND BAC_SRC_AZIENDA IN (SELECT COD_AZIENDA
                       FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
                      WHERE VALID_FR <= V_YEARMONTH
                        AND NVL(VALID_TO,'999999') >= V_YEARMONTH
                        AND REV_FLAG = 'Y'
                      )
UNION ALL
SELECT
    NEWID() AS OID
  , COD_SCENARIO
  , COD_PERIODO
  , SHOP_CODE
  , BAC_SRC_AZIENDA AS COD_AZIENDA
  , COD_DEST1
  , COD_AZI_CTP
  , D_PRC_GRP
  , COD_CONTO
  , D_SALE_DEPT
  , AZ.COD_DEST3 AS COD_DEST3
  , 'GA00_PA_IN' AS COD_CATEGORIA
  , D_PRO_CLASS
  , D_DATA_BLOCK
  , '100604001' AS D_DIFF_TYPE
  , MATERIAL_CODE
  , MATERIAL_NAME
  , COD_DEST2
  , COD_DEST4
  , D_MARKET_PNT
  , D_PRO_SSER
  , D_SPEC_SEC
  , D_PRO_TYPE_S
  , D_QUA_METHOD
  , D_PRO_STAGE
  , D_PRI_RANGE
  , D_PRO_SERIES
  , D_TECH_TYPE
  , D_MODEL_LCA
  , D_PRO_TYPE
  , SALE_MODEL_NAME
  , D_POL_CLASS
  , MODEL_NAME
  , CUST_CODE
  , MODEL_CODE
  , SALE_MODEL_CODE
  , CUST_NAME
  , D_CHANNEL
  , D_MODE
  , D_ONOFFLINE
  , D_ECOM_BU
  , CUST_UNITY_NAME
  , CREDIT_LEVEL_NAME
  , CUST_NATURE_NAME
  , CUST_TYPE_NAME
  , D_IND_C_TYPE
  , D_CNL_C_TYPE
  , COD_VALUTA
  , SHIP_QTY
  , COD_VALUTA_ORIGINARIA
  , ORDER_QTY
  , BILL_QTY
  , SALE_REV
  , DISCOUNT_3
  , DISCOUNT_4
  , DISCOUNT_5
  , DISCOUNT_6
  , TAX_RATE
  , EXCHANGE_RATE
  , ORG_QTY
  , MAP_QTY
  , ORG_REV
  , MAP_REV
  , MAP_REV1
  , MAP_DIS3
  , MAP_DIS4
  , MAP_DIS5
  , MAP_DIS6
  , POLICY_AMT
  , BATCH_ID
  , SOLD_TO_CODE
  , SOLD_TO_NAME
  , MATERIAL_GROUP_CODE
  , SRC_SYSTEM
  , SRC_DETAIL
  , SHOP_NAME
  , AGENCY_CODE
  , AGENCY_NAME
  , IS_MINILED_CODE
  , PROVENIENZA
  , SESSION_USER AS USERUPD
  , SYSDATE DATEUPD
  , EN_VERSION
  , SALE_COGS
  , DISCOUNT_1
  , MAP_DIS1
  , DISCOUNT_30
  , DISCOUNT_34
  , MAP_DIS30
  , MAP_DIS34
  , NOTE
  , D_BU_TRAN
  , CUSTOMER_MODEL
  , ORDER_TYPE_CODE
  , ZCALASSET
  , CALC_RULE
  , STATUTORY_ACCT_CODE
  , MAP_ZUM
  , CN_CLASS_MARK_CODE
  , CN_CLASS_MARK_NAME
  , SALE_CERT_TYPE
  , CN_SALE_COGS
  , CN_ORG_REV
  , CN_MAP_ZUM
  , D_ADJ_TYPE
  , CHANGE_COEFFICIENT
  , GFCFY_AMOUNT
  , GFCFL_AMOUNT
  , D_OPER_TYPE
  , BCY_REV
  , BCY_COGE
  , BCY_COGS
  , MATERIAL_GROUP_NAME
  , ORG_GP
  , AVG_UNIT_COST
  , AW.COD_AZIENDA AS BAC_AZIENDA
  ,D_MINILED
  FROM AW_MR9_REVM01_000001_TEMP AW
  LEFT JOIN (SELECT COD_AZIENDA,COD_DEST3_AUT AS COD_DEST3 FROM TGK_FIMA_HISENSE.AZIENDA) AZ
    ON AW.BAC_SRC_AZIENDA = AZ.COD_AZIENDA
 WHERE  1=P_ORG_FLAG
   AND COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND aw.BAC_SRC_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   --AND INSTR(V_AZIENDA, aw.BAC_SRC_AZIENDA) > 0
   AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
   AND NVL(aw.COD_AZIENDA,'|') <> NVL(BAC_SRC_AZIENDA,'|')
   AND aw.COD_AZIENDA IN ('6800','6700','2600','2300')
   AND aw.BAC_SRC_AZIENDA NOT IN ('6847','6746','6750','6751','6752')
   AND ((aw.COD_AZIENDA IN ('6800') AND BAC_SRC_AZIENDA LIKE '68%')
     OR (aw.COD_AZIENDA IN ('6700') AND BAC_SRC_AZIENDA LIKE '67%')
     OR (aw.COD_AZIENDA IN ('2600') AND (BAC_SRC_AZIENDA LIKE '26%' OR BAC_SRC_AZIENDA LIKE '23%'))
     --OR (aw.COD_AZIENDA IN ('2300') AND BAC_SRC_AZIENDA LIKE '23%')
   )
   AND BAC_SRC_AZIENDA IN (SELECT COD_AZIENDA
                       FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
                      WHERE VALID_FR <= V_YEARMONTH
                        AND NVL(VALID_TO,'999999') >= V_YEARMONTH
                        AND REV_FLAG = 'Y'
                      )

;
COMMIT;



-- 对未改造上线公司（2091/2090/4006/6000A/1610/2070/071'）按公司默认利润中心更新统一放到790081000-餐饮服务_fjf_add
  UPDATE AW_MR9_REVM01_000001_TEMP A
  SET COD_DEST2 = CASE WHEN COD_AZIENDA = '2090' THEN '790301000'
                       WHEN COD_AZIENDA = '2091' THEN '790081000'
                       WHEN COD_AZIENDA = '4006' THEN '790301000'
                       WHEN COD_AZIENDA = '6000A' THEN '107101000'
                       WHEN COD_AZIENDA IN ('1610','2070','2071') THEN '190023000'
                  END,
     /*202060728-2 shiqingfeng.ex 2090/2091/4006，默认业务范围修改为2000（原逻辑默认2018）*/
      COD_DEST3 = CASE WHEN COD_AZIENDA = '2090' THEN '2000'
                       WHEN COD_AZIENDA = '2091' THEN '2000'
                       WHEN COD_AZIENDA = '4006' THEN '2000'
                       WHEN COD_AZIENDA = '6000A' THEN '2000'
                       WHEN COD_AZIENDA IN ('1610','2070','2071') THEN '9999'
                  END
  WHERE COD_SCENARIO = V_SCENARIO
  AND COD_PERIODO = V_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
  AND COD_AZIENDA IN ('2091','2090','4006','6000A','1610','2070','2071')
  AND COD_CONTO NOT LIKE '%AD'
  ;
  COMMIT;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','冲销出库未开',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*
REV001_STEP_25(出库未开退货未办冲销) 20260512 ADD BY shiqingfeng.ex & yanheng.ex 新增 标记了出库未开&退货未办的总账凭证金额需要冲销
*/
INSERT /*+ PARALLEL(2) */   INTO AW_MR9_REVM01_000001_TEMP
(
OID,COD_SCENARIO,COD_PERIODO,COD_AZIENDA,COD_CATEGORIA,COD_CONTO,CUST_CODE,CUST_NAME,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,D_CHANNEL,D_MODE,D_ONOFFLINE,SALE_MODEL_CODE,MODEL_CODE,SHOP_CODE,SRC_SYSTEM,SOLD_TO_CODE,SOLD_TO_NAME,MATERIAL_GROUP_CODE,COD_AZI_CTP,BATCH_ID,D_PRC_GRP,COD_VALUTA_ORIGINARIA,SRC_DETAIL,PROVENIENZA,USERUPD,DATEUPD,BILL_QTY,SHIP_QTY,ORDER_QTY,SALE_REV,SALE_COGS,TAX_RATE,EXCHANGE_RATE,COD_DEST1,COD_DEST4,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_SSER,D_QUA_METHOD,D_PRO_STAGE,D_PRI_RANGE,D_PRO_SERIES,D_MARKET_PNT,D_TECH_TYPE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,SHOP_NAME,SALE_MODEL_NAME,MODEL_NAME,D_CNL_C_TYPE,D_IND_C_TYPE,D_ECOM_BU,D_SALE_DEPT,COD_DEST3
,D_BUS_SCE_S --业务场景分类
,AGENCY_CODE,AGENCY_NAME,IS_MINILED_CODE,CUSTOMER_MODEL,ORDER_TYPE_CODE,ZCALASSET,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,D_ADJ_TYPE,ORG_REV,MATERIAL_GROUP_NAME,BAC_SRC_AZIENDA,maktx_s810
,BCY_REV      --销售收入（含折扣）-本位币（调整进）
,MAP_REV      --销售收入（不含税不含折扣）-本位币（调整进）
,MAP_REV1     --还原兑现后收入-本位币（调整进）
,ORG_QTY      --销量1（原始销量；不含出库退货数量）
,MAP_QTY      --销量2（原始销量，含出库退货数量）
,MAP_ZUM      --折算销量
,CN_MAP_ZUM   --折算销量（中国区）
,CN_ORG_REV   --收入金额(含折扣）-净收入（中国区）
,MAP_DIS1     --收入折扣1(不含税)-本位币
,MAP_DIS3     --收入折扣3(不含税)-本位币
,MAP_DIS4     --收入折扣4(不含税)-本位币
,MAP_DIS5     --收入折扣5(不含税)-本位币
,MAP_DIS6     --收入折扣6(不含税)-本位币
,MAP_DIS30    --收入折扣30(不含税)-本位币
,MAP_DIS34    --收入折扣34(不含税)-本位币
,POLICY_AMT   --政策计提(不含税)-本位币
,AVG_UNIT_COST--平均单位成本
,BCY_COGS     --管报成本-本位币
,CN_SALE_COGS --管报成本（中国区）
,D_POL_CLASS  --政策二级分类
,D_MINILED
--20260917FJF_ADD 二期新增字段
,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)
SELECT
  NEWID() AS OID
  ,AW.COD_SCENARIO
  ,AW.COD_PERIODO
  ,AW.COD_AZIENDA
  ,AW.COD_CATEGORIA
  ,AW.COD_CONTO
  ,AW.CUST_CODE
  ,AW.CUST_NAME
  ,AW.MATERIAL_CODE
  ,AW.MATERIAL_NAME
  ,AW.COD_DEST2
  ,AW.D_CHANNEL
  ,AW.D_MODE
  ,AW.D_ONOFFLINE
  ,AW.SALE_MODEL_CODE
  ,AW.MODEL_CODE
  ,AW.SHOP_CODE
  ,AW.SRC_SYSTEM
  ,AW.SOLD_TO_CODE
  ,AW.SOLD_TO_NAME
  ,AW.MATERIAL_GROUP_CODE
  ,AW.COD_AZI_CTP
  ,AW.BATCH_ID
  ,AW.D_PRC_GRP
  ,AW.COD_VALUTA_ORIGINARIA
  ,'BSEG_TC' AS SRC_DETAIL
  ,'CPM_SP_D2M_REV_M' AS PROVENIENZA
  ,AW.USERUPD
  ,AW.DATEUPD
  ,0-AW.BILL_QTY AS BILL_QTY
  ,0-AW.SHIP_QTY AS SHIP_QTY
  ,0-AW.ORDER_QTY AS ORDER_QTY
  ,0-AW.SALE_REV AS SALE_REV
  ,0-SALE_COGS AS SALE_COGS
  ,AW.TAX_RATE
  ,AW.EXCHANGE_RATE
  ,AW.COD_DEST1
  ,AW.COD_DEST4
  ,AW.D_SPEC_SEC
  ,AW.D_PRO_TYPE_S
  ,AW.D_PRO_SSER
  ,AW.D_QUA_METHOD
  ,AW.D_PRO_STAGE
  ,AW.D_PRI_RANGE
  ,AW.D_PRO_SERIES
  ,AW.D_MARKET_PNT
  ,AW.D_TECH_TYPE
  ,AW.D_PRO_CLASS
  ,AW.D_MODEL_LCA
  ,AW.D_PRO_TYPE
  ,AW.CUST_UNITY_NAME
  ,AW.CREDIT_LEVEL_NAME
  ,AW.CUST_NATURE_NAME
  ,AW.CUST_TYPE_NAME
  ,AW.SHOP_NAME
  ,AW.SALE_MODEL_NAME
  ,AW.MODEL_NAME
  ,AW.D_CNL_C_TYPE
  ,AW.D_IND_C_TYPE
  ,AW.D_ECOM_BU
  ,AW.D_SALE_DEPT
  ,AW.COD_DEST3
  ,AW.D_BUS_SCE_S --业务场景分类
  ,AW.AGENCY_CODE
  ,AW.AGENCY_NAME
  ,AW.IS_MINILED_CODE
  ,AW.CUSTOMER_MODEL
  ,AW.ORDER_TYPE_CODE
  ,AW.ZCALASSET
  ,AW.CN_CLASS_MARK_CODE
  ,AW.CN_CLASS_MARK_NAME
  ,AW.SALE_CERT_TYPE
  ,AW.D_ADJ_TYPE
  ,0-AW.ORG_REV AS ORG_REV
  ,AW.MATERIAL_GROUP_NAME
  ,AW.BAC_SRC_AZIENDA
  ,AW.maktx_s810
  ,-1* BCY_REV       AS BCY_REV      --销售收入（含折扣）-本位币（调整进）
  ,-1* MAP_REV       AS MAP_REV      --销售收入（不含税不含折扣）-本位币（调整进）
  ,-1* MAP_REV1      AS MAP_REV1     --还原兑现后收入-本位币（调整进）
  ,-1* ORG_QTY       AS ORG_QTY      --销量1（原始销量；不含出库退货数量）
  ,-1* MAP_QTY       AS MAP_QTY      --销量2（原始销量，含出库退货数量）
  ,-1* MAP_ZUM       AS MAP_ZUM      --折算销量
  ,-1* CN_MAP_ZUM    AS CN_MAP_ZUM   --折算销量（中国区）
  ,-1* CN_ORG_REV    AS CN_ORG_REV   --收入金额(含折扣）-净收入（中国区）
  ,-1* MAP_DIS1      AS MAP_DIS1     --收入折扣1(不含税)-本位币
  ,-1* MAP_DIS3      AS MAP_DIS3     --收入折扣3(不含税)-本位币
  ,-1* MAP_DIS4      AS MAP_DIS4     --收入折扣4(不含税)-本位币
  ,-1* MAP_DIS5      AS MAP_DIS5     --收入折扣5(不含税)-本位币
  ,-1* MAP_DIS6      AS MAP_DIS6     --收入折扣6(不含税)-本位币
  ,-1* MAP_DIS30     AS MAP_DIS30    --收入折扣30(不含税)-本位币
  ,-1* MAP_DIS34     AS MAP_DIS34    --收入折扣34(不含税)-本位币
  ,-1* POLICY_AMT    AS POLICY_AMT   --政策计提(不含税)-本位币
  ,0-AVG_UNIT_COST AS AVG_UNIT_COST--平均单位成本
  ,0-BCY_COGS      AS BCY_COGS     --管报成本-本位币
  ,0-CN_SALE_COGS  AS CN_SALE_COGS --管报成本（中国区）
  ,D_POL_CLASS  --政策二级分类
  ,D_MINILED
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
FROM AW_MR9_REVM01_000001_TEMP AW
WHERE P_ORG_FLAG = 1
  AND AW.COD_SCENARIO = P_SCENARIO
  AND AW.COD_PERIODO = P_PERIODO
  AND AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, AW.COD_AZIENDA) > 0
  AND AW.PROVENIENZA = 'CPM_SP_D2M_REV_M'
  AND (AW.COD_CONTO LIKE 'S6001%' OR AW.COD_CONTO LIKE 'S6401%' )
  AND AW.SRC_SYSTEM = 'S600'
  AND AW.SRC_DETAIL IN ('BSEG','BSEG_FLJC','BSEG_REVM')
  --20260724-2 SHIQINGFENG.EX【REV001_STEP_25(出库未开退货未办冲销)】 业务场景分类限制条件新增024，025只有62，68开头的公司需要限制
  AND ((AW.D_BUS_SCE_S IN ('009','010','013','014')
        AND EXISTS (SELECT 1
               FROM TGK_FIMA_HISENSE.AW_RUL_CKTHAZ_000001 A
               /*20260915 10：14 shiqingfeng.ex 修改使用生产环境公司主数据*/
         LEFT JOIN TGK_FIMA_HISENSE.AZIENDA AZ
           ON AZ.COD_AZIENDA LIKE A.AZI_RANGE
              WHERE VALID_FR <= V_YEARMONTH
                AND NVL(VALID_TO,'999999') >= V_YEARMONTH
                AND AZ.COD_AZIENDA = AW.COD_AZIENDA
        )
        )
       OR (AW.D_BUS_SCE_S IN ('024','025') AND (AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%'))
       )

  ;
COMMIT;

/*币种为空或者为ZZZZ字段更新-交易币--更新成人民币  本位币--公司所属币种*/
MERGE  /*+ USE_HASH(T C) */ INTO AW_MR9_REVM01_000001_TEMP T
USING (
    SELECT COD_AZIENDA, COD_VALUTA
    FROM TGK_FIMA_HISENSE.AZIENDA
) C
ON (
     T.COD_AZIENDA = C.COD_AZIENDA

)
WHEN MATCHED THEN UPDATE
SET T.COD_VALUTA = C.COD_VALUTA
WHERE T.COD_SCENARIO   = P_SCENARIO
  AND T.COD_PERIODO     = P_PERIODO
  AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  --AND INSTR(V_AZIENDA, T.COD_AZIENDA) > 0
  AND NVL(T.COD_VALUTA, 'ZZZZ') = 'ZZZZ'
  AND T.PROVENIENZA = 'CPM_SP_D2M_REV_M'
  ;


UPDATE AW_MR9_REVM01_000001_TEMP ss
   SET SS.COD_VALUTA_ORIGINARIA = 'CNY'
 WHERE  1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND NVL(COD_VALUTA_ORIGINARIA,'ZZZZ') = 'ZZZZ'
    AND PROVENIENZA = 'CPM_SP_D2M_REV_M'
  ;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','客商信息和物料信息补充开始',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


MERGE  /*+ USE_HASH(T C) */ INTO AW_MR9_REVM01_000001_TEMP T
USING (

SELECT distinct

       CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.product_name ELSE AW.MATERIAL_NAME END AS MATERIAL_NAME  --物料描述
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.market_pos_code ELSE AW.D_MARKET_PNT END AS D_MARKET_PNT  --营销定位
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.prod_suite_code ELSE AW.D_PRO_SSER END AS D_PRO_SSER  --产品套系
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CASE WHEN MARA.big_class_code = 'P01' THEN MARA.SCREEN_SIZE_CODE
                      WHEN MARA.big_class_code = 'P02' THEN MARA.SPEC_RANGE_CODE
                      WHEN MARA.big_class_code = 'P03' THEN MARA.TOTAL_CAPACITY_CODE
                      WHEN MARA.big_class_code = 'P04' THEN MARA.WASHING_CAPACITY_CODE
                 END
            ELSE AW.D_SPEC_SEC END AS D_SPEC_SEC  --规格
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.product_spec_code ELSE AW.D_PRO_TYPE_S END AS D_PRO_TYPE_S  --产品形态分类
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.prod_stage_code ELSE AW.D_PRO_STAGE END AS D_PRO_STAGE  --产品阶段
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.price_range_code ELSE AW.D_PRI_RANGE END AS D_PRI_RANGE  --价格段
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.series_code ELSE AW.D_PRO_SERIES END AS D_PRO_SERIES  --产品系列
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.ac_ct_code ELSE AW.D_TECH_TYPE END AS D_TECH_TYPE  --技术类型
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CASE WHEN MARA.is_miniled_code = 'PC00013001' THEN '是'
                      WHEN MARA.is_miniled_code = 'PC00013002' THEN '否'
                      ELSE ''
                 END
            ELSE AW.IS_MINILED_CODE END AS IS_MINILED_CODE  --是否MiniLED
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.small_class_code ELSE AW.D_PRO_CLASS END AS D_PRO_CLASS  --产品类别（产品大中小类）
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.model_lca ELSE AW.D_MODEL_LCA END AS D_MODEL_LCA  --产品型号生命周期
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.MODEL_CODE ELSE AW.MODEL_CODE END AS MODEL_CODE  --产品型号
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.model_name ELSE AW.MODEL_NAME END AS MODEL_NAME  --产品型号
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CASE WHEN AZ.SAP_VERSION IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                     ELSE LTRIM(mara.matkl,'0')
                END
            ELSE AW.MATERIAL_GROUP_CODE END AS MATERIAL_GROUP_CODE  --物料组
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.miniled_type_code ELSE AW.D_MINILED END AS D_MINILED  --miniled类型
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN COALESCE(
                     NULLIF(UPPER(MARA.sale_model_name), '无'),
                     NULLIF(UPPER(MARA.zcusmodel),       '无')
                 )
            ELSE AW.customer_model END AS customer_model  --客户型号

     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN KNA1.name1 ELSE AW.CUST_NAME END AS CUST_NAME  --客商描述
     , CASE WHEN NVL(LTRIM(AW.D_CHANNEL),'ZZZZ') = 'ZZZZ'
            /* ALTER BY 20260820-2 SHIQINGFENG.EX 新增公司三级分类更新逻辑与D表一致*/
            THEN CASE
                      WHEN AW.D_ONOFFLINE = '020_ON_003'
                       AND AW.COD_AZIENDA IN ('2600', '6746', '6750', '6800', '6847')
                       AND AW.cust_code = '2031242'
                      THEN 'E4'
                      WHEN AW.D_ONOFFLINE = '020_ON_003'
                       AND AW.COD_AZIENDA IN ('2600', '6746', '6847')
                       AND AW.cust_code = '2030797'
                      THEN 'F4'
                      WHEN AW.D_ONOFFLINE = '020_ON_003'
                       AND AW.COD_AZIENDA IN ('2600', '6746', '6800')
                       AND AW.cust_code = '2018577'
                      THEN 'F4'
                      WHEN (AW.COD_AZIENDA = '1180' OR AW.COD_AZIENDA LIKE '12%')
                       AND ecom_map.channel_code_l3 IS NOT NULL
                      THEN ecom_map.channel_code_l3
                      ELSE nvl(CUST_INFO_sold.com_3rd_code,CUST_INFO.com_3rd_code)
                  END
            ELSE AW.D_CHANNEL
       END AS D_CHANNEL  --公司三级分类
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CUST_TRADE_INFO.MARKET_MODE_CODE ELSE AW.D_MODE END AS D_MODE  --营销模式
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CUST_INFO.channel_small_class_code ELSE AW.D_CNL_C_TYPE END AS D_CNL_C_TYPE  --渠道客户小类
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CUST_INFO.ind_small_class_code ELSE AW.D_IND_C_TYPE END AS D_IND_C_TYPE  --行业客户小类
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CUST_INFO.cust_unity_name ELSE AW.CUST_UNITY_NAME END AS CUST_UNITY_NAME  --统一客户组
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CUST_INFO.credit_level ELSE AW.CREDIT_LEVEL_NAME END AS CREDIT_LEVEL_NAME  --信用等级
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CUST_INFO.unit_nature_name ELSE AW.CUST_NATURE_NAME END AS CUST_NATURE_NAME  --单位性质
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CASE
                   WHEN CUST_INFO.is_channel_cust_type IS NULL
                    AND CUST_INFO.is_ent_cust_type IS NULL
                    AND CUST_INFO.is_fi_cust_type IS NULL
                   THEN NULL
                   ELSE REGEXP_REPLACE(
                       CASE WHEN CUST_INFO.is_channel_cust_type = 'Y' THEN ',渠道客户(经营)' ELSE '' END ||
                       CASE WHEN CUST_INFO.is_ent_cust_type = 'Y' THEN ',企事业单位(消费)' ELSE '' END ||
                       CASE WHEN CUST_INFO.is_fi_cust_type = 'Y' THEN ',财务类客户' ELSE '' END
                       , '^,|,$'
                       , ''
                     )
                 END
            ELSE AW.CUST_TYPE_NAME END AS CUST_TYPE_NAME  --客户类型
     , CASE WHEN NVL(LTRIM(AW.sold_to_code),'ZZZZ') <> 'ZZZZ'
            THEN KNA1_sold.name1 ELSE AW.sold_to_name END AS sold_to_name  --售达方名称

     , OID
     --20260917FJF_ADD 二期新增字段
    , CASE WHEN nvl(aw.D_EFF_CLASS,'|') = '|' OR aw.D_EFF_CLASS = 'ZZZZ' OR MARA.ee_level_code <> aw.D_EFF_CLASS
           THEN MARA.ee_level_code
           ELSE aw.D_EFF_CLASS
      END AS D_EFF_CLASS
    , CASE WHEN nvl(aw.D_BU_SHOP,'|') = '|' OR aw.D_BU_SHOP = 'ZZZZ' OR CUST_INFO.bu_code <> aw.D_BU_SHOP
           THEN CUST_INFO.bu_code
           ELSE aw.D_BU_SHOP
      END AS D_BU_SHOP

     , CASE WHEN nvl(aw.D_UNICUSTGRP,'|') = '|' OR aw.D_UNICUSTGRP = 'ZZZZ' OR CUST_INFO.cust_unity_code <> aw.D_UNICUSTGRP
           THEN CUST_INFO.cust_unity_code
           ELSE aw.D_UNICUSTGRP
      END AS D_UNICUSTGRP
  FROM
(
-- AW子查询：从目标表中取出所有需要保留原值的字段
SELECT OID
     , COD_AZIENDA
     , CUST_CODE
     , sold_to_code
     , MATERIAL_CODE
     , MATERIAL_GROUP_CODE
     -- 物料相关原值字段
     , MATERIAL_NAME
     , D_MARKET_PNT
     , D_PRO_SSER
     , D_SPEC_SEC
     , D_PRO_TYPE_S
     , D_PRO_STAGE
     , D_PRI_RANGE
     , D_PRO_SERIES
     , D_TECH_TYPE
     , IS_MINILED_CODE
     , D_PRO_CLASS
     , D_MODEL_LCA
     , MODEL_CODE
     , MODEL_NAME
     , D_MINILED
     , customer_model
     -- 客商相关原值字段
     , CUST_NAME
     , D_CHANNEL
     , D_MODE
     , D_CNL_C_TYPE
     , D_IND_C_TYPE
     , CUST_UNITY_NAME
     , CREDIT_LEVEL_NAME
     , CUST_NATURE_NAME
     , CUST_TYPE_NAME
     , sold_to_name
     , D_ECOM_BU
     , D_ONOFFLINE
    --20260917FJF_ADD 二期新增字段
          ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
  FROM AW_MR9_REVM01_000001_TEMP T
 WHERE 1=1
   AND COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M')
        )
   AND SRC_DETAIL IN ('ADJM01','ADJ_DI','REV_CIS','REVM01','POLICY_YT'
   ,'VBRP','ZTSO04_CK','ZTSO04_CK_LM','ZTSO04_TH','ZTSO04_TH_LM'
   ,'无销量收入','不进行分摊','按销量占比-6401','按收入占比-6401','ADJ_DI_MAG'

   )
) AW
LEFT JOIN (SELECT COD_AZIENDA,'S'||CITTA_LEGALE SAP_VERSION FROM TGK_FIMA_HISENSE.AZIENDA) AZ
  ON AW.COD_AZIENDA = AZ.COD_AZIENDA
LEFT JOIN
(
SELECT 'S'||MANDT AS SAP_VERSION,KUNNR,zkunnr_mdg,name1 FROM TGK_FIMA_HISENSE.DS_DWD_SAP_KNA1
) KNA1
  ON AZ.SAP_VERSION = KNA1.SAP_VERSION
 AND LTRIM(KNA1.kunnr,'0') = AW.CUST_CODE

LEFT JOIN
(
SELECT 'S'||MANDT AS SAP_VERSION,KUNNR,zkunnr_mdg,name1 FROM TGK_FIMA_HISENSE.DS_DWD_SAP_KNA1
) KNA1_sold
  ON AZ.SAP_VERSION = KNA1_sold.SAP_VERSION
 AND LTRIM(KNA1_sold.kunnr,'0') = AW.sold_to_code

LEFT JOIN TGK_FIMA_HISENSE.DIM_CUSTOMER_BASE_INFO_DD CUST_INFO
  ON LTRIM(KNA1.zkunnr_mdg,'0') = LTRIM(CUST_INFO.cust_code,'0')

LEFT JOIN TGK_FIMA_HISENSE.DIM_CUSTOMER_BASE_INFO_DD CUST_INFO_sold
  ON LTRIM(KNA1_sold.zkunnr_mdg,'0') = LTRIM(CUST_INFO_sold.cust_code,'0')

LEFT JOIN TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD MARA
  ON MARA.matnr = AW.MATERIAL_CODE
LEFT JOIN TGK_FIMA_HISENSE.DIM_CUSTOMER_TRADE_INFO_DD CUST_TRADE_INFO
  ON LTRIM(KNA1.zkunnr_mdg,'0') = LTRIM(CUST_TRADE_INFO.cust_code,'0')
 AND AW.COD_AZIENDA = CUST_TRADE_INFO.sale_org
 AND CASE WHEN NVL(LTRIM(AW.MATERIAL_GROUP_CODE),'|') = '|' OR AW.MATERIAL_GROUP_CODE = 'ZZZZ'
           THEN CASE WHEN AZ.SAP_VERSION IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                ELSE LTRIM(mara.matkl,'0')
                END
           ELSE AW.MATERIAL_GROUP_CODE
      END  = CUST_TRADE_INFO.material_group_code

LEFT JOIN (
  SELECT LTRIM(cust_code,'0') AS kunrg
        ,cp_company_code AS COD_AZI_CTP
        ,system_src AS system_src
    FROM TGK_FIMA_HISENSE.dim_rule_fi_mr_cust2ctp_mapping a
  WHERE cust_type_code = 'C'
    AND NVL(valid_fr,'202401') <= V_YEARMONTH
    AND NVL(valid_to,'999999') >= V_YEARMONTH
) CTP
ON CTP.kunrg = AW.CUST_CODE
AND CTP.system_src = AZ.SAP_VERSION
LEFT JOIN (SELECT ecom_code,MAX(channel_code_l3) AS channel_code_l3,MAX(channel_name_l3) AS channel_name_l3
             FROM TGK_FIMA_HISENSE.dim_rule_fi_mr_ecom_channel3_mapping
            GROUP BY ecom_code
          ) ecom_map
ON (AW.COD_AZIENDA = '1180' OR AW.COD_AZIENDA LIKE '12%')
AND AW.D_ECOM_BU = ecom_map.ecom_code
) C
ON(
   T.OID = C.OID
)
WHEN MATCHED THEN
UPDATE SET
       T.MATERIAL_NAME      = C.MATERIAL_NAME       -- 物料描述
      ,T.D_MARKET_PNT       = C.D_MARKET_PNT        -- 营销定位
      ,T.D_PRO_SSER         = C.D_PRO_SSER          -- 产品套系
      ,T.D_SPEC_SEC         = C.D_SPEC_SEC          -- 规格
      ,T.D_PRO_TYPE_S       = C.D_PRO_TYPE_S        -- 产品形态分类
      ,T.D_PRO_STAGE        = C.D_PRO_STAGE         -- 产品阶段
      ,T.D_PRI_RANGE        = C.D_PRI_RANGE         -- 价格段
      ,T.D_PRO_SERIES       = C.D_PRO_SERIES        -- 产品系列
      ,T.D_TECH_TYPE        = C.D_TECH_TYPE         -- 技术类型
      ,T.IS_MINILED_CODE    = C.IS_MINILED_CODE     -- 是否MiniLED
      ,T.D_PRO_CLASS        = C.D_PRO_CLASS          -- 产品类别（产品大中小类）
      ,T.D_MODEL_LCA        = C.D_MODEL_LCA         -- 产品型号生命周期
      ,T.MODEL_CODE         = C.MODEL_CODE          -- 产品型号编码
      ,T.MODEL_NAME         = C.MODEL_NAME          -- 产品型号名称
      ,T.MATERIAL_GROUP_CODE= C.MATERIAL_GROUP_CODE  -- 物料组
      ,T.D_MINILED          = C.D_MINILED           -- miniled类型
      ,T.customer_model     = C.customer_model      -- 客户型号
      ,T.CUST_NAME          = C.CUST_NAME           -- 客商描述
      ,T.D_CHANNEL          = C.D_CHANNEL           -- 公司三级分类
      ,T.D_MODE             = C.D_MODE              -- 营销模式
      ,T.D_CNL_C_TYPE       = C.D_CNL_C_TYPE        -- 渠道客户小类
      ,T.D_IND_C_TYPE       = C.D_IND_C_TYPE        -- 行业客户小类
      ,T.CUST_UNITY_NAME    = C.CUST_UNITY_NAME     -- 统一客户组
      ,T.CREDIT_LEVEL_NAME  = C.CREDIT_LEVEL_NAME   -- 信用等级
      ,T.CUST_NATURE_NAME   = C.CUST_NATURE_NAME    -- 单位性质
      ,T.CUST_TYPE_NAME     = C.CUST_TYPE_NAME      -- 客户类型
      ,T.sold_to_name       = C.sold_to_name        -- 售达方名称
      --20260917FJF_ADD 二期新增字段
      , T.D_EFF_CLASS = C.D_EFF_CLASS
      , T.D_BU_SHOP = C.D_BU_SHOP
      , T.D_UNICUSTGRP = C.D_UNICUSTGRP
;


COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','维度默认ZZZZ开始',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*将维度为空的更新为ZZZZ*/
UPDATE AW_MR9_REVM01_000001_TEMP
SET
   D_PRC_GRP    = CASE WHEN NVL(LTRIM(D_PRC_GRP),   '|') = '|' THEN 'ZZZZ' ELSE D_PRC_GRP    END
  ,D_SALE_DEPT  = CASE WHEN NVL(LTRIM(D_SALE_DEPT), '|') = '|' THEN 'ZZZZ' ELSE D_SALE_DEPT  END
  ,D_DIFF_TYPE  = CASE WHEN NVL(LTRIM(D_DIFF_TYPE), '|') = '|' THEN 'ZZZZ' ELSE D_DIFF_TYPE  END
  ,D_MARKET_PNT = CASE WHEN NVL(LTRIM(D_MARKET_PNT),'|') = '|' THEN 'ZZZZ' ELSE D_MARKET_PNT END
  ,D_PRO_SSER   = CASE WHEN NVL(LTRIM(D_PRO_SSER),  '|') = '|' THEN 'ZZZZ' ELSE D_PRO_SSER   END
  ,D_SPEC_SEC   = CASE WHEN NVL(LTRIM(D_SPEC_SEC),  '|') = '|' THEN 'ZZZZ' ELSE D_SPEC_SEC   END
  ,D_PRO_TYPE_S = CASE WHEN NVL(LTRIM(D_PRO_TYPE_S),'|') = '|' THEN 'ZZZZ' ELSE D_PRO_TYPE_S END
  ,D_QUA_METHOD = CASE WHEN NVL(LTRIM(D_QUA_METHOD),'|') = '|' THEN 'ZZZZ' ELSE D_QUA_METHOD END
  ,D_PRO_STAGE  = CASE WHEN NVL(LTRIM(D_PRO_STAGE), '|') = '|' THEN 'ZZZZ' ELSE D_PRO_STAGE  END
  ,D_PRI_RANGE  = CASE WHEN NVL(LTRIM(D_PRI_RANGE), '|') = '|' THEN 'ZZZZ' ELSE D_PRI_RANGE  END
  ,D_PRO_SERIES = CASE WHEN NVL(LTRIM(D_PRO_SERIES),'|') = '|' THEN 'ZZZZ' ELSE D_PRO_SERIES END
  ,D_TECH_TYPE  = CASE WHEN NVL(LTRIM(D_TECH_TYPE), '|') = '|' THEN 'ZZZZ' ELSE D_TECH_TYPE  END
  ,D_MODEL_LCA  = CASE WHEN NVL(LTRIM(D_MODEL_LCA), '|') = '|' THEN 'ZZZZ' ELSE D_MODEL_LCA  END
  ,D_PRO_TYPE   = CASE WHEN NVL(LTRIM(D_PRO_TYPE),  '|') = '|' THEN 'ZZZZ' ELSE D_PRO_TYPE   END
  ,D_POL_CLASS  = CASE WHEN NVL(LTRIM(D_POL_CLASS), '|') = '|' THEN 'ZZZZ' ELSE D_POL_CLASS  END
  ,D_CHANNEL    = CASE WHEN NVL(LTRIM(D_CHANNEL),   '|') = '|' THEN 'ZZZZ' ELSE D_CHANNEL    END
  ,D_MODE       = CASE WHEN NVL(LTRIM(D_MODE),      '|') = '|' THEN 'ZZZZ' ELSE D_MODE       END
  ,D_ONOFFLINE  = CASE WHEN NVL(LTRIM(D_ONOFFLINE), '|') = '|' THEN 'ZZZZ' ELSE D_ONOFFLINE  END
  ,D_ECOM_BU    = CASE WHEN NVL(LTRIM(D_ECOM_BU),   '|') = '|' THEN 'ZZZZ' ELSE D_ECOM_BU    END
  ,D_IND_C_TYPE = CASE WHEN NVL(LTRIM(D_IND_C_TYPE),'|') = '|' THEN 'ZZZZ' ELSE D_IND_C_TYPE END
  ,D_CNL_C_TYPE = CASE WHEN NVL(LTRIM(D_CNL_C_TYPE),'|') = '|' THEN 'ZZZZ' ELSE D_CNL_C_TYPE END
  ,D_BU_TRAN    = CASE WHEN NVL(LTRIM(D_BU_TRAN),   '|') = '|' THEN 'ZZZZ' ELSE D_BU_TRAN    END
  ,D_ADJ_TYPE   = CASE WHEN NVL(LTRIM(D_ADJ_TYPE),  '|') = '|' THEN 'ZZZZ' ELSE D_ADJ_TYPE   END
  ,D_OPER_TYPE  = CASE WHEN NVL(LTRIM(D_OPER_TYPE), '|') = '|' THEN 'ZZZZ' ELSE D_OPER_TYPE  END
  ,D_BUS_SCE_S  = CASE WHEN NVL(LTRIM(D_BUS_SCE_S), '|') = '|' THEN 'ZZZZ' ELSE D_BUS_SCE_S  END
  ,D_MINILED    = CASE WHEN NVL(LTRIM(D_MINILED),   '|') = '|' THEN 'ZZZZ' ELSE D_MINILED    END
  ,COD_DEST1    = CASE WHEN NVL(LTRIM(COD_DEST1),   '|') = '|' THEN 'ZZZZ' ELSE COD_DEST1    END
  ,COD_DEST2    = CASE WHEN NVL(LTRIM(COD_DEST2),   '|') = '|' THEN 'ZZZZ' ELSE COD_DEST2    END
  ,COD_DEST3    = CASE WHEN NVL(LTRIM(COD_DEST3),   '|') = '|' THEN 'ZZZZ' ELSE COD_DEST3    END
  ,COD_DEST4    = CASE WHEN NVL(LTRIM(COD_DEST4),   '|') = '|' THEN 'ZZZZ' ELSE COD_DEST4    END
  ,COD_CATEGORIA = CASE WHEN NVL(LTRIM(COD_CATEGORIA),   '|') = '|' THEN 'ZAMOUNT' ELSE COD_CATEGORIA    END
  --20260917FJF_ADD 二期新增字段
  ,D_EFF_CLASS = CASE WHEN NVL(LTRIM(D_EFF_CLASS),   '|') = '|' THEN 'ZZZZ' ELSE D_EFF_CLASS    END
  ,D_BU_SHOP = CASE WHEN NVL(LTRIM(D_BU_SHOP),   '|') = '|' THEN 'ZZZZ' ELSE D_BU_SHOP    END
  ,D_EC_STORE = CASE WHEN NVL(LTRIM(D_EC_STORE),   '|') = '|' THEN 'ZZZZ' ELSE D_EC_STORE    END
  ,D_UNICUSTGRP = CASE WHEN NVL(LTRIM(D_UNICUSTGRP),   '|') = '|' THEN 'ZZZZ' ELSE D_UNICUSTGRP    END
WHERE 1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )
    AND (
    -- 只处理至少有一个 D_ 字段为空的行
       NVL(LTRIM(D_PRC_GRP),   '|') = '|'
    OR NVL(LTRIM(D_SALE_DEPT), '|') = '|'
    OR NVL(LTRIM(D_DIFF_TYPE), '|') = '|'
    OR NVL(LTRIM(D_MARKET_PNT),'|') = '|'
    OR NVL(LTRIM(D_PRO_SSER),  '|') = '|'
    OR NVL(LTRIM(D_SPEC_SEC),  '|') = '|'
    OR NVL(LTRIM(D_PRO_TYPE_S),'|') = '|'
    OR NVL(LTRIM(D_QUA_METHOD),'|') = '|'
    OR NVL(LTRIM(D_PRO_STAGE), '|') = '|'
    OR NVL(LTRIM(D_PRI_RANGE), '|') = '|'
    OR NVL(LTRIM(D_PRO_SERIES),'|') = '|'
    OR NVL(LTRIM(D_TECH_TYPE), '|') = '|'
    OR NVL(LTRIM(D_MODEL_LCA), '|') = '|'
    OR NVL(LTRIM(D_PRO_TYPE),  '|') = '|'
    OR NVL(LTRIM(D_POL_CLASS), '|') = '|'
    OR NVL(LTRIM(D_CHANNEL),   '|') = '|'
    OR NVL(LTRIM(D_MODE),      '|') = '|'
    OR NVL(LTRIM(D_ONOFFLINE), '|') = '|'
    OR NVL(LTRIM(D_ECOM_BU),   '|') = '|'
    OR NVL(LTRIM(D_IND_C_TYPE),'|') = '|'
    OR NVL(LTRIM(D_CNL_C_TYPE),'|') = '|'
    OR NVL(LTRIM(D_BU_TRAN),   '|') = '|'
    OR NVL(LTRIM(D_ADJ_TYPE),  '|') = '|'
    OR NVL(LTRIM(D_OPER_TYPE), '|') = '|'
    OR NVL(LTRIM(D_BUS_SCE_S), '|') = '|'
    OR NVL(LTRIM(D_MINILED),   '|') = '|'
    OR NVL(LTRIM(COD_DEST2),   '|') = '|'
    OR NVL(LTRIM(COD_DEST3),   '|') = '|'
    OR NVL(LTRIM(COD_DEST4),   '|') = '|'
    OR NVL(LTRIM(COD_CATEGORIA),   '|') = '|'
    --20260917FJF_ADD 二期新增字段
    OR NVL(LTRIM(D_EFF_CLASS),   '|') = '|'
    OR NVL(LTRIM(D_BU_SHOP),   '|') = '|'
    OR NVL(LTRIM(D_EC_STORE),   '|') = '|'
    OR NVL(LTRIM(D_UNICUSTGRP),   '|') = '|'
    )
;
COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','维度信息补充结束',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*20260820-4 取消折算销量-标准量逻辑，直接去D表字段*/
/*REV001_STEP_12(折算销量-标准量逻辑处理) */
/*UPDATE AW_MR9_REVM01_000001_TEMP A
SET STD_QTY = CASE \*WHEN COD_CONTO IN ('S600100','S600100AD')
                     THEN BILL_QTY*\
                   WHEN COD_CONTO IN ('S600101','S600101AD')
                     THEN (SHIP_QTY-BILL_QTY)*(SELECT NVL(MA.SALE_STD_QTY,0) FROM TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD MA WHERE A.MATERIAL_CODE = MA.MATNR)
                   \*WHEN COD_CONTO IN ( 'S600102','S600102AD')
                     THEN BILL_QTY*\
                   ELSE BILL_QTY*(SELECT NVL(SALE_STD_QTY,0) FROM TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD MA WHERE A.MATERIAL_CODE = MA.MATNR)
              END
  WHERE 1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )
    ;*/
INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','成本重算开始',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

/*成本重算*/
/* ALTER BY 20261009 LICHENG.EX
   修改事项：按外层实际P_ORG_FLAG，仅将本次刷新的S6401成本SALE_COGS写入SH_BF_SALE_COGS，作为后续完整分摊的原始成本。 */
UPDATE AW_MR9_REVM01_000001_TEMP A
   SET A.SH_BF_SALE_COGS = A.SALE_COGS
 WHERE A.COD_SCENARIO = P_SCENARIO
   AND A.COD_PERIODO = P_PERIODO
   AND A.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND A.COD_CONTO LIKE 'S6401%'
   AND (
         (P_ORG_FLAG = 1 AND A.PROVENIENZA IN ('CPM_SP_D2M_REV_M','CPM_SP_A2M_REV_M'))
         OR
         (P_ORG_FLAG = 2
          AND A.PROVENIENZA = 'CPM_SP_D2M_REV_M'
          AND A.COD_CONTO LIKE '%AD'
          AND NVL(A.SRC_DETAIL,'REV_CIS') <> 'REV_CIS')
         OR
         (P_ORG_FLAG = 3 AND A.NOTE = 'CPM_SP_A2M_REV_M')
       )
;
COMMIT;

CPM_SP_M2M_REV_6401_M(P_SCENARIO,P_PERIODO,V_AZIENDA,SESSION_USER);

/*成本重算数据删除*/
/*DELETE AW_MR9_REVM01_000001_TEMP
WHERE COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST S1
                         WHERE SESSION_ID = V_SESSION_ID
                           AND ELEM NOT LIKE '12%'
                           AND ELEM NOT IN ('1180','6240','2023')
                           AND ELEM NOT LIKE '17%'
                           AND NOT EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S2
                                         WHERE S1.SESSION_ID =S2.SESSION_ID AND S2.ELEM =S1.ELEM
                                         AND S2.HIE = '10'  AND S2.NODE IN ('020')
                                        )
                        )*/

    /*AND COD_AZIENDA NOT IN (SELECT DISTINCT ELEM
                            FROM SESSION_V_REF_AZIENDA
                            WHERE SESSION_ID = V_SESSION_ID AND node = '020'
                            )*/
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    /*AND COD_CONTO LIKE 'S6401%'*/
    --AND COD_AZIENDA NOT LIKE '12%'
    --AND COD_AZIENDA NOT IN ('1180','6240','2023')
    --AND COD_AZIENDA NOT like '17%'
    /*AND PROVENIENZA IN ('CPM_SP_D2M_REV_M','CPM_SP_A2M_REV_M')

;
COMMIT;*/

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','成本重算结束',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;


/*UPDATE AW_MR9_REVM01_000001_TEMP
SET MATERIAL_CODE = ''
WHERE 1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN ('6012')
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  AND MATERIAL_CODE <> 'XN-MATNR'
  AND MATERIAL_CODE NOT IN (SELECT MATNR FROM TGK_FIMA_HISENSE.DIM_FI_MR_PRODUCT_DD)
  ;

COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','物料重置为空结束',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;*/




--20261027fjf_add REV001_STEP_999 二期新增维度特殊处理
MERGE INTO AW_MR9_REVM01_000001_TEMP T
USING(
    SELECT S.OID,
      NVL(COALESCE(CHAN.tov_channel_code,CHAN2.tov_channel_code),'ZZZZ') AS D_TOV_CHAN,
      NVL(crg.crg_cust_group_code,'ZZZZ') AS D_CC_CUSTGRP
    FROM(
        SELECT OID,COD_AZIENDA,CUST_CODE,D_CHANNEL
        FROM AW_MR9_REVM01_000001_TEMP
        WHERE COD_SCENARIO = P_SCENARIO
        AND COD_PERIODO  = P_PERIODO
        AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID )
      )S
    LEFT JOIN
    (
      SELECT DISTINCT company_code,cust_code,tov_channel_code
      FROM TGK_FIMA_HISENSE.dim_rule_fi_mr_ar_tov_channel_mapping
      WHERE batch_id = '1'
    ) CHAN
    ON S.COD_AZIENDA LIKE CHAN.company_code
    AND S.CUST_CODE = CHAN.cust_code
    LEFT JOIN
    (
      SELECT DISTINCT company_code,channel_l3_code,tov_channel_code
      FROM TGK_FIMA_HISENSE.dim_rule_fi_mr_ar_tov_channel_mapping
      WHERE batch_id = '2'
    ) CHAN2
    ON S.COD_AZIENDA LIKE CHAN2.company_code
    AND S.D_CHANNEL = CHAN2.channel_l3_code
    LEFT JOIN
    (
      SELECT company_code_mdg,LTRIM(cust_sap_code,'0') AS cust_sap_code,crg_cust_group_code
      FROM TGK_FIMA_HISENSE.dim_customer_company_info_dd
      WHERE CRG_CUST_GROUP_CODE IS NOT NULL
    ) crg
    ON crg.company_code_mdg = S.COD_AZIENDA
    AND crg.cust_sap_code = S.CUST_CODE

  ) SRC
ON (T.OID = SRC.OID)
WHEN MATCHED THEN UPDATE SET
    T.D_TOV_CHAN = NVL(SRC.D_TOV_CHAN,'ZZZZ'),
    T.D_CC_CUSTGRP = NVL(SRC.D_CC_CUSTGRP,'ZZZZ')
;

INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M', 'REV001_STEP_999 二期新增维度特殊处理', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO,P_AZIENDA);





/*2.1 当期数据删除*/
 DELETE FROM AW_MR9_REVM01_000001 T
  WHERE 1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    -- AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    /*AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )*/
    ;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','96 当期数据删除结束',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);


/*2.1 当期数据从临时表插入数据*/
INSERT INTO AW_MR9_REVM01_000001(
OID, COD_SCENARIO, COD_PERIODO, SHOP_CODE, COD_AZIENDA, COD_DEST1, COD_AZI_CTP, D_PRC_GRP, COD_CONTO, D_SALE_DEPT, COD_DEST3, COD_CATEGORIA, D_PRO_CLASS, D_DATA_BLOCK, D_DIFF_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_QUA_METHOD, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_MODEL_LCA, D_PRO_TYPE, SALE_MODEL_NAME, D_POL_CLASS, MODEL_NAME, CUST_CODE, MODEL_CODE, SALE_MODEL_CODE, CUST_NAME, D_CHANNEL, D_MODE, D_ONOFFLINE, D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, D_IND_C_TYPE, D_CNL_C_TYPE, COD_VALUTA, SHIP_QTY, COD_VALUTA_ORIGINARIA, ORDER_QTY, BILL_QTY, SALE_REV, DISCOUNT_3, DISCOUNT_4, DISCOUNT_5, DISCOUNT_6, TAX_RATE, EXCHANGE_RATE, ORG_QTY, MAP_QTY, ORG_REV, MAP_REV, MAP_REV1, MAP_DIS3, MAP_DIS4, MAP_DIS5, MAP_DIS6, POLICY_AMT, BATCH_ID, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, SRC_SYSTEM, SRC_DETAIL, SHOP_NAME, AGENCY_CODE, AGENCY_NAME, IS_MINILED_CODE, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, SALE_COGS, DISCOUNT_1, MAP_DIS1, DISCOUNT_30, DISCOUNT_34, MAP_DIS30, MAP_DIS34, NOTE, D_BU_TRAN, CUSTOMER_MODEL, ORDER_TYPE_CODE, ZCALASSET, CALC_RULE, STATUTORY_ACCT_CODE, MAP_ZUM, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, D_ADJ_TYPE, CHANGE_COEFFICIENT, GFCFY_AMOUNT, GFCFL_AMOUNT, D_OPER_TYPE, BCY_REV, BCY_COGE, BCY_COGS, MATERIAL_GROUP_NAME, ORG_GP, AVG_UNIT_COST, BAC_AZIENDA, BAC_SRC_AZIENDA, MAKTX_S810
,D_BUS_SCE_S --业务场景分类
,IS_SMALL_B
,D_MINILED
,INVOICE_CODE
,STD_QTY
,ZA_SALE_COGS
,MA_SALE_COGS
,SH_BF_SALE_COGS
,CALC_RULE_1
,Shipping_Order
--20260917FJF_ADD 二期新增字段
,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP
)
SELECT OID, COD_SCENARIO, COD_PERIODO, SHOP_CODE, COD_AZIENDA, COD_DEST1
, COD_AZI_CTP
, D_PRC_GRP, COD_CONTO, D_SALE_DEPT, COD_DEST3, COD_CATEGORIA, D_PRO_CLASS, D_DATA_BLOCK, D_DIFF_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_QUA_METHOD, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_MODEL_LCA, D_PRO_TYPE, SALE_MODEL_NAME, D_POL_CLASS, MODEL_NAME, CUST_CODE, MODEL_CODE, SALE_MODEL_CODE, CUST_NAME, D_CHANNEL, D_MODE, D_ONOFFLINE, D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, D_IND_C_TYPE, D_CNL_C_TYPE, COD_VALUTA, SHIP_QTY, COD_VALUTA_ORIGINARIA, ORDER_QTY, BILL_QTY, SALE_REV, DISCOUNT_3, DISCOUNT_4, DISCOUNT_5, DISCOUNT_6, TAX_RATE, EXCHANGE_RATE, ORG_QTY, MAP_QTY, ORG_REV
, CASE WHEN COD_CONTO LIKE '%AD' AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS' THEN BCY_REV ELSE MAP_REV END AS MAP_REV
, CASE WHEN COD_CONTO LIKE '%AD' AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS' THEN BCY_REV ELSE MAP_REV1 END AS MAP_REV1
, MAP_DIS3, MAP_DIS4, MAP_DIS5, MAP_DIS6, POLICY_AMT, BATCH_ID, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, SRC_SYSTEM, SRC_DETAIL, SHOP_NAME, AGENCY_CODE, AGENCY_NAME, IS_MINILED_CODE, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, SALE_COGS, DISCOUNT_1, MAP_DIS1, DISCOUNT_30, DISCOUNT_34, MAP_DIS30, MAP_DIS34, NOTE, D_BU_TRAN, CUSTOMER_MODEL, ORDER_TYPE_CODE, ZCALASSET, CALC_RULE, STATUTORY_ACCT_CODE, MAP_ZUM, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, D_ADJ_TYPE, CHANGE_COEFFICIENT, GFCFY_AMOUNT, GFCFL_AMOUNT, D_OPER_TYPE, BCY_REV, BCY_COGE, BCY_COGS, MATERIAL_GROUP_NAME, ORG_GP, AVG_UNIT_COST, BAC_AZIENDA, BAC_SRC_AZIENDA, MAKTX_S810
,D_BUS_SCE_S --业务场景分类
,IS_SMALL_B
,D_MINILED
,INVOICE_CODE
,STD_QTY
,NVL(ZA_SALE_COGS,0) + NVL(AD_SALE_COGS,0) ZA_SALE_COGS
,MA_SALE_COGS
,SH_BF_SALE_COGS
,CALC_RULE_1
,Shipping_Order
--20260917FJF_ADD 二期新增字段
,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,MAP_D_CHANNEL,MAP_D_ECOM_BU,D_UNICUSTGRP
 FROM AW_MR9_REVM01_000001_TEMP
 WHERE 1=1
    AND COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
    --AND INSTR(V_AZIENDA, COD_AZIENDA) > 0
    /*AND (
          (PROVENIENZA IN ('CPM_SP_D2M_REV_M') AND P_ORG_FLAG = 1)
          OR
          (
            (PROVENIENZA = 'CPM_SP_D2M_REV_M'
              AND COD_CONTO LIKE '%AD'
              AND NVL(SRC_DETAIL,'REV_CIS') <> 'REV_CIS'
              AND P_ORG_FLAG = 2
             )
          )
         OR (NOTE IN ('CPM_SP_A2M_REV_M') AND P_ORG_FLAG = 3)
         OR PROVENIENZA IN ('CPM_SP_M2M_REV_6401_M') --1,2,3都需要跑该程序
        )*/
    ;

/*20261021 ALTER BY LIYIFAN1.EX 平板电视出口收入调减显示器出口收入调增*/
/*研发费用品类间调整：0102003 节点下研发费用合计 CNY_AMT，由 101001001 转出、101006000 转入，一正一负两条 */
INSERT INTO AW_MR9_REVM01_000001(
       OID
      ,COD_SCENARIO
      ,COD_PERIODO
      ,COD_AZIENDA
      ,COD_CATEGORIA
      ,COD_CONTO
      ,CUST_CODE
      ,COD_DEST2
      ,D_ONOFFLINE
      ,SRC_SYSTEM
      ,SOLD_TO_CODE
      ,COD_AZI_CTP
      ,SRC_DETAIL
      ,SALE_REV
      ,COD_DEST4
      ,COD_DEST3
      ,D_ADJ_TYPE
      ,ORG_REV
      ,BCY_REV
      ,MAP_REV
      ,MAP_REV1
      ,D_DIFF_TYPE
      ,PROVENIENZA
      ,DATEUPD
      ,USERUPD
)
SELECT NEWID()                                   OID,          -- 主键
       P_SCENARIO                                COD_SCENARIO, -- 场景：参数
       P_PERIODO                                 COD_PERIODO,  -- 期间：参数
       '2000'                                    COD_AZIENDA,  -- 公司
       'GA00_BF'                                 COD_CATEGORIA,-- 类别
       'S600100AD'                               COD_CONTO,    -- 科目
       '20040'                                   CUST_CODE,    -- 客商
       D.COD_DEST2                               COD_DEST2,    -- 利润中心：101001001 / 101006000
       '020_OFF_001'                             D_ONOFFLINE,  -- 渠道分组
       'TA'                                      SRC_SYSTEM,   -- 源系统
       '20040'                                   SOLD_TO_CODE, -- 售达方
       '8010'                                    COD_AZI_CTP,  -- 对方公司
       'REVM01'                                  SRC_DETAIL,   -- 来源
       S.CNY_AMT * D.SGN                         SALE_REV,     -- 收入金额
       '0003'                                    COD_DEST4,    -- 品牌
       '7002'                                    COD_DEST3,    -- 业务范围
       'REV_01_229'                              D_ADJ_TYPE,   -- 调整类型
       S.CNY_AMT * D.SGN                         ORG_REV,      -- 销售收入-人民币
       S.CNY_AMT * D.SGN                         BCY_REV,      -- 销售收入(含折扣)-本位币
       S.CNY_AMT * D.SGN                         MAP_REV,      -- 销售收入(不含税不含折扣)-本位币
       S.CNY_AMT * D.SGN                         MAP_REV1,     -- 还原兑现后收入-本位币
       '100407001'                               D_DIFF_TYPE,  -- 管法差异项
       'CPM_SP_D2M_REV_M'                        PROVENIENZA,  -- 来源标识
       SYSDATE                                   DATEUPD,      -- 更新日期
       SESSION_USER                              USERUPD       -- 更新用户
  FROM (SELECT SUM(NVL(CNY_AMT,0)) CNY_AMT,
               COUNT(1)            CNT
          FROM TGK_FIMA_HISENSE.AW_MR8_RDES01_000001
         WHERE COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO  = P_PERIODO
           AND D_BG = 'BG001_BU001'
           AND COD_DEST2 IN (SELECT ELEM
                               FROM TGK_FIMA_HISENSE.V_REF_DEST2
                              WHERE HIE = '01'
                                AND NODE = '0102003')
           AND COD_DEST3 IN (SELECT ELEM
                               FROM TGK_FIMA_HISENSE.V_REF_DEST3
                              WHERE HIE = '02'
                                AND NODE = 'H01')
           AND NVL(D_BU_TRAN,'X') NOT IN ('INBG_ELIM','ING_ELIM')
           AND EXISTS (SELECT 1
              FROM SESSION_AZIENDA_LIST
             WHERE SESSION_ID = V_SESSION_ID
               AND ELEM = '2000') -- ALTER BY LIYIFAN1.EX 20261027 修改为当参数有2000时运行 但不限制源公司
       ) S
 CROSS JOIN (SELECT '101001001' COD_DEST2,  1 SGN FROM DUAL
             UNION ALL
             SELECT '101006000' COD_DEST2, -1 SGN FROM DUAL) D
 WHERE S.CNT > 0;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','96 当期数据从临时表插入数据结束',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);

COMMIT;


-- 删除本 Session 数据
DELETE FROM SESSION_V_REF_AZIENDA
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_V_REF_DEST3_NONAME
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_V_REF_ED_D_ONOFFLINE
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_AZIENDA_LIST
WHERE SESSION_ID = V_SESSION_ID;


INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','98 调用开始',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;
-- 2026.1.27 新增单体毛利处理
CPM_SP_M2M_GP_M(V_SCENARIO,V_PERIODO,V_AZIENDA,SESSION_USER);

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','98 CPM_SP_M2M_GP_M-调用结束',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;
--CPM_SP_M2M_REV_ALLC1_M(P_SCENARIO,P_PERIODO,V_AZIENDA,SESSION_USER);

CPM_SP_M2M_REV_ALLC2_M(P_SCENARIO,P_PERIODO,V_AZIENDA,SESSION_USER);

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','98 CPM_SP_M2M_REV_ALLC2_M-调用结束',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;
--CPM_SP_M2M_REV_ALLC3_M(P_SCENARIO,P_PERIODO,V_AZIENDA,SESSION_USER);
/* ALTER BY 20260831-1 shiqingfeng.ex 取消特殊成本分摊 月结不上*/
-- 2026.8.28 新增6230公司特殊分摊
CPM_SP_M2M_COGS_SP_M(P_SCENARIO,P_PERIODO,V_AZIENDA,SESSION_USER);

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','98 CPM_SP_M2M_COGS_SP_M-调用结束',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;

-- 2026.8.28 新增成本分摊通用配置
CPM_SP_ALC_NOMAT_M(P_SCENARIO,P_PERIODO,V_AZIENDA,SESSION_USER);

INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
VALUES('CPM_SP_D2M_REV_M','99 END',SYSDATE,SESSION_USER,V_SCENARIO,V_PERIODO,P_AZIENDA);
COMMIT;
END;
