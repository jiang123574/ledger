class BudgetItem < ApplicationRecord
  belongs_to :single_budget
  belongs_to :category, class_name: "Category", optional: true

  validates :name, length: { maximum: 100 }, allow_nil: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :spent_amount, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_name_from_category

  scope :by_category, ->(category) { where(category: category) if category.present? }

  def set_name_from_category
    self.name = category&.full_name if category && name.blank?
  end

  def display_name
    category&.full_name || name || "未分类"
  end

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

  def recalculate_spent_amount
    return spent_amount unless category && single_budget.start_date

    start_date = single_budget.start_date
    end_date = single_budget.end_date || Date.current

    category_ids = category.self_and_descendants.map(&:id)

    spent = Entry.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
      .where(entryable_type: 'Entryable::Transaction')
      .where(entryable_transactions: { category_id: category_ids })
      .where(date: start_date..end_date)
      .sum('ABS(entries.amount)')

    update(spent_amount: spent)
  end
end
