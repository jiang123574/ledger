# frozen_string_literal: true

module Ds
  # Empty State Component - Displays placeholder when no data available
  #
  # Usage:
  #   <%= render(Ds::EmptyStateComponent.new(
  #     icon: "folder-open",
  #     title: "No entries found",
  #     description: "Start adding entries to track your finances"
  #   )) %>
  #
  # With action:
  #   <%= render(Ds::EmptyStateComponent.new(
  #     icon: "plus",
  #     title: "No accounts",
  #     action: new_account_path,
  #     action_label: "Create Account"
  #   )) %>
  #
  # Options: icon, title (required), description, action, action_label
  #
  class EmptyStateComponent < BaseComponent
    def initialize(
      icon: nil,
      title:,
      description: nil,
      action: nil,
      action_label: nil,
      **options
    )
      @icon = icon
      @title = title
      @description = description
      @action = action
      @action_label = action_label
      @options = options
    end

    def call
      content_tag(:div, **options) do
        safe_join([ render_icon, render_title, render_description, render_action ].compact)
      end
    end

    private

    def options
      { class: [ "flex flex-col items-center justify-center py-12 px-4 text-center", @options[:class] ].compact.join(" ") }
    end

    def render_icon
      return nil unless @icon

      content_tag(:div, class: "mb-4") do
        render(Ds::IconComponent.new(name: @icon, size: :xl, color: :secondary))
      end
    end

    def render_title
      content_tag(:h3, @title, class: "text-base font-medium text-primary mb-2")
    end

    def render_description
      return nil unless @description

      content_tag(:p, @description, class: "text-sm text-secondary mb-4 max-w-sm")
    end

    def render_action
      return nil unless @action && @action_label

      render(Ds::ButtonComponent.new(href: @action, variant: :outline, size: :sm)) do
        @action_label
      end
    end
  end
end
