# CPM_SP_S2S_TDAYS_M 实现计划

## 1. 任务范围与已核对事实

本计划仅规划新增 Oracle 存储过程文件：

`/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`

禁止修改：

`/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql`

已读取并作为实现依据的文件：

- `/Users/shiqingfeng/Documents/1_工作/01_海信/.agents/tasks/CPM_SP_S2S_TDAYS_M-design.md`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/.agents/tasks/CPM_SP_S2S_TDAYS_M-design-review.json`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/.agents/tasks/CPM_SP_S2S_TDAYS_M-design-review.md`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_INS_M_PHASE2.sql`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_BD_M_PHASE2.sql`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_D2M_ARP_M_PHASE2.sql`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询.sql`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询_2026ACT08_2600_ALL.sql`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/ADS_周转明细表_字段英文命名.md`
- `/Users/shiqingfeng/Documents/1_工作/01_海信/98_临时存/kbdata_副本.json`

实际核对结果：

- 参考过程的签名顺序确实为 `P_SCENARIO、P_PERIODO、P_AZIENDA、P_BG、SESSION_USER`，并使用 `SYS_CONTEXT('USERENV','SESSIONID')`、`SESSION_AZIENDA_LIST`、`SESSION_V_REF_AZIENDA`、`ZTAB_CPM_LOG` 及 `ROLLBACK/ERROR日志/RAISE` 模式。
- 参考周转过程的公司范围还叠加了 `AW_RUL_ATSMAP_000001`、`AW_RUL_COSMAP_000001`、`AW_RUL_DWMCRS_000001` 和锁定规则；新过程是否完全沿用该范围必须按设计门禁冻结，不能默默继承或默默省略。
- 知识库副本登记了 `AW_MR7_ARPS02_000001`，未登记用户指定的 `AW_MR7_ARPA01_000001`、`AW_RUL_TOVCAL_000001`、`V_REF_ED_D_GRAN_CAL`、`SESSION_TOVCAL_RESULT` 或 `SESSION_TOVCAL_SCOPE`；本地也未找到这些对象的真实 DDL/SQL。
- 用户给出的目标字段资料明确要求目标为 `AW_MR7_ARPA01_000001`，包含 39 个业务字段：15 个维度字段、18 个金额字段和 6 个周转天数字段。不能以知识库中的 `ARPS02` 静默替换用户指定目标。
- 当前工作区没有 README、AGENTS.md、CONTRIBUTING.md 或项目级构建脚本；系统中未发现 `sqlplus`、`sqlcl` 或 `sqlfluff`，仅有 Python 3。因此数据库编译、权限、真实对象类型、执行计划和真实结果不能在本地验证。

## 2. 选定实现方案与边界决策

