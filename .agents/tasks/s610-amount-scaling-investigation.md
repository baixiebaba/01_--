# S610 金额保存后放大调查报告

## 摘要结论

代码中确实存在一处会改变金额表现/数值解释的特殊处理：`PRO_DATA` 对从 BSID/BSIK/BSIS/BSAS（以及相应已清表 BSAD/BSAK）读出的本位币 `DMBTR` 和交易币 `WRBTR`，在汇总前分别调用 `BAPI_CURRENCY_CONV_TO_EXTERNAL`，然后把返回值重新写回 `LIKE bsik-dmbtr/wrbtr` 的字段。这个调用不是简单的格式化显示；它按传入币种的货币小数位把 SAP 金额内部格式转换成外部格式。因此，如果后续目标字段仍按 SAP 内部金额接收，或 `ZZT003_SAVE` 的字段数据元素/小数位与该外部值不匹配，就可能出现金额按 10/100/1000 等比例解释的结果。

从静态代码看，`SAVE_ZZT003` 本身没有乘 10、乘 100 或乘 1000 的算术；`MOVE-CORRESPONDING` 和 `INSERT` 也没有显式放大逻辑。最可疑位置是“内部金额 -> 外部格式”转换后又继续作为金额参与汇总并直接写入数据库。仓库内没有找到 `ZZT003_SAVE` 或 `ZTzt_003` 的 DDIC/DDL 定义，所以无法仅凭本仓库确认目标字段的实际数据元素、CURR 小数位和货币参考字段；必须在 SAP 中核查这些元数据及转换前后的运行时值。

另外，用户描述“10 变成 1000”按数学比例实际是 100 倍，不是十倍；报告以下按“出现数量级放大”理解。若用户的原始内部值实际是 100 而显示为 1000，则仍应优先检查同一套转换/小数位问题。

## 证据与金额链路

### 1. 源表读取

文件：`/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/草稿/S610.abap`

- 第 27-57 行定义中间行结构 `gt_bskd`；`dmbtr LIKE bsik-dmbtr` 注释为本位币金额，`wrbtr LIKE bsik-wrbtr` 为交易币金额，`waers LIKE bsik-waers` 为交易币种。
- 第 152-161 行按公司代码循环，每个公司执行 `GET_DATA`、`PRO_DATA`、保存和清空 `itab`。
- 第 295-301 行：应收选择动态表 `BSID`，供应商选择动态表 `BSIK`，并分别设置 `g_koart = 'D'/'K'`。
- 第 312-326 行：从动态表读取 `budat <= p_keydat` 的行，使用 `APPENDING CORRESPONDING FIELDS OF TABLE gt_bskd`。
- 第 328-341 行：把表名第三字符改为 `A`，即 `BSID -> BSAD` 或 `BSIK -> BSAK`，追加清账日期大于关键日期的记录。
- 第 344-374 行：非统驭科目从 `BSIS` 和 `BSAS` 读取；第 376-386 行把这些行追加到 `gt_bskd`，并标记 `tabnam = 'BSIS'`。

这条链路没有看到金额字段上的乘法或除法。`SELECT *` 配合 `CORRESPONDING FIELDS` 会把源表金额放入 `gt_bskd-dmbtr/wrbtr`，其字段类型来自 `BSIK` 的同名字段（客户表字段也按同一结构接收）。

### 2. 货币转换发生在汇总之前

文件同上，`FORM pro_data`：

- 第 446-457 行计算账龄日期；这部分只决定金额进入哪个账龄桶，不改变金额数值。
- 第 459-462 行：

```abap
PERFORM currency_conv_to_external USING t001-waers
                                  CHANGING gt_bskd-dmbtr.
PERFORM currency_conv_to_external USING gt_bskd-waers
                                  CHANGING gt_bskd-wrbtr.
```

本位币使用公司代码 `T001-WAERS`，交易币使用源行 `WAERS`。两个字段都在进入汇总前被改写。

- 第 465-469 行：`SHKZG = 'H'` 时，将两个已经转换过的金额取负；这是正负号处理，不会造成正数数量级放大。
- 第 471-490 行：按公司、科目类型、客商/科目、利润中心、业务范围、科目、交易币和分支机构等键查找 `itab`；新行或已有行都执行 `dmbtr0/wrbtr0` 累加，并调用 `ASSIGN_FIELD`。
- `ASSIGN_FIELD`（第 497 行起）把同一转换后的金额累加到 `dmbtr1...dmbtr9`、`wrbtr1...wrbtr9` 对应账龄段。因转换发生在循环内，所有桶和合计使用的都是转换后的值。

### 3. 转换函数的具体实现

文件同上，约第 843-855 行，`FORM currency_conv_to_external`：

