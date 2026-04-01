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
    kind = self.type.to_s.downcase == 'income' ? 'income' : 'expense'
    entry_amount = kind == 'income' ? amount.to_d : -amount.to_d
    
    entryable = Entryable::Transaction.new(
      kind: kind,
      category_id: category_id
    )
    entryable.save(validate: false)
    
    entry = Entry.create!(
      account_id: account_id,
      date: next_date,
      name: note || "周期交易",
      amount: entry_amount,
      currency: currency || 'CNY',
      entryable: entryable
    )
    
    update(next_date: next_execution_date)
    entry
  end
end
