class DashboardController < ApplicationController
  def show
    @today = Date.today
    @month = params[:month].to_s.presence || @today.strftime("%Y-%m")

    begin
      start_date = Date.parse("#{@month}-01")
    rescue Date::Error
      start_date = @today.beginning_of_month
      @month = @today.strftime("%Y-%m")
    end
    end_date = start_date.end_of_month

    ev = CacheBuster.version(:entries)
    av = CacheBuster.version(:accounts)

    # Cache accounts lookup
    @accounts = Rails.cache.fetch("dashboard/accounts/#{av}", expires_in: CacheConfig::MODERATE) do
      Account.visible.to_a
    end

    # Cache recent entries
    @entries = Rails.cache.fetch("dashboard/entries/#{@month}/#{ev}", expires_in: CacheConfig::MEDIUM) do
      Entry.includes(:account)
        .where(date: start_date..end_date, entryable_type: "Entryable::Transaction")
        .where("transfer_id IS NULL")
        .reverse_chronological
        .limit(50)
        .to_a
    end

    # 预加载 entryable 及其 category（每次请求都做，因为缓存序列化会丢失预加载状态）
    ActiveRecord::Associations::Preloader.new(records: @entries, associations: [ :entryable ]).call
    if @entries.any?
      category_ids = @entries.map { |e| e.entryable.respond_to?(:category_id) ? e.entryable.category_id : nil }.compact.uniq
      if category_ids.any?
        @category_map = Category.where(id: category_ids).index_by(&:id)
      end
    end

    # Cache monthly stats
    @monthly_stats = Rails.cache.fetch("dashboard/stats/#{@month}/#{ev}", expires_in: CacheConfig::MODERATE) do
      entries = Entry.with_entryable_transaction
        .where(date: start_date..end_date, entryable_type: "Entryable::Transaction")
        .where("transfer_id IS NULL")
      {
        income: entries.where(entryable_transactions: { kind: "income" }).sum(:amount),
        expense: entries.where(entryable_transactions: { kind: "expense" }).sum("entries.amount * -1"),
        count: entries.count
      }
    end
    @total_income = @monthly_stats[:income]
    @total_expense = @monthly_stats[:expense]
    @monthly_stats[:balance] = @total_income - @total_expense

    # Cache expenses by category
    expenses_data = Rails.cache.fetch("dashboard/expenses/#{@month}/#{ev}", expires_in: CacheConfig::MODERATE) do
      Entry.with_category
        .transactions_only
        .non_transfers
        .where(date: start_date..end_date)
        .where(entryable_transactions: { kind: "expense" })
        .select("categories.id AS category_id, categories.name AS category_name, SUM(entries.amount * -1) AS total_amount")
        .group("categories.id, categories.name")
        .order(Arel.sql("SUM(entries.amount * -1) DESC"))
        .to_a
    end

    @expenses_by_category = expenses_data.map { |e| [ e.category_id, e.category_name, e.total_amount ] }

    @budgets = Budget.for_month(@month).to_a
    @total_budget = @budgets.sum(&:amount)
    # 预加载 spent_amount，消除 N+1
    Budget.preload_spent_amounts(@budgets)

    # total_spent 也纳入缓存
    @total_spent = Rails.cache.fetch("dashboard/total_spent/#{@month}/#{ev}", expires_in: CacheConfig::MODERATE) do
      Entry.with_entryable_transaction
        .transactions_only
        .non_transfers
        .where(entryable_transactions: { kind: "expense", category_id: @budgets.pluck(:category_id) })
        .where(date: start_date..end_date)
        .sum("entries.amount * -1")
    end

    # Trend chart data for current month (weekly)
    @trend_chart_data = Rails.cache.fetch("dashboard/trend/#{@month}/#{ev}", expires_in: CacheConfig::MODERATE) do
      load_weekly_trend(start_date, end_date)
    end

    # Category chart data for expenses (pie chart)
    @expense_chart_data = @expenses_by_category.first(10).map do |category_id, category_name, amount|
      { label: category_name || "未分类", value: amount, category_id: category_id }
    end

    # 使用优化后的 Account.total_assets（已消除 N+1）
    @total_assets = Rails.cache.fetch("dashboard/assets/#{av}", expires_in: CacheConfig::MODERATE) do
      Account.total_assets
    end

    # 近6个月柱状图数据（收支对比）
    @six_month_bar_data = Rails.cache.fetch("dashboard/six_month_bar/#{ev}", expires_in: CacheConfig::MODERATE) do
      load_six_month_bar_chart
    end

    # 净资产走势图数据（近6个月）
    @net_worth_trend_data = Rails.cache.fetch("dashboard/net_worth/#{av}/#{ev}", expires_in: CacheConfig::MODERATE) do
      load_net_worth_trend
    end
  end

  private

  def load_six_month_bar_chart
    today = Date.today
    six_months_ago = today.beginning_of_month - 5.months

    stats = Entry.with_entryable_transaction
      .transactions_only
      .non_transfers
      .where(date: six_months_ago..today.end_of_month)
      .group("date_trunc('month', entries.date)", "entryable_transactions.kind")
      .select("date_trunc('month', entries.date) as month_date, entryable_transactions.kind as kind, SUM(CASE WHEN entryable_transactions.kind = 'expense' THEN entries.amount * -1 ELSE entries.amount END) as total")
      .map { |r| { month: r.month_date.to_date, kind: r.kind, amount: r.total.to_f } }

    stats_by_month = stats.group_by { |s| s[:month].beginning_of_month }

    months = []
    current = six_months_ago.beginning_of_month
    while current <= today.beginning_of_month
      month_data = stats_by_month[current] || []
      income = month_data.find { |s| s[:kind] == "income" }&.dig(:amount) || 0
      expense = month_data.find { |s| s[:kind] == "expense" }&.dig(:amount) || 0

      months << {
        month: current,
        label: current.strftime("%m月"),
        income: income,
        expense: expense
      }

      current = current.next_month
    end

    {
      labels: months.map { |m| m[:label] },
      income: months.map { |m| m[:income] },
      expense: months.map { |m| m[:expense] }
    }
  end

  def load_net_worth_trend
    today = Date.today
    six_months_ago = today.beginning_of_month - 5.months

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

    monthly_changes = Entry.where(date: six_months_ago..today.end_of_month, entryable_type: "Entryable::Transaction")
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

    months = []
    cumulative_asset = 0
    cumulative_liability = 0

    current_assets = current_balances.select { |_, v| asset_types.include?(v[:type]) }.values.sum { |v| v[:balance] }
    current_liabilities = current_balances.select { |_, v| liability_types.include?(v[:type]) }.values.sum { |v| v[:balance] }

    months_in_range = []
    current = six_months_ago.beginning_of_month
    while current <= today.beginning_of_month
      months_in_range << current.month
      current = current.next_month
    end

    total_asset_delta = months_in_range.sum { |m| monthly_asset_delta[m] || 0 }
    total_liability_delta = months_in_range.sum { |m| monthly_liability_delta[m] || 0 }

    estimated_start_assets = current_assets - total_asset_delta
    estimated_start_liabilities = current_liabilities - total_liability_delta

    current = six_months_ago.beginning_of_month
    while current <= today.beginning_of_month
      m = current.month
      cumulative_asset += monthly_asset_delta[m] || 0
      cumulative_liability += monthly_liability_delta[m] || 0

      asset_val = estimated_start_assets + cumulative_asset
      liability_val = estimated_start_liabilities + cumulative_liability
      net_val = asset_val + liability_val

      months << {
        month: current,
        label: current.strftime("%m月"),
        net_worth: net_val.to_f.round(2)
      }

      current = current.next_month
    end

    {
      labels: months.map { |m| m[:label] },
      net_worth: months.map { |m| m[:net_worth] }
    }
  end

  def load_weekly_trend(start_date, end_date)
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
      week_data = stats_by_week[current.beginning_of_week] || []
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

    {
      labels: weeks.map { |w| w[:label] },
      income: weeks.map { |w| w[:income] },
      expense: weeks.map { |w| w[:expense] }
    }
  end
end
