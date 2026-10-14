# S610 总账科目与预期不一致调查报告

## 一、摘要结论

1. **S610 程序对总账科目确实有独立取数规则**：只有在 `ztzt_003` 配置范围内、且 `SKB1-MITKZ` 为空的非统驭科目才进入 `r_hkons`；随后从 `BSIS`（未清）和 `BSAS`（已清但关键日后清账）取数。应收/应付由 `ztzt_003-KOART` 与运行按钮共同决定，不能把所有总账科目直接与 BSID/BSIK 汇总比较。
2. **最可能造成“总账科目对不上”的口径差异是 SQL 侧没有对应 BSIS/BSAS 总账来源**：当前 `dwd_fi_mr_arap_detail_mi.sql` 明确写的是“仅处理 BSID/BSAD/BSIK/BSAK”，`unioned_items` 也仅合并这四类来源；未发现 BSIS/BSAS CTE 或合并分支。因此，S610 的 `BSIS/BSAS -> ZZT003_SAVE` 总账余额，和当前 DWD/2.0 账龄 SQL 不是同一取数范围，SQL 侧很可能完全漏掉该部分。
3. **金额仍然经过 `BAPI_CURRENCY_CONV_TO_EXTERNAL`，总账科目也不例外**。S610 的 `PRO_DATA` 对每一行先转换 `DMBTR/WRBTR`，再按借贷方向取负并汇总。函数按 `TCURX-CURRDEC` 计算 `10 ** (2-CURRDEC)`；例如 `CURRDEC=0` 时内部金额会乘 100，`CURRDEC=1` 时乘 10。用户描述“10 变 1000”实际是 100 倍，需先核实原值、输出值和币种；若实际是十倍，则需核查该币种的 `TCURX-CURRDEC=1` 或数据展示是否已包含一次小数位换算。
4. 总账科目被强制设置 `lv_datum = p_keydat`，所以总账科目全部进入最小账龄桶（按默认 `p1=30` 即 `DMBTR1/WRBTR1`），而不是依据凭证日期/基准日期分桶。这会造成账龄桶与 SQL 侧真实 `baseline_dt` 计算结果明显不同，但不应改变 `DMBTR0/WRBTR0` 总额。
5. 程序还有明确特殊排除：公司 `6377`、科目 `1123030101` 在应付模式下被额外作为非统驭科目取数，但最终 `BSIS/BSAS` 行只要 `GSBER` 非空就 `CONTINUE` 排除；`GSBER` 为空的该科目仍会保留。SQL 对照文件未发现同一条 `6377 + 1123030101 + GSBER` 排除规则，属于潜在口径差异。

## 二、S610 对总账科目的全部特殊规则与证据

### 1. `ztzt_003` / `SKB1` 科目分类与 `r_hkons` 构造

证据：`/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/草稿/S610.abap`，`FORM GET_DATA`，约第 256-291 行。

- 先按当前公司从 `ztzt_003` 读取科目区间，并通过 `T001-KTOPL` 关联科目表；再在 `SKB1` 中按 `SAKNR BETWEEN lt_003-HKONF AND lt_003-HKONT` 扫描。
- `MITKZ='K'`：加入 `r_hkonk`，即供应商统驭科目；`MITKZ='D'`：加入 `r_hkond`，即客户统驭科目。
- `MITKZ=''`：只有满足 `lt_003-koart='K' AND p_yf='X'`，或 `lt_003-koart='D' AND p_ys='X'`，才加入 `r_hkons`。代码注释将 S 类（`MITKZ` 为空）定义为应收/应付总账，D/K 定义为统驭科目。
- 因此总账科目不是按报表输入的任意 `HKONT` 直接取，而是同时受 `ztzt_003` 区间、公司、`SKB1-MITKZ`、应收/应付模式影响。
- `r_hkonk/r_hkond/r_hkons` 的表体在配置循环间没有显式 `CLEAR/REFRESH`，只有范围表头被赋为 `IEQ`。这意味着多个 `ztzt_003` 区间会累积到同一范围表；重复范围项通常不会让数据库 SELECT 重复返回同一行，但会使最终纳入科目范围依赖所有配置行的并集。建议核对配置是否存在重叠或错误区间。

