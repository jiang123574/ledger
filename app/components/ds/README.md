# DS Component Library

Design System components for Ledger application.

## Components

### AlertComponent

Display contextual feedback messages.

```erb
<%= render(Ds::AlertComponent.new(message: "Success!", variant: :success)) %>

<%= render(Ds::AlertComponent.new(message: "Warning!", variant: :warning, dismissible: true)) %>

<%= render(Ds::AlertComponent.new(variant: :error)) do %>
  <strong>Error:</strong> Something went wrong.
<% end %>
```

**Variants:** `:info`, `:success`, `:warning`, `:error`

---

### MenuComponent

Dropdown menu with items.

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

---

### TooltipComponent

Display helpful information on hover.

```erb
<%= render(Ds::TooltipComponent.new(text: "Helpful tip", placement: "top")) do %>
  <%= render(Ds::IconComponent.new(name: "information-circle", size: :sm)) %>
<% end %>
```

**Placements:** `top`, `bottom`, `left`, `right`, `top-start`, `top-end`, `bottom-start`, `bottom-end`

---

### ToggleComponent

Switch for boolean settings.

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

---

### SelectComponent

Custom dropdown select with search support.

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

---

## Dependencies

- `@hotwired/stimulus` - For interactive components
- `@floating-ui/dom` - For positioning (menus, tooltips)
- Tailwind CSS - For styling

## Stimulus Controllers

- `menu_controller.js` - Dropdown menu positioning
- `tooltip_controller.js` - Tooltip positioning
- `select_controller.js` - Custom select dropdown
- `list_filter_controller.js` - Search filtering for select
- `alert_controller.js` - Dismissible alerts