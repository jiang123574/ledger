require "test_helper"

class CounterpartyTest < ActiveSupport::TestCase
  setup do
    Receivable.delete_all
    Counterparty.delete_all
  end

  test "should be valid with name" do
    counterparty = Counterparty.new(name: "Test Counterparty")
    assert counterparty.valid?
  end

  test "should require name" do
    counterparty = Counterparty.new
    assert_not counterparty.valid?
    assert counterparty.errors.of_kind?(:name, :blank)
  end

  test "name should be unique" do
    Counterparty.create!(name: "Test Counterparty")

    duplicate = Counterparty.new(name: "Test Counterparty")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:name, :taken)
  end

  test "should have many receivables" do
    counterparty = Counterparty.create!(name: "Test Counterparty")
    assert_respond_to counterparty, :receivables
  end

  test "should calculate total_receivable_amount" do
    counterparty = Counterparty.create!(name: "Test Counterparty")

    Receivable.create!(
      counterparty: counterparty,
      description: "差旅",
      original_amount: 1000,
      remaining_amount: 1000,
      date: Date.current
    )
    Receivable.create!(
      counterparty: counterparty,
      description: "餐饮",
      original_amount: 500,
      remaining_amount: 500,
      date: Date.current
    )

    assert_equal 1500, counterparty.total_receivable_amount
  end

  test "should calculate pending_receivable_amount" do
    counterparty = Counterparty.create!(name: "Test Counterparty")

    # Pending
    Receivable.create!(
      counterparty: counterparty,
      description: "交通",
      original_amount: 1000,
      remaining_amount: 1000,
      date: Date.current
    )
    # Settled
    Receivable.create!(
      counterparty: counterparty,
      description: "办公",
      original_amount: 500,
      remaining_amount: 0,
      settled_at: Time.current,
      date: Date.current
    )

    assert_equal 1000, counterparty.pending_receivable_amount
  end
end
