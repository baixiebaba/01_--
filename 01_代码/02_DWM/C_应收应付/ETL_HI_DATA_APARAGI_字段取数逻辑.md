# ETL_HI_DATA_APARAGI 字段取数逻辑

## 1. 文档说明

本文档依据 `ETL_HI_DATA_APARAGI.sql` 整理，覆盖：

- 查询整体处理流程；
- 最终输出的全部 46 个字段；
- 字段来源、转换逻辑、优先级及默认值；
- 全部关联匹配条件；
- 源数据、配置数据和最终结果的限制条件；
- 重分类、税率、性质、利润中心等专项逻辑；
- 代码中无法确认的口径及潜在风险。

> 注意：该 SQL 文件只有 `WITH ... SELECT` 查询，没有 `INSERT`、`DELETE`、`MERGE`、`TRUNCATE` 或目标表字段清单。因此，本文中的“最终输出”指查询结果集，不能仅根据本文件确定物理目标表、主键、分区及覆盖方式。

---

## 2. 输入参数

| 参数 | 用途 | 使用位置及要求 |
|---|---|---|
| `{IN-YEARMONTH}` | 运行年月 | 预期为 `YYYYMM`；用于源表月末快照、配置有效期、公司层级场景/期间、利润中心映射启用时间等。参数替换后必须是合法 Oracle SQL 字面量。 |
| `{IN-ENTITY}` | 公司范围 | 直接用于 `IN ({IN-ENTITY})`；应展开为合法的公司代码列表。过滤的是公司转换和 `AZI_MAP` 映射后的最终公司。 |

本查询按单月运行：源账龄表仅取 `{IN-YEARMONTH}` 对应月末日的数据。

---

## 3. 数据处理总流程

```text
dw.DWFI_TF_ARAP_AGING@FMSLK（月末账龄快照）
    │
    ├─ 原始字段清洗
    │   ├─ 客户端 680 → 600
    │   ├─ 公司特殊转换
    │   ├─ 科目合并为 HKONT_T
    │   ├─ 客商类型、利润中心、名称标准化
    │   └─ 源数据过滤
    │
    ├─ HBCV：匹配合并重分类客商
    ├─ AZI_MAP：匹配目标公司
    │
    ▼
ZZT003
    ├─ 计算 DMBTR_REC（客商/科目粒度）
    ├─ 计算 DMBTR_REC_M（客商/科目/利润中心粒度）
    └─ 限定最终公司范围
    │
    ├─ XINGZHI：匹配 SAP 客商性质
    ├─ IC：匹配对方公司 CTP
    ├─ TAX / PRCTRTAX / NOTAXCV：匹配税率
    ├─ AZIENDA：补充本位币
    ├─ F_APAR_REC：计算重分类标志及编码
    │
    ▼
派生层 A
    ├─ LEVEL2～LEVEL6：按优先级转换客商性质
    ├─ MP / MP1：映射利润中心及利润中心名称
    ├─ 排除信汇名称
    └─ 输出 46 个字段，SRC 固定为 ZZT003
```

---

## 4. 源数据及基础清洗

### 4.1 主数据源

| 对象 | 用途 |
|---|---|
| `dw.DWFI_TF_ARAP_AGING@FMSLK` | 往来账龄月末快照，是金额、客商、科目、币种、利润中心等字段的主来源。 |

### 4.2 客户端 `MANDT` 标准化

```sql
TRIM(DECODE(MANDT, '680', '600', MANDT))
```

- `680` 转成 `600`；
- 其他值保持不变；
- 最终执行 `TRIM`。

### 4.3 公司 `BUKRS` 第一阶段转换

按以下顺序执行，命中第一条后不再继续：

| 优先级 | 条件 | 转换结果 |
|---:|---|---|
| 1 | `BUKRS IN ('4320','4330')` | 原公司代码后拼接 `A`，即 `4320A/4330A`。 |
| 2 | `MANDT='700' AND BUKRS='1000'` | `1730` |
| 2 | `MANDT='700' AND BUKRS='2000'` | `1740` |
| 2 | `MANDT='700' AND BUKRS='3000'` | `1750` |
| 2 | `MANDT='700' AND BUKRS='5000'` | `6240` |
| 2 | `MANDT='700'` 但公司不在上述范围 | 保持原公司。 |
| 3 | `BUKRS='6000' AND GSBER='200'` | `6000A` |
| 3 | `BUKRS='6000' AND GSBER='400'` | `6000B` |
| 3 | `BUKRS='6000' AND GSBER='500'` | `6000C` |
| 3 | `BUKRS='6000'` 但业务范围不在上述范围 | `6000` |
| 4 | `MANDT='800B' AND BUKRS='4221'` | `4220` |
| 5 | 其他 | 保持原公司。 |

### 4.4 公司 `BUKRS` 第二阶段映射

配置来源：`MAP_REGOLA_TAB_ELEMENTO`。

配置限制：

```text
COD_REGOLA_TAB = 'MAP_BUKRS_800C'
COD_MAPPATURA  = 'HI_DATA_GL'
```

字段关系：

