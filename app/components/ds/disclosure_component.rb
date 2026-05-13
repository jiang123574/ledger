# frozen_string_literal: true

module Ds
  # Disclosure Component - Expandable/collapsible content container
  #
  # Renders a details/summary element with configurable styling.
  # Supports both chevron and arrow rotation indicators.
  #
  # ## Usage
  #   render(Ds::DisclosureComponent.new(title: "Details")) do
  #     "Hidden content here"
  #   end
  #
  # ## Options
  # - title: Summary title text
  # - align: Icon alignment (:left, :right)
  # - open: Initial expanded state (true/false)
  # - rounded: Border radius (:sm, :md, :lg, :xl, :none)
  #
  class DisclosureComponent < BaseComponent
    renders_one :summary_content

    def initialize(
      title: nil,
      align: :right,
      open: false,
      rounded: :lg,
      **options
    )
      @title = title
      @align = align.to_sym
      @open = open
      @rounded = rounded
      @options = options
    end

    private

    attr_reader :options

    def summary_classes
      classes = [ "cursor-pointer flex items-center justify-between", base_summary_class ]

      classes << case @rounded
      when :sm then "rounded-sm"
      when :md then "rounded"
      when :lg then "rounded-lg"
      when :xl then "rounded-xl"
      when :none then ""
      else "rounded-lg"
      end

      classes.join(" ")
    end

    def base_summary_class
      "bg-container px-3 py-2"
    end

    def content_classes
      "mt-2"
    end

    def chevron_class
      "group-open:rotate-180 transition-transform duration-200"
    end

    def arrow_class
      "group-open:rotate-90 transition-transform duration-200"
    end
  end
end
