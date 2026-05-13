# frozen_string_literal: true

module Ds
  # Base Component - Foundation class for all Ds components
  #
  # Provides common utilities for ViewComponent-based design system.
  # All Ds::* components inherit from this base class.
  #
  # ## Key Methods
  # - class_names: Build CSS class strings from conditions
  #
  # ## Usage
  #   class_names(active: true, disabled: false) => "active"
  #   class_names("foo", "bar", active: true) => "foo bar active"
  #
  class BaseComponent < ViewComponent::Base
    # Build class names from keyword arguments or string arguments
    # Usage:
    #   class_names(active: true, disabled: false) => "active"
    #   class_names("foo", "bar", active: true) => "foo bar active"
    def class_names(*args, **options)
      classes = args.select { |arg| arg.is_a?(String) && arg.present? }
      keyword_classes = options.filter_map { |k, v| k.to_s.dasherize if v }
      (classes + keyword_classes).join(" ")
    end
  end
end
