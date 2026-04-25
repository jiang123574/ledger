class BudgetItem < ApplicationRecord
  belongs_to :single_budget, counter_cache: true
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

    category_ids = Category.descendant_ids_for([ category.id ])
    category_ids << category.id

    net_spent = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
      .where(entryable_type: "Entryable::Transaction")
      .where(entryable_transactions: { category_id: category_ids })
      .where(date: start_date..end_date)
      .sum("entries.amount")
      .abs

    update(spent_amount: net_spent)
  end

  class << self
    def refresh_for_category(category_id)
      return if category_id.blank?

      all_related_ids = [ category_id ] + Category.ancestor_ids_for([ category_id ]) + Category.descendant_ids_for([ category_id ])

      affected_items = BudgetItem.joins(:single_budget)
        .where(category_id: all_related_ids)
        .where(single_budgets: { status: %w[active planning] })

      affected_items.each(&:recalculate_spent_amount)

      affected_single_budget_ids = affected_items.pluck(:single_budget_id).uniq
      SingleBudget.where(id: affected_single_budget_ids).each(&:recalculate_spent_amount)

      CacheBuster.bump(:budgets)
    end
  end
end
