# Sure 项目 UI 和交互逻辑研究报告

> 项目地址: https://github.com/we-promise/sure (7.4k Stars, AGPL-3.0 License)

## 1. 项目概述

Sure 是一个功能完整的个人财务管理应用，基于 Rails 8 构建，采用 Hotwire (Turbo + Stimulus) 作为前端框架。项目代码质量高，组件化程度高，是 Ledger 项目学习和借鉴的最佳参考。

### 技术栈

| 类别 | 技术 |
|------|------|
| 后端框架 | Ruby on Rails 8 |
| 前端框架 | Hotwire (Turbo + Stimulus) |
| 组件化 | ViewComponent |
| 样式 | Tailwind CSS v4 |
| 图表 | D3.js (sankey, donut, time-series) |
| 定位 | Floating UI |
| 分页 | Pagy |
| i18n | Rails I18n |

---

## 2. 布局架构

### 2.1 整体布局 (四栏式)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [移动端顶部导航栏: Logo + 用户菜单]                                          │
├──────┬────────────────────────────────────────────┬─────────────────────────┤
│      │                                            │                         │
│ 导航  │              主内容区域                    │      右侧边栏           │
│ 84px │           max-w-5xl                       │      max-w-400         │
│      │                                            │                         │
│ Logo │         账户列表/交易列表等                 │       AI 助手           │
│ 主页 │                                            │                         │
│ 交易 │                                            │                         │
│ 报表 │                                            │                         │
│ 预算 │                                            │                         │
│ 用户 │                                            │                         │
├──────┴────────────────────────────────────────────┴─────────────────────────┤
│  [移动端底部导航栏: 主页 | 交易 | 报表 | 预算 | AI助手]                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 布局文件结构

| 文件 | 用途 |
|------|------|
| `app/views/layouts/application.html.erb` | 主布局，包含导航、侧边栏、主内容区 |
| `app/views/layouts/shared/_htmldoc.html.erb` | HTML 文档模板，包含主题初始化 |
| `app/views/layouts/shared/_head.html.erb` | 头部元数据，包含 PWA 配置 |
| `app/views/layouts/shared/_nav_item.html.erb` | 导航项组件 |
| `app/views/layouts/shared/_breadcrumbs.html.erb` | 面包屑导航 |

### 2.3 响应式断点

| 类名 | 断点 | 用途 |
|------|------|------|
| `lg:hidden` | `lg` (1024px+) | 移动端专属元素 |
| `hidden lg:block` | `lg` (1024px+) | 桌面端专属元素 |
| `md:hidden` | `md` (768px+) | 仅移动端 |

---

## 3. 设计系统

### 3.1 DS 组件库完整列表

位置: `app/components/DS/`

| 组件 | 文件 | 功能 |
|------|------|------|
| `DS::Button` | `button.rb` | 按钮，支持 variants 和 sizes |
| `DS::Link` | `link.rb` | 链接组件，用于导航 |
| `DS::Menu` | `menu.rb` | 下拉菜单，支持 icon/button/avatar variants |
| `DS::Tabs` | `tabs.rb` | 标签页，支持 URL 参数和 session 持久化 |
| `DS::Dialog` | `dialog.rb` | 对话框，支持 modal/drawer 模式 |
| `DS::Disclosure` | `disclosure.rb` | 可折叠内容，基于 `<details>` |
| `DS::Toggle` | `toggle.rb` | 开关组件，纯 CSS 实现 |
| `DS::Alert` | `alert.rb` | 警告提示，info/success/warning/error |
| `DS::Tooltip` | `tooltip.rb` | 工具提示，使用 Floating UI |
| `DS::FilledIcon` | `filled_icon.rb` | 填充图标容器 |

### 3.2 DS::Button 变体

```ruby
VARIANTS = {
  primary: "bg-gray-900 text-white hover:bg-gray-800",
  secondary: "bg-gray-100 text-primary hover:bg-gray-200",
  destructive: "bg-red-600 text-white hover:bg-red-700",
  outline: "border border-gray-300 text-primary hover:bg-gray-50",
  outline_destructive: "border border-red-300 text-red-600 hover:bg-red-50",
  ghost: "text-primary hover:bg-gray-100",
  icon: "text-secondary hover:text-primary hover:bg-gray-100",
  icon_inverse: "bg-gray-900 text-white hover:bg-gray-800"
}

SIZES = {
  sm: "h-8 px-3 text-sm gap-1.5",
  md: "h-10 px-4 text-sm gap-2",
  lg: "h-12 px-6 text-base gap-2.5"
}
```

