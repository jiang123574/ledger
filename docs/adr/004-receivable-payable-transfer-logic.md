# ADR-004: 应收款/应付款账务逻辑

**日期**: 2026-04-22
**状态**: 已完成
**分支**: fix/reimbursement-transfer-v2

## 背景

应收款（Receivable）和应付款（Payable）的账务处理逻辑存在设计问题：

1. **历史问题**：在 commit `e566996` 中，正确的转账逻辑被错误改回了收入/支出 Entry 逻辑
2. **之前的正确实现**：PR #79 (`30bc50b`) 和清理 commit (`f26194d`) 实现了转账逻辑

### 业务场景差异

| 类型 | 业务含义 | 资金状态 |
|------|----------|----------|
| 应收款 | 垫付后等待报销 | 已支出，等待收回 |
| 应付款 | 待付款的负债 | 未支出，等待付款 |

## 决策

### 应收款（Receivable）逻辑

| 操作 | 实现 | 说明 |
|------|------|------|
| 创建应收款 | 转账（支出账户 → "应收款"系统账户） | 记录垫付，不计入支出统计 |
| 报销 | 转账（"应收款"系统账户 → 报销账户） | 拿回垫付款，不计入收入统计 |

**优势**：
- 垫付和报销都不计入收支统计，避免账务混乱
- "应收款"系统账户余额反映待报销总额（通过 Entry 计算）

### 应付款（Payable）逻辑

| 操作 | 实现 | 说明 |
|------|------|------|
| 创建应付款 | 只保存 Payable，不创建 Entry | 仅记录负债，不影响账务 |
| 还款 | 创建支出 Entry（付款账户） | 真实资金流出，计入支出统计 |

**为什么创建时不创建 Entry**：
- 应付款是"应当支出但尚未支出"的负债记录
- 只有实际付款时才发生资金流出
- 应付款系统账户余额通过 `SystemAccountSyncService` 根据 `Payable.sum(:remaining_amount)` 计算

**为什么还款计入支出统计**：
- 还款是真实的资金流出
- 用户关心"这个月实际花了多少钱"，还款应反映在支出报表中

## 数据结构

### 应收款字段

```ruby
transfer_id              # 创建应收款时的转账ID
reimbursement_transfer_ids # 报销转账IDs数组（支持多次部分报销）
```

### 应付款字段

```ruby
settlement_transfer_ids  # 还款支出Entry IDs数组（支持多次部分还款）
# 注意：transfer_id 字段保留但不再使用
```

## 系统账户余额计算

| 系统账户 | 余额来源 |
|----------|----------|
| 应收款 | `initial_balance = 0`，通过 Entry 转账计算 |
| 应付款 | `initial_balance = -Payable.unsettled.sum(:remaining_amount)` |

## 相关文件

- `app/controllers/receivables_controller.rb`
- `app/controllers/payables_controller.rb`
- `app/models/receivable.rb`
- `app/models/payable.rb`
- `app/services/entry_creation_service.rb`
- `app/services/system_account_sync_service.rb`

## 参考

- 原 PR #79: `30bc50b` - 应收款使用转账逻辑替代收支 Entry
- 清理 commit: `f26194d` - 清理 Receivable 旧逻辑代码