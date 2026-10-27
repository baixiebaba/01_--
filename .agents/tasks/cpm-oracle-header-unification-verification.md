# CPM Oracle 过程头统一验证记录

## 范围与约束

- 执行范围：`01_代码/02_DWM/C_应收应付` 下的六个指定 `CPM_SP_*.sql` 文件。
- 仅替换各过程 `) AS` 后、首个变量声明 `V_SCENARIO` 前的 `/**** ... */` 文件头；未修改过程声明、变量、PL/SQL、动态 SQL 或业务逻辑。
- 未创建 Git commit，未使用 Git worktree。
- 执行前审查结论文件 `cpm-oracle-header-unification-review.json` 不存在；完成实现后的复查仍不存在，当前为首轮整理，尚未达到 `verdict=APPROVED` 的停止合同。

## 逐文件结果

| 文件 | 处理结果 | 本轮修改标识 | 待确认项 |
| --- | --- | --- | --- |
| `CPM_SP_D2M_ARP_M_PHASE2.sql` | 统一为 `/**** ... */`，名称修正为过程声明的完整 `_PHASE2` 名，使用“功能描述”和统一栏目顺序；完整保留既有六条历史。 | `ALTER BY 20261027 18:28 SHIQINGFENG.EX 统一Oracle过程头格式，未修改业务主体。` | 创建日期。 |
| `CPM_SP_M2M_ARP_AG_M_PHASE2.sql` | 统一边界、栏目和历史布局；完整保留既有十条历史。 | `ALTER BY 20261027 18:28 SHIQINGFENG.EX 统一Oracle过程头格式，未修改业务主体。` | 创建日期。 |
| `CPM_SP_M2M_ARP_BD_M_PHASE2.sql` | 统一边界、栏目和历史布局；完整保留既有十八条历史。首次精确替换未命中后，重新读取实际头部并以独立时分完成编辑。 | `ALTER BY 20261027 18:30 SHIQINGFENG.EX 统一Oracle过程头格式，未修改业务主体。` | 创建日期。 |
| `CPM_SP_M2M_ARP_INS_M_PHASE2.sql` | 统一边界、栏目和历史布局；保留两条原始历史及其原有的无时分形式。 | `ALTER BY 20261027 18:28 SHIQINGFENG.EX 统一Oracle过程头格式，未修改业务主体。` | 创建日期。 |
| `CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` | 因“每个过程”均需创建日期待确认字段且需统一 `/**** ... */` 边界，作最小头部整理；完整保留五条既有历史。 | `ALTER BY 20261027 18:32 SHIQINGFENG.EX 统一Oracle过程头格式，未修改业务主体。` | 创建日期。 |
| `CPM_SP_S2S_TDAYS_M_PHASE2.sql` | 统一栏目、历史布局和边界；原头两段说明未提供可核验的日期、时分、作者或完整历史，已逐字保留其说明内容并明确标识为“待确认”。 | `ALTER BY 20261027 18:28 SHIQINGFENG.EX 统一Oracle过程头格式，未修改业务主体。` | 创建日期；原“本次修改”及“上次修改”的日期、时分、作者和完整历史。 |

## 验证命令与结果

1. 编辑前、后均对从首个 `V_SCENARIO` 变量声明至文件末尾的主体执行同一 SHA-256 命令：

   ```zsh
   for f in <六个目标文件>; do
     awk '/^[[:space:]]*V_SCENARIO[[:space:]]/{p=1} p{print}' "$f" | shasum -a 256
   done
   ```

   编辑后哈希与编辑前逐文件一致：

   | 文件 | SHA-256 |
   | --- | --- |
   | `CPM_SP_D2M_ARP_M_PHASE2.sql` | `8f5dd609e67778091537462a22c6f2432dc06e9a73744c43e7448e28107c4710` |
   | `CPM_SP_M2M_ARP_AG_M_PHASE2.sql` | `a2640a405ec3f1f8f254fd687e84d496c1dfb476271cdd0947ce04e470345015` |
   | `CPM_SP_M2M_ARP_BD_M_PHASE2.sql` | `86e26f871db026cfb5151f7ab7c6e6adcc57369399cee9087ebbd3dd2000f7c8` |
   | `CPM_SP_M2M_ARP_INS_M_PHASE2.sql` | `28d9f45dc78bd14d1070af53f2804bff137d8a102e78ab1ec6ad7760747a7416` |
   | `CPM_SP_M2M_ARP_TOV_M_PHASE2.sql` | `0d1843f856a1daf34dd30da0b103026ba4095e4b7b57c42e9a0a114e5939d831` |
   | `CPM_SP_S2S_TDAYS_M_PHASE2.sql` | `decc282f1a9b78502ab6a3fd3cf82b81889c6e24cfa4d74b0833ede1300e36f8` |

2. 使用 Python 对每份文件检查 `/****` 起始、九个栏目顺序（最后更新时间、本次修改、上次修改、名称、功能描述、源表、目标表、创建日期、修改历史），结果均为 `header_boundary=True; fields_ordered=True`。

3. 使用以下命令检查过程声明仍存在且名称未变：

   ```zsh
   grep -H "CREATE OR REPLACE PROCEDURE" <六个目标文件>
   ```

   六个声明均存在，分别为 `CPM_SP_D2M_ARP_M_PHASE2`、`CPM_SP_M2M_ARP_AG_M_PHASE2`、`CPM_SP_M2M_ARP_BD_M_PHASE2`、`CPM_SP_M2M_ARP_INS_M_PHASE2`、`CPM_SP_M2M_ARP_TOV_M_PHASE2`、`CPM_SP_S2S_TDAYS_M_PHASE2`。

4. 执行：

   ```zsh
   git diff --check -- <六个目标文件>
   ```

   结果：退出码 `0`，无空白错误。

5. 执行：

   ```zsh
   git diff --unified=0 -- <六个目标文件>
   ```

   结果：可见本轮文件头 hunk；工作区在本任务开始前已存在 D2M、AG、BD、TOV 的业务改动，因此该 Git 对比还包含已有未提交内容。主体 SHA-256 前后完全一致，证明本轮未新增任何文件头之外的代码改动。

## 未执行项

工作区未发现项目定义的构建或测试命令，且未提供 Oracle 非生产编译连接；因此未执行数据库 `ALTER PROCEDURE ... COMPILE`。文本结构、过程声明、主体哈希和空白检查均已完成。
