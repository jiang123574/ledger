# Ledger 项目开发规范

## 项目概述

Ledger 是一个基于 Ruby on Rails 8 的个人记账应用，采用 PostgreSQL 数据库。

**核心原则**: 处理多年数据时，必须重点关注**数据库查询性能**（避免 N+1 查询）和**大批量数据的处理逻辑**。

## 技术栈

- **后端框架**: Ruby on Rails 8.1
- **数据库**: PostgreSQL
- **缓存**: Solid Cache + Solid Queue
- **前端**: ERB + Tailwind CSS + Hotwire (Turbo Frames)
- **组件化**: ViewComponent

## 项目结构

```
app/
├── components/      # ViewComponent 组件
├── controllers/    # 控制器
├── helpers/        # 视图助手
├── javascript/     # JavaScript
├── models/         # 数据模型
├── services/      # 服务类
└── views/          # 视图模板
config/
├── locales/        # 国际化文件
└── ...
lib/
├── money.rb       # 货币处理模块
└── ...
```

## 开发规范

### 模型设计原则

1. **胖模型原则**: 业务逻辑应放在模型中
2. **作用域 (Scope)**: 常用查询定义为 scope
3. **关联预加载**: 使用 `includes` 避免 N+1 查询
4. **验证**: 模型层级定义完整的数据验证

### 数据库查询优化

1. 使用 `explain` 分析查询性能
2. 为高频查询字段添加索引
3. 使用 `select` 避免加载不必要的字段
4. 使用 `pluck` 获取特定字段而非完整对象
5. **让数据库计算**: 不要把数据取出来用 Ruby 遍历，让 PostgreSQL 做统计

### ViewComponent 使用指南

| 使用场景 | 建议 |
|---------|------|
| 复杂业务逻辑 | 使用 ViewComponent |
| 静态 HTML | 使用 partial |
| 多处复用 | 使用 ViewComponent |
| 简单数据展示 | 使用 partial |

### i18n 命名规范

```
模块.组件.键名
```

例如:
```yaml
dashboard:
  title: "仪表盘"
transactions:
  list: "交易列表"
```

### Hotwire 局部刷新

数据按"年"或"月"切片加载，使用 Turbo Frames 实现局部刷新:

```erb
<%= turbo_frame_tag "monthly_report" do %>
  <%= render @transactions %>
  <%== pagy_nav(@pagy) %>
<% end %>
```

## 性能优化

### 数据库优化

```ruby
# 使用索引优化查询
add_index :transactions, [:account_id, :date]

# 预加载关联
@transactions = Transaction.includes(:account, :category)

# 使用范围查询
scope :by_date, ->(start_date, end_date) {
  where(date: start_date..end_date)
}

# 让数据库做统计（避免 Ruby 遍历）
stats = Transaction.where(date: 5.years.ago..Time.now)
                   .group("date_trunc('month', date)")
                   .sum(:amount)
```

### 大批量数据导出

当数据量达到几万条时，传统的 `.all.each` 会导致内存爆炸。**必须使用 `find_each`**:

```ruby
require 'csv'

def export_all_transactions
  file_path = "tmp/transactions_#{Time.now.to_i}.csv"
  
  CSV.open(file_path, "wb") do |csv|
    csv << ["日期", "类别", "金额", "备注"]
    
    Transaction.find_each(batch_size: 1000) do |t|
      csv << [t.date, t.category&.name, t.amount, t.note]
    end
  end
  
  puts "导出完成：#{file_path}"
end
```

### 批量操作

```ruby
# 使用 find_each 处理大批量数据
Transaction.find_each(batch_size: 1000) do |transaction|
  # 处理每条记录
end
```

## Git 提交规范

```
<type>: <subject>

<body>

<footer>
```

Type:
- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档变更
- `style`: 代码格式
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试
- `chore`: 构建/工具

## 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| DB_HOST | 数据库主机 | localhost |
| DB_USERNAME | 数据库用户名 | postgres |
| DB_PASSWORD | 数据库密码 | - |
| RAILS_MASTER_KEY | Rails 主密钥 | - |

## 常用命令

```bash
# 安装依赖
bundle install

# 数据库迁移
rails db:migrate

# 运行开发服务器
rails s

# 运行测试
rails test

# 代码检查
bundle exec rubocop
```
