class ReceivablesController < ApplicationController
  before_action :set_receivable, only: %i[show edit update destroy settle]

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
      # 自动创建支出交易（费用）
      Transaction.create!(
        type: "EXPENSE",
        account_id: @receivable.account_id,
        amount: @receivable.original_amount,
        currency: "CNY",
        date: @receivable.date,
        note: "[待报销] #{@receivable.description}",
        category_id: @receivable.category_id
      )
      redirect_to receivables_path, notice: "应收款已创建"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @receivable.update(receivable_params)
      redirect_to receivables_path, notice: "应收款已更新"
    else
      render :edit
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
      # 创建收入交易（报销款到账）
      Transaction.create!(
        type: "INCOME",
        account_id: @account_id,
        amount: @settle_amount,
        currency: "CNY",
        date: Date.current,
        note: "[报销] #{@receivable.description}",
        receivable: @receivable
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

  private

  def set_receivable
    @receivable = Receivable.find(params[:id])
  end

  def receivable_params
    params.require(:receivable).permit(
      :date, :description, :original_amount,
      :source_transaction_id, :note, :category,
      :counterparty_id, :account_id
    )
  end
end
