# frozen_string_literal: true

module Ds
  # Toggle Component - Switch for boolean settings
  #
  # Usage:
  #   <%= render(Ds::ToggleComponent.new(id: "notifications", name: "notifications", checked: true)) %>
  #   <%= render(Ds::ToggleComponent.new(id: "dark-mode", name: "dark_mode", checked: false, disabled: true)) %>
  #
  # In forms:
  #   <%= form_with(model: @settings) do |f| %>
  #     <%= f.label :notifications %>
  #     <%= render(Ds::ToggleComponent.new(id: "settings_notifications", name: "settings[notifications]", checked: @settings.notifications)) %>
  #   <% end %>
  #
  class ToggleComponent < BaseComponent
    def initialize(id:, name: nil, checked: false, disabled: false, checked_value: "1", unchecked_value: "0", **options)
      @id = id
      @name = name
      @checked = checked
      @disabled = disabled
      @checked_value = checked_value
      @unchecked_value = unchecked_value
      @options = options
    end

    def call
      tag.div(class: "relative inline-block select-none") do
        safe_join([
          hidden_field,
          checkbox,
          label
        ])
      end
    end

    private

    def hidden_field
      tag.input(
        type: "hidden",
        name: @name,
        value: @unchecked_value,
        id: nil
      )
    end

    def checkbox
      tag.input(
        type: "checkbox",
        name: @name,
        id: @id,
        value: @checked_value,
        checked: @checked,
        disabled: @disabled,
        class: "sr-only peer",
        data: @options[:data]
      )
    end

    def label
      tag.label(
        "&nbsp;".html_safe,
        for: @id,
        class: label_classes
      )
    end

    def label_classes
      class_names(
        # Base styles
        "block w-9 h-5 cursor-pointer rounded-full transition-colors duration-300",
        # Background colors
        "bg-gray-200 dark:bg-gray-700",
        # Track
        "after:content-[''] after:block after:bg-white after:absolute after:rounded-full",
        "after:top-0.5 after:left-0.5 after:w-4 after:h-4",
        "after:transition-transform after:duration-300 after:ease-in-out",
        # Checked state
        "peer-checked:bg-blue-600 peer-checked:after:translate-x-4",
        # Disabled state
        "peer-disabled:opacity-70 peer-disabled:cursor-not-allowed",
        # Hover
        "hover:shadow-sm"
      )
    end
  end
end
