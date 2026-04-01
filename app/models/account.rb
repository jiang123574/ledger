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

  has_many :sent_transactions, class_name: "Transaction", foreign_key: "account_id", dependent: :destroy
  has_many :received_transactions, class_name: "Transaction", foreign_key: "target_account_id", dependent: :destroy
  has_many :plans, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :currency, presence: true, length: { is: 3 }

  scope :visible, -> { where(hidden: false) }
  scope :included_in_total, -> { where(include_in_total: true) }
  scope :by_type, ->(type) { where(type: type) if type.present? }
  scope :by_currency, ->(currency) { where(currency: currency) if currency.present? }
  scope :by_last_activity, -> { order(last_transaction_date: :desc) }

  # 获取默认货币
  def self.default_currency
    Currency.default&.code || "CNY"
  end

  # 计算当前余额
  # INCOME: +amount
  # EXPENSE: -amount
  # TRANSFER: 源账户 -amount, 目标账户 +amount
  def current_balance
    balance = initial_balance.to_d

    # 收入：增加余额
    balance += sent_transactions.income.sum(:amount).to_d

    # 支出：减少余额
    balance -= sent_transactions.expense.sum(:amount).to_d

    # 预支：减少余额
    balance -= sent_transactions.where(type: "ADVANCE").sum(:amount).to_d

    # 报销：增加余额
    balance += sent_transactions.where(type: "REIMBURSE").sum(:amount).to_d

    # 转账：从本账户转出减少余额
    balance -= sent_transactions.transfers.sum(:amount).to_d

    # 转账：转入本账户增加余额
    balance += received_transactions.transfers.sum(:amount).to_d

    balance
  end

  # 计算总资产（所有账户余额之和）
  def self.total_assets
    visible.included_in_total.sum do |account|
      account.current_balance
    end
  end

  # 按账户类型统计余额
  def self.balance_by_type
    visible.included_in_total.group(:type).sum do |account|
      account.current_balance
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

    {
      income: sent_transactions.where(type: "INCOME", date: start_date..end_date).sum(:amount),
      expense: sent_transactions.where(type: "EXPENSE", date: start_date..end_date).sum(:amount)
    }
  end

  def currency_symbol
    Money.symbol(currency)
  end

  def type_name
    ACCOUNT_TYPES[type] || type.presence || "账户"
  end

  def cash_flow(from_date, to_date)
    income = sent_transactions.income.where(date: from_date..to_date).sum(:amount)
    expense = sent_transactions.expense.where(date: from_date..to_date).sum(:amount)
    { income: income, expense: expense, net: income - expense }
  end

  def update_transactions_cache!
    update(
      transactions_count: sent_transactions.count + received_transactions.count,
      last_transaction_date: [sent_transactions.maximum(:date), received_transactions.maximum(:date)].compact.max
    )
  end

  def self.bulk_update_cache
    find_each { |account| account.update_transactions_cache! }
  end
end
