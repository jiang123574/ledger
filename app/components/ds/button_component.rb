# frozen_string_literal: true

module Ds
  class ButtonComponent < BaseComponent
    VARIANTS = {
      primary: {
        container: "bg-inverse text-white hover:bg-inverse-hover",
        icon: "text-white"
      },
      secondary: {
        container: "bg-gray-200 text-primary hover:bg-gray-300",
        icon: "text-primary"
      },
      destructive: {
        container: "bg-destructive text-white hover:bg-destructive-hover",
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
      xs: "px-2 py-1 text-xs rounded-sm",
      sm: "px-3 py-1.5 text-sm rounded",
      md: "px-4 py-2 text-sm rounded-lg",
      lg: "px-5 py-3 text-base rounded-xl"
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
          content
        end
      else
        button_tag(**button_options) do
          content
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
      "inline-flex items-center justify-center gap-2 font-medium transition-smooth focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
    end

    def container_classes
      [base_classes, size_classes, variant_classes[:container]].join(" ")
    end

    def link_options
      opts = {
        class: [container_classes, @options[:class]].compact.join(" ")
      }
      opts[:data] = @options[:data] if @options[:data]
      opts
    end

    def button_options
      opts = {
        type: @type,
        disabled: @disabled || @loading,
        class: [container_classes, @options[:class]].compact.join(" ")
      }
      opts[:data] = { disable_with: "..." }.merge(@options[:data] || {}) if @loading
      opts
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
