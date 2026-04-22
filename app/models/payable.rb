class Payable < ApplicationRecord
  serialize :settlement_transfer_ids, coder: YAML

  def settlement_transfer_ids
    super || []
  end

  belongs_to :source_entry, class_name: "Entry", foreign_key: "source_entry_id", optional: true

  belongs_to :counterparty, optional: true
  belongs_to :account, optional: true

  validates :description, presence: true
  validates :original_amount, presence: true, numericality: { greater_than: 0 }
  validates :remaining_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :date, presence: true

  validates :transfer_id, format: { with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i }, allow_nil: true

  scope :unsettled, -> { where(settled_at: nil).where("remaining_amount > 0") }
  scope :settled, -> { where.not(settled_at: nil) }
  scope :recent, -> { order(date: :desc) }
  scope :by_category, ->(category) { where(category: category) if category.present? }

  CATEGORIES = %w[日常支出 房租 水电 网费 保险 医疗 教育 税费 其他].freeze

  after_commit :sync_system_accounts

  # 获取源交易的金额
  def source_amount
    source_entry&.amount || original_amount
  end

  # 获取源交易的日期
  def source_date
    source_entry&.date || date
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
    remaining_amount < original_amount ? "部分付款" : "待付款"
  end

  def status_color
    case status
    when "已完成" then "green"
    when "部分付款" then "orange"
    else "gray"
    end
  end

  private

  def sync_system_accounts
    SystemAccountSyncService.sync_all!
  end
end
