# CPM_SP_S2S_TDAYS_M 可执行设计核对稿

## Summary

`CPM_SP_S2S_TDAYS_M` 是 Oracle DWM 层的 S2S 周转天数装载过程。过程接收 `P_SCENARIO`、`P_PERIODO`、`P_AZIENDA`、`P_BG` 和 `SESSION_USER`，按场景期间读取 `AW_RUL_TOVCAL_000001` 的有效配置；每条可执行规则从白名单内的动态 `SOURCE_TABLE` 读取数据，按 10 组固定筛选条件过滤，将目标配置维度补空值为 `ZZZZ`，先聚合 18 个金额，再计算 6 个周转天数，最后写入配置指定的动态 `TARGET_TABLE`。

选定技术方案是 Oracle PL/SQL + `DBMS_SQL` + 预创建的 `ON COMMIT PRESERVE ROWS` 全局临时表。动态 SQL 只允许承载经过数据字典和白名单校验的 owner、表名、列名以及固定筛选模板；参数、配置值、HIE/NODE 和 IN 值全部使用绑定变量。由于用户示例允许 `SOURCE_TABLE=TARGET_TABLE`，所有来源结果必须先写入会话暂存表，全部来源读取完成后才可以删除和装载目标表。

本轮已经读取并参考：

- `/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql`
- 同目录 `CPM_SP_M2M_ARP_INS_M_PHASE2.sql`、`CPM_SP_M2M_ARP_BD_M_PHASE2.sql`、`CPM_SP_D2M_ARP_M_PHASE2.sql` 及其他 `CPM` 文件检索结果
- `/Users/shiqingfeng/Documents/1_工作/01_海信/98_临时存/kbdata_副本.json`
- 上一轮审查清单及完整审查文档

本地文件检索没有找到 `AW_MR7_ARPA01_000001`、`AW_RUL_TOVCAL_000001`、目标过程或其真实 SQL/DDL；知识库也没有登记这两个用户指定对象。因而本设计不把 owner、主键、审计列、权限、GTT 是否已部署、目标独占性或 `V_REF_ED_D_GRAN_CAL` 的存在性推导为已确认事实。它们必须在目标代码生成前完成数据库门禁；数据库不可连接时只能完成静态设计核对。

本轮只修改本设计文档，不修改：

`/Users/shiqingfeng/Documents/1_工作/01_海信/01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`

## Functional Requirements

### 1. 参数、SESSION_USER 和运行范围

过程签名、参数顺序和参数含义锁定为：

```sql
CREATE OR REPLACE PROCEDURE CPM_SP_S2S_TDAYS_M(
    P_SCENARIO   IN VARCHAR2
  , P_PERIODO    IN VARCHAR2
  , P_AZIENDA   IN VARCHAR2
  , P_BG         IN VARCHAR2
  , SESSION_USER IN VARCHAR2
);
```

参数在任何目标 `DELETE` 前校验：

- `P_SCENARIO` 必填，按用户目标表 `COD_SCENARIO VARCHAR2(15)` 收紧为最多 15 个字符；格式为四位年份加大写字母、数字或下划线，例如 `2026ACT`。小写是否允许不自动转换，非法值直接报错。
- `P_PERIODO` 必填，只接受 1~2 位数字；用 `LPAD(..., 2, '0')` 后必须为 `01`~`12`。超过两位、非数字或月份不存在直接报错。
- `P_AZIENDA` 必填，最多 4000 个字符；支持逗号分隔的公司编码或 `ALL`。去首尾空格后禁止空 token、重复分隔符和混合 `ALL`/具体值。每个 token 的长度必须不超过已核验的公司列长度。
- `P_BG` 必填，最多 4000 个字符；支持逗号分隔的完整事业部编码或 `ALL`。本版只做完整编码匹配，不把 `BG001` 自动展开成 `BG001_BU001`，也不隐式套用 AR 过程的 `COSMAP/DWMCRS` 规则。
- `SESSION_USER` 必填；其最大长度以 `ZTAB_CPM_LOG.CREATEBY` 的真实 DDL 为准，部署门禁要求至少能容纳项目当前使用的用户长度。它只作为日志创建人；目标表没有被用户资料确认的审计列，因此不得擅自写入 `USERUPD`。

`V_YEARMONTH` 固定为 `SUBSTR(P_SCENARIO, 1, 4) || V_PERIODO`。当前参考过程使用 `SYS_CONTEXT('USERENV','SESSIONID')`、`SESSION_AZIENDA_LIST` 和 `SESSION_V_REF_AZIENDA`，本过程沿用该会话范围模式：

1. 取得 `V_SESSION_ID := SYS_CONTEXT('USERENV', 'SESSIONID')`。
2. 删除本 session 的旧 `SESSION_AZIENDA_LIST`、`SESSION_V_REF_AZIENDA` 行，并清理两个周转 GTT 的旧 `SESSION_ID` 数据。
3. 将批准 owner 下的 `V_REF_AZIENDA` 复制到 `SESSION_V_REF_AZIENDA`。
4. 参照现有过程，以 `HIE='10'` 为公司层级：`P_AZIENDA='ALL'` 选择全部 `ELEM`；具体 token 命中 `ELEM` 或 `NODE` 时选择对应 `ELEM`，写入 `SESSION_AZIENDA_LIST`。
5. 来源查询始终追加当前 `SESSION_ID` 的公司集合限制，不能因为配置目标是通配值而读出运行参数范围之外的公司。

### 2. 配置行的适用范围和越界删除防护

配置表读取固定使用经部署矩阵确认 owner 下的 `AW_RUL_TOVCAL_000001`。有效期条件为：

```sql
VALID_FR <= :V_YEARMONTH
AND NVL(VALID_TO, '999999') >= :V_YEARMONTH
```

首版支持契约为 `VALID_FR`、`VALID_TO` 均为字符型 `YYYYMM`；若真实 DDL 是 NUMBER、DATE 或其他类型，不能隐式转换，必须停止并修订契约。读取每行时先校验：6 位数字、月份 `01~12`、`VALID_FR <= VALID_TO`；`VALID_TO IS NULL` 才能按 `999999` 处理。异常配置在任何目标删除前报错，并在错误信息中包含规则标识、source、target 和有效期值。

配置的 `COD_AZIENDA` 必须参与可执行 scope 建立，规则如下：

- 空值、空格或 `ALL`：视为通配，只能展开为本次 `SESSION_AZIENDA_LIST` 中的公司，目标输出值为 `ZZZZ`。
- 具体值命中 `SESSION_AZIENDA_LIST.ELEM`：只允许本次已授权的该公司来源，目标输出为该配置值。
- 具体值未命中 `ELEM`，但在本 session 的 `SESSION_V_REF_AZIENDA` 中作为 `HIE='10'` 的 `NODE` 命中：展开为该节点下同时属于当前 `SESSION_AZIENDA_LIST` 的 `ELEM`，目标输出仍为配置值；是否允许节点值作为目标公司编码需在业务确认后启用，未确认时部署门禁可收紧为只允许 `ELEM`。
- 具体值既不命中当前 session 的 `ELEM`，也不命中允许的公司 `NODE`：该配置行不生成 scope，也不执行来源 SQL，更不允许删除任何目标行。这样运行 `P_AZIENDA='2600'` 时不会因存在 `COD_AZIENDA='6100'` 的有效配置而删除 6100 数据。

