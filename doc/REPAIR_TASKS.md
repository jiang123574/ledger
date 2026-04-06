# 修复任务清单（已归档）

> 说明：本文件记录 2026-04-06 的一次性修复批次结果，当前不再作为活跃待办来源。  
> 当前唯一活跃待办统一维护在 `doc/UNIFIED_TODO.md`。

更新时间：2026-04-06
分支：`main`
状态：`已完成（199 examples, 0 failures）`

## 目标

基于完整 `rspec` 结果（`198 examples, 25 failures`），整理下一轮修复任务，优先恢复测试基线稳定性。

## P0（已完成）

1. 修复 request spec 的鉴权 helper
- 症状：`NoMethodError: undefined method 'env' for nil`
- 影响：`auth_spec`、`dashboard_spec`、`transactions_spec` 共 10 个失败
- 建议：改 `spec/support/auth_helper.rb`，不要写 `request.env`，改为返回 auth headers（或提供 helper 包装 get/post/patch/delete）。

2. 修复 `CacheBuster` 行为或对应测试
- 影响：`spec/models/cache_buster_spec.rb` 共 6 个失败
- 现象：`version` 未按预期递增，`bump_all` 也不生效
- 建议：检查 `CacheBuster.bump/version/bump_all` 的存储介质、scope key 拼接和测试隔离。

## P1（已完成）

3. 修复 Counterparty 与 Receivable 关联测试
- 影响：`spec/models/counterparty_spec.rb` 共 7 个失败
- 现象：`counterparty:` 传字符串触发 `AssociationTypeMismatch`
- 建议：统一为对象赋值（如 `counterparty: counterparty`）或调整模型接口；确认当前业务字段是否从 string 迁移为关联。

4. 修复 Category 关联断言
- 影响：`spec/models/category_spec.rb` 1 个失败
- 现象：断言 `Category has_many :entries` 但当前结构无 `entries.category_id`
- 建议：按当前 Entry/Entryable 模型重写该关联断言（或补充真实关联路径）。

5. 修复 FilterBadge 组件测试
- 影响：`spec/components/ds/filter_badge_component_spec.rb` 1 个失败
- 现象：SVG path 字符串断言与实际渲染格式不一致
- 建议：改用更稳健断言（元素存在/类名/aria），避免 path 文本硬编码。

## 本轮完成项

1. 转账编辑保存链路加固（金额符号）
- 转账转出强制负数、转入强制正数（abs）。

2. 账户拖拽排序
- 修复 `reorder` 的账户加载；
- 兼容 `show_hidden` 的 JSON 布尔值解析。

3. 删除交易后保留筛选状态
- 删除请求附带当前 query 参数；
- 后端 `filter_params` 扩展支持 `show_hidden/view_mode/page/per_page/type/kind`。

4. 新增账户排序 request spec
- 覆盖普通排序与隐藏账户场景。

## 实际修复结果

1. request spec 鉴权 helper 已改为默认注入 Authorization headers，修复 `request.env` 为 nil。
2. CacheBuster 新增 null_store 回退 + `clear!`，测试不再跨用例累积。
3. Counterparty/Receivable 测试迁移为关联对象赋值。
4. Category 关联改为 `entryable_transactions` + `entries through`，测试同步更新。
5. FilterBadge 组件测试改为稳定断言（不依赖 SVG path 文本）。
6. Transactions 删除用例改为断言目标记录确实被删除（避免全局计数脆弱断言）。
7. Accounts reorder 测试改为相对顺序断言，避免受其他测试数据影响。

## 后续优化（P2，非阻塞）

1. Payable 数据模型字段收敛
- 背景：`payables` 目前同时保留 `counterparty`（string）和 `counterparty_id`（foreign key）以兼容历史数据。
- 建议：后续通过迁移统一到 `counterparty_id`，并移除 string 字段。
- 计划：分阶段执行（回填 -> 双写兼容期 -> 清理旧字段）。

2. `accounts#index` 的系统账户同步调用优化
- 背景：当前每次访问账户页都会调用 `SystemAccountSyncService.sync_all!`。
- 建议：评估移除或降频调用（模型已有 `after_commit` 同步），仅保留兜底策略。
- 验收：在不影响应收/应付余额一致性的前提下减少不必要同步。

3. 应收/应付页面选择器脚本去重
- 背景：`receivables/index` 与 `payables/index` 中 account/category selector 逻辑高度重复。
- 建议：提取公共 JS 模块（可复用 `app/javascript/selectors.js` 能力）。
- 验收：行为一致、测试通过、减少重复维护成本。