### 2. BSIS/BSAS 查询、日期条件与数据来源

证据：同一 `S610.abap` 的 `FORM GET_DATA`，约第 311-376 行。

- 统驭科目先根据应收/应付模式选择：应收 `tabnam='BSID'`、条件为客户号和 `r_hkond`；应付 `tabnam='BSIK'`、条件为供应商号和 `r_hkonk`。
- 未清统驭科目 SELECT 条件包含公司、利润中心 `s_prctr`、业务范围 `s_gsber`、`budat <= p_keydat` 和动态科目/客商条件。
- 然后把 `tabnam+2(1)='A'` 改成已清表：BSID -> BSAD、BSIK -> BSAK；动态条件再追加 `augdt > p_keydat`，同样要求 `budat <= p_keydat`。所以关键日后的清账项目仍会回溯纳入，关键日前已清项目不纳入。
- 非统驭科目仅当 `r_hkons[] IS NOT INITIAL` 时处理：从 `BSIS` 取 `hkont IN r_hkons AND budat <= p_keydat`，再从 `BSAS` 取同一科目/公司/利润中心/业务范围条件并追加 `augdt > p_keydat`。
- 程序中按凭证日期 `bldat` 或基准日期 `zfbdt` 的条件已被注释掉；实际数据库筛选始终只用过账日期 `budat`，已清表再用清账日期 `augdt`。这是与“按凭证日期/基准日期筛选”的直觉预期不同的重点。
- 注释掉的 `blart <> 'DA'` 也没有生效，DA 凭证不会因该规则排除。

### 3. `6377/1123030101/GSBER` 特殊处理

证据：`S610.abap`，`FORM GET_DATA` 约第 271-279 行及第 366-374 行。

- 当 `SKB1-BUKRS='6377'`、`SKB1-SAKNR='1123030101'` 且 `p_yf='X'` 时，即使 `MITKZ='K'`，该科目仍额外加入 `r_hkons`，作为应付总账科目进入 BSIS/BSAS 查询。
- 对 BSIS/BSAS 结果循环时，若 `bukrs='6377'`、`hkont='1123030101'` 且 `gsber IS NOT INITIAL`，立即 `CONTINUE`，不追加到 `gt_bskd`。
- 该排除只针对总账 BSIS/BSAS 分支，不是所有来源的全局排除；业务范围为空的相同行仍会进入汇总。
- 当前调查到的 SQL 文件没有发现这组三条件的等价过滤，因此 SQL 与 ABAP 的总账结果可能不同。

### 4. 总账统一设置 `lv_datum = p_keydat` 与账龄桶

证据：`S610.abap`，`FORM PRO_DATA` 约第 423-438 行。

- 普通行先按 `p_pzrq` 选择 `bldat` 或 `zfbdt`。
- `blart='AB'` 强制改用 `zfbdt`。
- 但只要 `gt_bskd-tabnam='BSIS'`，无条件执行 `lv_datum=p_keydat`。代码注释明确写着“总账科目 不计算账龄”。BSAS 行在循环中也被赋值 `lt_bsis-tabnam='BSIS'`，因此 BSAS 结果同样走这个分支。
- `lv_difdat = p_keydat - lv_datum + 1`，所以总账行固定为 1 天；按 `ASSIGN_FIELD` 的区间逻辑会落入 `lv_difdat <= p1`，即默认 30 天以内的第 1 桶。总账金额不会进入更老的账龄桶。

### 5. 总账金额是否经过 BAPI 货币转换

结论：**是，且本位币和交易币都转换**。

证据：`S610.abap`，`FORM PRO_DATA` 约第 438-442 行，以及 `FORM CURRENCY_CONV_TO_EXTERNAL` 约第 843-853 行。

- 每一条 `gt_bskd`（包括 `tabnam='BSIS'` 的总账行）都执行：
  - `DMBTR` 使用公司本位币 `t001-waers` 调用 BAPI；
  - `WRBTR` 使用行项目交易币 `gt_bskd-waers` 调用 BAPI。
