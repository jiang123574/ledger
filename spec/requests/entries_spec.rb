# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entries", type: :request do
  before { login }

  let(:account) { create(:account) }
  let(:category) { create(:category, :expense) }

  describe "GET /entries" do
    it "redirects to accounts with 301" do
      get entries_path
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(accounts_path)
    end

    it "passes query parameters through redirect" do
      get entries_path, params: { account_id: account.id, page: 2 }
      expect(response).to redirect_to(accounts_path(account_id: account.id, page: 2))
    end
  end

  describe "POST /entries" do
    let(:valid_params) do
      {
        entry: {
          date: Date.current.to_s,
          kind: "expense",
          amount: "100.50",
          currency: "CNY",
          name: "测试支出",
          notes: "备注",
          category_id: category.id,
          account_id: account.id
        }
      }
    end

    it "creates a new entry" do
      expect {
        post entries_path, params: valid_params
      }.to change(Entry, :count).by(1)

      expect(response).to redirect_to(accounts_path)
      expect(flash[:notice]).to eq("交易已创建")
    end

    it "creates expense entry with negative amount" do
      post entries_path, params: valid_params
      entry = Entry.last
      expect(entry.amount).to eq(-100.50)
    end

    it "creates income entry with positive amount" do
      params = valid_params.deep_merge(entry: { kind: "income" })
      post entries_path, params: params
      entry = Entry.last
      expect(entry.amount).to eq(100.50)
    end

    it "uses provided name" do
      post entries_path, params: valid_params
      entry = Entry.last
      expect(entry.name).to eq("测试支出")
    end

    it "uses notes field" do
      post entries_path, params: valid_params
      entry = Entry.last
      expect(entry.notes).to eq("备注")
    end

    it "sets currency" do
      post entries_path, params: valid_params
      entry = Entry.last
      expect(entry.currency).to eq("CNY")
    end

    it "sets correct date" do
      date = Date.current - 1
      params = valid_params.deep_merge(entry: { date: date.to_s })
      post entries_path, params: params
      entry = Entry.last
      expect(entry.date).to eq(date)
    end

    context "with continue_entry mode" do
      it "returns JSON success response" do
        post entries_path, params: valid_params.merge(continue_entry: "1"), as: :json
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end
    end

    context "with JSON format" do
      it "returns JSON success response" do
        post entries_path, params: valid_params, as: :json
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["message"]).to eq("交易已创建")
      end
    end

    context "with invalid params" do
      it "handles save error with HTML format" do
        params = { entry: { amount: "100", kind: "expense", date: Date.current.to_s, name: "test" } }
        post entries_path, params: params
        expect(response).to redirect_to(accounts_path)
        expect(flash[:alert]).to be_present
      end

      it "returns JSON error for invalid params" do
        params = { entry: { amount: "100", kind: "expense", date: Date.current.to_s, name: "test" } }
        post entries_path, params: params, as: :json
        json = JSON.parse(response.body)
        expect(json["success"]).to be false
        expect(json["error"]).to be_present
      end
    end
  end

  describe "PATCH /entries/:id" do
    let!(:entry) { create(:entry, account: account) }

    it "updates the entry name" do
      patch entry_path(entry), params: { entry: { name: "更新后的名称" } }
      expect(entry.reload.name).to eq("更新后的名称")
      expect(response).to redirect_to(accounts_path)
      expect(flash[:notice]).to eq("交易已更新")
    end

    it "updates the entry notes" do
      patch entry_path(entry), params: { entry: { notes: "新备注" } }
      expect(entry.reload.notes).to eq("新备注")
    end

    context "with JSON format" do
      it "returns JSON success" do
        patch entry_path(entry), params: { entry: { name: "JSON更新" } }, as: :json
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end
    end
  end

  describe "DELETE /entries/:id" do
    let!(:entry) { create(:entry, account: account) }

    it "destroys the entry" do
      expect {
        delete entry_path(entry)
      }.to change(Entry, :count).by(-1)

      expect(response).to redirect_to(accounts_path)
      expect(flash[:notice]).to eq("交易已删除")
    end

    it "passes filter params to redirect" do
      delete entry_path(entry), params: { account_id: account.id }
      expect(response).to redirect_to(accounts_path(account_id: account.id))
    end
  end

  describe "POST /entries/bulk_destroy" do
    let!(:entry1) { create(:entry, account: account) }
    let!(:entry2) { create(:entry, account: account) }

    it "destroys multiple entries" do
      expect {
        post bulk_destroy_entries_path, params: { ids: [entry1.id, entry2.id] }
      }.to change(Entry, :count).by(-2)

      expect(flash[:notice]).to eq("已删除 2 笔交易")
    end

    it "shows alert when no ids provided" do
      post bulk_destroy_entries_path
      expect(flash[:alert]).to eq("请选择要删除的交易")
    end
  end
end
