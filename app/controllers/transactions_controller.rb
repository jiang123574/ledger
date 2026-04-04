# frozen_string_literal: true

class TransactionsController < ApplicationController
  before_action :set_transaction, only: [:show, :edit, :update, :destroy]
  before_action :load_lookups, only: [:edit, :create, :update]

  def index
    redirect_to accounts_path(request.query_parameters)
  end

  def show
    redirect_to transactions_path
  end

  def edit
    @accounts = Account.visible.order(:name)
    @categories = Category.active.by_sort_order

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

    if type == "TRANSFER"
      create_transfer_entry(account_id, target_account_id, amount, date, currency, note)
    elsif create_expense_with_funding_transfer?
      create_with_funding_transfer
    else
      create_regular_entry(type, account_id, amount, date, currency, note, category_id)
    end
  end

  def create_regular_entry(type, account_id, amount, date, currency, note, category_id)
    EntryCreationService.create_regular(
      type: type, account_id: account_id, amount: amount,
      date: date, currency: currency, note: note, category_id: category_id
    )
    expire_transactions_cache
    handle_successful_save("交易已创建")
  rescue ActiveRecord::RecordInvalid => e
    handle_save_error(e.record.errors.full_messages.join(", "))
  end

  def handle_save_error(error_message)
    respond_to do |format|
      format.json { render json: { success: false, error: error_message } }
      format.html { redirect_to accounts_path(filter_params), alert: error_message }
    end
  end

  def create_transfer_entry(from_account_id, to_account_id, amount, date, currency, note)
    EntryCreationService.create_transfer(
      from_account_id: from_account_id, to_account_id: to_account_id,
      amount: amount, date: date, currency: currency, note: note
    )
    expire_transactions_cache
    handle_successful_save("转账已创建")
  rescue ActiveRecord::RecordInvalid => e
    handle_save_error(e.record.errors.full_messages.join(", "))
  rescue ActiveRecord::RecordNotFound
    handle_save_error("账户不存在")
  end

  def update
    if update_entry
      expire_transactions_cache
      handle_successful_save("交易已更新")
    else
      redirect_to accounts_path(filter_params), alert: @entry.errors.full_messages.join(", ")
    end
  end

  def destroy
    @entry&.destroy
    expire_transactions_cache
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

  def set_transaction
    @entry = Entry.find_by(id: params[:id])
    raise ActiveRecord::RecordNotFound unless @entry

    @transaction = TransactionPresenter.from_entry(@entry)
  end

  def update_entry
    return false unless @entry

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
      @entry.entryable.save(validate: false)
    end

    @entry.save
  end

  def load_lookups
    @accounts = Account.visible.order(:name)
    @categories = Category.active.by_sort_order
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

    expire_transactions_cache
    handle_successful_save("交易已创建（已自动补记资金来源转账）")
  rescue ActiveRecord::RecordInvalid => e
    handle_save_error(e.record.errors.full_messages.join(", "))
  rescue ActiveRecord::RecordNotFound
    handle_save_error("资金来源账户不存在")
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

  def build_redirect_url
    if params[:account_id].present? || params[:period_type].present? || params[:search].present?
      accounts_path(filter_params)
    else
      referer = request.referer
      return accounts_path if referer.blank?

      begin
        uri = URI.parse(referer)
        filter_params_from_referer = Rack::Utils.parse_nested_query(uri.query).symbolize_keys
        accounts_path(filter_params_from_referer.select { |k, v| v.present? })
      rescue StandardError
        accounts_path
      end
    end
  end

  def handle_successful_save(message)
    if params[:continue_entry] == "1"
      respond_to do |format|
        format.json { render json: { success: true, message: "#{message}，请继续录入" } }
        format.html { redirect_to(continue_entry_redirect_url, notice: "#{message}，请继续录入") }
        format.turbo_stream { redirect_to(continue_entry_redirect_url, notice: "#{message}，请继续录入") }
      end
      return
    end

    redirect_url = build_redirect_url
    respond_to do |format|
      format.html { redirect_to redirect_url, notice: message }
      format.turbo_stream { redirect_to redirect_url, notice: message }
      format.json { render json: { success: true, message: message } }
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

  def expire_transactions_cache
    CacheBuster.bump(:entries)
    CacheBuster.bump(:accounts)
  end
end
