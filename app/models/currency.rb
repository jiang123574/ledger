class Currency < ApplicationRecord
  validates :code, presence: true, uniqueness: true, length: { is: 3 }
  validates :name, :symbol, presence: true

  def self.default
    find_by(is_default: true) || find_by(code: "CNY")
  end

  CURRENCY_SYMBOLS = {
    "CNY" => "¥", "USD" => "$", "EUR" => "€", "GBP" => "£",
    "JPY" => "¥", "KRW" => "₩", "HKD" => "HK$", "TWD" => "NT$",
    "SGD" => "S$", "AUD" => "A$", "CAD" => "C$", "NZD" => "NZ$"
  }

  def symbol_display
    CURRENCY_SYMBOLS[code] || code
  end
end
