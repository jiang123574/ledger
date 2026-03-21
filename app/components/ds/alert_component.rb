# frozen_string_literal: true

module Ds
  class AlertComponent < BaseComponent
    VARIANTS = {
      info: "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-900/20 dark:text-blue-400 dark:border-blue-800",
      success: "bg-green-50 text-green-700 border-green-200 dark:bg-green-900/20 dark:text-green-400 dark:border-green-800",
      warning: "bg-yellow-50 text-yellow-700 border-yellow-200 dark:bg-yellow-900/20 dark:text-yellow-400 dark:border-yellow-800",
      error: "bg-red-50 text-red-700 border-red-200 dark:bg-red-900/20 dark:text-red-400 dark:border-red-800",
      destructive: "bg-red-50 text-red-700 border-red-200 dark:bg-red-900/20 dark:text-red-400 dark:border-red-800"
    }.freeze

    ICONS = {
      info: "information-circle",
      success: "check-circle",
      warning: "exclamation-triangle",
      error: "x-circle",
      destructive: "x-circle"
    }.freeze

    def initialize(
      message:,
      variant: :info,
      dismissible: false,
      **options
    )
      @message = message
      @variant = variant.to_sym
      @dismissible = dismissible
      @options = options
    end

    private

    attr_reader :options

    def container_classes
      classes = ["flex items-start gap-3 p-4 rounded-lg border", VARIANTS[@variant]]
      classes.join(" ")
    end

    def icon_name
      ICONS[@variant]
    end
  end
end
