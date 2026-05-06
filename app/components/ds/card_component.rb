# frozen_string_literal: true

module Ds
  # Card Component - Renders a container with configurable styling
  #
  # Usage:
  #   <%= render(Ds::CardComponent.new) do %>Content here<% end %>
  #   <%= render(Ds::CardComponent.new(padding: false, shadow: :border_md)) do %>
  #     <div class="p-4">Custom padding</div>
  #   <% end %>
  #
  # Options:
  #   padding: true/false (default: true)
  #   rounded: :sm, :md, :lg, :xl, :none (default: :lg)
  #   shadow: :none, :border_xs, :border_sm, :border_md, :border_lg (default: :border_xs)
  #
  class CardComponent < BaseComponent
    ROUNDED_CLASSES = {
      sm: "rounded-sm",
      md: "rounded",
      lg: "rounded-lg",
      xl: "rounded-xl",
      none: ""
    }.freeze

    SHADOW_CLASSES = {
      none: "",
      border_xs: "shadow-border-xs",
      border_sm: "shadow-border-sm",
      border_md: "shadow-border-md",
      border_lg: "shadow-border-lg"
    }.freeze

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
        class: [ base_classes, @options[:class] ].compact.join(" ")
      }
    end

    def base_classes
      classes = [ "bg-container" ]
      classes << ROUNDED_CLASSES.fetch(@rounded, "rounded-lg")
      classes << SHADOW_CLASSES.fetch(@shadow, "shadow-border-xs")
      classes << "p-4 lg:p-6" if @padding

      classes.join(" ")
    end
  end
end
