class Tag < ApplicationRecord
  has_and_belongs_to_many :transaction_tags, class_name: "Transaction", join_table: "transaction_tags"

  validates :name, presence: true, uniqueness: true

  before_validation :set_default_color, on: :create

  def transactions
    Transaction.joins(:tags).where(tags: { id: id })
  end

  private

  def set_default_color
    self.color ||= "#3498db"
  end
end
