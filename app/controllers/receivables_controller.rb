class ReceivablesController < ApplicationController
  before_action :set_receivable, only: %i[show edit update destroy settle revert]
  before_action :check_not_settled, only: %i[edit update destroy]

  def index
    @receivables = Receivable.includes(:source_transaction, :counterparty, :account)
      .order(date: :desc)
    @unsettled = @receivables.where(settled_at: nil)
    @settled = @receivables.where.not(settled_at: nil)
    @receivable = Receivable.new(date: Date.today)
    @accounts = Account.visible.order(:name)
    @counterparties = Counterparty.ordered
  end

  def show
  end

  def new
    # 重定向到 receivables#index，使用模态框添加
    redirect_to receivables_path
  end

  def create
    @receivable = Receivable.new(receivable_params)
    @receivable.remaining_amount = @receivable.original_amount

    if @receivable.save
      # 自动创建支出 Entry
      create_entry(
        account_id: @receivable.account_id,
        amount: -@receivable.original_amount.to_d,
        date: @receivable.date,
        name: "[待报销] #{@receivable.description}",
        kind: 'expense',
        category_id: @receivable.category_id
      )
      redirect_to receivables_path, notice: "应收款已创建"
    else
      redirect_to receivables_path, alert: @receivable.errors.full_messages.join(", ")
    end
  end

  def edit
  end

  def update
    if @receivable.update(receivable_params)
      redirect_to receivables_path, notice: "应收款已更新"
    else
      redirect_to receivables_path, alert: @receivable.errors.full_messages.join(", ")
    end
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

  def create_entry(account_id:, amount:, date:, name:, kind:, category_id: nil)
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
      entryable: entryable
    )
  end
end
