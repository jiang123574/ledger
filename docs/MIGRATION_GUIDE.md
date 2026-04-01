# 从 Transaction 迁移到 Entry 统一模型指南

## 概述

本文档说明如何从现有的 `Transaction` 模型迁移到新的 `Entry` 统一模型架构。

## 迁移策略

### 阶段 1: 双模型并存（当前）

- **Entry**: 新功能使用
- **Transaction**: 现有功能保持不变
- 两者独立运行，互不影响

### 阶段 2: 新数据写入 Entry

- 所有新交易写入 `Entry` 表
- 旧数据保持 `Transaction` 表
- 读取时合并两个数据源

### 阶段 3: 迁移旧数据

- 运行迁移脚本
- 所有 `Transaction` 数据迁移到 `Entry`
- 废弃 `Transaction` 模型

## 迁移前准备

### 1. 备份数据库

```bash
# PostgreSQL 备份
pg_dump ledger_dev > backup_$(date +%Y%m%d_%H%M%S).sql

# 或使用 Rails 备份
rails backup:create
```

### 2. 检查数据完整性

```bash
# 验证账户余额
rails runner "
  Account.find_each do |account|
    calculated = account.sent_transactions.sum(:amount)
    stored = account.current_balance
    if calculated != stored
      puts '账户 #{account.name}: 计算值=#{calculated}, 存储值=#{stored}'
    end
  end
"
```

### 3. 统计数据量

```bash
# 统计迁移数据量
rails runner "
  puts '交易总数: #{Transaction.count}'
  puts '账户总数: #{Account.count}'
  puts '分类总数: #{Category.count}'
  puts '标签总数: #{Tag.count}'
"
```

## 执行迁移

### 方式 1: 使用 Rake 任务（推荐）

```bash
# 1. 运行数据库迁移
rails db:migrate

# 2. 迁移数据
rails migrate_to_entry:transactions

# 3. 验证数据
rails migrate_to_entry:verify
```

### 方式 2: 手动迁移

```ruby
# Rails console
Transaction.find_each do |old_trans|
  Entry.transaction do
    # 创建 Entryable::Transaction
    entryable_trans = Entryable::Transaction.create!(
      category_id: old_trans.category_id,
      kind: old_trans.type&.downcase,
      tags: old_trans.tags.pluck(:name)
    )
    
    # 创建 Entry
    Entry.create!(
      account_id: old_trans.account_id,
      entryable: entryable_trans,
      amount: old_trans.amount,
      currency: old_trans.currency || 'CNY',
      date: old_trans.date,
      name: old_trans.note || '未命名交易',
      extra: {
        old_transaction_id: old_trans.id
      }
    )
  end
end
```

## 数据映射

### Transaction -> Entry 映射表

| Transaction 字段 | Entry 字段 | 说明 |
|------------------|-----------|------|
| id | extra['old_transaction_id'] | 保留旧ID |
| account_id | account_id | 直接映射 |
| type | entryable.kind | INCOME -> 'income' |
| amount | amount | 直接映射 |
| currency | currency | 直接映射 |
| date | date | 直接映射 |
| note | name | 名称 |
| note | notes | 备注 |
| category_id | entryable.category_id | 分类关联 |
| tags | entryable.tags | 标签数组 |
| target_account_id | extra['target_account_id'] | 转账目标 |
| dedupe_key | extra['dedupe_key'] | 去重键 |

## 验证迁移

### 1. 数据量验证

```bash
rails runner "
  old_count = Transaction.count
  new_count = Entry.where(entryable_type: 'Entryable::Transaction').count
  
  puts 'Transaction 记录数: #{old_count}'
  puts 'Entry 记录数: #{new_count}'
  
  if old_count == new_count
    puts '✓ 数据量一致'
  else
    puts '✗ 数据量不一致'
  end
"
```

### 2. 金额验证

