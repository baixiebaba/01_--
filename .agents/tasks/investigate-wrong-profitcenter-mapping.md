# 错误利润中心映射只读排查报告

## 摘要结论

1. 当前第一段利润中心链路中，`profitcenter_pick` 已经按 `fact_key` 和最小 `batch_id` 聚合；如果输入事实键确实唯一、规则维度连接不重复，那么同一个 `fact_key` 不会同时回接一行原值和一行 `990900000`。因此截图中的两行不能仅凭 `src_profitcenter_code='1330101'` 判定为同一凭证行：它们可能是不同的 `system_src/ods_src/company_code/gjahr/acct_cert_id/acct_cert_item`，也可能是最终 SELECT 之前某个一对多 JOIN 复制了事实。必须在 Doris 按完整事实键核对。
2. batch 1 的空 `company_code`、`acct_src_code`、`onoffline_code` 不会在当前利润中心候选条件中形成无条件命中：规则公司通过 `b.cod_azienda LIKE TRIM(a.company_code)` 展开；空公司不会匹配正常公司，后续又使用 `r.company_code = b.company_code`。batch 1 还要求 `tov_channel_code LIKE 'ARTA_A_07%'`、公司相等和原利润中心相等。空键与 `=`/`LIKE` 比较为 NULL/false，故不会命中；但规则读取层没有显式排除空键，仍应增加按批次的非空约束，避免未来改写条件或空字符串数据造成宽匹配。
3. `990900000` 静态上最可能来自 batch 5：batch 5 只按公司匹配，且候选使用 `UNION ALL`；当 batch 1 因周转渠道、公司编码或原利润中心不匹配时，batch 5 会成为最小成功批次。也不能排除 batch 3/4 规则本身配置了该结果，因为当前 SQL 没有连接数据库查看规则数据。
4. `fact_key` 的组成是 `system_src + ods_src + company_code + gjahr + acct_cert_id + acct_cert_item` 的 `CONCAT_WS('|', COALESCE(...,''))` 的 MD5。它覆盖了 SAP 来源、凭证来源、公司、年度、凭证号和行项目，作为原始凭证行键原则上足够；但当前脚本没有在 `normalized_items` 层显式去重或断言唯一，且最终 SELECT 仍从 `normalized_items` 出发。因此“事实键设计足够”不等于“最终结果一定一行”。
5. 最小修复方向是：统一只在一个事实基表计算 `fact_key`；规则展开时只保留非空、有效的批次键；batch 1/3/4/5 分别严格使用指定匹配条件；候选按事实键先选最小批次，再对同批次冲突规则做显式诊断/确定性裁决，不能用 `MAX` 伪装解决冲突；最终用唯一的 `profitcenter_pick` 回接，未命中则回退 `src_profitcenter_code`。

## 证据与代码定位

### 1. 原利润中心已在 normalized_items 中去前导零

目标文件 `01_代码/01_DWD/C_应收应付/dwd_fi_mr_arap_detail_mi.sql:761-881` 定义 `normalized_items`。其中约 `:846-848`：

- `a.hkont AS acct_src_code`；
- `NULLIF(LTRIM(TRIM(a.prctr), '0'), '') AS src_profitcenter_code`。

所以后续规则比较看到的是去前导零后的值。对于示例 `1330101`，这一层不会再保留原始前导零；规则侧也在 `ar_profitcenter_rule` 中对 `src_profitcenter_code` 和 `acct_src_code` 做同样的标准化。建议继续保持“在最内层标准化一次”的方式，不在每个 JOIN 条件重复复杂的 `LTRIM/NULLIF`。

### 2. fact_key 的构成及其重复使用

`nf_match_base`（约 `:934-954`）首次计算：

```sql
MD5(CONCAT_WS('|'
  , COALESCE(a.system_src, '')
  , COALESCE(a.ods_src, '')
  , COALESCE(a.company_code, '')
  , COALESCE(a.gjahr, '')
  , COALESCE(a.acct_cert_id, '')
  , COALESCE(a.acct_cert_item, '')
)) AS fact_key
```

