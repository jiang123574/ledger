class AccountsController < ApplicationController
  before_action :set_account, only: [:show, :edit, :update, :destroy]

  def index
    @accounts = Account.order(:sort_order, :name)
  end

  def show
    @transactions = @account.transactions
      .includes(:category)
      .order(date: :desc)
      .limit(100)
    
    @balance_history = calculate_balance_history
    
    @stats = {
      total_income: @account.transactions.where(type: "INCOME").sum(:amount),
      total_expense: @account.transactions.where(type: "EXPENSE").sum(:amount),
      transaction_count: @account.transactions.count
    }
  end

  def new
    @account = Account.new
  end

  def edit
  end

  def create
    @account = Account.new(account_params)
    if @account.save
      redirect_to accounts_path, notice: "账户已创建"
    else
      render :new
    end
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "账户已更新"
    else
      render :edit
    end
  end

  def destroy
    @account.destroy
    redirect_to accounts_url, notice: "账户已删除"
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def calculate_balance_history
    initial = @account.initial_balance || 0
    transactions = @account.transactions
      .select("date, type, amount")
      .order(date: :asc)
      .group_by { |t| t.date.beginning_of_month }
    
    balance = initial
    history = []
    current_month = Date.today.beginning_of_month
    
    12.downto(0).each do |months_ago|
      month = current_month - months_ago.months
      month_end = month.end_of_month
      
      transactions_in_month = @account.transactions.where("date <= ?", month_end)
      month_change = transactions_in_month.sum(:amount)
      balance = initial + month_change
      
      history << {
        month: month.strftime("%Y-%m"),
        balance: balance,
        income: transactions_in_month.where(type: "INCOME").sum(:amount),
        expense: transactions_in_month.where(type: "EXPENSE").sum(:amount)
      }
    end
    
    history
  end

  def account_params
    params.require(:account).permit(
      :name, :account_type, :initial_balance, :currency,
      :billing_day, :due_day, :credit_limit,
      :include_in_total, :hidden, :sort_order
    )
  end
end
