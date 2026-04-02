class AccountsController < ApplicationController
  before_action :set_account, only: [:show, :edit, :update, :destroy]

  def index
    @accounts = Rails.cache.fetch("accounts_list_#{params[:show_hidden]}", expires_in: 10.minutes) do
      if params[:show_hidden] == 'true'
        Account.order(:sort_order, :name).to_a
      else
        Account.visible.order(:sort_order, :name).to_a
      end
    end
    
    @categories = Rails.cache.fetch("categories_active", expires_in: 1.hour) do
      Category.active.by_sort_order.to_a
    end

    period_type = params[:period_type].presence || "month"
    period_value = params[:period_value].presence || default_period_value(period_type)

    @entries = Entry.where(entryable_type: 'Entryable::Transaction')

    if params[:account_id].present?
      account_id = params[:account_id]
      @entries = @entries.where(account_id: account_id)
      @current_account_id = account_id
    else
      @entries = @entries.where("transfer_id IS NULL OR amount < 0")
    end

    if params[:type].present?
      kind = params[:type].downcase
      @entries = @entries.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
                         .where(entryable_transactions: { kind: kind })
    end

    if params[:category_ids].present?
      category_ids = Array(params[:category_ids]).reject(&:blank?)
      if category_ids.any?
        @entries = @entries.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
                           .where(entryable_transactions: { category_id: category_ids })
      end
    end

    @entries = apply_period_filter(@entries, period_type, period_value)

    if params[:search].present?
      @entries = @entries.where("entries.name LIKE ? OR entries.notes LIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    @entries = @entries.reverse_chronological.includes(:account)
    
    @page = [[params[:page].to_i, 1].max, 1000].min
    @per_page = [[params[:per_page].to_i, 5].max, 200].min
    
    filter_cache_key = build_filter_cache_key
    
    @total_count = Rails.cache.fetch("entries_count_#{filter_cache_key}", expires_in: 30.seconds) do
      @entries.count
    end
    
    entries_cache_key = "entries_list_#{filter_cache_key}_#{@page}_#{@per_page}"
    @entries_with_balance = Rails.cache.fetch(entries_cache_key, expires_in: 2.minutes) do
      load_entries_with_balance
    end

    @transactions_with_balance = @entries_with_balance.map { |e, balance| [build_transaction_from_entry(e), balance] }
    @transactions = @transactions_with_balance.map(&:first)

    stats_cache_key = "stats_#{params[:account_id] || 'all'}_#{period_type}_#{period_value}_#{params[:type]}_#{Array(params[:category_ids]).reject(&:blank?).sort.join(',')}"
    stats_data = Rails.cache.fetch(stats_cache_key, expires_in: 1.minute) do
      calculate_entry_stats(params[:account_id].presence, period_type, period_value, params[:type].presence, Array(params[:category_ids]).reject(&:blank?))
    end
    
    @account_balance = stats_data[:account_balance]
    @total_income = stats_data[:total_income]
    @total_expense = stats_data[:total_expense]
    @total_balance = stats_data[:total_balance]

    @transaction = Transaction.new(currency: "CNY", date: Date.today)
    @entry = Entry.new(currency: "CNY", date: Date.today)
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
    category_ids = Array(params[:category_ids]).reject(&:blank?)

    cache_key = "stats_#{account_id || 'all'}_#{period_type}_#{period_value}_#{filter_type}_#{category_ids.sort.join(',')}"
    stats_data = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      calculate_stats(account_id, period_type, period_value, filter_type, category_ids)
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

  def load_entries_with_balance
    paginated_entries = @entries.limit(@per_page).offset((@page - 1) * @per_page).to_a
    
    initial_balance = if params[:account_id].present?
      Account.find_by(id: params[:account_id])&.initial_balance || 0
    else
      Account.included_in_total.sum { |a| a.initial_balance || 0 }
    end
    
    if paginated_entries.empty?
      return paginated_entries.map { |e| [e, nil] }
    end
    
    earliest_date = paginated_entries.map(&:date).min
    earliest_id = paginated_entries.map(&:id).min
    
    all_prior_entries = Entry.where(entryable_type: 'Entryable::Transaction')
      .joins(:account)
    
    if params[:account_id].present?
      all_prior_entries = all_prior_entries.where(account_id: params[:account_id])
    else
      all_prior_entries = all_prior_entries.where(accounts: { include_in_total: true })
      all_prior_entries = all_prior_entries.where("transfer_id IS NULL")
    end
    
    all_prior_entries = all_prior_entries
      .where("entries.date < ? OR (entries.date = ? AND entries.id < ?)", earliest_date, earliest_date, earliest_id)
      .select("SUM(entries.amount) as total_amount")
      .to_a.first
    
    prior_total = all_prior_entries&.total_amount || 0
    running_balance = initial_balance.to_d + prior_total.to_d
    
    sorted = paginated_entries.sort_by { |e| [e.date || Date.new(1970), e.id] }
    balance_map = {}
    
    sorted.each do |e|
      if e.transfer_id.present? && params[:account_id].blank?
        balance_map[e.id] = running_balance
      else
        running_balance += e.amount.to_d
        balance_map[e.id] = running_balance
      end
    end
    
    paginated_entries.map { |e| [e, balance_map[e.id] || running_balance] }
  end

  def apply_period_filter(scope, period_type, period_value)
    case period_type
    when 'all'
      scope
    when 'year'
      start_date = Date.new(period_value.to_i, 1, 1)
      end_date = start_date.end_of_year
      scope.by_date_range(start_date, end_date)
    when 'week'
      if (m = period_value.match(/\A(\d{4})-W(\d{2})\z/))
        year = m[1].to_i
        week = m[2].to_i
        start_date = Date.commercial(year, week, 1)
        scope.by_date_range(start_date, start_date + 6.days)
      else
        scope
      end
    else
      if period_value.match?(/\A\d{4}-\d{2}\z/)
        start_date = Date.parse("#{period_value}-01")
        scope.by_date_range(start_date, start_date.end_of_month)
      else
        scope
      end
    end
  end

  def build_transaction_from_entry(entry)
    t = Transaction.new
    t.id = entry.id
    t.account_id = entry.account_id
    t.account = entry.account
    t.date = entry.date
    t.amount = entry.amount.abs
    t.currency = entry.currency
    t.note = entry.notes || entry.name
    
    if entry.transfer_id.present?
      t.type = 'TRANSFER'
      if entry.amount < 0
        t.account_id = entry.account_id
        t.account = entry.account
        t.target_account_id = find_transfer_target_account(entry)
        t.target_account = Account.find_by(id: t.target_account_id)
      else
        source_account_id = find_transfer_source_account(entry)
        t.account_id = source_account_id
        t.account = Account.find_by(id: source_account_id)
        t.target_account_id = entry.account_id
        t.target_account = entry.account
      end
    elsif entry.entryable.respond_to?(:kind)
      t.type = entry.entryable.kind.upcase
      if entry.entryable.respond_to?(:category)
        t.category = entry.entryable.category
        t.category_id = entry.entryable.category_id
      end
    end
    
    t
  end

  def find_transfer_target_account(entry)
    target_entry = Entry.where(transfer_id: entry.transfer_id)
                        .where.not(id: entry.id)
                        .where('amount > 0')
                        .first
    target_entry&.account_id
  end

  def find_transfer_source_account(entry)
    source_entry = Entry.where(transfer_id: entry.transfer_id)
                        .where.not(id: entry.id)
                        .where('amount < 0')
                        .first
    source_entry&.account_id
  end

  def calculate_entry_stats(account_id, period_type, period_value, filter_type, category_ids = nil)
    if account_id.present?
      account = Account.find_by(id: account_id)
      account_balance = account&.current_balance || 0

      entries_query = apply_period_filter(
        Entry.where(account_id: account_id, entryable_type: 'Entryable::Transaction'),
        period_type, period_value
      )
      
      if filter_type.present? || category_ids.present?
        entries_query = entries_query.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
        
        if filter_type.present?
          kind = filter_type.downcase
          entries_query = entries_query.where(entryable_transactions: { kind: kind })
        end
        
        if category_ids.present?
          entries_query = entries_query.where(entryable_transactions: { category_id: category_ids })
        end
      end

      stats = entries_query.select(
        "SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_income",
        "SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_expense"
      ).to_a.first

      {
        account_balance: account_balance,
        total_income: stats&.total_income || 0,
        total_expense: stats&.total_expense || 0,
        total_balance: (stats&.total_income || 0) - (stats&.total_expense || 0)
      }
    else
      account_balance = Account.visible.included_in_total.sum { |a| a.current_balance }

      entries_query = apply_period_filter(
        Entry.where(entryable_type: 'Entryable::Transaction'),
        period_type, period_value
      )
      
      if filter_type.present? || category_ids.present?
        entries_query = entries_query.joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
        
        if filter_type.present?
          kind = filter_type.downcase
          entries_query = entries_query.where(entryable_transactions: { kind: kind })
        end
        
        if category_ids.present?
          entries_query = entries_query.where(entryable_transactions: { category_id: category_ids })
        end
      end

      stats = entries_query.select(
        "SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_income",
        "SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_expense"
      ).to_a.first

      {
        account_balance: account_balance,
        total_income: stats&.total_income || 0,
        total_expense: stats&.total_expense || 0,
        total_balance: (stats&.total_income || 0) - (stats&.total_expense || 0)
      }
    end
  end

  def calculate_stats(account_id, period_type, period_value, filter_type, category_ids = nil)
    if account_id.present?
      account = Account.find_by(id: account_id)
      account_balance = account&.current_balance || 0

      stats_query = Transaction.where(
        "(account_id = ? AND type IN ('INCOME', 'EXPENSE')) OR " \
        "(type = 'TRANSFER' AND (account_id = ? OR target_account_id = ?))",
        account_id, account_id, account_id
      ).by_period(period_type, period_value)
      
      stats_query = stats_query.where(type: filter_type) if filter_type.present?
      stats_query = stats_query.where(category_id: category_ids) if category_ids.present?

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
      base_query = base_query.where(category_id: category_ids) if category_ids.present?

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