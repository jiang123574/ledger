class MonthNavigatorComponent < ViewComponent::Base
  include ApplicationComponent

  def initialize(current_month:, path_helper: "dashboard_path")
    @current_month = current_month
    @path_helper = path_helper
  end

  def call
    content_tag(:div, class: "flex items-center space-x-2") do
      concat(prev_link)
      concat(current_month_span)
      concat(next_link)
    end
  end

  private

  def prev_month
    @current_month.to_date.prev_month.strftime("%Y-%m")
  end

  def next_month
    @current_month.to_date.next_month.strftime("%Y-%m")
  end

  def prev_link
    link_to("←", { controller: @path_helper.gsub("_path", "").to_sym, action: :show, month: prev_month },
            class: "px-3 py-1 bg-white border rounded hover:bg-gray-50 transition-colors")
  end

  def next_link
    link_to("→", { controller: @path_helper.gsub("_path", "").to_sym, action: :show, month: next_month },
            class: "px-3 py-1 bg-white border rounded hover:bg-gray-50 transition-colors")
  end

  def current_month_span
    content_tag(:span, @current_month, class: "px-4 py-1 bg-white border rounded font-medium min-w-[100px] text-center")
  end
end
