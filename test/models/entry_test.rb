require "test_helper"

class EntryTest < ActiveSupport::TestCase
  setup do
    @account = FactoryBot.create(:account)
    @category = FactoryBot.create(:category)
  end

  test "should create entry with transaction" do
    entry = Entry.create!(
      account: @account,
      amount: 100.00,
      currency: 'CNY',
      date: Date.current,
      name: 'Test transaction',
      entryable: Entryable::Transaction.new(
        category: @category,
        kind: 'expense'
      )
    )

    assert entry.persisted?
    assert entry.transaction?
    assert_equal 'expense', entry.entryable.kind
  end

  test "classification should return income for positive amount" do
    entry = Entry.new(amount: 100)
    assert_equal 'income', entry.classification
  end

  test "classification should return expense for negative amount" do
    entry = Entry.new(amount: -100)
    assert_equal 'expense', entry.classification
  end

  test "should lock attribute" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current,
      name: 'Test',
      entryable: Entryable::Transaction.new
    )

    entry.lock_attribute!(:amount)
    
    assert entry.locked?(:amount)
    assert_includes entry.locked_field_names, 'amount'
  end

  test "should mark user modified" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current,
      name: 'Test',
      entryable: Entryable::Transaction.new
    )

    entry.mark_user_modified!
    
    assert entry.user_modified?
    assert entry.protected_from_sync?
    assert_equal :user_modified, entry.protection_reason
  end

  test "split! should raise error if amounts don't sum" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current,
      name: 'Test',
      entryable: Entryable::Transaction.new
    )

    error = assert_raises(ArgumentError) do
      entry.split!([
        { name: 'Part 1', amount: 60, category_id: @category.id },
        { name: 'Part 2', amount: 50, category_id: @category.id }
      ])
    end

    assert_match /Split amounts must sum/, error.message
  end

  test "split! should create child entries and exclude parent" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current,
      name: 'Test',
      entryable: Entryable::Transaction.new
    )

    entry.split!([
      { name: 'Part 1', amount: 60, category_id: @category.id },
      { name: 'Part 2', amount: 40, category_id: @category.id }
    ])

    assert entry.split_parent?
    assert entry.excluded?
    assert_equal 2, entry.child_entries.count
    assert entry.user_modified?
  end

  test "unsplit! should remove child entries and restore parent" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current,
      name: 'Test',
      entryable: Entryable::Transaction.new
    )

    entry.split!([
      { name: 'Part 1', amount: 60, category_id: @category.id },
      { name: 'Part 2', amount: 40, category_id: @category.id }
    ])

    entry.unsplit!

    assert_not entry.split_parent?
    assert_not entry.excluded?
    assert_equal 0, entry.child_entries.count
  end

  test "unlock_for_sync! should clear all protection flags" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current,
      name: 'Test',
      entryable: Entryable::Transaction.new,
      user_modified: true,
      import_locked: true
    )

    entry.lock_attribute!(:amount)

    entry.unlock_for_sync!

    assert_not entry.user_modified?
    assert_not entry.import_locked?
    assert_not entry.locked?(:amount)
    assert_not entry.protected_from_sync?
  end

  test "valuation? should return true for valuation entry" do
    entry = Entry.new(entryable_type: 'Entryable::Valuation')
    assert entry.valuation?
    assert_not entry.transaction?
    assert_not entry.trade?
  end

  test "trade? should return true for trade entry" do
    entry = Entry.new(entryable_type: 'Entryable::Trade')
    assert entry.trade?
    assert_not entry.transaction?
    assert_not entry.valuation?
  end

  test "chronological scope should order by date asc" do
    entry1 = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current - 1,
      name: 'Yesterday',
      entryable: Entryable::Transaction.new
    )

    entry2 = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current,
      name: 'Today',
      entryable: Entryable::Transaction.new
    )

    entries = Entry.chronological.to_a
    
    assert_equal entry1, entries.first
    assert_equal entry2, entries.last
  end

  test "reverse_chronological scope should order by date desc" do
    entry1 = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current - 1,
      name: 'Yesterday',
      entryable: Entryable::Transaction.new
    )

    entry2 = Entry.create!(
      account: @account,
      amount: 100,
      currency: 'CNY',
      date: Date.current,
      name: 'Today',
      entryable: Entryable::Transaction.new
    )

    entries = Entry.reverse_chronological.to_a
    
    assert_equal entry2, entries.first
    assert_equal entry1, entries.last
  end

  test "should validate presence of required fields" do
    entry = Entry.new
    
    assert_not entry.valid?
    assert entry.errors[:date].any?
    assert entry.errors[:name].any?
    assert entry.errors[:amount].any?
  end

  test "min_supported_date should return 30 years ago" do
    assert_equal 30.years.ago.to_date, Entry.min_supported_date
  end
end