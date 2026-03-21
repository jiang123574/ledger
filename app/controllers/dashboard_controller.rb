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

    @accounts = Account.visible.includes(sent_transactions: :category, received_transactions: :category)
    @transactions = Transaction.includes(:account, :category)
      .where(date: start_date..end_date)
      .order(date: :desc)
      .limit(50)
    
    @monthly_stats = Transaction.monthly_stats(@month)
    @total_income = @monthly_stats[:income]
    @total_expense = @monthly_stats[:expense]
    
    @expenses_by_category = Transaction.by_category(@month)
    @expenses_for_chart = @expenses_by_category.reject { |k, _| k.blank? }

    @budgets = Budget.for_month(@month)
    @total_budget = @budgets.sum(:amount)
    @total_spent = Transaction.where(
      type: "EXPENSE",
      category_id: @budgets.pluck(:category_id),
      date: start_date..end_date
    ).sum(:amount)
  end
end