1. **采用 PL/SQL + DBMS_SQL + 预创建 GTT。** `SOURCE_TABLE` 和 `TARGET_TABLE` 会变化，静态 SQL 无法安全覆盖动态对象；采用 `DBMS_SQL`，但动态 SQL 只允许插入经过固定白名单、数据字典和 `DBMS_ASSERT` 校验的对象名/列名/固定操作符片段，配置值全部绑定。来源结果先写入 `SESSION_TOVCAL_RESULT`，再删除和装载目标，解决 `SOURCE_TABLE=TARGET_TABLE` 的同表读写问题。
2. **v1 只支持一个已确认 target：用户指定的 `AW_MR7_ARPA01_000001`。** 不将知识库中的 `AW_MR7_ARPS02_000001` 当作替代目标；在目标身份、owner、DDL、独占性和直接授权确认前，过程设计中的 target 白名单、DELETE 和 INSERT 均属于发布阻断项。
3. **source 仍可按配置动态选择，但必须逐对象登记 source contract。** 每个允许 source 必须逐一确认 owner、对象类型、5 个基础字段、18 个金额字段、字段类型/精度和可过滤列；不根据字段同名或目标表结构相似度推断业务语义。缺失任一字段或契约未确认时，在任何目标删除前报错。
4. **配置维度的空值规则与来源直接字段规则分开。** 配置生成的 11 个目标维度空值统一补 `ZZZZ`；`COD_CATEGORIA`、`COD_VALUTA` 按用户“直接对应”语义处理，是否把来源 NULL/空格也归为 `ZZZZ` 必须先确认，不得沿用参考过程的 `CNY` 或未经授权的统一填充。配置字面量 `ALL` 不自动当作所有维度的通配值，除非业务逐字段确认其语义。
5. **公司和事业部范围必须在代码前冻结。** 计划保留设计提出的安全交集原则：运行公司范围、配置 `COD_AZIENDA` 范围、来源过滤和目标删除必须使用同一个 scope；但采用参考过程的 ATSMAP/COSMAP/DWMCRS 规则，还是采用批准的 `V_REF_AZIENDA HIE='10'` 范围，必须以业务/DBA确认为准。不能让 `P_AZIENDA='ALL'` 或 `P_BG='ALL'` 无边界扩展。
6. **YTD“本月占用金额”和零分母策略必须冻结。** 当前字段集合没有 `*_MTD_OCP_AMT`，设计稿暂以 `*_END_OCP_AMT` 作为候选映射、以分母为零输出 0 作为候选策略；这两项仅是待确认假设，不能在计划中伪装成已确认事实。实现时只使用最终确认的一套公式。
7. **主事务采用“全部来源暂存后再删装，成功末尾一次提交”。** `DBMS_LOCK.ALLOCATE_UNIQUE` 的事务副作用需在数据库门禁中验证；若会提交，应在业务 DML 前预分配 handle 或使用预生成 handle。目标级锁按 canonical target + scenario + periodo 获取，避免不同输入参数命中相同目标范围时并发覆盖。
8. **日志沿用现有 `ZTAB_CPM_LOG` 字段和中文阶段名称，但日志失败策略需可执行。** 参考过程使用 BEGIN、删除完成、目标装载完成、END、ERROR，并以 `SESSION_USER` 写入创建人；本过程应记录 RUN_ID、阶段、规则、source/target 和错误信息。日志字段长度、自治/主事务策略及 END 提交后的失败可观测机制必须在数据库门禁中确认，不能仅声明“日志失败但监控可见”。

## 3. 有序实现步骤

- [ ] 1. 冻结部署矩阵、业务口径和代码生成前硬门禁。
      取得并记录过程 owner、`AUTHID`、配置表 owner/DDL、用户指定目标 `AW_MR7_ARPA01_000001` 的 owner/DDL/非空默认列/索引/独占证明、允许 source 的逐对象字段契约、HIE 对象映射、两个 GTT 的 owner/DDL/索引、`ZTAB_CPM_LOG` DDL/长度以及所有直接授权。确认 `VALID_FR/VALID_TO` 类型、稳定规则标识、场景格式、P_AZIENDA/P_BG 范围、配置 `ALL` 语义、类别/币种空值规则、YTD 本月占用字段和零分母行为。目标对象仍以用户指定的 `AW_MR7_ARPA01_000001` 为准；若业务确认其为笔误，必须先修订设计和计划后再编码，不能由实现者自行切换到 `ARPS02`。
      Files: `/Users/shiqingfeng/Documents/1_工作/01_海信/.agents/tasks/CPM_SP_S2S_TDAYS_M-design.md`（仅在取得新权威资料后更新）、待 DBA 提供的 DDL/授权资料；本步骤不修改生产 SQL。
      Verify: 数据库可用时查询 `ALL_OBJECTS`、`ALL_TABLES`、`ALL_TAB_COLUMNS`、`ALL_CONSTRAINTS`、`ALL_INDEXES`、`ALL_TAB_PRIVS`/直接授权视图并形成对象清单；数据库不可用时将本步骤标记为“阻断，静态资料不足”，不得声称过程可编译或可部署。

