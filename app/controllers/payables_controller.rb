class PayablesController < ApplicationController
  before_action :set_payable, only: %i[show update destroy settle revert]
  before_action :check_not_settled, only: %i[update destroy]

  def index
    @unsettled = Payable.where(settled_at: nil).includes(:counterparty, :account, :source_entry, source_entry: :account).order(date: :desc)
    @settled = Payable.where.not(settled_at: nil).includes(:counterparty, :account, :source_entry, source_entry: :account).order(date: :desc)
    @payables = Payable.includes(:counterparty, :account, :source_entry, source_entry: :account).order(date: :desc)
    @selected_counterparty_id = params[:counterparty_id].presence
    @filtered_unsettled = filter_by_counterparty(@unsettled, @selected_counterparty_id).includes(:source_entry, source_entry: :account)
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
      source_entry = create_entry(
        account_id: @payable.account_id,
        amount: @payable.original_amount.to_d,
        date: @payable.date,
        name: "[待付款] #{@payable.description}",
        kind: "income",
        category_id: category_id,
        notes: nil
      )

      # 建立 source_entry_id 关联并锁定源交易
      if source_entry
        @payable.update!(source_entry_id: source_entry.id)
        source_entry.lock_attribute!(:amount)
        source_entry.lock_attribute!(:date)
        source_entry.lock_attribute!(:account_id)
        source_entry.entryable&.lock_attr!(:category_id) if source_entry.entryable.respond_to?(:lock_attr!)
      end

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
    @settlement_date = params[:settlement_date].present? ? Date.parse(params[:settlement_date]) : Date.current

    if @settle_amount <= 0 || @account_id.blank?
      redirect_to payables_path, alert: "请输入有效金额和账户"
      return
    end

    ActiveRecord::Base.transaction do
      category_id = resolve_category_id(@payable.category, kind: "expense")

      # 创建支出 Entry（付款）
      payment_entry = create_entry(
        account_id: @account_id,
        amount: -@settle_amount,
        date: @settlement_date,
        name: "[付款] #{@payable.description}",
        kind: "expense",
        category_id: category_id
      )

      # 锁定付款条目的关键字段
      if payment_entry
        payment_entry.lock_attribute!(:amount)
        payment_entry.lock_attribute!(:date)
        payment_entry.lock_attribute!(:account_id)
        payment_entry.entryable&.lock_attr!(:category_id) if payment_entry.entryable.respond_to?(:lock_attr!)
      end

      new_remaining = @payable.remaining_amount - @settle_amount
      @payable.update!(
        remaining_amount: new_remaining,
        settled_at: new_remaining <= 0 ? @settlement_date : nil
      )
    end

    redirect_to payables_path, notice: "付款成功"
  end

  def revert
    ActiveRecord::Base.transaction do
      # 删除相关的付款支出交易
      payment_entries = find_payment_entries
      payment_entries.each(&:destroy!)

      # 删除源交易（待付款记录）
      source_entry = find_source_entry
      source_entry&.destroy!

      # 恢复应付款状态
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

  def find_payment_entries
    Entry.transactions_only
      .with_entryable_transaction
      .where(entryable_transactions: { kind: "expense" })
      .where("entries.name LIKE ?", "%[付款] #{@payable.description}%")
      .where(account_id: @payable.account_id)
  end

  def find_source_entry(previous_attrs = nil)
    # 首先尝试通过 source_entry_id FK 查找
    return @payable.source_entry if @payable.source_entry_id.present?

    # 回退：通过属性匹配查找
    scope = Entry.transactions_only
      .with_entryable_transaction
      .where(entryable_transactions: { kind: "income" })

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
      notes: nil
    )
    return unless source_entry.entryable.is_a?(Entryable::Transaction)

    source_entry.entryable.update!(
      kind: "income",
      category_id: category_id
    )

    # 更新 source_entry_id
    @payable.update!(source_entry_id: source_entry.id) unless @payable.source_entry_id == source_entry.id
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
