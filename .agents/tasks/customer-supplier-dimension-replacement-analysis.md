# 客户/供应商统一维表替换分析报告

> **只读分析声明：本次仅阅读并分析目标 SQL 及项目内可检索到的相关 SQL，未修改任何 SQL 或其他项目文件，未提交代码。**
>
> 目标文件：`/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/dwd_fi_mr_arap_detail_mi.sql`

## 摘要结论

1. 这次替换的核心范围只在第一段“统驭科目凭证行项目”（约第 32–1706 行）：旧的 `src_kna1`、`src_lfa1`、`customer_dim`、`vendor_dim`、`customer_class_dim`、`cp_company_dim` 应收敛为“SAP 编码三元组 → MDG 客商编码 → 统一客商属性”的维度链。第二段“非统驭科目月末累计余额”（约第 1708 行至文件末尾）没有客商编码或客商维度 JOIN，不应为本次客户供应商替换增加维度关联。
2. 新链路应以 `dim.dim_fi_mr_customer_map_dd(cust_sap_code, cust_sap_client, cust_supp_type)` 为第一跳，再以得到的 `cust_mdg_code` 匹配 `dim.dim_fi_mr_customer_dd(cust_code)`；不能仅按 SAP 编码连接。`system_src` 必须显式转换为 `cust_sap_client`，并保留 S610/S810 在共享物理表时的 `mandt/client` 隔离。
3. 旧 SQL 将客户/供应商主数据编码和 MDG 编码统一 `LTRIM(...,'0')`；新表字段语义同时存在 SAP 码、MDG 码，建议内部保留“原值用于维表匹配、标准化值用于现有输出/规则匹配”两套字段，不能对所有新字段无条件去零。尤其要先确认新维表实际存储是否已经去零。
4. `cp_company_code` 旧值来自 `dim.dim_rule_fi_mr_cust2ctp_mapping` 的 `cp_company_code_mr` 优先、`cp_company_code` 兜底（约第 950–968 行）。新统一表明确提供 `cp_company_code/cp_company_mr_code/cp_company_le_code`，最接近旧语义的替换是 `COALESCE(NULLIF(TRIM(cp_company_mr_code),''),TRIM(cp_company_code))`，但需业务确认旧 mapping 的“对方公司”是否确实对应新表的 MR 码/普通码，而不是法人码。
5. 目标表当前输出的客户分类和国家可以直接由统一客商表提供；营销模式表能够提供 `market_mode_code/name`，但目标表目前没有营销模式输出列，且 `marketing_dept_code/name` 是另一套按利润中心/性质规则得到的“业务管理单元”，不能直接用营销模式字段替代。
6. 当前 `cust_kverm_dim` 仍读取六套 `knb1/lfb1` 的 KVERM 付款条件，并把供应商类型写成 `V`。新 map 的说明类型为 `C/S`，推荐只在新维度链的类型边界做 `V → S` 转换（或统一派生 `dim_cust_type = CASE object_source WHEN 'CUSTOMER' THEN 'C' ELSE 'S' END`），不要把事实层 `acct_type_code` 的 D/K 改成 C/S。

## 一、目标 SQL 的实际结构与旧来源证据

### 1. 事实输入和系统标识

