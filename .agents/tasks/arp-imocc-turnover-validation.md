# ARPM02/IMOCC 周转校验脚本静态验证记录

验证日期：20261021
验证范围：
- `01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询.sql`
- `01_代码/02_DWM/C_应收应付/ARPM02_IMOCC周转校验查询_2026ACT08_2600_ALL.sql`

## 1. CTE 结构、输出字段和标记逻辑

- 两份脚本均包含 20 个 CTE，顺序完全一致：`REF_AZIENDA`、`TOV_BG_SCOPE_ALL`、`TOV_BG_SCOPE`、`AZI_SCOPE`、`PROFIT_CENTER_RULE`、`ATS_BG_MAP_ALL`、`ATS_BG_MAP`、`PCR_BG_MAP_ALL`、`PCR_BG_MAP`、`ARPTOV_RULE`、`TURNOVER_SOURCE`、`TURNOVER_NORMALIZED`、`ATS_BG_STATUS`、`ATS_BG_STATUS_ALL`、`PCR_BG_STATUS`、`PCR_BG_STATUS_ALL`、`MAPPED_TURNOVER`、`BG_TURNOVER_NET`、`NEGATIVE_BG_TURNOVER`、`FILTERED_TURNOVER`。
- 两份脚本的最终输出字段顺序一致：场景、期间、公司、来源、类别、`ARPTOV_FLAG`、客商、客商名称、集团范围、对方公司、利润中心、事业部、`AR_AMT_FLAG`、`BUSINESS_UNIT_MAP_STATUS`、金额及两个描述字段。
- `ARPTOV_FLAG` 在来源层生成并进入映射、最终聚合；IMOCC固定为`N`，ARPM02按TOV的BATCH_ID=1/2/3/4/6规则判定。
- `AR_AMT_FLAG` 仅由`NEGATIVE_BG_TURNOVER`回标产生；配置剔除、事业部映射无效或未命中负净额规则的记录均保留并标记`N`。
- `BUSINESS_UNIT_CODE`仅在当前参数范围内公司映射事业部与利润中心映射事业部唯一且相等时赋值，否则为空；`BUSINESS_UNIT_MAP_STATUS`区分映射冲突、利润中心未映射、账套未映射、事业部参数/范围排除、公司与利润中心不一致和已映射同一事业部。
- 最终查询没有再次按`ARPTOV_FLAG`、`AR_AMT_FLAG`或金额非零条件过滤；IMOCC来源层原有非零条件仍保留，符合“来源正常条件保留、最终全量留痕”的口径。

## 2. 参数版与固定常量版一致性

- 将参数版`${$Scenario.code}`、`${$Period.code}`、`${$Entity.code}`、`${$ANL_D_BG.code}`分别归一化为`'2026ACT'`、`'08'`、`'2600'`、`'ALL'`后，与固定版从`WITH`开始逐段比较，正文完全一致。
- 两份脚本的差异仅为文件头说明、版本记录和参数/固定常量；没有额外业务分支。
- 两份脚本均保留单个ARPM02事实来源SELECT；ARPM02同时命中ME/MB账龄条件时由`CASE`优先生成一个类别，不会因`UNION ALL`重复计入。

## 3. TOV规则、NULL连接和重复计数静态核对