同样的表达式在 `profitcenter_candidate` 四个分支（约 `:1178-1332`）、`ar_mapping_base`（约 `:1370-1381`）以及最终 SELECT 的 JOIN（约 `:1820-1875`）中反复重算。字段集合本身是常见的 SAP 凭证行唯一键；但如果任一组成字段为空导致不同源行归并到同一串，或者源数据本来存在相同凭证行，则 MD5 不能修复业务重复。当前没有看到对 `normalized_items` 的唯一性校验。

### 3. 规则读取层存在公司编码展开风险

`ar_profitcenter_rule`（约 `:1151-1171`）从 `dim.dim_rule_fi_mr_ar_profit_mapping` 读取有效规则，并通过：

```sql
LEFT JOIN ods.odsfima_azienda b
  ON b.cod_azienda LIKE TRIM(a.company_code)
```

把规则公司模式展开成实际公司。随后以展开后的公司、批次、源利润中心、科目和渠道字段分组，并对结果字段使用 `MAX(a.profitcenter_code)`、`MAX(a.profitcenter_name)`。

这里有三类风险：

- `a.company_code` 为空时没有显式过滤；虽然 `LIKE NULL` 通常不会匹配，但空键不应依赖三值逻辑来保证安全。
- 一个公司模式可能展开多个公司，这是设计意图；如果 `odsfima_azienda.cod_azienda` 不是唯一，或规则模式重叠，同一业务公司可能生成多条相同批次规则。
- `MAX(profitcenter_code/name)` 会把冲突配置压成一个看似确定的值，而且代码中存在“名称与编码分别 MAX”而不保证成对一致的问题。用户此前指出不需要 MAX，这一判断正确；应先治理/去重规则，冲突则保留为诊断，不应靠 MAX 选值。

### 4. 四个利润中心候选分支的实际条件

`profitcenter_candidate` 约 `:1172-1337` 有四个 `UNION ALL` 分支：

- **batch 1（约 `:1228-1233`）**：
  `b.tov_channel_code LIKE 'ARTA_A_07%'`，`r.company_code = b.company_code`，`r.src_profitcenter_code = b.src_profitcenter_code`。
  因而 batch 1 只有在渠道前缀、公司、原利润中心同时满足时命中；它没有使用科目或 on/offline 条件。
- **batch 3（约 `:1260-1263`）**：
  公司相等，并执行 `b.acct_src_code LIKE r.acct_src_code`。这正是规则维护 `1122%` 时应使用的方向：事实科目匹配规则模式。规则模式本身必须非空，否则不应允许该分支参与。
- **batch 4（约 `:1305-1308`）**：
  公司相等且 `onoffline_code` 相等。当前 `nf` 未命中时会给事实默认值 `'020_OFF_002'`，所以 batch 4 可能按默认渠道命中；这应是业务有意行为，但规则键必须非空。
- **batch 5（约 `:1333-1336`）**：
  只使用公司相等。它是最宽的兜底规则，最容易把未命中 batch 1/3/4 的事实映射到某个配置值，例如截图中的 `990900000`；具体是否为 batch 5 必须查规则表。

当前所有候选使用 `UNION ALL`，这是正确的候选保留方式，但要求后续收敛严格可靠。

### 5. candidate/pick 是否按事实键收敛

`profitcenter_pick`（约 `:1338-1352`）先对每个 `fact_key` 求 `MIN(batch_id)`，再回接同批次候选，最后：

```sql
GROUP BY c.fact_key
```

所以从 SQL 形状看，`profitcenter_pick` 最终最多输出每个 `fact_key` 一行。问题在于同一最小批次仍可能有多条冲突规则，当前用 `MAX(c.profitcenter_code)` 和 `MAX(c.profitcenter_name)` 压缩它们；这不会产生多行，但会产生错误映射或编码/名称不配对。

最终 `ar_mapping_base`（约 `:1417-1428`）按同一六字段 MD5 回接 `profitcenter_pick`，最终 SELECT 又从 `normalized_items a` 出发，约 `:1850-1875` 再次按同一事实键回接 `profitcenter_pick`。因此单独看利润中心 pick/final JOIN，不会把一个唯一 `fact_key` 连接成两个不同利润中心。

最终输出约 `:1789` 使用：

```sql
COALESCE(NULLIF(TRIM(pc_map.profitcenter_code), ''), a.src_profitcenter_code)
```

未命中或规则结果为空时确实回退原始利润中心，满足兜底要求。

