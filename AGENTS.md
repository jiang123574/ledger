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
- **图标**: Heroicons (内嵌 SVG)

## 项目结构

```
app/
├── components/      # ViewComponent 组件
│   ├── ds/        # Design System 基础组件
│   └── ui/        # 业务组件
├── controllers/   # 控制器
├── helpers/       # 视图助手
├── javascript/    # JavaScript
│   └── controllers/  # Stimulus 控制器
├── models/        # 数据模型
├── services/     # 服务类
└── views/        # 视图模板
config/
├── locales/      # 国际化文件
└── ...
lib/
├── money.rb      # 货币处理模块
└── ...
```

## 设计系统 (Design System)

### DS 组件库

位置: `app/components/ds/`

| 组件 | 文件 | 功能 |
|------|------|------|
| Icon | `icon_component.rb` | SVG 图标 |
| Button | `button_component.rb` | 按钮，支持 variants/sizes |
| Badge | `badge_component.rb` | 徽章标签 |
| Card | `card_component.rb` | 卡片容器 |
| Tabs | `tabs_component.rb` | 标签页 |
| Dialog | `dialog_component.rb` | 对话框 |
| EmptyState | `empty_state_component.rb` | 空状态 |
| Input | `input_component.rb` | 输入框 |
| Base | `base_component.rb` | 基础组件 |

### 待添加组件

| 组件 | 说明 | 参考 |
|------|------|------|
| Disclosure | 可折叠内容 | Sure `DS::Disclosure` |
| Alert | 警告提示 | Sure `DS::Alert` |
| Toggle | 开关组件 | Sure `DS::Toggle` |
| Menu | 下拉菜单 | Sure `DS::Menu` |
| Tooltip | 工具提示 | Sure `DS::Tooltip` |

### Button 变体

```ruby
VARIANTS = {
  primary: "bg-inverse text-white hover:bg-inverse-hover",
  secondary: "bg-gray-200 text-primary hover:bg-gray-300",
  destructive: "bg-destructive text-white hover:bg-destructive-hover",
  outline: "border border-border text-primary hover:bg-surface-hover",
  ghost: "text-primary hover:bg-surface-hover",
  link: "text-blue-600 hover:underline"
}
```

### 颜色语义

```css
/* 功能性颜色 */
--color-primary     /* 主文字颜色 */
--color-secondary   /* 次要文字颜色 */
--color-destructive /* 危险/删除操作 */

/* 容器颜色 */
--color-surface      /* 页面背景 */
--color-container    /* 卡片背景 */
--color-container-inset /* 内嵌卡片背景 */

/* 边框 */
--color-border

/* 收入/支出颜色约定 */
--color-income: #ef4444    /* 收入 - 红色 */
--color-expense: #22c55e  /* 支出 - 绿色 */
```

### Tailwind 配置

```javascript
colors: {
  surface: { DEFAULT: '#f8f9fa', hover: '#f1f3f5', inset: '#e9ecef' },
  container: { DEFAULT: '#ffffff', inset: '#f8f9fa' },
  primary: { DEFAULT: '#1a1a1a', hover: '#333333' },
  secondary: { DEFAULT: '#6c757d', hover: '#495057' },
  income: '#ef4444',
  expense: '#22c55e'
}
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

### JavaScript 控制器 (Stimulus)

| 控制器 | 文件 | 功能 |
|--------|------|------|
| auto-submit-form | 待添加 | 表单自动提交 |
| bulk-select | 待添加 | 批量选择 |
| tabs | 待添加 | 标签页切换 |
| disclosure | 待添加 | 折叠面板 |

### 响应式设计

| 断点 | 宽度 | 用途 |
|------|------|------|
| `sm:` | 640px+ | 小屏幕 |
| `md:` | 768px+ | 平板 |
| `lg:` | 1024px+ | 桌面 |
| `xl:` | 1280px+ | 大桌面 |
| `2xl:` | 1536px+ | 超大屏幕 |

### 布局模式

**三栏式布局** (设置页):
```
┌─────┬────────────────────┐
│ 导航 │       主内容        │
│ 224px│       flex-1       │
└─────┴────────────────────┘
```

**移动端布局**:
- 固定顶部导航栏
- 固定底部导航栏
- 内容区域可滚动

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

## Hotwire 局部刷新

数据按"年"或"月"切片加载，使用 Turbo Frames 实现局部刷新:

```erb
<%= turbo_frame_tag "monthly_report" do %>
  <%= render @transactions %>
  <%== pagy_nav(@pagy) %>
<% end %>
```

## i18n 命名规范

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
