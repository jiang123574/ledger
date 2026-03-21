module ApplicationHelper
  # Currency formatting helper
  # Uses Rails' number_to_currency with sensible defaults for CNY
  def format_currency(amount, unit: "¥", precision: 2)
    return format_currency(0, unit: unit, precision: precision) if amount.nil?
    number_to_currency(amount, unit: unit, precision: precision, format: "%u%n")
  end

  # Format currency with sign (for income/expense display)
  def format_currency_with_sign(amount, type:, unit: "¥", precision: 2)
    amount = 0 if amount.nil?
    sign = type == "INCOME" ? "+" : "-"
    "#{sign}#{format_currency(amount.abs, unit: unit, precision: precision)}"
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
        class: nav_item_link_classes(is_active)
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
      is_active ? "bg-blue-100 text-blue-600" : ""
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
end
