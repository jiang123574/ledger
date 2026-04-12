# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts Comprehensive", type: :request do
  before { login }

  let(:account) { create(:account, initial_balance: 1000) }

  describe "GET /accounts" do
    it "renders the index page" do
      get "/accounts"
      expect(response).to have_http_status(:ok)
    end

    it "shows account names" do
      account
      get "/accounts"
      expect(response.body).to include(account.name)
    end

    it "renders with entries section" do
      create(:entry, account: account)
      get "/accounts"
      expect(response).to have_http_status(:ok)
    end

    it "renders with account type filter" do
      create(:account, type: "CREDIT_CARD")
      get "/accounts"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /accounts" do
    it "creates a new account" do
      expect {
        post "/accounts", params: {
          account: { name: "新账户", type: "CASH", currency: "CNY", initial_balance: 500 }
        }
      }.to change(Account, :count).by(1)

      expect(response).to redirect_to(accounts_path)
      expect(flash[:notice]).to eq("账户已创建")
    end

    it "creates account with sort_order" do
      post "/accounts", params: {
        account: { name: "排序账户", type: "CASH", currency: "CNY", initial_balance: 0, sort_order: 5 }
      }
      expect(Account.last.sort_order).to eq(5)
    end

    it "redirects with alert for invalid params" do
      post "/accounts", params: {
        account: { name: "", type: "CASH" }
      }
      expect(response).to redirect_to(accounts_path)
      expect(flash[:alert]).to be_present
    end

    it "redirects on success with HTML" do
      post "/accounts", params: {
        account: { name: "成功账户", type: "CASH", currency: "CNY", initial_balance: 0 }
      }
      expect(response).to redirect_to(accounts_path)
    end
  end

  describe "PATCH /accounts/:id" do
    it "updates the account name" do
      patch account_path(account), params: {
        account: { name: "更新名称" }
      }
      expect(response).to redirect_to(accounts_path)
      expect(account.reload.name).to eq("更新名称")
    end

    it "updates the account balance" do
      patch account_path(account), params: {
        account: { initial_balance: 2000 }
      }
      expect(account.reload.initial_balance).to eq(2000)
    end
  end

  describe "DELETE /accounts/:id" do
    it "deletes the account" do
      acc = create(:account)
      expect {
        delete account_path(acc)
      }.to change(Account, :count).by(-1)
      expect(response).to redirect_to(accounts_path)
    end

    it "shows notice after deletion" do
      acc = create(:account)
      delete account_path(acc)
      expect(flash[:notice]).to eq("账户已删除")
    end
  end

  describe "GET /accounts/stats" do
    it "returns stats as JSON" do
      create(:entry, account: account)
      get stats_accounts_path, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_a(Hash)
    end

    it "accepts period_type parameter" do
      get stats_accounts_path, params: { period_type: "year" }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "accepts account_id parameter" do
      get stats_accounts_path, params: { account_id: account.id }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "accepts type filter" do
      get stats_accounts_path, params: { type: "expense" }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /accounts/entries" do
    it "returns entries as JSON" do
      create(:entry, account: account)
      get entries_accounts_path, as: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["entries"]).to be_an(Array)
    end

    it "accepts page parameter" do
      create(:entry, account: account)
      get entries_accounts_path, params: { page: 1 }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "accepts period_type parameter" do
      get entries_accounts_path, params: { period_type: "year" }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "accepts account_id parameter" do
      get entries_accounts_path, params: { account_id: account.id }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "returns empty entries when no data" do
      get entries_accounts_path, as: :json
      json = JSON.parse(response.body)
      expect(json["entries"]).to be_an(Array)
    end
  end

  describe "PATCH /accounts/:id/reorder" do
    it "reorders the account" do
      a1 = create(:account, sort_order: 0)
      a2 = create(:account, sort_order: 1)

      patch "/accounts/#{a1.id}/reorder",
        params: { target_id: a2.id },
        as: :json

      expect(response).to have_http_status(:ok)
    end
  end
end
