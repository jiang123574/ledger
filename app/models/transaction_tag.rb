class TransactionTag < ApplicationRecord
  belongs_to :transaction
  belongs_to :tag

  validates :transaction_id, uniqueness: { scope: :tag_id }
end
