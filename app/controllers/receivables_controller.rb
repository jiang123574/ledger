class ReceivableCreationError < StandardError; end

class ReceivablesController < ApplicationController
  before_action :set_receivable, only: %i[show update destroy settle revert]
  before_action :check_not_settled, only: %i[update destroy]

  def index
    @unsettled = Receivable.where(settled_at: nil).order(date: :desc).includes(:counterparty)
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

    # 清除缓存，确保账户余额及时更新
    # 注意：bump 放在 transaction 外，避免事务回滚时浪费 cache 写入
    CacheBuster.bump(:entries)
    CacheBuster.bump(:accounts)

    redirect_to receivables_path, notice: "应收款已创建"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to receivables_path, alert: e.record.errors.full_messages.join(", ")
  rescue ReceivableCreationError => e
    redirect_to receivables_path, alert: e.message
  end

  def update
    old_account_id = @receivable.account_id

    ActiveRecord::Base.transaction do
      @receivable.update!(receivable_params)

      # 更新创建应收款时的转账记录
      if @receivable.transfer_id.present?
        # 检查是否选择了系统账户（应收款账户）
        receivable_account = Account.find_by(name: SystemAccountSyncService::RECEIVABLE_ACCOUNT_NAME)
        if receivable_account && @receivable.account_id == receivable_account.id
          # 如果选择了系统账户，删除转账记录
          Entry.where(transfer_id: @receivable.transfer_id).each(&:destroy!)
          @receivable.update!(transfer_id: nil)
        else
          # 更新转账金额、描述和日期
          transfer_note = "创建应收款 #{@receivable.description}"

          Entry.where(transfer_id: @receivable.transfer_id).find_each do |entry|
            # 根据 entry 的正负号设置金额
            new_amount = entry.amount < 0 ? -@receivable.original_amount.to_d : @receivable.original_amount.to_d

            updates = {
              amount: new_amount,
              name: transfer_note,
              notes: transfer_note,
              date: @receivable.date
            }

            # 如果账户发生变化，更新转出账户的 entry
            if old_account_id != @receivable.account_id && entry.amount < 0
              updates[:account_id] = @receivable.account_id
            end

            entry.update!(updates)
          end
        end
      end
    end

    # 清除缓存，确保账户余额及时更新
    # 注意：bump 放在 transaction 外，避免事务回滚时浪费 cache 写入
    # 如果事务成功后 crash 导致 cache 未 bump，下次请求会重新计算，可接受
    CacheBuster.bump(:entries)
    CacheBuster.bump(:accounts)

    redirect_to receivables_path, notice: "应收款已更新"
  rescue ActiveRecord::RecordInvalid
    redirect_to receivables_path, alert: @receivable.errors.full_messages.join(", ")
  end

  def destroy
    ActiveRecord::Base.transaction do
      cleanup_transfer_entries
      @receivable.destroy!
    end

    # 清除缓存，确保账户余额及时更新
    # 注意：bump 放在 transaction 外，避免事务回滚时浪费 cache 写入
    CacheBuster.bump(:entries)
    CacheBuster.bump(:accounts)

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

    ActiveRecord::Base.transaction do
      create_transfer_from_receivable_account

      new_remaining = [ @receivable.remaining_amount - @settle_amount, 0 ].max
      @receivable.update!(
        remaining_amount: new_remaining,
        settled_at: new_remaining <= 0 ? @settlement_date : nil
      )
    end

    # 清除缓存，确保账户余额及时更新
    # 注意：bump 放在 transaction 外，避免事务回滚时浪费 cache 写入
    CacheBuster.bump(:entries)
    CacheBuster.bump(:accounts)

    redirect_to receivables_path, notice: "报销成功"
  end

  def revert
    ActiveRecord::Base.transaction do
      cleanup_reimbursement_transfers

      @receivable.update!(
        remaining_amount: @receivable.original_amount,
        settled_at: nil
      )
    end

    # 清除缓存，确保账户余额及时更新
    # 注意：bump 放在 transaction 外，避免事务回滚时浪费 cache 写入
    CacheBuster.bump(:entries)
    CacheBuster.bump(:accounts)

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
      Entry.where(transfer_id: @receivable.transfer_id).each(&:destroy!)
    end

    # 删除所有报销转账
    cleanup_reimbursement_transfers
  end

  def cleanup_reimbursement_transfers
    ids = @receivable.reimbursement_transfer_ids
    ids.each do |transfer_id|
      Entry.where(transfer_id: transfer_id.to_s).each(&:destroy!)
    end
    @receivable.update!(reimbursement_transfer_ids: [])
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
