class Receivable < ApplicationRecord
  belongs_to :source_transaction, class_name: "Transaction", foreign_key: "source_transaction_id", optional: true
  belongs_to :counterparty, optional: true
  belongs_to :account, optional: true
  has_many :reimbursement_transactions, class_name: "Transaction", foreign_key: "receivable_id", dependent: :nullify

  validates :description, presence: true
  validates :original_amount, presence: true, numericality: { greater_than: 0 }
  validates :remaining_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :date, presence: true

  scope :unsettled, -> { where(settled_at: nil).where("remaining_amount > 0") }
  scope :settled, -> { where.not(settled_at: nil) }
  scope :recent, -> { order(date: :desc) }
  scope :by_category, ->(category) { where(category: category) if category.present? }

  CATEGORIES = %w[差旅 餐饮 交通 办公用品 其他].freeze

  def settled?
    settled_at.present? || remaining_amount.to_d <= 0
  end

  def progress_percentage
    return 0 if original_amount.to_d <= 0
    ((original_amount - remaining_amount) / original_amount * 100).round
  end

  def status
    return "已完成" if settled?
    remaining_amount < original_amount ? "部分报销" : "待报销"
  end

  def status_color
    case status
    when "已完成" then "green"
    when "部分报销" then "orange"
    else "gray"
    end
  end
end