```abap
FORM currency_conv_to_external  USING    p_waers
                                CHANGING p_dmbtr.
  DATA: lv_amount LIKE bapicurr-bapicurr.
  CALL FUNCTION 'BAPI_CURRENCY_CONV_TO_EXTERNAL'
    EXPORTING
      currency        = p_waers
      amount_internal = p_dmbtr
    IMPORTING
      amount_external = lv_amount.
  p_dmbtr = lv_amount.
ENDFORM.
```

该函数名明确表示“内部金额转外部金额”。它使用 `currency` 的货币小数位规则处理 `amount_internal`，返回外部表示，再通过 `p_dmbtr = lv_amount` 写回原来类似 `BSIK-DMBTR/WRBTR` 的金额字段。这里没有显式检查返回参数、异常或转换前后值，也没有区分“供显示的外部字符串”和“供数据库计算/存储的内部金额”。

这是最值得优先验证的代码缺陷：外部格式值在后续又被用于 ABAP 数值累加，并经 `MOVE-CORRESPONDING` 写入一个未知 DDIC 定义的目标表。如果外部值与目标字段的隐含小数位不一致，结果可能是数据库中实际值放大，也可能只是 SE16/SQL/下游程序按另一套小数位显示后看起来放大。

### 4. 汇总及保存没有显式倍增

文件同上：

- 第 471-490 行每个源行最多对当前分组累加一次 `dmbtr/wrbtr`，并同时写入一个账龄段。
- 第 152-161 行每个公司只调用一次 `GET_DATA` 和 `PRO_DATA`；`PRO_DATA` 末尾第 491-493 行 `FREE:gt_bskd`，循环结束第 158-160 行 `APPEND LINES OF itab TO itab_all` 后 `FREE:itab`。
- 第 820-838 行 `FORM save_zzt003`：循环 `itab`，第 825 行 `MOVE-CORRESPONDING itab TO lt_zzt003`，补充行号、关键日期、创建审计字段，第 834 行按公司/科目类型/关键日期删除旧记录，第 836 行批量 `INSERT zzt003_save FROM TABLE lt_zzt003`。

`MOVE-CORRESPONDING` 只按同名字段搬运，不包含金额乘法；`INSERT` 也没有金额表达式。因此保存例程不是最可能的“乘十”位置。需要注意的是，ABAP 赋值在不同 packed/DEC/CURR 字段之间仍可能受到字段长度和小数位定义影响，所以不能在目标 DDIC 定义缺失时断言“赋值绝对不会改变数值解释”。

### 5. 仓库中可见的相关表结构线索及其限制

仓库没有找到 `ZZT003_SAVE` 或 `ZTzt_003` 的 DDIC 导出、建表 SQL 或数据元素定义。唯一可见的相似草稿表定义是：

`/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/草稿/账龄-workbuddy.sql` 第 30-50 行，把 `dmbtr0...dmbtr9`、`wrbtr0...wrbtr9` 定义为 `DECIMAL(23,2)`。这不是 SAP 的 `ZZT003_SAVE` 定义，不能作为目标表的事实；它只能说明下游/草稿设计倾向于两位小数。

同一草稿第 5-6 项说明 SAP 原表金额及目标表处理，但未提供 SAP DDIC 的域、数据元素或货币参考字段。仓库 SQL 也不能证明 SAP 运行时 `BAPI_CURRENCY_CONV_TO_EXTERNAL` 的金额参数和 `ZZT003_SAVE` 字段之间的实际小数位关系。

## 最可能根因排序

1. **误用 `BAPI_CURRENCY_CONV_TO_EXTERNAL` 造成内部/外部金额格式错配（最高可能）。** 代码在汇总前对每一行调用该函数，并把外部结果写回金额字段；如果目标仍期待内部金额，或外部值再次被按 CURR 的隐含小数位解释，会产生数量级差异。放大倍数取决于币种小数位配置以及源/目标字段定义，不能仅凭源码确定是 10、100 还是 1000。
2. **`ZZT003_SAVE` 金额字段的数据元素/小数位或货币参考字段不匹配（同样很可能）。** `MOVE-CORRESPONDING` 不会自动根据 `WAERS` 为每一个金额字段选择正确的小数位；需要检查 `DMBTR*` 是否引用本位币字段/数据元素、`WRBTR*` 是否引用交易币字段/数据元素，以及目标字段是否为 `CURR`、`DEC` 或字符型。若数据库管理工具直接显示原始 packed/decimal 值，也可能把“内部整数”当成带两位/三位小数的外部值，形成假象。
3. **源表重复取数或业务上多行汇总（中低可能，但必须用运行数据排除）。** 程序有意将未清表与已清表按关键日期组合，也将 BSIS 与 BSAS 组合；正常情况下这些表代表不同状态，不应重复同一行。分组键又包含 `waers`、`filkd` 等字段，重复的源凭证行会被累计到 `dmbtr0`/账龄桶。静态阅读不能替用户数据排除重复，应核对凭证主键和每次 SELECT 的行数。
4. **正负号逻辑（不是放大原因）。** 只有 `SHKZG = 'H'` 时取负，没有正数倍增；它可能导致余额方向与预期相反，但不会把 10 变成 1000。
5. **ALV/下游显示小数位解释（可能是假放大）。** ALV 字段目录仅设置金额字段的参考表/字段（例如第 642 行起 `DMBTR*` 参考 `BSIK-DMBTR`，第 661 行起 `WRBTR*` 参考 `BSIK-WRBTR`），未设置 `CFIELDNAME`；而且被保存的 `itab` 数值已经经过外部转换。显示端、SE16、接口或数仓若采用不同的小数位规则，可能只表现为显示放大而非数据库实际值改变。

