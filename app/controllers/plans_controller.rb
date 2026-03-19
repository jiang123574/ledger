class PlansController < ApplicationController
  def index
    @plans = Plan.includes(:account).order(:name)
  end

  def new
    @plan = Plan.new
    @accounts = Account.order(:name)
  end

  def create
    @plan = Plan.new(plan_params)
    if @plan.save
      redirect_to plans_path, notice: "计划已创建"
    else
      @accounts = Account.order(:name)
      render :new
    end
  end

  def edit
    @plan = Plan.find(params[:id])
    @accounts = Account.order(:name)
  end

  def update
    @plan = Plan.find(params[:id])
    if @plan.update(plan_params)
      redirect_to plans_path, notice: "计划已更新"
    else
      @accounts = Account.order(:name)
      render :edit
    end
  end

  def destroy
    @plan = Plan.find(params[:id])
    @plan.destroy
    redirect_to plans_path, notice: "计划已删除"
  end

  private

  def plan_params
    params.require(:plan).permit(
      :name, :account_type, :amount, :currency, :total_amount,
      :installments_total, :installments_completed,
      :account_id, :day_of_month, :active, :last_generated
    )
  end
end
