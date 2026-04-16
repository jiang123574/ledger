# DONE - 已完成任务记录

更新时间：2026-04-16
维护规则：本文件记录所有已完成的优化任务，供历史查询参考。

---

## P1 - 高优先级

### 1. entry_card_renderer.js 双模板重构 ✅

**完成日期**: 2026-04-08
**PR**: #64
**优先级**: 高
**预估工期**: 1-2 天

**背景**:
- 桌面端和移动端使用两套独立的 HTML 模板
- 数据字段不一致（`data-field="date"` vs `data-field="date-mobile"`）
- 50% 的 DOM 节点被隐藏但仍占用内存
- 维护成本高：任何修改需要同时更新两处代码

**完成内容**:
- [x] 合并双端模板为单一响应式模板
- [x] 使用 `hidden lg:block` / `lg:hidden` 等 CSS 控制显示
- [x] 统一数据字段命名（移除 `-mobile` 后缀）
- [x] 减少 DOM 节点数 40-50%
- [x] 合并 entry_card_renderer.js 模板
- [x] 合并 accounts/index.html.erb 交易列表模板

**相关文件**:
- `app/javascript/entry_card_renderer.js`
- `app/views/accounts/index.html.erb`

---

## P2 - 中优先级

### 2. Receivables 字段完整迁移 ✅

**完成日期**: 2026-04-08
**PR**: #68
**优先级**: 中
**预估工期**: 2-3 小时

**背景**:
- Payables 已完成迁移：counterparty（字符串）→ counterparty_id（外键）
- Receivables 仍保留 counterparty 字符串字段以保持兼容
- 字段冗余导致维护成本增加

**完成内容**:
- [x] 创建迁移脚本 `20260408000000_migrate_receivables_counterparty_to_foreign_key.rb`
- [x] 创建缺失的 Counterparty 记录
- [x] 更新 receivables.counterparty_id
- [x] 删除 receivables.counterparty 字符串字段
- [x] 新增集成测试覆盖迁移

**相关文件**:
- `db/migrate/20260408000000_migrate_receivables_counterparty_to_foreign_key.rb`
- `app/models/receivable.rb`
- `spec/models/p3_phase_2_migration_spec.rb`

---

### 3. 清理 Docker 镜像中的 devDependencies ✅

**完成日期**: 2026-04-08
**PR**: #68
**优先级**: 中
**预估工期**: 0.5 小时

**背景**:
- Dockerfile 使用 `npm install` 安装所有依赖（包括 devDependencies）
- Tailwind CSS 编译后，devDependencies 不再需要
- 增加镜像大小约 5-10MB

**完成内容**:
- [x] 在 Dockerfile 中添加 `npm prune --production`
- [x] 将清理命令放在 Tailwind CSS 编译后
- [x] 添加 `npm cache clean --force` 进一步减小镜像

**相关文件**:
- `Dockerfile`

---

## P3 - 低优先级

### 4. Transaction 模型完全移除 ✅

**完成日期**: 2026-04-11
**PR**: #88
**优先级**: 低
**预估工期**: 4-6 小时（分三个 PR）

**背景**:
- 当前系统已是纯 Entry 体系
- Transaction 模型仅保留用于反向兼容

**完成内容**:
- [x] Phase 3b-1: 代码清理
  - 移除 `source_transaction_id` 字段和关联
  - 删除所有 `has_many :xxx_transactions` 关联
  - 清理兼容性回退代码
- [x] Phase 3b-2: 表清理
  - 删除 transactions 表
  - 删除 transaction_tags 表
  - 从 entryable_transactions 移除 source_transaction_id
  - 从 payables 移除 source_transaction_id
  - 更新 schema.rb
- [x] Phase 3b-3: 验证
  - 完整测试套件运行

**相关文件**:
- `app/models/transaction.rb`（已删除）
- `app/models/entry.rb`
- `db/migrate/`

---

### 5. 性能优化 ✅

**完成日期**: 2026-04-08
**PR**: #68, #72

