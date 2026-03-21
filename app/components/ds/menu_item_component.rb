# frozen_string_literal: true

module Ds
  class MenuItemComponent < BaseComponent
    VARIANTS = %i[link button destructive divider].freeze

    def initialize(
      variant: :link,
      text: nil,
      icon: nil,
      href: nil,
      method: :get,
      **options
    )
      @variant = variant.to_sym
      @text = text
      @icon = icon
      @href = href
      @method = method.to_sym
      @options = options
    end

    def call
      return divider_html if @variant == :divider

      link_content = content_tag(:span, @text, class: text_classes)

      if @icon
        link_content = safe_join([
          render(Ds::IconComponent.new(@icon, size: "sm", class: icon_classes)),
          link_content
        ])
      end

      if @variant == :button
        button_to @href, method: @method, class: container_classes, data: @options[:data], **@options do
          link_content
        end
      else
        link_to @href, class: container_classes, data: @options[:data], **@options do
          link_content
        end
      end
    end

    private

    def container_classes
      classes = ["flex items-center gap-2 px-3 py-2 rounded-md w-full text-sm transition-colors"]
      classes << case @variant
                 when :destructive then "text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20"
                 else "text-primary hover:bg-surface-hover"
                 end
      classes.join(" ")
    end

    def text_classes
      "flex-1"
    end

    def icon_classes
      case @variant
      when :destructive then "text-red-500"
      else ""
      end
    end

    def divider_html
      content_tag(:div, "", class: "my-1 border-t border-border")
    end
  end
end
