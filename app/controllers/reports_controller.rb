class ReportsController < ApplicationController
  def show
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i

    if @month.present?
      # 月度报表
      @start_date = Date.new(@year, @month, 1)
      @end_date = @start_date.end_of_month
      @report_type = :monthly
    else
      # 年度报表
      @start_date = Date.new(@year, 1, 1)
      @end_date = Date.new(@year, 12, 31)
      @report_type = :yearly
    end

    load_report_data
  end

  private

  def load_report_data
    # 缓存键需要考虑 Transaction 的更新时间
    # 注意：accounts 表没有 updated_at 列
    transaction_key = Transaction.maximum(:updated_at)&.to_i || 0
    @cache_key = "#{transaction_key}"

    # 收支统计
    transactions = Transaction.where(date: @start_date..@end_date).where.not(type: "TRANSFER")

    @total_income = transactions.income.sum(:amount)
    @total_expense = transactions.expense.sum(:amount)
    @net_balance = @total_income - @total_expense

    # 月度趋势
    @monthly_trend = load_monthly_trend

    # 分类统计
    @expense_by_category = load_category_stats("EXPENSE")
    @income_by_category = load_category_stats("INCOME")

    # 账户余额 - 使用缓存的余额计算（只包含计入资产的账户）
    @account_balances = Rails.cache.fetch("reports/accounts/#{@cache_key}", expires_in: 5.minutes) do
      Account.visible.included_in_total.map do |account|
        { account: account, balance: account.current_balance }
      end
    end

    # 预算进度
    load_budget_data if @report_type == :monthly

    # 图表数据
    load_chart_data
  end

  def load_chart_data
    # 收支趋势图表数据
    @trend_chart_data = {
      labels: @monthly_trend.map { |p| p[:label] },
      income: @monthly_trend.map { |p| p[:income] },
      expense: @monthly_trend.map { |p| p[:expense] }
    }

    # 支出分类图表数据
    @expense_chart_data = @expense_by_category.first(10).map do |category, amount|
      {
        label: category || "未分类",
        value: amount
      }
    end

    # 收入分类图表数据
    @income_chart_data = @income_by_category.first(10).map do |category, amount|
      {
        label: category || "未分类",
        value: amount
      }
    end
  end

  def load_monthly_trend
    if @report_type == :yearly
      # 年度：按月统计 - 一次查询
      stats = Transaction.where(date: @start_date..@end_date)
        .where.not(type: "TRANSFER")
        .group("date_trunc('month', date)", :type)
        .select("date_trunc('month', date) as month_date, type, SUM(amount) as total")
        .map { |r| { month: r.month_date.month, type: r.type, amount: r.total.to_f } }

      stats_by_month = stats.group_by { |s| s[:month] }
      (1..12).map do |month|
        month_data = stats_by_month[month] || []
        {
          month: month,
          label: "#{month}月",
          income: month_data.find { |s| s[:type] == 'INCOME' }&.dig(:amount) || 0,
          expense: month_data.find { |s| s[:type] == 'EXPENSE' }&.dig(:amount) || 0
        }
      end
    else
      # 月度：按周统计 - 一次查询
      stats = Transaction.where(date: @start_date..@end_date)
        .where.not(type: "TRANSFER")
        .group("date_trunc('week', date)", :type)
        .select("date_trunc('week', date) as week_date, type, SUM(amount) as total")
        .map { |r| { week: r.week_date.to_date, type: r.type, amount: r.total.to_f } }

      stats_by_week = stats.group_by { |s| s[:week] }
      weeks = []
      current = @start_date
      week_num = 1

      while current <= @end_date
        week_end = [current.end_of_week, @end_date].min
        week_data = stats_by_week[current] || []

        weeks << {
          week: week_num,
          label: "第#{week_num}周",
          income: week_data.find { |s| s[:type] == 'INCOME' }&.dig(:amount) || 0,
          expense: week_data.find { |s| s[:type] == 'EXPENSE' }&.dig(:amount) || 0
        }

        current = week_end + 1.day
        week_num += 1
      end

      weeks
    end
  end

  def load_category_stats(type)
    Transaction.where(type: type, date: @start_date..@end_date)
      .joins(:category)
      .group("categories.name")
      .order(Arel.sql("SUM(amount) DESC"))
      .sum(:amount)
  end

  def load_budget_data
    @budgets = Budget.for_month("#{@year}-#{@month.to_s.rjust(2, '0')}")
    return @budget_progress = [] if @budgets.empty?

    # 一次查询获取所有预算分类的支出
    category_ids = @budgets.pluck(:category_id)
    spent_by_category = Transaction.where(
      type: "EXPENSE",
      category_id: category_ids,
      date: @start_date..@end_date
    ).group(:category_id).sum(:amount)

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