#### 5.1 优化 sort_by! 性能（O(n²) → O(n)）

**完成内容**:
- [x] 将时间复杂度从 O(n²) 优化为 O(n)
- [x] 预计算 entry_id 到索引的映射
- [x] 应用到两个 sort_by! 调用位置
- [x] 对 29k+ entries 有显著性能提升
- [x] 添加 nil 边界保护

#### 5.2 查询性能优化

**完成内容**:
- [x] 分析 Entry 表上最常用的查询模式
- [x] 新增复合索引：`(account_id, date, notes)` 和 `(account_id, date, name)`
- [x] 新增 pg_trgm GIN 索引优化 LIKE 搜索
  - 启用 PostgreSQL pg_trgm 扩展
  - 添加 `idx_entries_name_trgm` 和 `idx_entries_notes_trgm` GIN 索引
- [x] 评估 BRIN 索引（暂不实施）

#### 5.3 缓存优化

**完成内容**:
- [x] 移除缓存 key 中的冗余 `sort_direction`
  - 分离为 `build_count_cache_key` 和 `build_entries_cache_key` 方法
- [x] 已有预加载机制：`includes(:source_entry)`

#### 5.4 accounts_controller 缓存键优化

**完成内容**:
- [x] `entries_count` 缓存移除不必要的 `sort_direction`
- [x] `entries_list` 缓存保留 `sort_direction`

**相关文件**:
- `app/controllers/accounts_controller.rb`
- `db/migrate/20260408082312_add_notes_index_to_entries.rb`
- `db/migrate/20260408083000_enable_pg_trgm_and_add_trgm_indexes.rb`

---

### 6. Tailwind CSS v4 迁移清理 ✅

**完成日期**: 2026-04-08
**PR**: #74
**优先级**: 低
**预估工期**: 0.5 小时

**完成内容**:
- [x] 全局搜索 `outline-hidden` 并替换为 `outline-none`
- [x] 检查其他 Tailwind v3 语法残留
- [x] 测试所有页面的 focus 样式

**相关文件**:
- `app/views/dashboard/show.html.erb`
- `app/views/plans/index.html.erb`

---

### 7. JavaScript 语法统一 ✅

**完成日期**: 2026-04-09
**PR**: #78
**优先级**: 低
**预估工期**: 2-3 小时

**完成内容**:
- [x] 将所有 `var` 声明改为 `const` 或 `let`
- [x] 统一代码风格，提高可读性
- [x] 测试所有页面的 JavaScript 功能

**相关文件**:
- `app/views/accounts/index.html.erb`
- `app/views/receivables/index.html.erb`
- `app/views/payables/index.html.erb`

---

### 8. Receivable 转账逻辑优化 ✅

**完成日期**: 2026-04-11
**PR**: #88
**优先级**: 低

**完成内容**:
- [x] update action 实现转账更新
- [x] 添加 Receivable transfer_id validation
- [x] 创建旧数据迁移脚本
- [x] 统一 destroy/destroy! 风格
- [x] 优化 transfer_id 生成策略（使用 UUID）

---

## P9 - 项目审查优化

### 9.1 提升测试覆盖率 ✅

**完成日期**: 2026-04-11
**Issue**: #90
**优先级**: 高
**预估工期**: 1-2 周

**成果**:
- 初始覆盖率 7.66%，完成时 82.62%（+74.96%）
- 新增测试文件约 30 个
- 测试用例总数约 1500+

**完成的测试**:
- [x] Entry 模型测试 (808 行)
- [x] Account 模型测试 (330 行)
- [x] Category 模型测试 (290 行)
- [x] Payable 模型测试 (219 行)
- [x] Receivable 模型测试 (227 行)
- [x] EntryCreationService 测试 (310 行)
- [x] 控制器请求测试（多个）
- [x] 服务层测试（BackupService, ExportService, ImportService, CacheBuster 等）

---

### 9.2 重构 accounts_controller.rb ✅

**完成日期**: 2026-04-11
**Issue**: #91
**优先级**: 高
**预估工期**: 2-3 天