### 6. 为什么截图会出现原值和 990900000 两行

静态 SQL 能确认的因果链是：

- 一条事实若没有任何候选，`pc_map` 为空，最终显示 `1330101`；
- 另一条事实若命中 batch 5（或配置了 `990900000` 的 batch 3/4），则显示 `990900000`；
- 仅按 `dt_month`、`src_profitcenter_code` 查询时，这两个事实可能看起来完全一样，但其完整事实键不同。

若截图中两行的完整事实键完全相同，则应重点查最终 FROM 链上的一对多关系。优先检查：

1. `normalized_items` 是否对同一六字段产生多行；
2. `customer_supplier_dim` 的映射是否一对多，最终对 `c/bc/ch/ci` 的 LEFT JOIN 是否复制事实；
3. `ar_business_mapping` 是否保证每个事实键一行；
4. `aging_seg_cfg` 的区间是否重叠；
5. `odsfima_azienda` 是否在规则展开时重复，及规则表是否存在同批次冲突配置。

不过，若只是最终 `profitcenter_pick` 多行，当前 `GROUP BY c.fact_key` 理论上已把它收敛，不足以解释同一事实键同时出现两个利润中心；需要以完整事实键和各中间 CTE 的行数验证。

## 建议的 Doris 核对查询（本次未执行）

以下查询应在与脚本相同的 Doris session、`dt_month='202608'` 运行；由于 CTE 只在脚本语句内存在，建议复制第一段 `WITH` 至目标 CTE 后，在末尾替换 SELECT。这里只给核对目标，不在本次调查中执行数据库查询：

```sql
-- 1. 先确认目标结果的完整事实键和来源字段，而不是只看 src_profitcenter_code。
SELECT system_src, ods_src, company_code, gjahr, acct_cert_id, acct_cert_item
     , src_profitcenter_code, profitcenter_code, COUNT(*) AS row_cnt
  FROM <第一段最终查询结果>
 WHERE dt_month = '202608'
   AND src_profitcenter_code = '1330101'
 GROUP BY system_src, ods_src, company_code, gjahr, acct_cert_id
        , acct_cert_item, src_profitcenter_code, profitcenter_code;

-- 2. 查事实键是否重复，以及不同利润中心是否对应同一事实键。
SELECT fact_key, COUNT(*) AS candidate_cnt
     , COUNT(DISTINCT profitcenter_code) AS mapped_code_cnt
  FROM profitcenter_candidate
 GROUP BY fact_key
HAVING COUNT(*) > 1 OR COUNT(DISTINCT profitcenter_code) > 1;

-- 3. 看每个事实键命中了哪些批次和规则结果。
SELECT fact_key, batch_id, profitcenter_code, profitcenter_name
  FROM profitcenter_candidate
 WHERE fact_key IN (<问题事实键>);

-- 4. 查规则键是否为空或同一有效键有冲突结果。
SELECT batch_id, company_code, src_profitcenter_code, acct_src_code
     , onoffline_code, COUNT(*) AS rule_cnt
     , COUNT(DISTINCT profitcenter_code) AS result_cnt
  FROM ar_profitcenter_rule
 GROUP BY batch_id, company_code, src_profitcenter_code, acct_src_code, onoffline_code
HAVING company_code IS NULL
    OR src_profitcenter_code IS NULL
    OR (batch_id IN (3, 4) AND (acct_src_code IS NULL OR onoffline_code IS NULL))
    OR result_cnt > 1;
```

`<第一段最终查询结果>` 和 `<问题事实键>` 只是占位说明，执行时应替换为实际可引用的 CTE/值；不能把这些文本直接当作可执行 SQL。

## 最小修改建议（只建议，不实施）

### A. 统一事实基表和 fact_key

在 `normalized_items` 之后新增一个事实基表，例如 `profitcenter_match_base`，一次投影：`fact_key`、公司、原利润中心、科目、周转渠道、on/offline。四个候选分支都从该基表读取，不再各自重复 MD5 和重复 LEFT JOIN。最终 `profitcenter_pick`、`ar_mapping_base`、最终 SELECT 都只回接这一键。

建议在上线前增加核对：事实基表按 `fact_key` 分组的 `COUNT(*)` 必须为 1；若不为 1，应先修复源/维度一对多，而不是用 `DISTINCT` 静默吞掉业务行。

