# 统一待办清单（唯一来源）

更新时间：2026-04-06 23:00  
维护规则：所有新的待办、修复计划、后续优化只更新本文件。其他文档仅保留历史记录。

## 当前待办（Open）

### P1 - ✅ 完成
1. 信用卡账单模块前端重构 ✅
   - [✅] 账单明细渲染统一到 `entry_card_renderer.js`，移除内联 template
   - [✅] 日期模式交易列表加载更多功能改用 `entry_list_controller.js` + 统一渲染器
   - [✅] `/accounts/entries` JSON API 分页加载 + 完整spec覆盖（25个测试）

### P2 - ✅ 完成
工程质量测试覆盖提升（进行中 → 完成）
- [✅] AccountStatsService 服务测试（22个测试）
- [✅] BackupService 测试（6个测试）
- [✅] ExportService 测试（17个测试）
- [✅] ImportService 测试（12个测试）
- **P2总计：57个新的测试用例**

### P3 - 长期迁移（Transaction -> Entry）
- [ ] Attachment / Receivable 关联迁移到 Entry 体系
- [ ] 编写旧 `transactions` 存量数据迁移脚本
- [ ] 完成迁移后移除 Transaction 模型/表残留引用

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

11. Payables 联系人筛选回归测试补充  
- 已完成：新增 `spec/requests/payables_spec.rb`，覆盖 `counterparty_id`（`id:` token）与 `none` 两条筛选路径，保障应付款列表筛选行为。

12. 信用卡账单金额格式化函数收敛  
- 已完成：新增 `app/javascript/bill_formatters.js` 并在账单卡片渲染与 `credit_bill_entries_controller` 复用，避免多处重复实现。

13. 系统账户兜底同步回归测试补充  
- 已完成：新增 `spec/requests/accounts_system_sync_spec.rb`，覆盖“缺失系统账户时自动补齐”与“系统账户齐全时不重复创建”两条路径。

## 文档分工

1. `doc/UNIFIED_TODO.md`：唯一活跃待办（可执行项）。
2. `doc/REPAIR_TASKS.md`：历史修复批次归档（不再增量维护）。
3. `.workbuddy/memory/MEMORY.md`：长期背景与阶段总结（允许记录，但不作为执行清单）。
4. `docs/*.md`：专题报告/设计文档（默认视为历史或说明文档）。
