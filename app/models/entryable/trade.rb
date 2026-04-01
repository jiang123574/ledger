# Entryable::Trade - 证券交易

class Entryable::Trade < ApplicationRecord
  include Entryable
  
  self.table_name = 'entryable_trades'
  
  belongs_to :security, class_name: '::Security', optional: true
  
  validates :qty, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  
  store_accessor :extra, :order_type, :commission, :fees
  
  def buy?
    order_type == 'buy'
  end
  
  def sell?
    order_type == 'sell'
  end
  
  def total_value
    qty * price
  end
  
  def lock_saved_attributes!
    lock_attr!(:security_id) if security_id.present?
    lock_attr!(:qty) if qty.present?
    lock_attr!(:price) if price.present?
  end
end