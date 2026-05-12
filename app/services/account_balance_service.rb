# AccountBalanceService - 账户余额与趋势计算服务
# 从 DashboardController 和 ReportsController 提取共同逻辑
#
# 使用方式:
#   service = AccountBalanceService.new(
#     start_date: @start_date,
#     end_date: @end_date
#   )
#   balance_data = service.compute_balance_data
#   trend_data = service.compute_net_worth_trend
#
class AccountBalanceService
  ASSET_TYPES = %w[CASH BANK INVESTMENT].freeze
  LIABILITY_TYPES = %w[CREDIT LOAN DEBT].freeze

  attr_reader :start_date, :end_date

  def initialize(start_date:, end_date:)
    @start_date = start_date
    @end_date = end_date
  end

  # 计算当前账户余额数据（用于趋势计算的基础数据）
  def compute_balance_data
    current_balances = load_current_balances
    asset_account_ids = current_balances.select { |_, v| ASSET_TYPES.include?(v[:type]) }.keys
    liability_account_ids = current_balances.select { |_, v| LIABILITY_TYPES.include?(v[:type]) }.keys

    current_assets = current_balances.select { |_, v| ASSET_TYPES.include?(v[:type]) }.values.sum { |v| v[:balance] }
    current_liabilities = current_balances.select { |_, v| LIABILITY_TYPES.include?(v[:type]) }.values.sum { |v| v[:balance] }

    monthly_changes = load_monthly_changes

    monthly_asset_delta = Hash.new(0.to_d)
    monthly_liability_delta = Hash.new(0.to_d)

    monthly_changes.each do |(month_key, account_id), amount|
      m = extract_month(month_key)
      next unless m
      if asset_account_ids.include?(account_id)
        monthly_asset_delta[m] += amount.to_d
      elsif liability_account_ids.include?(account_id)
        monthly_liability_delta[m] += amount.to_d
      end
    end

    total_asset_delta = monthly_asset_delta.values.sum
    total_liability_delta = monthly_liability_delta.values.sum

    {
      current_assets: current_assets,
      current_liabilities: current_liabilities,
      current_net_worth: current_assets + current_liabilities,
      monthly_asset_delta: monthly_asset_delta,
      monthly_liability_delta: monthly_liability_delta,
      total_asset_delta: total_asset_delta,
      total_liability_delta: total_liability_delta,
      estimated_start_assets: current_assets - total_asset_delta,
      estimated_start_liabilities: current_liabilities - total_liability_delta,
      asset_account_ids: asset_account_ids,
      liability_account_ids: liability_account_ids
    }
  end

  # 计算净资产趋势数据
  # 返回格式: { labels: [...], net_worth: [...], assets: [...], liabilities: [...] }
  def compute_net_worth_trend
    balance_data = compute_balance_data
    months = build_months_range

    trend = []
    cumulative_asset = 0.to_d
    cumulative_liability = 0.to_d

    months.each do |month_date|
      m = month_date.month
      cumulative_asset += balance_data[:monthly_asset_delta][m] || 0
      cumulative_liability += balance_data[:monthly_liability_delta][m] || 0

      asset_val = balance_data[:estimated_start_assets] + cumulative_asset
      liability_val = balance_data[:estimated_start_liabilities] + cumulative_liability
      net_val = asset_val + liability_val

      trend << {
        month: month_date,
        label: month_label(month_date),
        assets: asset_val.round(2).to_f,
        liabilities: liability_val.round(2).to_f,
        net_worth: net_val.round(2).to_f
      }
    end

    {
      labels: trend.map { |t| t[:label] },
      net_worth: trend.map { |t| t[:net_worth] },
      assets: trend.map { |t| t[:assets] },
      liabilities: trend.map { |t| t[:liabilities] },
      details: trend
    }
  end

  # 计算年度资产趋势（用于年报）
  # 返回12个月的资产/负债/净资产趋势数组
  def compute_yearly_asset_trend
    balance_data = compute_balance_data
    months = []

    cumulative_asset = 0.to_d
    cumulative_liability = 0.to_d

    (1..12).each do |m|
      cumulative_asset += balance_data[:monthly_asset_delta][m] || 0
      cumulative_liability += balance_data[:monthly_liability_delta][m] || 0

      asset_val = balance_data[:estimated_start_assets] + cumulative_asset
      liability_val = balance_data[:estimated_start_liabilities] + cumulative_liability
      net_val = asset_val + liability_val

      months << {
        label: "#{m}月",
        month: m,
        assets: asset_val.round(2).to_f,
        liabilities: liability_val.round(2).to_f,
        net_worth: net_val.round(2).to_f
      }
    end

    months
  end

  private

  # 加载所有账户的当前余额
  def load_current_balances
    # 有交易记录的账户
    with_entries = Account.visible.included_in_total
      .joins("LEFT JOIN entries ON entries.account_id = accounts.id AND entries.entryable_type = 'Entryable::Transaction'")
      .group("accounts.id")
      .pluck(Arel.sql("accounts.id, accounts.type, accounts.initial_balance + COALESCE(SUM(entries.amount), 0)"))
      .to_h { |id, type, bal| [ id, { type: type, balance: bal.to_d } ] }

    # 无交易记录的账户（补充初始余额）
    Account.visible.included_in_total.where.not(id: with_entries.keys)
      .pluck(:id, :type, :initial_balance)
      .each { |id, type, bal| with_entries[id] = { type: type, balance: bal.to_d } }

    with_entries
  end

  # 加载日期范围内的月度账户变动
  def load_monthly_changes
    Entry.where(date: start_date..end_date, entryable_type: "Entryable::Transaction")
      .group("date_trunc('month', date)")
      .group(:account_id)
      .sum(:amount)
  end

  # 构建日期范围内的月份列表
  def build_months_range
    months = []
    current = start_date.beginning_of_month
    while current <= end_date.beginning_of_month
      months << current
      current = current.next_month
    end
    months
  end

  # 从 date_trunc 结果中提取月份
  def extract_month(month_key)
    month_key.month rescue nil
  end

  # 生成月份标签
  def month_label(date)
    date.strftime("%m月")
  end
end