配置的 `D_BG` 适用性规则为：空值、空格或 `ALL` 适用于本次 `P_BG` 范围并输出 `ZZZZ`；具体值只有完整命中 `P_BG='ALL'` 或其逗号 token 时才适用，输出为该值。配置中的 `D_BG` 不自动变成来源表过滤条件；如需按来源事业部取数，必须将来源字段和规则明确写入 10 组过滤字段。

其他 9 个目标配置维度 `D_GRAN_CAL`、`COD_CONTO`、`D_CHANNEL`、`D_ONOFFLINE`、`COD_DEST2`、`COD_DEST3`、`D_SALE_DEPT`、`D_TOV_CHAN`、`D_CC_CUSTGRP` 的空值、空格或 `ALL` 统一输出 `ZZZZ`，具体值使用 `TRIM` 后的原值。该规范化表达式必须在暂存、最终聚合、目标删除 scope 和 INSERT 中完全一致。

建立 `SESSION_TOVCAL_SCOPE` 时只写“配置目标公司与运行公司范围相交”的规则。有效配置全部被过滤后若无 scope，过程记录“无适用配置”，不删除、不插入并正常结束；配置语法错误、有效期错误或对象门禁错误则失败并保持目标不变。

### 3. 动态对象、owner、类型和权限契约

配置中的 `SOURCE_TABLE` 和 `TARGET_TABLE` 不能自由指定 owner 或任意 SQL 对象。发布版本必须有固定部署矩阵，至少包含：

| 对象 | 必须冻结的内容 | 当前证据状态 |
|---|---|---|
| 过程 owner | owner、`AUTHID DEFINER`、直接授权 | 未找到 DDL，待 DBA 提供 |
| 配置表 | owner、TABLE 类型、完整列和 RULE_ID | 未找到 SQL/DDL |
| 目标表 | owner、TABLE 类型、39 个业务列、非空/默认/索引、独占性 | 用户提供业务字段，真实 DDL 未找到 |
| source 白名单 | 每个 `OWNER.TABLE/VIEW`、对象类型、来源列契约 | 未找到目标过程和 source DDL |
| target 白名单 | `AW_MR7_ARPA01_000001` 的 canonical owner、TABLE 类型 | 未找到 SQL/DDL |
| HIE 对象 | 每个派生视图 owner、对象类型、`ELEM/HIE/NODE` 类型 | `TGK_FIMA_HISENSE.V_REF_DEST2` 仅有知识库登记；`V_REF_ED_D_GRAN_CAL` 未登记 |
| GTT | owner、完整列、索引、`ON COMMIT` | 未找到 DDL，按本文设计预创建 |
| 日志 | `ZTAB_CPM_LOG` owner、列长度和权限 | 参考过程直接使用，真实 DDL 未找到 |

所有 owner 必须是发布矩阵中的固定值。配置中的对象若为单名，按固定 owner 补齐；若带 owner，必须与固定 owner 和白名单完全一致。每个对象执行以下校验，失败属于致命配置错误且发生在目标 `DELETE` 前：

1. `TRIM` 后转大写；只接受一个简单未加引号标识符或 `OWNER.TABLE`，正则为 `[A-Z][A-Z0-9_$#]*`；拒绝引号、空格、注释、分号、`@`、换行和多个点。
2. 调用 `DBMS_ASSERT.SIMPLE_SQL_NAME` 和 `DBMS_ASSERT.SQL_OBJECT_NAME`；`DBMS_ASSERT` 只做语法校验，不能替代白名单。
3. 查询 `ALL_OBJECTS`、`ALL_TABLES`、`ALL_TAB_COLUMNS`，核验 owner、对象类型、列名、数据类型、字符长度、数值精度和权限。
4. source 必须有 `COD_SCENARIO`、`COD_PERIODO`、`COD_AZIENDA`、`COD_CATEGORIA`、`COD_VALUTA` 和 18 个金额列；金额列首版只接受 `NUMBER`，过滤列只接受 `CHAR/VARCHAR2/VARCHAR`，禁止依赖 NLS 的隐式数字/日期转换。
5. target 必须具有用户资料列出的 39 个业务列。用户没有确认 `OID`、`PROVENIENZA`、`DATEUPD`、`USERUPD`，所以固定 INSERT 不包含它们；若真实 target 有额外 `NOT NULL` 且无默认值列，门禁失败，必须先补目标契约或补正式 INSERT 设计，不能照搬同类表。
6. 过程 owner 必须对 source、target、配置、HIE 对象和 GTT 具有直接授权，并对 `DBMS_SQL`、`DBMS_ASSERT`、`DBMS_LOCK` 具有直接执行权限；不依赖角色授权。

### 4. 十组取数限制和动态 SQL

必须处理全部 10 组：

`COLUMN_NAME_1~10`、`COLUMN_FILTER_1~10`、`COLUMN_VALUE_1~10`。

每组三列全部为空表示不加条件；只空其中一列是配置错误。列名 `TRIM/UPPER` 后必须通过简单列名校验和来源字典校验。只允许以下 9 个操作符：

| 规则 | 固定 SQL 形态 | 值校验与绑定 |
|---|---|---|
| `=` | `AND (S.COL = :B...)` | 一个非空 token |
| `<>` | `AND (S.COL <> :B...)` | 一个非空 token |
| `IN` | `AND (S.COL IN (:B1,...,:B1000) OR S.COL IN (...))` | 按逗号拆分，空 token/首尾逗号/连续逗号拒绝，1000 项分块 |
| `LIKE` | `AND (S.COL LIKE :B...)` | 绑定完整模式，不自动拼 `%` |
| `NOT LIKE` | `AND (S.COL NOT LIKE :B...)` | 绑定完整模式 |
| `HIE` | `AND (S.COL IN (SELECT ELEM FROM HIE_VIEW WHERE HIE=:H AND NODE=:N))` | 必须恰好一个 `|`，两段非空 |
| `NOT IN` | `AND (S.COL NOT IN (:B1,...) AND S.COL NOT IN (...))` | 与 IN 相同，分块之间必须是 `AND` |
| `IS NULL` | `AND (S.COL IS NULL)` | value 必须为空 |
| `IS NOT NULL` | `AND (S.COL IS NOT NULL)` | value 必须为空 |

过滤组永远用 `AND (...)` 包住，避免多个规则组的优先级歧义。每条规则的绑定名由稳定的规则标识和组号生成，例如 `B_R123_G02_I1001`；绑定顺序严格按动态 SQL 文本从左到右调用 `DBMS_SQL.BIND_VARIABLE`。值永远不拼接进 SQL。

`IN`/`NOT IN` 的分块静态样例为：

