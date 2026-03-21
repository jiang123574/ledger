# frozen_string_literal: true

module Ds
  class InputComponent < BaseComponent
    def initialize(
      label: nil,
      name:,
      type: :text,
      value: nil,
      placeholder: nil,
      error: nil,
      required: false,
      disabled: false,
      hint: nil,
      **options
    )
      @label = label
      @name = name
      @type = type
      @value = value
      @placeholder = placeholder
      @error = error
      @required = required
      @disabled = disabled
      @hint = hint
      @options = options
    end

    def call
      content_tag(:div, class: "space-y-1.5") do
        safe_join([ render_label, render_input, render_error, render_hint ].compact)
      end
    end

    private

    def render_label
      return nil unless @label

      content_tag(:label, for: @name, class: "block text-sm font-medium text-primary") do
        safe_join([
          @label,
          (@required ? tag.span("*", class: "text-red-500 ml-0.5") : nil)
        ])
      end
    end

    def render_input
      opts = {
        name: @name,
        id: @name,
        type: @type,
        value: @value,
        placeholder: @placeholder,
        required: @required,
        disabled: @disabled,
        class: input_classes,
        **@options
      }

      tag.input(**opts)
    end

    def render_error
      return nil unless @error

      content_tag(:p, @error, class: "text-sm text-red-600")
    end

    def render_hint
      return nil unless @hint

      content_tag(:p, @hint, class: "text-sm text-secondary")
    end

    def input_classes
      classes = [ "w-full px-3 py-2 text-sm rounded-lg border transition-smooth" ]

      classes << if @error
        "border-red-500 focus:ring-red-500 focus:border-red-500"
      else
        "border-border focus:ring-blue-500 focus:border-blue-500"
      end

      classes << "bg-gray-50 cursor-not-allowed opacity-50" if @disabled

      classes.join(" ")
    end
  end
end
