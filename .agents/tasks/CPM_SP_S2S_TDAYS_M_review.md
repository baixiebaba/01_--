# Replace the PL/SQL configuration-company `NOT EXISTS` check

本次目标差异只改动 `CPM_SP_S2S_TDAYS_M.sql` 的两处：声明区新增 `V_SESSION_AZIENDA_COUNT`，配置循环中把直接写在 PL/SQL `IF` 条件里的公司范围 `NOT EXISTS` 改成 `SELECT COUNT(*) INTO` 后按计数 `CONTINUE`。修复逻辑本身保持了非空配置公司必须命中当前 SESSION 公司范围才继续处理的语义；空配置公司仍走原有目标维度 `ZZZZ` 逻辑。窄范围静态核对未发现其他直接位于 PL/SQL `IF/ELSIF/赋值表达式`中的 SQL `EXISTS/NOT EXISTS`，但 coder 的验证记录实际检查的是另一版 DBMS_SQL/GTT 实现，与当前目标文件不匹配。

Watch for: **confirmed** `CPM_SP_S2S_TDAYS_M-verification.md` 声称当前文件包含 `SESSION_TOVCAL_RESULT`、`SESSION_TOVCAL_SCOPE`、DBMS_SQL、DBMS_LOCK 和 1000 项分块逻辑，而当前目标文件实际不包含这些内容；需要按当前版本重新记录文本/语法检查结果。**confirmed** coder 记录为 `ORACLE_CLIENT_UNAVAILABLE`，没有执行 Oracle 编译或 `USER_ERRORS` 查询；本审查不能把静态核对描述为数据库编译通过。

**Verdict**: NEEDS_CHANGES

## High-level view

**confirmed** 修复块的控制流语义是正确的：仅在 `TRIM(R.COD_AZIENDA) IS NOT NULL` 时查询当前 `V_SESSION_ID` 的 `SESSION_AZIENDA_LIST`，计数为零则跳过配置，命中后才继续执行；`COUNT(*)` 聚合查询静态上总会返回一行，变量类型也匹配。

**confirmed** `EXISTS` 的剩余出现位置没有被误改：`V_TARGET_SEEN.EXISTS(...)` 是 PL/SQL 关联数组方法，删除 SQL 字符串中的两个 `EXISTS` 位于合法的 `WHERE` 子查询中；窄范围扫描未发现其他直接写在 PL/SQL 条件或赋值表达式中的 SQL `EXISTS/NOT EXISTS`。

**confirmed** 目标过程的实际差异只包含计数变量声明和公司命中控制流替换。动态 SQL 架构、目标过程名、10 组筛选、HIE、18 个金额、6 个周转天数、`NEWID()`、直接日志 `INSERT`、SESSION 公司范围逻辑和现有禁止新增对象均保持不变；数据库编译没有执行。唯一阻塞项是 coder 验证记录错配，导致本次文本/结构检查不能由既有记录复核。

<details>
<summary>Issues (1)</summary>

1. **当前版本的 coder 验证记录错配（confirmed）** — `CPM_SP_S2S_TDAYS_M-verification.md` 检查并声称存在当前文件没有的 DBMS_SQL、GTT、`SESSION_TOVCAL_RESULT`、`SESSION_TOVCAL_SCOPE`、DBMS_LOCK 和分块逻辑，不能证明本次 `COUNT(*) INTO`、`IF/END IF`、`CONTINUE` 或同类 `EXISTS` 扫描；按当前目标文件重新生成文本/语法检查记录，并继续明确 Oracle 编译未执行。

</details>

<details>
<summary>Details</summary>

### The configuration-company gate now uses valid PL/SQL control flow

**confirmed** 目标 diff 在声明区新增 `V_SESSION_AZIENDA_COUNT NUMBER := 0`，在配置 `FOR R IN (...) LOOP` 的有效期校验之后，将原先的直接 `NOT EXISTS` 替换为 `IF TRIM(R.COD_AZIENDA) IS NOT NULL THEN` 下的 `SELECT COUNT(*) INTO V_SESSION_AZIENDA_COUNT`。查询同时限定 `L.SESSION_ID = V_SESSION_ID` 和 `TRIM(L.ELEM) = TRIM(R.COD_AZIENDA)`；计数为零时执行 `CONTINUE`，因此非空配置公司只有命中当前 SESSION 范围才继续，空配置公司不会进入该计数分支。