```sql
-- 1001 个 IN 值
AND (
       S.COD_DEST2 IN (:B_R1_G02_I0001, ..., :B_R1_G02_I1000)
    OR S.COD_DEST2 IN (:B_R1_G02_I1001)
)

-- 1001 个 NOT IN 值
AND (
       S.COD_DEST2 NOT IN (:B_R1_G02_I0001, ..., :B_R1_G02_I1000)
   AND S.COD_DEST2 NOT IN (:B_R1_G02_I1001)
)
```

重复分隔符、首尾分隔符和空 token 失败；重复但非空的值可以去重后绑定，也可以保留，二者结果相同，但实现必须固定一种行为并在单测中覆盖。Oracle `NOT IN` 的 NULL 语义不改写；若业务需要 NULL 命中，必须另配 `IS NULL`。

HIE 规则按用户给出的字段前缀推导，但最终只能使用白名单映射矩阵：

| 来源列 | 视图名推导 | 示例 |
|---|---|---|
| `COD_` 开头 | 去掉 `COD_` 后拼 `V_REF_` | `COD_DEST2 -> V_REF_DEST2` |
| `D_` 开头 | 拼 `V_REF_ED_` 和完整列名 | `D_GRAN_CAL -> V_REF_ED_D_GRAN_CAL` |
| 其他前缀 | 拒绝 | 不允许猜测 |

`COLUMN_VALUE_n='01|030'` 只拆成 `HIE='01'`、`NODE='030'`，生成：

```sql
S.COD_DEST2 IN (
    SELECT ELEM
      FROM <APPROVED_OWNER>.V_REF_DEST2
     WHERE HIE = :H_R1_G02
       AND NODE = :N_R1_G02
)
```

HIE 视图的 `ELEM/HIE/NODE` 首版均要求字符类型，`ELEM` 必须与来源过滤列字符类型兼容；否则失败，不在 SQL 中拼转换函数。视图缺失、列缺失、类型不兼容或权限不足在目标删除前失败。知识库只证明 `TGK_FIMA_HISENSE.V_REF_DEST2` 等多个同名对象被登记，不能证明本过程的批准 owner；`V_REF_ED_D_GRAN_CAL` 未在知识库中登记，必须通过真实数据库确认。

### 5. 固定 SQL 形态和动态表名边界

每条规则使用 `DBMS_SQL` 执行固定模板。动态部分只有：

- 已白名单校验的 canonical source object；
- 已白名单校验的 HIE object；
- 已来源字典校验的过滤列名；
- 固定的 10 组运算符片段。

目标表名不直接来自配置字符串，而是来自已确认的 target 白名单映射。动态 source 聚合的形态为：

```sql
INSERT INTO <FIXED_OWNER>.SESSION_TOVCAL_RESULT(
    SESSION_ID, RUN_ID, TARGET_OWNER, TARGET_TABLE
  , COD_SCENARIO, COD_PERIODO
  , D_BG, COD_CONTO, COD_AZIENDA, D_GRAN_CAL
  , COD_CATEGORIA, D_CHANNEL, D_ONOFFLINE, COD_DEST2, COD_DEST3
  , D_SALE_DEPT, D_TOV_CHAN, D_CC_CUSTGRP, COD_VALUTA
  , PLN_BEG_OCP_AMT, PLN_LM_OCP_AMT, PLN_END_OCP_AMT, PLN_YTD_OCP_AMT
  , PLN_MTD_CSM_AMT, PLN_YTD_CSM_AMT
  , ACT_BEG_OCP_AMT, ACT_LM_OCP_AMT, ACT_END_OCP_AMT, ACT_YTD_OCP_AMT
  , ACT_MTD_CSM_AMT, ACT_YTD_CSM_AMT
  , LY_BEG_OCP_AMT, LY_LM_OCP_AMT, LY_END_OCP_AMT, LY_YTD_OCP_AMT
  , LY_MTD_CSM_AMT, LY_YTD_CSM_AMT
)
SELECT :SESSION_ID, :RUN_ID, :TARGET_OWNER, :TARGET_TABLE
     , :P_SCENARIO, :P_PERIODO
     , :D_BG, :COD_CONTO, :COD_AZIENDA, :D_GRAN_CAL
     , CASE WHEN TRIM(S.COD_CATEGORIA) IS NULL THEN 'ZZZZ'
            ELSE TRIM(S.COD_CATEGORIA) END
     , :D_CHANNEL, :D_ONOFFLINE, :COD_DEST2, :COD_DEST3
     , :D_SALE_DEPT, :D_TOV_CHAN, :D_CC_CUSTGRP
     , CASE WHEN TRIM(S.COD_VALUTA) IS NULL THEN 'ZZZZ'
            ELSE TRIM(S.COD_VALUTA) END
     , SUM(NVL(S.PLN_BEG_OCP_AMT, 0))
     , SUM(NVL(S.PLN_LM_OCP_AMT, 0))
     , SUM(NVL(S.PLN_END_OCP_AMT, 0))
     , SUM(NVL(S.PLN_YTD_OCP_AMT, 0))
     , SUM(NVL(S.PLN_MTD_CSM_AMT, 0))
     , SUM(NVL(S.PLN_YTD_CSM_AMT, 0))
     , SUM(NVL(S.ACT_BEG_OCP_AMT, 0))
     , SUM(NVL(S.ACT_LM_OCP_AMT, 0))
     , SUM(NVL(S.ACT_END_OCP_AMT, 0))
     , SUM(NVL(S.ACT_YTD_OCP_AMT, 0))
     , SUM(NVL(S.ACT_MTD_CSM_AMT, 0))
     , SUM(NVL(S.ACT_YTD_CSM_AMT, 0))
     , SUM(NVL(S.LY_BEG_OCP_AMT, 0))
     , SUM(NVL(S.LY_LM_OCP_AMT, 0))
     , SUM(NVL(S.LY_END_OCP_AMT, 0))
     , SUM(NVL(S.LY_YTD_OCP_AMT, 0))
     , SUM(NVL(S.LY_MTD_CSM_AMT, 0))
     , SUM(NVL(S.LY_YTD_CSM_AMT, 0))
  FROM <CANONICAL_SOURCE> S
 WHERE S.COD_SCENARIO = :P_SCENARIO
   AND S.COD_PERIODO = :P_PERIODO
   AND TRIM(S.COD_AZIENDA) IN (
         SELECT TRIM(ELEM)
           FROM SESSION_AZIENDA_LIST
          WHERE SESSION_ID = :SESSION_ID
   )
   AND <CONFIG_COMPANY_INTERSECTION_PREDICATE>
   AND <10 组 AND (...) 条件>
 GROUP BY CASE WHEN TRIM(S.COD_CATEGORIA) IS NULL THEN 'ZZZZ'
              ELSE TRIM(S.COD_CATEGORIA) END
        , CASE WHEN TRIM(S.COD_VALUTA) IS NULL THEN 'ZZZZ'
              ELSE TRIM(S.COD_VALUTA) END;
```

