# frozen_string_literal: true

# SankeyDataService - Generate Sankey diagram data for reports
#
# Extracted from ReportsController#compute_sankey_data
# Generates nodes and links for visualizing income/expense flow
#
class SankeyDataService
  MAX_INCOME_CATEGORIES = 10
  MAX_EXPENSE_CATEGORIES = 15

  def self.generate(start_date, end_date, total_income, total_expense)
    service = new(start_date, end_date, total_income, total_expense)
    service.compute
  end

  def initialize(start_date, end_date, total_income, total_expense)
    @start_date = start_date
    @end_date = end_date
    @total_income = total_income
    @total_expense = total_expense
  end

  def compute
    {
      nodes: build_nodes,
      links: build_links
    }
  end

  private

  def build_nodes
    nodes = []

    # Income category nodes
    top_income_categories.each do |cat_name, _amount|
      nodes << { name: cat_name, type: "income" }
    end
    if other_income_amount > 0
      nodes << { name: "其他收入", type: "income" }
    end

    # Expense category nodes
    top_expense_categories.each do |cat_name, _amount|
      nodes << { name: cat_name, type: "expense" }
    end
    if other_expense_amount > 0
      nodes << { name: "其他支出", type: "expense" }
    end

    # Center nodes
    nodes << { name: "总收入", type: "center_income" }
    nodes << { name: "总支出", type: "center_expense" }

    nodes
  end

  def build_links
    links = []

    # Income to center links
    top_income_categories.each do |cat_name, amount|
      links << { source: cat_name, target: "总收入", value: amount.to_f, type: "income" }
    end
    if other_income_amount > 0
      links << { source: "其他收入", target: "总收入", value: other_income_amount.to_f, type: "income" }
    end

    # Center to center link (flow)
    if @total_income > 0
      expense_flow = [ @total_expense, @total_income ].min
      links << { source: "总收入", target: "总支出", value: expense_flow.to_f, type: "flow" }
    end

    # Center to expense links
    top_expense_categories.each do |cat_name, amount|
      links << { source: "总支出", target: cat_name, value: amount.to_f, type: "expense" }
    end
    if other_expense_amount > 0
      links << { source: "总支出", target: "其他支出", value: other_expense_amount.to_f, type: "expense" }
    end

    links
  end

  def top_income_categories
    @top_income_categories ||= income_categories
      .select { |_, a| a > 0 }
      .first(MAX_INCOME_CATEGORIES)
  end

  def other_income_amount
    @other_income_amount ||= income_categories
      .select { |_, a| a > 0 }
      .drop(MAX_INCOME_CATEGORIES)
      .sum { |_, a| a }
  end

  def top_expense_categories
    @top_expense_categories ||= expense_categories
      .select { |_, a| a > 0 }
      .first(MAX_EXPENSE_CATEGORIES)
  end

  def other_expense_amount
    @other_expense_amount ||= expense_categories
      .select { |_, a| a > 0 }
      .drop(MAX_EXPENSE_CATEGORIES)
      .sum { |_, a| a }
  end

  def income_categories
    Entry.with_category
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: "income" })
      .where(date: @start_date..@end_date)
      .group("categories.id, categories.name")
      .order(Arel.sql("SUM(entries.amount) DESC"))
      .sum("entries.amount")
  end

  def expense_categories
    Entry.with_category
      .transactions_only
      .non_transfers
      .where(entryable_transactions: { kind: "expense" })
      .where(date: @start_date..@end_date)
      .group("categories.id, categories.name")
      .order(Arel.sql("SUM(entries.amount * -1) DESC"))
      .sum("entries.amount * -1")
  end
end