- `src_ztzt_003`、`src_t001`、`src_skb1` 在约第 110–207 行分别按 S600、S700、S800、S900、S610、S810 汇总科目范围、公司币种和统驭标识。
- `src_bsid`/`src_bsad`（约第 366–540 行）输入客户行项目；`src_bsik`/`src_bsak`（约第 542–652 行）输入供应商行项目。四个 CTE 均携带 `system_src` 和 `cust_head_code`，其中客户取 `kunnr`，供应商取 `lifnr`，分户取 `filkd`。
- S610/S810 的行项目实际使用 `ods.odsslt_s810_*` 物理表，并分别通过 `mandt = '610'`、`mandt = '810'` 筛选（例如 `src_bsid`、`src_bsad`、`src_bsik`、`src_bsak` 的对应分支）。因此新维表若也共用物理数据，必须把 `system_src='S610'` 映射到 `cust_sap_client='610'`，`system_src='S810'` 映射到 `cust_sap_client='810'`，不能只按物理表名或只按 SAP 编码匹配。
- `unioned_items`（约第 670–696 行）把客户/供应商分别标成 `object_source='CUSTOMER'/'VENDOR'`，并把科目类型标成 D/K；这是后续维度类型判断的可靠边界。
- `normalized_items`（约第 782–905 行）将 `cust_head_code`、`cust_branch_code` 都做 `LTRIM(...,'0')`，同时保留 `object_source`。因此后续新维度匹配必须与该标准化策略兼容，或在维度 CTE 中重新保留原始码。

### 2. 旧 KNA1/LFA1 来源

- `src_kna1`（约第 210–238 行）从六套 `ods.odss600_kna1`、`odss700_kna1`、`odss800_kna1`、`odss900_kna1`、`odss610_kna1`、`odss810_kna1` 取 `kunnr/name1/zkunnr_mdg`。
- `src_lfa1`（约第 240–268 行）从对应六套 `lfa1` 取 `lifnr/name1/zlifnr_mdg`。
- `customer_dim`（约第 916–925 行）按 `system_src + LTRIM(kunnr,'0')` 聚合，输出 `name1` 和 `LTRIM(zkunnr_mdg,'0')`；`vendor_dim`（约第 926–935 行）同理。
- 这两套 CTE 同时承担两类功能：主/分户名称，以及从 SAP 客商码取得 MDG 码。前者可由统一客商表 `cust_name` 替换，后者应改成 map 表三字段匹配后取 `cust_mdg_code`，不能只把表名替换而保留旧的单字段 JOIN。

### 3. 旧统一客商表来源

- `customer_class_dim`（约第 936–949 行）从 `dw.dim_customer_base_info_dd` 按 `LTRIM(cust_code,'0')` 聚合，取 `com_1st/2nd/3rd_code/name` 及 `country_code/name`。
- 它在 `nf_match_base`（约第 1026–1068 行）、`ar_mapping_base`（约第 1192–1252 行）和最终第一段 SELECT（约第 1677–1684 行）被关联；这些下游依赖必须保留，但来源改为新 `dim_fi_mr_customer_dd`。
- 因为新表字段清单明确提供 `com_1st/2nd/3rd_code/name`、`country_code/name`，这一部分是最直接的可替换逻辑；建议新 CTE 先按 `cust_code` 去重/聚合，维持现有一行维度记录进入事实的假设。

### 4. 旧对方公司 mapping 来源

- `cp_company_dim`（约第 950–968 行）从 `dim.dim_rule_fi_mr_cust2ctp_mapping` 取 `cust_code/cust_type_code/system_src`，按有效期过滤，输出 `MAX(COALESCE(NULLIF(TRIM(cp_company_code_mr),''),TRIM(cp_company_code)))`。
- `nf_match_base`（约第 1061–1067 行）按主户编码、系统、C/V 类型关联它；最终第一段 SELECT（约第 1684–1689 行）再次关联它输出 `cp_company_code`。
- 新统一客商表有 `cp_company_code`、`cp_company_mr_code`、`cp_company_le_code`，可覆盖旧 mapping 的主要输出，但不能从目标 SQL 单独证明三者与旧字段的业务定义一一相等；法人编码 `cp_company_le_code` 不应未经确认替代当前字段。

### 5. 仍未被旧客户维度替换的规则依赖

