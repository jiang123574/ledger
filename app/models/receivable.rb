class Receivable < ApplicationRecord
  # Entry 关系（新）
  belongs_to :source_entry, class_name: "Entry", foreign_key: "source_entry_id", optional: true

  # 遗留关系（保持向后兼容）
  belongs_to :source_transaction, class_name: "Transaction", foreign_key: "source_transaction_id", optional: true
  has_many :reimbursement_transactions, class_name: "Transaction", foreign_key: "receivable_id", dependent: :nullify

  # 其他关系
  belongs_to :counterparty, optional: true
  belongs_to :account, optional: true

  validates :description, presence: true
  validates :original_amount, presence: true, numericality: { greater_than: 0 }
  validates :remaining_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :date, presence: true

  scope :unsettled, -> { where(settled_at: nil).where("remaining_amount > 0") }
  scope :settled, -> { where.not(settled_at: nil) }
  scope :recent, -> { order(date: :desc) }
  scope :by_category, ->(category) { where(category: category) if category.present? }

  CATEGORIES = %w[差旅 餐饮 交通 办公用品 其他].freeze

  after_commit :sync_system_accounts

  # P3 迁移兼容性方法
  # 返回源交易（优先使用 Entry，回退到旧 Transaction）
  def source_transaction_or_entry
    source_entry || source_transaction
  end

  # 获取源交易的金额
  def source_amount
    source_entry&.amount || source_transaction&.amount || original_amount
  end

  # 获取源交易的日期
  def source_date
    source_entry&.date || source_transaction&.date || date
  end

  # 自动同步 source_entry_id（从 source_transaction_id 如果需要）
  def ensure_entry_reference
    return if source_entry_id.present?
    return if source_transaction_id.nil?

    entry = find_entry_for_transaction(source_transaction_id)
    self.update_column(:source_entry_id, entry.id) if entry.present?
  end

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

  private

  def find_entry_for_transaction(transaction_id)
    return nil if transaction_id.nil?

    Entry
      .joins("INNER JOIN entryable_transactions ON entryable_transactions.id = entries.entryable_id")
      .where(entryable_type: "Entryable::Transaction")
      .where(entryable_transactions: { source_transaction_id: transaction_id })
      .first
  end

  def sync_system_accounts
    SystemAccountSyncService.sync_all!
  end
end
