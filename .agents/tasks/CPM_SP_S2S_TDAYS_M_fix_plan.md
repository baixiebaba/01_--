# CPM_SP_S2S_TDAYS_M Oracle 编译错误修复实施计划

## 只读检查结论

已只读检查目标过程 `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql` 的完整内容、变量声明、配置循环、SESSION 公司范围初始化、动态删除 SQL、动态 INSERT SQL、异常处理，以及参考过程 `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql`。参考过程只用于理解模式，绝不修改。

目标过程中的相关出现位置分类如下：

1. 第 386 行附近的 `AND NOT EXISTS (SELECT 1 FROM SESSION_AZIENDA_LIST...)` 位于配置 `FOR R IN (...) LOOP` 内的 PL/SQL `IF` 条件中，不属于 SQL 语句的 `WHERE/HAVING/JOIN`，会触发 `PLS-00204`。这是本次必须修复的唯一直接 `EXISTS/NOT EXISTS` 编译错误。
2. 第 407 行的 `V_TARGET_SEEN.EXISTS(V_TARGET_OBJECT)` 是 PL/SQL 关联数组 `T_SEEN_TABLE` 的 `EXISTS` 集合方法，不是 SQL 的 `EXISTS` 伪列，保留不改。
3. 第 412 行和第 424 行的 `EXISTS` 位于 `V_DELETE_SQL := ...` 拼接出的动态 SQL 字符串中，实际执行时分别属于目标删除 SQL 的 `WHERE` 子查询和 SESSION 公司范围子查询，语法合法，保留不改。
4. 目标过程没有其他直接写在 PL/SQL `IF/ELSIF/赋值表达式`中的 `EXISTS/NOT EXISTS`。`NOT REGEXP_LIKE(...)` 是合法的 PL/SQL 条件调用，不属于本类错误。
5. 参考过程出现的 `EXISTS/NOT EXISTS` 均位于 `DELETE` 或 CTE/查询的 `WHERE` 条件中，未发现可复制为 PL/SQL `IF` 的直接用法。

当前工作区没有找到 README、AGENTS.md、CONTRIBUTING.md、package.json、Makefile 或 sqlplus 包装脚本；因此本任务没有可直接复用的项目自动化编译命令。知识库副本已检查，SESSION 公司范围和本过程使用的 `SESSION_AZIENDA_LIST` 属于已登记的 Oracle 会话对象；实际编译仍需目标 Oracle 环境和有效连接信息。

## 实施步骤

- [ ] 1. 在目标过程声明区增加 SESSION 公司命中计数变量。
      在 `V_CONFIG_COUNT NUMBER := 0;`、`V_INSERT_COUNT NUMBER := 0;` 附近增加 `V_SESSION_AZIENDA_COUNT NUMBER := 0;`，用于复用到每条配置规则的公司命中检查。不要修改参考过程、过程签名或现有其他变量。
      文件：`/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`
      验证：完成后执行目标文件的文本检查，确认变量只在目标过程声明区新增，参考过程和其他 SQL 源文件无改动。

- [ ] 2. 将配置公司 PL/SQL `NOT EXISTS` 替换为 `SELECT COUNT(*) INTO` 后的 `CONTINUE`。
      在配置 `FOR R IN (...) LOOP` 中、当前配置有效期校验之后、P_BG 判断之前，替换第 386 行的直接 `AND NOT EXISTS` 条件为以下等价逻辑：仅当 `TRIM(R.COD_AZIENDA) IS NOT NULL` 时执行 `SELECT COUNT(*) INTO V_SESSION_AZIENDA_COUNT FROM SESSION_AZIENDA_LIST L WHERE L.SESSION_ID = V_SESSION_ID AND TRIM(L.ELEM) = TRIM(R.COD_AZIENDA)`；当计数为 0 时执行 `CONTINUE`，否则继续处理当前配置。补充中文注释，说明这是把 SQL 子查询改为合法 PL/SQL 控制流，并保持“配置 R.COD_AZIENDA 非空时，只有命中当前 V_SESSION_ID 的 SESSION_AZIENDA_LIST 才处理，未命中跳过”的原业务语义。`COUNT(*)` 必然返回一行，不新增 `NO_DATA_FOUND` 分支。
      不得把该检查改成无 SESSION_ID 条件的计数，不得放宽为节点或运行参数字符串匹配，不得改变空配置公司的 `ZZZZ` 目标处理逻辑；后续动态 SQL 中已有的 SESSION 公司过滤继续保留。
      文件：`/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`
      验证：执行静态语法边界检查，确认直接 PL/SQL 条件中不再出现 `AND NOT EXISTS`；确认保留 `V_TARGET_SEEN.EXISTS(...)` 和动态 SQL 字符串中的两个合法 `EXISTS`。

