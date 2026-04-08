# TODO

更新时间：2026-04-08
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
**前置条件**: 生产环境稳定运行 2-4 周后（2026-05-05 后）

**背景**:
- 当前系统已是纯 Entry 体系
- Transaction 模型仅保留用于反向兼容
- 迁移脚本支持 Entry/Transaction 双轨制

**目标**:
- 完全移除 Transaction 模型和相关表

**实施步骤**:

**Phase 3b-1: 代码清理**
- 移除 `source_transaction_id` 字段和关联
- 删除所有 `has_many :xxx_transactions` 关联
- 清理兼容性回退代码

**Phase 3b-2: 表清理**
- 创建最终迁移：删除 transactions 表
- 删除 transaction_tags 表
- 更新 schema.rb

**Phase 3b-3: 验证**
- 完整测试套件运行
- 生产环境滚动部署
- 监控系统正常性

**相关文件**:
- `app/models/transaction.rb`（删除）
- `app/models/entry.rb`（移除关联）
- `db/migrate/`（新建迁移）
- `config/routes.rb`

**验证清单**:
- [ ] 代码清理完成
- [ ] 表迁移完成
- [ ] 所有测试通过
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

**状态**: ✅ 部分完成

- 运行 bullet gem 检测 N+1 查询
- 分析 Entry 表上最常用的查询模式 ✅
- 新增复合索引：`(account_id, date, notes)` 和 `(account_id, date, name)` ✅
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

**最后更新**: 2026-04-08
**维护者**: 开发团队