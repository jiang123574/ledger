class BudgetItemsController < ApplicationController
  before_action :set_single_budget
  before_action :set_budget_item, only: %i[edit update destroy]

  def new
    @budget_item = @single_budget.budget_items.new
  end

  def create
    @budget_item = @single_budget.budget_items.new(budget_item_params)
    if @budget_item.save
      @single_budget.recalculate_spent_amount
      redirect_to @single_budget, notice: "预算项已添加"
    else
      render :new, alert: @budget_item.errors.full_messages.join(", ")
    end
  end

  def edit
  end

  def update
    if @budget_item.update(budget_item_params)
      @single_budget.recalculate_spent_amount
      redirect_to @single_budget, notice: "预算项已更新"
    else
      render :edit, alert: @budget_item.errors.full_messages.join(", ")
    end
  end

  def destroy
    @budget_item.destroy
    @single_budget.recalculate_spent_amount
    redirect_to @single_budget, notice: "预算项已删除"
  end

  private

  def set_single_budget
    @single_budget = SingleBudget.find(params[:single_budget_id])
  end

  def set_budget_item
    @budget_item = @single_budget.budget_items.find(params[:id])
  end

  def budget_item_params
    params.require(:budget_item).permit(:name, :amount, :spent_amount, :category, :notes)
  end
end