### 3.3 UI 组件库

位置: `app/components/UI/`

| 组件 | 文件 | 功能 |
|------|------|------|
| `UI::AccountPage` | `account_page.rb` | 账户详情页面容器 |
| `UI::Account::Chart` | `chart.rb` | 账户余额趋势图 |
| `UI::Account::ActivityFeed` | `activity_feed.rb` | 账户活动列表（交易） |
| `UI::Account::ActivityDate` | `activity_date.rb` | 按日期分组的活动项 |
| `UI::Account::BalanceReconciliation` | `balance_reconciliation.rb` | 余额调节表 |

### 3.4 Tailwind 设计令牌

文件: `app/assets/tailwind/maybe-design-system.css`

**语义化颜色系统**:
```css
/* 功能性颜色 */
--color-primary     /* 主文字颜色 */
--color-secondary   /* 次要文字颜色 */
--color-destructive /* 危险/删除操作 */

/* 容器颜色 */
--color-surface      /* 页面背景 */
--color-container    /* 卡片背景 */
--color-container-inset /* 内嵌卡片背景 */

/* 边框 */
--color-border
--color-tertiary

/* 交互状态 */
--color-surface-hover
--color-surface-inset-hover

/* 状态颜色 */
--color-success (green-600)
--color-warning (yellow-600)
--color-destructive (red-600)
```

---

## 4. 交互模式

### 4.1 Hotwire Turbo 交互

**核心模式**:

1. **局部刷新**: 使用 `turbo_frame_tag` 实现页面部分更新
2. **实时广播**: 使用 `turbo_stream_from` 和 `broadcast_replace_to` 实现实时更新
3. **表单自动提交**: 使用 `auto-submit-form` 控制器

**示例 - 账户实时更新**:
```erb
<%= turbo_stream_from account %>
<%= turbo_frame_tag dom_id(account, :container) do %>
  <!-- 内容会自动通过 WebSocket 更新 -->
<% end %>
```

```ruby
def broadcast_refresh!
  Turbo::StreamsChannel.broadcast_replace_to(
    broadcast_channel,
    target: id,
    renderable: self,
    layout: false
  )
end
```

### 4.2 Stimulus 控制器详解

| 控制器 | 文件 | 功能 |
|--------|------|------|
| `auto-submit-form` | `auto_submit_form_controller.js` | 表单自动提交，支持智能防抖 |
| `bulk-select` | `bulk_select_controller.js` | 批量选择，支持分组选择 |
| `checkbox-toggle` | `checkbox_toggle_controller.js` | 移动端复选框显示切换 |
| `dashboard-sortable` | `dashboard_sortable_controller.js` | 仪表盘区块拖拽排序 |
| `dashboard-section` | `dashboard_section_controller.js` | 仪表盘区块折叠/展开 |
| `transactions-section` | `transactions_section_controller.js` | 交易区块折叠/展开 |
| `app-layout` | `app_layout_controller.js` | 布局控制，侧边栏切换 |
| `theme` | `theme_controller.js` | 主题切换 |

### 4.3 auto-submit-form 控制器

```javascript
// 智能事件选择
switch (element.type) {
  case "text", "email", "search": return "blur";  // 文本输入 500ms 防抖
  case "number", "date": return "change";         // 数值/日期立即提交
  case "checkbox", "radio": return "change";      // 选择框立即提交
  case "range": return "input";                   // 滑块实时提交
}
```

### 4.4 bulk-select 控制器

```javascript
toggleRowSelection(e)      // 切换单行选择
toggleGroupSelection(e)    // 切换整组选择
togglePageSelection(e)     // 切换整页选择
submitBulkRequest(e) {
  // 添加隐藏表单字段并提交
  _addHiddenFormInputsForSelectedIds(form, paramName, ids)
  form.requestSubmit()
}
```

### 4.5 侧边栏交互 (AppLayoutController)

