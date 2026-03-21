# frozen_string_literal: true

module Ds
  class ToggleComponent < BaseComponent
    def initialize(
      id:,
      name: nil,
      checked: false,
      disabled: false,
      checked_value: "1",
      unchecked_value: "0",
      size: :md,
      **options
    )
      @id = id
      @name = name
      @checked = checked
      @disabled = disabled
      @checked_value = checked_value
      @unchecked_value = unchecked_value
      @size = size.to_sym
      @options = options
    end

    private

    attr_reader :options

    def track_classes
      classes = ["relative inline-block select-none cursor-pointer rounded-full transition-colors duration-300"]

      classes << case @size
                 when :sm then "w-7 h-4"
                 when :md then "w-9 h-5"
                 when :lg then "w-11 h-6"
                 else "w-9 h-5"
                 end

      classes << if @disabled
                   "bg-gray-200 dark:bg-gray-700 opacity-70 cursor-not-allowed"
                 else
                   "bg-gray-200 dark:bg-gray-700 peer-checked:bg-income"
                 end

      classes.join(" ")
    end

    def thumb_classes
      classes = ["absolute top-0.5 left-0.5 bg-white rounded-full transition-transform duration-300 ease-in-out shadow-sm"]

      classes << case @size
                 when :sm then "w-3 h-3"
                 when :md then "w-4 h-4"
                 when :lg then "w-5 h-5"
                 else "w-4 h-4"
                 end

      classes << "peer-checked:translate-x-full" if @size == :lg
      classes << case @size
                 when :sm then "peer-checked:translate-x-3.5"
                 when :md then "peer-checked:translate-x-4"
                 when :lg then "peer-checked:translate-x-5"
                 else "peer-checked:translate-x-4"
                 end

      classes.join(" ")
    end
  end
end
