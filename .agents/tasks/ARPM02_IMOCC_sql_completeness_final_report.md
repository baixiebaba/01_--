# ARPM02/IMOCC 周转校验 SQL 最终汇报

## 门禁结论

前置 SQL 审查门禁已通过：`ARPM02_IMOCC_sql_completeness_review.md` 的 Verdict 为 `APPROVED`，`ARPM02_IMOCC_sql_completeness_review.json` 为 `{"verdict":"APPROVED","findings":[]}`，未发现阻塞性 SQL 完整性问题。

本次仅依据已通过的静态审查结果完成汇报和复核；未修改 TOV、规则文件，未创建测试文件，未提交 Git commit。

## 修改的两个文件

1. `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询.sql`
2. `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询_2026ACT08_2600_ALL.sql`

参数版与固定版分别保留参数占位符和 `2026ACT/08/2600/ALL` 固定值；两者 CTE 结构、来源列顺序、输出列顺序、标记字段和聚合粒度一致。

## 关键结构变化

- **事业部过滤后置**：ATS/PCR 映射先基于当前期间全部有效 COS 事业部范围计算，不使用事业部参数前置过滤。先完成 `MAPPED_TURNOVER`、`BG_TURNOVER_NET`、`NEGATIVE_BG_TURNOVER` 和 `AR_AMT_FLAG` 回标，再在 `DISPLAY_TURNOVER`/`FINAL_TURNOVER` 处理事业部参数。参数外的实际事业部被置空并保留，映射失败、不一致、冲突和未映射记录也以空事业部留痕。
- **全量 `AR_AMT_FLAG` 计算**：负净额事业部按场景、期间、公司、规范化主户、类别和实际事业部聚合，在完整事业部集合上识别“净额小于零且存在其他事业部”的记录并标记 `AR_AMT_FLAG = 'Y'`。该计算不受参数事业部范围影响；最终展示筛选仅发生在标记之后。
- **移除 `AW_RUL_DWMCRS_000001`**：两份目标 SQL 不再依赖该进数/锁定表，也未发现 `ZAW_D2M_IN` 或 `ZAW_D2M_LOCK`。公司范围仍通过 `V_REF_AZIENDA` 的 `HIE = '10'` 和实际公司参数控制。
- **来源全量留痕**：保留 ARPM02 与 IMOCC 两个 `UNION ALL` 来源分支。ARPM02 继续保留 `ME_AGE_FLAG IN ('AR', 'CA', 'A10') OR MB_AGE_FLAG IN ('AR', 'CA', 'A10')`，并通过 `ARPTOV_RULE` 将配置剔除记录标记为 `ARPTOV_FLAG = 'Y'`，不再物理删除；IMOCC 继续使用原有公司、对方公司、利润中心和非零金额条件，并固定标记为 `N`。
- **映射与金额防重复**：账套和利润中心事业部映射先聚合统计，只有双方各唯一且一致时写入实际事业部，避免多行映射连接放大金额；规范化且非空的 `CUST_MATCH_CODE` 贯穿净额聚合和负净额回标。
- **参数版与固定版一致性**：两份 SQL 均使用同构的 17 个 CTE、两个来源分支、13 列来源结构和相同最终输出字段；差异仅为场景、期间、公司和事业部参数表达式与固定值。固定版使用 `ALL` 等价保留全部事业部。

## SQL 完整性静态检查结果

静态检查全部通过：

1. 两份 SQL 均保留 `WITH` 和连续 CTE 结构，括号平衡，`CASE`/`END` 配对。
2. `TURNOVER_SOURCE` 保留 ARPM02、IMOCC 两个 `UNION ALL` 分支，分支列数均为 13，列顺序和类型位置一致。
3. ARPM02 的 ME/MB 账龄条件、ARPTOV_RULE 有效期和批次 1/2/3/4/6 判定逻辑均存在；规则命中的记录通过 `ARPTOV_FLAG` 留痕，没有被来源层物理删除。
4. 两份 SQL 均不存在 `AW_RUL_DWMCRS_000001`、`ZAW_D2M_IN` 或 `ZAW_D2M_LOCK`。
5. ATS/PCR 映射未发现事业部参数或固定事业部列表的前置过滤；前置 `COD_BG IN (SELECT COD_BG FROM TOV_BG_SCOPE_ALL)` 仅用于当前期间有效 COS 范围。
6. `BG_TURNOVER_NET`/`NEGATIVE_BG_TURNOVER` 位于最终事业部参数处理之前，`AR_AMT_FLAG` 在全量事业部负净额计算完成后回标。
7. `CUST_MATCH_CODE` 在净额聚合和回标中复用，并显式排除空主户，未发现旧的可空键等值关联。
8. 最终事业部处理仅保留空事业部或命中参数的展示记录，不再按金额非零、`ARPTOV_FLAG` 或 `AR_AMT_FLAG` 误删来源行。
9. `git diff --check` 对两份目标 SQL 复核通过。
10. 当前工作区状态显示两份目标 SQL 和参考 TOV 均有修改；依据前置材料，参考 TOV 的修改属于实施前已有状态，本次未修改参考 TOV。

## 未执行项与后续待办

本轮**未执行 Oracle 数据库验证**，也未执行真实样例数据核对、执行计划/性能验证、数据库字段类型兼容性验证或完整 ARPM03 全链路业务验证。因此，当前结论仅代表 SQL 文本和静态结构完整性通过，不代表数据库运行结果或业务金额口径已经验证。

后续待办：在目标 Oracle 环境执行参数版和固定版，抽样核对 ARPM02/IMOCC 全量来源、ARPTOV 配置标记、事业部映射冲突与未映射留痕、全量事业部负净额及 `AR_AMT_FLAG`、参数外事业部置空逻辑，并与 ARPM03 有效周转结果进行完整业务校验。
