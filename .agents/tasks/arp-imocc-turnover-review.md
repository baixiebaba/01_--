# ARPM02/IMOCC 周转校验的全量留痕与 TOV 规则对齐

两份目标 SQL 将 ARPM02 与 IMOCC 的校验结果改为保留来源行，并新增 `ARPTOV_FLAG`、`AR_AMT_FLAG` 和 `BUSINESS_UNIT_MAP_STATUS`，用于解释配置剔除、负净额事业部剔除及事业部映射结果。ARPM02 改为单次来源读取，以 ME 优先、MB 其次生成类别；事业部映射改为左连接留痕，负净额只在有效集团外周转集合上计算，最终聚合按标记字段分开。对照 TOV 存储过程及计划、验证记录，静态逻辑未发现明确的规则键、重复计数或最终过滤错误。**Watch for:** **confirmed**，两份脚本仍缺少目标 Oracle 的可执行性、参数展开和实际规则/映射边界证据；在该证据补齐前，不能确认对象解析、报表参数和维度函数在目标环境中的行为。

**Verdict**: NEEDS_CHANGES

## High-level view

来源层保留了 TOV 的 ARPTOV 有效期、批次 1/2/3/4/6 和各批次判定：规则通过相关 `EXISTS/NOT EXISTS` 计算 `ARPTOV_FLAG`，没有把规则明细直接连接到事实表。ARPM02 的括号化 ME/MB 条件仍在，单条记录按 ME 优先、MB 其次只产生一个类别；IMOCC 保留 TOV 的来源级非零条件并使用客商主户键。

映射层把来源公司范围与事业部参数范围分开，用去重和状态聚合避免配置行扩张金额；不一致、未映射和参数/范围排除的来源行均保留，事业部编码在无效映射时置空。负净额计算只使用 ARPTOV 未剔除、集团外且已映射同一事业部的集合，回标 `AR_AMT_FLAG='Y'` 而不删除明细；最终 `GROUP BY` 包含所有标记和状态字段，也取消了末尾金额非零过滤。

两份脚本的正文结构、CTE、输出字段、标记逻辑和聚合粒度一致，固定版仅替换参数常量并更新文件头。**confirmed**，门禁仍受验证证据缺口阻塞：记录明确未完成 Oracle 解析/编译、参数展开、规则边界样例及实际金额勾稽，因此静态通过不能等同于目标环境可发布。

<details>
<summary>Issues (1)</summary>

1. **目标环境可执行性与规则边界证据缺失** — **confirmed**：`ARPM02_IMOCC周转校验查询.sql` 第 98-205、404-408 行及 `ARPM02_IMOCC周转校验查询_2026ACT08_2600_ALL.sql` 对应位置依赖目标 Oracle 对象、参数替换和维度函数，但 `arp-imocc-turnover-validation.md` 明确未完成 Oracle 解析/编译或 `EXPLAIN PLAN`、ARPTOV 批次边界、事业部映射边界、NULL 主户和实际金额样例验证。应在目标 Oracle 环境分别对两份脚本补做只读解析/执行验证，并覆盖这些边界后再放行。

</details>

<details>
<summary>Details</summary>

### ARPTOV_RULE 留痕与 ARPM02 类别去重

**confirmed**：两份目标文件的 `ARPTOV_RULE`（参数版/固定版第 98-109 行）读取与 TOV 相同的 `AW_RUL_ARPTOV_000001`，按 `VALID_FR`/`VALID_TO` 和批次 `1/2/3/4/6` 限定，并对配置字段 `TRIM`。`TURNOVER_SOURCE`（第 110-205 行）使用相关 `EXISTS/NOT EXISTS` 计算 `ARPTOV_FLAG`：批次 6 按公司配置的二级性质白名单判定，批次 1 使用客商模糊匹配，批次 2 使用公司加客商，批次 3 使用二级性质，批次 4 使用公司加销售部门；规则明细没有直接 JOIN 到事实来源，所以不会因配置重复而扩行。

**confirmed**：ARPM02 事实表在来源层只有一个 `SELECT`，`ME_AGE_FLAG` 与 `MB_AGE_FLAG` 条件带括号保留；类别 `CASE` 先判 ME 再判 MB，因此同时命中两类时只生成一条。`UNION ALL` 只连接 ARPM02 和 IMOCC 两个不同来源。IMOCC 使用 `TRIM(I.CUST_CODE)` 作为客商及主户键，保留 TOV 的公司、对方公司、利润中心和来源级非零金额条件。

