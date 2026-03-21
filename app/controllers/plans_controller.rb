class PlansController < ApplicationController
  before_action :set_plan, only: [ :edit, :update, :destroy, :execute ]

  def index
    @plans = Plan.includes(:account).order(:name)
    @active_plans = @plans.select(&:active?)
    @completed_plans = @plans.reject(&:active?)
  end

  def show
    @plan = Plan.includes(:account).find(params[:id])
  end

  def new
    @plan = Plan.new(
      type: Plan::ONE_TIME,
      currency: "CNY",
      day_of_month: 1,
      installments_total: 1,
      installments_completed: 0,
      active: true
    )
    @accounts = Account.order(:name)
  end

  def create
    @plan = Plan.new(plan_params)

    # Calculate amount from total for installment plans
    if @plan.type == Plan::INSTALLMENT && @plan.total_amount.present? && @plan.installments_total.present?
      @plan.amount = @plan.total_amount / @plan.installments_total
    end

    if @plan.save
      redirect_to plans_path, notice: "计划已创建"
    else
      @accounts = Account.order(:name)
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @accounts = Account.order(:name)
  end

  def update
    if @plan.update(plan_params)
      # Recalculate amount for installment plans
      if @plan.type == Plan::INSTALLMENT && @plan.total_amount.present? && @plan.installments_total.present?
        @plan.update(amount: @plan.total_amount / @plan.installments_total)
      end
      
      redirect_to plans_path, notice: "计划已更新"
    else
      @accounts = Account.order(:name)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @plan.destroy
    redirect_to plans_path, notice: "计划已删除"
  end

  def execute
    if @plan.account.blank?
      redirect_to plans_path, alert: "计划需要关联账户才能执行"
      return
    end

    if @plan.type == Plan::INSTALLMENT && @plan.completed?
      redirect_to plans_path, alert: "该分期计划已完成"
      return
    end

    transaction = @plan.generate_transaction!

    if transaction
      redirect_to transaction_path(transaction), notice: "计划已执行，交易已创建"
    else
      redirect_to plans_path, alert: "计划执行失败"
    end
  end

  private

  def set_plan
    @plan = Plan.find(params[:id])
  end

  def plan_params
    params.require(:plan).permit(
      :name, :type, :amount, :currency, :total_amount,
      :installments_total, :installments_completed,
      :account_id, :day_of_month, :active, :last_generated
    )
  end
end