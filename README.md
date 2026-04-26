# Ledger

一个用 Ruby on Rails 8 构建的个人记账系统，专注于简洁的用户体验和高效的记账流程。

## 技术栈

| 层级 | 技术 |
|------|------|
| **后端** | Ruby 3.3.10 + Rails 8.1.3 |
| **数据库** | PostgreSQL 16（含 pg_trgm 模糊搜索扩展） |
| **前端** | Hotwire (Turbo + Stimulus) + Tailwind CSS v4 |
| **组件化** | ViewComponent（21 个 DS 组件） |
| **资产管理** | Propshaft + Importmap-rails |
| **图表** | Chart.js |
| **部署** | Docker + Kamal + Thruster |

## 快速启动

### 本地开发

```bash
# 安装依赖
brew install postgresql@16
brew services start postgresql@16
bundle install

# 创建数据库
createdb ledger_dev -U postgres
bin/rails db:migrate db:seed

# 启动服务器
bin/rails server -p 3000
```

访问 http://localhost:3000

## 功能特性

### 核心功能
- 💰 **交易管理** - 5 种交易类型，标签系统，批量操作
- 🏦 **账户管理** - 多货币支持，余额追踪
- 📊 **分类管理** - 层级分类，预算追踪
- 📋 **应收款管理** - 报销流程，状态追踪
- 📅 **计划管理** - 分期还款，定期支出

### 数据管理
- 📥 **导入数据** - 支持 CSV/Excel/OFX/QIF
- ☁️ **云备份** - WebDAV 自动备份
- 📈 **报表统计** - 年度/月度报表，趋势分析

### UI/UX
- 🎨 **Design System** - 完整的组件库
- 📱 **移动端适配** - Safe Area 支持
- ⌨️ **快捷键** - 全局快捷键支持

## 项目结构

```
app/
├── components/ds/      # Design System 组件
├── controllers/        # 控制器
├── models/            # 数据模型
├── views/             # 视图模板
├── javascript/        # Stimulus 控制器
└── services/          # 服务类
```

## 开发指南

详细的开发规范和已实现功能清单，请参阅：

👉 **[AGENTS.md](./AGENTS.md)**

## 环境变量

| 变量 | 说明 |
|------|------|
| DB_HOST | 数据库主机 |
| DB_USERNAME | 数据库用户名 |
| DB_PASSWORD | 数据库密码 |
| AUTH_USER | 登录用户名（可选，未设置时跳过认证） |
| AUTH_PASSWORD | 登录密码（可选，未设置时跳过认证） |
| EXTERNAL_API_KEY | 外部 API 密钥 |

## 认证

生产环境支持 Session 登录认证：

- 设置 `AUTH_USER` 和 `AUTH_PASSWORD` 后，访问需要登录
- 未设置时，跳过认证（适用于内网或本地开发）
- 登录页面：`/login`
- 登出：`/logout`

## API 端点

- `GET /api/v1/external/health` - 健康检查
- `GET /api/v1/external/context` - 获取上下文
- `POST /api/v1/external/transactions` - 创建交易
- `GET /api/currency/rates` - 汇率信息

## 测试

```bash
bundle exec rspec
```

## Docker 部署

```bash
docker compose up -d
```

## 功能特性

### 💰 交易管理
- 统一 Entry 模型，支持 3 种交易类型（Transaction / Trade / Valuation）
- 标签系统（多对多多态关联）
- 批量操作（批量删除）
- 交易搜索（pg_trgm 模糊匹配）
- 版本历史追踪（PaperTrail）

### 🏦 账户管理
- 多种账户类型（现金、信用卡、投资等）
- 多货币支持（CNY/USD/EUR 等）
- 余额追踪与统计
- 信用卡账单周期管理
- 账户拖拽排序

### 📊 分类管理
- 层级分类（父子关系）
- 预算追踪（月度预算 + 单次预算）
- 分类统计与对比

### 📋 应收/应付管理
- 应收款报销流程
- 应付款结算追踪
- 对手方管理（Counterparty）
- 状态追踪（未结/已结）

### 📅 计划管理
- 分期还款计划
- 定期支出（Recurring Transaction）
- 自动生成交易条目

### 📥 数据管理
- CSV/Excel/OFX/QIF 导入
- 貔貅（Pixiu）数据导入
- WebDAV 云备份
- 数据导出

