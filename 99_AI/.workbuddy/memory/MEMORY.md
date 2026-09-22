# 项目长期记忆（MEMORY.md）

## Tagetik 知识库（合并报表/CPM 平台）
- **知识库文件（全量版，2026-09-22 重建，2026-09-22 晚补充业务章节）**：`/Users/zhouhong/Documents/01_TA工作/99_AI/98_TA知识库/Tagetik知识库.md`（Markdown 全量，八节：一～七为结构与血缘 + 八为业务知识补充）+ 同名 `Tagetik知识库.html`（单文件交互版，2.2MB，带左侧目录导航、表名过滤/检索、表约束与血缘查询面板、以及新增「业务知识补充」导航项：输入表名即显示字段字典/PK/FK→父表/被引用子表；点击「业务知识补充」看 MCP 提供的业务/概念知识）。
  - 【位置约定】知识库等产出统一放在**工作区目录 `99_AI/` 下**（用户明确要求），如 `99_AI/98_TA知识库/`；不要再放到 `01_TA工作/` 外层。
  - **数据来源原则 = 建库脚本为主、Excel 为辅**：用户明确要求——`application_install_oracle_sub.sql` / `repo_install_oracle_sub.sql` 是**权威主来源**（提供 100% 的表、字段、主键、外键、表血缘，**全量**）；Excel 表单仅作**辅助补充**（提供表/字段的中文释义等口径信息）。表清单/字段/约束/血缘一律以脚本为准，Excel 仅补充中文释义并以「(Excel)」标注，绝不为脚本中没有的表/字段臆造释义。注意：不要把 Excel 完全排除（思维不要极端），也不要以 Excel 为准（其表不全）。
  - **全量覆盖**：应用库 **1034 张表 / 17307 字段**，中央库 **89 张表 / 702 字段**；逐表字段字典（列名/类型/可空/默认值/是否主键）、主键目录、外键与表血缘索引（按父表组织全部 FK：应用库 896 PK / 2856 FK；中央库 49 PK / 4 FK）、血缘枢纽表 Top40、命名约定。
  - **解析关键结论**：① 建表语句为 `execute immediate ('CREATE TABLE …')` 形式，含 4 张跨多行建表（DIAG_ARCHIVIO/H_DIAG_ARCHIVIO/MAP_DATI_ACQUISITI/MAP_DATI_TRASFORMATI），须用整文件括号深度扫描；② 所有 PK/FK 均经 `ALTER TABLE ADD CONSTRAINT` 添加，无行内约束；③ 单引号在脚本中转义为 `''`；④ 应用库 241 个父表被引用，AZIENDA/CONTO/SCENARIO_PERIODO 等为主数据血缘枢纽。
  - **新增「八、业务知识补充」章节（来源：tagetik-knowledge MCP）**：2026-09-22 晚，用户要求用 `tagetik-knowledge` MCP 完善知识库。该 MCP 已配置于 `~/.workbuddy/mcp.json`（`type:http`，端点 `https://ta_mcp1.epm1.399.ink:60000/mcp`，需关闭 SSL 证书校验才能连通，Bearer Token 已在 mcp.json 中）。通过 `tagetik_knowledge_answer` 工具（分面返回 business/backend.{domain_model,physical_model,operations,examples,capability_boundary} + sources + coverage）拉取 14 个业务/概念主题（AZIENDA/CONTO/CATEGORIA/SCENARIO/PERIODO、余额表族、DATI_RETT、RACCOLTA、PROVENIENZA、关键枚举、合并流程、CONFIG_NAME_DB、TDL），整理为第八节并同时注入 HTML 的「业务知识补充」面板（const BIZ）。MCP 知识版本 `7ccc4f853654…`。原则：MCP 提供业务/概念层解释，不修改建库脚本得出的结构结论；覆盖状态（ANSWERED/PARTIAL vs INSUFFICIENT/UNKNOWN）如实标注。
  - 用户后续咨询 Tagetik 表结构/字段含义/表关系/主键外键/血缘/建库时，优先读此文件。
  - 旧版 `99_AI/Tagetik知识库.md`（增强前，93KB）已移入废纸篓（可恢复），不再使用。
- **双库架构**：Application DB（应用库，约 1034 张表，数据+模型） + Repository DB（中央库/中央存储库，约 89 张表，用户/角色/权限/审计）。单安装=1中央库+N应用库。
- **核心维度模型**：Scenario(场景)×Periodo(期间)×Azienda(实体)×Conto(科目)×Categoria(类别)×Dest1~5(自定义维度)×Valuta(货币)。
- **维度四表架构**：每个维度含 `维度主表` / `*_GERARCHIA`(层级) / `*_GERARCHIA_ABBI`(非时间相关挂接) / `*_GERARCHIA_ABBI_TV`(时间相关挂接) / `*_GERARCHIA_FLAT`(扁平)。适用于 SCENARIO/CATEGORIA/CONTO/DEST1/AZIENDA。
- **源文件位置**：`/Users/zhouhong/Documents/01_TA工作/99_AI/99_TA相关知识库文件/`（data model htm 导出自 `10.7.8.124:20500/tagetikcpm/datamodel`，版本 v5.3.14.201）。

## 用户相关偏好（TA/财务工程）
- 详见全局记忆（海信 TA 团队，SAP ABAP + Oracle/Doris/SQL Server，Tagetik 经 Citrix 访问）。
- 偏好：中文沟通、直接给代码+详细解释、结构化表格对比、逐字段对齐、SQL 最小改动保原结构、A/B 对比验证(COGS_AMT sum)。
