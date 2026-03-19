module Money
  CURRENCY_SYMBOLS = {
    "CNY" => "¥",
    "USD" => "$",
    "EUR" => "€",
    "GBP" => "£",
    "JPY" => "¥",
    "KRW" => "₩",
    "HKD" => "HK$",
    "TWD" => "NT$",
    "AUD" => "A$",
    "CAD" => "C$",
    "CHF" => "CHF",
    "INR" => "₹",
    "THB" => "฿",
    "SGD" => "S$"
  }.freeze

  def self.symbol(currency_code)
    CURRENCY_SYMBOLS[currency_code.to_s.upcase] || currency_code.to_s
  end

  def self.format(amount, currency_code = "CNY")
    "#{symbol(currency_code)}#{amount.to_s("%.2f")}"
  end

  module Concern
    extend ActiveSupport::Concern

    included do
      delegate :symbol, to: :"Money", prefix: false, allow_nil: true
    end

    def currency_symbol
      Money.symbol(currency)
    end

    def format_amount(amount = self.amount)
      Money.format(amount, currency)
    end
  end
end
