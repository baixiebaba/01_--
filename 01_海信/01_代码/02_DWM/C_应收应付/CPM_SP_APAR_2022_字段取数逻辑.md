# CPM_SP_APAR_2022 字段取数逻辑整理

> 存储过程：`TGK_GB_HISENSE.CPM_SP_APAR_2022`
> 用途：往来账龄表三期，数据源为 `ZTAB_APAR_AGING_SOURCE`，产出写入 `FORM_DATI`
> 最后更新：20260503 XIAOYACHAO.EX

---

## 一、入参说明

| 参数 | 说明 |
|------|------|
| V_SCENARIO | 场景（如 2022ACT） |
| V_PERIODO | 期间（月份，如 01~12） |
| V_ENTITY | 公司代码 |
| V_TESTO | 科目类别标识，决定取哪类科目（A/B/C/D/E/F/I/J/K/L/M/G/H） |
| V_USERUPD | 操作用户 |

### V_TESTO → P_LCODE / P_CONTO 映射

| V_TESTO | P_LCODE | 含义 | P_CONTO（科目编码） |
|---------|---------|------|---------------------|
| A | AR | 应收账款 | 1122000000 |
| B | OR | 其他应收款 | 122101F |
| C | AS | 预付账款 | 1123000000 |
| I | CA | 合同资产 | 1460000000 |
| K | RF | 应收款项融资 | 1124001000 |
| D | AP | 应付账款 | 2202000000 |
| E | OP | 其他应付款 | 224199F |
| F | AC | 预收账款 | 2203000000 |
| J | CL | 合同负债 | 2204000000 |
| L | A9 | 非流动性资产 | 1910000A70 |
| M | A10 | 长期应收款 | 1531000000 |
| G | G | 统一执行（资产+负债） | - |
| H | H | 确认 | - |

---

## 二、核心变量初始化逻辑

| 变量 | 取值逻辑 |
|------|----------|
| P_SCENARIO | = V_SCENARIO |
| P_PERIODO | LPAD(V_PERIODO, 2, '0') |
| V_YEARMONTH | SUBSTR(P_SCENARIO,1,4) \|\| P_PERIODO（如 202206） |
| P_SCENARIO_PRE | 若 P_PERIODO='01'，则取上年ACT（如 2021ACT）；否则同 P_SCENARIO |
| P_PERIODO_PRE | 若 P_PERIODO='01'，则为 '12'；否则 LPAD(V_PERIODO-1, 2, '0') |
| V_FLAG_BLOCCATO | 从 DATI_SALDI_LORDI 查 COD_CONTO='DFC.APAR' AND COD_DEST5='ZZOT' 的 IMPORTO 合计，判断账期是否已锁 |
| V_LOCK | 从 DATI_SALDI_LORDI 查 COD_CONTO='SLK0105' 的 IMPORTO 合计，判断坏账是否已锁 |
| V_GONGSI | 公司类型判断：视像(SHIXIANG)/日立(HITACHI)/宽带(KUANDAI)/空 |
| V_IS_HITACHI | 日立公司标志（HIE='30', NODE='1730'） |
| V_IS_KUANDAI | 宽带公司标志（HIE='10', NODE='070'） |
| V_IS_M | 管理口径重分类标志（HIE='10', NODE='170'，聚好看等） |
| V_WANGKE | 网科公司清单（HIE='01', NODE='1600A' 下所有公司） |
| V_BEIYONG_TYPE | 备用列取值方式（见下表） |
| V_XINGZHI_TYPE | 性质合并原则，固定为 1（优先取本月，全空时取上月） |

### V_BEIYONG_TYPE 备用列取值方式

