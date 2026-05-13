# frozen_string_literal: true

module Ds
  # Filled Icon Component - Icon with circular colored background
  #
  # Renders an icon inside a filled circular container.
  # Useful for status indicators, category icons, etc.
  #
  # ## Usage
  #   render(Ds::FilledIconComponent.new(icon: "wallet", color: :blue, size: :md))
  #
  # ## Options
  # - icon: Icon name (Lucide icon set)
  # - color: Background color (:red, :orange, :yellow, :green, :teal, :blue, :indigo, :purple, :pink, :gray)
  # - size: Container size (:sm, :md, :lg)
  #
  class FilledIconComponent < BaseComponent
    COLORS = {
      red: "bg-red-100 text-red-600",
      orange: "bg-orange-100 text-orange-600",
      yellow: "bg-yellow-100 text-yellow-600",
      green: "bg-green-100 text-green-600",
      teal: "bg-teal-100 text-teal-600",
      blue: "bg-blue-100 text-blue-600",
      indigo: "bg-indigo-100 text-indigo-600",
      purple: "bg-purple-100 text-purple-600",
      pink: "bg-pink-100 text-pink-600",
      gray: "bg-gray-100 text-gray-600"
    }.freeze

    SIZES = {
      sm: { container: "w-8 h-8", icon: :sm },
      md: { container: "w-10 h-10", icon: :md },
      lg: { container: "w-12 h-12", icon: :lg }
    }.freeze

    def initialize(
      icon: nil,
      color: :blue,
      size: :md,
      **options
    )
      @icon = icon
      @color = color.to_sym
      @size = size.to_sym
      @options = options
    end

    def call
      content_tag(:div, class: container_classes) do
        if @icon.present?
          render(Ds::IconComponent.new(@icon, size: icon_size))
        else
          content
        end
      end
    end

    private

    def container_classes
      classes = [ "flex items-center justify-center rounded-full shrink-0" ]
      classes << COLORS[@color] || COLORS[:blue]
      classes << size_class
      classes << @options[:class]
      classes.join(" ")
    end

    def size_class
      size_config = SIZES[@size] || SIZES[:md]
      size_config[:container]
    end

    def icon_size
      size_config = SIZES[@size] || SIZES[:md]
      size_config[:icon]
    end
  end
end
