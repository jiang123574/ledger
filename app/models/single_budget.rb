class SingleBudget < ApplicationRecord
  STATUSES = %w[planning active completed cancelled].freeze

  has_many :budget_items, dependent: :destroy
  belongs_to :category, class_name: "Category", optional: true

  validates :name, presence: true, length: { maximum: 100 }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :spent_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :start_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :planning, -> { where(status: "planning") }
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :cancelled, -> { where(status: "cancelled") }

  def recalculate_spent_amount
    if category && start_date && end_date
      category_ids = category.self_and_descendants.select(:id)
      end_date_val = end_date || start_date
      transactions = Transaction.where(category_id: category_ids)
                                 .where("date >= ? AND date <= ?", start_date, end_date_val)
      update(spent_amount: transactions.sum(:amount))
    else
      update(spent_amount: budget_items.sum(:spent_amount))
    end
  end

  def remaining_amount
    total_amount.to_d - spent_amount.to_d
  end

  def progress_percentage
    return 0 if total_amount.to_d <= 0
    (spent_amount.to_d / total_amount.to_d * 100).round(1)
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
    case status
    when "planning" then "gray"
    when "active" then "blue"
    when "completed" then "green"
    when "cancelled" then "gray"
    else "gray"
    end
  end

  def status_text
    case status
    when "planning" then "规划中"
    when "active" then "进行中"
    when "completed" then "已完成"
    when "cancelled" then "已取消"
    else status
    end
  end

  def planning?
    status == "planning"
  end

  def active?
    status == "active"
  end

  def completed?
    status == "completed"
  end

  def cancelled?
    status == "cancelled"
  end

  def start!
    update(status: "active")
  end

  def complete!
    update(status: "completed")
  end

  def cancel!
    update(status: "cancelled")
  end
end
