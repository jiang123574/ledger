# TODO

更新时间：2026-04-10
维护规则：本文件为项目唯一的待办清单，所有新的待办、优化任务只更新本文件。

---

## P1 - 高优先级（建议 1-2 周内完成）

### 1. entry_card_renderer.js 双模板重构

**优先级**: 高
**预估工期**: 1-2 天
**状态**: ✅ 完成

**背景**:
- 桌面端和移动端使用两套独立的 HTML 模板
- 数据字段不一致（`data-field="date"` vs `data-field="date-mobile"`）
- 50% 的 DOM 节点被隐藏但仍占用内存
- 维护成本高：任何修改需要同时更新两处代码

**目标**:
- 合并双端模板为单一响应式模板 ✅
- 使用 `hidden lg:block` / `lg:hidden` 等 CSS 控制显示 ✅
- 统一数据字段命名（移除 `-mobile` 后缀） ✅
- 减少 DOM 节点数 40-50% ✅

**相关文件**:
- `app/javascript/entry_card_renderer.js`（已优化） ✅
- `app/views/accounts/index.html.erb`（已优化） ✅

**完成内容**:
- [x] 合并 entry_card_renderer.js 模板
  - [x] 统一数据字段命名（移除 `-mobile` 后缀）
  - [x] 使用响应式 CSS 类
  - [x] 更新 JavaScript 处理逻辑
- [x] 合并 accounts/index.html.erb 交易列表模板
  - [x] 统一为单一响应式布局
  - [x] 移除双端重复的 HTML 结构

**验证清单**:
- [x] 桌面端表格布局正确
- [x] 移动端卡片布局正确
- [x] 响应式切换无样式闪现
- [x] DOM 节点数减少 40%+
- [x] 所有交易编辑/删除功能正常

---

## P2 - 中优先级（建议 2-4 周内完成）

### 2. Receivables 字段完整迁移

**优先级**: 中
**预估工期**: 2-3 小时
**状态**: ✅ 完成

**背景**:
- Payables 已完成迁移：counterparty（字符串）→ counterparty_id（外键）
- Receivables 仍保留 counterparty 字符串字段以保持兼容
- 字段冗余导致维护成本增加

**目标**:
- 将所有 receivables.counterparty（字符串）迁移到 counterparty_id（外键） ✅
- 删除 receivables.counterparty 字符串字段 ✅
- 确保数据完整性和一致性 ✅

**实施步骤**:
1. [x] 创建迁移脚本（复用 Payables 的迁移模式）
   - 新建 `20260408000000_migrate_receivables_counterparty_to_foreign_key.rb`
2. [x] 创建缺失的 counterparty 记录
3. [x] 更新 receivables.counterparty_id
4. [x] 删除 receivables.counterparty 字符串字段
5. [x] 新增集成测试覆盖迁移

**相关文件**:
- `db/migrate/20260408000000_migrate_receivables_counterparty_to_foreign_key.rb` ✅
- `app/models/receivable.rb`（无需更改，已使用 counterparty_id）
- `spec/models/p3_phase_2_migration_spec.rb`（可选扩展测试）

**验证清单**:
- [x] 迁移脚本创建
- [x] 本地测试通过
- [x] 集成测试覆盖
- [ ] 生产环境验证
- [ ] 回归测试通过

---

### 3. 清理 Docker 镜像中的 devDependencies

**优先级**: 中
**预估工期**: 0.5 小时
**状态**: ✅ 完成

**背景**:
- Dockerfile 使用 `npm install` 安装所有依赖（包括 devDependencies）
- Tailwind CSS 编译后，devDependencies 不再需要
- 增加镜像大小约 5-10MB

**优化方案**:
```dockerfile
RUN npm install && npm cache clean --force
RUN ./bin/build-css
RUN npm prune --production && npm cache clean --force
```

**相关文件**:
- `Dockerfile`（第 56-67 行已优化） ✅

**完成内容**:
- [x] 在 Dockerfile 中添加 `npm prune --production`
- [x] 将清理命令放在 Tailwind CSS 编译后
- [x] 保证 CSS 编译完整性
- [x] 添加 `npm cache clean --force` 进一步减小镜像

**验证清单**:
- [x] Docker 构建成功
- [x] Tailwind CSS 正常编译
- [ ] 镜像大小减少 5-10MB
- [ ] 功能无影响

---

## P3 - 低优先级（持续优化）

### 4. Transaction 模型完全移除

