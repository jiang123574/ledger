# Transaction 模型移除分析报告

生成时间：2026-04-11
项目路径：~/Desktop/ledger

## 1. Transaction 模型定义和关联关系

### 1.1 主要模型文件

| 文件路径 | 描述 | 状态 |
|---------|------|------|
| `app/models/transaction.rb` | 主要的 Transaction 模型（旧系统） | 待删除 |
| `app/models/entryable/transaction.rb` | 新的 Entryable::Transaction 模型（新系统） | 保留 |
| `app/models/transaction_tag.rb` | Transaction 的标签关联模型 | 待删除 |
| `app/models/transaction_search.rb` | 已弃用，指向 EntrySearch | 待删除 |

### 1.2 Transaction 模型关联关系

```ruby
# app/models/transaction.rb
class Transaction < ApplicationRecord
  belongs_to :account, class_name: "Account", optional: true
  belongs_to :target_account, class_name: "Account", foreign_key: "target_account_id", optional: true
  belongs_to :category, class_name: "Category", optional: true
  belongs_to :receivable, optional: true
  belongs_to :payable, optional: true
  belongs_to :link, class_name: "Transaction", optional: true
  has_many :attachments, dependent: :destroy
  has_many :transaction_tags, dependent: :destroy
  has_many :tags, through: :transaction_tags
end
```

### 1.3 Entryable::Transaction 模型关联关系

```ruby
# app/models/entryable/transaction.rb
class Entryable::Transaction < ApplicationRecord
  belongs_to :category, class_name: "::Category", optional: true
  belongs_to :merchant, class_name: "::Merchant", optional: true
  belongs_to :source_transaction, class_name: "::Transaction", foreign_key: :source_transaction_id, optional: true
  has_many :taggings, as: :taggable, class_name: "::Tagging", dependent: :destroy
  has_many :tags, through: :taggings
end
```

## 2. 所有引用 Transaction 的代码位置

### 2.1 控制器文件

| 文件路径 | 引用位置 | 使用方式 | 修改建议 |
|---------|---------|---------|---------|
| `app/controllers/accounts_controller.rb:553` | `Transaction.where(account_id: account.id).or(Transaction.where(target_account_id: account.id)).exists?` | 检查账户是否有交易记录 | 改用 Entry 模型 |
| `app/controllers/settings_controller.rb:185-186` | `Transaction.where.not(link_id: nil).update_all(link_id: nil)` 和 `Transaction.destroy_all` | 清理数据时删除 Transaction | 移除或改用 Entry |
| `app/controllers/transactions_controller.rb` | 多处使用 `Entryable::Transaction` | 创建交易记录 | 保留 Entryable::Transaction |
| `app/controllers/entries_controller.rb:82` | `entry.entryable = Entryable::Transaction.new(entryable_attrs)` | 创建 Entry 的 entryable | 保留 |

### 2.2 模型文件

| 文件路径 | 引用位置 | 使用方式 | 修改建议 |
|---------|---------|---------|---------|
| `app/models/payable.rb:4` | `belongs_to :source_transaction, class_name: "Transaction"` | 关联旧 Transaction | 移除关联 |
| `app/models/payable.rb:5` | `has_many :payment_transactions, class_name: "Transaction"` | 关联付款交易 | 移除关联 |
| `app/models/payable.rb:27-29` | `source_transaction_or_entry` 方法 | 兼容性方法 | 移除方法 |
| `app/models/payable.rb:42-48` | `ensure_entry_reference` 方法 | 同步 source_entry_id | 移除方法 |
| `app/models/payable.rb:74-82` | `find_entry_for_transaction` 方法 | 查找对应 Entry | 移除方法 |
| `app/models/entryable/transaction.rb:11` | `belongs_to :source_transaction` | 迁移追踪 | 待数据迁移完成后移除 |

### 2.3 服务文件

| 文件路径 | 引用位置 | 使用方式 | 修改建议 |
|---------|---------|---------|---------|
| `app/services/entry_creation_service.rb` | 多处使用 `Entryable::Transaction.create!` | 创建交易记录 | 保留 |
| `app/services/pixiu_import_service.rb` | 多处使用 `Entryable::Transaction.create!` | 导入交易 | 保留 |
| `app/services/importers/qif_importer.rb:36` | `Entryable::Transaction.new` | 导入交易 | 保留 |
| `app/services/importers/import_row_mapper.rb` | 多处使用 `Entryable::Transaction.create!` | 导入交易 | 保留 |
| `app/services/importers/ofx_importer.rb:43` | `Entryable::Transaction.new` | 导入交易 | 保留 |

### 2.4 迁移脚本文件