| 值 | 适用公司 | TESTO_3 取值内容 |
|----|----------|------------------|
| 0 | 默认/视像 | 不取备用列 |
| 1 | 日立 | 对方公司属性（关联方/内部公司） |
| 2 | 宽带（非4210/4230） | 业务范围 GSBER |
| 3 | 聚好看(163x)、1170、1592、26x、23x（非2300/2330） | 利润中心 KTEXT |
| 4 | 15x开头（非1592，赛维） | 业务范围 GSBER |
| 5 | 网科公司 | 利润中心+业务范围 PRCTR\|\|GSBER |

---

## 三、FORM_DATI 输出字段完整取数逻辑

### 3.1 标识与基础字段

| 字段 | 资产表(ZS_AR0001_IPT01) | 负债表(ZS_AP0001_IPT01) | 取数逻辑 |
|------|------------------------|------------------------|----------|
| OID_FORM_DATI | ✓ | ✓ | NEWID() 生成唯一ID |
| COD_PROSPETTO | ✓ | ✓ | 资产='ZS_AR0001_IPT01'，负债='ZS_AP0001_IPT01' |
| COD_SCENARIO | ✓ | ✓ | = P_SCENARIO |
| COD_PERIODO | ✓ | ✓ | = P_PERIODO |
| DATEUPD | ✓ | ✓ | SYSDATE |
| USERUPD | ✓ | ✓ | = V_USERUPD |
| PROVENIENZA | ✓ | ✓ | = 'CPM_SP_APAR_2022' |
| COD_CONTO | ✓ | ✓ | 由 LCODE 映射为科目编码（见第一节映射表） |
| COD_CATEGORIA | ✓ | ✓ | 客商分类：$AMOUNT(同子集团)/1ADJ(同集团)/1REC(集团外)，详见 3.2 |
| COD_VALUTA | ✓ | ✓ | AZI.COD_VALUTA（公司本位币） |
| COD_VALUTA_ORIGINARIA | ✓ | ✓ | AZI.COD_VALUTA |
| COD_AZIENDA | ✓ | ✓ | = BUKRS（公司代码）= V_ENTITY |
| COD_AZI_CTP | ✓ | ✓ | = CTP（对方公司代码），来自源表 ZTAB_APAR_AGING_SOURCE |

### 3.2 COD_CATEGORIA（客商分类）取数逻辑

在 CTE `DTM` 中根据对方公司(CTP)与当前公司的层级关系判断：

```
CASE 
  WHEN P_NODE = ET.NODE AND P_HQ = ET.HQ THEN '$AMOUNT'  -- 同子集团同总部
  WHEN P_HQ = ET.HQ THEN '1ADJ'                           -- 同总部不同子集团 → 集团内
  ELSE '1REC'                                              -- 集团外
END
```

后续步骤 5 会根据 V_REF_AZIENDA_TV 进一步调整：
- 同子集团内的对方公司 → '$AMOUNT'
- 1000A/3Z00/9Z00 节点下公司 → 统一改为 '1REC'（集团外）
- 日立 NODE='6000R' 下 → '内部公司'
- 应收账款-信汇客户 → 统一改为 '1ADJ'（2025年5月起）

### 3.3 客商与性质字段

| 字段 | 资产表 | 负债表 | 取数逻辑 |
|------|--------|--------|----------|
| TESTO_14 | ✓ | - | 客商编码 = LTRIM(CVCODE, '0')，来自源表 |
| TESTO_15 | ✓ | - | 客商名称 = NVL(本月NAME1, 上月TESTO_15) |
| TESTO_5 | - | ✓ | 客商编码 = LTRIM(CVCODE, '0') |
| TESTO_6 | - | ✓ | 客商名称 = NVL(本月NAME1, 上月TESTO_6) |
| TESTO_2 | ✓ | - | 性质(KVERM)，合并规则见下 |
| TESTO_7 | - | ✓ | 性质(KVERM)，负债表字段 |
| TESTO_28 | ✓ | ✓ | 一级性质(KVERM_1)，取数规则同 KVERM |
| TESTO_29 | ✓ | ✓ | 二级性质(KVERM_2)，取数规则同 KVERM |

