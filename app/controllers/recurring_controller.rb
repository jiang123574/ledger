class RecurringController < ApplicationController
  include OperationLoggable

  def index
    @recurring = RecurringTransaction.includes(:account, :category).order(:next_date)
    @accounts = Account.visible.order(:name)
    @categories = Category.active.by_sort_order
  end

  def create
    @recurring = RecurringTransaction.new(recurring_params)
    if @recurring.save
      redirect_to recurring_index_path, notice: "定期交易已创建"
    else
      redirect_to recurring_index_path, alert: @recurring.errors.full_messages.join(", ")
    end
  end

  def update
    @recurring = RecurringTransaction.find(params[:id])
    if @recurring.update(recurring_params)
      redirect_to recurring_index_path, notice: "定期交易已更新"
    else
      redirect_to recurring_index_path, alert: @recurring.errors.full_messages.join(", ")
    end
  end

  def destroy
    @recurring = RecurringTransaction.find(params[:id])
    @recurring.destroy
    redirect_to recurring_index_path, notice: "定期交易已删除"
  end

  def execute
    @recurring = RecurringTransaction.find(params[:id])
    transaction = @recurring.create_transaction

    # 记录执行操作
    OperationLog.log_execute(@recurring, result: transaction, request: request,
                              description: "执行定期交易 #{@recurring.note || @recurring.id}")

    redirect_to recurring_index_path, notice: "交易已生成"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to recurring_index_path, alert: "创建失败: #{e.message}"
  rescue => e
    redirect_to recurring_index_path, alert: "执行失败: #{e.message}"
  end

  private

  def recurring_params
    params.require(:recurring_transaction).permit(
      :transaction_type, :amount, :currency, :category_id, :account_id,
      :note, :frequency, :next_date, :is_active
    )
  end
end
