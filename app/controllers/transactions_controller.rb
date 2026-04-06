# frozen_string_literal: true

class TransactionsController < ApplicationController
  include EntryableActions

  before_action :set_entry, only: [:edit, :update, :destroy]
  before_action :load_lookups, only: [:edit, :create, :update]

  # GET /transactions — 301 重定向到 accounts
  def index
    redirect_to accounts_path(request.query_parameters), status: :moved_permanently
  end

  def edit
    render :edit_modal, layout: false if request.xhr?
  end

  def create
    attrs = transaction_params
    type = attrs[:type]
    account_id = attrs[:account_id]
    target_account_id = attrs[:target_account_id]
    amount = attrs[:amount].to_d
    date = attrs[:date]
    currency = attrs[:currency] || "CNY"
    note = attrs[:note]
    category_id = attrs[:category_id]

    # 如果有分类且非转账，从分类推断收支类型（防止前端 type 与分类不匹配）
    if type != "TRANSFER" && category_id.present?
      category = Category.find_by(id: category_id)
      type = category&.category_type || type
    end

    if type == "TRANSFER"
      create_transfer_entry(account_id, target_account_id, amount, date, currency, note)
    elsif create_expense_with_funding_transfer?
      create_with_funding_transfer
    else
      create_regular_entry(type, account_id, amount, date, currency, note, category_id)
    end
  end

  def update
    update_entry
    expire_entries_cache
    handle_successful_save("交易已更新")
  rescue ActiveRecord::RecordInvalid
    handle_save_error(@entry, @entry.entryable)
  end

  def destroy
    @entry&.destroy
    expire_entries_cache
    redirect_to accounts_path(filter_params), notice: "交易已删除"
  end

  def bulk_destroy
    ids = params[:ids].presence
    if ids
      count = Entry.where(id: ids).destroy_all.size
      redirect_to accounts_path(filter_params), notice: "已删除 #{count} 笔交易"
    else
      redirect_to accounts_path(filter_params), alert: "请选择要删除的交易"
    end
  end

  private

  def create_regular_entry(type, account_id, amount, date, currency, note, category_id)
    EntryCreationService.create_regular(
      type: type, account_id: account_id, amount: amount,
      date: date, currency: currency, note: note, category_id: category_id
    )
    expire_entries_cache
    handle_successful_save("交易已创建")
  rescue ActiveRecord::RecordInvalid => e
    handle_save_error(e.record)
  end

  def create_transfer_entry(from_account_id, to_account_id, amount, date, currency, note)
    EntryCreationService.create_transfer(
      from_account_id: from_account_id, to_account_id: to_account_id,
      amount: amount, date: date, currency: currency, note: note
    )
    expire_entries_cache
    handle_successful_save("转账已创建")
  rescue ActiveRecord::RecordInvalid => e
    handle_save_error(e.record)
  rescue ActiveRecord::RecordNotFound
    handle_save_error_with_message("账户不存在")
  end

  def create_with_funding_transfer
    attrs = transaction_params

    EntryCreationService.create_with_funding_transfer(
      funding_account_id: params[:funding_account_id],
      destination_account_id: attrs[:account_id],
      amount: attrs[:amount].to_d,
      date: attrs[:date],
      currency: attrs[:currency] || "CNY",
      note: attrs[:note],
      category_id: attrs[:category_id]
    )

    expire_entries_cache
    handle_successful_save("交易已创建（已自动补记资金来源转账）")
  rescue ActiveRecord::RecordInvalid => e
    handle_save_error(e.record)
  rescue ActiveRecord::RecordNotFound
    handle_save_error_with_message("资金来源账户不存在")
  end

  def set_entry
    @entry = Entry.includes(:entryable, :account, entryable: { category: :parent }).find_by(id: params[:id])
    raise ActiveRecord::RecordNotFound unless @entry
    # 预加载转账配对账户信息
    Entry.preload_transfer_accounts([@entry]) if @entry.transfer_id.present?
  end

  def set_new_transaction
    @entries = Entry.transactions_only.non_transfers.reverse_chronological.includes(:account, :entryable).limit(50)
    @accounts = Account.visible.order(:name)
    @categories = Category.active.by_sort_order
    @new_transaction = OpenStruct.new(
      type: "EXPENSE", persisted?: false,
      model_name: ActiveModel::Name.new(Entry, nil, 'transaction')
    )
  end

  def update_entry
    attrs = transaction_params

    @entry.date = attrs[:date] if attrs[:date].present?
    @entry.name = attrs[:note] if attrs[:note].present?
    @entry.notes = attrs[:note] if attrs[:note].present?
    @entry.account_id = attrs[:account_id] if attrs[:account_id].present?

    if attrs[:type].present?
      kind = attrs[:type].downcase
      amount = attrs[:amount].to_d
      @entry.amount = kind == 'income' ? amount : -amount
    end

    if @entry.entryable.is_a?(Entryable::Transaction)
      @entry.entryable.kind = attrs[:type].downcase if attrs[:type].present?
      @entry.entryable.category_id = attrs[:category_id] if attrs[:category_id].present?
      @entry.entryable.save!
    end

    # 转账：同步更新配对 Entry
    if @entry.transfer_id.present? && attrs[:target_account_id].present?
      target_account = Account.find_by(id: attrs[:target_account_id])
      if target_account
        paired_entry = Entry.where(transfer_id: @entry.transfer_id).where.not(id: @entry.id).first
        if paired_entry
          paired_entry.update!(
            account_id: target_account.id,
            date: @entry.date,
            amount: attrs[:amount].to_d,
            notes: @entry.notes
          )
        end
      end
    end

    @entry.save!
  end

  def load_lookups
    @accounts = Account.visible.order(:name)
    @categories = Category.active.by_sort_order.includes(:parent)
    @tags = Tag.alphabetically
    @transaction_types = TransactionTypeDisplay::TYPE_LABELS.map { |t, label| [label, t] }
  end

  def t_display(type)
    TransactionTypeDisplay.label(type)
  end

  def create_expense_with_funding_transfer?
    params.dig(:transaction, :type) == "EXPENSE" &&
      params[:funding_account_id].present? &&
      params.dig(:transaction, :account_id).present? &&
      params[:funding_account_id].to_s != params.dig(:transaction, :account_id).to_s
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

  def filter_params
    params.permit(:account_id, :search, :type, :period_type, :period_value, category_ids: [])
  end

  # 覆盖 concern 中的 continue_entry_redirect_url，使用 transactions 专有参数名
  def continue_entry_redirect_url
    super(continue_param: "open_new_transaction")
  end
end