- `cust_kverm_dim`（约第 270–334 行）读取 `knb1/lfb1` 的 KVERM，并按 system/company/customer code/type 聚合；`ar_mapping_base`（约第 1216–1249 行）使用 `k.kverm`，`ar_business_mapping`（约第 1484–1522 行）在没有性质规则命中时将其作为 `nature_l1_name`。这是付款条件/性质兜底，不是 KNA1/LFA1 的名称或 MDG 属性，不能因删除 `src_kna1/src_lfa1` 而误删。
- `ecom_retail_cust`、`ar_nf_*`、`ar_nature_*`、`ar_busrange_*`、`ar_busdept_*` 等规则 CTE 仍是业务规则依赖；新客户属性只应替换其输入上下文字段，不应重写规则优先级。

## 二、新字段与当前输出的对应关系

| 当前输出/中间用途 | 当前来源 | 新表建议来源 | 结论 |
|---|---|---|---|
| `cust_code` | `cust_branch_code` 非空则分户，否则主户；见最终第一段约第 1545–1580、`normalized_items` 约第 863–864 行 | 事实上的 SAP 主/分户码先经 map 得 `cust_mdg_code`，再以 `cust_code` 取属性；输出编码仍按现有事实规则 | 可替换，但需分别为主户和分户做 map，不能只映射主户 |
| `cust_name` | 主/分户 KNA1/LFA1 `name1` | `dim_fi_mr_customer_dd.cust_name`；主户和分户分别 lookup | 直接替换 |
| `cust_head_name` / `cust_branch_name` | `customer_dim/vendor_dim.name1` | 统一客商表 `cust_name`，按主/分户各自 MDG 码取 | 直接替换，注意分户为空时仍保持当前 NULL/空值行为 |
| `cust_head_code` / `cust_branch_code` | `normalized_items` 对 SAP `kunnr/lifnr/filkd` 去零 | 仍由事实行项目产生；仅用 map 做查找，不建议用 MDG 码覆盖这两个 SAP 业务编码 | 不应改成 `cust_mdg_code`，否则会改变输出含义 |
| `com_1st/2nd/3rd_code/name` | `dw.dim_customer_base_info_dd` | `dim_fi_mr_customer_dd` 同名字段 | 直接替换；保留 `MAX`/唯一性保护 |
| `country_code/name` | `dw.dim_customer_base_info_dd` | `dim_fi_mr_customer_dd` 同名字段 | 直接替换；供 `ar_business_mapping` 的 CN/海外判断 |
| `cp_company_code` | 旧 mapping 的 MR 码优先、普通码兜底 | 建议 MR 码优先：`COALESCE(NULLIF(TRIM(cp_company_mr_code),''),TRIM(cp_company_code))` | 需确认新旧码的业务等价性；LE 码暂不使用 |
| `channel_l1/l2/l3` | `customer_class_dim` | 新客商表 `com_1st/2nd/3rd_*` | 可直接替换 |
| `onoffline_*` | `ar_nf`/`rev_nf` 规则和默认值 | 不由新客商表直接提供 | 不改规则；新客户表仅提供规则匹配所需分类和对方公司上下文 |
| `cc_cust_group_*`、`tov_channel_*` | 当前第一段直接 NULL | 新表有 `cust_group_ccc_code/name`，但目标列是 `cc_cust_group_*` | 建议确认后映射 `cust_group_ccc_* → cc_cust_group_*`；`tov_channel_*` 无明显等价新字段，继续 NULL |
| `marketing_dept_*` | `ar_busdept_mapping` 按 system/profitcenter/nature 规则 | 新营销模式表的 `market_mode_*` 不是同名业务管理单元 | 不替换。业务管理单元仍走 `ar_busdept_*`；如要新增营销模式，应新增目标列或另行需求 |
| `market_mode_code/name` | 目标 SQL 当前无输出列 | `dim_fi_mr_cus_mkt_mode_mdg_dd.market_mode_code/name` | 可作为未来字段补充，但当前目标表无法无损输出；该表还要求按 `cust_code` 等业务键确认 sale_org/material_group 过滤 |
| `KVERM`/`nature_l1_name` 兜底 | 六套 `knb1/lfb1` 的 `kverm` | 新客商表字段清单未提供 KVERM | 保留旧来源，除非另有新字段/新规则确认 |

