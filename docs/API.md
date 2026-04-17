# API 文档

更新时间：2026-04-16

---

## 认证

页面级功能使用 session 认证（Cookie）。API 端点见下方说明。

---

## REST 资源

### 账户 (Accounts)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/accounts` | 账户列表 |
| GET | `/accounts/:id` | 账户详情（交易列表） |
| POST | `/accounts` | 创建账户 |
| PATCH | `/accounts/:id` | 更新账户 |
| DELETE | `/accounts/:id` | 删除账户 |
| GET | `/accounts/stats` | 账户统计 |
| GET | `/accounts/entries` | 账户条目（AJAX） |
| PATCH | `/accounts/:id/reorder` | 调整账户排序 |
| GET | `/accounts/:id/versions` | 账户变更历史 |
| GET | `/accounts/:id/bills` | 账单列表 |
| GET | `/accounts/:id/bills_entries` | 账单条目 |
| PATCH | `/accounts/:id/reorder_entries` | 调整条目排序 |
| POST | `/accounts/:id/bill_statements` | 创建账单金额 |

### 交易条目 (Entries)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/entries` | 条目列表 |
| POST | `/entries` | 创建条目 |
| PATCH | `/entries/:id` | 更新条目 |
| DELETE | `/entries/:id` | 删除条目 |
| POST | `/entries/bulk_destroy` | 批量删除 |
| GET | `/entries/:id/versions` | 条目变更历史 |

### 分类 (Categories)

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/categories` | 创建分类 |
| PATCH | `/categories/:id` | 更新分类 |
| DELETE | `/categories/:id` | 删除分类 |

### 标签 (Tags)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/tags` | 标签列表 |
| POST | `/tags` | 创建标签 |
| PATCH | `/tags/:id` | 更新标签 |
| DELETE | `/tags/:id` | 删除标签 |

### 交易对手 (Counterparties)

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/counterparties` | 创建交易对手 |
| PATCH | `/counterparties/:id` | 更新交易对手 |
| DELETE | `/counterparties/:id` | 删除交易对手 |

### 预算 (Budgets)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/budgets` | 预算列表 |
| POST | `/budgets` | 创建预算 |
| PATCH | `/budgets/:id` | 更新预算 |
| DELETE | `/budgets/:id` | 删除预算 |
| GET | `/budgets/:id/data` | 预算数据 |

### 计划 (Plans)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/plans` | 计划列表 |
| GET | `/plans/:id` | 计划详情 |
| POST | `/plans` | 创建计划 |
| PATCH | `/plans/:id` | 更新计划 |
| DELETE | `/plans/:id` | 删除计划 |
| POST | `/plans/:id/execute` | 执行计划 |

### 应收款 (Receivables)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/receivables` | 应收款列表 |
| GET | `/receivables/:id` | 应收款详情 |
| POST | `/receivables` | 创建应收款 |
| PATCH | `/receivables/:id` | 更新应收款 |
| DELETE | `/receivables/:id` | 删除应收款 |
| GET | `/receivables/:id/settle` | 结算表单 |
| POST | `/receivables/:id/settle` | 执行结算 |
| POST | `/receivables/:id/revert` | 撤销结算 |

### 应付款 (Payables)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/payables` | 应付款列表 |
| GET | `/payables/:id` | 应付款详情 |
| POST | `/payables` | 创建应付款 |
| PATCH | `/payables/:id` | 更新应付款 |
| DELETE | `/payables/:id` | 删除应付款 |
| GET | `/payables/:id/settle` | 结算表单 |
| POST | `/payables/:id/settle` | 执行结算 |
| POST | `/payables/:id/revert` | 撤销结算 |

### 定期交易 (Recurring)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/recurring` | 定期交易列表 |
| POST | `/recurring` | 创建定期交易 |
| PATCH | `/recurring/:id` | 更新定期交易 |
| DELETE | `/recurring/:id` | 删除定期交易 |
| POST | `/recurring/:id/execute` | 执行定期交易 |

### 导入 (Imports)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/imports/new` | 导入表单 |
| POST | `/imports` | 执行导入 |
| POST | `/imports/preview` | 预览导入 |
| GET | `/imports/templates` | 下载模板 |
| GET | `/imports/pixiu` | 貔貅导入表单 |
| POST | `/imports/pixiu_upload` | 貔貅上传 |
| POST | `/imports/pixiu_confirm` | 貔貅确认导入 |

### 备份 (Backups)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/backups` | 备份列表 |
| POST | `/backups` | 创建备份 |
| DELETE | `/backups/:id` | 删除备份 |
| GET | `/backups/:id/download` | 下载备份 |
| POST | `/backups/:id/restore` | 恢复备份 |
| POST | `/backups/:id/webdav_upload` | 上传到 WebDAV |
| POST | `/backups/webdav_connect` | 连接 WebDAV |
| GET | `/backups/webdav_test` | 测试 WebDAV |
| POST | `/backups/enable_auto_backup` | 启用自动备份 |
| POST | `/backups/disable_auto_backup` | 禁用自动备份 |
| GET | `/webdav/download` | WebDAV 下载 |

### 报表 (Reports)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/reports` | 当前年度报表 |
| GET | `/reports/:year` | 指定年度报表 |
| GET | `/reports/:year/:month` | 指定月度报表 |

### 仪表盘 (Dashboard)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/dashboard` | 仪表盘 |

### 设置 (Settings)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/settings` | 设置页面 |
| POST | `/settings/export` | 导出数据 |
| POST | `/settings/import` | 导入数据 |
| POST | `/settings/validate_import` | 验证导入 |
| POST | `/settings/backup` | 创建备份 |
| POST | `/settings/restore_upload` | 上传恢复文件 |
| GET | `/settings/backup/:name` | 下载备份文件 |
| POST | `/settings/clear_data` | 清除所有数据 |
| POST | `/settings/shortcuts/reset` | 重置快捷键 |

### 版本历史 (Versions)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/versions` | 版本列表 |
| GET | `/versions/:id` | 版本详情 |
| POST | `/versions/:id/revert` | 回滚版本 |

---

## JSON API

### 外部 API (`/api/external`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/external/health` | 健康检查 |
| GET | `/api/external/context` | 获取上下文信息 |
| POST | `/api/external/transactions` | 创建交易（外部调用） |

### 内部 API (`/api`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/currency/rates` | 汇率数据 |
| POST | `/api/vitals` | 上报性能数据 |
