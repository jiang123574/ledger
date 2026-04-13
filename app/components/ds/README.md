# DS Component Library

Design System components for Ledger application. 21 个组件提供统一的 UI 体验。

## 组件清单

### 基础组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `BaseComponent` | `base_component.rb` | 所有组件的基类 |
| `IconComponent` | `icon_component.rb` | Lucide 图标 |
| `FilledIconComponent` | `filled_icon_component.rb` | 填充色图标 |
| `BadgeComponent` | `badge_component.rb` | 标签/徽章 |

### 交互组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `ButtonComponent` | `button_component.rb` | 按钮（多种样式） |
| `ToggleComponent` | `toggle_component.rb` | 开关 |
| `SelectComponent` | `select_component.rb` | 下拉选择器 |
| `InputComponent` | `input_component.rb` | 输入框 |

### 反馈组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `AlertComponent` | `alert_component.rb` | 提示消息 |
| `TooltipComponent` | `tooltip_component.rb` | 工具提示 |

### 布局组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `CardComponent` | `card_component.rb` | 卡片容器 |
| `DialogComponent` | `dialog_component.rb` | 对话框 |
| `DisclosureComponent` | `disclosure_component/` | 折叠面板 |
| `EmptyStateComponent` | `empty_state_component.rb` | 空状态占位 |

### 导航组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `MenuComponent` | `menu_component.rb` | 下拉菜单 |
| `MenuItemComponent` | `menu_item_component.rb` | 菜单项 |
| `TabsComponent` | `tabs_component.rb` | 标签页 |
| `FilterBadgeComponent` | `filter_badge_component.rb` | 筛选标签 |
| `SelectionBarComponent` | `selection_bar_component.rb` | 批量操作栏 |

### 图表组件

| 组件 | 文件 | 说明 |
|------|------|------|
| `DonutChartComponent` | `donut_chart_component.rb` | 环形图 |
| `SankeyChartComponent` | `sankey_chart_component.rb` | 桑基图 |

## 使用示例

### AlertComponent

```erb
<%= render(Ds::AlertComponent.new(message: "Success!", variant: :success)) %>

<%= render(Ds::AlertComponent.new(message: "Warning!", variant: :warning, dismissible: true)) %>

<%= render(Ds::AlertComponent.new(variant: :error)) do %>
  <strong>Error:</strong> Something went wrong.
<% end %>
```

**Variants:** `:info`, `:success`, `:warning`, `:error`

### MenuComponent

```erb
<%= render(Ds::MenuComponent.new(placement: "bottom-end")) do |menu| %>
  <% menu.with_button do %>
    <%= render(Ds::ButtonComponent.new(variant: :ghost, icon: "dots-vertical")) %>
  <% end %>
  
  <% menu.with_item(variant: :link, text: "Edit", icon: "pencil", href: edit_path) %>
  <% menu.with_item(variant: :divider) %>
  <% menu.with_item(variant: :link, text: "Delete", icon: "trash", href: delete_path, destructive: true) %>
<% end %>
```

**Menu Variants:** `:icon` (default), `:button`, `:avatar`
**Item Variants:** `:link`, `:button`, `:divider`

### TooltipComponent

```erb
<%= render(Ds::TooltipComponent.new(text: "Helpful tip", placement: "top")) do %>
  <%= render(Ds::IconComponent.new(name: "information-circle", size: :sm)) %>
<% end %>
```

**Placements:** `top`, `bottom`, `left`, `right`, `top-start`, `top-end`, `bottom-start`, `bottom-end`

### ToggleComponent

```erb
<%= render(Ds::ToggleComponent.new(
  id: "notifications",
  name: "notifications",
  checked: true
)) %>

<%= render(Ds::ToggleComponent.new(
  id: "dark-mode",
  name: "settings[dark_mode]",
  checked: false,
  disabled: true
)) %>
```

### SelectComponent

```erb
<%# Basic usage %>
<%= render(Ds::SelectComponent.new(
  form: f,
  method: :category_id,
  items: Category.all,
  selected: @transaction.category_id,
  placeholder: "Select category"
)) %>

<%# With search %>
<%= render(Ds::SelectComponent.new(
  form: f,
  method: :user_id,
  items: User.all,
  searchable: true,
  placeholder: "Search users..."
)) %>

<%# Custom items %>
<%= render(Ds::SelectComponent.new(
  form: f,
  method: :status,
  items: [
    { value: "active", label: "Active" },
    { value: "inactive", label: "Inactive" }
  ],
  selected: "active"
)) %>
```

## Dependencies

- `@hotwired/stimulus` - For interactive components
- `@floating-ui/dom` - For positioning (menus, tooltips)
- `chart.js` - For chart components
- Tailwind CSS - For styling

## Stimulus Controllers

| 控制器 | 用途 |
|--------|------|
| `menu_controller.js` | 下拉菜单定位 |
| `tooltip_controller.js` | 工具提示定位 |
| `select_controller.js` | 自定义下拉选择 |
| `list_filter_controller.js` | 搜索筛选 |
| `alert_controller.js` | 可关闭提示 |
| `ds_disclosure_controller.js` | 折叠面板 |
