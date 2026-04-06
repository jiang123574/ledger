# 修复任务清单（待下一轮处理）

更新时间：2026-04-06
分支：`fix/transfer-edit-save`

## 目标

基于完整 `rspec` 结果（`198 examples, 25 failures`），整理下一轮修复任务，优先恢复测试基线稳定性。

## P0（先修）

1. 修复 request spec 的鉴权 helper
- 症状：`NoMethodError: undefined method 'env' for nil`
- 影响：`auth_spec`、`dashboard_spec`、`transactions_spec` 共 10 个失败
- 建议：改 `spec/support/auth_helper.rb`，不要写 `request.env`，改为返回 auth headers（或提供 helper 包装 get/post/patch/delete）。

2. 修复 `CacheBuster` 行为或对应测试
- 影响：`spec/models/cache_buster_spec.rb` 共 6 个失败
- 现象：`version` 未按预期递增，`bump_all` 也不生效
- 建议：检查 `CacheBuster.bump/version/bump_all` 的存储介质、scope key 拼接和测试隔离。

## P1（随后修）

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

## 已完成（本轮）

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

## 建议执行顺序

1. 先修鉴权 helper（可一次消除 10 个 request failures）。
2. 再修 CacheBuster（6 个 failures）。
3. 然后处理 Counterparty / Category / FilterBadge。