| 文件路径 | 引用位置 | 使用方式 | 修改建议 |
|---------|---------|---------|---------|
| `db/migrate/20260401100000_migrate_transactions_to_entries.rb` | 多处使用 `Transaction` | 数据迁移 | 迁移完成后可删除 |
| `db/migrate/20260406170000_enhance_entryable_transaction_for_migration.rb` | 添加 `source_transaction_id` | 迁移追踪 | 迁移完成后可删除 |
| `db/migrate/20260406180000_complete_receivables_payables_migration_to_entry.rb` | 使用 `source_transaction_id` | 数据迁移 | 迁移完成后可删除 |

### 2.5 测试文件

| 文件路径 | 引用位置 | 使用方式 | 修改建议 |
|---------|---------|---------|---------|
| `spec/factories/factories.rb:39-47` | `factory :transaction` | 测试工厂 | 删除 |
| `spec/factories/factories.rb:139-150` | `factory :entryable_transaction` | 测试工厂 | 保留 |
| `spec/models/account_spec.rb` | 多处使用 `Entryable::Transaction` | 测试 | 保留 |
| `spec/models/p3_phase_2_migration_spec.rb` | 多处使用 `source_transaction_id` | 测试迁移 | 迁移完成后可删除 |
| `spec/requests/transactions_spec.rb` | 测试 Transaction 相关请求 | 测试 | 保留但需检查 |
| 多个测试文件 | 使用 `Entryable::Transaction.new` | 测试数据创建 | 保留 |

## 3. source_transaction_id 字段的使用情况

### 3.1 数据库表中的字段

| 表名 | 字段名 | 类型 | 用途 | 状态 |
|------|--------|------|------|------|
| `entryable_transactions` | `source_transaction_id` | `bigint` | 迁移追踪，关联旧 Transaction | 迁移完成后可移除 |
| `payables` | `source_transaction_id` | `integer` | 关联旧 Transaction | 迁移完成后可移除 |
| `receivables` | `source_transaction_id` | `integer` | 关联旧 Transaction | 已移除（见迁移 20260410124404） |

### 3.2 代码中的使用

1. **迁移脚本**：用于数据映射和追踪
2. **Payable 模型**：用于兼容性方法（`source_transaction_or_entry`、`ensure_entry_reference`）
3. **Entryable::Transaction 模型**：关联旧 Transaction（迁移追踪）

## 4. transactions 表的结构和依赖

### 4.1 表结构（来自 schema.rb）

```ruby
create_table "transactions", force: :cascade do |t|
  t.integer "account_id"
  t.decimal "amount", precision: 10, scale: 2
  t.string "category"
  t.integer "category_id"
  t.string "currency", limit: 3, default: "CNY"
  t.datetime "date"
  t.string "dedupe_key", limit: 40
  t.decimal "exchange_rate", precision: 12, scale: 6
  t.jsonb "extra", default: {}
  t.integer "link_id"
  t.jsonb "locked_attributes", default: {}
  t.string "note"
  t.decimal "original_amount", precision: 12, scale: 6
  t.bigint "payable_id"
  t.integer "receivable_id"
  t.integer "sort_order", default: 0
  t.string "tag"
  t.integer "target_account_id"
  t.string "type"
  t.boolean "user_modified", default: false, null: false
  # 多个索引...
end
```

### 4.2 外键依赖

| 来源表 | 来源字段 | 目标表 | 约束类型 |
|--------|----------|--------|----------|
| `attachments` | `transaction_id` | `transactions` | 外键 |
| `transaction_tags` | `transaction_id` | `transactions` | 外键（级联删除） |
| `transactions` | `account_id` | `accounts` | 外键 |
| `transactions` | `target_account_id` | `accounts` | 外键 |
| `transactions` | `category_id` | `categories` | 外键 |
| `transactions` | `payable_id` | `payables` | 外键 |
| `transactions` | `receivable_id` | `receivables` | 外键 |
| `transactions` | `link_id` | `transactions` | 外键（自引用） |

### 4.3 相关表

| 表名 | 描述 | 与 Transaction 的关系 |
|------|------|----------------------|
| `transaction_tags` | Transaction 标签关联表 | 多对多关联表 |
| `attachments` | 附件表 | 旧系统关联 transaction_id |
| `payables` | 应付款表 | 旧系统关联 source_transaction_id |
| `receivables` | 应收款表 | 旧系统关联 source_transaction_id（已移除） |

## 5. 现有的迁移脚本模式

### 5.1 数据迁移模式（参考 20260401100000）

