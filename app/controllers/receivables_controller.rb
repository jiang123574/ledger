class ReceivablesController < ApplicationController
  before_action :set_receivable, only: %i[show update destroy settle revert]
  before_action :check_not_settled, only: %i[update destroy]

  def index
    @receivables = Receivable.includes(:counterparty, :account)
      .order(date: :desc)
    @unsettled = @receivables.where(settled_at: nil)
    @settled = @receivables.where.not(settled_at: nil)
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
      create_entry(
        account_id: @receivable.account_id,
        amount: -@receivable.original_amount.to_d,
        date: @receivable.date,
        name: "[待报销] #{@receivable.description}",
        kind: 'expense',
        category_id: category_id,
        notes: source_entry_note_for(@receivable.id)
      )
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
    @receivable.destroy
    redirect_to receivables_url, notice: "应收款已删除"
  end

  def settle
    @settle_amount = params[:amount].to_d
    @account_id = params[:account_id]

    if @settle_amount <= 0 || @account_id.blank?
      redirect_to @receivable, alert: "请输入有效金额和账户"
      return
    end

    ActiveRecord::Base.transaction do
      # 创建收入 Entry（报销款到账）
      create_entry(
        account_id: @account_id,
        amount: @settle_amount,
        date: Date.current,
        name: "[报销] #{@receivable.description}",
        kind: 'income'
      )

      # 更新应收款余额
      new_remaining = @receivable.remaining_amount - @settle_amount
      @receivable.update!(
        remaining_amount: new_remaining,
        settled_at: new_remaining <= 0 ? Date.current : nil
      )
    end

    redirect_to receivables_path, notice: "报销成功"
  end

  def revert
    ActiveRecord::Base.transaction do
      # 删除相关的报销收入交易
      @receivable.reimbursement_transactions.destroy_all

      # 恢复应收款状态
      @receivable.update!(
        remaining_amount: @receivable.original_amount,
        settled_at: nil
      )
    end

    redirect_to receivables_path, notice: "报销已撤销"
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

  def source_entry_note_for(receivable_id)
    "receivable:#{receivable_id}:source"
  end

  def find_source_entry(previous_attrs = nil)
    scope = Entry.transactions_only
      .with_entryable_transaction
      .where(entryable_transactions: { kind: "expense" })

    token = source_entry_note_for(@receivable.id)
    by_token = scope.where("entries.notes = ? OR entries.notes LIKE ?", token, "%#{token}%")
      .order(created_at: :desc)
      .first
    return by_token if by_token

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
      notes: source_entry_note_for(@receivable.id)
    )
    return unless source_entry.entryable.is_a?(Entryable::Transaction)

    source_entry.entryable.update!(
      kind: "expense",
      category_id: category_id
    )
  end
end
