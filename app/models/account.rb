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
  has_many :transaction_entries, -> { where(entryable_type: "Entryable::Transaction") }, class_name: "Entry"
  has_many :valuation_entries, -> { where(entryable_type: "Entryable::Valuation") }, class_name: "Entry"
  has_many :trade_entries, -> { where(entryable_type: "Entryable::Trade") }, class_name: "Entry"
  has_many :plans, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy
  has_many :bill_statements, dependent: :destroy

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

    month_entries = transaction_entries
      .joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id AND entries.entryable_type = 'Entryable::Transaction'")
      .where(date: start_date..end_date)

    {
      income: month_entries.where(entryable_transactions: { kind: "income" }).sum(:amount),
      expense: month_entries.where(entryable_transactions: { kind: "expense" }).sum("entries.amount * -1")
    }
  end

  def currency_symbol
    Money.symbol(currency)
  end

  def type_name
    ACCOUNT_TYPES[type] || type.presence || "账户"
  end

  def cash_flow(from_date, to_date)
    period_entries = transaction_entries
      .joins("INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id AND entries.entryable_type = 'Entryable::Transaction'")
      .where(date: from_date..to_date)
    income = period_entries.where(entryable_transactions: { kind: "income" }).sum(:amount)
    expense = period_entries.where(entryable_transactions: { kind: "expense" }).sum("entries.amount * -1")
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
    type == "CREDIT" && billing_day.present?
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

    if billing_day_mode == "next"
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
      label: format_bill_label(cycle_end),
      # unbilled: 今天还没到账单日
      unbilled: (Date.current >= cycle_start && Date.current < cycle_end)
    }
  end

  # 当前正在进行的账单周期（可能已出账或未出账）
  def current_bill_cycle
    bill_cycle_for(Date.current)
  end

  # 最近 N 期的账单周期
  # 返回数组：[未出账单(可选), XX月账单, XX月账单, ...]
  # 未出账单：今天还没到账单日
  def bill_cycles(count = 3)
    return [] unless credit_card?

    cycles = []
    base = Date.current

    # 找未出账单：今天在某账期内但还没到账单日
    unbilled_cycle = nil
    (0..2).each do |i|
      c = bill_cycle_for(base - i.months)
      if c && c[:unbilled]
        unbilled_cycle = c
        break
      end
    end

    # 如果有未出账单，加到数组第一位
    if unbilled_cycle
      cycles << unbilled_cycle
      # 最近一期已出账单 = 未出账单的前一期
      last_start = unbilled_cycle[:start_date] - 1.month
      last_end = unbilled_cycle[:end_date] - 1.month
      cycles << {
        start_date: last_start,
        end_date: last_end,
        due_date: calculate_due_date(last_end),
        label: format_bill_label(last_end),
        unbilled: false
      }
      # 往前推历史账单
      (1...count).each do |i|
        hist_start = last_start - i.months
        hist_end = last_end - i.months
        cycles << {
          start_date: hist_start,
          end_date: hist_end,
          due_date: calculate_due_date(hist_end),
          label: format_bill_label(hist_end),
          unbilled: false
        }
      end
    else
      # 没有未出账单：今天已经过了最近账单日，找最近一期已出账单
      last_cycle = nil
      (0..2).each do |i|
        c = bill_cycle_for(base - i.months)
        if c && !c[:unbilled]
          last_cycle = c
          break
        end
      end

      if last_cycle
        cycles << last_cycle
        (1...count).each do |i|
          hist_start = last_cycle[:start_date] - i.months
          hist_end = last_cycle[:end_date] - i.months
          cycles << {
            start_date: hist_start,
            end_date: hist_end,
            due_date: calculate_due_date(hist_end),
            label: format_bill_label(hist_end),
            unbilled: false
          }
        end
      end
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

    result = scope.pick(
      Arel.sql("SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN amount < 0 THEN 1 ELSE 0 END)"),
      Arel.sql("SUM(CASE WHEN amount > 0 THEN 1 ELSE 0 END)")
    )

    total_spend, total_repay = result[0..1].map { |v| v.to_d }
    spend_count, repay_count = result[2..3].map { |v| v.to_i }

    {
      spend_amount: total_spend,
      repay_amount: total_repay,
      balance_due: total_spend - total_repay,
      spend_count: spend_count,
      repay_count: repay_count
    }
  end

  # 批量计算多个账单周期的交易汇总（使用 Arel 安全构建 SQL）
  # 单次聚合查询，高效且安全
  def batch_bill_cycle_summary(cycles)
    return {} if cycles.empty?

    min_start = cycles.map { |c| c[:start_date] }.min
    max_end = cycles.map { |c| c[:end_date] }.max

    entry_table = Entry.arel_table
    aggs = []

    cycles.each do |cycle|
      start_date = cycle[:start_date]
      end_date = cycle[:end_date]

      # 条件：日期在周期内
      date_condition = entry_table[:date].gteq(start_date).and(entry_table[:date].lteq(end_date))

      # 消费金额聚合（amount < 0 时取 ABS）
      spend_condition = date_condition.and(entry_table[:amount].lt(0))
      spend_abs = Arel::Nodes::NamedFunction.new("ABS", [ entry_table[:amount] ])
      spend_sum = Arel::Nodes::Case.new.when(spend_condition).then(spend_abs).else(0)
      aggs << spend_sum.sum

      # 还款金额聚合（amount > 0）
      repay_condition = date_condition.and(entry_table[:amount].gt(0))
      repay_sum = Arel::Nodes::Case.new.when(repay_condition).then(entry_table[:amount]).else(0)
      aggs << repay_sum.sum

      # 消费笔数聚合
      spend_cnt = Arel::Nodes::Case.new.when(spend_condition).then(1).else(0)
      aggs << spend_cnt.sum

      # 还款笔数聚合
      repay_cnt = Arel::Nodes::Case.new.when(repay_condition).then(1).else(0)
      aggs << repay_cnt.sum
    end

    result = transaction_entries.where(date: min_start..max_end).pick(*aggs)

    if result.nil?
      return cycles.each_with_object({}) do |cycle, hash|
        hash[cycle[:end_date]] = {
          spend_amount: 0.to_d,
          repay_amount: 0.to_d,
          balance_due: 0.to_d,
          spend_count: 0,
          repay_count: 0
        }
      end
    end

    cycles.each_with_index.each_with_object({}) do |(cycle, idx), hash|
      base = idx * 4
      spend_amount = result[base].to_d
      repay_amount = result[base + 1].to_d
      spend_count = result[base + 2].to_i
      repay_count = result[base + 3].to_i

      hash[cycle[:end_date]] = {
        spend_amount: spend_amount,
        repay_amount: repay_amount,
        balance_due: spend_amount - repay_amount,
        spend_count: spend_count,
        repay_count: repay_count
      }
    end
  end

  # 带账单金额的账单周期（根据公式计算）
  # 公式：本期账单金额 = 本期消费 - 本期还款 + 上期账单金额
  def bill_cycles_with_statement(count = 3)
    cycles = bill_cycles(count)
    return cycles unless credit_card?

    stored = bill_statements.order(:billing_date).to_a
    return cycles if stored.empty?

    earliest_base = stored.first

    months_from_base = (Date.current.year * 12 + Date.current.month) - (earliest_base.billing_date.year * 12 + earliest_base.billing_date.month)
    needed_cycles = months_from_base + count + 2

    all_cycles = bill_cycles(needed_cycles.clamp(1, 60))
    cycles_by_date = all_cycles.sort_by { |c| c[:end_date] }

    # 批量获取所有周期的 summary（一次查询）
    summaries = batch_bill_cycle_summary(cycles_by_date)

    prev_amount = nil
    base_found = false

    cycles_by_date.each do |cycle|
      stored_for_cycle = stored.find do |s|
        s.billing_date.year == cycle[:end_date].year &&
        s.billing_date.month == cycle[:end_date].month
      end

      if stored_for_cycle
        cycle[:statement_amount] = stored_for_cycle.statement_amount.round(2)
        prev_amount = stored_for_cycle.statement_amount
        base_found = true
      elsif base_found
        summary = summaries[cycle[:end_date]]
        cycle[:statement_amount] = (summary[:spend_amount] - summary[:repay_amount] + prev_amount).round(2)
        prev_amount = cycle[:statement_amount]
      else
        cycle[:statement_amount] = nil
      end
    end

    if base_found && cycles_by_date.first[:end_date] < earliest_base.billing_date
      base_cycle_idx = cycles_by_date.find_index do |c|
        c[:end_date].year == earliest_base.billing_date.year &&
        c[:end_date].month == earliest_base.billing_date.month
      end
      if base_cycle_idx && base_cycle_idx > 0
        prev_amount = earliest_base.statement_amount
        (base_cycle_idx - 1).downto(0) do |idx|
          cycle = cycles_by_date[idx]
          summary = summaries[cycle[:end_date]]
          cycle[:statement_amount] = (prev_amount - (summary[:spend_amount] - summary[:repay_amount])).round(2)
          prev_amount = cycle[:statement_amount]
        end
      end
    end

    cycles_by_date.last(count).reverse
  end

  private

  # 根据账单截止日计算还款到期日
  def calculate_due_date(bill_end_date)
    case due_day_mode
    when "relative"
      # 还款日 = 账单日后 N 天
      offset_days = due_day_offset || 20
      bill_end_date + offset_days.days
    else
      # 固定还款日：取账单结束日的下个月 due_day 号
      due_d = (due_day || 5).to_i
      due_month = (bill_end_date + 1.month).beginning_of_month
      # 确保不超过该月最后一天
      actual_day = [ due_d, due_month.end_of_month.day ].min
      Date.new(due_month.year, due_month.month, actual_day)
    end
  end

  # 格式化账单标签如 "02月账单"
  def format_bill_label(cycle_end)
    "#{sprintf('%02d', cycle_end.month)}月账单"
  end
end
