class PlansController < ApplicationController
  before_action :set_plan, only: %i[update destroy execute]

  def index
    @plans = Plan.includes(:account, :category).order(:name)
    @active_plans = @plans.select(&:active?)
    @completed_plans = @plans.reject(&:active?)
    @accounts = Account.order(:name)
    @categories = Category.active.order(:name)
    @category_parent_map = Category.where(id: @categories.map(&:parent_id).compact).index_by(&:id)
  end

  def show
    @plan = Plan.includes(:account).find(params[:id])
  end

  def create
    @plan = Plan.new(plan_params)
    @plan.type ||= Plan::RECURRING
    apply_active_param(@plan)

    apply_plan_amount_logic(@plan)

    if @plan.errors.any?
      redirect_to plans_path, alert: @plan.errors.full_messages.join(", ")
      return
    end

    if @plan.save
      redirect_to plans_path, notice: t("plans.created")
    else
      redirect_to plans_path, alert: @plan.errors.full_messages.join(", ")
    end
  end

  def update
    @plan.assign_attributes(plan_params)
    apply_active_param(@plan)
    apply_plan_amount_logic(@plan, completed_installments: @plan.installments_completed.to_i)

    if @plan.errors.any?
      redirect_to plans_path, alert: @plan.errors.full_messages.join(", ")
      return
    end

    if @plan.save
      redirect_to plans_path, notice: t("plans.updated")
    else
      redirect_to plans_path, alert: @plan.errors.full_messages.join(", ")
    end
  end

  def destroy
    @plan.destroy
    redirect_to plans_path, notice: t("plans.deleted")
  end

  def execute
    if @plan.account.blank?
      redirect_to plans_path, alert: t("plans.need_account")
      return
    end

    if [ Plan::INSTALLMENT, Plan::MORTGAGE ].include?(@plan.type) && @plan.completed?
      redirect_to plans_path, alert: t("plans.already_completed")
      return
    end

    transaction = @plan.generate_transaction!

    if transaction
      redirect_to transaction_path(transaction), notice: t("plans.executed")
    else
      redirect_to plans_path, alert: t("plans.execute_failed")
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
      :account_id, :day_of_month, :active, :last_generated,
      :category_id
    )
  end

  def apply_plan_amount_logic(plan, completed_installments: 0)
    case plan.type
    when Plan::INSTALLMENT
      if plan.total_amount.present? && plan.installments_total.present?
        plan.amount = plan.total_amount / plan.installments_total
      end
    when Plan::MORTGAGE
      remaining_param = params[:remaining_periods]

      if remaining_param.present?
        remaining_periods = remaining_param.to_i
        if remaining_periods <= 0
          plan.errors.add(:base, "房贷剩余期数必须大于 0")
          return
        end

        plan.installments_total = completed_installments + remaining_periods
      end

      if plan.new_record? && plan.installments_total.to_i <= 0
        plan.errors.add(:base, "房贷剩余期数必须大于 0")
        return
      end

      if plan.amount.present? && plan.installments_total.present?
        plan.total_amount = plan.amount.to_d * plan.installments_total
      end
    end
  end

  def apply_active_param(plan)
    return unless params[:plan].is_a?(ActionController::Parameters) || params[:plan].is_a?(Hash)
    return unless params[:plan].key?(:active) || params[:plan].key?("active")

    raw = params[:plan][:active] || params[:plan]["active"]
    plan.active = active_value?(raw) ? 1 : 0
  end

  def active_value?(value)
    [ true, 1, "1", "true", "on", "yes" ].include?(value)
  end
end
