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

  describe "Api::ExternalController" do
    before do
      ENV["EXTERNAL_API_KEY"] = "test_api_key_123"
    end

    after do
      ENV["EXTERNAL_API_KEY"] = nil
    end

    describe "GET /api/external/health" do
      it "returns ok status with valid API key" do
        get api_external_health_path, headers: { "X-API-Key" => "test_api_key_123" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("ok")
        expect(json["timestamp"]).to be_present
      end

      it "rejects requests without API key" do
        get api_external_health_path
        expect(response).to have_http_status(:unauthorized)
      end

      it "rejects requests with wrong API key" do
        get api_external_health_path, headers: { "X-API-Key" => "wrong_key" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "GET /api/external/context" do
      it "returns accounts and categories" do
        create(:account)
        create(:category)
        get api_external_context_path, headers: { "X-API-Key" => "test_api_key_123" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["accounts"]).to be_an(Array)
        expect(json["categories"]).to be_an(Array)
      end

      it "rejects unauthorized requests" do
        get api_external_context_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe "POST /api/external/transactions" do
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
        post api_external_transactions_path, params: params, headers: { "X-API-Key" => "test_api_key_123" }

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
        post api_external_transactions_path, params: params, headers: { "X-API-Key" => "test_api_key_123" }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns errors for invalid entry" do
        params = { type: "expense", amount: 50.0 }
        post api_external_transactions_path, params: params, headers: { "X-API-Key" => "test_api_key_123" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
      end

      it "rejects unauthorized requests" do
        post api_external_transactions_path, params: { type: "expense", amount: 50 }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when API key is not configured" do
      before { ENV["EXTERNAL_API_KEY"] = nil }

      it "returns forbidden for health" do
        get api_external_health_path
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("API Key not configured")
      end
    end
  end
end
