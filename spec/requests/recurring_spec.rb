# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Recurring", type: :request do
  let(:account) { create(:account) }
  let(:category) { create(:category, name: "Test Category") }

  before do
    login
  end

  describe "GET /recurring" do
    it "returns success" do
      get recurring_index_path
      expect(response).to have_http_status(:success)
    end

    it "displays recurring transactions" do
      recurring = create(:recurring_transaction, account: account, category: category, note: "Monthly Rent")
      get recurring_index_path
      expect(response.body).to include("Monthly Rent")
    end
  end

  describe "POST /recurring" do
    let(:valid_attributes) do
      {
        recurring_transaction: {
          transaction_type: "expense",
          amount: 1000.00,
          currency: "CNY",
          category_id: category.id,
          account_id: account.id,
          note: "Monthly subscription",
          frequency: "monthly",
          next_date: Date.tomorrow,
          is_active: 1
        }
      }
    end

    context "with valid parameters" do
      it "creates a new recurring transaction" do
        expect {
          post recurring_index_path, params: valid_attributes
        }.to change(RecurringTransaction, :count).by(1)
      end

      it "redirects to recurring index with success notice" do
        post recurring_index_path, params: valid_attributes
        expect(response).to redirect_to(recurring_index_path)
        expect(flash[:notice]).to eq("定期交易已创建")
      end
    end

    context "with invalid parameters" do
      it "does not create a recurring transaction without amount" do
        expect {
          post recurring_index_path, params: {
            recurring_transaction: { note: "Missing amount", account_id: account.id }
          }
        }.not_to change(RecurringTransaction, :count)
      end

      it "redirects with error alert" do
        post recurring_index_path, params: {
          recurring_transaction: { note: "Missing amount", account_id: account.id }
        }
        expect(response).to redirect_to(recurring_index_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /recurring/:id" do
    let!(:recurring) do
      create(:recurring_transaction, account: account, category: category, note: "Original Note")
    end

    context "with valid parameters" do
      it "updates the recurring transaction" do
        patch recurring_path(recurring), params: { recurring_transaction: { note: "Updated Note" } }
        expect(recurring.reload.note).to eq("Updated Note")
      end

      it "redirects to recurring index with success notice" do
        patch recurring_path(recurring), params: { recurring_transaction: { note: "Updated Note" } }
        expect(response).to redirect_to(recurring_index_path)
        expect(flash[:notice]).to eq("定期交易已更新")
      end
    end

    context "with invalid parameters" do
      it "does not update the recurring transaction" do
        original_note = recurring.note
        patch recurring_path(recurring), params: { recurring_transaction: { amount: nil } }
        expect(recurring.reload.note).to eq(original_note)
      end

      it "redirects with error alert" do
        patch recurring_path(recurring), params: { recurring_transaction: { amount: nil } }
        expect(response).to redirect_to(recurring_index_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /recurring/:id" do
    let!(:recurring) do
      create(:recurring_transaction, account: account, category: category, note: "To Delete")
    end

    it "destroys the recurring transaction" do
      expect {
        delete recurring_path(recurring)
      }.to change(RecurringTransaction, :count).by(-1)
    end

    it "redirects to recurring index with success notice" do
      delete recurring_path(recurring)
      expect(response).to redirect_to(recurring_index_path)
      expect(flash[:notice]).to eq("定期交易已删除")
    end
  end

  describe "POST /recurring/:id/execute" do
    let!(:recurring) do
      create(:recurring_transaction, account: account, category: category, note: "Execute Me")
    end

    it "creates a transaction" do
      expect {
        post execute_recurring_path(recurring)
      }.to change(Entry, :count).by(1)
    end

    it "redirects to recurring index with success notice" do
      post execute_recurring_path(recurring)
      expect(response).to redirect_to(recurring_index_path)
      expect(flash[:notice]).to eq("交易已生成")
    end
  end
end
