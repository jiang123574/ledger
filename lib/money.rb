module Money
  def self.symbol(currency_code)
    code = currency_code.to_s.upcase
    # 优先使用 Currency 模型的符号表，未加载时回退到内置表
    if defined?(Currency::CURRENCY_SYMBOLS)
      Currency::CURRENCY_SYMBOLS[code] || code
    else
      FALLBACK_SYMBOLS[code] || code
    end
  end

  def self.format(amount, currency_code = "CNY")
    "#{symbol(currency_code)}#{amount.to_s("%.2f")}"
  end

  # 内置回退表（Currency 模型未加载时使用）
  FALLBACK_SYMBOLS = {
    "CNY" => "¥", "USD" => "$", "EUR" => "€", "GBP" => "£",
    "JPY" => "¥", "KRW" => "₩", "HKD" => "HK$", "TWD" => "NT$",
    "SGD" => "S$", "AUD" => "A$", "CAD" => "C$", "NZD" => "NZ$",
    "CHF" => "CHF", "INR" => "₹", "THB" => "฿"
  }.freeze

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
