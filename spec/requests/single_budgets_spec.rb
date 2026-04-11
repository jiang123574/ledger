# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SingleBudgets", type: :request do
  before do
    login
  end

  describe "POST /single_budgets" do
    let(:valid_attributes) do
      {
        single_budget: {
          name: "New Budget",
          total_amount: 5000,
          start_date: Date.current,
          end_date: 30.days.from_now,
          currency: "CNY"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new single budget" do
        expect {
          post single_budgets_path, params: valid_attributes
        }.to change(SingleBudget, :count).by(1)
      end

      it "redirects with success notice" do
        post single_budgets_path, params: valid_attributes
        expect(response).to redirect_to(single_budgets_path)
        expect(flash[:notice]).to eq("单次预算已创建")
      end
    end

    context "with invalid parameters" do
      it "does not create a budget without name" do
        expect {
          post single_budgets_path, params: { single_budget: { name: nil } }
        }.not_to change(SingleBudget, :count)
      end

      it "redirects with error alert" do
        post single_budgets_path, params: { single_budget: { name: nil } }
        expect(response).to redirect_to(single_budgets_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /single_budgets/:id" do
    let(:budget) { create(:single_budget, name: "Original Name") }

    context "with valid parameters" do
      it "updates the budget" do
        patch single_budget_path(budget), params: { single_budget: { name: "Updated Name" } }
        expect(budget.reload.name).to eq("Updated Name")
      end

      it "redirects with success notice" do
        patch single_budget_path(budget), params: { single_budget: { name: "Updated Name" } }
        expect(response).to redirect_to(single_budgets_path)
        expect(flash[:notice]).to eq("单次预算已更新")
      end
    end

    context "with invalid parameters" do
      it "does not update the budget" do
        original_name = budget.name
        patch single_budget_path(budget), params: { single_budget: { name: nil } }
        expect(budget.reload.name).to eq(original_name)
      end

      it "redirects with error alert" do
        patch single_budget_path(budget), params: { single_budget: { name: nil } }
        expect(response).to redirect_to(single_budgets_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /single_budgets/:id" do
    let!(:budget) { create(:single_budget, name: "Delete Me") }

    it "destroys the budget" do
      expect {
        delete single_budget_path(budget)
      }.to change(SingleBudget, :count).by(-1)
    end

    it "redirects with success notice" do
      delete single_budget_path(budget)
      expect(response).to redirect_to(single_budgets_path)
      expect(flash[:notice]).to eq("单次预算已删除")
    end
  end
end
