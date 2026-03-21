class EventBudgetsController < ApplicationController
  before_action :set_event_budget, only: [:show, :edit, :update, :destroy]

  def index
    @status = params[:status]
    @event_budgets = EventBudget.by_status(@status).order(start_date: :desc)
    
    @active_budgets = @event_budgets.active
    @completed_budgets = @event_budgets.completed
    @cancelled_budgets = @event_budgets.cancelled
    
    @total_budget = @event_budgets.sum(:total_amount)
    @total_spent = @event_budgets.sum(:spent_amount)
  end

  def show
    @transactions = @event_budget.transactions.order(date: :desc)
  end

  def new
    @event_budget = EventBudget.new
  end

  def create
    @event_budget = EventBudget.new(event_budget_params)
    if @event_budget.save
      redirect_to event_budgets_path, notice: "活动预算已创建"
    else
      render :new, alert: @event_budget.errors.full_messages.join(", ")
    end
  end

  def edit
  end

  def update
    if @event_budget.update(event_budget_params)
      redirect_to event_budgets_path, notice: "活动预算已更新"
    else
      render :edit, alert: @event_budget.errors.full_messages.join(", ")
    end
  end

  def destroy
    @event_budget.destroy
    redirect_to event_budgets_path, notice: "活动预算已删除"
  end

  private

  def set_event_budget
    @event_budget = EventBudget.find(params[:id])
  end

  def event_budget_params
    params.require(:event_budget).permit(:name, :description, :total_amount, :start_date, :end_date, :status, :currency)
  end
end