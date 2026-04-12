# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Budgets", type: :request do
  let(:category) { create(:category, name: "Food", category_type: "EXPENSE") }
  let(:current_month) { Date.today.strftime("%Y-%m") }

  before do
    login
  end

  describe "GET /budgets" do
    it "returns success" do
      get budgets_path
      expect(response).to have_http_status(:success)
    end

    it "displays current month when no month param" do
      get budgets_path
      expect(response.body).to include(current_month)
    end

    it "displays specific month when provided" do
      get budgets_path, params: { month: "2025-01" }
      expect(response.body).to include("2025-01")
    end
  end

  describe "POST /budgets" do
    let(:valid_attributes) do
      {
        budget: {
          category_id: category.id,
          month: current_month,
          amount: 1000.00,
          currency: "CNY"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new budget" do
        expect {
          post budgets_path, params: valid_attributes
        }.to change(Budget, :count).by(1)
      end

      it "redirects to budgets index with the month" do
        post budgets_path, params: valid_attributes
        expect(response).to redirect_to(budgets_path(month: current_month))
        expect(flash[:notice]).to eq("预算已创建")
      end
    end

    context "with invalid parameters" do
      it "does not create a budget without month" do
        expect {
          post budgets_path, params: { budget: { category_id: category.id, amount: 1000 } }
        }.not_to change(Budget, :count)
      end

      it "redirects with error alert" do
        post budgets_path, params: { budget: { category_id: category.id, amount: 1000 } }
        expect(response).to redirect_to(budgets_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "PATCH /budgets/:id" do
    let!(:budget) { create(:budget, category: category, month: current_month, amount: 1000) }

    context "with valid parameters" do
      it "updates the budget amount" do
        patch budget_path(budget), params: { budget: { amount: 2000 } }
        expect(budget.reload.amount).to eq(2000)
      end

      it "redirects to budgets index with the month" do
        patch budget_path(budget), params: { budget: { amount: 2000 } }
        expect(response).to redirect_to(budgets_path(month: current_month))
        expect(flash[:notice]).to eq("预算已更新")
      end
    end

    context "with invalid parameters" do
      it "does not update the budget" do
        original_amount = budget.amount
        patch budget_path(budget), params: { budget: { amount: nil } }
        expect(budget.reload.amount).to eq(original_amount)
      end

      it "redirects with error alert" do
        patch budget_path(budget), params: { budget: { amount: nil } }
        expect(response).to redirect_to(budgets_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE /budgets/:id" do
    let!(:budget) { create(:budget, category: category, month: current_month, amount: 1000) }

    it "destroys the budget" do
      expect {
        delete budget_path(budget)
      }.to change(Budget, :count).by(-1)
    end

    it "redirects to budgets index" do
      delete budget_path(budget)
      expect(response).to redirect_to(budgets_path)
      expect(flash[:notice]).to eq("预算已删除")
    end
  end
end
