require 'rails_helper'

RSpec.describe Budget, type: :model do
  describe "associations" do
    it { should belong_to(:category).class_name("Category").optional }
  end

  describe "validations" do
    it { should validate_presence_of(:month) }
    it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
  end

  describe "#progress_percentage" do
    let(:category) { create(:category) }
    let(:budget) { create(:budget, category: category, month: "2024-01", amount: 1000) }

    before do
      allow(budget).to receive(:spent_amount).and_return(750)
    end

    it "returns correct percentage" do
      expect(budget.progress_percentage).to eq(75.0)
    end
  end

  describe "#status_color" do
    let(:budget) { build(:budget, amount: 1000) }

    it "returns red when overspent" do
      allow(budget).to receive(:spent_amount).and_return(1200)
      expect(budget.status_color).to eq("red")
    end

    it "returns yellow when near limit" do
      allow(budget).to receive(:spent_amount).and_return(850)
      expect(budget.status_color).to eq("yellow")
    end

    it "returns blue when normal" do
      allow(budget).to receive(:spent_amount).and_return(500)
      expect(budget.status_color).to eq("blue")
    end
  end

  describe "scopes" do
    let(:category) { create(:category) }

    describe ".for_month" do
      it "returns budgets for the given month" do
        budget = create(:budget, month: "2024-01")
        other = create(:budget, month: "2024-02")

        expect(Budget.for_month("2024-01")).to include(budget)
        expect(Budget.for_month("2024-01")).not_to include(other)
      end
    end

    describe ".for_category" do
      it "returns budgets for the given category" do
        budget = create(:budget, category: category)
        other = create(:budget, category: create(:category))

        expect(Budget.for_category(category.id)).to include(budget)
        expect(Budget.for_category(category.id)).not_to include(other)
      end
    end

    describe ".total_budgets" do
      it "returns budgets without a category" do
        total = create(:budget, category: nil)
        category_budget = create(:budget, category: category)

        expect(Budget.total_budgets).to include(total)
        expect(Budget.total_budgets).not_to include(category_budget)
      end
    end

    describe ".category_budgets" do
      it "returns budgets with a category" do
        total = create(:budget, category: nil)
        category_budget = create(:budget, category: category)

        expect(Budget.category_budgets).to include(category_budget)
        expect(Budget.category_budgets).not_to include(total)
      end
    end
  end

  describe "#total_budget?" do
    it "returns true when category_id is nil" do
      budget = build(:budget, category: nil)
      expect(budget.total_budget?).to be true
    end

    it "returns false when category_id is present" do
      budget = build(:budget, category: create(:category))
      expect(budget.total_budget?).to be false
    end
  end

  describe "#remaining_amount" do
    let(:budget) { build(:budget, amount: 1000) }

    it "returns positive when under budget" do
      allow(budget).to receive(:spent_amount).and_return(300)
      expect(budget.remaining_amount).to eq(700)
    end

    it "returns negative when over budget" do
      allow(budget).to receive(:spent_amount).and_return(1200)
      expect(budget.remaining_amount).to eq(-200)
    end
  end

  describe "#overspent?" do
    let(:budget) { build(:budget, amount: 1000) }

    it "returns true when over budget" do
      allow(budget).to receive(:spent_amount).and_return(1200)
      expect(budget.overspent?).to be true
    end

    it "returns false when under budget" do
      allow(budget).to receive(:spent_amount).and_return(500)
      expect(budget.overspent?).to be false
    end
  end

  describe "#near_limit?" do
    let(:budget) { build(:budget, amount: 1000) }

    it "returns true when between 80% and 100%" do
      allow(budget).to receive(:spent_amount).and_return(850)
      expect(budget.near_limit?).to be true
    end

    it "returns false when below 80%" do
      allow(budget).to receive(:spent_amount).and_return(500)
      expect(budget.near_limit?).to be false
    end

    it "returns false when at 100% or over" do
      allow(budget).to receive(:spent_amount).and_return(1000)
      expect(budget.near_limit?).to be false
    end
  end

  describe "#status_text" do
    let(:budget) { build(:budget, amount: 1000) }

    it "returns '已超支' when overspent" do
      allow(budget).to receive(:spent_amount).and_return(1200)
      expect(budget.status_text).to eq("已超支")
    end

    it "returns '即将超支' when near limit" do
      allow(budget).to receive(:spent_amount).and_return(850)
      expect(budget.status_text).to eq("即将超支")
    end

    it "returns '正常' when normal" do
      allow(budget).to receive(:spent_amount).and_return(500)
      expect(budget.status_text).to eq("正常")
    end
  end

  describe "#spent_amount_from_transactions" do
    let(:budget) { build(:budget, amount: 1000) }

    it "delegates to spent_amount" do
      allow(budget).to receive(:spent_amount).and_return(750)
      expect(budget.spent_amount_from_transactions).to eq(750)
    end
  end

  describe "#spent_amount" do
    it "returns 0 when month is blank" do
      budget = build(:budget, month: nil)
      expect(budget.spent_amount).to eq(0)
    end
  end
end