```javascript
toggleLeftSidebar()   // 切换左侧账户栏 (w-full <-> w-0)
toggleRightSidebar()  // 切换右侧 AI 栏
openMobileSidebar()   // 打开移动端侧边栏
closeMobileSidebar()  // 关闭移动端侧边栏

// 用户偏好通过 PATCH 保存到后端
fetch(`/users/${userId}`, {
  method: "PATCH",
  body: new URLSearchParams({ "user[show_sidebar]": value })
});
```

### 4.6 模态框 (Dialog)

**模式**:
- **Modal**: 居中显示，支持 sm/md/lg/full 宽度
- **Drawer**: 从右侧滑出

```erb
<%= render DS::Dialog.new(variant: :modal, width: :md) do |dialog| %>
  <% dialog.with_header(title: "新建交易") %>
  <% dialog.with_body do %>
    <!-- 表单内容 -->
  <% end %>
  <% dialog.with_actions do %>
    <%= dialog.with_cancel_button %>
    <%= dialog.with_submit_button %>
  <% end %>
<% end %>
```

---

## 5. 账户管理 UI

### 5.1 账户侧边栏结构

```
┌─────────────────────────────────────┐
│  [Missing Data Provider Warning]     │  ← 可折叠警告
├─────────────────────────────────────┤
│  [ All ] [ Assets ] [ Debts ]       │  ← DS::Tabs
├─────────────────────────────────────┤
│  + New Account                      │  ← 添加按钮
│  ├─ Bank Accounts                  │  ← Disclosure 折叠组
│  │   ├─ Chase Checking   $5,000    │
│  │   └─ Savings         $10,000     │
│  └─ Investments                     │
│      ├─ Brokerage      $25,000     │
│      └─ 401k          $100,000      │
└─────────────────────────────────────┘
```

**组件文件**:
- `app/views/accounts/_account_sidebar_tabs.html.erb`
- `app/views/accounts/_accountable_group.html.erb`
- `app/views/accounts/_account.html.erb`

### 5.2 账户详情页结构

```
┌────────────────────────────────────────┐
│  Logo + 名称 + 机构名                  │
│  [Sync] [Menu]                        │
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │     Balance Chart (D3.js)        │  │  ← 余额趋势图
│  │     [1M] [3M] [6M] [1Y]         │  │  ← 时间段选择
│  └──────────────────────────────────┘  │
├────────────────────────────────────────┤
│  [ Activity ] [ Holdings/Overview ]   │  ← DS::Tabs
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │ Search: [________________]       │  │  ← 自动提交搜索
│  ├──────────────────────────────────┤  │
│  │ ☐ Date        Amount    Balance  │  │  ← 桌面端表头
│  ├──────────────────────────────────┤  │
│  │ ▼ March 20, 2026                 │  │  ← 可折叠日期
│  │   Coffee          -$5.00   $xxx │  │
│  │   Salary       +$5,000.00   $xxx │  │
│  │ ▶ March 19, 2026                 │  │
│  ├──────────────────────────────────┤  │
│  │ [< 1 2 3 ... 10 >]              │  │  ← 分页
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

### 5.3 账户卡片交互

```erb
<div class="p-4 flex items-center justify-between gap-3 group/account">
  <!-- 悬停显示编辑按钮 -->
  <%= link_to edit_account_path(account), 
      class: "group-hover/account:flex hidden" do %>
    <%= icon("pencil-line", size: "sm") %>
  <% end %>
  
  <!-- 余额 -->
  <p class="text-sm font-medium">
    <%= format_money account.balance_money %>
  </p>
  
  <!-- 启用/禁用开关 -->
  <%= render DS::Toggle.new(checked: account.active?) %>
