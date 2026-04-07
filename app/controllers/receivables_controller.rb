class ReceivablesController < ApplicationController
  before_action :set_receivable, only: %i[show update destroy settle revert]
  before_action :check_not_settled, only: %i[update destroy]

  def index
    @unsettled = Receivable.where(settled_at: nil).order(date: :desc).includes(:counterparty, :source_entry, source_entry: :account)
    @settled = Receivable.where.not(settled_at: nil).order(date: :desc).includes(:counterparty, :source_entry, source_entry: :account)
    @receivables = Receivable.order(date: :desc).includes(:counterparty, :source_entry, source_entry: :account)
    @selected_counterparty_id = params[:counterparty_id].presence
    @filtered_unsettled = filter_by_counterparty(@unsettled, @selected_counterparty_id).includes(:source_entry, source_entry: :account)
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

    if @receivable.save
      category_id = resolve_category_id(@receivable.category, kind: "expense")

      # 自动创建支出 Entry
      source_entry = create_entry(
        account_id: @receivable.account_id,
        amount: -@receivable.original_amount.to_d,
        date: @receivable.date,
        name: "[待报销] #{@receivable.description}",
        kind: "expense",
        category_id: category_id,
        notes: nil
      )

      # 建立 source_entry_id 关联
      @receivable.update!(source_entry_id: source_entry.id) if source_entry

      # 锁定源交易的关键字段，防止随意编辑
      if source_entry
        source_entry.lock_attribute!(:amount)
        source_entry.lock_attribute!(:date)
        source_entry.lock_attribute!(:account_id)
        source_entry.entryable&.lock_attr!(:category_id) if source_entry.entryable.respond_to?(:lock_attr!)
      end

      redirect_to receivables_path, notice: "应收款已创建"
    else
      redirect_to receivables_path, alert: @receivable.errors.full_messages.join(", ")
    end
  end

  def update
    previous_attrs = {
      description: @receivable.description,
      date: @receivable.date,
      original_amount: @receivable.original_amount,
      account_id: @receivable.account_id
    }

    ActiveRecord::Base.transaction do
      @receivable.update!(receivable_params)
      sync_source_entry!(previous_attrs)
    end

    redirect_to receivables_path, notice: "应收款已更新"
  rescue ActiveRecord::RecordInvalid
    redirect_to receivables_path, alert: @receivable.errors.full_messages.join(", ")
  end

  def destroy
    ActiveRecord::Base.transaction do
      source_entry = find_source_entry
      source_entry&.destroy!
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

    reimburse_category_id = Category.where(type: "INCOME", name: "报销").first&.id

    ActiveRecord::Base.transaction do
      reimbursement_entry = create_entry(
        account_id: @account_id,
        amount: @settle_amount,
        date: @settlement_date,
        name: "[报销] #{@receivable.description}",
        kind: "income",
        category_id: reimburse_category_id
      )

      # 锁定报销条目的关键字段
      if reimbursement_entry
        reimbursement_entry.lock_attribute!(:amount)
        reimbursement_entry.lock_attribute!(:date)
        reimbursement_entry.lock_attribute!(:account_id)
        reimbursement_entry.entryable&.lock_attr!(:category_id) if reimbursement_entry.entryable.respond_to?(:lock_attr!)
      end

      # 更新应收款余额
      new_remaining = [ @receivable.remaining_amount - @settle_amount, 0 ].max
      @receivable.update!(
        remaining_amount: new_remaining,
        settled_at: new_remaining <= 0 ? @settlement_date : nil
      )
    end

    redirect_to receivables_path, notice: "报销成功"
  end

  def revert
    ActiveRecord::Base.transaction do
      # 删除相关的报销收入交易（匹配名称）
      reimbursement_entries = find_reimbursement_entries
      reimbursement_entries.each(&:destroy!)

      # 保留源交易（待报销记录）。撤销报销应只移除报销相关的收入条目，保留原始支出记录。
      # 恢复应收款状态为初始状态（未报销）
      @receivable.update!(
        remaining_amount: @receivable.original_amount,
        settled_at: nil
      )
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

  def create_entry(account_id:, amount:, date:, name:, kind:, category_id: nil, notes: nil)
    # 获取该账户该日期的下一个 sort_order
    max_order = Entry.where(account_id: account_id, date: date).maximum(:sort_order) || 0
    sort_order = max_order + 1

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
      currency: "CNY",
      notes: notes,
      entryable: entryable,
      sort_order: sort_order
    )
  end

  def resolve_category_id(category_name, kind:)
    return nil if category_name.blank?

    category_type = kind == "income" ? "INCOME" : "EXPENSE"
    Category.where(type: category_type).find_by(name: category_name)&.id ||
      Category.find_by(name: category_name)&.id
  end

  def find_source_entry(previous_attrs = nil)
    # 首先尝试通过 source_entry_id FK 查找
    return @receivable.source_entry if @receivable.source_entry_id.present?

    # 回退：通过属性匹配查找
    scope = Entry.transactions_only
      .with_entryable_transaction
      .where(entryable_transactions: { kind: "expense" })

    attrs = previous_attrs || {}
    description = attrs[:description].presence || @receivable.description
    amount = attrs[:original_amount].presence || @receivable.original_amount
    date = attrs[:date].presence || @receivable.date
    account_id = attrs[:account_id].presence || @receivable.account_id

    scope.where(
      name: "[待报销] #{description}",
      amount: -amount.to_d,
      date: date,
      account_id: account_id
    ).order(created_at: :desc).first
  end

  def sync_source_entry!(previous_attrs)
    source_entry = find_source_entry(previous_attrs) || find_source_entry
    return unless source_entry

    category_id = resolve_category_id(@receivable.category, kind: "expense")
    source_entry.update!(
      account_id: @receivable.account_id,
      date: @receivable.date,
      name: "[待报销] #{@receivable.description}",
      amount: -@receivable.original_amount.to_d,
      notes: nil
    )
    return unless source_entry.entryable.is_a?(Entryable::Transaction)

    source_entry.entryable.update!(
      kind: "expense",
      category_id: category_id
    )

    # 更新 source_entry_id
    @receivable.update!(source_entry_id: source_entry.id) unless @receivable.source_entry_id == source_entry.id

    # 再次锁定关键字段
    source_entry.lock_attribute!(:amount)
    source_entry.lock_attribute!(:date)
    source_entry.lock_attribute!(:account_id)
    source_entry.entryable&.lock_attr!(:category_id) if source_entry.entryable.respond_to?(:lock_attr!)
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

  def find_reimbursement_entries
    Entry.transactions_only
      .with_entryable_transaction
      .where(entryable_transactions: { kind: "income" })
      .where("entries.name LIKE ?", "%[报销] #{@receivable.description}%")
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