## 需要在 SAP 中核查的项目

1. 在 SE11/SE16N 分别查看 `BSIK-DMBTR`、`BSIK-WRBTR`、`BSID` 对应字段、`T001-WAERS`、源行 `WAERS` 的数据元素、域类型、长度、小数位，以及货币字段参考关系。
2. 查看 `ZZT003_SAVE` 的完整字段定义：`DMBTR0...DMBTR9`、`WRBTR0...WRBTR9` 的数据元素/域、ABAP 类型（尤其 `CURR`/`DEC`/字符）、长度和小数位；检查本位币金额是否引用 `HWAER`，交易币金额是否引用 `WAERS`。同时核查 `ZTzt_003` 配置表仅用于科目范围，不要误把其定义当成保存表定义。
3. 在 SE37 或 ABAP 调试器中用同一实际凭证断点观察：
   - `GET_DATA` 完成后 `gt_bskd-dmbtr/wrbtr` 的值和币种；
   - 第一次 `PERFORM currency_conv_to_external` 前后值；
   - `lv_amount` 的值和类型；
   - `PRO_DATA` 汇总后 `itab-dmbtr0/wrbtr0` 及对应账龄桶；
   - `MOVE-CORRESPONDING` 后 `lt_zzt003-dmbtr*/wrbtr*`；
   - `INSERT` 后用 SE16N/SQL 查询的内部值和前端显示值。
4. 对发生问题的凭证核查 `BUKRS` 本位币、`WAERS` 交易币及 SAP 金额字段实际小数位。特别确认问题是否只发生于特定币种；若只发生于某币种，强烈支持货币小数位/外部转换假设。
5. 用凭证唯一键（至少 `BUKRS`、客商、`BELNR`、`GJAHR`、`BUZEI`、`HKONT`、来源表）分别统计 BSID/BSAD、BSIK/BSAK、BSIS/BSAS 的命中行，确认同一行是否被多个 SELECT 追加；同时检查是否一次选择了多个公司代码导致比较时误把不同公司合计在一起。
6. 查询数据库存储的原始值时不要只看前端格式化结果：同时使用 ABAP/SE16N 的 DDIC 格式和数据库原始查询结果对照，并记录货币字段参考。用户口述的“10 -> 1000”应明确是哪个字段、哪种查看工具、哪种币种和哪一层值。

## 最小修复建议（仅建议，不在本次调查中实施）

首选方案是删除 `PRO_DATA` 中面向数据库金额的两次 `BAPI_CURRENCY_CONV_TO_EXTERNAL` 调用，让 `gt_bskd-dmbtr/wrbtr` 保持 SAP 内部金额语义，直接在内部格式中取负、汇总并写入与源字段小数位一致的目标字段；仅在 ALV/文本输出边界另行做外部格式转换。目标表金额字段应使用与业务币种一致、明确小数位的 DDIC 数据元素，并正确维护货币参考字段。

若业务确实要求保存外部格式，则不要把外部格式重新写回 `LIKE bsik-dmbtr/wrbtr` 并继续数值累加；应将外部结果保存到明确的字符/外部金额字段，或在写库前明确执行一次、可验证的格式到数值转换。修复前应先用调试器记录转换前、转换后、汇总后、`MOVE-CORRESPONDING` 后和数据库读取后的五组值，避免把真实的 SAP 内部金额转换成错误的倍数。

此外，修复后应增加最小回归验证：选取一条 `BSID`/`BSIK` 行和一条 `BSIS`/`BSAS` 行，分别覆盖 `SHKZG = 'S'/'H'` 及至少两种不同货币小数位；确认保存前后金额绝对值、符号、账龄桶和合计均符合预期，并确认同一凭证没有重复累计。

## 验证限制

本次仅进行静态只读调查，仓库不包含 SAP ABAP 运行环境、SAP DDIC 元数据或可连接的 `ZZT003_SAVE` 数据库，因此无法执行 ABAP、调用实际 BAPI 或直接证明数据库中“实际数值”与“显示值”的差异。上述关于 `BAPI_CURRENCY_CONV_TO_EXTERNAL` 的风险判断基于调用名称、参数方向、代码位置和 SAP 金额字段使用方式；最终倍数必须通过 SAP 字典检查和调试器前后值确认。
