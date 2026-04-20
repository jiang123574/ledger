# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SingleBudgets", type: :request do
  before { login }

  let!(:budget) do
    SingleBudget.create!(
      name: "Trip",
      total_amount: 5000,
      start_date: Date.today,
      end_date: Date.today + 7.days,
      currency: "CNY"
    )
  end

  describe "GET /single_budgets" do
    it "redirects to budgets" do
      get single_budgets_path
      expect(response).to have_http_status(:redirect).or have_http_status(:moved_permanently)
    end
  end

  describe "POST /single_budgets" do
    it "creates a new single budget with correct attributes" do
      expect {
        post single_budgets_path, params: {
          single_budget: {
            name: "Vacation",
            total_amount: 8000,
            start_date: Date.today,
            end_date: Date.today + 14.days,
            currency: "CNY"
          }
        }
      }.to change(SingleBudget, :count).by(1)

      expect(response).to redirect_to(single_budgets_path)
      expect(flash[:notice]).to eq("单次预算已创建")

      new_budget = SingleBudget.last
      expect(new_budget.name).to eq("Vacation")
      expect(new_budget.total_amount).to eq(8000)
    end

    it "handles validation errors" do
      post single_budgets_path, params: {
        single_budget: {
          name: "",
          total_amount: nil
        }
      }

      expect(response).to redirect_to(single_budgets_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "PATCH /single_budgets/:id" do
    it "updates the budget" do
      patch single_budget_path(budget), params: {
        single_budget: { name: "Updated Trip", total_amount: 6000 }
      }

      expect(response).to redirect_to(single_budgets_path)
      expect(flash[:notice]).to eq("单次预算已更新")
      expect(budget.reload.name).to eq("Updated Trip")
      expect(budget.total_amount).to eq(6000)
    end

    it "handles validation errors on update" do
      patch single_budget_path(budget), params: {
        single_budget: { name: "" }
      }

      expect(response).to redirect_to(single_budgets_path)
      expect(flash[:alert]).to be_present
      expect(budget.reload.name).to eq("Trip") # unchanged
    end
  end

  describe "DELETE /single_budgets/:id" do
    it "deletes the budget" do
      expect {
        delete single_budget_path(budget)
      }.to change(SingleBudget, :count).by(-1)

      expect(response).to redirect_to(single_budgets_path)
      expect(flash[:notice]).to eq("单次预算已删除")
    end
  end
end