- BAPI 实现文件 `/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/草稿/BAPI_CURRENCY_CONV_TO_EXTERNAL` 第 15-34 行：先查 `TCURX`；查到特殊币种时 `int_shift = 2 - currdec`，查不到时按 2 位小数 `int_shift=0`，最后执行 `amount_external = amount_internal * 10 ** int_shift`。
- 因而：`CURRDEC=0` -> ×100；`CURRDEC=1` -> ×10；`CURRDEC=2` -> ×1；`CURRDEC=3` -> ×0.1。金额变大不是总账专属，而是该统一转换过程导致的。
- `BAPI_CURRENCY_CONV_TO_EXTERNAL` 使用静态缓存 `last_currency/last_int_shift`。在单线程、币种切换正常的情况下可工作；调查文件未显示缓存清空逻辑，若同一 ABAP 内存会话中币种代码或函数全局变量异常复用，也应纳入运行核查，但当前没有运行证据证明这是本次问题。

### 6. `SHKZG` 取负规则

证据：`S610.abap`，`FORM PRO_DATA` 约第 443-449 行。

- 原本按应收/应付分别判断借贷方向的逻辑被注释掉。
- 当前生效规则是：只要 `SHKZG='H'`，所有贷方金额统一将 `DMBTR`、`WRBTR` 乘以 -1；`SHKZG='S'` 保持原符号。
- 因此总账科目也遵循该规则，不存在“应付才取负、应收不取负”的现行差异化处理。若对账端使用了不同的借贷符号约定，净额会对不上。

### 7. 汇总键、重复追加与公司代码循环

证据：`S610.abap`，主流程约第 146-162 行，`FORM PRO_DATA` 约第 450-485 行。

- 主流程先从 `T001` 按 `s_bukrs` 取公司，逐公司执行 `GET_DATA -> PRO_DATA -> GET_DISC -> SAVE_CHECK`；每个公司结束后把 `itab` 追加到 `itab_all`，再清空 `itab`。
- `PRO_DATA` 的汇总键是 `BUKRS + KOART + OBJECT + PRCTR + GSBER + HKONT + WAERS + FILKD`。没有凭证号、会计年度、凭证行、来源表等字段；同一键下的多行会故意合并。
- `OBJECT` 优先取供应商号，其次客户号，否则取总账科目号。因此总账行按 `HKONT` 自身作为客商/对象；这与 SQL 侧通常以客户、客商和科目维度汇总的结果不一定同粒度。
- `DMBTR0/WRBTR0` 先累加全部行，账龄桶再按同一键追加；程序没有发现对 BSIS 与 BSAS 做去重，依靠表本身的未清/已清互斥和日期条件避免重叠。若源数据快照同时重复、或 BSIS/BSAS ODS 复制重复，程序会直接累加。
- `READ TABLE itab WITH KEY` 没有使用二分查找（`BINARY SEARCH` 被注释），但因为是标准表线性查找，当前主要是性能问题，不改变匹配结果。
- 保存时 `SAVE_ZZT003` 按当前公司、科目类型、关键日期先删除 `ZZT003_SAVE` 后批量插入并提交；同一公司重复运行通常不会叠加旧快照，但不同 `KOART`、关键日期或公司代码会形成不同数据集。`itmno` 每个公司循环重新从 1 开始，属于行号局部编号，不应作为金额唯一键。

## 三、与 SQL 侧的口径差异

### 1. DWD 明细 SQL 没有 BSIS/BSAS 总账来源

证据：`/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/dwd_fi_mr_arap_detail_mi.sql`。

- 文件在参数初始化后的注释明确写“仅处理六套 SAP 的 BSID/BSAD/BSIK/BSAK”（约第 30 行附近）。
- CTE 为 `src_bsid`、`src_bsad`、`src_bsik`、`src_bsak`；`unioned_items` 约第 690 行附近仅 `UNION ALL` 这四个 CTE。调查未发现 `src_bsis` 或 `src_bsas`。
- 因此 SQL 侧即使有同名 `hkont` 总账科目，也不会按 S610 ABAP 的 BSIS/BSAS 规则进入 `dwd_fi_mr_arap_detail_mi`。这是当前最强的“总账科目 SQL 与 ZZT003 对不上”解释。
- SQL 的 S610 数据源还使用 `ods.odsslt_s810_bsid/bsad/bsik/bsak` 并限制 `mandt='610'`（例如 BSID 约第 414-419 行、BSAD 约第 470-477 行），应确认这是否是系统对 S610 的正式映射，避免将 S810/S610 标识混淆。