`CONFIG_COMPANY_INTERSECTION_PREDICATE` 对通配配置使用当前 session 公司集合，对具体 ELEM 使用绑定等值条件，对允许的 NODE 使用 `SESSION_V_REF_AZIENDA` 的 `HIE='10' AND NODE=:CONFIG_AZIENDA` 展开，同时再次与 `SESSION_AZIENDA_LIST` 相交。目标配置维度不是来源过滤条件；只有运行安全的公司范围和配置明确写入的 10 组过滤条件可以限制来源。

配置规则按 `RULE_ID` 固定排序。有效规则在规范化的 `(TARGET_OWNER, TARGET_TABLE, SOURCE_OWNER, SOURCE_TABLE, 场景, 期间, 11 个目标维度)` 上建立冲突检查：同一 source/target/output scope 的多条规则统一拒绝，避免同一来源重复加总；不同 source 到同一 target scope 允许在最终 GTT 聚合阶段汇总。若配置表没有稳定 `RULE_ID`，部署门禁失败，不通过 `ROWID` 或查询顺序猜测。

### 6. 18 个金额、聚合粒度和 6 个周转天数

18 个金额必须完整处理，顺序固定为：

```text
PLN_BEG_OCP_AMT, PLN_LM_OCP_AMT, PLN_END_OCP_AMT, PLN_YTD_OCP_AMT,
PLN_MTD_CSM_AMT, PLN_YTD_CSM_AMT,
ACT_BEG_OCP_AMT, ACT_LM_OCP_AMT, ACT_END_OCP_AMT, ACT_YTD_OCP_AMT,
ACT_MTD_CSM_AMT, ACT_YTD_CSM_AMT,
LY_BEG_OCP_AMT, LY_LM_OCP_AMT, LY_END_OCP_AMT, LY_YTD_OCP_AMT,
LY_MTD_CSM_AMT, LY_YTD_CSM_AMT
```

来源阶段使用 `SUM(NVL(source_amount, 0))`。最终阶段按：

`TARGET_OWNER, TARGET_TABLE, COD_SCENARIO, COD_PERIODO, 11 个目标维度, COD_CATEGORIA, COD_VALUTA`

聚合 18 个金额，然后只在外层计算周转天数。

用户公式写的是“本月占用金额”，但目标字段资料没有 `*_MTD_OCP_AMT`，只有 `*_END_OCP_AMT`。因此本版的唯一字段映射假设是：计划、实际、同期的“本月占用金额”均使用相应 `*_END_OCP_AMT`。该映射是由现有字段集合推导的待确认假设，不宣称已经得到业务确认。

选定的公式 SQL 形态如下；为安全处理零分母，本设计暂选分母为零输出 `0`，而不是抛出 `ORA-01476`。如果业务确认零分母应为 `NULL`，只需在固定外层公式替换为 `NULL`，不得让实现者自行决定。

```sql
CASE WHEN PLN_MTD_CSM_AMT = 0 THEN 0
     ELSE (PLN_LM_OCP_AMT + PLN_END_OCP_AMT) / 2 * 30
          / PLN_MTD_CSM_AMT END AS PLN_MTD_TDAYS

CASE WHEN PLN_YTD_CSM_AMT = 0 THEN 0
     ELSE (PLN_BEG_OCP_AMT / 2 + PLN_YTD_OCP_AMT
           - PLN_END_OCP_AMT / 2) * 30
          / PLN_YTD_CSM_AMT END AS PLN_YTD_TDAYS

CASE WHEN ACT_MTD_CSM_AMT = 0 THEN 0
     ELSE (ACT_LM_OCP_AMT + ACT_END_OCP_AMT) / 2 * 30
          / ACT_MTD_CSM_AMT END AS ACT_MTD_TDAYS

CASE WHEN ACT_YTD_CSM_AMT = 0 THEN 0
     ELSE (ACT_BEG_OCP_AMT / 2 + ACT_YTD_OCP_AMT
           - ACT_END_OCP_AMT / 2) * 30
          / ACT_YTD_CSM_AMT END AS ACT_YTD_TDAYS

CASE WHEN LY_MTD_CSM_AMT = 0 THEN 0
     ELSE (LY_LM_OCP_AMT + LY_END_OCP_AMT) / 2 * 30
          / LY_MTD_CSM_AMT END AS LY_MTD_TDAYS

CASE WHEN LY_YTD_CSM_AMT = 0 THEN 0
     ELSE (LY_BEG_OCP_AMT / 2 + LY_YTD_OCP_AMT
           - LY_END_OCP_AMT / 2) * 30
          / LY_YTD_CSM_AMT END AS LY_YTD_TDAYS
```

金额为负时按来源值计算，不擅自过滤。金额字段若真实来源精度不兼容 `NUMBER(27,9)`，在来源门禁失败而不是静默截断。

### 7. 目标字段、空值和删除边界

目标业务 INSERT 只按用户提供资料固定以下 39 列，不自行增加同类表常见审计列：

```text
COD_SCENARIO, COD_PERIODO,
D_BG, COD_CONTO, COD_AZIENDA, D_GRAN_CAL, COD_CATEGORIA,
D_CHANNEL, D_ONOFFLINE, COD_DEST2, COD_DEST3, D_SALE_DEPT,
D_TOV_CHAN, D_CC_CUSTGRP, COD_VALUTA,
18 个金额字段,
PLN_MTD_TDAYS, PLN_YTD_TDAYS, ACT_MTD_TDAYS, ACT_YTD_TDAYS,
LY_MTD_TDAYS, LY_YTD_TDAYS
```

`COD_CATEGORIA` 和 `COD_VALUTA` 是来源直接对应字段；来源为空或空格时也统一输出 `ZZZZ`，以满足目标维度空值补 `ZZZZ`，不改变非空来源值。

目标表必须在部署资料中被确认由本过程独占，或者目标 DDL 必须提供稳定的过程归属键。当前用户资料没有归属列，也没有台账证明独占性，因此在独占性未确认前禁止生成无条件删除代码。若确认独占，删除按 `SESSION_TOVCAL_SCOPE` 逐 scope 执行：

```sql
DELETE FROM <CANONICAL_TARGET> D
 WHERE D.COD_SCENARIO = :P_SCENARIO
   AND D.COD_PERIODO = :P_PERIODO
   AND NORMALIZE(D.D_BG) = :SCOPE_D_BG
   AND NORMALIZE(D.COD_CONTO) = :SCOPE_COD_CONTO
   AND NORMALIZE(D.COD_AZIENDA) = :SCOPE_COD_AZIENDA
   AND NORMALIZE(D.D_GRAN_CAL) = :SCOPE_D_GRAN_CAL
   AND NORMALIZE(D.D_CHANNEL) = :SCOPE_D_CHANNEL
   AND NORMALIZE(D.D_ONOFFLINE) = :SCOPE_D_ONOFFLINE
   AND NORMALIZE(D.COD_DEST2) = :SCOPE_COD_DEST2
   AND NORMALIZE(D.COD_DEST3) = :SCOPE_COD_DEST3
   AND NORMALIZE(D.D_SALE_DEPT) = :SCOPE_D_SALE_DEPT
   AND NORMALIZE(D.D_TOV_CHAN) = :SCOPE_D_TOV_CHAN
   AND NORMALIZE(D.D_CC_CUSTGRP) = :SCOPE_D_CC_CUSTGRP;
```

