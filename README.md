# Ledger

一个用 Ruby on Rails 8 构建的个人记账系统。

## 技术栈

- 后端：Ruby on Rails 8
- 数据库：PostgreSQL
- 前端：Tailwind CSS + Hotwire
- 组件化：ViewComponent
- 部署：Docker + Kamal

## 快速启动

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

- `GET /api/external/health` - 健康检查
- `GET /api/external/context` - 获取上下文
- `POST /api/external/transactions` - 创建交易
- `GET /api/currency/rates` - 汇率信息

## 测试

```bash
bundle exec rspec
```

## 部署

```bash
docker compose up -d
```

## 许可证

MIT