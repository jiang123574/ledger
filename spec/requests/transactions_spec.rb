# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transactions", type: :request do
  before { http_login }

  describe "GET /transactions" do
    it "redirects to accounts" do
      get "/transactions"
      expect(response).to redirect_to("/accounts")
    end
  end

  describe "POST /transactions" do
    let(:account) { create(:account) }
    let(:category) { create(:category) }

    context "creating an expense" do
      it "creates a new entry via EntryCreationService" do
        expect {
          post "/transactions", params: {
            transaction: {
              type: "EXPENSE",
              amount: 100,
              date: Date.current,
              currency: "CNY",
              account_id: account.id,
              category_id: category.id,
              note: "Test expense"
            }
          }
        }.to change(Entry, :count).by(1)

        expect(response).to have_http_status(:redirect)
      end
    end

    context "creating a transfer" do
      let(:target_account) { create(:account, name: "Target Account") }

      it "creates transfer entries" do
        expect {
          post "/transactions", params: {
            transaction: {
              type: "TRANSFER",
              amount: 200,
              date: Date.current,
              currency: "CNY",
              account_id: account.id,
              target_account_id: target_account.id,
              note: "Test transfer"
            }
          }
        }.to change(Entry, :count).by(2) # 转出 + 转入

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "DELETE /transactions/:id" do
    let(:account) { create(:account) }
    let(:category) { create(:category) }
    let(:entryable) { create(:entryable_transaction, :expense, category: category) }
    let(:entry) { create(:entry, :expense, account: account, entryable: entryable) }

    it "destroys the entry" do
      expect {
        delete "/transactions/#{entry.id}"
      }.to change { Entry.exists?(entry.id) }.from(true).to(false)

      expect(response).to redirect_to("/accounts")
    end
  end
end
