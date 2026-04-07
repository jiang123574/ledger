# frozen_string_literal: true

# 账户统计服务
# 从 AccountsController 抽离的统计计算逻辑
class AccountStatsService
  # 计算期间内 Entry 维度的收支统计
  def self.entry_stats(account_id: nil, period_type:, period_value:, filter_type: nil, category_ids: nil)
    account_balance = if account_id.present?
      Account.find_by(id: account_id)&.current_balance || 0
    else
      Account.total_assets
    end

    entries_query = Entry.where(entryable_type: "Entryable::Transaction")
    entries_query = apply_period_filter(entries_query, period_type, period_value)
    entries_query = entries_query.where(account_id: account_id) if account_id.present?
    entries_query = apply_entry_filters(entries_query, filter_type, category_ids)

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

  # 计算带余额的分页 Entry 列表
  # 返回 [[Entry, balance], ...]
  def self.entries_with_balance(entries_scope, page:, per_page:, account_id: nil)
    paginated_entries = entries_scope.includes(:entryable, entryable: :category)
      .limit(per_page).offset((page - 1) * per_page).to_a

    if paginated_entries.empty?
      return paginated_entries.map { |e| [ e, nil ] }
    end

    # 找到最早的一条记录（使用与排序相同的比较键，包含 sort_order）
    # 对于倒序分页，earliest 是这一页中日期最小、sort_order 最小、id 最小的记录
    earliest = paginated_entries.min_by { |e| [ e.date || Date.new(1970), e.sort_order || 0, e.id ] }

    # 计算该记录之前的所有 Entry 总和
    initial_balance = if account_id.present?
      Account.find_by(id: account_id)&.initial_balance || 0
    else
      Account.included_in_total.sum(:initial_balance)
    end

    all_prior_entries = Entry.where(entryable_type: "Entryable::Transaction")
      .joins(:account)

    if account_id.present?
      all_prior_entries = all_prior_entries.where(account_id: account_id)
    else
      all_prior_entries = all_prior_entries.where(accounts: { include_in_total: true })
    end

    all_prior_entries = all_prior_entries
      .where("entries.date < ? OR (entries.date = ? AND (entries.sort_order < ? OR (entries.sort_order = ? AND entries.id < ?)))",
             earliest.date, earliest.date, earliest.sort_order || 0, earliest.sort_order || 0, earliest.id)
      .select("SUM(entries.amount) as total_amount")
      .to_a.first

    prior_total = all_prior_entries&.total_amount || 0
    running_balance = initial_balance.to_d + prior_total.to_d

    # 余额计算：按正序（日期从小到大）计算，与 chronological 排序一致
    # sorted_asc 按日期正序、sort_order 正序、id 正序排列
    sorted_asc = paginated_entries.sort_by { |e| [ e.date || Date.new(1970), e.sort_order || 0, e.id ] }
    balance_map = {}

    sorted_asc.each do |e|
      running_balance += e.amount.to_d
      balance_map[e.id] = running_balance
    end

    # 返回原始分页顺序（保持 reverse_chronological 顺序：日期倒序、sort_order 正序、id 倒序）
    # 每条记录的余额是"截止到该记录的累计余额"（从最早到该记录）
    paginated_entries.map { |e| [ e, balance_map[e.id] || running_balance ] }
  end

  # 预加载转账配对账户信息（消除视图中的 N+1 查询）
  # 在 entries_with_balance 之后调用
  def self.preload_transfer_accounts_for(entries_with_balance)
    entries = entries_with_balance.map(&:first)
    Entry.preload_transfer_accounts(entries)
  end

  class << self
    private

    # 应用期间过滤（复用 PeriodFilterable 的逻辑）
    def apply_period_filter(scope, period_type, period_value)
      range = PeriodFilterable.resolve_period(period_type, period_value)
      return scope unless range

      scope.by_date_range(range.first, range.last)
    end

    # 应用类型和分类过滤
    def apply_entry_filters(query, filter_type, category_ids)
      return query if filter_type.blank? && category_ids.blank?

      query = query.joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id")
      query = query.where(entryable_transactions: { kind: filter_type.downcase }) if filter_type.present?
      query = query.where(entryable_transactions: { category_id: category_ids }) if category_ids.present?
      query
    end
  end
end