**性质(KVERM)合并规则**（V_XINGZHI_TYPE=1）：
- 本月与上月完全匹配（含一二级性质）→ 合并为一条，取本月性质
- 本月与上月不匹配 → 按金额排序，顺序号相同的合并
- 本月一二三级性质全为空 → 取上月性质
- V_XINGZHI_TYPE=0 时，性质不同不合并（rn+10000）

### 3.4 备用列与利润中心字段

| 字段 | 资产表 | 负债表 | 取数逻辑 |
|------|--------|--------|----------|
| TESTO_3 | ✓ | ✓ | 备用列，根据 V_BEIYONG_TYPE 取值：日立→对方公司属性；宽带→业务范围；聚好看/赛维→利润中心；网科→利润中心+业务范围 |
| TESTO_21 | ✓ | ✓ | 利润中心(PRCTR)，根据 V_BEIYONG_TYPE 决定是否取值 |
| TESTO_22 | ✓ | ✓ | 利润中心描述(DESC_PRCTR/KTEXT) |
| TESTO_23 | ✓ | ✓ | 业务范围(YWFW)，仅 V_BEIYONG_TYPE=4/5 时取值 |
| TESTO_24 | ✓ | ✓ | 业务范围描述(YWFWMC)，宽带/赛维从 TGSBT 取 GTEXT |
| TESTO_26 | ✓ | ✓ | 标记(FLAG) = GJ.FLAG \|\| ZG.FLAG（国际营销客户标志+暂估科目标志） |
| TESTO_27 | ✓ | - | 线上/线下标志，仅视像公司(26x/23x)：线上客户='线上'，其他='线下' |

### 3.5 金额字段 — 账龄区间

> 数据源：`ZTAB_APAR_AGING_SOURCE` 的 DMBTR0~9（本位币金额）和 WRBTR0~9（原币金额）
> 汇率处理：HUILVPG=1 时用 WRBTR×CAMBIO（原币×汇率），否则直接取 DMBTR

| 字段 | 资产表 | 负债表 | 含义 | 取数逻辑 |
|------|--------|--------|------|----------|
| IMPORTO_1 | ✓ | ✓ | 年初余额(BTR_NC) | 上月 FORM_DATI 中 IMPORTO_3（12月）或 IMPORTO_1（非12月） |
| IMPORTO_2 | ✓ | ✓ | 上月余额(BTR_LM) | 上月 FORM_DATI 的 IMPORTO_3 |
| IMPORTO_3 | ✓ | ✓ | 本月余额(BTR0) | 当月源表 DMBTR0 或 WRBTR0×CAMBIO |
| IMPORTO_6 | ✓ | ✓ | 1个月以内(BTR_M1) | 当月源表 DMBTR1 或 WRBTR1×CAMBIO |
| IMPORTO_7 | ✓ | ✓ | 1-3个月(BTR_M23) | 当月源表 DMBTR2 或 WRBTR2×CAMBIO |
| IMPORTO_8 | ✓ | ✓ | 3-6个月(BTR_M46) | 当月源表 DMBTR3 或 WRBTR3×CAMBIO |
| IMPORTO_9 | ✓ | ✓ | 6-12个月(BTR_M712) | 当月源表 DMBTR4 或 WRBTR4×CAMBIO |
| IMPORTO_10 | ✓ | ✓ | 1-2年(BTR_Y12) | 当月源表 DMBTR5 或 WRBTR5×CAMBIO |
| IMPORTO_11 | ✓ | ✓ | 2-3年(BTR_Y23) | 当月源表 DMBTR6 或 WRBTR6×CAMBIO |
| IMPORTO_12 | ✓ | ✓ | 3-4年(BTR_Y34) | 当月源表 DMBTR7 或 WRBTR7×CAMBIO |
| IMPORTO_22 | ✓ | ✓ | 4-5年(BTR_Y45) | 当月源表 DMBTR8 或 WRBTR8×CAMBIO |
| IMPORTO_21 | ✓ | ✓ | 5年以上(BTR_Y5A) | 当月源表 DMBTR9 或 WRBTR9×CAMBIO |

