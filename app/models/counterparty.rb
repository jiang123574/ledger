class Counterparty < ApplicationRecord
  # Support both current FK relation (counterparty_id) and legacy name field (counterparty)

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:name) }

  def receivables
    Receivable.where(counterparty_id: id).or(Receivable.where(counterparty: name))
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
