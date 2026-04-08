class StatCardComponent < ViewComponent::Base
  include ApplicationComponent

  def initialize(title:, value:, currency: "¥", trend: nil, trend_direction: nil, color: "blue")
    @title = title
    @value = value
    @currency = currency
    @trend = trend
    @trend_direction = trend_direction
    @color = color
  end

  def call
    content_tag(:div, class: "bg-white rounded-lg shadow-sm p-6") do
      concat(content_tag(:h3, @title, class: "text-sm font-medium text-gray-500"))
      concat(content_tag(:p, formatted_value, class: "text-2xl font-bold text-#{@color}-600 mt-1"))
      if @trend
        concat(content_tag(:p, trend_html, class: "text-sm mt-2"))
      end
    end
  end

  private

  def formatted_value
    "#{@currency}#{@value.to_s("%.2f")}"
  end

  def trend_html
    direction_class = @trend_direction == :up ? "text-income" : "text-expense"
    arrow = @trend_direction == :up ? "↑" : "↓"
    content_tag(:span, "#{arrow} #{@trend}", class: direction_class)
  end
end