### EXISTS forms remain separated by execution context

**confirmed** 当前文件中剩余的 `EXISTS` 可分为三处：`V_TARGET_SEEN.EXISTS(V_TARGET_OBJECT)` 这一关联数组方法，以及 `V_DELETE_SQL` 字符串中的目标删除范围子查询和 SESSION 公司范围子查询。后两处在动态 SQL 的 `WHERE` 条件中，保留是正确的；`NOT REGEXP_LIKE(...)` 是合法的 PL/SQL 函数条件，不属于 SQL `NOT EXISTS`。窄范围搜索未发现其他直接位于 PL/SQL `IF/ELSIF/赋值表达式`中的 `EXISTS/NOT EXISTS`。

### The intended preservation boundary is visible in the actual diff

**confirmed** 目标过程 diff 仅包含声明区一行和第 386 行附近的控制流块，没有改变过程名或签名。当前文件仍保留 10 次 `APPEND_FILTER(R.COLUMN_NAME_...)` 调用、HIE 分支、18 个 `SUM(NVL(S.<金额>, 0))`、6 个周转天数 CASE、`NEWID()`、动态 `V_SQL/V_DELETE_SQL`、直接 `INSERT INTO ZTAB_CPM_LOG` 以及 SESSION 公司范围初始化/清理；文件中没有新增 `SESSION_TOVCAL_RESULT`、`SESSION_TOVCAL_SCOPE`、GTT 或 `WRITE_LOG`。

**confirmed** 目标文件的实际工作区差异不包含参考过程。工作区状态显示参考过程另有差异，coder 记录称该参考文件在本轮前后均为 `36/4`；因此这些既有差异不能归因于本次修复，但没有任务起始快照时，只能将“未被本次目标 diff 修改”作为可核验边界，而不能把工作区整体清洁误报为事实。本审查未修改任何代码、参考过程或创建 Git commit。

### Current verification evidence cannot be reused as-is

**confirmed** `CPM_SP_S2S_TDAYS_M-verification.md` 中的断言要求 `SESSION_TOVCAL_RESULT`、`SESSION_TOVCAL_SCOPE`、DBMS_SQL、DBMS_LOCK、`RUN_ID`、GTT 暂存和 1000 项分块，但当前目标文件使用 `EXECUTE IMMEDIATE`，仅使用 `SESSION_AZIENDA_LIST`/`SESSION_V_REF_AZIENDA`，不存在这些对象或逻辑。因此该记录不能证明当前版本的计数查询、控制块闭合或同类 `EXISTS` 分类。

**confirmed** coder 记录同时给出 `ORACLE_CLIENT_UNAVAILABLE`，说明没有执行 sqlplus/sqlcl、Oracle 编译、`USER_ERRORS/ALL_ERRORS` 查询、对象权限验证或运行时 SESSION 范围验证。当前审查只进行了围绕修复块的差异阅读和窄范围 `EXISTS` 分类核对，没有重复完整检查或测试套件；最终结论必须保持“数据库编译未执行”。

</details>

<details>
<summary>File map</summary>

- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql` — 在配置循环中用计数查询和 `CONTINUE` 替换非法 PL/SQL `NOT EXISTS`。
- `/Users/shiqingfeng/Documents/1_工作/01_海信/.agents/tasks/CPM_SP_S2S_TDAYS_M_fix_plan.md` — 本次修复计划、检查要求和明确保留项。
- `/Users/shiqingfeng/Documents/1_工作/01_海信/.agents/tasks/CPM_SP_S2S_TDAYS_M-verification.md` — coder 既有验证记录；内容与当前目标文件版本错配，是本审查发现的阻塞证据问题。

完整目标差异以 Git 工作区中的 `CPM_SP_S2S_TDAYS_M.sql` 为准；参考过程仅作只读边界核对。

</details>
