# ReportGenerationService - 报表数据计算服务
# 从 ReportsController 提取报表生成逻辑
#
# 使用方式:
#   service = ReportGenerationService.new(
#     start_date: @start_date,
#     end_date: @end_date,
#     report_type: :yearly,
#     categories: @categories
#   )
#   data = service.generate
class ReportGenerationService
  attr_reader :start_date, :end_date, :report_type, :categories

  def initialize(start_date:, end_date:, report_type:, categories: [])
    @start_date = start_date
    @end_date = end_date
    @report_type = report_type
    @categories = categories
  end

  # 生成完整的报表数据
  def generate
    data = base_statistics

    data[:monthly_trend] = compute_monthly_trend
    data[:expense_by_category] = compute_category_stats("expense")
    data[:income_by_category] = compute_category_stats("income")

    if report_type == :yearly
      balance_data = compute_account_balance_data
      data[:asset_trend] = compute_asset_trend(balance_data)
      data[:waterfall_data] = compute_waterfall_data(balance_data)
      data[:category_monthly_comparison] = compute_category_monthly_comparison
      data[:sankey_data] = compute_sankey_data(data[:total_income], data[:total_expense])
      data[:calendar_heatmap_data] = compute_calendar_heatmap_data
    end

    if report_type == :monthly
      data[:budget_progress] = compute_budget_data
    end

    data[:filter_categories] = compute_filter_categories
    data
  end

  private

  # 基础统计：总收入、总支出、净余额
  def base_statistics
    entries = Entry.where(date: start_date..end_date, entryable_type: "Entryable::Transaction")
      .where("transfer_id IS NULL")

    total_income = entries.with_entryable_transaction
      .where(entryable_transactions: { kind: "income" }).sum(:amount)
    total_expense = entries.with_entryable_transaction
      .where(entryable_transactions: { kind: "expense" }).sum("entries.amount * -1")

    {
      total_income: total_income,
      total_expense: total_expense,
      net_balance: total_income - total_expense
    }
  end

  # 月度趋势计算
  def compute_monthly_trend
    if report_type == :yearly
      compute_yearly_trend
    else
      compute_monthly_trend_for_month
    end
  end

  def compute_yearly_trend
    stats = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(date: start_date..end_date)
      .group("date_trunc('month', entries.date)", "entryable_transactions.kind")
      .select("date_trunc('month', entries.date) as month_date, entryable_transactions.kind as kind, SUM(CASE WHEN entryable_transactions.kind = 'expense' THEN entries.amount * -1 ELSE entries.amount END) as total")
      .map { |r| { month: r.month_date.month, kind: r.kind, amount: r.total.to_f } }

    stats_by_month = stats.group_by { |s| s[:month] }
    (1..12).map do |month|
      month_data = stats_by_month[month] || []
      income = month_data.find { |s| s[:kind] == "income" }&.dig(:amount) || 0
      expense = month_data.find { |s| s[:kind] == "expense" }&.dig(:amount) || 0
      {
        month: month,
        label: "#{month}月",
        income: income,
        expense: expense
      }
    end
  end

  def compute_monthly_trend_for_month
    stats = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(date: start_date..end_date)
      .group("date_trunc('week', entries.date)", "entryable_transactions.kind")
      .select("date_trunc('week', entries.date) as week_date, entryable_transactions.kind as kind, SUM(CASE WHEN entryable_transactions.kind = 'expense' THEN entries.amount * -1 ELSE entries.amount END) as total")
      .map { |r| { week: r.week_date.to_date, kind: r.kind, amount: r.total.to_f } }

    stats_by_week = stats.group_by { |s| s[:week] }
    weeks = []
    current = start_date
    week_num = 1

    while current <= end_date
      week_end = [ current.end_of_week, end_date ].min
      week_data = stats_by_week[current] || []
      income = week_data.find { |s| s[:kind] == "income" }&.dig(:amount) || 0
      expense = week_data.find { |s| s[:kind] == "expense" }&.dig(:amount) || 0

      weeks << {
        week: week_num,
        label: "第#{week_num}周",
        income: income,
        expense: expense
      }

      current = week_end + 1.day
      week_num += 1
    end

    weeks
  end

  # 分类统计
  def compute_category_stats(kind)
    entries = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(date: start_date..end_date)
      .where(entryable_transactions: { kind: kind })

    if kind == "expense"
      entries = entries.where("entries.amount < 0")
    end

    entries.joins(:category)
      .group("categories.id", "categories.name")
      .order("SUM(ABS(entries.amount)) DESC")
      .limit(15)
      .pluck("categories.id", "categories.name", "SUM(ABS(entries.amount))")
      .map { |cat_id, cat_name, amount| [ [ cat_id, cat_name ], amount ] }
  end

  # 预算进度（月报）
  def compute_budget_data
    budgets = Budget.for_month("#{start_date.year}-#{start_date.month.to_s.rjust(2, '0')}")
    return [] if budgets.empty?

    category_ids = budgets.pluck(:category_id)
    spent_by_category = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: "expense", category_id: category_ids })
      .where(date: start_date..end_date)
      .group("entryable_transactions.category_id")
      .sum("entries.amount * -1")

    budgets.map do |budget|
      spent = spent_by_category[budget.category_id] || 0
      {
        budget: budget,
        spent: spent,
        percentage: budget.amount > 0 ? (spent / budget.amount * 100).round : 0
      }
    end
  end

  # 账户余额数据
  def compute_account_balance_data
    # TODO: 从控制器提取 compute_account_balance_data 逻辑
    # 此方法较复杂，暂保留在控制器
    []
  end

  # 资产趋势
  def compute_asset_trend(_balance_data)
    # TODO: 提取 compute_asset_trend 逻辑
    []
  end

  # 瀑布图数据
  def compute_waterfall_data(_balance_data)
    # TODO: 提取 compute_waterfall_data 逻辑
    []
  end

  # 分类月度对比
  def compute_category_monthly_comparison
    # TODO: 提取 compute_category_monthly_comparison 逻辑
    {}
  end

  # Sankey 数据
  def compute_sankey_data(_total_income, _total_expense)
    # TODO: 提取 compute_sankey_data 逻辑
    []
  end

  # 日历热力图
  def compute_calendar_heatmap_data
    # TODO: 提取 compute_calendar_heatmap_data 逻辑
    []
  end

  # 筛选分类 — 只返回该时间段内有活动的分类
  def compute_filter_categories
    cats = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(date: start_date..end_date)
      .select("DISTINCT categories.id, categories.name, entryable_transactions.kind")
      .joins("INNER JOIN categories ON entryable_transactions.category_id = categories.id")
      .map { |r| { id: r.id, name: r.name, kind: r.kind } }

    {
      expense: cats.select { |c| c[:kind] == "expense" },
      income: cats.select { |c| c[:kind] == "income" }
    }
  end
end
