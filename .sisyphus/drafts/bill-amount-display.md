# Draft: 账单金额醒目显示

## Requirements (confirmed)
- 用户需求：给每期账单算出账单金额，更醒目地显示
- 账单金额定义：消费金额 (spend_amount) - 该期账单周期内的消费总额
- 当前已有数据：后端已返回 spend_amount, repay_amount, balance_due

## Technical Decisions
- 在账单卡片标题下方新增醒目的账单金额显示
- 使用更大字体 (text-lg) 和醒目颜色 (text-expense)
- 简化原有显示：消费金额已醒目显示，底部只显示还款金额和笔数统计

## Implementation Plan
- 修改文件：app/views/accounts/index.html.erb
- 修改函数：renderBillCards (约第 2531-2544 行)
- 具体变更：
  1. 在卡片标题后新增醒目账单金额行
  2. 底部简化为还款金额和笔数统计

## Open Questions
- 无（需求明确）

## Scope Boundaries
- INCLUDE：账单卡片显示优化
- EXCLUDE：后端数据修改（已有数据）