**负债表（合同负债CL）特殊处理**：当 IS_REC='Y' 时，金额 = DMBTR / (1+税率SHUILV)，即扣除税额

### 3.6 金额字段 — 本位币与发生额

| 字段 | 资产表 | 负债表 | 含义 | 取数逻辑 |
|------|--------|--------|------|----------|
| IMPORTO_23 | ✓ | ✓ | 原币折本位币金额(DMBTR_W) | SUM(WRBTR0 × CAMBIO) |
| IMPORTO_24 | ✓ | ✓ | 本位币余额(DMBTR0) | SUM(DMBTR0)（不经过汇率） |
| IMPORTO_34 | ✓ | - | 上月坏账余额(BTR_LM_HuaiZHang) | 上月 FORM_DATI 的 IMPORTO_19 |
| IMPORTO_36 | ✓ | ✓ | 是否修改标记 | 初始=0，用于数据校验 |
| IMPORTO_51 | ✓ | ✓ | 借方发生额(DMBTR_S) | 源表 DMBTR_S × CAMBIO（HUILVPG=1时） |
| IMPORTO_52 | ✓ | ✓ | 贷方发生额(DMBTR_H) | 源表 DMBTR_H × CAMBIO（HUILVPG=1时） |
| IMPORTO_53 | ✓ | ✓ | 年初发生额(DMBTR_NC) | 源表 DMBTR_NC × CAMBIO（HUILVPG=1时） |
| IMPORTO_54 | ✓ | ✓ | 应收借方发生额(REC_DMBTR_S) | IS_REC='Y' 时取 DMBTR_S，否则0 |
| IMPORTO_55 | ✓ | ✓ | 应收贷方发生额(REC_DMBTR_H) | IS_REC='Y' 时取 DMBTR_H，否则0 |
| IMPORTO_56 | ✓ | ✓ | 应收年初发生额(REC_DMBTR_NC) | IS_REC='Y' 时取 DMBTR_NC，否则0 |

### 3.7 汇率(CAMBIO)取数逻辑

```
CASE
  WHEN BUKRS='2023' AND CAMBIO2023.cambio_F IS NOT NULL THEN CAMBIO2023.cambio_F  -- 越南工厂用当地汇率
  WHEN HWAER<>'CNY' AND WAERS<>'CNY' THEN ROUND(1/DC.CAMBIO_FINALE × DC1.CAMBIO_FINALE, 5)  -- 交叉汇率
  ELSE 1/DC.CAMBIO_FINALE × DC1.CAMBIO_FINALE  -- 标准汇率
END
```

- DC: DATI_CAMBIO 表，按 WAERS（凭证币种）取汇率
- DC1: DATI_CAMBIO 表，按 HWAER（本位币）取汇率
- CAMBIO2023: 越南工厂(2023)特殊汇率，从 ODSS600_TCURR 取 VND 月初汇率

### 3.8 HUILVPG（汇率评估标志）取数逻辑

**资产表**：
```
CASE
  WHEN MANDT='800C' THEN 0                          -- 乾照公司不评估
  WHEN V_YEARMONTH>='202405' AND LCODE='AS' THEN 0  -- 预付账款2024年5月起不评估
  WHEN MANDT<>'800C' AND FLAG IS NULL THEN 1        -- 无特殊标记时需评估
  ELSE 0
END
```

**负债表**：
```
CASE
  WHEN V_YEARMONTH>='202405' AND LCODE='AC' THEN 0  -- 预收账款2024年5月起不评估
  WHEN FLAG IS NULL THEN 1
  ELSE 0
END
```

---

## 四、手工维护字段更新逻辑

### 4.1 上期手工数据带到本期（步骤3）

**条件**：当月有余额(IMPORTO_3≠0)且上月有余额(IMPORTO_2≠0)

