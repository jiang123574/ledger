module Ds
  class BaseComponent < ViewComponent::Base
    def class_names(**options)
      options.filter_map { |k, v| k.to_s.dasherize if v }.join(" ")
    end
  end
end
