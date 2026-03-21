class Counterparty < ApplicationRecord
  has_many :receivables, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :with_receivables, -> { joins(:receivables).distinct }
  scope :ordered, -> { order(:name) }

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
