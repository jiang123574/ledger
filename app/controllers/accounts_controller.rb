class AccountsController < ApplicationController
  before_action :set_account, only: [ :show, :edit, :update, :destroy ]

  def index
    @accounts = Rails.cache.fetch("accounts_list", expires_in: 10.minutes) do
      Account.order(:sort_order, :name).to_a
    end
    
    @categories = Rails.cache.fetch("categories_active", expires_in: 1.hour) do
      Category.active.by_sort_order.to_a
    end

    period_type = params[:period_type].presence || "month"
    period_value = params[:period_value].presence || default_period_value(period_type)

    @transactions = Transaction.includes(:account, :category, :tags)

    if params[:account_id].present?
      account_id = params[:account_id]
      @transactions = @transactions.where(
        "transactions.account_id = ? OR (transactions.type = 'TRANSFER' AND transactions.target_account_id = ?)",
        account_id, account_id
      )
      @current_account_id = account_id
    end

    if params[:type].present?
      @transactions = @transactions.where(type: params[:type])
    end

    if params[:category_ids].present?
      category_ids = Array(params[:category_ids]).reject(&:blank?)
      @transactions = @transactions.where(category_id: category_ids) if category_ids.any?
    end

    @transactions = @transactions.by_period(period_type, period_value)

    if params[:search].present?
      @transactions = @transactions.where("note LIKE ?", "%#{params[:search]}%")
    end

    @transactions = @transactions.reverse_chronological
    
    @page = [[params[:page].to_i, 1].max, 1000].min
    @per_page = [[params[:per_page].to_i, 5].max, 200].min
    
    filter_cache_key = build_filter_cache_key
    
    @total_count = Rails.cache.fetch("transactions_count_#{filter_cache_key}", expires_in: 30.seconds) do
      @transactions.count
    end
    
    transactions_cache_key = "transactions_list_#{filter_cache_key}_#{@page}_#{@per_page}"
    @transactions_with_balance = Rails.cache.fetch(transactions_cache_key, expires_in: 2.minutes) do
      load_transactions_with_balance
    end

    stats_cache_key = "stats_#{params[:account_id] || 'all'}_#{period_type}_#{period_value}_#{params[:type]}"
    stats_data = Rails.cache.fetch(stats_cache_key, expires_in: 1.minute) do
      calculate_stats(params[:account_id].presence, period_type, period_value, params[:type].presence)
    end
    
    @account_balance = stats_data[:account_balance]
    @total_income = stats_data[:total_income]
    @total_expense = stats_data[:total_expense]
    @total_balance = stats_data[:total_balance]

    @transaction = Transaction.new(currency: "CNY", date: Date.today)
  end

  def stats
    account_id = params[:account_id].presence
    period_type = params[:period_type].presence || "month"
    period_value = params[:period_value].presence ||
      case period_type
      when "year" then Date.current.year.to_s
      when "week" then Date.current.strftime("%G-W%V")
      else Date.current.strftime("%Y-%m")
      end
    filter_type = params[:type].presence

    range = calculate_period_range(period_type, period_value)

    cache_key = "stats_#{account_id || 'all'}_#{period_type}_#{period_value}_#{filter_type}"
    stats_data = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      calculate_stats(account_id, range, filter_type)
    end

    render json: stats_data
  end

  def show
  end

  def new
    @account = Account.new
  end

  def edit
  end

  def create
    @account = Account.new(account_params)
    if @account.save
      redirect_to accounts_path, notice: "账户已创建"
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.join(", ")
    end
  end

  def update
    if @account.update(account_params)
      expire_accounts_cache
      redirect_to accounts_path, notice: "账户已更新"
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.join(", ")
    end
  end

  def destroy
    @account.destroy
    expire_accounts_cache
    redirect_to accounts_path, notice: "账户已删除"
  end

  def reorder
    target_account = Account.find(params[:target_id])

    # 交换 sort_order
    current_order = @account.sort_order
    target_order = target_account.sort_order

    @account.update!(sort_order: target_order)
    target_account.update!(sort_order: current_order)
    
    expire_accounts_cache

    head :ok
  end

  private

  def expire_accounts_cache
    Rails.cache.delete("accounts_list")
    Rails.cache.delete("categories_active")
  end

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.require(:account).permit(
      :name, :type, :initial_balance, :currency,
      :billing_day, :due_day, :credit_limit,
      :billing_day_mode, :due_day_mode, :due_day_offset,
      :include_in_total, :hidden, :sort_order
    )
  end
  
  def default_period_value(period_type)
    case period_type
    when 'year' then Date.current.year.to_s
    when 'week' then Date.current.strftime("%G-W%V")
    else Date.current.strftime("%Y-%m")
    end
  end
  
  def build_filter_cache_key
    "#{params[:account_id]}_#{params[:type]}_#{params[:period_type]}_#{params[:period_value]}_#{params[:search]}_#{Array(params[:category_ids]).sort.join(',')}"
  end
  
  def load_transactions_with_balance
    paginated_transactions = @transactions.limit(@per_page).offset((@page - 1) * @per_page).to_a
    
    current_account_id = params[:account_id].to_i
    initial_balance = if params[:account_id].present?
      Account.find_by(id: params[:account_id])&.initial_balance || 0
    else
      Account.included_in_total.sum(&:initial_balance)
    end
    
    result = []
    if @page == 1 && paginated_transactions.any?
      sorted = paginated_transactions.sort_by { |t| [t.date || Date.new(1970), t.id] }
      running_balance = initial_balance.to_d
      balance_map = {}
      
      sorted.each do |t|
        case t.type
        when "INCOME" then running_balance += t.amount.to_d
        when "EXPENSE" then running_balance -= t.amount.to_d
        when "TRANSFER"
          if t.account_id.to_i == current_account_id
            running_balance -= t.amount.to_d
          elsif t.target_account_id.to_i == current_account_id
            running_balance += t.amount.to_d
          end
        end
        balance_map[t.id] = running_balance
      end
      
      paginated_transactions.each do |t|
        result << [t, balance_map[t.id] || running_balance]
      end
    else
      paginated_transactions.each do |t|
        result << [t, nil]
      end
    end
    result
  end

  def calculate_stats(account_id, period_type, period_value, filter_type)
    if account_id.present?
      account = Account.find_by(id: account_id)
      account_balance = account&.current_balance || 0

      stats_query = Transaction.where(
        "(account_id = ? AND type IN ('INCOME', 'EXPENSE')) OR " \
        "(type = 'TRANSFER' AND (account_id = ? OR target_account_id = ?))",
        account_id, account_id, account_id
      ).by_period(period_type, period_value)
      
      stats_query = stats_query.where(type: filter_type) if filter_type.present?

      stats = stats_query.select(
        "SUM(CASE WHEN (type = 'INCOME' OR (type = 'TRANSFER' AND target_account_id = #{account_id})) THEN amount ELSE 0 END) as total_income",
        "SUM(CASE WHEN (type = 'EXPENSE' OR (type = 'TRANSFER' AND account_id = #{account_id} AND target_account_id != #{account_id})) THEN amount ELSE 0 END) as total_expense"
      ).to_a.first

      {
        account_balance: account_balance,
        total_income: stats&.total_income || 0,
        total_expense: stats&.total_expense || 0,
        total_balance: (stats&.total_income || 0) - (stats&.total_expense || 0)
      }
    else
      account_balance = Account.total_assets

      base_query = Transaction.where.not(type: "TRANSFER").by_period(period_type, period_value)
      base_query = base_query.where(type: filter_type) if filter_type.present?

      stats = base_query.select(
        "SUM(CASE WHEN type = 'INCOME' THEN amount ELSE 0 END) as total_income",
        "SUM(CASE WHEN type = 'EXPENSE' THEN amount ELSE 0 END) as total_expense"
      ).to_a.first

      {
        account_balance: account_balance,
        total_income: stats&.total_income || 0,
        total_expense: stats&.total_expense || 0,
        total_balance: (stats&.total_income || 0) - (stats&.total_expense || 0)
      }
    end
  end
end
