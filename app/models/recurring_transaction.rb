class RecurringTransaction < ApplicationRecord
  self.inheritance_column = nil

  belongs_to :account, class_name: "Account"
  belongs_to :category, class_name: "Category", optional: true

  validates :amount, :frequency, :next_date, presence: true
  validates :frequency, inclusion: { in: %w[daily weekly monthly yearly] }

  scope :active, -> { where(is_active: true) }
  scope :due_today, -> { active.where("next_date <= ?", Time.current) }

  def active?
    is_active == true || is_active == 1
  end

  def next_execution_date
    case frequency
    when "daily"
      next_date + 1.day
    when "weekly"
      next_date + 1.week
    when "monthly"
      next_date + 1.month
    when "yearly"
      next_date + 1.year
    end
  end

  def create_transaction
    Transaction.create!(
      transaction_type: transaction_type,
      amount: amount,
      currency: currency,
      category: category,
      category_id: category_id,
      account_id: account_id,
      note: note,
      date: next_date
    )
    update(next_date: next_execution_date)
  end

  def type
    transaction_type
  end

  def type=(value)
    self.transaction_type = value
  end
end
