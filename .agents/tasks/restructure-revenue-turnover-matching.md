# CPM_SP_M2S_ARP_TOV_M_PHASE2 重构报告

## 本次修改范围

仅修改 `01_代码/03_DWS/C_应收应付/CPM_SP_M2S_ARP_TOV_M_PHASE2.sql`。未修改参考过程、其他业务过程或 DWD 来源过程；未创建 Git commit；未执行数据库验证。

## 收入与周转匹配

- `TURNOVER` 先合并并汇总 ARPM02 与 IMOCC，保留匹配前的周转输出维度及 `COD_CATEGORIA`。
- `REVENUE_MATCH_KEY` 按 `COD_SCENARIO`、`COD_PERIODO`、`COD_AZIENDA`、`CUST_CODE`、`COD_DEST2`、`COD_CATEGORIA` 汇总收入金额。
- `MATCHED` 按上述键将 `REV_AMT` 写入周转行，输出维度完全来自周转行。
- `UNMATCHED_REVENUE` 仅在不存在同一匹配键的周转数据时追加收入自身维度行；REV 的 DEST3 国家名称映射仅在此类收入行中保留。
- 场景、期间、类别均在匹配键中，避免 `ZAMOUNT` 与 `ZAMOUNT_L2`、跨场景或跨期间误匹配。

## D_BG 后置映射

`MAPPED_FACT` 位于已匹配周转、未匹配收入、CPRS 三类数据合并之后。其映射顺序为：

1. `AW_RUL_PCRMAP_000001`：利润中心 (`COD_DEST2`) + 公司；
2. `AW_RUL_ATSMAP_000001`：公司兜底；
3. `ZZZZ`：未命中兜底。

PCRMAP、ATSMAP 的有效期和 `P_BG`（`ALL` 或逗号多选）条件均置于自身 CTE 的 `WHERE`；未将这些限制写入最终映射 JOIN 条件。`AW_RUL_DWMCRS_000001` 保持原有公司范围及锁定逻辑。

## 负 AR_AMT 过滤分区

`MULTI_BG_TURNOVER` 的判断分区为：`COD_SCENARIO`、`COD_PERIODO`、`COD_AZIENDA`、`CUST_CODE`、`COD_CATEGORIA`。同一分区存在多个 `D_BG` 时，`FILTERED_FACT` 排除 `AR_AMT < 0` 的行；仅一个事业部的负数行保留。保留 `COD_CATEGORIA` 以隔离 `ZAMOUNT` 与 `ZAMOUNT_L2`。

## 未确认项

当前资料未明确：同一“公司 + 客商 + 利润中心 + 场景 + 期间 + 类别”存在多条不同周转输出维度时，收入是否需按特定规则分摊。当前实现沿用用户指定的核心匹配键：匹配到的收入写入每条匹配周转维度行；如源数据该匹配键并非唯一，需要业务方补充分摊/唯一化规则后再调整。

## 静态核对项

目标 INSERT 保留顺序一致的 34 个业务字段，并额外写入 `OID = NEWID()`、`PROVENIENZA`、`DATEUPD`、`USERUPD`。删除仍按 `PROVENIENZA` 隔离。已按要求进行静态检查，不执行数据库验证。
