module ApplicationComponent
  extend ActiveSupport::Concern

  included do
    class_attribute :default_classes
    self.default_classes = ""
  end

  def classes(*args)
    args.flatten.compact.join(" ")
  end

  def data_attributes(attrs = {})
    attrs.map { |k, v| "data-#{k}=\"#{v}\"" }.join(" ")
  end
end
