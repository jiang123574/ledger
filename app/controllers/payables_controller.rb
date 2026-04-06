class PayablesController < ApplicationController
  before_action :set_payable, only: %i[show update destroy settle revert]
  before_action :check_not_settled, only: %i[update destroy]

  def index
    @payables = Payable.includes(:counterparty, :account).order(date: :desc)
    @unsettled = @payables.where(settled_at: nil)
    @settled = @payables.where.not(settled_at: nil)
    @selected_counterparty_id = params[:counterparty_id].presence
    @filtered_unsettled = filter_by_counterparty(@unsettled, @selected_counterparty_id)
    @unsettled_counterparty_stats = build_counterparty_stats(@unsettled)
    @payable = Payable.new(date: Date.today)
    @accounts = Account.visible.order(:name)
    @expense_categories = Category.expense.active.by_sort_order.includes(:parent)
    @counterparties = Counterparty.ordered
  end

  def show; end

  def create
    @payable = Payable.new(payable_params)
    @payable.remaining_amount = @payable.original_amount

    if @payable.save
      category_id = resolve_category_id(@payable.category, kind: "income")

      # 自动创建收入 Entry（待付款负债登记）
      create_entry(
        account_id: @payable.account_id,
        amount: @payable.original_amount.to_d,
        date: @payable.date,
        name: "[待付款] #{@payable.description}",
        kind: 'income',
        category_id: category_id,
        notes: source_entry_note_for(@payable.id)
      )
      redirect_to payables_path, notice: "应付款已创建"
    else
      redirect_to payables_path, alert: @payable.errors.full_messages.join(", ")
    end
  end

  def update
    previous_attrs = {
      description: @payable.description,
      date: @payable.date,
      original_amount: @payable.original_amount,
      account_id: @payable.account_id
    }

    ActiveRecord::Base.transaction do
      @payable.update!(payable_params)
      sync_source_entry!(previous_attrs)
    end

    redirect_to payables_path, notice: "应付款已更新"
  rescue ActiveRecord::RecordInvalid
    redirect_to payables_path, alert: @payable.errors.full_messages.join(", ")
  end

  def destroy
    ActiveRecord::Base.transaction do
      source_entry = find_source_entry
      source_entry&.destroy!
      @payable.destroy!
    end

    redirect_to payables_url, notice: "应付款已删除"
  rescue ActiveRecord::RecordInvalid
    redirect_to payables_path, alert: "应付款删除失败"
  end

  def settle
    @settle_amount = params[:amount].to_d
    @account_id = params[:account_id]

    if @settle_amount <= 0 || @account_id.blank?
      redirect_to payables_path, alert: "请输入有效金额和账户"
      return
    end

    ActiveRecord::Base.transaction do
      category_id = resolve_category_id(@payable.category, kind: "expense")

      # 创建支出 Entry（付款）
      create_entry(
        account_id: @account_id,
        amount: -@settle_amount,
        date: Date.current,
        name: "[付款] #{@payable.description}",
        kind: 'expense',
        category_id: category_id
      )

      new_remaining = @payable.remaining_amount - @settle_amount
      @payable.update!(
        remaining_amount: new_remaining,
        settled_at: new_remaining <= 0 ? Date.current : nil
      )
    end

    redirect_to payables_path, notice: "付款成功"
  end

  def revert
    ActiveRecord::Base.transaction do
      @payable.payment_transactions.destroy_all
      @payable.update!(
        remaining_amount: @payable.original_amount,
        settled_at: nil
      )
    end

    redirect_to payables_path, notice: "付款已撤销"
  end

  private

  def set_payable
    @payable = Payable.find(params[:id])
  end

  def check_not_settled
    if @payable.settled?
      redirect_to payables_path, alert: "已完成的付款无法修改或删除"
    end
  end

  def payable_params
    params.require(:payable).permit(
      :date, :description, :original_amount,
      :source_transaction_id, :note, :category,
      :counterparty_id, :account_id
    )
  end

  def create_entry(account_id:, amount:, date:, name:, kind:, category_id: nil, notes: nil)
    entryable = Entryable::Transaction.new(
      kind: kind,
      category_id: category_id
    )
    entryable.save(validate: false)

    Entry.create!(
      account_id: account_id,
      date: date,
      name: name,
      amount: amount,
      currency: 'CNY',
      notes: notes,
      entryable: entryable
    )
  end

  def resolve_category_id(category_name, kind:)
    return nil if category_name.blank?

    category_type = kind == "income" ? "INCOME" : "EXPENSE"
    Category.where(type: category_type).find_by(name: category_name)&.id ||
      Category.find_by(name: category_name)&.id
  end

  def source_entry_note_for(payable_id)
    "payable:#{payable_id}:source"
  end

  def find_source_entry(previous_attrs = nil)
    scope = Entry.transactions_only
      .with_entryable_transaction
      .where(entryable_transactions: { kind: "income" })

    token = source_entry_note_for(@payable.id)
    by_token = scope.where("entries.notes = ? OR entries.notes LIKE ?", token, "%#{token}%")
      .order(created_at: :desc)
      .first
    return by_token if by_token

    attrs = previous_attrs || {}
    description = attrs[:description].presence || @payable.description
    amount = attrs[:original_amount].presence || @payable.original_amount
    date = attrs[:date].presence || @payable.date
    account_id = attrs[:account_id].presence || @payable.account_id

    scope.where(
      name: "[待付款] #{description}",
      amount: amount.to_d,
      date: date,
      account_id: account_id
    ).order(created_at: :desc).first
  end

  def sync_source_entry!(previous_attrs)
    source_entry = find_source_entry(previous_attrs) || find_source_entry
    return unless source_entry

    category_id = resolve_category_id(@payable.category, kind: "income")
    source_entry.update!(
      account_id: @payable.account_id,
      date: @payable.date,
      name: "[待付款] #{@payable.description}",
      amount: @payable.original_amount.to_d,
      notes: source_entry_note_for(@payable.id)
    )
    return unless source_entry.entryable.is_a?(Entryable::Transaction)

    source_entry.entryable.update!(
      kind: "income",
      category_id: category_id
    )
  end

  def build_counterparty_stats(records)
    records.group_by { |r| counterparty_filter_token_for(r) }
      .map do |filter_value, rows|
        first = rows.first
        name = first.counterparty&.name.presence || first.counterparty.presence || "未设置联系人"
        {
          name: name,
          filter_value: filter_value,
          count: rows.size,
          amount: rows.sum { |row| row.remaining_amount.to_d }
        }
      end
      .sort_by { |s| [ -s[:amount], -s[:count], s[:name] ] }
      .first(8)
  end

  def filter_by_counterparty(scope, counterparty_id)
    return scope if counterparty_id.blank?
    return scope.where(counterparty_id: nil, counterparty: [ nil, "" ]) if counterparty_id == "none"

    if counterparty_id.start_with?("name:")
      name = counterparty_id.delete_prefix("name:")
      return scope.where(counterparty: name).or(scope.joins(:counterparty).where(counterparties: { name: name }))
    end

    normalized_id = counterparty_id.start_with?("id:") ? counterparty_id.delete_prefix("id:") : counterparty_id

    cp = Counterparty.find_by(id: normalized_id)
    return scope.none unless cp

    scope.where(counterparty_id: cp.id).or(scope.where(counterparty: cp.name))
  end

  def counterparty_filter_token_for(record)
    if record.counterparty_id.present?
      "id:#{record.counterparty_id}"
    elsif record.counterparty.present?
      "name:#{record.counterparty}"
    else
      "none"
    end
  end
end
