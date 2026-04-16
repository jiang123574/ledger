# ADR-001: Entry 模型迁移（Transaction → Entry）

**日期**: 2026-04-11
**状态**: 已完成
**PR**: #88

## 背景

项目最初使用 `Transaction` 模型作为核心数据模型。随着业务需求扩展（应收/应付、转账、附件等），单一 Transaction 模型难以承载多态关联，代码复杂度不断增加。

## 决策

将系统从 `Transaction` 模型迁移到 `Entry` 多态体系：

- `Entry` 作为核心记录表，包含通用字段（金额、日期、账户、备注）
- `Entryable::*` 作为多态子类型（Transaction, Transfer, Adjustment 等）
- `Entryable::Transaction` 替代原 `Transaction` 模型

## 影响

### 正面
- 支持多种交易类型，扩展性好
- 统一的余额计算逻辑
- 更清晰的关注点分离

### 代价
- 需要数据迁移（已完成）
- 旧 `transactions` 表已删除
- `source_transaction_id` 过渡字段已移除

## 相关文件

- `app/models/entry.rb`
- `app/models/entryable/transaction.rb`
- `db/migrate/20260401100000_migrate_transactions_to_entries.rb`
