# -*- coding: utf-8 -*-
import openpyxl, re

SRC = '/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/草稿/经分二期-应收-数据模型详细设计文档.xlsx'
wb = openpyxl.load_workbook(SRC, data_only=True)


def g(ws, r, c):
    v = ws.cell(r, c).value
    return '' if v is None else str(v).strip()


def clean(s):
    return re.sub(r'\s+', ' ', s).replace('|', '/').strip()


def parse_type(t):
    t = t.strip()
    m = re.match(r'(varchar2?|number|date|decimal\w*|int\w*)\s*\(?([\d,]*)\)?', t, re.I)
    if not m:
        return (t.upper(), '')
    tn = m.group(1).upper()
    ln = m.group(2) or ''
    if tn.startswith('VARCHAR'):
        tn = 'VARCHAR2'
    if tn.startswith('DECIMAL') or tn.startswith('INT'):
        tn = 'NUMBER'
    return (tn, ln)


out = []
W = out.append

# ================= ARPM01 =================
ws1 = wb['ARPM01账龄计算底稿-STEP1数据聚合']
W('#### AW_MR9_ARPM01_000001')
W('**说明**: 往来账龄计算底稿；DWM 层 STEP1 数据聚合，将 D 层往来账龄汇总推到 M 层，并汇总出库未开与退货未办数据')
W('**存储过程**: `CPM_SP_D2M_ARP_M`')
W('**数仓分层**: DWM ｜ **表类型**: 事实表 ｜ **更新方式**: 增量更新 ｜ **数仓目录**: 管理财经 → 财报管理 → 应收')
W('**参数**: 场景 `P_SCENARIO`、期间 `P_PERIODO`、公司 `P_AZIENDA`、用户 `SESSION_USER`')
W('**源表(7路)**: ①`dwd_fi_mr_arap_sum_mi`（主，往来账龄明细）②`AW_MR9_REVM01_000001`（单体销售明细，出库/退货）'
  '③`dwd_fi_mr_ar_overdue_mi`（超期款）④`dwd_fi_mr_arap_sum_mi`（提前回款）⑤`dwd_fi_mr_arap_sum_mi`（电商零售销售节奏）'
  '⑥`dwd_fi_mr_arap_sum_mi`（欠付费用）⑦`dwd_fi_mr_arap_sum_mi`（欠付返利）')
W('**抽取范围限制**: ①`is_apar_flag` 为 Y 或为空；②公司限制在 `AW_RUL_DWMCRS_000001` 中 `ARP_FLAG` 为 Y 的 `COD_AZIENDA` 范围内')
W('**数据分类(SRC_DETAIL)取值**: `ZTSO04_CK-出库未开`（S600101%）、`ZTSO04_TH-退货未办`（S600102%）、`overdue-超期款`、'
  '`inv_sample-开票样机额度`、`epay-提前回款`、`ECLS-电商零售`、`ufee-欠付费用`、`ureb-欠付返利`，其余为 `ORG%` 原始往来')
# STEP2 / STEP3 补充规则（STEP1 中留空的字段在此定义）
EXTRA_RULE = {
    'COD_AZIENDA': '按《账龄表进数范围维护》按取数类型剔除：EX1-按公司+客商剔除；EX2-按公司+科目剔除；'
                   'EX3-按系统号+科目剔除；IN1-按系统号+公司+科目取数',
    'LE_AGE_FLAG': '重分类函数 `F_APAR_REC`：按 系统号+公司+科目范围+主户 匹配，判断同一账套+主户编码下 '
                   '数据分类为 BS% 和总账标识（FAGLFLEXT/GLFUNCT）的 bcy_amt 汇总是否符合金额条件，输出【重分类标识】',
    'ME_AGE_FLAG': '重分类函数 `F_APAR_REC`：口径同法人，但汇总范围额外包含 `ZTSO04%`（出库未开/退货未办）',
    'MB_AGE_FLAG': '重分类函数 `F_APAR_REC`：口径同管理单体，且汇总粒度增加【利润中心】',
    'GRP_SCOPE':   '按场景期间公司取视图 `V_APAR_ELEM_NODE_TAB` 得到 node（日立公司取 nodes）与 hq，'
                   '再用对方公司匹配该视图：node 与 hq 均相等 → `SUB-子公司`；仅 hq 相等 → `GIN-集团内`；'
                   '其余 → `GEX-集团外`',
}

