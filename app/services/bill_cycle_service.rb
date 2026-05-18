# frozen_string_literal: true

# BillCycleService - Handle credit card billing cycle calculations
#
# Extracted from Account model for maintainability
# Handles:
# - Billing cycle generation with statement amounts
# - Batch summary calculations for cycles
#
class BillCycleService
  # Generate billing cycles with statement amounts
  #
  # @param account [Account] Credit card account
  # @param count [Integer] Number of cycles to generate
  # @return [Array<Hash>] Billing cycles with statement data
  def self.cycles_with_statement(account, count = 3)
    service = new(account)
    service.generate_cycles_with_statement(count)
  end

  # Calculate batch summaries for multiple cycles
  #
  # @param account [Account] Credit card account
  # @param cycles [Array<Hash>] Billing cycles
  # @return [Hash<Date, Hash>] Summaries keyed by end_date
  def self.batch_summary(account, cycles)
    service = new(account)
    service.calculate_batch_summary(cycles)
  end

  def initialize(account)
    @account = account
  end

  def generate_cycles_with_statement(count = 3)
    cycles = @account.bill_cycles(count)
    return cycles unless @account.credit_card?

    stored = @account.bill_statements.order(:billing_date).to_a
    return cycles if stored.empty?

    earliest_base = stored.first

    months_from_base = calculate_months_from_base(earliest_base)
    # 确保 needed_cycles 至少为 count，以获取足够多的周期
    needed_cycles = [ months_from_base + count + 2, count ].max.clamp(1, 60)

    all_cycles = @account.bill_cycles(needed_cycles)
    cycles_by_date = all_cycles.sort_by { |c| c[:end_date] }

    summaries = calculate_batch_summary(cycles_by_date)

    enrich_cycles_with_statements(cycles_by_date, stored, summaries, earliest_base)

    cycles_by_date.last(count).reverse
  end

  def calculate_batch_summary(cycles)
    return {} if cycles.empty?

    min_start = cycles.map { |c| c[:start_date] }.min
    max_end = cycles.map { |c| c[:end_date] }.max

    entry_table = Entry.arel_table
    aggs = build_aggregations(cycles, entry_table)

    result = @account.transaction_entries.where(date: min_start..max_end).pick(*aggs)

    build_summary_hash(cycles, result)
  end

  private

  def calculate_months_from_base(earliest_base)
    (Date.current.year * 12 + Date.current.month) -
      (earliest_base.billing_date.year * 12 + earliest_base.billing_date.month)
  end

  def build_aggregations(cycles, entry_table)
    aggs = []

    cycles.each do |cycle|
      start_date = cycle[:start_date]
      end_date = cycle[:end_date]

      date_condition = entry_table[:date].gteq(start_date).and(entry_table[:date].lteq(end_date))

      # Spend aggregation (amount < 0, take ABS)
      spend_condition = date_condition.and(entry_table[:amount].lt(0))
      spend_abs = Arel::Nodes::NamedFunction.new("ABS", [ entry_table[:amount] ])
      spend_sum = Arel::Nodes::Case.new.when(spend_condition).then(spend_abs).else(0)
      aggs << spend_sum.sum

      # Repay aggregation (amount > 0)
      repay_condition = date_condition.and(entry_table[:amount].gt(0))
      repay_sum = Arel::Nodes::Case.new.when(repay_condition).then(entry_table[:amount]).else(0)
      aggs << repay_sum.sum

      # Spend count
      spend_cnt = Arel::Nodes::Case.new.when(spend_condition).then(1).else(0)
      aggs << spend_cnt.sum

      # Repay count
      repay_cnt = Arel::Nodes::Case.new.when(repay_condition).then(1).else(0)
      aggs << repay_cnt.sum
    end

    aggs
  end

  def build_summary_hash(cycles, result)
    if result.nil?
      return cycles.each_with_object({}) do |cycle, hash|
        hash[cycle[:end_date]] = empty_summary
      end
    end

    summaries = {}
    cycles.each_with_index do |cycle, idx|
      base_idx = idx * 4
      summaries[cycle[:end_date]] = {
        spend_amount: result[base_idx].to_d,
        repay_amount: result[base_idx + 1].to_d,
        balance_due: (result[base_idx] - result[base_idx + 1]).to_d,
        spend_count: result[base_idx + 2],
        repay_count: result[base_idx + 3]
      }
    end

    summaries
  end

  def empty_summary
    {
      spend_amount: 0.to_d,
      repay_amount: 0.to_d,
      balance_due: 0.to_d,
      spend_count: 0,
      repay_count: 0
    }
  end

  def enrich_cycles_with_statements(cycles_by_date, stored, summaries, earliest_base)
    prev_amount = nil
    base_found = false

    cycles_by_date.each do |cycle|
      summary = summaries[cycle[:end_date]]

      cycle[:spend_amount] = summary[:spend_amount]
      cycle[:repay_amount] = summary[:repay_amount]
      cycle[:balance_due] = summary[:balance_due]
      cycle[:spend_count] = summary[:spend_count]
      cycle[:repay_count] = summary[:repay_count]

      stored_for_cycle = find_stored_statement(stored, cycle)

      if stored_for_cycle
        cycle[:statement_amount] = stored_for_cycle.statement_amount.round(2)
        prev_amount = stored_for_cycle.statement_amount
        base_found = true
      elsif base_found
        calculate_estimated_statement(cycle, summary, prev_amount)
        prev_amount = cycle[:statement_amount] if cycle[:statement_amount]
      else
        cycle[:statement_amount] = nil
      end
    end

    # Backfill historical cycles before earliest statement
    backfill_historical_statements(cycles_by_date, summaries, earliest_base) if base_found
  end

  def find_stored_statement(stored, cycle)
    stored.find do |s|
      s.billing_date.year == cycle[:end_date].year &&
        s.billing_date.month == cycle[:end_date].month
    end
  end

  def calculate_estimated_statement(cycle, summary, prev_amount)
    if cycle[:unbilled] && prev_amount
      matching_repay = @account.transaction_entries
        .where(date: cycle[:start_date]..cycle[:end_date])
        .where(amount: prev_amount)
        .where("amount > 0")
        .sum(:amount)

      adjusted_repay = summary[:repay_amount] - matching_repay
      cycle[:statement_amount] = (summary[:spend_amount] - adjusted_repay).round(2)
    else
      cycle[:statement_amount] = (summary[:spend_amount] - summary[:repay_amount] + prev_amount).round(2)
    end
  end

  def backfill_historical_statements(cycles_by_date, summaries, earliest_base)
    return unless cycles_by_date.first[:end_date] < earliest_base.billing_date

    base_cycle_idx = cycles_by_date.find_index do |c|
      c[:end_date].year == earliest_base.billing_date.year &&
        c[:end_date].month == earliest_base.billing_date.month
    end

    return unless base_cycle_idx && base_cycle_idx > 0

    prev_amount = earliest_base.statement_amount
    (base_cycle_idx - 1).downto(0) do |idx|
      cycle = cycles_by_date[idx]
      summary = summaries[cycle[:end_date]]
      cycle[:statement_amount] = (prev_amount - (summary[:spend_amount] - summary[:repay_amount])).round(2)
      prev_amount = cycle[:statement_amount]
    end
  end
end
