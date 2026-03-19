module ApplicationHelper
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
      class: mobile_nav_item_classes(is_active)
    ) do
      safe_join([
        render(Ds::IconComponent.new(name: icon, size: :md, color: is_active ? :primary : :secondary)),
        content_tag(:span, label, class: "text-xs mt-1")
      ])
    end
  end

  private

  def nav_item_link_classes(is_active)
    [
      "flex items-center gap-3 px-3 py-2 rounded-lg transition-smooth",
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

    content_tag(:div, "", class: "absolute left-0 w-1 h-6 bg-blue-500 rounded-r")
  end

  def mobile_nav_item_classes(is_active)
    [
      "flex flex-col items-center justify-center flex-1 h-full py-2",
      is_active ? "text-blue-600" : "text-secondary"
    ].join(" ")
  end
end
