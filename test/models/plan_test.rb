require "test_helper"

class PlanTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Test Account", type: "CASH", initial_balance: 1000)
  end

  test "should be valid with required attributes" do
    plan = Plan.new(
      name: "Test Plan",
      amount: 100,
      day_of_month: 15,
      type: Plan::ONE_TIME
    )
    assert plan.valid?
  end

  test "should require name" do
    plan = Plan.new(amount: 100, day_of_month: 15)
    assert_not plan.valid?
    assert plan.errors.of_kind?(:name, :blank)
  end

  test "should require amount" do
    plan = Plan.new(name: "Test", day_of_month: 15)
    assert_not plan.valid?
    assert plan.errors.of_kind?(:amount, :blank)
  end

  test "should validate day_of_month range" do
    plan = Plan.new(name: "Test", amount: 100, day_of_month: 0)
    assert_not plan.valid?

    plan.day_of_month = 32
    assert_not plan.valid?

    plan.day_of_month = 15
    assert plan.valid?
  end

  test "should validate plan type" do
    plan = Plan.new(name: "Test", amount: 100, day_of_month: 15, type: "INVALID")
    assert_not plan.valid?
  end

  test "installment plan should require total_amount and installments_total" do
    plan = Plan.new(
      name: "Installment Plan",
      amount: 100,
      day_of_month: 15,
      type: Plan::INSTALLMENT
    )
    assert_not plan.valid?
    assert plan.errors.of_kind?(:total_amount, :blank)
  end

  test "installment plan should be valid with all required fields" do
    plan = Plan.new(
      name: "Installment Plan",
      amount: 100,
      total_amount: 1200,
      installments_total: 12,
      day_of_month: 15,
      type: Plan::INSTALLMENT
    )
    assert plan.valid?
  end

  test "should calculate installments_remaining" do
    plan = Plan.new(
      name: "Installment Plan",
      type: Plan::INSTALLMENT,
      installments_total: 12,
      installments_completed: 3
    )
    assert_equal 9, plan.installments_remaining
  end

  test "should calculate progress_percentage" do
    plan = Plan.new(
      name: "Installment Plan",
      type: Plan::INSTALLMENT,
      installments_total: 12,
      installments_completed: 3
    )
    assert_equal 25.0, plan.progress_percentage
  end

  test "should detect completed installment plan" do
    plan = Plan.new(
      name: "Installment Plan",
      type: Plan::INSTALLMENT,
      installments_total: 12,
      installments_completed: 12
    )
    assert plan.completed?
  end

  test "should calculate next_due_date" do
    plan = Plan.new(
      name: "Test Plan",
      amount: 100,
      day_of_month: 15,
      active: true
    )

    travel_to Date.new(2024, 1, 10) do
      assert_equal Date.new(2024, 1, 15), plan.next_due_date
    end

    travel_to Date.new(2024, 1, 20) do
      assert_equal Date.new(2024, 2, 15), plan.next_due_date
    end
  end

  test "generate_transaction! should create entry" do
    plan = Plan.create!(
      name: "Test Plan",
      amount: 100,
      day_of_month: 15,
      type: Plan::ONE_TIME,
      account: @account,
      active: true
    )

    entry = plan.generate_transaction!

    assert_instance_of Entry, entry
    assert_equal -100, entry.amount
    assert_equal @account, entry.account
  end

  test "generate_transaction! should increment installments_completed for installment plan" do
    plan = Plan.create!(
      name: "Installment Plan",
      amount: 100,
      total_amount: 1200,
      installments_total: 12,
      installments_completed: 0,
      day_of_month: 15,
      type: Plan::INSTALLMENT,
      account: @account,
      active: true
    )

    plan.generate_transaction!
    assert_equal 1, plan.reload.installments_completed
  end

  test "generate_transaction! should deactivate completed installment plan" do
    plan = Plan.create!(
      name: "Installment Plan",
      amount: 100,
      total_amount: 100,
      installments_total: 1,
      installments_completed: 0,
      day_of_month: 15,
      type: Plan::INSTALLMENT,
      account: @account,
      active: true
    )

    plan.generate_transaction!
    assert_not plan.reload.active?
  end
end
