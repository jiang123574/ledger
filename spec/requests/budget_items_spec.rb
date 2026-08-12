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

  describe "category uniqueness within a budget" do
    let!(:existing) { create(:budget_item, single_budget: single_budget) } # factory 自动带 category

    it "rejects a duplicate category in the same budget" do
      expect {
        post single_budget_budget_items_path(single_budget),
          params: { budget_item: { category_id: existing.category_id, amount: 100 } }
      }.not_to change(BudgetItem, :count)
      expect(response).to be_redirect
      expect(flash[:alert]).to include("已在本预算中使用")
    end

    it "allows the same category in a different budget" do
      other = create(:single_budget)
      expect {
        post single_budget_budget_items_path(other),
          params: { budget_item: { category_id: existing.category_id, amount: 100 } }
      }.to change(BudgetItem, :count).by(1)
    end

    it "allows multiple items without a category" do
      expect {
        2.times do
          post single_budget_budget_items_path(single_budget),
            params: { budget_item: { name: "手工项", amount: 100 } }
        end
      }.to change(BudgetItem, :count).by(2)
    end

    it "rejects updating an item to a category already used by another item" do
      other_item = create(:budget_item, single_budget: single_budget)
      patch single_budget_budget_item_path(single_budget, other_item),
        params: { budget_item: { category_id: existing.category_id, amount: 100 } }
      expect(response).to be_redirect
      expect(flash[:alert]).to include("已在本预算中使用")
    end

    it "allows editing an item while keeping its own category" do
      patch single_budget_budget_item_path(single_budget, existing),
        params: { budget_item: { category_id: existing.category_id, amount: 200 } }
      expect(response).to be_redirect
      expect(flash[:notice]).to eq("预算项已更新")
      expect(existing.reload.amount).to eq(200)
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