`NORMALIZE` 的实际 SQL 表达式为 `CASE WHEN TRIM(COL) IS NULL OR UPPER(TRIM(COL))='ALL' THEN 'ZZZZ' ELSE TRIM(COL) END`。目标空值、空格和旧数据中的 `ALL` 仅在规范化后等价于 `ZZZZ`；类别和币种不在 scope 中，因此一个 scope 删除该 scope 下全部类别和币种。无来源行仍按已建立的 scope 删除；无适用配置不建立 scope，绝不删除。

所有 source SQL 完成并写入 GTT 后才执行删除。因而 `SOURCE_TABLE=TARGET_TABLE` 时，来源读取不会被当前批次删除影响。目标删除、最终聚合和 INSERT 在同一主事务中执行，成功时最后提交，重复执行不翻倍。

### 8. 并发锁、GTT 和事务边界

采用保守的目标级锁，而不是按原始 `P_AZIENDA/P_BG` 加锁。原因是通配配置可能让不同入参实际命中同一目标表、场景和期间；按入参锁会出现并发互相覆盖。

锁粒度固定为每个 canonical `TARGET_OWNER.TARGET_TABLE + V_SCENARIO + V_PERIODO`，不包含原始输入参数，也不依赖来源行数量；这是比按 11 维逐 scope 加锁更容易证明安全的保守实现。多个目标按 canonical target、场景、期间排序后依次锁定。锁名算法固定为：对规范化键使用 `DBMS_UTILITY.GET_HASH_VALUE`，范围固定为 `0..1073741823`，生成 `CPM_SP_S2S_TDAYS_M_` 加十进制哈希值后调用 `DBMS_LOCK.ALLOCATE_UNIQUE`。哈希碰撞只会造成额外串行，不会造成错误并发放行；实际诊断同时记录原始 canonical 键。`DBMS_LOCK.REQUEST` 使用 `timeout=0`、`release_on_commit=FALSE`。

返回码固定处理：`0` 成功；`1` 超时；`2` 死锁；`3` 参数错误；`4` 当前 session 已持有；`5` 非法句柄。`1/2` 转为“目标范围正在执行”的业务错误，`3/5` 转为部署/实现错误，`4` 视为本次已持有并继续。异常和正常路径都调用 `DBMS_LOCK.RELEASE`；释放返回非零只记录，不覆盖主错误。

部署要求预创建两个 GTT，owner 由部署矩阵冻结，过程使用静态表名：

1. `SESSION_TOVCAL_RESULT`：`ON COMMIT PRESERVE ROWS`；包括 `SESSION_ID NUMBER`、`RUN_ID VARCHAR2(32)`、`TARGET_OWNER VARCHAR2(128)`、`TARGET_TABLE VARCHAR2(128)`、场景期间、11 个目标维度、`COD_CATEGORIA`、`COD_VALUTA` 和 18 个 `NUMBER(27,9)` 金额。索引至少为 `(SESSION_ID, RUN_ID, TARGET_OWNER, TARGET_TABLE)` 和最终聚合键。
2. `SESSION_TOVCAL_SCOPE`：`ON COMMIT PRESERVE ROWS`；包括 `SESSION_ID`、`RUN_ID`、canonical target、场景期间和 11 个规范化目标维度。唯一索引为 `(SESSION_ID, RUN_ID, TARGET_OWNER, TARGET_TABLE, COD_SCENARIO, COD_PERIODO, 11 个维度)`，不把 RULE_ID 放入唯一键，以允许不同 source 汇入同一目标 scope。

`RUN_ID` 使用 `RAWTOHEX(SYS_GUID())`，所有 GTT 查询都带 `SESSION_ID + RUN_ID`。不能因为日志自治提交而使用 `ON COMMIT DELETE ROWS`。

事务所有权明确为：过程独占其自身 DML 事务，调用方不得将未提交业务 DML 与本过程混合。正常路径不在目标删除/装载中间提交；全部成功后删除 session 范围数据并提交一次。异常路径顺序固定为：

1. 保存原始 `SQLCODE`、`SQLERRM`、规则标识、canonical source/target 和当前阶段。
2. 关闭所有打开的 `DBMS_SQL` 游标。
3. `ROLLBACK`，撤销目标删除/装载。
4. 在回滚后显式删除本 session 的两个 GTT 和 `SESSION_AZIENDA_LIST/SESSION_V_REF_AZIENDA`，单独 `COMMIT` 清理事务；清理失败不得覆盖原错误。
5. 调用自治事务 `LOG_EVENT` 写 ERROR 日志。
6. 释放全部已取得锁，释放失败不得覆盖原错误。
7. 用 `RAISE` 重新抛出原始异常。

正常路径的 `END 执行完成` 日志必须在主事务成功 `COMMIT` 之后写入；如果 END 日志失败，目标已经成功提交，过程返回成功并将日志失败作为可观测告警，不把已完成业务误报为失败。

### 9. 日志和错误处理

参考过程直接写入 `ZTAB_CPM_LOG(CPM, STEP, EXECTIME, CREATEBY, COD_SCENARIO, COD_PERIODO, COD_AZIENDA)`，异常额外写 `REMARK`。本过程采用自治 `LOG_EVENT`，但不假设日志列长度：部署门禁要求 `CPM` 至少 30、`STEP` 至少 100、`REMARK` 至少 4000、`CREATEBY` 至少 255、`COD_SCENARIO` 至少 15、`COD_PERIODO` 至少 2、`COD_AZIENDA` 至少 4000，`EXECTIME` 为 DATE 或兼容类型；否则先修订日志契约。

至少记录以下阶段：

- `BEGIN 开始执行`
- `参数和配置校验完成`
- `来源暂存完成`，包含规则标识、来源/目标 canonical 名和暂存行数
- `目标范围删除完成`
- `目标表装载完成`
- `END 执行完成`
- `ERROR 执行报错`，包含阶段、规则标识、source/target、`SQLCODE:SQLERRM`

`LOG_EVENT` 自治事务写入后立即提交；日志本身失败时回滚日志事务并设置内部告警，不覆盖业务原异常，也不在业务成功路径把日志故障升级为目标回滚。日志失败不能阻断主流程，但必须返回监控可见的计数/告警；若项目要求日志为强制审计，则需在部署前把此策略改为“日志失败即失败”，不能由实现者临时决定。

## Non-Functional Requirements

### 安全和边界

- 动态对象只来自固定 owner 和 source/target/HIE 白名单；`DBMS_ASSERT`、数据字典和直接授权三者缺一不可。
- 所有配置值、输入参数、HIE/NODE、IN/LIKE token 和 session/run 标识绑定；不能拼接值或任意表达式。
- 配置不能注入函数、JOIN、子查询、排序、额外操作符或 SQL 片段。

### 一致性、可重跑和并发

