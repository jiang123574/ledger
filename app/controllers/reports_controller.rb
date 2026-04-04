class ReportsController < ApplicationController
  def show
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i

    if @month.present?
      @start_date = Date.new(@year, @month, 1)
      @end_date = @start_date.end_of_month
      @report_type = :monthly
    else
      @start_date = Date.new(@year, 1, 1)
      @end_date = Date.new(@year, 12, 31)
      @report_type = :yearly
    end

    load_report_data
  end

  private

  def load_report_data
    entry_key = Entry.maximum(:updated_at)&.to_i || 0
    @cache_key = "#{entry_key}"

    # 收支统计 - 使用 Entry
    entries = Entry.where(date: @start_date..@end_date, entryable_type: 'Entryable::Transaction')
      .where("transfer_id IS NULL")

    @total_income = entries.where('amount > 0').sum(:amount)
    @total_expense = entries.where('amount < 0').sum('ABS(amount)')
    @net_balance = @total_income - @total_expense

    # 月度趋势
    @monthly_trend = load_monthly_trend

    # 分类统计
    @expense_by_category = load_category_stats('expense')
    @income_by_category = load_category_stats('income')

    # 预算进度
    load_budget_data if @report_type == :monthly

    # 图表数据
    load_chart_data
  end

  def load_chart_data
    @trend_chart_data = {
      labels: @monthly_trend.map { |p| p[:label] },
      income: @monthly_trend.map { |p| p[:income] },
      expense: @monthly_trend.map { |p| p[:expense] }
    }

    @expense_chart_data = @expense_by_category.first(10).map do |category, amount|
      { label: category || "未分类", value: amount }
    end

    @income_chart_data = @income_by_category.first(10).map do |category, amount|
      { label: category || "未分类", value: amount }
    end
  end

  def load_monthly_trend
    if @report_type == :yearly
      stats = Entry.with_entryable_transaction
        .transactions_only
        .non_transfers
        .where(date: @start_date..@end_date)
        .group("date_trunc('month', entries.date)", 'entryable_transactions.kind')
        .select("date_trunc('month', entries.date) as month_date, entryable_transactions.kind as kind, SUM(ABS(entries.amount)) as total")
        .map { |r| { month: r.month_date.month, kind: r.kind, amount: r.total.to_f } }

      stats_by_month = stats.group_by { |s| s[:month] }
      (1..12).map do |month|
        month_data = stats_by_month[month] || []
        income = month_data.find { |s| s[:kind] == 'income' }&.dig(:amount) || 0
        expense = month_data.find { |s| s[:kind] == 'expense' }&.dig(:amount) || 0
        {
          month: month,
          label: "#{month}月",
          income: income,
          expense: expense
        }
      end
    else
      stats = Entry.with_entryable_transaction
        .transactions_only
        .non_transfers
        .where(date: @start_date..@end_date)
        .group("date_trunc('week', entries.date)", 'entryable_transactions.kind')
        .select("date_trunc('week', entries.date) as week_date, entryable_transactions.kind as kind, SUM(ABS(entries.amount)) as total")
        .map { |r| { week: r.week_date.to_date, kind: r.kind, amount: r.total.to_f } }

      stats_by_week = stats.group_by { |s| s[:week] }
      weeks = []
      current = @start_date
      week_num = 1

      while current <= @end_date
        week_end = [current.end_of_week, @end_date].min
        week_data = stats_by_week[current] || []
        income = week_data.find { |s| s[:kind] == 'income' }&.dig(:amount) || 0
        expense = week_data.find { |s| s[:kind] == 'expense' }&.dig(:amount) || 0

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
  end

  def load_category_stats(kind)
    Entry.with_category
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: kind })
      .where(date: @start_date..@end_date)
      .group("categories.name")
      .order(Arel.sql("SUM(ABS(entries.amount)) DESC"))
      .sum('ABS(entries.amount)')
  end

  def load_budget_data
    @budgets = Budget.for_month("#{@year}-#{@month.to_s.rjust(2, '0')}")
    return @budget_progress = [] if @budgets.empty?

    category_ids = @budgets.pluck(:category_id)
    spent_by_category = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: 'expense', category_id: category_ids })
      .where(date: @start_date..@end_date)
      .group('entryable_transactions.category_id')
      .sum('ABS(entries.amount)')

    @budget_progress = @budgets.map do |budget|
      spent = spent_by_category[budget.category_id] || 0
      {
        budget: budget,
        spent: spent,
        percentage: budget.amount > 0 ? (spent / budget.amount * 100).round : 0
      }
    end
  end
end