</div>
```

---

## 6. 交易管理 UI

### 6.1 交易列表页结构

```
┌────────────────────────────────────────┐
│  Transactions                          │
│  [Menu] [Import] [+ New Transaction] │
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │  Income: $5,000  Expense: $xxx  │  │  ← Summary 统计
│  │  Net: $xxx                       │  │
│  └──────────────────────────────────┘  │
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │ Search: [________________]       │  │  ← 自动提交搜索
│  │ [Filter Menu ▼]                 │  │
│  │ [Date Badge] [Type Badge]       │  │  ← 已选过滤器徽章
│  ├──────────────────────────────────┤  │
│  │ ☐ Date        Category Account  │  │
│  ├──────────────────────────────────┤  │
│  │ ▼ Upcoming Recurring (折叠)     │  │  ← 即将到来的定期交易
│  │ ▶ March 20, 2026                 │  │
│  │   Netflix Subscription  -$15.99  │  │
│  │ ▶ March 19, 2026                 │  │
│  │   Coffee          -$5.00         │  │
│  │   Salary       +$5,000.00       │  │
│  ├──────────────────────────────────┤  │
│  │ [< 1 2 3 ... 10 >]              │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

### 6.2 过滤器系统

**文件**: `app/views/transactions/searches/`

| 过滤器 | 文件 | 功能 |
|--------|------|------|
| Category | `filters/_category_filter.html.erb` | 按类别筛选 |
| Merchant | `filters/_merchant_filter.html.erb` | 按商户筛选 |
| Account | `filters/_account_filter.html.erb` | 按账户筛选 |
| Type | `filters/_type_filter.html.erb` | 收入/支出/转账 |
| Tag | `filters/_tag_filter.html.erb` | 按标签筛选 |
| Amount | `filters/_amount_filter.html.erb` | 按金额范围筛选 |
| Date | `filters/_date_filter.html.erb` | 按日期范围筛选 |

**过滤器徽章**:
```erb
<%= render "filters/badge", param: :date, value: "2026-01-01..2026-03-20" %>
<!-- 显示: "Date: Jan 1 - Mar 20 [x]" -->
```

### 6.3 批量操作

**选择栏** (`app/views/entries/_selection_bar.html.erb`):
```erb
<div class="fixed bottom-0 left-0 right-0 bg-container border-t">
  <div class="flex justify-center items-center gap-4 p-4">
    <span>3 transactions selected</span>
    <%= link_to "Edit", new_transaction_bulk_update_path %>
    <%= button_to "Delete", bulk_delete_path, method: :delete %>
  </div>
</div>
```

### 6.4 批量更新抽屉

**文件**: `app/views/transactions/bulk_updates/new.html.erb`

```erb
<%= render DS::Dialog.new(variant: :drawer) do |dialog| %>
  <% dialog.with_header(title: "Edit Transactions") %>
  <% dialog.with_body do %>
    <%= form_with method: :post do |f| %>
      <%# 日期修改 %>
      <%# 类别修改 %>
      <%# 商户修改 %>
      <%# 标签修改 %>
      <%# 备注修改 %>
    <% end %>
  <% end %>
<% end %>
```

---

## 7. 图表系统

### 7.1 时间序列图 (Time Series)

**控制器**: `time_series_chart_controller.js`

**特性**:
- D3.js 实现
- 分段渐变（历史数据 vs 当前数据）
- 鼠标跟踪 + 十字线
- 动态 Y 轴缩放
- ResizeObserver 响应式重绘

```erb
<div data-controller="time-series-chart"
     data-time-series-chart-data-value="<%= series.to_json %>"
     data-time-series-chart-period-value="1M">
</div>
```

### 7.2 环形图 (Donut)

**控制器**: `donut_chart_controller.js`

**特性**:
- 支持扩展悬停区域
- 点击跳转到交易列表
- 缓存路径选择提升性能

```erb
<div data-controller="donut-chart"
     data-donut-chart-segments-value="<%= categories.to_json %>"
     data-donut-chart-extended-hover-value="true">
</div>
```

### 7.3 桑基图 (Sankey)

**控制器**: `sankey_chart_controller.js`

**用途**: 现金流可视化（收入来源 → 支出分类）

```erb
<div data-controller="sankey-chart"
     data-sankey-chart-data-value="<%= cashflow.to_json %>">
</div>
```

### 7.4 Sparkline (迷你图)

**文件**: `app/views/shared/_sparkline.html.erb`

```erb
<%= tag.div data: {
  controller: "time-series-chart",
  "time-series-chart-data-value": series.to_json,
  "time-series-chart-use-labels-value": false,
  "time-series-chart-use-tooltip-value": false
} %>
```

---

## 8. 主题系统

