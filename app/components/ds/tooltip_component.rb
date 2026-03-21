# frozen_string_literal: true

module Ds
  class TooltipComponent < BaseComponent
    def initialize(
      text: nil,
      placement: "top",
      offset: 10,
      icon: "information-circle",
      size: :sm,
      **options
    )
      @text = text
      @placement = placement
      @offset = offset
      @icon = icon
      @size = size
      @options = options
    end

    def call
      content_tag(:span, class: "inline-flex relative group", data: {
        controller: "ds-tooltip",
        ds_tooltip_placement_value: @placement,
        ds_tooltip_offset_value: @offset
      }) do
        safe_join([
          render(Ds::IconComponent.new(@icon, size: @size, class: "text-secondary")),
          content_tag(:div, "", class: "hidden absolute z-50 bg-gray-900 text-white text-xs px-2 py-1 rounded whitespace-nowrap pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-200", 
            data: { ds_tooltip_target: "tooltip" }) do
            @text
          end
        ])
      end
    end
  end
end
