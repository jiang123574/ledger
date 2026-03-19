# Sure 项目 UI 和交互逻辑研究报告

## 1. 项目概述

Sure 是一个基于 Rails 8 的个人财务管理应用，采用 Hotwire (Turbo + Stimulus) 作为前端框架。项目结构清晰，组件化程度高。

### 技术栈
- **后端**: Ruby on Rails 8
- **前端**: Hotwire (Turbo + Stimulus), Tailwind CSS v4
- **图标**: Lucide Icons (通过 `icon` helper)
- **组件化**: ViewComponent

---

## 2. 布局架构

### 2.1 整体布局 (三栏式)

```
┌─────────────────────────────────────────────────────────────────┐
│  [移动端顶部导航栏]                                                │
├──────┬────────────────────────────────────────────┬────────────┤
│      │                                            │            │
│ 侧边栏 │              主内容区域                    │  右侧边栏  │
│ 84px │           max-w-5xl                        │  max-w-400 │
│      │                                            │            │
│ 导航   │         账户列表/交易列表等               │   AI助手   │
│ Logo  │                                            │            │
│ 用户   │                                            │            │
├──────┴────────────────────────────────────────────┴────────────┤
│  [移动端底部导航栏]                                                │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 布局代码结构

**主布局文件**: `app/views/layouts/application.html.erb`

- **左侧导航** (84px): Logo + 主导航项 (首页、交易、报表、预算)
- **左侧边栏** (max-w-320px): 可折叠的账户列表，支持按资产/负债分组
- **主内容区** (max-w-5xl): 居中显示，带面包屑导航
- **右侧边栏** (max-w-400px): AI 助手对话区域

### 2.3 响应式策略

| 断点 | 布局变化 |
|------|----------|
| lg (1024px) | 显示完整三栏布局 |
| < lg | 隐藏侧边栏，显示移动端顶部+底部导航 |

---

## 3. 设计系统

### 3.1 DS 组件库

位置: `app/components/DS/`

| 组件 | 用途 |
|------|------|
| Button | 按钮，支持 variants (primary, secondary, outline, ghost, icon) |
| Link | 链接按钮，与 Button 类似但用于导航 |
| Menu | 下拉菜单，支持 icon/button/avatar variants |
| Tabs | 标签页切换，支持 session 持久化 |
| Dialog | 模态对话框 |
| Disclosure | 可折叠内容 (details/summary) |
| Toggle | 开关组件 |
| Alert | 警告/提示框 |
| Tooltip | 工具提示 |

### 3.2 UI 组件库

位置: `app/components/UI/`

| 组件 | 用途 |
|------|------|
| AccountPage | 账户详情页面容器 |
| Account::Chart | 账户余额图表 |
| Account::ActivityFeed | 账户活动列表 |
| Account::ActivityDate | 按日期分组的活动项 |

### 3.3 Tailwind 设计令牌

文件: `app/assets/tailwind/maybe-design-system.css`

**语义化颜色系统**:
```css
/* 功能性颜色 - 替代直接使用 white/black */
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
```

---

## 4. 交互模式

### 4.1 Hotwire Turbo 交互

**核心模式**:
1. **局部刷新**: 使用 `turbo_frame_tag` 实现页面部分更新
2. **实时广播**: 使用 `turbo_stream_from` 和 `broadcast_replace_to` 实现实时更新
3. **表单自动提交**: 使用 `auto-submit-form` 控制器，搜索/过滤表单自动提交

**示例 - 账户实时更新**:
```erb
<%= turbo_stream_from account %>
<%= turbo_frame_tag id do %>
  <!-- 内容 -->
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

### 4.2 Stimulus 控制器

**常用控制器**:

| 控制器 | 功能 |
|--------|------|
| auto-submit-form | 表单自动提交 |
| bulk-select | 批量选择操作 |
| checkbox-toggle | 复选框显示/隐藏 |
| dashboard-sortable | 仪表盘区块拖拽排序 |
| dashboard-section | 仪表盘区块折叠/展开 |
| transactions-section | 交易区块折叠/展开 |
| DS--tabs | 标签页切换 |
| DS--menu | 下拉菜单 |

### 4.3 侧边栏交互

**AppLayoutController**:
```javascript
toggleLeftSidebar()   // 切换左侧账户栏
toggleRightSidebar()  // 切换右侧 AI 栏
openMobileSidebar()   // 打开移动端侧边栏
```

用户偏好通过 PATCH 请求保存到后端:
```javascript
fetch(`/users/${userId}`, {
  method: "PATCH",
  body: new URLSearchParams({ "user[show_sidebar]": value })
});
```

### 4.4 模态框

使用 `<dialog>` HTML 原生元素，配合 Turbo Frame:
```erb
<%= render DS::Link.new(
  href: new_transaction_path,
  frame: :modal  # 生成 data: { turbo_frame: :modal }
) %>

<!-- 模态框内容 -->
<%= turbo_frame_tag :modal do %>
  <!-- 模态框内容 -->
<% end %>
```

---

## 5. 账户管理 UI

### 5.1 账户侧边栏

**结构**:
- Tabs: 全部 / 资产 / 负债
- 每个 Tab 内按账户类型分组 (Depository, CreditCard, Investment 等)
- 使用 Disclosure 组件折叠/展开账户组

**组件**: `app/views/accounts/_account_sidebar_tabs.html.erb`

