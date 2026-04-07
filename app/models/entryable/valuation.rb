# Entryable::Valuation - 估值记录

class Entryable::Valuation < ApplicationRecord
  include Entryable

  self.table_name = "entryable_valuations"

  validates :extra, presence: true

  store_accessor :extra, :valuation_method, :source

  def lock_saved_attributes!
    # 估值通常不需要锁定
  end
end