- 先读取并暂存全部来源，再删除和装载目标，保证同表 source/target 隔离。
- scope 删除包含场景、期间和完整 11 个目标维度；无来源 scope 仍能清理旧结果，无适用配置不删除。
- 主事务只在成功末尾提交，失败回滚后再独立清理会话数据。
- 目标级锁使用最终 canonical target、场景、期间，不使用原始输入参数，防止通配 scope 竞争失效。

### 可测试性和性能

- 规则解析器、对象名校验、HIE 名称推导、token 拆分和公式可以做 PL/SQL 单元测试。
- `DBMS_SQL` parse/bind/execute、真实权限、GTT、锁、目标删除、同表读取和结果字段必须做 Oracle 集成测试。
- 来源过滤列、场景期间、公司和目标 scope 的索引由 DBA 按真实 DDL 核验；本过程不通过隐式转换换取索引命中。
- 数据库不可连接时只能报告静态核对，不得声称已编译、已验证权限或已验证数据结果。

## Implementation Steps

1. 获取并冻结目标表、配置表、日志表、HIE 视图、source 白名单、target 白名单、过程 owner 和所有直接授权的真实 DDL。确认 `VALID_FR/VALID_TO`、规则主键、目标非空列和目标独占性。
2. 若尚未存在，按本文列契约创建两个 `ON COMMIT PRESERVE ROWS` GTT 及索引；确认 GTT owner、权限和统计信息策略。
3. 按 Oracle DWM 规范创建过程头、参数、局部变量、session/run 标识、锁句柄、DBMS_SQL 游标和原始错误变量；过程使用 `AUTHID DEFINER`，前提是部署矩阵确认。
4. 实现参数、月份、配置有效期、规则标识、owner/对象/列/类型/权限和配置重叠校验，全部在目标 DELETE 前完成。
5. 实现 `SESSION_AZIENDA_LIST` 的 ELEM/NODE/ALL 解析，以及配置 `COD_AZIENDA` 与当前 session 公司的交集过滤；建立规范化 `SESSION_TOVCAL_SCOPE`。
6. 按 canonical target/scenario/period 排序获取目标级 DBMS_LOCK；锁失败立即退出，不进行目标变更。
7. 实现 10 组过滤解析器、九类规则、IN/NOT IN 1000 项分块、唯一 bind 名、HIE 视图固定映射和 DBMS_SQL 绑定执行。
8. 对每条有效规则执行固定金额聚合 SQL，写入 `SESSION_TOVCAL_RESULT`；source 与 target 相同的情况下此时仍未修改目标。
9. 按 scope 删除独占目标表的当前场景期间和 11 维数据；从 result GTT 再按目标键聚合 18 个金额，固定计算 6 个天数，使用 39 列业务 INSERT 写入目标。
10. 成功后提交主事务，再写 END 日志；异常按“保存错误、关闭游标、回滚、清理并提交清理、ERROR 日志、释放锁、重抛”执行。
11. 静态检查通过且数据库门禁闭合后，才将实现代码写入目标 SQL 文件。本轮不写目标过程文件。

## SQL/DDL 静态校验清单

- [ ] 过程名称和 5 个参数名称、顺序、含义一致；`SESSION_USER` 是入参，不误用 `SYS_CONTEXT('USERENV','SESSION_USER')` 替代。
- [ ] `P_SCENARIO` 按目标 `VARCHAR2(15)` 校验；`P_PERIODO` 规范化为 `01~12`；参数错误发生在目标变更前。
- [ ] `P_AZIENDA` 的 ELEM/NODE/ALL 逻辑与 `SESSION_AZIENDA_LIST` 一致；具体配置公司必须与当前 session 相交，未相交配置不能建立 scope。
- [ ] `P_BG` 和配置 `D_BG` 只按完整 token 匹配，不发生未确认的层级展开或 AR 专用规则继承。
- [ ] `VALID_FR/VALID_TO` 类型和 `YYYYMM` 格式门禁已闭合，起止顺序和月份合法性已验证。
- [ ] 配置存在稳定 RULE_ID；同一 source/target/output scope 重叠规则在 DELETE 前拒绝。
- [ ] owner、对象类型、source/target/HIE 白名单、直接 grants 和 `ALL_TAB_COLUMNS` 契约全部验证。
- [ ] target 的 39 个用户业务列形成闭合 INSERT；额外非空无默认列会阻断，不假设 OID/PROVENIENZA/DATEUPD/USERUPD。
- [ ] HIE 映射明确覆盖 `COD_DEST2 -> V_REF_DEST2` 和 `D_GRAN_CAL -> V_REF_ED_D_GRAN_CAL`，并核验 owner、ELEM/HIE/NODE 字符类型和权限。
- [ ] 两个 GTT 的完整列、索引、owner、`ON COMMIT PRESERVE ROWS` 和 `RUN_ID` 已冻结。
- [ ] 10 组字段全部逐组处理；部分空组、非法列、非法操作符失败。
- [ ] 九类操作符均有固定 SQL 形态；IN/NOT IN 覆盖空 token、1000、1001 项和 bind 顺序。
- [ ] HIE 只允许一个 `|` 和两个非空 token；所有 HIE/NODE 使用绑定变量。
- [ ] 18 个金额全部 `SUM(NVL(...,0))`，最终以目标维度、类别和币种聚合后再计算天数。
- [ ] 三个 YTD 公式的“本月占用”统一映射为 `*_END_OCP_AMT`，该映射已取得业务确认或明确标为发布阻断假设。
- [ ] 六个分母为零时按已确认策略输出 0 或 NULL，任何情况下不抛除零异常。
- [ ] 目标配置维度、来源类别、来源币种空值统一为 `ZZZZ`，删除和 INSERT 使用同一规范化表达式。
- [ ] 删除 scope 包含场景、期间、完整 11 维度，类别和币种不在 scope 中；无来源和无配置边界正确。
- [ ] source 全部暂存后才删除目标；`SOURCE_TABLE=TARGET_TABLE` 同表路径不丢数。
- [ ] 锁按最终 canonical target/scenario/period 获取并排序，不按原始 P_AZIENDA/P_BG；返回码、超时和释放规则固定。
- [ ] 日志字段长度、自治提交、END 提交后语义和日志故障策略已冻结。
- [ ] 正常和异常路径均关闭 DBMS_SQL、清理 session/GTT、释放锁；原始异常不被清理/日志/释放错误覆盖。
- [ ] 文件头、Oracle 大写、中文行注释、逗号前置字段风格符合项目 SQL 规范。

## 验证方案

### 静态验证

当前工作区未提供 Oracle 连接，也未找到目标/配置/HIE/GTT 的真实 DDL，因此本轮只能完成：过程签名和参考 SQL 风格核对、规则和公式设计、动态 SQL 边界设计、审查意见修订以及知识库差异记录。不能执行编译、`DBMS_SQL.PARSE`、`USER_ERRORS`、权限、执行计划、并发或真实结果验证。

### 数据库可连接后的验证顺序

