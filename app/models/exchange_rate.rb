class ExchangeRate < ApplicationRecord
  validates :from_currency, :to_currency, :rate, :date, presence: true

  scope :for_pair, ->(from, to) {
    where(from_currency: from, to_currency: to)
      .order(date: :desc)
      .first
  }
end