**优先级**: 低
**预估工期**: 4-6 小时（分三个 PR）
**状态**: ✅ 完成

**背景**:
- 当前系统已是纯 Entry 体系
- Transaction 模型仅保留用于反向兼容
- 迁移脚本支持 Entry/Transaction 双轨制

**目标**:
- 完全移除 Transaction 模型和相关表 ✅

**实施步骤**:

**Phase 3b-1: 代码清理** ✅
- 移除 `source_transaction_id` 字段和关联 ✅
- 删除所有 `has_many :xxx_transactions` 关联 ✅
- 清理兼容性回退代码 ✅

**Phase 3b-2: 表清理** ✅
- 创建最终迁移：删除 transactions 表 ✅
- 删除 transaction_tags 表 ✅
- 更新 schema.rb ✅

**Phase 3b-3: 验证** ✅
- 完整测试套件运行 ✅
- 生产环境滚动部署
- 监控系统正常性

**相关文件**:
- `app/models/transaction.rb`（已删除）✅
- `app/models/entry.rb`（已移除关联）
- `db/migrate/`（已创建迁移）✅
- `config/routes.rb`

**验证清单**:
- [x] 代码清理完成
- [x] 表迁移完成
- [x] 所有测试通过
- [ ] 生产环境验证

---

### 5. 性能优化

**优先级**: 低
**预估工期**: 6-8 小时

**背景**:
- 当前系统有 29,678 个 Entry
- Receivable/Payable 访问需要通过 notes 字段关联 Entry
- 可能存在 N+1 查询问题

**优化项目**:

#### 5.1 优化 sort_by! 性能（O(n²) → O(n)）

**状态**: ✅ 完成

原始实现（O(n²)）:
```ruby
entries.sort_by! { |e| entry_ids.index(e.id) }
```

优化为 O(n):
```ruby
entry_id_to_index = entry_ids.each_with_index.to_h
entries.sort_by! { |e| entry_id_to_index[e.id] || Float::INFINITY }
```

**优化效果**:
- 时间复杂度从 O(n²) 降低为 O(n)
- 对于 29,000+ entries 有显著改进
- 添加 nil 边界保护

**相关文件**:
- `app/controllers/accounts_controller.rb`（第 85-90 行、第 171-177 行已优化） ✅

---

#### 5.2 查询性能优化

**状态**: ✅ 完成

- 运行 bullet gem 检测 N+1 查询（已有预加载机制）
- 分析 Entry 表上最常用的查询模式 ✅
- 新增复合索引：`(account_id, date, notes)` 和 `(account_id, date, name)` ✅
- 新增 pg_trgm GIN 索引优化 LIKE 搜索 ✅
  - 启用 PostgreSQL pg_trgm 扩展
  - 添加 `idx_entries_name_trgm` 和 `idx_entries_notes_trgm` GIN 索引
  - 优化 `%term%` 模式的模糊查询性能
- 评估是否需要 BRIN 索引（时间序列）
  - Entry 表约 30k 条记录，BRIN 索引收益不明显
  - 暂不实施，观察后续数据增长情况

#### 5.3 缓存优化

**状态**: ✅ 完成

- 移除缓存 key 中的冗余 `sort_direction` ✅
  - 对于 `entries_count` 缓存：移除 sort_direction（不影响 count）
  - 对于 `entries_list` 缓存：保留 sort_direction（影响排序顺序和余额计算）
  - 分离为 `build_count_cache_key` 和 `build_entries_cache_key` 方法
- 考虑在 Receivable/Payable 上缓存 source_entry 关联
  - 已有预加载机制：`includes(:source_entry)`
  - 暂不需要额外优化

**验证清单**:
- [ ] N+1 查询检测完成（已有预加载机制）
- [x] 索引优化实施
- [x] 缓存 key 优化完成
- [ ] 性能测试验证

---

#### 5.4 accounts_controller 缓存键优化

**优先级**: 低
**状态**: ✅ 完成
**来源**: PR #74 Code Review

**问题描述**:
- `build_filter_cache_key` 同时用于 `entries_count` 和 `entries_list` 缓存
- `entries_count` 缓存包含了不必要的 `sort_direction` 参数
- 切换排序方向时，count 缓存不会命中，导致轻微缓存浪费

