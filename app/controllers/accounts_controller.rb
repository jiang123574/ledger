require "ostruct"

class AccountsController < ApplicationController
  before_action :set_account, only: [ :show, :edit, :update, :destroy, :bills, :bills_entries, :reorder, :reorder_entries ]
  before_action :prevent_locked_system_account!, only: [ :edit, :update, :destroy ]

  def index
    data = AccountDashboardService.new(params).load_dashboard
    data.each { |key, value| instance_variable_set("@#{key}", value) }
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

  def entries
    ev = CacheBuster.version(:entries)
    period_type = params[:period_type].presence || "month"
    period_value = params[:period_value].presence || PeriodFilterable.default_period_value(period_type)

    entries_query = AccountDashboardService.build_entries_query(params, period_type, period_value)
    count_cache_key = AccountDashboardService.build_count_cache_key(params)
    total_count = Rails.cache.fetch("entries_count/#{count_cache_key}/#{ev}", expires_in: CacheConfig::FAST) do
      entries_query.count
    end

    page = [ [ params[:page].to_i, 1 ].max, 1000 ].min
    per_page = [ [ params[:per_page].to_i, 15 ].max, 200 ].min
    entries_cache_key = "entries_list/#{AccountDashboardService.build_entries_cache_key(params)}/#{page}/#{per_page}/#{ev}"

    cached_data = Rails.cache.fetch(entries_cache_key, expires_in: CacheConfig::MEDIUM) do
      result = AccountStatsService.entries_with_balance(
        entries_query, page: page, per_page: per_page, account_id: params[:account_id].presence
      )
      result.map { |entry, balance| [ entry.id, balance ] }
    end
    entry_ids = cached_data.map(&:first)
    balance_map = cached_data.to_h
    if entry_ids.empty?
      render json: { entries: [], total: 0 }
      return
    end
    entries = Entry.where(id: entry_ids)
      .includes(:account, :entryable, entryable: :category)
      .to_a
    entry_id_to_index = entry_ids.each_with_index.to_h
    entries.sort_by! { |e| entry_id_to_index[e.id] || Float::INFINITY }
    AccountStatsService.preload_transfer_accounts_for(entries.map { |e| [ e, nil ] })

    current_account_filter = params[:account_id].to_s
    entry_data = entries.map { |e| EntryPresenter.entry_to_json(e, balance_map, current_account_filter) }
    render json: { entries: entry_data, total: total_count }
  end

  def bills
    unless @account.credit_card?
      render json: { error: "该账户不是信用卡或未设置账单日" }, status: :unprocessable_entity
      return
    end

    count = (params[:count] || 3).to_i.clamp(1, 24)
    cycles = @account.bill_cycles_with_statement(count)
    bill_data = cycles.map do |cycle|
      summary = @account.bill_cycle_summary(start_date: cycle[:start_date], end_date: cycle[:end_date])
      {
        label: cycle[:label],
        unbilled: cycle[:unbilled],
        start_date: cycle[:start_date],
        end_date: cycle[:end_date],
        due_date: cycle[:due_date],
        spend_amount: summary[:spend_amount],
        repay_amount: summary[:repay_amount],
        balance_due: summary[:balance_due],
        statement_amount: cycle[:statement_amount],
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

    start_date = Date.parse(start_s) rescue nil
    end_date = Date.parse(end_s) rescue nil
    unless start_date && end_date
      render json: { entries: [], error: "日期格式错误" }, status: :bad_request
      return
    end

    entries = @account.transaction_entries
                    .where(date: start_date..end_date)
                    .includes(:account, :entryable, entryable: :category)
                    .order(date: :desc)
    Entry.preload_transfer_accounts(entries.to_a)

    entry_data = entries.map { |e| EntryPresenter.entry_for_bill(e) }
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
    blocking_refs = blocking_references_for(@account)
    if blocking_refs.any?
      redirect_to accounts_path, alert: "账户仍有关联数据（#{blocking_refs.join("、")}），请先处理后再删除"
      return
    end
    @account.destroy!
    expire_accounts_cache
    redirect_to accounts_path, notice: "账户已删除"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to accounts_path, alert: "账户仍有关联数据，无法删除"
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

  def reorder_entries
    unless params[:entry_ids].is_a?(Array) && params[:date].present?
      render json: { success: false, error: "缺少排序参数" }, status: :bad_request
      return
    end

    date = Date.parse(params[:date]) rescue nil
    unless date
      render json: { success: false, error: "日期格式不正确" }, status: :bad_request
      return
    end

    entry_ids = params[:entry_ids].map(&:to_i)
    expected_entry_ids = Entry.where(account_id: @account.id, date: date).pluck(:id)
    if expected_entry_ids.sort != entry_ids.uniq.sort
      render json: { success: false, error: "条目列表不匹配：期望 #{expected_entry_ids.size} 个条目，实际提供 #{entry_ids.uniq.size} 个" }, status: :unprocessable_entity
      return
    end

    balances = ActiveRecord::Base.transaction do
      total_entries = entry_ids.size
      entry_ids.each_with_index do |entry_id, index|
        Entry.where(id: entry_id, account_id: @account.id, date: date)
             .update_all(sort_order: total_entries - index)
      end

      running_balance = Entry.where(account_id: @account.id)
                              .where("date < ?", date)
                              .sum(:amount) + @account.initial_balance

      all_entries_from_date = Entry.where(account_id: @account.id)
                                    .where("date >= ?", date)
                                    .order(date: :asc, sort_order: :asc)
                                    .pluck(:id, :amount, :date)

      balances = []
      all_entries_from_date.each do |entry_id, amount, _|
        running_balance += amount
        balances << { entry_id: entry_id, balance_after: running_balance }
      end
      balances
    end

    CacheBuster.bump(:entries)
    render json: { success: true, balances: balances }
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

  def blocking_references_for(account)
    refs = []

    if Entry.where(account_id: account.id).exists?
      refs << "交易记录"
    end
    refs << "应收款" if Receivable.where(account_id: account.id).exists?
    refs << "应付款" if Payable.where(account_id: account.id).exists?

    refs
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
end
