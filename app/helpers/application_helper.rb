module ApplicationHelper
  # Currency formatting helper
  # Supports both:
  #   format_currency(amount, "CNY")
  #   format_currency(amount, unit: "¥")
  def format_currency(amount, currency = nil, unit: nil, precision: 2)
    amount = 0 if amount.nil?
    currency_unit = unit || currency_unit_for(currency)
    number_to_currency(amount, unit: currency_unit, precision: precision, format: "%u%n")
  end

  # Format currency with sign (for income/expense display)
  # Output format: +123.00 or -123.00 (no currency symbol, just number with sign)
  def format_currency_with_sign(amount, type:, unit: "", precision: 2)
    amount = 0 if amount.nil?
    sign = type == "INCOME" ? "+" : "-"
    fmt = unit.present? ? "%u%n" : "%n"
    "#{sign}#{number_to_currency(amount.abs, unit: unit, precision: precision, format: fmt)}"
  end

  # Format balance with appropriate sign and CSS class
  # Returns a hash with :amount and :css_class for easy use in views
  def format_balance(amount, unit: "¥", precision: 2)
    amount = 0 if amount.nil?
    is_positive = amount >= 0

    {
      amount: "#{is_positive ? '+' : '-'}#{format_currency(amount.abs, unit: unit, precision: precision)}",
      css_class: is_positive ? "text-income" : "text-expense"
    }
  end

  def nav_item(key, label, path, icon)
    is_active = current_page?(path) || (controller_name == key.to_s && action_name == "show" && key != :dashboard)

    content_tag(:div, class: "relative group") do
      link_to(
        path,
        class: nav_item_link_classes(is_active),
        data: { nav_path: path }
      ) do
        safe_join([
          active_indicator(is_active),
          icon_container(icon, is_active),
          content_tag(:span, label, class: nav_item_text_classes(is_active))
        ])
      end
    end
  end

  def mobile_nav_item(key, label, path, icon)
    is_active = current_page?(path) || (controller_name == key.to_s && action_name == "show" && key != :dashboard)

    link_to(
      path,
      class: mobile_nav_item_classes(is_active),
      data: { nav_path: path },
      "aria-current": is_active ? "page" : nil
    ) do
      safe_join([
        content_tag(:div, class: "mb-0.5") do
          render(Ds::IconComponent.new(name: icon, size: :md, color: is_active ? :primary : :secondary))
        end,
        content_tag(:span, label, class: "text-xs font-medium")
      ])
    end
  end

  private

  def currency_unit_for(currency)
    case currency.to_s.upcase
    when "USD"
      "$"
    when "EUR"
      "€"
    when "JPY"
      "¥"
    when "GBP"
      "£"
    else
      "¥"
    end
  end

  def nav_item_link_classes(is_active)
    [
      "flex items-center gap-3 px-3 py-3 rounded-lg transition-colors duration-150",
      "min-h-[44px]",  # Touch-friendly tap target
      is_active ? "bg-surface text-primary" : "text-secondary hover:bg-surface-hover hover:text-primary"
    ].join(" ")
  end

  def icon_container(icon, is_active)
    content_tag(:div, class: icon_container_classes(is_active)) do
      render(Ds::IconComponent.new(name: icon, size: :md, color: is_active ? :primary : :default))
    end
  end

  def icon_container_classes(is_active)
    [
      "w-8 h-8 flex items-center justify-center rounded-lg",
      is_active ? "bg-gray-200 dark:bg-surface-dark-hover text-primary dark:text-primary-dark" : "bg-gray-100 dark:bg-surface-dark-inset"
    ].join(" ")
  end

  def nav_item_text_classes(is_active)
    [
      "text-sm font-medium",
      is_active ? "text-primary" : "text-secondary"
    ].join(" ")
  end

  def active_indicator(is_active)
    return "" unless is_active

    content_tag(:div, "", class: "absolute left-0 w-1 h-6 bg-inverse rounded-r")
  end

  def mobile_nav_item_classes(is_active)
    [
      "flex flex-col items-center justify-center",
      "min-w-[44px] min-h-[44px]",  # Touch-friendly tap target
      "px-2 py-1.5 rounded-lg",
      "transition-colors duration-150",
      is_active ? "text-blue-600 bg-blue-50" : "text-secondary hover:text-primary hover:bg-surface-hover"
    ].join(" ")
  end

  def merge_filter_params
    { start_date: params[:start_date], end_date: params[:end_date], type: params[:type] }.compact
  end

  # 生成层级分类选项
  def category_options_for_select(categories, selected_id = nil)
    options = []

    # 按类型分组
    expense_categories = categories.select { |c| c.category_type == "EXPENSE" || c.type == "EXPENSE" }
    income_categories = categories.select { |c| c.category_type == "INCOME" || c.type == "INCOME" }

    if expense_categories.any?
      options << [ "── 支出分类 ──", "", disabled: true ]
      options += build_category_tree_options(expense_categories)
    end

    if income_categories.any?
      options << [ "", "", disabled: true ] if expense_categories.any?
      options << [ "── 收入分类 ──", "", disabled: true ]
      options += build_category_tree_options(income_categories)
    end

    options_for_select(options, selected_id)
  end

  private

  def build_category_tree_options(categories, parent_id = nil, level = 0)
    options = []
    roots = categories.select { |c| c.parent_id == parent_id }.sort_by(&:sort_order)

    roots.each do |category|
      prefix = "　" * level + (level > 0 ? "└ " : "")
      options << [ "#{prefix}#{category.name}", category.id ]

      children = categories.select { |c| c.parent_id == category.id }
      if children.any?
        options += build_category_tree_options(categories, category.id, level + 1)
      end
    end

    options
  end

  def render_category_filter_tree(categories, selected_ids)
    # 从已加载的所有 categories 中构建映射，完全避免 SQL 查询
    all_cats = @categories || categories
    children_map = all_cats.group_by(&:parent_id)
    # parent_id → category 映射，用于 full_name 的内存查找
    parent_map = all_cats.index_by(&:id)

    render_tree_nodes(categories, selected_ids, children_map, parent_map)
  end

  # 在内存中构建 full_name，完全不触发 SQL
  # @categories 集合必须在 controller 中已预加载
  def full_name_for(category)
    all_cats = @categories
    return category.full_name unless all_cats.is_a?(Array)

    parent_map = all_cats.index_by(&:id)
    build_full_name_in_memory(category, parent_map)
  end

  private

  def render_tree_nodes(nodes, selected_ids, children_map, parent_map)
    safe_join(nodes.map do |cat|
      indent = "padding-left: " + (cat.level * 16 + 12).to_s + "px"
      children = children_map[cat.id] || []
      # 用 parent_map 做内存查找，避免 full_name 递归触发 SQL
      full_name = build_full_name_in_memory(cat, parent_map)

      content_tag(:label, class: "flex items-center gap-2 py-1.5 px-3 cursor-pointer category-filter-item hover:bg-surface-hover dark:hover:bg-surface-dark-hover border-b border-border dark:border-border-dark last:border-b-0",
                  data: { name: cat.name, full_name: full_name, pinyin: PinYin.abbr(full_name || cat.name).downcase, type: cat.category_type },
                  style: indent) do
        safe_join([
          check_box_tag("category_ids[]", cat.id, selected_ids.include?(cat.id.to_s), class: "category-filter-option w-4 h-4 rounded border-border dark:border-border-dark"),
          content_tag(:span, full_name, class: "text-sm text-primary dark:text-primary-dark")
        ])
      end.html_safe +
      if children.any?
        render_tree_nodes(children, selected_ids, children_map, parent_map)
      else
        "".html_safe
      end
    end)
  end

  # 在内存中递归构建 full_name，完全不触发 SQL
  def build_full_name_in_memory(category, parent_map, separator: " > ")
    parent = parent_map[category.parent_id]
    parent ? "#{build_full_name_in_memory(parent, parent_map, separator: separator)}#{separator}#{category.name}" : category.name
  end
end