- `ARPTOV_RULE`按TOV存储过程使用的`AW_RUL_ARPTOV_000001`、`VALID_FR`、`VALID_TO`及批次`1/2/3/4/6`读取字段并`TRIM`；没有把规则明细直接JOIN到ARPM02事实表。
- BATCH_ID=6使用“公司存在二级性质配置但本行未命中配置”的剔除判定；BATCH_ID=1使用模糊客商，BATCH_ID=2使用公司+客商，BATCH_ID=3使用二级性质，BATCH_ID=4使用公司+销售部门。
- 来源公司范围与事业部映射范围分离，`AZI_SCOPE`只按HIE=10、公司参数和D2M进数规则控制；因此无事业部映射或被事业部参数排除的来源行可以保留到结果。
- `ATS_BG_MAP`、`PCR_BG_MAP`及其全部范围集合先按事业部配置去重，再通过状态聚合CTE压缩为每个账套/利润中心一行；多事业部配置不择一，按“事业部映射冲突”置空，避免事实金额被配置重复放大。
- 事业部映射全部使用`LEFT JOIN`；未命中映射时不会因NULL等值连接消失。`BUSINESS_UNIT_CODE`通过显式条件赋值，未使用假编码代替NULL。
- `BG_TURNOVER_NET`只使用`ARPTOV_FLAG='N'`、`GRP_SCOPE='GEX-集团外'`且映射状态为已映射同一事业部的行；分组键包含场景、期间、公司、标准化主户、类别和事业部，且主户为NULL的行不进入负净额分组。
- 负净额回标使用相同标准化主户、场景、期间、公司、类别和事业部键；没有用会把NULL错误匹配的笼统`NVL`连接。
- `NEGATIVE_BG_TURNOVER`只识别存在不同事业部且净额小于0的事业部；`FILTERED_TURNOVER`不删除记录，而是通过`CASE`生成`AR_AMT_FLAG`。

## 4. SQL格式和可执行性检查

- 两份文件均通过括号平衡检查，括号差值为0。
- 两份文件均通过`git diff --check`，没有空白错误。
- 每个CTE上方均有连续`--`中文用途注释；字段逐行排列，逗号前置，未修改参考存储过程及其他业务文件。
- 最终事业部描述使用显式`CASE`处理`BUSINESS_UNIT_CODE IS NULL`，不以假编码调用描述函数。
- 本机未安装`sqlfluff`或其他可用Oracle SQL lint工具，因此未完成SQL lint。
- 当前环境没有Oracle连接、目标对象元数据或实际规则/映射数据，未完成Oracle编译、执行、实际金额勾稽和规则边界样例验证；需要在目标Oracle环境执行`EXPLAIN PLAN`或只读查询后确认参数展开、字段类型、函数对NULL的行为及实际配置唯一性。

## 5. 变更范围

- 业务SQL修改仅涉及上述两份目标脚本。
- 本验证记录按需求新增；未创建提交，未修改参考存储过程，未新增测试文件。

## 6. 后续审查复核（20261021）

- 已读取 `.agents/tasks/arp-imocc-turnover-review.json` 及其 `reviewDoc` 指向的完整审查文档。审查仅提出一项合理发现：缺少目标 Oracle 环境解析、参数展开和实际规则边界证据。
- 重新执行静态检查结果通过：两份脚本括号平衡；CTE 顺序均为上述 20 个；ARPM02 事实来源仅出现一个；ME/MB 账龄条件仍为带括号的 `OR`；ARPTOV 批次 1/2/3/4/6 和各自条件均存在；`ARPTOV_FLAG`、`AR_AMT_FLAG`、`BUSINESS_UNIT_MAP_STATUS` 均进入最终输出与 `GROUP BY`；最终未按金额、`ARPTOV_FLAG` 或 `AR_AMT_FLAG` 删除记录；参数版和固定版正文归一化后完全一致。
- NULL/重复计数/聚合粒度静态复核通过：事业部映射使用聚合后的 `LEFT JOIN`，未映射和参数范围外记录保留并将事业部置空；负净额分组排除 NULL 主户且不含来源字段，回标键包含场景、期间、公司、主户、类别、事业部；规则表未直接连接事实表。
- 目标环境验证仍无法完成：本机未发现 `sqlplus`、Oracle 客户端、SQL lint 工具或可用连接配置，因此未执行 Oracle 编译/`EXPLAIN PLAN`、报表参数实际展开、规则/映射边界样例、NULL 主户样例及实际金额勾稽。该审查发现属于环境证据缺口，不能通过静态改写安全解决；交付时不宣称数据库执行通过。
- 本次复核未修改参考存储过程、未创建测试文件、未创建提交；除按需求更新本验证记录外，未扩大文件范围。
