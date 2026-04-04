class Account < ApplicationRecord
  self.inheritance_column = nil

  ACCOUNT_TYPES = {
    "CASH" => "现金",
    "BANK" => "储蓄卡",
    "CREDIT" => "信用卡",
    "INVESTMENT" => "网络账户",
    "LOAN" => "贷款",
    "DEBT" => "欠款"
  }.freeze

  has_many :entries, dependent: :destroy
  has_many :transaction_entries, -> { where(entryable_type: 'Entryable::Transaction') }, class_name: 'Entry'
  has_many :valuation_entries, -> { where(entryable_type: 'Entryable::Valuation') }, class_name: 'Entry'
  has_many :trade_entries, -> { where(entryable_type: 'Entryable::Trade') }, class_name: 'Entry'
  has_many :plans, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :currency, presence: true, length: { is: 3 }

  scope :visible, -> { where(hidden: false) }
  scope :included_in_total, -> { where(include_in_total: true) }
  scope :by_type, ->(type) { where(type: type) if type.present? }
  scope :by_currency, ->(currency) { where(currency: currency) if currency.present? }
  scope :by_last_activity, -> { order(last_transaction_date: :desc) }

  def self.default_currency
    Currency.default&.code || "CNY"
  end

  def current_balance
    initial_balance.to_d + transaction_entries.sum(:amount).to_d
  end

  # 已废弃：使用 current_balance（基于 Entry）
  def current_balance_from_transactions
    current_balance
  end

  # 优化：单次 SQL 查询，避免 N+1
  def self.total_assets
    result = visible.included_in_total
      .joins("LEFT JOIN entries ON entries.account_id = accounts.id AND entries.entryable_type = 'Entryable::Transaction'")
      .group("accounts.id")
      .pluck(Arel.sql("accounts.id, accounts.initial_balance + COALESCE(SUM(entries.amount), 0)"))
      .to_h

    Account.visible.included_in_total
      .where.not(id: result.keys)
      .pluck(:id, :initial_balance)
      .each { |id, balance| result[id] = balance }

    result.values.sum(&:to_d)
  end

  def self.balance_by_type
    accounts_by_type = visible.included_in_total.group(:type).pluck(:type)

    accounts_by_type.each_with_object({}) do |type, hash|
      result = visible.included_in_total.where(type: type)
        .joins("LEFT JOIN entries ON entries.account_id = accounts.id AND entries.entryable_type = 'Entryable::Transaction'")
        .group("accounts.id")
        .pluck(Arel.sql("accounts.id, accounts.initial_balance + COALESCE(SUM(entries.amount), 0)"))
        .to_h

      visible.included_in_total.where(type: type)
        .where.not(id: result.keys)
        .pluck(:id, :initial_balance)
        .each { |id, balance| result[id] = balance }

      hash[type] = result.values.sum(&:to_d)
    end
  end

  def balance_series(months = 12)
    balances = []
    current = current_balance
    months.times do |i|
      date = i.months.ago.end_of_month
      balances << { date: date, balance: current }
    end
    balances.reverse
  end

  def monthly_flow(month)
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    month_entries = transaction_entries.where(date: start_date..end_date).where("transfer_id IS NULL")

    {
      income: month_entries.where('amount > 0').sum(:amount),
      expense: month_entries.where('amount < 0').sum('ABS(amount)')
    }
  end

  def currency_symbol
    Money.symbol(currency)
  end

  def type_name
    ACCOUNT_TYPES[type] || type.presence || "账户"
  end

  def cash_flow(from_date, to_date)
    period_entries = transaction_entries.where(date: from_date..to_date).where("transfer_id IS NULL")
    income = period_entries.where('amount > 0').sum(:amount)
    expense = period_entries.where('amount < 0').sum('ABS(amount)')
    { income: income, expense: expense, net: income - expense }
  end

  # 已废弃：使用 update_entries_cache!
  def update_transactions_cache!
    update_entries_cache!
  end

  def update_entries_cache!
    update(
      transactions_count: entries.count,
      last_transaction_date: entries.maximum(:date)
    )
  end

  def self.bulk_update_cache
    find_each { |account| account.update_entries_cache! }
  end

  # 已废弃：统一用 bulk_update_cache
  def self.bulk_update_entries_cache
    bulk_update_cache
  end
end
