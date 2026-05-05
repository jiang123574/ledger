# Performance Optimization Guide

**更新日期**: 2026-05-05
**适用项目**: Ledger 个人财务系统

## 概览

本指南提供 Ledger 系统的性能优化策略，涵盖数据库查询、缓存、前端等方面。

## 缓存策略

### Rails 缓存配置

项目使用 Rails 默认缓存存储，可配置 Redis 提升性能：

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV['REDIS_URL'],
  expires_in: 1.hour
}
```

### 账户余额缓存

账户余额计算频繁，建议缓存：

```ruby
# app/models/account.rb
def cached_balance
  Rails.cache.fetch("account:#{id}:balance", expires_in: 1.hour) do
    calculate_balance
  end
end

# 更新后清除缓存
after_save :clear_balance_cache

def clear_balance_cache
  Rails.cache.delete("account:#{id}:balance")
end
```

### 分类树缓存

分类树结构稳定，适合长期缓存：

```ruby
# app/models/category.rb
def self.tree
  Rails.cache.fetch('categories:tree', expires_in: 1.day) do
    build_tree
  end
end

# 分类更新时清除
after_save :clear_tree_cache
after_destroy :clear_tree_cache

def clear_tree_cache
  Rails.cache.delete('categories:tree')
end
```

## N+1 问题预防

### 常见场景

| 场景 | 问题 | 解决方案 |
|------|------|---------|
| Entry 列表加载 Account | N+1 | `Entry.includes(:account)` |
| Entry 加载转账对方账户 | N+1 | `Entry.preload_transfer_accounts` |
| Category 加载子分类 | N+1 | `Category.includes(:children)` |
| Entry 加载分类 | N+1 | `Entry.includes(entryable: :category)` |

### Bullet 检测

开发环境启用 Bullet 检测 N+1：

```ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.rails_logger = true
  Bullet.raise = true  # 严格模式，N+1 直接报错
end
```

## 查询优化

### 明确指定列

避免 SELECT *，明确指定需要的列：

```ruby
# 低效
Entry.all.map { |e| e.amount }

# 高效
Entry.select(:id, :amount).map { |e| e.amount }
```

### 使用 exists? 代替 count

```ruby
# 低效 - 计算全部行数
Account.where(balance: 0).count > 0

# 高效 - 布尔检查
Account.where(balance: 0).exists?
```

### 批量处理

```ruby
# 批量创建 (避免单条插入)
entries_data = [...]
Entry.insert_all(entries_data)

# 批量更新
Entry.where(account_id: 1).update_all(excluded: true)
```

### 使用索引优化

项目已优化索引：
- `idx_entries_account_date` - 账户日期复合索引
- `idx_entries_name_trgm` - 名称全文搜索
- `idx_trans_category` - 分类查询

**查询建议**:
```ruby
# 利用复合索引
Entry.where(account_id: 1).where('date >= ?', Date.current)

# TRGM 搜索
Entry.where("name ILIKE '%#{query}%'")
```

## 前端优化

### Turbo Frame 局部更新

使用 Turbo Frame 实现局部页面更新，避免全页刷新：

```erb
<%= turbo_frame_tag "entries_list" do %>
  <%= render @entries %>
<% end %>
```

### 分页加载

使用 kaminari 分页，避免一次加载过多数据：

```ruby
# controller
@entries = Entry.page(params[:page]).per(20)

# view
<%= paginate @entries %>
```

### 懒加载图片

附件图片使用懒加载：

```erb
<%= image_tag attachment.url, loading: "lazy" %>
```

## 监控和分析

### rack-mini-profiler

开发环境自动启用，页面右上角显示性能指标。

### 慢查询日志

PostgreSQL 配置：

```sql
-- 记录超过 100ms 的查询
SET log_min_duration_statement = 100;
```

### 执行计划分析

```ruby
# Rails 中分析查询
Entry.where(account_id: 1).explain

# PostgreSQL 直接分析
EXPLAIN ANALYZE SELECT * FROM entries WHERE account_id = 1;
```

## 性能基准

### 关键指标

| 操作 | 目标响应时间 |
|-----|------------|
| 首页加载 | < 200ms |
| Entry 列表 (100 条) | < 300ms |
| Entry 创建 | < 100ms |
| 报表统计 | < 500ms |

### 测试示例

```ruby
# spec/performance/baseline_spec.rb
RSpec.describe 'Performance Baseline' do
  it 'homepage loads in < 200ms' do
    start = Time.current
    get '/'
    elapsed = Time.current - start
    expect(elapsed).to be < 0.2
  end
end
```

## 常见瓶颈

### 数据库连接

确保连接池配置合理：

```yaml
# config/database.yml
pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

### 内存使用

监控内存，避免大对象：

```ruby
# 避免一次性加载大量数据
# 使用 find_each 分批处理
Entry.find_each do |entry|
  # 处理每条记录
end
```

### 缓存命中率

监控缓存效果：

```ruby
# 查看缓存统计
Rails.cache.stats
```

---

**文档维护**: 随系统优化持续更新
**性能问题**: 参考 docs/DATABASE_SCHEMA.md 索引策略