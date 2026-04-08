class CardComponent < ViewComponent::Base
  include ApplicationComponent

  def initialize(title: nil, classes: "")
    @title = title
    @classes = classes
  end

  def call
    content_tag(:div, class: "bg-white rounded-lg shadow-sm #{@classes}") do
      if @title
        concat(content_tag(:div, @title, class: "px-6 py-4 border-b border-gray-200 font-medium text-gray-900"))
      end
      concat(content_tag(:div, class: "p-6") do
        yield
      end)
    end
  end
end
