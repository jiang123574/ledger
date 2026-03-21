class Transaction < ApplicationRecord
  self.inheritance_column = nil

  belongs_to :account, class_name: "Account", optional: true
  belongs_to :target_account, class_name: "Account", foreign_key: "target_account_id", optional: true
  belongs_to :category, class_name: "Category", optional: true
  belongs_to :receivable, optional: true
  belongs_to :link, class_name: "Transaction", optional: true
  has_many :attachments, dependent: :destroy

  validates :type, presence: true
  validates :amount, presence: true, numericality: true

  after_save_commit :broadcast_refresh
  after_destroy_commit :broadcast_destroy

  scope :by_date, ->(start_date, end_date) {
    where(date: start_date..end_date)
  }
  scope :by_type, ->(type) { where(type: type) if type.present? }
  scope :by_account, ->(account_id) { where(account_id: account_id) if account_id.present? }
  scope :income, -> { where(type: "INCOME") }
  scope :expense, -> { where(type: "EXPENSE") }
  scope :for_month, ->(month) {
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month
    where(date: start_date..end_date)
  }

  def broadcast_channel
    "transaction_#{id}"
  end

  def broadcast_refresh
    broadcast_replace_later_to "transactions"
    broadcast_replace_later_to "dashboard"
    account&.broadcast_refresh
    target_account&.broadcast_refresh
  end

  def broadcast_destroy
    broadcast_remove_to "transactions"
    broadcast_replace_to "dashboard"
    account&.broadcast_refresh
    target_account&.broadcast_refresh
  end

  def currency_symbol
    account&.currency_symbol || "¥"
  end

  def account_name
    account&.name || "未知账户"
  end

  def target_account_name
    target_account&.name
  end

  def expense?
    type == "EXPENSE"
  end

  def income?
    type == "INCOME"
  end

  def display_amount
    prefix = income? ? "+" : "-"
    "#{prefix}#{currency_symbol}#{amount.to_s("%.2f")}"
  end

  def self.monthly_stats(month)
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    transactions = where(date: start_date..end_date)
    {
      income: transactions.income.sum(:amount),
      expense: transactions.expense.sum(:amount),
      balance: transactions.income.sum(:amount) - transactions.expense.sum(:amount),
      count: transactions.count
    }
  end

  def self.by_category(month, transaction_type = "EXPENSE")
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    where(type: transaction_type, date: start_date..end_date)
      .group("COALESCE(category, 'Uncategorized')")
      .order(Arel.sql("SUM(amount) DESC"))
      .sum(:amount)
  end
end