## 三、六套系统与 `cust_sap_client` 映射建议

建议在新的 map lookup CTE 中显式派生：

```sql
CASE a.system_src
    WHEN 'S600' THEN '600'
    WHEN 'S700' THEN '700'
    WHEN 'S800' THEN '800'
    WHEN 'S900' THEN '900'
    WHEN 'S610' THEN '610'
    WHEN 'S810' THEN '810'
END AS cust_sap_client
```

其中 `cust_sap_code` 应取当前事实中的 `cust_head_code` 或 `cust_branch_code` 对应的 SAP 客商编码；`cust_supp_type` 应由 `object_source` 派生。连接键建议为：

```sql
map.cust_sap_code = <原始或统一规范化的 SAP 客商编码>
AND map.cust_sap_client = <上述客户端>
AND map.cust_supp_type = CASE WHEN object_source = 'CUSTOMER' THEN 'C' ELSE 'S' END
```

注意：目标 SQL 的 S610/S810 客户和供应商主数据当前各自引用 `odss610_*`/`odss810_*`，但行项目已经证明 S610/S810 共用 `ods.odsslt_s810_*` 且依赖 `mandt`。新 map 维表若同样将 S610/S810 存在一张物理表，应以 `cust_sap_client` 区分，不能把两者合并成一个系统或仅按 `cust_sap_code` 关联。

`S700` 还存在公司编码标准化（`s700_company_map`，约第 103–108 行及多处行项目 CTE）；这只影响 `company_code`，不应错误地把公司码当成 `cust_sap_client`。系统客户端和公司代码是两个独立连接维度。

## 四、编码、类型与匹配风险

### 1. `cust_sap_code` 是否去前导零

当前 `normalized_items` 已把 `cust_head_code`、`cust_branch_code` 去零（约第 863–864 行），旧 `customer_dim/vendor_dim` 也在 CTE 内去零并按去零值分组（约第 918–934 行），因此旧逻辑依赖“事实码和维度码都去零”。新 map 的三元组是第一跳，建议：

- 若新表 `cust_sap_code` 保留 SAP 原始定长码，则 map lookup 用 `LPAD`/原始码对齐，或在 map CTE 中同时生成规范化码，不能只拿已经去零的事实值直接匹配。
- 若新表已去零，则 map lookup 使用 `LTRIM` 后的事实码；必须先以抽样 SQL 验证。
- 对 `cust_sap_code='0000...'` 的全零值，Doris `LTRIM` 可能变成空串；应使用 `NULLIF` 保护，避免空编码误匹配。
- 同一个 SAP 编码在不同客户端或 C/S 类型下可能合法重复，所以去零绝不能脱离 `cust_sap_client + cust_supp_type`。

### 2. `cust_mdg_code` 与 `cust_code` 是否去零

旧逻辑把 `zkunnr_mdg/zlifnr_mdg` 和 `dim_customer_base_info_dd.cust_code` 都去零（约第 920–948 行）。新链路的第二跳应优先使用 map 返回的 `cust_mdg_code` 与统一表 `cust_code` 做同一规范化比较；建议在同一 CTE 中同时保留：

- `cust_mdg_code_raw`/`cust_code_raw`：用于审计和发现编码格式不一致；
- `cust_mdg_code_norm`/`cust_code_norm`：用于延续当前规则的去零匹配。

不能只对 map 表的 `cust_mdg_code` 去零而不处理统一表 `cust_code`，也不能把最终输出的 SAP `cust_head_code/cust_branch_code` 改成 MDG 码。新表的 `cust_code` 若本身是字符串编码，空值、全零、非数字前缀均应保留并单独确认，不宜假设全部是纯数字。

### 3. C/V 与 C/S

当前 SQL 有三套不同语义：