### 事业部映射与全量留痕

**confirmed**：`ATS_BG_MAP`、`PCR_BG_MAP` 及其全部范围集合先去重，再由状态 CTE 压缩到每个账套或利润中心一行；`MAPPED_TURNOVER` 对映射状态使用 `LEFT JOIN`。公司事业部和利润中心事业部只有在当前范围内各唯一且相等时才填入 `BUSINESS_UNIT_CODE`，否则置空，并区分多事业部冲突、利润中心未映射、账套未映射、参数/范围排除及事业部不一致，避免内连接丢失来源行或配置重复放大金额。

**confirmed**：来源入口仍保留公司参数、HIE=10 和 D2M 进数有效期条件；事业部选择只在映射判定中使用，使参数范围排除的来源行能够留痕。该拆分是计划中为满足“未映射/参数排除可查”而设计的取舍，不应与 TOV 实际装载入口的公司集合直接等同；若要求校验表严格等于装载过程的公司集合，仍需业务确认其边界。

### 负净额回标、NULL 连接与最终聚合

**confirmed**：`BG_TURNOVER_NET`（第 306-330 行）按场景、期间、公司、标准化主户、类别和事业部汇总，只取 `ARPTOV_FLAG='N'`、`GRP_SCOPE='GEX-集团外'` 且状态为已映射同一事业部的行；NULL 主户不进入负净额分组。`NEGATIVE_BG_TURNOVER` 只识别净额小于零且存在其他事业部的分组，负净额识别没有带入 `DATA_SOURCE`，所以 ARPM02 与 IMOCC 能合并计算。

**confirmed**：`FILTERED_TURNOVER` 以场景、期间、公司、类别、标准化主户和事业部回标 `AR_AMT_FLAG`，没有使用 `NOT EXISTS NEGATIVE...` 删除行；NULL 主户通过非空分组条件和等值回标避免错误匹配。ARPTOV 标记行、事业部无效行和未命中负净额规则的行仍保留并得到 `AR_AMT_FLAG='N'`。

**confirmed**：最终查询将 `ARPTOV_FLAG`、`AR_AMT_FLAG` 和 `BUSINESS_UNIT_MAP_STATUS` 同时放入输出与 `GROUP BY`，不会把 Y/N 或不同状态合并；不存在末尾 `WHERE NVL(F.TURNOVER_AMT,0) <> 0` 或按任一标记删除记录。IMOCC 来源层的 `NVL(I.IMOCC_CNY_AMT,0) <> 0` 仍在，这是 TOV 的正常来源条件而不是最终展示过滤。

### 两份脚本一致性与变更范围

**confirmed**：将固定版的 `2026ACT`、`08`、`2600`、`ALL` 与参数版对应位置归一化后，验证记录报告两份脚本从 `WITH` 开始正文一致；当前静态 spot-check 未发现 CTE、输出列、标记 CASE、JOIN、WHERE 或 GROUP BY 的参数版/固定版漂移。

**confirmed**：`git diff --name-only` 的业务 SQL 变更仅包含两份目标文件；参考存储过程未修改。计划、验证和本审查文件属于任务记录，不计入目标 SQL 的业务变更范围；未创建提交，也未运行完整测试套件或数据库查询。

### 未完成的目标环境验证

**confirmed**：验证记录第 4、6 节说明当前没有 Oracle 连接、目标对象元数据或实际规则/映射数据，因而未完成 Oracle 解析/执行、参数实际展开、规则/映射边界样例、NULL 主户样例和实际金额勾稽。目标文件依赖未加 schema 的 `AW_RUL_ARPTOV_000001`、报表参数替换以及第 404-408 行的维度描述函数；这些行为不能仅凭 SQL 文本确认。修复方向是补齐目标环境只读验证证据，而不是在本次审查中修改目标 SQL。

</details>

<details>
<summary>File map</summary>

- `01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询.sql` — 参数版全量留痕、TOV 规则标记、事业部状态和负净额标记。
- `01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询_2026ACT08_2600_ALL.sql` — 2026ACT/08/2600/ALL 固定参数版，与参数版正文同构。
- `01_代码/02_DWM/C_应收应付/CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` — 规则和负净额口径参考，未修改。

完整变更见两份目标 SQL 的 `git diff`。

</details>
