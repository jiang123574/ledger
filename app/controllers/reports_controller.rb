class ReportsController < ApplicationController
  def show
    @year = params[:year].to_i
    @year = Date.current.year unless @year.between?(2000, 2100)

    @month = params[:month].to_i
    @month = nil unless @month.between?(1, 12)

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

    # Turbo Frame 请求跳过 layout，只返回 frame 内容
    render :show, layout: false if turbo_frame_request?
  end

  private

  def load_report_data
    # 收支统计 - 使用 Entry
    entries = Entry.where(date: @start_date..@end_date, entryable_type: "Entryable::Transaction")
      .where("transfer_id IS NULL")

    @total_income = entries.with_entryable_transaction
      .where(entryable_transactions: { kind: "income" }).sum(:amount)
    @total_expense = entries.with_entryable_transaction
      .where(entryable_transactions: { kind: "expense" }).sum("entries.amount * -1")
    @net_balance = @total_income - @total_expense

    # 月度趋势
    @monthly_trend = load_monthly_trend

    # 分类统计
    @expense_by_category = load_category_stats("expense")
    @income_by_category = load_category_stats("income")

    # 资产走势（年度视图时加载）
    if @report_type == :yearly
      @asset_trend = load_asset_trend
    end

    # 年度分类月度对比（年度视图时加载）
    if @report_type == :yearly
      @category_monthly_comparison = load_category_monthly_comparison
    end

    # 桑基图数据（年度视图）
    if @report_type == :yearly
      @sankey_data = load_sankey_data
    end

    # 日历热力图数据（年度视图）
    if @report_type == :yearly
      @calendar_heatmap_data = load_calendar_heatmap_data
    end

    # 瀑布图数据（年度视图）
    if @report_type == :yearly
      @waterfall_data = load_waterfall_data
    end

    # 预算进度
    load_budget_data if @report_type == :monthly

    # 图表数据
    load_chart_data

    # 分类筛选列表（所有有活动的分类，用于前端多选过滤）
    @filter_categories = load_filter_categories
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
    else
      stats = Entry.with_entryable_transaction
        .transactions_only
        .non_transfers
        .where(date: @start_date..@end_date)
        .group("date_trunc('week', entries.date)", "entryable_transactions.kind")
        .select("date_trunc('week', entries.date) as week_date, entryable_transactions.kind as kind, SUM(CASE WHEN entryable_transactions.kind = 'expense' THEN entries.amount * -1 ELSE entries.amount END) as total")
        .map { |r| { week: r.week_date.to_date, kind: r.kind, amount: r.total.to_f } }

      stats_by_week = stats.group_by { |s| s[:week] }
      weeks = []
      current = @start_date
      week_num = 1

      while current <= @end_date
        week_end = [ current.end_of_week, @end_date ].min
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
  end

  def load_category_stats(kind)
    amount_expr = kind == "expense" ? "entries.amount * -1" : "entries.amount"
    Entry.with_category
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: kind })
      .where(date: @start_date..@end_date)
      .group("categories.name")
      .order(Arel.sql("SUM(#{amount_expr}) DESC"))
      .sum(amount_expr)
  end

  def load_budget_data
    @budgets = Budget.for_month("#{@year}-#{@month.to_s.rjust(2, '0')}")
    return @budget_progress = [] if @budgets.empty?

    category_ids = @budgets.pluck(:category_id)
    spent_by_category = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: "expense", category_id: category_ids })
      .where(date: @start_date..@end_date)
      .group("entryable_transactions.category_id")
      .sum("entries.amount * -1")

    @budget_progress = @budgets.map do |budget|
      spent = spent_by_category[budget.category_id] || 0
      {
        budget: budget,
        spent: spent,
        percentage: budget.amount > 0 ? (spent / budget.amount * 100).round : 0
      }
    end
  end

  # 资产走势图数据 — 基于当前余额反推月度变化
  def load_asset_trend
    # 资产类账户类型
    asset_types = %w[CASH BANK INVESTMENT]
    # 负债类账户类型（信用卡余额通常为负数）
    liability_types = %w[CREDIT LOAN DEBT]

    # 计算当前各账户余额
    current_balances = Account.visible.included_in_total
      .joins("LEFT JOIN entries ON entries.account_id = accounts.id AND entries.entryable_type = 'Entryable::Transaction'")
      .group("accounts.id")
      .pluck(Arel.sql("accounts.id, accounts.type, accounts.initial_balance + COALESCE(SUM(entries.amount), 0)"))
      .to_h { |id, type, bal| [ id, { type: type, balance: bal.to_d } ] }

    # 没有任何 entry 的账户用 initial_balance
    Account.visible.included_in_total.where.not(id: current_balances.keys)
      .pluck(:id, :type, :initial_balance)
      .each { |id, type, bal| current_balances[id] = { type: type, balance: bal.to_d } }

    # 按类型汇总当前值
    current_assets = current_balances.select { |_, v| asset_types.include?(v[:type]) }.values.sum { |v| v[:balance] }
    current_liabilities = current_balances.select { |_, v| liability_types.include?(v[:type]) }.values.sum { |v| v[:balance] }

    # 资产类账户 ID 列表
    asset_account_ids = current_balances.select { |_, v| asset_types.include?(v[:type]) }.keys
    liability_account_ids = current_balances.select { |_, v| liability_types.include?(v[:type]) }.keys

    # 按月计算交易变动
    monthly_changes = Entry.where(date: @start_date..@end_date, entryable_type: "Entryable::Transaction")
      .group("date_trunc('month', date)")
      .group(:account_id)
      .sum(:amount)

    # 按月 + 账户类型汇总变动
    monthly_asset_delta = Hash.new(0)
    monthly_liability_delta = Hash.new(0)

    monthly_changes.each do |(month_key, account_id), amount|
      m = month_key.month rescue nil
      next unless m
      if asset_account_ids.include?(account_id)
        monthly_asset_delta[m] += amount.to_d
      elsif liability_account_ids.include?(account_id)
        monthly_liability_delta[m] += amount.to_d
      end
    end

    # 年度总变动（用于反推年初值）
    yearly_asset_delta = monthly_asset_delta.values.sum
    yearly_liability_delta = monthly_liability_delta.values.sum

    estimated_start_assets = current_assets - yearly_asset_delta
    estimated_start_liabilities = current_liabilities - yearly_liability_delta

    # 逐月累加（按月份顺序遍历）
    months = []
    cumulative_asset = 0
    cumulative_liability = 0

    (1..12).each do |m|
      cumulative_asset += monthly_asset_delta[m]
      cumulative_liability += monthly_liability_delta[m]

      asset_val = estimated_start_assets + cumulative_asset
      liability_val = estimated_start_liabilities + cumulative_liability
      net_val = asset_val + liability_val # 信用卡余额为负，所以是加

      months << {
        label: "#{m}月",
        month: m,
        assets: asset_val.round(2),
        liabilities: liability_val.round(2),
        net_worth: net_val.round(2)
      }
    end

    months
  end

  # 年度分类月度对比 — 支出+收入分类按12个月展示，含月度总计
  def load_category_monthly_comparison
    # 获取所有有活动的支出和收入类别
    active_categories = Entry.with_entryable_transaction
      .transactions_only
      .where(date: @start_date..@end_date)
      .select("DISTINCT categories.id, categories.name, entryable_transactions.kind")
      .joins("INNER JOIN categories ON entryable_transactions.category_id = categories.id")
      .map { |r| { id: r.id, name: r.name, kind: r.kind } }

    return {} if active_categories.empty?

    # 一次性查询所有分类的月度数据
    category_ids = active_categories.map { |c| c[:id] }
    all_monthly = Entry.with_entryable_transaction
      .transactions_only
      .where(entryable_transactions: { category_id: category_ids })
      .where(date: @start_date..@end_date)
      .group("entryable_transactions.category_id", "date_trunc('month', entries.date)", "entryable_transactions.kind")
      .sum("CASE WHEN entryable_transactions.kind = 'expense' THEN entries.amount * -1 ELSE entries.amount END")

    # 按 category_id 预索引
    all_monthly_by_cat = all_monthly.group_by { |(cat_id, _, _), _| cat_id }

    categories = {}
    active_categories.each do |cat|
      monthly_data = (1..12).index_with { |m| 0.to_d }

      (all_monthly_by_cat[cat[:id]] || []).each do |(_, month_key, _), amount|
        m = month_key.month rescue nil
        monthly_data[m] = amount.to_d.round(2) if m
      end

      categories[cat[:id]] = {
        name: cat[:name],
        kind: cat[:kind],
        monthly: monthly_data,
        total: monthly_data.values.sum.round(2)
      }
    end

    # 月度总计行（使用 BigDecimal 精度）
    monthly_totals = (1..12).index_with { |m| { expense: 0.to_d, income: 0.to_d } }
    categories.each_value do |cat_data|
      (1..12).each do |m|
        monthly_totals[m][cat_data[:kind].to_sym] += cat_data[:monthly][m]
      end
    end

    # 对总计做 round(2) 并转浮点数传给前端
    monthly_totals.transform_values! do |v|
      { expense: v[:expense].round(2).to_f, income: v[:income].round(2).to_f }
    end

    # 将所有数值转为 float（BigDecimal to_json 会变成字符串，JS 端拿到的是 string 不是 number）
    categories.transform_values! do |v|
      {
        name: v[:name],
        kind: v[:kind],
        monthly: v[:monthly].transform_values(&:to_f),
        total: v[:total].to_f
      }
    end

    # 排序规则：支出分类优先（expense=0, income=1），同类型按总额降序
    {
      categories: categories.sort_by { |_, v| [ -(v[:kind] == "expense" ? 0 : 1), -v[:total] ] }.to_h,
      monthly_totals: monthly_totals
    }
  end

  # 筛选器用的分类列表 — 返回所有有活动的分类（含 id/name/kind）
  def load_filter_categories
    cats = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(date: @start_date..@end_date)
      .select("DISTINCT categories.id, categories.name, entryable_transactions.kind")
      .joins("INNER JOIN categories ON entryable_transactions.category_id = categories.id")
      .map { |r| { id: r.id, name: r.name, kind: r.kind } }

    {
      expense: cats.select { |c| c[:kind] == "expense" },
      income: cats.select { |c| c[:kind] == "income" }
    }
  end

  # 桑基图数据 — 收入来源 -> 分类 -> 支出流向
  def load_sankey_data
    nodes = []
    links = []

    max_income_categories = 10
    max_expense_categories = 15

    income_categories = Entry.with_category
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: "income" })
      .where(date: @start_date..@end_date)
      .group("categories.id, categories.name")
      .order(Arel.sql("SUM(entries.amount) DESC"))
      .sum("entries.amount")

    top_income = income_categories.select { |_, a| a > 0 }.first(max_income_categories)
    other_income_amount = income_categories.select { |_, a| a > 0 }.drop(max_income_categories).sum { |_, a| a }

    top_income.each do |cat_name, amount|
      nodes << { name: cat_name, type: "income" }
    end
    if other_income_amount > 0
      nodes << { name: "其他收入", type: "income" }
    end

    expense_categories = Entry.with_category
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: "expense" })
      .where(date: @start_date..@end_date)
      .group("categories.id, categories.name")
      .order(Arel.sql("SUM(entries.amount * -1) DESC"))
      .sum("entries.amount * -1")

    top_expense = expense_categories.select { |_, a| a > 0 }.first(max_expense_categories)
    other_expense_amount = expense_categories.select { |_, a| a > 0 }.drop(max_expense_categories).sum { |_, a| a }

    top_expense.each do |cat_name, amount|
      nodes << { name: cat_name, type: "expense" }
    end
    if other_expense_amount > 0
      nodes << { name: "其他支出", type: "expense" }
    end

    nodes << { name: "总收入", type: "center_income" }
    nodes << { name: "总支出", type: "center_expense" }

    top_income.each do |cat_name, amount|
      links << {
        source: cat_name,
        target: "总收入",
        value: amount.to_f,
        type: "income"
      }
    end
    if other_income_amount > 0
      links << {
        source: "其他收入",
        target: "总收入",
        value: other_income_amount.to_f,
        type: "income"
      }
    end

    if @total_income > 0
      expense_flow = [ @total_expense, @total_income ].min
      links << {
        source: "总收入",
        target: "总支出",
        value: expense_flow.to_f,
        type: "flow"
      }
    end

    top_expense.each do |cat_name, amount|
      links << {
        source: "总支出",
        target: cat_name,
        value: amount.to_f,
        type: "expense"
      }
    end
    if other_expense_amount > 0
      links << {
        source: "总支出",
        target: "其他支出",
        value: other_expense_amount.to_f,
        type: "expense"
      }
    end

    { nodes: nodes, links: links }
  end

  # 日历热力图数据 — 每日消费金额/频率分布
  def load_calendar_heatmap_data
    daily_data = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: "expense" })
      .where(date: @start_date..@end_date)
      .group("entries.date")
      .select("entries.date, COUNT(*) as count, SUM(entries.amount * -1) as total")
      .map { |r| { date: r.date.to_s, count: r.count.to_i, amount: r.total.to_f.abs } }

    daily_data.map do |d|
      {
        date: d[:date],
        count: d[:count],
        amount: d[:amount],
        level: calculate_heatmap_level(d[:amount])
      }
    end
  end

  def calculate_heatmap_level(amount)
    case amount
    when 0..100 then 1
    when 100..500 then 2
    when 500..1000 then 3
    when 1000..5000 then 4
    else 5
    end
  end

  # 瀑布图数据 — 账户余额变动明细（按月汇总）
  def load_waterfall_data
    labels = []
    data = []
    totals = []

    asset_types = %w[CASH BANK INVESTMENT]
    liability_types = %w[CREDIT LOAN DEBT]

    current_balances = Account.visible.included_in_total
      .joins("LEFT JOIN entries ON entries.account_id = accounts.id AND entries.entryable_type = 'Entryable::Transaction'")
      .group("accounts.id")
      .pluck(Arel.sql("accounts.id, accounts.type, accounts.initial_balance + COALESCE(SUM(entries.amount), 0)"))
      .to_h { |id, type, bal| [ id, { type: type, balance: bal.to_d } ] }

    Account.visible.included_in_total.where.not(id: current_balances.keys)
      .pluck(:id, :type, :initial_balance)
      .each { |id, type, bal| current_balances[id] = { type: type, balance: bal.to_d } }

    asset_account_ids = current_balances.select { |_, v| asset_types.include?(v[:type]) }.keys
    liability_account_ids = current_balances.select { |_, v| liability_types.include?(v[:type]) }.keys

    current_assets = current_balances.select { |_, v| asset_types.include?(v[:type]) }.values.sum { |v| v[:balance] }
    current_liabilities = current_balances.select { |_, v| liability_types.include?(v[:type]) }.values.sum { |v| v[:balance] }

    monthly_changes = Entry.where(date: @start_date..@end_date, entryable_type: "Entryable::Transaction")
      .group("date_trunc('month', date)")
      .group(:account_id)
      .sum(:amount)

    monthly_asset_delta = Hash.new(0)
    monthly_liability_delta = Hash.new(0)

    monthly_changes.each do |(month_key, account_id), amount|
      m = month_key.to_date.month rescue nil
      next unless m
      if asset_account_ids.include?(account_id)
        monthly_asset_delta[m] += amount.to_d
      elsif liability_account_ids.include?(account_id)
        monthly_liability_delta[m] += amount.to_d
      end
    end

    yearly_asset_delta = (1..12).sum { |m| monthly_asset_delta[m] || 0 }
    yearly_liability_delta = (1..12).sum { |m| monthly_liability_delta[m] || 0 }

    estimated_start_net_worth = (current_assets + current_liabilities) - (yearly_asset_delta + yearly_liability_delta)

    # 期初余额
    labels << "年初"
    data << 0
    totals << estimated_start_net_worth.to_f.round(2)

    cumulative = 0
    (1..12).each do |m|
      asset_delta = monthly_asset_delta[m] || 0
      liability_delta = monthly_liability_delta[m] || 0
      net_delta = asset_delta + liability_delta

      cumulative += net_delta

      labels << "#{m}月"
      data << net_delta.to_f.round(2)
      totals << (estimated_start_net_worth + cumulative).to_f.round(2)
    end

    # 期末余额（作为汇总条）
    labels << "年末"
    data << 0
    totals << (current_assets + current_liabilities).to_f.round(2)

    { labels: labels, data: data, totals: totals }
  end
end
