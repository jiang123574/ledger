class BillStatement < ApplicationRecord
  belongs_to :account

  validates :billing_date, presence: true
  validates :statement_amount, presence: true
  validates :billing_date, uniqueness: { scope: :account_id }
end
