# frozen_string_literal: true

module Ds
  class DonutChartComponent < BaseComponent
    COLORS = %w[
      #ef4444 #f97316 #eab308 #84cc16 #22c55e #14b8a6 #06b6d4 #0ea5e9 #3b82f6
      #6366f1 #8b5cf6 #a855f7 #d946ef #ec4899 #f43f5e
    ].freeze

    def initialize(
      data: {},
      size: 200,
      inner_radius: nil,
      show_labels: true,
      **options
    )
      @data = data
      @size = size.to_i
      @inner_radius = inner_radius.present? ? inner_radius.to_i : (@size * 0.5).to_i
      @show_labels = show_labels
      @options = options
    end

    def call
      content_tag(:div, class: "relative", data: {
        controller: "donut-chart",
        donut_chart_data_value: data_json,
        donut_chart_size_value: @size,
        donut_chart_inner_radius_value: @inner_radius,
        donut_chart_colors_value: COLORS
      }) do
        safe_join([
          content_tag(:svg, "", class: "donut-chart", data: { donut_chart_target: "chart" }),
          if @show_labels
            content_tag(:div, "", class: "absolute inset-0 flex items-center justify-center", data: { donut_chart_target: "legend" })
          end
        ])
      end
    end

    private

    def data_json
      @data.map.with_index do |(label, value), index|
        {
          id: index,
          label: label,
          value: value.to_f,
          color: COLORS[index % COLORS.size]
        }
      end.to_json
    end
  end
end
