# Ledger 项目全面审查报告

**审查日期**: 2026-05-05  
**审查范围**: 安全、代码质量、性能、架构  
**审查版本**: main 分支 (commit 400a5ac)

---

## 执行摘要

Ledger 是一个基于 Rails 8 + Hotwire + Tailwind CSS v4 的个人财务追踪系统。项目整体代码质量良好，遵循 Rails 最佳实践。本次审查发现：

- **安全问题**: 1 个高危（SQL LIKE 注入），1 个中危（innerHTML 使用）
- **代码质量**: 4 个高优先级重构建议（代码重复、过大控制器）
- **性能**: 总体良好，有 2 个优化建议
- **架构**: 需要提取 3 个 Service 对象

---

## 一、安全审查

### 1.1 高危问题：SQL LIKE 通配符注入

**文件**: `app/controllers/versions_controller.rb:23`

```ruby
@operation_logs = @operation_logs.where("description LIKE ?", "%#{params[:search]}%")
```

**问题**: 用户输入的 `%` 和 `_` 字符未转义，可匹配任意记录绕过过滤。

**修复建议**:
```ruby
search_term = params[:search].to_s.gsub(/[%_]/) { |char| "\\#{char}" }
@operation_logs = @operation_logs.where("description LIKE ?", "%#{search_term}%")
```

**参考**: `AccountEntriesQueryService` 第 96 行已正确实现此模式。

---

### 1.2 中危问题：innerHTML 动态内容

**文件**: `app/javascript/controllers/transaction_modal_controller.js:100`

```javascript
container.innerHTML = html // html 来自服务器
```

**问题**: 从服务器获取 HTML 后直接插入，虽然 Rails ERB 默认转义，但需确保编辑端点返回内容已净化。

**建议**: 监控编辑端点返回内容，确保不包含未转义的用户输入。

---

### 1.3 已正确处理的模式

| 安全措施 | 文件 | 状态 |
|---------|------|------|
| XSS 防护 (escapeHtml) | `selectors.js`, `category_detail_controller.js`, `bill_statement_controller.js` | ✅ 已实现 |
| CSRF Token | 所有 AJAX 请求 | ✅ 正确传递 |
| API 认证 | `external_controller.rb` | ✅ 使用 secure_compare |
| 安全头 | `application_controller.rb` | ✅ X-Frame-Options, CSP 等 |
| 路径遍历防护 | `backups_controller.rb`, `settings_controller.rb` | ✅ File.basename + realpath |

---

## 二、代码质量审查

### 2.1 代码重复

**高优先级：PayablesController 与 ReceivablesController 重复**

两个控制器有 3 个几乎相同的方法：
- `build_counterparty_stats`
- `filter_by_counterparty`
- `counterparty_filter_token_for`

**建议**: 创建 `app/controllers/concerns/counterparty_filterable.rb`

---

**中优先级：资产/净资产趋势计算重复**

涉及文件：
- `reports_controller.rb:220-271, 273-296`
- `dashboard_controller.rb:152-233`
- `account.rb:46-57, 64-76`

**建议**: 创建 `AccountBalanceService`

---

### 2.2 过大控制器

| 控制器 | 行数 | 问题 |
|--------|------|------|
| `ReportsController` | 594 行 | 14 个私有计算方法，应提取为 `ReportGenerationService` |
| `TransactionsController#update` | 84 行 | 复杂分支逻辑，应提取为 `EntryUpdateService` |
| `AccountsController#entries` | 100+ 行 | JSON 构建逻辑，应提取为 `AccountEntriesResponseService` |

---

### 2.3 视图逻辑过多

**关键问题**: `accounts/index.html.erb` (956 行)

- 第 342-371 行：Entry 类型判断逻辑
- 第 382-391 行：CSS 类选择逻辑
- 第 471-479 行：移动端显示逻辑

**建议**: 创建 `EntryDisplayHelper` 或使用 `EntryPresenter`

---

### 2.4 复杂方法需简化

| 方法 | 文件 | 行数 |
|------|------|------|
| `Account#bill_cycles_with_statement` | `account.rb` | 75 行 |
| `Account#batch_bill_cycle_summary` | `account.rb` | 65 行 |
| `ReportsController#compute_sankey_data` | `reports_controller.rb` | 93 行 |
| `Entry#bulk_update!` | `entry.rb` | 47 行 |

