# 项目审查报告：Ledger (个人记账系统)

**审查日期**: 2026-04-21  
**审查范围**: 全项目代码库  
**审查方式**: 静态代码分析 + 架构评估

---

## 项目概述

| 指标 | 数据 |
|------|------|
| 技术栈 | Rails 8.1 + Ruby 3.3 + PostgreSQL 16 + Hotwire + Tailwind v4 |
| 代码量 | ~28,000 行 |
| 模型 | 24 个 (含 Entryable delegated_type) |
| 控制器 | 28 个 |
| 服务类 | 11 个 |
| Stimulus 控制器 | 37 个 |
| 测试文件 | 80+ 个 |
| DS 组件 | 21 个 ViewComponent |

---

## 架构评价

### ✅ 优秀设计

#### 1. Delegated Type 模式

`Entry` → `Entryable::Transaction/Valuation/Trade`

- 参考 Sure 项目设计，统一财务记录入口
- 避免 STI 的复杂性，支持多态查询
- `Entry.preload_transfer_accounts` 有效解决 N+1 问题

```ruby
# app/models/entry.rb
delegated_type :entryable, types: Entryable::TYPES, dependent: :destroy
```

#### 2. 数据库索引策略

- pg_trgm 扩展支持 `name`/`notes` 模糊搜索
- 复合索引覆盖常见查询场景 (`idx_entries_account_date_type`)
- 条件索引优化存储 (`idx_entries_excluded` WHERE clause)

```ruby
# db/schema.rb 示例
add_index :entries, [:account_id, :date, :entryable_type], name: "idx_entries_account_date_type"
add_index :entries, :excluded, where: "excluded = true", name: "idx_entries_excluded"
```

#### 3. 前端架构

- ViewComponent DS 组件库统一 UI
- Stimulus 控制器职责清晰
- IIFE 包裹 inline script 避免 Turbo 重复声明冲突

---

## 潜在问题

### 🔴 高优先级

#### 1. API External Controller - 保存前跳过验证

**文件位置**: `app/controllers/api/external_controller.rb:31`

```ruby
entryable.save(validate: false)
```

**问题**: 跳过验证可能导致无效数据进入数据库

**影响**: 外部 API 导入的数据可能缺少必要字段，导致后续查询或展示异常

**建议**: 
- 移除 `validate: false`
- 或在保存前添加显式数据校验逻辑

---

#### 2. Entry 模型验证逻辑冲突

**文件位置**: `app/models/entry.rb:30-31`

```ruby
validates :date, :name, :amount, :currency, presence: true, unless: -> { transfer_id.present? }
validates :date, :amount, :currency, presence: true
```

**问题**: 转账条目 `name` 未强制校验，但数据库 `name` 列有 `null: false` 约束

**影响**: 转账创建时如果 `name` 为空，会导致数据库插入失败，但模型验证通过

**建议**: 统一验证逻辑，转账条目也应确保 `name` 存在

---

#### 3. Category 循环引用检测可能触发 N+1

**文件位置**: `app/models/category.rb:155`

```ruby
if self_and_descendants.map(&:id).include?(parent_id)
```

**问题**: `self_and_descendants` 递归加载所有子分类到内存

**影响**: 分类层级深时，性能显著下降

**建议**: 使用 CTE 查询替代（已有 `descendant_ids_for` 类方法可借鉴）

```ruby
# 改进方案示例
def would_create_cycle?(new_parent_id)
  descendant_ids = Category.descendant_ids_for(id)
  descendant_ids.include?(new_parent_id)
end
```

---

### 🟡 中优先级

#### 4. BackupService - shell 命令注入风险

**文件位置**: `app/services/backup_service.rb:202-212`

**现状**:
- 使用 `Open3.capture3` 执行 `pg_dump/psql`
- 参数来自数据库配置，非用户输入

**风险等级**: 低（配置可信）

**建议**: 确保配置文件不被外部修改，或添加参数校验

---

#### 5. Entryable::Transaction belongs_to :merchant 但无 Merchant 模型

**文件位置**: `app/models/entryable/transaction.rb:10`

```ruby
belongs_to :merchant, class_name: "::Merchant", optional: true
```

**问题**: 项目中无 `Merchant` 模型定义

**影响**: 关联查询时会抛出异常，或导致意外行为

**建议**: 移除未使用的关联，或补充 Merchant 模型

---

#### 6. 版本历史无限制

**现状**: `versions` 表无清理策略

**问题**: 长期运行会膨胀，占用大量存储空间

**建议**: 
- 添加定期清理 Job
- 或设置保留策略（如保留最近 1000 条）