### 2. SQL 侧统驭科目配置与金额转换

- SQL 的 `account_cfg` 同样从 `src_ztzt_003 + src_t001 + src_skb1` 按科目区间匹配，并只保留 `MITKZ IN ('D','K')`，之后 `all_items` 通过 `INNER JOIN account_cfg` 过滤。它本质上只为 BSID/BSAD/BSIK/BSAK 的客商行筛选统驭科目，不会补出 ABAP 的 `MITKZ=''` 总账行。
- SQL 的 S610 金额也有 `TCURX` 转换：`conversion_factor = POW(10, 2-currdec)`，`all_items` 对 S610 `dmbtr/wrbtr`分别按公司本位币/行交易币乘转换因子。这与 ABAP BAPI 的数学规则一致，但 SQL 没有 BSIS/BSAS 所以不能据此证明总账金额一致。
- SQL 的 `items_with_aging_date` 对 AB 凭证、公司级/系统级配置和默认日期计算账龄；它没有 ABAP 中“所有 BSIS/BSAS 统一 `lv_datum=p_keydat`”这一总账特殊规则。即使未来补入 BSIS/BSAS，也必须明确该分支的账龄策略。

### 3. 汇总 SQL 对科目和来源的限制

证据：`dwd_fi_mr_arap_sum_mi.sql`。

- `detail_fact` 只保留明细表中的非零金额，并排除 `acct_map_code IN ('1122000095','2202000095')`，这两个科目改由 XH 应收/应付来源构造（约第 294-354 行）。这不是 `6377/1123030101` 规则，但会导致直接以这两个映射科目对账时出现差异。
- `standard_fact` 将 detail、XH、OVERDUE、样机、SMS、POLICY、WRITEOFF 等九类来源以 `UNION ALL` 合并（约第 1084-1115 行），并保留 `system_src/ods_src`；来源粒度和 S610 程序的 `itab` 粒度不同。
- `D2M` 的 `DWD_STANDARD` 只读取 `DWD_FI_MR_ARAP_SUM_MI`，且要求 `NVL(IS_APAR_FLAG,'Y')='Y'` 和公司在 `SESSION_AZIENDA_LIST`；随后 `ACCT_REC_CODE` 对某些公司/科目重分类，`AGG_FACT` 按完整维度汇总。总账若未进入 DWD，后续 D2M、坏账和校验 SQL 都不会凭空恢复。
- `账龄校验query.sql` 的 2.0 查询只从 `AW_MR9_ARPM02_000001` 按预定义 `COD_CONTO` 汇总，且限定 `COD_CATEGORIA='ZAMOUNT'`；预付账款使用 `1123000000`，应付账款使用 `2202000000`。它不是对原始 S610 BSIS/BSAS 的直接校验，也没有覆盖 `1123030101` 这一原始科目，除非前置映射已经将其转成校验清单中的科目。

## 四、可能导致对不上的原因（按优先级）

1. **最高优先级：比较了不同来源**。ABAP 总账来自 BSIS/BSAS，而 SQL DWD 明细明确只读 BSID/BSAD/BSIK/BSAK，导致 SQL 侧漏掉总账金额。
2. **金额被外部币种格式转换放大**。BAPI 对 `TCURX-CURRDEC` 做幂次换算；需确认 `T001-WAERS` 和每行 `WAERS`，以及 ABAP 运行前后的内部值/外部值。用户所说“10 -> 1000”按数值是 100 倍，对应 `CURRDEC=0` 的典型因子；若确实是 10 倍则对应 `CURRDEC=1`。
3. **`6377/1123030101` 有条件排除**。应付总账仅在 `GSBER` 为空时保留；SQL 未见同等过滤。
4. **账龄桶不同但总额可能相同**。总账行固定进入第 1 桶，SQL 侧使用真实基准日期/账龄规则；若对比的是某个账龄桶而不是 0 桶总额，必然可能不同。
5. **借贷符号口径不同**。ABAP 对所有 `SHKZG='H'` 取负；对账 SQL 或原始总账余额可能按相反方向展示。
6. **科目分类/配置不同**。`ztzt_003` 区间、`SKB1-MITKZ`、`KOART` 和运行模式共同决定总账是否取数；SQL 的 account_cfg 只保留 D/K 统驭科目。
7. **汇总粒度不同或源数据重复**。ABAP 按公司、对象、利润中心、业务范围、科目、币种、分支机构聚合；SQL 后续还包含来源、映射科目及更多维度。ABAP 对 BSIS/BSAS 没有显式去重，ODS 重复会被累加。
8. **公司代码范围/映射不同**。ABAP 逐一读取 `T001` 中 `s_bukrs`；DWM 通过 `SESSION_AZIENDA_LIST`、有效性规则和锁定公司筛选公司。SQL S610 还从 S810 物理表按 `mandt='610'`取数，需确认公司映射。
9. **校验对象不同**。`账龄校验query.sql` 只看 2.0 `AW_MR9_ARPM02` 的 `ZAMOUNT` 和固定标准科目，不等于 `ZZT003_SAVE` 原始总账行；坏账处理还可能经过重分类、FIFO、个别认定和比例计算。

