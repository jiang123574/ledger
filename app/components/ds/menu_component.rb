# frozen_string_literal: true

module Ds
  # Menu Component - Dropdown menu with items
  #
  # Usage:
  #   <%= render(Ds::MenuComponent.new(placement: "bottom-end")) do |menu| %>
  #     <% menu.with_button do %>
  #       <%= render(Ds::ButtonComponent.new(variant: :ghost, icon: "dots-vertical")) %>
  #     <% end %>
  #     <% menu.with_item(variant: :link, text: "Edit", icon: "pencil", href: edit_path) %>
  #     <% menu.with_item(variant: :link, text: "Delete", icon: "trash", href: delete_path, destructive: true) %>
  #   <% end %>
  #
  # Variants for menu: :icon (default), :button, :avatar
  # Variants for items: :link, :button, :divider
  #
  class MenuComponent < BaseComponent
    renders_one :button
    renders_one :header
    renders_many :items, "Ds::MenuItemComponent"

    VARIANTS = %i[icon button avatar].freeze

    def initialize(variant: :icon, placement: "bottom-end", offset: 12, mobile_fullwidth: true, **options)
      @variant = variant.to_sym
      @placement = placement
      @offset = offset
      @mobile_fullwidth = mobile_fullwidth
      @options = options

      raise ArgumentError, "Invalid variant: #{@variant}" unless VARIANTS.include?(@variant)
    end

    def call
      tag.div(
        data: {
          controller: "menu",
          menu_placement_value: @placement,
          menu_offset_value: @offset,
          menu_mobile_fullwidth_value: @mobile_fullwidth
        }
      ) do
        safe_join([trigger_button, menu_content])
      end
    end

    private

    def trigger_button
      case @variant
      when :icon
        render(Ds::ButtonComponent.new(
          variant: :ghost,
          icon: "dots-vertical",
          data: { menu_target: "button" }
        ))
      when :button
        tag.button(data: { menu_target: "button" }) { button }
      when :avatar
        tag.button(data: { menu_target: "button" }) do
          tag.div(class: "w-9 h-9 cursor-pointer rounded-full bg-gray-200 dark:bg-gray-700 flex items-center justify-center") do
            tag.span(class: "text-sm font-medium text-gray-600 dark:text-gray-300") { "U" }
          end
        end
      end
    end

    def menu_content
      tag.div(data: { menu_target: "content" }, class: "hidden z-50 px-2 lg:px-0 max-w-full") do
        tag.div(class: "mx-auto min-w-[200px] shadow-lg bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700") do
          safe_join([
            header_content,
            items_content
          ].compact)
        end
      end
    end

    def header_content
      return nil unless header

      tag.div(class: "border-b border-gray-200 dark:border-gray-700 p-3") { header }
    end

    def items_content
      tag.div(class: "py-1") do
        safe_join(items.map { |item| item })
      end
    end
  end
end