- [ ] 2. 确认或部署两个预创建会话暂存 GTT，并闭合同一 session 的隔离策略。
      按设计稿创建/核验 `SESSION_TOVCAL_RESULT` 和 `SESSION_TOVCAL_SCOPE`，均使用 `ON COMMIT PRESERVE ROWS`，包含 `SESSION_ID + RUN_ID`、canonical target、场景期间、11 个配置维度、类别/币种及18个金额所需列；为最终聚合键、scope 唯一键和 session/run 查询建立索引。现有共享表 `SESSION_AZIENDA_LIST`、`SESSION_V_REF_AZIENDA` 若不能增加 RUN_ID，则通过 session 级互斥禁止重入；若能改表，则所有清理/读取改为 `SESSION_ID + RUN_ID`。过程不在运行时 CREATE TABLE，也不把 GTT 当作生产 DDL 隐式创建。
      Files: 数据库部署 DDL（待确认路径）；实现过程中的静态 GTT 引用仅写入目标过程文件。
      Verify: 数据库可用时查询 `ALL_TABLES.TEMPORARY/DURATION`、`ALL_TAB_COLUMNS` 和索引，确认 `ON COMMIT PRESERVE ROWS`、列类型和索引闭合；数据库不可用时只能由文本检查确认过程引用列与设计清单一致，不能验证对象存在。

- [ ] 3. 建立过程文件头、签名、参数初始化和运行上下文。
      新建过程 `CPM_SP_S2S_TDAYS_M`，签名严格包含并按顺序排列 `P_SCENARIO IN VARCHAR2`、`P_PERIODO IN VARCHAR2`、`P_AZIENDA IN VARCHAR2`、`P_BG IN VARCHAR2`、`SESSION_USER IN VARCHAR2`，使用 Oracle 大写、文件头块注释、中文行注释和逗号前置字段格式。初始化 `V_SESSION_ID := SYS_CONTEXT('USERENV','SESSIONID')`、规范化期间、年月、`RUN_ID := RAWTOHEX(SYS_GUID())`、执行阶段、当前规则/source/target、DBMS_SQL 游标和锁句柄；日志不使用可能因公司数量过多而 `LISTAGG` 溢出的完整公司清单。
      Files: `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`
      Verify: `python3` 文本检查过程名、5 个参数名称/顺序、`SESSION_USER` 使用、文件头和禁止修改的参考文件未发生变化；预期目标文件存在且仅包含新过程草稿，参考过程 `git diff --exit-code -- CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` 不应因本任务产生改动。

- [ ] 4. 实现前置参数、有效期和配置 scope 校验。
      在任何目标 DELETE 前校验场景非空/长度及正式场景格式、期间只能规范化为 `01~12`、公司和事业部 token 无空 token/重复分隔符/非法混合 ALL，`SESSION_USER` 长度符合日志契约。按 `VALID_FR <= V_YEARMONTH AND NVL(VALID_TO,'999999') >= V_YEARMONTH` 读取配置，并校验有效期格式、月份、起止顺序和稳定 RULE_ID。配置每行校验 `TARGET_TABLE` 只能命中已确认的 ARPA01 canonical target，`SOURCE_TABLE` 只能命中 source 白名单，目标维度和 `COD_AZIENDA`/`D_BG` 的适用性按冻结口径规范化；无适用配置时正常结束且不删除目标，配置错误必须在目标变更前失败。
      Files: `CPM_SP_S2S_TDAYS_M.sql`；设计/部署矩阵资料。
      Verify: 静态检查确认所有配置校验位于 DELETE 之前；数据库可用时分别用非法期间、非法有效期、未知 RULE_ID、非白名单 target/source、未命中公司范围配置执行负向测试，预期目标表无变化并记录包含规则/source/target 的错误。

