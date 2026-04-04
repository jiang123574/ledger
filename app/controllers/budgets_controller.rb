class BudgetsController < ApplicationController
  def index
    @month = params[:month] || Date.today.strftime("%Y-%m")

    ev = CacheBuster.version(:entries)
    sv = CacheBuster.version(:budgets)

    @budgets = Rails.cache.fetch("budgets/monthly/#{@month}/#{sv}", expires_in: 5.minutes) do
      Budget.for_month(@month).includes(:category).to_a
    end
    @total_budget = @budgets.sum(:amount)

    start_date = Date.parse("#{@month}-01")
    end_date = start_date.end_of_month

    budget_category_ids = @budgets.map(&:category_id).compact
    @total_spent = Rails.cache.fetch("budgets/total_spent/#{@month}/#{ev}", expires_in: 2.minutes) do
      if budget_category_ids.any?
        Entry.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
          .where(entryable_type: 'Entryable::Transaction', date: start_date..end_date)
          .where(entryable_transactions: { kind: 'expense', category_id: budget_category_ids })
          .where(transfer_id: nil)
          .sum('ABS(entries.amount)')
      else
        0
      end
    end

    # 缓存只存 IDs，预加载在缓存外做，避免 bullet 误报
    @category_ids = Rails.cache.fetch("budgets/category_ids/#{sv}", expires_in: 1.hour) do
      Category.expense.pluck(:id)
    end
    @categories = Category.where(id: @category_ids).includes(:parent)
    cv = CacheBuster.version(:categories)
    @categories_json = Rails.cache.fetch("budgets/categories_json/#{cv}", expires_in: 1.hour) do
      @categories.map { |c| { id: c.id, name: c.name, full_name: c.full_name, pinyin: PinYin.abbr(c.full_name || c.name).downcase, level: c.level || 0, parent_id: c.parent_id } }.to_json
    end

    status = params[:status]
    cache_key = "budgets/single_list/#{status}/#{sv}"
    @single_budgets = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      scope = SingleBudget.all
      scope = scope.where(status: status) if status.present?
      scope.order(start_date: :desc).pluck(:id)
    end

    # 在缓存外做完整预加载，bullet 能正确追踪
    @single_budgets = SingleBudget.where(id: @single_budgets)
      .includes(budget_items: { category: :parent })
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
    items = budget.budget_items.includes(:category).map do |item|
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
      CacheBuster.bump(:budgets)
      redirect_to budgets_path(month: @budget.month), notice: "预算已创建"
    else
      redirect_to budgets_path, alert: @budget.errors.full_messages.join(", ")
    end
  end

  def update
    @budget = Budget.find(params[:id])
    if @budget.update(budget_params)
      CacheBuster.bump(:budgets)
      redirect_to budgets_path(month: @budget.month), notice: "预算已更新"
    else
      redirect_to budgets_path, alert: @budget.errors.full_messages.join(", ")
    end
  end

  def destroy
    @budget = Budget.find(params[:id])
    @budget.destroy
    CacheBuster.bump(:budgets)
    redirect_to budgets_path, notice: "预算已删除"
  end

  private

  def budget_params
    params.require(:budget).permit(:category_id, :month, :amount, :currency)
  end
end
