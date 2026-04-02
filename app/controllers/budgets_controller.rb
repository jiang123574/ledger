class BudgetsController < ApplicationController
  before_action :set_no_cache, only: [:index, :data]

  def index
    @month = params[:month] || Date.today.strftime("%Y-%m")
    @budgets = Budget.for_month(@month).includes(:category)
    @categories = Category.order(:name)
    @total_budget = @budgets.sum(:amount)

    start_date = Date.parse("#{@month}-01")
    end_date = start_date.end_of_month
    @total_spent = Entry.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
      .where(entryable_type: 'Entryable::Transaction', date: start_date..end_date)
      .where(entryable_transactions: { kind: 'expense' })
      .sum('ABS(entries.amount)')

    @single_budgets = SingleBudget.all
    @single_budgets = @single_budgets.where(status: params[:status]) if params[:status].present?
    @single_budgets = @single_budgets.order(start_date: :desc)
    @single_total_budget = @single_budgets.sum(:total_amount)
    @single_total_spent = @single_budgets.sum(:spent_amount)

    @selected_budget = if params[:selected_id].present?
      @single_budgets.find_by(id: params[:selected_id])
    elsif @single_budgets.any?
      @single_budgets.first
    end
  end

  def data
    budget = SingleBudget.find(params[:id])
    items = budget.budget_items.map do |item|
      {
        id: item.id,
        name: item.display_name,
        amount: item.amount.to_f,
        spent_amount: item.spent_amount.to_f,
        formatted_amount: format_currency(item.amount),
        formatted_spent: format_currency(item.spent_amount),
        currency_symbol: "¥",
        category_id: item.category_id,
        category_name: item.category&.full_name || "",
        notes: item.notes || ""
      }
    end
    total = budget.budget_items.sum(:amount)
    render json: {
      id: budget.id,
      name: budget.name,
      total_amount: total.to_f,
      spent_amount: budget.spent_amount.to_f,
      formatted_total: format_currency(total),
      formatted_spent: format_currency(budget.spent_amount),
      currency_symbol: "¥",
      items: items
    }
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

  def set_no_cache
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate'
  end

  def budget_params
    params.require(:budget).permit(:category_id, :month, :amount, :currency)
  end
end
