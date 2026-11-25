# 双版本维护约定（应收应付 DWD）

## 〇、当前生效版本（2026-10-30 起）

| 项 | 说明 |
|---|---|
| **当前生效 = 不使用客户大表版** | 客户大表 `dim_fi_mr_customer_map_dd` / `dim_fi_mr_customer_dd` 仍在改造，存在数据问题，暂不启用 |
| 主文件名放的就是生效版 | `dwd_fi_mr_arap_detail_mi.sql`、`dwd_fi_mr_arap_sum_mi.sql` = **不使用客户大表** |
| 使用客户大表版转为备用文件 | `detail使用客户大表.sql`、`sum使用客户大表.sql` |
| 线上部署 | hidata 36135 / 36138 部署的就是当前主文件，2026-10-30 核对**正文逐字一致** |
| 切换条件 | 客户大表改造完成 + 数据验证通过 + 业务确认后，才切回「使用客户大表」版 |

> **切换方法**：把 `detail使用客户大表.sql` 的内容覆盖到 `dwd_fi_mr_arap_detail_mi.sql`，
> 同步改版本说明，再走 hidata 的 review → save → submit。
> **不要直接按文件名推线上**——那等于换实现，hidata skill 的「版本错位」拦截会挡住。

## 一、四个文件，两对并行版本

| 当前生效（不使用客户大表） | 备用（使用客户大表） | 目标表 |
|---|---|---|
| `dwd_fi_mr_arap_detail_mi.sql` | `detail使用客户大表.sql` | `test.dwd_fi_mr_arap_detail_mi` |
| `dwd_fi_mr_arap_sum_mi.sql` | `sum使用客户大表.sql` | `test.dwd_fi_mr_arap_sum_mi` |

两对文件**业务逻辑必须完全一致**，唯一允许的差异就是「客商维度是否依赖客户大表」。

> 历史遗留：`detail不使用客户大表_20260921旧版备份.sql` 是 2026-09-21 的旧备份，不参与维护、不做校验。

## 二、唯一允许的差异

| 项 | 生效版（不使用大表） | 备用版（使用大表） |
|---|---|---|
| SAP 客商 → MDG 映射 | **SAP `KNA1` / `LFA1`（六套 UNION），取 `zkunnr_mdg` / `zlifnr_mdg`** | `dim.dim_fi_mr_customer_map_dd` |
| 客商名称 / 分类 / 国家 | **名称取 KNA1/LFA1.name1；分类国家取 `dw.dim_customer_base_info_dd`** | `dim.dim_fi_mr_customer_dd` |
| 对方公司 | **`dim.dim_rule_fi_mr_cust2ctp_mapping`** | `dim.dim_fi_mr_customer_dd` |

**其余一律不许有差异**：包括所有规则表、科目映射、账龄段、利润中心、渠道、业务范围、INSERT 列清单、文件头格式。

## 三、同步规则（强制）

1. **任何业务逻辑改动，四个文件里对应的那一对必须同时改**（detail 一对、sum 一对，各与自己的目标表绑）。
2. 改完必须做一致性校验（见第四节），**校验不过不许提交**。
3. `ALTER BY YYYYMMDD HH:MI SHIQINGFENG.EX` 的**时间戳在成对的两个文件里必须完全相同**，
   这样一眼能看出是不是漏改了一个。
   > **唯一例外**：记录「本文件为并行版本」的那一条分叉标记（detail `20261029 18:45`、sum `20261029 18:40`）
   > 只存在于生效版，属于版本身份说明，不计入「漏改」判定。
4. 新增字段/DDL 只改一次（表是同一张），但**两个文件的 INSERT 列清单都要加**。
5. 头部「版本说明」块两版不同（生效版写「当前生效」、备用版写「备用」），**这是允许的差异，不算业务差异**。

## 四、一致性校验（每次改完跑）

