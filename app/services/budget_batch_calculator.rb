# 预算批量计算服务
# 用于预算列表页面，避免 N+1 查询
#
# 使用方式：
#   budgets = Budget.for_month("2026-04")
#   spent_amounts = BudgetBatchCalculator.calculate_spent_amounts(budgets)
#   budgets.each { |b| puts spent_amounts[b.id] }

class BudgetBatchCalculator
  # 批量计算预算支出金额
  # 返回 Hash: { budget_id => spent_amount }
  def self.calculate_spent_amounts(budgets)
    return {} if budgets.empty?

    # 收集所有需要查询的月份和分类
    month_ranges = {}
    category_ids = []

    budgets.each do |budget|
      if budget.month.present?
        start_date = Date.parse("#{budget.month}-01")
        end_date = start_date.end_of_month
        month_ranges[budget.month] = [ start_date, end_date ]
      end
      category_ids << budget.category_id if budget.category_id.present?
    end

    # 单次查询获取所有支出金额
    # 按 month 和 category_id 分组
    results = {}

    month_ranges.each do |month, (start_date, end_date)|
      # 计算该月总支出（无分类限制）
      total_spent = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
        .where(entryable_type: "Entryable::Transaction", date: start_date..end_date)
        .where(entryable_transactions: { kind: "expense" })
        .sum("entries.amount * -1")
      results[month] = { total: [ total_spent.abs, 0 ].max, by_category: {} }

      # 计算该月各分类支出
      if category_ids.any?
        category_spent = Entry.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
          .where(entryable_type: "Entryable::Transaction", date: start_date..end_date)
          .where(entryable_transactions: { kind: "expense", category_id: category_ids })
          .group("entryable_transactions.category_id")
          .sum("entries.amount * -1")

        category_spent.each do |cat_id, amount|
          results[month][:by_category][cat_id] = [ amount.abs, 0 ].max
        end
      end
    end

    # 映射到每个预算
    spent_map = {}
    budgets.each do |budget|
      month_data = results[budget.month]
      if month_data
        if budget.category_id.present?
          spent_map[budget.id] = month_data[:by_category][budget.category_id] || 0
        else
          spent_map[budget.id] = month_data[:total]
        end
      else
        spent_map[budget.id] = 0
      end
    end

    spent_map
  end

  # 为预算对象设置预计算的支出金额
  # 用于视图中避免 N+1
  def self.assign_spent_amounts(budgets)
    spent_map = calculate_spent_amounts(budgets)
    budgets.each do |budget|
      budget.define_singleton_method(:spent_amount) { spent_map[id] || 0 }
    end
    budgets
  end
end
