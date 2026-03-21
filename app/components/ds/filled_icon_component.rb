# frozen_string_literal: true

module Ds
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
      classes = ["flex items-center justify-center rounded-full shrink-0"]
      classes << COLORS[@color] || COLORS[:blue]
      classes << size_class
      classes << @options[:class]
      classes.join(" ")
    end

    def size_class
      case @size
      when :sm then "w-8 h-8"
      when :md then "w-10 h-10"
      when :lg then "w-12 h-12"
      else "w-10 h-10"
      end
    end

    def icon_size
      case @size
      when :sm then :sm
      when :md then :md
      when :lg then :lg
      else :md
      end
    end
  end
end
