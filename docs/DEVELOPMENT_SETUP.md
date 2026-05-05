# Development Environment Setup

**更新日期**: 2026-05-05

## 快速启动

```bash
# 1. 克隆项目
git clone https://github.com/jiang123574/ledger.git
cd ledger

# 2. 安装依赖
bundle install

# 3. 初始化数据库
bin/setup

# 4. 启动服务
bin/dev  # 或 bin/rails server -b 0.0.0.0
```

## 系统要求

- Ruby 3.3.10
- PostgreSQL 16+
- Node.js 18+ (用于 Tailwind CSS)

## 环境变量

### 必需变量

```bash
# .env (可选，大多数配置有默认值)
RAILS_ENV=development
SECRET_KEY_BASE=development_secret
```

### 可选变量

```bash
# External API
EXTERNAL_API_KEY=test_key_for_development

# WebDAV 备份
WEBDAV_URL=https://your-server.com/dav
WEBDAV_USER=username
WEBDAV_PASSWORD=password

# 认证密码 (清除数据等敏感操作)
AUTH_PASSWORD=CONFIRM
```

## 数据库配置

默认使用 PostgreSQL：

```yaml
# config/database.yml
development:
  adapter: postgresql
  database: ledger_development
  host: localhost
  username: postgres
  password:
```

### macOS PostgreSQL

```bash
# 安装
brew install postgresql@16

# 启动服务
brew services start postgresql@16

# 创建数据库
bin/rails db:create
```

## 测试

```bash
# 运行所有测试
bundle exec rspec

# 运行单个文件
bundle exec rspec spec/models/entry_spec.rb

# 运行特定行
bundle exec rspec spec/models/entry_spec.rb:100
```

## 代码质量

```bash
# Ruby 代码检查
bundle exec rubocop

# 安全检查
bundle exec brakeman

# 修复 rubocop 问题
bundle exec rubocop -A
```

## IDE 配置

### VS Code

```json
{
  "rubyLSP.rubyExecutablePath": "/opt/homebrew/bin/ruby",
  "rubyLSP.serverTransportMode": "stdio",
  "[ruby]": {
    "editor.defaultFormatter": "Shopify.ruby-lsp",
    "editor.formatOnSave": true
  }
}
```

### RubyMine

1. Settings → Languages & Frameworks → Ruby
2. Ruby SDK: `/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/ruby`

## 常见问题

### 数据库连接失败

```bash
# 检查 PostgreSQL 状态
brew services list

# 重启服务
brew services restart postgresql@16
```

### Tailwind CSS 未更新

```bash
# 手动构建
bin/rails tailwindcss:build

# 或使用 bin/dev 自动监听
```

### Gem 安装失败

```bash
# 清理并重新安装
bundle clean
bundle install
```

---

**相关文档**: docs/DATABASE_SCHEMA.md, docs/PERFORMANCE_GUIDE.md
