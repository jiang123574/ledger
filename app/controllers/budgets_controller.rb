class BudgetsController < ApplicationController
  def index
    @month = params[:month] || Date.today.strftime("%Y-%m")
    @budgets = Budget.for_month(@month).includes(:category)
    @categories = Category.order(:name)
    @total_budget = @budgets.sum(:amount)

    start_date = Date.parse("#{@month}-01")
    end_date = start_date.end_of_month
    @total_spent = Transaction.where(type: "EXPENSE", date: start_date..end_date).sum(:amount)
  end

  def create
    @budget = Budget.new(budget_params)
    if @budget.save
      redirect_to budgets_path(month: @budget.month), notice: "预算已创建"
    else
      redirect_to budgets_path, alert: @budget.errors.full_messages.join(", ")
    end
  end

  def update
    @budget = Budget.find(params[:id])
    if @budget.update(budget_params)
      redirect_to budgets_path(month: @budget.month), notice: "预算已更新"
    else
      redirect_to budgets_path, alert: @budget.errors.full_messages.join(", ")
    end
  end

  def destroy
    @budget = Budget.find(params[:id])
    @budget.destroy
    redirect_to budgets_path, notice: "预算已删除"
  end

  private

  def budget_params
    params.require(:budget).permit(:category_id, :month, :amount, :currency)
  end
end
