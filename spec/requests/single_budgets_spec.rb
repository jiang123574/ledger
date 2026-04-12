# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SingleBudgets", type: :request do
  before { login }

  describe "POST /single_budgets" do
    it "creates a new single budget" do
      expect {
        post single_budgets_path, params: {
          single_budget: {
            name: "Trip",
            total_amount: 5000,
            start_date: Date.today,
            end_date: Date.today + 7.days,
            currency: "CNY"
          }
        }
      }.to change(SingleBudget, :count).by(1)
    end

    it "redirects after successful creation" do
      post single_budgets_path, params: {
        single_budget: {
          name: "Trip",
          total_amount: 5000,
          start_date: Date.today,
          end_date: Date.today + 7.days,
          currency: "CNY"
        }
      }
      expect(response).to be_redirect
    end
  end

  describe "DELETE /single_budgets/:id" do
    it "deletes the budget" do
      budget = SingleBudget.create!(name: "Test", total_amount: 1000, start_date: Date.today, end_date: Date.today + 30.days, currency: "CNY")
      expect {
        delete single_budget_path(budget)
      }.to change(SingleBudget, :count).by(-1)
    end

    it "redirects after deletion" do
      budget = SingleBudget.create!(name: "Test", total_amount: 1000, start_date: Date.today, end_date: Date.today + 30.days, currency: "CNY")
      delete single_budget_path(budget)
      expect(response).to be_redirect
    end
  end
end
