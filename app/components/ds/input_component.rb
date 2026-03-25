# frozen_string_literal: true

module Ds
  class InputComponent < ViewComponent::Base
    def initialize(form:, field:, type: :text, placeholder: nil, required: false, prefix: nil, html_class: nil, **options)
      @form = form
      @field = field
      @type = type
      @placeholder = placeholder
      @required = required
      @prefix = prefix
      @html_class = html_class
      @options = options
    end

    def call
      if @prefix
        content_tag(:div, class: "relative") do
          content_tag(:span, @prefix, class: "absolute left-3 top-1/2 -translate-y-1/2 text-secondary dark:text-secondary-dark") +
          text_field_or_select
        end
      else
        text_field_or_select
      end
    end

    private

    def base_classes
      prefix_class = @prefix ? "pl-8 pr-3 py-2" : "px-3 py-2"
      custom_class = @html_class ? "#{@html_class} " : ""
      "#{custom_class}w-full #{prefix_class} text-sm rounded-lg border border-border dark:border-border-dark bg-white dark:bg-container-dark text-primary dark:text-primary-dark focus:ring-blue-500 dark:focus:ring-blue-400 focus:border-blue-500 dark:focus:border-blue-400"
    end

    def text_field_or_select
      case @type
      when :text
        @form.text_field(@field, class: base_classes, placeholder: @placeholder, required: @required, **@options)
      when :email
        @form.email_field(@field, class: base_classes, placeholder: @placeholder, required: @required, **@options)
      when :password
        @form.password_field(@field, class: base_classes, placeholder: @placeholder, required: @required, **@options)
      when :number
        @form.number_field(@field, class: base_classes, placeholder: @placeholder, required: @required, **@options)
      when :textarea
        @form.text_area(@field, class: base_classes, placeholder: @placeholder, required: @required, rows: 3, **@options)
      when :select
        choices = @options.delete(:choices) || []
        include_blank = @options.delete(:include_blank) || @placeholder
        @form.select(@field, choices, { include_blank: include_blank }, class: base_classes, **@options)
      else
        @form.text_field(@field, class: base_classes, placeholder: @placeholder, required: @required, **@options)
      end
    end
  end
end