**优化方案**:
```ruby
def build_count_cache_key
  "#{params[:account_id]}_#{params[:type]}_#{params[:period_type]}_#{params[:period_value]}_#{params[:search]}_#{Array(params[:category_ids]).sort.join(',')}"
end

def build_entries_cache_key
  sort_direction = params[:sort_direction]&.downcase || "desc"
  sort_direction = "desc" unless sort_direction.in?(%w[asc desc])
  "#{build_count_cache_key}_#{sort_direction}"
end
```

**预期收益**:
- 减少 count 缓存的冗余存储
- 提升缓存命中率
- 与原有设计保持一致

**相关文件**:
- `app/controllers/accounts_controller.rb`

**备注**:
- 功能正常，非关键问题
- 可在下次重构时一并优化

---

### 8. Receivable 转账逻辑优化（PR #79 Review 建议）

**优先级**: 低
**状态**: ✅ 完成
**来源**: PR #79 Code Review

#### 8.1 update action TODO 未实现

**问题描述**:
- `ReceivablesController#update` 中有 `TODO: 处理新数据（有 transfer_id）- 更新转账金额`
- 若用户修改了 receivable 金额，对应的转账分录不会更新，导致会计数据与 receivable 不一致

**修复方案**:
- 在 update action 中添加处理 transfer_id 的逻辑
- 更新对应 Entry 的 amount、date 等字段

**相关文件**:
- `app/controllers/receivables_controller.rb`

#### 8.2 迁移缺少外键约束

**问题描述**:
- `transfer_id` 和 `reimbursement_transfer_ids` 是普通 integer/text 列，无 FK 约束
- 虽非传统 FK（值对应 entries.transfer_id 而非 entries.id），但建议添加数据库级校验或 model 层 validation

**修复方案**:
- 在 Receivable model 中添加 validation
- 或添加数据库级 check 约束

**相关文件**:
- `app/models/receivable.rb`（已添加 validation） ✅
- `db/migrate/*.rb`

**完成内容**:
- [x] 添加 Receivable transfer_id validation

#### 8.3 无数据迁移脚本 ✅

**问题描述**:
- 旧 receivables 仍用 `source_entry_id`，新逻辑用 `transfer_id`
- 双路径兼容处理正确，但建议添加数据迁移脚本将旧数据统一为新格式

**修复方案**:
- 创建数据迁移脚本 ✅
- 将旧数据的 source_entry_id 转换为 transfer_id 格式 ✅

**完成内容**:
- 创建数据完整性验证迁移脚本 ✅
- 创建 transfer_id 格式转换迁移脚本（整数 → UUID）✅
- 验证所有数据格式正确 ✅
- 将 7 条 receivables 和 14287 条 entries 的 transfer_id 转换为 UUID 格式 ✅

**相关文件**:
- `db/migrate/20260411120002_validate_transfer_id_data_integrity.rb` ✅
- `db/migrate/20260411120003_convert_transfer_id_to_uuid_format.rb` ✅

#### 8.4 destroy vs destroy! 不一致

**问题描述**:
- 部分清理方法用 `destroy`（静默忽略失败）
- 部分用 `destroy!`（抛异常）
- 在事务中影响不大，但风格应统一

**修复方案**:
- 统一使用 `destroy!` 或统一使用 `destroy`
- 保持代码风格一致

**相关文件**:
- `app/controllers/receivables_controller.rb`

#### 8.5 transfer_id 碰撞风险

**问题描述**:
- `SecureRandom.random_number(2**31)` 生成策略有极低概率碰撞
- 建议添加唯一性检查或使用 UUID

**修复方案**:
- 使用 `SecureRandom.uuid` 替代随机数
- 或在 EntryCreationService 中添加唯一性检查

**相关文件**:
- `app/services/entry_creation_service.rb`（已优化） ✅

**完成内容**:
- [x] 使用 UUID 替代随机数生成 transfer_id
- [x] 创建数据库迁移将 transfer_id 从 integer 改为 string

**验证清单**:
- [x] update action 实现转账更新 (已修复：同步更新转账记录的描述、金额、日期和备注)
- [x] 添加外键约束或 validation (已添加 Receivable transfer_id validation)
- [x] 创建旧数据迁移脚本 (已完成：transfer_id 格式转换)
- [x] 统一 destroy/destroy! 风格 (已修复：统一使用 `each(&:destroy!)`)
- [x] 优化 transfer_id 生成策略 (已使用 UUID)

---

### 6. Tailwind CSS v4 迁移清理

**优先级**: 低
**预估工期**: 0.5 小时
**状态**: ✅ 完成
**来源**: PR #74 Code Review

