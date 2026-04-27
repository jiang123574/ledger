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

      # 批量查询所有相关分类的后代（单次 CTE）
      all_category_ids = items_data.map { |d| d[:category_id] }.uniq.compact
      category_descendants = Category.batch_descendants_map(all_category_ids)

      # 收集所有唯一的日期范围
      date_ranges = items_data.map { |d| [ d[:start_date], d[:end_date] ] }.uniq

      # 批量查询：按日期范围和分类组合查询
      # 构建一次性查询获取所有数据
      spent_amounts = {}

      date_ranges.each do |(start_date, end_date)|
        # 该日期范围内的所有相关分类
        items_in_range = items_data.select { |d| d[:start_date] == start_date && d[:end_date] == end_date }
        cat_ids_for_range = items_in_range.flat_map { |d| category_descendants[d[:category_id]] || [] }.uniq.compact

        next if cat_ids_for_range.empty?

        # 单次查询获取该日期范围内所有分类的支出
        results = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
          .where(entryable_type: "Entryable::Transaction")
          .where(entryable_transactions: { category_id: cat_ids_for_range })
          .where(date: start_date..end_date)
          .group("entryable_transactions.category_id")
          .sum("entries.amount")

        # 按 category_id 分配支出给对应的 budget_item
        items_in_range.each do |data|
          cat_ids = category_descendants[data[:category_id]] || []
          net_spent = cat_ids.sum { |cid| results[cid].abs rescue 0 }
          spent_amounts[data[:id]] = net_spent
        end
      end

      # 执行批量更新
      spent_amounts.each do |item_id, spent|
        BudgetItem.where(id: item_id).update_all(spent_amount: spent)
      end
    end
  end
end
