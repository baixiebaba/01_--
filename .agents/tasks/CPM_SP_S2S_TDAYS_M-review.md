# Configuration-driven turnover days loader remains blocked by runtime and deployment gaps

当前实现已经建立了 Oracle `DBMS_SQL` 动态取数路径：10 组筛选条件由固定过程解析，来源结果先写入 `SESSION_TOVCAL_RESULT`，再按 scope 删除并装载 `AW_MR7_ARPA01_000001`，18 个金额和 6 个周转天数字段也已列全。实现同时对标识符调用了 `DBMS_ASSERT`，绑定了配置值、HIE/NODE 和筛选 token，并保留了 `SOURCE_TABLE=TARGET_TABLE` 的暂存隔离思路。可是，动态对象信任边界、配置/目标 DDL 契约、运行公司范围、公式待确认项和事务日志顺序仍未闭合；本地没有 Oracle 客户端，因此不能把文本静态断言当成可编译或可部署证据。

Watch for: **confirmed** SOURCE_TABLE 可选任意当前 owner 下的同字段对象而非固定 source 白名单；**confirmed** 实现把 YTD 的“本月占用”直接替换为 `*_END_OCP_AMT`、把零分母固定为 `NULL`，但计划仍将两项列为业务待确认；**confirmed** `END 执行完成` 日志在主事务 `COMMIT` 之前写入，可能留下“已完成”但实际回滚的日志；**confirmed** 运行公司只复制 `V_REF_AZIENDA` 的 HIE=10 范围，未实现参考周转程序使用的有效 ATSMAP/COSMAP/DWMCRS 交集。

**Verdict**: NEEDS_CHANGES

## High-level view

**confirmed** 对象校验只证明了名称语法、字典存在性和局部 owner 边界；它没有逐 source 白名单、准确 HIE 映射矩阵或完整直接授权契约，因此不能把任意配置对象安全地当作业务来源。

**confirmed** 过程的配置预检没有闭合完整部署契约，并以 ROWID 哈希充当规则标识；无 Oracle 编译证据时，未限定 owner 的配置表、GTT、日志表和字段类型仍可能在部署时失败。

**confirmed** 公司范围实现与现有参考过程的有效规则链路不一致，且 SESSION 级互斥只保护本过程名下的调用，不能证明共享 `SESSION_AZIENDA_LIST`/`SESSION_V_REF_AZIENDA` 不会被其他过程覆盖。

**confirmed** 目标清理存在旧值 `ALL` 不归一化、提交前 END 日志和公式待确认项；验证覆盖也不足以作为发布依据。

<details>
<summary>Issues (9)</summary>

1. **动态来源与 HIE 白名单缺失（confirmed）** — SOURCE_TABLE 只限制为当前 owner 下存在的对象，HIE 只限制名称正则，未逐对象固定 source/HIE 白名单和直接授权；补齐部署矩阵与严格拒绝逻辑，所有配置对象在读数前必须命中批准契约。
2. **部署 DDL 契约未闭合（confirmed）** — 配置表 owner/对象类型/完整维度列、GTT/日志表 owner 与权限、目标维度和天数字段类型均未被完整校验，静态表名也未统一限定 owner；补齐 DDL/直接 grant 门禁并在 DELETE 前失败。
3. **规则标识使用 ROWID 哈希（confirmed）** — `ROWIDTOCHAR(ROWID)` 生成的哈希不是稳定 RULE_ID，迁移、重装或哈希碰撞会改变日志定位并削弱重复规则诊断；使用配置表稳定主键并在同一 SQL 内采用固定安全 bind 名。
4. **运行公司范围未对齐参考有效规则（confirmed）** — 实现仅按 `V_REF_AZIENDA` 的 HIE=10 选公司，省略参考程序的 ATSMAP、COSMAP、DWMCRS 有效期、周转标记和锁定规则；冻结新引擎授权口径，或实现批准的有效交集，并让 source、scope 和 DELETE 共用它。
5. **共享 SESSION 范围表隔离不足（confirmed）** — 过程仅用本过程的 DBMS_LOCK 清理共享表按 SESSION_ID 的全部行，不能阻止其他过程或调用方状态被覆盖，异常路径也会无条件删除这些行；增加 RUN_ID/跨过程互斥，或只清理本次持有的范围并证明不会串用。
6. **周转公式待确认口径被硬编码（confirmed）** — `*_MTD_TDAYS` 与 `*_YTD_TDAYS` 均用 `*_END_OCP_AMT` 代替用户公式中的本月占用，六个零分母分支均返回 NULL，而设计仍要求业务确认；在确认前显式阻断发布，确认后固化唯一字段映射和 0/NULL 规则。
7. **END 日志早于业务提交且失败不可观测（confirmed）** — 正常路径先写自治 `END 执行完成` 再 COMMIT，提交失败会留下错误成功日志；将 END 日志放到提交后并提供可观察的日志失败告警/返回机制，不能只依赖 DBMS_OUTPUT。
8. **ZZZZ 删除归一化不对称（confirmed）** — DELETE 只把目标 NULL/空格映射到 ZZZZ，没有将旧目标维度值 `ALL` 归一化为 ZZZZ，可能留下旧行并与新结果重复；统一目标旧值、scope 和 INSERT 的规范化表达式，或明确拒绝并清理历史 ALL 数据。
9. **静态验证不能证明可执行性（confirmed）** — 已记录的脚本只做文本计数和关键字符串存在性检查，未证明 Oracle 编译、动态 bind 计数、真实 1000/1001 分块、权限、GTT、HIE 类型、回滚和范围结果；数据库可用后补编译/错误视图和窄集成门禁，数据库不可用时保持 CHANGES_REQUESTED。