```bash
cd "01_代码/01_DWD/C_应收应付"

# detail 对：除了客商维度那几段，其余应该零差异
diff <(sed -n '/^INSERT INTO/,/^$/p' dwd_fi_mr_arap_detail_mi.sql) \
     <(sed -n '/^INSERT INTO/,/^$/p' detail使用客户大表.sql) | head -50

# 快速判据：两个文件的 ALTER BY 时间戳集合必须一致
python3 - <<'PY'
import io, re
for a, b in [("dwd_fi_mr_arap_detail_mi.sql", "detail使用客户大表.sql"),
             ("dwd_fi_mr_arap_sum_mi.sql",    "sum使用客户大表.sql")]:
    sa = set(re.findall(r"ALTER BY (\d{8} \d{2}:\d{2})", io.open(a, encoding="utf-8").read()))
    sb = set(re.findall(r"ALTER BY (\d{8} \d{2}:\d{2})", io.open(b, encoding="utf-8").read()))
    print(a, "vs", b, "| 只在主版本:", sorted(sa - sb - {""}), "| 只在备用版本:",
          sorted(sb - sa - {""}), "| 判定:", "✅" if sa == sb else "❌")
PY
```

## 五、客商维度在生效版里的实现（供对照）

### detail（`dwd_fi_mr_arap_detail_mi.sql`）

| CTE | 作用 |
|---|---|
| `src_kna1` / `src_lfa1` | 六套 SAP 主数据 UNION，带 MDG 编码 |
| `cust_sap_map_dim` | 客户(C) + 供应商(S)，按 系统+编码 聚合，MDG 空则回退 SAP 编码 |
| `cust_class_dim` | `dw.dim_customer_base_info_dd` 三级分类 + 国家 |
| `cust_ctp_rule` | `dim_rule_fi_mr_cust2ctp_mapping` 对方公司，**类型 V → S** |
| `customer_supplier_dim` | 拼装，输出 15 列，列名与备用版完全一致 → 下游 7 处 JOIN 不用改 |

### sum（`dwd_fi_mr_arap_sum_mi.sql`）

| CTE | 作用 |
|---|---|
| `policy_customer_kna1` | S600 KNA1，客户名称 + MDG 编码 |
| `policy_customer_class_dim` | `dw.dim_customer_base_info_dd` 三级分类 + 国家 |
| `policy_customer_ctp` | `dim_rule_fi_mr_cust2ctp_mapping` 对方公司（仅 C 类型） |
| `policy_customer_dim` | 拼装，输出 13 列，列名与备用版完全一致 |

## 六、两个必须记住的坑

| # | 坑 | 说明 |
|---|---|---|
| 1 | **供应商类型编码不同** | 大表 `cust_supp_type` 用 `C/S`；规则表 `dim_rule_fi_mr_cust2ctp_mapping.cust_type_code` 用 `C/V`。生效版里必须把 **V 转成 S**，否则供应商对方公司整类静默丢失 |
| 2 | **全零不等于 NULL** | `zkunnr_mdg` / `zlifnr_mdg` 用 `'0000000000'` 表示空，必须 `NULLIF(LTRIM(TRIM(x),'0'),'')` 归一化 |

## 七、实测依据（20261029，当时「生效版」记为并行版本）

| 指标 | 使用客户大表 | 不使用客户大表（现生效） |
|---|---|---|
| detail 维度行数 | 5,278,741 | 5,412,284 |
| detail 对方公司填充 | 2,433 | **5,790** |
| detail S600 BSID 客商覆盖 | 12,634 / 17,128（73.8%） | **17,128 / 17,128（100%）** |
| sum POLICY 客商维度行数 | 515,751（**含 2 个重复键**） | **550,491（无重复）** |
| sum 名称填充 | 475,145（92.1%） | **550,491（100%）** |
| sum 国家填充 | 475,145 | **486,281** |
| sum 对方公司填充 | 979 | **1,446** |

> 不使用客户大表版在所有指标上都不低于使用大表版，且修正了 `policy_customer_dim` 的 1 个重复键问题。
> 但客户大表改造完成后仍需重新比对一次，再决定是否切回。
