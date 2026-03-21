class Currency < ApplicationRecord
  validates :code, presence: true, uniqueness: true, length: { is: 3 }
  validates :name, :symbol, presence: true

  scope :active, -> { where(is_active: true) }

  CURRENCY_SYMBOLS = {
    "CNY" => "¥", "USD" => "$", "EUR" => "€", "GBP" => "£",
    "JPY" => "¥", "KRW" => "₩", "HKD" => "HK$", "TWD" => "NT$",
    "SGD" => "S$", "AUD" => "A$", "CAD" => "C$", "NZD" => "NZ$"
  }

  def self.default
    find_by(is_default: true) || find_by(code: "CNY")
  end

  def symbol_display
    symbol.presence || CURRENCY_SYMBOLS[code] || code
  end

  # 获取汇率（相对于默认货币）
  def exchange_rate
    return BigDecimal("1") if is_default?
    rate.presence || BigDecimal("1")
  end

  # 转换金额到默认货币
  def convert_to_default(amount)
    return amount if is_default?
    (amount.to_d * exchange_rate).round(2)
  end

  # 从默认货币转换
  def convert_from_default(amount)
    return amount if is_default?
    return amount if exchange_rate.zero?
    (amount.to_d / exchange_rate).round(2)
  end

  # 类方法：获取货币符号
  def self.symbol(code)
    CURRENCY_SYMBOLS[code] || code
  end

  # 类方法：货币间转换
  def self.convert(amount, from_code, to_code, date: Date.current)
    return amount if from_code == to_code

    from_rate = find_by(code: from_code)&.exchange_rate || 1
    to_rate = find_by(code: to_code)&.exchange_rate || 1

    # 先转为默认货币，再转为目标货币
    default_amount = amount.to_d * from_rate
    target_amount = to_rate > 0 ? default_amount / to_rate : default_amount

    target_amount.round(2)
  end
end
