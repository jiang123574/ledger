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
      entries = Entry.where(date: start_date..end_date, entryable_type: "Entryable::Transaction")
        .where("transfer_id IS NULL")
      {
        income: entries.where("amount > 0").sum(:amount),
        expense: entries.where("amount < 0").sum("ABS(amount)"),
        balance: entries.where("amount > 0").sum(:amount) - entries.where("amount < 0").sum("ABS(amount)"),
        count: entries.count
      }
    end
    @total_income = @monthly_stats[:income]
    @total_expense = @monthly_stats[:expense]

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

    @budgets = Budget.for_month(@month)
    @total_budget = @budgets.sum(:amount)

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
  end

  private

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