- [ ] 5. 实现运行公司范围、HIE 公司交集和目标 scope 建立。
      按已确认的组织口径重建 `SESSION_V_REF_AZIENDA` 和 `SESSION_AZIENDA_LIST`；支持 `P_AZIENDA` 的具体 ELEM、允许的 NODE 和 ALL，但只保留当前运行范围。`P_BG` 按完整 token 匹配，不自动将 `BG001` 展开为 `BG001_BU001`。配置 `COD_AZIENDA` 必须与运行公司集合相交，未命中不得建 scope、读 source 或删 target；配置空值的输出维度按确认规则补 `ZZZZ`。把 canonical target、场景、期间和完整 11 个目标维度写入 `SESSION_TOVCAL_SCOPE`，不把 RULE_ID 放进最终 scope 唯一键，以允许多个不同 source 汇入同一目标 scope，同时拒绝同一 source/target/output scope 重复规则。
      Files: `CPM_SP_S2S_TDAYS_M.sql`；必要时的 GTT/共享 session 表部署 DDL。
      Verify: 静态检查确认 source 条件、scope 条件、DELETE 条件共享同一 session/run 公司边界；数据库可用时覆盖 `P_AZIENDA='2600'`、配置公司 `6100`、配置公司 ALL、ELEM、NODE、未命中，以及 `P_BG='ALL'`/具体事业部，预期不越界建立 scope。

- [ ] 6. 实现对象、列、类型、权限和 HIE 映射安全校验。
      对配置中的 source/target 名称先 `TRIM/UPPER`，只接受简单标识符或固定 owner.table，拒绝引号、空格、注释、分号、`@`、换行和多余点；同时调用 `DBMS_ASSERT.SIMPLE_SQL_NAME`/`SQL_OBJECT_NAME`，再用白名单和 `ALL_OBJECTS/ALL_TAB_COLUMNS` 完成 owner、对象类型、列存在性、字符类型、金额 NUMBER 类型/精度、HIE `ELEM/HIE/NODE` 类型以及直接授权校验。HIE 只实现固定映射：`COD_*` 去掉前缀拼 `V_REF_*`，`D_*` 拼 `V_REF_ED_D_*`；至少明确校验 `COD_DEST2 -> V_REF_DEST2` 和 `D_GRAN_CAL -> V_REF_ED_D_GRAN_CAL`，不得按同名对象猜 owner 或回退。来源缺失任一基础字段/18个金额字段、target 存在额外 NOT NULL 无默认字段、HIE 视图缺失或类型不兼容，均在 DELETE 前失败。
      Files: `CPM_SP_S2S_TDAYS_M.sql`；部署矩阵和 source/HIE contract。
      Verify: 数据库可用时注入非法对象名、非白名单 owner、缺列、错误类型、缺直接授权和不存在 HIE 视图，预期过程在来源执行或目标删除前失败；数据库不可用时用 Python 检查 `DBMS_ASSERT`、`ALL_OBJECTS`、`ALL_TAB_COLUMNS` 和白名单校验代码均存在，并在待确认项中明确无法验证真实对象。

- [ ] 7. 实现 10 组、9 类操作符和 DBMS_SQL 绑定解析器。
      逐组处理 `COLUMN_NAME_1~10`、`COLUMN_FILTER_1~10`、`COLUMN_VALUE_1~10`：三列全空表示不加条件，只空部分列则报配置错误。支持且只支持 `=`、`<>`、`IN`、`LIKE`、`NOT LIKE`、`HIE`、`NOT IN`、`IS NULL`、`IS NOT NULL`；每个条件外层使用 `AND (...)`。`IN/NOT IN` 按逗号拆分并拒绝首尾/连续分隔符和空 token，按每组最多 1000 个 bind 分块；IN 分块用 OR，NOT IN 分块用 AND。LIKE/NOT LIKE 绑定完整模式，不自动追加 `%`；IS NULL/IS NOT NULL 要求 value 为空。绑定名使用固定长度安全编码（RULE_ID 仅用于日志，不直接拼入 bind 名），同一动态 SQL 内检查唯一性。
      HIE 值必须恰好包含一个 `|`，拆成绑定的 HIE/NODE，按来源字段前缀选择批准视图并生成 `S.COLUMN IN (SELECT ELEM ... WHERE HIE=:H ... NODE=:N)`；不得拼接配置值、HIE、NODE、IN token 或 LIKE 值。动态 SQL 仅拼接 canonical source、批准 HIE object、已字典校验列名和固定操作符模板。
      Files: `CPM_SP_S2S_TDAYS_M.sql`
      Verify: 文本检查确认10组字段和9个操作符都出现；数据库可用时覆盖每个组位、各操作符、1000/1001个 IN/NOT IN 值、重复分隔符、空 token、LIKE完整模式、HIE多分隔符和非法前缀，预期绑定执行正确或在源 SQL/DELETE 前拒绝。

