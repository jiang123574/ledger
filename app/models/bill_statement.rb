class BillStatement < ApplicationRecord
  belongs_to :account

  validates :billing_date, presence: true
  validates :statement_amount, presence: true, numericality: { greater_than: 0, message: "必须大于0" }
  validates :billing_date, uniqueness: { scope: :account_id }
end