| 配置字段 | 含义 |
|---|---|
| `ELEDIM_INPUT1` | 源客户端 `SRC_MANDT` |
| `ELEDIM_INPUT2` | 源公司 `SRC_ENT` |
| `ELEDIM_OUTPUT1` | 目标公司 `TAG_ENT` |

匹配条件：

```text
第一阶段转换后的 T.BUKRS = AZI_MAP.SRC_ENT
标准化后的 T.MANDT       = AZI_MAP.SRC_MANDT
```

最终公司：

```sql
NVL(AZI_MAP.TAG_ENT, T.BUKRS)
```

即配置匹配成功时使用目标公司，否则使用第一阶段转换后的公司。

### 4.5 科目 `HKONT_T` 合并规则

原始科目 `HKONT` 先执行 `TRIM`；`HKONT_T` 再按以下顺序转换：

| 优先级 | 公司/科目条件 | `HKONT_T` |
|---:|---|---|
| 1 | `HKONT LIKE '1466%'` | `1466000000` |
| 2 | `BUKRS IN ('6500','6510')` 且 `HKONT IN ('2241010100','2241010200','2241020000','2241040000')` | `2241010100` |
| 3 | `BUKRS IN ('6500','6510')` 且 `HKONT IN ('1221010000','1221020000','1221040000')` | `1221010000` |
| 4 | `BUKRS IN ('1007','1008','1041')` 且 `HKONT LIKE '2202%'` | `2202000000` |
| 5 | `BUKRS LIKE '66%' AND BUKRS<>'6600'`，`HKONT LIKE '1131%'` 且不等于 `1131999001` | `1131002000` |
| 6 | 同上公司范围，`HKONT LIKE '1133%'` 且不等于 `1133999001` | `1133001003` |
| 7 | 同上公司范围，`HKONT LIKE '2181%'` 且不等于 `2181999001` | `2181001005` |
| 8 | 同上公司范围，`HKONT LIKE '2121%'` 且不等于 `2121999001` | `2121001000` |
| 9 | `BUKRS IN ('6000','6600')` 且 `HKONT LIKE '1131%'` | `1131002000` |
| 10 | `BUKRS IN ('6000','6600')` 且 `HKONT LIKE '1133%'` | `1133001003` |
| 11 | `BUKRS IN ('6000','6600')` 且 `HKONT LIKE '2181%'` | `2181001005` |
| 12 | `BUKRS IN ('6000','6600')` 且 `HKONT LIKE '2121%'` | `2121001000` |
| 13 | `BUKRS LIKE '16%'`，但不以 `163/162` 开头，且 `HKONT IN ('2202000000','2202000089')` | `2202000000` |
| 14 | 其他 | 原始 `HKONT` |

> 上述公司判断使用源数据中的原始 `BUKRS`，不是后续 `AZI_MAP` 映射后的公司。

### 4.6 其他基础字段标准化

| 字段 | 处理逻辑 |
|---|---|
| `CUSVEN` | `KOART='D'` 时为客户 `C`；其余所有值均为供应商 `V`。 |
| `CVCODE` | 直接取源字段 `OBJECT`；代码注释中的 `NVL(FILKD,OBJECT)` 未实际启用。 |
| `NAME1` | `TRIM(NAME1)`。 |
| `PRCTR` | 去前导零；结果为 `1330201` 时改为 `1300201`。 |
| `KTEXT` | `TRIM(KTEXT)`；名称为 `容声酒柜` 时改为 `容声冰箱`。 |
| `GSBER` | `TRIM(GSBER)`。 |
| `HWAER` | 源层先 `TRIM(HWAER)`，后续为空时以公司主数据币种补充。 |
| `WAERS` | `TRIM(WAERS)`。 |
| `DMBTR0～DMBTR9` | 源字段原值带出。 |
| `WRBTR0～WRBTR9` | 源字段原值带出。 |

---

## 5. 最终输出字段逻辑

最终查询共输出 **46 个字段**，顺序如下。