- `object_source` 为 CUSTOMER/VENDOR（约第 670–696 行）；
- 统驭/总账科目类型为 D/K（约第 654–667、1916–1930 行）；
- `cust_kverm_dim` 和 `cp_company_dim` 使用 C/V（约第 276–332、962 行）。

新表定义为 C/S 时，建议在新维度 lookup 层统一转换：客户 `C`，供应商将旧 `V` 语义转换为新 `S`。`cp_company_dim` 如保留兼容接口，可内部输出旧别名 `V`，但与新表 JOIN 时使用 `S`；`cust_kverm_dim` 仍是旧表逻辑，暂不改其物理来源和 C/V 字面值。必须先确认新表的 S 确实表示 Supplier，而不是其他业务类型。

## 五、按 CTE 边界的最小修改方案（供确认后实施）

1. **不改事实来源和第二段。** 保留 `src_bsid/src_bsad/src_bsik/src_bsak`、`unioned_items`、`all_items`、`normalized_items` 的取数、日期、金额、账龄和 S610/S810 `mandt` 逻辑。
2. **替换 `src_kna1/src_lfa1` 的下游接口，而非简单改表名。** 可删除或停用这两个旧 CTE，新增一个统一 map lookup CTE，输入 `system_src/object_source/cust_head_code/cust_branch_code`，输出主户、分户各自的 `cust_mdg_code` 和统一表属性。map JOIN 必须包含 SAP 编码、客户端、C/S 类型三个条件。
3. **合并 `customer_dim/vendor_dim` 的职责。** 推荐形成一个 `customer_supplier_dim`（名称可按项目命名规范确认）并保证每个 `system_src + SAP码 + object_source` 至多一行；主户和分户通过两次别名 JOIN 或一次主/分户展开得到名称和 MDG 码。这样 `nf_match_base`、`ar_mapping_base`、最终 SELECT 中原有的 customer/vendor 分支可以最小化调整。
4. **替换 `customer_class_dim`。** 从 `dim.dim_fi_mr_customer_dd` 取 `com_1st/2nd/3rd_*`、`country_*`；按规范化 `cust_code` 聚合。第二跳 key 采用 map 返回的 MDG 码，保留 `MAX` 只是防止重复，不应掩盖同一个 MDG 码多国家/分类的真实冲突。
5. **替换 `cp_company_dim`。** 从统一客商表按 MDG `cust_code`（必要时同时保留 system/type 过滤）输出 `cp_company_code`，优先 MR 码、普通码兜底；暂不使用 LE 码。若新表没有 system/client/type 粒度，需要确认同一 MDG 客商跨 SAP/客户供应商类型时是否会多值。
6. **保持下游规则接口。** `nf_match_base` 继续提供 `channel_l1_code/channel_l3_code/cp_company_code`；`ar_mapping_base` 继续提供 `channel_l1_code/channel_l2_code/country_code/kverm`；`ar_business_mapping` 继续产生业务范围、业务管理单元和三级性质。这样替换不改变规则优先级。
7. **营销模式只做可选扩展。** 当前目标列没有 `market_mode_code/name`，不能把新营销模式表硬塞入 `marketing_dept_*`。若用户确认要输出营销模式，需先修改目标表列清单和两段 INSERT 列映射，并明确 `sale_org/material_group_code` 的取值来源；否则本次不关联营销模式表。
8. **校验事实粒度。** 在每个维度 CTE 完成去重后，验证 map 三元组唯一、MDG `cust_code` 唯一或有明确优先级；最终应比较第一段替换前后事实行数和金额合计，不得用 `DISTINCT` 掩盖一对多。

## 六、潜在一对多和事实行膨胀风险

