class ReceivableCreationError < StandardError; end

class ReceivablesController < ApplicationController
  include OperationLoggable
  include CounterpartyFilterable

  before_action :set_receivable, only: %i[show update destroy settle revert]
  before_action :check_not_settled, only: %i[update destroy]

  def index
    @unsettled = Receivable.where(settled_at: nil).order(date: :desc).includes(:counterparty, :account)
    @settled = Receivable.where.not(settled_at: nil).order(date: :desc).includes(:counterparty)
    @receivables = Receivable.order(date: :desc).includes(:counterparty)
    @selected_counterparty_id = params[:counterparty_id].presence
    @filtered_unsettled = filter_by_counterparty(@unsettled, @selected_counterparty_id)
    @unsettled_counterparty_stats = build_counterparty_stats(@unsettled)
    @receivable = Receivable.new(date: Date.today)
    @accounts = Account.visible.order(:name)
    @expense_categories = Category.expense.active.by_sort_order.includes(:parent)
    @counterparties = Counterparty.ordered
  end

  def show
  end

  def create
    @receivable = Receivable.new(receivable_params)
    @receivable.remaining_amount = @receivable.original_amount

    ActiveRecord::Base.transaction do
      @receivable.save!
      funding_account_id = params[:funding_account_id].presence
      create_transfer_to_receivable_account(funding_account_id: funding_account_id)
    end

    redirect_to receivables_path, notice: "应收款已创建"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to receivables_path, alert: e.record.errors.full_messages.join(", ")
  rescue ReceivableCreationError => e
    redirect_to receivables_path, alert: e.message
  end

  def update
    ActiveRecord::Base.transaction do
      @receivable.update!(receivable_params)

      # 更新创建应收款时的转账金额
      if @receivable.transfer_id.present?
        amount_value = @receivable.original_amount
        quoted_amount = ActiveRecord::Base.connection.quote(amount_value)
        Entry.where(transfer_id: @receivable.transfer_id).update_all(
          amount: Arel.sql("CASE WHEN amount < 0 THEN -#{quoted_amount} ELSE #{quoted_amount} END")
        )
      end
    end

    redirect_to receivables_path, notice: "应收款已更新"
  rescue ActiveRecord::RecordInvalid
    redirect_to receivables_path, alert: @receivable.errors.full_messages.join(", ")
  end

  def destroy
    ActiveRecord::Base.transaction do
      cleanup_transfer_entries
      @receivable.destroy!
    end

    redirect_to receivables_url, notice: "应收款已删除"
  rescue ActiveRecord::RecordInvalid
    redirect_to receivables_path, alert: "应收款删除失败"
  end

  def settle
    @settle_amount = params[:amount].to_d
    @account_id = params[:account_id]
    @settlement_date = params[:settlement_date].present? ? Date.parse(params[:settlement_date]) : Date.current

    if @settle_amount <= 0 || @account_id.blank?
      redirect_to @receivable, alert: "请输入有效金额和账户"
      return
    end

    account = Account.find_by(id: @account_id)
    unless account
      redirect_to receivables_path, alert: "账户不存在"
      return
    end

    ActiveRecord::Base.transaction do
      create_transfer_from_receivable_account

      new_remaining = [ @receivable.remaining_amount - @settle_amount, 0 ].max
      @receivable.update!(
        remaining_amount: new_remaining,
        settled_at: new_remaining <= 0 ? @settlement_date : nil
      )

      # 记录结算操作
      log_settle(@receivable, amount: @settle_amount, account: account,
                 description: "报销 #{@receivable.description} ¥#{@settle_amount}")
    end

    redirect_to receivables_path, notice: "报销成功"
  end

  def revert
    ActiveRecord::Base.transaction do
      cleanup_reimbursement_transfers

      @receivable.update!(
        remaining_amount: @receivable.original_amount,
        settled_at: nil
      )

      # 记录撤销操作
      log_revert(@receivable, description: "撤销报销 #{@receivable.description}")
    end

    redirect_to receivables_path, notice: "报销已撤销"
  rescue ActiveRecord::RecordInvalid
    redirect_to receivables_path, alert: "撤销报销失败"
  end

  private

  def set_receivable
    @receivable = Receivable.find(params[:id])
  end

  def check_not_settled
    if @receivable.settled?
      redirect_to receivables_path, alert: "已完成的报销无法修改或删除"
    end
  end

  def receivable_params
    params.require(:receivable).permit(
      :date, :description, :original_amount,
      :source_transaction_id, :note, :category,
      :counterparty_id, :account_id
    )
  end

  def create_transfer_to_receivable_account(funding_account_id: nil)
    receivable_account = Account.find_by(name: SystemAccountSyncService::RECEIVABLE_ACCOUNT_NAME)
    unless receivable_account
      Rails.logger.warn "应收款系统账户不存在，无法创建转账"
      raise ReceivableCreationError, "系统账户'应收款'不存在，请先创建该账户"
    end

    from_account_id = if funding_account_id.present? && funding_account_id != @receivable.account_id.to_s
                        funding_account_id
    else
                        @receivable.account_id
    end

    return if from_account_id == receivable_account.id

    transfer = EntryCreationService.create_transfer(
      from_account_id: from_account_id,
      to_account_id: receivable_account.id,
      amount: @receivable.original_amount.to_d,
      date: @receivable.date,
      currency: "CNY",
      note: "创建应收款 #{@receivable.description}"
    )

    @receivable.update!(transfer_id: transfer) if transfer
  end

  def create_transfer_from_receivable_account
    receivable_account = Account.find_by(name: SystemAccountSyncService::RECEIVABLE_ACCOUNT_NAME)
    unless receivable_account
      Rails.logger.warn "应收款系统账户不存在，无法创建报销转账"
      raise ReceivableCreationError, "系统账户'应收款'不存在，无法报销"
    end

    transfer = EntryCreationService.create_transfer(
      from_account_id: receivable_account.id,
      to_account_id: @account_id,
      amount: @settle_amount,
      date: @settlement_date,
      currency: "CNY",
      note: "报销 #{@receivable.description}"
    )

    if transfer
      # 支持多次部分报销：用逗号分隔存储多个 transfer_id
      existing_ids = @receivable.reimbursement_transfer_ids
      new_ids = existing_ids + [ transfer ]
      @receivable.update!(reimbursement_transfer_ids: new_ids)
    end
  end

  def cleanup_transfer_entries
    # 删除创建应收款时的转账
    if @receivable.transfer_id.present?
      Entry.where(transfer_id: @receivable.transfer_id).destroy_all
    end

    # 删除所有报销转账
    cleanup_reimbursement_transfers
  end

  def cleanup_reimbursement_transfers
    ids = @receivable.reimbursement_transfer_ids
    ids.each do |transfer_id|
      Entry.where(transfer_id: transfer_id).destroy_all
    end
    @receivable.update!(reimbursement_transfer_ids: [])
  end
end
