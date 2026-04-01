# frozen_string_literal: true

require "test_helper"

class EntrySearchTest < ActiveSupport::TestCase
  setup do
    @account = FactoryBot.create(:account)
    @category = FactoryBot.create(:category)
    @tag = FactoryBot.create(:tag)
    
    @entry_income = Entry.create!(
      account: @account,
      name: "Salary",
      amount: 5000,
      date: Date.new(2024, 1, 15),
      entryable: Entryable::Transaction.create!(
        category: @category,
        kind: "income"
      )
    )
    
    @entry_expense = Entry.create!(
      account: @account,
      name: "Lunch",
      amount: -50,
      date: Date.new(2024, 1, 20),
      entryable: Entryable::Transaction.create!(
        category: @category,
        kind: "expense"
      )
    )
  end

  test "should filter by account" do
    search = EntrySearch.new(account_id: @account.id)
    results = search.build_query(Entry.all)
    assert_includes results, @entry_income
    assert_includes results, @entry_expense
  end

  test "should filter by date range" do
    search = EntrySearch.new(start_date: "2024-01-15", end_date: "2024-01-15")
    results = search.build_query(Entry.all)
    assert_includes results, @entry_income
    assert_not_includes results, @entry_expense
  end

  test "should filter by period month" do
    search = EntrySearch.new(period_type: "month", period_value: "2024-01")
    results = search.build_query(Entry.all)
    assert_includes results, @entry_income
    assert_includes results, @entry_expense
  end

  test "should filter by kind" do
    search = EntrySearch.new(kind: "income")
    results = search.build_query(Entry.all)
    assert_includes results, @entry_income
    assert_not_includes results, @entry_expense
  end

  test "should filter by category" do
    search = EntrySearch.new(category_id: @category.id)
    results = search.build_query(Entry.all)
    assert_includes results, @entry_income
    assert_includes results, @entry_expense
  end

  test "should filter by search term" do
    search = EntrySearch.new(search: "Salary")
    results = search.build_query(Entry.all)
    assert_includes results, @entry_income
    assert_not_includes results, @entry_expense
  end

  test "should filter by amount range" do
    search = EntrySearch.new(min_amount: 100)
    results = search.build_query(Entry.all)
    assert_includes results, @entry_income
    assert_not_includes results, @entry_expense
  end

  test "should sort by date desc" do
    search = EntrySearch.new(sort: "date_desc")
    results = search.build_query(Entry.all).to_a
    assert_equal @entry_expense, results.first if results.include?(@entry_expense)
  end

  test "should sort by date asc" do
    search = EntrySearch.new(sort: "date_asc")
    results = search.build_query(Entry.all).to_a
    assert_equal @entry_income, results.first if results.include?(@entry_income)
  end

  test "should return active_filters_list" do
    search = EntrySearch.new(account_id: @account.id, search: "test")
    filters = search.active_filters_list
    assert_equal 2, filters.count
    assert_equal "account_id", filters.first[:key]
    assert_equal "search", filters.last[:key]
  end

  test "should count filters correctly" do
    search = EntrySearch.new(account_id: @account.id, category_id: @category.id)
    assert_equal 2, search.filters_count
    assert search.active_filters?
  end

  test "should clear filter" do
    search = EntrySearch.new(account_id: @account.id, category_id: @category.id)
    new_params = search.clear_filter(:account_id)
    assert_not new_params.key?(:account_id)
    assert new_params.key?(:category_id)
  end
end