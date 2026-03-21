class Counterparty < ApplicationRecord
  # Counterparties are referenced by name in receivables.counterparty string field
  # We can query receivables by name matching

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:name) }

  # Find receivables that reference this counterparty by name
  def receivables
    Receivable.where(counterparty: name)
  end

  def total_receivable_amount
    receivables.sum(:original_amount)
  end

  def pending_receivable_amount
    receivables.where(settled_at: nil).sum(:remaining_amount)
  end

  def settled_receivable_amount
    receivables.where.not(settled_at: nil).sum(:original_amount)
  end

  def receivables_count
    receivables.count
  end
end
