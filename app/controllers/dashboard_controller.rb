class DashboardController < ApplicationController
  # Enable fragment caching with custom key
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
      Account.visible.includes(sent_transactions: :category, received_transactions: :category).to_a
    end

    # Cache recent transactions
    @transactions = Rails.cache.fetch("dashboard/transactions/#{@month}/#{@cache_key}", expires_in: 2.minutes) do
      Transaction.includes(:account, :category)
        .where(date: start_date..end_date)
        .order(date: :desc)
        .limit(50)
        .to_a
    end

    # Cache monthly stats
    @monthly_stats = Rails.cache.fetch("dashboard/stats/#{@month}", expires_in: 5.minutes) do
      Transaction.monthly_stats(@month)
    end
    @total_income = @monthly_stats[:income]
    @total_expense = @monthly_stats[:expense]

    # Cache expenses by category
    @expenses_by_category = Rails.cache.fetch("dashboard/expenses/#{@month}", expires_in: 5.minutes) do
      Transaction.by_category(@month)
    end

    @budgets = Budget.for_month(@month)
    @total_budget = @budgets.sum(:amount)
    @total_spent = Transaction.where(
      type: "EXPENSE",
      category_id: @budgets.pluck(:category_id),
      date: start_date..end_date
    ).sum(:amount)

    # Cache total assets
    @total_assets = Rails.cache.fetch("dashboard/assets/#{@cache_key}", expires_in: 5.minutes) do
      Account.total_assets
    end
  end

  private

  def set_cache_key
    # Use last transaction timestamp as cache key
    last_transaction = Transaction.maximum(:updated_at)
    @cache_key = last_transaction&.to_i || 0
  end
end
