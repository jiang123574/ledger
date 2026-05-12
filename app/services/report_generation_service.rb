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
    # 按周统计当月数据
    first_day = start_date
    last_day = end_date

    weeks = []
    current = first_day
    while current <= last_day
      week_end = [ current + 6.days, last_day ].min
      weeks << { start: current, end: week_end, label: "第#{(current - first_day).to_i / 7 + 1}周" }
      current = week_end + 1.day
    end

    weeks.map do |week|
      week_entries = Entry.with_entryable_transaction
        .transactions_only
        .non_transfers
        .where(date: week[:start]..week[:end])

      income = week_entries.where(entryable_transactions: { kind: "income" }).sum(:amount)
      expense = week_entries.where(entryable_transactions: { kind: "expense" }).sum("entries.amount * -1")

      {
        month: week[:start].day,
        label: week[:label],
        income: income,
        expense: expense
      }
    end
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
    Budget.where(month: start_date)
      .includes(:category)
      .map do |budget|
        spent = budget.spent_amount || 0
        percentage = budget.amount > 0 ? (spent / budget.amount * 100).round(1) : 0
        {
          category: budget.category,
          budget_amount: budget.amount,
          spent_amount: spent,
          percentage: percentage,
          remaining: budget.amount - spent
        }
      end
      .sort_by { |b| -b[:spent_amount] }
  end

  # 账户余额数据
  def compute_account_balance_data
    # TODO: 从控制器提取 compute_account_balance_data 逻辑
    # 此方法较复杂，暂保留在控制器
    []
  end

  # 资产趋势
  def compute_asset_trend(balance_data)
    # TODO: 提取 compute_asset_trend 逻辑
    []
  end

  # 瀑布图数据
  def compute_waterfall_data(balance_data)
    # TODO: 提取 compute_waterfall_data 逻辑
    []
  end

  # 分类月度对比
  def compute_category_monthly_comparison
    # TODO: 提取 compute_category_monthly_comparison 逻辑
    {}
  end

  # Sankey 数据
  def compute_sankey_data(total_income, total_expense)
    # TODO: 提取 compute_sankey_data 逻辑
    []
  end

  # 日历热力图
  def compute_calendar_heatmap_data
    # TODO: 提取 compute_calendar_heatmap_data 逻辑
    []
  end

  # 筛选分类
  def compute_filter_categories
    expense_cats = categories.select { |c| (c.category_type || c.type) == "EXPENSE" }.sort_by(&:name)
    income_cats = categories.select { |c| (c.category_type || c.type) == "INCOME" }.sort_by(&:name)
    {
      expense: expense_cats,
      income: income_cats
    }
  end
end
