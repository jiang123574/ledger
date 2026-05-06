# frozen_string_literal: true

module Ds
  # Alert Component - Display contextual feedback messages
  #
  # Usage:
  #   <%= render(Ds::AlertComponent.new(message: "Operation successful!", variant: :success)) %>
  #   <%= render(Ds::AlertComponent.new(message: "Warning message", variant: :warning)) do %>
  #     <strong>Warning:</strong> Please review before continuing.
  #   <% end %>
  #
  # Variants: :info, :success, :warning, :error
  #
  class AlertComponent < BaseComponent
    VARIANTS = %i[info success warning error].freeze

    VARIANT_STYLES = {
      info: {
        container: "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-900/20 dark:text-blue-400 dark:border-blue-800",
        icon: "text-blue-600"
      },
      success: {
        container: "bg-green-50 text-green-700 border-green-200 dark:bg-green-900/20 dark:text-green-400 dark:border-green-800",
        icon: "text-green-600"
      },
      warning: {
        container: "bg-yellow-50 text-yellow-700 border-yellow-200 dark:bg-yellow-900/20 dark:text-yellow-400 dark:border-yellow-800",
        icon: "text-yellow-600"
      },
      error: {
        container: "bg-red-50 text-red-700 border-red-200 dark:bg-red-900/20 dark:text-red-400 dark:border-red-800",
        icon: "text-red-600"
      }
    }.freeze

    VARIANT_ICONS = {
      info: "information-circle",
      success: "check-circle",
      warning: "exclamation-circle",
      error: "x-circle"
    }.freeze

    def initialize(message: nil, variant: :info, dismissible: false, **options)
      @message = message
      @variant = variant.to_sym
      @dismissible = dismissible
      @options = options

      raise ArgumentError, "Invalid variant: #{@variant}" unless VARIANTS.include?(@variant)
    end

    def call
      tag.div(class: container_classes, data: { controller: ("alert--dismissible" if @dismissible) }) do
        safe_join([
          render(Ds::IconComponent.new(name: icon_name, size: :sm, class: "shrink-0 #{icon_color_class}")),
          tag.div(class: "flex-1 text-sm") { content.presence || @message },
          dismissible_button
        ].compact)
      end
    end

    private

    def container_classes
      variant_style = VARIANT_STYLES[@variant] || VARIANT_STYLES[:info]
      [ "flex items-start gap-3 p-4 rounded-lg border", variant_style[:container], @options[:class] ].compact.join(" ")
    end

    def icon_name
      VARIANT_ICONS[@variant] || VARIANT_ICONS[:info]
    end

    def icon_color_class
      variant_style = VARIANT_STYLES[@variant] || VARIANT_STYLES[:info]
      variant_style[:icon]
    end

    def dismissible_button
      return nil unless @dismissible

      tag.button(
        type: "button",
        class: "ml-auto -mr-1 p-1 rounded hover:bg-black/5 dark:hover:bg-white/5 transition-colors",
        data: { action: "alert--dismissible#dismiss" }
      ) do
        render(Ds::IconComponent.new(name: "x", size: :sm, class: "text-current opacity-70"))
      end
    end
  end
end
