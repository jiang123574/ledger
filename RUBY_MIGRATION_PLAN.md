# My Ledger - Ruby SSR 重写计划

## 项目概述

将现有前后端分离项目（FastAPI + Vue.js）迁移到 Ruby on Rails 服务端渲染架构。

## 技术栈对比

| 层级 | 当前技术 | 目标技术 |
|------|----------|----------|
| 后端 | FastAPI (Python) | Ruby on Rails 8 |
| 数据库 | SQLite + SQLAlchemy | PostgreSQL + ActiveRecord |
| 前端渲染 | Vue 3 SPA | Rails SSR + Turbo/Htmx |
| 状态管理 | Pinia | Session/Cookies |
| 构建工具 | Vite | Propshaft/Simports |
| 图表 | Chart.js/ECharts | Chart.js (CDN) |

## 数据模型映射

### Ruby Models (app/models/)

```
currency.rb          -> Currency
exchange_rate.rb     -> ExchangeRate
tag.rb               -> Tag
category.rb          -> Category
account.rb           -> Account
transaction.rb       -> Transaction
receivable.rb        -> Receivable
counterparty.rb      -> Counterparty
plan.rb              -> Plan
budget.rb            -> Budget
one_time_budget.rb   -> OneTimeBudget
recurring_transaction.rb -> RecurringTransaction
backup_record.rb     -> BackupRecord
attachment.rb        -> Attachment
import_batch.rb      -> ImportBatch
```

### 关联关系保持不变
- Transaction <-> Tag: 多对多 (transaction_tags)
- Transaction -> Account: 多对一
- Transaction -> Category: 多对一
- Transaction -> Receivable: 多对一

## 执行计划

### 阶段 1: 项目初始化
- [x] 创建 Rails 8 项目
- [x] 配置 SQLite 数据库
- [x] 配置 Tailwind CSS (CDN)
- [x] 路由配置

### 阶段 2: 数据模型迁移
- [x] 创建所有 Model 文件
- [x] 配置数据库迁移
- [x] 建立索引和关联
- [ ] 迁移种子数据

### 阶段 3: 控制器和视图
- [x] Dashboard (仪表盘)
- [x] Transactions (交易管理)
- [x] Accounts (账户管理)
- [x] Categories & Tags (分类标签)
- [x] Budgets (预算)
- [x] Plans (计划)
- [x] Settings (设置)
- [x] Recurring (定期交易)

### 阶段 4: API 端点 (外部调用)
- [ ] /api/external/* 端点保持兼容
- [ ] 汇率 API

### 阶段 5: 功能和组件
- [ ] 图表组件 (Dashboard)
- [ ] 日历热力图
- [ ] 交易导入/导出
- [ ] 附件管理
- [ ] 备份功能

### 阶段 6: DevOps
- [ ] Docker 配置
- [ ] 环境变量配置
- [ ] 生产环境部署

## 页面结构

```
app/views/
├── layouts/
│   └── application.html.erb
├── dashboard/
│   └── show.html.erb
├── transactions/
│   ├── index.html.erb
│   ├── new.html.erb
│   └── edit.html.erb
├── accounts/
│   ├── index.html.erb
│   ├── new.html.erb
│   └── edit.html.erb
├── categories/
│   └── index.html.erb
├── budgets/
│   └── index.html.erb
├── plans/
│   ├── index.html.erb
│   ├── new.html.erb
│   └── edit.html.erb
├── tags/
│   └── index.html.erb
├── recurring/
│   ├── index.html.erb
│   ├── new.html.erb
│   └── edit.html.erb
└── settings/
    └── show.html.erb
```

## 文件结构

```
ledger/
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── transactions_controller.rb
│   │   ├── accounts_controller.rb
│   │   ├── categories_controller.rb
│   │   ├── tags_controller.rb
│   │   ├── budgets_controller.rb
│   │   ├── plans_controller.rb
│   │   ├── recurring_controller.rb
│   │   └── settings_controller.rb
│   └── models/
│       ├── application_record.rb
│       ├── currency.rb
│       ├── exchange_rate.rb
│       ├── tag.rb
│       ├── category.rb
│       ├── account.rb
│       ├── transaction.rb
│       ├── receivable.rb
│       ├── counterparty.rb
│       ├── plan.rb
│       ├── budget.rb
│       ├── one_time_budget.rb
│       ├── recurring_transaction.rb
│       ├── backup_record.rb
│       ├── attachment.rb
│       └── import_batch.rb
├── config/
│   └── routes.rb
├── db/
│   ├── migrate/
│   └── schema.rb
└── public/
```

## 实施优先级

1. **高优先级**: Models, Transactions, Dashboard
2. **中优先级**: Accounts, Categories, Budgets
3. **低优先级**: Reports, Settings, 备份/导入功能

## 风险和注意事项

- 外部 API 兼容性需要保持
- 图表组件需要重新实现
- 移动端适配需要使用 Rails 的响应式设计
- 定期交易逻辑需要重新实现为 ActiveJob

## 启动方式

```bash
cd ledger
export PATH="/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH"
bin/rails server -p 3000
```

访问 http://localhost:3000