### 5.2 账户详情页

**结构**:
```
┌────────────────────────────────────┐
│  Header (Logo + 名称 + 菜单按钮)     │
├────────────────────────────────────┤
│  Chart (余额趋势图 + 周期选择)        │
├────────────────────────────────────┤
│  Tabs [Activity | Holdings/Overview] │
├────────────────────────────────────┤
│  Activity Feed                      │
│  ├── Search Bar                     │
│  ├── Table Header                   │
│  └── 交易列表 (按日期分组)           │
└────────────────────────────────────┘
```

**组件**: `app/components/UI/account_page.rb`

### 5.3 账户卡片

**位置**: `app/views/accounts/_account.html.erb`

**特点**:
- Logo + 名称 + 机构名称
- 余额显示
- 启用/禁用开关 (Toggle)
- 悬停显示编辑/链接按钮
- 支持 Turbo 局部更新

---

## 6. 交易管理 UI

### 6.1 交易列表页

**结构**:
```
┌────────────────────────────────────┐
│  Header (标题 + 新建按钮)            │
├────────────────────────────────────┤
│  Summary (收入/支出/净额统计)        │
├────────────────────────────────────┤
│  Search & Filter                   │
├────────────────────────────────────┤
│  即将到来的定期交易 (可折叠)         │
├────────────────────────────────────┤
│  交易列表 (按日期分组)              │
│  ├── 日期分组标题                   │
│  └── 交易项 (支持批量选择)          │
└────────────────────────────────────┘
```

**位置**: `app/views/transactions/index.html.erb`

### 6.2 交易项

**组件**: `app/views/transactions/_transaction.html.erb`

**信息展示**:
- 日期
- 类别 (带图标)
- 账户
- 金额 (收入绿色/支出红色)
- 待处理标记

### 6.3 批量操作

使用 BulkSelectController:
- 顶部选择栏 (Selection Bar)
- 批量删除、分类、标签

---

## 7. 仪表盘 UI

**位置**: `app/views/pages/dashboard.html.erb`

### 7.1 可折叠区块

每个区块支持:
- 折叠/展开
- 拖拽排序 (touch + keyboard 支持)
- 用户偏好持久化

### 7.2 默认区块

| 区块 | 内容 |
|------|------|
| Net Worth Chart | 净资产趋势图 |
| Balance Sheet | 资产负债表 (可展开的账户组) |
| Outflows Donut | 支出分类饼图 |
| Cashflow Sankey | 现金流桑基图 |
| Group Weight | 账户权重分布 |

### 7.3 余额表组件

**位置**: `app/views/pages/dashboard/_balance_sheet.html.erb`

**特点**:
- 按资产/负债分类
- 使用 `<details>` 实现账户组展开
- 显示权重百分比
- 可折叠到具体账户

---

## 8. 表单模式

### 8.1 通用表单结构

```erb
<%= form_with model: @transaction, local: true, class: "space-y-6" do |f| %>
  <!-- 字段组 -->
  <div>
    <label>金额</label>
    <%= f.number_field :amount %>
  </div>
  
  <!-- 提交按钮 -->
  <div class="flex gap-4">
    <%= link_to "取消", :back %>
    <%= f.submit "保存" %>
  </div>
<% end %>
```

### 8.2 类型切换 (收入/支出)

使用 Tab 或 Segmented Control:
```erb
<div class="flex" data-controller="tabs">
  <button data-tabs-target="btn" data-action="tabs#select">支出</button>
  <button data-tabs-target="btn" data-action="tabs#select">收入</button>
</div>
<%= f.hidden_field :type, id: "transaction_type" %>
```

---

## 9. 组件通信模式

### 9.1 ViewComponent Slots

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

### 9.2 Turbo 广播

当数据更新时，通过 ActionCable 广播:
```ruby
# 账户余额更新后
Turbo::StreamsChannel.broadcast_replace_to(
  "account_#{account.id}",
  target: "account_#{account.id}",
  renderable: AccountCardComponent.new(account: account)
)
```

---

## 10. 可借鉴的设计模式

### 10.1 推荐采用

1. **三栏布局**: 侧边栏(账户) + 主内容 + 详情栏(AI)
2. **DS 组件库**: 统一的 Button/Link/Menu/Tabs/Dialog 组件
3. **语义化颜色**: 使用 `text-primary`/`bg-container` 替代 `text-white`/`bg-white`
4. **Hotwire 局部刷新**: 交易列表、账户余额等高频更新区域
5. **Disclosure 折叠**: 使用 `<details>` 而非自定义折叠组件
6. **批量操作**: Selection Bar + BulkSelect 控制器

### 10.2 Ledger 项目适配建议

1. **交易页改版**:
   - 左栏: 账户列表 (添加"所有交易"选项)
   - 中栏: 选中账户详情
   - 右栏: 交易列表

2. **统一设计令牌**: 将颜色定义为 Tailwind CSS 变量

3. **组件化**: 将交易项、账户卡提取为 ViewComponent

4. **交互优化**:
   - 搜索框添加 auto-submit-form
   - 使用 Turbo Frame 实现筛选后局部刷新

---

## 11. 参考资源

- Sure 项目地址: https://github.com/we-promise/sure
- 组件文档: `/lookbook`
- Hotwire 文档: https://hotwired.dev/
- Stimulus 文档: https://stimulus.hotwired.dev/
