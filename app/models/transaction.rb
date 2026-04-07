class Transaction < ApplicationRecord
  self.inheritance_column = nil

  TYPES = %w[INCOME EXPENSE TRANSFER ADVANCE REIMBURSE].freeze

  belongs_to :account, class_name: "Account", optional: true
  belongs_to :target_account, class_name: "Account", foreign_key: "target_account_id", optional: true
  belongs_to :category, class_name: "Category", optional: true
  belongs_to :receivable, optional: true
  belongs_to :payable, optional: true
  belongs_to :link, class_name: "Transaction", optional: true
  has_many :attachments, dependent: :destroy
  has_many :transaction_tags, dependent: :destroy
  has_many :tags, through: :transaction_tags

  has_many_attached :files

  after_commit :update_account_cache

  validates :type, presence: true, inclusion: { in: TYPES }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true
  validates :currency, presence: true, length: { is: 3 }
  validates :target_account, presence: true, if: :transfer?
  validates :account, presence: true, unless: :transfer?

  store_accessor :extra, :provider_data, :sync_status, :enrichment_data
  store_accessor :locked_attributes, :amount_locked, :category_locked, :date_locked

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
  scope :advances, -> { where(type: "ADVANCE") }
  scope :reimburses, -> { where(type: "REIMBURSE") }

  scope :for_month, ->(month) {
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month
    where(date: start_date..end_date)
  }

  scope :for_year, ->(year) {
    start_date = Date.new(year, 1, 1)
    end_date = start_date.end_of_year
    where(date: start_date..end_date)
  }

  scope :recent, ->(limit = 10) { order(date: :desc).limit(limit) }
  scope :chronological, -> { order(date: :asc, sort_order: :asc, id: :asc) }
  scope :reverse_chronological, -> { order(date: :desc, sort_order: :desc, id: :desc) }

  scope :visible, -> { joins(:account).where(accounts: { hidden: false }) }
  scope :included_in_total, -> { joins(:account).where(accounts: { include_in_total: true }) }

  scope :with_amount, -> { where.not(amount: nil) }
  scope :with_category, -> { where.not(category_id: nil) }
  scope :without_category, -> { where(category_id: nil) }

  scope :inflow, -> { where(type: [ "INCOME", "REIMBURSE" ]) }
  scope :outflow, -> { where(type: [ "EXPENSE", "ADVANCE" ]) }

  scope :by_period, ->(period_type, period_value) {
    case period_type
    when "all" then all
    when "year" then for_year(period_value.to_i)
    when "week"
      if (m = period_value.match(/\A(\d{4})-W(\d{2})\z/))
        year = m[1].to_i
        week = m[2].to_i
        start_date = Date.commercial(year, week, 1)
        where(date: start_date..(start_date + 6.days))
      else
        all
      end
    else
      if period_value.match?(/\A\d{4}-\d{2}\z/)
        for_month(period_value)
      else
        all
      end
    end
  }

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
    TransactionTypeDisplay.label(type)
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
  class << self
    # 统计方法 - 单次查询获取所有统计数据
    def stats_for_account(account_id, period_type: "month", period_value: nil)
      period_value ||= default_period_value(period_type)

      query = where(
        "account_id = ? OR (type = 'TRANSFER' AND target_account_id = ?)",
        account_id, account_id
      ).by_period(period_type, period_value)

      result = query.select(
        "SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as total_income",
        "SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as total_expense",
        "SUM(CASE WHEN type = 'ADVANCE' THEN amount ELSE 0 END) as total_advance",
        "SUM(CASE WHEN type = 'REIMBURSE' THEN amount ELSE 0 END) as total_reimburse",
        "COUNT(CASE WHEN type IN ('INCOME', 'EXPENSE', 'ADVANCE', 'REIMBURSE') THEN 1 END) as count",
        "COUNT(DISTINCT date) as days"
      ).to_a.first

      {
        income: result&.total_income || 0,
        expense: result&.total_expense || 0,
        advance: result&.total_advance || 0,
        reimburse: result&.total_reimburse || 0,
        count: result&.count || 0,
        days: result&.days || 0
      }
    end

    # 批量查询优化 - 一次性获取多个账户的统计
    def batch_stats_for_accounts(account_ids, period_type: "month", period_value: nil)
      period_value ||= default_period_value(period_type)

      where(account_id: account_ids)
        .by_period(period_type, period_value)
        .group(:account_id)
        .select(
          "account_id",
          "SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as total_income",
          "SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as total_expense"
        )
        .each_with_object({}) do |record, hash|
          hash[record.account_id] = {
            income: record.total_income,
            expense: record.total_expense
          }
        end
    end

    # 按分类统计
    def by_category_stats(account_id: nil, period_type: "month", period_value: nil)
      period_value ||= default_period_value(period_type)

      query = where.not(category_id: nil).by_period(period_type, period_value)
      query = query.where(account_id: account_id) if account_id.present?

      query.joins(:category)
           .group("categories.name", "categories.id")
           .order("SUM(amount) DESC")
           .select(
             "categories.id as category_id",
             "categories.name as category_name",
             "SUM(amount) as total_amount",
             "COUNT(*) as count"
           )
    end

    # 按日期统计
    def by_date_stats(account_id: nil, period_type: "month", period_value: nil)
      period_value ||= default_period_value(period_type)

      query = by_period(period_type, period_value)
      query = query.where(account_id: account_id) if account_id.present?

      query.group(:date)
           .order(:date)
           .select(
             "date",
             "SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as income",
             "SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as expense"
           )
    end

    # 查找重复交易
    def find_duplicates(account_id: nil, days: 30)
      query = where("date >= ?", days.days.ago)
      query = query.where(account_id: account_id) if account_id.present?

      query.group(:account_id, :date, :amount, :type)
           .having("COUNT(*) > 1")
           .select("account_id, date, amount, type, COUNT(*) as duplicate_count")
    end

    private

      def default_period_value(period_type)
        case period_type
        when "year" then Date.current.year.to_s
        when "week" then Date.current.strftime("%G-W%V")
        else Date.current.strftime("%Y-%m")
        end
      end
  end

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

  def self.create_transfer!(from_account:, to_account:, amount:, date:, note: nil)
    create!(
      type: "TRANSFER",
      account: from_account,
      target_account: to_account,
      amount: amount,
      date: date,
      note: note
    )
  end

  def lock_attribute!(attr_name)
    self.locked_attributes ||= {}
    self.locked_attributes[attr_name] = Time.current.iso8601
    save!
  end

  def locked?(attr_name)
    locked_attributes&.dig(attr_name).present?
  end

  def mark_user_modified!
    update!(user_modified: true)
  end

  def protected_from_sync?
    user_modified? || locked_attributes&.any?
  end

  private

  def update_account_cache
    account&.update_transactions_cache!
    target_account&.update_transactions_cache!
  end
end
