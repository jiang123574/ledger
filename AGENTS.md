# Ledger 项目开发规范

## 项目概述

Ledger 是一个基于 Ruby on Rails 8 的个人记账应用，采用 PostgreSQL 数据库。

**核心原则**: 处理多年数据时，必须重点关注**数据库查询性能**（避免 N+1 查询）和**大批量数据的处理逻辑**。

---

## 一、性能优化

### 1.1 数据库查询

```ruby
# ✅ 正确：让数据库做统计
stats = Transaction.where(date: 5.years.ago..Time.now)
                   .group("date_trunc('month', date)")
                   .sum(:amount)

# ✅ 使用索引优化查询
add_index :transactions, [:account_id, :date]

# ✅ 预加载关联避免 N+1
@transactions = Transaction.includes(:account, :category, :tags)

# ✅ 使用 pluck 获取特定字段
Account.pluck(:id, :name)
```

### 1.2 大批量数据处理

```ruby
# ✅ 必须使用 find_each
Transaction.find_each(batch_size: 1000) do |transaction|
  # 处理每条记录
end
```

---

## 二、代码规范

### 2.1 模型设计

- 业务逻辑放在模型中
- 常用查询定义为 scope
- 完整的数据验证

### 2.2 ViewComponent 使用

| 场景 | 建议 |
|------|------|
| 复杂业务逻辑 | ViewComponent |
| 多处复用 | ViewComponent |
| 简单数据展示 | partial |

### 2.3 Git 提交规范

```
feat: 新功能
fix: 修复 bug
refactor: 重构
docs: 文档变更
style: 代码格式
test: 测试
chore: 构建/工具
```

---

## 三、环境配置

| 变量 | 默认值 | 说明 |
|------|--------|------|
| DB_HOST | localhost | 数据库主机 |
| DB_USERNAME | postgres | 数据库用户名 |
| DB_PASSWORD | - | 数据库密码 |

---

## 四、常用命令

```bash
bundle install          # 安装依赖
rails db:migrate       # 数据库迁移
rails s                # 启动服务器
bundle exec rspec      # 运行测试
bundle exec rubocop    # 代码检查
```

---

## 五、项目文档

- **[PROJECT_GUIDE.md](./PROJECT_GUIDE.md)** - 完整开发指南和功能清单
- **[README.md](./README.md)** - 项目简介和快速启动
- **[app/components/ds/README.md](./app/components/ds/README.md)** - DS 组件库使用说明
