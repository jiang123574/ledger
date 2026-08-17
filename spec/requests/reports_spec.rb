# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports", type: :request do
  before { login }

  let(:account) { create(:account) }
  let(:income_category) { create(:category, name: "工资", category_type: "INCOME") }
  let(:expense_category) { create(:category, name: "餐饮", category_type: "EXPENSE") }
  let(:current_year) { Date.current.year }

  describe "GET /reports" do
    it "renders the default report" do
      get reports_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /reports/:year (yearly)" do
    it "renders yearly report with correct totals" do
      create(:entry, account: account, amount: 5000, date: Date.current,
             entryable: create(:entryable_transaction, kind: "income", category: income_category))
      create(:entry, account: account, amount: -2000, date: Date.current,
             entryable: create(:entryable_transaction, kind: "expense", category: expense_category))

      get report_year_path(year: current_year)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("收入")
      expect(response.body).to include("支出")
    end

    it "handles out-of-range year by defaulting to current year" do
      get report_year_path(year: 1999)
      expect(response).to have_http_status(:success)
    end

    it "excludes transfer entries from totals" do
      transfer_id = SecureRandom.uuid
      create(:entry, account: account, amount: -500, date: Date.current, transfer_id: transfer_id,
             entryable: create(:entryable_transaction))
      create(:entry, account: account, amount: 500, date: Date.current, transfer_id: transfer_id,
             entryable: create(:entryable_transaction))
      create(:entry, account: account, amount: -100, date: Date.current,
             entryable: create(:entryable_transaction, kind: "expense", category: expense_category))

      get report_year_path(year: current_year)
      expect(response).to have_http_status(:success)
    end

    it "renders turbo frame content with layout: false" do
      get report_year_path(year: current_year), headers: { "Turbo-Frame" => "report-content" }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /reports/:year/:month (monthly)" do
    it "renders monthly report with expense categories" do
      create(:entry, account: account, amount: -800, date: Date.current.beginning_of_month,
             entryable: create(:entryable_transaction, kind: "expense", category: expense_category))

      get report_month_path(year: current_year, month: Date.current.month)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("餐饮")
    end

    it "renders monthly report with income categories" do
      create(:entry, account: account, amount: 10000, date: Date.current.beginning_of_month,
             entryable: create(:entryable_transaction, kind: "income", category: income_category))

      get report_month_path(year: current_year, month: Date.current.month)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("工资")
    end

    it "includes the first partial week in weekly trend when the month doesn't start on Monday" do
      # 2026-08-01 是周六：第一周(8/1~8/2)的支出按 date_trunc('week') 归属到 7/27（周一）键，
      # 修复前 Ruby 侧从 8/1 开始迭代永远访问不到该键，导致第 1 周数据丢失
      create(:entry, account: account, amount: -800, date: Date.new(2026, 8, 1),
             entryable: create(:entryable_transaction, kind: "expense", category: expense_category))

      get report_month_path(year: 2026, month: 8)

      expect(response).to have_http_status(:success)
      expense_data = JSON.parse(response.body[/data-trend-line-chart-expense-data-value="([^"]+)"/, 1])
      expect(expense_data.first).to eq(800.0), "第 1 周应包含 8/1 的支出，实际: #{expense_data.inspect}"
      expect(expense_data.sum).to eq(800.0)
    end

    it "handles invalid month gracefully" do
      get report_month_path(year: current_year, month: 13)
      expect(response).to have_http_status(:success)
    end

    it "handles month 0 gracefully" do
      get report_month_path(year: current_year, month: 0)
      expect(response).to have_http_status(:success)
    end

    it "handles negative month gracefully" do
      get report_month_path(year: current_year, month: -1)
      expect(response).to have_http_status(:success)
    end
  end
end
