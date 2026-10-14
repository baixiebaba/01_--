# BAPI_CURRENCY_CONV_TO_EXTERNAL 只读分析报告

## 摘要结论

1. **币种为空或未知时，源码不会主动报错，也不会返回 NULL 或 0（除非输入金额本身为空/为 0）**。在正常执行路径中，`SELECT SINGLE ... FROM tcurx WHERE currkey = currency` 查不到记录时，代码将 `int_shift` 设为 `0`，等价于乘数 `10 ** 0 = 1`，因此输出基本等于输入金额。
2. **TCURX 无配置时的默认小数位按 2 位处理，默认乘数为 1**。源码并未真的设置一个“默认小数位”变量，而是通过 `int_shift = 0` 实现二位小数币种不做缩放。
3. **`amount_internal` 为空时，源码没有专门的空值分支**。`MOVE amount_internal TO dec_amount_int` 将其转入数值变量；对 ABAP 数值语义下的初始/空金额，结果为初始数值（通常为 0），最后输出为 `0`。源码不产生 NULL。
4. **不存在 `RETURN` 参数、消息字段、显式异常处理或币种合法性校验**。代码只检查 TCURX 查询的 `sy-subrc`；未知或不合法的币种字符串只要能作为查询条件传入，通常会走“非例外币种、两位小数”的默认路径。若金额输入是无法转换为目标数值类型的非数值内容，可能由 ABAP 类型转换触发运行时错误，但本源码没有捕获或转换该错误。
5. **需要注意 `last_currency` / `last_int_shift` 缓存**：同一函数处理连续相同币种时不再查询 TCURX，而直接复用上次因子；因此严格说，运行时结果还依赖函数全局/静态缓存变量的初始化和生命周期。源码片段没有展示这些变量的声明或初始化，但首次正常使用时其逻辑仍是上述 TCURX 命中/未命中规则。

## 证据与符号定位

### 1. 接口没有 RETURN 或消息参数

在函数接口注释 `FUNCTION bapi_currency_conv_to_external` 的 `Lokale Schnittstelle` 中，只有：

- IMPORTING：`CURRENCY LIKE TCURC-WAERS`、`AMOUNT_INTERNAL`
- EXPORTING：`AMOUNT_EXTERNAL LIKE BAPICURR-BAPICURR`

接口中没有 `RETURN`、`MESSAGE`、`TYPE`、`EXCEPTION` 等参数。文件正文也没有 `RAISING`、`MESSAGE` 或 `CATCH` 语句。因此，源码没有向调用方返回业务错误消息的路径。

### 2. TCURX 命中时的转换因子

在变量声明中定义了：

- `int_shift TYPE i`
- `dec_amount_int LIKE bapicurr-bapicurr`
- `struct_tcurx TYPE tcurx`

主逻辑的首个分支为：

```abap
IF currency NE last_currency.
  SELECT SINGLE * FROM tcurx
                  INTO struct_tcurx
                  WHERE currkey = currency.

  IF sy-subrc = 0. "Currency has a number of decimals not equal two
    int_shift = 2 - struct_tcurx-currdec.
```

当币种在 TCURX 中查到记录时，使用 `currdec` 计算 `int_shift = 2 - currdec`。随后金额处理部分执行：

```abap
amount_external = 10 ** int_shift.
amount_external = amount_external * dec_amount_int.
```

所以实际乘数是 `10 ** (2 - currdec)`。例如 `currdec = 0` 时，因子是 `100`；`currdec = 3` 时，因子是 `0.1`（具体精度还受 ABAP 目标字段类型影响）。

### 3. TCURX 缺失、币种未知或查询不到时的默认行为

紧接 TCURX 查询的是：

```abap
ELSE. "Currency is no exceptional currency. It has two decimals
  int_shift = 0.
ENDIF.
```

这意味着只要 `sy-subrc <> 0`，不区分“标准的两位小数币种”“TCURX 没维护的币种”还是“拼写错误/未知币种”，全部进入同一分支。后续 `10 ** int_shift` 即 `10 ** 0 = 1`，因此金额不缩放。

