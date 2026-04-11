# Transaction 模型移除文件清单

更新时间：2026-04-11

## 1. 需要删除的文件

### 1.1 模型文件
- [ ] `app/models/transaction.rb` - 主要的 Transaction 模型
- [ ] `app/models/transaction_tag.rb` - Transaction 标签关联模型
- [ ] `app/models/transaction_search.rb` - 已弃用的搜索模型

### 1.2 迁移脚本（迁移完成后）
- [ ] `db/migrate/20260401100000_migrate_transactions_to_entries.rb` - 数据迁移脚本
- [ ] `db/migrate/20260406170000_enhance_entryable_transaction_for_migration.rb` - 迁移增强脚本
- [ ] `db/migrate/20260406180000_complete_receivables_payables_migration_to_entry.rb` - 字段迁移脚本

### 1.3 测试文件
- [ ] `spec/factories/factories.rb` 中的 `factory :transaction` 定义

## 2. 需要修改的文件

### 2.1 模型文件

#### `app/models/payable.rb`
- [ ] 移除第 4 行：`belongs_to :source_transaction, class_name: "Transaction", foreign_key: "source_transaction_id", optional: true`
- [ ] 移除第 5 行：`has_many :payment_transactions, class_name: "Transaction", foreign_key: "payable_id", dependent: :nullify`
- [ ] 移除第 27-29 行：`source_transaction_or_entry` 方法
- [ ] 移除第 41-48 行：`ensure_entry_reference` 方法
- [ ] 移除第 74-82 行：`find_entry_for_transaction` 方法

#### `app/models/entryable/transaction.rb`
- [ ] 移除第 11 行：`belongs_to :source_transaction, class_name: "::Transaction", foreign_key: :source_transaction_id, optional: true`
- [ ] 前提：确保数据迁移完成

### 2.2 控制器文件

#### `app/controllers/accounts_controller.rb`
- [ ] 修改第 553 行：`if Transaction.where(account_id: account.id).or(Transaction.where(target_account_id: account.id)).exists?`
- [ ] 改用 Entry 模型检查账户是否有交易记录

#### `app/controllers/settings_controller.rb`
- [ ] 修改第 185 行：`Transaction.where.not(link_id: nil).update_all(link_id: nil)`
- [ ] 修改第 186 行：`Transaction.destroy_all`
- [ ] 移除或改用 Entry 模型

### 2.3 测试文件

#### `spec/factories/factories.rb`
- [ ] 删除第 39-47 行的 `factory :transaction` 定义

#### `spec/models/p3_phase_2_migration_spec.rb`
- [ ] 移除对 `source_transaction_id` 的测试引用

#### 其他测试文件
- [ ] 检查并移除对旧 Transaction 模型的引用

## 3. 需要创建的文件

### 3.1 数据库迁移脚本

#### `db/migrate/[timestamp]_drop_transactions_table.rb`
```ruby
class DropTransactionsTable < ActiveRecord::Migration[8.0]
  def up
    # 移除外键约束
    remove_foreign_key :attachments, :transactions if foreign_key_exists?(:attachments, :transactions)
    remove_foreign_key :transaction_tags, :transactions if foreign_key_exists?(:transaction_tags, :transactions)
    
    # 删除表
    drop_table :transaction_tags if table_exists?(:transaction_tags)
    drop_table :transactions if table_exists?(:transactions)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

#### `db/migrate/[timestamp]_remove_source_transaction_id_from_tables.rb`
```ruby
class RemoveSourceTransactionIdFromTables < ActiveRecord::Migration[8.0]
  def up
    # 从 entryable_transactions 表移除
    remove_column :entryable_transactions, :source_transaction_id, :bigint if column_exists?(:entryable_transactions, :source_transaction_id)
    
    # 从 payables 表移除
    remove_column :payables, :source_transaction_id, :integer if column_exists?(:payables, :source_transaction_id)
  end

  def down
    # 回滚：重新添加字段
    add_column :entryable_transactions, :source_transaction_id, :bigint unless column_exists?(:entryable_transactions, :source_transaction_id)
    add_column :payables, :source_transaction_id, :integer unless column_exists?(:payables, :source_transaction_id)
  end
end
```

## 4. 验证清单

### 4.1 数据迁移验证
- [ ] 确认所有 Transaction 数据已迁移到 Entry 系统
- [ ] 确认 source_transaction_id 映射关系正确
- [ ] 确认关联数据（attachments、transaction_tags）已正确处理

### 4.2 代码修改验证
- [ ] 运行完整测试套件
- [ ] 检查所有控制器功能正常
- [ ] 检查所有模型关联正确
- [ ] 检查所有服务功能正常

### 4.3 数据库修改验证
- [ ] 运行迁移脚本无错误
- [ ] 确认外键约束已正确移除
- [ ] 确认表已正确删除
- [ ] 确认字段已正确移除

## 5. 执行顺序

1. **准备阶段**
   - [ ] 验证数据迁移完成
   - [ ] 运行完整测试套件
   - [ ] 创建数据库备份

2. **Phase 3b-1: 代码清理**
   - [ ] 修改 `app/models/payable.rb`
   - [ ] 修改 `app/models/entryable/transaction.rb`（数据迁移完成后）
   - [ ] 修改 `app/controllers/accounts_controller.rb`
   - [ ] 修改 `app/controllers/settings_controller.rb`
   - [ ] 删除 `app/models/transaction.rb`
   - [ ] 删除 `app/models/transaction_tag.rb`
   - [ ] 删除 `app/models/transaction_search.rb`
   - [ ] 修改测试文件
   - [ ] 运行测试验证

3. **Phase 3b-2: 表清理**
   - [ ] 创建迁移脚本删除 transactions 表
   - [ ] 创建迁移脚本删除 transaction_tags 表
   - [ ] 创建迁移脚本移除 source_transaction_id 字段
   - [ ] 运行迁移脚本
   - [ ] 运行测试验证

4. **Phase 3b-3: 验证**
   - [ ] 运行完整测试套件
   - [ ] 部署到测试环境
   - [ ] 监控系统日志
   - [ ] 部署到生产环境

## 6. 注意事项

1. **数据完整性**：确保所有 Transaction 数据已正确迁移到 Entry 系统
2. **外键约束**：删除表前必须移除所有外键约束
3. **关联数据**：正确处理 attachments、transaction_tags 等关联数据
4. **测试覆盖**：确保测试覆盖所有移除的功能
5. **备份**：执行删除操作前务必备份数据库
6. **监控**：部署后密切监控系统日志和性能

## 7. 风险提示

- **高风险**：删除 transactions 表是不可逆操作
- **中风险**：移除兼容性代码可能影响未发现的调用点
- **低风险**：删除模型文件可能影响测试和文档

建议在非生产环境充分测试后再执行生产环境部署。