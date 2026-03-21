# frozen_string_literal: true

class TransactionsController < ApplicationController
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy ]
  before_action :load_lookups, only: [ :new, :edit, :create, :update ]

  def index
    @search = TransactionSearch.new(params)
    @transactions = Transaction.includes(:account, :category)
      .order(date: :desc)
    @transactions = @search.apply(@transactions)

    @accounts = Account.visible.order(:name).select(:id, :name, :type, :currency, :initial_balance)
    @categories = Category.order(:name)

    @summary = {
      total_income: @transactions.where(type: "INCOME").sum(:amount),
      total_expense: @transactions.where(type: "EXPENSE").sum(:amount),
      count: @transactions.count
    }
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
      redirect_to transactions_path, notice: "交易已创建"
    else
      render :new
    end
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to transactions_path, notice: "交易已更新"
    else
      render :edit
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_path, notice: "交易已删除"
  end

  def bulk_destroy
    if params[:ids].present?
      Transaction.where(id: params[:ids]).destroy_all
      redirect_to transactions_path, notice: "已删除 #{params[:ids].count} 笔交易"
    else
      redirect_to transactions_path, alert: "请选择要删除的交易"
    end
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
