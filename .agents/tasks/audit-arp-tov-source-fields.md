# CPM_SP_M2S_ARP_TOV_M_PHASE2 来源字段审计报告

## 本次调整范围

已修改 `01_代码/03_DWS/C_应收应付/CPM_SP_M2S_ARP_TOV_M_PHASE2.sql` 的目标接口和完整事实加工链路，移除 `COUNTRY_CODE`。目标 `AW_MR8_ARPS01_000001` 的 INSERT 接口由 37 列调整为 36 列（25 个维度/属性列、10 个金额列和 `PROVENIENZA`）。

`COUNTRY_CODE` 已从 INSERT 目标列、ARPM02/IMOCC/REV/CPRS 四个事实来源、`SOURCE_FACT` 四段 UNION ALL、`NORMALIZED_FACT`、最终 SELECT 和 GROUP BY 中删除；目标过程内该字段出现次数为 0。

## COUNTRY_NAME 来源口径

| 来源 | COUNTRY_NAME 处理 |
| --- | --- |
| `ARPM02_FACT` | 直接取 `A.COUNTRY_NAME`，规范化层以 `NVL` 回退 `'ZZZZ'`。 |
| `IMOCC_FACT` | 直接取 `I.COUNTRY_NAME`，规范化层以 `NVL` 回退 `'ZZZZ'`。 |
| `REV_FACT` | 仅该来源左关联 `TGK_FIMA_HISENSE.DEST3_GERARCHIA_FLAT`：`R.COD_DEST3 = DEST3_GERARCHIA_FLAT.COD_DEST3` 且 `COD_DEST3_GERARCHIA = '01'`；名称取 `NVL(NVL(DESC_DEST3_ELEGER3, DESC_DEST3_ELEGER4), DESC_DEST3_ELEGER5)`，最外层 `NVL` 未命中回退 `'ZZZZ'`。 |
| `CPRS_FACT` | 固定 `'ZZZZ'`。 |

知识库副本 `98_临时存/kbdata_副本.json` 登记了真实对象 `TGK_FIMA_HISENSE.DEST3_GERARCHIA_FLAT`，以及 `COD_DEST3`、`COD_DEST3_GERARCHIA`、`DESC_DEST3_ELEGER3`、`DESC_DEST3_ELEGER4`、`DESC_DEST3_ELEGER5` 字段，作为 REV 映射对象和字段证据。

## 已移除的无效国家依赖

此前仅供国家字段使用的 `DIM_FI_MR_CUSTOMER_MAP_DD` / `DIM_FI_MR_CUSTOMER_DD` 客商国家映射 CTE 及其 REV JOIN 已删除。`CUSTOMER_CC_MAP` 仍用于 `D_CC_CUSTGRP`，因此保留。

## 保持不变的逻辑

- 会话公司范围与 `P_BG` 过滤保持不变。
- ARPM02 的利润中心优先、账套事业部回退映射保持不变。
- REV 的 `COD_DEST2`、`D_BG`、`D_TOV_CHAN`、`D_CC_CUSTGRP`、`GRP_SCOPE` 和收入金额汇率换算保持不变。
- 四来源 `UNION ALL`、`ZAMOUNT`/`ZAMOUNT_L2`、来源先过滤再关联、D_/COD_ 默认值及最终按目标粒度 SUM 保持不变。
- 全过程 `SELECT *` 出现次数为 0。

## 验证

- 已重新读取目标 SQL，核对 36 列 INSERT、四来源接口、四段 UNION ALL、最终 SELECT 与 GROUP BY 的列顺序一致。
- 已核对 DEST3 JOIN、`COD_DEST3_GERARCHIA = '01'` 和三级描述回退只出现在 `REV_FACT`。
- 已执行 `git diff --check`；未执行数据库验证，符合本次任务要求。
