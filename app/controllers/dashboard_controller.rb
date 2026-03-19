class DashboardController < ApplicationController
  def show
    @today = Date.today
    @month = params[:month] || @today.strftime("%Y-%m")
    start_date = Date.parse("#{@month}-01")
    end_date = start_date.end_of_month

    @accounts = Account.visible.includes(:sent_transactions, :received_transactions)
    @transactions = Transaction.where(date: start_date..end_date).order(date: :desc).limit(50)
    @total_income = @transactions.where(transaction_type: "INCOME").sum(:amount)
    @total_expense = @transactions.where(transaction_type: "EXPENSE").sum(:amount)

    @expenses_by_category = Transaction.where(transaction_type: "EXPENSE", date: start_date..end_date)
      .group("transactions.category")
      .sum(:amount)

    @budgets = Budget.for_month(@month)
  end
end
