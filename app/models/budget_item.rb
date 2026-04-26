class BudgetItem < ApplicationRecord
  belongs_to :single_budget, counter_cache: true
  belongs_to :category, class_name: "Category", optional: true

  validates :name, length: { maximum: 100 }, allow_nil: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :spent_amount, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_name_from_category

  scope :by_category, ->(category) { where(category: category) if category.present? }

  def set_name_from_category
    self.name = category&.full_name if category && name.blank?
  end

  def display_name
    category&.full_name || name || "未分类"
  end

  def remaining_amount
    amount.to_d - spent_amount.to_d
  end

  def progress_percentage
    return 0 if amount.to_d <= 0
    (spent_amount.to_d / amount.to_d * 100).round(1)
  end

  def overspent?
    remaining_amount < 0
  end

  def recalculate_spent_amount
    return spent_amount unless category && single_budget.start_date

    start_date = single_budget.start_date
    end_date = single_budget.end_date || Date.current

    category_ids = Category.descendant_ids_for([ category.id ]) | [ category.id ]

    net_spent = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
      .where(entryable_type: "Entryable::Transaction")
      .where(entryable_transactions: { category_id: category_ids })
      .where(date: start_date..end_date)
      .sum("entries.amount")
      .abs

    update(spent_amount: net_spent)
  end

  class << self
    def refresh_for_category(category_id)
      return if category_id.blank?

      all_related_ids = ([ category_id ] + Category.ancestor_ids_for([ category_id ]) + Category.descendant_ids_for([ category_id ])).uniq

      affected_items = BudgetItem.joins(:single_budget)
        .where(category_id: all_related_ids)
        .where(single_budgets: { status: %w[active planning] })

      # 批量计算并更新，避免逐条 N+1
      batch_update_spent_amounts(affected_items)

      affected_single_budget_ids = affected_items.pluck(:single_budget_id).uniq
      SingleBudget.where(id: affected_single_budget_ids).each(&:recalculate_spent_amount)

      CacheBuster.bump(:budgets)
    end

    private

    # 批量更新支出金额
    def batch_update_spent_amounts(items)
      return if items.empty?

      # 收集所有需要的参数
      items_data = items.map do |item|
        {
          id: item.id,
          category_id: item.category_id,
          start_date: item.single_budget.start_date,
          end_date: item.single_budget.end_date || Date.current
        }
      end

      # 批量查询所有相关分类的后代
      all_category_ids = items_data.map { |d| d[:category_id] }.uniq.compact
      category_descendants = {}
      all_category_ids.each do |cat_id|
        category_descendants[cat_id] = Category.descendant_ids_for([ cat_id ]) | [ cat_id ]
      end

      # 批量查询所有时间范围内的支出
      # 按 category_id 和时间范围分组
      all_start_dates = items_data.map { |d| d[:start_date] }.uniq
      all_end_dates = items_data.map { |d| d[:end_date] }.uniq

      # 执行单次大查询，获取所有需要的数据
      spent_amounts = {}
      items_data.each do |data|
        cat_ids = category_descendants[data[:category_id]] || []
        next if cat_ids.empty?

        # 使用单次查询计算
        net_spent = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
          .where(entryable_type: "Entryable::Transaction")
          .where(entryable_transactions: { category_id: cat_ids })
          .where(date: data[:start_date]..data[:end_date])
          .sum("entries.amount")
          .abs

        spent_amounts[data[:id]] = net_spent
      end

      # 执行批量更新
      spent_amounts.each do |item_id, spent|
        BudgetItem.where(id: item_id).update_all(spent_amount: spent)
      end
    end
  end
end
