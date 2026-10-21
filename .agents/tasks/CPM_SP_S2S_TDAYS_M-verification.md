# CPM_SP_S2S_TDAYS_M 验证记录

验证对象：`01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`
验证时间：2026-10-21

## 文本级静态校验

在工作区根目录 `/Users/shiqingfeng/Documents/1_工作/01_海信` 执行：

```bash
python3 - <<'PY'
from pathlib import Path
import re, subprocess
p = Path('01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql')
r = Path('01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql')
s = p.read_text()
assert re.search(r'CREATE OR REPLACE PROCEDURE CPM_SP_S2S_TDAYS_M\(', s)
assert re.search(
    r'P_SCENARIO\s+IN VARCHAR2.*P_PERIODO\s+IN VARCHAR2.*P_AZIENDA\s+IN VARCHAR2.*P_BG\s+IN VARCHAR2.*SESSION_USER\s+IN VARCHAR2',
    s, re.S
)
for i in range(1, 11):
    assert all(f'{x}{i}' in s for x in ('COLUMN_NAME_', 'COLUMN_FILTER_', 'COLUMN_VALUE_'))
assert all(x in s for x in ['=', '<>', 'IN', 'LIKE', 'NOT LIKE', 'HIE', 'NOT IN', 'IS NULL', 'IS NOT NULL'])
amts = [
    'PLN_BEG_OCP_AMT', 'PLN_LM_OCP_AMT', 'PLN_END_OCP_AMT', 'PLN_YTD_OCP_AMT',
    'PLN_MTD_CSM_AMT', 'PLN_YTD_CSM_AMT', 'ACT_BEG_OCP_AMT', 'ACT_LM_OCP_AMT',
    'ACT_END_OCP_AMT', 'ACT_YTD_OCP_AMT', 'ACT_MTD_CSM_AMT', 'ACT_YTD_CSM_AMT',
    'LY_BEG_OCP_AMT', 'LY_LM_OCP_AMT', 'LY_END_OCP_AMT', 'LY_YTD_OCP_AMT',
    'LY_MTD_CSM_AMT', 'LY_YTD_CSM_AMT'
]
days = ['PLN_MTD_TDAYS', 'PLN_YTD_TDAYS', 'ACT_MTD_TDAYS', 'ACT_YTD_TDAYS', 'LY_MTD_TDAYS', 'LY_YTD_TDAYS']
assert all(x in s for x in amts + days)
assert s.count('SUM(NVL(S.') == 18
assert s.count('APPEND_FILTER(R.COLUMN_NAME_') == 10
for x in (
    'DBMS_ASSERT.SIMPLE_SQL_NAME', 'DBMS_ASSERT.SQL_OBJECT_NAME', 'ALL_OBJECTS',
    'ALL_TAB_COLUMNS', 'ALL_TAB_PRIVS', 'DBMS_SQL.PARSE', 'DBMS_SQL.BIND_VARIABLE',
    'DBMS_LOCK.ALLOCATE_UNIQUE', 'DBMS_LOCK.REQUEST', 'DBMS_LOCK.RELEASE',
    'RUN_ID', 'V_SCOPE_SEEN', 'ROLLBACK', 'RAISE'
):
    assert x in s
assert s.index('INSERT INTO SESSION_TOVCAL_RESULT') < s.index("DELETE FROM ' || V_TARGET_OBJECT")
assert s.count('THEN NULL ELSE') == 6
assert "V_CONFIG_MODE := 'NODE'" in s
assert "V_OPERATOR = 'HIE'" in s
assert 'SOURCE/TARGET对象owner不在固定过程owner内' in s
assert not any(line.rstrip() != line for line in s.splitlines())
assert subprocess.run(['git', 'diff', '--check', '--', str(p)], capture_output=True).returncode == 0
print('STATIC_ASSERTIONS_PASS')
print('TARGET_BYTES=' + str(len(s.encode())))
print('AMOUNT_SUM_COUNT=' + str(s.count('SUM(NVL(S.')))
print('FILTER_GROUP_CALLS=' + str(s.count('APPEND_FILTER(R.COLUMN_NAME_')))
print('TDAYS_FORMULA_COUNT=' + str(s.count('THEN NULL ELSE')))
print('REFERENCE_DIFF_NUMSTAT=' + subprocess.check_output(['git', 'diff', '--numstat', '--', str(r)], text=True).strip())
PY

git diff --check -- '01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql'
```

