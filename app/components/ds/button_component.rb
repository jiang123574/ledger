# frozen_string_literal: true

module Ds
  class ButtonComponent < BaseComponent
    VARIANTS = {
      primary: {
        container: "bg-inverse text-white hover:bg-inverse-hover",
        icon: "text-white"
      },
      secondary: {
        container: "border border-border text-primary hover:bg-surface-hover",
        icon: "text-primary"
      },
      destructive: {
        container: "bg-red-100 text-red-600 hover:bg-red-200",
        icon: "text-red-600"
      },
      inverse: {
        container: "bg-inverse text-white hover:bg-inverse-hover",
        icon: "text-white"
      },
      outline: {
        container: "border border-border text-primary hover:bg-surface-hover",
        icon: "text-secondary"
      },
      ghost: {
        container: "text-primary hover:bg-surface-hover",
        icon: "text-secondary"
      },
      link: {
        container: "text-blue-600 hover:underline",
        icon: "text-blue-600"
      }
    }.freeze

    SIZES = {
      xs: "px-2 py-1 text-xs rounded-lg",
      sm: "px-3 py-1.5 text-sm rounded-lg",
      md: "px-4 py-1.5 text-sm rounded-lg",
      lg: "px-5 py-2 text-base rounded-lg"
    }.freeze

    def initialize(
      variant: :primary,
      size: :md,
      type: :button,
      href: nil,
      disabled: false,
      loading: false,
      icon: nil,
      icon_position: :left,
      **options
    )
      @variant = variant
      @size = size
      @type = type
      @href = href
      @disabled = disabled
      @loading = loading
      @icon = icon
      @icon_position = icon_position
      @options = options
    end

    def call
      if @href.present? && !@disabled
        link_to(@href, **link_options) do
          button_content
        end
      else
        button_tag(**button_options) do
          button_content
        end
      end
    end

    private

    def variant_classes
      VARIANTS[@variant] || VARIANTS[:primary]
    end

    def size_classes
      SIZES[@size] || SIZES[:md]
    end

    def base_classes
      "inline-flex items-center justify-center gap-2 font-medium transition-smooth btn-modern focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
    end

    def container_classes
      [ base_classes, size_classes, variant_classes[:container] ].join(" ")
    end

    def link_options
      opts = {
        class: [ container_classes, @options[:class] ].compact.join(" ")
      }
      opts[:data] = @options[:data] if @options[:data]
      opts
    end

    def button_options
      opts = {
        type: @type,
        disabled: @disabled || @loading,
        class: [ container_classes, @options[:class] ].compact.join(" ")
      }
      opts[:data] = (@options[:data] || {})
      opts[:data] = opts[:data].merge(loading: @loading) if @loading
      opts
    end

    def button_content
      icon = @loading ? tag.span(class: "btn-spinner", aria: { hidden: true }) : render_icon
      label = content if content.present?

      return icon || label unless icon && label

      @icon_position == :right ? safe_join([ label, icon ]) : safe_join([ icon, label ])
    end

    def render_icon
      return nil unless @icon

      render(Ds::IconComponent.new(name: @icon, size: icon_size))
    end

    def icon_size
      case @size
      when :xs then :xs
      when :sm then :xs
      when :lg then :md
      else :sm
      end
    end
  end
end
