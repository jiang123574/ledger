class ExchangeRate < ApplicationRecord
  validates :from_currency, :to_currency, :rate, :date, presence: true
  validates :rate, numericality: { greater_than: 0 }

  scope :for_pair_query, ->(from, to) {
    where(from_currency: from, to_currency: to)
      .order(date: :desc)
  }

  def self.for_pair(from, to)
    for_pair_query(from, to).first
  end

  scope :latest, -> { order(date: :desc) }
  scope :for_date, ->(date) { where(date: date) }

  # 获取最新汇率
  def self.latest_rate(from, to)
    return BigDecimal("1") if from == to

    rate = for_pair(from, to)
    rate&.rate || BigDecimal("1")
  end

  # 获取指定日期的汇率
  def self.rate_on_date(from, to, date)
    return BigDecimal("1") if from == to

    rate = where(from_currency: from, to_currency: to, date: date).first
    rate&.rate || latest_rate(from, to)
  end

  # 转换金额
  def self.convert(amount, from, to, date: Date.current)
    return amount if from == to

    rate = rate_on_date(from, to, date)
    (amount.to_d * rate).round(2)
  end

  # 创建反向汇率
  def create_reverse!
    return if rate.zero?

    ExchangeRate.find_or_create_by(
      from_currency: to_currency,
      to_currency: from_currency,
      date: date
    ) do |r|
      r.rate = (1.0 / rate).round(6)
      r.source = "#{source}_auto_reversed"
    end
  end
end
