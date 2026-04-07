# P3 Optional 优化计划

## 概述

P3 Phase 1-2 已完成，系统完全支持 Entry 模型和向后兼容的 Receivable/Payable。本文档规划可选的后续优化项目。

## 优化项目

### 优化项 1：Receivables 字段清理（Priority: Medium）

**背景**
- Payables 已完成迁移：counterparty（字符串）→ counterparty_id（外键）
- Receivables 仍保留 counterparty 字符串字段以保持兼容
- 字段冗余导致维护成本增加

**目标**
- 将所有 receivables.counterparty（字符串）迁移到 counterparty_id（外键）
- 确保数据完整性和一致性

**实施步骤**

1. **新增迁移脚本** (Phase 3a)
   ```bash
   # 创建迁移: db/migrate/20260407XXXXXX_complete_receivables_counterparty_migration.rb
   # 类似 Payables 的迁移脚本
   ```
   - 创建缺失的 counterparty 记录
   - 更新 receivables.counterparty_id
   - 删除 receivables.counterparty 字符串字段

2. **更新模型关联**
   - 确保 Receivable 只有 counterparty_id（外键）
   - 移除相关的 string 字段兼容代码

3. **验证测试**
   - 新增集成测试覆盖字符串→外键迁移
   - 验证 Counterparty 关联的完整性

**时间估计**：2-3 小时
**复杂度**：Low（复用 Payables 的迁移模式）
**风险等级**：Low

---

### 优化项 2：Transaction 模型逐步废弃（Priority: Low）

**背景**
- 当前系统已是纯 Entry 体系
- Transaction 模型仅保留用于反向兼容
- 迁移脚本支持完的 Entry/Transaction 双轨制

**目标**
- 在生产环保正常运行 2-4 周后（2026-04-21 到 2026-05-05）
- 完全移除 Transaction 模型和相关表

**实施步骤**

1. **第一阶段：代码清理** (Phase 3b-1)
   - 移除 `source_transaction_id` 字段和关联
   - 删除所有 has_many :xxx_transactions 关联
   - 清理兼容性回退代码

2. **第二阶段：表清理** (Phase 3b-2)
   - 创建最终迁移：删除 transactions 表
   - 删除 transaction_tags 表
   - 更新 schema.rb

3. **第三阶段：验证** (Phase 3b-3)
   - 完整测试套件运行
   - 生产环境滚动部署
   - 监控系统正常性

**时间估计**：4-6 小时（分三个 PR）
**复杂度**：Medium
**风险等级**：Medium（需要滚动部署）

---

### 优化项 3：性能优化（Priority: Low）

**背景**
- 当前系统有 29,678 个 Entry
- Receivable/Payable 访问需要通过 notes 字段关联 Entry
- 可能存在 N+1 查询问题

**目标**
- 优化 Entry 表查询性能
- 改进 Receivable/Payable 的源交易关联查询

**实施步骤**

1. **查询性能分析** (Phase 3c-1)
   - 运行 bullet gem 检测 N+1 查询
   - 分析 Entry 表上最常用的查询模式
   - 评估是否需要 materialized view

2. **索引优化** (Phase 3c-2)
   - 新增复合索引：`(notes, account_id, date)`
   - 评估是否需要 BRIN 索引（时间序列）

3. **缓存优化** (Phase 3c-3)
   - 考虑在 Receivable/Payable 上缓存 source_entry 关联
   - 或使用 Rails QueryCache 中间件

**时间估计**：6-8 小时
**复杂度**：Medium-High
**风险等级**：Medium

---

## 建议优化顺序

### 立即可做（1-2 周内）
1. ✅ PR59 合并到 main
2. ✅ 数据库迁移应用
3. ✅ 所有测试验证

### Phase 3a（2-3 周内）
- [ ] Receivables 字段完整迁移

### Phase 3b（4-6 周后）
- [ ] Transaction 模型完全移除（分三个 PR）

### Phase 3c（持续优化）
- [ ] 性能优化和监控

---

## 检查清单

### 前置条件
- [x] P3 Phase 1-2 已完成并合并到 main
- [x] 数据库迁移已应用
- [x] 所有新测试已通过
- [x] 迁移验证任务成功运行

### 执行前

#### Phase 3a（Receivables 迁移）
- [ ] 备份生产数据库
- [ ] 撰写迁移脚本
- [ ] 编写迁移测试
- [ ] 本地验证通过
- [ ] 创建 PR 进行 review

#### Phase 3b（Transaction 移除）
- [ ] 完成 Phase 3a
- [ ] 生产环境运行稳定 2-4 周
- [ ] 确认没有 Transaction 查询
- [ ] 撰写分阶段的迁移脚本

#### Phase 3c（性能优化）
- [ ] 收集性能指标
- [ ] 使用 bullet 分析 N+1
- [ ] 设计优化方案
- [ ] 性能测试验证

---

## 监控指标

### P3 完成后应该监控的指标
- 数据库查询时间
- Entry 表大小和增长率
- Receivable/Payable 平均查询时间
- 缓存命中率（如实施缓存）

### 告警阈值
- 单个查询超过 100ms
- N+1 查询检测
- 表大小增长超过预期

---

## 相关 PR 和提交

- P3-1：基础设施 (commit a1038c9 到 ed56acb)
- P3-2：完整迁移和兼容  (commit 091dc24 + 7021455 + more)
- P3-Optional：本优化计划

---

## 参考文档

- [P3_PHASE_2_IMPLEMENTATION.md](./P3_PHASE_2_IMPLEMENTATION.md)
- [P3_MIGRATION_PLAN.md](./P3_MIGRATION_PLAN.md)
- [UNIFIED_TODO.md](./UNIFIED_TODO.md)
