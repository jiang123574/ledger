# My Ledger

一个个人记账系统，前后端分离：
- 后端：FastAPI + SQLAlchemy + SQLite
- 前端：Vue 3 + Pinia + Vite

![效果展示](https://github.com/jiang123574/my-ledger/blob/main/images/PixPin_2025-11-28_20-15-42.png)

## 核心功能

- 账户、分类、交易、计划、预算、标签管理
- 报销/垫付/转账场景支持
- 仪表盘汇总、收支趋势、账户余额趋势
- 定期交易（Recurring）自动处理
- 数据导入/导出
- 多币种与汇率接口
- 外部 API（供 AI 或自动化流程调用）

## 快速启动

### 方式一：Docker（推荐）

```bash
docker compose up -d --build
```

- 前端：`http://localhost:8899`
- 后端：`http://localhost:${BACKEND_PORT:-18000}`

### 方式二：本地开发

1. 启动后端

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 18000
```

2. 启动前端

```bash
cd frontend
npm install
npm run dev
```

## 环境变量

- `DATABASE_URL`：数据库连接（默认 `sqlite:///./data/ledger.db`）
- `BACKEND_PORT`：Docker 映射端口（默认 `18000`）
- `EXTERNAL_API_KEY`：启用外部 API 鉴权
- `BACKEND_CORS_ORIGINS`：CORS 白名单（JSON 数组字符串）

示例：

```bash
export EXTERNAL_API_KEY="your-strong-api-key"
export BACKEND_PORT=18000
```

## 外部 API（AI/自动化）

当设置 `EXTERNAL_API_KEY` 后，可使用以下接口：

- `GET /api/external/health`
- `GET /api/external/context`
- `POST /api/external/transactions`

请求头：

```http
X-API-Key: your-strong-api-key
```

调用示例：

```bash
curl -X POST http://localhost:${BACKEND_PORT:-18000}/api/external/transactions \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-strong-api-key" \
  -d '{
    "date": "2026-02-14T10:30:00",
    "type": "EXPENSE",
    "amount": 38.5,
    "category": "午餐",
    "tag": "工作日",
    "note": "外卖",
    "account_id": 1
  }'
```

## 项目结构

```text
my-ledger/
├── backend/
│   ├── main.py
│   ├── models.py
│   ├── schemas.py
│   ├── services.py
│   ├── database.py
│   └── routers/
│       ├── api.py
│       └── currency.py
├── frontend/
│   └── src/
│       ├── views/
│       ├── components/
│       └── stores/
├── docker-compose.yml
└── README.md
```

## 常见问题（FAQ）

### 1) SQLite 报错 `database is locked`

- 优先使用 Docker 方式运行（已配置 WAL 模式）
- 避免同时启动多个后端进程写同一个 `ledger.db`
- 确保数据库文件位于可写目录（默认 `backend/data/`）

### 2) 前端请求失败或跨域（CORS）报错

- 设置后端环境变量 `BACKEND_CORS_ORIGINS`，示例：

```bash
export BACKEND_CORS_ORIGINS='["http://localhost:5173","http://localhost:8899"]'
```

- 重启后端使配置生效

### 3) 端口被占用

- Docker 模式可修改：
  - 后端端口：`BACKEND_PORT`（默认 `18000`）
  - 前端端口：修改 `docker-compose.yml` 中 `frontend.ports`
- 本地模式可修改：
  - 后端：`uvicorn ... --port <新端口>`
  - 前端：`vite --port <新端口>` 或 `npm run dev -- --port <新端口>`

### 4) 外部 API 返回 `401` 或 `503`

- `503`：后端未配置 `EXTERNAL_API_KEY`
- `401`：请求头 `X-API-Key` 与后端配置不一致

建议排查：

```bash
echo $EXTERNAL_API_KEY
curl -H "X-API-Key: your-strong-api-key" http://localhost:${BACKEND_PORT:-18000}/api/external/health
```

### 5) 前端页面打开但没有数据

- 先确认后端是否可访问：`/api/external/health` 或其他接口
- 检查前端开发代理配置与后端端口是否一致
- 检查浏览器 Network 面板中 `/api/*` 请求状态码与错误信息

## 发布与部署建议

### 1) 推荐部署拓扑

- `Nginx`：统一入口、TLS 终止、静态资源缓存、反向代理
- `Frontend`：构建后静态资源（或容器内 Nginx）
- `Backend`：FastAPI + Uvicorn（建议配合进程管理）
- `DB`：SQLite（单机小规模）或后续迁移到 PostgreSQL（多实例/高并发）

### 2) Nginx 反向代理示例

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8899;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:18000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 3) HTTPS 建议

- 使用 `certbot` + Let's Encrypt 自动签发证书
- 强制 HTTP 跳转 HTTPS
- 定期检查证书自动续期是否生效

### 4) 运行与安全建议

- 为 `EXTERNAL_API_KEY` 使用高强度随机值，并定期轮换
- 生产环境限制 `BACKEND_CORS_ORIGINS`，不要使用过宽配置
- 对外仅暴露 Nginx 端口，后端服务绑定内网地址
- 开启日志轮转，避免日志无限增长

### 5) 数据备份建议（SQLite）

- 重点备份目录：`backend/data/`
- 建议每天至少一次快照备份，保留最近 7-30 天版本
- 升级前先手动备份数据库文件
- 定期执行恢复演练，确保备份可用
