# frozen_string_literal: true

module Ds
  # Menu Item Component - Individual item within a menu
  #
  # Usage (typically used via MenuComponent#with_item):
  #   menu.with_item(variant: :link, text: "Edit", icon: "pencil", href: edit_path)
  #   menu.with_item(variant: :button, text: "Delete", icon: "trash", href: delete_path, destructive: true)
  #   menu.with_item(variant: :divider)
  #
  class MenuItemComponent < BaseComponent
    VARIANTS = %i[link button divider].freeze

    def initialize(variant:, text: nil, icon: nil, href: nil, method: :post, destructive: false, confirm: nil, **options)
      @variant = variant.to_sym
      @text = text
      @icon = icon
      @href = href
      @method = method.to_sym
      @destructive = destructive
      @confirm = confirm
      @options = options

      raise ArgumentError, "Invalid variant: #{@variant}" unless VARIANTS.include?(@variant)
    end

    def call
      if @variant == :divider
        tag.hr(class: "my-1 border-gray-200 dark:border-gray-700")
      else
        tag.div(class: "px-1") { render_item }
      end
    end

    private

    def render_item
      case @variant
      when :link
        link_to(@href, class: container_classes, **link_options) do
          safe_join([icon_element, text_element].compact)
        end
      when :button
        button_to(@href, method: @method, class: container_classes, **button_options) do
          safe_join([icon_element, text_element].compact)
        end
      end
    end

    def container_classes
      [
        "flex items-center gap-2 p-2 rounded-md w-full text-sm",
        destructive? ? "text-red-600 hover:bg-red-50 dark:text-red-400 dark:hover:bg-red-900/20" : "text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
      ].join(" ")
    end

    def icon_element
      return nil unless @icon

      render(Ds::IconComponent.new(
        name: @icon,
        size: :sm,
        class: destructive? ? "text-red-500" : "text-gray-500 dark:text-gray-400"
      ))
    end

    def text_element
      return nil unless @text
      tag.span(@text)
    end

    def destructive?
      @method == :delete || @destructive
    end

    def link_options
      opts = @options.dup
      data = opts.delete(:data) || {}
      opts.merge(data: data)
    end

    def button_options
      opts = @options.dup
      data = opts.delete(:data) || {}

      if @confirm.present?
        data = data.merge(turbo_confirm: @confirm)
      end

      opts.merge(data: data)
    end
  end
end