- map 表若同一 `(cust_sap_code,cust_sap_client,cust_supp_type)` 有多条 `cust_mdg_code`，主户或分户 JOIN 会直接复制凭证明细。
- 统一客商表若同一 `cust_code` 存在多版本、国家、公司或加载日期记录，`customer_class_dim` 的 `MAX` 可能得到“字段分别来自不同记录”的混合属性；应先按明确生效/加载规则选一行，再投影字段。
- 同一个 MDG 客商可能既作为客户又作为供应商；若新表没有类型/客户端粒度，按 MDG 码关联会把 C/S 属性混用。
- `dim_fi_mr_cus_mkt_mode_mdg_dd` 明确含 `sale_org`、`material_group_code` 等粒度；若只按 `cust_code` 关联，很容易一对多。即使最终只取营销模式，也必须按目标事实的销售组织/物料组补齐 key，或先制定确定性优先级。
- 旧 SQL 已在 `customer_dim/vendor_dim/customer_class_dim/cp_company_dim` 使用 `GROUP BY + MAX` 防止普通重复，但 `MAX` 不是业务去重规则；新维表迁移不应默认沿用而不检查冲突。
- `nf_match_base` 和 `ar_mapping_base` 通过事实 MD5 key 回接最终事实；如果维度上下文膨胀，后续 `ar_nf_*`、`ar_nature_*`、`ar_business_mapping` 可能先放大，再按 fact key 聚合，造成金额重复或规则结果不确定。

## 七、第二段非统驭余额是否需要改动

结论：**按本次客户/供应商维表替换，不需要改动第二段。**

证据：第二段从约第 1916 行的 `gl_account_cfg`、约第 1930 行的 `src_gl_balance`、约第 2070 行的 `balance_detail/balance_agg` 生成非统驭科目余额；最终 SELECT（约第 2220 行以后）对 `cust_code/cust_name/cust_head_code/cust_branch_code/cp_company_code/country/channel` 等字段全部输出 NULL。它只关联公司范围、业务范围规则、账龄段、科目映射、公司币种和利润中心文本，不读取 KNA1/LFA1、旧 customer base、旧 cust2ctp mapping 或新三张客商表。

唯一需要在未来整体重构中留意的是：第一段和第二段各自重复定义了 `src_t001/src_skb1/src_cepct` 等 CTE，但这属于现有脚本结构，不是本次客商维度替换的依赖；不要为了统一维度而扩大改动范围。

## 八、需要用户确认的问题

1. `cust_sap_code`、`cust_mdg_code`、统一表 `cust_code` 在新维表中的实际存储格式是保留前导零还是已去零？请提供各系统各抽样值，尤其 S610/S810。
2. `cust_sap_client` 的实际值是否就是 `600/700/800/900/610/810`，还是带 `S` 前缀？S610/S810 共用物理表时是否以 `mandt` 区分？
3. 新表 `cust_supp_type='S'` 是否严格等价旧 SQL 的供应商 `V`？是否存在同一 SAP 码同时 C/S 的记录？
4. 新表 `cust_sap_code` 是否覆盖 `filkd` 分户编码，还是只覆盖 `kunnr/lifnr` 主户编码？如果不覆盖分户，`cust_branch_name/cust_name` 需要保留旧 KNA1/LFA1 兜底还是允许为空？
5. `cp_company_mr_code` 是否就是旧 `cp_company_code_mr` 的同一业务含义？普通 `cp_company_code` 与旧 mapping 的 `cp_company_code` 是否同口径？`cp_company_le_code` 是否只作为法人编码，不参与当前 `cp_company_code` 输出？
6. 统一客商表是否按 MDG 客商唯一一行，还是按系统、客户/供应商类型、加载日期、组织等维度多行？如多行，生效/最新记录规则是什么？
7. `cc_cust_group_code/name` 是否要求填入目标的 `cc_cust_group_*`；如果要求，是否从主户还是分户 MDG 码取？
8. 用户是否希望本次同时新增营销模式输出？若是，需要目标表新增哪些列，以及 `sale_org/material_group_code` 分别从当前 ARAP 事实的哪个字段取得；否则本次只替换已有输出，不使用营销模式表。
9. 新表能否提供或替代 KVERM？当前 `nature_l1_name` 无规则命中时依赖 KVERM；若不能，`cust_kverm_dim` 必须继续保留六套 KNB1/LFB1。
10. 是否要求保留旧数据输出编码格式（去前导零）和旧事实行数/金额合计作为回归基线？建议确认并作为实施后的验收条件。