1. 查询 `ALL_OBJECTS`、`ALL_TABLES`、`ALL_TAB_COLUMNS`、约束、索引和直接授权，核验部署矩阵中所有 owner、对象类型、列长度、精度、非空/默认值、GTT `ON COMMIT` 和日志字段长度。
2. 确认目标 39 列与真实 DDL 一致；确认没有未处理的非空无默认列；取得目标独占证明。没有独占证明时阻断目标 DELETE。
3. 核验配置表的规则主键、有效期真实类型、30 个过滤配置列长度和 `TARGET_TABLE/SOURCE_TABLE` 值；插入一个最小合法规则作为 smoke test。
4. 编译过程并查询 `USER_ERRORS/ALL_ERRORS`；用 `=` 规则验证最小来源和最小目标写入。
5. 分别覆盖 10 个组位和九类规则；验证 1000/1001 项 IN/NOT IN、空 token、重复分隔符、LIKE 完整模式和 HIE 多分隔符拒绝。
6. 使用 `COD_DEST2 + 01|030` 验证批准的 `V_REF_DEST2`；使用 `D_GRAN_CAL + 01|030` 验证批准的 `V_REF_ED_D_GRAN_CAL`；核对只返回对应 `HIE/NODE` 的 `ELEM`。
7. 用 `P_AZIENDA='2600'`、配置 `COD_AZIENDA='6100'` 验证不建立 scope、不删除 6100；用 `ALL`、ELEM、NODE 分别验证当前 session 交集。
8. 构造多行来源，逐列核对 18 个金额的 SUM；六个耗用分母分别为零时验证已确认的 0/NULL 结果且无 `ORA-01476`；逐项核对六个公式。
9. 验证目标维度空值、空格、ALL、ZZZZ 的统一规范化；验证无来源但已有 scope 时删除旧数据，无适用配置时目标不变。
10. 令 `SOURCE_TABLE=TARGET_TABLE=AW_MR7_ARPA01_000001`，确认所有来源暂存结束后才删除；重复运行不翻倍且金额一致。
11. 两个 session 用不同 `P_AZIENDA/P_BG` 但实际命中同一目标场景期间，确认目标级锁使其串行或立即失败；不同 target/scenario/period 可并行且 GTT 不串读。
12. 注入非法 owner、对象名、列名、类型、权限、规则重叠和目标额外非空列，确认目标没有部分删除，错误包含阶段/source/target/RULE_ID。
13. 模拟日志表不可写，确认业务错误不被日志错误覆盖；模拟最终 COMMIT 后 END 日志失败，确认目标状态仍被正确报告为已提交并产生告警。

## 待确认假设和发布门禁

1. `AW_MR7_ARPA01_000001` 的 owner、完整 DDL、主键/唯一键、非空列、索引和目标独占性未确认；用户业务字段资料不等于完整 DDL。
2. `AW_RUL_TOVCAL_000001` 的 owner、RULE_ID、字段长度、有效期类型和重叠规则未确认；本文首版只支持 `VARCHAR2(6)` 的 `YYYYMM`。
3. source 白名单和所有 source 的完整 18 金额列/基础键契约未确认；不允许按字段名相似度自动映射。
4. `TGK_FIMA_HISENSE.V_REF_DEST2` 是知识库登记对象之一，但批准 owner、权限和真实列类型需核验；`V_REF_ED_D_GRAN_CAL` 未在知识库登记，不能视为存在。
5. `SESSION_TOVCAL_RESULT`、`SESSION_TOVCAL_SCOPE` 是否已存在及其 owner/索引未确认；若不存在，需要 DBA 先部署，过程不运行时创建表。
6. `ZTAB_CPM_LOG` 真实 owner、列长度和授权未确认；本文要求部署门禁核验，不能从参考过程的 INSERT 反推完整 DDL。
7. “本月占用金额”使用 `*_END_OCP_AMT` 是由用户字段集合推导的映射；业务若确认其他来源字段，必须修订固定公式。
8. 分母为零暂选输出 `0`；业务若要求 `NULL`，必须在代码生成前确认并修改唯一公式契约。
9. 配置 `COD_AZIENDA` 的 NODE 展开可以支持，但目标公司维度写入节点编码是否符合业务尚未确认；未确认时应只允许 ELEM。
10. 目标表按引擎独占处理仅在 DBA/台账确认后生效；否则必须增加稳定归属字段或拒绝生成删除逻辑。
11. 过程采用 `AUTHID DEFINER`、过程独占事务和自治日志是本版选定架构；若调度框架要求共享调用方事务，需要重新评审。
12. 锁算法采用固定 `GET_HASH_VALUE`，碰撞只会保守串行；DBMS_LOCK 包权限和实际 API 返回码必须通过数据库验证。

## Acceptance Criteria

1. 过程签名完全匹配 `P_SCENARIO、P_PERIODO、P_AZIENDA、P_BG、SESSION_USER`；输入期间 `1` 被规范为 `01`，非法场景/期间/范围在任何目标变更前失败。
2. `P_AZIENDA='2600'` 时，配置 `COD_AZIENDA='6100'` 不进入 scope，不能读取 6100 来源或删除 6100 目标；配置 `ALL` 只能作用于当前 session 公司集合。
3. 配置公司 ELEM、允许的 NODE、ALL 三种情况均按本设计交集规则执行；未命中的具体公司不产生删除范围。
4. 当前 `P_BG` 为完整编码时只命中同编码配置；`P_BG='BG001'` 不自动展开子事业部；配置目标维度空/空格/ALL 输出 `ZZZZ`。
5. 10 个过滤组分别配置时全部生效；部分空组、非法列或非法规则在来源 SQL 执行前失败。
6. `=`、`<>`、`IN`、`LIKE`、`NOT LIKE`、`HIE`、`NOT IN`、`IS NULL`、`IS NOT NULL` 九类规则均生成固定 SQL；1001 项 IN/NOT IN 不触发 Oracle 1000 项限制，空 token 和多余 `|` 失败。
7. HIE 对 `COD_DEST2` 生成批准的 `V_REF_DEST2` 子查询，对 `D_GRAN_CAL` 生成批准的 `V_REF_ED_D_GRAN_CAL` 子查询，且绑定 `HIE='01'`、`NODE='030'`。
8. 非白名单 source/target/HIE、非法 owner、引号/分号/注释对象名、缺列、错误类型或缺权限均失败；所有值使用 bind，不执行配置表达式。
9. 多条来源明细的 18 个金额等于聚合结果；六个天数只使用聚合金额计算；六个分母为零时按发布确认的 0/NULL 策略返回且无除零异常；YTD 的本月占用映射明确为 `*_END_OCP_AMT` 或经确认的替代字段。
10. 目标 39 列按用户字段顺序写入；来源类别/币种空值和配置目标维度空值统一为 `ZZZZ`；目标额外非空无默认列未闭合时过程不生成/不部署。
11. 同一 source/target/output scope 的重复规则被拒绝；不同 source 可以汇入同一目标 scope 且不重复执行同一 source。
12. 删除只影响当前场景、期间、完整 11 个目标维度的已确认独占 target，并包括该 scope 下全部类别和币种；无来源仍按 scope 删除，无适用配置不删除。
13. `SOURCE_TABLE=TARGET_TABLE` 时全部来源先入 GTT 再删除/装载；重复执行不翻倍，失败回滚不留下部分目标结果。
14. DBMS_LOCK 按 canonical target/scenario/period 获取；不同原始入参但实际同一目标范围不能绕过锁；锁返回码、释放和异常路径可追踪。
15. 正常日志有 BEGIN、校验、暂存、删除、装载、END；异常日志包含阶段、规则、source/target、错误码和错误信息；日志故障不覆盖原始业务异常。
16. 数据库编译无 `USER_ERRORS`，直接授权、DDL、GTT、HIE 对象和 target 独占证明全部满足；数据库不可连接时验收状态只能是“静态核对完成，数据库验证待执行”。