---

### 2.5 JavaScript 控制器过大

| 控制器 | 行数 | 建议 |
|--------|------|------|
| `transaction_modal_controller.js` | 676 行 | 拆分为 TransactionForm, CategorySelector, AccountSelector |
| `account_page_controller.js` | 490 行 | 拆分为 AccountFilter, PeriodPicker |

---

### 2.6 N+1 预防（已良好实现）

项目已正确实现：
- `Entry.preload_transfer_accounts` - 批量预加载转账配对账户
- `Budget.preload_spent_amounts` - 批量预加载预算支出
- 控制器中多处 `includes` 调用

---

## 三、性能审查

### 3.1 数据库索引（已良好实现）

`db/schema.rb` 包含完善的索引：
- `idx_entries_account_date` - 账户+日期过滤
- `idx_entries_report_transactions` - 报表查询（部分索引）
- `idx_entries_name_trgm`, `idx_entries_notes_trgm` - GIN 三字母搜索
- `idx_entryable_transactions_category_kind` - 分类+类型过滤

---

### 3.2 缓存策略（俄罗斯套娃模式）

使用 `CacheBuster` 版本控制：
```ruby
# lib/cache_config.rb
FAST = 30.seconds    # 高频数据
SHORT = 1.minute     # 交易列表
MEDIUM = 2.minutes   # 统计数据
LONG = 1.hour        # 账户、分类
```

**问题**: `ReportsController` 缓存键缺少 `CacheBuster.version(:entries)`，可能导致数据过期。

**建议**: 第 47 行添加 `ev = CacheBuster.version(:entries)` 到缓存键。

---

### 3.3 资源加载优化

| 文件 | 大小 | 建议 |
|------|------|------|
| `chart.js.umd.js` | 205KB | 按需懒加载 `import()` |
| 控制器注册 | 59 个 upfront | 使用 `stimulus-loading.js` 懒加载 |

---

### 3.4 API 响应优化

**问题**: `AccountsController#entries` 内联 JSON 构建返回 18 个字段

**建议**:
1. 使用 `ActiveModel::Serializer`
2. 列表视图减少返回字段

---

## 四、架构审查

### 4.1 需要提取的 Service 对象

| Service | 来源 | 职责 |
|---------|------|------|
| `ReportGenerationService` | `ReportsController` | 报表数据计算 |
| `AccountBalanceService` | 多处重复 | 账户余额/趋势计算 |
| `TrendDataService` | `ReportsController`, `DashboardController` | 月度/周趋势计算 |
| `EntryUpdateService` | `TransactionsController` | 交易更新逻辑 |

---

### 4.2 需要提取的 Concern

| Concern | 来源 | 方法 |
|---------|------|------|
| `CounterpartyFilterable` | `PayablesController`, `ReceivablesController` | counterparty 过滤方法 |

---

### 4.3 需要创建的 Helper

| Helper | 职责 |
|--------|------|
| `EntryDisplayHelper` | Entry 显示类型、CSS 类、转账对手计算 |

---

## 五、修复优先级

### 立即修复（P0）

1. **SQL LIKE 注入** - `versions_controller.rb:23`
2. **ReportsController 缓存键** - 添加 entries 版本

### 短期修复（P1）

1. **提取 CounterpartyFilterable concern**
2. **拆分 transaction_modal_controller.js**
3. **简化 accounts/index.html.erb 视图逻辑**

### 中期改进（P2）

1. 创建 `ReportGenerationService`
2. 创建 `AccountBalanceService`
3. Chart.js 按需懒加载
4. JSON 序列化优化

### 长期优化（P3）

1. 控制器懒加载
2. 大方法拆分
3. 错误处理增强

---

## 六、总体评价

| 维度 | 评分 | 说明 |
|------|------|------|
| 安全 | B+ | 1 个高危问题需立即修复，其余防护完善 |
| 代码质量 | B | 有重复代码和过大控制器，但不影响功能 |
| 性能 | A- | 索引完善、N+1 预防良好、缓存策略合理 |
| 架构 | B | 需要提取 Service，但结构清晰 |
| 测试覆盖 | 未审查 | 建议补充 |

**结论**: 项目整体实现良好，核心功能稳定。建议优先修复安全问题，逐步重构代码重复和过大控制器。

---

**审查人**: Claude Opus 4.7  
**报告生成**: 2026-05-05