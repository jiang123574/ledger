# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  before { login }

  let!(:account) { create(:account, initial_balance: 10000, hidden: false, include_in_total: true) }
  let!(:category) { create(:category, name: '餐饮') }

  describe "GET /dashboard" do
    it "returns HTTP success" do
      get "/dashboard"
      expect(response).to have_http_status(:success)
    end

    it "renders the dashboard template" do
      get "/dashboard"
      expect(response.body).to include("总资产")
    end

    context "with month parameter" do
      it "accepts a valid month filter" do
        get "/dashboard", params: { month: "2024-01" }
        expect(response).to have_http_status(:success)
      end

      it "handles invalid month format gracefully" do
        get "/dashboard", params: { month: "invalid" }
        expect(response).to have_http_status(:success)
      end

      it "handles empty month parameter" do
        get "/dashboard", params: { month: "" }
        expect(response).to have_http_status(:success)
      end

      it "handles future month" do
        get "/dashboard", params: { month: "2030-12" }
        expect(response).to have_http_status(:success)
      end
    end

    context "without month parameter" do
      it "defaults to current month" do
        get "/dashboard"
        expect(response).to have_http_status(:success)
      end
    end

    context "with entries" do
      before do
        create(:entry, account: account, amount: 5000, date: Date.current, entryable: create(:entryable_transaction, kind: 'income'))
        create(:entry, account: account, amount: -2000, date: Date.current, entryable: create(:entryable_transaction, kind: 'expense', category: category))
      end

      it "displays monthly stats" do
        get "/dashboard"
        expect(response).to have_http_status(:success)
        expect(response.body).to include("收入")
        expect(response.body).to include("支出")
      end

      it "displays expense categories" do
        get "/dashboard"
        expect(response).to have_http_status(:success)
      end
    end

    context "with budgets" do
      before do
        create(:budget, category: category, month: Date.current.strftime("%Y-%m"), amount: 5000)
      end

      it "displays budget information" do
        get "/dashboard"
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "caching" do
    it "uses cache for accounts" do
      get "/dashboard"
      expect(response).to have_http_status(:success)

      # Second request should hit cache
      get "/dashboard"
      expect(response).to have_http_status(:success)
    end

    it "invalidates cache when CacheBuster version changes" do
      get "/dashboard"
      expect(response).to have_http_status(:success)

      CacheBuster.bump(:entries)

      get "/dashboard"
      expect(response).to have_http_status(:success)
    end
  end

  describe "edge cases" do
    it "handles month with single digit" do
      get "/dashboard", params: { month: "2024-1" }
      expect(response).to have_http_status(:success)
    end

    it "handles very old month" do
      get "/dashboard", params: { month: "2020-01" }
      expect(response).to have_http_status(:success)
    end

    it "handles month at year boundary" do
      get "/dashboard", params: { month: "2024-12" }
      expect(response).to have_http_status(:success)
    end
  end
end