**资产表**（ZS_AR0001_IPT01）— 匹配条件：COD_CONTO + TESTO_14(客商) + TESTO_2(性质) + TESTO_28/29(一二级性质) + IMPORTO_1(年初)：

| 字段 | 含义 | 来源 |
|------|------|------|
| TESTO_48 | 挂账原因 | 上月 FORM_DATI |
| TESTO_47 | 清理措施 | 上月 FORM_DATI |
| TESTO_10 | 预计清理时间 | 上月 FORM_DATI |
| TESTO_11 | 责任人 | 上月 FORM_DATI |

**负债表**（ZS_AP0001_IPT01）— 匹配条件：COD_CONTO + TESTO_5(客商) + TESTO_7(性质) + TESTO_28/29 + TESTO_3：

| 字段 | 含义 | 来源 |
|------|------|------|
| TESTO_50 | 挂账原因 | 上月 FORM_DATI |
| TESTO_11 | 预计清理时间 | 上月 FORM_DATI |
| TESTO_12 | 清理措施 | 上月 FORM_DATI |
| TESTO_13 | 负责人 | 上月 FORM_DATI |

### 4.2 本月临时表数据恢复（步骤4）

从 FORM_DATI_ARAP_TMP 恢复本次抽数前已手工维护的数据。

**资产表**更新字段：

| 字段 | 含义 |
|------|------|
| IMPORTO_13 | 超期金额 |
| IMPORTO_14 | 超期账龄-1个月以内 |
| IMPORTO_15 | 超期账龄-1个月以上 |
| IMPORTO_16 | 呆死金额 |
| IMPORTO_17 | 风险金额 |
| IMPORTO_19 | 应计提坏账金额 |
| IMPORTO_41~47 | 超期金额明细 |
| TESTO_48 | 挂账原因 |
| TESTO_7 | 账期 |
| TESTO_8 | 付款方式 |
| TESTO_50 | 产生时间 |
| TESTO_47 | 清理措施 |
| TESTO_10 | 预计清理时间 |
| TESTO_16 | 清理进度 |
| TESTO_11 | 责任人 |
| TESTO_49 | 超期账龄备注 |

**负债表**更新字段：

| 字段 | 含义 |
|------|------|
| IMPORTO_13 | 超期金额 |
| IMPORTO_14 | 超期账龄1个月以内 |
| IMPORTO_15 | 超期账龄1个月以上 |
| IMPORTO_16 | 呆死金额 |
| IMPORTO_17 | 风险金额 |
| IMPORTO_18 | 应付款中暂估金额 |
| TESTO_8 | 超期账龄备注 |
| TESTO_9 | 账期 |
| TESTO_10 | 付款方式 |
| TESTO_11 | 清理措施 |
| TESTO_12 | 预计清理时间 |
| TESTO_13 | 负责人 |
| TESTO_50 | 挂账原因 |

---

## 五、合同负债税率更新（步骤4 - 仅CL）

| 字段 | 含义 | 取数逻辑 |
|------|------|----------|
| IMPORTO_31 | 年初税率 | 默认0.13（2020年为0），从 ZG_IC001_TAXSET 取特殊维护税率（$AMOUNT按公司、1ADJ按客户） |
| IMPORTO_32 | 上月税率 | 默认0.13，从 ZG_IC001_TAXSET 取上月特殊税率 |
| IMPORTO_33 | 当月税率 | 默认0.13，从 ZG_IC001_TAXSET 取当月特殊税率 |

---

## 六、特殊公司处理逻辑

### 6.1 日立公司（V_IS_HITACHI>0）

| 处理项 | 逻辑 |
|--------|------|
| 客商名称(NAME1) | 根据 MANDT+CUSVEN 从 SAP 各系统 LFA1/KNA1 表取供应商/客户名称 |
| 科目名称 | CVCODE=HKONT 时从 SKAT 表取科目描述(TXT50) |
| TESTO_3 | 对方公司属性：关联方/内部公司(NODE='6000R') |
| CTP | 清空 1800/7000 |
| IMPORTO_35 | 垫资扣减：从 ZS_AR0002_IPT01 取 SZK5150 金额 |

