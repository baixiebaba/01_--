# ARPM02/IMOCC 周转校验查询的全量留痕与后置事业部筛选

本轮修改将两份 ARPM02/IMOCC 校验 SQL 调整为“来源全量留痕、映射后计算、最终事业部展示筛选”的结构。ARPM02 继续按 ME/MB 账龄条件取数，并以 `ARPTOV_FLAG` 标记 ARPTOV_RULE 配置剔除；IMOCC 保留原有来源筛选并使用 `N` 标记。两份 SQL 都删除了 DWMCRS 进数/锁定依赖，在全量有效事业部上完成映射、负净额聚合和 `AR_AMT_FLAG` 回标，再处理参数版的事业部展示范围。Watch for: **confirmed** — 本轮静态审查未识别出阻塞性 SQL 完整性问题；Oracle 执行、真实数据和 ARPM03 全链路结果仍属于本轮范围之外。

**Verdict**: APPROVED

## High-level view

来源层仍只有 ARPM02 与 IMOCC 两个 `UNION ALL` 分支。ARPM02 的 ME/MB 条件、ARPTOV_RULE 有效期和批次 1/2/3/4/6 标记逻辑均在来源层保留，配置剔除记录不再被物理过滤；IMOCC 的公司、对方公司、利润中心和非零金额条件也保持在来源层。

事业部处理先建立当前期间有效的完整周转事业部范围，再分别聚合账套和利润中心映射，避免多行映射直接连接放大金额。`MAPPED_TURNOVER` 留存映射冲突、未映射和公司/利润中心不一致状态；`BG_TURNOVER_NET` 与 `NEGATIVE_BG_TURNOVER` 在参数版事业部条件生效前计算，`FILTERED_TURNOVER` 通过规范化且非空的主户键回标 `AR_AMT_FLAG`。

最终展示层保留映射失败或参数排除后置空的 `BUSINESS_UNIT_CODE` 记录，并在参数版只将事业部参数用于 `DISPLAY_TURNOVER`/`FINAL_TURNOVER`。固定版以 `ALL` 走等价分支；两份文件的 CTE、来源列顺序、输出列顺序、标记字段和聚合粒度一致，仅场景/期间/公司/事业部的参数表达式与固定常量不同。

<details>
<summary>Issues (0)</summary>

无需要在本轮 SQL 完整性门禁前修复的阻塞性问题。

</details>

<details>
<summary>Details</summary>

## 来源全量留痕与 ARPTOV 标记

`TURNOVER_SOURCE` 保留两个来源分支，两个分支均为 13 列且列位置一致。ARPM02 使用单个来源分支，以 `CASE` 在 ME 命中时生成 `ZAMOUNT`、否则在 MB 命中时生成 `ZAMOUNT_L2`，WHERE 条件仍为 `ME_AGE_FLAG IN ('AR','CA','A10') OR MB_AGE_FLAG IN ('AR','CA','A10')`。这满足本轮要求的双字段筛选，同时避免同一来源行因两个标识同时命中而重复进入来源层。

`ARPTOV_RULE` 仍按当前期间有效期读取批次 1、2、3、4、6；ARPM02 的 `ARPTOV_FLAG` 通过批次 6 公司/二级性质规则以及批次 1 至 4 的 EXISTS 判定配置剔除为 `Y`，其他行标记为 `N`。这些判断只生成标记，没有把配置命中的 ARPM02 行从来源中删除。IMOCC 的 `ARPTOV_FLAG` 固定为 `N`，其原有当前月、1740/2080 公司、空对方公司、有效利润中心、非零金额和 `AZI_SCOPE` 公司范围条件仍在。

## 全量事业部映射与负净额回标

`TOV_BG_SCOPE_ALL` 只按当前期间、`AR_TOV_FLAG = 'Y'`、有效 COS 范围和 CXC 排除构造周转事业部集合；`ATS_BG_MAP` 与 `PCR_BG_MAP` 没有读取事业部参数。`AZI_SCOPE` 只保留 HIE=10 和实际公司参数，因此公司范围与事业部范围已分离。

`ATS_BG_STATUS`、`PCR_BG_STATUS` 先按账套或标准化利润中心聚合并统计不同事业部数量，`MAPPED_TURNOVER` 只有双方各唯一且相等时才写入 `BUSINESS_UNIT_CODE`，否则写空并保留映射状态。这样映射冲突、未映射和不一致行仍能进入最终校验结果，同时不会因明细配置多行连接重复计算周转金额。

`BG_TURNOVER_NET` 仅对 `ARPTOV_FLAG = 'N'`、集团外、映射成功且主户键非空的记录按场景、期间、公司、规范化主户、类别和事业部聚合；`NEGATIVE_BG_TURNOVER` 只在存在其他事业部且净额小于零时识别负净额事业部。`FILTERED_TURNOVER` 不删除这些行，而是通过同一 `CUST_MATCH_CODE` 和事业部键将 `AR_AMT_FLAG` 回标为 `Y`，因此负净额剔除数据仍可查询。

## 最终事业部范围与保留记录

`DISPLAY_TURNOVER` 位于负净额回标之后。参数版只有在该层才判断 `ALL` 或 `${$ANL_D_BG.code}`，参数外的实际事业部被置为 NULL，并将映射状态改为“被事业部参数排除”；本来就没有有效事业部的映射失败/不一致行也保持 NULL。`FINAL_TURNOVER` 保留 NULL 事业部、`ALL` 或命中参数的记录，最终 SELECT 不再按金额非零、`ARPTOV_FLAG` 或 `AR_AMT_FLAG` 删除行。

该顺序满足“先按全量事业部计算负净额，再按参数展示”的约束。规范化主户键在 `MAPPED_TURNOVER` 中生成并在净额聚合和回标关联中复用，当前目标 SQL 没有把可能为空的原始表达式重新用于 `=` 关联；负净额集合本身只来自成功映射且非空主户的行。

## 双文件结构与静态证据

对两份当前文件去除注释、字符串字面量、参数表达式和固定数字后的定向结构比较结果相同；两份文件均包含 17 个 CTE、1 个来源 `UNION ALL`、括号平衡、`CASE`/`END` 数量一致，来源分支为 13 列。静态检查记录进一步确认字段别名、CTE 引用、聚合字段与 GROUP BY、来源标记位置和最终筛选位置均通过检查。

目标文件中未发现 `AW_RUL_DWMCRS_000001`、`ZAW_D2M_IN` 或 `ZAW_D2M_LOCK`；前置映射中没有事业部参数谓词，命中的 `COD_BG IN (SELECT COD_BG FROM TOV_BG_SCOPE_ALL)` 是当前期间有效 COS 范围，不是参数事业部过滤。`git diff --check` 通过。实施记录说明参考过程的工作区修改在本轮开始前已存在；本次审查未修改该参考文件，也未修改目标 SQL。

本审查只使用 SQL 文本、当前目标文件 diff、实施计划和静态检查记录，没有执行 Oracle SQL、样例数据校验、执行计划分析或 ARPM03 全链路验证；这些限制不构成本轮 SQL 完整性门禁的阻塞项。

</details>

<details>
<summary>File map</summary>

- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询.sql` — 参数版 ARPM02/IMOCC 全量留痕、全量事业部负净额计算和最终事业部筛选。
- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询_2026ACT08_2600_ALL.sql` — 2026ACT/08/2600/ALL 固定参数版的同构实现。
- 完整变更依据：两份目标文件相对当前 Git 基线的 `git diff`；参考 `CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` 仅作读取对照。

</details>
