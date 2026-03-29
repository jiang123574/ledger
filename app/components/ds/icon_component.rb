# frozen_string_literal: true

module Ds
  class IconComponent < BaseComponent
    SIZES = {
      xs: "w-3 h-3",
      sm: "w-4 h-4",
      md: "w-5 h-5",
      lg: "w-6 h-6",
      xl: "w-8 h-8"
    }.freeze

    # Legacy icon names mapped to Lucide icons
    ICON_MAPPING = {
      "home" => "home",
      "chart-bar" => "bar-chart-3",
      "bar-chart-2" => "bar-chart-2",
      "credit-card" => "credit-card",
      "folder" => "folder",
      "map" => "map",
      "cog" => "settings",
      "plus" => "plus",
      "minus" => "minus",
      "x" => "x",
      "chevron-down" => "chevron-down",
      "chevron-up" => "chevron-up",
      "chevron-right" => "chevron-right",
      "chevron-left" => "chevron-left",
      "check" => "check",
      "search" => "search",
      "filter" => "filter",
      "calendar" => "calendar",
      "tag" => "tag",
      "user" => "user",
      "logout" => "log-out",
      "dots-vertical" => "more-vertical",
      "trash" => "trash-2",
      "pencil" => "pencil",
      "plus-circle" => "plus-circle",
      "minus-circle" => "minus-circle",
      "arrow-right" => "arrow-right",
      "arrow-left" => "arrow-left",
      "arrow-up-right" => "arrow-up-right",
      "arrow-down-right" => "arrow-down-right",
      "arrow-right-left" => "arrow-right-left",
      "refresh" => "refresh-cw",
      "external-link" => "external-link",
      "information-circle" => "info",
      "exclamation-circle" => "alert-circle",
      "check-circle" => "check-circle",
      "clock" => "clock",
      "cloud-upload" => "cloud-upload",
      "eye" => "eye",
      "eye-off" => "eye-off",
      "menu" => "menu",
      "bars-3" => "menu",
      "dots-horizontal" => "more-horizontal",
      "inbox" => "inbox",
      "photo" => "image",
      "paper-clip" => "paperclip",
      "globe" => "globe",
      "x-circle" => "x-circle",
      "alert-triangle" => "alert-triangle",
      "grip-vertical" => "grip-vertical",
      "receipt" => "receipt",
      "wallet" => "wallet",
      "upload" => "upload",
      "pie-chart" => "pie-chart",
      "target" => "target",
      "x-mark" => "x",
      "trash-2" => "trash-2",
      "trending-up" => "trending-up",
      "trending-down" => "trending-down"
    }.freeze

    def initialize(name:, size: :md, color: :current, **options)
      @name = name
      @size = size
      @color = color
      @options = options
    end

    def call
      helpers.lucide_icon(
        lucide_icon_name,
        class: [ "shrink-0", size_class, color_class, @options[:class] ]
      )
    end

    private

    def lucide_icon_name
      ICON_MAPPING[@name] || @name
    end

    def size_class
      SIZES[@size] || SIZES[:md]
    end

    def color_class
      @color == :current ? "text-current" : "text-#{@color}"
    end
  end
end
