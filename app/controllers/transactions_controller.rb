class TransactionsController < ApplicationController
  before_action :set_transaction, only: [:show, :edit, :update, :destroy]
  before_action :load_lookups, only: [:new, :edit, :create, :update]

  def index
    @accounts = Account.visible.order(:name).select(:id, :name, :type, :currency, :initial_balance)
    @transactions = Transaction.includes(:account, :category)
      .order(date: :desc)

    if params[:start_date].present? && params[:end_date].present?
      @transactions = @transactions.where(date: params[:start_date]..params[:end_date])
    end

    if params[:type].present?
      @transactions = @transactions.where(type: params[:type])
    end

    if params[:account_id].present?
      @transactions = @transactions.where(account_id: params[:account_id])
    end
  end

  def show
  end

  def new
    @transaction = Transaction.new(date: Date.today)
  end

  def edit
  end

  def create
    @transaction = Transaction.new(transaction_params)
    if @transaction.save
      redirect_to @transaction, notice: "交易已创建"
    else
      render :new
    end
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to @transaction, notice: "交易已更新"
    else
      render :edit
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_url, notice: "交易已删除"
  end

  private

  def set_transaction
    @transaction = Transaction.find(params[:id])
  end

  def load_lookups
    @accounts = Account.order(:name)
    @categories = Category.order(:name)
  end

  def transaction_params
    params.require(:transaction).permit(
      :date, :type, :amount, :currency, :category, :category_id,
      :account_id, :target_account_id, :note, :transaction_type
    )
  end
end
