class Account < ApplicationRecord
  self.inheritance_column = nil

  has_many :sent_transactions, class_name: "Transaction", foreign_key: "account_id", dependent: :destroy
  has_many :received_transactions, class_name: "Transaction", foreign_key: "target_account_id", dependent: :destroy
  has_many :plans, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :currency, length: { is: 3 }, allow_blank: true

  scope :visible, -> { where(hidden: false) }
  scope :included_in_total, -> { where(include_in_total: true) }
  scope :by_type, ->(type) { where(type: type) if type.present? }

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

  def format_balance
    "#{currency_symbol}#{current_balance.to_s("%.2f")}"
  end

  def cash_flow(from_date, to_date)
    income = sent_transactions.income.where(date: from_date..to_date).sum(:amount)
    expense = sent_transactions.expense.where(date: from_date..to_date).sum(:amount)
    { income: income, expense: expense, net: income - expense }
  end
end