- [ ] 8. 实现每条规则的来源聚合和同表读写隔离。
      对每条有效配置按稳定 RULE_ID 顺序构造固定 INSERT-SELECT，先将来源行写入 `SESSION_TOVCAL_RESULT`。来源固定绑定场景、期间、SESSION_ID/RUN_ID、运行公司范围和配置公司交集；来源目标维度映射按配置值或 `ZZZZ` 规范化，`COD_CATEGORIA`、`COD_VALUTA` 使用已确认的直接对应空值策略。18 个金额逐列 `SUM(NVL(SOURCE_COLUMN,0))`，并按目标维度、类别、币种形成来源聚合。所有规则和 source 完成前不执行目标 DELETE；因此 source 与 target 同名时仍从未删除的原目标读取。
      不允许通过拼接值生成 SQL；每次 DBMS_SQL 操作都按 parse、bind、execute、close 顺序管理游标，异常中关闭当前和已打开游标，并记录规则、canonical source/target 和阶段。
      Files: `CPM_SP_S2S_TDAYS_M.sql`
      Verify: 静态检查确认目标 DELETE 出现在所有动态 source 执行之后；数据库可用时配置 source=target 的最小数据集，预期暂存结果完整、删除发生在来源读取之后；重复执行结果不翻倍。

- [ ] 9. 获取目标级锁并实现事务边界、删除和最终装载。
      对已建立 scope 的 canonical target + scenario + periodo 排序后获取 `DBMS_LOCK`；锁名按固定 hash 算法生成，超时/死锁立即失败，不能按原始 `P_AZIENDA/P_BG` 加锁。按数据库门禁确认 `ALLOCATE_UNIQUE` 的提交行为后冻结调用时点。全部 source 暂存成功并锁定后，按 scope 删除当前场景/期间/完整11维目标数据；类别和币种是否纳入删除条件按已确认目标归属口径处理，未经独占证明不得执行宽范围删除。
      从 result GTT 再按目标唯一键聚合18个金额，在外层计算6个周转天数。目标 INSERT 只使用已确认的 39 个业务字段，字段逐行排列、逗号前置；金额先聚合后计算，分母保护按最终确认的 0/NULL 策略；YTD“本月占用”按确认映射，不由实现者临时选择。目标配置空值统一按确认的 `ZZZZ` 规范化表达式，删除、result 聚合和 INSERT 使用同一表达式。
      Files: `CPM_SP_S2S_TDAYS_M.sql`
      Verify: 数据库可用时核对18个金额逐列 SUM、6个公式、零分母、负数金额、空维度、无来源但有 scope、无适用配置和同一目标并发锁；查询 `USER_ERRORS/ALL_ERRORS` 确认无编译错误，并核对目标实际写入39列。数据库不可用时只能完成文本级字段/公式/顺序检查。