- [ ] 3. 对目标过程做最小范围回归核对，禁止顺带改动现有架构和业务字段逻辑。
      逐项确认过程名仍为 `CPM_SP_S2S_TDAYS_M`，10 组 `APPEND_FILTER` 调用、HIE 规则处理、18 个金额字段聚合、6 个周转天数公式、`NEWID()`、目标审计字段写入、动态 SQL 架构、SESSION 公司范围初始化/清理、直接 `INSERT INTO ZTAB_CPM_LOG` 日志和现有提交/异常处理均未改变。不得新增 `SESSION_TOVCAL_RESULT`、`SESSION_TOVCAL_SCOPE` 或任何 GTT；不得恢复 `WRITE_LOG`；不得把 SQL `WHERE` 中合法的 `EXISTS` 改为其他形式。
      文件：`/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`
      验证：执行 `git diff --check -- 01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`，确认无空白错误；再用只读差异检查确认只有计数变量声明、PL/SQL 公司命中检查和必要注释发生变化。不要创建 Git commit。

- [ ] 4. 执行文本级 PL/SQL/SQL 结构检查。
      使用 Python 或其他本地只读脚本读取目标文件，检查过程仍以 `CREATE OR REPLACE PROCEDURE CPM_SP_S2S_TDAYS_M` 开始并以 `END CPM_SP_S2S_TDAYS_M; /` 结束；检查 `SELECT COUNT(*) INTO V_SESSION_AZIENDA_COUNT` 位于配置循环中；检查 `SESSION_ID = V_SESSION_ID` 和 `TRIM(L.ELEM) = TRIM(R.COD_AZIENDA)` 同时存在；检查 `EXISTS` 分类结果为：一个集合方法、两个动态 SQL 字符串，且没有 PL/SQL 直接 `AND NOT EXISTS`。同时检查 `BEGIN/END`、`IF/END IF`、`LOOP/END LOOP` 和过程结束分隔符成对，避免替换时漏掉控制块。
      该检查只证明文本结构和括号/控制块边界，不把它当作 Oracle 编译结果；不能用简单的全文件 `grep` 结果替代字符串与 PL/SQL 上下文区分。
      文件：`/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`
      验证：本地脚本退出码为 0，并输出目标过程、命中计数 SQL、合法动态 SQL `EXISTS` 和集合方法检查均通过。

- [ ] 5. 在 Oracle 客户端可用时执行真实编译并核对错误视图。
      使用项目实际可用的 Oracle 客户端和连接方式，在目标数据库中只编译 `CPM_SP_S2S_TDAYS_M`，然后查询当前 schema 的 `USER_ERRORS`（必要时查询 `ALL_ERRORS`）中该过程的 `PLS-`、`ORA-` 和 `SP2-` 错误，重点确认第 386 行的 `PLS-00204` 已消失且没有新增同类语法错误。编译测试不得修改参考过程，不执行目标数据装载，不新增表/GTT，不创建 Git commit。
      文件：数据库中的目标过程；本地只读取目标 SQL 文件作为编译输入。
      验证：Oracle 编译返回成功，`USER_ERRORS` 对 `CPM_SP_S2S_TDAYS_M` 无编译错误；若环境要求执行脚本，先用 `SHOW ERRORS PROCEDURE CPM_SP_S2S_TDAYS_M` 再查错误视图。

- [ ] 6. Oracle 客户端不可用或连接失败时如实报告验证边界。
      先记录客户端检查结果（例如 `command -v sqlplus` 的结果）和连接/权限/对象缺失错误；不得把本地文本检查、编辑器高亮或静态匹配描述为“Oracle 已编译通过”。报告必须明确写出：已完成目标 SQL 的静态结构检查和差异检查；未完成 Oracle 服务器编译、`USER_ERRORS` 查询、对象权限验证及运行时 SESSION 公司范围验证；待具备连接后按步骤 5 重试。若 SQL 源文件未被修改，则本计划阶段只应报告计划文件已生成，并确认没有 SQL 源文件变更。
      文件：`/Users/shiqingfeng/Documents/1_工作/01_海信/.agents/tasks/CPM_SP_S2S_TDAYS_M_fix_plan.md`
      验证：最终报告不声称未执行的数据库验证，不创建 Git commit。

## 明确不变项

- 不新增 `SESSION_TOVCAL_RESULT`、`SESSION_TOVCAL_SCOPE` 或 GTT。
- 动态 SQL 架构不变；只修复配置循环中的 PL/SQL 控制流。
- 日志继续直接 `INSERT`，不恢复 `WRITE_LOG`。
- 目标过程名、10 组筛选、HIE 规则、18 个金额、6 个周转天数、`NEWID()`、目标通用字段和 SESSION 公司范围逻辑不改变。
- 不修改参考过程 `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql`。
- 本次只生成本计划文件；实施阶段不得创建 Git commit，也不得把任何其他 SQL 源文件作为顺带格式化对象。