```ruby
# 1. 批量处理避免内存溢出
Transaction.find_in_batches(batch_size: 500) do |batch|
  batch.each do |t|
    # 创建新系统的数据
  end
end

# 2. 使用 source_transaction_id 追踪映射关系
entryable_trans = Entryable::Transaction.new(
  kind: t.type.downcase,
  category_id: t.category_id,
  extra: t.extra || {},
  locked_attributes: t.locked_attributes || {}
)

# 3. 跳过验证加速迁移
entryable_trans.save(validate: false)
```

### 5.2 字段迁移模式（参考 20260406180000）

```ruby
# 1. 查找对应的 Entry
entry = Entry
  .joins("INNER JOIN entryable_transactions ON entryable_transactions.id = entries.entryable_id")
  .where(entryable_type: 'Entryable::Transaction')
  .where(entryable_transactions: { source_transaction_id: transaction_id })
  .first

# 2. 更新关联字段
receivable.update_column(:source_entry_id, entry.id) if entry.present?
```

## 6. 修改优先级和计划

### 6.1 Phase 3b-1: 代码清理（预计 2-3 小时）

**高优先级（必须修改）：**

1. **移除 Payable 模型中的 Transaction 关联**
   - 文件：`app/models/payable.rb`
   - 修改：删除 `belongs_to :source_transaction`、`has_many :payment_transactions`
   - 修改：删除 `source_transaction_or_entry`、`ensure_entry_reference`、`find_entry_for_transaction` 方法

2. **移除 Entryable::Transaction 中的 source_transaction 关联**
   - 文件：`app/models/entryable/transaction.rb`
   - 修改：删除 `belongs_to :source_transaction`
   - 前提：确保数据迁移完成

3. **修改 accounts_controller.rb**
   - 文件：`app/controllers/accounts_controller.rb:553`
   - 修改：改用 Entry 模型检查账户是否有交易记录

4. **修改 settings_controller.rb**
   - 文件：`app/controllers/settings_controller.rb:185-186`
   - 修改：移除 Transaction 相关清理代码

**中优先级（建议修改）：**

5. **删除 Transaction 模型文件**
   - 文件：`app/models/transaction.rb`
   - 文件：`app/models/transaction_tag.rb`
   - 文件：`app/models/transaction_search.rb`

6. **删除测试工厂**
   - 文件：`spec/factories/factories.rb`
   - 修改：删除 `factory :transaction`

7. **更新测试文件**
   - 移除对旧 Transaction 模型的引用
   - 移除对 source_transaction_id 的测试

### 6.2 Phase 3b-2: 表清理（预计 1-2 小时）

**创建迁移脚本：**

1. **删除 transactions 表**
   - 移除所有外键约束
   - 删除 transactions 表
   - 删除 transaction_tags 表

2. **移除 source_transaction_id 字段**
   - 从 entryable_transactions 表移除
   - 从 payables 表移除

3. **更新 schema.rb**

### 6.3 Phase 3b-3: 验证（预计 1 小时）

1. 运行完整测试套件
2. 检查所有功能正常
3. 监控系统日志

## 7. 风险评估

### 7.1 高风险项

1. **数据完整性**：确保所有 Transaction 数据已正确迁移到 Entry 系统
2. **外键约束**：删除 transactions 表前需移除所有外键依赖
3. **关联数据**：attachments、transaction_tags 等关联数据需正确处理

### 7.2 中风险项

1. **兼容性代码**：移除兼容性代码可能影响未发现的调用点
2. **测试覆盖**：确保测试覆盖所有移除的功能

### 7.3 低风险项

1. **路由清理**：transactions 路由可保留用于重定向
2. **视图清理**：相关视图文件可后续清理

## 8. 建议的执行顺序

1. **验证数据迁移完成**：确认所有 Transaction 数据已迁移到 Entry 系统
2. **运行完整测试**：确保当前系统功能正常
3. **创建备份**：备份数据库和代码
4. **执行 Phase 3b-1**：代码清理
5. **运行测试**：验证代码修改无影响
6. **执行 Phase 3b-2**：表清理
7. **运行测试**：验证表结构修改无影响
8. **部署到测试环境**：验证完整功能
9. **部署到生产环境**：分阶段部署，监控系统状态

## 9. 待确认事项

1. 是否还有其他地方引用 Transaction 模型？
2. source_transaction_id 的数据是否已完全迁移？
3. 是否有定时任务或后台任务使用 Transaction？
4. 是否有外部 API 或集成使用 Transaction？

## 10. 相关文档

- TODO.md - 第 4 节：Transaction 模型完全移除
- 数据迁移脚本：`db/migrate/20260401100000_migrate_transactions_to_entries.rb`
- 字段迁移脚本：`db/migrate/20260406180000_complete_receivables_payables_migration_to_entry.rb`
- Receivables 字段清理：`db/migrate/20260410124404_remove_legacy_fields_from_receivables.rb`