| 序号 | 输出字段 | 来源/表达式 | 字段逻辑及说明 |
|---:|---|---|---|
| 1 | `YEARMONTH` | `TO_CHAR(KEYDAT,'YYYYMM')` | 数据年月；由于源表按参数月末过滤，通常等于 `{IN-YEARMONTH}`。 |
| 2 | `MANDT` | 标准化后的源 `MANDT` | `680→600`，其他保持原值并去首尾空格。 |
| 3 | `BUKRS` | `NVL(AZI_MAP.TAG_ENT,T.BUKRS)` | 先执行公司特殊转换，再按客户端+公司匹配 `AZI_MAP`；匹配不到保留转换后公司。 |
| 4 | `HKONT` | `TRIM(源.HKONT)` | 原始总账科目，不应用科目合并规则。 |
| 5 | `HKONT_T` | 科目转换 `CASE` | 合并/重分类后的科目，规则见“4.5 科目 HKONT_T 合并规则”。 |
| 6 | `CUSVEN` | `DECODE(TRIM(KOART),'D','C','V')` | 客商类型：`C` 客户、`V` 供应商；所有非 `D` 的科目类型均归为 `V`。 |
| 7 | `CVCODE` | `源.OBJECT` | 原始客商编码。合并客商映射不覆盖该字段。 |
| 8 | `NAME1` | `TRIM(源.NAME1)` | 客商名称；最终会排除两个信汇名称。 |
| 9 | `PRCTR` | 基础清洗后的 `A.PRCTR`，再应用年月映射 | 先去前导零并将 `1330201→1300201`；2025-12 起应用静态映射；2026-01 起改用 `MP1→MP→原值` 优先级，详见第 8 节。 |
| 10 | `KTEXT` | 基础清洗后的 `A.KTEXT`，再应用年月映射 | 先将 `容声酒柜→容声冰箱`；2025-12 起部分映射为 `平板电视`；2026-01 起按 `MP1→MP→原值` 取名称。 |
| 11 | `GSBER` | `TRIM(源.GSBER)` | 业务范围。 |
| 12 | `HWAER` | `NVL(T3.HWAER,BZ.COD_VALUTA)` | 本位币；源值非空优先，否则按公司从 `AZIENDA` 补充币种。 |
| 13 | `DMBTR0` | `源.DMBTR0` | 本位币金额桶 0，原值带出。代码未定义该桶对应的具体账龄区间。 |
| 14 | `DMBTR1` | `源.DMBTR1` | 本位币金额桶 1，原值带出。 |
| 15 | `DMBTR2` | `源.DMBTR2` | 本位币金额桶 2，原值带出。 |
| 16 | `DMBTR3` | `源.DMBTR3` | 本位币金额桶 3，原值带出。 |
| 17 | `DMBTR4` | `源.DMBTR4` | 本位币金额桶 4，原值带出。 |
| 18 | `DMBTR5` | `源.DMBTR5` | 本位币金额桶 5，原值带出。 |
| 19 | `DMBTR6` | `源.DMBTR6` | 本位币金额桶 6，原值带出。 |
| 20 | `DMBTR7` | `源.DMBTR7` | 本位币金额桶 7，原值带出。 |
| 21 | `DMBTR8` | `源.DMBTR8` | 本位币金额桶 8，原值带出。 |
| 22 | `DMBTR9` | `源.DMBTR9` | 本位币金额桶 9，原值带出。 |
| 23 | `WAERS` | `TRIM(源.WAERS)` | 交易/凭证币种。 |
| 24 | `WRBTR0` | `源.WRBTR0` | 交易币金额桶 0，原值带出。代码未定义该桶对应的具体账龄区间。 |
| 25 | `WRBTR1` | `源.WRBTR1` | 交易币金额桶 1，原值带出。 |
| 26 | `WRBTR2` | `源.WRBTR2` | 交易币金额桶 2，原值带出。 |
| 27 | `WRBTR3` | `源.WRBTR3` | 交易币金额桶 3，原值带出。 |
| 28 | `WRBTR4` | `源.WRBTR4` | 交易币金额桶 4，原值带出。 |
| 29 | `WRBTR5` | `源.WRBTR5` | 交易币金额桶 5，原值带出。 |
| 30 | `WRBTR6` | `源.WRBTR6` | 交易币金额桶 6，原值带出。 |
| 31 | `WRBTR7` | `源.WRBTR7` | 交易币金额桶 7，原值带出。 |
| 32 | `WRBTR8` | `源.WRBTR8` | 交易币金额桶 8，原值带出。 |
| 33 | `WRBTR9` | `源.WRBTR9` | 交易币金额桶 9，原值带出。 |
| 34 | `DMBTR_REC` | `SUM(T.DMBTR0) OVER (...)` | 按特殊公司归并值、客商类型、合并后客商、`HKONT_T` 汇总 `DMBTR0`；不区分利润中心。 |
| 35 | `DMBTR_REC_M` | `SUM(T.DMBTR0) OVER (...)` | 与 `DMBTR_REC` 相同，但窗口分组额外包含 `PRCTR`。 |
| 36 | `IS_REC` | `F_APAR_REC(...,DMBTR_REC,'1')` | 以非利润中心粒度汇总金额调用重分类函数；返回含义依赖函数定义，本文件中未提供。 |
| 37 | `LCODE` | `F_APAR_REC(...,DMBTR_REC,'2')` | 以非利润中心粒度汇总金额调用重分类函数；返回编码规则无法由本文件确定。 |
| 38 | `IS_REC_M` | `F_APAR_REC(...,DMBTR_REC_M,'1')` | 以利润中心粒度汇总金额调用重分类函数。 |
| 39 | `LCODE_M` | `F_APAR_REC(...,DMBTR_REC_M,'2')` | 以利润中心粒度汇总金额调用重分类函数。 |
| 40 | `CTP` | `IC.CTP` | 对方公司；按客户端+去前导零客商+客商类型匹配 `MAP_CTP`，取配置输出最小值。 |
| 41 | `SHUILV` | `NVL(NOTAXCV.SHUILV,NVL(PRCTRTAX.SHUILV,NVL(TAX.SHUILV,0.13)))` | 税率优先级：客商特殊税率→利润中心税率→公司税率→默认 `0.13`。配置允许显式税率为 0。 |
| 42 | `CVCODE_HB` | `HBCV.TESTO_12` | 合并重分类客商编码；用于重分类汇总分组，但不覆盖最终 `CVCODE`。 |
| 43 | `KVERM` | 多层性质匹配 `CASE` | 优先级：LEVEL6→LEVEL5→LEVEL4→LEVEL3→LEVEL2→特定公司节点清空→SAP 原始性质。详见第 9 节。 |
| 44 | `KVERM_1` | LEVEL6/5/4/3 的 `TESTO_12` | 按 LEVEL6→5→4→3 优先级取扩展性质字段；没有 LEVEL2 或原始性质后备，未命中返回 `NULL`。 |
| 45 | `KVERM_2` | LEVEL6/5/4/3 的 `TESTO_13` | 按 LEVEL6→5→4→3 优先级取扩展性质字段；没有 LEVEL2 或原始性质后备，未命中返回 `NULL`。 |
| 46 | `SRC` | 常量 `'ZZT003'` | 数据来源标识。 |

