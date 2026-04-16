require "test_helper"

class BillStatementTest < ActiveSupport::TestCase
  setup do
    @credit_card = FactoryBot.create(:account, :credit_card)
  end

  test "valid with required attributes" do
    statement = BillStatement.new(
      account: @credit_card,
      billing_date: Date.new(2026, 3, 16),
      statement_amount: 3000.00
    )
    assert statement.valid?
  end

  test "requires billing_date" do
    statement = BillStatement.new(
      account: @credit_card,
      statement_amount: 1000.00
    )
    assert_not statement.valid?
    assert statement.errors[:billing_date].present?
  end

  test "requires statement_amount" do
    statement = BillStatement.new(
      account: @credit_card,
      billing_date: Date.new(2026, 3, 16)
    )
    assert_not statement.valid?
    assert statement.errors[:statement_amount].present?
  end

  test "billing_date is unique per account" do
    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 3, 16),
      statement_amount: 3000.00
    )

    duplicate = BillStatement.new(
      account: @credit_card,
      billing_date: Date.new(2026, 3, 16),
      statement_amount: 5000.00
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:billing_date].present?
  end

  test "same billing_date allowed for different accounts" do
    other_card = FactoryBot.create(:account, :credit_card, name: "Other Card")

    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 3, 16),
      statement_amount: 3000.00
    )

    other_statement = BillStatement.new(
      account: other_card,
      billing_date: Date.new(2026, 3, 16),
      statement_amount: 2000.00
    )
    assert other_statement.valid?
  end

  test "belongs to account" do
    statement = BillStatement.new(
      billing_date: Date.new(2026, 3, 16),
      statement_amount: 1000.00
    )
    assert_not statement.valid?
    assert statement.errors[:account].present?
  end

  test "destroyed when account is destroyed" do
    statement = BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 3, 16),
      statement_amount: 3000.00
    )
    @credit_card.destroy!
    assert_not BillStatement.exists?(statement.id)
  end
end