</details>

<details>
<summary>Details</summary>

### Dynamic source trust boundary is still broader than the business contract

**confirmed** `VALIDATE_OBJECT` 对 SOURCE_TABLE 做了正则、`DBMS_ASSERT`、`ALL_OBJECTS` 和当前 owner 检查，但 `P_TARGET=FALSE` 的分支没有查逐对象 source 白名单；因此配置可以选择当前 owner 下任何包含 5 个基础字段和 18 个同名金额字段的 TABLE、VIEW 或 MATERIALIZED VIEW。对 HIE 的检查也只允许 `TGK_FIMA_HISENSE` 下匹配 `^V_REF(_ED)?_...` 的任意视图，并未把 `COD_DEST2 -> V_REF_DEST2`、`D_GRAN_CAL -> V_REF_ED_D_GRAN_CAL` 等批准对象固化为映射表。值绑定能阻止 token 注入，却不能阻止未经批准的数据对象或 HIE 语义进入结果；应按 source/HIE/字段/类型/直接 grant 建立固定契约后再允许配置执行。

这条边界还没有覆盖全部授权。代码只对跨 owner HIE 视图查询 `ALL_TAB_PRIVS`，没有对 source、target、配置表、GTT、日志表和公司范围对象验证过程 owner 的直接授权；`AUTHID DEFINER` 下依赖角色或错误 owner 会在动态 parse 或静态引用处失败。配置、GTT、日志和 SESSION 表均以未限定 owner 的静态名称使用，`CURRENT_SCHEMA` 还被用于拼接动态对象 owner；在没有真实部署矩阵前，过程不能被判定为可部署。

### Configuration and target contracts do not close the Oracle execution gate

**confirmed** `CHECK_CONFIG_CONTRACT` 只检查有效期、TARGET_TABLE、SOURCE_TABLE 和 10 组三列，随后静态 cursor 直接读取 11 个目标维度配置列，却没有逐一检查这些列、配置对象类型或稳定规则主键。`CHECK_REQUIRED_COLUMNS` 对 source 的基础字段/金额做了字符与 NUMBER 检查，但对目标维度、类别、币种和 6 个天数字段没有完整类型/长度/精度检查；对目标额外非空字段的判断也不能替代完整 target DDL 契约。实际 DDL、owner、直接授权和额外非空列未确认时，这些缺口可能在编译、parse 或 INSERT 时才暴露。所有对象和字段契约必须在任何目标 DELETE 之前闭合。

**confirmed** 规则 ID 在循环中由 `ROWIDTOCHAR(RID)`、source 和 target 计算哈希。ROWID 会因表迁移、重装或导入变化，哈希也可能碰撞；它不能承担计划要求的稳定规则排序、错误定位和重复配置诊断。应使用配置表真实稳定主键；若配置表没有该字段，应在数据库门禁中阻断，而不是以 ROWID 代替。

### Runtime company scope is not the reference turnover scope

**confirmed** 实现从 `TGK_FIMA_HISENSE.V_REF_AZIENDA` 复制全量关系，只以 HIE=10 和 P_AZIENDA 的 ELEM/NODE/ALL 生成 `SESSION_AZIENDA_LIST`。参考程序另外按 `AW_RUL_ATSMAP_000001`、有效 `AW_RUL_COSMAP_000001`、`AW_RUL_DWMCRS_000001` 的 ARP 标记/科目和场景期间锁定规则收敛公司范围。当前计划明确要求在新引擎口径冻结前不能默默继承或默默省略这些规则；实现已经选择了省略，却没有代码内的待确认阻断或批准标识。这样即使 source 和 DELETE 共享自身列表，也可能读写参考周转口径之外的公司。