---

## 6. 合并客商与重分类金额逻辑

### 6.1 合并客商 `CVCODE_HB`

配置来源：`FORM_DATI`。

配置限制：

```text
COD_PROSPETTO = 'ZS_APAR01_IPT04'
COD_CATEGORIA = 'XT02'
去前导零后的 TESTO_11 非空
去前导零后的 TESTO_12 非空
{IN-YEARMONTH} BETWEEN NVL(TRIM(TESTO_13),'0')
                   AND NVL(TRIM(TESTO_13),'999999')
```

配置字段：

| 配置字段 | 用途 |
|---|---|
| `COD_AZIENDA` | 公司 |
| 去前导零的 `TESTO_11` | 待合并的原客商 |
| `TESTO_12` | 合并后的客商 `CVCODE_HB` |
| `TESTO_13` | 当前 SQL 同时作为有效期开始和结束字段使用 |

匹配条件：

```text
HBCV.COD_AZIENDA = 第一阶段转换后的 T.BUKRS
LTRIM(T.CVCODE,'0') = LTRIM(TRIM(HBCV.TESTO_11),'0')
```

> 此关联发生在 `AZI_MAP` 公司映射前，因此配置公司采用的是第一阶段转换后的公司，而不是最终映射公司。

### 6.2 `DMBTR_REC` 分组

汇总表达式：

```sql
SUM(T.DMBTR0) OVER (
  PARTITION BY 重分类公司,
               T.CUSVEN,
               NVL(HBCV.CVCODE_HB,T.CVCODE),
               T.HKONT_T
)
```

其中“重分类公司”规则：

```text
当最终映射公司属于 6000、6000A、6000B、6000C、6600，
且 HKONT_T 属于 1131002000、1133001003、2181001005、2121001000 时，
统一按公司 6000 分组；其他情况按最终映射公司分组。
```

### 6.3 `DMBTR_REC_M` 分组

与 `DMBTR_REC` 相同，但分组额外增加 `T.PRCTR`：

```sql
SUM(T.DMBTR0) OVER (
  PARTITION BY 重分类公司,
               T.CUSVEN,
               NVL(HBCV.CVCODE_HB,T.CVCODE),
               T.HKONT_T,
               T.PRCTR
)
```

两个字段都只汇总 `DMBTR0`，不会汇总 `DMBTR1～DMBTR9`。

### 6.4 `F_APAR_REC` 调用参数

四个派生字段的调用形式如下：

| 输出字段 | 调用逻辑 |
|---|---|
| `IS_REC` | `F_APAR_REC(YEARMONTH,MANDT,BUKRS,HKONT_T,CVCODE,DMBTR_REC,'1')` |
| `LCODE` | `F_APAR_REC(YEARMONTH,MANDT,BUKRS,HKONT_T,CVCODE,DMBTR_REC,'2')` |
| `IS_REC_M` | `F_APAR_REC(YEARMONTH,MANDT,BUKRS,HKONT_T,CVCODE,DMBTR_REC_M,'1')` |
| `LCODE_M` | `F_APAR_REC(YEARMONTH,MANDT,BUKRS,HKONT_T,CVCODE,DMBTR_REC_M,'2')` |

仓库中未提供 `F_APAR_REC` 函数定义，因此无法进一步还原返回值判断及编码规则。

---

## 7. 对方公司、税率和币种匹配

### 7.1 对方公司 `CTP`

配置来源：`MAP_REGOLA_TAB_ELEMENTO`。

配置限制：

```text
COD_MAPPATURA = 'HI_DATA_APARAGI'
COD_REGOLA_TAB = 'MAP_CTP'
```

配置转换：

- `ELEDIM_INPUT1` 经 `LTRIM(ELEDIM_INPUT1,'ZTCLIENT.')` 处理后作为客户端；结果为 `800B1` 时再转成 `800B`；
- `ELEDIM_INPUT2` 去前导零后作为客商编码；
- `ELEDIM_INPUT3` 作为客商类型；
- 同一组配置存在多条时取 `MIN(ELEDIM_OUTPUT1)` 作为 `CTP`。

匹配条件：

```text
LTRIM(T3.CVCODE,'0') = LTRIM(IC.CVCODE,'0')
T3.CUSVEN             = IC.CUSVEN
T3.MANDT              = IC.MANDT
```