## 九、实施后建议的验证（本报告不执行）

- 对每个系统、客户/供应商类型，验证 map 三元组唯一性，以及 map → MDG → 客商属性的未匹配数。
- 比较替换前后第一段行数、`bcy_amt/qcy_amt` 按 `system_src/company_code/acct_type_code` 汇总值；客商属性变化应不改变事实金额。
- 验证 S610/S810 的 map 命中不会串户；特别检查共享物理表中 `cust_sap_client`/`mandt` 的隔离。
- 抽查主户、分户、跨 C/S 同码、前导零、无 MDG 码、无对方公司码和多版本维度记录。
- 单独执行第二段前后行数与余额合计比较，确认它没有因第一段维度改造而被意外改变；按脚本注释，两个 INSERT 必须在同一 session 顺序执行，第二段重复执行会产生重复余额行。

## 十、补充核对：batch_id=4 利润中心映射与同一原始利润中心出现两种结果

### 1. batch_id=4 本身的匹配条件是“公司 + 线上线下编码”，不是“公司 + 原始利润中心”

目标 SQL 的 `ar_profitcenter_rule`（约第 1152–1172 行）读取 `dim.dim_rule_fi_mr_ar_profit_mapping`，保留 batch 1、3、4、5；其中规则字段被统一规范化：

- `company_code`：通过 `ods.odsfima_azienda` 展开后 `LTRIM(TRIM(...),'0')`；
- `src_profitcenter_code`：规则表字段本身也去前导零；
- `onoffline_code`：规则表字段去前导零；
- 同一 `batch_id + company_code + src_profitcenter_code + acct_src_code + onoffline_code` 使用 `MAX` 聚合。

`profitcenter_candidate` 的 batch 4 分支（约第 1310–1336 行）只要求：

```sql
r.batch_id = 4
AND r.company_code = NULLIF(LTRIM(TRIM(b.company_code), '0'), '')
AND r.onoffline_code = NULLIF(LTRIM(TRIM(b.onoffline_code), '0'), '')
```

因此，用户截图所述：`company_code=1180`、`onoffline_code=020_ON_002`、事实 `src_profitcenter_code=1330101`、结果 `profitcenter_code=990990000/产品销售公共`，在当前 SQL 语义下是符合 batch 4 设计的。batch 4 不要求 `r.src_profitcenter_code = b.src_profitcenter_code`；`1330101` 是被替换的原始利润中心，而不是 batch 4 的必要匹配键。`020_ON_002` 与规则值均经过同样的去零处理后比较，形式上为 `20_ON_002`，不会因前导零导致该案例不匹配。

### 2. 为什么同一个 `src_profitcenter_code=1330101` 可能同时看到原值回退行和 batch 4 映射行

最终第一段 SELECT（约第 1788–1790 行）使用：

```sql
COALESCE(NULLIF(TRIM(pc_map.profitcenter_code), ''), a.src_profitcenter_code) AS profitcenter_code
```

所以只有在 `profitcenter_pick` 没有匹配结果时，才会显示原始利润中心；batch 4 命中时应显示 `990990000`。`profitcenter_pick`（约第 1338–1353 行）按 `fact_key` 和最小 batch 优先级选择结果，理论上同一 fact key 不应在最终 SELECT 中一行显示映射值、另一行显示原值。

但是，页面上按 `src_profitcenter_code` 聚合或抽查时，同一原始利润中心出现两种 `profitcenter_code`，不能直接证明 batch 4 错误，至少有以下两类解释：

