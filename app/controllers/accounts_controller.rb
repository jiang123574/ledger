class AccountsController < ApplicationController
  before_action :set_account, only: [ :show, :edit, :update, :destroy ]

  def index
    @accounts = Account.order(:sort_order, :name)
    @transactions = Transaction.includes(:account, :category)
                             .order(date: :desc, created_at: :desc)
                             .limit(50)
    
    # 本月统计
    start_of_month = Date.today.beginning_of_month
    end_of_month = Date.today.end_of_month
    @monthly_income = Transaction.where(type: "INCOME", date: start_of_month..end_of_month).sum(:amount)
    @monthly_expense = Transaction.where(type: "EXPENSE", date: start_of_month..end_of_month).sum(:amount)
    @monthly_balance = @monthly_income - @monthly_expense
  end

  def show
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

  def account_params
    params.require(:account).permit(
      :name, :account_type, :initial_balance, :currency,
      :billing_day, :due_day, :credit_limit,
      :include_in_total, :hidden, :sort_order
    )
  end
end