```bash
rails runner "
  accounts = Account.all
  
  accounts.each do |account|
    old_balance = account.sent_transactions.sum(:amount)
    new_balance = Entry.where(account_id: account.id)
                        .joins(:entryable)
                        .sum('CASE WHEN entryable_transactions.kind = \'income\' THEN entries.amount ELSE -entries.amount END')
    
    if old_balance != new_balance
      puts '账户 #{account.name}: 旧=#{old_balance}, 新=#{new_balance}'
    end
  end
  
  puts '验证完成'
"
```

### 3. 分类统计验证

```bash
rails runner "
  Category.find_each do |category|
    old_count = Transaction.where(category_id: category.id).count
    new_count = Entry.joins(:entryable)
                     .where(entryable_transactions: { category_id: category.id })
                     .count
    
    if old_count != new_count
      puts '分类 #{category.name}: 旧=#{old_count}, 新=#{new_count}'
    end
  end
  
  puts '验证完成'
"
```

## 回滚迁移

如果迁移出现问题，可以回滚：

```bash
# 1. 删除所有 Entry 数据
rails migrate_to_entry:rollback

# 2. 恢复数据库备份
psql ledger_dev < backup_20260401_100000.sql

# 3. 回滚数据库迁移
rails db:rollback STEP=4
```

## 迁移后更新

### 1. 更新控制器

```ruby
# app/controllers/accounts_controller.rb
# 将 @transactions 改为 @entries

def index
  @entries = Entry.by_account(params[:account_id])
                  .chronological
                  .page(params[:page])
end
```

### 2. 更新视图

```erb
<%# 将 @transactions 改为 @entries %>
<% @entries.each do |entry| %>
  <tr>
    <td><%= entry.date %></td>
    <td><%= entry.name %></td>
    <td><%= entry.amount %></td>
  </tr>
<% end %>
```

### 3. 更新路由

```ruby
# config/routes.rb
# 可以添加新的路由指向 Entry 控制器
resources :entries, only: [:index, :show, :create, :update, :destroy]
```

## 性能优化

### 1. 添加索引

```ruby
# 已在迁移中添加
add_index :entries, [:account_id, :date]
add_index :entries, [:entryable_type, :entryable_id]
```

### 2. 使用缓存

```ruby
# 使用 account 更新时间作为缓存键
cache_key = "account_stats_#{account.id}_#{account.updated_at.to_i}"
```

### 3. 批量查询

```ruby
# 使用 find_each 批量处理
Entry.find_each(batch_size: 1000) do |entry|
  # 处理逻辑
end
```

## 常见问题

### Q1: 迁移后如何查询旧数据？

A: 通过 `extra['old_transaction_id']` 关联：

```ruby
old_trans = Transaction.find(123)
entry = Entry.find_by("extra->>'old_transaction_id' = '123'")
```

### Q2: 如何处理转账记录？

A: 转账记录需要特殊处理：

```ruby
Entry.create!(
  account_id: from_account.id,
  entryable: Entryable::Transaction.new(kind: 'transfer'),
  extra: {
    target_account_id: to_account.id
  }
)
```

### Q3: 迁移后数据不一致怎么办？

A: 
1. 检查数据量
2. 检查金额总和
3. 检查分类统计
4. 必要时回滚重新迁移

### Q4: 如何测试迁移结果？

A: 运行测试：

```bash
rails test test/models/entry_test.rb
rails test test/integration/entry_integration_test.rb
```

## 监控指标

迁移后监控以下指标：

1. **查询性能**
   - Entry 查询时间 < 200ms
   - 索引使用率 > 90%

2. **数据完整性**
   - 记录数一致
   - 金额总和一致

3. **错误率**
   - 迁移错误率 < 0.1%
   - 运行时错误率 < 0.01%

## 完成检查清单

迁移完成后检查：

- [ ] 数据库迁移成功
- [ ] 数据量一致
- [ ] 金额总和一致
- [ ] 分类统计一致
- [ ] 测试通过
- [ ] 性能符合预期
- [ ] 监控指标正常
- [ ] 文档更新
- [ ] 团队培训完成

## 支持

如有问题，请联系开发团队或查看文档：

- [Entry 使用指南](./ENTRY_MODEL_GUIDE.md)
- [快速开始](./ENTRY_QUICK_START.md)
- [架构设计](./ENTRY_MODEL_SUMMARY.md)