### 8.1 主题架构

```
┌─────────────────────────────────────────┐
│  User Preference (数据库)                │
│  └── theme: "light" | "dark" | "system" │
├─────────────────────────────────────────┤
│  HTML 属性                               │
│  └── data-theme="light|dark"            │
│       data-controller="theme"            │
├─────────────────────────────────────────┤
│  CSS 变量                               │
│  └── --color-primary, --bg-surface 等   │
│       theme-dark: 变体                  │
└─────────────────────────────────────────┘
```

### 8.2 主题控制器

**文件**: `theme_controller.js`

```javascript
updateTheme(event) {
  const selectedTheme = event.currentTarget.value;
  if (selectedTheme === "system") {
    this.setTheme(this.systemPrefersDark());
  } else {
    this.setTheme(selectedTheme === "dark");
  }
}

setTheme(isDark) {
  if (isDark) {
    localStorage.theme = "dark";
    document.documentElement.setAttribute("data-theme", "dark");
  } else {
    localStorage.theme = "light";
    document.documentElement.setAttribute("data-theme", "light");
  }
}
```

### 8.3 CSS 暗色模式变体

```erb
<!-- 基础样式 -->
<div class="divide-alpha-black-100">

<!-- 暗色模式变体 -->
<div class="theme-dark:divide-alpha-white-200">

<!-- 条件类名 -->
<span class="bg-red-50 theme-dark:bg-red-950/30">
```

---

## 9. 共享组件

### 9.1 shared 目录

| 文件 | 功能 |
|------|------|
| `_pagination.html.erb` | 分页组件，支持每页数量选择 |
| `_sparkline.html.erb` | 迷你趋势图 |
| `_trend_change.html.erb` | 趋势变化显示（涨跌颜色和百分比） |
| `_progress_circle.html.erb` | SVG 进度圆环 |
| `_ruler.html.erb` | 分隔线 |
| `_money_field.html.erb` | 货币输入字段 |
| `_transaction_type_tabs.html.erb` | 交易类型切换 |
| `_color_avatar.html.erb` | 彩色头像（首字母+背景色） |

### 9.2 分页组件

```erb
<div class="flex items-center gap-2">
  <%= link_to_prev_page @pagy, "← Previous" %>
  <% @pagy.series.each do |item| %>
    <% if item == :ellipsis %>
      <span>...</span>
    <% else %>
      <%= link_to item, ... %>
    <% end %>
  <% end %>
  <%= link_to_next_page @pagy, "Next →" %>
</div>
```

---

## 10. 仪表盘 UI

### 10.1 仪表盘结构

**文件**: `app/views/pages/dashboard.html.erb`

```
┌────────────────────────────────────────┐
│  Welcome, John                         │
│  [New Account]                         │
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │ ▼ Net Worth                      │  │  ← 可折叠
│  │   [拖拽手柄]                     │  │  ← 可拖拽排序
│  │   [Net Worth Chart]              │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │ ▼ Balance Sheet                  │  │
│  │   Assets: $150,000              │  │
│  │   Liabilities: $50,000          │  │
│  │   ▶ Bank Accounts    $50,000    │  │  ← 可展开
│  │   ▶ Investments     $100,000   │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │ ▼ Spending                      │  │
│  │   [Donut Chart]                 │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

### 10.2 余额表组件

**文件**: `app/views/pages/dashboard/_balance_sheet.html.erb`

```erb
<details class="group open:bg-container rounded-lg">
  <summary class="cursor-pointer p-4 flex items-center justify-between">
    <div>
      <span class="text-sm font-medium">Bank Accounts</span>
    </div>
    <div class="flex items-center gap-4">
      <span class="text-sm font-medium">$50,000</span>
      <%= icon("chevron-right", class: "group-open:rotate-90") %>
    </div>
  </summary>
  <div>
    <% account_group.accounts.each do |account| %>
      <%= link_to account.name, account_path(account) %>
    <% end %>
  </div>
</details>
```

---

## 11. 核心代码模式

### 11.1 ViewComponent Slots

```ruby
class UI::AccountPage < ApplicationComponent
  renders_one :activity_feed, ->(feed_data:, pagy:, search:) {
    UI::Account::ActivityFeed.new(...)
  }
