# frozen_string_literal: true

module Ds
  class BadgeComponent < BaseComponent
    VARIANTS = {
      default: "bg-gray-100 text-gray-800",
      primary: "bg-blue-100 text-blue-800",
      success: "bg-green-100 text-green-800",
      warning: "bg-yellow-100 text-yellow-800",
      danger: "bg-red-100 text-red-800",
      info: "bg-blue-100 text-blue-800",
      income: "bg-income-light text-income",
      expense: "bg-expense-light text-expense",
      transfer: "bg-blue-100 text-blue-700"
    }.freeze

    SIZES = {
      xs: "px-1.5 py-0.5 text-xs",
      sm: "px-2 py-0.5 text-xs",
      md: "px-2.5 py-1 text-sm"
    }.freeze

    def initialize(
      variant: :default,
      size: :sm,
      dot: false,
      **options
    )
      @variant = variant
      @size = size
      @dot = dot
      @options = options
    end

    def call
      content_tag(:span, **options) do
        safe_join([ render_dot, content ].compact)
      end
    end

    private

    def options
      {
        class: [ base_classes, variant_classes, size_classes, @options[:class] ].compact.join(" ")
      }
    end

    def base_classes
      "inline-flex items-center gap-1 font-medium rounded-full"
    end

    def variant_classes
      VARIANTS[@variant] || VARIANTS[:default]
    end

    def size_classes
      SIZES[@size] || SIZES[:sm]
    end

    def render_dot
      return nil unless @dot

      tag.span(
        class: [
          "w-1.5 h-1.5 rounded-full",
          dot_color
        ].join(" ")
      )
    end

    def dot_color
      case @variant
      when :success, :expense then "bg-income"
      when :warning then "bg-yellow-500"
      when :danger, :income then "bg-expense"
      when :info, :transfer then "bg-blue-500"
      else "bg-gray-500"
      end
    end
  end
end
