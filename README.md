# My Ledger

一个用 Ruby on Rails 8 构建的个人记账系统。

## 技术栈

- 后端：Rails 8
- 数据库：PostgreSQL
- 前端：Tailwind CSS + Chart.js
- 部署：Docker + Kamal

## 快速启动

### 1. 安装依赖

```bash
cd ledger
brew install postgresql@16
brew services start postgresql@16
```

### 2. 安装 Ruby 依赖

```bash
# 如果没有 Ruby 3.3+
brew install ruby@3.3
export PATH="/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH"
bundle install
```

### 3. 创建数据库

```bash
createdb ledger_dev -U postgres
bin/rails db:migrate db:seed
```

### 4. 启动服务器

```bash
bin/rails server -p 3000
```

访问 http://localhost:3000

## Docker 部署

```bash
docker compose up -d --build
```

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| DB_USERNAME | postgres | 数据库用户名 |
| DB_PASSWORD | | 数据库密码 |
| DB_HOST | localhost | 数据库主机 |
| EXTERNAL_API_KEY | | 外部 API 密钥 |

## API 端点

- `GET /api/external/health` - 健康检查
- `GET /api/external/context` - 获取账户/分类/标签列表
- `POST /api/external/transactions` - 创建交易
- `GET /api/currency/rates` - 汇率信息
