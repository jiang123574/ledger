# UI 改造计划 - 基于 Sure 项目研究

> 参考: [Sure 项目研究文档](./docs/sure-ui-research.md)

## 已完成 ✅

| 功能 | 状态 | 文件 |
|------|------|------|
| DS 基础组件 | ✅ | `app/components/ds/` |
| 语义化颜色系统 | ✅ | `tailwind.config.js` |
| 响应式布局 | ✅ | `app/views/layouts/` |
| 设置页左导航 | ✅ | `app/views/settings/` |
| 交易列表改版 | ✅ | `app/views/transactions/` |
| 账户类型下拉 | ✅ | `Account::ACCOUNT_TYPES` |
| 收入/支出颜色 | ✅ | 红/绿 颜色对调 |

## 阶段一：组件完善 ✅

| 组件 | 状态 | 文件 |
|------|------|------|
| Disclosure | ✅ | `app/components/ds/disclosure_component.rb` |
| Alert | ✅ | `app/components/ds/alert_component.rb` |
| Toggle | ✅ | `app/components/ds/toggle_component.rb` |
| Menu | ✅ | `app/components/ds/menu_component.rb` |
| Tooltip | ✅ | `app/components/ds/tooltip_component.rb` |
| FilledIcon | ✅ | `app/components/ds/filled_icon_component.rb` |

## 阶段二：交互增强 ✅

| 功能 | 状态 | 文件 |
|------|------|------|
| auto-submit-form | ✅ | `app/javascript/controllers/auto_submit_form_controller.js` |
| bulk-select | ✅ | `app/javascript/controllers/bulk_select_controller.js` |
| tabs | ✅ | `app/javascript/controllers/tabs_controller.js` |
| disclosure | ✅ | `app/javascript/controllers/ds_disclosure_controller.js` |

## 阶段三：页面改版 ✅

| 功能 | 状态 | 文件 |
|------|------|------|
| 交易页三栏布局 | ✅ | `app/views/transactions/index.html.erb` |
| 账户详情页 | ✅ | `app/views/accounts/show.html.erb` |
| 批量操作 (SelectionBar) | ✅ | `app/components/ds/selection_bar_component.rb` |
| 过滤器系统 | ✅ | `TransactionSearch` 模型 |

## 阶段四：高级功能 ✅

| 功能 | 状态 | 文件 |
|------|------|------|
| 图表系统 - 环形图 | ✅ | `app/components/ds/donut_chart_component.rb` |
| 图表系统 - 折线图 | ✅ | `app/javascript/controllers/sparkline_chart_controller.js` |
| 图表系统 - 时间序列 | ✅ | `app/javascript/controllers/time_series_chart_controller.js` |
| 图表系统 - 桑基图 | ✅ | `app/components/ds/sankey_chart_component.rb` |
| 暗色模式 | ✅ | `tailwind.config.js`, `theme_controller.js` |
| Turbo 实时更新 | ✅ | `Account#broadcast_refresh`, `Transaction#broadcast_refresh` |

## DS 组件库完整列表

| 组件 | 文件 | 功能 |
|------|------|------|
| Base | `base_component.rb` | 基础组件 |
| Icon | `icon_component.rb` | SVG 图标 |
| Button | `button_component.rb` | 按钮 |
| Badge | `badge_component.rb` | 徽章 |
| Card | `card_component.rb` | 卡片 |
| Tabs | `tabs_component.rb` | 标签页 |
| Dialog | `dialog_component.rb` | 对话框 |
| EmptyState | `empty_state_component.rb` | 空状态 |
| Input | `input_component.rb` | 输入框 |
| Disclosure | `disclosure_component.rb` | 折叠内容 |
| Alert | `alert_component.rb` | 警告提示 |
| Toggle | `toggle_component.rb` | 开关 |
| Menu | `menu_component.rb` | 下拉菜单 |
| MenuItem | `menu_item_component.rb` | 菜单项 |
| Tooltip | `tooltip_component.rb` | 工具提示 |
| FilledIcon | `filled_icon_component.rb` | 填充图标 |
| DonutChart | `donut_chart_component.rb` | 环形图 |
| SankeyChart | `sankey_chart_component.rb` | 桑基图 |
| FilterBadge | `filter_badge_component.rb` | 筛选徽章 |
| SelectionBar | `selection_bar_component.rb` | 批量选择栏 |

## Stimulus 控制器列表

| 控制器 | 文件 | 功能 |
|--------|------|------|
| auto-submit-form | `auto_submit_form_controller.js` | 表单自动提交 |
| bulk-select | `bulk_select_controller.js` | 批量选择 |
| tabs | `tabs_controller.js` | 标签页 |
| ds-menu | `ds_menu_controller.js` | 下拉菜单 |
| ds-tooltip | `ds_tooltip_controller.js` | 工具提示 |
| ds-disclosure | `ds_disclosure_controller.js` | 折叠面板 |
| donut-chart | `donut_chart_controller.js` | 环形图 |
| sparkline-chart | `sparkline_chart_controller.js` | 迷你折线图 |
| time-series-chart | `time_series_chart_controller.js` | 时间序列图 |
| sankey-chart | `sankey_chart_controller.js` | 桑基图 |
| theme | `theme_controller.js` | 主题切换 |

## 颜色语义

| 颜色 | CSS 类 | 用途 |
|------|--------|------|
| `bg-surface` | 页面背景 | 主背景色 |
| `bg-container` | 卡片背景 | 卡片/容器背景 |
| `text-primary` | 主文字 | 标题/重要文字 |
| `text-secondary` | 次要文字 | 说明文字 |
| `text-income` | 收入 | 金额为正 (红色 #ef4444) |
| `text-expense` | 支出 | 金额为负 (绿色 #22c55e) |

## 响应式断点

| 类名 | 断点 | 用途 |
|------|------|------|
| `lg:hidden` | 1024px+ | 桌面端隐藏 |
| `hidden lg:block` | 1024px+ | 移动端隐藏 |
| `md:hidden` | 768px+ | 仅移动端 |

## Hotwire 模式

```erb
<%# 局部刷新 %>
<%= turbo_frame_tag "transactions", src: transactions_path(format: :turbo) %>

<%# 实时广播 %>
<%= turbo_stream_from @account %>
<%= turbo_stream_from "transactions" %>

<%# 模型广播 %>
<%# after_save_commit :broadcast_refresh %>
<%# after_destroy_commit :broadcast_destroy %>
```

---

## 所有任务已完成！ ✅
