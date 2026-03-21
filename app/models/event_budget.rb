class EventBudget < ApplicationRecord
  STATUSES = %w[active completed cancelled].freeze

  has_many :event_budget_transactions, dependent: :destroy
  has_many :transactions, through: :event_budget_transactions

  validates :name, presence: true, length: { maximum: 100 }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :spent_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :start_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :by_status, ->(status) { where(status: status) if status.present? }

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
    "blue"
  end

  def status_text
    return "已超支" if overspent?
    return "即将超支" if near_limit?
    case status
    when "active" then "进行中"
    when "completed" then "已完成"
    when "cancelled" then "已取消"
    else status
    end
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

  def completed!
    update(status: "completed")
  end

  def cancelled!
    update(status: "cancelled")
  end

  def recalculate_spent_amount
    update(spent_amount: transactions.where(type: "EXPENSE").sum(:amount))
  end

  def add_transaction(transaction)
    return false unless transaction.is_a?(Transaction)
    return false if transactions.include?(transaction)

    event_budget_transactions.create!(transaction: transaction)
    recalculate_spent_amount
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end

  def remove_transaction(transaction)
    event_budget_transactions.where(transaction: transaction).destroy_all
    recalculate_spent_amount
  end

  def days_remaining
    return nil unless end_date.present? && active?

    (end_date - Date.current).to_i
  end

  def days_elapsed
    (Date.current - start_date).to_i
  end

  def duration_days
    return nil unless end_date.present?
    (end_date - start_date).to_i + 1
  end

  def progress_by_time
    return 0 unless end_date.present? && start_date.present?

    total_days = duration_days
    return 100 if total_days.nil? || total_days <= 0

    [(days_elapsed.to_f / total_days * 100).round(1), 100].min
  end
end