end
```

```erb
<%= render UI::AccountPage.new(...) do |account_page| %>
  <%= account_page.with_activity_feed(feed_data: ..., pagy: ..., search: ...) %>
<% end %>
```

### 11.2 Stimulus 值绑定

```erb
<div data-controller="example"
     data-example-ids-value="<%= @ids.to_json %>"
     data-example-user-id-value="<%= current_user.id %>">
</div>
```

```javascript
export default class extends Controller {
  static values = { ids: Array, userId: Number };
  
  idSelected(e) {
    const id = e.target.dataset.id;
    this.idsValue.includes(id) ? 'remove' : 'add';
  }
}
```

### 11.3 Turbo 局部刷新

```erb
<%= turbo_frame_tag "transactions", src: transactions_path(format: :turbo) do %>
  <div class="animate-pulse">Loading...</div>
<% end %>
```

### 11.4 Entries 按日期分组

```ruby
# app/helpers/entries_helper.rb
def entries_by_date(entries, totals: false)
  # 去除重复的转账显示（只显示 outflow）
  deduped_entries = transfer_groups.flat_map do |transfer_id, grouped|
    if transfer_id.nil? || grouped.size == 1
      grouped
    else
      grouped.reject { |e| e.entryable.transfer_as_inflow.present? }
    end
  end
  
  # 按日期分组并渲染
  deduped_entries.group_by(&:date).each do |date, items|
    # 输出日期标题 + 项目列表
  end
end
```

---

## 12. 关键交互流程

### 12.1 批量选择流程

```
用户点击复选框 
    ↓
bulk-select#toggleRowSelection
    ↓
更新 selectedIdsValue (Stimulus Value)
    ↓
selectedIdsValueChanged 触发 _updateView
    ↓
更新选择栏显示 + 复选框状态
    ↓
点击编辑按钮 → 打开 DS::Dialog drawer
    ↓
填写表单 → bulk-select#submitBulkRequest
    ↓
Transactions::BulkUpdatesController#create
```

### 12.2 自动提交搜索流程

```
用户输入 
    ↓
触发 auto-submit-form 事件 (blur/change/input)
    ↓
handleInput (防抖 500ms for 文本)
    ↓
element.requestSubmit()
    ↓
TransactionsController#index
    ↓
更新 @search 和 @pagy → 重新渲染页面
```

### 12.3 Turbo 实时更新

```
Account 更新 
    ↓
AccountChannel 广播
    ↓
turbo_stream_from account
    ↓
页面自动刷新相关部分
```

---

## 13. Ledger 项目适配建议

### 13.1 优先级高

1. **DS 组件库**: 创建统一的 Button/Link/Menu/Tabs/Dialog/Toggle 组件
2. **语义化颜色**: 定义 `text-primary`、`bg-container` 等设计令牌
3. **auto-submit-form**: 搜索框自动提交
4. **交易页改版**: 三栏布局（账户列表 + 详情 + 交易列表）

### 13.2 优先级中

1. **批量操作**: Selection Bar + BulkSelect
2. **Disclosure 组件**: 账户组折叠
3. **Sparkline**: 账户余额迷你图
4. **过滤器系统**: 可视化的过滤器徽章

### 13.3 优先级低

1. **图表系统**: D3.js 图表
2. **主题系统**: 暗色模式
3. **拖拽排序**: 仪表盘区块
4. **Turbo 广播**: 实时更新

### 13.4 具体实现建议

**1. 创建 DS 组件库**

```ruby
# app/components/ds/button.rb
class Ds::ButtonComponent < ApplicationComponent
  VARIANTS = {
    primary: "bg-blue-600 text-white hover:bg-blue-700",
    secondary: "bg-gray-100 text-primary hover:bg-gray-200"
  }
  
  def initialize(variant: :primary, href: nil, **)
    @variant = variant
    @href = href
  end
end
```

**2. 添加 auto-submit-form**

```javascript
// app/javascript/controllers/auto_submit_form_controller.js
export default class extends Controller {
  static targets = ["auto"];
  
  connect() {
    this.element.addEventListener(this.eventType, this.handleSubmit.bind(this));
  }
  
