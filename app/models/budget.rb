class Budget < ApplicationRecord
  include ProgressCalculable

  belongs_to :category, class_name: "Category", optional: true

  validates :month, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :for_month, ->(month) { where(month: month) }
  scope :for_category, ->(category_id) { where(category_id: category_id) }
  scope :total_budgets, -> { where(category_id: nil) }
  scope :category_budgets, -> { where.not(category_id: nil) }

  # 批量预加载 spent_amount，消除 N+1 查询
  # 用法: Budget.preload_spent_amounts(budgets) 在 Controller 中调用
  def self.preload_spent_amounts(budgets)
    return {} if budgets.empty?

    month = budgets.first.month
    return {} unless month.present?

    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    # 获取所有 category_ids（排除 nil）
    category_ids = budgets.map(&:category_id).compact.uniq

    # 一次查询计算所有分类的支出
    category_spends = {}
    if category_ids.any?
      results = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
        .where(entryable_type: "Entryable::Transaction", date: start_date..end_date)
        .where(entryable_transactions: { kind: "expense", category_id: category_ids })
        .where(transfer_id: nil)
        .group("entryable_transactions.category_id")
        .sum("entries.amount * -1")

      category_spends = results.transform_values { |v| [ v, 0 ].max }
    end

    # 计算总支出（用于 total_budget）
    total_spent = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
      .where(entryable_type: "Entryable::Transaction", date: start_date..end_date)
      .where(entryable_transactions: { kind: "expense" })
      .where(transfer_id: nil)
      .sum("entries.amount * -1")
    total_spent = [ total_spent, 0 ].max

    # 构建缓存
    cache = { category_spends: category_spends, total_spent: total_spent }

    # 注入到每个 budget 实例
    budgets.each do |budget|
      budget.instance_variable_set(:@spent_amount_cache, cache)
    end

    cache
  end

  def total_budget?
    category_id.nil?
  end

  def spent_amount
    # 如果有预加载缓存，优先使用
    if @spent_amount_cache
      if category_id.present?
        @spent_amount_cache[:category_spends][category_id] || 0
      else
        @spent_amount_cache[:total_spent]
      end
    else
      # 没有缓存时，执行独立查询（兼容旧代码）
      compute_spent_amount
    end
  end

  # 已废弃：使用 spent_amount（基于 Entry 模型）
  # 保留以兼容可能的外部调用，但内部统一走 spent_amount
  def spent_amount_from_transactions
    spent_amount
  end

  # ProgressCalculable 默认使用 amount 作为 total，spent_amount 作为 current
  # 以下方法由 concern 提供，不再需要重复定义：
  # - progress_percentage
  # - progress_remaining (作为 remaining_amount 的别名)
  # - progress_exceeded? (作为 overspent? 的别名)
  # - progress_near_limit? (作为 near_limit? 的别名)
  # - progress_color (作为 status_color 的基础)

  # 保留业务语义方法名（包装 concern 方法）
  def remaining_amount
    progress_remaining
  end

  def overspent?
    progress_exceeded?
  end

  def near_limit?
    progress_near_limit?
  end

  def status_color
    progress_color
  end

  def status_text
    return "已超支" if overspent?
    return "即将超支" if near_limit?
    "正常"
  end

  private

  def compute_spent_amount
    return 0 unless month.present?

    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    query = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
      .where(entryable_type: "Entryable::Transaction", date: start_date..end_date)
      .where(entryable_transactions: { kind: "expense" })
      .where(transfer_id: nil)

    if category_id.present?
      query = query.where(entryable_transactions: { category_id: category_id })
    end

    [ query.sum("entries.amount * -1"), 0 ].max
  end
end
