# CPM_SP_S2S_TDAYS_M 验证记录

验证对象：`01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`
验证时间：2026-10-21

## 文本级静态校验

执行命令（工作区根目录 `/Users/shiqingfeng/Documents/1_工作/01_海信`）：

```bash
python3 - <<'PY'
from pathlib import Path
p = Path('01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql')
r = Path('01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql')
s = p.read_text()
ref = r.read_text()
assert s.startswith('/*') and '*/\nCREATE OR REPLACE PROCEDURE CPM_SP_S2S_TDAYS_M' in s
signature = ['P_SCENARIO   IN VARCHAR2','P_PERIODO   IN VARCHAR2','P_AZIENDA   IN VARCHAR2','P_BG        IN VARCHAR2','SESSION_USER IN VARCHAR2']
assert all(x in s for x in signature)
for i in range(1, 11):
    for prefix in ('COLUMN_NAME_', 'COLUMN_FILTER_', 'COLUMN_VALUE_'):
        assert f'{prefix}{i}' in s
ops = ["V_OPERATOR = '='", "V_OPERATOR = '<>'", "V_OPERATOR = 'IN'", "V_OPERATOR = 'LIKE'", "V_OPERATOR = 'NOT LIKE'", "V_OPERATOR = 'HIE'", "V_OPERATOR = 'NOT IN'", "V_OPERATOR = 'IS NULL'", "V_OPERATOR = 'IS NOT NULL'"]
assert all(x in s for x in ops)
amounts = ['PLN_BEG_OCP_AMT','PLN_LM_OCP_AMT','PLN_END_OCP_AMT','PLN_YTD_OCP_AMT','PLN_MTD_CSM_AMT','PLN_YTD_CSM_AMT','ACT_BEG_OCP_AMT','ACT_LM_OCP_AMT','ACT_END_OCP_AMT','ACT_YTD_OCP_AMT','ACT_MTD_CSM_AMT','ACT_YTD_CSM_AMT','LY_BEG_OCP_AMT','LY_LM_OCP_AMT','LY_END_OCP_AMT','LY_YTD_OCP_AMT','LY_MTD_CSM_AMT','LY_YTD_CSM_AMT']
days = ['PLN_MTD_TDAYS','PLN_YTD_TDAYS','ACT_MTD_TDAYS','ACT_YTD_TDAYS','LY_MTD_TDAYS','LY_YTD_TDAYS']
assert all(x in s for x in amounts + days)
assert s.count('SUM(NVL(S.') == 18
assert s.count('APPEND_FILTER(R.COLUMN_NAME_') == 10
for x in ['DBMS_ASSERT.SIMPLE_SQL_NAME','DBMS_ASSERT.SQL_OBJECT_NAME','ALL_OBJECTS','ALL_TAB_COLUMNS','DBMS_SQL.OPEN_CURSOR','DBMS_SQL.PARSE','DBMS_SQL.BIND_VARIABLE','DBMS_LOCK.ALLOCATE_UNIQUE','DBMS_LOCK.REQUEST','DBMS_LOCK.RELEASE','ROLLBACK','EXCEPTION','RAISE']:
    assert x in s
assert 'V_SQL            CLOB' in s
assert 'V_HIE_OBJECT := \'TGK_FIMA_HISENSE.V_REF_\' || SUBSTR(V_COLUMN, 5)' in s
assert "V_HIE_OBJECT := 'TGK_FIMA_HISENSE.V_REF_ED_' || V_COLUMN" in s
assert s.index('INSERT INTO SESSION_TOVCAL_RESULT') < s.index("DELETE FROM ' || V_TARGET_OBJECT")
assert 'THEN NULL ELSE' in s
assert not any(line.rstrip() != line for line in s.splitlines())
assert ref == r.read_text()
print('STATIC_ASSERTIONS_PASS')
print('TARGET_BYTES=' + str(len(s.encode())))
print('AMOUNT_SUM_COUNT=' + str(s.count('SUM(NVL(S.')))
print('FILTER_GROUP_CALLS=' + str(s.count('APPEND_FILTER(R.COLUMN_NAME_')))
print('REFERENCE_READBACK_STABLE=True')
PY

git diff --check --no-index /dev/null '01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql'
```

实际结果：

```text
STATIC_ASSERTIONS_PASS
TARGET_BYTES=38184
AMOUNT_SUM_COUNT=18
FILTER_GROUP_CALLS=10
REFERENCE_READBACK_STABLE=True
DIFF_CHECK_PASS
```

静态检查覆盖：

- 过程名、5 个参数及 `SESSION_USER`；
- `COLUMN_NAME_1~10`、`COLUMN_FILTER_1~10`、`COLUMN_VALUE_1~10`；
- `=`、`<>`、`IN`、`LIKE`、`NOT LIKE`、`HIE`、`NOT IN`、`IS NULL`、`IS NOT NULL`；
- 18 个金额字段的来源 `SUM(NVL(S.<AMOUNT>, 0))`；
- 6 个周转天数字段及分母为 0 返回 `NULL`；
- `DBMS_ASSERT`、`ALL_OBJECTS`、`ALL_TAB_COLUMNS`、`DBMS_SQL` 绑定、`DBMS_LOCK`、异常回滚和原错重抛；
- HIE 的 `COD_ -> V_REF_`、`D_ -> V_REF_ED_D_` 推导；
- 所有来源先写入 `SESSION_TOVCAL_RESULT`，之后才生成目标删除语句；
- 动态 SQL 使用 CLOB，避免多组 1000 项 IN/NOT IN 条件超过 VARCHAR2 长度；
- 动态来源表只允许字典中可访问的 TABLE/VIEW/MATERIALIZED VIEW，目标固定白名单为 `AW_MR7_ARPA01_000001`；
- 参考程序内容回读稳定，未由本次操作写入。

## 数据库编译

执行环境检查：

```bash
if command -v sqlplus >/dev/null 2>&1 || command -v sqlcl >/dev/null 2>&1; then
  echo ORACLE_CLIENT_AVAILABLE
else
  echo ORACLE_CLIENT_UNAVAILABLE
fi
```

结果：

```text
ORACLE_CLIENT_UNAVAILABLE
```

本机没有 `sqlplus` 或 `sqlcl`，且未提供数据库连接信息，因此无法执行 Oracle 编译、`USER_ERRORS/ALL_ERRORS` 检查、对象DDL/权限检查、GTT检查或运行结果验证。不能据此声称过程已编译或已部署。

## 待数据库门禁确认

- `AW_MR7_ARPA01_000001` 与知识库 `AW_MR7_ARPS02_000001` 的对象身份、OWNER、完整DDL及目标独占性；
- `AW_RUL_TOVCAL_000001`、`SESSION_TOVCAL_RESULT`、`SESSION_TOVCAL_SCOPE`、`ZTAB_CPM_LOG` 的OWNER、DDL和直接授权；
- 每个配置来源的5个基础字段、18个金额字段及字段类型/精度；
- `V_REF_DEST2`、`V_REF_ED_D_GRAN_CAL` 的批准OWNER、对象类型、ELEM/HIE/NODE类型和权限；
- DBMS_LOCK、日志自治事务、共享SESSION表重入及目标额外非空列行为；
- `*_END_OCP_AMT` 作为YTD公式“本月占用金额”的映射已在代码头部标记为待确认。

## 文件范围

本次新增/修改：

- `01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`
- `.agents/tasks/CPM_SP_S2S_TDAYS_M-verification.md`

参考文件 `CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` 未被本次操作写入；工作区在任务开始时已存在该参考文件的 git 修改状态，本次未对其执行格式化、修复、回滚或提交。