1. **它们是不同事实行。** 当前 `fact_key` 只由以下字段组成：`system_src + ods_src + company_code + gjahr + acct_cert_id + acct_cert_item`（该表达式在 `nf_match_base`、利润中心候选各子查询、最终关联处重复出现，约第 1028–1042、1180–1205、1240–1254、1280–1297、1320–1334、1848–1860 行）。它没有包含 `object_source`、主/分户客商编码、`acct_type_code`、`acct_src_code`、`src_profitcenter_code`、`onoffline_code` 等字段。若源数据存在同一凭证行键的多条业务上下文/重复来源，行之间会共享一个 fact key；反过来，若这几个身份字段不同但仍被页面隐藏，按 `src_profitcenter_code` 看起来就像同一利润中心有两种映射。
2. **同一 fact key 被不同上下文反复计算。** `profitcenter_candidate` 的 batch 1 分支还依赖 `tov_channel_code`，batch 4 分支依赖 `nf_final` 产生的 `onoffline_code`，而这两个上下文都通过同一简化 fact key 回接。若上游事实或规则 JOIN 形成重复/冲突上下文，`profitcenter_pick` 的 `MIN(batch_id)` 只能解决候选批次优先级，不能修复 fact key 本身不能唯一代表一条事实的问题。

需要特别区分：当前 `profitcenter_pick` 已经对候选按 fact key 取最小 batch；因此若确实在同一个完整事实身份上同时存在“原值回退”和“990990000”，应优先检查最终查询是否把不同事实行的 `company_code/onoffline_code/acct_src_code/object_source/cust_head_code/cust_branch_code/凭证来源` 隐藏后做了合并，而不是先否定 batch 4。还应确认是否有同一账证行在 `src_bsid/src_bsad` 或 `src_bsik/src_bsak` 中重复出现，以及 `ods_src` 是否足以区分这些重复。

### 3. 最小修复建议

1. **先保留 batch 4 规则，不改成增加原始利润中心条件。** 对截图案例，正确的最小语义是保留 `company_code + onoffline_code` 匹配，并验证有效期、规则规范化值和 `profitcenter_code` 是否唯一；不要擅自加入 `src_profitcenter_code=1330101`，否则会改变 batch 4 的业务含义。
2. **修复事实键唯一性，而不是修复 batch 4。** 统一修改所有重复出现的 fact key 表达式，使其至少加入当前事实粒度中能区分行的字段：`object_source`、`acct_type_code`、`cust_head_code`、`cust_branch_code`、`acct_src_code`、`src_profitcenter_code`、以及规范化后的 `onoffline_code`/客户分类上下文；若源系统已有更可靠的行项目唯一键，应优先使用该键。所有 CTE 和最终 JOIN 必须使用完全相同的表达式，不能只改某一个候选分支。
3. **先用诊断 SQL 证明冲突类型。** 按现有 fact key 分组，检查 `COUNT(*)`、`COUNT(DISTINCT CONCAT(object_source,cust_head_code,cust_branch_code,acct_src_code,src_profitcenter_code))`、`COUNT(DISTINCT onoffline_code)` 和 `COUNT(DISTINCT profitcenter_code)`；同时输出 `system_src/ods_src/company_code/gjahr/acct_cert_id/acct_cert_item`。若一个 fact key 对应多个业务上下文，说明是键碰撞；若每个 fact key 唯一但按展示维度出现两种结果，则是不同事实行，batch 4 命中和原值回退可以同时合理存在。
4. **增加结果级回归检查。** 对 `company_code=1180`、`onoffline_code=020_ON_002`、`src_profitcenter_code=1330101` 的样本，逐行输出完整 fact key、凭证主键、`nf_final.onoffline_code`、所有候选 batch、`profitcenter_pick` 和最终 `profitcenter_code`。预期命中 batch 4 的事实行得到 `990990000/产品销售公共`；无 batch 4 命中的其他事实行才允许按 `COALESCE` 回退 `1330101`。

以上补充结论仍属于只读分析；本次没有修改目标 SQL，也没有修改原有业务规则。 