  get eventType() {
    return this.autotarget.dataset.autoSubmitFormTarget === "auto" ? "blur" : "change";
  }
}
```

**3. 交易页三栏布局**

```erb
<div class="grid grid-cols-12 gap-4">
  <!-- 左栏: 账户列表 -->
  <div class="col-span-12 md:col-span-3">
    <%= render "accounts/sidebar", accounts: @accounts %>
  </div>
  
  <!-- 中栏: 账户详情 -->
  <div class="col-span-12 md:col-span-3">
    <%= render "accounts/detail", account: @selected_account %>
  </div>
  
  <!-- 右栏: 交易列表 -->
  <div class="col-span-12 md:col-span-6">
    <%= render "transactions/list", transactions: @transactions %>
  </div>
</div>
```

---

---

## 14. DS 组件库详细 API

### 14.1 Button 组件

```ruby
DS::Button.new(
  variant: :primary,        # 按钮样式
  size: :md,               # 按钮大小
  href: nil,               # 链接地址
  text: "Click",           # 按钮文本
  icon: "plus",            # 图标名称
  icon_position: :left,    # 图标位置
  full_width: false,       # 是否全宽
  frame: nil,              # Turbo Frame ID
  confirm: nil              # 确认对话框文本
)
```

### 14.2 Dialog 组件

```ruby
DS::Dialog.new(
  variant: "modal",           # "modal" | "drawer"
  auto_open: true,            # 是否自动打开
  reload_on_close: false,     # 关闭后是否刷新
  width: "md",               # "sm" | "md" | "lg" | "full"
  frame: nil
)
```

### 14.3 Menu 组件

```ruby
DS::Menu.new(
  variant: "icon",           # "icon" | "button" | "avatar"
  placement: "bottom-end",   # 弹出位置
  offset: 12                # 偏移量
)
```

### 14.4 Tabs 组件

```ruby
DS::Tabs.new(
  active_tab: "tab1",       # 当前激活的标签
  url_param_key: "tab",     # URL 参数持久化
  session_key: nil,          # Session 持久化
  variant: :default         # :default | :unstyled
)
```

---

## 15. 搜索过滤系统详细流程

### 15.1 搜索参数结构

```ruby
# 支持的搜索参数
{
  search: "coffee",                    # 文本搜索
  start_date: "2024-01-01",          # 开始日期
  end_date: "2024-12-31",            # 结束日期
  amount: "100",                      # 金额
  amount_operator: "greater",          # 操作符
  accounts: ["Checking", "Savings"],  # 账户列表
  categories: ["Food", "Transport"],   # 分类列表
  merchants: ["Starbucks"],           # 商户列表
  types: ["income", "expense"],       # 类型列表
  tags: ["work"]                      # 标签列表
}
```

### 15.2 过滤器 UI 结构

```
┌──────────────────────────────────────────────────────────────┐
│  Filter Menu                                                 │
├────────────────┬─────────────────────────────────────────────┤
│   Account      │                                             │
│   Date         │   ┌─────────────────────────────────────┐ │
│   Type         │   │  Account Filter Content             │ │
│   Amount  ◀──  │   │                                     │ │
│   Category     │   │  [Search input]                     │ │
│   Tag          │   │  ☑ Checking Account                │ │
│   Merchant     │   │  ☑ Savings Account                 │ │
│                │   │  ☐ Credit Card                    │ │
│                │   └─────────────────────────────────────┘ │
└────────────────┴─────────────────────────────────────────────┘
```

---

## 16. 图表实现详细技术

### 16.1 D3.js 使用模式

```javascript
import * as d3 from "d3";
import { sankey, sankeyLinkHorizontal } from "d3-sankey";

// 比例尺
const xScale = d3.scaleTime().rangeRound([0, width]);
const yScale = d3.scaleLinear().rangeRound([height, 0]);

// 弧形生成器
const pie = d3.pie().sortValues(null).value(d => d.amount);
const arc = d3.arc().innerRadius(r).outerRadius(r + 10);