### 6.2 宽带公司（V_IS_KUANDAI>0）

| 处理项 | 逻辑 |
|--------|------|
| GSBER | 1123003000 科目业务范围置空 |
| TESTO_3 | 2024年2月前：GSBER+'\_'+GTEXT（从 TGSBT 取业务范围描述） |
| TESTO_24 | 业务范围名称，从 TGSBT 取 GTEXT |
| TESTO_21/22 | 利润中心从 2013ACT01 XT02 配置取 |
| 账龄特殊处理 | 特定客商(6000044等)全部归入 IMPORTO_6（1个月以内） |

### 6.3 视像公司

| 处理项 | 逻辑 |
|--------|------|
| TESTO_27 | 线上/线下：2600公司且客商在 LIST_ONLINE_CUS/LIST_ONLINE_V 中='线上'，否则='线下' |
| TESTO_22 | 利润中心名称=TESTO_3（备用列值） |
| 备用列 | 非应收/其他应收科目不取业务范围 |

### 6.4 赛维公司（15x，非1592）

| 处理项 | 逻辑 |
|--------|------|
| TESTO_24 | 业务范围名称，从 ODSS600_TGSBT 取 GTEXT |
| TESTO_21/22 | 利润中心从 2013ACT01 XT03 配置取 |

### 6.5 网能嘉科/日立垫资扣减

IMPORTO_35 = ZS_AR0002_IPT01 中 SZK5150 科目的 IMPORTO_2（上月余额），按客商匹配

---

## 七、坏账计算逻辑（步骤H，仅2024年2月前）

### 计算条件
- P_LCODE IN ('G','HZ','AR','OR','CA')
- V_YEARMONTH <= '202402'
- V_LOCK = 0（坏账未锁）
- DATA_1 IS NULL（未计算过）
- IMPORTO_3 > IMPORTO_35（余额大于垫资金额）

### 计算规则

IMPORTO_19（应计提坏账金额）按三级优先级计算：

1. **H1 - 按客户匹配**：2013ACT01 的坏账比例表，按 TESTO_14(客商) LIKE 匹配
2. **H2 - 按备用列匹配**：按 TESTO_3(备用列) LIKE 匹配
3. **H3 - 统一计算**：TESTO_3 和 TESTO_14 均为空的通用比例

计算公式（从5年以上开始逐级扣减垫资IMPORTO_35）：

```
CASE
  WHEN IMPORTO_35 <= 0 THEN  -- 无垫资：各账龄区间 × 对应坏账率
    IMPORTO_21×B21 + IMPORTO_22×B22 + IMPORTO_12×B12 + ... + IMPORTO_6×B6
  WHEN IMPORTO_35 >= 所有区间合计 THEN 0  -- 垫资覆盖全部
  ELSE  -- 部分覆盖：从5年以上开始逐级扣减
    (剩余金额 × 对应区间坏账率) + 已确认区间 × 对应坏账率
END
```

其中 B6~B21 为 2013ACT01 配置的各账龄区间坏账计提比例。

---

## 八、其他后处理逻辑

### 8.1 默认产品线处理

对于 V_BEIYONG_TYPE<=1（视像/日立）且 TESTO_21 为空的公司，从 2013ACT01 XT01 配置取默认利润中心(TESTO_21/22)。

### 8.2 信汇客户处理（2025年5月起）

- 应收账款(TESTO_15='应收账款-信汇') → COD_CATEGORIA='1ADJ'，COD_AZI_CTP='-'
- 合同负债(TESTO_6='应收账款-信汇') → COD_CATEGORIA='1ADJ'，COD_AZI_CTP='-'

### 8.3 新旧利润中心映射（2026ACT01）

