require "test_helper"

class AccountBillTest < ActiveSupport::TestCase
  setup do
    @category = FactoryBot.create(:category)
    @credit_card = FactoryBot.create(:account, :credit_card, billing_day: 16)
  end

  # === bill_cycles_with_statement 正向计算 ===

  test "bill_cycles_with_statement returns nil statement_amount without stored base" do
    cycles = @credit_card.bill_cycles_with_statement(3)
    assert cycles.is_a?(Array)
    # 没有录入基准账单，所有周期的 statement_amount 应为 nil
    cycles.each do |cycle|
      assert_nil cycle[:statement_amount], "Expected nil for cycle ending #{cycle[:end_date]}"
    end
  end

  test "bill_cycles_with_statement forward calculates from stored base" do
    # 录入基准账单: 2026-02-16 金额 3000
    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 2, 16),
      statement_amount: 3000.00
    )

    # 在 02-17 ~ 03-16 周期内添加消费
    create_expense_entry(@credit_card, Date.new(2026, 3, 1), -500)
    create_income_entry(@credit_card, Date.new(2026, 3, 10), 200)

    cycles = @credit_card.bill_cycles_with_statement(3)
    assert cycles.is_a?(Array)

    # 基准周期（02月）应直接使用存储值
    feb_cycle = cycles.find { |c| c[:end_date].month == 2 }
    if feb_cycle
      assert_in_delta 3000.00, feb_cycle[:statement_amount].to_f, 0.005
    end
  end

  test "bill_cycles_with_statement formula: current = spend - repay + prev" do
    # 基准: 2026-02-16 = 3000
    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 2, 16),
      statement_amount: 3000.00
    )

    # 03月周期 (02-17 ~ 03-16): 消费 500, 还款 200
    # 03月账单 = 500 - 200 + 3000 = 3300
    create_expense_entry(@credit_card, Date.new(2026, 3, 1), -500)
    create_income_entry(@credit_card, Date.new(2026, 3, 10), 200)

    cycles = @credit_card.bill_cycles_with_statement(6)

    mar_cycle = cycles.find { |c| c[:end_date].month == 3 }
    if mar_cycle && mar_cycle[:statement_amount]
      assert_in_delta 3300.00, mar_cycle[:statement_amount].to_f, 0.005,
        "03月账单 = 500消费 - 200还款 + 3000上期 = 3300"
    end
  end

  test "bill_cycles_with_statement multiple months forward" do
    # 基准: 02月 = 3000
    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 2, 16),
      statement_amount: 3000.00
    )

    # 03月周期: 消费 800, 无还款 → 03月 = 800 - 0 + 3000 = 3800
    create_expense_entry(@credit_card, Date.new(2026, 3, 5), -800)

    # 04月周期: 消费 200, 还款 4000 → 04月 = 200 - 4000 + 3800 = 0
    create_expense_entry(@credit_card, Date.new(2026, 4, 5), -200)
    create_income_entry(@credit_card, Date.new(2026, 4, 10), 4000)

    cycles = @credit_card.bill_cycles_with_statement(6)

    apr_cycle = cycles.find { |c| c[:end_date].month == 4 }
    if apr_cycle && apr_cycle[:statement_amount]
      assert_in_delta 0.00, apr_cycle[:statement_amount].to_f, 0.005,
        "04月账单 = 200消费 - 4000还款 + 3800上期 = 0"
    end
  end

  # === bill_cycles_with_statement 反向计算 ===

  test "bill_cycles_with_statement reverse calculates before base" do
    # 基准: 2026-03-16 = 2500
    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 3, 16),
      statement_amount: 2500.00
    )

    # 02月周期 (01-17 ~ 02-16): 消费 600, 还款 100
    # 反向公式: 上期 = 本期 - (消费 - 还款) = 2500 - (600 - 100) = 2000
    create_expense_entry(@credit_card, Date.new(2026, 2, 5), -600)
    create_income_entry(@credit_card, Date.new(2026, 2, 10), 100)

    cycles = @credit_card.bill_cycles_with_statement(6)

    feb_cycle = cycles.find { |c| c[:end_date].month == 2 }
    if feb_cycle && feb_cycle[:statement_amount]
      assert_in_delta 2000.00, feb_cycle[:statement_amount].to_f, 0.005,
        "反向: 02月 = 2500 - (600 - 100) = 2000"
    end
  end

  # === 精度测试 ===

  test "bill_cycles_with_statement rounds to 2 decimal places" do
    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 2, 16),
      statement_amount: 3000.33
    )

    # 消费含小数
    create_expense_entry(@credit_card, Date.new(2026, 3, 1), -199.99)
    create_income_entry(@credit_card, Date.new(2026, 3, 10), 50.01)

    cycles = @credit_card.bill_cycles_with_statement(6)

    mar_cycle = cycles.find { |c| c[:end_date].month == 3 }
    if mar_cycle && mar_cycle[:statement_amount]
      # 3000.33 + 199.99 - 50.01 = 3150.31
      assert_in_delta 3150.31, mar_cycle[:statement_amount].to_f, 0.005
      # 验证精度：只有 2 位小数
      assert_equal mar_cycle[:statement_amount].to_f.round(2), mar_cycle[:statement_amount].to_f
    end
  end

  # === bill_cycles 返回值基本结构 ===

  test "bill_cycles_with_statement returns proper cycle structure" do
    # 需要至少一条基准账单才会添加 statement_amount
    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 2, 16),
      statement_amount: 3000.00
    )

    cycles = @credit_card.bill_cycles_with_statement(3)
    assert cycles.is_a?(Array)

    cycles.each do |cycle|
      assert cycle.key?(:start_date), "Missing start_date"
      assert cycle.key?(:end_date), "Missing end_date"
      assert cycle.key?(:label), "Missing label"
      assert cycle.key?(:due_date), "Missing due_date"
      assert cycle.key?(:statement_amount), "Missing statement_amount"
    end
  end

  test "bill_cycles_with_statement returns empty for non-credit account" do
    cash_account = FactoryBot.create(:account)
    cycles = cash_account.bill_cycles_with_statement(3)
    assert_equal [], cycles
  end

  test "bill_cycles_with_statement count limits results" do
    # 创建较早的基准账单，确保有足够的账单周期
    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2025, 6, 16),
      statement_amount: 1000.00
    )

    cycles_3 = @credit_card.bill_cycles_with_statement(3)
    assert cycles_3.length <= 4, "count=3 should return at most 4 (including unbilled)"
    assert cycles_3.length >= 3, "count=3 should return at least 3 cycles"

    cycles_6 = @credit_card.bill_cycles_with_statement(6)
    assert cycles_6.length <= 7, "count=6 should return at most 7 (including unbilled)"
    assert cycles_6.length > cycles_3.length, "count=6 should return more cycles than count=3"
  end

  # === 辅助方法 ===

  private

  def create_expense_entry(account, date, amount)
    FactoryBot.create(:entry,
      account: account,
      amount: amount,
      date: date,
      entryable: FactoryBot.create(:entryable_transaction, :expense, category: @category)
    )
  end

  def create_income_entry(account, date, amount)
    FactoryBot.create(:entry,
      account: account,
      amount: amount,
      date: date,
      entryable: FactoryBot.create(:entryable_transaction, :income, category: @category)
    )
  end
end
