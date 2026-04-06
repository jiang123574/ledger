class Account < ApplicationRecord
  self.inheritance_column = nil

  ACCOUNT_TYPES = {
    "CASH" => "现金",
    "BANK" => "储蓄卡",
    "CREDIT" => "信用卡",
    "INVESTMENT" => "网络账户",
    "LOAN" => "贷款",
    "DEBT" => "欠款"
  }.freeze

  has_many :entries, dependent: :destroy
  has_many :transaction_entries, -> { where(entryable_type: 'Entryable::Transaction') }, class_name: 'Entry'
  has_many :valuation_entries, -> { where(entryable_type: 'Entryable::Valuation') }, class_name: 'Entry'
  has_many :trade_entries, -> { where(entryable_type: 'Entryable::Trade') }, class_name: 'Entry'
  has_many :plans, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :currency, presence: true, length: { is: 3 }

  scope :visible, -> { where(hidden: false) }
  scope :included_in_total, -> { where(include_in_total: true) }
  scope :by_type, ->(type) { where(type: type) if type.present? }
  scope :by_currency, ->(currency) { where(currency: currency) if currency.present? }
  scope :by_last_activity, -> { order(last_transaction_date: :desc) }

  def self.default_currency
    Currency.default&.code || "CNY"
  end

  def current_balance
    initial_balance.to_d + transaction_entries.sum(:amount).to_d
  end

  # 已废弃：使用 current_balance（基于 Entry）
  def current_balance_from_transactions
    current_balance
  end

  # 优化：单次 SQL 查询，避免 N+1
  def self.total_assets
    result = visible.included_in_total
      .joins("LEFT JOIN entries ON entries.account_id = accounts.id AND entries.entryable_type = 'Entryable::Transaction'")
      .group("accounts.id")
      .pluck(Arel.sql("accounts.id, accounts.initial_balance + COALESCE(SUM(entries.amount), 0)"))
      .to_h

    Account.visible.included_in_total
      .where.not(id: result.keys)
      .pluck(:id, :initial_balance)
      .each { |id, balance| result[id] = balance }

    result.values.sum(&:to_d)
  end

  def self.balance_by_type
    accounts_by_type = visible.included_in_total.group(:type).pluck(:type)

    accounts_by_type.each_with_object({}) do |type, hash|
      result = visible.included_in_total.where(type: type)
        .joins("LEFT JOIN entries ON entries.account_id = accounts.id AND entries.entryable_type = 'Entryable::Transaction'")
        .group("accounts.id")
        .pluck(Arel.sql("accounts.id, accounts.initial_balance + COALESCE(SUM(entries.amount), 0)"))
        .to_h

      visible.included_in_total.where(type: type)
        .where.not(id: result.keys)
        .pluck(:id, :initial_balance)
        .each { |id, balance| result[id] = balance }

      hash[type] = result.values.sum(&:to_d)
    end
  end

  def balance_series(months = 12)
    balances = []
    current = current_balance
    months.times do |i|
      date = i.months.ago.end_of_month
      balances << { date: date, balance: current }
    end
    balances.reverse
  end

  def monthly_flow(month)
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    month_entries = transaction_entries.where(date: start_date..end_date)

    {
      income: month_entries.where('amount > 0').sum(:amount),
      expense: month_entries.where('amount < 0').sum('ABS(amount)')
    }
  end

  def currency_symbol
    Money.symbol(currency)
  end

  def type_name
    ACCOUNT_TYPES[type] || type.presence || "账户"
  end

  def cash_flow(from_date, to_date)
    period_entries = transaction_entries.where(date: from_date..to_date)
    income = period_entries.where('amount > 0').sum(:amount)
    expense = period_entries.where('amount < 0').sum('ABS(amount)')
    { income: income, expense: expense, net: income - expense }
  end

  # 已废弃：使用 update_entries_cache!
  def update_transactions_cache!
    update_entries_cache!
  end

  def update_entries_cache!
    update(
      transactions_count: entries.count,
      last_transaction_date: entries.maximum(:date)
    )
  end

  # ========== 信用卡账单相关 ==========

  # 是否为信用卡
  def credit_card?
    type == 'CREDIT' && billing_day.present?
  end

  # 计算指定月份的账单周期
  # billing_day_mode:
  #   "current" (默认): 账单日当天计入本期 → 上月billing_day+1 ~ 本月billing_day
  #   "next": 账单日当天计入下期 → 上月billing_day ~ 本月billing_day-1
  #
  # 例如 billing_day=16, mode=current, month=2026-03:
  #   账期: 2026-02-17 ~ 2026-03-16
  # 例如 billing_day=16, mode=next, month=2026-03:
  #   账期: 2026-02-16 ~ 2026-03-15
  def bill_cycle_for(month_date = Date.current)
    return nil unless credit_card?
    return nil if billing_day.blank? || billing_day < 1 || billing_day > 28

    day = billing_day.to_i
    year = month_date.year
    month = month_date.month

    begin
      # 上月账单日当天
      prev_billing_day = Date.new(year, month, 1) - 1.month + (day - 1).days
      # 本月账单日当天
      cur_billing_day = Date.new(year, month, day)
    rescue Date::Error
      return nil
    end

    if billing_day_mode == 'next'
      # 账单日计入下期：本期不包含账单日当天
      # 本期: 上月billing_day ~ 本月billing_day-1
      # 例如 billing_day=16: 本期 02-16 ~ 03-15，下期 03-16 ~ 04-15
      cycle_start = prev_billing_day
      cycle_end   = cur_billing_day.yesterday
    else
      # 默认(current)：账单日计入本期
      # 本期: 上月billing_day+1 ~ 本月billing_day
      # 例如 billing_day=16: 本期 02-17 ~ 03-16，上期 01-17 ~ 02-16
      cycle_start = prev_billing_day.tomorrow
      cycle_end   = cur_billing_day
    end

    {
      start_date: cycle_start,
      end_date: cycle_end,
      due_date: calculate_due_date(cycle_end),
      label: format_bill_label(cycle_start),
      # current 始终基于今天判断，不依赖传入的 month_date
      current: (Date.current >= cycle_start && Date.current <= cycle_end)
    }
  end

  # 当前正在进行的账单周期（可能已出账或未出账）
  def current_bill_cycle
    bill_cycle_for(Date.current)
  end

  # 最近 N 期的账单周期（包含当前期 + 未出账单）
  # 返回数组：[未出账单(可选), 当期, 上期, 上上期, ...]
  # 未出账单：当前日期已经过了当期 end_date（即本期已过账单日，下期已经开始但还没到下个账单日）
  def bill_cycles(count = 3)
    return [] unless credit_card?

    cycles = []
    base = Date.current

    # 找到真正的当期：可能需要往前搜几个月
    # 因为 bill_cycle_for(month_date) 对 mode=next 可能返回非当期
    real_current = nil
    (0..2).each do |i|
      c = bill_cycle_for(base - i.months)
      if c && c[:current]
        real_current = c
        break
      end
    end

    # 如果找不到 current，就用 bill_cycle_for(base) 作为基准
    real_current ||= bill_cycle_for(base)

    # 判断是否有未出账单：
    # 今天已经超过了当期的 end_date → 本期已过账单日，下一期是"未出账单"
    has_unbilled = real_current && base > real_current[:end_date]

    # 未出账单 = 下一个账单周期（直接基于 real_current 推算，避免 bill_cycle_for 跳月）
    if has_unbilled
      unbilled_start = real_current[:start_date] + 1.month
      unbilled_end = real_current[:end_date] + 1.month
      cycles << {
        start_date: unbilled_start,
        end_date: unbilled_end,
        due_date: calculate_due_date(unbilled_end),
        label: format_bill_label(unbilled_start),
        current: false
      }
    end

    # 加当前/当期账单
    cycles << real_current if real_current

    # 往前推历史账单（直接从 real_current 的 start/end 减 1 个月）
    # 不能用 bill_cycle_for(target) 因为它基于传入日期所在月份推算会跳月
    (1...count).each do |i|
      hist_start = real_current[:start_date] - i.months
      hist_end = real_current[:end_date] - i.months
      cycles << {
        start_date: hist_start,
        end_date: hist_end,
        due_date: calculate_due_date(hist_end),
        label: format_bill_label(hist_start),
        current: false
      }
    end

    cycles
  end

  # 获取指定标签的账单周期（用于前端点击时查找）
  def bill_cycle_by_label(label)
    bill_cycles(12).find { |c| c[:label] == label }
  end

  # 某个账单周期内的交易汇总（SQL 聚合，单次查询）
  def bill_cycle_summary(start_date:, end_date:)
    scope = transaction_entries.where(date: start_date..end_date)

    # 单次 CASE WHEN 聚合，替代 4 次独立查询
    result = scope.pick(
      Arel.sql("SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN amount < 0 THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN amount > 0 THEN 1 ELSE 0 END)")
    )

    total_spend, total_repay, spend_count, repay_count = result.map { |v| v.to_i }

    {
      spend_amount: total_spend,
      repay_amount: total_repay,
      balance_due: total_spend - total_repay,
      spend_count: spend_count,
      repay_count: repay_count
    }
  end

  private

  # 根据账单截止日计算还款到期日
  def calculate_due_date(bill_end_date)
    case due_day_mode
    when 'relative'
      # 还款日 = 账单日后 N 天
      offset_days = due_day_offset || 20
      bill_end_date + offset_days.days
    else
      # 固定还款日：取账单结束日的下个月 due_day 号
      due_d = (due_day || 5).to_i
      due_month = (bill_end_date + 1.month).beginning_of_month
      # 确保不超过该月最后一天
      actual_day = [due_d, due_month.end_of_month.day].min
      Date.new(due_month.year, due_month.month, actual_day)
    end
  end

  # 格式化账单标签如 "02月账单"
  def format_bill_label(cycle_start)
    "#{sprintf('%02d', cycle_start.month)}月账单"
  end
end
