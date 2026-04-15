require "test_helper"

class AccountsBillStatementTest < ActionDispatch::IntegrationTest
  setup do
    @credit_card = FactoryBot.create(:account, :credit_card)
    @cash_account = FactoryBot.create(:account)
  end

  # === create_bill_statement ===

  test "create bill statement with valid params" do
    post "/accounts/#{@credit_card.id}/create_bill_statement", params: {
      billing_date: "2026-03-16",
      statement_amount: "3000.50"
    }, as: :json

    assert_response :success
    data = JSON.parse(response.body)
    assert data["success"]
    assert_equal "2026-03-16", data["statement"]["billing_date"]
    assert_in_delta 3000.50, data["statement"]["statement_amount"].to_f, 0.005
  end

  test "create bill statement rejects non-credit account" do
    post "/accounts/#{@cash_account.id}/create_bill_statement", params: {
      billing_date: "2026-03-16",
      statement_amount: "1000"
    }, as: :json

    assert_response :unprocessable_entity
    data = JSON.parse(response.body)
    assert_includes data["error"], "不是信用卡"
  end

  test "create bill statement rejects invalid date" do
    post "/accounts/#{@credit_card.id}/create_bill_statement", params: {
      billing_date: "not-a-date",
      statement_amount: "1000"
    }, as: :json

    assert_response :bad_request
    data = JSON.parse(response.body)
    assert_includes data["error"], "日期格式错误"
  end

  test "create bill statement rejects zero amount" do
    post "/accounts/#{@credit_card.id}/create_bill_statement", params: {
      billing_date: "2026-03-16",
      statement_amount: "0"
    }, as: :json

    assert_response :bad_request
    data = JSON.parse(response.body)
    assert_includes data["error"], "金额必须大于0"
  end

  test "create bill statement rejects negative amount" do
    post "/accounts/#{@credit_card.id}/create_bill_statement", params: {
      billing_date: "2026-03-16",
      statement_amount: "-100"
    }, as: :json

    assert_response :bad_request
    data = JSON.parse(response.body)
    assert_includes data["error"], "金额必须大于0"
  end

  test "create bill statement upserts on duplicate billing_date" do
    # 首次创建
    post "/accounts/#{@credit_card.id}/create_bill_statement", params: {
      billing_date: "2026-03-16",
      statement_amount: "3000"
    }, as: :json
    assert_response :success

    # 同一日期更新金额
    post "/accounts/#{@credit_card.id}/create_bill_statement", params: {
      billing_date: "2026-03-16",
      statement_amount: "3500"
    }, as: :json
    assert_response :success

    data = JSON.parse(response.body)
    assert_in_delta 3500.0, data["statement"]["statement_amount"].to_f, 0.005

    # 验证只有一条记录
    assert_equal 1, @credit_card.bill_statements.count
  end

  test "create bill statement for non-existent account" do
    post "/accounts/999999/create_bill_statement", params: {
      billing_date: "2026-03-16",
      statement_amount: "1000"
    }, as: :json

    assert_response :not_found
  end

  # === bills (账单列表) ===

  test "bills endpoint returns JSON for credit card" do
    BillStatement.create!(
      account: @credit_card,
      billing_date: Date.new(2026, 2, 16),
      statement_amount: 3000.00
    )

    get "/accounts/#{@credit_card.id}/bills.json", params: { count: 3 }

    assert_response :success
    data = JSON.parse(response.body)
    assert data.key?("bills")
  end

  test "bills endpoint returns empty for non-credit account" do
    get "/accounts/#{@cash_account.id}/bills.json"

    assert_response :unprocessable_entity
    data = JSON.parse(response.body)
    assert data.key?("error")
  end
end