### B. 规则展开时显式隔离空键

保留公司模式展开，但在 `ar_profitcenter_rule` 中使用清晰的标准化字段，并按批次过滤：

- 所有批次：`company_code IS NOT NULL`、`src_profitcenter_code IS NOT NULL`、`profitcenter_code` 非空；
- batch 1：`tov_channel_code` 不在规则表，但候选必须继续要求 `LIKE 'ARTA_A_07%'`；
- batch 3：`acct_src_code IS NOT NULL`，使用 `fact.acct_src_code LIKE rule.acct_src_code`；
- batch 4：`acct_src_code IS NOT NULL`、`onoffline_code IS NOT NULL`，使用公司+on/offline 精确匹配；
- batch 5：至少要求公司和源利润中心非空，使用公司精确匹配。

不要把空规则键转换成 `%`，也不要用 `COALESCE(rule_key, fact_key)` 之类条件制造无条件命中。公司模式展开应先对 `odsfima_azienda.cod_azienda` 去重；如果模式不是业务允许的 LIKE 模式，应改成明确的模式字段处理，避免 `LIKE` 的通配符语义被误用。

### C. 按业务优先级选唯一候选，去掉 MAX 伪裁决

保留 `MIN(batch_id)` 的 1→3→4→5 优先级，但不要在同一事实键/批次内用 `MAX` 选择编码和名称。推荐：

1. 先将规则结果按完整规则键 `SELECT DISTINCT`；
2. 对同一 `fact_key` 求最小 batch；
3. 对最小 batch 的候选检查 `COUNT(DISTINCT profitcenter_code)`：为 0 走兜底、为 1 保留唯一编码及其配对名称、超过 1 输出异常核对集并阻止静默上线；
4. 若当前必须保证 SQL 继续产出一行，使用 `ROW_NUMBER()` 按明确、稳定且业务认可的规则优先字段排序，只取 `rn=1`，并同时落异常统计；不要分别对 code/name 做 MAX。

### D. 确保 batch 1/3/4/5 条件严格对应需求

建议将四个 `UNION ALL` 分支保留为分支形式，避免一个 OR JOIN 难以验证优先级：

- batch 1：`fact.tov_channel_code LIKE 'ARTA_A_07%' AND rule.company_code = fact.company_code AND rule.src_profitcenter_code = fact.src_profitcenter_code`；
- batch 3：`rule.company_code = fact.company_code AND fact.acct_src_code LIKE rule.acct_src_code`；
- batch 4：`rule.company_code = fact.company_code AND rule.onoffline_code = fact.onoffline_code`；
- batch 5：`rule.company_code = fact.company_code`。

四个分支均应依赖已标准化的非空事实键字段；特别是 batch 5 只能作为前面规则未命中时的公司级兜底，不能因为空规则键或空公司被扩大成全量命中。

### E. 保留最终原值兜底并验证一行性

保留当前最终输出的：

```sql
COALESCE(NULLIF(TRIM(pc_map.profitcenter_code), ''), a.src_profitcenter_code)
```

同时上线前必须验证：最终结果按 `system_src, ods_src, company_code, gjahr, acct_cert_id, acct_cert_item` 分组后 `COUNT(*)=1`。若失败，应定位实际一对多 JOIN（尤其客商维度、业务映射、账龄区间），不能靠 `MAX` 或最终 `DISTINCT` 隐藏问题。

## 本次调查范围和限制

- 已阅读目标文件第一段的 `normalized_items`、`nf_match_base`、`ar_profitcenter_rule`、`profitcenter_candidate`、`profitcenter_pick`、`ar_mapping_base` 和最终回接；也检查了第二段存在独立的利润中心规则链，但本报告聚焦用户指定的第一段。
- 未修改 SQL、未提交代码、未重启任何服务。
- 未执行 Doris 或其他数据库查询；因此无法在本次只读静态检查中确认 `990900000` 的实际规则批次、`company_code` 的实际值、`tov_channel_code` 的实际值，或截图两行是否拥有相同完整 `fact_key`。
- 仓库根目录未发现 README、AGENTS.md、CONTRIBUTING.md 或 `.kiro/steering/*` 文件；本报告遵循已提供的 DWD SQL 风格要求，并保留现有工作区改动不作处理。