- [ ] 10. 实现日志、清理、异常恢复和锁释放。
      复用参考过程中文日志阶段：`BEGIN 开始执行`、参数/配置校验完成、来源暂存完成、目标范围删除完成、目标表装载完成、`END 执行完成`、`ERROR 执行报错`；日志中保留 `SESSION_USER`、场景、期间、原始参数摘要、RUN_ID、规则/source/target和错误码。正常路径在目标删除/装载全部成功后提交，再写 END 日志；END 日志提交后失败必须按已冻结的备用告警/日志策略可观测，不能把已提交业务误报为回滚失败。异常路径固定为：保存原始 SQLCODE/SQLERRM/阶段/规则/source/target，关闭 DBMS_SQL，ROLLBACK 目标事务，清理当前 session/run 的 GTT 和会话范围并单独提交清理，记录 ERROR，释放所有锁，最后重抛原始异常；清理、日志和释放错误不得覆盖原始异常。
      Files: `CPM_SP_S2S_TDAYS_M.sql`
      Verify: 数据库可用时模拟 source/HIE/权限/目标约束/日志失败和锁超时，预期目标无部分删除、GTT不串 session/run、锁被释放、错误包含定位信息；模拟 END 日志失败时验证业务提交状态和告警状态分离。无数据库时仅能检查异常结构和关闭/回滚/清理/释放调用的文本存在性。

- [ ] 11. 完成 Oracle 风格静态检查和禁止文件变更检查。
      对新过程执行纯文本检查：过程名、参数、`SESSION_USER`、Oracle 全大写、文件头块注释、中文行注释、CTE用途注释、字段逐行排列、逗号前置；10 组配置列、9类操作符、18个金额、6个天数、39列目标清单无遗漏；动态值不以字符串拼接进入 SQL；对象名有白名单/字典/`DBMS_ASSERT`三层校验；source暂存先于DELETE；异常路径含游标关闭、ROLLBACK、清理、ERROR日志、锁释放、原错重抛。静态检查不得只用 grep 作为唯一验证，使用 Python 脚本对关键清单和顺序做断言。
      同时确认现有 `CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` 的工作区改动不是本任务造成，禁止对其执行格式化、修复或回滚。
      Files: `CPM_SP_S2S_TDAYS_M.sql`；`CPM_SP_M2M_ARP_TOV_M_PHASE2.sql`（只读核对，禁止修改）。
      Verify: `python3 - <<'PY' ... PY`（由实现阶段编写临时内存检查或使用不落盘脚本）应输出所有断言通过；`git diff --check -- CPM_SP_S2S_TDAYS_M.sql` 无空白错误；`git diff --numstat -- CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` 与任务开始前状态一致，参考文件不得出现新增 diff。

- [ ] 12. 按数据库可用性出具最终验证结论和待确认清单。
      数据库可连接时按顺序执行：查询所有对象/DDL/直接 grant；编译过程；查询 `USER_ERRORS/ALL_ERRORS`；验证最小合法规则；覆盖10组和9类规则、IN/NOT IN 1000/1001、HIE两种示例、公司/事业部交集、同表读写、18个金额、6个公式、零分母、重复运行、异常回滚和并发锁。数据库不可连接时只执行文本级静态检查，并在结果中明确“数据库编译无法验证”，不声称权限、DDL、HIE对象、GTT、执行计划或业务结果已验证。
      最终待确认项至少包括：ARPA01与知识库ARPS02的对象身份差异；owner和完整DDL；配置 RULE_ID/有效期类型；逐 source 字段契约；HIE批准 owner及 `V_REF_ED_D_GRAN_CAL` 存在性；公司/事业部范围；目标独占性；类别/币种空值；YTD本月占用映射；零分母行为；日志失败可观测策略；DBMS_LOCK事务行为；共享 session 表重入策略。
      Files: `/Users/shiqingfeng/Documents/1_工作/01_海信/.agents/tasks/CPM_SP_S2S_TDAYS_M-plan.md`（本计划仅记录执行结果，不修改生产 SQL）；可选静态验证报告放 `.agents/tasks/`。
      Verify: 数据库可用时报告编译、`USER_ERRORS`、集成验证结果；数据库不可用时报告 Python 静态检查通过、Oracle 编译无法验证，并明确列出阻断项。

## 4. 目标字段与公式核对清单

### 4.1 目标业务字段顺序

固定按用户资料逐行覆盖以下字段：