### 📈 报表统计
- 年度/月度报表
- 桑基图（Sankey）收支流向
- 趋势分析图表
- 分类对比分析

### 🎨 UI/UX
- 完整的 Design System 组件库（21 个组件）
- 移动端适配（Safe Area 支持）
- 全局快捷键
- PWA 支持
- 暗色主题

## 项目结构

```
app/
├── components/          # ViewComponent 组件
│   └── ds/             # Design System 组件库（21 个）
├── controllers/        # 控制器（25 个）
│   ├── concerns/      # 控制器 Concerns
│   └── api/           # API 控制器
├── models/             # 数据模型（26 个）
│   ├── concerns/      # 模型 Concerns
│   └── entryable/     # Entry 子类型（3 个）
├── services/           # 服务对象（12 个）
├── views/              # 视图模板（39 个）
├── javascript/         # Stimulus 控制器（37 个）
│   └── controllers/   # JS 控制器
├── helpers/            # Helper 模块
├── jobs/               # 后台任务
└── middleware/         # 中间件
```

## 数据模型

### 核心模型

| 模型 | 说明 |
|------|------|
| `Account` | 账户（现金/信用卡/投资） |
| `Entry` | 交易条目（统一入口，delegated_type） |
| `Category` | 分类（层级结构） |
| `Budget` | 月度预算 |
| `SingleBudget` | 单次预算 |
| `Payable` | 应付款 |
| `Receivable` | 应收款 |
| `Plan` | 分期计划 |
| `RecurringTransaction` | 定期交易 |
| `Counterparty` | 交易对手 |
| `Tag` / `Tagging` | 标签系统 |
| `Currency` / `ExchangeRate` | 货币与汇率 |
| `BillStatement` | 信用卡账单 |

### Entry 子类型（Delegated Type）

| 类型 | 说明 |
|------|------|
| `Entryable::Transaction` | 普通交易（含分类、标签） |
| `Entryable::Trade` | 投资交易（证券买卖） |
| `Entryable::Valuation` | 资产估值 |

## API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/v1/external/health` | GET | 健康检查 |
| `/api/v1/external/context` | GET | 获取上下文 |
| `/api/v1/external/transactions` | POST | 创建交易 |
| `/api/currency/rates` | GET | 汇率信息 |

## 认证

- 设置 `AUTH_USER` 和 `AUTH_PASSWORD` 后启用 Session 登录
- 未设置时跳过认证（适用于内网或本地开发）
- 登录页：`/login`，登出：`/logout`

## 环境变量

| 变量 | 说明 | 必需 |
|------|------|------|
| `DB_HOST` | 数据库主机 | 生产环境 |
| `DB_USERNAME` | 数据库用户名 | 生产环境 |
| `DB_PASSWORD` | 数据库密码 | 生产环境 |
| `AUTH_USER` | 登录用户名 | 可选 |
| `AUTH_PASSWORD` | 登录密码 | 可选 |
| `EXTERNAL_API_KEY` | 外部 API 密钥 | 可选 |
| `RAILS_MASTER_KEY` | Rails 主密钥 | 生产环境 |

## 测试

```bash
# 运行全部测试
bundle exec rspec

# 运行单个文件
bundle exec rspec spec/models/entry_spec.rb

# 查看覆盖率报告
open coverage/index.html
```

- 测试框架：RSpec
- 覆盖率：SimpleCov
- 测试工厂：FactoryBot
- 测试用例：~85 个文件，覆盖模型、控制器、服务、组件

## 开发工具

```bash
# 代码风格检查
bundle exec rubocop

# 安全扫描
bundle exec brakeman

# N+1 查询检测
# 开发环境自动启用 Bullet

# 数据库迁移
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails db:migrate
```

## 文档

- [待办事项](./TODO.md) - 当前活跃的优化任务
- [已完成任务](./DONE.md) - 历史完成记录
- [DS 组件库](./app/components/ds/README.md) - Design System 组件文档
- [AccountDashboardService](./docs/ACCOUNT_DASHBOARD_SERVICE.md) - 账户仪表盘服务文档
- [拼音选择器](./docs/PINYIN_SELECTOR_GUIDE.md) - 拼音筛选组件指南
- [API 文档](./docs/API.md) - REST API 和 JSON API 详细说明
- [架构决策记录](./docs/adr/) - 关键架构决策和设计原则

## 许可证

MIT
