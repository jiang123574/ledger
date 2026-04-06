# 统一待办清单（唯一来源）

更新时间：2026-04-06  
维护规则：所有新的待办、修复计划、后续优化只更新本文件。其他文档仅保留历史记录。

## 当前待办（Open）

### P1
1. 信用卡账单模块前端重构
- 账单相关函数（`renderBillEntries` / `formatMoney` / `formatCurrencyRaw`）收敛到模块内部，避免全局函数。
- 账单模式与日期模式卡片渲染逻辑抽象复用，减少双实现偏差。

### P2
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

5. Payable 交易对方字段收敛  
- 已完成：新增迁移将 `payables.counterparty` 历史数据回填到 `counterparty_id`（缺失联系人自动补建），并删除 `payables.counterparty` 字段，控制器筛选/统计改为仅基于外键。

6. 信用卡账单明细渲染改造  
- 已完成：账单交易明细 `renderBillEntries` 从页面内联 HTML 拼接迁移到 Stimulus 控制器 + `<template>` 渲染，筛选与加载流程改为调用控制器渲染接口。

7. 账单明细状态渲染 XSS 防护  
- 已完成：`credit_bill_entries_controller.js` 的 `showError/showEmpty` 改为 `textContent` 渲染，移除字符串插值 `innerHTML` 风险。

8. Payables 联系人筛选分支清理  
- 已完成：移除 `PayablesController#filter_by_counterparty` 中不再使用的 `name:` 前缀兼容分支，保留 `id:` 与 `none` 两种有效路径。

9. 信用卡账单控制器桥接稳定性  
- 已完成：`accounts/index` 改为通过自定义事件与 `credit_bill_entries_controller` 通信（`credit-bill-entries:*`），不再依赖 `window.Stimulus.getControllerForElementAndIdentifier`。

10. 选择器模块进一步统一  
- 已完成：`initGenericSelector` 收敛为基于 `initSelectorWithData` 的包装层，减少重复逻辑；`receivables/payables` 页面选择器数据变量命名已统一。

## 文档分工

1. `doc/UNIFIED_TODO.md`：唯一活跃待办（可执行项）。
2. `doc/REPAIR_TASKS.md`：历史修复批次归档（不再增量维护）。
3. `.workbuddy/memory/MEMORY.md`：长期背景与阶段总结（允许记录，但不作为执行清单）。
4. `docs/*.md`：专题报告/设计文档（默认视为历史或说明文档）。
