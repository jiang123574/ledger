# frozen_string_literal: true

module Ds
  # Tooltip Component - Display helpful information on hover
  #
  # Usage:
  #   <%= render(Ds::TooltipComponent.new(text: "Helpful tip", placement: "top")) do %>
  #     <%= render(Ds::IconComponent.new(name: "information-circle", size: :sm)) %>
  #   <% end %>
  #
  # Placements: top, bottom, left, right, top-start, top-end, bottom-start, bottom-end
  #
  class TooltipComponent < BaseComponent
    PLACEMENTS = %w[top bottom left right top-start top-end bottom-start bottom-end].freeze

    def initialize(text: nil, placement: "top", offset: 10, **options)
      @text = text
      @placement = placement
      @offset = offset
      @options = options

      raise ArgumentError, "Invalid placement: #{@placement}" unless PLACEMENTS.include?(@placement)
    end

    def call
      tag.span(
        data: {
          controller: "tooltip",
          tooltip_placement_value: @placement,
          tooltip_offset_value: @offset
        },
        class: "inline-flex"
      ) do
        safe_join([
          content,
          tooltip_element
        ])
      end
    end

    private

    def tooltip_element
      tag.div(
        role: "tooltip",
        data: { tooltip_target: "tooltip" },
        class: "hidden absolute z-50 px-2 py-1 text-sm text-white bg-gray-900 dark:bg-gray-700 rounded-md shadow-lg max-w-[200px]"
      ) do
        @text
      end
    end
  end
end