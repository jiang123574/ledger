class DashboardController < ApplicationController
  before_action :set_cache_key

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

    # Cache accounts lookup
    @accounts = Rails.cache.fetch("dashboard/accounts/#{@cache_key}", expires_in: 5.minutes) do
      Account.visible.to_a
    end

    # Cache recent entries
    @entries = Rails.cache.fetch("dashboard/entries/#{@month}/#{@cache_key}", expires_in: 2.minutes) do
      Entry.includes(:account, :entryable)
        .where(date: start_date..end_date, entryable_type: 'Entryable::Transaction')
        .where("transfer_id IS NULL")
        .reverse_chronological
        .limit(50)
        .to_a
    end

    # 兼容旧视图
    @transactions = @entries.map { |e| build_transaction_from_entry(e) }

    # Cache monthly stats - 使用 Entry
    @monthly_stats = Rails.cache.fetch("dashboard/stats/#{@month}", expires_in: 5.minutes) do
      entries = Entry.where(date: start_date..end_date, entryable_type: 'Entryable::Transaction')
        .where("transfer_id IS NULL")
      {
        income: entries.where('amount > 0').sum(:amount),
        expense: entries.where('amount < 0').sum('ABS(amount)'),
        balance: entries.where('amount > 0').sum(:amount) - entries.where('amount < 0').sum('ABS(amount)'),
        count: entries.count
      }
    end
    @total_income = @monthly_stats[:income]
    @total_expense = @monthly_stats[:expense]

    # Cache expenses by category
    @expenses_by_category = Rails.cache.fetch("dashboard/expenses/#{@month}", expires_in: 5.minutes) do
      Entry.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
        .joins('INNER JOIN categories ON entryable_transactions.category_id = categories.id')
        .where(entries: { entryable_type: 'Entryable::Transaction' })
        .where(date: start_date..end_date)
        .where("entries.transfer_id IS NULL")
        .where(entryable_transactions: { kind: 'expense' })
        .group("categories.name")
        .order(Arel.sql("SUM(ABS(entries.amount)) DESC"))
        .sum('ABS(entries.amount)')
    end

    @budgets = Budget.for_month(@month)
    @total_budget = @budgets.sum(:amount)
    @total_spent = Entry.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
      .where(entries: { entryable_type: 'Entryable::Transaction' })
      .where("entries.transfer_id IS NULL")
      .where(entryable_transactions: { kind: 'expense', category_id: @budgets.pluck(:category_id) })
      .where(date: start_date..end_date)
      .sum('ABS(entries.amount)')

    # Cache total assets
    @total_assets = Rails.cache.fetch("dashboard/assets/#{@cache_key}", expires_in: 5.minutes) do
      Account.visible.included_in_total.sum { |a| a.current_balance }
    end
  end

  private

  def set_cache_key
    last_entry = Entry.maximum(:updated_at)
    @cache_key = last_entry&.to_i || 0
  end

  def build_transaction_from_entry(entry)
    t = Transaction.new
    t.id = entry.id
    t.account_id = entry.account_id
    t.account = entry.account
    t.date = entry.date
    t.amount = entry.amount.abs
    t.currency = entry.currency
    t.note = entry.notes || entry.name
    
    if entry.entryable.respond_to?(:kind)
      t.type = entry.entryable.kind.upcase
      if entry.entryable.respond_to?(:category)
        t.category = entry.entryable.category
        t.category_id = entry.entryable.category_id
      end
    end
    
    t
  end
end
