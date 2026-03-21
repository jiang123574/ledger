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

  # 计算已使用金额
  def spent_amount
    return 0 unless month.present?

    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    query = Transaction.where(type: "EXPENSE", date: start_date..end_date)
    query = query.where(category_id: category_id) if category_id.present?

    query.sum(:amount)
  end

  # 计算进度百分比
  def progress_percentage
    return 0 if amount.to_d <= 0
    (spent_amount.to_d / amount.to_d * 100).round(1)
  end

  # 计算剩余金额
  def remaining_amount
    amount.to_d - spent_amount.to_d
  end

  # 是否超支
  def overspent?
    remaining_amount < 0
  end

  # 是否接近预算（超过80%）
  def near_limit?
    progress_percentage >= 80 && progress_percentage < 100
  end

  # 状态颜色
  def status_color
    return "red" if overspent?
    return "yellow" if near_limit?
    "blue"
  end

  # 状态文本
  def status_text
    return "已超支" if overspent?
    return "即将超支" if near_limit?
    "正常"
  end
end
