# Entry 统一模型使用指南

## 概述

Entry 统一模型是学习 Sure 项目的设计，将所有财务记录统一到一个 Entry 表中，使用 `delegated_type` 支持多种类型。

## 架构设计

### 1. Entry 表（主表）

```ruby
Entry
├── entryable_type: "Entryable::Transaction" | "Entryable::Valuation" | "Entryable::Trade"
├── entryable_id: UUID
├── account_id: UUID
├── amount: decimal
├── currency: string
├── date: date
├── name: string
├── extra: jsonb
└── locked_attributes: jsonb
```

### 2. Entryable 类型

#### Transaction（交易）
```ruby
Entryable::Transaction
├── category_id: UUID
├── merchant_id: UUID
├── kind: string ('income' | 'expense')
├── tags: jsonb array
└── extra: jsonb
```

#### Valuation（估值）
```ruby
Entryable::Valuation
└── extra: jsonb
```

#### Trade（证券交易）
```ruby
Entryable::Trade
├── security_id: UUID
├── qty: decimal
├── price: decimal
└── extra: jsonb
```

## 使用方法

### 1. 创建交易

```ruby
# 方式 1：创建 Entry + Entryable
entry = Entry.create!(
  account: account,
  amount: 100.00,
  currency: 'CNY',
  date: Date.current,
  name: '午餐',
  entryable: Entryable::Transaction.new(
    category: category,
    kind: 'expense',
    tags: ['餐饮', '午餐']
  )
)

# 方式 2：使用嵌套属性
entry = Entry.create!(
  account: account,
  amount: 100.00,
  currency: 'CNY',
  date: Date.current,
  name: '午餐',
  entryable_type: 'Entryable::Transaction',
  entryable_attributes: {
    category_id: category.id,
    kind: 'expense',
    tags: ['餐饮']
  }
)
```

### 2. 查询交易

```ruby
# 查询所有交易
Entry.where(entryable_type: 'Entryable::Transaction')

# 查询收入
Entry.joins(:entryable)
     .where(entryable_type: 'Entryable::Transaction', entryable_transactions: { kind: 'income' })

# 按账户查询
Entry.by_account(account_id)

# 按时间范围查询
Entry.by_date_range(start_date, end_date)

# 按分类查询
Entry.joins(entryable: :category)
     .where(categories: { id: category_id })
```

### 3. 统计分析

```ruby
# 按分类统计
Entryable::Transaction.by_category_stats(account_id: account.id)

# 账户余额
Entry.where(account_id: account.id)
     .joins(:entryable)
     .sum("CASE WHEN entryable_transactions.kind = 'income' THEN amount ELSE -amount END")
```

### 4. 锁定机制

```ruby
# 锁定字段（防止自动同步覆盖）
entry.lock_attribute!(:amount)
entry.lock_attribute!(:category_id)

# 检查是否锁定
entry.locked?(:amount) # => true

# 解锁（允许同步更新）
entry.unlock_for_sync!
```

### 5. 分层交易

```ruby
# 拆分交易
entry.split!([
  { name: '食材', amount: 60, category_id: food_category.id },
  { name: '饮料', amount: 40, category_id: drink_category.id }
])

# 取消拆分
entry.unsplit!
```

## 迁移步骤

### 1. 备份数据库

```bash
pg_dump ledger_dev > backup_$(date +%Y%m%d).sql
```

### 2. 运行迁移

```bash
rails db:migrate
```

### 3. 迁移数据

```bash
rails migrate_to_entry:transactions
```

### 4. 验证数据

```bash
rails migrate_to_entry:verify
```

### 5. 回滚（如果需要）

```bash
rails migrate_to_entry:rollback
```

## 性能优势

### 1. 统一查询接口
- 单表查询，减少 JOIN
- 统一的索引策略
- 更快的聚合查询

### 2. 灵活的扩展性
- 轻松添加新的 Entryable 类型
- JSONB 存储灵活元数据
- 不需要修改表结构

### 3. 更好的缓存
- 单一缓存键
- 更少的缓存失效
- 更高的命中率

## 注意事项

1. **UUID 支持**：需要 PostgreSQL 的 `pgcrypto` 扩展
2. **数据完整性**：迁移前务必备份
3. **向后兼容**：保留了原 Transaction 表
4. **测试**：在生产环境前充分测试

## 参考

- [Sure 项目](https://github.com/we-promise/sure)
- [Rails delegated_type](https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html)
- [PostgreSQL JSONB](https://www.postgresql.org/docs/current/datatype-json.html)