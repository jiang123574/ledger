# frozen_string_literal: true

module Ds
  class MenuComponent < BaseComponent
    VARIANTS = %i[icon button].freeze

    renders_one :button_content
    renders_many :items, MenuItemComponent

    def initialize(
      variant: :icon,
      placement: "bottom-end",
      offset: 8,
      **options
    )
      @variant = variant.to_sym
      @placement = placement
      @offset = offset
      @options = options
    end

    private

    attr_reader :options

    def wrapper_classes
      "relative inline-block"
    end
  end
end
