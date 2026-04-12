require "ostruct"

# 账户仪表盘数据服务
# 从 AccountsController#index 提取的数据准备逻辑
class AccountDashboardService
  def initialize(params)
    @params = params
  end

  # 加载仪表盘所需的所有数据
  # @return [Hash] 包含所有 index 所需数据的 hash
  def load_dashboard
    av = CacheBuster.version(:accounts)
    ev = CacheBuster.version(:entries)

    # 仅在系统账户缺失时兜底同步；常规联动由 Receivable/Payable 的 after_commit 负责
    SystemAccountSyncService.sync_all! if system_accounts_sync_needed?

    accounts = load_accounts(av)
    accounts_map = accounts.index_by(&:id)
    account_balances = load_account_balances(ev, accounts.map(&:id))
    total_assets = load_total_assets(ev)
    categories = load_categories(av)
    expense_categories = load_expense_categories(av)
    counterparties = load_counterparties(av)
    unsettled_receivables = load_unsettled_receivables

    # entries 查询构建 + 分页 + 运行余额计算
    period_type = @params[:period_type].presence || "month"
    period_value = @params[:period_value].presence || PeriodFilterable.default_period_value(period_type)
    
    entries_query = build_entries_query(period_type, period_value)
    count_cache_key = build_count_cache_key
    total_count = load_entries_count(entries_query, count_cache_key, ev)
    
    page = [[@params[:page].to_i, 1].max, 1000].min
    per_page = [[@params[:per_page].to_i, 15].max, 200].min
    
    entries_with_balance = load_entries_with_balance(entries_query, page, per_page, ev)

    # 统计数据
    category_ids = @params[:category_ids]&.map(&:to_i)&.select { |id| id > 0 } || []
    stats_data = load_stats(period_type, period_value, category_ids, ev)

    # 新建表单数据
    entry = Entry.new(currency: "CNY", date: Date.today)
    new_transaction = ::OpenStruct.new(
      type: "EXPENSE", account_id: nil, category_id: nil,
      target_account_id: nil, account: nil, category: nil, target_account: nil,
      persisted?: false, model_name: ActiveModel::Name.new(Entry, nil, "transaction")
    )

    {
      accounts: accounts,
      accounts_map: accounts_map,
      account_balances: account_balances,
      total_assets: total_assets,
      categories: categories,
      expense_categories: expense_categories,
      counterparties: counterparties,
      unsettled_receivables: unsettled_receivables,
      entries_with_balance: entries_with_balance,
      total_count: total_count,
      page: page,
      per_page: per_page,
      account_balance: stats_data[:account_balance],
      total_income: stats_data[:total_income],
      total_expense: stats_data[:total_expense],
      total_balance: stats_data[:total_balance],
      entry: entry,
      new_transaction: new_transaction
    }
  end

  # 公开的查询构建方法，供外部使用
  def self.build_entries_query(params, period_type, period_value)
    new(params).send(:build_entries_query, period_type, period_value)
  end

  # 公开的缓存键构建方法，供外部使用
  def self.build_count_cache_key(params)
    new(params).send(:build_count_cache_key)
  end

  def self.build_entries_cache_key(params)
    new(params).send(:build_entries_cache_key)
  end

  private

  # 检查是否需要同步系统账户
  def system_accounts_sync_needed?
    required_names = [
      SystemAccountSyncService::RECEIVABLE_ACCOUNT_NAME,
      SystemAccountSyncService::PAYABLE_ACCOUNT_NAME
    ]
    Account.where(name: required_names).distinct.count(:name) < required_names.size
  end

  # 加载账户列表
  def load_accounts(av)
    Rails.cache.fetch("accounts_list/#{@params[:show_hidden]}/#{av}", expires_in: CacheConfig::TEN_MINUTES) do
      if @params[:show_hidden] == "true"
        Account.order(:sort_order, :name).to_a
      else
        Account.visible.order(:sort_order, :name).to_a
      end
    end
  end

  # 加载账户余额映射
  def load_account_balances(ev, account_ids)
    Rails.cache.fetch("account_balances/#{ev}", expires_in: CacheConfig::SHORT) do
      results = Entry.where(account_id: account_ids, entryable_type: "Entryable::Transaction")
                       .group(:account_id)
                       .sum(:amount)
      Account.where(id: account_ids).pluck(:id, :initial_balance).each_with_object({}) do |(id, ib), hash|
        hash[id] = ib.to_d + (results[id] || 0)
      end
    end
  end

  # 加载总资产
  def load_total_assets(ev)
    Rails.cache.fetch("total_assets/#{ev}", expires_in: CacheConfig::SHORT) do
      Account.total_assets
    end
  end

  # 加载活跃分类
  def load_categories(av)
    Rails.cache.fetch("categories_active/#{av}", expires_in: CacheConfig::LONG) do
      Category.active.by_sort_order.to_a
    end
  end

  # 加载活跃支出分类
  def load_expense_categories(av)
    Rails.cache.fetch("expense_categories_active/#{av}", expires_in: CacheConfig::LONG) do
      Category.expense.active.by_sort_order.to_a
    end
  end

  # 加载交易对手列表
  def load_counterparties(av)
    Rails.cache.fetch("counterparties_list/#{av}", expires_in: CacheConfig::LONG) do
      Counterparty.order(:name).to_a
    end
  end

  # 加载未结应收款
  def load_unsettled_receivables
    Receivable.unsettled
      .order(date: :desc)
      .limit(50)
  end

  # 加载条目总数
  def load_entries_count(entries_query, count_cache_key, ev)
    Rails.cache.fetch("entries_count/#{count_cache_key}/#{ev}", expires_in: CacheConfig::FAST) do
      entries_query.count
    end
  end

  # 加载带余额的条目列表
  def load_entries_with_balance(entries_query, page, per_page, ev)
    entries_cache_key = "entries_list/#{build_entries_cache_key}/#{page}/#{per_page}/#{ev}"
    
    # 缓存 ID+balance 而非完整 ActiveRecord 对象：
    # - 余额计算（运行余额逐行求和）是 O(n) 开销，值得缓存
    # - Marshal 序列化会丢失 includes 预加载信息，缓存对象后仍需重新查询
    # - 因此只缓存轻量的 ID 列表 + 余额映射，每次请求重新查询对象 + 预加载关联
    cached_data = Rails.cache.fetch(entries_cache_key, expires_in: CacheConfig::MEDIUM) do
      result = AccountStatsService.entries_with_balance(
        entries_query, page: page, per_page: per_page, account_id: @params[:account_id].presence
      )
      # 缓存只存 ID 和 balance，不缓存 ActiveRecord 对象（序列化会丢失预加载）
      result.map { |entry, balance| [entry.id, balance] }
    end

    # 重新查询并预加载（每次请求都执行，确保预加载信息完整）
    entry_ids = cached_data.map(&:first)
    balance_map = cached_data.to_h
    
    if entry_ids.empty?
      []
    else
      entries = Entry.where(id: entry_ids)
        .includes(:account, :entryable, entryable: :category)
        .to_a
      # 按照缓存的entry_ids顺序重新排序，保持倒序顺序
      # 优化：从 O(n²) 优化为 O(n) 通过预计算索引映射
      entry_id_to_index = entry_ids.each_with_index.to_h
      entries.sort_by! { |e| entry_id_to_index[e.id] || Float::INFINITY }
      AccountStatsService.preload_transfer_accounts_for(entries.map { |e| [e, nil] })
      entries.map { |e| [e, balance_map[e.id]] }
    end
  end

  # 加载统计数据
  def load_stats(period_type, period_value, category_ids, ev)
    stats_cache_key = "stats/#{@params[:account_id] || 'all'}/#{period_type}/#{period_value}/#{@params[:type]}/#{category_ids.empty? ? 'no_cat' : category_ids.sort.join(',')}/#{ev}"
    
    Rails.cache.fetch(stats_cache_key, expires_in: CacheConfig::SHORT) do
      AccountStatsService.entry_stats(
        account_id: @params[:account_id].presence,
        period_type: period_type,
        period_value: period_value,
        filter_type: @params[:type].presence,
        category_ids: category_ids
      )
    end
  end

  # 构建 count 缓存键（不含 sort_direction）
  def build_count_cache_key
    "#{@params[:account_id]}_#{@params[:type]}_#{@params[:period_type]}_#{@params[:period_value]}_#{@params[:search]}_#{Array(@params[:category_ids]).sort.join(',')}"
  end

  # 构建 entries 缓存键（含 sort_direction）
  def build_entries_cache_key
    sort_direction = @params[:sort_direction]&.downcase || "desc"
    sort_direction = "desc" unless sort_direction.in?(%w[asc desc])
    "#{build_count_cache_key}_#{sort_direction}"
  end

  # 构建 entries 查询
  def build_entries_query(period_type, period_value)
    entries = Entry.where(entryable_type: ["Entryable::Transaction"])

    if @params[:account_id].present?
      entries = entries.where(account_id: @params[:account_id])
    else
      entries = entries.where("transfer_id IS NULL OR amount < 0")
    end

    if @params[:type].present?
      kind = @params[:type].downcase
      entries = entries.with_entryable_transaction
                        .where(entryable_transactions: { kind: kind })
    end

    if @params[:category_ids].present?
      category_ids = Array(@params[:category_ids]).reject(&:blank?)
      if category_ids.any?
        entries = entries.with_entryable_transaction
                          .where(entryable_transactions: { category_id: category_ids })
      end
    end

    # 使用 PeriodFilterable
    range = PeriodFilterable.resolve_period(period_type, period_value)
    entries = entries.by_date_range(range.first, range.last) if range

    if @params[:search].present?
      search_term = "%#{@params[:search].to_s.gsub(/[%_]/) { |char| "\\#{char}" }}%"
      entries = entries.where("entries.name LIKE ? OR entries.notes LIKE ?", search_term, search_term)
    end

    # 支持排序方向参数 (asc 或 desc)，默认 desc (倒序)
    sort_direction = @params[:sort_direction]&.downcase || "desc"
    sort_direction = "desc" unless sort_direction.in?(%w[asc desc])

    if sort_direction == "asc"
      entries.chronological
    else
      entries.reverse_chronological
    end
  end
end