```text
COD_SCENARIO, COD_PERIODO,
D_BG, COD_CONTO, COD_AZIENDA, D_GRAN_CAL, COD_CATEGORIA,
D_CHANNEL, D_ONOFFLINE, COD_DEST2, COD_DEST3, D_SALE_DEPT,
D_TOV_CHAN, D_CC_CUSTGRP, COD_VALUTA,
PLN_BEG_OCP_AMT, PLN_LM_OCP_AMT, PLN_END_OCP_AMT, PLN_YTD_OCP_AMT,
PLN_MTD_CSM_AMT, PLN_YTD_CSM_AMT,
ACT_BEG_OCP_AMT, ACT_LM_OCP_AMT, ACT_END_OCP_AMT, ACT_YTD_OCP_AMT,
ACT_MTD_CSM_AMT, ACT_YTD_CSM_AMT,
LY_BEG_OCP_AMT, LY_LM_OCP_AMT, LY_END_OCP_AMT, LY_YTD_OCP_AMT,
LY_MTD_CSM_AMT, LY_YTD_CSM_AMT,
PLN_MTD_TDAYS, PLN_YTD_TDAYS, ACT_MTD_TDAYS, ACT_YTD_TDAYS,
LY_MTD_TDAYS, LY_YTD_TDAYS
```

18 个金额必须逐列 `SUM(NVL(..., 0))`，不得遗漏、改名或按来源字段相似度自动映射。来源动态表不是目标表复制品，必须执行逐对象字段契约检查。

### 4.2 周转天数公式

最终按聚合后的金额计算：

```text
PLN_MTD_TDAYS = ((PLN_LM_OCP_AMT + PLN_END_OCP_AMT) / 2 * 30) / PLN_MTD_CSM_AMT
PLN_YTD_TDAYS = ((PLN_BEG_OCP_AMT / 2 + PLN_YTD_OCP_AMT - PLN_END_OCP_AMT / 2) * 30) / PLN_YTD_CSM_AMT
ACT_MTD_TDAYS = ((ACT_LM_OCP_AMT + ACT_END_OCP_AMT) / 2 * 30) / ACT_MTD_CSM_AMT
ACT_YTD_TDAYS = ((ACT_BEG_OCP_AMT / 2 + ACT_YTD_OCP_AMT - ACT_END_OCP_AMT / 2) * 30) / ACT_YTD_CSM_AMT
LY_MTD_TDAYS = ((LY_LM_OCP_AMT + LY_END_OCP_AMT) / 2 * 30) / LY_MTD_CSM_AMT
LY_YTD_TDAYS = ((LY_BEG_OCP_AMT / 2 + LY_YTD_OCP_AMT - LY_END_OCP_AMT / 2) * 30) / LY_YTD_CSM_AMT
```

代码必须使用 `CASE` 安全保护每个分母。分母为零的输出值在编码前必须由业务确认；计划中不把设计稿暂选的 `0` 视为最终事实。

## 5. 证据等级与差异保留

- **SQL 文本直接读出：** 参考过程的参数签名、SESSION 范围表、日志阶段、提交/异常结构；周转校验 SQL 的 ARPM02/IMOCC 当前校验口径。
- **知识库台账登记：** `AW_MR7_ARPS02_000001`、`TGK_FIMA_HISENSE.V_REF_AZIENDA`、部分 `V_REF_DEST2` 对象及 AR/AP 过程对象。
- **用户设计/字段资料要求：** 目标必须是 `AW_MR7_ARPA01_000001`、10组过滤字段、9类规则、HIE 前缀推导、18个金额、6个天数和 `SESSION_USER` 参数。
- **待确认/推导：** ARPA01 owner/DDL/独占性、TOVCAL 配置表实际结构、source逐表契约、`V_REF_ED_D_GRAN_CAL`、YTD本月占用映射、零分母、类别/币种空值、日志和锁事务行为。

实现者不得把知识库中登记的 ARPS02 静默当成 ARPA01，也不得以参考 ARP 过程的业务规则替代本引擎尚未确认的配置驱动规则。数据库不可连接时，最终结论必须明确为“文本级静态校验完成，数据库编译及运行验证无法完成”。
