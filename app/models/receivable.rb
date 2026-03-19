class Receivable < ApplicationRecord
  belongs_to :source_transaction, class_name: "Transaction", foreign_key: "source_transaction_id", optional: true
  has_many :reimbursement_transactions, class_name: "Transaction", dependent: :nullify

  validates :original_amount, :remaining_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :unsettled, -> { where(settled_at: nil).where("remaining_amount > 0") }

  def settled?
    settled_at.present? || remaining_amount.to_d <= 0
  end
end
