class Transaction < ApplicationRecord
  self.inheritance_column = nil

  # ============ 交易类型常量 ============
  TYPES = %w[INCOME EXPENSE TRANSFER ADVANCE REIMBURSE].freeze

  # 类型枚举说明:
  # INCOME: 收入
  # EXPENSE: 支出
  # TRANSFER: 转账 (账户间)
  # ADVANCE: 预支 (待报销)
  # REIMBURSE: 报销

  belongs_to :account, class_name: "Account", optional: true
  belongs_to :target_account, class_name: "Account", foreign_key: "target_account_id", optional: true
  belongs_to :category, class_name: "Category", optional: true
  belongs_to :receivable, optional: true
  belongs_to :link, class_name: "Transaction", optional: true
  has_many :attachments, dependent: :destroy
  has_many :transaction_tags, dependent: :destroy
  has_many :tags, through: :transaction_tags

  # Active Storage 附件
  has_many_attached :files

  validates :type, presence: true, inclusion: { in: TYPES }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true
  validates :currency, presence: true, length: { is: 3 }

  # 转账交易必须指定目标账户
  validates :target_account, presence: true, if: :transfer?
  validates :account, presence: true, unless: :transfer?

  # ============ Scopes ============
  scope :by_date, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_type, ->(type) { where(type: type) if type.present? }
  scope :by_account, ->(account_id) { where(account_id: account_id) if account_id.present? }
  scope :by_category, ->(category_id) { where(category_id: category_id) if category_id.present? }
  scope :by_tag, ->(tag_id) { joins(:transaction_tags).where(transaction_tags: { tag_id: tag_id }) if tag_id.present? }
  scope :by_amount_range, ->(min, max) { where(amount: min..max) if min.present? && max.present? }

  scope :income, -> { where(type: "INCOME") }
  scope :expense, -> { where(type: "EXPENSE") }
  scope :transfers, -> { where(type: "TRANSFER") }
  scope :for_month, ->(month) {
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month
    where(date: start_date..end_date)
  }
  scope :recent, ->(limit = 10) { order(date: :desc).limit(limit) }
  scope :chronological, -> { order(date: :asc, sort_order: :asc) }
  scope :reverse_chronological, -> { order(date: :desc, sort_order: :desc) }

  # ============ 类型判断方法 ============
  def transfer?
    type == "TRANSFER"
  end

  def income?
    type == "INCOME"
  end

  def expense?
    type == "EXPENSE"
  end

  def advance?
    type == "ADVANCE"
  end

  def reimburse?
    type == "REIMBURSE"
  end

  # 是否影响预算统计 (转账不影响)
  def affects_budget?
    !transfer?
  end

  # ============ 显示方法 ============
  def currency_symbol
    Currency.symbol(currency) || account&.currency_symbol || "¥"
  end

  def account_name
    account&.name || "未知账户"
  end

  def target_account_name
    target_account&.name
  end

  def display_amount
    prefix = income? ? "+" : "-"
    "#{prefix}#{currency_symbol}#{amount.to_s('F')}"
  end

  def display_type
    {
      "INCOME" => "收入",
      "EXPENSE" => "支出",
      "TRANSFER" => "转账",
      "ADVANCE" => "预支",
      "REIMBURSE" => "报销"
    }[type] || type
  end

  # 获取原始金额（如果有）
  def original_amount_value
    original_amount || amount
  end

  # 转换到默认货币金额
  def amount_in_default_currency
    return amount if currency == Currency.default&.code
    Currency.convert(amount, currency, Currency.default&.code)
  end

  # 转换到指定货币金额
  def amount_in_currency(target_currency)
    return amount if currency == target_currency
    Currency.convert(amount, currency, target_currency)
  end

  def tag_list=(tag_ids)
    self.tag_ids = tag_ids.reject(&:blank?).map(&:to_i)
  end

  def tag_list
    tags.pluck(:id)
  end

  def tag_names
    tags.pluck(:name)
  end

  # ============ 类方法 ============
  def self.monthly_stats(month)
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    transactions = where(date: start_date..end_date).where.not(type: "TRANSFER")
    {
      income: transactions.income.sum(:amount),
      expense: transactions.expense.sum(:amount),
      balance: transactions.income.sum(:amount) - transactions.expense.sum(:amount),
      count: transactions.count
    }
  end

  def self.by_category(month, transaction_type = "EXPENSE")
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    where(type: transaction_type, date: start_date..end_date)
      .joins(:category)
      .group("categories.name")
      .order(Arel.sql("SUM(amount) DESC"))
      .sum(:amount)
  end

  # 创建转账交易 (同时创建两条关联记录)
  # 创建转账交易（只创建一条记录）
  # 转出账户余额减少，转入账户余额增加
  # 账户余额计算逻辑：sent_transfers 减少余额，received_transfers 增加余额
  def self.create_transfer!(from_account:, to_account:, amount:, date:, note: nil)
    create!(
      type: "TRANSFER",
      account: from_account,        # 转出账户
      target_account: to_account,   # 转入账户
      amount: amount,
      date: date,
      note: note
    )
  end
end
