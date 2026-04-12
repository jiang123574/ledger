# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BudgetItems", type: :request do
  let(:single_budget) { create(:single_budget, name: "Test Budget") }

  before do
    login
  end

  describe "POST /single_budgets/:single_budget_id/budget_items" do
    let(:valid_attributes) do
      {
        budget_item: {
          name: "New Item",
          amount: 1000,
          notes: "Test notes"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new budget item" do
        expect {
          post single_budget_budget_items_path(single_budget), params: valid_attributes
        }.to change(BudgetItem, :count).by(1)
      end

      it "redirects" do
        post single_budget_budget_items_path(single_budget), params: valid_attributes
        expect(response).to be_redirect
        expect(flash[:notice]).to eq("预算项已添加")
      end
    end
  end

  describe "DELETE /single_budgets/:single_budget_id/budget_items/:id" do
    let!(:budget_item) { create(:budget_item, single_budget: single_budget) }

    it "destroys the budget item" do
      expect {
        delete single_budget_budget_item_path(single_budget, budget_item)
      }.to change(BudgetItem, :count).by(-1)
    end

    it "redirects" do
      delete single_budget_budget_item_path(single_budget, budget_item)
      expect(response).to be_redirect
      expect(flash[:notice]).to eq("预算项已删除")
    end
  end
end
