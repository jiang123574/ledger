# frozen_string_literal: true

require "rails_helper"

RSpec.describe BudgetItem, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:single_budget) }
    it { is_expected.to belong_to(:category).optional }
  end

  describe "validations" do
    it { is_expected.to validate_length_of(:name).is_at_most(100).allow_nil }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:spent_amount).is_greater_than_or_equal_to(0) }
  end

  describe "#display_name" do
    it "returns category full_name when category present" do
      category = create(:category, name: "Food")
      item = BudgetItem.new(category: category)
      expect(item.display_name).to eq("Food")
    end

    it "returns name when category is nil" do
      item = BudgetItem.new(name: "Custom Name")
      expect(item.display_name).to eq("Custom Name")
    end

    it "returns 未分类 when both are nil" do
      item = BudgetItem.new
      expect(item.display_name).to eq("未分类")
    end
  end

  describe "#remaining_amount" do
    it "calculates remaining amount" do
      item = BudgetItem.new(amount: 1000, spent_amount: 300)
      expect(item.remaining_amount).to eq(700)
    end
  end

  describe "#progress_percentage" do
    it "calculates percentage" do
      item = BudgetItem.new(amount: 1000, spent_amount: 250)
      expect(item.progress_percentage).to eq(25.0)
    end

    it "returns 0 when amount is 0" do
      item = BudgetItem.new(amount: 0, spent_amount: 0)
      expect(item.progress_percentage).to eq(0)
    end
  end

  describe "#overspent?" do
    it "returns true when spent exceeds amount" do
      item = BudgetItem.new(amount: 100, spent_amount: 150)
      expect(item.overspent?).to be true
    end

    it "returns false when spent is within amount" do
      item = BudgetItem.new(amount: 100, spent_amount: 50)
      expect(item.overspent?).to be false
    end
  end
end

RSpec.describe ExchangeRate, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:from_currency) }
    it { is_expected.to validate_presence_of(:to_currency) }
    it { is_expected.to validate_presence_of(:rate) }
    it { is_expected.to validate_numericality_of(:rate).is_greater_than(0) }
  end

  describe ".for_pair" do
    let!(:rate) { create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2) }

    it "finds rate for currency pair" do
      result = ExchangeRate.find_by(from_currency: "USD", to_currency: "CNY")
      expect(result).to eq(rate)
    end
  end
end

RSpec.describe Counterparty, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe "scopes" do
    let!(:counterparty_b) { create(:counterparty, name: "Bob") }
    let!(:counterparty_a) { create(:counterparty, name: "Alice") }

    describe ".ordered" do
      it "orders by name" do
        expect(Counterparty.ordered.first).to eq(counterparty_a)
      end
    end
  end
end

RSpec.describe Plan, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:account).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    let!(:active_plan) { create(:plan, :active) }
    let!(:inactive_plan) { create(:plan, :inactive) }

    describe ".active" do
      it "returns active plans" do
        expect(Plan.active).to include(active_plan)
        expect(Plan.active).not_to include(inactive_plan)
      end
    end
  end

  describe "#active?" do
    it "returns true for active plans" do
      plan = create(:plan, active: true)
      expect(plan.active?).to be true
    end

    it "returns false for inactive plans" do
      plan = create(:plan, active: false)
      expect(plan.active?).to be false
    end
  end

  describe "#completed?" do
    it "returns true for completed installment plans" do
      plan = create(:plan, :installment, installments_completed: 12, installments_total: 12)
      expect(plan.completed?).to be true
    end

    it "returns false for incomplete installment plans" do
      plan = create(:plan, :installment, installments_completed: 5, installments_total: 12)
      expect(plan.completed?).to be false
    end
  end
end