W('')
W('| 字段名 | 类型 | 长度/精度 | 可空 | 含义 | 取数来源与规则 |')
W('|--------|------|-----------|------|------|----------------|')
for r in range(9, ws1.max_row + 1):
    name = g(ws1, r, 3)
    if not name:
        continue
    typ, ln = parse_type(g(ws1, r, 4))
    nul = 'Y' if g(ws1, r, 7) else 'N'
    desc = clean(g(ws1, r, 6)) or clean(g(ws1, r, 2))
    rule = clean(g(ws1, r, 13))
    tab = clean(g(ws1, r, 15))
    fld = clean(g(ws1, r, 16))
    parts = []
    if rule == '直接对应':
        if tab and fld:
            parts.append('直接对应 ' + tab + '.' + fld)
        elif fld:
            parts.append('直接对应 ' + fld)
        else:
            parts.append('直接对应')
    elif rule:
        parts.append(rule)
    if name in EXTRA_RULE:
        parts.append('STEP2/3：' + EXTRA_RULE[name])
    r2 = clean(g(ws1, r, 22))
    t2 = clean(g(ws1, r, 24))
    f2 = clean(g(ws1, r, 25))
    if t2 or r2:
        seg = [x for x in (t2, f2, r2) if x]
        parts.append('出库/退货路：' + ' '.join(seg))
    r3 = clean(g(ws1, r, 31))
    t3 = clean(g(ws1, r, 33))
    f3 = clean(g(ws1, r, 34))
    if t3 or r3:
        seg = [x for x in (t3, f3, r3) if x]
        parts.append('超期款路：' + ' '.join(seg))
    rule_txt = '；'.join(parts)
    if len(rule_txt) > 300:
        rule_txt = rule_txt[:300] + '…'
    W('| ' + name + ' | ' + typ + ' | ' + ln + ' | ' + nul + ' | ' + desc + ' | ' + rule_txt + ' |')
    # 在 COD_AZIENDA 后插入 STEP3 定义的 COD_CONTO
    if name == 'COD_AZIENDA':
        W('| COD_CONTO | VARCHAR2 | 30 | Y | 科目 | STEP2/3：由 `LE_AGE_FLAG` 映射，'
          'AR→1122000000、OR→122101F、AS→1123000000、CA→1460000000、RF→1124001000、AP→2202000000、'
          'OP→224199F、AC→2203000000、CL→2204000000、A9→1910000A70、A10→1531000000；'
          '源头取 `dwd_fi_mr_arap_sum_mi.acct_map_code` |')
W('')
W('**STEP3 重分类补充字段**（ARPM02 引用，STEP1 页未列出，取自 STEP3 页）：')
W('')
W('| 字段名 | 类型 | 长度/精度 | 可空 | 含义 | 取数来源与规则 |')
W('|--------|------|-----------|------|------|----------------|')
W('| IS_REC_LG | VARCHAR2 | 5 | Y | 是否重分类_法人 | 重分类函数 `F_APAR_REC`：按 系统号+公司+科目范围+主户 匹配，'
  '判断同一账套+主户编码下数据分类为 BS% 和总账标识（FAGLFLEXT/GLFUNCT）的 bcy_amt 汇总是否符合金额条件，输出【是否重分类】 |')
W('| IS_REC_ME | VARCHAR2 | 5 | Y | 是否重分类_管理 | 同 `IS_REC_LG`，汇总范围额外包含 `ZTSO04%` |')
W('| IS_REC_MB | VARCHAR2 | 5 | Y | 是否重分类_管理分公司 | 同 `IS_REC_ME`，汇总粒度增加【利润中心】 |')
W('')
W('> **注1**: `ACCT_REC_CODE`（重分类科目编码）按原始科目判断合并，核心规则：`ACCT_SRC_CODE LIKE '
  "'1466%' → `1466000000`；公司 `6500/6510` 且原始科目 `2241010100/2241010200/2241020000/2241040000` → `2241010100`。")
W('> **注2**: `D_ADJ_TYPE`（调整类型）默认填 `ZZZZ`；`COD_CATEGORIA`（类别）各路统一填 `ZAMOUNT`。')
W('> **注3**: 出库/退货路（来源②）金额汇总自 `AW_MR9_REVM01_000001` 的 `BCY_REV`（本位币）/`ORG_REV`（交易币），按同一维度聚合；'
  '`SRC_DETAIL` 由 `COD_CONTO` 判断，S600101% → `ZTSO04_CK-出库未开`，S600102% → `ZTSO04_TH-退货未办`。')
W('> **注4**: 超期款路（来源③）同一金额拆两行展示：`overdue_amt` → `overdue-超期款`，`inv_sample_amt` → `inv_sample-开票样机额度`；'
  '该路仅提供 `BCY_0_AMT`/`QCY_0_AMT`（本月账龄段），其余账龄段不适用。')
W('> **注5**: 提前回款路（来源④）`SRC_DETAIL` 固定 `epay-提前回款`，核心过滤为 `ods_src` 属 bsid/bsad 且 `pay_reason_code=400`、'
  '`acct_map_code` 为 1122%，并按 `baseline_dt` 判断；电商零售路（来源⑤）固定 `ECLS-电商零售` 且排除《电商零售客户》范围内客户。')
W('')

# ================= ARPM02 =================
ws2 = wb['ARPM02-账龄结果表']
W('#### AW_MR9_ARPM02_000001')
W('**说明**: 往来账龄结果表；DWM 层，将计算底稿 `AW_MR9_ARPM01_000001` 中不同数据分类的数据平铺到列上展示，'
  '并对应收重分类到合同负债的数据剔除对应税额')
