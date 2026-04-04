class SingleBudgetsController < ApplicationController
  before_action :set_single_budget, only: %i[show edit update destroy start complete cancel]

  def index
    @status = params[:status]
    @single_budgets = SingleBudget.by_status(@status).order(start_date: :desc)

    @total_budget = @single_budgets.sum(:total_amount)
    @total_spent = @single_budgets.sum(:spent_amount)
  end

  def show
    @budget_items = @single_budget.budget_items.order(created_at: :desc)
  end

  def new
    @single_budget = SingleBudget.new
  end

  def create
    @single_budget = SingleBudget.new(single_budget_params)
    if @single_budget.save
      @single_budget.recalculate_spent_amount
      CacheBuster.bump(:budgets)
      redirect_to single_budgets_path, notice: "单次预算已创建"
    else
      redirect_to single_budgets_path, alert: @single_budget.errors.full_messages.join(", ")
    end
  end

  def edit
  end

  def update
    if @single_budget.update(single_budget_params)
      @single_budget.recalculate_spent_amount
      CacheBuster.bump(:budgets)
      redirect_to single_budgets_path, notice: "单次预算已更新"
    else
      redirect_to single_budgets_path, alert: @single_budget.errors.full_messages.join(", ")
    end
  end

  def destroy
    @single_budget.destroy
    CacheBuster.bump(:budgets)
    redirect_to single_budgets_path, notice: "单次预算已删除"
  end

  def start
    @single_budget.start!
    CacheBuster.bump(:budgets)
    redirect_to @single_budget, notice: "预算已启动"
  end

  def complete
    @single_budget.complete!
    CacheBuster.bump(:budgets)
    redirect_to @single_budget, notice: "预算已完成"
  end

  def cancel
    @single_budget.cancel!
    CacheBuster.bump(:budgets)
    redirect_to @single_budget, notice: "预算已取消"
  end

  private

  def set_single_budget
    @single_budget = SingleBudget.find(params[:id])
  end

  def single_budget_params
    params.require(:single_budget).permit(:name, :description, :total_amount, :start_date, :end_date, :status, :currency, :category_id)
  end
end
