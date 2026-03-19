# frozen_string_literal: true

module Ds
  class DialogComponent < BaseComponent
    VARIANTS = {
      modal: "max-w-md",
      wide: "max-w-2xl",
      full: "max-w-4xl"
    }.freeze

    def initialize(
      title: nil,
      subtitle: nil,
      size: :modal,
      show_close: true,
      **options
    )
      @title = title
      @subtitle = subtitle
      @size = size
      @show_close = show_close
      @options = options
    end

    def call
      content_tag(:div, **dialog_wrapper_options) do
        content_tag(:div, **dialog_content_options) do
          header + body + actions
        end
      end
    end

    def with_header(**options, &block)
      @header_block = block
      @header_options = options
      nil
    end

    def with_body(**options, &block)
      @body_block = block
      @body_options = options
      nil
    end

    def with_actions(**options, &block)
      @actions_block = block
      @actions_options = options
      nil
    end

    private

    def dialog_wrapper_options
      {
        class: "fixed inset-0 z-50 overflow-y-auto",
        data: { controller: "dialog" }
      }
    end

    def dialog_content_options
      size_class = VARIANTS[@size] || VARIANTS[:modal]
      { class: "relative bg-container rounded-xl shadow-border-lg m-auto p-6 #{size_class}" }
    end

    def header
      return @header_block.call if @header_block
      return nil unless @title

      content_tag(:div, class: "mb-4") do
        safe_join([
          content_tag(:h3, @title, class: "text-lg font-semibold text-primary"),
          (@subtitle ? content_tag(:p, @subtitle, class: "text-sm text-secondary mt-1") : nil)
        ].compact)
      end
    end

    def body
      return @body_block.call(@body_options) if @body_block
      content
    end

    def actions
      return nil unless @actions_block

      content_tag(:div, class: "mt-6 flex justify-end gap-3") do
        @actions_block.call
      end
    end
  end
end