W('**存储过程**: `CPM_SP_M2M_ARP_AG_M`')
W('**数仓分层**: DWM ｜ **表类型**: 事实表 ｜ **更新方式**: 增量更新 ｜ **数仓目录**: 管理财经 → 财报管理 → 应收')
W('**参数**: 场景 `P_SCENARIO`、期间 `P_PERIODO`、公司 `P_AZIENDA`、用户 `SESSION_USER`')
W('**源表**: `AW_MR9_ARPM01_000001`（往来账龄计算底稿）')
W('**核心口径**: ①本月账龄金额对 `LE_AGE_FLAG` 为 CL 且 `IS_REC_LG` 为 Y 的行，取 `SRC_DETAIL` 为 `ORG%` 的数据 `/(1+TAX_RATE)` 剔除税额；'
  '②年初/上月余额按 公司+科目+客商+利润中心 全量匹配本表对应场景期间取 `BCY_0_AMT`，本月无而年初/上月有的，其余字段取年初/上月信息；'
  '③各类专项金额（出库未开、退货未办、超期款、开票样机、提前回款、电商零售、欠付返利、欠付费用）按 科目+客户+利润中心 匹配到同一行')
W('')
W('| 字段名 | 类型 | 长度/精度 | 可空 | 含义 | 取数来源与规则 |')
W('|--------|------|-----------|------|------|----------------|')
for r in range(9, ws2.max_row + 1):
    name = g(ws2, r, 3)
    if not name:
        continue
    typ, ln = parse_type(g(ws2, r, 4))
    nul = 'Y' if g(ws2, r, 7) else 'N'
    desc = clean(g(ws2, r, 6)) or clean(g(ws2, r, 2))
    rule = clean(g(ws2, r, 13))
    tab = clean(g(ws2, r, 15))
    fld = clean(g(ws2, r, 16))
    parts = []
    if rule == '直接对应':
        if tab and fld:
            parts.append('直接对应 ' + tab + '.' + fld)
        elif fld:
            parts.append('直接对应 ' + fld)
        else:
            parts.append('直接对应')
    elif rule:
        parts.append(rule)
        if tab and fld:
            parts.append('← ' + tab + '.' + fld)
        elif fld:
            parts.append('← ' + fld)
    rule_txt = '；'.join(parts)
    if len(rule_txt) > 320:
        rule_txt = rule_txt[:320] + '…'
    W('| ' + name + ' | ' + typ + ' | ' + ln + ' | ' + nul + ' | ' + desc + ' | ' + rule_txt + ' |')
W('')
W('> **注1**: `CURRENCY_ACCT_DETAIL`（币种科目构成明细）格式为 `【法人分类标识:本币余额\\原币:原币余额;】`，'
  "实现为 `LISTAGG(LE_AGE_FLG || ':' || BCY_0_AMT || '\\' || COD_VALUTA_ORIGINARIA || ':' || QCY_0_AMT, ';') "
  "WITHIN GROUP (ORDER BY LE_AGE_FLG, BCY_0_AMT)`。")
W('> **注2**: `TH_FX_EVAL_AMT`（理论汇兑评估金额）= `BCY_0_AMT - POSTING_RATE_BCY_AMT`。')
W('> **注3**: `CLOSING_RATE_BCY_AMT`（期末汇率余额）：2023 公司取 SAP `ODS.ODSS600_TCURR@FMSLK` 的 `UKURS`'
  '（TCURR=VND 且 FCURR=USD 时 ×1000，TCURR=VND 其他时 ×100）；其余公司取 `DATI_CAMBIO.CAMBIO_FINALE`；'
  '交易币且本位币非 CNY 时按交易币折算本位币后保留 5 位小数。')
W('> **注4**: `overdue_2_amt` ～ `overdue_9_amt`（超期款 2-3个月 至 5年以上）当前规则为**置空**，仅 `overdue_0_amt`/`overdue_1_amt` 取数。')
W('> **注5**: `UFEE_AMT`（欠付费用金额）取 `SRC_DETAIL` 为 **`ureb%`** 的数据，`UREB_AMT`（欠付返利余额）取 `SRC_DETAIL` 为 **`ufee%`** 的数据，'
  '两字段 SRC_DETAIL 前缀为交叉对应，按设计文档原样保留，开发时需重点核对。')
W('> **注6**: `ADJ_REB_AMT`（调整后返利金额）= `UREB_AMT - MIN(BCY_AMT0 / UREB_AMT)`；'
  '`ADJ_RET_AMT`（调整后退货金额）= `MIN(BCY_AMT0 / ret_ntrf_amt)`。')
W('> **注7**: `LE/ME/MB_AGE_FLAG` 在底稿中字段名为 `LE_AGE_FLG`/`ME_AGE_FLG`/`MB_AGE_FLG`，到本表统一改为 `_FLAG` 后缀。')

md = '\n'.join(out)
with open('/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/草稿/_arpm_dict.md', 'w') as f:
    f.write(md)

n1 = sum(1 for r in range(9, ws1.max_row + 1) if g(ws1, r, 3))
n2 = sum(1 for r in range(9, ws2.max_row + 1) if g(ws2, r, 3))
print('ARPM01 字段数:', n1)
print('ARPM02 字段数:', n2)
print('输出行数:', len(out))
