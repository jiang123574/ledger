# P3 第二期：Transaction 代码清理和完整迁移

## 概述

P3 第二期专注于完成从 Transaction 模型到 Entry 模型的全面迁移，并清理遗留的 Transaction 相关代码。

## 实施步骤

### 1. 数据迁移层 ✅
- 创建迁移脚本：20260406180000_complete_receivables_payables_migration_to_entry.rb
- 将所有 Receivable.source_transaction_id → source_entry_id
- 将所有 Payable.source_transaction_id → source_entry_id
- 验证迁移完整性

### 2. 模型兼容层 ✅
添加到 Receivable/Payable 模型：
- `source_transaction_or_entry()` - 优先返回 Entry，回退到 Transaction
- `source_amount()` - 从源交易获取金额
- `source_date()` - 从源交易获取日期  
- `ensure_entry_reference()` - 自动同步 source_entry_id

### 3. 控制器更新 (进行中)
需要更新的控制器：
- receivables_controller.rb - 在创建/更新时保存 source_entry_id
- payables_controller.rb - 在创建/更新时保存 source_entry_id

### 4. 视图和模板更新 (进行中)
- 评估是否需要更新显示层

### 5. 测试补充 (进行中)
- 添加 Receivable/Payable 与 Entry 的集成测试
- 验证兼容性方法工作正常
- 测试数据迁移脚本

## 关键决策

### 向后兼容性
系统采用"双轨制"设计：
1. **迁移期间**: 所有模型同时支持旧 (Transaction) 和新 (Entry) 关系
2. **查询时**: 优先使用 Entry，自动回退到 Transaction
3. **创建时**: 只保存 Entry 关联，但也接受 transaction_id 参数并自动转换

### 时间线

**第一阶段** (已完成):
- Schema 迁移准备就绪
- 模型关联已添加
- Rake 任务框架完成

**第二阶段** (进行中):
- 兼容性方法添加 ✅
- 数据迁移脚本准备 ✅
- 控制器更新 (进行中)

**第三阶段** (待完成):
- 测试覆盖补充
- 文档完善
- 发布和监控

## 迁移验证

运行以下命令验证迁移进度：

```bash
# 直接运行迁移
rails db:migrate

# 验证迁移状态
rails migrate_to_entry:verify_all

# 检查 Receivable/Payable 状态
rails migrate_to_entry:verify_receivables_payables

# 运行 Receivable/Payable 迁移任务
rails migrate_to_entry:receivables_payables
```

## 兼容性方法示例

```ruby
# Receivable 或 Payable 实例
receivable = Receivable.find(1)

# 优先获取 Entry，自动回退到 Transaction
source = receivable.source_transaction_or_entry

# 从源交易获取金额和日期
amount = receivable.source_amount
date = receivable.source_date

# 自动确保有 Entry 引用
receivable.ensure_entry_reference
```

## 风险和缓解

### 风险 1: 数据不一致
**问题**: 某些 Receivable/Payable 的 source_transaction_id 可能无法找到对应的 Entry
**缓解**: 
- 迁移脚本会记录警告和失败的记录
- 可以手动修复或标记这些记录

### 风险 2: 性能影响
**问题**: 额外的数据库查询可能影响性能
**缓解**:
- 在 Entry 和 Entryable::Transaction 表上添加了索引
- 使用 find_entry_for_transaction 方法进行优化查询

### 风险 3: 控制器参数处理
**问题**: 现有代码可能仍然发送 source_transaction_id
**缓解**:
- 在 controller params 中同时接受两个参数
- 在模型中自动同步转换

## 清理步骤（未来）

一旦迁移完成并验证（建议在生产环境运行 2-4 周后）：

1. 删除 source_transaction_id 字段
2. 删除 `has_many :reimbursement_transactions` 关联
3. 删除 `has_many :payment_transactions` 关联  
4. 删除所有兼容性回退代码
5. 清理无用的 Transaction 表

## 时间表

- **P3-1**: 基础设施 (完成)
- **P3-2**: 代码清理和兼容性 (进行中)
- **P3-3**: 完全清理和 Transaction 移除 (待定, 建议 3 个月后)

## 参考资源

- [Entry 模型设计](../ENTRY_MODEL_GUIDE.md)
- [Receivable/Payable API](../RECEIVABLE_PAYABLE_GUIDE.md)
- [迁移计划 V1](./P3_MIGRATION_PLAN.md)
