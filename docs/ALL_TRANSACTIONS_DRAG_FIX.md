# 所有交易页面拖动排序问题修复

## 问题描述

**URL**: http://localhost:3000/accounts?period_type=month&period_value=2026-04

**症状**: "所有交易"页面无法拖动排序

## 根本原因

1. **路由设计**: `reorder_entries` 是 `member` 路由，需要 `account_id`
   ```ruby
   # config/routes.rb:36
   resources :accounts do
     member do
       patch :reorder_entries  # 需要account_id
     end
   end
   ```

2. **JavaScript限制**: `entry_list_controller.js:243` 会在没有 `accountId` 时直接返回
   ```javascript
   submitSortOrder(date) {
     if (!this.accountIdValue) return  // ❌ 阻止提交
     // ...
   }
   ```

3. **设计问题**: "所有交易"页面显示的是多个账户的混合记录
   - `sort_order` 是按账户分别管理的
   - 无法跨账户排序
   - 同一天可能有多条不同账户的记录

## 解决方案

**禁用"所有交易"页面的拖动功能**，只在单个账户页面启用。

### 修改内容

#### 1. 添加 `dragEnabled` 参数 (view)

`app/views/accounts/index.html.erb:305`

```erb
data-entry-list-drag-enabled-value="<%= params[:account_id].present? %>"
```

#### 2. 添加 `dragEnabled` value (JavaScript)

`app/javascript/controllers/entry_list_controller.js:6-17`

```javascript
static values = {
  // ... 其他values
  dragEnabled: { type: Boolean, default: true }
}
```

#### 3. 修改 `setupDragAndDrop` 方法

`app/javascript/controllers/entry_list_controller.js:150-160`

```javascript
setupDragAndDrop() {
  // 只有在拖动启用且有accountId时才设置拖拽
  if (!this.dragEnabledValue || !this.accountIdValue) {
    return
  }

  // ... 原有的拖拽设置代码
}
```

## 验证结果

### 所有交易页面（无account_id）
```
URL: /accounts?period_type=month&period_value=2026-04
drag-enabled-value: "false" ✓
拖动功能：禁用 ✓
```

### 单个账户页面（有account_id）
```
URL: /accounts?period_type=month&period_value=2026-04&account_id=824
drag-enabled-value: "true" ✓
拖动功能：启用 ✓
```

## 为什么这样设计？

### 所有交易页面
- 显示多个账户的混合记录
- 无法跨账户排序（sort_order按账户管理）
- 禁用拖动避免混淆

### 单个账户页面
- 只显示一个账户的记录
- sort_order属于该账户
- 可以自由拖动排序

## 用户体验

✓ 所有交易页面：无法拖动，避免误导
✓ 单个账户页面：可以拖动，保存顺序
✓ 刷新后顺序保持一致

## 测试步骤

1. 访问所有交易页面，尝试拖动 → 无反应 ✓
2. 点击账户进入单个账户页面 → 可以拖动 ✓
3. 拖动后刷新 → 顺序保持 ✓