通过 MAP_REGOLA_TAB_ELEMENTO 映射表（COD_MAPPATURA='HI_DATA_APARAGI'）：
- MAP_PRCTR：按 TESTO_21 精确匹配，映射为新利润中心
- MAP_PRCTR1：按 TESTO_21 + COD_AZIENDA + TESTO_14 模糊匹配

### 8.4 赛维公司锁定（2024年8月起）

15x 公司自动设置 COD_DEST5='ZZOT'（锁定标记）

### 8.5 TESTO_30 校验字段

拼接所有金额字段值，格式如：
`I1:年初余额/I2:上月余额/I3:本月余额/I6:1月内/I7:1-3月/.../I21:5年以上`

用于数据校验（testo30 数据校验，importo_36 是否修改）。

---

## 九、数据流概览

```
ZTAB_APAR_AGING_SOURCE (源表)
    │
    ├── DTM (当月数据 CTE)
    │     ├── LCODE → COD_CONTO 科目映射
    │     ├── HUILVPG → 汇率评估判断
    │     ├── CAMBIO → 汇率取数
    │     ├── GSBER/PRCTR/YWFW → 备用列取值(V_BEIYONG_TYPE)
    │     └── COD_CATEGORIA → 客商分类判断
    │
    ├── DLM (上月数据 CTE)
    │     └── 从 FORM_DATI 取上月的 IMPORTO_1(年初)/IMPORTO_3(上月余额)/IMPORTO_19(坏账)
    │
    ├── D99 (匹配合并 CTE)
    │     ├── 完全匹配：DTM ∩ DLM → 合并为一条
    │     └── 不匹配：DTM - DLM ∪ DLM - DTM → 按金额排序 row_number 合并
    │
    └── INSERT INTO FORM_DATI
          │
          ├── 步骤3：上月手工维护字段带到本期
          ├── 步骤4：临时表数据恢复(本月已手工维护的数据)
          ├── 步骤4(CLA)：合同负债税率更新
          ├── 步骤5：客商分类调整(子集团/集团内/集团外)
          ├── 步骤S1-S3：特殊公司处理(日立/宽带/视像/赛维)
          ├── 步骤H：坏账计算(2024年2月前)
          ├── 步骤10：坏账余额同步(CPM_SP_AG_HZOC)
          └── 利润中心映射(2026ACT01)
```

---

## 十、涉及的源表与配置表

| 表名 | 用途 |
|------|------|
| ZTAB_APAR_AGING_SOURCE | 主数据源，SAP账龄明细 |
| FORM_DATI | 输出表，存储账龄结果 |
| FORM_DATI_ARAP_TMP | 临时表，保存手工维护数据 |
| DATI_SALDI_LORDI | 账期锁定/坏账锁定状态 |
| DATI_CAMBIO | 汇率表 |
| V_REF_AZIENDA / V_REF_AZIENDA_TV | 公司层级关系 |
| V_APAR_ELEM_NODE_TAB | 公司节点与总部关系 |
| AZIENDA | 公司基本信息（本位币等） |
| ZG_IC001_TAXSET (FORM_DATI) | 税率配置 |
| ZS_APAR01_IPT04 (FORM_DATI) | 国际营销客户配置 |
| ZS_APAR01_IPT06 (FORM_DATI) | 暂估科目列表 |
| ZS_AR0002_IPT01 (FORM_DATI) | 垫资数据 |
| ODSSxxx_LFA1/KNA1@FMSLK | SAP 供应商/客户主数据 |
| ODSSxxx_SKAT@FMSLK | SAP 科目主数据 |
| ODSSxxx_TGSBT@FMSLK | SAP 业务范围主数据 |
| ODSS600_TCURR@FMSLK | SAP 汇率表（越南特殊汇率） |
| MAP_REGOLA_TAB_ELEMENTO | 利润中心新旧映射表 |
| FORM_DIZIONARIO_ELEMENTO | 数据字典（线上客户清单等） |
| ZTAB_CPM_LOG | 执行日志表 |
