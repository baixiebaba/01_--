# ARPM02/IMOCC 周转校验 SQL 完整性验证

## 验证范围

本轮仅对以下两份 SQL 做静态完整性检查，未执行 Oracle 数据库查询、样例数据核对或 ARPM03 全链路业务校验：

- `01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询.sql`
- `01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询_2026ACT08_2600_ALL.sql`

参考文件 `01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` 仅作读取核对，本轮未修改。审查记录路径 `ARPM02_IMOCC_sql_completeness_review.json` 在实施前不存在，因此按首次实现处理。

## 静态检查方法与结果

使用一次性 `python3` 内联检查程序读取两份 SQL，去除注释和字符串后检查括号、CASE/END、CTE 和 UNION 结构；同时使用 Git 检查空白错误和目标差异。

检查项全部通过：

1. 两份 SQL 均保留 `WITH` 和连续 CTE 结构，括号数量平衡，`CASE` 与 `END` 数量一致。
2. `TURNOVER_SOURCE` 保留 ARPM02、IMOCC 两个 `UNION ALL` 来源分支；两分支均为 13 列，列顺序和类型位置保持一致。
3. ARPM02 的 `ME_AGE_FLAG`、`MB_AGE_FLAG` 条件仍为 `AR`、`CA`、`A10` 范围；ARPTOV 批次 1 至 4、6 的标记逻辑仍存在，配置剔除行未物理删除而通过 `ARPTOV_FLAG` 留痕。
4. 未发现 `AW_RUL_DWMCRS_000001`、`ZAW_D2M_IN` 或 `ZAW_D2M_LOCK`；公司范围只保留 HIE=10 层级和实际公司参数条件。
5. ATS/PCR 映射只按有效期和 `TOV_BG_SCOPE_ALL` 的有效 COS 范围构造，没有事业部参数或固定事业部范围前置过滤。
6. `MAPPED_TURNOVER` 先完成全量公司事业部/利润中心事业部映射及冲突、未映射、不一致留痕；`BG_TURNOVER_NET`、`NEGATIVE_BG_TURNOVER` 在最终事业部处理前按场景、期间、公司、规范化主户、类别、事业部计算负净额。
7. 主户使用 `CUST_MATCH_CODE` 贯穿聚合和负净额关联，并在净额层及回标层显式排除空主户，未发现旧的 `CUST_MATCH_CODE = CASE ...` 可空键比较。
8. `AR_AMT_FLAG` 在全量事业部负净额计算完成后回标；参数版在 `DISPLAY_TURNOVER`/`FINAL_TURNOVER` 最后层将参数外实际事业部置空并保留，最终只按“展示事业部为空或命中参数”条件输出。固定版使用 `ALL` 等价逻辑。
9. 参数版与固定版的 CTE 名称、来源 `UNION ALL` 数量和字段结构一致，仅使用场景、期间、公司及事业部参数/常量不同。
10. `git diff --check -- <两份目标 SQL>` 通过。

验证时目标 SQL 的 Git 差异仅涉及上述两份目标文件；参考 TOV 在实施前已处于工作区修改状态，本轮未新增对其内容的修改。

## 未执行项目与后续待办

- 当前未使用 Oracle 客户端执行 SQL，因此未确认 Oracle 实际语法解析、执行计划、数据库字段类型兼容性或运行性能。
- 当前未使用真实数据验证 ARPM02/IMOCC 金额、事业部映射冲突、负净额剔除、`AR_AMT_FLAG` 和 ARPM03 入数结果。
- 后续整体校验时需在目标数据库中执行参数版和固定版，抽样核对全量事业部负净额计算、参数外事业部置空留痕、ARPTOV 配置标记及与 ARPM03 的有效周转结果。