### 7.2 公司级税率 `TAX`

配置来源及限制：

```text
FORM_DATI.COD_PROSPETTO = 'ZG_IC001_TAXSET'
FORM_DATI.COD_CATEGORIA = '$AMOUNT'
{IN-YEARMONTH} BETWEEN NVL(TESTO_11,'000000') AND NVL(TESTO_12,'999999')
COD_AZIENDA IS NOT NULL
```

匹配条件：`T3.BUKRS = TAX.COD_AZIENDA`。

税率取值：`NVL(IMPORTO_1,0)`。

### 7.3 利润中心级税率 `PRCTRTAX`

配置来源及限制：

```text
FORM_DATI.COD_PROSPETTO = 'ZG_IC001_TAXSET'
FORM_DATI.COD_CATEGORIA = '1REC'
{IN-YEARMONTH} BETWEEN NVL(TESTO_11,'000000') AND NVL(TESTO_12,'999999')
COD_AZIENDA IS NOT NULL
TRIM(TESTO_16) IS NOT NULL
```

匹配条件：

```text
T3.BUKRS = PRCTRTAX.COD_AZIENDA
LTRIM(T3.PRCTR,'0') = LTRIM(PRCTRTAX.TESTO_16,'0')
```

税率取值：`NVL(IMPORTO_1,0)`。

### 7.4 客商特殊税率 `NOTAXCV`

配置来源及限制：

```text
FORM_DATI.COD_PROSPETTO = 'ZG_IC001_TAXSET'
FORM_DATI.COD_CATEGORIA = '1ADJ'
{IN-YEARMONTH} BETWEEN NVL(TESTO_11,'000000') AND NVL(TESTO_12,'999999')
COD_AZIENDA IS NOT NULL
TRIM(TESTO_14) IS NOT NULL
```

匹配条件：

```text
T3.BUKRS = NOTAXCV.COD_AZIENDA
LTRIM(T3.CVCODE,'0') = LTRIM(NOTAXCV.TESTO_14,'0')
```

税率取值：`NVL(IMPORTO_1,0)`。

虽然代码注释称为“无税客户”，但配置实际可设置任意税率，不局限于 0。

### 7.5 最终税率优先级

```text
客商特殊税率 NOTAXCV
    > 利润中心级税率 PRCTRTAX
    > 公司级税率 TAX
    > 默认税率 0.13
```

配置中的 `NULL` 被转换为 0，因此“配置了税率但 `IMPORTO_1` 为空”会按 0 税率处理，不会继续回退到低优先级。

### 7.6 本位币补充

公司主数据来源：`TGK_GB_HISENSE.AZIENDA`。

匹配条件：

```text
T3.BUKRS = AZIENDA.COD_AZIENDA
```

最终本位币：

```sql
NVL(T3.HWAER, AZIENDA.COD_VALUTA)
```

---

## 8. 最终利润中心及名称逻辑

### 8.1 基础清洗

- `PRCTR` 去前导零；
- 清洗结果 `1330201` 改为 `1300201`；
- `KTEXT='容声酒柜'` 改为 `容声冰箱`。

### 8.2 2025-12 静态映射

当 `{IN-YEARMONTH} >= '202512'` 且 `< '202601'` 时：

| 原利润中心 | 输出 `PRCTR` | 输出 `KTEXT` |
|---|---|---|
| `101001001`、`101001002` | `1100101` | `平板电视` |
| `101008002`、`190880002` | `1100104` | 保持原名称 |
| `101056000` | `1100131` | 保持原名称 |
| 其他 | 保持原利润中心 | 保持原名称 |

### 8.3 2026-01 起配置映射

当 `{IN-YEARMONTH} >= '202601'` 时，不再执行上述静态分支，改为：

```text
PRCTR = COALESCE(MP1.ELEDIM_OUTPUT1, MP.ELEDIM_OUTPUT1, A.PRCTR)
KTEXT = COALESCE(MP1.ELEDIM_OUTPUT2, MP.ELEDIM_OUTPUT2, A.KTEXT)
```

#### MP：通用利润中心映射

配置限制：

```text
COD_MAPPATURA = 'HI_DATA_APARAGI'
COD_REGOLA_TAB = 'MAP_PRCTR'
```

匹配条件：`A.PRCTR = MP.ELEDIM_INPUT1`。

#### MP1：公司+客商+利润中心特殊映射

配置限制：

```text
COD_MAPPATURA = 'HI_DATA_APARAGI'
COD_REGOLA_TAB = 'MAP_PRCTR1'
```

匹配条件：

```text
A.BUKRS LIKE MP1.ELEDIM_INPUT1
LTRIM(A.CVCODE,'0') LIKE MP1.ELEDIM_INPUT2
A.PRCTR LIKE MP1.ELEDIM_INPUT3
```

`MP1` 优先于 `MP`。配置值中的 `%` 和 `_` 会按 SQL `LIKE` 通配符解释。

> `MP`、`MP1` 始终参与关联；年月条件只控制最终 `CASE` 是否使用其输出。若配置一对多，即使在 2026-01 以前也可能造成结果行数放大。

---

## 9. 客商性质逻辑

### 9.1 SAP 原始性质 `A.KVERM`

