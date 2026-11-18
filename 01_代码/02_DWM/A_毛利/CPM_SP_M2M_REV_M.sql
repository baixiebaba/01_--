CREATE OR REPLACE PROCEDURE CPM_SP_M2M_REV_M(
  P_SCENARIO    IN VARCHAR2,
  P_PERIODO     IN VARCHAR2,  -- YYYYMM
  P_AZIENDA     IN VARCHAR2,
  SESSION_USER  IN VARCHAR2
) AS
/******
当前版本 ： V4.9  更新人：LIYIFAN1.EX  更新时间：20261118 14:58 更新完成
上一版信息: V4.8  更新人：SHEXUANXUAN.EX  更新时间：20261107 11.01 更新完成

最后修改时间: 
  20261118 14:58 LIYIFAN1.EX V4.9 新增「日立合并层成本分摊（BSFT）」（步骤 3-2，位置在「3 日立成本轧差」之后、END IF 之前）：
            ① 待分摊五场景：①②总账内销/外销、③物料差异取老管报 TGK_GB_HISENSE.V_HITACH_ZXSLR_CONS
              （按 MATNR 伪物料名区分内外销），④管法差、⑤手工调整取本表 TEMP（均要求物料为空）；
            ② 因子池：①②③④ 全 050 节点各一张，⑤ 每个业务管理单元一张；剔除 AW_RUL_BAFRUL_000001 与
              AW_RUL_RDEMAT_000001 的物料；「12-海外」判定走 V_REF_ED_D_SALE_DEPT（HIE=HISD，NODE=12）；
            ③ 结果按 OID 汇总覆盖 OTH_ASSESS_COST；④⑤ 已分摊后插负数行冲销原行（COD_CONTO=S640100、
              SRC_DETAIL=BSFT、PROVENIENZA=CPM_SP_BSFT_M_T0、COD_CATEGORIA 继承原行）；过程数据落 ZTAB_BSFT_BASE1；
            ④ 配套：7 处 PROVENIENZA 白名单补 CPM_SP_BSFT_M_T0（V4.8 原行号 4172/4294/4433/6437/6737/6921/6950），
              轧差取数排除该来源；日立段开头加「3-0 重跑清理」（删上一轮 GB_ZXSLR 与 BSFT 冲销行、OTH 归零）。
            ★ 必须位于 PSI_COMB_COST = DOM_PSI_COST + OTH_ASSESS_COST 汇总之前；依赖先建 ZTAB_BSFT_BASE1（否则 ORA-00942）。
            ★ 版内修正：④⑤ 待分摊的 ROWNUM 改 ROW_NUMBER() OVER（原与 GROUP BY 同层，ORA-00979）；
              冲销行类别由固定 ZAMOUNT 改继承原行（原写法使 ⑤ 的 CADJ_COST 净不掉，合并成本翻倍）。
  20261107 11.01 SHEXUANXUAN.EX 20261107 2910端到端合并成本逻辑，改成与1098一致
  20261106 14:24 LICHENG.EX 修正 V4.6 文件头注释：说明文字里误写了注释结束符，把外层注释块提前闭合，
            编译报 PLS-00103（第 19 行）。已改为纯文字表述，SQL 代码零改动，与 V4.6 逐字相同（除本节）。

  20261106 14:20 LICHENG.EX STEP 7 加固：禁止谓词下推 + 强制 hash join（只加 hint / 等价改写，业务口径零变化）
            背景：DEV 库（TGK_FIMA_DEV）7.0 的 MERGE 跑了 2689 秒、2.53 亿逻辑读、返回 0 行。
            TEMP 表统计停在 11-03，A 视图估算 13 行、实际 COD_DEST3 LIKE '2%' 命中 58 万行（低估约 4.5 万倍），
            优化器因此把 B 的「按物料分组聚合」推成逐行标量子查询（VIEW PUSHED PREDICATE + FILTER +
            按 MATERIAL_CODE 回表），58 万行各跑一遍。生产库因统计较新走 hash join，10 秒跑完，所以只有 DEV 复现。
            改动：① 7.0 —— CASE 里的 IN (SELECT ... ATSMAP) 改为预聚合 CTE「CTE_BG001_AZI」LEFT JOIN
              （同一集合只算一次），B 加 NO_PUSH_PRED 提示，外层加 USE_HASH(A B) 提示；
            ② 7.1/7.2 —— NEED_UPDATE_MC 加 NO_PUSH_PRED，主查询加 USE_HASH(T MC)；
            ③ REV005_STEP_7 贵阳工厂端 / 广东 —— ALLOC_COST 加 NO_PUSH_PRED，末段加 USE_HASH(BL AC)。
            7.3（无物料号）无「分组派生表 JOIN」结构，不加 hint，避免过度干预计划。
            语义不变：CASE 判定由「COD_AZI_CTP IN 小集合」改成「LEFT JOIN 命中非空」，其余字段与过滤条件逐字保留。

  20261101 15:40 LICHENG.EX 2910政策记账方式不同于内销，收入部分做特殊逻辑处理
  20261030 19:17 LICHENG.EX REV005_STEP_6.0（抵消前对方公司处理）：OPTY061 取消对方公司置空
            原条件 OR D_OPER_TYPE IN ('OPTY060','OPTY061') 收敛为仅 OPTY060 置空；OPTY061 行保留
            COD_AZI_CTP / COD_AZI_CTP_ORG，后续「插入抵消数据」按 M.COD_AZI_CTP_ORG IS NOT NULL 正常生成抵消数。
            仅动 STEP_6.0 这一条 UPDATE；STEP_1.2-1.5 政策分摊因子中 OPTY060/OPTY061/OPTY039 的排除不变。
  20261029 10:59 LICHENG.EX 直接写死020_OFF_002
  20261027 14:52 LICHENG.EX REV005_STEP_9（事业部 / 产销存打标）性能重构：两段 UPDATE 合并为一条 ROWID 驱动 MERGE
            原写法两条 UPDATE 全表刷新：目标表整表扫 2 次、整表写 2 次（130+ 列宽表，undo/redo 翻倍），
            且每个命中行都执行一次相关标量子查询，映射派生表（MAGPCR × SESSION_V_REF_AZIENDA → PCRMAP）
            逐行重算，标量子查询缓存只按 (COD_AZIENDA / COD_AZIENDA+COD_DEST2) 命中，公司×利润中心组合
            越多重算越多 —— 这是主要耗时；另有 SUBSTR(...)||LPAD(...) 每行重复计算且不可索引。
            现改为：两个映射派生表在 USING 里各算一次（hash join），目标表只扫 1 次、只写 1 次，MERGE 按
            ROWID 定位；有效期比较统一用 v_per0；UPDATE ... WHERE 只写「新旧值不同」的行。
            语义逐行等价：公司命中才有 IS_PSC；公司+利润中心命中才有 COD_BG 与 IS_BG_PL='Y'；未命中一律为空。
            两个 LEFT JOIN 派生表均按主键收敛，每个 ROWID 在 USING 内唯一，不会 ORA-30926 / 不放大行数。

  20261026 21:42 LICHENG.EX REV005_STEP_6.0（抵消前对方公司处理）新增 REVM05 + REV_01_229 对方公司置空
  20261026 21:42 LICHENG.EX REV005_STEP_6.0（抵消前对方公司处理）：对方公司置空新增一个分支 ——
            SRC_DETAIL = 'REVM05' 且 D_ADJ_TYPE = 'REV_01_229' 的行，COD_AZI_CTP / COD_AZI_CTP_ORG 一并置空。
            该类行由 REV005_STEP_2-3（研发费用品类间调整-事业部层）产出：插入时 COD_AZI_CTP 已写 NULL（L3126），
            但 COD_AZI_CTP_ORG 仍带源行值（L3127），会被后续「插入抵消数据」的 COD_AZI_CTP_ORG IS NOT NULL 判定命中，
            凭空生成抵消数；置空后即不参与抵消。
            命中范围：全程序只有 STEP_2-3 产出 D_ADJ_TYPE = 'REV_01_229'；STEP_2-1 / 2-2 / 2-4 虽同为 REVM05 但
            硬编码 REV_01_311 / REV_01_312 / REV_01_503，不受影响，故该分支零误伤。
            写法：沿用同一条 UPDATE 加 OR 分支（继承公司会话 + PROVENIENZA 限制），不新增语句。

  20261026 17:45 LICHENG.EX REV005_STEP_9 合并收入成本表新增事业部/产销存三个字段
  20261026 17:45 LICHENG.EX REV005_STEP_9（事业部 / 产销存打标）：AW_MR9_REVM05_000001 新增三个字段，
            不改 INSERT 结构，落表之后用两条 UPDATE 按【期间 + 公司 + PROVENIENZA】回刷本批数据，
            不参与任何金额计算，不影响原有字段取值：
            ① COD_BG（事业部编码）：本行 COD_AZIENDA 经 SESSION_V_REF_AZIENDA（HIE='01'）按层级展开后
               命中 AW_RUL_MAGPCR_000001 —— NODE_ELEMENT_FLAG='N' 走 NODE（层级编码）、='E' 走 ELEM（具体公司码），
               COMPANY_CODE 不能简单等值；有效期按 YYYYMM 卡（VALID_FR / VALID_TO）。
               命中后取出该配置的 COD_BG，再用 AW_RUL_PCRMAP_000001（同期间有效）换出该事业部的利润中心范围；
               本行 COD_DEST2 落在范围内 → 写 COD_BG，否则为空。
            ② IS_BG_PL（是否事业部）：与 ① 同一判据，利润中心落在事业部范围内写 'Y'，否则为空。
            ③ IS_PSC（是否产销存）：只看公司是否命中 AW_RUL_MAGPCR_000001，直接取该配置的 IS_PSC，
               与利润中心无关（订单口径落在公司层）。
            ★ 故意拆成两条 UPDATE：IS_PSC 是公司级，COD_BG / IS_BG_PL 是「公司 + 利润中心」级；
              合在一条 SET (...) = (...) 里，公司没命中任何事业部时会连同 IS_PSC 一起被冲成空。
            ★ 两段映射派生表都按主键收敛（GROUP BY AZI_CODE / AZI_CODE,PCR_CODE），标量子查询最多返回 1 行；
              映射表配错也只会取到其中一条，不会 ORA-01427、不放大行数。
            ★ 语句位置：本次 INSERT 的 COMMIT 之后、SESSION 表清理之前（要读 SESSION_V_REF_AZIENDA /
              SESSION_AZIENDA_LIST）。重跑同期间自动覆盖，不需要另写历史回填脚本。
            ★ 这里的 HIE 固定取 '01'（2S_MA 公司树），与 CPM_SP_FI_CO_M 读同一张 MAGPCR 的口径保持一致；
              本程序其它位置用的 HIE='10'（中国区节点口径）是另一棵树，两者不能混用。
  上一版信息:  V3.9  更新人：LIYIFAN1.EX  更新时间：20261023 16:08 更新完成
  20261023 16:08 LIYIFAN1.EX 源2-3 研发费用品类间调整 对方公司放null
  上一版信息:  V3.8  更新人：LICHENG.EX  更新时间：20261023 10:00 更新完成
  20261023 10:00 LICHENG.EX REV005_STEP_1.2-1.5（政策分摊）①业务分类 D_OPER_TYPE 为 OPTY060/OPTY061/OPTY039 的收入行不作为分摊因子：
            1.2 打标 A_STEP1 / A_STEP2_READY / A_STEP3 / B_STEP1_READY / B_STEP2_READY（各非空调+空调 共10处）
            与 1.3 生成政策分摊数据（本月、上两月 共2处）同步加排除；
            ②按【公司三级分类】D_CHANNEL 匹配的政策（A_STEP3、B_STEP2）不认 CUST_CODE=1001200、A012** 的收入行：
            1.2 打标 4 处 + 1.3 本月分摊 A_STEP3/B_STEP2 分支 ON 条件同步排除，该类行既不进分摊分母也不接分摊；
            整组因子被清空时政策不再打标，回落 1.4 段1「未分配政策」，金额不丢。
  20261022 LIYIFAN1.EX REV005_STEP_2-4 古洛尼合并层还原
  20261022 FENGJIANFENG.ex 20261022fjf_add REV005_STEP_999 二期新增维度处理
  20261021 LIYIFAN1.EX  REV005_STEP_2-3 研发费用品类间调整-事业部层 
  20261020 10:58 licheng.ex REV005_STEP_1（单体-收入、政策）：新增 1.6 段，公司 2910 的考核收入 ASSESSED_REV 取数。
            公式：ASSESSED_REV = ORG_REV - POLICY_AMT + POLICY_CASH_PD
                  （【收入金额(含折扣)-净收入】-【政策计提】+【政策兑现】），其余公司维持原 NULL 口径。
            位置：置于汇率折算 MERGE 之后、STEP 2 之前，保证三个参与字段均取最终值。
  20261019 licheng.ex 非国际营销机1098公司按以下逻辑取数
  20261016 LIYIFAN1.EX 新增业务分类OPTY060、OPTY061
  20261015 18:30 LICHENG.EX REV005_STEP_1（单体-收入、政策）：POLICY_CASH_PD 进数新增 SRC_DETAIL='ZTFI313A' 的数据。
            ① 1.4 段2（COD_CONTO LIKE 'S60010%' 当期）CASE 名单由 ('VBRP','REVM01','ADJM01') 扩为 (...,'ZTFI313A')；
            ② 1.5 段（科目非 S60010% 且非 S6001G5/S6001G5AD 的当期插入）POLICY_CASH_PD 由硬编码 0 改为 CASE，
               当 M.SRC_DETAIL='ZTFI313A' 时取 NVL(MAP_DIS1,0)+NVL(MAP_DIS3,0)+NVL(MAP_DIS4,0)+NVL(MAP_DIS30,0)+NVL(MAP_DIS34,0)，其余仍为 0。
               背景：ZTFI313A（TVS 销售明细收入）在 D2M 落 S600114/S600111，不匹配 'S60010%'，故实际从 1.5 段进数。

  20261013 16:31 冰箱增加6015公司取数
  20261005 11:52 限制这个范围在BG009_BU010事业部的账套范围里
  20260929 15:42 licheng.ex 中国区事业部成本9月不上线
  20260920 19：42 FENGJIANFENG.ex 20260915fjf_add 二期新增字段 ,维度，如果为空要补ZZZZ
  20260916 16：41 LICHENG.ex REV005_STEP_2-2（插入线下O2O冲销数）①修改类别为GA00_CON_G05
  20260915 17：49 FENGJIANFENG.ex 20260915fjf_add REV005_STEP_2-2（插入线下O2O冲销数）①修改类别 ②新增中国区相关取数字段；中国区专题原来做的删除，不要做删除 改成更新为0
  20260914 FENGJIANFENG.ex 20260914fjf_add REV005_STEP_2-2（插入线下O2O冲销数）
  20260908 10：41 开放 20260810-3 shiqingfeng.ex SXX补充逻辑【中国区专题】，开始测试
  20260908 10：38 开放 20260810-1 shiqingfeng.ex 对方公司是中国区公司，不生成成本抵消数，开始测试
  20260908 10：33 开放 20260817-2 CHENDONG3.ex  将中国区费用转政策的业务在产品公司还原的部分，对方公司置为空，以确保后续不参与抵消，开始测试



  20260716 shiqingfeng.ex 新增插入墨西哥利润调整
  20260730 SHQINGFENG.EX 新增 MA_SALE_COGS 字段
  20260804 SHIQINGFENG.EX 补充2900公司取数时排除ZZFT
  20260806-1 【需求】管报中国区(1180、12**公司)政策分摊兜底逻辑：D_CHANNEL替换为D_ECOM_BU；D_ECOM_BU为空或ZZZZ不分摊；不跨公司分摊
  20260806-2 【fix】1.1保留D_ECOM_BU空/ZZZZ记录，A_STEP3收入端排除并自然落入1.4未分配政策；1.4的M端D_CHANNEL同步转换
  20260806-3 新增将单体前三个月的数据缓存到temp表，将后续所有单体表替换为temp表
  20260810-1 shiqingfeng.ex 对方公司是中国区公司，不生成成本抵消数
  20260810-2 shiqingfeng.ex 需排除科目为S6401开头，SALE_COGS=0且SH_BF_SALE_COGS不为0 ---该部分为成本分摊前金额
  20260810-3 shiqingfeng.ex SXX补充逻辑【中国区专题】：
                            如果公司范围是中国区公司【公司节点为200】
                            且科目范围为S6401开头
                            则限制业务分类范围在AW_RUL_CNMECL_000001-中国区-其他业务收入范围配置表范围内的才取成本数，其他公司直接取SALE_COGS
   20260817-1 CHENDONG3.ex  新增6012公司处理字段ASSESS_MANG_COST逻辑
   20260817-2 CHENDONG3.ex  将中国区费用转政策的业务在产品公司还原的部分，对方公司置为空，以确保后续不参与抵消
   20260818 shiqingfeng.ex 将政策的临时表修改为实体表，并增加session_id字段
   20260819 SHIQNGFENG.EX 插入未实现金额修改为全单机
   20260820 FENGJIANFENG.EX 20260820FJF_ADD 新增REV005_STEP_6_1（古洛尼赠品抵消数还原）
   20260820-2 SHIQNGFENG.EX 新增公司三级分类更新逻辑与D表一致
   20260825-1 SHIQINGFENG.EX  新增 落户纸号  Shipping_Order
   20260826-1 SHIQINGFENG.EX  REV005_STEP_7（ 考核成本无物料分摊）,【BG001_BU030-显示事业部-广东】SXX20260825新增范围内公司 注意：贵阳、广东的事业部只能分别在自己的事业部范围内分摊
   20260827 SHIQINGFENG.EX 取消补充2900公司取数时排除ZZFT
   20250828 XIAOYACHAO.EX 工厂端外销收入成本增加公司6002
   20260831 shiqingfeng.ex 月结不上取消逻辑  20260810-1 shiqingfeng.ex 对方公司是中国区公司，不生成成本抵消数
   20260831 shiqingfeng.ex 月结不上取消逻辑  20260817-2 CHENDONG3.ex  将中国区费用转政策的业务在产品公司还原的部分，对方公司置为空，以确保后续不参与抵消
   20260831 XIAOYACHAO.EX 工厂端成本6002公司特殊处理
   20260902 XIAOYACHAO.EX 涉及万高端到端成本，工厂端成本逻辑更新
   20260904 alter by shiqingfeng.ex 比例大于是10的数据进行去重

   20260905 EDIT BY LC 20260905 中国区线上业务部分主营业务成本不取数8月不上线
   20260907 修改人 shiqingfeng.ex 去掉所有锁定表限制，仅保留最上面参数session表限制



******/
  v_per0  VARCHAR2(6);
  v_per1  VARCHAR2(6);
  v_per2  VARCHAR2(6);
  v_per0_ACT  VARCHAR2(7);
  v_per1_ACT  VARCHAR2(7);
  v_per2_ACT  VARCHAR2(7);
  v_per0_PER  VARCHAR2(7);
  v_per1_PER  VARCHAR2(7);
  v_per2_PER  VARCHAR2(7);
  V_CN_AZIENDA VARCHAR2(4000) ;
  V_HITACHI_AZIENDA VARCHAR2(4000);
  V_AZIENDA        VARCHAR2(5000);-- 公司
  V_ENTITY       VARCHAR2(5000);-- 用于存放如果遇到【合并收入，冰箱、厨卫（63、67）-BX，空气（62、68）-KT，视像（2、163）-SX】公司需要把参数调整成BX\KT\SX 以及ALL
  V_AZI_CTP       VARCHAR2(5000);-- 对方公司，海信内部公司的三级分类有值时，要限制海信内部公司即对方公司不参与分摊
  V_MATERIAL     VARCHAR2(4000);-- 虚拟物料
  V_PRO_CLASS    VARCHAR2(4000); -- 配件类不参与分摊:通用规则:根据物料对应产品中类为配件的不参与分摊，或物料组1100105(附加产品)、1100107(商显附加产品)不参与分摊
  V_ERROR_COD          NUMBER;
  V_ERROR_MSG      VARCHAR2(4000);--错误信息
  V_SESSION_ID  NUMBER;
  V_FLAG  NUMBER;
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
    INSERT INTO SESSION_V_REF_DEST2 (SESSION_ID, HIE, NODE, ELEM)
    SELECT V_SESSION_ID, HIE, NODE, ELEM
    FROM TGK_FIMA_HISENSE.V_REF_DEST2
    ;


    -- rolling quarter: 当前月 + 前两月
    v_per0 := SUBSTR(P_SCENARIO,1,4) || P_PERIODO ;
    v_per1 := TO_CHAR(ADD_MONTHS(TO_DATE(SUBSTR(P_SCENARIO,1,4) || P_PERIODO || '01', 'YYYYMMDD'), -1), 'YYYYMM');
    v_per2 := TO_CHAR(ADD_MONTHS(TO_DATE(SUBSTR(P_SCENARIO,1,4) || P_PERIODO || '01', 'YYYYMMDD'), -2), 'YYYYMM');
    /*因为有BGT场景的数据，所以取数的时候需要现在实际场景*/
    v_per0_ACT:= SUBSTR(v_per0,0,4)||'ACT';
    v_per1_ACT:= SUBSTR(v_per1,0,4)||'ACT';
    v_per2_ACT:= SUBSTR(v_per2,0,4)||'ACT';

    v_per0_per := SUBSTR(v_per0,-2);
    v_per1_per := SUBSTR(v_per1,-2);
    v_per2_per := SUBSTR(v_per2,-2);
  -- 公司参数赋值
  SELECT LISTAGG(COD_AZIENDA, ',')
    INTO V_CN_AZIENDA
    FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
   WHERE COD_BG = 'BG012'
     AND COD_AZIENDA <> '1183'
     ;

  SELECT LISTAGG(ELEM, ',')
    INTO V_HITACHI_AZIENDA
    FROM SESSION_V_REF_AZIENDA
   WHERE 1=1
     AND SESSION_ID = V_SESSION_ID
     AND HIE = '10'
     AND NODE = '050'
     /*20260226 新增排除锁定公司*/
     AND ELEM NOT IN (SELECT COD_AZIENDA
                        FROM AW_RUL_DWMCRS_000001 T
                       WHERE REV05_FLAG = 'Y'
                         AND T.COD_SCENARIO = P_SCENARIO
                         AND T.COD_PERIODO = P_PERIODO
                         AND T.COD_CONTO = 'ZAW_D2M_LOCK')
      ;

  -- 公司参数赋值,除了电冰空工厂需要集体跑，其他都可以按照单家去运行

INSERT INTO SESSION_AZIENDA_LIST(SESSION_ID, ELEM)
SELECT DISTINCT V_SESSION_ID,ELEM
  FROM(
    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'BX' OR P_AZIENDA LIKE '63%' OR P_AZIENDA LIKE '67%' OR P_AZIENDA LIKE '6000%')
          AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '6000%')

      UNION ALL

    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'KT' OR P_AZIENDA LIKE '62%' OR P_AZIENDA LIKE '68%')
          AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')

      UNION ALL

    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'SX' OR P_AZIENDA LIKE '2%' OR P_AZIENDA LIKE '163%')
          AND (COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%')

      UNION ALL

        SELECT DISTINCT ELEM
        FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID AND P_AZIENDA = 'ALL' AND HIE = '10'

      UNION ALL

        SELECT DISTINCT ELEM
        FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID AND HIE = '10'
        AND (    INSTR(','||P_AZIENDA||',',','||ELEM||',') > 0
              OR INSTR(','||P_AZIENDA||',',','||NODE||',') > 0
              OR ((P_AZIENDA LIKE '17%' OR P_AZIENDA = '6240') AND NODE = '050')
            )
        AND ELEM NOT LIKE '63%'
        AND ELEM NOT LIKE '67%'
        AND ELEM NOT LIKE '62%'
        AND ELEM NOT LIKE '68%'
        AND ELEM NOT LIKE '2%'
        AND ELEM NOT LIKE '163%'
    )
    /*20260226 新增排除锁定公司*/
   WHERE ELEM NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   )
    ;


  SELECT LISTAGG(ELEM,',') INTO V_AZIENDA
  FROM(
    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'BX' OR P_AZIENDA LIKE '63%' OR P_AZIENDA LIKE '67%' OR P_AZIENDA LIKE '6000%')
          AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '6000%')

      UNION ALL

    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'KT' OR P_AZIENDA LIKE '62%' OR P_AZIENDA LIKE '68%')
          AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')

      UNION ALL

    SELECT DISTINCT COD_AZIENDA AS ELEM
        FROM TGK_FIMA_HISENSE.AZIENDA
        WHERE (P_AZIENDA = 'SX' OR P_AZIENDA LIKE '2%' OR P_AZIENDA LIKE '163%')
          AND (COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%')

      UNION ALL

        SELECT DISTINCT ELEM
        FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID AND P_AZIENDA = 'ALL' AND HIE = '10'

      UNION ALL

        SELECT DISTINCT ELEM
        FROM SESSION_V_REF_AZIENDA
        WHERE SESSION_ID = V_SESSION_ID AND HIE = '10'
        AND (    INSTR(','||P_AZIENDA||',',','||ELEM||',') > 0
              OR INSTR(','||P_AZIENDA||',',','||NODE||',') > 0
              OR ((P_AZIENDA LIKE '17%' OR P_AZIENDA = '6240') AND NODE = '050')
            )
        AND ELEM NOT LIKE '63%'
        AND ELEM NOT LIKE '67%'
        AND ELEM NOT LIKE '62%'
        AND ELEM NOT LIKE '68%'
        AND ELEM NOT LIKE '2%'
        AND ELEM NOT LIKE '163%'
    )
    /*20260226 新增排除锁定公司*/
   WHERE ELEM NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   )
    ;


/*
INSERT INTO TMP_V_REF_DEST3_NONAME( HIE,NODE,ELEM)
SELECT HIE,NODE,ELEM FROM SESSION_V_REF_DEST3_NONAME;
*/

--如果遇到【合并收入，冰箱、厨卫（63、67）-BX，空气（62、68）-KT，视像（2、163）-SX】公司需要把参数调整成BX\KT\SX
IF P_AZIENDA = 'ALL' THEN V_ENTITY := 'ALL';
ELSIF P_AZIENDA <> 'ALL' AND (','||V_AZIENDA||',' LIKE '%,62%' OR ','||V_AZIENDA||',' LIKE '%,68%') THEN V_ENTITY := 'KT';
ELSIF P_AZIENDA <> 'ALL' AND (','||V_AZIENDA||',' LIKE '%,63%' OR ','||V_AZIENDA||',' LIKE '%,67%') THEN V_ENTITY := 'BX';
ELSIF P_AZIENDA <> 'ALL' AND (','||V_AZIENDA||',' LIKE '%,2%' OR ','||V_AZIENDA||',' LIKE '%,163%') THEN V_ENTITY := 'SX';
ELSE V_ENTITY := P_AZIENDA;
END IF
;

  --海信内部公司的三级分类有值时，要限制海信内部公司即对方公司不参与分摊
  SELECT LISTAGG(COD_AZIENDA,',')
  INTO V_AZI_CTP
  FROM TGK_FIMA_HISENSE.AW_RUL_PLCCTP_000001 A
  WHERE A.VALID_FR <= CONCAT(SUBSTR(P_SCENARIO,1,4),P_PERIODO) AND A.VALID_TO >= CONCAT(SUBSTR(P_SCENARIO,1,4),P_PERIODO) ;

  --配件类不参与分摊:通用规则:根据物料对应产品中类为配件的不参与分摊，或物料组1100105(附加产品)、1100107(商显附加产品)不参与分摊
  SELECT LISTAGG(D_PRO_CLASS,',')
  INTO V_PRO_CLASS
  FROM TGK_FIMA_HISENSE.AW_RUL_PROCLS_000001 A ;
  --WHERE A.VALID_FR <= CONCAT(SUBSTR(P_SCENARIO,1,4),P_PERIODO) AND A.VALID_TO > CONCAT(SUBSTR(P_SCENARIO,1,4),P_PERIODO) ;

  --虚拟物料
  SELECT LISTAGG(T.MATERIAL_CODE,',')
  INTO V_MATERIAL
    FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 t
    WHERE T.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
    AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
    AND MATERIAL_CODE IS NOT NULL ;

    -- 记录开始日志
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '0.0 START', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '大系统产销存销售、收入、成本计算开始',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 0.  创建全局临时表-迁移时候运行一次
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- 1.1  缓存政策数据及事业部组织数据
  -----------------------------------------------------------------------------

/*20260806 shiqingfeng.ex 新增将单体前三个月的数据缓存到temp表，将政策分摊的所有的单体表替换为temp表*/
/*
CREATE TABLE AW_MR9_REVM01_000001_CON_TEMP AS
SELECT * FROM AW_MR9_REVM01_000001_CON_TEMP
WHERE 1=2


*/


DELETE
   FROM AW_MR9_REVM01_000001_CON_TEMP T
  WHERE --SUBSTR(T.COD_SCENARIO,1,4) || T.COD_PERIODO IN (v_per0, v_per1, v_per2)
    1=1
    AND (
           (T.COD_SCENARIO = v_per0_ACT
          AND T.COD_PERIODO = v_per0_per
           )
          OR
           (T.COD_SCENARIO = v_per1_ACT
          AND T.COD_PERIODO = v_per1_per
          )
          OR
           (T.COD_SCENARIO = v_per2_ACT
          AND T.COD_PERIODO = v_per2_per
          )
        )
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                    WHERE SESSION_ID = V_SESSION_ID
                    )
    ;
INSERT INTO AW_MR9_REVM01_000001_CON_TEMP(
OID, COD_SCENARIO, COD_PERIODO, SHOP_CODE, COD_AZIENDA, COD_DEST1, COD_AZI_CTP, D_PRC_GRP, COD_CONTO, D_SALE_DEPT, COD_DEST3, COD_CATEGORIA, D_PRO_CLASS, D_DATA_BLOCK, D_DIFF_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_QUA_METHOD, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_MODEL_LCA, D_PRO_TYPE, SALE_MODEL_NAME, D_POL_CLASS, MODEL_NAME, CUST_CODE, MODEL_CODE, SALE_MODEL_CODE, CUST_NAME, D_CHANNEL, D_MODE, D_ONOFFLINE, D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, D_IND_C_TYPE, D_CNL_C_TYPE, COD_VALUTA, SHIP_QTY, COD_VALUTA_ORIGINARIA, ORDER_QTY, BILL_QTY, SALE_REV, DISCOUNT_3, DISCOUNT_4, DISCOUNT_5, DISCOUNT_6, TAX_RATE, EXCHANGE_RATE, ORG_QTY, MAP_QTY, ORG_REV, MAP_REV, MAP_REV1, MAP_DIS3, MAP_DIS4, MAP_DIS5, MAP_DIS6, POLICY_AMT, BATCH_ID, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE, SRC_SYSTEM, SRC_DETAIL, SHOP_NAME, AGENCY_CODE, AGENCY_NAME, IS_MINILED_CODE, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, SALE_COGS, DISCOUNT_1, MAP_DIS1, DISCOUNT_30, DISCOUNT_34, MAP_DIS30, MAP_DIS34, NOTE, D_BU_TRAN, CUSTOMER_MODEL, ORDER_TYPE_CODE, ZCALASSET, CALC_RULE, STATUTORY_ACCT_CODE, MAP_ZUM, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, D_ADJ_TYPE, CHANGE_COEFFICIENT, GFCFY_AMOUNT, GFCFL_AMOUNT, D_OPER_TYPE, BCY_REV, BCY_COGE, BCY_COGS, MATERIAL_GROUP_NAME, ORG_GP, AVG_UNIT_COST, BAC_AZIENDA, BAC_SRC_AZIENDA, MAKTX_S810, BUS_SCE_CAT_CODE, BUS_SCE_CAT_NAME, IS_SMALL_B, IS_SALE, D_BUS_SCE_S, D_MINILED, INVOICE_CODE, ADJ_LEV_2, STD_QTY, ZA_SALE_COGS, AD_SALE_COGS, MA_SALE_COGS, CALC_RULE_1, SH_BF_SALE_COGS
,SHIPPING_ORDER
--20260920FJF_ADD 二期新增字段
 ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
)

 SELECT OID, COD_SCENARIO, COD_PERIODO, SHOP_CODE, COD_AZIENDA, COD_DEST1, COD_AZI_CTP, D_PRC_GRP, COD_CONTO
 , D_SALE_DEPT, COD_DEST3, COD_CATEGORIA, D_PRO_CLASS, D_DATA_BLOCK
 , D_DIFF_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4
 , D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_QUA_METHOD, D_PRO_STAGE
 , D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_MODEL_LCA, D_PRO_TYPE, SALE_MODEL_NAME
 , D_POL_CLASS, MODEL_NAME, CUST_CODE, MODEL_CODE, SALE_MODEL_CODE, CUST_NAME, D_CHANNEL, D_MODE
 , D_ONOFFLINE, D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME
 , D_IND_C_TYPE, D_CNL_C_TYPE, COD_VALUTA, SHIP_QTY, COD_VALUTA_ORIGINARIA, ORDER_QTY, BILL_QTY, SALE_REV
 , DISCOUNT_3, DISCOUNT_4, DISCOUNT_5, DISCOUNT_6, TAX_RATE, EXCHANGE_RATE, ORG_QTY, MAP_QTY, ORG_REV, MAP_REV
 , MAP_REV1, MAP_DIS3, MAP_DIS4, MAP_DIS5, MAP_DIS6
 , POLICY_AMT, BATCH_ID, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_GROUP_CODE
 , SRC_SYSTEM, SRC_DETAIL, SHOP_NAME, AGENCY_CODE, AGENCY_NAME, IS_MINILED_CODE, PROVENIENZA
 , USERUPD, DATEUPD, EN_VERSION
 , SALE_COGS
 , DISCOUNT_1, MAP_DIS1, DISCOUNT_30, DISCOUNT_34, MAP_DIS30, MAP_DIS34, NOTE, D_BU_TRAN, CUSTOMER_MODEL, ORDER_TYPE_CODE, ZCALASSET, CALC_RULE, STATUTORY_ACCT_CODE, MAP_ZUM, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, D_ADJ_TYPE, CHANGE_COEFFICIENT, GFCFY_AMOUNT, GFCFL_AMOUNT, D_OPER_TYPE, BCY_REV, BCY_COGE, BCY_COGS, MATERIAL_GROUP_NAME, ORG_GP, AVG_UNIT_COST, BAC_AZIENDA, BAC_SRC_AZIENDA, MAKTX_S810, BUS_SCE_CAT_CODE, BUS_SCE_CAT_NAME, IS_SMALL_B, IS_SALE, D_BUS_SCE_S, D_MINILED, INVOICE_CODE, ADJ_LEV_2, STD_QTY, ZA_SALE_COGS, AD_SALE_COGS, MA_SALE_COGS, CALC_RULE_1, SH_BF_SALE_COGS
 , SHIPPING_ORDER
 --20260920FJF_ADD 二期新增字段
 ,nvl(D_EFF_CLASS,'ZZZZ') as D_EFF_CLASS,nvl(D_BU_SHOP,'ZZZZ') as D_BU_SHOP,nvl(D_EC_STORE,'ZZZZ') as D_EC_STORE,nvl(D_UNICUSTGRP,'ZZZZ') as D_UNICUSTGRP
  FROM TGK_FIMA_HISENSE.AW_MR9_REVM01_000001 T
  WHERE --SUBSTR(T.COD_SCENARIO,1,4) || T.COD_PERIODO IN (v_per0, v_per1, v_per2)
    1=1
    AND (
           (T.COD_SCENARIO = v_per0_ACT
          AND T.COD_PERIODO = v_per0_per
           )
          OR
           (T.COD_SCENARIO = v_per1_ACT
          AND T.COD_PERIODO = v_per1_per
          )
          OR
           (T.COD_SCENARIO = v_per2_ACT
          AND T.COD_PERIODO = v_per2_per
          )
        )
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                    WHERE SESSION_ID = V_SESSION_ID
                    )
    ;




    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '0.1 START', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '单体临时表数据插入完成',P_AZIENDA);
    COMMIT;

    /*20260810-2 shiqingfeng.ex 需排除科目为S6401开头，SALE_COGS=0且SH_BF_SALE_COGS不为0 ---该部分为成本分摊前金额*/
    DELETE FROM AW_MR9_REVM01_000001_CON_TEMP T
      WHERE 1=1
        AND (
               (T.COD_SCENARIO = v_per0_ACT
              AND T.COD_PERIODO = v_per0_per
               )
              OR
               (T.COD_SCENARIO = v_per1_ACT
              AND T.COD_PERIODO = v_per1_per
              )
              OR
               (T.COD_SCENARIO = v_per2_ACT
              AND T.COD_PERIODO = v_per2_per
              )
            )
        AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                        WHERE SESSION_ID = V_SESSION_ID
                        )
        AND (COD_CONTO LIKE 'S6401%' AND SALE_COGS = 0 AND SH_BF_SALE_COGS <> 0)
  ;


    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '0.2 START', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '剔除成本分摊前',P_AZIENDA);
    COMMIT;


--EDIT BY LC 20260905 8月不上线
    /*20260810-3 shiqingfeng.ex 20260810 SXX补充逻辑【中国区专题】：
                  如果公司范围是中国区公司【公司节点为200】
                  且科目范围为S6401开头
                  则限制业务分类范围在AW_RUL_CNMECL_000001-中国区-其他业务收入范围配置表范围内的才取成本数，其他公司直接取SALE_COGS
    20260908 10：41 开放 20260810-3 shiqingfeng.ex SXX补充逻辑【中国区专题】，开始测试
    */
  --20260915fjf_add 中国区专题原来做的删除，不要做删除 改成更新为0
  --20260929lc 中国区事业部成本不上线
  /*UPDATE AW_MR9_REVM01_000001_CON_TEMP T
  SET SALE_COGS = 0
  WHERE 1=1
  AND COD_AZIENDA IN (SELECT ELEM
                              FROM SESSION_AZIENDA_LIST A
                             WHERE SESSION_ID = V_SESSION_ID
                               AND EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S WHERE SESSION_ID = V_SESSION_ID AND S.HIE = '10' AND S.NODE = '200' AND A.ELEM = S.ELEM)
                        )
  AND NOT EXISTS (SELECT D_OPER_TYPE
                    FROM TGK_FIMA_HISENSE.AW_RUL_CNMECL_000001 OPER_MAP
                   WHERE VALID_FR <= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                     AND NVL(VALID_TO,'999999') >= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                     AND OPER_MAP.D_OPER_TYPE = T.D_OPER_TYPE
           UNION ALL
           SELECT 'OPTY039' FROM DUAL
           UNION ALL
           SELECT 'OPTY040' FROM DUAL
                  )
  ;*/
    /* DELETE FROM AW_MR9_REVM01_000001_CON_TEMP T
      WHERE 1=1
        AND (
               (T.COD_SCENARIO = v_per0_ACT
              AND T.COD_PERIODO = v_per0_per
               )
              OR
               (T.COD_SCENARIO = v_per1_ACT
              AND T.COD_PERIODO = v_per1_per
              )
              OR
               (T.COD_SCENARIO = v_per2_ACT
              AND T.COD_PERIODO = v_per2_per
              )
            )
        AND COD_AZIENDA IN (SELECT ELEM
                              FROM SESSION_AZIENDA_LIST A
                             WHERE SESSION_ID = V_SESSION_ID
                               AND EXISTS (SELECT 1 FROM SESSION_V_REF_AZIENDA S WHERE SESSION_ID = V_SESSION_ID AND S.HIE = '10' AND S.NODE = '200' AND A.ELEM = S.ELEM)
                        )
        AND COD_CONTO LIKE 'S6401%'
        AND NOT EXISTS (SELECT D_OPER_TYPE
                    FROM TGK_FIMA_HISENSE.AW_RUL_CNMECL_000001 OPER_MAP
                   WHERE VALID_FR <= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                     AND NVL(VALID_TO,'999999') >= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                     AND OPER_MAP.D_OPER_TYPE = T.D_OPER_TYPE
                  )

  ; */
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '0.3 START', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '中国区-其他业务收入范围配置表范围内的才取成本',P_AZIENDA);
    COMMIT;


    --插入分公司政策数据到临时表
  INSERT INTO TMP_TABLE_POLICY(SESSION_ID,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)
    --非空调
  SELECT
       V_SESSION_ID ,COD_AZIENDA, COD_DEST2, NVL(D_ONOFFLINE,'') D_ONOFFLINE,
        --【20260806 修改v2】1180/12**使用D_ECOM_BU；空/ZZZZ政策保留，待1.4作为未分配政策落表
        CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
             THEN NVL(D_ECOM_BU,'')
             ELSE NVL(D_CHANNEL,'')
         END AS D_CHANNEL, NVL(CUST_CODE,'') CUST_CODE,
        NULL MATERIAL_CODE, NULL COD_AZIENDA_NEW, SUM(POLICY_AMT) POLICY_AMT, NULL STEP_ID, NULL GROUP_ID
    FROM AW_MR9_REVM01_000001_CON_TEMP
   WHERE SRC_DETAIL IN ('POLICY_YT','ADJM01')
     AND COD_CONTO IN ('S6001G5','S6001G5AD')
     AND COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%')
                            --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                         )
     --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
     --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
     AND (MATERIAL_CODE IS NULL OR MATERIAL_CODE = 'ZZZZ')
     /*20260226 新增排除锁定公司*/
     /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                               FROM AW_RUL_DWMCRS_000001 T
                              WHERE REV05_FLAG = 'Y'
                                AND T.COD_SCENARIO = P_SCENARIO
                                AND T.COD_PERIODO = P_PERIODO
                                AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                             )*/
    GROUP BY COD_AZIENDA, COD_DEST2, NVL(D_ONOFFLINE,''),
         CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
              THEN NVL(D_ECOM_BU,'')
              ELSE NVL(D_CHANNEL,'')
          END, NVL(CUST_CODE,'')
    HAVING SUM(POLICY_AMT) <> 0
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '插入分公司政策数据到临时表-非空调', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;


  INSERT INTO TMP_TABLE_POLICY(SESSION_ID,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)

  --空调
    SELECT
         V_SESSION_ID ,COD_AZIENDA, D_SALE_DEPT AS COD_DEST2, NVL(D_ONOFFLINE,'') D_ONOFFLINE,
        CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
             THEN NVL(D_ECOM_BU,'')
             ELSE NVL(D_CHANNEL,'')
         END AS D_CHANNEL, NVL(CUST_CODE,'') CUST_CODE,
        NULL MATERIAL_CODE, NULL COD_AZIENDA_NEW, SUM(POLICY_AMT) POLICY_AMT, NULL STEP_ID, NULL GROUP_ID
    FROM AW_MR9_REVM01_000001_CON_TEMP
   WHERE SRC_DETAIL IN ('POLICY_YT','ADJM01')
     AND COD_CONTO IN ('S6001G5','S6001G5AD')
     AND COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                            --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                         )
     --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
     --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
     AND (MATERIAL_CODE IS NULL OR MATERIAL_CODE = 'ZZZZ')
          /*20260226 新增排除锁定公司*/
     /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                               FROM AW_RUL_DWMCRS_000001 T
                              WHERE REV05_FLAG = 'Y'
                                AND T.COD_SCENARIO = P_SCENARIO
                                AND T.COD_PERIODO = P_PERIODO
                                AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                              )*/
    GROUP BY COD_AZIENDA, D_SALE_DEPT, NVL(D_ONOFFLINE,''),
         CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
              THEN NVL(D_ECOM_BU,'')
              ELSE NVL(D_CHANNEL,'')
          END, NVL(CUST_CODE,'')
    HAVING SUM(POLICY_AMT) <> 0
    ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '插入分公司政策数据到临时表-空调', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --插入公司对应的事业部关系进入临时表
    INSERT INTO TMP_TABLE_ENT(SESSION_ID,COD_CTP, COD_BU)
    SELECT V_SESSION_ID,COD_AZIENDA COD_CTP, 'BX' COD_BU
    FROM TGK_FIMA_HISENSE.AZIENDA
    WHERE COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%'
    ;

    INSERT INTO TMP_TABLE_ENT(SESSION_ID,COD_CTP, COD_BU)
    SELECT V_SESSION_ID,COD_AZIENDA COD_CTP, 'KT' COD_BU
    FROM TGK_FIMA_HISENSE.AZIENDA
    WHERE COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%'
    ;

    INSERT INTO TMP_TABLE_ENT(SESSION_ID,COD_CTP, COD_BU)
    SELECT V_SESSION_ID,COD_AZIENDA COD_CTP, 'SX' COD_BU
    FROM TGK_FIMA_HISENSE.AZIENDA
    WHERE COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%'
    ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '插入公司对应的事业部关系进入临时表', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
  ------------------------------------------------------------------------------
  -- 1.2A  处理分公司及总部线上政策数据
  ------------------------------------------------------------------------------

    --Step1 对所有的政策数据，根据账套+利润中心/业务管理单元+线上线下+客户去收入中进行查找，并标记STEP, GROUP
    UPDATE TMP_TABLE_POLICY M  SET STEP_ID = 'A_STEP1',
                                   GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
     WHERE EXISTS( SELECT 1
                     FROM (
                            --本期的收入中的账套+利润中心+线上线下+客户组合 非空调
                            SELECT COD_AZIENDA, LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, CUST_CODE
                              FROM AW_MR9_REVM01_000001_CON_TEMP
                            LEFT JOIN TMP_TABLE_ENT E
                                   ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                            WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                            WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                            ELSE 'OTH'
                                        END) = E.COD_BU
                                    AND COD_AZI_CTP = E.COD_CTP
                                    AND E.SESSION_ID = V_SESSION_ID
                             WHERE COD_SCENARIO = P_SCENARIO
                               AND COD_PERIODO = P_PERIODO
                               AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                      AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%'
                                                            OR ELEM LIKE '8%' OR ELEM LIKE 'G%')
                                                   )
                               --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                               AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                               --分公司&总公司线上
                               AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600')
                                    OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%')
                                    )
                               --开票收入、出库未开、退货未办且排除国际营销公司
                               AND COD_CONTO LIKE 'S60010%'
                               --AND COD_AZIENDA NOT LIKE '8%'
                               --AND COD_AZIENDA NOT LIKE 'G%'
                               AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                               --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                               AND MAP_REV1 <> 0
                               --剔除虚拟物料
                               AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                               --剔除配件
                               AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                               AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                               --限制内销
                               AND COD_DEST3 LIKE '2%'
                               /*20260226 新增排除锁定公司*/
                               /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                         FROM AW_RUL_DWMCRS_000001 T
                                                        WHERE REV05_FLAG = 'Y'
                                                          AND T.COD_SCENARIO = P_SCENARIO
                                                          AND T.COD_PERIODO = P_PERIODO
                                                          AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                       )*/
                               AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                               -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                               AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                          GROUP BY COD_AZIENDA, LTRIM(COD_DEST2,'0') , D_ONOFFLINE, CUST_CODE
                            HAVING ROUND(SUM(MAP_REV1),2) <> 0

                           UNION ALL

                            --本期的收入中的账套+利润中心+线上线下+客户组合 空调

                            SELECT COD_AZIENDA, LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, CUST_CODE
                              FROM AW_MR9_REVM01_000001_CON_TEMP
                         LEFT JOIN TMP_TABLE_ENT E
                                ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                         WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                         WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                         ELSE 'OTH'
                                     END) = E.COD_BU
                                 AND COD_AZI_CTP = E.COD_CTP
                                 AND E.SESSION_ID = V_SESSION_ID
                              WHERE COD_SCENARIO = P_SCENARIO
                                AND COD_PERIODO = P_PERIODO
                                AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                   )
                                --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                                AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                                --分公司&总公司线上
                                AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                                --开票收入、出库未开、退货未办且排除国际营销公司
                                AND COD_CONTO LIKE 'S60010%'
                                --AND COD_AZIENDA NOT LIKE '8%'
                                --AND COD_AZIENDA NOT LIKE 'G%'
                                AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                                --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                                AND MAP_REV1 <> 0
                                --剔除虚拟物料
                                AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                                --剔除配件
                                AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                                AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                                --限制内销
                                AND COD_DEST3 LIKE '2%'
                                 /*20260226 新增排除锁定公司*/
                                /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                          FROM AW_RUL_DWMCRS_000001 T
                                                         WHERE REV05_FLAG = 'Y'
                                                           AND T.COD_SCENARIO = P_SCENARIO
                                                           AND T.COD_PERIODO = P_PERIODO
                                                           AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                       )*/
                                AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                                -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                                AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                           GROUP BY COD_AZIENDA, LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, CUST_CODE
                             HAVING ROUND(SUM(MAP_REV1),2) <> 0
                           ) A1
                      WHERE M.COD_AZIENDA = A1.COD_AZIENDA
                        AND M.COD_DEST2 = A1.COD_DEST2
                        AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                        AND M.CUST_CODE = A1.CUST_CODE
              )
         AND M.SESSION_ID = V_SESSION_ID
         AND M.STEP_ID IS NULL

         AND (M.COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (M.COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND M.D_ONOFFLINE LIKE '020_ON%'))
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-update-A_STEP1', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --Step2 对没有匹配到的政策数据，根据滚动季度(上2个月中)账套+利润中心/业务范围+线上线下+客户去收入中进行查找前20物料，并标记STEP, GROUP
    --打标记
    UPDATE TMP_TABLE_POLICY M SET STEP_ID = 'A_STEP2_READY',
                                  GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
    WHERE EXISTS (SELECT 1
                    FROM (
                          SELECT COD_AZIENDA, LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE
                            FROM (
                                  SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE,
                                         ROW_NUMBER() OVER(PARTITION BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE ORDER BY REV DESC) RN
                                    FROM (
                                           --非空调
                                           SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, ROUND(SUM(MAP_REV1),2) REV
                                             FROM AW_MR9_REVM01_000001_CON_TEMP
                                        LEFT JOIN TMP_TABLE_ENT E
                                               ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                                        WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                                        WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                                        ELSE 'OTH'
                                                    END) = E.COD_BU
                                               AND COD_AZI_CTP = E.COD_CTP
                                               AND E.SESSION_ID = V_SESSION_ID
                                             WHERE --SUBSTR(COD_SCENARIO,1,4) || COD_PERIODO IN (v_per1, v_per2)
                                               1=1
                                              AND (
                                                  (COD_SCENARIO = v_per1_ACT
                                                  AND COD_PERIODO = v_per1_per
                                                  )
                                                  OR
                                                  (COD_SCENARIO = v_per2_ACT
                                                  AND COD_PERIODO = v_per2_per
                                                  )
                                                )
                                              AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                                          WHERE SESSION_ID = V_SESSION_ID
                                                                            --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                                            AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%'
                                                                                  OR ELEM LIKE '8%' OR ELEM LIKE 'G%')
                                                                        )
                                               --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                                               AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                                               AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                                               --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                                               AND COD_CONTO LIKE 'S60010%'
                                               --AND COD_AZIENDA NOT LIKE '8%'
                                               --AND COD_AZIENDA NOT LIKE 'G%'
                                               AND (CUST_CODE IS NOT NULL AND CUST_CODE <> 'ZZZZ')
                                               AND (MATERIAL_CODE IS NOT NULL AND MATERIAL_CODE <> 'ZZZZ')
                                               --剔除虚拟物料
                                               AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                                               --剔除配件
                                               AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                                               AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                                               --限制内销
                                               AND COD_DEST3 LIKE '2%'
                                               AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                                               /*20260226 新增排除锁定公司*/
                                               /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                                         FROM AW_RUL_DWMCRS_000001 T
                                                                        WHERE REV05_FLAG = 'Y'
                                                                          AND T.COD_SCENARIO = P_SCENARIO
                                                                          AND T.COD_PERIODO = P_PERIODO
                                                                          AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                                        )*/
                                              AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                                              -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                                              AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                                         GROUP BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE

                                          UNION ALL
                                          --空调
                                          SELECT COD_AZIENDA, D_SALE_DEPT AS COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, ROUND(SUM(MAP_REV1),2) REV
                                            FROM AW_MR9_REVM01_000001_CON_TEMP
                                       LEFT JOIN TMP_TABLE_ENT E
                                              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                                       ELSE 'OTH'
                                                   END) = E.COD_BU
                                              AND COD_AZI_CTP = E.COD_CTP
                                              AND E.SESSION_ID = V_SESSION_ID
                                            WHERE --SUBSTR(COD_SCENARIO,1,4) || COD_PERIODO IN (v_per1, v_per2)
                                              1=1
                                              AND (
                                                  ( COD_SCENARIO = v_per1_ACT
                                                  AND COD_PERIODO = v_per1_per
                                                  )
                                                  OR
                                                  (COD_SCENARIO = v_per2_ACT
                                                  AND COD_PERIODO = v_per2_per
                                                  )
                                                )
                                              AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                                          WHERE SESSION_ID = V_SESSION_ID
                                                                            AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                                            --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                                        )
                                              --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                                              AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                                              AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                                              --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                                              AND COD_CONTO LIKE 'S60010%'
                                              --AND COD_AZIENDA NOT LIKE '8%'
                                              --AND COD_AZIENDA NOT LIKE 'G%'
                                              AND (CUST_CODE IS NOT NULL AND CUST_CODE <> 'ZZZZ')
                                              AND (MATERIAL_CODE IS NOT NULL AND MATERIAL_CODE <> 'ZZZZ')
                                              --剔除虚拟物料
                                              AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                                              --剔除配件
                                              AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                                              AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                                              --限制内销
                                              AND COD_DEST3 LIKE '2%'
                                              AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                                              /*20260226 新增排除锁定公司*/
                                              /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                                        FROM AW_RUL_DWMCRS_000001 T
                                                                       WHERE REV05_FLAG = 'Y'
                                                                         AND T.COD_SCENARIO = P_SCENARIO
                                                                         AND T.COD_PERIODO = P_PERIODO
                                                                         AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                                      )*/
                                              AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                                              -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                                              AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                                         GROUP BY COD_AZIENDA, D_SALE_DEPT, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE
                                        ) T
                                   WHERE T.REV <> 0
                                  ) TT
                           WHERE RN <= 20
                      )A1
                WHERE M.COD_AZIENDA = A1.COD_AZIENDA
                  AND M.COD_DEST2 = A1.COD_DEST2
                  AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                  AND M.CUST_CODE = A1.CUST_CODE
                )
                AND M.SESSION_ID = V_SESSION_ID
                AND M.STEP_ID IS NULL
                AND (M.COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (M.COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND M.D_ONOFFLINE LIKE '020_ON%'))
 ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-update-A_STEP2_READY', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --扩展物料编码
    INSERT INTO TMP_TABLE_POLICY(SESSION_ID,D_CHANNEL,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)
    SELECT
        DISTINCT V_SESSION_ID,M.D_CHANNEL,M.COD_AZIENDA, M.COD_DEST2, M.D_ONOFFLINE, M.CUST_CODE, A1.MATERIAL_CODE, NULL COD_AZIENDA_NEW, M.POLICY_AMT, 'A_STEP2' STEP_ID, M.GROUP_ID
    FROM TMP_TABLE_POLICY M
    JOIN (
          SELECT COD_AZIENDA, LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE
            FROM (
                  SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE,
                         ROW_NUMBER() OVER(PARTITION BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE ORDER BY REV DESC) RN
                    FROM (
                            --非空调
                            SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, ROUND(SUM(MAP_REV1),2) REV
                              FROM AW_MR9_REVM01_000001_CON_TEMP
                         LEFT JOIN TMP_TABLE_ENT E
                               ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                        WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                        WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                        ELSE 'OTH'
                                     END) = E.COD_BU
                               AND COD_AZI_CTP = E.COD_CTP
                               AND E.SESSION_ID = V_SESSION_ID
                             WHERE /* SUBSTR(COD_SCENARIO,1,4) || COD_PERIODO IN (v_per1, v_per2) */
                               1=1
                               AND (
                                      (COD_SCENARIO = v_per1_ACT
                                      AND COD_PERIODO = v_per1_per
                                      )
                                      OR
                                      (COD_SCENARIO = v_per2_ACT
                                      AND COD_PERIODO = v_per2_per
                                      )
                                    )
                               AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                      AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%'
                                                             OR ELEM LIKE '8%' OR ELEM LIKE 'G%')
                                                   )
                               --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                               AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                               AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                               --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                               AND COD_CONTO LIKE 'S60010%'
                               --AND COD_AZIENDA NOT LIKE '8%'
                               --AND COD_AZIENDA NOT LIKE 'G%'
                               AND (CUST_CODE IS NOT NULL AND CUST_CODE <> 'ZZZZ')
                               AND (MATERIAL_CODE IS NOT NULL AND MATERIAL_CODE <> 'ZZZZ')
                               --剔除虚拟物料
                               AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                               --剔除配件
                               AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                               AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                               --限制内销
                               AND COD_DEST3 LIKE '2%'
                               AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                               /*20260226 新增排除锁定公司*/
                               /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                         FROM AW_RUL_DWMCRS_000001 T
                                                        WHERE REV05_FLAG = 'Y'
                                                          AND T.COD_SCENARIO = P_SCENARIO
                                                          AND T.COD_PERIODO = P_PERIODO
                                                          AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                       )*/
                              AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                         GROUP BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE

                      UNION ALL
                          --空调
                          SELECT COD_AZIENDA, D_SALE_DEPT AS COD_DEST2, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE, ROUND(SUM(MAP_REV1),2) REV
                            FROM AW_MR9_REVM01_000001_CON_TEMP
                       LEFT JOIN TMP_TABLE_ENT E
                              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                       ELSE 'OTH'
                                   END) = E.COD_BU
                             AND COD_AZI_CTP = E.COD_CTP
                             AND E.SESSION_ID = V_SESSION_ID
                           WHERE /* SUBSTR(COD_SCENARIO,1,4) || COD_PERIODO IN (v_per1, v_per2) */
                             1=1
                             AND (
                                    (COD_SCENARIO = v_per1_ACT
                                    AND COD_PERIODO = v_per1_per
                                    )
                                    OR
                                    (COD_SCENARIO = v_per2_ACT
                                    AND COD_PERIODO = v_per2_per
                                    )
                                  )
                             AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                   )
                             --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                             AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                             AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                             --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                             AND COD_CONTO LIKE 'S60010%'
                             --AND COD_AZIENDA NOT LIKE '8%'
                             --AND COD_AZIENDA NOT LIKE 'G%'
                             AND (CUST_CODE IS NOT NULL AND CUST_CODE <> 'ZZZZ')
                             AND (MATERIAL_CODE IS NOT NULL AND MATERIAL_CODE <> 'ZZZZ')
                             --剔除虚拟物料
                             AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                             --剔除配件
                             AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                             AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                             --限制内销
                             AND COD_DEST3 LIKE '2%'
                             AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                             /*20260226 新增排除锁定公司*/
                             /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                       FROM AW_RUL_DWMCRS_000001 T
                                                      WHERE REV05_FLAG = 'Y'
                                                        AND T.COD_SCENARIO = P_SCENARIO
                                                        AND T.COD_PERIODO = P_PERIODO
                                                        AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                      )*/
                            AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                       GROUP BY COD_AZIENDA, D_SALE_DEPT, D_ONOFFLINE, CUST_CODE, MATERIAL_CODE
                     ) T
                  WHERE T.REV <> 0
                ) TT
           WHERE RN <= 20
         ) A1
      ON M.COD_AZIENDA = A1.COD_AZIENDA
     AND M.COD_DEST2 = A1.COD_DEST2
     AND M.D_ONOFFLINE = A1.D_ONOFFLINE
     AND M.CUST_CODE = A1.CUST_CODE
   WHERE M.STEP_ID IN ('A_STEP2_READY')
   AND M.SESSION_ID = V_SESSION_ID
   ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-update-扩展物料编码', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

    --剔除原来STEP2的准备记录
    DELETE FROM TMP_TABLE_POLICY M WHERE M.STEP_ID IN ('A_STEP2_READY') AND M.SESSION_ID = V_SESSION_ID;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-剔除原来STEP2的准备记录', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

    --Step3 对所有的政策数据，根据账套+利润中心+线上线下+渠道去收入中进行查找，并标记STEP, GROUP
    UPDATE TMP_TABLE_POLICY M SET STEP_ID = 'A_STEP3',
                                  GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
    WHERE EXISTS(SELECT 1
                  FROM (
                        --非空调
                        SELECT DISTINCT COD_AZIENDA, LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE,
                               --【20260806 修改v2】收入端按D_ECOM_BU匹配；空/ZZZZ在WHERE中排除
                               CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                    THEN D_ECOM_BU
                                    ELSE D_CHANNEL
                                END AS D_CHANNEL
                          FROM AW_MR9_REVM01_000001_CON_TEMP
                     LEFT JOIN TMP_TABLE_ENT E
                            ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                     WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                     WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                    ELSE 'OTH'
                                 END) = E.COD_BU
                            AND COD_AZI_CTP = E.COD_CTP
                            AND E.SESSION_ID = V_SESSION_ID
                          WHERE COD_SCENARIO = P_SCENARIO
                            AND COD_PERIODO = P_PERIODO
                            AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                      AND NOT (ELEM LIKE '62%' OR ELEM LIKE '68%'
                                                             OR ELEM LIKE '8%' OR ELEM LIKE 'G%')
                                                   )
                            --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                            AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                            AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                            --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                            AND COD_CONTO LIKE 'S60010%'
                            --AND COD_AZIENDA NOT LIKE '8%'
                            --AND COD_AZIENDA NOT LIKE 'G%'
                            AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                            AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
                            --剔除虚拟物料
                            AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                            --剔除配件
                            AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                            AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                            --【20260806 修改v2】D_ECOM_BU为空或ZZZZ时不打A_STEP3，自然落入1.4未分配政策
                            AND NOT ((COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                     AND NVL(D_ECOM_BU,'ZZZZ') = 'ZZZZ')
                            --限制内销
                            AND COD_DEST3 LIKE '2%'
                            /*20260226 新增排除锁定公司*/
                            /*
                            20260907 修改人 shiqingfeng.ex 去掉所有锁定表限制，仅保留最上面参数session表限制
                            AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                      FROM AW_RUL_DWMCRS_000001 T
                                                     WHERE REV05_FLAG = 'Y'
                                                       AND T.COD_SCENARIO = P_SCENARIO
                                                       AND T.COD_PERIODO = P_PERIODO
                                                       AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                   )*/
                           AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                           -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                           AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                           -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 客户1001200/A012**不参与按公司三级分类(D_CHANNEL)的政策分摊
                           AND NVL(TRIM(CUST_CODE),'|') <> '1001200'
                           AND NVL(TRIM(CUST_CODE),'|') NOT LIKE 'A012%'
                          GROUP BY COD_AZIENDA, LTRIM(COD_DEST2,'0'), D_ONOFFLINE,
                               CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                    THEN D_ECOM_BU
                                    ELSE D_CHANNEL
                                END
                        HAVING ROUND(SUM(MAP_REV1),2) <> 0

                    UNION ALL
                        --空调
                        SELECT DISTINCT COD_AZIENDA, LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE,
                               CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                    THEN D_ECOM_BU
                                    ELSE D_CHANNEL
                                END AS D_CHANNEL
                          FROM AW_MR9_REVM01_000001_CON_TEMP
                     LEFT JOIN TMP_TABLE_ENT E
                          ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                   WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                   WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                  ELSE 'OTH'
                               END) = E.COD_BU
                         AND COD_AZI_CTP = E.COD_CTP
                         AND E.SESSION_ID = V_SESSION_ID
                       WHERE COD_SCENARIO = P_SCENARIO
                         AND COD_PERIODO = P_PERIODO
                         AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                   )
                         --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
                         AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
                         AND (COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND D_ONOFFLINE LIKE '020_ON%'))
                         --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                         AND COD_CONTO LIKE 'S60010%'
                         --AND COD_AZIENDA NOT LIKE '8%'
                         --AND COD_AZIENDA NOT LIKE 'G%'
                         AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                         AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
                         --剔除虚拟物料
                         AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                         --剔除配件
                         AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                         AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                         --限制内销
                         AND COD_DEST3 LIKE '2%'
                         /*20260226 新增排除锁定公司*/
                         /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                                   FROM AW_RUL_DWMCRS_000001 T
                                                  WHERE REV05_FLAG = 'Y'
                                                    AND T.COD_SCENARIO = P_SCENARIO
                                                    AND T.COD_PERIODO = P_PERIODO
                                                    AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                                  )*/
                         AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                         -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                         AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                         -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 客户1001200/A012**不参与按公司三级分类(D_CHANNEL)的政策分摊
                         AND NVL(TRIM(CUST_CODE),'|') <> '1001200'
                         AND NVL(TRIM(CUST_CODE),'|') NOT LIKE 'A012%'
                    GROUP BY COD_AZIENDA, LTRIM(D_SALE_DEPT,'0'), D_ONOFFLINE,
                             CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                                  THEN D_ECOM_BU
                                  ELSE D_CHANNEL
                              END
                      HAVING ROUND(SUM(MAP_REV1),2) <> 0
                     ) A1
              WHERE M.COD_AZIENDA = A1.COD_AZIENDA
                AND M.COD_DEST2 = A1.COD_DEST2
                AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                AND M.D_CHANNEL = A1.D_CHANNEL
            )
           AND M.SESSION_ID = V_SESSION_ID
           AND M.STEP_ID IS NULL
           AND (M.COD_AZIENDA NOT IN ('6700','6800','2000','2300','2600') OR (M.COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND M.D_ONOFFLINE LIKE '020_ON%'))
;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2A  处理分公司及总部线上政策数据-update-A_STEP3', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 1.2B  处理总公司线下政策数据
  ------------------------------------------------------------------------------
    --Step1 对所有的政策数据，根据账套+利润中心+线上线下+渠道+客户去收入中进行查找，并标记STEP, GROUP
    --打标记
    UPDATE TMP_TABLE_POLICY M SET STEP_ID = 'B_STEP1_READY',
                                  GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
    WHERE EXISTS(SELECT 1
                   FROM (
                        --非空调
                        SELECT DISTINCT
                               CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                    WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                    WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                END AS COD_AZIENDA,
                                LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE
                                ,D_CHANNEL, CUST_CODE
                        FROM AW_MR9_REVM01_000001_CON_TEMP
                   LEFT JOIN TMP_TABLE_ENT E
                          ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                   WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                   WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                   ELSE 'OTH'
                               END) = E.COD_BU
                          AND COD_AZI_CTP = E.COD_CTP
                          AND E.SESSION_ID = V_SESSION_ID
                        WHERE COD_SCENARIO = P_SCENARIO
                          AND COD_PERIODO = P_PERIODO
                          AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      AND (ELEM LIKE '63%' OR ELEM LIKE '67%' OR ELEM LIKE '2%')
                                                   )
                          --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
                          AND D_ONOFFLINE LIKE '020_OFF%'
                          --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                          AND COD_CONTO LIKE 'S60010%'
                          --AND COD_AZIENDA NOT LIKE '8%'
                          --AND COD_AZIENDA NOT LIKE 'G%'
                          AND  ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                          --剔除虚拟物料
                          AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                          --剔除配件
                          AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                          AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                          --限制内销
                          AND COD_DEST3 LIKE '2%'
                          AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                          -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                          AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                     GROUP BY CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                   WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                   WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                               END,
                               LTRIM(COD_DEST2,'0') , D_ONOFFLINE
                               ,D_CHANNEL, CUST_CODE
                       HAVING ROUND(SUM(MAP_REV1),2) <> 0

                      UNION ALL
                        --空调
                        SELECT DISTINCT
                               CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                    WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                    WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                END AS COD_AZIENDA,
                                LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
                        FROM AW_MR9_REVM01_000001_CON_TEMP
                   LEFT JOIN TMP_TABLE_ENT E
                          ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                   WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                   WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                   ELSE 'OTH'
                              END) = E.COD_BU
                         AND COD_AZI_CTP = E.COD_CTP
                         AND E.SESSION_ID = V_SESSION_ID
                       WHERE COD_SCENARIO = P_SCENARIO
                         AND COD_PERIODO = P_PERIODO
                         AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                                    WHERE SESSION_ID = V_SESSION_ID
                                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                                   )
                         --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
                         AND D_ONOFFLINE LIKE '020_OFF%'
                         --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                         AND COD_CONTO LIKE 'S60010%'
                         --AND COD_AZIENDA NOT LIKE '8%'
                         --AND COD_AZIENDA NOT LIKE 'G%'
                         AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                         --剔除虚拟物料
                         AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                         --剔除配件
                         AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                         AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                         --限制内销
                         AND COD_DEST3 LIKE '2%'
                         AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                         -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                         AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                        GROUP BY CASE
                                    WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                    WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                    WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                 END ,
                                LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
                         HAVING ROUND(SUM(MAP_REV1),2) <> 0
                      ) A1
                  WHERE (CASE WHEN M.COD_AZIENDA IN ('2000','2300','2600') THEN '2600' ELSE M.COD_AZIENDA END) = A1.COD_AZIENDA
                    AND M.COD_DEST2 = A1.COD_DEST2
                    AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                    AND M.D_CHANNEL = A1.D_CHANNEL
                    AND M.CUST_CODE = A1.CUST_CODE
              )
             AND M.SESSION_ID = V_SESSION_ID
             AND M.STEP_ID IS NULL
             AND M.COD_AZIENDA IN ('6700','6800','2000','2300','2600')
             AND M.D_ONOFFLINE LIKE '020_OFF%'
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-update-B_STEP1_READY', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

    --扩展账套编码
    INSERT INTO TMP_TABLE_POLICY(SESSION_ID,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)
    SELECT
        DISTINCT V_SESSION_ID,M.COD_AZIENDA, M.COD_DEST2, M.D_ONOFFLINE, M.D_CHANNEL, M.CUST_CODE, NULL MATERIAL_CODE, A1.COD_AZIENDA_NEW, M.POLICY_AMT, 'B_STEP1' STEP_ID, M.GROUP_ID
    FROM TMP_TABLE_POLICY M
    JOIN (
          --非空调
          SELECT DISTINCT COD_AZIENDA COD_AZIENDA_NEW,
                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                  END AS COD_AZIENDA,
                  LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
             FROM AW_MR9_REVM01_000001_CON_TEMP
        LEFT JOIN TMP_TABLE_ENT E
               ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                        WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                        WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                        ELSE 'OTH'
                    END) = E.COD_BU
              AND COD_AZI_CTP = E.COD_CTP
              AND E.SESSION_ID = V_SESSION_ID
             WHERE COD_SCENARIO = P_SCENARIO
               AND COD_PERIODO = P_PERIODO
               AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '63%' OR ELEM LIKE '67%' OR ELEM LIKE '2%')
                                   )
               --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
               AND D_ONOFFLINE LIKE '020_OFF%'
               --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
               AND COD_CONTO LIKE 'S60010%'
               --AND COD_AZIENDA NOT LIKE '8%'
               --AND COD_AZIENDA NOT LIKE 'G%'
               AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
               --剔除虚拟物料
               AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
               --剔除配件
               AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
               AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
               --限制内销
               AND COD_DEST3 LIKE '2%'
               AND NVL(SRC_DETAIL,'|') <> 'REVM01'
          GROUP BY COD_AZIENDA ,
                   CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                        WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                        WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                   END ,
                  LTRIM(COD_DEST2,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
           HAVING ROUND(SUM(MAP_REV1),2) <> 0

          UNION ALL

              --非空调
          SELECT DISTINCT COD_AZIENDA COD_AZIENDA_NEW,
                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                  END AS COD_AZIENDA,
                  LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
            FROM AW_MR9_REVM01_000001_CON_TEMP
       LEFT JOIN TMP_TABLE_ENT E
              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                       ELSE 'OTH'
                   END) = E.COD_BU
             AND COD_AZI_CTP = E.COD_CTP
             AND E.SESSION_ID = V_SESSION_ID
           WHERE COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
             AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                   )
             --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
             AND D_ONOFFLINE LIKE '020_OFF%'
             --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
             AND COD_CONTO LIKE 'S60010%'
             --AND COD_AZIENDA NOT LIKE '8%'
             --AND COD_AZIENDA NOT LIKE 'G%'
             AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
             --剔除虚拟物料
             AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
             --剔除配件
             AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
             AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
             --限制内销
             AND COD_DEST3 LIKE '2%'
             AND NVL(SRC_DETAIL,'|') <> 'REVM01'
        GROUP BY COD_AZIENDA ,
                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                  END ,
                  LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
         HAVING ROUND(SUM(MAP_REV1),2) <> 0
        ) A1
       ON CASE WHEN M.COD_AZIENDA IN ('2000','2300','2600') THEN '2600' ELSE M.COD_AZIENDA END = A1.COD_AZIENDA
      AND M.COD_DEST2 = A1.COD_DEST2
      AND M.D_ONOFFLINE = A1.D_ONOFFLINE
      AND M.D_CHANNEL = A1.D_CHANNEL
      AND M.CUST_CODE = A1.CUST_CODE
    WHERE M.STEP_ID IN ('B_STEP1_READY')
      AND M.SESSION_ID = V_SESSION_ID
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-扩展账套编码', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --剔除原来STEP1的准备记录
    DELETE FROM TMP_TABLE_POLICY M WHERE M.STEP_ID IN ('B_STEP1_READY') AND M.SESSION_ID = V_SESSION_ID;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-剔除原来STEP1的准备记录', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --Step2 对所有的政策数据，根据账套+利润中心+线上线下+渠道去收入中进行查找，并标记STEP, GROUP
    --打标记
    UPDATE TMP_TABLE_POLICY M SET STEP_ID = 'B_STEP2_READY',
                                  GROUP_ID = COD_AZIENDA||'_'||COD_DEST2||'_'||D_ONOFFLINE||'_'||D_CHANNEL||'_'||CUST_CODE
    WHERE EXISTS( SELECT 1
                    FROM (
                          --非空调
                          SELECT DISTINCT
                                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                 END AS COD_AZIENDA,
                                 LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL
                            FROM AW_MR9_REVM01_000001_CON_TEMP
                       LEFT JOIN TMP_TABLE_ENT E
                              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                       ELSE 'OTH'
                                   END) = E.COD_BU
                              AND COD_AZI_CTP = E.COD_CTP
                              AND E.SESSION_ID = V_SESSION_ID
                            WHERE COD_SCENARIO = P_SCENARIO
                              AND COD_PERIODO = P_PERIODO
                              AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '63%' OR ELEM LIKE '67%' OR ELEM LIKE '2%')
                                   )
                              --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
                              AND D_ONOFFLINE LIKE '020_OFF%'
                              --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                              AND COD_CONTO LIKE 'S60010%'
                              --AND COD_AZIENDA NOT LIKE '8%'
                              --AND COD_AZIENDA NOT LIKE 'G%'
                              AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                              AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
                              --剔除虚拟物料
                              AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                              --剔除配件
                              AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                              AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                              --限制内销
                              AND COD_DEST3 LIKE '2%'
                              AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                              -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                              AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                              -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 客户1001200/A012**不参与按公司三级分类(D_CHANNEL)的政策分摊
                              AND NVL(TRIM(CUST_CODE),'|') <> '1001200'
                              AND NVL(TRIM(CUST_CODE),'|') NOT LIKE 'A012%'
                         GROUP BY CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                       WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                       WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                   END ,
                                  LTRIM(COD_DEST2,'0') , D_ONOFFLINE, D_CHANNEL
                          HAVING ROUND(SUM(MAP_REV1),2) <> 0

                          UNION ALL
                          --空调
                          SELECT DISTINCT
                                 CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                  END AS COD_AZIENDA,
                                  LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL
                            FROM AW_MR9_REVM01_000001_CON_TEMP
                      LEFT JOIN TMP_TABLE_ENT E
                             ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                                      WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                                      WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                                      ELSE 'OTH'
                                  END) = E.COD_BU
                            AND COD_AZI_CTP = E.COD_CTP
                            AND E.SESSION_ID = V_SESSION_ID
                          WHERE COD_SCENARIO = P_SCENARIO
                            AND COD_PERIODO = P_PERIODO
                            AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                   )
                            --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
                            AND D_ONOFFLINE LIKE '020_OFF%'
                            --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
                            AND COD_CONTO LIKE 'S60010%'
                            --AND COD_AZIENDA NOT LIKE '8%'
                            --AND COD_AZIENDA NOT LIKE 'G%'
                            AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
                            AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
                            --剔除虚拟物料
                            AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
                            --剔除配件
                            AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                            AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                            --限制内销
                            AND COD_DEST3 LIKE '2%'
                            AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                            -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                            AND NVL(D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                            -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 客户1001200/A012**不参与按公司三级分类(D_CHANNEL)的政策分摊
                            AND NVL(TRIM(CUST_CODE),'|') <> '1001200'
                            AND NVL(TRIM(CUST_CODE),'|') NOT LIKE 'A012%'
                        GROUP BY CASE WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                                      WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                                      WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                                 END ,
                                 LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, D_CHANNEL
                          HAVING ROUND(SUM(MAP_REV1),2) <> 0
                        ) A1
                    WHERE CASE WHEN M.COD_AZIENDA IN ('2000','2300','2600') THEN '2600' ELSE M.COD_AZIENDA END = A1.COD_AZIENDA
                      AND M.COD_DEST2 = A1.COD_DEST2
                      AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                      AND M.D_CHANNEL = A1.D_CHANNEL
             )
            AND M.SESSION_ID = V_SESSION_ID
            AND M.STEP_ID IS NULL
            AND M.COD_AZIENDA IN ('6700','6800','2000','2300','2600') AND M.D_ONOFFLINE LIKE '020_OFF%'
 ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-B_STEP2_READY', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;


    --扩展账套编码
    INSERT INTO TMP_TABLE_POLICY(SESSION_ID,COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE, MATERIAL_CODE, COD_AZIENDA_NEW, POLICY_AMT, STEP_ID, GROUP_ID)
    SELECT
        DISTINCT V_SESSION_ID,M.COD_AZIENDA, M.COD_DEST2, M.D_ONOFFLINE, M.D_CHANNEL, M.CUST_CODE, NULL MATERIAL_CODE, A1.COD_AZIENDA_NEW, M.POLICY_AMT, 'B_STEP2' STEP_ID, M.GROUP_ID
    FROM TMP_TABLE_POLICY M
    JOIN
          (
          --非空调
          SELECT DISTINCT
                 COD_AZIENDA COD_AZIENDA_NEW,
                 CASE
                     WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                     WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                     WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                 END AS COD_AZIENDA,
                 LTRIM(COD_DEST2,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
            FROM AW_MR9_REVM01_000001_CON_TEMP
       LEFT JOIN TMP_TABLE_ENT E
              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                       ELSE 'OTH'
                   END) = E.COD_BU
             AND COD_AZI_CTP = E.COD_CTP
             AND E.SESSION_ID = V_SESSION_ID
           WHERE COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
             AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '63%' OR ELEM LIKE '67%' OR ELEM LIKE '2%')
                                   )
             --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
             AND D_ONOFFLINE LIKE '020_OFF%'
             --AND NOT (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
             AND COD_CONTO LIKE 'S60010%'
             --AND COD_AZIENDA NOT LIKE '8%'
             --AND COD_AZIENDA NOT LIKE 'G%'
             AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
             AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
             --剔除虚拟物料
             AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
             --剔除配件
             AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
             AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
             --限制内销
             AND COD_DEST3 LIKE '2%'
             AND NVL(SRC_DETAIL,'|') <> 'REVM01'
        GROUP BY COD_AZIENDA ,
                 CASE
                     WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                     WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                     WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                 END ,
                 LTRIM(COD_DEST2,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
         HAVING ROUND(SUM(MAP_REV1),2) <> 0

         UNION ALL
          --空调
          SELECT DISTINCT
                 COD_AZIENDA COD_AZIENDA_NEW,
                 CASE
                     WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                     WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                     WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                 END AS COD_AZIENDA,
                 LTRIM(D_SALE_DEPT,'0') COD_DEST2, D_ONOFFLINE, D_CHANNEL, CUST_CODE
            FROM AW_MR9_REVM01_000001_CON_TEMP
       LEFT JOIN TMP_TABLE_ENT E
              ON (CASE WHEN COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' THEN 'BX'
                       WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN 'KT'
                       WHEN COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' THEN 'SX'
                       ELSE 'OTH'
                   END) = E.COD_BU
             AND COD_AZI_CTP = E.COD_CTP
             AND E.SESSION_ID = V_SESSION_ID
           WHERE COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO = P_PERIODO
             AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '62%' OR ELEM LIKE '68%')
                                   )
             --AND (COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%' OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '2%')
             AND D_ONOFFLINE LIKE '020_OFF%'
             --AND (COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%')
             AND COD_CONTO LIKE 'S60010%'
             --AND COD_AZIENDA NOT LIKE '8%'
             --AND COD_AZIENDA NOT LIKE 'G%'
             AND ((COD_AZI_CTP IS NULL OR COD_AZI_CTP = 'ZZZZ') OR (COD_AZI_CTP <> 'ZZZZ' AND COD_CTP IS NULL))
             AND INSTR(V_AZI_CTP, NVL(COD_AZI_CTP,'|')) = 0
             --剔除虚拟物料
             AND INSTR(V_MATERIAL, MATERIAL_CODE) = 0
             --剔除配件
             AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
             AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
             --限制内销
             AND COD_DEST3 LIKE '2%'
             AND NVL(SRC_DETAIL,'|') <> 'REVM01'
        GROUP BY COD_AZIENDA ,
                 CASE
                     WHEN COD_AZIENDA LIKE '67%' THEN '6700'
                     WHEN COD_AZIENDA LIKE '68%' THEN '6800'
                     WHEN COD_AZIENDA LIKE '26%' OR COD_AZIENDA LIKE '23%' THEN '2600'
                 END ,
                 LTRIM(D_SALE_DEPT,'0') , D_ONOFFLINE, D_CHANNEL, CUST_CODE
         HAVING ROUND(SUM(MAP_REV1),2) <> 0
        ) A1
    ON (CASE WHEN M.COD_AZIENDA IN ('2000','2300','2600') THEN '2600' ELSE M.COD_AZIENDA END) = A1.COD_AZIENDA
   AND M.COD_DEST2 = A1.COD_DEST2
   AND M.D_ONOFFLINE = A1.D_ONOFFLINE
   AND M.D_CHANNEL = A1.D_CHANNEL
 WHERE M.STEP_ID IN ('B_STEP2_READY')
 AND M.SESSION_ID = V_SESSION_ID
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1.2B  处理总公司线下政策数据-扩展账套编码', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;
    --剔除原来STEP2的准备记录
    DELETE FROM TMP_TABLE_POLICY M
    WHERE M.STEP_ID IN ('B_STEP2_READY')
    AND M.SESSION_ID = V_SESSION_ID;

    -- 1.2 总分公司政策分摊与收入匹配完成
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.2 总分公司政策分摊与收入匹配完成',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 1.3  生成政策分摊数据
  ------------------------------------------------------------------------------
/*
    --在每条收入明细上，生成对应的分摊数据
    INSERT INTO TMP_TABLE_POLICY_ALLOC(SESSION_ID,OID,STEP_ID,GROUP_ID,MAP_REV1,POLICY_AMT,POLICY_ALC_AMT
                                       ,BL,MAX_ABS_BL)
    SELECT
        V_SESSION_ID,OID, STEP_ID, GROUP_ID, MAP_REV1, POLICY_AMT
        \*20260714 shiqingfeng.ex 如果组内任意一行的分摊比例绝对值>10，则整组不参与分摊*\
        , POLICY_AMT*CASE WHEN MAX_ABS_BL > 10 THEN 0 ELSE BL END AS POLICY_ALC_AMT
        , BL
        , MAX_ABS_BL
    FROM(
      SELECT T2.*,
             -- 组内最大绝对比例，用于判断整组是否排除
             MAX(ABS(T2.BL)) OVER(PARTITION BY T2.STEP_ID, T2.GROUP_ID) AS MAX_ABS_BL
       FROM
       (
          SELECT
                A1.STEP_ID, A1.GROUP_ID, M.OID,
                M.MAP_REV1,
                A1.POLICY_AMT,
                CASE
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) <> 0
                    THEN M.MAP_REV1/SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) = 0 AND M.MAP_REV1 > 0
                    THEN (CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END)/SUM(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                END BL\*,
                CASE
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) <> 0
                    THEN A1.POLICY_AMT*M.MAP_REV1/SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) = 0 AND M.MAP_REV1 > 0
                    THEN A1.POLICY_AMT*(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END)/SUM(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                END AS POLICY_ALC_AMT*\
           FROM (
                  SELECT OID, COD_SCENARIO, COD_PERIODO, COD_AZIENDA,
                         (CASE WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN D_SALE_DEPT ELSE COD_DEST2 END) AS COD_DEST2,
                         --【20260806 修改v2】1180/12**收入明细按D_ECOM_BU与政策匹配
                         D_ONOFFLINE,
                         CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                              THEN D_ECOM_BU
                              ELSE D_CHANNEL
                          END AS D_CHANNEL,
                         CUST_CODE, MATERIAL_CODE, COD_AZI_CTP,MAP_REV1
                   FROM AW_MR9_REVM01_000001_CON_TEMP T
                  WHERE --SUBSTR(T.COD_SCENARIO,1,4) || T.COD_PERIODO IN (v_per0, v_per1, v_per2)
                    1=1
                    AND (
                           (T.COD_SCENARIO = v_per0_ACT
                          AND T.COD_PERIODO = v_per0_per
                           )
                          OR
                           (T.COD_SCENARIO = v_per1_ACT
                          AND T.COD_PERIODO = v_per1_per
                          )
                          OR
                           (T.COD_SCENARIO = v_per2_ACT
                          AND T.COD_PERIODO = v_per2_per
                          )
                        )
                    AND T.COD_CONTO LIKE 'S60010%'
                    --AND T.COD_AZIENDA NOT LIKE '8%'
                    --AND T.COD_AZIENDA NOT LIKE 'G%'
                    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND ELEM NOT LIKE '8%'
                                      AND ELEM NOT LIKE 'G%'
                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                      AND ELEM NOT IN(SELECT ELEM
                                                        FROM SESSION_V_REF_AZIENDA
                                                       WHERE 1=1
                                                         AND SESSION_ID = V_SESSION_ID
                                                         AND HIE = '10'
                                                         AND NODE = '050')
                                    )
                    --AND INSTR(V_HITACHI_AZIENDA,T.COD_AZIENDA) = 0
                    AND T.MAP_REV1 <> 0
                    --剔除虚拟物料
                    AND  NOT EXISTS (SELECT 1
                                       FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 tT
                                      WHERE TT.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
                                        AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                                        AND TT.MATERIAL_CODE IS NOT NULL
                                        AND T.MATERIAL_CODE = TT.MATERIAL_CODE
                                      )
                    --AND INSTR(V_MATERIAL, T.MATERIAL_CODE) = 0
                    --剔除配件
                    --AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                    AND NOT EXISTS
                      (  SELECT 1
                           FROM TGK_FIMA_HISENSE.AW_RUL_PROCLS_000001 A
                          WHERE  a.D_PRO_CLASS =  SUBSTR(NVL(t.D_PRO_CLASS,'|'),1,5)
                       )

                    AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                    --限制内销
                    AND COD_DEST3 LIKE '2%'
                    AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                ) M

           JOIN  (
                SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL,
                       CASE WHEN STEP_ID IN ('A_STEP3','B_STEP2') THEN NULL ELSE CUST_CODE END CUST_CODE,
                       CASE WHEN STEP_ID IN ('A_STEP2') THEN MATERIAL_CODE ELSE NULL END MATERIAL_CODE,
                       CASE WHEN STEP_ID IN ('B_STEP1','B_STEP2') THEN COD_AZIENDA_NEW ELSE NULL END COD_AZIENDA_NEW,
                       SUM(POLICY_AMT) POLICY_AMT,
                       STEP_ID,GROUP_ID
                  FROM TMP_TABLE_POLICY
                 WHERE SESSION_ID = V_SESSION_ID
                   AND STEP_ID IS NOT NULL
              GROUP BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL,
                       CASE WHEN STEP_ID IN ('A_STEP3','B_STEP2') THEN NULL ELSE CUST_CODE END ,
                       CASE WHEN STEP_ID IN ('A_STEP2') THEN MATERIAL_CODE ELSE NULL END ,
                       CASE WHEN STEP_ID IN ('B_STEP1','B_STEP2') THEN COD_AZIENDA_NEW ELSE NULL END,
                       STEP_ID,GROUP_ID
                ) A1
             ON ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
                 \*M.COD_SCENARIO = v_per0_ACT AND M.COD_PERIODO = v_per0_per*\
                 AND A1.STEP_ID IN ('A_STEP1') AND M.COD_AZIENDA = A1.COD_AZIENDA AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.CUST_CODE = A1.CUST_CODE)
             OR ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per1, v_per2)
                  \*(M.COD_SCENARIO = v_per1_ACT AND M.COD_PERIODO = v_per1_per
                   OR M.COD_SCENARIO = v_per2_ACT AND M.COD_PERIODO = v_per2_per)*\
                 AND A1.STEP_ID IN ('A_STEP2') AND M.COD_AZIENDA = A1.COD_AZIENDA AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.CUST_CODE = A1.CUST_CODE AND M.MATERIAL_CODE = A1.MATERIAL_CODE)
             OR ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
                  \*M.COD_SCENARIO = v_per0_ACT AND M.COD_PERIODO = v_per0_per*\
                  AND A1.STEP_ID IN ('A_STEP3') AND M.COD_AZIENDA = A1.COD_AZIENDA AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.D_CHANNEL = A1.D_CHANNEL)
             OR ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
                  \*M.COD_SCENARIO = v_per0_ACT AND M.COD_PERIODO = v_per0_per*\
                  AND A1.STEP_ID IN ('B_STEP1') AND M.COD_AZIENDA = A1.COD_AZIENDA_NEW AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.D_CHANNEL = A1.D_CHANNEL AND M.CUST_CODE = A1.CUST_CODE)
             OR ( SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
                  \*M.COD_SCENARIO = v_per0_ACT AND M.COD_PERIODO = v_per0_per*\
                  AND A1.STEP_ID IN ('B_STEP2') AND M.COD_AZIENDA = A1.COD_AZIENDA_NEW AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2 AND M.D_ONOFFLINE = A1.D_ONOFFLINE AND M.D_CHANNEL = A1.D_CHANNEL)
      LEFT JOIN TMP_TABLE_ENT A2
             ON (CASE WHEN M.COD_AZIENDA LIKE '63%' OR M.COD_AZIENDA LIKE '67%' THEN 'BX'
                      WHEN M.COD_AZIENDA LIKE '62%' OR M.COD_AZIENDA LIKE '68%' THEN 'KT'
                      WHEN M.COD_AZIENDA LIKE '2%' THEN 'SX'
                      ELSE 'OTH'
                  END) = A2.COD_BU
            AND M.COD_AZI_CTP = A2.COD_CTP
            AND A2.SESSION_ID = V_SESSION_ID
          WHERE ((M.COD_AZI_CTP IS NULL OR M.COD_AZI_CTP = 'ZZZZ') OR (M.COD_AZI_CTP <> 'ZZZZ' AND A2.COD_CTP IS NULL))
        ) T2
      ) T
  WHERE T.POLICY_AMT*BL <> 0
  \*20260714 shiqingfeng.ex 如果组内任意一行的分摊比例绝对值>10，则整组不参与分摊*\
  --AND T.MAX_ABS_BL <= 10
;*/


  ------------------------------------------------------------------------------
  -- 1.3  生成政策分摊数据
  ------------------------------------------------------------------------------

    --在每条收入明细上，生成对应的分摊数据
    INSERT INTO TMP_TABLE_POLICY_ALLOC(SESSION_ID,OID,STEP_ID,GROUP_ID,MAP_REV1,POLICY_AMT,POLICY_ALC_AMT
                                       ,BL,MAX_ABS_BL)
    SELECT
        V_SESSION_ID,OID, STEP_ID, GROUP_ID, MAP_REV1, POLICY_AMT
        /*20260714 shiqingfeng.ex 如果组内任意一行的分摊比例绝对值>10，则整组不参与分摊*/
        , POLICY_AMT*CASE WHEN MAX_ABS_BL > 10 THEN 0 ELSE BL END AS POLICY_ALC_AMT
        , BL
        , MAX_ABS_BL
    FROM(
      SELECT T2.*,
             -- 组内最大绝对比例，用于判断整组是否排除
             MAX(ABS(T2.BL)) OVER(PARTITION BY T2.STEP_ID, T2.GROUP_ID) AS MAX_ABS_BL
       FROM
       (
          SELECT
                A1.STEP_ID, A1.GROUP_ID, M.OID,
                M.MAP_REV1,
                A1.POLICY_AMT,
                CASE
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) <> 0
                    THEN M.MAP_REV1/SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) = 0 AND M.MAP_REV1 > 0
                    THEN (CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END)/SUM(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                END BL/*,
                CASE
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) <> 0
                    THEN A1.POLICY_AMT*M.MAP_REV1/SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                  WHEN ROUND(SUM(MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID),2) = 0 AND M.MAP_REV1 > 0
                    THEN A1.POLICY_AMT*(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END)/SUM(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                END AS POLICY_ALC_AMT*/
           FROM
           (
                SELECT COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL,
                       CASE WHEN STEP_ID IN ('A_STEP3','B_STEP2') THEN NULL ELSE CUST_CODE END CUST_CODE,
                       CASE WHEN STEP_ID IN ('A_STEP2') THEN MATERIAL_CODE ELSE NULL END MATERIAL_CODE,
                       CASE WHEN STEP_ID IN ('B_STEP1','B_STEP2') THEN COD_AZIENDA_NEW ELSE NULL END COD_AZIENDA_NEW,
                       SUM(POLICY_AMT) POLICY_AMT,
                       STEP_ID,GROUP_ID
                  FROM TMP_TABLE_POLICY
                 WHERE SESSION_ID = V_SESSION_ID
                   AND STEP_ID IN ('A_STEP1','A_STEP3','B_STEP1','B_STEP2')
              GROUP BY COD_AZIENDA, COD_DEST2, D_ONOFFLINE, D_CHANNEL,
                       CASE WHEN STEP_ID IN ('A_STEP3','B_STEP2') THEN NULL ELSE CUST_CODE END ,
                       CASE WHEN STEP_ID IN ('A_STEP2') THEN MATERIAL_CODE ELSE NULL END ,
                       CASE WHEN STEP_ID IN ('B_STEP1','B_STEP2') THEN COD_AZIENDA_NEW ELSE NULL END,
                       STEP_ID,GROUP_ID
                ) A1


           JOIN (
                  SELECT OID, COD_SCENARIO, COD_PERIODO, COD_AZIENDA,
                         (CASE WHEN COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' THEN D_SALE_DEPT ELSE COD_DEST2 END) AS COD_DEST2,
                         --【20260806 修改v2】1180/12**收入明细按D_ECOM_BU与政策匹配
                         D_ONOFFLINE,
                         CASE WHEN (COD_AZIENDA = '1180' OR COD_AZIENDA LIKE '12%')
                              THEN D_ECOM_BU
                              ELSE D_CHANNEL
                          END AS D_CHANNEL,
                         CUST_CODE, MATERIAL_CODE, COD_AZI_CTP,MAP_REV1
                   FROM AW_MR9_REVM01_000001_CON_TEMP T
                  WHERE T.COD_SCENARIO = v_per0_ACT
                    AND T.COD_PERIODO = v_per0_per
                    AND T.COD_CONTO LIKE 'S60010%'
                    --AND T.COD_AZIENDA NOT LIKE '8%'
                    --AND T.COD_AZIENDA NOT LIKE 'G%'
                    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND ELEM NOT LIKE '8%'
                                      AND ELEM NOT LIKE 'G%'
                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                      AND ELEM NOT IN(SELECT ELEM
                                                        FROM SESSION_V_REF_AZIENDA
                                                       WHERE 1=1
                                                         AND SESSION_ID = V_SESSION_ID
                                                         AND HIE = '10'
                                                         AND NODE = '050')
                                    )
                    --AND INSTR(V_HITACHI_AZIENDA,T.COD_AZIENDA) = 0
                    AND T.MAP_REV1 <> 0
                    --剔除虚拟物料
                    AND  NOT EXISTS (SELECT 1
                                       FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 tT
                                      WHERE TT.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
                                        AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                                        AND TT.MATERIAL_CODE IS NOT NULL
                                        AND T.MATERIAL_CODE = TT.MATERIAL_CODE
                                      )
                    --AND INSTR(V_MATERIAL, T.MATERIAL_CODE) = 0
                    --剔除配件
                    --AND INSTR(V_PRO_CLASS, SUBSTR(NVL(D_PRO_CLASS,'|'),1,5)) = 0
                    AND NOT EXISTS
                      (  SELECT 1
                           FROM TGK_FIMA_HISENSE.AW_RUL_PROCLS_000001 A
                          WHERE  a.D_PRO_CLASS =  SUBSTR(NVL(t.D_PRO_CLASS,'|'),1,5)
                       )

                    AND NVL(MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                    --限制内销
                    AND COD_DEST3 LIKE '2%'
                    AND NVL(SRC_DETAIL,'|') <> 'REVM01'
                    -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                    AND NVL(T.D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                ) M
             ON (A1.STEP_ID = 'A_STEP1'
                 AND M.COD_AZIENDA = A1.COD_AZIENDA
                 AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2
                 AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                 AND M.CUST_CODE = A1.CUST_CODE)
             OR (A1.STEP_ID = 'A_STEP3'
                 AND M.COD_AZIENDA = A1.COD_AZIENDA
                 AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2
                 AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                 AND M.D_CHANNEL = A1.D_CHANNEL
                 -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 客户1001200/A012**不参与按公司三级分类(D_CHANNEL)的政策分摊
                 AND NVL(TRIM(M.CUST_CODE),'|') <> '1001200'
                 AND NVL(TRIM(M.CUST_CODE),'|') NOT LIKE 'A012%'
                 )
             OR (A1.STEP_ID = 'B_STEP1'
                 AND M.COD_AZIENDA = A1.COD_AZIENDA_NEW
                 AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2
                 AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                 AND M.D_CHANNEL = A1.D_CHANNEL
                 AND M.CUST_CODE = A1.CUST_CODE)
             OR (A1.STEP_ID = 'B_STEP2'
                 AND M.COD_AZIENDA = A1.COD_AZIENDA_NEW
                 AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2
                 AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                 AND M.D_CHANNEL = A1.D_CHANNEL
                 -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 客户1001200/A012**不参与按公司三级分类(D_CHANNEL)的政策分摊
                 AND NVL(TRIM(M.CUST_CODE),'|') <> '1001200'
                 AND NVL(TRIM(M.CUST_CODE),'|') NOT LIKE 'A012%'
                 )
      LEFT JOIN TMP_TABLE_ENT A2
             ON (CASE WHEN M.COD_AZIENDA LIKE '63%' OR M.COD_AZIENDA LIKE '67%' THEN 'BX'
                      WHEN M.COD_AZIENDA LIKE '62%' OR M.COD_AZIENDA LIKE '68%' THEN 'KT'
                      WHEN M.COD_AZIENDA LIKE '2%' THEN 'SX'
                      ELSE 'OTH'
                  END) = A2.COD_BU
            AND M.COD_AZI_CTP = A2.COD_CTP
            AND A2.SESSION_ID = V_SESSION_ID
          WHERE ((M.COD_AZI_CTP IS NULL OR M.COD_AZI_CTP = 'ZZZZ') OR (M.COD_AZI_CTP <> 'ZZZZ' AND A2.COD_CTP IS NULL))
        ) T2
      ) T
  WHERE T.POLICY_AMT*BL <> 0
  /*20260714 shiqingfeng.ex 如果组内任意一行的分摊比例绝对值>10，则整组不参与分摊*/
  --AND T.MAX_ABS_BL <= 10
;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.3 生成政策分摊数据-本月',P_AZIENDA);

    --上两月：A_STEP2仍合并计算分摊比例，保持原跨两月分母口径
    INSERT INTO TMP_TABLE_POLICY_ALLOC(SESSION_ID,OID,STEP_ID,GROUP_ID,MAP_REV1,POLICY_AMT,POLICY_ALC_AMT
                                       ,BL,MAX_ABS_BL)
    SELECT V_SESSION_ID, OID, STEP_ID, GROUP_ID, MAP_REV1, POLICY_AMT,
           POLICY_AMT * CASE WHEN MAX_ABS_BL > 10 THEN 0 ELSE BL END AS POLICY_ALC_AMT,
           BL,
           MAX_ABS_BL
      FROM (
            SELECT T2.*,
                   MAX(ABS(T2.BL)) OVER(PARTITION BY T2.STEP_ID, T2.GROUP_ID) AS MAX_ABS_BL
              FROM (
                    SELECT A1.STEP_ID,
                           A1.GROUP_ID,
                           M.OID,
                           M.MAP_REV1,
                           A1.POLICY_AMT,
                           CASE
                             WHEN ROUND(SUM(M.MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID), 2) <> 0
                               THEN M.MAP_REV1 / SUM(M.MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                             WHEN ROUND(SUM(M.MAP_REV1) OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID), 2) = 0
                                  AND M.MAP_REV1 > 0
                               THEN M.MAP_REV1
                                    / SUM(CASE WHEN M.MAP_REV1 > 0 THEN M.MAP_REV1 ELSE 0 END)
                                      OVER(PARTITION BY A1.STEP_ID, A1.GROUP_ID)
                           END AS BL
                      FROM (
                            SELECT COD_AZIENDA,
                                   COD_DEST2,
                                   D_ONOFFLINE,
                                   D_CHANNEL,
                                   CUST_CODE,
                                   MATERIAL_CODE,
                                   NULL AS COD_AZIENDA_NEW,
                                   SUM(POLICY_AMT) AS POLICY_AMT,
                                   STEP_ID,
                                   GROUP_ID
                              FROM TMP_TABLE_POLICY
                             WHERE SESSION_ID = V_SESSION_ID
                               AND STEP_ID = 'A_STEP2'
                          GROUP BY COD_AZIENDA,
                                   COD_DEST2,
                                   D_ONOFFLINE,
                                   D_CHANNEL,
                                   CUST_CODE,
                                   MATERIAL_CODE,
                                   STEP_ID,
                                   GROUP_ID
                           ) A1
                      JOIN (
                            SELECT T.OID,
                                   T.COD_SCENARIO,
                                   T.COD_PERIODO,
                                   T.COD_AZIENDA,
                                   CASE
                                     WHEN T.COD_AZIENDA LIKE '62%' OR T.COD_AZIENDA LIKE '68%'
                                       THEN T.D_SALE_DEPT
                                     ELSE T.COD_DEST2
                                   END AS COD_DEST2,
                                   T.D_ONOFFLINE,
                                   CASE
                                     WHEN T.COD_AZIENDA = '1180' OR T.COD_AZIENDA LIKE '12%'
                                       THEN T.D_ECOM_BU
                                     ELSE T.D_CHANNEL
                                   END AS D_CHANNEL,
                                   T.CUST_CODE,
                                   T.MATERIAL_CODE,
                                   T.COD_AZI_CTP,
                                   T.MAP_REV1
                              FROM AW_MR9_REVM01_000001_CON_TEMP T
                             WHERE ((T.COD_SCENARIO = v_per1_ACT AND T.COD_PERIODO = v_per1_per)
                                 OR (T.COD_SCENARIO = v_per2_ACT AND T.COD_PERIODO = v_per2_per))
                               AND T.COD_CONTO LIKE 'S60010%'
                               AND T.COD_AZIENDA IN (
                                       SELECT ELEM
                                         FROM SESSION_AZIENDA_LIST
                                        WHERE SESSION_ID = V_SESSION_ID
                                          AND ELEM NOT LIKE '8%'
                                          AND ELEM NOT LIKE 'G%'
                                          AND ELEM NOT IN (
                                                  SELECT ELEM
                                                    FROM SESSION_V_REF_AZIENDA
                                                   WHERE SESSION_ID = V_SESSION_ID
                                                     AND HIE = '10'
                                                     AND NODE = '050'
                                              )
                                   )
                               AND T.MAP_REV1 <> 0
                               AND NOT EXISTS (
                                       SELECT 1
                                         FROM TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 TT
                                        WHERE TT.COD_CONTO = 'ZAW_DWD_LIST_ZHEKOU'
                                          AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO
                                              BETWEEN NVL(TT.VALID_FR,'000000') AND NVL(TT.VALID_TO,'999999')
                                          AND TT.MATERIAL_CODE IS NOT NULL
                                          AND T.MATERIAL_CODE = TT.MATERIAL_CODE
                                   )
                               AND NOT EXISTS (
                                       SELECT 1
                                         FROM TGK_FIMA_HISENSE.AW_RUL_PROCLS_000001 A
                                        WHERE A.D_PRO_CLASS = SUBSTR(NVL(T.D_PRO_CLASS,'|'),1,5)
                                   )
                               AND NVL(T.MATERIAL_GROUP_CODE,'|') NOT IN ('1100105','1100107')
                               AND T.COD_DEST3 LIKE '2%'
                               AND NVL(T.SRC_DETAIL,'|') <> 'REVM01'
                               -- ALTER BY LICHENG.EX 20261023 10:00 REV005_STEP_1.2 业务分类OPTY060/OPTY061/OPTY039不作为政策分摊因子
                               AND NVL(T.D_OPER_TYPE,'ZZZZ') NOT IN ('OPTY060','OPTY061','OPTY039')
                           ) M
                        ON M.COD_AZIENDA = A1.COD_AZIENDA
                       AND LTRIM(M.COD_DEST2,'0') = A1.COD_DEST2
                       AND M.D_ONOFFLINE = A1.D_ONOFFLINE
                       AND M.CUST_CODE = A1.CUST_CODE
                       AND M.MATERIAL_CODE = A1.MATERIAL_CODE
                 LEFT JOIN TMP_TABLE_ENT A2
                        ON (CASE
                              WHEN M.COD_AZIENDA LIKE '63%' OR M.COD_AZIENDA LIKE '67%' THEN 'BX'
                              WHEN M.COD_AZIENDA LIKE '62%' OR M.COD_AZIENDA LIKE '68%' THEN 'KT'
                              WHEN M.COD_AZIENDA LIKE '2%' THEN 'SX'
                              ELSE 'OTH'
                            END) = A2.COD_BU
                       AND M.COD_AZI_CTP = A2.COD_CTP
                       AND A2.SESSION_ID = V_SESSION_ID
                     WHERE (M.COD_AZI_CTP IS NULL OR M.COD_AZI_CTP = 'ZZZZ')
                        OR (M.COD_AZI_CTP <> 'ZZZZ' AND A2.COD_CTP IS NULL)
                   ) T2
           ) T
     WHERE T.POLICY_AMT * T.BL <> 0
;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.3 生成政策分摊数据-上两月',P_AZIENDA);
    COMMIT;



 INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.3 生成政策分摊后的数据',P_AZIENDA);
    COMMIT;

    --把政策分摊数据进行汇总，为后续插入做准备
  INSERT INTO TMP_TABLE_POLICY_ALLOC(SESSION_ID,OID,STEP_ID,GROUP_ID,MAP_REV1,POLICY_AMT,POLICY_ALC_AMT)
    --本月
  SELECT
       V_SESSION_ID, OID, 'CURRENT_PERIOD' STEP_ID, NULL GROUP_ID, NULL MAP_REV1, NULL POLICY_AMT, SUM(POLICY_ALC_AMT) POLICY_ALC_AMT

    FROM TMP_TABLE_POLICY_ALLOC
    WHERE SESSION_ID = V_SESSION_ID
      AND STEP_ID IS NOT NULL
      AND STEP_ID <> 'A_STEP2'
  GROUP BY OID

  UNION ALL
  --上2个月
  SELECT
        V_SESSION_ID,OID, 'LAST_TWO_PERIOD' STEP_ID, NULL GROUP_ID, NULL MAP_REV1, NULL POLICY_AMT, SUM(POLICY_ALC_AMT) POLICY_ALC_AMT
    FROM TMP_TABLE_POLICY_ALLOC
    WHERE SESSION_ID = V_SESSION_ID
      AND STEP_ID IS NOT NULL
      AND STEP_ID = 'A_STEP2'
    GROUP BY OID
     ;

    -- 1.3 生成并汇总政策分摊后的数据
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.3 汇总政策分摊后的数据',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 1.4  政策和收入数据一起插入目标表, MAP_QTY, ORG_REV, SALE_COGS, POLICY_AMT, POLICY_CASH_PD
  ------------------------------------------------------------------------------

    --删除上次更新的数据
    DELETE
      FROM AW_MR9_REVM05_000001_TEMP
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO = P_PERIODO
       AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
       --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
       AND  PROVENIENZA = 'CPM_SP_M2M_REV_M'
       /*20260226 新增排除锁定公司*/
       /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                 FROM AW_RUL_DWMCRS_000001 T
                                WHERE REV05_FLAG = 'Y'
                                  AND T.COD_SCENARIO = P_SCENARIO
                                  AND T.COD_PERIODO = P_PERIODO
                                  AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                               )*/
     ;


    --插入未分配的政策分摊数据
    INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
    OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
    COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
    D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
    D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
    CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
    MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
    D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
    D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
    D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
    BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
    D_POL_CLASS, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
    ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
    AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
    DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
    CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
    CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
    ,D_BUS_SCE_S,D_MINILED,MA_SALE_COGS, SHIPPING_ORDER
    --20260920FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP

    )
    SELECT
        NEWID() AS OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, M.COD_AZIENDA,COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, M.CUST_CODE, CUST_NAME,
        M.D_CHANNEL, D_MODE, M.D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        M.MATERIAL_CODE, MATERIAL_NAME, M.COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_ZUM MAP_QTY, M.ORG_REV, M.POLICY_AMT,
        0 AS POLICY_CASH_PD,D_ADJ_TYPE,
        NULL, SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        M.CN_MAP_ZUM,M.CN_ORG_REV,M.CN_SALE_COGS,M.CUSTOMER_MODEL,M.BILL_QTY as ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED,M.MA_SALE_COGS, SHIPPING_ORDER
    --20260920FJF_ADD 二期新增字段
    ,M.D_EFF_CLASS,M.D_BU_SHOP,M.D_EC_STORE,M.D_UNICUSTGRP
    FROM AW_MR9_REVM01_000001_CON_TEMP M
    JOIN (/*20260904 alter by shiqingfeng.ex 比例大于是10的数据进行去重*/
        SELECT distinct COD_AZIENDA,COD_DEST2,D_ONOFFLINE,D_CHANNEL,CUST_CODE
            FROM TMP_TABLE_POLICY A11
           WHERE A11.SESSION_ID = V_SESSION_ID
             AND (A11.STEP_ID IS NULL
                  OR EXISTS
                    (SELECT 1
                       FROM TMP_TABLE_POLICY_ALLOC A22
                      WHERE A22.SESSION_ID = V_SESSION_ID
                        AND A11.STEP_ID = A22.STEP_ID
                        AND A11.GROUP_ID = A22.GROUP_ID
                        AND A22.MAX_ABS_BL > 10
                    )
                 )
          ) A1
      ON M.COD_AZIENDA = A1.COD_AZIENDA
     AND (CASE WHEN M.COD_AZIENDA LIKE '62%' OR M.COD_AZIENDA LIKE '68%'
         THEN M.D_SALE_DEPT ELSE M.COD_DEST2 END) = A1.COD_DEST2
     AND NVL(M.D_ONOFFLINE,'Z') = NVL(A1.D_ONOFFLINE,'Z')
     --【20260806 修改v2】M端同步转换D_ECOM_BU，保证空/ZZZZ政策可按原维度落入未分配政策
     AND NVL(CASE WHEN (M.COD_AZIENDA = '1180' OR M.COD_AZIENDA LIKE '12%')
                       THEN M.D_ECOM_BU
                       ELSE M.D_CHANNEL
                   END,'Z') = NVL(A1.D_CHANNEL,'Z')
     AND NVL(M.CUST_CODE,'Z') = NVL(A1.CUST_CODE,'Z')
   WHERE 1=1
     AND M.SRC_DETAIL IN ('POLICY_YT','ADJM01')
     AND M.COD_SCENARIO = P_SCENARIO
     AND M.COD_PERIODO = P_PERIODO
     AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
     --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND M.COD_CONTO IN ('S6001G5','S6001G5AD')
     AND (M.MATERIAL_CODE IS NULL OR M.MATERIAL_CODE = 'ZZZZ')
     /*20260226 新增排除锁定公司*/
     /*AND M.COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                FROM AW_RUL_DWMCRS_000001 T
                               WHERE REV05_FLAG = 'Y'
                                 AND T.COD_SCENARIO = P_SCENARIO
                                 AND T.COD_PERIODO = P_PERIODO
                                 AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                               )*/
    ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入未分配的政策分摊数据',P_AZIENDA);
    COMMIT;


/*20260716 删除未分摊或分摊后为0的临时表中的政策数据*/
/*
DELETE FROM TMP_TABLE_POLICY_ALLOC
 WHERE NVL(MAX_ABS_BL,0) > 10
 ;*/

    --插入收入、出库未开、退货未办、已政策分摊数据
    INSERT INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
        AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
        DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
        CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
        CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
        ,D_BUS_SCE_S
        ,D_MINILED,MA_SALE_COGS, SHIPPING_ORDER
    --20260920FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP

    )

    SELECT
        NEWID() AS OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, LTRIM(COD_DEST2,'0') AS COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_ZUM MAP_QTY, M.ORG_REV, A1.POLICY_ALC_AMT POLICY_AMT,
        /*20261015 EDIT BY LC POLICY_CASH_PD  新增 SRC_DETAIL='ZTFI313A' 取数*/
        CASE WHEN M.SRC_DETAIL IN ('VBRP','REVM01','ADJM01','ZTFI313A') OR M.SRC_SYSTEM IN ('SMS','GSMS') THEN NVL(MAP_DIS1,0)+NVL(MAP_DIS3,0)+NVL(MAP_DIS4,0)+NVL(MAP_DIS30,0)+NVL(MAP_DIS34,0)
             ELSE 0
         END AS POLICY_CASH_PD,
        D_ADJ_TYPE,
        NULL, SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        M.CN_MAP_ZUM,M.CN_ORG_REV,M.CN_SALE_COGS,M.CUSTOMER_MODEL,M.MAP_QTY AS ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED,M.MA_SALE_COGS, SHIPPING_ORDER
     --20260920FJF_ADD 二期新增字段
    ,M.D_EFF_CLASS,M.D_BU_SHOP,M.D_EC_STORE,M.D_UNICUSTGRP
    FROM AW_MR9_REVM01_000001_CON_TEMP M
  --LEFT JOIN， 要COPY所有记录
    LEFT JOIN (SELECT *
                 FROM TMP_TABLE_POLICY_ALLOC
                WHERE SESSION_ID = V_SESSION_ID
                  AND STEP_ID = 'CURRENT_PERIOD') A1
           ON M.OID = A1.OID
        WHERE 1=1
          AND M.COD_CONTO LIKE 'S60010%'
          --AND M.COD_AZIENDA NOT LIKE '8%'
          --AND M.COD_AZIENDA NOT LIKE 'G%'
          --AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
          --AND SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per0)
          AND M.COD_SCENARIO = v_per0_ACT
          AND M.COD_PERIODO = v_per0_per
          AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND ELEM NOT LIKE '8%'
                                      AND ELEM NOT LIKE 'G%'
                                    )
          --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
          /*20260226 新增排除锁定公司*/
          /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                    FROM AW_RUL_DWMCRS_000001 T
                                   WHERE REV05_FLAG = 'Y'
                                     AND T.COD_SCENARIO = P_SCENARIO
                                     AND T.COD_PERIODO = P_PERIODO
                                     AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                  )*/

     ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入收入、出库未开、退货未办、已政策分摊数据',P_AZIENDA);
    COMMIT;


    --插入收入、出库未开、退货未办、已政策分摊数据
    INSERT INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
        AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
        DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
        CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
        CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
        ,D_BUS_SCE_S
        ,D_MINILED,MA_SALE_COGS, SHIPPING_ORDER
    --20260920FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
    )

    SELECT
        NEWID() AS OID, P_SCENARIO AS COD_SCENARIO, P_PERIODO AS COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, LTRIM(COD_DEST2,'0') AS COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,0 AS MAP_QTY, 0 AS ORG_REV, A1.POLICY_ALC_AMT AS POLICY_AMT,
        0 AS POLICY_CASH_PD,D_ADJ_TYPE,
        NULL, 0 AS SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        0 AS CN_MAP_ZUM,0 AS CN_ORG_REV,0 AS CN_SALE_COGS,M.CUSTOMER_MODEL,0 AS ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED,M.MA_SALE_COGS, SHIPPING_ORDER
     --20260920FJF_ADD 二期新增字段
    ,M.D_EFF_CLASS,M.D_BU_SHOP,M.D_EC_STORE,M.D_UNICUSTGRP
    FROM AW_MR9_REVM01_000001_CON_TEMP M
  --注意这里要用inner join， 只COPY匹配记录
    JOIN (SELECT *
            FROM TMP_TABLE_POLICY_ALLOC
           WHERE SESSION_ID = V_SESSION_ID
             AND STEP_ID = 'LAST_TWO_PERIOD') A1
      ON M.OID = A1.OID
    WHERE 1=1
      AND M.COD_CONTO LIKE 'S60010%'
      --AND M.COD_AZIENDA NOT LIKE '8%'
      --AND M.COD_AZIENDA NOT LIKE 'G%'
      AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0
      --AND SUBSTR(M.COD_SCENARIO,1,4) || M.COD_PERIODO IN (v_per1, v_per2)
      AND ((M.COD_SCENARIO = v_per1_ACT AND M.COD_PERIODO= v_per1_PER)
         OR (M.COD_SCENARIO = v_per2_ACT  AND M.COD_PERIODO= v_per2_PER)
      )

      AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND ELEM NOT LIKE '8%'
                                      AND ELEM NOT LIKE 'G%'
                                      --AND INSTR(V_HITACHI_AZIENDA,ELEM) = 0
                                    )
      --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
      /*20260226 新增排除锁定公司*/
      /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                FROM AW_RUL_DWMCRS_000001 T
                               WHERE REV05_FLAG = 'Y'
                                 AND T.COD_SCENARIO = P_SCENARIO
                                 AND T.COD_PERIODO = P_PERIODO
                                 AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                                 )*/
 ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入收入、出库未开、退货未办、已政策分摊数据',P_AZIENDA);
    COMMIT;


    INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
        AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
        DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
        CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
        CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
       ,D_BUS_SCE_S
       ,D_MINILED
       ,STD_QTY,MA_SALE_COGS, SHIPPING_ORDER
     --20260920FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP

    )
    SELECT
        NEWID() AS OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, M.COD_AZIENDA,COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, M.CUST_CODE, CUST_NAME,
        M.D_CHANNEL, D_MODE, M.D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        M.MATERIAL_CODE, MATERIAL_NAME, M.COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_ZUM MAP_QTY, M.ORG_REV, M.POLICY_AMT,
        0 AS POLICY_CASH_PD,D_ADJ_TYPE,
        NULL, SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        M.CN_MAP_ZUM,M.CN_ORG_REV,M.CN_SALE_COGS,M.CUSTOMER_MODEL,M.BILL_QTY as ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED
       ,M.STD_QTY,M.MA_SALE_COGS, SHIPPING_ORDER
     --20260920FJF_ADD 二期新增字段
    ,M.D_EFF_CLASS,M.D_BU_SHOP,M.D_EC_STORE,M.D_UNICUSTGRP
    FROM AW_MR9_REVM01_000001_CON_TEMP M
    WHERE 1=1
      AND M.SRC_DETAIL IN ('POLICY_YT','ADJM01','REVM01')
      AND M.COD_SCENARIO = P_SCENARIO
      AND M.COD_PERIODO = P_PERIODO
      AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
      --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
      AND M.COD_CONTO IN ('S6001G5','S6001G5AD')
      AND (
          (M.SRC_DETAIL <> 'REVM01' AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) = 0 AND NOT (M.MATERIAL_CODE IS NULL OR M.MATERIAL_CODE = 'ZZZZ'))   OR
          (M.SRC_DETAIL <> 'REVM01' AND INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) > 0) OR
          (M.SRC_DETAIL = 'REVM01')
          )
      /*20260226 新增排除锁定公司*/
      /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                FROM AW_RUL_DWMCRS_000001 T
                               WHERE REV05_FLAG = 'Y'
                                 AND T.COD_SCENARIO = P_SCENARIO
                                 AND T.COD_PERIODO = P_PERIODO
                                 AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                              )*/
    ;


    -- 1.4 插入收入、出库未开、退货未办、已分摊政策、未分摊政策数据
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.4 插入收入、出库未开、退货未办、已分摊政策、未分摊政策数据',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 1.5  插入除开票收入、出库未开、退货未办、政策分摊数据,MAP_QTY, ORG_REV, SALE_COGS
  ------------------------------------------------------------------------------

  --插入除开票、出库未开、退货未办、及政策分摊外的数据
  INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
        AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
        DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA,DATEUPD, USERUPD,
        CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
        CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,ORG_QTY,COD_DEST1,BILL_QTY
       ,D_BUS_SCE_S
       ,D_MINILED
       ,STD_QTY,MA_SALE_COGS, SHIPPING_ORDER
     --20260920FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
    )

  SELECT
        NEWID() AS OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA,COD_AZI_CTP AS COD_AZI_CTP_ORG,
        NVL(COD_CATEGORIA, 'ZAMOUNT') AS COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_OPER_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, LTRIM(COD_DEST2,'0') AS COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_ZUM MAP_QTY, M.ORG_REV,
        CASE WHEN INSTR(V_HITACHI_AZIENDA,COD_AZIENDA) > 0 THEN POLICY_AMT ELSE 0 END  AS POLICY_AMT,
        0 AS POLICY_CASH_PD,
        D_ADJ_TYPE,
        NULL, SALE_COGS, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
        'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
        M.CN_CLASS_MARK_CODE,M.CN_CLASS_MARK_NAME,M.SALE_CERT_TYPE,
        M.CN_MAP_ZUM,M.CN_ORG_REV,M.CN_SALE_COGS,M.CUSTOMER_MODEL,M.MAP_QTY AS ORG_QTY,COD_DEST1,BILL_QTY
       ,M.D_BUS_SCE_S
       ,M.D_MINILED
       ,M.STD_QTY,M.MA_SALE_COGS, SHIPPING_ORDER
     --20260920FJF_ADD 二期新增字段
    ,M.D_EFF_CLASS,M.D_BU_SHOP,M.D_EC_STORE,M.D_UNICUSTGRP
    FROM AW_MR9_REVM01_000001_CON_TEMP M
    WHERE 1=1
      AND (
           (M.COD_CONTO NOT LIKE 'S60010%' AND M.COD_CONTO NOT IN ('S6001G5','S6001G5AD')) OR
           COD_AZIENDA LIKE '8%' OR
           COD_AZIENDA LIKE 'G%'
          )
      AND M.COD_SCENARIO = P_SCENARIO
      AND M.COD_PERIODO = P_PERIODO
      AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
      --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
      /*20260226 新增排除锁定公司*/
      /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                                FROM AW_RUL_DWMCRS_000001 T
                               WHERE REV05_FLAG = 'Y'
                                 AND T.COD_SCENARIO = P_SCENARIO
                                 AND T.COD_PERIODO = P_PERIODO
                                 AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                              )*/
;



    -- 1.5 插入除收入、出库未开、退货未办、政策分摊数据
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.5 插入除收入、出库未开、退货未办、政策分摊数据',P_AZIENDA);
    COMMIT;

/*

    --20260716 新增插入墨西哥利润调整
    INSERT INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO,
         COD_PERIODO,
         SRC_DETAIL,
         COD_CONTO,
         COD_CATEGORIA,
         COD_AZIENDA,
         D_MODE,
         D_ONOFFLINE,
         COD_DEST3,
         D_SALE_DEPT,
         D_ADJ_TYPE,
         COD_DEST2,
         COD_DEST4,
         SALE_COGS,
         PROVENIENZA,DATEUPD, USERUPD

    )
      SELECT
           NEWID() AS OID
         , P_SCENARIO AS COD_SCENARIO
         , P_PERIODO AS COD_PERIODO
         , 'HB_ADJM01' AS SRC_DETAIL
         , 'S640100AD' AS COD_CONTO
         , 'GA00_CON_BG' AS COD_CATEGORIA
         , '2000' AS COD_AZIENDA
         , 'ZZZZ' AS D_MODE
         , '020_OFF_002' AS D_ONOFFLINE
         , '3020' AS COD_DEST3
         , 'ZZZZ' AS D_SALE_DEPT
         , 'REV_01_501' AS D_ADJ_TYPE
         , '101001001' AS COD_DEST2
         , '0003' AS COD_DEST4
         , SALE_COGS_PY10 - SALE_COGS_PY09 AS SALE_COGS
         , 'CPM_SP_M2M_REV_M' AS PROVENIENZA
         , SYSDATE AS DATEUPD
         , SESSION_USER AS USERUPD
        FROM

        (
          SELECT   ABS(SUM(CASE WHEN MAP_CAT_IM IN ('PY10') THEN IMPORTO_IM ELSE 0 END)) AS SALE_COGS_PY10
                , ABS(SUM(CASE WHEN MAP_CAT_IM IN ('PY09') THEN IMPORTO_IM ELSE 0 END)) AS SALE_COGS_PY09
           FROM TGK_FIMA_HISENSE.ZTAB_IM_SYNC_ZB_MAP A
          WHERE 1=1
            AND COD_SCENARIO = P_SCENARIO
            AND COD_PERIODO = P_PERIODO
            AND MAP_CAT_IM IN ('PY10','PY09')
            AND '2000' IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
        )
        ;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '插入墨西哥利润调整', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入墨西哥利润调整完成',P_AZIENDA);
    COMMIT;*/


  --2026.02.06  BY YANGHAO 汇率折算
MERGE INTO AW_MR9_REVM05_000001_TEMP SS
USING(
  SELECT AZIENDA.COD_VALUTA,CAMBIO_PERIODO,COD_AZIENDA
  FROM TGK_FIMA_HISENSE.AZIENDA
  LEFT JOIN TGK_FIMA_HISENSE.DATI_CAMBIO
  ON AZIENDA.COD_VALUTA = DATI_CAMBIO.COD_VALUTA
 WHERE DATI_CAMBIO.COD_SCENARIO = P_SCENARIO
   AND DATI_CAMBIO.COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
   /*20260226 新增排除锁定公司*/
          /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   )*/
) C
ON
(SS.COD_AZIENDA = C.COD_AZIENDA
AND SS.COD_SCENARIO = P_SCENARIO
 AND SS.COD_PERIODO = P_PERIODO
 AND SS.PROVENIENZA = 'CPM_SP_M2M_REV_M'
 )
WHEN MATCHED THEN UPDATE SET
  --SS.POLICY_AMT = NVL(SS.POLICY_AMT,0) * C.CAMBIO_PERIODO,
  SS.POLICY_CASH_PD = NVL(SS.POLICY_CASH_PD,0) / C.CAMBIO_PERIODO;
 COMMIT;


    ------------------------------------------------------------------------------
    -- 1.6  2910 考核收入 ASSESSED_REV 计算（20261020 新增）
    --   考核收入 = 【收入金额(含折扣)-净收入】-【政策计提】+【政策兑现】
    --            = ORG_REV - POLICY_AMT + POLICY_CASH_PD
    --   范围：仅公司 2910，其它公司维持原 NULL 口径不变
    --   位置：置于汇率折算 MERGE 之后，ORG_REV/POLICY_AMT/POLICY_CASH_PD 均取最终值
    ------------------------------------------------------------------------------
    UPDATE AW_MR9_REVM05_000001_TEMP
       SET ASSESSED_REV = NVL(ORG_REV,0) - NVL(POLICY_AMT,0) + NVL(POLICY_CASH_PD,0)
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO = P_PERIODO
       AND COD_AZIENDA = '2910'
       AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
    ;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '1 单体-收入、政策', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '1.6 2910 考核收入 ASSESSED_REV=ORG_REV-POLICY_AMT+POLICY_CASH_PD',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 2  插入合并层调整数据
  ------------------------------------------------------------------------------
  -- 补充调整数
  INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP
  (
    OID,
    COD_SCENARIO,
    COD_PERIODO,
    SRC_DETAIL,
    COD_CONTO,
    COD_AZIENDA,
    COD_CATEGORIA,
    CUST_CODE,
    CUST_NAME,
    D_ONOFFLINE,
    COD_DEST3,
    D_SALE_DEPT,
    MATERIAL_CODE,
    MATERIAL_NAME,
    COD_DEST2,
    COD_DEST4,
    COD_AZI_CTP_ORG,
    MAP_QTY,
    ORG_REV,
    SALE_COGS,
    PROVENIENZA,
    DATEUPD,
    USERUPD,
    D_ADJ_TYPE,
    POLICY_AMT,
    POLICY_CASH_PD,
    BILL_QTY,
    COD_AZI_CTP,
    SOLD_TO_CODE,
    SOLD_TO_NAME,
    COD_DEST1
  --20260920FJF_ADD 二期新增字段
  ,D_EC_STORE,D_CHANNEL,D_ECOM_BU,D_MARKET_PNT,MODEL_CODE,MODEL_NAME,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME
  )
  SELECT
    NEWID(),
    P_SCENARIO AS COD_SCENARIO,
    P_PERIODO AS COD_PERIODO,
    'HB_ADJM01' AS SRC_DETAIL,
    CASE
      WHEN NVL(MAP_QTY,0)<>0 OR NVL(ORG_REV,0)<>0 THEN 'S600100AD'
      WHEN NVL(SALE_COGS,0)<>0 THEN 'S640100AD'
     WHEN NVL(POLICY_AMT,0) <> 0 THEN 'S6001G5AD'
      ELSE 'S600100AD'
    END AS COD_CONTO,
    COD_AZIENDA,
    CASE WHEN COD_CATEGORIA = 'GA00_CON_L2' THEN 'GA00_CON_L2' ELSE 'GA00_CON' END AS COD_CATEGORIA,
    CUST_CODE,
    CUST_NAME,
    D_ONOFFLINE,
    COD_DEST3,
    D_SALE_DEPT,
    MATERIAL_CODE,
    MATERIAL_NAME,
    COD_DEST2,
    COD_DEST4,
    COD_AZI_CTP AS COD_AZI_CTP_ORG,
    MAP_QTY,
    ORG_REV,
    SALE_COGS,
    'CPM_SP_M2M_REV_M' PROVENIENZA, SYSDATE DATEUPD, SESSION_USER USERUPD,
    D_ADJ_TYPE,
    POLICY_AMT,
    POLICY_CASH_PD,
    CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN MAP_QTY ELSE 0 END AS BILL_QTY, --0304 fjf_add
    COD_AZI_CTP,
    SOLD_TO_CODE,
    SOLD_TO_NAME,
    CASE WHEN COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240' THEN COD_DEST1 ELSE 'ZZZZ' END AS COD_DEST1
  --20260920FJF_ADD 二期新增字段
  ,NVL(D_EC_STORE,'ZZZZ')AS D_EC_STORE --电商细分店铺
  ,NVL(D_CHANNEL,'ZZZZ')AS D_CHANNEL--销售渠道
  ,NVL(D_ECOM_BU,'ZZZZ')AS D_ECOM_BU--电商BU渠道细分
  ,NVL(D_MARKET_PNT,'ZZZZ')AS D_MARKET_PNT--营销定位
  ,NVL(MODEL_CODE,'ZZZZ')AS MODEL_CODE--产品型号
  ,NVL(MODEL_NAME,'ZZZZ')AS MODEL_NAME--产品型号描述
  ,NVL(CN_CLASS_MARK_CODE,'ZZZZ')AS CN_CLASS_MARK_CODE--中国区品线标记编码
  ,NVL(CN_CLASS_MARK_NAME,'ZZZZ')AS CN_CLASS_MARK_NAME--中国区品线标记描述

FROM TGK_FIMA_HISENSE.AW_MR9_ADJM01_000001
WHERE COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                WHERE SESSION_ID = V_SESSION_ID
                )
--AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
AND COD_CONTO='ZAW_DWM_REV_MERG'
/*20260526 shqingfeng.ex 修改限制条件*/
AND COD_CATEGORIA IN ('GA00_CON_L2','GA00_CON')
--AND COD_CATEGORIA='ZFAMOUNT'
--AND D_ADJ_TYPE='REV_01_301'
AND NOT (NVL(SALE_COGS,0)=0 AND NVL(MAP_QTY,0)=0 AND NVL(ORG_REV,0)=0 AND NVL(POLICY_AMT,0)=0 AND NVL(POLICY_CASH_PD,0)=0)
  /*20260226 新增排除锁定公司*/
    /*AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
        FROM AW_RUL_DWMCRS_000001 T
       WHERE REV05_FLAG = 'Y'
         AND T.COD_SCENARIO = P_SCENARIO
         AND T.COD_PERIODO = P_PERIODO
         AND T.COD_CONTO = 'ZAW_D2M_LOCK'
         )*/
  ;

  COMMIT;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '2  插入合并层调整数据', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 2.1 REV005_STEP_2-1（插入中国区其他业务）
  ------------------------------------------------------------------------------

  INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP
  (
    OID
   ,COD_SCENARIO
   ,COD_PERIODO
   ,SRC_DETAIL
   ,COD_CONTO
   ,COD_CATEGORIA
   ,COD_AZIENDA
   ,AGENCY_CODE
   ,AGENCY_NAME
   ,CUST_CODE
   ,CUST_NAME
   ,D_CHANNEL
   ,D_MODE
   ,D_ONOFFLINE
   ,D_CNL_C_TYPE
   ,D_IND_C_TYPE
   ,D_ECOM_BU
   ,CUST_UNITY_NAME
   ,CREDIT_LEVEL_NAME
   ,CUST_NATURE_NAME
   ,CUST_TYPE_NAME
   ,SOLD_TO_CODE
   ,SOLD_TO_NAME
   ,COD_DEST3
   ,D_SALE_DEPT
   ,D_DATA_BLOCK
   ,D_DIFF_TYPE
   ,D_ADJ_TYPE
   ,MATERIAL_CODE
   ,MATERIAL_NAME
   ,COD_DEST2
   ,COD_DEST4
   ,D_MARKET_PNT
   ,D_PRO_SSER
   ,D_SPEC_SEC
   ,D_PRO_TYPE_S
   ,D_PRO_STAGE
   ,D_PRI_RANGE
   ,D_PRO_SERIES
   ,D_TECH_TYPE
   ,IS_MINILED_CODE
   ,D_PRO_CLASS
   ,D_MODEL_LCA
   ,D_PRO_TYPE
   ,SALE_MODEL_CODE
   ,SALE_MODEL_NAME
   ,MODEL_CODE
   ,MODEL_NAME
   ,BATCH_ID
   ,D_PRC_GRP
   ,MATERIAL_GROUP_CODE
   ,SHOP_CODE
   ,SHOP_NAME
   ,D_POL_CLASS
   ,COD_AZI_CTP
   ,ORG_QTY
   ,BILL_QTY
   ,MAP_QTY
   ,ORG_REV
   ,POLICY_AMT
   ,POLICY_CASH_PD
   ,ASSESSED_REV
   ,SALE_COGS
   ,CN_CLASS_MARK_CODE
   ,CN_CLASS_MARK_NAME
   ,SALE_CERT_TYPE
   ,CUSTOMER_MODEL
   ,D_OPER_TYPE
   ,COD_DEST1
    ,PROVENIENZA
    ,DATEUPD
    ,USERUPD
    ,COD_AZI_CTP_ORG
  ,D_MINILED
  )
  SELECT
     NEWID()OID
   ,COD_SCENARIO
   ,COD_PERIODO
   ,'REVM05' AS SRC_DETAIL
   ,COD_CONTO
   ,'GA00_BF' AS COD_CATEGORIA
   ,COD_AZIENDA
   ,AGENCY_CODE
   ,AGENCY_NAME
   ,CUST_CODE
   ,CUST_NAME
   ,D_CHANNEL
   ,D_MODE
   ,D_ONOFFLINE
   ,D_CNL_C_TYPE
   ,D_IND_C_TYPE
   ,D_ECOM_BU
   ,CUST_UNITY_NAME
   ,CREDIT_LEVEL_NAME
   ,CUST_NATURE_NAME
   ,CUST_TYPE_NAME
   ,SOLD_TO_CODE
   ,SOLD_TO_NAME
   ,COD_DEST3
   ,D_SALE_DEPT
   ,D_DATA_BLOCK
   ,D_DIFF_TYPE
   ,'REV_01_311' AS D_ADJ_TYPE
   ,MATERIAL_CODE
   ,MATERIAL_NAME
   ,COD_DEST2
   ,COD_DEST4
   ,D_MARKET_PNT
   ,D_PRO_SSER
   ,D_SPEC_SEC
   ,D_PRO_TYPE_S
   ,D_PRO_STAGE
   ,D_PRI_RANGE
   ,D_PRO_SERIES
   ,D_TECH_TYPE
   ,IS_MINILED_CODE
   ,D_PRO_CLASS
   ,D_MODEL_LCA
   ,D_PRO_TYPE
   ,SALE_MODEL_CODE
   ,SALE_MODEL_NAME
   ,MODEL_CODE
   ,MODEL_NAME
   ,BATCH_ID
   ,D_PRC_GRP
   ,MATERIAL_GROUP_CODE
   ,SHOP_CODE
   ,SHOP_NAME
   ,D_POL_CLASS
   ,COD_AZI_CTP
   ,0-ORG_QTY AS ORG_QTY
   ,0-BILL_QTY AS BILL_QTY
   ,0-MAP_QTY AS MAP_QTY
   ,0-ORG_REV AS ORG_REV
   ,0-POLICY_AMT AS POLICY_AMT
   ,0-POLICY_CASH_PD AS POLICY_CASH_PD
   ,0-ASSESSED_REV AS ASSESSED_REV
   ,0-SALE_COGS AS SALE_COGS
   ,CN_CLASS_MARK_CODE
   ,CN_CLASS_MARK_NAME
   ,SALE_CERT_TYPE
   ,CUSTOMER_MODEL
   ,D_OPER_TYPE
   ,COD_DEST1
    ,'CPM_SP_M2M_REV_M' PROVENIENZA
   ,SYSDATE DATEUPD
   ,SESSION_USER USERUPD
   ,COD_AZI_CTP_ORG AS COD_AZI_CTP_ORG
   ,D_MINILED
   FROM AW_MR9_REVM05_000001_TEMP
  WHERE COD_SCENARIO = P_SCENARIO
    AND COD_PERIODO = P_PERIODO
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
    AND D_OPER_TYPE IN (SELECT D_OPER_TYPE
                    FROM TGK_FIMA_HISENSE.AW_RUL_CNMECL_000001
                   WHERE VALID_FR <= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                     AND NVL(VALID_TO,'999999') >= SUBSTR(P_SCENARIO,1,4)||P_PERIODO
                  )
      /*20260226 新增排除锁定公司*/
/*    AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
           FROM AW_RUL_DWMCRS_000001 T
          WHERE REV05_FLAG = 'Y'
            AND T.COD_SCENARIO = P_SCENARIO
            AND T.COD_PERIODO = P_PERIODO
            AND T.COD_CONTO = 'ZAW_D2M_LOCK'
            ) */
  ;

  COMMIT;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_2-1（插入中国区其他业务）完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- REV005_STEP_2-2（插入线下O2O冲销数） --20260914fjf_add
  ------------------------------------------------------------------------------

INSERT INTO AW_MR9_REVM05_000001_TEMP
(
    OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_CATEGORIA, COD_AZIENDA,
    AGENCY_CODE, AGENCY_NAME, CUSTOMER_MODEL, CUST_CODE, CUST_NAME,
    D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU,
    CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME,
    SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT, D_DATA_BLOCK, D_DIFF_TYPE,
    D_ADJ_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
    D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES,
    D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, IS_MINILED_CODE,
    SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, D_PRC_GRP,
    MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME, D_POL_CLASS, COD_AZI_CTP,
    COD_AZI_CTP_ORG, ORG_QTY, BILL_QTY, MAP_QTY, ORG_REV, POLICY_AMT,
    POLICY_CASH_PD, ASSESSED_REV, SALE_COGS,
    CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, D_OPER_TYPE, COD_DEST1,CN_MAP_ZUM ,CN_ORG_REV ,CN_SALE_COGS
  ,PROVENIENZA,DATEUPD,USERUPD
)
SELECT
    SYS_GUID(), S.COD_SCENARIO, S.COD_PERIODO, 'REVM05', S.COD_CONTO, 'GA00_CON_G05', S.COD_AZIENDA,
    S.AGENCY_CODE, S.AGENCY_NAME, S.CUSTOMER_MODEL, S.CUST_CODE, S.CUST_NAME,
    S.D_CHANNEL, S.D_MODE, S.D_ONOFFLINE, S.D_CNL_C_TYPE, S.D_IND_C_TYPE, S.D_ECOM_BU,
    S.CUST_UNITY_NAME, S.CREDIT_LEVEL_NAME, S.CUST_NATURE_NAME, S.CUST_TYPE_NAME,
    S.SOLD_TO_CODE, S.SOLD_TO_NAME, S.COD_DEST3, S.D_SALE_DEPT, S.D_DATA_BLOCK, S.D_DIFF_TYPE,
    'REV_01_312', S.MATERIAL_CODE, S.MATERIAL_NAME, S.COD_DEST2, S.COD_DEST4, S.D_MARKET_PNT,
    S.D_PRO_SSER, S.D_SPEC_SEC, S.D_PRO_TYPE_S, S.D_PRO_STAGE, S.D_PRI_RANGE, S.D_PRO_SERIES,
    S.D_TECH_TYPE, S.D_PRO_CLASS, S.D_MODEL_LCA, S.D_PRO_TYPE, S.IS_MINILED_CODE,
    S.SALE_MODEL_CODE, S.SALE_MODEL_NAME, S.MODEL_CODE, S.MODEL_NAME, S.BATCH_ID, S.D_PRC_GRP,
    S.MATERIAL_GROUP_CODE, S.SHOP_CODE, S.SHOP_NAME, S.D_POL_CLASS, S.COD_AZI_CTP,
    S.COD_AZI_CTP_ORG, 0-S.ORG_QTY, 0-S.BILL_QTY, 0-S.MAP_QTY, 0-S.ORG_REV, 0-S.POLICY_AMT,
    0-S.POLICY_CASH_PD, 0-S.ASSESSED_REV, 0-S.SALE_COGS,
    S.CN_CLASS_MARK_CODE, S.CN_CLASS_MARK_NAME, S.SALE_CERT_TYPE, S.D_OPER_TYPE, S.COD_DEST1
  --20260915fjf_add REV005_STEP_2-2（插入线下O2O冲销数）①修改类别 ②新增中国区相关取数字段
  ,0-CN_MAP_ZUM as CN_MAP_ZUM
  ,0-CN_ORG_REV as CN_ORG_REV
  ,0-CN_SALE_COGS as CN_SALE_COGS
  ,'CPM_SP_M2M_REV_M' as PROVENIENZA
    ,SYSDATE as DATEUPD
    ,SESSION_USER as USERUPD
FROM AW_MR9_REVM05_000001_TEMP S
WHERE COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
AND (S.COD_AZIENDA = '1180' OR S.COD_AZIENDA LIKE '12%')
AND S.D_OPER_TYPE = 'OPTY020';
COMMIT;


    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_2-2（插入线下O2O冲销数）完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 20261021 LIYIFAN1.EX  REV005_STEP_2-3 研发费用品类间调整-事业部层 
  ------------------------------------------------------------------------------

/* REV005 研发费用品类间调整-事业部层：把单体层（类别 GA00_BF / 调整类型 REV_01_229）的收入行转成成本口径落事业部层 */
INSERT INTO AW_MR9_REVM05_000001_TEMP
(
    OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_CATEGORIA, COD_AZIENDA,
    AGENCY_CODE, AGENCY_NAME, CUSTOMER_MODEL, CUST_CODE, CUST_NAME,
    D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU,
    CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME,
    SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT, D_DATA_BLOCK, D_DIFF_TYPE,
    D_ADJ_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
    D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES,
    D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, IS_MINILED_CODE,
    SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, D_PRC_GRP,
    MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME, D_POL_CLASS, COD_AZI_CTP, COD_AZI_CTP_ORG,
    ORG_QTY, BILL_QTY, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD, ASSESSED_REV, SALE_COGS,
    CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, D_OPER_TYPE, COD_DEST1,
    CN_MAP_ZUM, CN_ORG_REV, CN_SALE_COGS,
    PROVENIENZA, DATEUPD, USERUPD
)
SELECT
    SYS_GUID()                        -- OID
  , P_SCENARIO                        -- 场景
  , P_PERIODO                         -- 期间
  , 'REVM05'                          -- 源数据明细
  , 'S640100AD'                       -- 科目
  , 'GA00_CON_BG'                     -- 类别
  , S.COD_AZIENDA                     -- 账套
  , S.AGENCY_CODE
  , S.AGENCY_NAME
  , S.CUSTOMER_MODEL
  , S.CUST_CODE
  , S.CUST_NAME
  , S.D_CHANNEL
  , S.D_MODE
  , S.D_ONOFFLINE
  , S.D_CNL_C_TYPE
  , S.D_IND_C_TYPE
  , S.D_ECOM_BU
  , S.CUST_UNITY_NAME
  , S.CREDIT_LEVEL_NAME
  , S.CUST_NATURE_NAME
  , S.CUST_TYPE_NAME
  , S.SOLD_TO_CODE
  , S.SOLD_TO_NAME
  , S.COD_DEST3
  , S.D_SALE_DEPT
  , S.D_DATA_BLOCK
  , S.D_DIFF_TYPE
  , S.D_ADJ_TYPE                      -- 调整类型：直接对应
  , S.MATERIAL_CODE
  , S.MATERIAL_NAME
  , S.COD_DEST2                       -- 利润中心：直接对应（承接单体层 101001001 / 101006000 两行）
  , S.COD_DEST4
  , S.D_MARKET_PNT
  , S.D_PRO_SSER
  , S.D_SPEC_SEC
  , S.D_PRO_TYPE_S
  , S.D_PRO_STAGE
  , S.D_PRI_RANGE
  , S.D_PRO_SERIES
  , S.D_TECH_TYPE
  , S.D_PRO_CLASS
  , S.D_MODEL_LCA
  , S.D_PRO_TYPE
  , S.IS_MINILED_CODE
  , S.SALE_MODEL_CODE
  , S.SALE_MODEL_NAME
  , S.MODEL_CODE
  , S.MODEL_NAME
  , S.BATCH_ID
  , S.D_PRC_GRP
  , S.MATERIAL_GROUP_CODE
  , S.SHOP_CODE
  , S.SHOP_NAME
  , S.D_POL_CLASS
  , NULL COD_AZI_CTP  -- 20261023 LIYIFAN 对方公司放null
  , S.COD_AZI_CTP_ORG
  , NULL                              -- 销量-原始：放空
  , NULL                              -- 销量-原始（日立用）：放空
  , NULL                              -- 数量(处理后)：放空
  , NULL                              -- 收入金额(含折扣)-净收入：放空
  , S.POLICY_AMT                      -- 政策计提数据：直接对应
  , S.POLICY_CASH_PD                  -- 政策兑现价差：直接对应
  , NULL                              -- 考核收入：放空
  , 0 - NVL(S.ORG_REV, 0)             -- 销售成本：ORG_REV * -1
  , S.CN_CLASS_MARK_CODE
  , S.CN_CLASS_MARK_NAME
  , S.SALE_CERT_TYPE
  , S.D_OPER_TYPE
  , S.COD_DEST1                       -- 成本中心：直接对应
  , NULL                              -- 销量-特殊处理后-中国区：放空
  , NULL                              -- 收入金额(折扣后不含税)-本位币-中国区：放空
  , 0 - NVL(S.ORG_REV, 0)             -- 成本金额-交易币-中国区：ORG_REV * -1
  , 'CPM_SP_M2M_REV_M'                -- 来源
  , S.DATEUPD                         -- 更新日期：直接对应
  , S.USERUPD                         -- 更新用户：直接对应
  FROM AW_MR9_REVM05_000001_TEMP S
 WHERE S.COD_SCENARIO = P_SCENARIO
   AND S.COD_PERIODO  = P_PERIODO
   AND S.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND S.COD_CATEGORIA = 'GA00_BF'
   AND S.D_ADJ_TYPE = 'REV_01_229';
COMMIT;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_2-3（研发费用品类间调整-事业部层）完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);
    COMMIT;

  ------------------------------------------------------------------------------
  -- 20261022 LIYIFAN1.EX REV005_STEP_2-4 古洛尼合并层还原
  ------------------------------------------------------------------------------

/* 取 D_ADJ_TYPE=REV_01_311 的冲销行，金额全部翻负，写成 REV_01_503 的还原行 */
INSERT INTO AW_MR9_REVM05_000001_TEMP
(
    OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_CATEGORIA, COD_AZIENDA,
    AGENCY_CODE, AGENCY_NAME, CUSTOMER_MODEL, CUST_CODE, CUST_NAME,
    D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU,
    CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME,
    SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT, D_DATA_BLOCK, D_DIFF_TYPE,
    D_ADJ_TYPE, MATERIAL_CODE, MATERIAL_NAME, COD_DEST2, COD_DEST4, D_MARKET_PNT,
    D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES,
    D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, IS_MINILED_CODE,
    SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, D_PRC_GRP,
    MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME, D_POL_CLASS, COD_AZI_CTP, COD_AZI_CTP_ORG,
    ORG_QTY, BILL_QTY, MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD, ASSESSED_REV, SALE_COGS,
    CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, D_OPER_TYPE, COD_DEST1,
    CN_MAP_ZUM, CN_ORG_REV, CN_SALE_COGS,
    DATEUPD, USERUPD, PROVENIENZA
)
SELECT
    SYS_GUID()                        -- OID
  , P_SCENARIO                        -- 场景
  , P_PERIODO                         -- 期间
  , 'REVM05'                          -- 源数据明细
  , S.COD_CONTO                       -- 科目：直接对应
  , 'GA00_CON_G05'                    -- 类别
  , S.COD_AZIENDA                     -- 账套
  , S.AGENCY_CODE
  , S.AGENCY_NAME
  , S.CUSTOMER_MODEL
  , S.CUST_CODE
  , S.CUST_NAME
  , S.D_CHANNEL
  , S.D_MODE
  --EDIT BY LC 20261029 直接写死020_OFF_002
  , '020_OFF_002' AS D_ONOFFLINE
  , S.D_CNL_C_TYPE
  , S.D_IND_C_TYPE
  , S.D_ECOM_BU
  , S.CUST_UNITY_NAME
  , S.CREDIT_LEVEL_NAME
  , S.CUST_NATURE_NAME
  , S.CUST_TYPE_NAME
  , S.SOLD_TO_CODE
  , S.SOLD_TO_NAME
  , S.COD_DEST3
  , S.D_SALE_DEPT
  , S.D_DATA_BLOCK
  , S.D_DIFF_TYPE
  , 'REV_01_503'                      -- 调整类型：古洛尼智能生态业务还原
  , S.MATERIAL_CODE
  , S.MATERIAL_NAME
  , S.COD_DEST2
  , S.COD_DEST4
  , S.D_MARKET_PNT
  , S.D_PRO_SSER
  , S.D_SPEC_SEC
  , S.D_PRO_TYPE_S
  , S.D_PRO_STAGE
  , S.D_PRI_RANGE
  , S.D_PRO_SERIES
  , S.D_TECH_TYPE
  , S.IS_MINILED_CODE
  , S.D_PRO_CLASS
  , S.D_MODEL_LCA
  , S.D_PRO_TYPE
  , S.SALE_MODEL_CODE
  , S.SALE_MODEL_NAME
  , S.MODEL_CODE
  , S.MODEL_NAME
  , S.BATCH_ID
  , S.D_PRC_GRP
  , S.MATERIAL_GROUP_CODE
  , S.SHOP_CODE
  , S.SHOP_NAME
  , S.D_POL_CLASS
  , S.COD_AZI_CTP
  , S.COD_AZI_CTP_ORG
  , 0 - NVL(S.ORG_QTY, 0)             -- 销量-原始
  , 0 - NVL(S.BILL_QTY, 0)            -- 销量-原始（日立用）
  , 0 - NVL(S.MAP_QTY, 0)             -- 数量(处理后)
  , 0 - NVL(S.ORG_REV, 0)             -- 收入金额(含折扣)-净收入
  , 0 - NVL(S.POLICY_AMT, 0)          -- 政策计提数据
  , 0 - NVL(S.POLICY_CASH_PD, 0)      -- 政策兑现价差
  , 0 - NVL(S.ASSESSED_REV, 0)        -- 考核收入
  , 0 - NVL(S.SALE_COGS, 0)           -- 销售成本
  , S.CN_CLASS_MARK_CODE
  , S.CN_CLASS_MARK_NAME
  , S.SALE_CERT_TYPE
  , S.D_OPER_TYPE
  , S.COD_DEST1
  , 0 - NVL(S.CN_MAP_ZUM, 0)          -- 销量-特殊处理后-中国区
  , 0 - NVL(S.CN_ORG_REV, 0)          -- 收入金额(折扣后不含税)-本位币-中国区
  , 0 - NVL(S.CN_SALE_COGS, 0)        -- 成本金额-交易币-中国区
  , S.DATEUPD
  , S.USERUPD
  , 'CPM_SP_M2M_REV_M'                -- 来源
  FROM AW_MR9_REVM05_000001_TEMP S
 WHERE S.COD_SCENARIO = P_SCENARIO
   AND S.COD_PERIODO  = P_PERIODO
   AND S.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND S.D_ADJ_TYPE  = 'REV_01_311'
   AND S.D_OPER_TYPE = 'OPTY036';
COMMIT;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_2-4（古洛尼合并层还原）完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);
    COMMIT;


  ------------------------------------------------------------------------------
  -- 3  插入未实现数据和产销存单位成本, BEG_UNREAL_GP, END_UNREAL_GP, WTD_UNIT_COST, DOM_PSI_COST
  ------------------------------------------------------------------------------


MERGE
INTO AW_MR9_REVM05_000001_TEMP A
USING (

WITH
/* ===== CTE 区：所有重复子查询只查一次 ===== */

-- CTE 1: L1级别的业务组列表（替代4处重复的 CASE WHEN V_ENTITY 子查询）
CTE_L1_BU AS (
    SELECT DISTINCT CASE WHEN V_ENTITY = 'BX' THEN 'CXC030'
                WHEN V_ENTITY = 'KT' THEN 'BG003_BU011'
                WHEN V_ENTITY = 'SX' THEN 'BG001_BU001'
                ELSE ''
           END AS D_BU
      FROM TGK_FIMA_HISENSE.AW_RUL_REVCXC_000001
     WHERE COST_CALC_LEVEL = 'L1'
),
-- CTE 2: 符合L1条件的公司集合（替代3处 COD_AZIENDA IN (SELECT ... ATSMAP WHERE COD_BG IN (SELECT ...))）
CTE_L1_AZI AS (
    SELECT A.COD_AZIENDA, A.COD_BG
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
      INNER JOIN CTE_L1_BU L ON A.COD_BG = L.D_BU
),
-- CTE 3: 同业务组公司对（用于排除"公司+CTP在同一BG"的情况）
CTE_SAME_BG_PAIR AS (
    SELECT A1.COD_AZIENDA AS COD_AZI_SELL, A2.COD_AZIENDA AS COD_AZI_BUY
      FROM CTE_L1_AZI A1
      INNER JOIN CTE_L1_AZI A2 ON A1.COD_BG = A2.COD_BG
),
-- CTE 4: 内销DEST3（HN）
CTE_DEST3_HN AS (
    SELECT ELEM
      FROM SESSION_V_REF_DEST3_NONAME
     WHERE SESSION_ID = V_SESSION_ID
       AND NODE = 'HN'
),
-- CTE 5: 锁定公司
/*CTE_LOCK_AZI AS (
    SELECT COD_AZIENDA
      FROM AW_RUL_DWMCRS_000001
     WHERE REV05_FLAG   = 'Y'
       AND COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO  = P_PERIODO
       AND COD_CONTO    = 'ZAW_D2M_LOCK'
),*/
-- CTE 6: 单位成本（原 B2 子查询）
CTE_UC AS (
    SELECT TRIM(MATERIAL_CODE) AS MATERIAL_CODE, MAX(UC) AS WTD_UNIT_COST
      FROM TGK_FIMA_HISENSE.ZTAB_UC_LIST
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO  = P_PERIODO
       AND TRIM(MATERIAL_CODE) IS NOT NULL
       AND D_BU IN ('CXC030', 'BG003_BU011', 'BG001_BU001')
     GROUP BY TRIM(MATERIAL_CODE)
),
-- CTE 7: 上一期未实现毛利（原 B3 子查询，用 CTE_L1_AZI 替代重复子查询）
CTE_PREV_GP AS (
    SELECT MATERIAL_CODE,
           SUM(BEG_UNREAL_GP) AS BEG_UNREAL_GP,
           SUM(END_UNREAL_GP) AS END_UNREAL_GP
      FROM (
          SELECT COD_AZIENDA, TRIM(MATERIAL_CODE) AS MATERIAL_CODE,
                 SUM(NVL(BEG_UNREAL_GP, 0)) AS BEG_UNREAL_GP,
                 SUM(NVL(END_UNREAL_GP, 0)) AS END_UNREAL_GP
            FROM TGK_FIMA_HISENSE.AW_MR9_REVM04_000001
           WHERE COD_SCENARIO = P_SCENARIO
             AND COD_PERIODO  = P_PERIODO
             AND COD_AZIENDA IN (SELECT COD_AZIENDA FROM CTE_L1_AZI)
             AND D_BU IN ('CXC030', 'BG003_BU011', 'BG001_BU001')
             AND TRIM(MATERIAL_CODE) IS NOT NULL
             AND (NVL(BEG_UNREAL_GP, 0) <> 0 OR NVL(END_UNREAL_GP, 0) <> 0)
             AND COD_DEST3 IN (SELECT ELEM FROM CTE_DEST3_HN)
           GROUP BY COD_AZIENDA, MATERIAL_CODE
      )
      WHERE TRIM(MATERIAL_CODE) IS NOT NULL
        AND NVL(MATERIAL_CODE, '|') <> 'ZZZZ'
      GROUP BY MATERIAL_CODE
)
    /* 核心逻辑：
       B1: 主表 + 套机单机映射 → 窗口函数计算 BL（分摊比例）
       B2: 单位成本（CTE_UC）
       B3: 上一期未实现毛利（CTE_PREV_GP），按 ZDETAIL 匹配
       外层 SUM(GP.BEG_UNREAL_GP * MD.BL) = 按比例分摊上一期毛利
    */
    SELECT MD.OID,
           MD.MATERIAL_CODE,
           MAX(UC.WTD_UNIT_COST) AS WTD_UNIT_COST,
           SUM(GP.BEG_UNREAL_GP * MD.BL) AS BEG_UNREAL_GP,
           SUM(GP.END_UNREAL_GP * MD.BL) AS END_UNREAL_GP
      FROM (
          SELECT OID, MATERIAL_CODE, ZDETAIL,
                 RATIO_TO_REPORT(ORG_QTY) OVER (PARTITION BY ZDETAIL) AS BL
            FROM (
                SELECT AW.OID, AW.MATERIAL_CODE,
                       CASE WHEN M_LIST.ZDETAIL IS NULL THEN AW.MATERIAL_CODE
                            ELSE M_LIST.ZDETAIL
                       END AS ZDETAIL,
                       AW.ORG_QTY
                  FROM AW_MR9_REVM05_000001_TEMP AW
                  LEFT JOIN (SELECT ZSET, ZDETAIL
                               FROM TGK_FIMA_HISENSE.ZTAB_MATNR_TJ) M_LIST
                         ON AW.MATERIAL_CODE = M_LIST.ZSET
                 WHERE AW.COD_SCENARIO = P_SCENARIO
                   AND AW.COD_PERIODO  = P_PERIODO
                   AND AW.MATERIAL_CODE IS NOT NULL
                   AND AW.ORG_QTY <> 0
                   AND AW.COD_AZIENDA IN (SELECT COD_AZIENDA FROM CTE_L1_AZI)
                   AND AW.COD_DEST3 IN (SELECT ELEM FROM CTE_DEST3_HN)
                   AND NOT EXISTS (
                       SELECT 1 FROM CTE_SAME_BG_PAIR P
                        WHERE P.COD_AZI_SELL = AW.COD_AZIENDA
                          AND P.COD_AZI_BUY  = NVL(AW.COD_AZI_CTP_ORG, '9999')
                   )
            )
      ) MD
      /* LEFT JOIN 单位成本 */
      LEFT JOIN CTE_UC UC ON MD.MATERIAL_CODE = UC.MATERIAL_CODE
      /* LEFT JOIN 上一期未实现毛利（按套机/单机 ZDETAIL 匹配）*/
      LEFT JOIN CTE_PREV_GP GP ON MD.ZDETAIL = GP.MATERIAL_CODE
     GROUP BY MD.OID, MD.MATERIAL_CODE

) B
ON (A.OID = B.OID)
WHEN MATCHED THEN
    UPDATE SET
        A.BEG_UNREAL_GP   = B.BEG_UNREAL_GP,
        A.END_UNREAL_GP   = B.END_UNREAL_GP,
        A.WTD_UNIT_COST   = B.WTD_UNIT_COST
;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_3（插入未实现及产销存单位成本）完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);
    COMMIT;


-- ============================================================
-- ② 主查询：内销未实现GP + 物料主数据维度
-- ============================================================
INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP
(
OID,
D_ONOFFLINE,
SRC_DETAIL,
COD_CONTO,
COD_SCENARIO,
COD_PERIODO,
COD_AZIENDA,
COD_CATEGORIA,
MATERIAL_CODE,
COD_DEST2,
COD_DEST3,
COD_DEST4,
BEG_UNREAL_GP,
END_UNREAL_GP,
DATEUPD,
USERUPD,
PROVENIENZA,

--COD_DEST4,
D_MARKET_PNT,
D_PRO_SSER,
D_SPEC_SEC,
D_PRO_TYPE_S,
D_PRO_STAGE,
D_PRI_RANGE,
D_PRO_SERIES,
D_TECH_TYPE,
D_PRO_CLASS,
D_MODEL_LCA,
CUSTOMER_MODEL,
MATERIAL_NAME,
MODEL_NAME,
MODEL_CODE,
IS_MINILED_CODE,
MATERIAL_GROUP_CODE,
SALE_MODEL_CODE,
SALE_MODEL_NAME

)
WITH
  bg_azienda AS (
    SELECT COD_BG, COD_AZIENDA
    FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
    WHERE COD_BG IN ('BG001_BU001')
  ),
-- CTE 2: 符合L1条件的公司集合（替代3处 COD_AZIENDA IN (SELECT ... ATSMAP WHERE COD_BG IN (SELECT ...))）
CTE_L1_AZI AS (
    SELECT A.COD_AZIENDA, A.COD_BG
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
     WHERE A.COD_BG = 'BG001_BU001'
),
-- CTE 3: 同业务组公司对（用于排除"公司+CTP在同一BG"的情况）
CTE_SAME_BG_PAIR AS (
    SELECT A1.COD_AZIENDA AS COD_AZI_SELL, A2.COD_AZIENDA AS COD_AZI_BUY
      FROM CTE_L1_AZI A1
      INNER JOIN CTE_L1_AZI A2 ON A1.COD_BG = A2.COD_BG
),
-- CTE 4: 内销DEST3（HN）
CTE_DEST3_HN AS (
    SELECT ELEM
      FROM SESSION_V_REF_DEST3_NONAME
     WHERE SESSION_ID = V_SESSION_ID
       AND NODE = 'HN'
),
excl_mat AS
(

    SELECT CASE WHEN M_LIST.ZDETAIL IS NULL THEN AW.MATERIAL_CODE
                ELSE M_LIST.ZDETAIL
           END AS ZDETAIL
      FROM AW_MR9_REVM05_000001_TEMP AW
      LEFT JOIN (SELECT ZSET, ZDETAIL
                   FROM TGK_FIMA_HISENSE.ZTAB_MATNR_TJ) M_LIST
             ON AW.MATERIAL_CODE = M_LIST.ZSET
     WHERE AW.COD_SCENARIO = P_SCENARIO
       AND AW.COD_PERIODO  = P_PERIODO
       AND AW.MATERIAL_CODE IS NOT NULL
       AND AW.ORG_QTY <> 0
       AND AW.COD_AZIENDA IN (SELECT COD_AZIENDA FROM bg_azienda)
       AND AW.COD_DEST3 IN (SELECT ELEM FROM CTE_DEST3_HN)
       AND NOT EXISTS (
           SELECT 1 FROM CTE_SAME_BG_PAIR P
            WHERE P.COD_AZI_SELL = AW.COD_AZIENDA
              AND P.COD_AZI_BUY  = NVL(AW.COD_AZI_CTP_ORG, '9999')
       )
     GROUP BY CASE WHEN M_LIST.ZDETAIL IS NULL THEN AW.MATERIAL_CODE
                ELSE M_LIST.ZDETAIL
           END
     HAVING SUM(AW.ORG_QTY) <> 0
)
/*
  excl_mat AS (
  \*20260819 SHIQNGFENG.EX 插入未实现金额修改为全单机*\
    SELECT AW.MATERIAL_CODE\*CASE WHEN M_LIST.ZDETAIL IS NULL
                THEN AW.MATERIAL_CODE
                ELSE M_LIST.ZDETAIL
           END AS MATERIAL_CODE*\
    FROM AW_MR9_REVM05_000001_TEMP AW
    LEFT JOIN TGK_FIMA_HISENSE.ZTAB_MATNR_TJ M_LIST
           ON AW.MATERIAL_CODE = M_LIST.ZSET
    WHERE AW.COD_SCENARIO = P_SCENARIO
      AND AW.COD_PERIODO  = P_PERIODO
      AND AW.COD_AZIENDA IN (
              SELECT COD_AZIENDA FROM bg_azienda WHERE COD_BG = 'BG001_BU001'
          )
      AND NOT EXISTS (
              SELECT 1
              FROM bg_azienda A1
              INNER JOIN bg_azienda A2 ON A1.COD_BG = A2.COD_BG
              WHERE A1.COD_AZIENDA = AW.COD_AZIENDA
                AND A2.COD_AZIENDA = NVL(AW.COD_AZI_CTP_ORG, '9999')
          )
      AND AW.COD_DEST3 IN (
              SELECT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE SESSION_ID = V_SESSION_ID AND NODE = 'HN'
          )
    GROUP BY AW.MATERIAL_CODE
      \*CASE WHEN M_LIST.ZDETAIL IS NULL
           THEN AW.MATERIAL_CODE
           ELSE M_LIST.ZDETAIL
      END*\
    HAVING SUM(NVL(AW.BEG_UNREAL_GP, 0)) <> 0
        OR SUM(NVL(AW.END_UNREAL_GP, 0)) <> 0
  )*/

SELECT
  NEWID()                                              AS OID,
  '020_OFF_002'                                        AS D_ONOFFLINE,
  'UP'                                                 AS SRC_DETAIL,
  'S640110C'                                           AS COD_CONTO,
  X1.COD_SCENARIO,
  X1.COD_PERIODO,
  '2000'                                               AS COD_AZIENDA,
  'ZAMOUNT'                                            AS COD_CATEGORIA,
  X1.MATERIAL_CODE,
  X1.COD_DEST2,
  X1.COD_DEST3,
  X1.COD_DEST4,
  X1.BEG_UNREAL_GP,
  X1.END_UNREAL_GP,
  SYSDATE                                              AS DATEUPD,
  SESSION_USER                                         AS USERUPD,
  'CPM_SP_M2M_REV_M'                                   AS PROVENIENZA,
  NVL(MARA.MARKET_POS_CODE,   'ZZZZ')                 AS D_MARKET_PNT,       -- 市场定位
  NVL(MARA.prod_suite_code,   'ZZZZ')                 AS D_PRO_SSER,         -- 产品套系
  NVL(CASE WHEN MARA.big_class_code = 'P01' THEN MARA.SCREEN_SIZE_CODE
       WHEN MARA.big_class_code = 'P02' THEN MARA.SPEC_RANGE_CODE
       WHEN MARA.big_class_code = 'P03' THEN MARA.TOTAL_CAPACITY_CODE
       WHEN MARA.big_class_code = 'P04' THEN MARA.WASHING_CAPACITY_CODE
  END,'ZZZZ')                 AS D_SPEC_SEC,         -- 规格段
  NVL(MARA.PRODUCT_SPEC_CODE, 'ZZZZ')                 AS D_PRO_TYPE_S,       -- 产品规格类型
  NVL(MARA.PROD_STAGE_CODE,   'ZZZZ')                 AS D_PRO_STAGE,        -- 产品阶段
  NVL(MARA.PRICE_RANGE_CODE,  'ZZZZ')                 AS D_PRI_RANGE,        -- 价格段
  NVL(MARA.SERIES_CODE,       'ZZZZ')                 AS D_PRO_SERIES,       -- 产品系列
  NVL(MARA.AC_CT_CODE,        'ZZZZ')                 AS D_TECH_TYPE,        -- 技术类型
  NVL(MARA.small_class_code,  'ZZZZ')                 AS D_PRO_CLASS,        -- 产品小类
  NVL(MARA.model_lca,         'ZZZZ')                 AS D_MODEL_LCA,        -- 型号生命周期
  COALESCE(
    NULLIF(UPPER(MARA.sale_model_name), '无'),
    NULLIF(UPPER(MARA.zcusmodel),       '无')
  )                                                    AS CUSTOMER_MODEL,    -- 客户型号
  MARA.product_name                                    AS MATERIAL_NAME,     -- 物料描述
  NVL(MARA.model_name,        'ZZZZ')                 AS MODEL_NAME,         -- 型号名称
  NVL(MARA.model_code,        'ZZZZ')                 AS MODEL_CODE,         -- 型号编码
  NVL(CASE WHEN MARA.is_miniled_code = 'PC00013001' THEN '是'
           WHEN MARA.is_miniled_code = 'PC00013002' THEN '否'
           ELSE ''
       END, 'ZZZZ')                                    AS IS_MINILED_CODE,   -- 是否MiniLED
  NVL(REPLACE(REPLACE(REPLACE(MARA.prod_line,'BP',''),'DS',''),'TA',''),
      'ZZZZ')                                          AS MATERIAL_GROUP_CODE, -- 物料组
  NVL(COALESCE(
        NULLIF(TRIM(MARA.zzprdmodel),    ''),
        NULLIF(TRIM(MARA.zfacmodel),     ''),
        NULLIF(TRIM(MARA.pmodel_number), '')
      ), 'ZZZZ')                                       AS SALE_MODEL_CODE,   -- 销售型号
  NVL(MARA.sale_model_name,   'ZZZZ')                 AS SALE_MODEL_NAME


FROM (
    SELECT MATERIAL_CODE,
           COD_SCENARIO,
           COD_PERIODO,
           COD_DEST2,
           COD_DEST3,
           COD_DEST4,
           BEG_UNREAL_GP,
           END_UNREAL_GP
    FROM TGK_FIMA_HISENSE.AW_MR9_REVM04_000001
    WHERE COD_SCENARIO = P_SCENARIO
      AND COD_PERIODO  = P_PERIODO
      /* AND COD_AZIENDA IN (
                     SELECT COD_AZIENDA
                     FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                     WHERE COD_BG IN ('BG001_BU001')
                   ) */
      AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                             AND ELEM IN (
                                         SELECT COD_AZIENDA
                                         FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                                         WHERE COD_BG IN ('BG001_BU001')
                                      )
                                    )
     --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
      AND D_BU         = 'BG001_BU001'
      AND COD_DEST3 IN (
              SELECT ELEM FROM CTE_DEST3_HN
          )


) X1
LEFT JOIN TGK_FIMA_HISENSE.DIM_FI_PRODUCT MARA
       ON X1.MATERIAL_CODE = MARA.MATNR

WHERE NOT EXISTS (
    SELECT 1 FROM excl_mat e
    WHERE e.ZDETAIL = X1.MATERIAL_CODE
)
;



    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_3（插入无销量未实现金额）完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '2  插入合并层调整数据',P_AZIENDA);

COMMIT;




SELECT COUNT(1)
  INTO V_FLAG
  FROM  SESSION_AZIENDA_LIST
 WHERE SESSION_ID = V_SESSION_ID
   AND (ELEM LIKE '17%' OR ELEM = '6240') ;

IF V_FLAG > 0

THEN

    /* ----------------------------------------------------------------------
       ALTER BY <你的域账号>.EX 20261116 17:25:00
       3-0  重跑清理：日立段每次运行前先清掉上一轮产出的数据，保证跑几次结果都一样
            · 删 GB_ZXSLR（轧差行）—— 不清的话第二次运行轧差会重复插一遍，差异翻倍
            · 删 CPM_SP_BSFT_M_T0（分摊冲销行）—— 不清的话冲销行叠加
            · OTH_ASSESS_COST 归零 —— 结果列全清，重算后即为最新结果
            只动 本场景 + 本期间 + 050 节点公司；上游各步骤写入的原始行、以及
            待分摊金额（SALE_COGS / DOM_PSI_COST / FAC_EXTERNAL_SALE_COST）一行不删。
       ---------------------------------------------------------------------- */
    DELETE FROM AW_MR9_REVM05_000001_TEMP
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO  = P_PERIODO
       AND COD_AZIENDA  IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                             WHERE SESSION_ID = V_SESSION_ID
                               AND (ELEM LIKE '17%' OR ELEM = '6240'))
       AND (PROVENIENZA = 'CPM_SP_BSFT_M_T0' OR SRC_DETAIL = 'GB_ZXSLR');

    UPDATE AW_MR9_REVM05_000001_TEMP
       SET OTH_ASSESS_COST = 0
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO  = P_PERIODO
       AND COD_AZIENDA  IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                             WHERE SESSION_ID = V_SESSION_ID
                               AND (ELEM LIKE '17%' OR ELEM = '6240'));

    DELETE FROM ZTAB_BSFT_BASE1
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO  = P_PERIODO;
    COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  插入日立单位成本开始', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  插入日立单位成本开始',P_AZIENDA);
    COMMIT;

  /* 更新日立产销存单位成本字段 WTD_UNIT_COST --fjf_add */
  MERGE /*+ USE_HASH(SS T) */ INTO AW_MR9_REVM05_000001_TEMP SS
  USING (SELECT A.OID, B.DWCB AS WTD_UNIT_COST
           FROM (SELECT OID, COD_AZIENDA, MATERIAL_CODE, MANG_QTY
                   FROM AW_MR9_REVM05_000001_TEMP T
                  WHERE 1 = 1
                    AND COD_SCENARIO = P_SCENARIO
                    AND COD_PERIODO = P_PERIODO
                    --AND (COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240')
                    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND (ELEM LIKE '17%' OR ELEM = '6240')
                                    )
                    AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
                    ) A
          INNER JOIN (SELECT GJAHR,
                            POPER,
                            MATNR,
                            MEINS,
                            BISMT,
                            SUM(COST_MO2) AS COST_MO2,
                            SUM(MNG_SALE) AS MNG_SALE,
                            DECODE(SUM(MNG_SALE),
                                   0,
                                   0,
                                   SUM(COST_MO2) / SUM(MNG_SALE)) AS DWCB
                     --SELECT *
                       FROM TGK_GB_HISENSE.V_HITACH_ZXSLR_CONS T --合并成本
                      WHERE 1 = 1
                        AND T.GJAHR = SUBSTR(P_SCENARIO, 1, 4)
                        AND T.POPER = P_PERIODO
                      GROUP BY GJAHR, POPER, MATNR, MEINS, BISMT
                     HAVING SUM(MNG_SALE) <> 0) B
             ON A.MATERIAL_CODE = B.MATNR) T

  ON (SS.OID = T.OID
  --and SS.COD_SCENARIO = P_SCENARIO
  --AND SS.COD_PERIODO = P_PERIODO

  --AND (INSTR(V_AZIENDA, SS.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')

  /*20260226 新增排除锁定公司*/
  /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                            FROM AW_RUL_DWMCRS_000001 T
                           WHERE REV05_FLAG = 'Y'
                             AND T.COD_SCENARIO = P_SCENARIO
                             AND T.COD_PERIODO = P_PERIODO
                             AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
   )
  WHEN MATCHED THEN
    UPDATE SET WTD_UNIT_COST = T.WTD_UNIT_COST;


/*20260905 zhuangxinzhou错误修正原在轧差之后错误*/


  UPDATE AW_MR9_REVM05_000001_TEMP
     SET DOM_PSI_COST = NVL(BILL_QTY, 0) * NVL(WTD_UNIT_COST, 0)
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND (ELEM LIKE '17%' OR ELEM = '6240')
                        )
     AND COD_DEST3 IN (SELECT ELEM
                         FROM SESSION_V_REF_DEST3_NONAME
                        WHERE SESSION_ID = V_SESSION_ID
                          AND HIE = '01'
                          AND NODE = 'HN')
    AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
  ;







  UPDATE AW_MR9_REVM05_000001_TEMP
     SET FAC_EXTERNAL_SALE_COST = NVL(BILL_QTY, 0) * NVL(WTD_UNIT_COST, 0)
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND (ELEM LIKE '17%' OR ELEM = '6240')
                        )
     AND COD_DEST3 IN
                    (SELECT ELEM
                       FROM SESSION_V_REF_DEST3_NONAME
                      WHERE SESSION_ID = V_SESSION_ID AND HIE = '01'
                        AND NODE = 'HW')
     AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
  ;




/*
  UPDATE AW_MR9_REVM05_000001_TEMP
     SET DOM_PSI_COST = CASE
                        \* 更新日立工厂端内销销售成本字段 --fjf_add *\
                          WHEN COD_DEST3 IN (SELECT ELEM
                                               FROM SESSION_V_REF_DEST3_NONAME
                                              WHERE SESSION_ID = V_SESSION_ID
                                                AND HIE = '01'
                                                AND NODE = 'HN') AND
                               (COD_AZIENDA LIKE '17%' OR
                               COD_AZIENDA = '6240') THEN
                           NVL(BILL_QTY, 0) * NVL(WTD_UNIT_COST, 0)
                          WHEN COD_DEST3 IN (SELECT ELEM
                                               FROM SESSION_V_REF_DEST3_NONAME
                                              WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01'
                                                AND NODE = 'HN') THEN
                           NVL(ORG_QTY, 0) * NVL(WTD_UNIT_COST, 0)
                          ELSE
                           0
                        END

         \* 更新日立工厂端外销销售成本字段 --fjf_add *\,
         FAC_EXTERNAL_SALE_COST = CASE
                                    WHEN COD_DEST3 IN
                                         (SELECT ELEM
                                            FROM SESSION_V_REF_DEST3_NONAME
                                           WHERE SESSION_ID = V_SESSION_ID AND HIE = '01'
                                             AND NODE = 'HW') AND
                                         (COD_AZIENDA LIKE '17%' OR
                                         COD_AZIENDA = '6240') THEN
                                     NVL(BILL_QTY, 0) * NVL(WTD_UNIT_COST, 0)
                                    ELSE
                                     0
                                  END
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
    --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
        \*20260226 新增排除锁定公司*\
     \* AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK') *\
     AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
  ---AND SRC_DETAIL='VBRP'
  ;
*/


    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  插入未实现数据和产销存单位成本', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  插入未实现数据和产销存单位成本',P_AZIENDA);
    COMMIT;
/*20260905*/


INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  插入日立单位成本结束', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  插入日立单位成本结束',P_AZIENDA);
    COMMIT;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  日立内外销成本及成本轧差处理开始', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  日立内外销成本及成本轧差处理开始',P_AZIENDA);
    COMMIT;



 /* 日立成本轧差处理：因为日立的老管报成本和现有成本两边不一致_fjf_add */
 INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP
  (
    OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT
    , D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES
    , D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE
    , SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE
    , SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST, AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST
    , OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL, FAC_EXTERNAL_SALE_REVENUE
    , IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM
    , COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY, CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST
    , ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY
    , FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY, DOM_PSI_COST, FAC_EXTERNAL_SALE_COST,D_MINILED
    )

WITH SRC AS
(
  SELECT OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT
    , D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES
    , D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE
    , SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE
    , SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST, AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST
    , OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL, FAC_EXTERNAL_SALE_REVENUE
    , IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM
    , COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY, CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST
    , ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY
    , FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY
  , NVL(DOM_PSI_COST,0) AS DOM_PSI_COST
  , NVL(FAC_EXTERNAL_SALE_COST,0) AS FAC_EXTERNAL_SALE_COST
  ,D_MINILED
  FROM AW_MR9_REVM05_000001_TEMP
  WHERE 1 = 1
  AND COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                       WHERE SESSION_ID = V_SESSION_ID
                          AND (ELEM LIKE '17%' OR ELEM = '6240')
                      )
  --AND (COD_AZIENDA LIKE '17%' OR COD_AZIENDA = '6240')
  AND COD_CONTO NOT LIKE '%AD'
  AND NVL(PROVENIENZA,'|') <> 'CPM_SP_BSFT_M_T0'  /* ALTER BY LIYIFAN1.EX 20261116 16:24:00 轧差取数排除上一轮日立分摊冲销行 */
)

SELECT NEWID() AS OID, COD_SCENARIO, COD_PERIODO, 'GB_ZXSLR' AS SRC_DETAIL,'S640100'AS COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT
    , D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES
    , D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE
    , SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE
    , SHOP_NAME
    , 0 AS MAP_QTY, 0 AS ORG_REV, 0 AS POLICY_AMT,0 AS ASSESSED_REV,0 AS SALE_COGS,0 AS BEG_UNREAL_GP,0 AS END_UNREAL_GP,0 AS COMB_COST,0 AS AVG_UNIT_COST
    , 0 AS COMB_COST_AVG,0 AS PSI_COMB_COST,0 AS WTD_UNIT_COST
    , 0 AS OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, 0 AS POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL
    , 0 AS FAC_EXTERNAL_SALE_REVENUE, 0 AS IM_SALE_COST
    , COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE
    , 0 AS CN_SALE_COGS, 0 AS CN_ORG_REV, 0 AS CN_MAP_ZUM
    , COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST,0 ELIM_REV,0 COMB_REV,0 MANG_REV,0 ENT_QTY,0 ENT_QTY_ADJ,0 ELIM_QTY,0 CADJ_QTY,0 MANG_QTY,0 ENT_REV,0 ENT_REV_ADJ,0 CADJ_REV, ENT_COST
    , ENT_COST_ADJ, CADJ_COST,0 CN_ELIM_QTY,0 CN_MANG_QTY,0 CN_ELIM_REV,0 CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE
    , 0 AS ORG_QTY
    , 0 FAC_MANG_REV,0 IM_MANG_REV,0 FAC_CADJ_REV,0 CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1
    , 0 AS BILL_QTY
    , CASE WHEN T.COD_DEST3 IN (SELECT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01' AND NODE = 'HN') THEN D.CY_COST ELSE 0 END AS DOM_PSI_COST
    , CASE WHEN T.COD_DEST3 IN (SELECT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01' AND NODE = 'HW') THEN D.CY_COST ELSE 0 END AS  FAC_EXTERNAL_SALE_COST
  ,D_MINILED
FROM(
    SELECT * FROM SRC
  )T
INNER JOIN
  (
    SELECT OID,CY_COST
    FROM( --按物料找出最大销量对应行ID：维度按照销量最大的行的维度来定义
        SELECT OID, MATERIAL_CODE, BILL_QTY
        FROM(
            SELECT OID, MATERIAL_CODE, BILL_QTY
              ,ROW_NUMBER() OVER (PARTITION BY MATERIAL_CODE ORDER BY BILL_QTY DESC) AS RN
            FROM SRC
          )
        WHERE RN = 1
      )SRC
    INNER JOIN
      (
        --取出两边系统的成本然后计算出成本差
        SELECT B.GJAHR AS COD_SCENARIO,B.POPER AS COD_PERIODO,B.MATNR AS MATERIAL_CODE
          ,NVL(B.COST_MO2,0) - NVL(A.TOTAL_COST,0) AS CY_COST
        FROM(
            SELECT COD_SCENARIO, COD_PERIODO,  MATERIAL_CODE
              ,SUM(NVL(DOM_PSI_COST,0) + NVL(FAC_EXTERNAL_SALE_COST,0)) AS TOTAL_COST
              ,SUM(BILL_QTY) AS BILL_QTY
            FROM SRC
            GROUP BY COD_SCENARIO,COD_PERIODO,MATERIAL_CODE
            HAVING SUM(DOM_PSI_COST + FAC_EXTERNAL_SALE_COST) <> 0
          ) A
        LEFT JOIN
          ( --老管报合并成本
            SELECT GJAHR,POPER,MATNR,SUM(NVL(COST_MO2,0)) AS COST_MO2,SUM(MNG_SALE) AS MNG_SALE
            FROM TGK_GB_HISENSE.V_HITACH_ZXSLR_CONS T --合并成本
            WHERE 1 = 1
            AND T.GJAHR = SUBSTR(P_SCENARIO ,1 ,4)
            AND T.POPER = P_PERIODO
            GROUP BY GJAHR,POPER,MATNR
            HAVING SUM(MNG_SALE) <> 0
          ) B
        ON A.MATERIAL_CODE = B.MATNR
        WHERE (NVL(B.COST_MO2,0) - NVL(A.TOTAL_COST,0)) <> 0
        AND NVL(B.COST_MO2,0) <> 0
      )C
    ON SRC.MATERIAL_CODE = C.MATERIAL_CODE
  )D
ON T.OID = D.OID
;
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  日立内外销成本及成本轧差处理结束', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '3  日立内外销成本及成本轧差处理结束',P_AZIENDA);
    COMMIT;

    /* ======================================================================
       ALTER BY LIYIFAN1.EX 20261116 16:24:00
       新增「3-2  日立合并层成本分摊（BSFT）」（接在 3 日立成本轧差之后）
       五场景待分摊 → 五个因子池 → 结果写 OTH_ASSESS_COST → ④⑤ 冲销原行
       过程数据落 ZTAB_BSFT_BASE1（需先建表，否则本段 ORA-00942）
       【公司范围判定】本段位于外层 IF V_FLAG > 0 内（V_FLAG = SESSION_AZIENDA_LIST 中 17%/6240 公司条数）：
         · 参数不含 050 节点公司时进不来 —— V_FLAG 统计 SESSION_AZIENDA_LIST 中
           ELEM LIKE '17%' OR ELEM = '6240' 的条数，为 0 则整段跳过；
         · 只要进来，取数与接收一律按 SESSION_AZIENDA_LIST —— 该表在
           P_AZIENDA LIKE '17%' 或 P_AZIENDA = '6240' 时整节点展开
           （见 SESSION_AZIENDA_LIST / SESSION_V_REF_AZIENDA 装载处的 ((P_AZIENDA LIKE '17%' OR P_AZIENDA = '6240')
           AND NODE = '050') 分支），所以只跑一家公司也按整个 050 节点分摊。
       【重跑】日立段开头有「3-0 重跑清理」：先删上一轮 GB_ZXSLR 轧差行与 BSFT 冲销行、
         OTH_ASSESS_COST 归零，再重算，所以第二次运行结果与第一次完全一致。
       【不覆盖待分摊数】本段对 AW_MR9_REVM05_000001_TEMP 只做两类写：
         ① 插负数冲销行（PROVENIENZA='CPM_SP_BSFT_M_T0'）；② 把分摊结果 SET 进
         接收行 OTH_ASSESS_COST。待分摊金额一行不改，分摊前/过程/结果全部可在
         ZTAB_BSFT_BASE1 查到。
       ★ 本段必须位于本文件 PSI_COMB_COST = DOM_PSI_COST + OTH_ASSESS_COST 的汇总 UPDATE 之前，
         否则分摊额不进产销存成本，日立合并成本（DOM+OTH+CADJ）随之少一块
       ====================================================================== */

    --------------------------------------------------------------------------
    /* 3-2  日立合并层成本分摊（BSFT）开始 */
    --------------------------------------------------------------------------
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK, COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '3  日立合并层成本分摊（BSFT）开始', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO,
           '3  日立合并层成本分摊（BSFT）开始', P_AZIENDA);
    COMMIT;

    /* ----------------------------------------------------------------------
       S1  清理已在日立段开头「3-0 重跑清理」完成，本段不再重复：
            删上一轮 GB_ZXSLR 轧差行 / CPM_SP_BSFT_M_T0 冲销行 / OTH_ASSESS_COST 归零
           分摊前金额 / 因子 / 分母 / 比例 / 结果全部落在 ZTAB_BSFT_BASE1：
             COD_CATEGORIA = 'T0'  待分摊，每笔来源一行（OID = 源行 OID，AMT_T0 = 该笔金额）
             COD_CATEGORIA = 'RS'  因子明细（OID = 接收行 OID，
                                   FACTOR_AMT 因子 / FACTOR_SUM 分母 / RATE 比例 / ALLOC_AMT 分摊额）
           对目标表只在 S9 写一次：把汇总分摊额 SET 进接收行 OTH_ASSESS_COST（覆盖不累加）。
           ④⑤ 的原行金额保持不动，另插负数行冲销，分摊前 / 冲销 / 分摊后三方都留痕。
       ---------------------------------------------------------------------- */

    /* ----------------------------------------------------------------------
       S2b  装载「12-海外」业务管理单元码表
            源：V_REF_ED_D_SALE_DEPT（HIE='HISD'，NODE 为一级节点编码，12=海外，
                含 12A 海外自营、12B 全球大客户运营），ELEM 为业务管理单元编码
            ELEM 形如 1730.S0026，落表时把点号后半段抽成 POOL_ID 统一比对，
            避免每处重复写 SUBSTR/INSTR
       ---------------------------------------------------------------------- */
    INSERT INTO ZTAB_BSFT_BASE1
      (COD_SCENARIO, COD_PERIODO, COD_CATEGORIA, SCENE, POOL_ID, NUM,
       COD_AZIENDA, D_SALE_DEPT, DATEUPD, USERUPD)
    SELECT P_SCENARIO, P_PERIODO, 'MAP', '12',
           CASE WHEN INSTR(X.ELEM, '.') > 0 THEN SUBSTR(X.ELEM, INSTR(X.ELEM, '.') + 1) ELSE X.ELEM END,
           SUBSTR('000000' || ROWNUM, -5),
           CASE WHEN INSTR(X.ELEM, '.') > 0 THEN SUBSTR(X.ELEM, 1, INSTR(X.ELEM, '.') - 1) END,
           X.ELEM, SYSDATE, SESSION_USER
      FROM (SELECT DISTINCT ELEM
              FROM TGK_FIMA_HISENSE.V_REF_ED_D_SALE_DEPT
             WHERE HIE = 'HISD'
               AND NODE = '12') X;
    COMMIT;

    /* 码表为空时只告警不中断：否则①②④ 的接收范围会整体失真 */
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK, COD_AZIENDA)
    SELECT 'CPM_SP_M2M_REV_M', '3  BSFT告警：12-海外码表为空', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO,
           'V_REF_ED_D_SALE_DEPT(HIE=HISD,NODE=12) 取不到业务管理单元，①②④ 的接收范围将全部按「不在12-海外」处理',
           P_AZIENDA
      FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM ZTAB_BSFT_BASE1
                        WHERE COD_SCENARIO = P_SCENARIO AND COD_PERIODO = P_PERIODO
                          AND COD_CATEGORIA = 'MAP');
    COMMIT;

    /* ----------------------------------------------------------------------
       S3  待分摊①②③：老管报 TGK_GB_HISENSE.V_HITACH_ZXSLR_CONS
           ① 总账内销：MATNR IN ('总账成本_内销','总账成本_内销_solution')
           ② 总账外销：MATNR = '总账成本_外销'
           ①② 各只产 1 行（单行内联视图 + WHERE 过滤，不会放大）
           需求里「SRC_DETAIL<>'BSFT'」是老管报视图没有的字段，该限制只作用于
           新管报侧（④⑤ 与因子池），此处不适用
       ---------------------------------------------------------------------- */
    INSERT INTO ZTAB_BSFT_BASE1
      (COD_SCENARIO, COD_PERIODO, COD_CATEGORIA, SCENE, POOL_ID, NUM,
       COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, D_SALE_DEPT, MATERIAL_CODE,
       AMT_T0, DATEUPD, USERUPD)
    WITH OLD AS
    (
      SELECT MATNR, SUM(NVL(COST_MO2, 0)) AS COST_MO2
        FROM TGK_GB_HISENSE.V_HITACH_ZXSLR_CONS
       WHERE GJAHR = SUBSTR(P_SCENARIO, 1, 4)
         AND POPER = P_PERIODO
       GROUP BY MATNR
    )
    SELECT P_SCENARIO, P_PERIODO, 'T0', '01', '01', '00001',
           NULL, NULL, NULL, NULL, NULL, NULL,
           X.AMT, SYSDATE, SESSION_USER
      FROM (SELECT NVL(SUM(CASE WHEN MATNR IN ('总账成本_内销', '总账成本_内销_solution')
                                THEN COST_MO2 END), 0) AS AMT
              FROM OLD) X
     WHERE X.AMT <> 0;

    INSERT INTO ZTAB_BSFT_BASE1
      (COD_SCENARIO, COD_PERIODO, COD_CATEGORIA, SCENE, POOL_ID, NUM,
       COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, D_SALE_DEPT, MATERIAL_CODE,
       AMT_T0, DATEUPD, USERUPD)
    WITH OLD AS
    (
      SELECT MATNR, SUM(NVL(COST_MO2, 0)) AS COST_MO2
        FROM TGK_GB_HISENSE.V_HITACH_ZXSLR_CONS
       WHERE GJAHR = SUBSTR(P_SCENARIO, 1, 4)
         AND POPER = P_PERIODO
       GROUP BY MATNR
    )
    SELECT P_SCENARIO, P_PERIODO, 'T0', '02', '02', '00001',
           NULL, NULL, NULL, NULL, NULL, NULL,
           X.AMT, SYSDATE, SESSION_USER
      FROM (SELECT NVL(SUM(CASE WHEN MATNR = '总账成本_外销' THEN COST_MO2 END), 0) AS AMT
              FROM OLD) X
     WHERE X.AMT <> 0;
    COMMIT;

    /* ----------------------------------------------------------------------
       S3-3  待分摊③ 物料差异
             仅源表（老管报）有、新管报无的物料：
             新管报该物料的「老管报来源成本合计」= 0
             老管报来源判定：NVL(WTD_UNIT_COST,0) <> 0 OR SRC_DETAIL = 'GB_ZXSLR'
             按 MATNR 唯一（OLD 已 GROUP BY MATNR），保留物料级明细便于事后核对
       ---------------------------------------------------------------------- */
    INSERT INTO ZTAB_BSFT_BASE1
      (COD_SCENARIO, COD_PERIODO, COD_CATEGORIA, SCENE, POOL_ID, NUM,
       COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, D_SALE_DEPT, MATERIAL_CODE,
       AMT_T0, DATEUPD, USERUPD)
    WITH OLD AS
    (
      SELECT MATNR, SUM(NVL(COST_MO2, 0)) AS COST_MO2
        FROM TGK_GB_HISENSE.V_HITACH_ZXSLR_CONS
       WHERE GJAHR = SUBSTR(P_SCENARIO, 1, 4)
         AND POPER = P_PERIODO
       GROUP BY MATNR
    ),
    SRCMAT AS
    (
      SELECT T.MATERIAL_CODE
        FROM AW_MR9_REVM05_000001_TEMP T
       WHERE T.COD_SCENARIO = P_SCENARIO
         AND T.COD_PERIODO  = P_PERIODO
         AND T.COD_AZIENDA  IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                 WHERE SESSION_ID = V_SESSION_ID
                                   AND (ELEM LIKE '17%' OR ELEM = '6240'))
         AND T.MATERIAL_CODE IS NOT NULL
         AND (NVL(T.WTD_UNIT_COST, 0) <> 0 OR T.SRC_DETAIL = 'GB_ZXSLR')
         AND NVL(T.SRC_DETAIL, '|') <> 'BSFT'
       GROUP BY T.MATERIAL_CODE
      HAVING SUM(NVL(T.DOM_PSI_COST, 0) + NVL(T.FAC_EXTERNAL_SALE_COST, 0)) <> 0
    )
    SELECT P_SCENARIO, P_PERIODO, 'T0', '03', '03',
           SUBSTR('000000' || ROWNUM, -5),
           NULL, NULL, NULL, NULL, NULL, O.MATNR,
           O.COST_MO2, SYSDATE, SESSION_USER
      FROM OLD O
     WHERE O.MATNR NOT LIKE '%总账%'
       AND O.COST_MO2 <> 0
       AND NOT EXISTS (SELECT 1 FROM SRCMAT M WHERE M.MATERIAL_CODE = O.MATNR);
    COMMIT;

    /* ----------------------------------------------------------------------
       S4-4  待分摊④ 管法差
             新管报：物料为空、管法差异项有值且非 ZZZZ
             按 OID 一行（OID 唯一，1:1），池 = 全 050 节点一张
       ---------------------------------------------------------------------- */
    INSERT INTO ZTAB_BSFT_BASE1
      (COD_SCENARIO, COD_PERIODO, COD_CATEGORIA, SCENE, POOL_ID, NUM, OID,
       COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, D_SALE_DEPT, MATERIAL_CODE,
       AMT_T0, DATEUPD, USERUPD)
    SELECT P_SCENARIO, P_PERIODO, 'T0', '04', '04',
           SUBSTR('000000' || ROW_NUMBER() OVER (ORDER BY X.OID), -5), X.OID,
           X.COD_AZIENDA, X.COD_DEST2, X.COD_DEST3, X.COD_DEST4, X.D_SALE_DEPT, NULL,
           X.AMT_T0, SYSDATE, SESSION_USER
      FROM (SELECT T.OID, T.COD_AZIENDA, T.COD_DEST2, T.COD_DEST3, T.COD_DEST4, T.D_SALE_DEPT,
                   SUM(NVL(T.SALE_COGS, 0)) AS AMT_T0
              FROM AW_MR9_REVM05_000001_TEMP T
             WHERE T.COD_SCENARIO = P_SCENARIO
               AND T.COD_PERIODO  = P_PERIODO
               AND T.COD_AZIENDA  IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                       WHERE SESSION_ID = V_SESSION_ID
                                         AND (ELEM LIKE '17%' OR ELEM = '6240'))
               AND T.D_DIFF_TYPE IS NOT NULL
               AND T.D_DIFF_TYPE <> 'ZZZZ'
               AND NVL(T.SRC_DETAIL, '|') <> 'BSFT'
               AND T.MATERIAL_CODE IS NULL
             GROUP BY T.OID, T.COD_AZIENDA, T.COD_DEST2, T.COD_DEST3, T.COD_DEST4, T.D_SALE_DEPT
            HAVING SUM(NVL(T.SALE_COGS, 0)) <> 0) X;
    COMMIT;

    /* ----------------------------------------------------------------------
       S4-5  待分摊⑤ 手工调整兜底
             新管报：物料为空、类别 GA00_CON%（手工调整）、业务管理单元不在 12-海外
             每个业务管理单元一张池（跨公司，不带公司隔离）
             与④用 D_DIFF_TYPE 互斥，防止同一行被两个池各摊一次
             按源行逐笔写 T0（带 OID 与全部维度），池合计由 S5 按 POOL_ID 汇总，
             这样过程表能看到「哪一笔待摊了多少」，不会被池汇总吃掉明细
       ---------------------------------------------------------------------- */
    INSERT INTO ZTAB_BSFT_BASE1
      (COD_SCENARIO, COD_PERIODO, COD_CATEGORIA, SCENE, POOL_ID, NUM, OID,
       COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, D_SALE_DEPT, MATERIAL_CODE,
       AMT_T0, DATEUPD, USERUPD)
    SELECT P_SCENARIO, P_PERIODO, 'T0', '05', NVL(X.D_SALE_DEPT, 'ZZZZ'),
           SUBSTR('000000' || ROW_NUMBER() OVER (ORDER BY X.OID), -5), X.OID,
           X.COD_AZIENDA, X.COD_DEST2, X.COD_DEST3, X.COD_DEST4, NVL(X.D_SALE_DEPT, 'ZZZZ'), NULL,
           X.AMT_T0, SYSDATE, SESSION_USER
      FROM (SELECT T.OID, T.COD_AZIENDA, T.COD_DEST2, T.COD_DEST3, T.COD_DEST4, T.D_SALE_DEPT,
                   SUM(NVL(T.SALE_COGS, 0)) AS AMT_T0
              FROM AW_MR9_REVM05_000001_TEMP T
             WHERE T.COD_SCENARIO = P_SCENARIO
               AND T.COD_PERIODO  = P_PERIODO
               AND T.COD_AZIENDA  IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                       WHERE SESSION_ID = V_SESSION_ID
                                         AND (ELEM LIKE '17%' OR ELEM = '6240'))
               AND T.COD_CATEGORIA LIKE 'GA00_CON%'
               AND NVL(T.SRC_DETAIL, '|') <> 'BSFT'
               AND T.MATERIAL_CODE IS NULL
               AND NVL(T.D_DIFF_TYPE, 'ZZZZ') = 'ZZZZ'
               AND NOT EXISTS (SELECT 1 FROM ZTAB_BSFT_BASE1 H
                                WHERE H.COD_SCENARIO = P_SCENARIO
                                  AND H.COD_PERIODO  = P_PERIODO
                                  AND H.COD_CATEGORIA = 'MAP'
                                  AND H.POOL_ID = CASE WHEN INSTR(T.D_SALE_DEPT, '.') > 0
                                                       THEN SUBSTR(T.D_SALE_DEPT, INSTR(T.D_SALE_DEPT, '.') + 1)
                                                       ELSE NVL(T.D_SALE_DEPT, 'ZZZZ') END)
             GROUP BY T.OID, T.COD_AZIENDA, T.COD_DEST2, T.COD_DEST3, T.COD_DEST4, T.D_SALE_DEPT
            HAVING SUM(NVL(T.SALE_COGS, 0)) <> 0) X;
    COMMIT;

    /* ----------------------------------------------------------------------
       S5  分摊因子池（5 段 UNION ALL，一段一个场景）
           通用限制：050 节点 / 老管报来源成本<>0 / 非 BSFT / 物料不为空 /
                     管法差异项为空或 ZZZZ / 物料不在剔除集合
           ①②③④ 池金额取「单行内联视图 CROSS JOIN」，不产生笛卡尔积；
           ⑤ 池汇总按 POOL_ID 唯一后等值 JOIN（1:N，不放大接收行）；
           12-海外 判定一律 EXISTS / NOT EXISTS 半连接，不做 JOIN
       ---------------------------------------------------------------------- */
    INSERT INTO ZTAB_BSFT_BASE1
      (COD_SCENARIO, COD_PERIODO, COD_CATEGORIA, SCENE, POOL_ID, NUM, OID,
       COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, D_SALE_DEPT, MATERIAL_CODE,
       AMT_T0, FACTOR_AMT, DATEUPD, USERUPD)
    WITH CTE_AZI AS
    (
      SELECT ELEM FROM SESSION_AZIENDA_LIST
       WHERE SESSION_ID = V_SESSION_ID
         AND (ELEM LIKE '17%' OR ELEM = '6240')
    ),
    CTE_EXCL_MAT AS
    (
      SELECT MATERIAL_CODE
        FROM TGK_FIMA_HISENSE.AW_RUL_BAFRUL_000001
       WHERE COD_AZIENDA = '1730'
         AND SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
             BETWEEN NVL(VALID_FR, '000000') AND NVL(VALID_TO, '999999')
      UNION
      SELECT MATERIAL_CODE_R
        FROM TGK_FIMA_HISENSE.AW_RUL_RDEMAT_000001
       WHERE COMPANY_CODE_R = '050'
    ),
    BASE AS
    (
      SELECT T.OID, T.COD_AZIENDA, T.COD_DEST2, T.COD_DEST3, T.COD_DEST4,
             T.D_SALE_DEPT, T.MATERIAL_CODE,
             NVL(T.DOM_PSI_COST, 0)           AS DOM_AMT,
             NVL(T.FAC_EXTERNAL_SALE_COST, 0) AS FAC_AMT,
             CASE WHEN INSTR(T.D_SALE_DEPT, '.') > 0
                  THEN SUBSTR(T.D_SALE_DEPT, INSTR(T.D_SALE_DEPT, '.') + 1)
                  ELSE NVL(T.D_SALE_DEPT, 'ZZZZ') END AS DEPT_CODE
        FROM AW_MR9_REVM05_000001_TEMP T
       WHERE T.COD_SCENARIO = P_SCENARIO
         AND T.COD_PERIODO  = P_PERIODO
         AND T.COD_AZIENDA  IN (SELECT ELEM FROM CTE_AZI)
         AND (NVL(T.WTD_UNIT_COST, 0) <> 0 OR T.SRC_DETAIL = 'GB_ZXSLR')
         AND NVL(T.SRC_DETAIL, '|') <> 'BSFT'
         AND T.MATERIAL_CODE IS NOT NULL
         AND NVL(T.D_DIFF_TYPE, 'ZZZZ') = 'ZZZZ'
         AND NOT EXISTS (SELECT 1 FROM CTE_EXCL_MAT X WHERE X.MATERIAL_CODE = T.MATERIAL_CODE)
    )
    /* ① 总账内销：DOM_PSI_COST 因子，接收方不在 12-海外 */
    SELECT P_SCENARIO, P_PERIODO, 'RS', '01', '01', SUBSTR('000000' || ROWNUM, -5), B.OID,
           B.COD_AZIENDA, B.COD_DEST2, B.COD_DEST3, B.COD_DEST4, B.D_SALE_DEPT, B.MATERIAL_CODE,
           P.AMT_T0, B.DOM_AMT, SYSDATE, SESSION_USER
      FROM BASE B
     CROSS JOIN (SELECT NVL(SUM(AMT_T0), 0) AS AMT_T0 FROM ZTAB_BSFT_BASE1
                  WHERE COD_SCENARIO = P_SCENARIO AND COD_PERIODO = P_PERIODO
                    AND COD_CATEGORIA = 'T0' AND SCENE = '01') P
     WHERE B.DOM_AMT <> 0
       AND P.AMT_T0 <> 0
       AND NOT EXISTS (SELECT 1 FROM ZTAB_BSFT_BASE1 H
                        WHERE H.COD_SCENARIO = P_SCENARIO
                          AND H.COD_PERIODO  = P_PERIODO
                          AND H.COD_CATEGORIA = 'MAP'
                          AND H.POOL_ID = B.DEPT_CODE)
    UNION ALL
    /* ② 总账外销：FAC_EXTERNAL_SALE_COST 因子，接收方在 12-海外 */
    SELECT P_SCENARIO, P_PERIODO, 'RS', '02', '02', SUBSTR('000000' || ROWNUM, -5), B.OID,
           B.COD_AZIENDA, B.COD_DEST2, B.COD_DEST3, B.COD_DEST4, B.D_SALE_DEPT, B.MATERIAL_CODE,
           P.AMT_T0, B.FAC_AMT, SYSDATE, SESSION_USER
      FROM BASE B
     CROSS JOIN (SELECT NVL(SUM(AMT_T0), 0) AS AMT_T0 FROM ZTAB_BSFT_BASE1
                  WHERE COD_SCENARIO = P_SCENARIO AND COD_PERIODO = P_PERIODO
                    AND COD_CATEGORIA = 'T0' AND SCENE = '02') P
     WHERE B.FAC_AMT <> 0
       AND P.AMT_T0 <> 0
       AND EXISTS     (SELECT 1 FROM ZTAB_BSFT_BASE1 H
                        WHERE H.COD_SCENARIO = P_SCENARIO
                          AND H.COD_PERIODO  = P_PERIODO
                          AND H.COD_CATEGORIA = 'MAP'
                          AND H.POOL_ID = B.DEPT_CODE)
    UNION ALL
    /* ③ 物料差异：DOM+FAC 因子，不分内外销 */
    SELECT P_SCENARIO, P_PERIODO, 'RS', '03', '03', SUBSTR('000000' || ROWNUM, -5), B.OID,
           B.COD_AZIENDA, B.COD_DEST2, B.COD_DEST3, B.COD_DEST4, B.D_SALE_DEPT, B.MATERIAL_CODE,
           P.AMT_T0, B.DOM_AMT + B.FAC_AMT, SYSDATE, SESSION_USER
      FROM BASE B
     CROSS JOIN (SELECT NVL(SUM(AMT_T0), 0) AS AMT_T0 FROM ZTAB_BSFT_BASE1
                  WHERE COD_SCENARIO = P_SCENARIO AND COD_PERIODO = P_PERIODO
                    AND COD_CATEGORIA = 'T0' AND SCENE = '03') P
     WHERE (B.DOM_AMT + B.FAC_AMT) <> 0
       AND P.AMT_T0 <> 0
    UNION ALL
    /* ④ 管法差：DOM_PSI_COST 因子，接收方不在 12-海外 */
    SELECT P_SCENARIO, P_PERIODO, 'RS', '04', '04', SUBSTR('000000' || ROWNUM, -5), B.OID,
           B.COD_AZIENDA, B.COD_DEST2, B.COD_DEST3, B.COD_DEST4, B.D_SALE_DEPT, B.MATERIAL_CODE,
           P.AMT_T0, B.DOM_AMT, SYSDATE, SESSION_USER
      FROM BASE B
     CROSS JOIN (SELECT NVL(SUM(AMT_T0), 0) AS AMT_T0 FROM ZTAB_BSFT_BASE1
                  WHERE COD_SCENARIO = P_SCENARIO AND COD_PERIODO = P_PERIODO
                    AND COD_CATEGORIA = 'T0' AND SCENE = '04') P
     WHERE B.DOM_AMT <> 0
       AND P.AMT_T0 <> 0
       AND NOT EXISTS (SELECT 1 FROM ZTAB_BSFT_BASE1 H
                        WHERE H.COD_SCENARIO = P_SCENARIO
                          AND H.COD_PERIODO  = P_PERIODO
                          AND H.COD_CATEGORIA = 'MAP'
                          AND H.POOL_ID = B.DEPT_CODE)
    UNION ALL
    /* ⑤ 手工调整兜底：DOM+FAC 因子，接收方与源行同一业务管理单元 */
    SELECT P.COD_SCENARIO, P.COD_PERIODO, 'RS', '05', P.POOL_ID, SUBSTR('000000' || ROWNUM, -5), B.OID,
           B.COD_AZIENDA, B.COD_DEST2, B.COD_DEST3, B.COD_DEST4, B.D_SALE_DEPT, B.MATERIAL_CODE,
           P.AMT_T0, B.DOM_AMT + B.FAC_AMT, SYSDATE, SESSION_USER
      FROM BASE B
    INNER JOIN (SELECT COD_SCENARIO, COD_PERIODO, POOL_ID, SUM(AMT_T0) AS AMT_T0
                  FROM ZTAB_BSFT_BASE1
                 WHERE COD_SCENARIO = P_SCENARIO AND COD_PERIODO = P_PERIODO
                   AND COD_CATEGORIA = 'T0' AND SCENE = '05'
                 GROUP BY COD_SCENARIO, COD_PERIODO, POOL_ID) P
       ON P.POOL_ID = NVL(B.D_SALE_DEPT, 'ZZZZ')   /* ⑤ 池键用 D_SALE_DEPT 原值，不做点号剥离，与 T0 侧一致 */
     WHERE (B.DOM_AMT + B.FAC_AMT) <> 0;
    COMMIT;

    /* ----------------------------------------------------------------------
       S6  按池汇总分母
           USING 已按 SCENE+POOL_ID 收敛，每个池只有 1 行，不会 ORA-30926
       ---------------------------------------------------------------------- */
    MERGE INTO ZTAB_BSFT_BASE1 A
    USING (
      SELECT COD_SCENARIO, COD_PERIODO, SCENE, POOL_ID, SUM(FACTOR_AMT) AS FACTOR_SUM
        FROM ZTAB_BSFT_BASE1
       WHERE COD_SCENARIO = P_SCENARIO
         AND COD_PERIODO  = P_PERIODO
         AND COD_CATEGORIA = 'RS'
       GROUP BY COD_SCENARIO, COD_PERIODO, SCENE, POOL_ID
    ) B
    ON (A.COD_SCENARIO = B.COD_SCENARIO
    AND A.COD_PERIODO  = B.COD_PERIODO
    AND A.COD_CATEGORIA = 'RS'
    AND A.SCENE        = B.SCENE
    AND A.POOL_ID      = B.POOL_ID)
    WHEN MATCHED THEN UPDATE SET A.FACTOR_SUM = B.FACTOR_SUM;
    COMMIT;

    /* ----------------------------------------------------------------------
       S7  比例 + 分摊额
           DECODE 防除零；因子合计为 0 的池标 N（未分摊，金额留在 T0 不动）
       ---------------------------------------------------------------------- */
    UPDATE ZTAB_BSFT_BASE1
       SET RATE       = DECODE(NVL(FACTOR_SUM, 0), 0, 0, FACTOR_AMT / FACTOR_SUM),
           ALLOC_AMT  = DECODE(NVL(FACTOR_SUM, 0), 0, 0,
                               ROUND(FACTOR_AMT / FACTOR_SUM * AMT_T0, 2)),
           IS_SUCCESS = DECODE(NVL(FACTOR_SUM, 0), 0, 'N', 'Y')
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO  = P_PERIODO
       AND COD_CATEGORIA = 'RS';
    COMMIT;

    /* ----------------------------------------------------------------------
       S8  尾差配平
           ROUND(,2) 必然留 1 分钱级残差，不收敛则池内已摊<>待摊，
           PSI_COMB_COST 总额会漂。把差额挂到池内因子最大的那行
       ---------------------------------------------------------------------- */
    MERGE INTO ZTAB_BSFT_BASE1 A
    USING (
      SELECT SCENE, POOL_ID, NUM,
             SUM(ALLOC_AMT) OVER (PARTITION BY SCENE, POOL_ID) AS SUM_ALLOC,
             MAX(AMT_T0)    OVER (PARTITION BY SCENE, POOL_ID) AS SUM_T0,
             ROW_NUMBER()   OVER (PARTITION BY SCENE, POOL_ID
                                  ORDER BY FACTOR_AMT DESC NULLS LAST, NUM) AS RN
        FROM ZTAB_BSFT_BASE1
       WHERE COD_SCENARIO = P_SCENARIO
         AND COD_PERIODO  = P_PERIODO
         AND COD_CATEGORIA = 'RS'
         AND NVL(FACTOR_SUM, 0) <> 0
    ) B
    ON (A.COD_SCENARIO = P_SCENARIO
    AND A.COD_PERIODO  = P_PERIODO
    AND A.COD_CATEGORIA = 'RS'
    AND A.SCENE         = B.SCENE
    AND A.POOL_ID       = B.POOL_ID
    AND A.NUM           = B.NUM
    AND B.RN            = 1)
    WHEN MATCHED THEN UPDATE SET A.ALLOC_AMT = A.ALLOC_AMT + (B.SUM_T0 - B.SUM_ALLOC);
    COMMIT;

    /* ----------------------------------------------------------------------
       S9  按接收行 OID 汇总写回 OTH_ASSESS_COST
           多场景落到同一接收行的，在这里汇总后一次覆盖（需求注意事项 5）
           USING 按 OID 唯一，ON 带场景+期间，不会 ORA-30926
       ---------------------------------------------------------------------- */
    MERGE INTO AW_MR9_REVM05_000001_TEMP A
    USING (
      SELECT OID, SUM(ALLOC_AMT) AS ALLOC_AMT
        FROM ZTAB_BSFT_BASE1
       WHERE COD_SCENARIO = P_SCENARIO
         AND COD_PERIODO  = P_PERIODO
         AND COD_CATEGORIA = 'RS'
       GROUP BY OID
      HAVING SUM(ALLOC_AMT) <> 0
    ) B
    ON (A.COD_SCENARIO = P_SCENARIO
    AND A.COD_PERIODO  = P_PERIODO
    AND A.OID          = B.OID)
    WHEN MATCHED THEN UPDATE SET A.OTH_ASSESS_COST = B.ALLOC_AMT;
    COMMIT;

    /* ----------------------------------------------------------------------
       S10-4  场景④ 冲销原行（管法差）
              只在「已分摊」时冲：池 04 存在 RATE<>0 的接收方
              从 TEMP 取原始行，不拿池汇总行（池汇总丢了维度）
              成本字段取相反数，其他金额字段一律 0，维度同原行
              COD_CATEGORIA 继承原行（不写死 ZAMOUNT）：原行 ZAMOUNT/ZFAMOUNT 时冲销行
              经第 5 步归入 ENT_COST、原行 GA00_CON% 时归入 CADJ_COST，与原行同口径相抵

              未写入的字段（写 NULL）：D_BUS_SCE_S / STD_QTY / MA_SALE_COGS /
              SHIPPING_ORDER / ASSESS_NM_ALLOC_COST / ASSESS_MANG_* —— 这些字段
              后续由步骤 9（事业部/产销存打标）与考核成本段按 PROVENIENZA 重算，
              继承原值反而会和重算结果打架
       ---------------------------------------------------------------------- */
    INSERT INTO AW_MR9_REVM05_000001_TEMP
    (
      OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4,
      AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT,
      D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC,
      D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES,
      D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME,
      CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE,
      SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE,
      MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE,
      SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
      AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
      OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL,
      FAC_EXTERNAL_SALE_REVENUE,
      IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE,
      CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM,
      COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY,
      CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST,
      ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST,
      BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY,
      FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY,
      DOM_PSI_COST, FAC_EXTERNAL_SALE_COST, D_MINILED,
      D_EFF_CLASS, D_BU_SHOP, D_EC_STORE, D_UNICUSTGRP, D_BRANCH, D_CHANNEL_BU
    )
    SELECT NEWID(), T.COD_SCENARIO, T.COD_PERIODO, 'BSFT', 'S640100', T.COD_AZIENDA, T.COD_DEST2, T.COD_DEST3,
           NVL(T.COD_DEST4, 'ZZZZ'),
           T.AGENCY_CODE, T.AGENCY_NAME, T.CUST_CODE, T.CUST_NAME, T.D_SALE_DEPT,
           T.D_CHANNEL, T.D_MODE, T.D_ONOFFLINE, T.D_CNL_C_TYPE, T.D_IND_C_TYPE, T.D_ECOM_BU, T.D_MARKET_PNT,
           T.D_PRO_SSER, T.D_SPEC_SEC,
           T.D_PRO_TYPE_S, T.D_PRO_STAGE, T.D_PRI_RANGE, T.D_PRO_SERIES,
           T.D_TECH_TYPE, T.D_PRO_CLASS, T.D_MODEL_LCA, T.D_PRO_TYPE, T.D_PRC_GRP, T.D_POL_CLASS, T.CUST_UNITY_NAME,
           T.CREDIT_LEVEL_NAME,
           T.CUST_NATURE_NAME, T.CUST_TYPE_NAME, T.SOLD_TO_CODE,
           T.SOLD_TO_NAME, T.MATERIAL_CODE, T.MATERIAL_NAME, T.IS_MINILED_CODE, T.SALE_MODEL_CODE, T.SALE_MODEL_NAME,
           T.MODEL_CODE,
           T.MODEL_NAME, T.BATCH_ID, T.MATERIAL_GROUP_CODE, T.SHOP_CODE,
           T.SHOP_NAME, 0, 0, 0, 0, -1 * NVL(T.SALE_COGS, 0), 0, 0, 0,
           0, 0, 0, 0,
           0, 'CPM_SP_BSFT_M_T0', SESSION_USER, SYSDATE, 0, 0, T.COD_CATEGORIA, T.CUSTOMER_MODEL,  /* 冲销行类别继承原行，见版本记录 20261118 14:58 */
           0,
           0, T.COD_AZI_CTP, 0, T.D_DATA_BLOCK, T.D_DIFF_TYPE, T.D_ADJ_TYPE, T.CN_CLASS_MARK_CODE,
           T.CN_CLASS_MARK_NAME, T.SALE_CERT_TYPE, 0, 0, 0,
           T.COD_AZI_CTP_ORG, T.D_OPER_TYPE, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, T.NOTE, 0,
           0, 0, 0, 0, 0, T.COD_DEST1, 0,
           0, 0, T.D_MINILED,
           T.D_EFF_CLASS, T.D_BU_SHOP, T.D_EC_STORE, T.D_UNICUSTGRP, T.D_BRANCH, T.D_CHANNEL_BU
      FROM AW_MR9_REVM05_000001_TEMP T
     WHERE T.COD_SCENARIO = P_SCENARIO
       AND T.COD_PERIODO  = P_PERIODO
       AND T.COD_AZIENDA  IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                               WHERE SESSION_ID = V_SESSION_ID
                                 AND (ELEM LIKE '17%' OR ELEM = '6240'))
       AND NVL(T.SRC_DETAIL, '|') <> 'BSFT'
       AND NVL(T.SALE_COGS, 0) <> 0
       AND T.D_DIFF_TYPE IS NOT NULL
       AND T.D_DIFF_TYPE <> 'ZZZZ'
       AND T.MATERIAL_CODE IS NULL
       AND EXISTS (SELECT 1 FROM ZTAB_BSFT_BASE1 B
                    WHERE B.COD_SCENARIO = P_SCENARIO
                      AND B.COD_PERIODO  = P_PERIODO
                      AND B.COD_CATEGORIA = 'RS'
                      AND B.SCENE = '04'
                      AND NVL(B.RATE, 0) <> 0);
    COMMIT;

    /* ----------------------------------------------------------------------
       S10-5  场景⑤ 冲销原行（手工调整兜底）
              所在池（业务管理单元）已分摊才冲
              COD_CATEGORIA 继承原行：本段原行为 GA00_CON%，成本进 CADJ_COST，
              冲销行必须同类别才能相抵（写死 ZAMOUNT 会让原行 CADJ_COST 净不掉，合并成本变 2 倍）
       ---------------------------------------------------------------------- */
    INSERT INTO AW_MR9_REVM05_000001_TEMP
    (
      OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4,
      AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT,
      D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC,
      D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES,
      D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME,
      CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE,
      SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE,
      MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE,
      SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST,
      AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST,
      OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL,
      FAC_EXTERNAL_SALE_REVENUE,
      IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE,
      CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM,
      COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY,
      CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST,
      ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST,
      BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY,
      FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY,
      DOM_PSI_COST, FAC_EXTERNAL_SALE_COST, D_MINILED,
      D_EFF_CLASS, D_BU_SHOP, D_EC_STORE, D_UNICUSTGRP, D_BRANCH, D_CHANNEL_BU
    )
    SELECT NEWID(), T.COD_SCENARIO, T.COD_PERIODO, 'BSFT', 'S640100', T.COD_AZIENDA, T.COD_DEST2, T.COD_DEST3,
           NVL(T.COD_DEST4, 'ZZZZ'),
           T.AGENCY_CODE, T.AGENCY_NAME, T.CUST_CODE, T.CUST_NAME, T.D_SALE_DEPT,
           T.D_CHANNEL, T.D_MODE, T.D_ONOFFLINE, T.D_CNL_C_TYPE, T.D_IND_C_TYPE, T.D_ECOM_BU, T.D_MARKET_PNT,
           T.D_PRO_SSER, T.D_SPEC_SEC,
           T.D_PRO_TYPE_S, T.D_PRO_STAGE, T.D_PRI_RANGE, T.D_PRO_SERIES,
           T.D_TECH_TYPE, T.D_PRO_CLASS, T.D_MODEL_LCA, T.D_PRO_TYPE, T.D_PRC_GRP, T.D_POL_CLASS, T.CUST_UNITY_NAME,
           T.CREDIT_LEVEL_NAME,
           T.CUST_NATURE_NAME, T.CUST_TYPE_NAME, T.SOLD_TO_CODE,
           T.SOLD_TO_NAME, T.MATERIAL_CODE, T.MATERIAL_NAME, T.IS_MINILED_CODE, T.SALE_MODEL_CODE, T.SALE_MODEL_NAME,
           T.MODEL_CODE,
           T.MODEL_NAME, T.BATCH_ID, T.MATERIAL_GROUP_CODE, T.SHOP_CODE,
           T.SHOP_NAME, 0, 0, 0, 0, -1 * NVL(T.SALE_COGS, 0), 0, 0, 0,
           0, 0, 0, 0,
           0, 'CPM_SP_BSFT_M_T0', SESSION_USER, SYSDATE, 0, 0, T.COD_CATEGORIA, T.CUSTOMER_MODEL,  /* 冲销行类别继承原行，见版本记录 20261118 14:58 */
           0,
           0, T.COD_AZI_CTP, 0, T.D_DATA_BLOCK, T.D_DIFF_TYPE, T.D_ADJ_TYPE, T.CN_CLASS_MARK_CODE,
           T.CN_CLASS_MARK_NAME, T.SALE_CERT_TYPE, 0, 0, 0,
           T.COD_AZI_CTP_ORG, T.D_OPER_TYPE, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, T.NOTE, 0,
           0, 0, 0, 0, 0, T.COD_DEST1, 0,
           0, 0, T.D_MINILED,
           T.D_EFF_CLASS, T.D_BU_SHOP, T.D_EC_STORE, T.D_UNICUSTGRP, T.D_BRANCH, T.D_CHANNEL_BU
      FROM AW_MR9_REVM05_000001_TEMP T
     WHERE T.COD_SCENARIO = P_SCENARIO
       AND T.COD_PERIODO  = P_PERIODO
       AND T.COD_AZIENDA  IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                               WHERE SESSION_ID = V_SESSION_ID
                                 AND (ELEM LIKE '17%' OR ELEM = '6240'))
       AND NVL(T.SRC_DETAIL, '|') <> 'BSFT'
       AND NVL(T.SALE_COGS, 0) <> 0
       AND T.COD_CATEGORIA LIKE 'GA00_CON%'
       AND T.MATERIAL_CODE IS NULL
       AND NVL(T.D_DIFF_TYPE, 'ZZZZ') = 'ZZZZ'
       AND NOT EXISTS (SELECT 1 FROM ZTAB_BSFT_BASE1 H
                        WHERE H.COD_SCENARIO = P_SCENARIO
                          AND H.COD_PERIODO  = P_PERIODO
                          AND H.COD_CATEGORIA = 'MAP'
                          AND H.POOL_ID = CASE WHEN INSTR(T.D_SALE_DEPT, '.') > 0
                                               THEN SUBSTR(T.D_SALE_DEPT, INSTR(T.D_SALE_DEPT, '.') + 1)
                                               ELSE NVL(T.D_SALE_DEPT, 'ZZZZ') END)
       AND EXISTS (SELECT 1 FROM ZTAB_BSFT_BASE1 B
                    WHERE B.COD_SCENARIO = P_SCENARIO
                      AND B.COD_PERIODO  = P_PERIODO
                      AND B.COD_CATEGORIA = 'RS'
                      AND B.SCENE = '05'
                      AND B.POOL_ID = NVL(T.D_SALE_DEPT, 'ZZZZ')
                      AND NVL(B.RATE, 0) <> 0);
    COMMIT;

    /* ----------------------------------------------------------------------
       S11  未分摊告警 + 结束日志
            因子合计为 0 的池，金额静默留在 T0（需求：未分摊不冲销，
            金额停在此处，靠这条日志和对账 SQL 暴露）
       ---------------------------------------------------------------------- */
    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK, COD_AZIENDA)
    SELECT 'CPM_SP_M2M_REV_M', '3  BSFT告警：池未分摊', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO,
           'SCENE=' || A.SCENE || ' POOL=' || A.POOL_ID || ' 待分摊金额=' || TO_CHAR(A.AMT_T0), P_AZIENDA
      FROM (SELECT SCENE, POOL_ID, SUM(AMT_T0) AS AMT_T0
              FROM ZTAB_BSFT_BASE1
             WHERE COD_SCENARIO = P_SCENARIO AND COD_PERIODO = P_PERIODO
               AND COD_CATEGORIA = 'T0'
             GROUP BY SCENE, POOL_ID) A
     WHERE A.AMT_T0 <> 0
       AND NOT EXISTS (SELECT 1 FROM ZTAB_BSFT_BASE1 B
                        WHERE B.COD_SCENARIO = P_SCENARIO AND B.COD_PERIODO = P_PERIODO
                          AND B.COD_CATEGORIA = 'RS'
                          AND B.SCENE = A.SCENE AND B.POOL_ID = A.POOL_ID
                          AND NVL(B.FACTOR_SUM, 0) <> 0);

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK, COD_AZIENDA)
    SELECT 'CPM_SP_M2M_REV_M', '3  日立合并层成本分摊（BSFT）结束', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO,
           'T0待摊=' || TO_CHAR(NVL(SUM(CASE WHEN COD_CATEGORIA = 'T0' THEN AMT_T0 END), 0)) ||
           ' 已摊='   || TO_CHAR(NVL(SUM(CASE WHEN COD_CATEGORIA = 'RS' THEN ALLOC_AMT END), 0)) ||
           ' 差额='   || TO_CHAR(NVL(SUM(CASE WHEN COD_CATEGORIA = 'T0' THEN AMT_T0 END), 0)
                              - NVL(SUM(CASE WHEN COD_CATEGORIA = 'RS' THEN ALLOC_AMT END), 0)),
           P_AZIENDA
      FROM ZTAB_BSFT_BASE1
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO  = P_PERIODO;
    COMMIT;

END IF;

/*除日立以外*/
  UPDATE AW_MR9_REVM05_000001_TEMP
     SET DOM_PSI_COST = NVL(ORG_QTY, 0) * NVL(WTD_UNIT_COST, 0)
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                          WHERE SESSION_ID = V_SESSION_ID
                            AND NOT (ELEM LIKE '17%' OR ELEM = '6240')
                        )
     AND COD_DEST3 IN (SELECT ELEM
                         FROM SESSION_V_REF_DEST3_NONAME
                        WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01'
                          AND NODE = 'HN')
     AND PROVENIENZA = 'CPM_SP_M2M_REV_M'
  ;
 COMMIT;
  ------------------------------------------------------------------------------
  -- 4  插入无物料总账成本分摊数据及小B国补, OTH_ASSESS_COST, FAC_CADJ_REV, CN_CADJ_REV
  ------------------------------------------------------------------------------

--edit by lc 260207 分事业部跑
IF V_ENTITY = 'BX' THEN
   CPM_SP_M2M_ZZFT_M(P_SCENARIO,P_PERIODO,'6700',SESSION_USER);
END IF
;

IF V_ENTITY = 'KT' THEN
   CPM_SP_M2M_ZZFT_M(P_SCENARIO,P_PERIODO,'6800',SESSION_USER);
END IF
;

IF V_ENTITY = 'SX' THEN
   CPM_SP_M2M_ZZFT_M(P_SCENARIO,P_PERIODO,'2000',SESSION_USER);
END IF
;

IF V_ENTITY = 'ALL' THEN
   CPM_SP_M2M_ZZFT_M(P_SCENARIO,P_PERIODO,'ALL',SESSION_USER);
END IF
;

  UPDATE AW_MR9_REVM05_000001_TEMP
     SET PSI_COMB_COST = NVL(DOM_PSI_COST, 0) + NVL(OTH_ASSESS_COST, 0)
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                                    )
    --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
        /*20260226 新增排除锁定公司*/
     /* AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
  ;

    INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '4  插入无物料总账成本分摊数据', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '4.1  插入无物料总账成本分摊数据',P_AZIENDA);

    COMMIT;
/* 临时处理 视像分摊总账数据的  单体字段  分摊没有考虑手工调整，回写 先处理视像*/
UPDATE AW_MR9_REVM05_000001_TEMP t
   SET ENT_COST = NVL(SALE_COGS, 0)
 WHERE COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                           AND ELEM IN (SELECT COD_AZIENDA
                                     FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                                    WHERE COD_BG = 'BG001_BU001')
                       )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
   /* AND COD_AZIENDA IN (SELECT COD_AZIENDA
                         FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                        WHERE COD_BG = 'BG001_BU001') */
   AND PROVENIENZA = 'CPM_SP_ZZFT_M_T0'
      /*20260226 新增排除锁定公司*/
   /* AND COD_AZIENDA NOT IN
       (SELECT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001 T
         WHERE REV05_FLAG = 'Y'
           AND T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO = P_PERIODO
           AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
           ;

  ------------------------------------------------------------------------------
  -- 5  计算单体原始数据、单体调整数据、合并调整数据, ENT, ENT_ADJ, CADJ FOR QTY, REV, COST
  ------------------------------------------------------------------------------

  UPDATE AW_MR9_REVM05_000001_TEMP
     SET ENT_QTY = CASE
                     WHEN COD_CATEGORIA IN ('ZAMOUNT', 'ZFAMOUNT') THEN
                      NVL(MAP_QTY, 0)
                     ELSE
                      0
                   END,
         ENT_QTY_ADJ = CASE
                         WHEN COD_CATEGORIA IN
                              ('GA00_DI_IN',
                               'GA00_DI_OUT',
                               'GA00_BF',
                               'GA00_REV_KH',
                               'GA00_PA_IN',
                               'GA00_PA_OUT') THEN
                          NVL(MAP_QTY, 0)
                         ELSE
                          0
                       END,
         CADJ_QTY = CASE
                      WHEN COD_CATEGORIA LIKE 'GA00_CON%' THEN
                       NVL(MAP_QTY, 0)
                      ELSE
                       0
                    END,
         ENT_REV = CASE
                     WHEN COD_AZIENDA = '2023' AND COD_CONTO = 'S600111' AND
                          COD_CATEGORIA IN ('ZAMOUNT', 'ZFAMOUNT') THEN
                      NVL(ORG_REV, 0)
                     WHEN COD_CATEGORIA IN ('ZAMOUNT', 'ZFAMOUNT') THEN
                      NVL(ORG_REV, 0)
                     ELSE
                      0
                   END,
         ENT_REV_ADJ = CASE
                         WHEN COD_AZIENDA = '2023' AND COD_CONTO = 'S600111' AND
                              COD_CATEGORIA IN
                              ('GA00_DI_IN',
                               'GA00_DI_OUT',
                               'GA00_BF',
                               'GA00_REV_KH',
                               'GA00_AF',
                               'GA00_PA_IN',
                               'GA00_PA_OUT') THEN
                          NVL(ORG_REV, 0)
                         WHEN COD_CATEGORIA IN
                              ('GA00_DI_IN',
                               'GA00_DI_OUT',
                               'GA00_BF',
                               'GA00_REV_KH',
                               'GA00_AF',
                               'GA00_PA_IN',
                               'GA00_PA_OUT') THEN
                          NVL(ORG_REV, 0)
                         ELSE
                          0
                       END,
         CADJ_REV = CASE
                      WHEN COD_CATEGORIA LIKE 'GA00_CON%' THEN
                       NVL(ORG_REV, 0)
                      ELSE
                       0
                    END,
         ENT_COST = CASE
                      WHEN COD_CATEGORIA IN ('ZAMOUNT', 'ZFAMOUNT') THEN
                       NVL(SALE_COGS, 0)
                      ELSE
                       0
                    END,
         ENT_COST_ADJ = CASE
                          WHEN COD_CATEGORIA IN
                               ('GA00_DI_IN',
                                'GA00_DI_OUT',
                                'GA00_BF',
                                'GA00_REV_KH',
                                'GA00_AF',
                                'GA00_PA_IN',
                                'GA00_PA_OUT','GA00_ALC_CN') THEN
                           NVL(SALE_COGS, 0)
                          ELSE
                           0
                        END,
         CADJ_COST = CASE
                       WHEN COD_CATEGORIA LIKE 'GA00_CON%' THEN
                        NVL(SALE_COGS, 0)
                       ELSE
                        0
                     END
   WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                       )
    --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
        --对于收入直接调整数据也要做相同逻辑处理
     AND PROVENIENZA IN
         ('CPM_SP_M2M_REV_M', 'INPUT_DEFORM', 'CPM_SP_ZZFT_M_T0', 'CPM_SP_BSFT_M_T0')  /* ALTER BY LIYIFAN1.EX 20261116 16:24:00 步骤5：日立分摊冲销行参与 ENT/CADJ 计算 */
        --排除返利价差科目余额, 不进入到管理口径，被政策分摊和政策兑现数据替换
     AND (COD_CONTO NOT IN ('S600111') OR COD_AZIENDA = '2023')
        /*20260226 新增排除锁定公司*/
     /* AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
  ---AND SRC_DETAIL='VBRP'
  ;

  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '5  计算单体原始数据、单体调整数据、合并调整数据', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '5  计算单体原始数据、单体调整数据、合并调整数据',P_AZIENDA);
    COMMIT;


--20260206 新增手工调整数据客商信息和物料信息补充更新
MERGE /*+ USE_HASH(T C) */INTO AW_MR9_REVM05_000001_TEMP T
USING (
SELECT distinct CASE
                  WHEN nvl(aw.D_MARKET_PNT, '|') = '|' OR
                       aw.D_MARKET_PNT = 'ZZZZ' THEN
                   MARA.market_pos_code
                  ELSE
                   aw.D_MARKET_PNT
                END AS D_MARKET_PNT -- 营销定位编码
               ,
                CASE
                  WHEN nvl(aw.D_CNL_C_TYPE, '|') = '|' OR
                       aw.D_CNL_C_TYPE = 'ZZZZ' THEN
                   CUST_INFO.channel_small_class_code
                  ELSE
                   aw.D_CNL_C_TYPE
                END AS D_CNL_C_TYPE -- 渠道客户小类编码
               ,
                CASE
                  WHEN nvl(AW.D_CHANNEL, '|') = '|' OR AW.D_CHANNEL = 'ZZZZ' THEN
                   CUST_INFO.com_3rd_code
                  ELSE
                   AW.D_CHANNEL
                END AS D_CHANNEL -- 销售渠道三级编码
               ,
                CASE
                  WHEN nvl(aw.D_PRO_CLASS, '|') = '|' OR
                       aw.D_PRO_CLASS = 'ZZZZ' THEN
                   MARA.small_class_code
                  ELSE
                   aw.D_PRO_CLASS
                END AS D_PRO_CLASS -- 产品小类编码
               ,
                CASE
                  WHEN nvl(aw.MATERIAL_GROUP_CODE, '|') = '|' OR
                       aw.MATERIAL_GROUP_CODE = 'ZZZZ' THEN
                   CASE
                     WHEN AZ.SAP_VERSION IN ('S600', 'S900') THEN
                      REPLACE(REPLACE(REPLACE(mara.prod_line, 'BP', ''),
                                      'DS',
                                      ''),
                              'TA',
                              '')
                     ELSE
                      LTRIM(mara.matkl, '0')
                   END
                  ELSE
                   aw.MATERIAL_GROUP_CODE --物料组编码
                END AS MATERIAL_GROUP_CODE,
                CASE
                  WHEN nvl(aw.model_code, '|') = '|' OR
                       aw.model_code = 'ZZZZ' THEN
                   MARA.model_code
                  ELSE
                   aw.model_code
                END AS model_code -- 产品型号
               ,
                CASE
                  WHEN nvl(aw.COD_AZI_CTP, '|') = '|' OR
                       aw.COD_AZI_CTP = 'ZZZZ' THEN
                   CTP.COD_AZI_CTP
                  ELSE
                   aw.COD_AZI_CTP
                END AS COD_AZI_CTP,
                AW.OID


        --20260920FJF_ADD 二期新增字段
      , CASE WHEN nvl(aw.D_EFF_CLASS,'|') = '|' OR aw.D_EFF_CLASS = 'ZZZZ' OR MARA.ee_level_code <> aw.D_EFF_CLASS
           THEN NVL(MARA.ee_level_code,'ZZZZ')
           ELSE NVL(aw.D_EFF_CLASS,'ZZZZ')
        END AS D_EFF_CLASS
      , CASE WHEN nvl(aw.D_BU_SHOP,'|') = '|' OR aw.D_BU_SHOP = 'ZZZZ' OR CUST_INFO.bu_code <> aw.D_BU_SHOP
           THEN NVL(CUST_INFO.bu_code,'ZZZZ')
           ELSE NVL(aw.D_BU_SHOP,'ZZZZ')
        END AS D_BU_SHOP

       , CASE WHEN nvl(aw.D_UNICUSTGRP,'|') = '|' OR aw.D_UNICUSTGRP = 'ZZZZ' OR CUST_INFO.cust_unity_code <> aw.D_UNICUSTGRP
           THEN NVL(CUST_INFO.cust_unity_code,'ZZZZ')
           ELSE NVL(aw.D_UNICUSTGRP,'ZZZZ')
        END AS D_UNICUSTGRP
  FROM (SELECT OID,
               COD_AZI_CTP,
               model_code,
               MATERIAL_GROUP_CODE,
               D_PRO_CLASS,
               D_CHANNEL,
               D_MARKET_PNT,
               D_CNL_C_TYPE,
               COD_AZIENDA,
               CUST_CODE,
               MATERIAL_CODE
         --20260920FJF_ADD 二期新增字段
        ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
          FROM AW_MR9_REVM05_000001_TEMP
         WHERE COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO = P_PERIODO
           AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0', 'CPM_SP_BSFT_M_T0')  /* ALTER BY LIYIFAN1.EX 20261116 16:24:00 维度回刷补日立分摊来源 */
              /*20260226 新增排除锁定公司*/
           /* AND COD_AZIENDA NOT IN
               (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
           AND SRC_DETAIL = 'HB_ADJM01') AW
  LEFT JOIN (SELECT COD_AZIENDA, 'S' || CITTA_LEGALE SAP_VERSION
               FROM TGK_FIMA_HISENSE.AZIENDA) AZ
    ON AW.COD_AZIENDA = AZ.COD_AZIENDA
  LEFT JOIN (SELECT 'S' || MANDT AS SAP_VERSION, KUNNR, zkunnr_mdg, name1
               FROM TGK_FIMA_HISENSE.DS_DWD_SAP_KNA1) KNA1
    ON AZ.SAP_VERSION = KNA1.SAP_VERSION
   AND LTRIM(KNA1.kunnr, '0') = AW.CUST_CODE
  LEFT JOIN TGK_FIMA_HISENSE.DIM_CUSTOMER_BASE_INFO_DD CUST_INFO
    ON LTRIM(KNA1.zkunnr_mdg, '0') = LTRIM(CUST_INFO.cust_code, '0')
  LEFT JOIN TGK_FIMA_HISENSE.DIM_FI_PRODUCT MARA
    ON MARA.matnr = AW.MATERIAL_CODE
  LEFT JOIN (SELECT cust_code       AS kunrg,
                    cp_company_code AS COD_AZI_CTP,
                    system_src      AS system_src
               FROM TGK_FIMA_HISENSE.dim_rule_fi_mr_cust2ctp_mapping a
              WHERE cust_type_code = 'C'
                AND NVL(valid_fr, '202401') <=
                    SUBSTR(P_SCENARIO, 0, 4) || P_PERIODO
                AND NVL(valid_to, '999999') >=
                    SUBSTR(P_SCENARIO, 0, 4) || P_PERIODO) CTP
    ON CTP.kunrg = AW.CUST_CODE
   AND CTP.system_src = AZ.SAP_VERSION
) C
ON(
   T.OID = C.OID
)
WHEN MATCHED THEN
UPDATE SET  T.D_MARKET_PNT = C.D_MARKET_PNT
      , T.D_CNL_C_TYPE = C.D_CNL_C_TYPE
      , T.D_CHANNEL = C.D_CHANNEL
      , T.D_PRO_CLASS = C.D_PRO_CLASS
      , T.MATERIAL_GROUP_CODE = C.MATERIAL_GROUP_CODE
      , T.model_code = C.model_code
      , T.COD_AZI_CTP = C.COD_AZI_CTP
    --20260920FJF_ADD 二期新增字段
      , T.D_EFF_CLASS = C.D_EFF_CLASS --能效等级
      , T.D_BU_SHOP = C.D_BU_SHOP --门店所属BU
      , T.D_UNICUSTGRP = C.D_UNICUSTGRP --统一客户组编码
      ;
  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '手工调整数据客商信息和物料信息补充更新完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;


/*插入抵消数据之前将政策兑现字段更新成0
20260626SXX补充逻辑：
如果本方对方同时在事业部对应账套配置表【AW_RUL_ATSMAP_000001】的视像、冰箱、空调、中国区的公司范围里，则该字段放0
视像：BG001_BU001、BG002_BU001
冰箱：BG004_BU001、BG005_BU001
空调：BG003_BU011
中国区：BG012_BU

注意：
①如果是视像范围，需要是本方对方同事在视像范围里才把这个字段放0
②注意要考虑开始时间跟结束时间
*/

UPDATE AW_MR9_REVM05_000001_TEMP A
SET POLICY_CASH_PD = 0
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
  AND (
        (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG001_BU001','BG002_BU001')
                           AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')

                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG001_BU001','BG002_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )

      )
  ;
  --EDIT BY CHENDONG3.EX 260817 将中国区费用转政策的业务在产品公司还原的部分，对方公司置为空，以确保后续不参与抵消
--20260831 shiqingfeng.ex 月结不上线
--20260908 10：33 开放 20260817-2 CHENDONG3.ex  将中国区费用转政策的业务在产品公司还原的部分，对方公司置为空，以确保后续不参与抵消，开始测试
--20261016 LIYIFAN1.EX 新增业务分类OPTY060、OPTY061

UPDATE AW_MR9_REVM05_000001_TEMP T
SET COD_AZI_CTP_ORG= '',
    COD_AZI_CTP= ''
WHERE ((D_OPER_TYPE IN ('OPTY039','OPTY040') AND D_ADJ_TYPE = 'REV_01_221')
      /*ALTER BY LICHENG.EX 20261030 19:17 OPTY061 取消对方公司置空，仅 OPTY060 置空；恢复时把 'OPTY061' 加回 IN 列表*/
      OR D_OPER_TYPE IN ('OPTY060')
      /* 20261026 21:42 LICHENG.EX REV005_STEP_2-3 产出的研发费用品类间调整行，对方公司一并置空，不参与抵消 */
      OR (SRC_DETAIL = 'REVM05' AND D_ADJ_TYPE = 'REV_01_229'))
     AND COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
     AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0', 'CPM_SP_BSFT_M_T0')  /* ALTER BY LIYIFAN1.EX 20261116 16:24:00 对方公司置空补日立分摊来源 */
     ;
  ------------------------------------------------------------------------------
  --插入抵消数据-根据有CTP的收入, 未实现不能复制, ELIM_QTY, ELIM_REV, ELIM_COST, CN_ELIM_QTY, CN_ELIM_REV, CN_ELIM_COST
  ------------------------------------------------------------------------------

INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_AZI_CTP, COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST1, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS, D_ADJ_TYPE,
    PROVENIENZA,DATEUPD, USERUPD,
    CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,
    CUSTOMER_MODEL,
    ELIM_QTY, ELIM_REV, ELIM_COST,
    CN_ELIM_QTY, CN_ELIM_REV
  ,D_MINILED
  ,ORG_QTY --原始销量
  ,MAP_QTY --数量(处理后)
  ,BILL_QTY --开票销量（日立用）
  ,STD_QTY,d_oper_type
    )
WITH CN_AZI AS (
    -- 中国区公司集合（等同于 V_CN_AZIENDA 的 LISTAGG 来源）
    SELECT COD_AZIENDA
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
     WHERE COD_BG = 'BG012'
       AND COD_AZIENDA <> '1183'
),
NODE_200 AS
(
SELECT NODE,ELEM FROM SESSION_V_REF_AZIENDA S
 WHERE SESSION_ID = V_SESSION_ID AND S.HIE = '10' AND S.NODE = '200'
)
  SELECT NEWID() AS OID,
         COD_SCENARIO,
         COD_PERIODO,
         'ELIM' AS SRC_DETAIL,
         COD_CONTO,
         M.COD_AZIENDA,
         COD_AZI_CTP_ORG AS COD_AZI_CTP,
         COD_AZI_CTP_ORG,
         'GA00_ELIM' AS COD_CATEGORIA,
         AGENCY_CODE,
         AGENCY_NAME,
         CUST_CODE,
         CUST_NAME,
         D_CHANNEL,
         D_MODE,
         D_ONOFFLINE,
         D_CNL_C_TYPE,
         D_IND_C_TYPE,
         D_ECOM_BU,
         CUST_UNITY_NAME,
         CREDIT_LEVEL_NAME,
         CUST_NATURE_NAME,
         CUST_TYPE_NAME,
         SOLD_TO_CODE,
         SOLD_TO_NAME,
         COD_DEST3,
         D_SALE_DEPT,
         D_DATA_BLOCK,
         D_DIFF_TYPE,
         MATERIAL_CODE,
         MATERIAL_NAME,
         COD_DEST1,
         COD_DEST2,
         COD_DEST4,
         D_MARKET_PNT,
         D_PRO_SSER,
         D_SPEC_SEC,
         D_PRO_TYPE_S,
         D_PRO_STAGE,
         D_PRI_RANGE,
         D_PRO_SERIES,
         D_TECH_TYPE,
         IS_MINILED_CODE,
         D_PRO_CLASS,
         D_MODEL_LCA,
         D_PRO_TYPE,
         SALE_MODEL_CODE,
         SALE_MODEL_NAME,
         MODEL_CODE,
         MODEL_NAME,
         BATCH_ID,
         D_PRC_GRP,
         MATERIAL_GROUP_CODE,
         SHOP_CODE,
         SHOP_NAME,
         D_POL_CLASS,
         D_ADJ_TYPE,
         PROVENIENZA,
         DATEUPD,
         USERUPD,
         M.CN_CLASS_MARK_CODE,
         M.CN_CLASS_MARK_NAME,
         M.SALE_CERT_TYPE,
         M.CUSTOMER_MODEL,
         -1 * (NVL(ENT_QTY, 0) + NVL(ENT_QTY_ADJ, 0) + NVL(CADJ_QTY, 0)) AS ELIM_QTY,
         -1 * (NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) -
         NVL(POLICY_CASH_PD, 0) + NVL(CADJ_REV, 0)) AS ELIM_REV,
         CASE
           /*20260810-1 shiqingfeng.ex 对方公司是中国区公司，不生成成本抵消数*/
           /*20260831 shiqingfeng.ex 月结不上取消逻辑*/
           /*
             20260908 10：38 开放 20260810-1 shiqingfeng.ex 对方公司是中国区公司，不生成成本抵消数，开始测试
           */
           --20260929 中国区事业部成本9月不上线
           /*WHEN NODE_200.ELEM IS NOT NULL
             THEN 0*/
           WHEN CN_SELL.COD_AZIENDA IS NOT NULL AND
                CN_BUY.COD_AZIENDA IS NOT NULL THEN
            0
           ELSE
            NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) +
            NVL(CADJ_REV, 0) - NVL(POLICY_CASH_PD, 0)
         END AS ELIM_COST,
         CASE
           WHEN CN_SELL.COD_AZIENDA IS NOT NULL AND
                CN_BUY.COD_AZIENDA IS NOT NULL THEN
            -1 * NVL(CN_MAP_ZUM, 0)
           ELSE
            0
         END AS CN_ELIM_QTY,
         CASE
           WHEN CN_SELL.COD_AZIENDA IS NOT NULL AND
                CN_BUY.COD_AZIENDA IS NOT NULL THEN
            -1 * (NVL(CN_ORG_REV, 0) + NVL(POLICY_AMT, 0) -
            NVL(POLICY_CASH_PD, 0))
           ELSE
            0
         END AS CN_ELIM_REV,
         D_MINILED,
         -1 * NVL(ORG_QTY, 0) AS ORG_QTY --原始销量
        ,
         -1 * NVL(MAP_QTY, 0) AS MAP_QTY --数量(处理后)
        ,
         -1 * NVL(BILL_QTY, 0) AS BILL_QTY --开票销量（日立用）
        ,-1 * NVL(STD_QTY, 0) AS STD_QTY
        ,d_oper_type
    FROM AW_MR9_REVM05_000001_TEMP M
    LEFT JOIN CN_AZI CN_SELL ON CN_SELL.COD_AZIENDA = M.COD_AZIENDA
    LEFT JOIN CN_AZI CN_BUY  ON CN_BUY.COD_AZIENDA  = M.COD_AZI_CTP_ORG
    LEFT JOIN NODE_200 ON NODE_200.ELEM  = M.COD_AZI_CTP_ORG
   WHERE 1 = 1
     AND M.COD_SCENARIO = P_SCENARIO
     AND M.COD_PERIODO = P_PERIODO
     AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
     --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND M.COD_AZI_CTP_ORG IS NOT NULL
     AND EXISTS (
         SELECT 1 FROM SESSION_V_REF_AZIENDA S
          WHERE SESSION_ID = V_SESSION_ID AND S.HIE = '10' AND S.ELEM <> 'Z001' AND S.ELEM = M.COD_AZI_CTP_ORG
     )
     AND M.SRC_DETAIL <> 'ZTAB_IM_ZB'
     AND M.COD_CONTO LIKE 'S6001%'
     AND M.PROVENIENZA <> 'INPUT_DEFORM'
     /*
     20260907 修改人 shiqingfeng.ex 去掉所有锁定表限制，仅保留最上面参数session表限制
     AND NOT EXISTS (
         SELECT 1 FROM AW_RUL_DWMCRS_000001 T
          WHERE T.REV05_FLAG = 'Y'
            AND T.COD_SCENARIO = P_SCENARIO
            AND T.COD_PERIODO = P_PERIODO
            AND T.COD_CONTO = 'ZAW_D2M_LOCK'
            AND T.COD_AZIENDA = M.COD_AZIENDA
     )*/
     /* AND NOT
          (EXISTS (
              SELECT 1 FROM tgk_gb_hisense.FORM_DIZIONARIO_ELEMENTO t
               WHERE t.COD_ELEDIZ = NVL(M.MATERIAL_CODE, '|')
                 AND t.COD_DIZIONARIO = 'LIST_ZHEKOU_MM'
                 AND t.ATTRIBUTO1_ELEDIZ = '600'
          )
          AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZIENDA
          )
          AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZI_CTP_ORG
          )) */
         ;


DELETE FROM AW_MR9_REVM05_000001_TEMP M
 WHERE COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
   AND SRC_DETAIL = 'ELIM'
   AND (EXISTS (
              SELECT 1 FROM tgk_gb_hisense.FORM_DIZIONARIO_ELEMENTO t
               WHERE t.COD_ELEDIZ = NVL(M.MATERIAL_CODE, '|')
                 AND t.COD_DIZIONARIO = 'LIST_ZHEKOU_MM'
                 AND t.ATTRIBUTO1_ELEDIZ = '600'
          )
          AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZIENDA
          )
          AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZI_CTP_ORG
          )
         )
 ;


  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'STEP_6  插入抵消数据-根据有CTP的收入, 未实现不能复制完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

/* 20260406 zhuangxinzhou 视像ZK01兑现抵消逻辑 与中国区逻辑不一致 尚未拉通，单独设置
            中国区逻辑3月变化，视像与原逻辑保持一致
 POLICY_CASH_PD */
  INSERT /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_AZI_CTP, COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST1, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,   D_ADJ_TYPE,
    PROVENIENZA,DATEUPD, USERUPD,
    CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,
    CUSTOMER_MODEL,
    ELIM_QTY, ELIM_REV, ELIM_COST,
    CN_ELIM_QTY, CN_ELIM_REV, CN_ELIM_COST
  ,D_MINILED
  ,ORG_QTY --原始销量
  ,MAP_QTY --数量(处理后)
  ,BILL_QTY --开票销量（日立用）
  ,STD_QTY
    )
  SELECT NEWID() AS OID,
         COD_SCENARIO,
         COD_PERIODO,
         'ELIM' AS SRC_DETAIL,
         COD_CONTO,
         COD_AZIENDA,
         COD_AZI_CTP_ORG AS COD_AZI_CTP,
         COD_AZI_CTP_ORG,
         'GA00_ELIM' AS COD_CATEGORIA,
         AGENCY_CODE,
         AGENCY_NAME,
         CUST_CODE,
         CUST_NAME,
         D_CHANNEL,
         D_MODE,
         D_ONOFFLINE,
         D_CNL_C_TYPE,
         D_IND_C_TYPE,
         D_ECOM_BU,
         CUST_UNITY_NAME,
         CREDIT_LEVEL_NAME,
         CUST_NATURE_NAME,
         CUST_TYPE_NAME,
         SOLD_TO_CODE,
         SOLD_TO_NAME,
         COD_DEST3,
         D_SALE_DEPT,
         D_DATA_BLOCK,
         D_DIFF_TYPE,
         MATERIAL_CODE,
         MATERIAL_NAME,
         COD_DEST1,
         COD_DEST2,
         COD_DEST4,
         D_MARKET_PNT,
         D_PRO_SSER,
         D_SPEC_SEC,
         D_PRO_TYPE_S,
         D_PRO_STAGE,
         D_PRI_RANGE,
         D_PRO_SERIES,
         D_TECH_TYPE,
         IS_MINILED_CODE,
         D_PRO_CLASS,
         D_MODEL_LCA,
         D_PRO_TYPE,
         SALE_MODEL_CODE,
         SALE_MODEL_NAME,
         MODEL_CODE,
         MODEL_NAME,
         BATCH_ID,
         D_PRC_GRP,
         MATERIAL_GROUP_CODE,
         SHOP_CODE,
         SHOP_NAME,
         D_POL_CLASS,
         D_ADJ_TYPE,
         PROVENIENZA,
         DATEUPD,
         USERUPD,
         M.CN_CLASS_MARK_CODE,
         M.CN_CLASS_MARK_NAME,
         M.SALE_CERT_TYPE,
         M.CUSTOMER_MODEL,
         -1 * (NVL(ENT_QTY, 0) + NVL(ENT_QTY_ADJ, 0) + NVL(CADJ_QTY, 0)) AS ELIM_QTY,
         -1 * (NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) -
         NVL(POLICY_CASH_PD, 0) + NVL(CADJ_REV, 0)) AS ELIM_REV,
         NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) +
         NVL(CADJ_REV, 0) /*-NVL(POLICY_CASH_PD,0)*/ AS ELIM_COST,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            -1 * NVL(CN_MAP_ZUM, 0)
           ELSE
            0
         END AS CN_ELIM_QTY,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            -1 * (NVL(CN_ORG_REV, 0) + NVL(POLICY_AMT, 0) -
            NVL(POLICY_CASH_PD, 0))
           ELSE
            0
         END AS CN_ELIM_REV,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            NVL(CN_ORG_REV, 0) + NVL(POLICY_AMT, 0) - NVL(POLICY_CASH_PD, 0)
           ELSE
            0
         END AS CN_ELIM_COST,
         D_MINILED,
         -1 * NVL(ORG_QTY, 0) AS ORG_QTY --原始销量
        ,
         -1 * NVL(MAP_QTY, 0) AS MAP_QTY --数量(处理后)
        ,
         -1 * NVL(BILL_QTY, 0) AS BILL_QTY --开票销量（日立用）
        ,-1 * NVL(STD_QTY, 0) AS STD_QTY
    FROM AW_MR9_REVM05_000001_TEMP M
   WHERE 1 = 1
     AND M.COD_SCENARIO = P_SCENARIO
     AND M.COD_PERIODO = P_PERIODO
     AND M.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
     --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     --AND M.COD_AZI_CTP_ORG IS NOT NULL
     AND M.COD_AZI_CTP_ORG IN
         (SELECT ELEM FROM SESSION_V_REF_AZIENDA WHERE HIE = '10' AND SESSION_ID = V_SESSION_ID)
     AND COD_AZI_CTP_ORG NOT IN ('Z001')
     AND
        --国际营销提供抵消后结果
         M.SRC_DETAIL <> 'ZTAB_IM_ZB'
     --AND (M.COD_CONTO LIKE 'S6001%' OR M.COD_CONTO LIKE 'S6001G%')
     AND M.COD_CONTO LIKE 'S6001%'
     AND M.PROVENIENZA <> 'INPUT_DEFORM'
     /*AND NOT EXISTS (
         SELECT 1 FROM AW_RUL_DWMCRS_000001 T
          WHERE T.REV05_FLAG = 'Y'
            AND T.COD_SCENARIO = P_SCENARIO
            AND T.COD_PERIODO = P_PERIODO
            AND T.COD_CONTO = 'ZAW_D2M_LOCK'
            AND T.COD_AZIENDA = M.COD_AZIENDA
     )*/
     AND EXISTS (
              SELECT 1 FROM tgk_gb_hisense.FORM_DIZIONARIO_ELEMENTO t
               WHERE t.COD_ELEDIZ = NVL(M.MATERIAL_CODE, '|')
                 AND t.COD_DIZIONARIO = 'LIST_ZHEKOU_MM'
                 AND t.ATTRIBUTO1_ELEDIZ = '600'
          )
     AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZIENDA
          )
     AND EXISTS (
              SELECT 1 FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A
               WHERE A.COD_BG = 'BG001_BU001'
                 AND A.COD_AZIENDA = M.COD_AZI_CTP_ORG
          )
         ;


     /*
        \*20260226 新增排除锁定公司*\
     AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK')
     AND (NVL(MATERIAL_CODE, '|') IN
         (SELECT COD_ELEDIZ
             FROM tgk_gb_hisense.FORM_DIZIONARIO_ELEMENTO t
            WHERE COD_DIZIONARIO = 'LIST_ZHEKOU_MM'
              AND ATTRIBUTO1_ELEDIZ = '600') AND
         COD_AZIENDA IN (SELECT COD_AZIENDA
                            FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                           WHERE COD_BG = 'BG001_BU001') AND
         cod_azi_ctp_org IN
         (SELECT COD_AZIENDA
             FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
            WHERE COD_BG = 'BG001_BU001'))
         ;*/
  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '中国区逻辑3月变化，视像与原逻辑保持一致', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

IF P_SCENARIO='2026ACT' AND P_PERIODO='01' THEN
INSERT INTO AW_MR9_REVM05_000001_TEMP(
        OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_AZI_CTP, COD_AZI_CTP_ORG,
        COD_CATEGORIA, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME,
        D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE,
        D_ECOM_BU, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME,
        CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, COD_DEST3, D_SALE_DEPT,D_DATA_BLOCK,D_DIFF_TYPE,
        MATERIAL_CODE, MATERIAL_NAME, COD_DEST1, COD_DEST2, COD_DEST4, D_MARKET_PNT,
        D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE,
        D_PRO_SERIES, D_TECH_TYPE, IS_MINILED_CODE, D_PRO_CLASS, D_MODEL_LCA,
        D_PRO_TYPE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME,
        BATCH_ID, D_PRC_GRP, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME,
        D_POL_CLASS,MAP_QTY, ORG_REV, POLICY_AMT, POLICY_CASH_PD,D_ADJ_TYPE,
        ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, OTH_ASSESS_COST,
    PROVENIENZA,DATEUPD, USERUPD,
    CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,CN_MAP_ZUM,
    CN_ORG_REV,CN_SALE_COGS,CUSTOMER_MODEL,
    ELIM_QTY, ELIM_REV, ELIM_COST,
    CN_ELIM_QTY, CN_ELIM_REV, CN_ELIM_COST
  ,D_MINILED
    )


  SELECT NEWID() AS OID,
         COD_SCENARIO,
         COD_PERIODO,
         'ELIM' AS SRC_DETAIL,
         COD_CONTO,
         COD_AZIENDA,
         COD_AZI_CTP_ORG AS COD_AZI_CTP,
         COD_AZI_CTP_ORG,
         'GA00_ELIM' AS COD_CATEGORIA,
         AGENCY_CODE,
         AGENCY_NAME,
         CUST_CODE,
         CUST_NAME,
         D_CHANNEL,
         D_MODE,
         D_ONOFFLINE,
         D_CNL_C_TYPE,
         D_IND_C_TYPE,
         D_ECOM_BU,
         CUST_UNITY_NAME,
         CREDIT_LEVEL_NAME,
         CUST_NATURE_NAME,
         CUST_TYPE_NAME,
         SOLD_TO_CODE,
         SOLD_TO_NAME,
         COD_DEST3,
         D_SALE_DEPT,
         D_DATA_BLOCK,
         D_DIFF_TYPE,
         MATERIAL_CODE,
         MATERIAL_NAME,
         COD_DEST1,
         COD_DEST2,
         COD_DEST4,
         D_MARKET_PNT,
         D_PRO_SSER,
         D_SPEC_SEC,
         D_PRO_TYPE_S,
         D_PRO_STAGE,
         D_PRI_RANGE,
         D_PRO_SERIES,
         D_TECH_TYPE,
         IS_MINILED_CODE,
         D_PRO_CLASS,
         D_MODEL_LCA,
         D_PRO_TYPE,
         SALE_MODEL_CODE,
         SALE_MODEL_NAME,
         MODEL_CODE,
         MODEL_NAME,
         BATCH_ID,
         D_PRC_GRP,
         MATERIAL_GROUP_CODE,
         SHOP_CODE,
         SHOP_NAME,
         D_POL_CLASS,
         0 AS MAP_QTY,
         0 AS ORG_REV,
         0 AS POLICY_AMT,
         0 AS POLICY_CASH_PD,
         D_ADJ_TYPE,
         0 AS ASSESSED_REV,
         0 AS SALE_COGS,
         0 AS BEG_UNREAL_GP,
         0 AS END_UNREAL_GP,
         0 AS OTH_ASSESS_COST,
         PROVENIENZA,
         DATEUPD,
         USERUPD,
         M.CN_CLASS_MARK_CODE,
         M.CN_CLASS_MARK_NAME,
         M.SALE_CERT_TYPE,
         0 AS CN_MAP_ZUM,
         0 AS CN_ORG_REV,
         0 AS CN_SALE_COGS,
         M.CUSTOMER_MODEL,
         -1 * (NVL(ENT_QTY, 0) + NVL(ENT_QTY_ADJ, 0)) AS ELIM_QTY,
         -1 * (NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0) -
         NVL(POLICY_CASH_PD, 0)) AS ELIM_REV,
         (NVL(ENT_REV, 0) + NVL(ENT_REV_ADJ, 0) + NVL(POLICY_AMT, 0)) AS ELIM_COST,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            -1 * NVL(CN_MAP_ZUM, 0)
           ELSE
            0
         END AS CN_ELIM_QTY,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            -1 * NVL(CN_ORG_REV, 0)
           ELSE
            0
         END AS CN_ELIM_REV,
         CASE
           WHEN INSTR(V_CN_AZIENDA, COD_AZIENDA) > 0 AND
                INSTR(V_CN_AZIENDA, COD_AZI_CTP_ORG) > 0 THEN
            NVL(CN_ORG_REV, 0)
           ELSE
            0
         END AS CN_ELIM_COST,
         D_MINILED
    FROM AW_MR9_REVM05_000001_TEMP M
   WHERE 1 = 1
     AND M.COD_SCENARIO = P_SCENARIO
     AND M.COD_PERIODO = P_PERIODO
     AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND M.COD_AZI_CTP_ORG IS NOT NULL
     AND M.COD_AZI_CTP_ORG IN
         (SELECT DISTINCT ELEM FROM SESSION_V_REF_AZIENDA WHERE HIE = '10' AND SESSION_ID = V_SESSION_ID)
     AND COD_AZI_CTP_ORG NOT IN ('Z001')
     AND
        --国际营销提供抵消后结果
         (COD_SCENARIO = '2026ACT' AND COD_PERIODO = '01' AND
         COD_AZIENDA = '6515' AND SRC_DETAIL = 'CON_INP' AND
         COD_CONTO = 'S600111')
        /*20260226 新增排除锁定公司*/
    /*
    20260907 修改人 shiqingfeng.ex 去掉所有锁定表限制，仅保留最上面参数session表限制
    AND COD_AZIENDA NOT IN
         (SELECT COD_AZIENDA
            FROM AW_RUL_DWMCRS_000001 T
           WHERE REV05_FLAG = 'Y'
             AND T.COD_SCENARIO = P_SCENARIO
             AND T.COD_PERIODO = P_PERIODO
             AND T.COD_CONTO = 'ZAW_D2M_LOCK')*/
             ;
END IF ;


/*ELIM_COST成本抵消-法人更新为0
20260626SXX补充逻辑：
如果本方对方同时在事业部对应账套配置表【AW_RUL_ATSMAP_000001】的视像、冰箱、空调、中国区的公司范围里且属于折扣物料，则该字段放0
视像：BG001_BU001、BG002_BU001
冰箱：BG004_BU001、BG005_BU001
空调：BG003_BU011
中国区：BG012_BU
折扣物料取数范围：AW_RUL_REVEMA_000001-折扣物料清单
注意：
①如果是视像范围，需要是本方对方同事在视像范围里才把这个字段放0
②注意要考虑开始时间跟结束时间

*/

UPDATE AW_MR9_REVM05_000001_TEMP A
SET ELIM_COST = 0
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
  --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  AND A.MATERIAL_CODE IN (  SELECT T.MATERIAL_CODE
                              FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 t
                            WHERE T.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
                              AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                              AND MATERIAL_CODE IS NOT NULL
                           )
  AND ( (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      /* OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
 */
      )
  ;



UPDATE AW_MR9_REVM05_000001_TEMP A
SET ELIM_COST = 0
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
  --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  AND A.MATERIAL_CODE IN (  SELECT T.MATERIAL_CODE
                              FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 t
                            WHERE T.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
                              AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                              AND MATERIAL_CODE IS NOT NULL
                           )
  AND ( /* (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR */ (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      /* OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         ) */

      )
  ;




UPDATE AW_MR9_REVM05_000001_TEMP A
SET ELIM_COST = 0
WHERE COD_SCENARIO = P_SCENARIO
  AND COD_PERIODO = P_PERIODO
  AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
  --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  AND A.MATERIAL_CODE IN (  SELECT T.MATERIAL_CODE
                              FROM  TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001 t
                            WHERE T.COD_CONTO='ZAW_DWD_LIST_ZHEKOU'
                              AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                              AND MATERIAL_CODE IS NOT NULL
                           )
  AND ( /* (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG004_BU001','BG005_BU001')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG003_BU011')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )
      OR */ (COD_AZIENDA IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         AND A.COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG IN ('BG012_BU')
                         AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999')
                         )
         )

      )
  ;


  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '6  插入抵消数据完成', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '6  插入抵消数据',P_AZIENDA);
    COMMIT;


/* REV005_STEP_6_1（古洛尼赠品抵消数还原）  */ --20260820FJF_ADD

INSERT INTO AW_MR9_REVM05_000001_TEMP
(
  OID,COD_SCENARIO,COD_PERIODO,SRC_DETAIL,COD_CONTO,COD_CATEGORIA,COD_AZIENDA,AGENCY_CODE,AGENCY_NAME,CUSTOMER_MODEL,CUST_CODE,CUST_NAME,D_CHANNEL,D_MODE,D_ONOFFLINE
  ,D_CNL_C_TYPE,D_IND_C_TYPE,D_ECOM_BU,CUST_UNITY_NAME,CREDIT_LEVEL_NAME,CUST_NATURE_NAME,CUST_TYPE_NAME,SOLD_TO_CODE,SOLD_TO_NAME,COD_DEST3,D_SALE_DEPT,D_DATA_BLOCK
  ,D_DIFF_TYPE,D_ADJ_TYPE,MATERIAL_CODE,MATERIAL_NAME,COD_DEST2,COD_DEST4,D_MARKET_PNT,D_PRO_SSER,D_SPEC_SEC,D_PRO_TYPE_S,D_PRO_STAGE,D_PRI_RANGE,D_PRO_SERIES,D_TECH_TYPE
  ,IS_MINILED_CODE,D_PRO_CLASS,D_MODEL_LCA,D_PRO_TYPE,SALE_MODEL_CODE,SALE_MODEL_NAME,MODEL_CODE,MODEL_NAME,BATCH_ID,D_PRC_GRP,MATERIAL_GROUP_CODE,SHOP_CODE,SHOP_NAME
  ,D_POL_CLASS,COD_AZI_CTP,COD_AZI_CTP_ORG,DATEUPD,USERUPD,CN_CLASS_MARK_CODE,CN_CLASS_MARK_NAME,SALE_CERT_TYPE,D_OPER_TYPE,COD_DEST1,ELIM_QTY,CN_ELIM_QTY,ELIM_REV
  ,CN_ELIM_REV,ELIM_COST,CN_ELIM_COST,ORG_QTY,MAP_QTY,BILL_QTY,STD_QTY,PROVENIENZA
)

SELECT NEWID() AS OID
  ,COD_SCENARIO        --场景
  ,COD_PERIODO         --期间
  ,'TA' AS SRC_DETAIL          --源数据明细
  ,COD_CONTO           --科目
  ,'GA00_EG' AS COD_CATEGORIA       --类别
  ,COD_AZIENDA         --账套
  ,AGENCY_CODE         --销售部门
  ,AGENCY_NAME         --销售部门描述
  ,CUSTOMER_MODEL      --客户型号
  ,CUST_CODE           --客商
  ,CUST_NAME           --客商描述
  ,D_CHANNEL           --销售渠道
  ,D_MODE              --营销模式
  ,D_ONOFFLINE         --渠道分组
  ,D_CNL_C_TYPE        --渠道客户大类小类
  ,D_IND_C_TYPE        --行业客户大类小类
  ,D_ECOM_BU           --电商BU渠道细分
  ,CUST_UNITY_NAME     --统一客户组
  ,CREDIT_LEVEL_NAME   --信用等级
  ,CUST_NATURE_NAME    --单位性质
  ,CUST_TYPE_NAME      --客户类型
  ,SOLD_TO_CODE        --售达方
  ,SOLD_TO_NAME        --售达方名称
  ,COD_DEST3           --业务范围
  ,D_SALE_DEPT         --业务管理单元
  ,D_DATA_BLOCK        --数据块明细划分
  ,D_DIFF_TYPE         --管法差异项
  ,'REV_01_502' AS D_ADJ_TYPE          --调整类型
  ,MATERIAL_CODE       --物料
  ,MATERIAL_NAME       --物料描述
  ,COD_DEST2           --利润中心
  ,COD_DEST4           --品牌
  ,D_MARKET_PNT        --营销定位
  ,D_PRO_SSER          --产品套系
  ,D_SPEC_SEC          --规格段
  ,D_PRO_TYPE_S        --产品形态分类
  ,D_PRO_STAGE         --产品阶段
  ,D_PRI_RANGE         --价格段
  ,D_PRO_SERIES        --产品系列
  ,D_TECH_TYPE         --技术类型
  ,IS_MINILED_CODE     --是否MiniLED编码
  ,D_PRO_CLASS         --产品类别
  ,D_MODEL_LCA         --产品型号生命周期
  ,D_PRO_TYPE          --产品类型
  ,SALE_MODEL_CODE     --销售型号
  ,SALE_MODEL_NAME     --销售型号描述
  ,MODEL_CODE          --产品型号
  ,MODEL_NAME          --产品型号描述
  ,BATCH_ID            --批次号
  ,D_PRC_GRP           --定价组
  ,MATERIAL_GROUP_CODE --物料组
  ,SHOP_CODE           --门店
  ,SHOP_NAME           --门店名称
  ,D_POL_CLASS         --政策二级分类
  ,COD_AZI_CTP         --对方公司
  ,COD_AZI_CTP_ORG
  ,SYSDATE AS DATEUPD             --更新日期
  ,SESSION_USER AS USERUPD             --更新用户
  ,CN_CLASS_MARK_CODE  --中国区品线标记编码
  ,CN_CLASS_MARK_NAME  --中国区品线标记描述
  ,SALE_CERT_TYPE      --销售凭证类型
  ,D_OPER_TYPE         --业务分类
  ,COD_DEST1           --成本中心
  ,0 - ELIM_QTY     AS ELIM_QTY            --抵消数量
  ,0 - CN_ELIM_QTY  AS CN_ELIM_QTY         --中国区自营-抵消数量
  ,0 - ELIM_REV     AS ELIM_REV            --收入抵消-法人
  ,0 - CN_ELIM_REV  AS CN_ELIM_REV         --中国区自营-抵消收入
  ,0 - ELIM_COST    AS ELIM_COST           --成本抵消-法人
  ,0 - CN_ELIM_COST AS CN_ELIM_COST        --中国区自营-抵消成本
  ,0 - ORG_QTY      AS ORG_QTY             --原始销量
  ,0 - MAP_QTY      AS MAP_QTY             --数量(处理后)
  ,0 - BILL_QTY     AS BILL_QTY            --开票销量（日立用）
  ,0 - STD_QTY      AS STD_QTY             --折算销量-标准量
  ,'CPM_SP_M2M_REV_M' AS PROVENIENZA
FROM AW_MR9_REVM05_000001_TEMP M
WHERE 1=1
AND COD_SCENARIO = P_SCENARIO
AND COD_PERIODO = P_PERIODO
--edit by lc 20261005 限制这个范围在BG009_BU010事业部的账套范围里
AND COD_AZI_CTP_ORG IN (SELECT COD_AZIENDA
                    FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                    WHERE COD_BG IN ('BG009_BU010')
                    AND SUBSTR(P_SCENARIO,1,4) || P_PERIODO BETWEEN NVL(VALID_FR,'000000') AND NVL(VALID_TO,'999999'))
AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID)
AND D_OPER_TYPE = 'OPTY038' --取数时限制：OPTY038-中国区自营-古洛尼-赠品业务
AND COD_CATEGORIA = 'GA00_ELIM'
AND SRC_DETAIL = 'ELIM'
/*
20260907 修改人 shiqingfeng.ex 去掉所有锁定表限制，仅保留最上面参数session表限制
AND NOT EXISTS (
         SELECT 1 FROM AW_RUL_DWMCRS_000001 T
          WHERE T.REV05_FLAG = 'Y'
            AND T.COD_SCENARIO = P_SCENARIO
            AND T.COD_PERIODO = P_PERIODO
            AND T.COD_CONTO = 'ZAW_D2M_LOCK'
            AND T.COD_AZIENDA = M.COD_AZIENDA
     )*/
  ;
INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
VALUES('CPM_SP_M2M_REV_M', 'STEP_6_1  古洛尼赠品抵消数还原', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, 'STEP_6_1  古洛尼赠品抵消数还原',P_AZIENDA);
COMMIT;



  ------------------------------------------------------------------------------
  -- 7  内销-计算法人成本和大系统产销存的差，在工厂内销账套范围内根据利润中心把差值分摊，写入VAR_ALLOC_COST
  ------------------------------------------------------------------------------
IF P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL' THEN
   INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '7.0 START  计算法人成本和大系统产销存的差并分摊', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;

  MERGE INTO AW_MR9_REVM05_000001_TEMP M
  USING (
    /*ALTER BY LICHENG.EX 20261106 14:20 7.0 加固：ATSMAP 小集合先物化成 CTE，B 禁止下推 + 强制 hash join*/
    WITH CTE_BG001_AZI AS (
          SELECT DISTINCT COD_AZIENDA
            FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
           WHERE COD_BG = 'BG001_BU001'
    )
    SELECT /*+ USE_HASH(A B) */ A.OID,
                COD_SCENARIO,
                COD_PERIODO,
                CASE
                  WHEN NVL(B.DIFF_AMT, 0) <> 0 AND NVL(DOM_PSI_COST, 0) = 0 THEN
                   NVL(B.DIFF_AMT, 0)
                  ELSE
                   B.DIFF_AMT * DOM_PSI_COST / SUM_DOM_PSI_COST
                END VAR_ALLOC_COST
           FROM (
                 --在物料内，按照大系统产销存的金额进行分摊
                 SELECT OID,
                         COD_SCENARIO,
                         COD_PERIODO,
                         MATERIAL_CODE,
                         NVL(DOM_PSI_COST, 0) DOM_PSI_COST,
                         SUM(NVL(DOM_PSI_COST, 0)) OVER(PARTITION BY COD_SCENARIO, COD_PERIODO, MATERIAL_CODE) SUM_DOM_PSI_COST
                   FROM AW_MR9_REVM05_000001_TEMP
                  WHERE COD_SCENARIO = P_SCENARIO
                    AND COD_PERIODO = P_PERIODO
                    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST A1
                                         WHERE SESSION_ID = V_SESSION_ID
                                           AND EXISTS (SELECT 1
                                                   FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A2
                                                  WHERE COD_BG = 'BG001_BU001'
                                                    AND A2.COD_AZIENDA = A1.ELEM
                                                    )
                              )
                    /*AND COD_AZIENDA IN
                        (SELECT COD_AZIENDA
                           FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                          WHERE COD_BG = 'BG001_BU001')*/
                    AND COD_DEST3 LIKE '2%'
                    /*AND COD_DEST3 IN (SELECT ELEM
                                        FROM SESSION_V_REF_DEST3_NONAME
                                       WHERE  SESSION_ID = V_SESSION_ID AND HIE = '01'
                                         AND NODE = 'HN')*/

                    AND
                       --(COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' /*OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%'*/) AND
                        NVL(DOM_PSI_COST, 0) <> 0
                    AND PROVENIENZA NOT IN ('INPUT_DEFORM')
                    ) A
           JOIN (
                --按照物料获取差值
                /* B 按物料汇总差值；NO_PUSH_PRED 防止被推成逐行标量子查询
                   原写法 CASE WHEN COD_AZI_CTP IN (SELECT COD_AZIENDA FROM ATSMAP WHERE COD_BG='BG001_BU001')
                   在统计失真时会逐行执行子查询，改为 LEFT JOIN 预聚合 CTE，集合只算一次 */
                SELECT /*+ NO_PUSH_PRED */
                        T.MATERIAL_CODE,
                        SUM(CASE
                              WHEN CTP.COD_AZIENDA IS NOT NULL THEN
                               NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0) +
                               NVL(T.ELIM_COST, 0) /*+ NVL(OTH_ASSESS_COST,0)*/
                               -NVL(T.DOM_PSI_COST, 0)
                              ELSE
                               NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0) /*+ NVL(OTH_ASSESS_COST,0)*/
                               -NVL(T.DOM_PSI_COST, 0)
                            END) DIFF_AMT
                  FROM AW_MR9_REVM05_000001_TEMP T
                  LEFT JOIN CTE_BG001_AZI CTP
                         ON CTP.COD_AZIENDA = T.COD_AZI_CTP
                 WHERE T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST A1
                                    WHERE SESSION_ID = V_SESSION_ID
                                      AND EXISTS (SELECT 1
                                                   FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 A2
                                                  WHERE COD_BG = 'BG001_BU001'
                                                    AND A2.COD_AZIENDA = A1.ELEM
                                                    )
                              )
                   /*AND COD_AZIENDA IN
                       (SELECT COD_AZIENDA
                          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
                         WHERE COD_BG = 'BG001_BU001')*/
                   AND T.COD_DEST3 LIKE '2%'
                   /*AND COD_DEST3 IN (SELECT ELEM
                                       FROM SESSION_V_REF_DEST3_NONAME
                                      WHERE  SESSION_ID = V_SESSION_ID
                                        AND HIE = '01'
                                        AND NODE = 'HN')*/

                   AND
                      --(COD_AZIENDA LIKE '2%' OR COD_AZIENDA LIKE '163%' /*OR COD_AZIENDA LIKE '62%' OR COD_AZIENDA LIKE '68%' OR COD_AZIENDA LIKE '63%' OR COD_AZIENDA LIKE '67%'*/) AND
                       (NVL(T.ENT_COST, 0) <> 0 OR NVL(T.ENT_COST_ADJ, 0) <> 0 OR
                       NVL(T.ELIM_COST, 0) <> 0 OR
                       NVL(T.OTH_ASSESS_COST, 0) <> 0OR
                        NVL(T.DOM_PSI_COST, 0) <> 0)
                 GROUP BY T.MATERIAL_CODE) B
             ON A.MATERIAL_CODE = B.MATERIAL_CODE
          WHERE ROUND(A.SUM_DOM_PSI_COST, 3) <> 0) T

  ON (M.OID = T.OID
  --AND (INSTR(V_AZIENDA, M.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  /*20260226 新增排除锁定公司*/
  /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                            FROM AW_RUL_DWMCRS_000001 T
                           WHERE REV05_FLAG = 'Y'
                             AND T.COD_SCENARIO = P_SCENARIO
                             AND T.COD_PERIODO = P_PERIODO
                             AND T.COD_CONTO = 'ZAW_D2M_LOCK') */
   )
  WHEN MATCHED THEN
    UPDATE SET VAR_ALLOC_COST = T.VAR_ALLOC_COST
    ;

   INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '7.1  计算法人成本 ', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;
 /*物料分摊后仍未分摊金额*/

MERGE /*取消并发*/ INTO AW_MR9_REVM05_000001_TEMP A
USING (
WITH
BG001_AZI AS (
    SELECT COD_AZIENDA
      FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
     WHERE COD_BG = 'BG001_BU001'
),
NEED_UPDATE_MC AS (
    /*ALTER BY LICHENG.EX 20261106 14:20 禁止把本聚合视图下推成逐行标量子查询*/
    SELECT /*+ NO_PUSH_PRED */ T.MATERIAL_CODE
      FROM AW_MR9_REVM05_000001_TEMP T
      LEFT JOIN BG001_AZI BG_CTP
             ON BG_CTP.COD_AZIENDA = T.COD_AZI_CTP_ORG
     WHERE T.COD_SCENARIO = P_SCENARIO
       AND T.COD_PERIODO  = P_PERIODO
       AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
       AND T.COD_AZIENDA IN (SELECT COD_AZIENDA FROM BG001_AZI)
       /*
       20260907 修改人 shiqingfeng.ex 去掉所有锁定表限制，仅保留最上面参数session表限制
       AND NOT EXISTS (
           SELECT 1 FROM AW_RUL_DWMCRS_000001 L
            WHERE L.REV05_FLAG   = 'Y'
              AND L.COD_SCENARIO = P_SCENARIO
              AND L.COD_PERIODO  = P_PERIODO
              AND L.COD_CONTO    = 'ZAW_D2M_LOCK'
              AND L.COD_AZIENDA  = T.COD_AZIENDA
       )*/
       AND T.COD_DEST3 LIKE '2%'
       /*AND T.COD_DEST3 IN (
           SELECT ELEM
             FROM SESSION_V_REF_DEST3_NONAME
            WHERE SESSION_ID = V_SESSION_ID
              AND HIE = '01'
              AND NODE = 'HN'
       )*/
       AND T.MATERIAL_CODE IS NOT NULL
       AND NVL(T.SRC_DETAIL, '|') NOT IN ('CON_INP')
       AND T.COD_CONTO <> 'SEGP000'
     GROUP BY T.MATERIAL_CODE
    HAVING ROUND(
             SUM(NVL(T.DOM_PSI_COST, 0))                     /* DOM_PSI_COST */
           + SUM(NVL(T.VAR_ALLOC_COST, 0))                   /* VAR_ALLOC_COST */
           - SUM(NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)) /* ENT_COST */
           - SUM(CASE WHEN BG_CTP.COD_AZIENDA IS NOT NULL
                      THEN NVL(T.ELIM_COST, 0)
                      ELSE 0 END)                            /* ELIM_COST */
           , 3
           ) <> 0
)
    /*ALTER BY LICHENG.EX 20261106 14:20 物料清单与明细按 hash join 关联，避免逐行回表*/
    SELECT /*+ USE_HASH(T MC) */ T.OID AS OID,
           T.VAR_ALLOC_COST
         + NVL(T.ENT_COST_ADJ, 0)
         + NVL(T.ENT_COST, 0)
         + CASE
             WHEN BG_CTP.COD_AZIENDA IS NOT NULL
             THEN NVL(T.ELIM_COST, 0)
             ELSE 0
           END
           AS NEW_VAR_ALLOC_COST
      FROM AW_MR9_REVM05_000001_TEMP T
      INNER JOIN NEED_UPDATE_MC MC
              ON MC.MATERIAL_CODE = T.MATERIAL_CODE
      LEFT JOIN BG001_AZI BG_CTP
             ON BG_CTP.COD_AZIENDA = T.COD_AZI_CTP_ORG
     WHERE T.COD_SCENARIO = P_SCENARIO
       AND T.COD_PERIODO  = P_PERIODO
       AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
      --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
       AND T.COD_AZIENDA IN (SELECT COD_AZIENDA FROM BG001_AZI)
       /* AND NOT EXISTS (
           SELECT 1 FROM AW_RUL_DWMCRS_000001 L
            WHERE L.REV05_FLAG   = 'Y'
              AND L.COD_SCENARIO = P_SCENARIO
              AND L.COD_PERIODO  = P_PERIODO
              AND L.COD_CONTO    = 'ZAW_D2M_LOCK'
              AND L.COD_AZIENDA  = T.COD_AZIENDA
       ) */
       AND T.COD_DEST3 LIKE '2%'
       /*AND T.COD_DEST3 IN (
           SELECT ELEM
             FROM SESSION_V_REF_DEST3_NONAME
            WHERE SESSION_ID = V_SESSION_ID
              AND HIE = '01'
              AND NODE = 'HN'
       )*/
       AND T.MATERIAL_CODE IS NOT NULL
       AND NVL(T.SRC_DETAIL, '|') NOT IN ('CON_INP')
       AND T.COD_CONTO <> 'SEGP000'
) S
ON (A.OID = S.OID)
WHEN MATCHED THEN
  UPDATE SET A.VAR_ALLOC_COST = S.NEW_VAR_ALLOC_COST
;

   INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '7.2  物料分摊后仍未分摊金额', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;
/*物料号为空的 赋值到差异分摊中*/

MERGE /*取消并发*/
INTO AW_MR9_REVM05_000001_TEMP A
USING (
    WITH
    -- CTE 1: BG001_BU001 公司集合（SET 和 WHERE 各用一次，合并为1个CTE）
    CTE_BG001 AS (
        SELECT COD_AZIENDA
          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
         WHERE COD_BG = 'BG001_BU001'
    ),
    -- CTE 2: 内销 DEST3 集合
    CTE_DEST3_HN AS (
        SELECT ELEM
          FROM SESSION_V_REF_DEST3_NONAME
         WHERE SESSION_ID = V_SESSION_ID
           AND HIE = '01'
           AND NODE = 'HN'
    ),
    -- CTE 3: 锁定公司集合
    CTE_LOCK_AZI AS (
        SELECT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001
         WHERE REV05_FLAG = 'Y'
           AND COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO = P_PERIODO
           AND COD_CONTO = 'ZAW_D2M_LOCK'
    ),
    -- 主查询：筛选需要更新的行，预计算新值
    CTE_UPD AS (
        SELECT T.OID AS OID,
               -- 预计算 VAR_ALLOC_COST 新值
               NVL(T.ENT_COST_ADJ, 0)
             + NVL(T.ENT_COST, 0)
             + CASE WHEN CTP_BG.COD_AZIENDA IS NOT NULL  -- CTP_ORG 属于 BG001_BU001
                    THEN NVL(T.ELIM_COST, 0)
                    ELSE 0
               END AS NEW_VAR_ALLOC_COST
          FROM AW_MR9_REVM05_000001_TEMP T
          -- LEFT JOIN: 判断 CTP_ORG 是否属于 BG001_BU001（替代 SET 中的相关子查询）
          LEFT JOIN CTE_BG001 CTP_BG
                 ON CTP_BG.COD_AZIENDA = T.COD_AZI_CTP_ORG
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           -- 卖方属于 BG001_BU001
           AND EXISTS (SELECT 1 FROM CTE_BG001 S WHERE S.COD_AZIENDA = T.COD_AZIENDA)
           -- 内销
           AND EXISTS (SELECT 1 FROM CTE_DEST3_HN D WHERE D.ELEM = T.COD_DEST3)
           -- 无物料
           AND T.MATERIAL_CODE IS NULL
           -- 排除特定来源
           AND NVL(T.SRC_DETAIL, '|') NOT IN ('CON_INP')
           AND T.COD_CONTO <> 'SEGP000'
           -- 有成本数据才更新
           AND (NVL(T.ENT_COST, 0) <> 0
             OR NVL(T.ELIM_COST, 0) <> 0
             OR NVL(T.ENT_COST_ADJ, 0) <> 0)
           -- 公司过滤
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           -- 排除锁定公司
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
    )
    SELECT OID, NEW_VAR_ALLOC_COST
      FROM CTE_UPD

) S
ON (A.OID = S.OID)
WHEN MATCHED THEN
    UPDATE SET A.VAR_ALLOC_COST = S.NEW_VAR_ALLOC_COST
;

  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '7.3 END  计算法人成本和大系统产销存的差并分摊', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;

END IF;
  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '计算法人成本和大系统产销存的差并分摊仅视像运行', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '7  计算法人成本和大系统产销存的差并分摊',P_AZIENDA);
    COMMIT;


MERGE /*取消并发*/
INTO AW_MR9_REVM05_000001_TEMP A
USING (
    WITH
    -- ---------------------------------------------------------------
    -- CTE1：BG001_BU020-显示事业部-贵阳工厂端 公司范围
    -- ---------------------------------------------------------------
    CTE_BG001 AS (
        SELECT COD_AZIENDA
          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
         WHERE COD_BG IN ('BG001_BU020')
    ),
    -- ---------------------------------------------------------------
    -- CTE2：内销 DEST3 集合（HIE='01', NODE='HN'）
    -- ---------------------------------------------------------------
    CTE_DEST3_HN AS (
        SELECT ELEM
          FROM SESSION_V_REF_DEST3_NONAME
         WHERE SESSION_ID = V_SESSION_ID
           AND HIE = '01'
           AND (NODE = 'HN' OR ELEM = '9999')
    ),
    -- ---------------------------------------------------------------
    -- CTE3：锁定公司集合
    -- ---------------------------------------------------------------
    CTE_LOCK_AZI AS (
        SELECT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001
         WHERE REV05_FLAG  = 'Y'
           AND COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO  = P_PERIODO
           AND COD_CONTO    = 'ZAW_D2M_LOCK'
    ),
    -- ---------------------------------------------------------------
    -- CTE4：折扣物料清单（带有效期判断）
    -- ---------------------------------------------------------------
    ZK_MATERIAL_CODE AS (
        SELECT MATERIAL_CODE
          FROM TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001
         WHERE COD_CONTO = 'ZAW_DWD_LIST_ZHEKOU'
           AND SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
               BETWEEN NVL(VALID_FR, '000000') AND NVL(VALID_TO, '999999')
           AND MATERIAL_CODE IS NOT NULL
    ),
    -- ---------------------------------------------------------------
    -- CTE5：DEST2 映射关系（源→目标，无配置则保留原值）
    -- ---------------------------------------------------------------
    D2_MAP AS (
        SELECT DISTINCT
               CASE WHEN M.FROM_COLUMN_VALUE_1 = '990990000'
                      THEN 'ZZZZ'
                    ELSE M.FROM_COLUMN_VALUE_1
               END AS D2_SRC,
               NVL(D2.ELEM, M.TO_COLUMN_VALUE_1) AS D2_MAP
          FROM TGK_FIMA_HISENSE.AW_RUL_ALCMAP_000001 M
          LEFT JOIN (
                    SELECT NODE, ELEM
                      FROM SESSION_V_REF_DEST2
                     WHERE SESSION_ID = V_SESSION_ID
                    ) D2
            ON M.TO_COLUMN_VALUE_1 = D2.NODE
         WHERE SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
               BETWEEN NVL(M.BEGIN_DATE, '000000') AND NVL(M.END_DATE, '999999')
           AND M.ALCMAP_ID IN (
               'EXP-MAP-A10001', 'EXP-MAP-A10002', 'EXP-MAP-A10003',
               'EXP-MAP-A10004', 'EXP-MAP-A10013', 'EXP-MAP-A10008'
           )
    ),
    -- ---------------------------------------------------------------
    -- CTE6：DEST3 映射关系（源→目标，无配置则保留原值）
    -- ---------------------------------------------------------------
    D3_MAP AS (
        SELECT DISTINCT
               M.FROM_COLUMN_VALUE_1             AS D3_SRC,
               NVL(D3.ELEM, M.TO_COLUMN_VALUE_1) AS D3_MAP
          FROM TGK_FIMA_HISENSE.AW_RUL_ALCMAP_000001 M
          LEFT JOIN (
                    SELECT NODE, ELEM
                      FROM SESSION_V_REF_DEST3_NONAME
                     WHERE SESSION_ID = V_SESSION_ID
                    ) D3
            ON M.TO_COLUMN_VALUE_1 = D3.NODE
         WHERE SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
               BETWEEN NVL(M.BEGIN_DATE, '000000') AND NVL(M.END_DATE, '999999')
           AND M.ALCMAP_ID IN (
               'EXP-MAP-A10006', 'EXP-MAP-A10011', 'EXP-MAP-A100013'
           )
    ),
    -- ---------------------------------------------------------------
    -- CTE7：分摊基础数据（未汇总，只做条件过滤）
    -- ---------------------------------------------------------------
    ALLOC_BASE AS (
        -- 部分①：折扣物料抵消金额
        --   条件：SRC_DETAIL='ELIM' + 本方&对方同在BG001 + 内销 + 折扣物料
        SELECT T.COD_DEST2,
               T.COD_DEST3,
               NVL(T.ELIM_COST, 0) AS ALLOC_AMT
          FROM AW_MR9_REVM05_000001_TEMP T
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           AND T.SRC_DETAIL   = 'ELIM'
           AND EXISTS (SELECT 1 FROM CTE_BG001     B WHERE B.COD_AZIENDA  = T.COD_AZIENDA)
           AND EXISTS (SELECT 1 FROM CTE_BG001     B WHERE B.COD_AZIENDA  = T.COD_AZI_CTP_ORG)
           AND EXISTS (SELECT 1 FROM CTE_DEST3_HN  D WHERE D.ELEM         = T.COD_DEST3)
           AND EXISTS (SELECT 1 FROM ZK_MATERIAL_CODE M WHERE M.MATERIAL_CODE = T.MATERIAL_CODE)
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND (P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL')
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND NVL(T.ELIM_COST, 0) <> 0
        UNION ALL
        -- 部分②：无物料单体成本
        --   条件：MATERIAL_CODE IS NULL + 本方在BG001 + 内销
        SELECT T.COD_DEST2,
               T.COD_DEST3,
               NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0) AS ALLOC_AMT
          FROM AW_MR9_REVM05_000001_TEMP T
         WHERE T.COD_SCENARIO  = P_SCENARIO
           AND T.COD_PERIODO   = P_PERIODO
           AND T.SRC_DETAIL   <> 'ZZFT'
           AND EXISTS (SELECT 1 FROM CTE_BG001    B WHERE B.COD_AZIENDA = T.COD_AZIENDA)
           AND EXISTS (SELECT 1 FROM CTE_DEST3_HN D WHERE D.ELEM        = T.COD_DEST3)
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND (P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL')
         AND T.MATERIAL_CODE IS NULL
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0) <> 0
    ),
    -- ---------------------------------------------------------------
    -- CTE8：待分摊金额
    -- ---------------------------------------------------------------
    ALLOC_COST AS (
        /*ALTER BY LICHENG.EX 20261106 14:20 待分摊金额禁止下推，保证只聚合一次*/
        SELECT /*+ NO_PUSH_PRED */ B.SRC_DEST2, B.SRC_DEST3,
               NVL(D2.D2_MAP, B.SRC_DEST2) AS TARGET_DEST2,
               NVL(D3.D3_MAP, B.SRC_DEST3) AS TARGET_DEST3,
               SUM(B.TOTAL_ALLOC_AMT) AS TOTAL_ALLOC_AMT
          FROM (
                   -- 按原始 DEST2/DEST3 汇总金额
                   SELECT COD_DEST2 AS SRC_DEST2,
                          COD_DEST3 AS SRC_DEST3,
                          SUM(ALLOC_AMT) AS TOTAL_ALLOC_AMT
                     FROM ALLOC_BASE
                    GROUP BY COD_DEST2, COD_DEST3
                    HAVING SUM(ALLOC_AMT) <> 0
               ) B
          LEFT JOIN D2_MAP D2 ON B.SRC_DEST2 = D2.D2_SRC
          LEFT JOIN D3_MAP D3 ON B.SRC_DEST3 = D3.D3_SRC
          GROUP BY B.SRC_DEST2, B.SRC_DEST3,NVL(D2.D2_MAP, B.SRC_DEST2),
                   NVL(D3.D3_MAP, B.SRC_DEST3)
    ),
    -- ---------------------------------------------------------------
    -- CTE9：分摊因子 + 分摊比例
    -- ---------------------------------------------------------------
    ALLOC_BL AS (
        SELECT T.OID,
               ALLOC_COST.SRC_DEST2,ALLOC_COST.SRC_DEST3,
               T.COD_DEST2,
               T.COD_DEST3,
               NVL(T.PSI_COMB_COST, 0) AS BL,
               RATIO_TO_REPORT(NVL(T.PSI_COMB_COST, 0)) OVER (PARTITION BY ALLOC_COST.SRC_DEST2,ALLOC_COST.SRC_DEST3) AS ALLOC_RATIO
          FROM AW_MR9_REVM05_000001_TEMP T
          LEFT JOIN (SELECT DISTINCT SRC_DEST2,SRC_DEST3,TARGET_DEST2,TARGET_DEST3 FROM ALLOC_COST) ALLOC_COST
            ON T.COD_DEST2 = ALLOC_COST.TARGET_DEST2
           AND T.COD_DEST3 = ALLOC_COST.TARGET_DEST3
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           AND EXISTS (SELECT 1 FROM CTE_BG001 B WHERE B.COD_AZIENDA = T.COD_AZIENDA)
           AND T.COD_CATEGORIA NOT IN ('GA00_PA_IN','GA00_PA_IN')
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND (P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL')
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND NVL(T.PSI_COMB_COST, 0) <> 0
    )
    /*ALTER BY LICHENG.EX 20261106 14:20 分摊明细与待分摊金额按 hash join 关联*/
    SELECT /*+ USE_HASH(BL AC) */ BL.OID,
           SUM(NVL(AC.TOTAL_ALLOC_AMT,0) * NVL(BL.ALLOC_RATIO,0)) AS ASSESS_NM_ALLOC_COST
      FROM ALLOC_BL BL
      LEFT JOIN ALLOC_COST AC
        ON BL.COD_DEST2 = AC.TARGET_DEST2
       AND BL.COD_DEST3 = AC.TARGET_DEST3
       AND BL.SRC_DEST2 = AC.SRC_DEST2
       AND BL.SRC_DEST3 = AC.SRC_DEST3
     GROUP BY BL.OID
     HAVING SUM(NVL(AC.TOTAL_ALLOC_AMT,0) * NVL(BL.ALLOC_RATIO,0)) <> 0
) S
ON (A.OID = S.OID)
WHEN MATCHED THEN
    UPDATE SET A.ASSESS_NM_ALLOC_COST = S.ASSESS_NM_ALLOC_COST
;

  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_7（ 考核成本无物料分摊）-显示事业部-贵阳工厂端结束', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;

/*   20260826-1 SHIQINGFENG.EX  REV005_STEP_7（ 考核成本无物料分摊）,【BG001_BU030-显示事业部-广东】SXX20260825新增范围内公司 注意：贵阳、广东的事业部只能分别在自己的事业部范围内分摊
*/


MERGE /*取消并发*/
INTO AW_MR9_REVM05_000001_TEMP A
USING (
    WITH
    -- ---------------------------------------------------------------
    -- CTE1 20260826 新增BG001_BU030-显示事业部-广东
    -- ---------------------------------------------------------------
    CTE_BG001 AS (
        SELECT COD_AZIENDA
          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
         WHERE COD_BG IN ('BG001_BU030')
    ),
    -- ---------------------------------------------------------------
    -- CTE2：内销 DEST3 集合（HIE='01', NODE='HN'）
    -- ---------------------------------------------------------------
    CTE_DEST3_HN AS (
        SELECT ELEM
          FROM SESSION_V_REF_DEST3_NONAME
         WHERE SESSION_ID = V_SESSION_ID
           AND HIE = '01'
           AND (NODE = 'HN' OR ELEM = '9999')
    ),
    -- ---------------------------------------------------------------
    -- CTE3：锁定公司集合
    -- ---------------------------------------------------------------
    CTE_LOCK_AZI AS (
        SELECT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001
         WHERE REV05_FLAG  = 'Y'
           AND COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO  = P_PERIODO
           AND COD_CONTO    = 'ZAW_D2M_LOCK'
    ),
    -- ---------------------------------------------------------------
    -- CTE4：折扣物料清单（带有效期判断）
    -- ---------------------------------------------------------------
    ZK_MATERIAL_CODE AS (
        SELECT MATERIAL_CODE
          FROM TGK_FIMA_HISENSE.AW_RUL_REVEMA_000001
         WHERE COD_CONTO = 'ZAW_DWD_LIST_ZHEKOU'
           AND SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
               BETWEEN NVL(VALID_FR, '000000') AND NVL(VALID_TO, '999999')
           AND MATERIAL_CODE IS NOT NULL
    ),
    -- ---------------------------------------------------------------
    -- CTE5：DEST2 映射关系（源→目标，无配置则保留原值）
    -- ---------------------------------------------------------------
    D2_MAP AS (
        SELECT DISTINCT
               CASE WHEN M.FROM_COLUMN_VALUE_1 = '990990000'
                      THEN 'ZZZZ'
                    ELSE M.FROM_COLUMN_VALUE_1
               END AS D2_SRC,
               NVL(D2.ELEM, M.TO_COLUMN_VALUE_1) AS D2_MAP
          FROM TGK_FIMA_HISENSE.AW_RUL_ALCMAP_000001 M
          LEFT JOIN (
                    SELECT NODE, ELEM
                      FROM SESSION_V_REF_DEST2
                     WHERE SESSION_ID = V_SESSION_ID
                    ) D2
            ON M.TO_COLUMN_VALUE_1 = D2.NODE
         WHERE SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
               BETWEEN NVL(M.BEGIN_DATE, '000000') AND NVL(M.END_DATE, '999999')
           AND M.ALCMAP_ID IN (
               'EXP-MAP-A10001', 'EXP-MAP-A10002', 'EXP-MAP-A10003',
               'EXP-MAP-A10004', 'EXP-MAP-A10013', 'EXP-MAP-A10008'
           )
    ),
    -- ---------------------------------------------------------------
    -- CTE6：DEST3 映射关系（源→目标，无配置则保留原值）
    -- ---------------------------------------------------------------
    D3_MAP AS (
        SELECT DISTINCT
               M.FROM_COLUMN_VALUE_1             AS D3_SRC,
               NVL(D3.ELEM, M.TO_COLUMN_VALUE_1) AS D3_MAP
          FROM TGK_FIMA_HISENSE.AW_RUL_ALCMAP_000001 M
          LEFT JOIN (
                    SELECT NODE, ELEM
                      FROM SESSION_V_REF_DEST3_NONAME
                     WHERE SESSION_ID = V_SESSION_ID
                    ) D3
            ON M.TO_COLUMN_VALUE_1 = D3.NODE
         WHERE SUBSTR(P_SCENARIO, 1, 4) || P_PERIODO
               BETWEEN NVL(M.BEGIN_DATE, '000000') AND NVL(M.END_DATE, '999999')
           AND M.ALCMAP_ID IN (
               'EXP-MAP-A10006', 'EXP-MAP-A10011', 'EXP-MAP-A100013'
           )
    ),
    -- ---------------------------------------------------------------
    -- CTE7：分摊基础数据（未汇总，只做条件过滤）
    -- ---------------------------------------------------------------
    ALLOC_BASE AS (
        -- 部分①：折扣物料抵消金额
        --   条件：SRC_DETAIL='ELIM' + 本方&对方同在BG001 + 内销 + 折扣物料
        SELECT T.COD_DEST2,
               T.COD_DEST3,
               NVL(T.ELIM_COST, 0) AS ALLOC_AMT
          FROM AW_MR9_REVM05_000001_TEMP T
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           AND T.SRC_DETAIL   = 'ELIM'
           AND EXISTS (SELECT 1 FROM CTE_BG001     B WHERE B.COD_AZIENDA  = T.COD_AZIENDA)
           AND EXISTS (SELECT 1 FROM CTE_BG001     B WHERE B.COD_AZIENDA  = T.COD_AZI_CTP_ORG)
           AND EXISTS (SELECT 1 FROM CTE_DEST3_HN  D WHERE D.ELEM         = T.COD_DEST3)
           AND EXISTS (SELECT 1 FROM ZK_MATERIAL_CODE M WHERE M.MATERIAL_CODE = T.MATERIAL_CODE)
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND (P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL')
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND NVL(T.ELIM_COST, 0) <> 0
        UNION ALL
        -- 部分②：无物料单体成本
        --   条件：MATERIAL_CODE IS NULL + 本方在BG001 + 内销
        SELECT T.COD_DEST2,
               T.COD_DEST3,
               NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0) AS ALLOC_AMT
          FROM AW_MR9_REVM05_000001_TEMP T
         WHERE T.COD_SCENARIO  = P_SCENARIO
           AND T.COD_PERIODO   = P_PERIODO
           AND T.SRC_DETAIL   <> 'ZZFT'
           AND EXISTS (SELECT 1 FROM CTE_BG001    B WHERE B.COD_AZIENDA = T.COD_AZIENDA)
           AND EXISTS (SELECT 1 FROM CTE_DEST3_HN D WHERE D.ELEM        = T.COD_DEST3)
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND (P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL')
         AND T.MATERIAL_CODE IS NULL
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0) <> 0
    ),
    -- ---------------------------------------------------------------
    -- CTE8：待分摊金额
    -- ---------------------------------------------------------------
    ALLOC_COST AS (
        /*ALTER BY LICHENG.EX 20261106 14:20 待分摊金额禁止下推，保证只聚合一次*/
        SELECT /*+ NO_PUSH_PRED */ B.SRC_DEST2, B.SRC_DEST3,
               NVL(D2.D2_MAP, B.SRC_DEST2) AS TARGET_DEST2,
               NVL(D3.D3_MAP, B.SRC_DEST3) AS TARGET_DEST3,
               SUM(B.TOTAL_ALLOC_AMT) AS TOTAL_ALLOC_AMT
          FROM (
                   -- 按原始 DEST2/DEST3 汇总金额
                   SELECT COD_DEST2 AS SRC_DEST2,
                          COD_DEST3 AS SRC_DEST3,
                          SUM(ALLOC_AMT) AS TOTAL_ALLOC_AMT
                     FROM ALLOC_BASE
                    GROUP BY COD_DEST2, COD_DEST3
                    HAVING SUM(ALLOC_AMT) <> 0
               ) B
          LEFT JOIN D2_MAP D2 ON B.SRC_DEST2 = D2.D2_SRC
          LEFT JOIN D3_MAP D3 ON B.SRC_DEST3 = D3.D3_SRC
          GROUP BY B.SRC_DEST2, B.SRC_DEST3,NVL(D2.D2_MAP, B.SRC_DEST2),
                   NVL(D3.D3_MAP, B.SRC_DEST3)
    ),
    -- ---------------------------------------------------------------
    -- CTE9：分摊因子 + 分摊比例
    -- ---------------------------------------------------------------
    ALLOC_BL AS (
        SELECT T.OID,
               ALLOC_COST.SRC_DEST2,ALLOC_COST.SRC_DEST3,
               T.COD_DEST2,
               T.COD_DEST3,
               NVL(T.PSI_COMB_COST, 0) AS BL,
               RATIO_TO_REPORT(NVL(T.PSI_COMB_COST, 0)) OVER (PARTITION BY ALLOC_COST.SRC_DEST2,ALLOC_COST.SRC_DEST3) AS ALLOC_RATIO
          FROM AW_MR9_REVM05_000001_TEMP T
          LEFT JOIN (SELECT DISTINCT SRC_DEST2,SRC_DEST3,TARGET_DEST2,TARGET_DEST3 FROM ALLOC_COST) ALLOC_COST
            ON T.COD_DEST2 = ALLOC_COST.TARGET_DEST2
           AND T.COD_DEST3 = ALLOC_COST.TARGET_DEST3
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           AND EXISTS (SELECT 1 FROM CTE_BG001 B WHERE B.COD_AZIENDA = T.COD_AZIENDA)
           AND T.COD_CATEGORIA NOT IN ('GA00_PA_IN','GA00_PA_IN')
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           AND (P_AZIENDA = 'SX' OR P_AZIENDA = 'ALL')
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND NVL(T.PSI_COMB_COST, 0) <> 0
    )
    /*ALTER BY LICHENG.EX 20261106 14:20 分摊明细与待分摊金额按 hash join 关联*/
    SELECT /*+ USE_HASH(BL AC) */ BL.OID,
           SUM(NVL(AC.TOTAL_ALLOC_AMT,0) * NVL(BL.ALLOC_RATIO,0)) AS ASSESS_NM_ALLOC_COST
      FROM ALLOC_BL BL
      LEFT JOIN ALLOC_COST AC
        ON BL.COD_DEST2 = AC.TARGET_DEST2
       AND BL.COD_DEST3 = AC.TARGET_DEST3
       AND BL.SRC_DEST2 = AC.SRC_DEST2
       AND BL.SRC_DEST3 = AC.SRC_DEST3
     GROUP BY BL.OID
     HAVING SUM(NVL(AC.TOTAL_ALLOC_AMT,0) * NVL(BL.ALLOC_RATIO,0)) <> 0
) S
ON (A.OID = S.OID)
WHEN MATCHED THEN
    UPDATE SET A.ASSESS_NM_ALLOC_COST = S.ASSESS_NM_ALLOC_COST
;


  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', 'REV005_STEP_7（ 考核成本无物料分摊）-显示事业部-广东结束', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '',P_AZIENDA);
    COMMIT;





  ------------------------------------------------------------------------------
  -- 8  外销成本处理
  ------------------------------------------------------------------------------


  /*如果收入成本是以下条件的，才把对应字段进行在此列赋值
  收入成本表取数限制条件：
  ①公司范围：【COD_AZIENDA】
  取工厂法人（视像:2000/2300/2330/2900；
  激光：2050;空调：62开头公司（目前6220/6210/6230）；
  冰冷洗：63开头公司（目前6300/6320/6330/6360/6370）；
  厨电：6515）；商冷：6380 20260114 SXX新增）
  ②科目范围限制【COD_CONTO】
  取收入-S6001开头科目，成本-S6401开头科目。
  需剔除AD结尾科目
  ③业务范围限制【COD_DEST3】
  取外销类业务，节点在HW-海外节点下的所有要素
  ④对方公司限制【COD_AZI_CTP_ORG】
  剔除对方公司为工厂法人（视像:2000/2300/2330/2900；
  激光：2050;空调：62开头公司（目前6220/6210/6230）；
  冰冷洗：63开头公司（目前6300/6320/6330/6360/6370）；
  厨电：6515）；商冷：6380 20260114 SXX新增）
  ⑤增加管法差类型限制，只取空调返利【D_DIFF_TYPE】
  限制
  只取【D_DIFF_TYPE】为空、为ZZZZ、为140304001-供应商直接返给空调的外销-压缩机返利，
  法人计入空调，管理口径调给国际营销
  20260114 SXX新增
  */

  /*如果收入成本是以下条件的，才把对应字段进行在此列赋值
  收入成本表取数限制条件：
  ①公司范围：【COD_AZIENDA】
  限制公司为10-海信管理架构下 020节点-国际营销下所有公司
  ②科目范围限制【COD_CONTO】
  成本-S6401开头科目。*/

MERGE /*+ USE_HASH(A S)*/
INTO AW_MR9_REVM05_000001_TEMP A
USING (
    WITH
    -- CTE 1: 外销公司列表（硬编码，与原代码一致）
    -- 原代码中 COD_AZIENDA IN (...) 和 CTP_ORG NOT IN (...) 用的是同一组公司
    CTE_HW_AZI AS (
        SELECT '2000' AS COD_AZIENDA FROM DUAL UNION ALL
        SELECT '2080' FROM DUAL UNION ALL
        SELECT '2023' FROM DUAL UNION ALL
        SELECT '2300' FROM DUAL UNION ALL
        SELECT '2330' FROM DUAL UNION ALL
        SELECT '2900' FROM DUAL UNION ALL
        SELECT '2050' FROM DUAL UNION ALL
        SELECT '6012' FROM DUAL UNION ALL
        SELECT '6220' FROM DUAL UNION ALL
        SELECT '6210' FROM DUAL UNION ALL
        SELECT '6230' FROM DUAL UNION ALL
        SELECT '6300' FROM DUAL UNION ALL
        SELECT '6320' FROM DUAL UNION ALL
        SELECT '6330' FROM DUAL UNION ALL
        SELECT '6360' FROM DUAL UNION ALL
        SELECT '6370' FROM DUAL UNION ALL
        SELECT '6375' FROM DUAL UNION ALL
        SELECT '6515' FROM DUAL UNION ALL
        SELECT '6380' FROM DUAL UNION ALL
        SELECT '6012' FROM DUAL UNION ALL
        SELECT '6002' FROM DUAL UNION ALL          /*ALTER BY 20260828 10:57 XIAOYACHAO.EX 工厂端外销收入成本增加公司6002*/
        SELECT '6015' FROM DUAL                    /*ALTER BY 20261013 16:31 XIAOYACHAO.EX 工厂端外销收入成本增加公司6015*/
    ),
    -- CTE 2: DEST3 外销集合
    CTE_DEST3_HW AS (
        SELECT ELEM
          FROM SESSION_V_REF_DEST3_NONAME
         WHERE SESSION_ID = V_SESSION_ID
           AND NODE = 'HW'
    ),
    -- CTE 3: 锁定公司（两个UPDATE共用）
    CTE_LOCK_AZI AS (
        SELECT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001
         WHERE REV05_FLAG = 'Y'
           AND COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO = P_PERIODO
           AND COD_CONTO = 'ZAW_D2M_LOCK'
    ),
    -- CTE 4: 国际营销公司（第二个UPDATE用）
    CTE_IM_AZI AS (
        SELECT ELEM AS COD_AZIENDA
          FROM SESSION_V_REF_AZIENDA
         WHERE NODE = '020'
           AND SESSION_ID = V_SESSION_ID
    ),
    -- CTE 5: 排除的 DEST2（商显+日立利润中心）
    CTE_EXCL_DEST2 AS (
        SELECT ELEM
          FROM SESSION_V_REF_DEST2
         WHERE SESSION_ID = V_SESSION_ID
           AND NODE = '0103'
        UNION ALL
        SELECT '109080000' FROM DUAL UNION ALL
        SELECT '109081000' FROM DUAL UNION ALL
        SELECT '109083000' FROM DUAL UNION ALL
        SELECT '109082000' FROM DUAL UNION ALL
        SELECT '109071000' FROM DUAL UNION ALL
        SELECT '109072000' FROM DUAL UNION ALL
        SELECT '109073000' FROM DUAL UNION ALL
        SELECT '109074000' FROM DUAL UNION ALL
        SELECT '109075000' FROM DUAL UNION ALL
        SELECT '109076000' FROM DUAL UNION ALL
        SELECT '109077000' FROM DUAL UNION ALL
        SELECT '109087000' FROM DUAL UNION ALL
        SELECT '109091000' FROM DUAL
    ),
    -- CTE 6: 主查询 — 判断每行命中哪个UPDATE，预计算新值
    CTE_UPD AS (
        SELECT T.OID AS RID,
               -- 标志位：命中第一个UPDATE条件
               CASE WHEN EXISTS (SELECT 1 FROM CTE_HW_AZI H WHERE H.COD_AZIENDA = T.COD_AZIENDA)
                     AND EXISTS (SELECT 1 FROM CTE_DEST3_HW D WHERE D.ELEM = T.COD_DEST3)
                     AND NOT EXISTS (SELECT 1 FROM CTE_HW_AZI H WHERE H.COD_AZIENDA = NVL(T.COD_AZI_CTP_ORG, '|') AND H.COD_AZIENDA NOT IN  ('6002','6015')) /*ALTER BY 20261013 XIAOYACHAO.EX 剔除6015*/
                     /*ALTER BY 20261013 XIAOYACHAO.EX 只有冰箱剔除6015客户*/
                     AND (NVL(T.CUST_CODE, '|') NOT IN (/*'4000033',*/ '1010132') AND T.COD_AZIENDA NOT LIKE '63%'
                         OR T.COD_AZIENDA LIKE '63%'
                         )                   /*ALTER BY 20260902 XIAOYACHAO.EX 剔除万高客户*/
                     AND NVL(T.SRC_DETAIL, '-') <> 'ELIM'
                     AND SUBSTR(T.COD_CONTO, 1, 5) IN ('S6001', 'S6401')
                    THEN 'Y' ELSE 'N'
               END AS IS_HW_UPDATE,
               -- 标志位：命中第二个UPDATE条件
               CASE WHEN EXISTS (SELECT 1 FROM CTE_IM_AZI I WHERE I.COD_AZIENDA = T.COD_AZIENDA)
                     AND T.COD_CONTO LIKE 'S6401%'
                     AND NOT EXISTS (SELECT 1 FROM CTE_EXCL_DEST2 E WHERE E.ELEM = T.COD_DEST2)
                     AND NVL(T.SRC_DETAIL, '-') <> 'ELIM'
                    THEN 'Y' ELSE 'N'
               END AS IS_IM_UPDATE,
               -- 预计算第一个UPDATE的新值
               T.SALE_COGS,
               CASE WHEN T.COD_AZIENDA = '2080' THEN 0 ELSE T.ORG_REV END AS NEW_FAC_EXT_REV
          FROM AW_MR9_REVM05_000001_TEMP T
         WHERE T.COD_SCENARIO = P_SCENARIO
           AND T.COD_PERIODO  = P_PERIODO
           AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
         --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
           /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */
           AND T.PROVENIENZA IN ('CPM_SP_M2M_REV_M')  -- 两个UPDATE都要求
           AND (  -- 至少命中一个UPDATE条件才有意义
               (EXISTS (SELECT 1 FROM CTE_HW_AZI H WHERE H.COD_AZIENDA = T.COD_AZIENDA)
                AND SUBSTR(T.COD_CONTO, 1, 5) IN ('S6001', 'S6401'))
               OR
               (EXISTS (SELECT 1 FROM CTE_IM_AZI I WHERE I.COD_AZIENDA = T.COD_AZIENDA)
                AND T.COD_CONTO LIKE 'S6401%')
           )
    )
    SELECT RID,
           IS_HW_UPDATE,
           IS_IM_UPDATE,
           SALE_COGS,
           NEW_FAC_EXT_REV
      FROM CTE_UPD
     WHERE IS_HW_UPDATE = 'Y' OR IS_IM_UPDATE = 'Y'

) S
ON (A.OID = S.RID)
WHEN MATCHED THEN
    UPDATE SET
        -- 第一个UPDATE的字段（仅命中时赋值，否则保持原值）
        A.FAC_EXTERNAL_SALE_COST    = CASE WHEN S.IS_HW_UPDATE = 'Y' THEN S.SALE_COGS ELSE A.FAC_EXTERNAL_SALE_COST END,
        A.FAC_EXTERNAL_SALE_REVENUE = CASE WHEN S.IS_HW_UPDATE = 'Y' THEN S.NEW_FAC_EXT_REV ELSE A.FAC_EXTERNAL_SALE_REVENUE END,
        -- 第二个UPDATE的字段（仅命中时赋值，否则保持原值）
        A.IM_SALE_COST              = CASE WHEN S.IS_IM_UPDATE = 'Y' THEN S.SALE_COGS ELSE A.IM_SALE_COST END
;

COMMIT;

  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '8  外销成本处理', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '8  外销成本处理',P_AZIENDA);
    COMMIT;


  ------------------------------------------------------------------------------
  -- 9  计算合并销量、合并收入、合并成本
  ------------------------------------------------------------------------------


MERGE INTO AW_MR9_REVM05_000001_TEMP M
USING (


  SELECT    OID
          , CASE WHEN AZ_BG003.COD_AZIENDA IS NOT NULL AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6015'
                   THEN 0
                   ELSE NVL(AW.ENT_QTY,0) + NVL(AW.ENT_QTY_ADJ,0) + NVL(AW.ELIM_QTY,0) + NVL(AW.CADJ_QTY,0)
            END AS MANG_QTY
          , CASE WHEN AZ_BG003.COD_AZIENDA IS NOT NULL AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6015'
                   THEN 0
                 --EDIT BY LC 20261101 2910政策记账方式不同于内销，在此做一段特殊逻辑处理
                 WHEN NVL(AW.COD_AZIENDA,'|') = '2910' 
                   THEN NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) + NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0)
                   ELSE NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0)
            END AS MANG_REV --端到端收入-BG
          , CASE WHEN AZ_BG003.COD_AZIENDA IS NOT NULL AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6015'
                   THEN 0
                 --EDIT BY LC 20261101 2910政策记账方式不同于内销，在此做一段特殊逻辑处理
                 WHEN NVL(AW.COD_AZIENDA,'|') = '2910' 
                   THEN NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) + NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0)
                   ELSE NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0) + NVL(AW.FAC_CADJ_REV,0) + NVL(AW.CN_CADJ_REV,0)
            END AS FAC_MANG_REV  --工厂端收入-BU
          , CASE WHEN AZ_BG003.COD_AZIENDA IS NOT NULL AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6015'
                   THEN 0
                --EDIT BY LC 20261101 2910政策记账方式不同于内销，在此做一段特殊逻辑处理
                 WHEN NVL(AW.COD_AZIENDA,'|') = '2910' 
                   THEN NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) + NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0)
                   ELSE NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0)
            END AS IM_MANG_REV --国际营销收入-BU
          , CASE WHEN DEST3_HW.ELEM IS NOT NULL AND NVL(AW.SRC_DETAIL,'|') = 'HB_ADJM01'
                   THEN NVL(AW.IM_SALE_COST,0) + NVL(AW.END_UNREAL_GP,0)-NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.CADJ_COST,0)
                 WHEN DEST3_HW.ELEM IS NOT NULL AND NVL(AW.SRC_DETAIL,'|') <> 'ELIM'
                   THEN  NVL(AW.FAC_EXTERNAL_SALE_COST,0)
                      + NVL(AW.IM_SALE_COST,0)
                      + NVL(AW.END_UNREAL_GP,0)-NVL(AW.BEG_UNREAL_GP,0)+ NVL(AW.CADJ_COST,0)
                      + CASE WHEN AW.COD_AZIENDA in('1098','2910') AND NOT(AW.COD_SCENARIO='2026ACT' AND AW.COD_PERIODO='01')
                      --EDIT BY SXX 20261107 2910端到端合并成本逻辑，改成与1098一致
                                THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0)+ NVL(AW.CADJ_COST,0)
                            ELSE 0
                        END
                --非收入成本抵消来源处理-日立
                WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM' AND (AW.COD_AZIENDA LIKE '17%' OR AW.COD_AZIENDA IN ('6240'))
                  THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.CADJ_COST,0)
                --非收入成本抵消来源处理-冰冷洗 & 空调
                WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM' AND (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA IN ( '6000A','6000') OR AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%')
                  THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.CADJ_COST,0)
                --非收入成本抵消来源处理-显示
                WHEN /*SRC_DETAIL <> 'ELIM' AND */
                  (AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%' )
                  AND (NVL(AW.SRC_DETAIL,'|') <> 'ELIM'
                        OR (NVL(AW.SRC_DETAIL,'|') ='ELIM' AND AZ_BG001.COD_AZIENDA IS NOT NULL)
                      )
                  THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.VAR_ALLOC_COST,0) + NVL(AW.END_UNREAL_GP,0) - NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.CADJ_COST,0)
                --非收入成本抵消来源处理-非电冰空
                WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM'
                  THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0) + NVL(AW.END_UNREAL_GP,0) - NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.ELIM_COST,0) + NVL(AW.CADJ_COST,0)
                --外销 内部流转
                WHEN AW.SRC_DETAIL = 'ELIM' AND DEST3_HA0.ELEM IS NOT NULL AND
                  (
                    (
                        (AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%')
                    AND AZ_BG001.COD_AZIENDA IS NOT NULL
                    )
                    OR
                    (
                      (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA  IN ( '6000A','6000') ) AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR AW.COD_AZI_CTP_ORG IN ('6000A','6000'))
                    )
                    OR
                    (
                      (AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%')
                    )
                  )
                THEN NVL(AW.ELIM_COST,0)
              --收入成本抵消来源处理-统一
              WHEN AW.SRC_DETAIL = 'ELIM' AND
               NOT (
                      (
                        (AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%')
                        AND AZ_BG001.COD_AZIENDA IS NOT NULL
                      )
                      OR
                      (
                        (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000') )
                        /*ALTER BY 20260902 XIAOYACHAO.EX 交易对手剔除万高*/
                        /*ALTER BY 20261013 XIAOYACHAO.EX 交易对手剔除6015*/
                        AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR NVL(AW.COD_AZI_CTP_ORG,'|')  IN( '6000A','6000'/*,'6015','6002'*/))
                      )
                      OR
                      (
                        (AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%'  OR NVL(AW.COD_AZI_CTP_ORG,'|') IN( '6015') )
                      )
                   )
                THEN NVL(AW.ELIM_COST,0)
                ELSE 0
            END AS MANG_COST --端到端成本-BG
          , CASE
              --外销成本 非内部流转
              /*ALTER BY 20260831 XIAOYACHAO.EX 工厂端成本6002公司特殊处理*/
              WHEN DEST3_HW.ELEM IS NOT NULL AND AW.COD_AZIENDA = '6002' AND AW.COD_DEST2 = '101185000' THEN 0
              WHEN DEST3_HW.ELEM IS NOT NULL AND AW.COD_AZIENDA = '6002' THEN NVL(AW.FAC_EXTERNAL_SALE_COST,0) + NVL(AW.ELIM_COST,0)
              /*ALTER BY 20261013 XIAOYACHAO.EX 增加6015公司*/
              WHEN DEST3_HW.ELEM IS NOT NULL AND AW.COD_AZIENDA = '6015' AND AW.COD_DEST2 IN (SELECT V2.ELEM FROM TGK_FIMA_HISENSE.V_REF_DEST2 V2 WHERE LENGTH(V2.NODE) = 4 AND V2.NODE IN ('0117','0118','0119','0120','0121'))
                THEN NVL(AW.FAC_EXTERNAL_SALE_COST,0) + NVL(AW.ELIM_COST,0)
              /*ALTER BY 20260902 XIAOYACHAO.EX 我方是冰箱公司，交易对手是万高的取工厂端外销成本+抵消成本*/
              WHEN (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000') ) AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6002' THEN NVL(AW.FAC_EXTERNAL_SALE_COST,0) + NVL(AW.ELIM_COST,0)
              /*ALTER BY 20261013 XIAOYACHAO.EX 我方是冰箱公司，交易对手是6015的取工厂端外销成本+抵消成本*/
              WHEN (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000') ) AND NVL(AW.COD_AZI_CTP_ORG,'|') = '6015' THEN NVL(AW.FAC_EXTERNAL_SALE_COST,0) + NVL(AW.ELIM_COST,0)
              WHEN DEST3_HW.ELEM IS NOT NULL
                  AND
                    NOT (
                          ((AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%') AND (AZ_BG001.COD_AZIENDA IS NOT NULL))
                          OR
                          ((AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000') ) AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR NVL(AW.COD_AZI_CTP_ORG,'|')    IN( '6000A','6000')))
                          OR
                          ((AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%'))
                        )
                THEN NVL(AW.FAC_EXTERNAL_SALE_COST,0)
              --外销 内部流转
              WHEN AW.SRC_DETAIL = 'ELIM' AND DEST3_HA0.ELEM IS NOT NULL
                   AND
                  (
                      ((AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%') AND (AZ_BG001.COD_AZIENDA IS NOT NULL))
                      OR
                      ((AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000') ) AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR NVL(AW.COD_AZI_CTP_ORG,'|')    IN( '6000A','6000','6002'))) /*ALTER BY 20260902 XIAOYACHAO.EX 我方公司是冰箱，对方是6002万高也取抵消成本*/
                      OR
                      ((AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%'))
                  )
                THEN NVL(AW.ELIM_COST,0)
              --非收入成本抵消来源处理-日立
              WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM' AND (AW.COD_AZIENDA LIKE '17%' OR AW.COD_AZIENDA IN ('6240'))
                THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.CADJ_COST,0)
              --非收入成本抵消来源处理-冰冷洗 & 空调
              WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM' AND (AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%'  OR AW.COD_AZIENDA IN ( '6000A','6000') OR AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%')
                THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.CADJ_COST,0)

              --非收入成本抵消来源处理-显示
              WHEN (AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%' )
                THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.VAR_ALLOC_COST,0) + NVL(AW.END_UNREAL_GP,0) - NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.CADJ_COST,0)

              --非收入成本抵消来源处理-非电冰空
              WHEN NVL(AW.SRC_DETAIL,'|') <> 'ELIM'
                THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0) + NVL(AW.END_UNREAL_GP,0) - NVL(AW.BEG_UNREAL_GP,0) + NVL(AW.OTH_ASSESS_COST,0) + NVL(AW.ELIM_COST,0) + NVL(AW.CADJ_COST,0)

              --收入成本抵消来源处理-统一
              WHEN AW.SRC_DETAIL = 'ELIM' AND
              NOT (
                    ((AW.COD_AZIENDA LIKE '2%' OR AW.COD_AZIENDA LIKE '163%') AND (AZ_BG001.COD_AZIENDA IS NOT NULL))
                    OR
                    ((AW.COD_AZIENDA LIKE '63%' OR AW.COD_AZIENDA LIKE '67%' OR AW.COD_AZIENDA   IN ( '6000A','6000')) AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '63%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '67%'  OR NVL(AW.COD_AZI_CTP_ORG,'|') IN( '6000A','6000')))
                    OR
                    ((AW.COD_AZIENDA LIKE '62%' OR AW.COD_AZIENDA LIKE '68%') AND (NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '62%' OR NVL(AW.COD_AZI_CTP_ORG,'|')  LIKE '68%'))
                  )
              THEN NVL(AW.ELIM_COST,0)
              ELSE 0
          END AS FAC_MANG_COST --工厂端成本-BU
        , CASE
            --EDIT BY LC 20261019 非国际营销机1098公司按以下逻辑取数
            WHEN AZ_020.ELEM IS NULL AND AW.COD_AZIENDA NOT in ('1098') 
            THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0) + NVL(AW.CADJ_COST,0) + NVL(AW.ELIM_COST,0)
                    --外销成本
            WHEN DEST3_HW.ELEM IS NOT NULL
              THEN NVL(AW.IM_SALE_COST,0)
               + CASE WHEN AW.COD_AZIENDA in('1098') AND NOT(AW.COD_SCENARIO='2026ACT' AND AW.COD_PERIODO='01')
                        THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0) + NVL(AW.CADJ_COST,0)
                      ELSE 0
                 END/*20260302 1098 香港分 外销成本算到终端成本 后续2910 也需要增加  即 市场端外销成本 不限于国际营销的成本*/
                    --内销
            ELSE 0
          END AS IM_MANG_COST --国际营销成本-BU
        , NVL(AW.CN_MAP_ZUM,0) + NVL(AW.CN_ELIM_QTY,0) AS CN_MANG_QTY
        , CASE WHEN NVL(AW.COD_CONTO,'|') <> 'S600111'
                 THEN (NVL(AW.CN_ORG_REV,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.CN_ELIM_REV,0))
               ELSE 0
          END AS CN_MANG_REV
        , NVL(AW.CN_SALE_COGS,0) AS CN_MANG_COST
        , CASE WHEN AZ_010102.ELEM IS NOT NULL AND AZ_BG001_BG002.COD_AZIENDA IS NOT NULL
                THEN 0
               WHEN AW.COD_AZIENDA = '2900'
                THEN NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0)
                ELSE NVL(AW.ENT_REV,0) + NVL(AW.ENT_REV_ADJ,0) + NVL(AW.POLICY_AMT,0) - NVL(AW.POLICY_CASH_PD,0) + NVL(AW.ELIM_REV,0) + NVL(AW.CADJ_REV,0)
          END AS ASSESS_MANG_REV
        , CASE WHEN AZ_010102.ELEM IS NOT NULL AND AZ_BG001_BG002.COD_AZIENDA IS NOT NULL
                 THEN 0
               WHEN AW.COD_AZIENDA = '2900'
                THEN NVL(AW.ENT_QTY,0) + NVL(AW.ENT_QTY_ADJ,0)
                  ELSE NVL(AW.ENT_QTY,0) + NVL(AW.ENT_QTY_ADJ,0) + NVL(AW.ELIM_QTY,0) + NVL(AW.CADJ_QTY,0)
          END AS ASSESS_MANG_QTY
          /*20260827 SHIQINGFENG.EX 取消补充2900公司取数时排除ZZFT*/
        , CASE WHEN AW.COD_AZIENDA IN (/*'2900',*/'6012')
                /*20260804 SHIQINGFENG.EX 补充2900公司取数时排除ZZFT*/
                /*20260817 CHENDONG3.EX 新增6012公司同逻辑处理*/
                AND SRC_DETAIL <> 'ZZFT'
                 THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0)
               WHEN  AW.COD_AZIENDA IN ('2900')
                 THEN NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0)+NVL(ASSESS_NM_ALLOC_COST,0)
               WHEN AZ_010102.ELEM IS NOT NULL
                THEN CASE WHEN DEST3_HW.ELEM IS NOT NULL
                            THEN NVL(AW.CADJ_COST,0) + NVL(AW.ENT_COST,0) + NVL(AW.ENT_COST_ADJ,0)
                          WHEN DEST3_HW.ELEM IS NULL
                            THEN NVL(AW.DOM_PSI_COST,0) + NVL(AW.ASSESS_NM_ALLOC_COST,0)
                     END
              ELSE 0
          END AS ASSESS_MANG_COST
    FROM AW_MR9_REVM05_000001_TEMP AW
    LEFT JOIN (SELECT DISTINCT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG003_BU011') AZ_BG003
      ON AZ_BG003.COD_AZIENDA = AW.COD_AZIENDA
    LEFT JOIN (SELECT DISTINCT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE SESSION_ID = V_SESSION_ID AND HIE='01' AND NODE='HW') DEST3_HW
      ON DEST3_HW.ELEM = AW.COD_DEST3
    LEFT JOIN (SELECT DISTINCT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG = 'BG001_BU001') AZ_BG001
      ON AZ_BG001.COD_AZIENDA = AW.COD_AZI_CTP_ORG
    LEFT JOIN (SELECT DISTINCT ELEM FROM SESSION_V_REF_DEST3_NONAME WHERE SESSION_ID = V_SESSION_ID AND HIE='01' AND NODE='HA0') DEST3_HA0
      ON DEST3_HA0.ELEM = AW.COD_DEST3
    LEFT JOIN (SELECT DISTINCT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND  HIE = '10' AND NODE = '010102') AZ_010102
      ON AZ_010102.ELEM = AW.COD_AZIENDA
    LEFT JOIN (SELECT DISTINCT ELEM FROM SESSION_V_REF_AZIENDA WHERE SESSION_ID = V_SESSION_ID AND  HIE = '10' AND NODE = '020') AZ_020
      ON AZ_020.ELEM = AW.COD_AZIENDA
    LEFT JOIN (SELECT DISTINCT COD_AZIENDA FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001 WHERE COD_BG IN ('BG001_BU001','BG002_BU001')) AZ_BG001_BG002
      ON AZ_BG001_BG002.COD_AZIENDA = AW.COD_AZI_CTP_ORG
  WHERE AW.COD_SCENARIO=P_SCENARIO
  AND AW.COD_PERIODO=P_PERIODO
  AND AW.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
  --AND (INSTR(V_AZIENDA, AW.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
  --对于收入直接调整数据也要做相同逻辑处理 分摊没有物料的 回写反冲值也需要参与
  AND AW.PROVENIENZA IN ('CPM_SP_M2M_REV_M','INPUT_DEFORM','CPM_SP_ZZFT_M_T0','CPM_SP_BSFT_M_T0')  /* ALTER BY LIYIFAN1.EX 20261116 16:24:00 考核成本口径补日立分摊冲销行 */
  AND ( NVL(AW.SRC_DETAIL,'|') NOT IN ( 'CON_INP')
   --OR (AW.COD_SCENARIO='2026ACT' AND AW.COD_PERIODO='01'AND AW.COD_AZIENDA='6515' AND AW.SRC_DETAIL='CON_INP'AND AW.COD_CONTO='S600111')
  )
  /*20260226 新增排除锁定公司*/
/*          AND AW.COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   )*/
) T
ON (M.OID = T.OID)
WHEN MATCHED THEN
  UPDATE SET
        M.MANG_QTY = T.MANG_QTY
      , M.MANG_REV = T.MANG_REV
      , M.FAC_MANG_REV = T.FAC_MANG_REV
      , M.IM_MANG_REV = T.IM_MANG_REV
      , M.MANG_COST = T.MANG_COST
      , M.FAC_MANG_COST = T.FAC_MANG_COST
      , M.IM_MANG_COST = T.IM_MANG_COST
      , M.CN_MANG_QTY = T.CN_MANG_QTY
      , M.CN_MANG_REV = T.CN_MANG_REV
      , M.CN_MANG_COST = T.CN_MANG_COST
      , M.ASSESS_MANG_REV = T.ASSESS_MANG_REV
      , M.ASSESS_MANG_QTY = T.ASSESS_MANG_QTY
      , M.ASSESS_MANG_COST = T.ASSESS_MANG_COST
    ;

    COMMIT;

MERGE INTO AW_MR9_REVM05_000001_TEMP A
USING (
    WITH
    CTE_BG001 AS (
        SELECT DISTINCT COD_AZIENDA
          FROM TGK_FIMA_HISENSE.AW_RUL_ATSMAP_000001
         WHERE COD_BG = 'BG001_BU001'
           AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST A1
                                    WHERE SESSION_ID = V_SESSION_ID)
    ),
    -- CTE 2: 外销 DEST3 集合
    CTE_DEST3_HW AS (
        SELECT DISTINCT ELEM
          FROM SESSION_V_REF_DEST3_NONAME
         WHERE SESSION_ID = V_SESSION_ID
           AND HIE = '01'
           AND NODE = 'HW'
    ),
    -- CTE 3: 利润中心映射
    CTE_DEST2 AS (
        SELECT DISTINCT COD_DEST2
          FROM TGK_FIMA_HISENSE.AW_RUL_PCRMAP_000001
         WHERE COD_BG IN ('BG001_BU001', 'BG002_BU001')
    )/*,
    -- CTE 4: 锁定公司
    CTE_LOCK_AZI AS (
        SELECT DISTINCT COD_AZIENDA
          FROM AW_RUL_DWMCRS_000001
         WHERE REV05_FLAG = 'Y'
           AND COD_SCENARIO = P_SCENARIO
           AND COD_PERIODO = P_PERIODO
           AND COD_CONTO = 'ZAW_D2M_LOCK'
    )*/
    -- 主查询：筛选行 + 预计算所有新值（CASE 逻辑全部在此完成）
    SELECT T.OID AS OID,
           CASE WHEN NVL(T.SRC_DETAIL, '|') = 'ELIM' AND CTP_BG.COD_AZIENDA IS NOT NULL
                THEN NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
                   + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
                   + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
                   + NVL(T.ELIM_COST, 0)
                ELSE NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
                   + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
                   + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
           END AS NEW_FAC_EXT_COST,
           CASE WHEN NVL(T.SRC_DETAIL, '|') = 'ELIM' AND CTP_BG.COD_AZIENDA IS NOT NULL
                THEN NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
                   + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
                   + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
                   + NVL(T.ELIM_COST, 0)
                ELSE NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
                   + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
                   + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
           END AS NEW_FAC_MANG_COST,
           NVL(T.ENT_COST, 0) + NVL(T.ENT_COST_ADJ, 0)
         + NVL(T.OTH_ASSESS_COST, 0) + NVL(T.CADJ_COST, 0)
         + (NVL(-T.BEG_UNREAL_GP, 0) + NVL(T.END_UNREAL_GP, 0))
         + NVL(T.ELIM_COST, 0) AS NEW_MANG_COST
      FROM AW_MR9_REVM05_000001_TEMP T
      LEFT JOIN CTE_BG001 CTP_BG
             ON CTP_BG.COD_AZIENDA = NVL(T.COD_AZI_CTP_ORG, '|')
     WHERE T.COD_SCENARIO = P_SCENARIO
       AND T.COD_PERIODO = P_PERIODO
       AND T.COD_AZIENDA IN (SELECT COD_AZIENDA FROM CTE_BG001)
      --AND (INSTR(V_AZIENDA, T.COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
       AND EXISTS (SELECT 1 FROM CTE_DEST3_HW D WHERE D.ELEM = T.COD_DEST3)
       --AND EXISTS (SELECT 1 FROM CTE_BG001 S WHERE S.COD_AZIENDA = T.COD_AZIENDA)
       AND EXISTS (SELECT 1 FROM CTE_DEST2 P WHERE P.COD_DEST2 = T.COD_DEST2)
       AND NVL(T.SRC_DETAIL, '|') NOT IN ('CON_INP')
       /* AND NOT EXISTS (SELECT 1 FROM CTE_LOCK_AZI L WHERE L.COD_AZIENDA = T.COD_AZIENDA) */

) S
ON (A.OID = S.OID)
WHEN MATCHED THEN
    UPDATE SET
        A.FAC_EXTERNAL_SALE_COST = S.NEW_FAC_EXT_COST,
        A.FAC_MANG_COST          = S.NEW_FAC_MANG_COST,
        A.MANG_COST              = S.NEW_MANG_COST
;

    COMMIT;


  INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M', '9  计算合并销量、合并收入、合并成本', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '9  计算合并销量、合并收入、合并成本',P_AZIENDA);
    COMMIT;


 INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
  VALUES('CPM_SP_M2M_REV_M', '客商信息和物料信息补充更新开始', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '客商信息和物料信息补充更新',P_AZIENDA);
  COMMIT;

--20260522 新增客商信息和物料信息补充更新
MERGE  INTO AW_MR9_REVM05_000001_TEMP T
USING (

SELECT DISTINCT
       CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN MARA.product_name ELSE AW.MATERIAL_NAME END AS MATERIAL_NAME  --物料描述
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.market_pos_code,'ZZZZ') ELSE AW.D_MARKET_PNT END AS D_MARKET_PNT  --营销定位
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.prod_suite_code,'ZZZZ') ELSE AW.D_PRO_SSER END AS D_PRO_SSER  --产品套系
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(CASE WHEN MARA.big_class_code = 'P01' THEN MARA.SCREEN_SIZE_CODE
                          WHEN MARA.big_class_code = 'P02' THEN MARA.SPEC_RANGE_CODE
                          WHEN MARA.big_class_code = 'P03' THEN MARA.TOTAL_CAPACITY_CODE
                          WHEN MARA.big_class_code = 'P04' THEN MARA.WASHING_CAPACITY_CODE
                     END,'ZZZZ')
            ELSE AW.D_SPEC_SEC END AS D_SPEC_SEC  --规格
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.product_spec_code,'ZZZZ') ELSE AW.D_PRO_TYPE_S END AS D_PRO_TYPE_S  --产品形态分类
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.prod_stage_code,'ZZZZ') ELSE AW.D_PRO_STAGE END AS D_PRO_STAGE  --产品阶段
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.price_range_code,'ZZZZ') ELSE AW.D_PRI_RANGE END AS D_PRI_RANGE  --价格段
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.series_code,'ZZZZ') ELSE AW.D_PRO_SERIES END AS D_PRO_SERIES  --产品系列
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.ac_ct_code,'ZZZZ') ELSE AW.D_TECH_TYPE END AS D_TECH_TYPE  --技术类型
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN CASE WHEN MARA.is_miniled_code = 'PC00013001' THEN '是'
                      WHEN MARA.is_miniled_code = 'PC00013002' THEN '否'
                      ELSE ''
                 END
            ELSE AW.IS_MINILED_CODE END AS IS_MINILED_CODE  --是否MiniLED
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.small_class_code,'ZZZZ') ELSE AW.D_PRO_CLASS END AS D_PRO_CLASS  --产品类别（产品大中小类）
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(MARA.model_lca,'ZZZZ') ELSE AW.D_MODEL_LCA END AS D_MODEL_LCA  --产品型号生命周期
     , CASE WHEN NVL(LTRIM(AW.MATERIAL_CODE),'ZZZZ') <> 'ZZZZ'
            THEN '' ELSE AW.SALE_MODEL_NAME END AS SALE_MODEL_NAME  --销售型号
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
            THEN NVL(MARA.miniled_type_code,'ZZZZ') ELSE AW.D_MINILED END AS D_MINILED  --miniled类型
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
            THEN NVL(CUST_TRADE_INFO.MARKET_MODE_CODE,'ZZZZ') ELSE AW.D_MODE END AS D_MODE  --营销模式
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(CUST_INFO.channel_small_class_code,'ZZZZ') ELSE AW.D_CNL_C_TYPE END AS D_CNL_C_TYPE  --渠道客户小类
     , CASE WHEN NVL(LTRIM(AW.CUST_CODE),'ZZZZ') <> 'ZZZZ'
            THEN NVL(CUST_INFO.ind_small_class_code,'ZZZZ') ELSE AW.D_IND_C_TYPE END AS D_IND_C_TYPE  --行业客户小类
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
     --20260920FJF_ADD 二期新增字段
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
     , SALE_MODEL_NAME
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
   --20260920FJF_ADD 二期新增字段
     ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP
  FROM AW_MR9_REVM05_000001_TEMP PS
 WHERE COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
   AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0', 'CPM_SP_BSFT_M_T0')  /* ALTER BY LIYIFAN1.EX 20261116 16:24:00 补日立分摊来源 */
   /*20260226 新增排除锁定公司*/
   /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                            FROM AW_RUL_DWMCRS_000001 T
                           WHERE REV05_FLAG = 'Y'
                             AND T.COD_SCENARIO = P_SCENARIO
                             AND T.COD_PERIODO = P_PERIODO
                             AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                           ) */
   AND (SRC_DETAIL IN ('HB_ADJM01','POLICY_YT','ELIM') OR NVL(POLICY_AMT,0) <> 0)
) AW
LEFT JOIN (SELECT COD_AZIENDA,'S'||CITTA_LEGALE SAP_VERSION FROM tgk_fima_hisense.AZIENDA) AZ
  ON AW.COD_AZIENDA = AZ.COD_AZIENDA
LEFT JOIN
(
SELECT 'S'||MANDT AS SAP_VERSION,KUNNR,zkunnr_mdg,name1 FROM tgk_fima_hisense.DS_DWD_SAP_KNA1
) KNA1
  ON AZ.SAP_VERSION = KNA1.SAP_VERSION
 AND LTRIM(KNA1.kunnr,'0') = AW.CUST_CODE
LEFT JOIN
(
SELECT 'S'||MANDT AS SAP_VERSION,KUNNR,zkunnr_mdg,name1 FROM tgk_fima_hisense.DS_DWD_SAP_KNA1
) KNA1_sold
  ON AZ.SAP_VERSION = KNA1_sold.SAP_VERSION
 AND LTRIM(KNA1_sold.kunnr,'0') = AW.sold_to_code

LEFT JOIN tgk_fima_hisense.DIM_CUSTOMER_BASE_INFO_DD CUST_INFO
  ON LTRIM(KNA1.zkunnr_mdg,'0') = LTRIM(CUST_INFO.cust_code,'0')

LEFT JOIN tgk_fima_hisense.DIM_CUSTOMER_BASE_INFO_DD CUST_INFO_sold
  ON LTRIM(KNA1_sold.zkunnr_mdg,'0') = LTRIM(CUST_INFO_sold.cust_code,'0')

LEFT JOIN TGK_FIMA_HISENSE.DIM_FI_PRODUCT MARA
  ON MARA.matnr = AW.MATERIAL_CODE
LEFT JOIN tgk_fima_hisense.DIM_CUSTOMER_TRADE_INFO_DD CUST_TRADE_INFO
  ON LTRIM(KNA1.zkunnr_mdg,'0') = LTRIM(CUST_TRADE_INFO.cust_code,'0')
 AND AW.COD_AZIENDA = CUST_TRADE_INFO.sale_org
 AND CASE WHEN NVL(LTRIM(AW.MATERIAL_GROUP_CODE),'|') = '|' OR AW.MATERIAL_GROUP_CODE = 'ZZZZ'
           THEN CASE WHEN AZ.SAP_VERSION IN ('S600','S900') THEN REPLACE(REPLACE(REPLACE(mara.prod_line,'BP',''),'DS',''),'TA','')
                ELSE LTRIM(mara.matkl,'0')
                END
           ELSE AW.MATERIAL_GROUP_CODE
      END  = CUST_TRADE_INFO.material_group_code
LEFT JOIN (
  SELECT cust_code AS kunrg
        ,cp_company_code AS COD_AZI_CTP
        ,system_src AS system_src
    FROM tgk_fima_hisense.dim_rule_fi_mr_cust2ctp_mapping a
  WHERE cust_type_code = 'C'
    AND NVL(valid_fr,'202401') <= SUBSTR(P_SCENARIO,0,4)||P_PERIODO
    AND NVL(valid_to,'999999') >= SUBSTR(P_SCENARIO,0,4)||P_PERIODO
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
       T.MATERIAL_NAME      = C.MATERIAL_NAME             -- 物料描述
      ,T.D_MARKET_PNT       = C.D_MARKET_PNT              -- 营销定位
      ,T.D_PRO_SSER         = C.D_PRO_SSER                -- 产品套系
      ,T.D_SPEC_SEC         = C.D_SPEC_SEC                -- 规格
      ,T.D_PRO_TYPE_S       = C.D_PRO_TYPE_S              -- 产品形态分类
      ,T.D_PRO_STAGE        = C.D_PRO_STAGE               -- 产品阶段
      ,T.D_PRI_RANGE        = C.D_PRI_RANGE               -- 价格段
      ,T.D_PRO_SERIES       = C.D_PRO_SERIES              -- 产品系列
      ,T.D_TECH_TYPE        = C.D_TECH_TYPE               -- 技术类型
      ,T.IS_MINILED_CODE    = C.IS_MINILED_CODE           -- 是否MiniLED
      ,T.D_PRO_CLASS        = C.D_PRO_CLASS                -- 产品类别（产品大中小类）
      ,T.D_MODEL_LCA        = C.D_MODEL_LCA               -- 产品型号生命周期
      ,T.SALE_MODEL_NAME    = C.SALE_MODEL_NAME           -- 销售型号
      ,T.MODEL_CODE         = C.MODEL_CODE                 -- 产品型号编码
      ,T.MODEL_NAME         = C.MODEL_NAME                 -- 产品型号名称
      ,T.MATERIAL_GROUP_CODE= C.MATERIAL_GROUP_CODE        -- 物料组
      ,T.D_MINILED          = C.D_MINILED                  -- miniled类型
      ,T.customer_model     = C.customer_model             -- 客户型号
      ,T.CUST_NAME          = C.CUST_NAME                  -- 客商描述
      ,T.D_CHANNEL          = C.D_CHANNEL                  -- 公司三级分类
      ,T.D_MODE             = C.D_MODE                     -- 营销模式
      ,T.D_CNL_C_TYPE       = C.D_CNL_C_TYPE              -- 渠道客户小类
      ,T.D_IND_C_TYPE       = C.D_IND_C_TYPE              -- 行业客户小类
      ,T.CUST_UNITY_NAME    = C.CUST_UNITY_NAME           -- 统一客户组
      ,T.CREDIT_LEVEL_NAME  = C.CREDIT_LEVEL_NAME         -- 信用等级
      ,T.CUST_NATURE_NAME   = C.CUST_NATURE_NAME          -- 单位性质
      ,T.CUST_TYPE_NAME     = C.CUST_TYPE_NAME            -- 客户类型
      ,T.sold_to_name       = C.sold_to_name               -- 售达方名称
      --20260920FJF_ADD 二期新增字段
      , T.D_EFF_CLASS = nvl(C.D_EFF_CLASS,'ZZZZ')  --能效等级
      , T.D_BU_SHOP = nvl(C.D_BU_SHOP,'ZZZZ')   --门店所属BU
      , T.D_UNICUSTGRP = nvl(C.D_UNICUSTGRP,'ZZZZ') --统一客户组编码
;

UPDATE AW_MR9_REVM05_000001_TEMP T
   SET D_EFF_CLASS   = NVL(T.D_EFF_CLASS, 'ZZZZ'),
       D_BU_SHOP     = NVL(T.D_BU_SHOP, 'ZZZZ'),
       D_EC_STORE    = NVL(T.D_EC_STORE, 'ZZZZ'),
       D_UNICUSTGRP  = NVL(T.D_UNICUSTGRP, 'ZZZZ')
 WHERE T.COD_SCENARIO = P_SCENARIO
   AND T.COD_PERIODO  = P_PERIODO
   AND T.COD_AZIENDA IN (
         SELECT ELEM
           FROM SESSION_AZIENDA_LIST
          WHERE SESSION_ID = V_SESSION_ID
       )
  AND T.PROVENIENZA = 'CPM_SP_M2M_REV_M'
;
 COMMIT;
 
 
 

INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
VALUES('CPM_SP_M2M_REV_M', '二期新增维度处理', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '二期新增维度处理',P_AZIENDA);
COMMIT;
  
--20261022fjf_add REV005_STEP_999 二期新增维度处理
MERGE INTO AW_MR9_REVM05_000001_TEMP T
USING(
    SELECT S.OID,
      NVL(BMU.BMU_CODE, S.D_SALE_DEPT) AS D_SALE_DEPT,
      CASE WHEN S.COD_AZIENDA = '6700' AND S.CUST_CODE IN ('2171731', '2112453', '2020217', '2059117')
          THEN 'S101'
        ELSE NVL(BR.D_BRANCH,'ZZZZ')
      END AS D_BRANCH,
      NVL(CH.CHANNEL_BU_CODE,'ZZZZ') AS D_CHANNEL_BU,
      CASE WHEN S.COD_AZIENDA = '1180' OR S.COD_AZIENDA LIKE '12%'
          THEN CASE WHEN S.CN_CLASS_MARK_CODE = 'Z1' THEN '1' ELSE '2' END
         ELSE CASE WHEN S.D_UNICUSTGRP = 'T0076' THEN '1' ELSE '2' END
      END AS D_STORE_TYPE
    FROM(
        SELECT OID,D_SALE_DEPT,COD_AZIENDA,CUST_CODE,D_CHANNEL,COD_DEST2,CN_CLASS_MARK_CODE,D_UNICUSTGRP
        FROM AW_MR9_REVM05_000001_TEMP T
        WHERE T.COD_SCENARIO = P_SCENARIO
        AND T.COD_PERIODO  = P_PERIODO
        AND T.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST WHERE SESSION_ID = V_SESSION_ID )
      )S
    LEFT JOIN 
    (
      SELECT DISTINCT PROFITCENTER_CODE, BMU_CODE
      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_BMU_TO_PROFITCENTER
      WHERE DIM_FLAG = '01'
    ) BMU
    ON BMU.PROFITCENTER_CODE = S.COD_DEST2
    LEFT JOIN 
    (
      SELECT DISTINCT COD_AZIENDA, D_BRANCH
      FROM TGK_FIMA_HISENSE.DIM_RULE_FI_MR_AZIENDA_MAPPING_BRANCH
      WHERE D_BRANCH <> 'SI01'
    ) BR
    ON BR.COD_AZIENDA = S.COD_AZIENDA
    LEFT JOIN 
    (     
      SELECT DISTINCT CHANNEL_BU_CODE,COM_3RD_CODE
      FROM TGK_FIMA_HISENSE.DIM_RULE_MRS_MR3_CHANNEL_BU_RELATION
    ) CH
    ON CH.COM_3RD_CODE = S.D_CHANNEL
  ) SRC
ON (T.OID = SRC.OID)
WHEN MATCHED THEN UPDATE SET
    T.D_SALE_DEPT  = SRC.D_SALE_DEPT,
    T.D_BRANCH     = SRC.D_BRANCH,
    T.D_CHANNEL_BU = SRC.D_CHANNEL_BU,
    T.D_STORE_TYPE = SRC.D_STORE_TYPE
;


INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
  VALUES('CPM_SP_M2M_REV_M', '临时表处理', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '临时表处理完成,插入aw表开始',P_AZIENDA);
  COMMIT;
    DELETE FROM AW_MR9_REVM05_000001
    WHERE COD_SCENARIO = P_SCENARIO
     AND COD_PERIODO = P_PERIODO
     AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
     --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
     AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0', 'CPM_SP_BSFT_M_T0')  /* ALTER BY LIYIFAN1.EX 20261116 16:24:00 正式表 DELETE 补日立分摊来源 */
      /*20260226 新增排除锁定公司*/
      /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   ) */
          ;

  INSERT INTO AW_MR9_REVM05_000001
  (OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT, D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST, AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST, DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL, FAC_EXTERNAL_SALE_COST, FAC_EXTERNAL_SALE_REVENUE, IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY, CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST, ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY, FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY,D_MINILED,ASSESS_MANG_COST,ASSESS_MANG_REV,ASSESS_MANG_QTY
  ,D_BUS_SCE_S,ASSESS_NM_ALLOC_COST,STD_QTY,MA_SALE_COGS, SHIPPING_ORDER
  --20260920FJF_ADD 二期新增字段
  ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP,D_BRANCH,D_CHANNEL_BU
  )

  SELECT NEWID() OID, COD_SCENARIO, COD_PERIODO, SRC_DETAIL, COD_CONTO, COD_AZIENDA, COD_DEST2, COD_DEST3, COD_DEST4, AGENCY_CODE, AGENCY_NAME, CUST_CODE, CUST_NAME, D_SALE_DEPT, D_CHANNEL, D_MODE, D_ONOFFLINE, D_CNL_C_TYPE, D_IND_C_TYPE, D_ECOM_BU, D_MARKET_PNT, D_PRO_SSER, D_SPEC_SEC, D_PRO_TYPE_S, D_PRO_STAGE, D_PRI_RANGE, D_PRO_SERIES, D_TECH_TYPE, D_PRO_CLASS, D_MODEL_LCA, D_PRO_TYPE, D_PRC_GRP, D_POL_CLASS, CUST_UNITY_NAME, CREDIT_LEVEL_NAME, CUST_NATURE_NAME, CUST_TYPE_NAME, SOLD_TO_CODE, SOLD_TO_NAME, MATERIAL_CODE, MATERIAL_NAME, IS_MINILED_CODE, SALE_MODEL_CODE, SALE_MODEL_NAME, MODEL_CODE, MODEL_NAME, BATCH_ID, MATERIAL_GROUP_CODE, SHOP_CODE, SHOP_NAME, MAP_QTY, ORG_REV, POLICY_AMT, ASSESSED_REV, SALE_COGS, BEG_UNREAL_GP, END_UNREAL_GP, COMB_COST, AVG_UNIT_COST, COMB_COST_AVG, PSI_COMB_COST, WTD_UNIT_COST, DOM_PSI_COST, OTH_ASSESS_COST, PROVENIENZA, USERUPD, DATEUPD, EN_VERSION, POLICY_CASH_PD, COD_CATEGORIA, CUSTOMER_MODEL, FAC_EXTERNAL_SALE_COST, FAC_EXTERNAL_SALE_REVENUE, IM_SALE_COST, COD_AZI_CTP, MANG_COST, D_DATA_BLOCK, D_DIFF_TYPE, D_ADJ_TYPE, CN_CLASS_MARK_CODE, CN_CLASS_MARK_NAME, SALE_CERT_TYPE, CN_SALE_COGS, CN_ORG_REV, CN_MAP_ZUM, COD_AZI_CTP_ORG, D_OPER_TYPE, ELIM_COST, ELIM_REV, COMB_REV, MANG_REV, ENT_QTY, ENT_QTY_ADJ, ELIM_QTY, CADJ_QTY, MANG_QTY, ENT_REV, ENT_REV_ADJ, CADJ_REV, ENT_COST, ENT_COST_ADJ, CADJ_COST, CN_ELIM_QTY, CN_MANG_QTY, CN_ELIM_REV, CN_MANG_REV, CN_ELIM_COST, CN_MANG_COST, BU_MANG_COST, FAC_MANG_COST, IM_MANG_COST, NOTE, ORG_QTY, FAC_MANG_REV, IM_MANG_REV, FAC_CADJ_REV, CN_CADJ_REV, VAR_ALLOC_COST, COD_DEST1, BILL_QTY ,D_MINILED,ASSESS_MANG_COST,ASSESS_MANG_REV,ASSESS_MANG_QTY
    ,D_BUS_SCE_S,ASSESS_NM_ALLOC_COST,STD_QTY,MA_SALE_COGS, SHIPPING_ORDER
    --20260920FJF_ADD 二期新增字段
    ,D_EFF_CLASS,D_BU_SHOP,D_EC_STORE,D_UNICUSTGRP,D_BRANCH,D_CHANNEL_BU
  FROM AW_MR9_REVM05_000001_TEMP
    WHERE COD_SCENARIO = P_SCENARIO
   AND COD_PERIODO = P_PERIODO
   AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                    WHERE SESSION_ID = V_SESSION_ID
                              )
   --AND (INSTR(V_AZIENDA, COD_AZIENDA) > 0 OR P_AZIENDA = 'ALL')
   AND PROVENIENZA IN ('CPM_SP_M2M_REV_M', 'CPM_SP_ZZFT_M_T0', 'CPM_SP_BSFT_M_T0')  /* ALTER BY LIYIFAN1.EX 20261116 16:24:00 正式表 INSERT 补日立分摊冲销行 */
          /*20260226 新增排除锁定公司*/
          /* AND COD_AZIENDA NOT IN (SELECT COD_AZIENDA
                  FROM AW_RUL_DWMCRS_000001 T
                 WHERE REV05_FLAG = 'Y'
                   AND T.COD_SCENARIO = P_SCENARIO
                   AND T.COD_PERIODO = P_PERIODO
                   AND T.COD_CONTO = 'ZAW_D2M_LOCK'
                   ) */
          ;
INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
  VALUES('CPM_SP_M2M_REV_M', '临时表插入AW', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '插入完成',P_AZIENDA);
  COMMIT;

--用于获取外销成本-高低开及预分成调整数
CPM_SP_M2M_REVADJ_M(P_SCENARIO,P_PERIODO,SESSION_USER);

--EDIT BY LC 260302 空调配套数据生成
IF V_ENTITY = 'KT' OR P_AZIENDA = 'ALL' THEN
   CPM_SP_M2M_ZSET_M(P_SCENARIO,P_PERIODO,SESSION_USER);
END IF;

--ADD BY YH 20260405 新增调用CPM_SP_M2M_OPL_SUP程序
 CPM_SP_M2M_OPL_SUP(P_SCENARIO,P_PERIODO,SESSION_USER);


  /*20261026 新增：事业部编码 / 是否事业部 / 是否产销存 —— 落表后回刷，不动 INSERT 结构
    ① 公司码按层级规则匹配 AW_RUL_MAGPCR_000001：NODE_ELEMENT_FLAG='N' 是层级编码（走 NODE 展开），
       'E' 是具体公司码（走 ELEM 等值），不能简单等值；有效期按 VALID_FR / VALID_TO 卡 YYYYMM。
    ② 命中后取 COD_BG，再用 AW_RUL_PCRMAP_000001（同期间有效）换出该事业部的利润中心范围。
    ③ 本行 COD_DEST2 落在范围内 → 写 COD_BG 并打 IS_BG_PL='Y'；不在范围内 → 两列留空。
    ④ IS_PSC 只看公司是否命中，直接取配置值，与利润中心无关。

    ★ 20261027 性能重构（V4.2）：原「IS_PSC 一条 + COD_BG/IS_BG_PL 一条」两段 UPDATE，合并为一条
      ROWID 驱动的 MERGE，结果逐行等价。原写法三个瓶颈：
      · 目标表整表扫 2 次、整表写 2 次（本表 130+ 列，undo/redo 与索引维护成本翻倍）；
      · WHERE 命中的每一行都要跑一次标量子查询，派生表（MAGPCR × SESSION_V_REF_AZIENDA，再 join
        PCRMAP）逐行重算；标量子查询缓存只按关联列 (COD_AZIENDA / COD_AZIENDA+COD_DEST2) 命中，
        公司×利润中心组合越多重算次数越多 —— 这是主要耗时；
      · 有效期比较 SUBSTR(P_SCENARIO,1,4)||LPAD(P_PERIODO,2,'0') 每行、每处 NVL 各算一遍，表达式不可索引。
      现写法：两个映射派生表在 USING 里各算一次（hash join 到目标表），目标表只扫 1 次、只写 1 次，
        MERGE 按 ROWID 定位不再二次扫描；再加 UPDATE ... WHERE「新旧值不同才写」，未命中且原本为空的行走不到写。
      有效期统一用 v_per0（SP 内已有 = SUBSTR(P_SCENARIO,1,4)||P_PERIODO；P_PERIODO 为两位月份，
        与原 LPAD 写法等价，且本程序其余 100+ 处都是这个口径）。
      ? 原注释担心「合在一条里 IS_PSC 会一并被冲成空」只对 SET (A,B) = (SELECT ...) 元组写法成立；
        这里三列各自独立赋值，公司未命中时 IS_PSC 为空，与拆开写结论完全一致。
      ? 两个 LEFT JOIN 的派生表都按主键收敛（GROUP BY AZI_CODE / AZI_CODE,PCR_CODE），每个 ROWID 在
        USING 里只出现一次，不会 ORA-30926、不放大行数。
      ? 本段属「USING 内扫目标表取 ROWID + MERGE 定位更新」；若该表后续改成分区键变动/GTT，需复测。*/

  MERGE INTO AW_MR9_REVM05_000001 T
  USING (
      SELECT T2.ROWID              AS RID
           , PSC.IS_PSC_V          AS IS_PSC
           , BG.PCR_CODE           AS PCR_CODE
           , BG.BG_CODE            AS BG_CODE
        FROM AW_MR9_REVM05_000001 T2
        LEFT JOIN (
             /* 公司级映射：公司 → 是否产销存。同一公司多条配置取 MAX，与原标量子查询一致 */
             SELECT AZI_CODE, MAX(IS_PSC_V) AS IS_PSC_V
               FROM (SELECT DISTINCT V.ELEM AS AZI_CODE, C.IS_PSC AS IS_PSC_V
                       FROM TGK_FIMA_HISENSE.AW_RUL_MAGPCR_000001 C
                       JOIN SESSION_V_REF_AZIENDA V
                         ON V.SESSION_ID = V_SESSION_ID
                        AND V.HIE = '01'
                        AND (   (C.NODE_ELEMENT_FLAG = 'N' AND V.NODE = C.COMPANY_CODE)
                             OR (C.NODE_ELEMENT_FLAG = 'E' AND V.ELEM = C.COMPANY_CODE))
                      WHERE NVL(C.VALID_FR, '000000') <= v_per0
                        AND NVL(C.VALID_TO, '999999') >= v_per0
                    )
              GROUP BY AZI_CODE
          ) PSC
          ON PSC.AZI_CODE = T2.COD_AZIENDA
        LEFT JOIN (
             /* 公司 + 利润中心级映射：命中才有 COD_BG；未命中 COD_BG / IS_BG_PL 一律为空 */
             SELECT AZ.COD_AZIENDA AS AZI_CODE, PM.COD_DEST2 AS PCR_CODE, MAX(AZ.COD_BG) AS BG_CODE
               FROM (SELECT DISTINCT V.ELEM AS COD_AZIENDA, C.COD_BG
                       FROM TGK_FIMA_HISENSE.AW_RUL_MAGPCR_000001 C
                       JOIN SESSION_V_REF_AZIENDA V
                         ON V.SESSION_ID = V_SESSION_ID
                        AND V.HIE = '01'
                        AND (   (C.NODE_ELEMENT_FLAG = 'N' AND V.NODE = C.COMPANY_CODE)
                             OR (C.NODE_ELEMENT_FLAG = 'E' AND V.ELEM = C.COMPANY_CODE))
                      WHERE NVL(C.VALID_FR, '000000') <= v_per0
                        AND NVL(C.VALID_TO, '999999') >= v_per0
                    ) AZ
               JOIN (SELECT DISTINCT COD_BG, COD_DEST2
                       FROM TGK_FIMA_HISENSE.AW_RUL_PCRMAP_000001
                      WHERE NVL(VALID_FR, '000000') <= v_per0
                        AND NVL(VALID_TO, '999999') >= v_per0
                    ) PM
                 ON PM.COD_BG = AZ.COD_BG
              GROUP BY AZ.COD_AZIENDA, PM.COD_DEST2
          ) BG
          ON BG.AZI_CODE = T2.COD_AZIENDA
         AND BG.PCR_CODE = T2.COD_DEST2
       WHERE T2.COD_SCENARIO = P_SCENARIO
         AND T2.COD_PERIODO  = P_PERIODO
         AND T2.COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                                 WHERE SESSION_ID = V_SESSION_ID)
  ) S
  ON (T.ROWID = S.RID)
  WHEN MATCHED THEN UPDATE
     SET T.IS_PSC   = S.IS_PSC
       , T.COD_BG   = S.BG_CODE
       , T.IS_BG_PL = CASE WHEN S.PCR_CODE IS NOT NULL THEN 'Y' END
   /* 只写「新旧值不同」的行：新值有 → 写；旧值有而新值为空 → 写（清空，与原 UPDATE 全表置空等价）；
      新旧都为空 → 不写，省掉一次行版本。*/
   WHERE S.IS_PSC   IS NOT NULL
      OR S.PCR_CODE IS NOT NULL
      OR T.IS_PSC   IS NOT NULL
      OR T.COD_BG   IS NOT NULL
      OR T.IS_BG_PL IS NOT NULL
  ;
  COMMIT;

INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
  VALUES('CPM_SP_M2M_REV_M', '更新正式表数据-管法显差所需FLAG', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '更新完成',P_AZIENDA);
  COMMIT;

DELETE
   FROM AW_MR9_REVM01_000001_CON_TEMP T
  WHERE --SUBSTR(T.COD_SCENARIO,1,4) || T.COD_PERIODO IN (v_per0, v_per1, v_per2)
    1=1
    AND (
           (T.COD_SCENARIO = v_per0_ACT
          AND T.COD_PERIODO = v_per0_per
           )
          OR
           (T.COD_SCENARIO = v_per1_ACT
          AND T.COD_PERIODO = v_per1_per
          )
          OR
           (T.COD_SCENARIO = v_per2_ACT
          AND T.COD_PERIODO = v_per2_per
          )
        )
    AND COD_AZIENDA IN (SELECT ELEM FROM SESSION_AZIENDA_LIST
                    WHERE SESSION_ID = V_SESSION_ID
                    )
    ;
-- 删除本 Session 数据
DELETE FROM TMP_TABLE_POLICY_ALLOC
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM TMP_TABLE_POLICY
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM TMP_TABLE_ENT
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_V_REF_AZIENDA
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_V_REF_DEST3_NONAME
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_V_REF_DEST2
WHERE SESSION_ID = V_SESSION_ID;
DELETE FROM SESSION_AZIENDA_LIST
WHERE SESSION_ID = V_SESSION_ID;


/* 记录日志 */
INSERT INTO ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, REMARK,COD_AZIENDA)
  VALUES('CPM_SP_M2M_REV_M', '99 ENDT', SYSDATE, SESSION_USER, P_SCENARIO, P_PERIODO, '计算完成',P_AZIENDA);

  COMMIT;




/*    EXCEPTION
    WHEN OTHERS THEN
    ROLLBACK;
    V_ERROR_COD:=SQLCODE;
    V_ERROR_MSG:=SQLERRM;
    INSERT INTO ZTAB_CPM_LOG(CPM,STEP,EXECTIME,CREATEBY,COD_SCENARIO,COD_PERIODO,COD_AZIENDA)
    VALUES('CPM_SP_M2M_REV_M',SUBSTR(V_ERROR_COD||V_ERROR_MSG,1,1000),SYSDATE,SESSION_USER,P_SCENARIO,P_PERIODO,P_AZIENDA);
    COMMIT;*/


END ;
