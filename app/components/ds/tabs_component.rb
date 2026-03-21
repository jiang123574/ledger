# frozen_string_literal: true

module Ds
  class TabsComponent < BaseComponent
    def initialize(
      active_tab: nil,
      url_param_key: nil,
      variant: :default,
      **options
    )
      @active_tab = active_tab
      @url_param_key = url_param_key
      @variant = variant
      @options = options
      @tabs = []
    end

    def tab(id:, label:, &block)
      @tabs << { id: id, label: label, block: block }
    end

    def call
      content_tag(:div, class: "w-full", data: {
        controller: "tabs",
        tabs_active_tab_value: @active_tab || @tabs.first&.dig(:id),
        tabs_url_param_key_value: @url_param_key
      }) do
        safe_join([
          content_tag(:div, class: "border-b border-border") do
            content_tag(:nav, class: "flex space-x-8") do
              safe_join(@tabs.map { |t| tab_button(t) })
            end
          end,
          content_tag(:div, class: "mt-4") do
            safe_join(@tabs.map { |t| tab_panel(t) })
          end
        ])
      end
    end

    private

    attr_reader :options

    def tab_button(tab)
      is_active = (tab[:id].to_s == (@active_tab || @tabs.first[:id]).to_s)
      
      content_tag(:button,
        type: :button,
        class: tab_classes(is_active),
        data: { tab: tab[:id], action: "tabs#selectTab" }
      ) do
        tab[:label]
      end
    end

    def tab_panel(tab)
      is_active = (tab[:id].to_s == (@active_tab || @tabs.first[:id]).to_s)
      
      content_tag(:div,
        class: [is_active ? "" : "hidden"],
        data: { tab_panel: tab[:id] }
      ) do
        tab[:block].call
      end
    end

    def tab_classes(active)
      base = if @variant == :unstyled
        "py-2 px-3 text-sm font-medium rounded"
      else
        "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors"
      end
      
      active ? "#{base} #{@variant == :unstyled ? 'bg-blue-100 text-blue-700' : 'border-blue-600 text-blue-600'}" : "#{base} #{@variant == :unstyled ? 'text-gray-500 hover:text-gray-700' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
    end
  end
end
