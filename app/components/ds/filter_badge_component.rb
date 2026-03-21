# frozen_string_literal: true

module Ds
  class FilterBadgeComponent < BaseComponent
    def initialize(label:, value:, remove_url: nil)
      @label = label
      @value = value
      @remove_url = remove_url
    end

    def call
      content_tag(:span, class: "inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-surface text-primary") do
        safe_join([
          content_tag(:span, @label, class: "text-secondary"),
          content_tag(:span, ":", class: "text-secondary mx-0.5"),
          content_tag(:span, @value),
          if @remove_url
            link_to(@remove_url, class: "ml-1 hover:text-income") do
              render(Ds::IconComponent.new(name: "x", size: :xs))
            end
          end
        ])
      end
    end
  end
end