```ruby
# 示例清理 Job
class VersionCleanupJob < ApplicationJob
  def perform
    PaperTrail::Version.where("created_at < ?", 1.year.ago).delete_all
  end
end
```

---

### 🟢 低优先级

#### 7. CSP 头过于宽松

**文件位置**: `app/controllers/application_controller.rb:40`

```ruby
"default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'"
```

**问题**: `unsafe-inline` 削弱 CSP 保护，增加 XSS 攻击面

**建议**: 使用 nonce 或 hash 替代（需配合 Turbo 调整）

---

#### 8. JavaScript 内存泄漏风险

**文件位置**: `app/javascript/controllers/entry_list_controller.js:33`

```javascript
window.loadMoreEntries = () => { ... }
```

**问题**: 全局函数未在 disconnect 时清理

**影响**: 页面切换后全局函数残留，可能导致重复执行

**建议**: 移除全局挂载，使用事件委托或 Stimulus action

---

## 安全评估

| 项目 | 状态 | 说明 |
|------|------|------|
| Session 认证 | ✅ | 环境变量配置，可选启用 |
| API Key 认证 | ✅ | secure_compare 防止时序攻击 |
| CSRF | ✅ | 默认启用，API 端点跳过 |
| Rate Limiting | ✅ | Rack::Attack 限制 API/POST |
| 安全头 | ✅ | X-Frame-Options, X-Content-Type-Options |
| SQL 注入 | ✅ | 使用 Arel 构建复杂查询 |
| XSS | ⚠️ | inline script 需注意，已有 IIFE 包裹 |

---

## 测试覆盖

### 现状

- **框架**: RSpec + FactoryBot + SimpleCov
- **覆盖范围**: Models, Requests, Services, Components
- **测试文件数**: 80+

### 缺失项

| 类型 | 建议 |
|------|------|
| 系统测试 | 添加 Capybara 端到端测试覆盖关键业务流程 |
| JavaScript 单元测试 | 添加 Jest/Vitest 测试 Stimulus 控制器逻辑 |
| 边界测试 | 补充更多边界情况测试（空数据、极端值） |

---

## 建议改进清单

### 高优先级 (建议立即处理)

1. [x] 移除 `entryable.save(validate: false)` - 添加显式校验 ✅ PR #152
2. [x] 统一 Entry 验证逻辑 - 转账条目也需要 `name` 校验 ✅ PR #152
3. [x] 优化 Category 循环检测 - 使用 CTE 查询替代 ✅ PR #152

### 中优先级 (建议近期处理)

4. [x] 补充 Merchant 模型或移除关联 ✅ PR #153
5. [x] 添加版本历史清理策略 ✅ PR #153 (ActivityLogCleanupJob)
6. [x] 确保 BackupService 配置安全 ✅ PR #153 (已确认风险低)

### 低优先级 (可选处理)

7. [x] CSP 头配置 - 已评估，保留 `unsafe-inline` 以支持 Turbo inline scripts ✅
8. [x] 清理全局 JavaScript 函数挂载 - 已修复 entry_list_controller disconnect ✅
9. [-] 系统测试覆盖 - 延后处理，当前单元测试覆盖充分

> **CSP 说明**: 项目使用大量 inline scripts (IIFE 包裹) 配合 Turbo，移除 `unsafe-inline` 需要重构所有 erb 模板中的 inline scripts，工作量较大。当前风险评估：风险可接受，建议后续版本逐步迁移到 Stimulus actions 替代 onclick handlers。

---

## 总评

| 维度 | 评分 | 说明 |
|------|------|------|
| **代码质量** | 良好 | 代码风格一致，命名清晰 |
| **架构设计** | 优秀 | delegated_type, ViewComponent 模式运用得当 |
| **安全性** | 基本完善 | 存在少量待改进点，无严重漏洞 |
| **可维护性** | 良好 | 文档完善，测试覆盖充分 |
| **性能** | 良好 | 已有批量查询优化，少量 N+1 待处理 |

---

## 附录：关键文件索引

| 文件 | 说明 |
|------|------|
| `app/models/entry.rb` | Entry 核心模型，delegated_type |
| `app/models/account.rb` | 账户模型，账单周期计算 |
| `app/models/category.rb` | 分类模型，层级管理 |
| `app/controllers/api/external_controller.rb` | 外部 API 导入 |
| `app/services/backup_service.rb` | 数据库备份恢复 |
| `app/components/ds/` | DS 组件库 |
| `app/javascript/controllers/` | Stimulus 控制器 |
| `docs/adr/` | 架构决策记录 |

---

**审查人**: AI Code Review  
**下次审查建议**: 6 个月后或重大功能变更时