### SESSION-level cleanup does not isolate shared range state

**confirmed** 过程取得的是名称为 `CPM_SP_S2S_TDAYS_M_SESSION_<session>` 的锁，随后按 SESSION_ID 删除 `SESSION_AZIENDA_LIST` 和 `SESSION_V_REF_AZIENDA` 全部行；该锁不能约束其他过程使用同一共享表。异常处理在任何失败点也会无条件删除这两个表的当前 session 行，包括尚未取得目标锁或尚未完成本过程初始化的失败。若调用方或其他过程在同一数据库 session 中保有范围状态，结果可能被清空或被本次范围污染。应让共享表具备 RUN_ID 并在所有读写中携带它，或者建立跨过程的统一互斥和“本过程拥有的行”证明。

### Formula assumptions are shipped as facts instead of release gates

**confirmed** 文件头和最终 INSERT 都把三套 YTD/MTD 计算中的本月占用固定替换成相应 `*_END_OCP_AMT`，并将六个零分母 CASE 固定返回 NULL。用户提供的目标字段没有 `*_MTD_OCP_AMT`，但计划和设计把这个映射及零分母行为列为尚待业务确认的发布门禁；当前实现没有把这两项标成代码级待确认，也没有在确认前拒绝装载。公式字段虽然齐全，业务结果仍可能与确认口径不同，必须先冻结映射和边界样例。

### Business commit and END logging report different states

**confirmed** 正常路径在清理 session/GTT 后调用自治 `WRITE_LOG('END 执行完成')`，然后才执行主事务 `COMMIT`。因此目标 DELETE/INSERT 的提交失败时，日志已经独立提交了成功 END；反之日志本身失败又会在主提交前触发回滚。设计要求 END 反映已提交业务状态，而当前顺序无法满足这一点。提交后写 END 时若日志失败，现有 `P_STRICT=>FALSE` 只向 `DBMS_OUTPUT` 输出错误，没有返回状态、告警表或事件接口，调度方无法可靠观察日志故障。

### Target cleanup does not use the same dimension normalization as scope generation

**confirmed** scope 通过 `DIM_VALUE` 把配置空值转为 ZZZZ，并拒绝配置值 ALL；DELETE 的动态谓词只使用 `NVL(NULLIF(TRIM(D.column), ''), 'ZZZZ')`，没有把历史目标中的 `ALL` 映射成 ZZZZ。若旧结果以 ALL 表示通配而新配置产生 ZZZZ，旧行不会被删除，随后 INSERT 会留下并行结果。应按最终确认的 ALL 语义统一 scope、DELETE 和 INSERT；若 ALL 应非法，则必须在发布前处理历史数据而不能静默留下。

### Verification evidence stops at text presence

**confirmed** 验证记录中的 Python 检查能证明过程名、参数、10 组字段名、9 类操作符文本、18 个 `SUM(NVL(...))`、6 个 CASE 和若干 API 名称存在，也确认参考程序工作区差异仍为既有 `36/4`。但这些断言不能证明 PL/SQL 编译、动态 SQL 的实际 bind 对应关系、Oracle `IN`/`NOT IN` 1000/1001 分块、对象直接授权、GTT `ON COMMIT`、HIE ELEM 类型兼容、范围交集或异常回滚。验证记录也明确本机无 sqlplus/sqlcl 和数据库连接；在这些证据补齐前，门禁必须保持阻塞，而不能把静态通过解释成可执行性通过。

</details>

<details>
<summary>File map</summary>

- `01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql` — 配置驱动动态来源读取、规则解析、暂存聚合、目标删除/装载、周转天数和日志异常处理。
- `.agents/tasks/CPM_SP_S2S_TDAYS_M-plan.md` — 实现计划与发布门禁，作为本审查的约束输入。
- `.agents/tasks/CPM_SP_S2S_TDAYS_M-design.md` — 设计口径、未决假设和验收标准，作为本审查的约束输入。
- `.agents/tasks/CPM_SP_S2S_TDAYS_M-verification.md` — 代码员静态验证记录及数据库不可用说明。

完整实现内容以目标 SQL 文件为准；参考程序 `CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` 仅作只读对照，本审查未把其既有 `36/4` 工作区差异归因于本任务。

</details>
