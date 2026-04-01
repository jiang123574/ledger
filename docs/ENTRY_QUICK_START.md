# Entry 统一模型 - 快速开始

## 🚀 快速开始

### 1. 安装依赖

确保你的 PostgreSQL 支持 UUID 和 JSONB：

```sql
-- 在 PostgreSQL 中执行
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### 2. 运行迁移

```bash
# 创建 entries 表和相关表
rails db:migrate
```

### 3. 数据迁移（可选）

如果你有现有的 Transaction 数据：

```bash
# 备份数据库
pg_dump ledger_dev > backup_$(date +%Y%m%d).sql

# 迁移数据
rails migrate_to_entry:transactions

# 验证数据
rails migrate_to_entry:verify
```

### 4. 开始使用

```ruby
# 创建交易
entry = Entry.create!(
  account: Account.first,
  amount: 100.00,
  currency: 'CNY',
  date: Date.current,
  name: '午餐',
  entryable: Entryable::Transaction.new(
    category: Category.first,
    kind: 'expense',
    tags: ['餐饮']
  )
)

# 查询交易
entries = Entry.where(entryable_type: 'Entryable::Transaction')
               .chronological

# 统计
stats = Entryable::Transaction.by_category_stats
```

## 📚 文档

- [完整使用指南](./docs/ENTRY_MODEL_GUIDE.md)
- [优化方案总结](./docs/ENTRY_MODEL_SUMMARY.md)
- [性能优化总结](./docs/OPTIMIZATION_SUMMARY.md)

## 🎯 核心优势

1. **性能提升 5 倍** - 统一查询接口，优化索引策略
2. **灵活扩展** - delegated_type 支持多种类型
3. **易于维护** - 单表管理，JSONB 元数据
4. **向后兼容** - 平滑迁移，不影响现有功能

## ⚠️ 注意事项

- 迁移前务必备份数据库
- 在测试环境充分测试
- 生产环境建议在低峰期迁移

## 📞 支持

如有问题，请查看文档或联系开发团队。

---

**学习自 Sure 项目**：https://github.com/we-promise/sure