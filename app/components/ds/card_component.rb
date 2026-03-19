# frozen_string_literal: true

module Ds
  class CardComponent < BaseComponent
    def initialize(
      padding: true,
      rounded: :lg,
      shadow: :border_xs,
      **options
    )
      @padding = padding
      @rounded = rounded
      @shadow = shadow
      @options = options
    end

    def call
      content_tag(:div, **options) do
        content
      end
    end

    private

    def options
      {
        class: [base_classes, @options[:class]].compact.join(" ")
      }
    end

    def base_classes
      classes = ["bg-container"]

      classes << case @rounded
                 when :sm then "rounded-sm"
                 when :md then "rounded"
                 when :lg then "rounded-lg"
                 when :xl then "rounded-xl"
                 when :none then ""
                 else "rounded-lg"
                 end

      classes << case @shadow
                 when :none then ""
                 when :border_xs then "shadow-border-xs"
                 when :border_sm then "shadow-border-sm"
                 when :border_md then "shadow-border-md"
                 when :border_lg then "shadow-border-lg"
                 else "shadow-border-xs"
                 end

      classes << (@padding ? "p-4 lg:p-6" : "")

      classes.join(" ")
    end
  end
end
