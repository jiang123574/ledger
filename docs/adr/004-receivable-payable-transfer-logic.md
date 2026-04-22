# ADR-004: 应收款/应付款转账逻辑

**日期**: 2026-04-22
**状态**: 已完成
**分支**: fix/reimbursement-transfer-v2

## 背景

应收款（Receivable）和应付款（Payable）的账务处理逻辑存在设计问题：

1. **历史问题**：在 commit `e566996` 中，正确的转账逻辑被错误改回了收入/支出 Entry 逻辑
2. **之前的正确实现**：PR #79 (`30bc50b`) 和清理 commit (`f26194d`) 实现了转账逻辑

### 原错误逻辑

| 操作 | 实现 | 问题 |
|------|------|------|
| 创建应收款 | 创建支出 Entry | 计入支出统计，但实际没花钱 |
| 报销应收款 | 创建收入 Entry | 计入收入统计，但只是拿回垫付款 |

| 操作 | 实现 | 问题 |
|------|------|------|
| 创建应付款 | 创建收入 Entry | 不合理，应付是负债 |
| 还款 | 创建支出 Entry | 合理，但与创建逻辑不对称 |

## 决策

### 应收款（Receivable）逻辑

| 操作 | 实现 | 说明 |
|------|------|------|
| 创建应收款 | 转账（支出账户 → "应收款"系统账户） | 记录垫付，不计入支出 |
| 报销 | 转账（"应收款"系统账户 → 报销账户） | 拿回垫付款，不计入收入 |

**优势**：
- 垫付和报销都不计入收支统计，避免账务混乱
- "应收款"系统账户余额反映待报销总额

### 应付款（Payable）逻辑

| 操作 | 实现 | 说明 |
|------|------|------|
| 创建应付款 | 转账（"应付款"系统账户 → 目标账户） | 记录负债，不计入支出 |
| 还款 | 支出 Entry + 收入 Entry（应付款系统账户） | 实际付款计入支出统计 |

**还款为什么计入支出**：
- 还款是真实的资金流出，应反映在支出报表中
- 支出 Entry 在付款账户，收入 Entry 在应付款系统账户（减少负债）

**为什么不使用 transfer_id 关联还款的两条 Entry**：
- 转账在报表中被 `non_transfers` 过滤，不计入统计
- 还款需要计入支出统计，所以使用两条独立的 Entry

## 数据结构

### 应收款新增字段

```ruby
transfer_id              # 创建应收款时的转账ID
reimbursement_transfer_ids # 报销转账IDs数组（支持多次部分报销）
```

### 应付款新增字段

```ruby
transfer_id              # 创建应付款时的转账ID
settlement_transfer_ids  # 还款Entry IDs数组（支持多次部分还款）
```

## 相关文件

- `app/controllers/receivables_controller.rb`
- `app/controllers/payables_controller.rb`
- `app/models/receivable.rb`
- `app/models/payable.rb`
- `app/services/entry_creation_service.rb`
- `db/migrate/20260422122231_add_transfer_fields_to_payables.rb`

## 参考

- 原 PR #79: `30bc50b` - 应收款使用转账逻辑替代收支 Entry
- 清理 commit: `f26194d` - 清理 Receivable 旧逻辑代码