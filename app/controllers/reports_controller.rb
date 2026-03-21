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

    # 账户余额
    @account_balances = Account.visible.map do |account|
      {
        account: account,
        balance: account.current_balance
      }
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
      # 年度：按月统计
      (1..12).map do |month|
        start_date = Date.new(@year, month, 1)
        end_date = start_date.end_of_month

        transactions = Transaction.where(date: start_date..end_date).where.not(type: "TRANSFER")

        {
          month: month,
          label: "#{month}月",
          income: transactions.income.sum(:amount),
          expense: transactions.expense.sum(:amount)
        }
      end
    else
      # 月度：按周统计
      weeks = []
      current = @start_date
      week_num = 1

      while current <= @end_date
        week_end = [ current.end_of_week, @end_date ].min
        transactions = Transaction.where(date: current..week_end).where.not(type: "TRANSFER")

        weeks << {
          week: week_num,
          label: "第#{week_num}周",
          income: transactions.income.sum(:amount),
          expense: transactions.expense.sum(:amount)
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
    @budget_progress = @budgets.map do |budget|
      spent = Transaction.where(
        type: "EXPENSE",
        category_id: budget.category_id,
        date: @start_date..@end_date
      ).sum(:amount)

      {
        budget: budget,
        spent: spent,
        percentage: budget.amount > 0 ? (spent / budget.amount * 100).round : 0
      }
    end
  end
end
