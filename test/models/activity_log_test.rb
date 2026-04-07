require "test_helper"

class ActivityLogTest < ActiveSupport::TestCase
  setup do
    @account = FactoryBot.create(:account)
    @category = FactoryBot.create(:category)
  end

  test "should log create action" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: "CNY",
      date: Date.current,
      name: "Test Entry",
      entryable: Entryable::Transaction.new(category: @category, kind: "expense")
    )

    assert ActivityLog.where(item: entry, action: "create").exists?
  end

  test "should log update action" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: "CNY",
      date: Date.current,
      name: "Original Name",
      entryable: Entryable::Transaction.new(category: @category, kind: "expense")
    )

    entry.update!(name: "Updated Name")

    log = ActivityLog.where(item: entry, action: "update").last
    assert log.present?
    assert log.changeset.present?
  end

  test "should log destroy action" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: "CNY",
      date: Date.current,
      name: "Test Entry",
      entryable: Entryable::Transaction.new(category: @category, kind: "expense")
    )
    entry_id = entry.id

    entry.destroy

    assert ActivityLog.where(item_type: "Entry", item_id: entry_id, action: "destroy").exists?
  end

  test "revert update should restore old values" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: "CNY",
      date: Date.current,
      name: "Original Name",
      entryable: Entryable::Transaction.new(category: @category, kind: "expense")
    )

    entry.update!(name: "Changed Name")

    log = ActivityLog.where(item: entry, action: "update").last
    log.revert!

    entry.reload
    assert_equal "Original Name", entry.name
  end

  test "revert destroy should restore record" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: "CNY",
      date: Date.current,
      name: "Test Entry",
      entryable: Entryable::Transaction.new(category: @category, kind: "expense")
    )
    entry_id = entry.id

    entry.destroy

    log = ActivityLog.where(item_type: "Entry", item_id: entry_id, action: "destroy").last
    restored = log.revert!

    assert restored.persisted?
    assert_equal "Test Entry", restored.name
  end

  test "changes_summary should return formatted string" do
    entry = Entry.create!(
      account: @account,
      amount: 100,
      currency: "CNY",
      date: Date.current,
      name: "Original",
      entryable: Entryable::Transaction.new(category: @category, kind: "expense")
    )

    entry.update!(name: "Changed")

    log = ActivityLog.where(item: entry, action: "update").last
    summary = log.changes_summary

    assert summary.include?("name")
  end

  test "should not log create revert" do
    log = ActivityLog.new(action: "create")
    assert_equal false, log.revert!
  end

  test "should validate action inclusion" do
    log = ActivityLog.new(
      item_type: "Entry",
      item_id: 1,
      action: "invalid_action"
    )

    assert_not log.valid?
    assert log.errors[:action].any?
  end
end
