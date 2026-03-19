class Transaction < ApplicationRecord
  self.inheritance_column = nil

  belongs_to :account, class_name: "Account", optional: true
  belongs_to :target_account, class_name: "Account", foreign_key: "target_account_id", optional: true
  belongs_to :category, class_name: "Category", optional: true
  belongs_to :receivable, optional: true
  belongs_to :link, class_name: "Transaction", optional: true
  has_and_belongs_to_many :tags, join_table: "transaction_tags"
  has_many :attachments, dependent: :destroy

  validates :transaction_type, presence: true
  validates :amount, presence: true, numericality: true

  scope :by_date, ->(start_date, end_date) {
    where(date: start_date..end_date)
  }
  scope :by_type, ->(type) { where(transaction_type: type) if type.present? }
  scope :by_account, ->(account_id) { where(account_id: account_id) if account_id.present? }

  def account_name
    account&.name || "未知账户"
  end

  def target_account_name
    target_account&.name
  end

  def tag_list
    tags.pluck(:id)
  end

  CURRENCY_SYMBOLS = {
    "CNY" => "¥", "USD" => "$", "EUR" => "€", "GBP" => "£",
    "JPY" => "¥", "KRW" => "₩", "HKD" => "HK$", "TWD" => "NT$"
  }

  def currency_symbol
    CURRENCY_SYMBOLS[currency] || currency
  end

  def expense?
    transaction_type == "EXPENSE"
  end

  def income?
    transaction_type == "INCOME"
  end

  def type
    transaction_type
  end

  def type=(value)
    self.transaction_type = value
  end
end
