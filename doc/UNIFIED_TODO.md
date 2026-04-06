# 统一待办清单（唯一来源）

更新时间：2026-04-06  
维护规则：所有新的待办、修复计划、后续优化只更新本文件。其他文档仅保留历史记录。

## 当前待办（Open）

### P1
1. 信用卡账单模块前端重构（PR #50 暂缓项）
- 账单交易明细 `renderBillEntries` 从内联 HTML 拼接迁移到 Stimulus + template。
- 账单相关函数（`renderBillEntries` / `formatMoney` / `formatCurrencyRaw`）收敛到模块内部，避免全局函数。
- 账单模式与日期模式卡片渲染逻辑抽象复用，减少双实现偏差。

### P2
2. Payable 交易对方字段收敛
- 目标：`payables.counterparty`（string）逐步迁移到 `counterparty_id`（foreign key）单轨。
- 计划：回填 -> 双写兼容 -> 清理旧字段。

### 长期迁移（Transaction -> Entry）
5. Attachment / Receivable 关联迁移到 Entry 体系。
6. 编写旧 `transactions` 存量数据迁移脚本到 Entry。
7. 完成迁移后移除 Transaction 模型/表残留引用。

### 工程质量
8. 测试覆盖率继续提升（Controller + 更多 Service + 关键流程）。

## 本次对齐已补记为完成（Done）

1. 预先存在测试失败修复（`request.env` 鉴权 helper / `category_spec` / 相关测试基线）  
- 已在 `doc/REPAIR_TASKS.md` 记录完成，本次同步回写到 `.workbuddy/memory/MEMORY.md`。

2. 文档职责收敛  
- `doc/REPAIR_TASKS.md` 标记为“已归档”；  
- `.workbuddy/memory/MEMORY.md` 标注为“历史背景记忆”；  
- 本文件设为唯一活跃待办来源。

3. `accounts#index` 系统账户同步调用优化  
- 已完成：改为“仅系统账户缺失时兜底触发 `SystemAccountSyncService.sync_all!`”，避免每次进入账户页都同步。

4. 应收/应付页面选择器脚本去重  
- 已完成：`receivables/index` 与 `payables/index` 均改为复用 `app/javascript/selectors.js` 中的通用初始化函数，移除页面内重复选择器实现。

## 文档分工

1. `doc/UNIFIED_TODO.md`：唯一活跃待办（可执行项）。
2. `doc/REPAIR_TASKS.md`：历史修复批次归档（不再增量维护）。
3. `.workbuddy/memory/MEMORY.md`：长期背景与阶段总结（允许记录，但不作为执行清单）。
4. `docs/*.md`：专题报告/设计文档（默认视为历史或说明文档）。
