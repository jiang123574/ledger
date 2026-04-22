class PayableCreationError < StandardError; end

class PayablesController < ApplicationController
  before_action :set_payable, only: %i[show update destroy settle revert]
  before_action :check_not_settled, only: %i[update destroy]

  def index
    @unsettled = Payable.where(settled_at: nil).order(date: :desc).includes(:counterparty, :account)
    @settled = Payable.where.not(settled_at: nil).order(date: :desc).includes(:counterparty, :account)
    @payables = Payable.order(date: :desc).includes(:counterparty, :account)
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

    ActiveRecord::Base.transaction do
      @payable.save!
      funding_account_id = params[:funding_account_id].presence
      create_transfer_from_payable_account(funding_account_id: funding_account_id)
    end

    redirect_to payables_path, notice: "应付款已创建"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to payables_path, alert: e.record.errors.full_messages.join(", ")
  rescue PayableCreationError => e
    redirect_to payables_path, alert: e.message
  end

  def update
    ActiveRecord::Base.transaction do
      @payable.update!(payable_params)

      if @payable.transfer_id.present?
        Entry.where(transfer_id: @payable.transfer_id).update_all(
          amount: Arel.sql("CASE WHEN amount < 0 THEN -#{@payable.original_amount} ELSE #{@payable.original_amount} END")
        )
      end
    end

    redirect_to payables_path, notice: "应付款已更新"
  rescue ActiveRecord::RecordInvalid
    redirect_to payables_path, alert: @payable.errors.full_messages.join(", ")
  end

  def destroy
    ActiveRecord::Base.transaction do
      cleanup_transfer_entries
      @payable.destroy!
    end

    redirect_to payables_url, notice: "应付款已删除"
  rescue ActiveRecord::RecordInvalid
    redirect_to payables_path, alert: "应付款删除失败"
  end

  def settle
    @settle_amount = params[:amount].to_d
    @account_id = params[:account_id]
    @settlement_date = params[:settlement_date].present? ? Date.parse(params[:settlement_date]) : Date.current

    if @settle_amount <= 0 || @account_id.blank?
      redirect_to payables_path, alert: "请输入有效金额和账户"
      return
    end

    ActiveRecord::Base.transaction do
      create_payment_entries

      new_remaining = [ @payable.remaining_amount - @settle_amount, 0 ].max
      @payable.update!(
        remaining_amount: new_remaining,
        settled_at: new_remaining <= 0 ? @settlement_date : nil
      )
    end

    redirect_to payables_path, notice: "付款成功"
  end

  def revert
    ActiveRecord::Base.transaction do
      cleanup_settlement_entries

      @payable.update!(
        remaining_amount: @payable.original_amount,
        settled_at: nil
      )
    end

    redirect_to payables_path, notice: "付款已撤销"
  rescue ActiveRecord::RecordInvalid
    redirect_to payables_path, alert: "撤销付款失败"
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

  def create_transfer_from_payable_account(funding_account_id: nil)
    payable_account = Account.find_by(name: SystemAccountSyncService::PAYABLE_ACCOUNT_NAME)
    unless payable_account
      Rails.logger.warn "应付款系统账户不存在，无法创建转账"
      raise PayableCreationError, "系统账户'应付款'不存在，请先创建该账户"
    end

    to_account_id = if funding_account_id.present? && funding_account_id != @payable.account_id.to_s
                      funding_account_id
    else
                      @payable.account_id
    end

    return if to_account_id == payable_account.id

    transfer = EntryCreationService.create_transfer(
      from_account_id: payable_account.id,
      to_account_id: to_account_id,
      amount: @payable.original_amount.to_d,
      date: @payable.date,
      currency: "CNY",
      note: "创建应付款 #{@payable.description}"
    )

    @payable.update!(transfer_id: transfer) if transfer
  end

  def create_payment_entries
    payable_account = Account.find_by(name: SystemAccountSyncService::PAYABLE_ACCOUNT_NAME)
    unless payable_account
      Rails.logger.warn "应付款系统账户不存在，无法创建付款记录"
      raise PayableCreationError, "系统账户'应付款'不存在，无法付款"
    end

    expense_sort_order = Entry.where(account_id: @account_id, date: @settlement_date).maximum(:sort_order) || 0 + 1
    expense_entryable = Entryable::Transaction.create!(kind: "expense")
    expense_entry = Entry.create!(
      account_id: @account_id,
      date: @settlement_date,
      name: "付款 #{@payable.description}",
      amount: -@settle_amount,
      currency: "CNY",
      entryable: expense_entryable,
      sort_order: expense_sort_order
    )
    expense_entry.lock_attribute!(:amount)
    expense_entry.lock_attribute!(:date)
    expense_entry.lock_attribute!(:account_id)

    income_sort_order = Entry.where(account_id: payable_account.id, date: @settlement_date).maximum(:sort_order) || 0 + 1
    income_entryable = Entryable::Transaction.create!(kind: "income")
    income_entry = Entry.create!(
      account_id: payable_account.id,
      date: @settlement_date,
      name: "付款 #{@payable.description}",
      amount: @settle_amount,
      currency: "CNY",
      entryable: income_entryable,
      sort_order: income_sort_order
    )

    existing_ids = @payable.settlement_transfer_ids
    @payable.update!(settlement_transfer_ids: existing_ids + [ expense_entry.id, income_entry.id ])
  end

  def cleanup_transfer_entries
    if @payable.transfer_id.present?
      Entry.where(transfer_id: @payable.transfer_id).destroy_all
    end

    cleanup_settlement_entries
  end

  def cleanup_settlement_entries
    ids = @payable.settlement_transfer_ids
    Entry.where(id: ids).destroy_all
    @payable.update!(settlement_transfer_ids: [])
  end

  def build_counterparty_stats(records)
    records.group_by { |r| counterparty_filter_token_for(r) }
      .map do |filter_value, rows|
        first = rows.first
        name = first.counterparty&.name.presence || "未设置联系人"
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
    return scope.where(counterparty_id: nil) if counterparty_id == "none"

    normalized_id = counterparty_id.start_with?("id:") ? counterparty_id.delete_prefix("id:") : counterparty_id

    cp = Counterparty.find_by(id: normalized_id)
    return scope.none unless cp

    scope.where(counterparty_id: cp.id)
  end

  def counterparty_filter_token_for(record)
    if record.counterparty_id.present?
      "id:#{record.counterparty_id}"
    else
      "none"
    end
  end
end