## 五、建议的核查与修复方向（不在本次调查中实施）

1. **先做同口径明细核对**：针对一家公司、一个总账科目、一个关键日期，分别统计 BSIS 和 BSAS：公司、科目、业务范围、利润中心、币种、借贷方向、过账日期、清账日期、原始 `DMBTR/WRBTR`。复现 ABAP 的 `budat <= p_keydat`、`augdt > p_keydat`、`SHKZG='H'` 规则后，再与 ZZT003 的 `DMBTR0/WRBTR0` 比较。
2. **记录 BAPI 转换前后值**：至少提供 `T001-WAERS`、行项目 `WAERS`、`TCURX-CURRDEC`、DMBTR/WRBTR 原始内部值、BAPI 输出值。若希望保存“数据库金额”而非外部显示金额，应评估移除或改造 ABAP 的转换；若 SQL 要复刻 ABAP，则必须使用同一币种小数位规则。
3. **明确总账是否应进入 SQL 账龄**：若应进入，应在 DWD 明细新增独立 BSIS/BSAS 来源，复用相同的关键日、币种、借贷方向和科目配置规则，并明确总账账龄固定进第 1 桶还是按日期计算；同时补充 `6377/1123030101/GSBER` 规则。不要直接把 BSIS/BSAS 混入统驭科目 CTE，以免改变客商账龄口径。
4. **统一科目映射**：确认原始 `1123030101` 是否应映射到校验 SQL 的 `1123000000`，以及 D2M 的 `ACCT_REC_CODE/ACCT_MAP_CODE` 是否应参与对账。对账时同时展示原始科目、映射科目、来源系统和来源表。
5. **检查重复与公司范围**：以凭证唯一键（公司、年度、凭证号、行号、科目）检查 BSIS/BSAS ODS 是否重复；确认 ABAP 的 `s_bukrs` 与 SQL 的 S610 公司列表、`mandt='610'` 映射一致，并排除 DWM 锁定公司差异。

## 六、当前无法从静态代码确认的内容

本次仅做只读静态调查，未连接 SAP/Doris/Oracle 运行环境，无法确认实际哪几行被取出、`TCURX` 实际小数位、ODS 是否重复、配置表实际内容，也无法判断某个具体科目是否落入 `ztzt_003` 区间。要完成定量归因，请提供：

- 公司代码（`BUKRS`）；
- 总账科目（`HKONT`，尤其是否为 `1123030101`）；
- 运行模式：应收/应付（`p_ys` 或 `p_yf`）；
- 关键日期 `p_keydat`，以及凭证日期/过账日期范围；
- 本位币和交易币；
- `SHKZG`、`GSBER`、利润中心；
- BSIS/BSAS 原始 `DMBTR/WRBTR`、ZZT003_SAVE 对应总额和各账龄桶金额；
- SQL 侧对应月份、公司、原始/映射科目和对账数字；
- `TCURX` 中相关币种的 `CURRDEC`。

在这些参数齐全后，才能判断差异是“SQL 漏总账”“币种倍数”“6377 特殊排除”“借贷符号”还是多个因素叠加。