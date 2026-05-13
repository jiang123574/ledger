# frozen_string_literal: true

module Ds
  # Filter Badge Component - Displays active filter state
  #
  # Renders a badge showing current filter label and value,
  # with optional remove link to clear the filter.
  #
  # ## Usage
  #   render(Ds::FilterBadgeComponent.new(
  #     label: "Category",
  #     value: "Food",
  #     remove_url: accounts_path(category_id: nil)
  #   ))
  #
  # ## Options
  # - label: Filter type label (required)
  # - value: Current filter value (required)
  # - remove_url: URL to clear this filter (optional)
  #
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
