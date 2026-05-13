# frozen_string_literal: true

module Ds
  # Sankey Chart Component - Renders flow diagram visualization
  #
  # Displays data flow between nodes as connected streams.
  # Uses Stimulus controller for client-side D3.js rendering.
  #
  # ## Usage
  #   render(Ds::SankeyChartComponent.new(
  #     data: {
  #       nodes: [{ name: "Income" }, { name: "Expense" }],
  #       links: [{ source: 0, target: 1, value: 100 }]
  #     },
  #     height: 400
  #   ))
  #
  # ## Options
  # - data: Hash with :nodes and :links arrays
  # - height: SVG height in pixels (default: 400)
  #
  class SankeyChartComponent < BaseComponent
    def initialize(
      data: {},
      height: 400,
      **options
    )
      @data = data
      @height = height.to_i
      @options = options
    end

    def call
      content_tag(:div, class: "relative", data: {
        controller: "sankey-chart",
        sankey_chart_data_value: data_json,
        sankey_chart_height_value: @height
      }) do
        content_tag(:svg, "", class: "w-full", data: { sankey_chart_target: "chart" })
      end
    end

    private

    def data_json
      {
        nodes: @data[:nodes] || [],
        links: @data[:links] || []
      }.to_json
    end
  end
end
