# Entryable 基类模块
# 学习自 Sure 的 delegated_type 设计

module Entryable
  extend ActiveSupport::Concern
  
  TYPES = %w[
    Entryable::Transaction
    Entryable::Valuation
    Entryable::Trade
  ].freeze
  
  included do
    has_one :entry, as: :entryable, touch: true, dependent: :destroy
    has_one :account, through: :entry
    
    delegate :date, :name, :amount, :currency, :notes, :excluded?,
             :date=, :name=, :amount=, :currency=, :notes=,
             to: :entry, allow_nil: true
    
    after_initialize :set_defaults, if: :new_record?
  end
  
  def set_defaults
    self.locked_attributes ||= {}
  end
  
  def lock_attr!(attr_name)
    self.locked_attributes ||= {}
    self.locked_attributes[attr_name] = Time.current.iso8601
    save!
  end
  
  def locked?(attr_name)
    locked_attributes&.dig(attr_name).present?
  end
  
  def lock_saved_attributes!
  end
  
  class_methods do
    def model_name
      ActiveModel::Name.new(self, nil, name.demodulize)
    end
  end
end