源码没有查询 TCURC 来验证 `CURRENCY` 是否存在，也没有在 TCURX 查询失败时设置错误、返回空值或将金额改为 0。因此对 SQL 转换逻辑而言，直接对应的默认因子是 **1**，而不是 NULL 或 0。

### 4. 币种为空时的行为及缓存注意事项

源码没有 `IF currency IS INITIAL` 或类似空币种校验。空字符串/初始值会直接参与：

```abap
WHERE currkey = currency.
```

如果该次进入查询且 TCURX 没有空的 `currkey` 记录，按 `sy-subrc <> 0` 进入默认分支，因子为 1，金额保持不变；源码不会产生 NULL 或显式错误。

但币种查询被包在：

```abap
IF currency NE last_currency.
  ...查询并计算 int_shift...
  last_currency = currency.
  last_int_shift = int_shift.
ELSE.
  int_shift = last_int_shift.
ENDIF.
```

如果当前 `currency` 与 `last_currency` 相同，代码跳过 TCURX 查询并使用 `last_int_shift`。因此空币种若恰好与缓存的 `last_currency` 相同，结果取决于此前缓存的 `last_int_shift`；不能仅凭这段函数体证明每次空币种都会重新查询。若变量初始值均为空/0，首次空币种通常仍会得到因子 1。

### 5. `amount_internal` 为空时的行为

金额转换只有两步：

```abap
MOVE amount_internal TO dec_amount_int.
amount_external = 10 ** int_shift.
amount_external = amount_external * dec_amount_int.
```

没有 `IS INITIAL`、NULL 检查、错误返回或默认金额分支。ABAP 内部数值变量不存在数据库 SQL 意义上的 NULL；当输入为空且可按数值初始值处理时，`dec_amount_int` 为初始数值（通常为 0），最后乘以任何合法转换因子后 `amount_external` 为 0。

如果调用方传入的是无法转换为 `BAPICURR`/目标数值格式的非数值文本，`MOVE` 可能触发 ABAP 运行时类型转换错误；该函数没有 `TRY...CATCH` 或异常声明来处理它。因而不能把“任意非法金额文本”概括为必然返回 0，确定能从源码得到的结论是：**空/初始数值按 0 处理；不可转换文本走未处理的运行时错误路径**。

### 6. RETURN、异常和消息字段

全文仅包含函数声明、变量声明、TCURX 查询、缓存赋值、字段移动和乘法计算。未发现：

- `RETURN` 或其他 EXPORTING 消息结构；
- `MESSAGE` 语句；
- `RAISING`、`EXCEPTION`、`CATCH` 或 `TRY`；
- 对 `currency` 合法性的显式校验；
- 对金额转换失败的错误码或 fallback 分支。

因此，TCURX 缺失和币种未知都不是该实现中的错误条件；真正的数据库/类型运行时错误若发生，也不会被本函数转成结构化返回值。

## 结论与对 S610 SQL 的建议

1. 如果 SQL 要复刻这段 BAPI 的正常转换语义，`TCURX` 未命中时应使用默认因子 **1**，并保留原金额的数值结果，而不是把结果置为 NULL 或 0。
2. `TCURX.CURRDEC` 命中时使用因子 `10 ^ (2 - CURRDEC)`；本位币和交易币都可以用同一份币种因子映射，分别以各自币种字段关联。
3. 对 SQL 中的 NULL 金额，建议明确决定是否按 BAPI 的“空/初始数值约等于 0”语义处理：若要严格模拟 ABAP，可在乘法前将 NULL 处理成 0；若业务需要保留源系统缺失语义，则保留 NULL，并在报告/字段说明中标注这不是该 BAPI 的原样语义。
4. 对 NULL/空币种或格式错误的币种，源码本身没有独立错误返回。为了避免 SQL 因关联失败而丢失金额，建议采用“未匹配因子默认 1”的策略，并额外保留可审计的币种缺失/未匹配标识（如果下游允许）。这属于 SQL 侧增强，不是该文件已有行为。
5. **只读范围声明**：本报告仅分析 `/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/草稿/BAPI_CURRENCY_CONV_TO_EXTERNAL`，未修改任何 SQL 文件或草稿文件；除按要求创建本报告外没有进行代码实现、提交或服务重启。