// 线条生成器
const line = d3.line().x(d => xScale(d.date)).y(d => yScale(d.value));
```

### 16.2 响应式处理

```javascript
connect() {
  this.resizeObserver = new ResizeObserver(() => this.#draw());
  this.resizeObserver.observe(this.element);
}

disconnect() {
  this.resizeObserver?.disconnect();
}
```

### 16.3 交互效果

```javascript
// 悬浮高亮
.on("mouseenter", function(event, d) {
  d3.select(this).style("opacity", 1);
  showTooltip(d);
}).on("mouseleave", function() {
  d3.select(this).style("opacity", 0.6);
  hideTooltip();
});
```

---

## 17. 模型设计模式

### 17.1 Delegated Type 模式

```ruby
# 账户类型多态
class Account < ApplicationRecord
  delegated_type :accountable, types: Accountable::TYPES, dependent: :destroy
end

# 账目类型多态
class Entry < ApplicationRecord
  delegated_type :entryable, types: Entryable::TYPES, dependent: :destroy
end
```

### 17.2 Concern 组合模式

```ruby
class Account < ApplicationRecord
  include AASM, Syncable, Monetizable, Chartable, Linkable, Enrichable
end
```

### 17.3 Query Object 模式

```ruby
class EntrySearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :search, :string
  attribute :amount, :string

  def build_query(scope)
    query = scope.joins(:account)
    query = apply_search_filter(query, search)
    query = apply_date_filters(query, start_date, end_date)
    query
  end
end
```

---

## 18. 关键文件清单

### 18.1 控制器

| 文件 | 功能 |
|------|------|
| `app/controllers/transactions_controller.rb` | 交易列表主控制器 |
| `app/controllers/transactions/bulk_updates_controller.rb` | 批量更新控制器 |
| `app/controllers/transactions/bulk_deletions_controller.rb` | 批量删除控制器 |

### 18.2 模型

| 文件 | 功能 |
|------|------|
| `app/models/account.rb` | 账户模型 |
| `app/models/entry.rb` | 账目模型 |
| `app/models/transaction.rb` | 交易模型 |
| `app/models/entry_search.rb` | 搜索查询对象 |
| `app/models/balance_sheet.rb` | 资产负债表 |

### 18.3 JavaScript 控制器

| 文件 | 功能 |
|------|------|
| `app/javascript/controllers/auto_submit_form_controller.js` | 自动提交表单 |
| `app/javascript/controllers/bulk_select_controller.js` | 批量选择 |
| `app/javascript/controllers/dashboard_sortable_controller.js` | 拖拽排序 |
| `app/javascript/controllers/theme_controller.js` | 主题切换 |
| `app/javascript/controllers/sankey_chart_controller.js` | 桑基图 |
| `app/javascript/controllers/donut_chart_controller.js` | 环形图 |
| `app/javascript/controllers/time_series_chart_controller.js` | 时间序列图 |

### 18.4 DS 组件

| 文件 | 功能 |
|------|------|
| `app/components/DS/button.rb` | 按钮组件 |
| `app/components/DS/dialog.rb` | 对话框组件 |
| `app/components/DS/menu.rb` | 菜单组件 |
| `app/components/DS/tabs.rb` | 标签页组件 |
| `app/components/DS/toggle.rb` | 开关组件 |
| `app/components/DS/disclosure.rb` | 折叠组件 |
| `app/components/DS/tooltip.rb` | 提示组件 |

### 18.5 视图

| 文件 | 功能 |
|------|------|
| `app/views/transactions/index.html.erb` | 交易列表页 |
| `app/views/transactions/searches/_form.html.erb` | 搜索表单 |
| `app/views/transactions/searches/_menu.html.erb` | 过滤器菜单 |
| `app/views/transactions/bulk_updates/new.html.erb` | 批量更新表单 |
| `app/views/accounts/_account_sidebar_tabs.html.erb` | 账户侧边栏 |
| `app/views/pages/dashboard.html.erb` | 仪表盘 |

---

## 19. 参考资源

| 资源 | 链接 |
|------|------|
| GitHub | https://github.com/we-promise/sure |
| Demo | https://demo.sure.am |
| Discord | https://discord.gg/36ZGBsxYEK |
| Hotwire | https://hotwired.dev/ |
| Stimulus | https://stimulus.hotwired.dev/ |
| ViewComponent | https://viewcomponent.org/ |
| Tailwind CSS | https://tailwindcss.com/ |
| D3.js | https://d3js.org/ |