性质来源包括供应商和客户两支数据：

| 客商类型 | 来源表 | 客商字段 | 限制及聚合 |
|---|---|---|---|
| 供应商 `V` | `ODS.ODSS600_LFB1@FMSLK` | `LIFNR` | `TRIM(KVERM) IS NOT NULL`；按 `BUKRS,LIFNR` 分组，取 `MAX(KVERM)`。 |
| 客户 `C` | `ODS.ODSS600_KNB1@FMSLK` | `KUNNR` | `TRIM(KVERM) IS NOT NULL`；按 `BUKRS,KUNNR` 分组，取 `MAX(KVERM)`。 |

两支数据通过 `UNION ALL` 合并，字段均为：

```text
CVCODE, KVERM, BUKRS, CUSVEN
```

匹配条件：

```text
T3.BUKRS  = XINGZHI.BUKRS
T3.CUSVEN = XINGZHI.CUSVEN
T3.CVCODE = XINGZHI.CVCODE
```

### 9.2 性质转换层级

最终 `KVERM` 按以下优先级取值：

```text
LEVEL6 科目+客商级
  > LEVEL5 客商级
  > LEVEL4 利润中心级
  > LEVEL3 公司+科目级
  > LEVEL2 系统级 LIKE 映射
  > 特定公司层级节点清空
  > SAP 原始性质 A.KVERM
```

#### LEVEL2：系统级性质映射

配置来源：`TGK_GB_HISENSE.MAP_REGOLA_TAB_ELEMENTO`。

```text
COD_MAPPATURA = 'HI_DATA_APARAGI'
COD_REGOLA_TAB = 'TYPE'
```

匹配条件：

```text
NVL(A.MANDT,'|')  LIKE ELEDIM_INPUT1
NVL(A.HKONT,'|')  LIKE ELEDIM_INPUT2
NVL(A.CVCODE,'|') LIKE ELEDIM_INPUT3
```

输出性质：`ELEDIM_OUTPUT1`。

#### LEVEL3：公司+科目级

配置来源：`TGK_GB_HISENSE.FORM_DATI`。

```text
COD_PROSPETTO = 'ZS_APAR01_IPT02'
COD_CATEGORIA = 'XT04'
NVL(TESTO_17,'N') <> 'Y'
```

匹配条件：

```text
A.MANDT = TESTO_1
A.HKONT = TESTO_2
A.BUKRS = COD_AZIENDA
```

配置去重限制：按 `TESTO_1+TESTO_2+COD_AZIENDA` 在 `V_SQL_FORM_DATI` 中统计；同一完整键超过 1 条时，该键的全部配置均被排除。

#### LEVEL4：利润中心级

配置来源：`TGK_GB_HISENSE.FORM_DATI`。

```text
COD_PROSPETTO = 'ZS_APAR01_IPT02'
COD_CATEGORIA = 'XT03'
COD_AZIENDA、TESTO_1、TESTO_2、TESTO_7 均非空
NVL(TESTO_17,'N') <> 'Y'
```

匹配条件：

```text
A.MANDT = TESTO_1
A.HKONT = TESTO_2
A.PRCTR = TESTO_7
A.BUKRS = COD_AZIENDA
```

配置去重限制：按 `TESTO_1+TESTO_2+TESTO_7+COD_AZIENDA` 统计；重复完整键全部排除。

#### LEVEL5：客商级

配置来源：`TGK_GB_HISENSE.FORM_DATI`。

```text
COD_PROSPETTO = 'ZS_APAR01_IPT02'
COD_CATEGORIA = 'XT02'
COD_AZIENDA、TESTO_1、TESTO_3 均非空
NVL(TESTO_17,'N') <> 'Y'
```

匹配条件：

```text
A.MANDT  = TESTO_1
A.CVCODE = TESTO_3
A.BUKRS  = COD_AZIENDA
```

配置去重限制理论键为 `TESTO_1+TESTO_3+COD_AZIENDA`，但重复检测子查询使用的类别为 `'$XT02'`，与外层的 `'XT02'` 不一致，详见风险说明。

#### LEVEL6：科目+客商级

配置来源：`TGK_GB_HISENSE.FORM_DATI`。

```text
COD_PROSPETTO = 'ZS_APAR01_IPT02'
COD_CATEGORIA = '$AMOUNT'
COD_AZIENDA、TESTO_1、TESTO_2、TESTO_3 均非空
NVL(TESTO_17,'N') <> 'Y'
```

匹配条件：

```text
A.MANDT  = TESTO_1
A.HKONT  = TESTO_2
A.CVCODE = TESTO_3
A.BUKRS  = COD_AZIENDA
```

配置去重限制：按 `TESTO_1+TESTO_2+TESTO_3+COD_AZIENDA` 统计；重复完整键全部排除。

### 9.3 各性质输出字段

| 输出字段 | LEVEL6 | LEVEL5 | LEVEL4 | LEVEL3 | LEVEL2 | SAP 原始性质 |
|---|---|---|---|---|---|---|
| `KVERM` | `TESTO_4` | `TESTO_4` | `TESTO_4` | `TESTO_4` | `ELEDIM_OUTPUT1` | 有后备 |
| `KVERM_1` | `TESTO_12` | `TESTO_12` | `TESTO_12` | `TESTO_12` | 无 | 无 |
| `KVERM_2` | `TESTO_13` | `TESTO_13` | `TESTO_13` | `TESTO_13` | 无 | 无 |

