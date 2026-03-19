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

  def current_balance
    initial_balance + sent_transactions.sum(:amount).to_d - received_transactions.where.not(account_id: id).sum(:amount).to_d
  end

  CURRENCY_SYMBOLS = {
    "CNY" => "¥", "USD" => "$", "EUR" => "€", "GBP" => "£",
    "JPY" => "¥", "KRW" => "₩", "HKD" => "HK$", "TWD" => "NT$"
  }

  def currency_symbol
    CURRENCY_SYMBOLS[currency] || currency
  end
end
