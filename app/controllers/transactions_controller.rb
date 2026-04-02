# frozen_string_literal: true

class TransactionsController < ApplicationController
  before_action :set_transaction, only: [:show, :edit, :update, :destroy]
  before_action :load_lookups, only: [:new, :edit, :create, :update]

  def index
    redirect_to accounts_path(request.query_parameters)
  end

  def show
    redirect_to transactions_path
  end

  def new
    redirect_to accounts_path(open_new_transaction: 1)
  end

  def edit
    @accounts = Account.visible.order(:name)
    @categories = Category.active.by_sort_order
    
    if request.xhr?
      render :edit_modal, layout: false
    end
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
    kind = type.downcase

    entryable = Entryable::Transaction.create!(
      kind: kind,
      category_id: category_id
    )

    entry = Entry.create!(
      account_id: account_id,
      date: date,
      name: note.presence || "#{type == 'INCOME' ? '收入' : '支出'} #{amount}",
      amount: kind == 'income' ? amount : -amount,
      currency: currency,
      notes: note,
      entryable: entryable
    )

    expire_transactions_cache
    handle_successful_save("交易已创建")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to accounts_path(filter_params), alert: e.record.errors.full_messages.join(", ")
  end

  def create_transfer_entry(from_account_id, to_account_id, amount, date, currency, note)
    from_account = Account.find(from_account_id)
    to_account = Account.find(to_account_id)

    transfer_id = SecureRandom.uuid.gsub('-', '').to_i(16) % 2_000_000_000
    transfer_note = note.presence || "转账: #{from_account.name} → #{to_account.name}"

    entry_out = Entry.create!(
      account_id: from_account_id,
      date: date,
      name: transfer_note,
      amount: -amount,
      currency: currency,
      notes: transfer_note,
      entryable: Entryable::Transaction.create!(kind: 'expense'),
      transfer_id: transfer_id
    )

    entry_in = Entry.create!(
      account_id: to_account_id,
      date: date,
      name: transfer_note,
      amount: amount,
      currency: currency,
      notes: transfer_note,
      entryable: Entryable::Transaction.create!(kind: 'income'),
      transfer_id: transfer_id
    )

    expire_transactions_cache
    handle_successful_save("转账已创建")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to accounts_path(filter_params), alert: e.record.errors.full_messages.join(", ")
  rescue ActiveRecord::RecordNotFound => e
    redirect_to accounts_path(filter_params), alert: "账户不存在"
  end

  def update
    # 更新 Entry 而非 Transaction
    if update_entry
      expire_transactions_cache
      handle_successful_save("交易已更新")
    else
      redirect_to accounts_path(filter_params), alert: @entry.errors.full_messages.join(", ")
    end
  end

  def destroy
    # 删除 Entry 而非 Transaction
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
    # 先尝试找 Entry，再 fallback 到 Transaction
    @entry = Entry.find_by(id: params[:id])
    
    if @entry
      @transaction = build_transaction_from_entry(@entry)
    else
      @transaction = Transaction.find(params[:id])
    end
  end

  def build_transaction_from_entry(entry)
    t = Transaction.new
    t.id = entry.id
    t.account_id = entry.account_id
    t.account = entry.account
    t.date = entry.date
    t.amount = entry.amount.abs
    t.currency = entry.currency
    t.note = entry.notes || entry.name
    
    if entry.transfer_id.present?
      t.type = 'TRANSFER'
    elsif entry.entryable.respond_to?(:kind)
      t.type = entry.entryable.kind.upcase
      if entry.entryable.respond_to?(:category)
        t.category = entry.entryable.category
        t.category_id = entry.entryable.category_id
      end
    end
    
    # 让这个对象表现得像一个已持久化的记录
    t.define_singleton_method(:persisted?) { true }
    t.define_singleton_method(:new_record?) { false }
    
    t
  end

  def update_entry
    return false unless @entry
    
    attrs = transaction_params
    
    # 更新 Entry
    @entry.date = attrs[:date] if attrs[:date].present?
    @entry.name = attrs[:note] if attrs[:note].present?
    @entry.notes = attrs[:note] if attrs[:note].present?
    @entry.account_id = attrs[:account_id] if attrs[:account_id].present?
    
    # 更新金额和类型
    if attrs[:type].present?
      kind = attrs[:type].downcase
      amount = attrs[:amount].to_d
      @entry.amount = kind == 'income' ? amount : -amount
    end
    
    # 更新 Entryable
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
    @transaction_types = Transaction::TYPES.map { |t| [t_display(t), t] }
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
    amount = attrs[:amount].to_d
    date = attrs[:date]
    currency = attrs[:currency] || "CNY"
    note = attrs[:note]
    category_id = attrs[:category_id]

    Entry.transaction do
      transfer_id = SecureRandom.uuid.gsub('-', '').to_i(16) % 2_000_000_000
      transfer_note = [
        "自动补记资金来源",
        source_account.name,
        "->",
        destination_account.name,
        (note.present? ? "（#{note}）" : nil)
      ].compact.join(" ")

      Entry.create!(
        account_id: source_account.id,
        date: date,
        name: transfer_note,
        amount: -amount,
        currency: currency,
        notes: transfer_note,
        entryable: Entryable::Transaction.create!(kind: 'expense'),
        transfer_id: transfer_id
      )

      Entry.create!(
        account_id: destination_account.id,
        date: date,
        name: transfer_note,
        amount: amount,
        currency: currency,
        notes: transfer_note,
        entryable: Entryable::Transaction.create!(kind: 'income'),
        transfer_id: transfer_id
      )

      expense_entryable = Entryable::Transaction.create!(
        kind: 'expense',
        category_id: category_id
      )

      Entry.create!(
        account_id: destination_account.id,
        date: date,
        name: note.presence || "支出 #{amount}",
        amount: -amount,
        currency: currency,
        notes: note,
        entryable: expense_entryable
      )
    end

    expire_transactions_cache
    handle_successful_save("交易已创建（已自动补记资金来源转账）")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to accounts_path(filter_params), alert: e.record.errors.full_messages.join(", ")
  rescue ActiveRecord::RecordNotFound
    redirect_to accounts_path(filter_params), alert: "资金来源账户不存在"
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
      rescue
        accounts_path
      end
    end
  end

  def handle_successful_save(message)
    if params[:continue_entry] == "1"
      return redirect_to(continue_entry_redirect_url, notice: "#{message}，请继续录入")
    end

    redirect_url = build_redirect_url
    respond_to do |format|
      format.html { redirect_to redirect_url, notice: message }
      format.turbo_stream { redirect_to redirect_url, notice: message }
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
    Rails.cache.delete_matched("transactions_*")
    Rails.cache.delete_matched("entries_*")
  end
end
