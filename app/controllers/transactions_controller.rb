# frozen_string_literal: true

class TransactionsController < ApplicationController
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy ]
  before_action :load_lookups, only: [ :new, :edit, :create, :update ]

  def index
    # 重定向到账户页面，并透传筛选参数
    redirect_to accounts_path(request.query_parameters)
  end

  def show
    redirect_to transactions_path
  end


  def new
    # 统一新建入口到账户页的模态框
    redirect_to accounts_path(open_new_transaction: 1)
  end

  def edit
    @transaction = Transaction.find(params[:id])
    @accounts = Account.visible.order(:name)
    @categories = Category.active.by_sort_order
  end


  def create
    if create_expense_with_funding_transfer?
      create_with_funding_transfer
      return
    end

    @transaction = build_transaction

    if @transaction.save
      handle_successful_save("交易已创建")
    else
      redirect_to transactions_path, alert: @transaction.errors.full_messages.join(", ")
    end
  end

  def update
    if @transaction.update(transaction_params)
      handle_successful_save("交易已更新")
    else
      redirect_to transactions_path, alert: @transaction.errors.full_messages.join(", ")
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

  def create_expense_with_funding_transfer?
    params.dig(:transaction, :type) == "EXPENSE" &&
      params[:funding_account_id].present? &&
      params.dig(:transaction, :account_id).present? &&
      params[:funding_account_id].to_s != params.dig(:transaction, :account_id).to_s
  end

  def create_with_funding_transfer
    attrs = transaction_params
    source_account = Account.find(params[:funding_account_id])
    destination_account = Account.find(attrs[:account_id])
    note = attrs[:note]

    Transaction.transaction do
      transfer_note = [
        "自动补记资金来源",
        source_account.name,
        "->",
        destination_account.name,
        (note.present? ? "（#{note}）" : nil)
      ].compact.join(" ")

      transfer_out = Transaction.create_transfer!(
        from_account: source_account,
        to_account: destination_account,
        amount: attrs[:amount],
        date: attrs[:date],
        note: transfer_note
      )

      @transaction = build_transaction
      @transaction.link = transfer_out
      @transaction.save!
    end

    handle_successful_save("交易已创建（已自动补记资金来源转账）")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to transactions_path, alert: e.record.errors.full_messages.join(", ")
  rescue ActiveRecord::RecordNotFound
    redirect_to transactions_path, alert: "资金来源账户不存在"
  end

  def transaction_params
    params.require(:transaction).permit(
      :date, :type, :amount, :currency, :original_amount,
      :category_id, :account_id, :target_account_id,
      :note, :link_id,
      tag_ids: [],
      files: []
    )
  end

  def handle_successful_save(message)
    if params[:continue_entry] == "1"
      return redirect_to(continue_entry_redirect_url, notice: "#{message}，请继续录入")
    end

    respond_to do |format|
      format.html { redirect_to transactions_path, notice: message }
      format.turbo_stream { redirect_to transactions_path, notice: message }
    end
  end

  def continue_entry_redirect_url
    fallback = accounts_path(open_new_transaction: 1)
    referer = request.referer
    return fallback if referer.blank?

    uri = URI.parse(referer)
    params_hash = Rack::Utils.parse_nested_query(uri.query)
    params_hash["open_new_transaction"] = "1"
    uri.query = params_hash.to_query
    uri.to_s
  rescue URI::InvalidURIError
    fallback
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
