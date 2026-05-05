# frozen_string_literal: true

module Ds
  # Tabs Component - Renders tab navigation with panels
  #
  # Usage:
  #   <%= render(Ds::TabsComponent.new(active_tab: :overview)) do |t| %>
  #     <% t.tab_link(:overview, "Overview") %>
  #     <% t.tab_link(:details, "Details") %>
  #     <% t.panel(:overview) do %>Overview content<% end %>
  #     <% t.panel(:details) do %>Details content<% end %>
  #   <% end %>
  #
  # Methods: tab_link(id, label), panel(id), panel_with_frame(id)
  # Options: active_tab (default: nil)
  #
  class TabsComponent < BaseComponent
    def initialize(active_tab: nil, **options)
      @active_tab = active_tab
      @options = options
    end

    def tab_link(id, label, **link_options)
      active_class = active?(id) ? "border-blue-500 text-blue-600" : "border-transparent text-secondary hover:text-primary hover:border-border"
      tab_classes = "px-4 py-2 text-sm font-medium border-b-2 transition-smooth #{active_class}"

      data = { action: "tabs#switch", tabs_target: "tab", tab_id: id }
      data = data.merge(link_options[:data]) if link_options[:data]

      link_to("#", class: tab_classes, data: data) do
        label
      end
    end

    def panel(id, &block)
      panel_classes = active?(id) ? "mt-4" : "mt-4 hidden"
      content_tag(:div, class: panel_classes, data: { tabs_target: "panel", tab_panel_id: id }, &block)
    end

    def panel_with_frame(id, &block)
      turbo_frame_tag("tab_panel_#{id}", data: { tabs_target: "panel", tab_panel_id: id }, &block)
    end

    private

    def active?(id)
      @active_tab == id
    end
  end
end