### 9.4 特定公司节点清空性质

仅当 LEVEL6～LEVEL2 均未匹配时，执行以下判断：

公司 `A.BUKRS` 属于 `V_REF_AZIENDA_TV` 中：

```text
HIE          = '30'
COD_SCENARIO = SUBSTR({IN-YEARMONTH},1,4) || 'ACT'
COD_PERIODO  = SUBSTR({IN-YEARMONTH},5,2)
NODE         = '2000'
```

并且公司代码不以 `23` 或 `26` 开头时，最终 `KVERM` 返回 `''`。在 Oracle 中空字符串等同于 `NULL`。

---

## 10. 全部关联匹配条件汇总

| 序号 | 关联对象 | 关联方式 | 匹配条件 | 用途 |
|---:|---|---|---|---|
| 1 | `HBCV` | `LEFT JOIN` | 第一阶段公司相等；源客商与配置客商去前导零后相等 | 取得合并客商 `CVCODE_HB`。 |
| 2 | `AZI_MAP` | `LEFT JOIN` | 第一阶段公司=`SRC_ENT`；标准化客户端=`SRC_MANDT` | 取得最终映射公司。 |
| 3 | `XINGZHI` | `LEFT JOIN` | 最终公司+客商类型+原客商编码精确相等 | 取得 SAP 原始性质。 |
| 4 | `IC` | `LEFT JOIN` | 客商去前导零相等；客商类型相等；客户端相等 | 取得对方公司 `CTP`。 |
| 5 | `TAX` | `LEFT JOIN` | 最终公司相等 | 取得公司级税率。 |
| 6 | `PRCTRTAX` | `LEFT JOIN` | 最终公司相等；利润中心去前导零后相等 | 取得利润中心级税率。 |
| 7 | `NOTAXCV` | `LEFT JOIN` | 最终公司相等；客商去前导零后相等 | 取得客商特殊税率。 |
| 8 | `AZIENDA BZ` | `LEFT JOIN` | 最终公司相等 | 源本位币为空时补公司币种。 |
| 9 | `LEVEL2` | `LEFT JOIN` | 客户端、原科目、原客商分别按配置执行 `LIKE` | 系统级性质映射。 |
| 10 | `LEVEL3` | `LEFT JOIN` | 客户端+原科目+最终公司 | 公司+科目级性质。 |
| 11 | `LEVEL4` | `LEFT JOIN` | 客户端+原科目+基础利润中心+最终公司 | 利润中心级性质。 |
| 12 | `LEVEL5` | `LEFT JOIN` | 客户端+原客商+最终公司 | 客商级性质。 |
| 13 | `LEVEL6` | `LEFT JOIN` | 客户端+原科目+原客商+最终公司 | 科目+客商级性质。 |
| 14 | `MP` | `LEFT JOIN` | 基础利润中心精确匹配 `ELEDIM_INPUT1` | 通用利润中心/名称映射。 |
| 15 | `MP1` | `LEFT JOIN` | 最终公司、去前导零客商、基础利润中心分别按配置执行 `LIKE` | 特殊利润中心/名称映射，优先于 MP。 |

> 性质 LEVEL3～LEVEL6 使用的是原始科目 `HKONT`，不是合并后的 `HKONT_T`；LEVEL4 使用最终输出映射前的基础 `A.PRCTR`。

---

## 11. 全部限制条件汇总

### 11.1 主源数据限制

```sql
KEYDAT = LAST_DAY(TO_DATE({IN-YEARMONTH},'YYYYMM'))
```

只取参数年月的月末快照。

```sql
NOT (MANDT='800B' AND BUKRS='4220')
```

排除源数据中原始客户端 `800B`、原始公司 `4220` 的记录。原始公司为 `4221` 的记录不受此条件影响，后续仍会转换为 `4220`。

```sql
NOT (
  DMBTR0=0 AND DMBTR1=0 AND ... AND DMBTR9=0
)
```

排除十个本位币金额桶全部为 0 的记录。该条件不检查 `WRBTR0～WRBTR9`；即使交易币金额非 0，只要十个 `DMBTR` 都为 0，记录仍会被排除。

```sql
TRIM(HKONT) <> '2801020000'
```

排除预计负债—保修准备科目 `2801020000`。

### 11.2 公司范围限制

```sql
NVL(AZI_MAP.TAG_ENT,T.BUKRS) IN ({IN-ENTITY})
```

按最终映射公司限定组织范围，不按原始公司限定。

### 11.3 最终名称限制

```sql
A.NAME1 NOT IN ('应收账款-信汇','应付账款-信汇')
```

排除两类信汇记录。由于 Oracle `NULL NOT IN (...)` 的结果不是 `TRUE`，`NAME1 IS NULL` 的记录也会被过滤。

### 11.4 配置有效性限制

