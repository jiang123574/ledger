class BudgetItem < ApplicationRecord
  belongs_to :single_budget

  validates :name, presence: true, length: { maximum: 100 }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :spent_amount, numericality: { greater_than_or_equal_to: 0 }

  scope :by_category, ->(category) { where(category: category) if category.present? }

  def remaining_amount
    amount.to_d - spent_amount.to_d
  end

  def progress_percentage
    return 0 if amount.to_d <= 0
    (spent_amount.to_d / amount.to_d * 100).round(1)
  end

  def overspent?
    remaining_amount < 0
  end
end
