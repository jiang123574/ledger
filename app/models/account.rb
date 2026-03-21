class Account < ApplicationRecord
  self.inheritance_column = nil

  ACCOUNT_TYPES = {
    "CASH" => "现金",
    "BANK" => "银行账户",
    "CREDIT" => "信用卡",
    "INVESTMENT" => "投资账户",
    "LOAN" => "贷款",
    "DEBT" => "欠款"
  }.freeze

  has_many :sent_transactions, class_name: "Transaction", foreign_key: "account_id", dependent: :destroy
  has_many :received_transactions, class_name: "Transaction", foreign_key: "target_account_id", dependent: :destroy
  has_many :plans, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :currency, length: { is: 3 }, allow_blank: true

  after_save_commit :broadcast_refresh
  after_destroy_commit :broadcast_destroy

  scope :visible, -> { where(hidden: false) }
  scope :included_in_total, -> { where(include_in_total: true) }
  scope :by_type, ->(type) { where(type: type) if type.present? }

  def broadcast_channel
    "account_#{id}"
  end

  def broadcast_refresh
    broadcast_replace_later_to "accounts", partial: "accounts/account", locals: { account: self }
    broadcast_replace_later_to "dashboard", partial: "dashboard/account_item", locals: { account: self }
  end

  def broadcast_destroy
    broadcast_remove_to "accounts"
    broadcast_replace_to "dashboard", partial: "dashboard/account_item", locals: { account: self }
  end

  def current_balance
    initial_balance.to_d + sent_transactions.sum(:amount).to_d - received_transactions.where.not(account_id: id).sum(:amount).to_d
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

  def transactions
    Transaction.where("account_id = ? OR target_account_id = ?", id, id)
  end
end
