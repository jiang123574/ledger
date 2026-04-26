class Budget < ApplicationRecord
  include ProgressCalculable

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

    query = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
      .where(entryable_type: "Entryable::Transaction", date: start_date..end_date)
      .where(entryable_transactions: { kind: "expense" })

    if category_id.present?
      query = query.where(entryable_transactions: { category_id: category_id })
    end

    [ query.sum("entries.amount * -1"), 0 ].max
  end

  # 已废弃：使用 spent_amount（基于 Entry 模型）
  # 保留以兼容可能的外部调用，但内部统一走 spent_amount
  def spent_amount_from_transactions
    spent_amount
  end

  # ProgressCalculable 默认使用 amount 作为 total，spent_amount 作为 current
  # 以下方法由 concern 提供，不再需要重复定义：
  # - progress_percentage
  # - progress_remaining (作为 remaining_amount 的别名)
  # - progress_exceeded? (作为 overspent? 的别名)
  # - progress_near_limit? (作为 near_limit? 的别名)
  # - progress_color (作为 status_color 的基础)

  # 保留业务语义方法名（包装 concern 方法）
  def remaining_amount
    progress_remaining
  end

  def overspent?
    progress_exceeded?
  end

  def near_limit?
    progress_near_limit?
  end

  def status_color
    progress_color
  end

  def status_text
    return "已超支" if overspent?
    return "即将超支" if near_limit?
    "正常"
  end
end