**成果**:
- 644 行 → 312 行 (-51.6%)

**完成内容**:
- [x] 数据准备逻辑提取到 `AccountDashboardService`
- [x] 创建 `EntryPresenter` 简化视图逻辑
- [x] 功能保持不变（1570 测试全部通过）

**相关文件**:
- `app/controllers/accounts_controller.rb`
- `app/services/account_dashboard_service.rb`
- `app/presenters/entry_presenter.rb`

---

## 历史记录

### Tailwind CSS v4 升级 ✅
- 从 v3.4.1 升级到 v4.2.2
- 配置迁移到 CSS @theme 指令
- 添加 @tailwindcss/cli 编译工具
- PR: #63

### 快捷键优化与弹窗完善 ✅
- 快捷键 a/z/d/b 已实现
- 应收款/报销模态框已实现

### 交易记录拖动排序 ✅
- 数据库迁移已应用（sort_order 字段）
- 拖放前端实现完成
- 后端 API 实现完成

### P3 - Entry 模型迁移 ✅
- Attachment / Receivable 关联迁移到 Entry 体系
- Receivable/Payable 完整迁移和兼容性方法
- 数据库迁移脚本和验证任务
- 控制器更新和源 Entry 自动关联

---

---

## P9 - 项目审查后续优化

### 9.3 安全加固 ✅

**完成日期**: 2026-04-15
**PR**: #111
**优先级**: 中

**完成内容**:
- [x] Brakeman 安全扫描（修复 2 个 High 级别路径穿越漏洞）
- [x] 所有表单有 CSRF 保护
- [x] 用户输入适当转义
- [x] 安全响应头（X-Content-Type-Options, X-Frame-Options 等）
- [x] CSP 头已配置（允许 Chart.js CDN）

---

### 9.4 性能监控 ✅

**完成日期**: 2026-04-15
**PR**: #112
**优先级**: 中

**完成内容**:
- [x] rack-mini-profiler 已安装配置（开发环境）
- [x] 慢查询监控已启用（开发环境 >100ms，生产环境 >500ms）

---

## P4 - 账单金额功能后续优化

### 10. 前端重构 - 账单相关全局函数改为 Stimulus controller ✅

**完成日期**: 2026-04-15
**PR**: #114

**完成内容**:
- [x] 全局函数封装为 Stimulus controller
- [x] 与项目现有风格一致

---

### 11. 测试补充 - 账单金额功能测试 ✅

**完成日期**: 2026-04-15
**PR**: #115

**完成内容**:
- [x] 模型验证测试
- [x] 控制器 action 测试
- [x] 正向/反向/精度计算测试

---

### 12. 路由优化 - 改为 RESTful 风格 ✅

**完成日期**: 2026-04-15
**PR**: #116

**完成内容**:
- [x] `create_bill_statement` 路由改为 RESTful

---

### 13. 模型验证错误消息国际化 ✅

**完成日期**: 2026-04-15
**PR**: #117

**完成内容**:
- [x] BillStatement 模型验证错误消息中文国际化

---

## P5 - 代码质量与工具链

### 14. 代码质量工具集成 ✅

**完成日期**: 2026-04-15
**PR**: #113
**优先级**: 中

**完成内容**:
- [x] brakeman CI 集成
- [x] flog/reek 检查
- [x] CI 覆盖率门槛 80%
- [x] GitHub Actions CI 完整配置

---

---

## P6 - 文档完善

### 15. 项目文档完善 ✅

**完成日期**: 2026-04-16
**优先级**: 低

**完成内容**:
- [x] README.md 引用修复（PROJECT_GUIDE.md → AGENTS.md）
- [x] API 端点文档（docs/API.md）
- [x] 架构决策记录 ADR（docs/adr/）
  - ADR-001: Entry 模型迁移
  - ADR-002: 负数支出退款约定
  - ADR-003: Turbo Native 移动端适配
- [x] temp/ 目录已清理

---

**最后更新**: 2026-04-16
**维护者**: 开发团队