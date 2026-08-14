# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Controllers", type: :request do
  describe "Api::CurrencyController" do
    before { login }

    describe "GET /api/currency/rates" do
      before { create(:currency, code: "CNY", rate: 1.0, is_default: true) }

      it "returns currency rates as JSON" do
        get api_currency_rates_path
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["base"]).to eq("CNY")
        expect(json["rates"]).to include("CNY")
      end

      it "includes all currencies" do
        create(:currency, code: "USD", rate: 7.2)
        get api_currency_rates_path
        json = JSON.parse(response.body)
        expect(json["rates"]).to have_key("USD")
      end
    end
  end

  describe "Api::V1::ExternalController" do
    before do
      ENV["EXTERNAL_API_KEY"] = "test_api_key_123"
    end

    after do
      ENV["EXTERNAL_API_KEY"] = nil
    end

    describe "GET /api/v1/external/health" do
      it "returns ok status with valid API key" do
        get api_v1_external_health_path, headers: { "X-API-Key" => "test_api_key_123" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["timestamp"]).to be_present
      end

      it "rejects requests without API key" do
        get api_v1_external_health_path
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects requests with wrong API key" do
        get api_v1_external_health_path, headers: { "X-API-Key" => "wrong_key" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "GET /api/v1/external/context" do
      it "returns accounts and categories" do
        create(:account)
        create(:category)
        get api_v1_external_context_path, headers: { "X-API-Key" => "test_api_key_123" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["accounts"]).to be_an(Array)
        expect(json["categories"]).to be_an(Array)
      end

      it "rejects unauthorized requests" do
        get api_v1_external_context_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "POST /api/v1/external/transactions" do
      let(:account) { create(:account) }
      let(:category) { create(:category, :expense) }

      it "creates an expense entry via API" do
        params = {
          type: "expense",
          amount: 50.0,
          account_id: account.id,
          category_id: category.id,
          note: "API test",
          date: Date.current.to_s
        }
        post api_v1_external_transactions_path, params: params, headers: { "X-API-Key" => "test_api_key_123" }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["entry"]["id"]).to be_present
      end

      it "creates an income entry via API" do
        income_cat = create(:category, :income)
        params = {
          type: "income",
          amount: 200.0,
          account_id: account.id,
          category_id: income_cat.id,
          note: "Income test",
          date: Date.current.to_s
        }
        post api_v1_external_transactions_path, params: params, headers: { "X-API-Key" => "test_api_key_123" }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns not_found for invalid account_id" do
        params = {
          type: "expense",
          amount: 50.0,
          account_id: 99999,
          category_id: category.id,
          note: "API test"
        }
        post api_v1_external_transactions_path, params: params, headers: { "X-API-Key" => "test_api_key_123" }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(json["error"]).to eq("Account not found")
      end

      it "returns not_found for nil account_id" do
        params = {
          type: "expense",
          amount: 50.0,
          account_id: nil,
          category_id: category.id
        }
        post api_v1_external_transactions_path, params: params, headers: { "X-API-Key" => "test_api_key_123" }

        expect(response).to have_http_status(:not_found)
      end

      it "returns errors for invalid entry" do
        # 使用超过 30 年前的日期会触发验证错误
        params = {
          type: "expense",
          account_id: account.id,
          category_id: category.id,
          amount: 100,
          date: "1970-01-01"
        }
        post api_v1_external_transactions_path, params: params, headers: { "X-API-Key" => "test_api_key_123" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(json["errors"]).to be_present
      end

      it "rejects unauthorized requests" do
        post api_v1_external_transactions_path, params: { type: "expense", amount: 50 }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "GET /api/v1/external/transactions" do
      let(:account) { create(:account) }
      let(:headers) { { "X-API-Key" => "test_api_key_123" } }

      before do
        create(:entry, :expense, account: account, date: Date.current - 2, name: "午餐", amount: -45.0)
        create(:entry, :income, account: account, date: Date.current - 1, name: "工资", amount: 8000.0)
      end

      it "returns all transactions with entry details" do
        get api_v1_external_transactions_path, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["total"]).to eq(2)
        expect(json["transactions"].size).to eq(2)

        first = json["transactions"].first
        expect(first).to include(
          "id", "date", "name", "amount", "currency", "kind",
          "entryable_type", "account_id", "account_name",
          "category_id", "category_name", "notes", "created_at", "transfer_id"
        )
        expect(first["kind"]).to be_in(%w[expense income])
        expect(first["account_name"]).to eq(account.name)
      end

      it "exposes transfer_id for transfer entries" do
        transfer_id = SecureRandom.uuid
        target_account = create(:account, name: "目标账户")
        create(:entry, :expense, account: account, name: "转账: A → B", amount: -100.0, transfer_id: transfer_id)
        create(:entry, :income, account: target_account, name: "转账: A → B", amount: 100.0, transfer_id: transfer_id)

        get api_v1_external_transactions_path, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        transfer_entries = json["transactions"].select { |t| t["name"].include?("转账") }
        expect(transfer_entries.size).to eq(2)
        expect(transfer_entries.map { |t| t["transfer_id"] }.uniq).to eq([ transfer_id ])
      end

      it "returns nil transfer_id for regular entries" do
        get api_v1_external_transactions_path, headers: headers

        json = JSON.parse(response.body)
        expect(json["transactions"].all? { |t| t["transfer_id"].nil? }).to be true
      end

      it "filters by account_id" do
        other_account = create(:account)
        create(:entry, :expense, account: other_account, name: "其他账户")

        get api_v1_external_transactions_path, params: { account_id: account.id }, headers: headers

        json = JSON.parse(response.body)
        expect(json["total"]).to eq(2)
        expect(json["transactions"].map { |t| t["account_id"] }.uniq).to eq([ account.id ])
      end

      it "filters by type" do
        get api_v1_external_transactions_path, params: { type: "income" }, headers: headers

        json = JSON.parse(response.body)
        expect(json["total"]).to eq(1)
        expect(json["transactions"].first["kind"]).to eq("income")
      end

      it "filters by date range" do
        get api_v1_external_transactions_path,
            params: { start_date: Date.current - 2, end_date: Date.current - 2 },
            headers: headers

        json = JSON.parse(response.body)
        expect(json["total"]).to eq(1)
        expect(json["transactions"].first["name"]).to eq("午餐")
      end

      it "filters by category_id" do
        category = create(:category)
        entry = Entry.find_by(name: "午餐")
        entry.entryable.update!(category_id: category.id)

        get api_v1_external_transactions_path, params: { category_id: category.id }, headers: headers

        json = JSON.parse(response.body)
        expect(json["total"]).to eq(1)
        expect(json["transactions"].first["category_id"]).to eq(category.id)
      end

      it "respects the limit parameter" do
        create(:entry, :expense, account: account, name: "第三笔")

        get api_v1_external_transactions_path, params: { limit: 2 }, headers: headers

        json = JSON.parse(response.body)
        expect(json["transactions"].size).to eq(2)
        expect(json["total"]).to eq(3)
      end

      it "excludes transactions from hidden accounts" do
        hidden_account = create(:account, hidden: true)
        create(:entry, :expense, account: hidden_account, name: "隐藏账户")

        get api_v1_external_transactions_path, headers: headers

        json = JSON.parse(response.body)
        expect(json["total"]).to eq(2)
      end

      it "returns not_found for invalid account_id" do
        get api_v1_external_transactions_path, params: { account_id: 99999 }, headers: headers

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
      end

      it "rejects unauthorized requests" do
        get api_v1_external_transactions_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when API key is not configured" do
      before { ENV["EXTERNAL_API_KEY"] = nil }

      it "returns forbidden for health" do
        get api_v1_external_health_path
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("API Key not configured")
      end
    end
  end
end