**问题描述**:
- 部分文件仍使用 `focus:outline-hidden`（Tailwind v3 语法）
- Tailwind v4 中应使用 `focus:outline-none`

**受影响文件**:
- `app/views/dashboard/show.html.erb` - 4 处
- `app/views/plans/index.html.erb` - 2 处

**修复方案**:
```erb
<!-- 修改前 -->
focus:outline-hidden focus-visible:ring-2 ...

<!-- 修改后 -->
focus:outline-none focus-visible:ring-2 ...
```

**验证清单**:
- [x] 全局搜索 `outline-hidden` 并替换
- [x] 检查其他 Tailwind v3 语法残留
- [x] 测试所有页面的 focus 样式

---

### 7. JavaScript 语法统一

**优先级**: 低
**预估工期**: 2-3 小时
**状态**: ✅ 完成
**来源**: PR #78 Code Review

**问题描述**:
- JavaScript 代码中 `var` 和现代语法（`const`/`let`）混用
- 缺乏统一的代码风格
- 影响代码可维护性

**受影响文件**:
- `app/views/accounts/index.html.erb` - 模态框初始化相关代码
- `app/views/receivables/index.html.erb` - 应收款相关代码
- `app/views/payables/index.html.erb` - 应付款相关代码

**优化方案**:
1. 将所有 `var` 声明改为 `const` 或 `let`
   - 不会被重新赋值的变量使用 `const`
   - 会被重新赋值的变量使用 `let`
2. 统一代码风格，提高可读性

**验证清单**:
- [x] 全局搜索 `var ` 并评估替换
- [x] 测试所有页面的 JavaScript 功能
- [x] 检查浏览器兼容性

**备注**:
- 功能正常，非关键问题
- 可在后续重构时逐步优化

---

### 9. 项目审查优化建议（2026-04-11 审查）

**优先级**: 高
**状态**: ⏳ 待优化
**来源**: 项目审查报告 (PROJECT_REVIEW.md)

#### 9.1 提升测试覆盖率

