# 拖动排序Bug修复说明

## 问题描述

**症状**: 当天的交易记录拖动后，刷新页面会颠倒过来

**测试URL**: http://localhost:3000/accounts?period_type=month&period_value=2026-04&account_id=824

**影响范围**: 4月4日的交易记录（共7条）

## 根本原因

在 `app/controllers/accounts_controller.rb:478-480` 的 `reorder_entries` 方法中：

```ruby
# ❌ 错误的逻辑
entry_ids.each_with_index do |entry_id, index|
  Entry.where(id: entry_id, account_id: @account.id, date: date)
       .update_all(sort_order: index + 1)  # 第一个是1，第二个是2...
end
```

这导致：
- 拖动后的第一个条目（页面最上方）被设置 `sort_order: 1`
- 拖动后的最后一个条目（页面最下方）被设置最大的 `sort_order`

但是 `reverse_chronological` scope 是 `sort_order: :desc`：
- `sort_order` 大的排在上面
- `sort_order` 小的排在下面

**结果**: 刷新后顺序完全颠倒！

## 修复方案

```ruby
# ✅ 正确的逻辑
total_entries = entry_ids.size
entry_ids.each_with_index do |entry_id, index|
  Entry.where(id: entry_id, account_id: @account.id, date: date)
       .update_all(sort_order: total_entries - index)
end
```

现在的设置：
- 拖动后的第一个条目（页面最上方）→ `sort_order: 7` (最大)
- 拖动后的第二个条目 → `sort_order: 6`
- ...
- 拖动后的最后一个条目（页面最下方）→ `sort_order: 1` (最小)

刷新后 `reverse_chronological` 显示顺序保持一致！

## 验证测试

### 测试场景
模拟用户拖动4月4日的7条记录为以下顺序：
1. id:29736 (转账)
2. id:29729 (支出)
3. id:29727 (转账)
4. id:29731 (支出)
5. id:29730 (支出)
6. id:29748 (转账)
7. id:29741 (转账)

### 数据库结果
```
sort_order:7 | id:29736 ✓
sort_order:6 | id:29729 ✓
sort_order:5 | id:29727 ✓
sort_order:4 | id:29731 ✓
sort_order:3 | id:29730 ✓
sort_order:2 | id:29748 ✓
sort_order:1 | id:29741 ✓
```

### API返回顺序
```json
{"id": 29736, "date": "2026-04-04"} ✓
{"id": 29729, "date": "2026-04-04"} ✓
{"id": 29727, "date": "2026-04-04"} ✓
{"id": 29731, "date": "2026-04-04"} ✓
{"id": 29730, "date": "2026-04-04"} ✓
{"id": 29748, "date": "2026-04-04"} ✓
{"id": 29741, "date": "2026-04-04"} ✓
```

### 页面显示顺序
与拖动顺序一致 ✓

## 使用说明

1. **在浏览器中强制刷新页面**（Ctrl+Shift+R 或 Cmd+Shift+R）
2. 测试拖动功能，刷新后顺序应保持不变

## 修改的文件

- `app/controllers/accounts_controller.rb` (line 477-483)

## 相关问题

- ✅ 修复了node_modules被Git追踪的问题（添加到.gitignore）
- ✅ 修复了交易记录排序问题（Entry.reverse_chronological）
- ✅ 修复了缓存entry_ids顺序问题（添加sort_by!）

所有问题已解决！