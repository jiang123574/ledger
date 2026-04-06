require 'ostruct'

class AccountsController < ApplicationController
  before_action :set_account, only: [:show, :edit, :update, :destroy, :bills, :bills_entries, :reorder]
  before_action :prevent_locked_system_account!, only: [:edit, :update, :destroy]

  def index
    # 确保应收/应付系统账户金额与未结清余额保持联动
    SystemAccountSyncService.sync_all!

    av = CacheBuster.version(:accounts)
    ev = CacheBuster.version(:entries)

    @accounts = Rails.cache.fetch("accounts_list/#{params[:show_hidden]}/#{av}", expires_in: CacheConfig::TEN_MINUTES) do
      if params[:show_hidden] == 'true'
        Account.order(:sort_order, :name).to_a
      else
        Account.visible.order(:sort_order, :name).to_a
      end
    end
    @accounts_map = @accounts.index_by(&:id)

    # 预计算所有账户余额，避免视图中 N+1 查询
    @account_balances = Rails.cache.fetch("account_balances/#{ev}", expires_in: CacheConfig::SHORT) do
      account_ids = @accounts.map(&:id)
      results = Entry.where(account_id: account_ids, entryable_type: 'Entryable::Transaction')
                       .group(:account_id)
                       .sum(:amount)
      Account.where(id: account_ids).pluck(:id, :initial_balance).each_with_object({}) do |(id, ib), hash|
        hash[id] = ib.to_d + (results[id] || 0)
      end
    end

    @total_assets = Rails.cache.fetch("total_assets/#{ev}", expires_in: CacheConfig::SHORT) do
      Account.total_assets
    end

    @categories = Rails.cache.fetch("categories_active/#{av}", expires_in: CacheConfig::LONG) do
      Category.active.by_sort_order.to_a
    end

    period_type = params[:period_type].presence || "month"
    period_value = params[:period_value].presence || PeriodFilterable.default_period_value(period_type)

    @entries = build_entries_query(period_type, period_value)

    filter_cache_key = build_filter_cache_key

    @total_count = Rails.cache.fetch("entries_count/#{filter_cache_key}/#{ev}", expires_in: CacheConfig::FAST) do
      @entries.count
    end

    @page = [[params[:page].to_i, 1].max, 1000].min
    @per_page = [[params[:per_page].to_i, 5].max, 200].min

    entries_cache_key = "entries_list/#{filter_cache_key}/#{@page}/#{@per_page}/#{ev}"
    # 缓存 ID+balance 而非完整 ActiveRecord 对象：
    # - 余额计算（运行余额逐行求和）是 O(n) 开销，值得缓存
    # - Marshal 序列化会丢失 includes 预加载信息，缓存对象后仍需重新查询
    # - 因此只缓存轻量的 ID 列表 + 余额映射，每次请求重新查询对象 + 预加载关联
    cached_data = Rails.cache.fetch(entries_cache_key, expires_in: CacheConfig::MEDIUM) do
      result = AccountStatsService.entries_with_balance(
        @entries, page: @page, per_page: @per_page, account_id: params[:account_id].presence
      )
      # 缓存只存 ID 和 balance，不缓存 ActiveRecord 对象（序列化会丢失预加载）
      result.map { |entry, balance| [entry.id, balance] }
    end

    # 重新查询并预加载（每次请求都执行，确保预加载信息完整）
    entry_ids = cached_data.map(&:first)
    balance_map = cached_data.to_h
    @entries_with_balance = if entry_ids.empty?
      []
    else
      entries = Entry.where(id: entry_ids)
        .includes(:entryable, entryable: :category)
        .reverse_chronological
        .to_a
      AccountStatsService.preload_transfer_accounts_for(entries.map { |e| [e, nil] })
      entries.map { |e| [e, balance_map[e.id]] }
    end

    category_ids = params[:category_ids]&.map(&:to_i)&.select { |id| id > 0 } || []
    stats_cache_key = "stats/#{params[:account_id] || 'all'}/#{period_type}/#{period_value}/#{params[:type]}/#{category_ids.empty? ? 'no_cat' : category_ids.sort.join(',')}/#{ev}"
    stats_data = Rails.cache.fetch(stats_cache_key, expires_in: CacheConfig::SHORT) do
      AccountStatsService.entry_stats(
        account_id: params[:account_id].presence,
        period_type: period_type,
        period_value: period_value,
        filter_type: params[:type].presence,
        category_ids: category_ids
      )
    end

    @account_balance = stats_data[:account_balance]
    @total_income = stats_data[:total_income]
    @total_expense = stats_data[:total_expense]
    @total_balance = stats_data[:total_balance]

    @entry = Entry.new(currency: "CNY", date: Date.today)
    @new_transaction = ::OpenStruct.new(
      type: "EXPENSE", account_id: nil, category_id: nil,
      target_account_id: nil, account: nil, category: nil, target_account: nil,
      persisted?: false, model_name: ActiveModel::Name.new(Entry, nil, 'transaction')
    )
  end

  def stats
    account_id = params[:account_id].presence
    period_type = params[:period_type].presence || "month"
    period_value = params[:period_value].presence || PeriodFilterable.default_period_value(period_type)
    filter_type = params[:type].presence
    category_ids = params[:category_ids]&.map(&:to_i)&.select { |id| id > 0 } || []
    ev = CacheBuster.version(:entries)

    cache_key = "stats/#{account_id || 'all'}/#{period_type}/#{period_value}/#{filter_type}/#{category_ids.empty? ? 'no_cat' : category_ids.sort.join('/')}/#{ev}"
    stats_data = Rails.cache.fetch(cache_key, expires_in: CacheConfig::SHORT) do
      AccountStatsService.entry_stats(
        account_id: account_id,
        period_type: period_type,
        period_value: period_value,
        filter_type: filter_type,
        category_ids: category_ids
      )
    end

    render json: stats_data
  end

  # 信用卡账单列表（JSON）
  # 返回最近 N 期的账单卡片数据 + 每期汇总
  def bills
    unless @account.credit_card?
      render json: { error: "该账户不是信用卡或未设置账单日" }, status: :unprocessable_entity
      return
    end

    count = (params[:count] || 3).to_i.clamp(1, 12)
    cycles = @account.bill_cycles(count)

    bill_data = cycles.map do |cycle|
      summary = @account.bill_cycle_summary(
        start_date: cycle[:start_date],
        end_date: cycle[:end_date]
      )

      {
        label: cycle[:label],
        current: cycle[:current],
        start_date: cycle[:start_date],
        end_date: cycle[:end_date],
        due_date: cycle[:due_date],
        spend_amount: summary[:spend_amount],
        repay_amount: summary[:repay_amount],
        balance_due: summary[:balance_due],
        spend_count: summary[:spend_count],
        repay_count: summary[:repay_count]
      }
    end

    render json: {
      account_id: @account.id,
      account_name: @account.name,
      credit_limit: @account.credit_limit,
      current_balance: @account.current_balance,
      bills: bill_data
    }
  end

  # 某期账单的交易明细（JSON，用于下方表格）
  def bills_entries
    unless @account.credit_card?
      render json: { entries: [] }
      return
    end

    start_s = params[:start_date]
    end_s = params[:end_date]

    if start_s.blank? || end_s.blank?
      render json: { entries: [], error: "缺少日期参数" }, status: :bad_request
      return
    end

    start_date = begin
      Date.parse(start_s)
    rescue Date::Error
      nil
    end
    end_date = begin
      Date.parse(end_s)
    rescue Date::Error
      nil
    end

    unless start_date && end_date
      render json: { entries: [], error: "日期格式错误" }, status: :bad_request
      return
    end

    entries = @account.transaction_entries
                    .where(date: start_date..end_date)
                    .includes(:entryable, entryable: :category)
                    .order(date: :desc)

    Entry.preload_transfer_accounts(entries.to_a)

    entry_data = entries.map do |e|
      entry_type = e.display_entry_type
      is_transfer = entry_type == 'TRANSFER'
      # 单账户视图：amount > 0 = 转入（还款），amount < 0 = 转出（消费）
      is_inflow = is_transfer && e.amount.positive?

      # 显示类型标签（和按日期视图一致）
      display_type = if is_transfer
        is_inflow ? "转入" : "转出"
      else
        e.display_type_label
      end

      # 金额类型（决定颜色）
      display_amount_type = if is_transfer
        is_inflow ? "INCOME" : "EXPENSE"
      else
        entry_type
      end

      # 显示名称（对方账户）
      display_name = if is_transfer
        counterpart = is_inflow ? e.source_account_for_transfer&.name : e.target_account_for_display&.name
        (is_inflow ? "← " : "→ ") + (counterpart || "未知账户")
      else
        e.display_category&.name || '-'
      end

      {
        id: e.id,
        date: e.date,
        amount: e.amount,
        display_amount: e.display_amount,
        type: entry_type,
        type_label: e.display_type_label,
        display_type: display_type,
        display_amount_type: display_amount_type,
        display_name: display_name,
        note: e.display_note,
        category_name: e.display_category&.name,
        is_repayment: e.amount.positive?,
        is_spend: e.amount.negative?,
        balance_after: nil
      }
    end

    # 计算运行余额（从最早到最新）
    running_balance = @account.initial_balance.to_d
    balance_map = {}
    entry_data.reverse_each do |ed|
      running_balance += ed[:amount]
      balance_map[ed[:id]] = running_balance
    end

    entry_data.each { |ed| ed[:balance_after] = balance_map[ed[:id]] }

    render json: { entries: entry_data, total: entry_data.size }
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

    # 获取当前排序的全部账户列表，确定拖拽后的位置
    # 如果被拖账户是隐藏的，用 Account.all（否则 visible scope 里找不到它）
    show_hidden = ActiveModel::Type::Boolean.new.cast(params[:show_hidden]) || @account.hidden?
    scope = show_hidden ? Account.all : Account.visible
    all_accounts = scope.order(:sort_order, :name).to_a
    all_ids = all_accounts.map(&:id)

    dragged_idx = all_ids.index(@account.id)
    target_idx = all_ids.index(target_account.id)

    unless dragged_idx && target_idx
      head :bad_request
      return
    end

    # 从原位置移除，插入到目标位置
    all_ids.delete_at(dragged_idx)
    all_ids.insert(target_idx, @account.id)

    # 用新位置索引更新所有账户的 sort_order
    ActiveRecord::Base.transaction do
      all_ids.each_with_index do |id, idx|
        Account.where(id: id).update_all(sort_order: idx)
      end
    end

    expire_accounts_cache
    CacheBuster.bump(:entries)

    head :ok
  rescue ActiveRecord::ActiveRecordError => e
    head :conflict
  end

  private

  def locked_system_account?(account)
    return false unless account

    locked_names = [
      SystemAccountSyncService::RECEIVABLE_ACCOUNT_NAME,
      SystemAccountSyncService::PAYABLE_ACCOUNT_NAME
    ]
    locked_names.include?(account.name)
  end

  def prevent_locked_system_account!
    return unless locked_system_account?(@account)

    redirect_to accounts_path, alert: "系统账户（应收款/应付款）已锁定，无法编辑或删除"
  end

  def expire_accounts_cache
    CacheBuster.bump(:accounts)
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

  def build_filter_cache_key
    "#{params[:account_id]}_#{params[:type]}_#{params[:period_type]}_#{params[:period_value]}_#{params[:search]}_#{Array(params[:category_ids]).sort.join(',')}"
  end

  def build_entries_query(period_type, period_value)
    entries = Entry.where(entryable_type: 'Entryable::Transaction')

    if params[:account_id].present?
      entries = entries.where(account_id: params[:account_id])
    else
      entries = entries.where("transfer_id IS NULL OR amount < 0")
    end

    if params[:type].present?
      kind = params[:type].downcase
      entries = entries.with_entryable_transaction
                        .where(entryable_transactions: { kind: kind })
    end

    if params[:category_ids].present?
      category_ids = Array(params[:category_ids]).reject(&:blank?)
      if category_ids.any?
        entries = entries.with_entryable_transaction
                          .where(entryable_transactions: { category_id: category_ids })
      end
    end

    # 使用 PeriodFilterable
    range = PeriodFilterable.resolve_period(period_type, period_value)
    entries = entries.by_date_range(range.first, range.last) if range

    if params[:search].present?
      search_term = "%#{params[:search].to_s.gsub(/[%_]/) { |char| "\\#{char}" }}%"
      entries = entries.where("entries.name LIKE ? OR entries.notes LIKE ?", search_term, search_term)
    end

    entries.reverse_chronological
  end
end
