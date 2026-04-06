class PayablesController < ApplicationController
  before_action :set_payable, only: %i[show update destroy settle revert]
  before_action :check_not_settled, only: %i[update destroy]

  def index
    @payables = Payable.includes(:counterparty, :account).order(date: :desc)
    @unsettled = @payables.where(settled_at: nil)
    @settled = @payables.where.not(settled_at: nil)
    @payable = Payable.new(date: Date.today)
    @accounts = Account.visible.order(:name)
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
        category_id: category_id
      )
      redirect_to payables_path, notice: "应付款已创建"
    else
      redirect_to payables_path, alert: @payable.errors.full_messages.join(", ")
    end
  end

  def update
    if @payable.update(payable_params)
      redirect_to payables_path, notice: "应付款已更新"
    else
      redirect_to payables_path, alert: @payable.errors.full_messages.join(", ")
    end
  end

  def destroy
    @payable.destroy
    redirect_to payables_url, notice: "应付款已删除"
  end

  def settle
    @settle_amount = params[:amount].to_d
    @account_id = params[:account_id]

    if @settle_amount <= 0 || @account_id.blank?
      redirect_to payables_path, alert: "请输入有效金额和账户"
      return
    end

    ActiveRecord::Base.transaction do
      # 创建支出 Entry（付款）
      create_entry(
        account_id: @account_id,
        amount: -@settle_amount,
        date: Date.current,
        name: "[付款] #{@payable.description}",
        kind: 'expense'
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

  def resolve_category_id(category_name, kind:)
    return nil if category_name.blank?

    category_type = kind == "income" ? "INCOME" : "EXPENSE"
    Category.where(type: category_type).find_by(name: category_name)&.id ||
      Category.find_by(name: category_name)&.id
  end
end