**优先级**: 高
**预估工期**: 1-2 周
**状态**: ✅ 已完成 (82.62%)
**Issue**: [#90](https://github.com/jiang123574/ledger/issues/90)

**问题描述**:
- 初始覆盖率 7.66%，当前 82.62%（+74.96%）
- 缺乏单元测试，主要依赖集成测试
- 测试覆盖率低可能导致潜在 bug 未被发现

**已完成的测试**:
- [x] Entry 模型测试 (808 行)
- [x] Account 模型测试 (330 行)
- [x] Category 模型测试 (290 行)
- [x] Payable 模型测试 (219 行)
- [x] Receivable 模型测试 (227 行)
- [x] EntryCreationService 测试 (310 行)
- [x] AccountsController 请求测试 (442 行)
- [x] TransactionsController 请求测试 (290 行)
- [x] DashboardController 请求测试 (100 行)
- [x] ReceivablesController 请求测试 (348 行)
- [x] PayablesController 请求测试 (184 行)

**已完成的测试**（补充）:
- [x] PlansController 请求测试
- [x] CounterpartiesController 请求测试
- [x] ImportController 请求测试
- [x] 其他 Service 层测试（BackupService, ExportService, ImportService, CacheBuster 等）

**验证清单**:
- [x] 行覆盖率提升至 80%+（当前 82.62%）
- [x] 所有核心模型有单元测试
- [x] 所有控制器有功能测试
- [x] 服务层有单元测试

---

#### 9.2 重构 accounts_controller.rb

**优先级**: 高
**预估工期**: 2-3 天
**状态**: ⏳ 待优化

**问题描述**:
- `accounts_controller.rb` 有 644 行，过于庞大
- `index` action 包含复杂的数据准备逻辑
- 控制器承担了过多职责

**优化方案**:
1. 将 `index` action 的数据准备逻辑提取到 `AccountDashboardService`
2. 考虑使用 Presenter 模式简化视图逻辑
3. 将统计计算逻辑提取到独立服务

**验证清单**:
- [ ] 控制器行数减少至 300 行以内
- [ ] 数据准备逻辑提取到服务对象
- [ ] 功能保持不变
- [ ] 测试覆盖新提取的服务

---

#### 9.3 安全加固

**优先级**: 中
**预估工期**: 1-2 天
**状态**: ⏳ 待优化

**问题描述**:
- 需要检查 CSRF 保护是否完整
- 需要验证 SQL 注入防护
- 需要检查 XSS 防护
- 需要添加 Content Security Policy (CSP)

**优化方案**:
1. 运行 Brakeman 安全扫描
2. 检查所有表单的 CSRF 令牌
3. 验证所有用户输入都经过适当转义
4. 添加 CSP 头

**验证清单**:
- [ ] Brakeman 扫描无高风险漏洞
- [ ] 所有表单有 CSRF 保护
- [ ] 用户输入适当转义
- [ ] CSP 头已配置

---

#### 9.4 性能监控

**优先级**: 中
**预估工期**: 1 天
**状态**: ⏳ 待优化

**问题描述**:
- 缺乏生产环境性能监控
- 需要慢查询监控
- 需要 APM 工具

**优化方案**:
1. 添加 Skylight 或 New Relic APM
2. 配置慢查询日志
3. 设置性能警报

**验证清单**:
- [ ] APM 工具已安装配置
- [ ] 慢查询监控已启用
- [ ] 性能警报已设置

---

## 已完成任务（历史记录）

### P3 - Entry 模型迁移（✅ 完成）
- [x] Attachment / Receivable 关联迁移到 Entry 体系
- [x] Receivable/Payable 完整迁移和兼容性方法
- [x] 数据库迁移脚本和验证任务
- [x] 控制器更新和源 Entry 自动关联
- [x] 完整的集成测试覆盖（31+ 新测试用例）
- [x] 数据库迁移应用（2026-04-07 完成）

### Tailwind CSS v4 升级（✅ 完成）
- [x] 从 v3.4.1 升级到 v4.2.2
- [x] 配置迁移到 CSS @theme 指令
- [x] 添加 @tailwindcss/cli 编译工具
- [x] 开发环境 CSS watch 进程
- [x] 生产环境构建脚本更新
- [x] 表格列对齐优化

### 快捷键优化与弹窗完善（✅ 完成）
- [x] 快捷键 a/z/d/b 已实现
- [x] 应收款模态框已实现
- [x] 报销模态框已实现
- [x] 快捷键帮助列表已更新

### 交易记录拖动排序（✅ 完成）
- [x] 数据库迁移已应用（sort_order 字段）
- [x] 拖放前端实现完成
- [x] 后端 API 实现完成
- [x] 同一天交易可自由排序
- [x] 排序后余额实时更新

### P1 - entry_card_renderer.js 双模板重构（✅ 完成）
- [x] 合并 entry_card_renderer.js 的双端模板为响应式单模板
- [x] 合并 accounts/index.html.erb 的交易列表双模板
- [x] 统一数据字段命名（移除 -mobile 后缀）
- [x] DOM 节点大幅减少，改善性能
- **PR**: #64

### P2 - Receivables 和 Docker 优化（✅ 完成）
**P2.1 - Receivables 字段完整迁移**
- [x] 创建数据库迁移：20260408000000_migrate_receivables_counterparty_to_foreign_key
- [x] 将 receivables.counterparty 字符串迁移到 counterparty_id 外键
- [x] 创建缺失的 Counterparty 记录
- [x] 删除旧的 counterparty 字符串列
- [x] 统一 Receivables 和 Payables 的字段结构

**P2.2 - 清理 Docker 镜像中的 devDependencies**
- [x] 在 Dockerfile 中添加 npm prune --production
- [x] 减少镜像大小约 5-10MB
- [x] 保证 CSS 编译功能完整

**PR**: #68

### P3 - 性能优化（部分完成）

**P3b.1 - 优化 sort_by! 性能（✅ 完成）**
- [x] 将时间复杂度从 O(n²) 优化为 O(n)
- [x] 预计算 entry_id 到索引的映射
- [x] 应用到两个 sort_by! 调用位置
- [x] 对 29k+ entries 有显著性能提升
- [x] 添加 nil 边界保护

**PR**: #68

---

## 文档维护规则

1. **本文件（TODO.md）**：唯一的活跃待办清单
2. **AGENTS.md**：AI agent 运行必需配置，不可删除
3. **README.md**：项目标准说明，不可删除
4. **app/components/ds/README.md**：组件库文档，不可删除

---

## 相关链接

- **PR #63**: Tailwind CSS v4 升级
- **PR #64**: entry_card 双模板重构
- **PR #66**: esm.sh CDN 本地化
- **PR #67**: Docker CDN 验证
- **PR #68**: P2 迁移 + Docker 优化 + sort_by! 性能
- **P3 迁移**: Entry 模型完整迁移

---

**最后更新**: 2026-04-11
**维护者**: 开发团队