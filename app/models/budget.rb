class Budget < ApplicationRecord
  belongs_to :category, class_name: "Category", optional: true

  validates :month, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :for_month, ->(month) { where(month: month) }
  scope :for_category, ->(category_id) { where(category_id: category_id) }
  scope :total_budgets, -> { where(category_id: nil) }
  scope :category_budgets, -> { where.not(category_id: nil) }

  def total_budget?
    category_id.nil?
  end

  def spent_amount
    return 0 unless month.present?

    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    query = Entry.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
      .where(entryable_type: 'Entryable::Transaction', date: start_date..end_date)
      .where(entryable_transactions: { kind: 'expense' })
    
    if category_id.present?
      query = query.where(entryable_transactions: { category_id: category_id })
    end

    query.sum('ABS(entries.amount)')
  end

  def spent_amount_from_transactions
    return 0 unless month.present?

    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    query = Transaction.where(type: "EXPENSE", date: start_date..end_date)
    query = query.where(category_id: category_id) if category_id.present?

    query.sum(:amount)
  end

  def progress_percentage
    return 0 if amount.to_d <= 0
    (spent_amount.to_d / amount.to_d * 100).round(1)
  end

  def remaining_amount
    amount.to_d - spent_amount.to_d
  end

  def overspent?
    remaining_amount < 0
  end

  def near_limit?
    progress_percentage >= 80 && progress_percentage < 100
  end

  def status_color
    return "red" if overspent?
    return "yellow" if near_limit?
    "blue"
  end

  def status_text
    return "已超支" if overspent?
    return "即将超支" if near_limit?
    "正常"
  end
end