- 税率配置均按 `{IN-YEARMONTH}` 落在 `TESTO_11～TESTO_12` 的有效期内；
- 性质 LEVEL3～LEVEL6 均排除 `NVL(TESTO_17,'N')='Y'` 的禁用记录；
- 性质 LEVEL3～LEVEL6 对重复完整键采用“整组排除”，不是任选一条；
- HBCV 使用 `TESTO_13` 同时作为有效期上下界；
- SAP 客商性质仅保留 `KVERM` 非空的记录；
- LEVEL2、MP1 使用 `LIKE`，配置中的 `%/_` 会影响匹配范围。

---

## 12. 涉及对象清单

| 对象 | 作用 |
|---|---|
| `dw.DWFI_TF_ARAP_AGING@FMSLK` | 往来账龄月末快照主源。 |
| `MAP_REGOLA_TAB_ELEMENTO` | 公司映射 `MAP_BUKRS_800C`、对方公司 `MAP_CTP`。 |
| `TGK_GB_HISENSE.MAP_REGOLA_TAB_ELEMENTO` | 性质 LEVEL2、利润中心 `MAP_PRCTR/MAP_PRCTR1` 映射。 |
| `FORM_DATI` | 合并客商和税率配置。 |
| `TGK_GB_HISENSE.FORM_DATI` | LEVEL3～LEVEL6 性质配置。 |
| `V_SQL_FORM_DATI` | 检测性质配置重复完整键。 |
| `ODS.ODSS600_LFB1@FMSLK` | 供应商公司级性质。 |
| `ODS.ODSS600_KNB1@FMSLK` | 客户公司级性质。 |
| `TGK_GB_HISENSE.AZIENDA` | 公司本位币。 |
| `V_REF_AZIENDA_TV` | 判断公司是否属于指定层级节点。 |
| `F_APAR_REC` | 计算重分类标志及编码。 |

---

## 13. 代码风险及待确认事项

### 13.1 无物理目标表及装载策略

当前文件只有查询，没有目标表、插入字段、删除范围、分区替换或提交逻辑。因此无法确认：

- 最终写入哪张表；
- 是否先删后插、覆盖分区或追加；
- 同月重复运行是否幂等；
- 46 个结果字段在目标表中的类型及约束。

### 13.2 `F_APAR_REC` 函数定义缺失

无法从当前文件确定 `IS_REC/LCODE/IS_REC_M/LCODE_M` 的准确返回规则。需要函数 DDL 或业务口径补充。

### 13.3 HBCV 有效期上下界使用同一字段

当前代码为：

```sql
{IN-YEARMONTH} BETWEEN NVL(TRIM(TESTO_13),'0')
                   AND NVL(TRIM(TESTO_13),'999999')
```

当 `TESTO_13` 非空时，只有运行年月恰好等于 `TESTO_13` 才能匹配。若配置设计为起止期间，结束期间可能应读取其他字段，需要确认。

### 13.4 LEVEL5 重复检测类别不一致

LEVEL5 外层配置类别为 `'XT02'`，重复检测子查询却使用 `'$XT02'`。这可能导致 `XT02` 重复配置未被排除，进而一条事实记录匹配多条性质配置并放大结果行数。

### 13.5 多个配置关联存在一对多放大风险

以下配置未在当前 SQL 中完全保证匹配键唯一：

- `AZI_MAP`；
- `HBCV`；
- `TAX/PRCTRTAX/NOTAXCV`；
- `LEVEL2`；
- `MP/MP1`。

任一配置匹配多条都会复制事实记录。建议在执行前检查配置键唯一性。

### 13.6 `LTRIM` 不是固定前缀删除

```sql
LTRIM(ELEDIM_INPUT1,'ZTCLIENT.')
```

Oracle 会把第二个参数视为字符集合，而不是固定字符串 `ZTCLIENT.`。它会持续删除左侧属于该字符集合的字符，可能误删有效客户端字符。若目的是删除固定前缀，建议另行确认实现。

### 13.7 `LIKE` 规则可能多重匹配

LEVEL2 和 MP1 直接以配置作为 `LIKE` 模式。若模式范围重叠，一条事实记录可能匹配多条配置；SQL 未定义配置间优先级，也未去重。

### 13.8 客商类型默认范围较宽

`KOART='D'` 才归客户，所有其他值均归供应商。如果源表存在非客户、非供应商的其他科目类型，也会被标记为 `V`，需确认源数据范围。

### 13.9 分户账号逻辑未启用

注释说明“取分户账号”，但实际 `CVCODE` 仍固定取 `OBJECT`；原计划的 `NVL(FILKD,OBJECT)` 被注释，需确认当前业务口径。

### 13.10 账龄桶区间无法由本文件确定

本文件只引用 `DMBTR0～DMBTR9`、`WRBTR0～WRBTR9`，未给出各桶对应的天数/月数区间。需要源表设计或上游生成逻辑补充。

### 13.11 名称为空会被最终过滤

最终 `A.NAME1 NOT IN (...)` 会同时排除 `NAME1 IS NULL` 的记录。如仅需排除两个指定名称，应确认是否需要保留空名称。

### 13.12 查询结果无固定顺序

最终没有 `ORDER BY`，因此结果行顺序不保证稳定。