## Out of Scope

- 本轮不修改或生成目标过程文件，不创建数据库对象，不执行 DDL，不删除业务数据，不编译 Oracle 过程。
- 不补造或猜测 `AW_MR7_ARPA01_000001`、`AW_RUL_TOVCAL_000001`、HIE 视图、GTT、日志表的真实 DDL；不使用知识库中的 `AW_MR7_ARPS02_000001` 替代用户指定目标。
- 不默认继承参考 AR 过程的 `AR_FLAG`、`COSMAP`、`DWMCRS`、锁定事业部、账龄、坏账、收入匹配或科目映射逻辑。
- 不实现来源同义字段自动映射、汇率换算、事业部层级展开、自定义金额公式或配置中的任意 SQL/JOIN/函数。
- 不在目标表独占性、目标非空列、owner/权限、HIE 对象和有效期类型确认前生成可部署删除逻辑。

## 对上一轮设计审查意见的逐项处理

1. **HIGH：配置目标公司未纳入运行范围，可能越界删除。已处理。** 新版明确 `COD_AZIENDA` 的 ALL/ELEM/NODE/未命中规则；scope 只有在配置公司与 `SESSION_AZIENDA_LIST` 相交时才建立，未命中配置不会删除。
2. **HIGH：DBMS_LOCK 按入参加锁。已处理。** 改为按最终 canonical target owner/table + 场景 + 期间的保守目标级锁，不使用原始 `P_AZIENDA/P_BG`；多个 target 排序后获取，通配入参不会绕过锁。
3. **HIGH：目标 INSERT 强制审计列未经 DDL 证明。已处理。** 固定 INSERT 只包含用户提供的 39 个业务列，不假设 `OID/PROVENIENZA/DATEUPD/USERUPD`；真实 target 的额外非空无默认列必须在门禁中闭合，否则阻断。
4. **HIGH：owner、白名单、GTT、日志和权限没有部署契约。已处理。** 增加部署矩阵，明确固定 owner/对象类型/白名单/直接授权是运行前门禁；当前缺失资料保持待补，不自行猜测。
5. **HIGH：HIE 对象映射和类型不可验证。已处理。** 固定 `COD_ -> V_REF_`、`D_ -> V_REF_ED_` 映射矩阵，要求批准 owner、ELEM/HIE/NODE 字符类型和权限；明确知识库没有 `V_REF_ED_D_GRAN_CAL` 登记。
6. **HIGH：异常清理事务边界未闭合。已处理。** 明确先保存错误、关闭游标、回滚业务事务，再单独提交 session/GTT 清理；清理和日志错误均不覆盖原始异常，最后释放锁并重抛。
7. **HIGH：YTD 映射和零分母未确认。已处理但保留发布门禁。** 明确唯一候选为 `*_END_OCP_AMT`，零分母暂选 0，并在假设、静态清单和验收中要求业务确认；未确认不得把推导称为事实。
8. **HIGH：目标独占性和通配删除未经证实。已处理。** 删除策略改为“目标独占证明后才启用”；删除只基于完整 11 维规范化 scope，未确认独占性时拒绝生成删除代码。
9. **MEDIUM：参数长度和来源类型未对齐。已处理。** `P_SCENARIO` 收紧到目标资料的 15，金额要求 NUMBER，过滤列要求 CHAR/VARCHAR2/VARCHAR，所有长度和精度以真实 DDL 门禁核验，禁止静默截断。
10. **MEDIUM：HIE 列类型和绑定不完整。已处理。** HIE 三列首版统一要求字符类型，HIE/NODE/ELEM 均绑定且与来源列兼容，类型不符直接失败。
11. **MEDIUM：有效期格式和起止顺序未校验。已处理。** 有效配置读取前校验 `YYYYMM`、月份和起止顺序；异常含 RULE_ID/source/target 并发生在 DELETE 前。
12. **MEDIUM：日志不能定位规则且最终提交语义不清。已处理。** 日志部署门禁冻结字段长度；暂存日志包含规则和 source/target；END 放在主事务成功提交之后，日志故障不误报已提交业务。
13. **NIT：DBMS_LOCK 哈希/API 未固定。已处理。** 固定 `DBMS_UTILITY.GET_HASH_VALUE` 算法、范围、锁名前缀、timeout=0、返回码映射和释放规则；碰撞只造成额外串行。
14. **NIT：10 组和 9 类规则缺少静态样例。已处理。** 新版列出全部 10 组、9 类规则、括号、IN OR 分块、NOT IN AND 分块、1000/1001 边界、HIE 单分隔符和 bind 顺序。

## 11. 用户最终确认（2026-10-21）

用户确认上一轮 1—9 项口径均成立，并特别纠正字段契约：不能把目标表字段资料泛化为“所有动态来源表都天然具备同样字段”。实现必须逐行依据用户提供的字段清单处理，不得遗漏、改名或按字段名称推断业务含义。

目标表需要逐行覆盖以下 18 个金额字段：

- `PLN_BEG_OCP_AMT`
- `PLN_LM_OCP_AMT`
- `PLN_END_OCP_AMT`
- `PLN_YTD_OCP_AMT`
- `PLN_MTD_CSM_AMT`
- `PLN_YTD_CSM_AMT`
- `ACT_BEG_OCP_AMT`
- `ACT_LM_OCP_AMT`
- `ACT_END_OCP_AMT`
- `ACT_YTD_OCP_AMT`
- `ACT_MTD_CSM_AMT`
- `ACT_YTD_CSM_AMT`
- `LY_BEG_OCP_AMT`
- `LY_LM_OCP_AMT`
- `LY_END_OCP_AMT`
- `LY_YTD_OCP_AMT`
- `LY_MTD_CSM_AMT`
- `LY_YTD_CSM_AMT`

周转天数为计算结果字段，必须逐行覆盖：

- `PLN_MTD_TDAYS`
- `PLN_YTD_TDAYS`
- `ACT_MTD_TDAYS`
- `ACT_YTD_TDAYS`
- `LY_MTD_TDAYS`
- `LY_YTD_TDAYS`

来源动态表不得被无依据地假定为目标表结构的复制品；过程应根据实际来源对象和字段契约校验可取的 18 个金额字段，金额字段缺失时在删除目标数据前报错。目标表身份以用户指定的 `AW_MR7_ARPA01_000001` 和当前知识库最新记录为准，需重新读取知识库副本确认，不再以旧审查中未更新的知识库快照否定用户最新资料。