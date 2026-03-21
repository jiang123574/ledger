# frozen_string_literal: true

class TransactionsController < ApplicationController
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy ]
  before_action :load_lookups, only: [ :new, :edit, :create, :update, :index ]

  def index
    @search = TransactionSearch.new(params)
    @transactions = @search.apply(Transaction.includes(:account, :category, :tags))
                           .reverse_chronological

    @summary = calculate_summary(@transactions)
  end

  def show
  end

  def new
    @transaction = Transaction.new(
      date: Date.today,
      type: params[:type] || "EXPENSE"
    )
  end

  def edit
  end

  def create
    @transaction = build_transaction

    if @transaction.save
      handle_successful_save("交易已创建")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @transaction.update(transaction_params)
      handle_successful_save("交易已更新")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_path, notice: "交易已删除"
  end

  def bulk_destroy
    ids = params[:ids].presence
    if ids
      count = Transaction.where(id: ids).destroy_all.size
      redirect_to transactions_path, notice: "已删除 #{count} 笔交易"
    else
      redirect_to transactions_path, alert: "请选择要删除的交易"
    end
  end

  private

  def set_transaction
    @transaction = Transaction.find(params[:id])
  end

  def load_lookups
    @accounts = Account.visible.order(:name)
    @categories = Category.active.by_sort_order
    @tags = Tag.alphabetically
    @transaction_types = Transaction::TYPES.map { |t| [ t_display(t), t ] }
  end

  def t_display(type)
    {
      "INCOME" => "收入",
      "EXPENSE" => "支出",
      "TRANSFER" => "转账",
      "ADVANCE" => "预支",
      "REIMBURSE" => "报销"
    }[type] || type
  end

  def build_transaction
    attrs = transaction_params

    # 处理标签
    tag_ids = attrs.delete(:tag_ids) || []
    transaction = Transaction.new(attrs)
    transaction.tag_ids = tag_ids.reject(&:blank?).map(&:to_i)
    transaction
  end

  def transaction_params
    params.require(:transaction).permit(
      :date, :type, :amount, :currency,
      :category_id, :account_id, :target_account_id,
      :note, :link_id,
      tag_ids: []
    )
  end

  def handle_successful_save(message)
    respond_to do |format|
      format.html { redirect_to transactions_path, notice: message }
      format.turbo_stream { redirect_to transactions_path, notice: message }
    end
  end

  def calculate_summary(transactions)
    {
      total_income: transactions.income.sum(:amount),
      total_expense: transactions.expense.sum(:amount),
      transfer_count: transactions.transfers.count,
      count: transactions.count
    }
  end
end
