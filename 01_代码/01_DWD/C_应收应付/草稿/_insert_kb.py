# -*- coding: utf-8 -*-
KB = '/Users/zhouhong/Documents/01_TA工作/01_海信/99_AI/数据字典与ER关系知识库.md'
FRAG = '/Users/zhouhong/Documents/01_TA工作/01_海信/01_代码/01_DWD/C_应收应付/草稿/_arpm_dict.md'

with open(KB, encoding='utf-8') as f:
    kb = f.read()
with open(FRAG, encoding='utf-8') as f:
    frag = f.read().rstrip() + '\n'

anchor = '### AW_MR8_* — S层汇总表（9张）'
assert kb.count(anchor) == 1, '锚点异常'
assert 'AW_MR9_ARPM01_000001' not in kb, '已存在，避免重复插入'

# 1) 插入正文
kb = kb.replace(anchor, frag + '\n\n' + anchor, 1)

# 2) 章节计数 21 -> 23
old_sec = '### AW_MR9_* — M层明细表（21张）'
assert kb.count(old_sec) == 1
kb = kb.replace(old_sec, '### AW_MR9_* — M层明细表（23张）', 1)

old_dir = '- [AW_MR9_* — M层明细表（21张）](#aw_mr9_-m层明细表)'
assert kb.count(old_dir) == 1
kb = kb.replace(old_dir, '- [AW_MR9_* — M层明细表（23张）](#aw_mr9_-m层明细表)', 1)

old_h1 = '### 一、02_单体收入成本(D2M/M2M)（185张表）'
assert kb.count(old_h1) == 1
kb = kb.replace(old_h1, '### 一、02_单体收入成本(D2M/M2M)（187张表）', 1)

# 3) 更新头
old_upd = '> 更新时间: 2026-09-16（读取最新应收应付 Detail、Sum、客户账期和 SMS 返利余额脚本及建表语句，补充 SMS 余额表并修订 Sum 最新来源与执行口径）'
assert kb.count(old_upd) == 1
new_upd = ('> 更新时间: 2026-09-24（依据《经分二期-应收-数据模型详细设计文档》新增 AW_MR9_ARPM01_000001 往来账龄计算底稿'
           '与 AW_MR9_ARPM02_000001 往来账龄结果表两张 DWM 层 M 表数据字典，字段取数规则含 STEP2 进数范围限制与 STEP3 重分类处理补充）\n'
           + old_upd)
kb = kb.replace(old_upd, new_upd, 1)

with open(KB, 'w', encoding='utf-8') as f:
    f.write(kb)

print('插入完成')
print('新增字符:', len(frag))
print('文件总行数:', kb.count('\n') + 1)