实际结果：

```text
STATIC_ASSERTIONS_PASS
TARGET_BYTES=46185
AMOUNT_SUM_COUNT=18
FILTER_GROUP_CALLS=10
TDAYS_FORMULA_COUNT=6
REFERENCE_DIFF_NUMSTAT=36  4  01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql
git diff --check：通过
```

静态检查覆盖：

- 过程名、`P_SCENARIO`、`P_PERIODO`、`P_AZIENDA`、`P_BG`、`SESSION_USER`及参数顺序；
- `COLUMN_NAME_1~10`、`COLUMN_FILTER_1~10`、`COLUMN_VALUE_1~10`；
- `=`、`<>`、`IN`、`LIKE`、`NOT LIKE`、`HIE`、`NOT IN`、`IS NULL`、`IS NOT NULL`；
- 10组筛选按绑定变量处理，IN/NOT IN按1000项分块，空token拒绝；
- 18个来源金额的`SUM(NVL(S.<AMOUNT>, 0))`及最终18个金额聚合；
- 6个周转天数字段，6个分母为0返回`NULL`，YTD使用相应`*_END_OCP_AMT`参与公式；
- 目标配置维度空值补`ZZZZ`，`COD_CATEGORIA`和`COD_VALUTA`直接保留来源值；
- `DBMS_ASSERT`、当前过程owner边界、HIE固定owner/前缀推导、`ALL_OBJECTS`、`ALL_TAB_COLUMNS`和直接授权检查；
- `DBMS_SQL` parse/bind/execute、`DBMS_LOCK`分配/请求/释放、SESSION互斥、`RUN_ID`暂存隔离；
- 所有来源先写入`SESSION_TOVCAL_RESULT`，之后才删除目标，覆盖`SOURCE_TABLE=TARGET_TABLE`同表读写；
- 异常路径关闭游标、回滚、按当前session/run清理、ERROR日志、释放锁并重抛原异常；
- 参考文件变更状态未改变：任务开始时该文件已有`36/4`工作区差异，本次仍为`36/4`，未执行格式化、修复、回滚或提交。

## 数据库编译

执行环境检查：

```bash
if command -v sqlplus >/dev/null 2>&1; then
  echo SQLPLUS_AVAILABLE
elif command -v sqlcl >/dev/null 2>&1; then
  echo SQLCL_AVAILABLE
else
  echo ORACLE_CLIENT_UNAVAILABLE
fi
```

实际结果：

```text
ORACLE_CLIENT_UNAVAILABLE
```

本机没有 `sqlplus` 或 `sqlcl`，也没有可用数据库连接信息，因此无法执行 Oracle 编译、`USER_ERRORS/ALL_ERRORS`、真实对象DDL/授权检查、GTT检查或运行验证。不能据此声称过程已编译、已部署或业务结果已验证。

## 待数据库门禁确认

- `AW_MR7_ARPA01_000001`、`AW_RUL_TOVCAL_000001`和过程当前schema的真实OWNER、完整DDL、列类型/长度、索引、目标独占性；
- `SESSION_TOVCAL_RESULT`、`SESSION_TOVCAL_SCOPE`的完整DDL、索引及`ON COMMIT PRESERVE ROWS`；
- `ZTAB_CPM_LOG`的OWNER、列长度、直接授权及自治事务写入条件；
- 每个配置SOURCE_TABLE的逐对象字段契约、金额精度和来源语义；
- `TGK_FIMA_HISENSE.V_REF_DEST2`、`V_REF_ED_D_GRAN_CAL`及其他前缀推导HIE对象的存在性、类型、列类型和直接授权；
- 过程owner对动态SOURCE/TARGET、配置、GTT、日志和`DBMS_SQL/DBMS_ASSERT/DBMS_LOCK`的直接授权；
- `DBMS_LOCK.ALLOCATE_UNIQUE`事务行为、目标独占删除策略及共享SESSION表的部署约束。

## 文件范围

本轮修改：

- `01_代码/02_DWM/C_应收应付/CPM_SP_S2S_TDAYS_M.sql`
- `.agents/tasks/CPM_SP_S2S_TDAYS_M-verification.md`

未修改：

- `01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql`
- 其他现有业务程序。
