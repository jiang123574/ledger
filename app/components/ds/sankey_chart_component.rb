# frozen_string_literal: true

module Ds
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
