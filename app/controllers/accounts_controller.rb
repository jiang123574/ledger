class AccountsController < ApplicationController
  before_action :set_account, only: [ :show, :edit, :update, :destroy ]

  def index
    @accounts = Account.order(:sort_order, :name)
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
