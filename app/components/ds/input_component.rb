# frozen_string_literal: true

module Ds
  class InputComponent < ViewComponent::Base
    def initialize(form:, field:, type: :text, placeholder: nil, required: false, **options)
      @form = form
      @field = field
      @type = type
      @placeholder = placeholder
      @required = required
      @options = options
    end

    def call
      base_classes = "w-full px-3 py-2 text-sm rounded-lg border border-border dark:border-border-dark bg-white dark:bg-container-dark text-primary dark:text-primary-dark focus:ring-blue-500 dark:focus:ring-blue-400 focus:border-blue-500 dark:focus:border-blue-400"
      
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
        @form.select(@field, @options[:choices], { include_blank: @placeholder }, class: base_classes)
      else
        @form.text_field(@field, class: base_classes, placeholder: @placeholder, required: @required, **@options)
      end
    end
  end
end
