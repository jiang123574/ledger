# frozen_string_literal: true

require "rails_helper"

RSpec.describe SingleBudget, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:budget_items).dependent(:destroy) }
    it { is_expected.to belong_to(:category).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_numericality_of(:spent_amount).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[planning active completed cancelled]) }
  end

  describe "scopes" do
    let!(:planning) { create(:single_budget, status: "planning") }
    let!(:active) { create(:single_budget, status: "active") }
    let!(:completed) { create(:single_budget, status: "completed") }
    let!(:cancelled) { create(:single_budget, status: "cancelled") }

    describe ".by_status" do
      it "filters by status" do
        expect(SingleBudget.by_status("active")).to include(active)
        expect(SingleBudget.by_status("active")).not_to include(planning)
      end
    end

    describe ".planning" do
      it "returns planning budgets" do
        expect(SingleBudget.planning).to include(planning)
      end
    end

    describe ".active" do
      it "returns active budgets" do
        expect(SingleBudget.active).to include(active)
      end
    end

    describe ".completed" do
      it "returns completed budgets" do
        expect(SingleBudget.completed).to include(completed)
      end
    end

    describe ".cancelled" do
      it "returns cancelled budgets" do
        expect(SingleBudget.cancelled).to include(cancelled)
      end
    end
  end

  describe "#remaining_amount" do
    let(:budget) { create(:single_budget, total_amount: 1000, spent_amount: 300) }

    it "calculates remaining amount" do
      expect(budget.remaining_amount).to eq(700)
    end
  end

  describe "#progress_percentage" do
    context "when total_amount is positive" do
      let(:budget) { create(:single_budget, total_amount: 1000, spent_amount: 250) }

      it "calculates progress percentage" do
        expect(budget.progress_percentage).to eq(25.0)
      end
    end

    context "when total_amount is zero" do
      let(:budget) { create(:single_budget, total_amount: 0, spent_amount: 0) }

      it "returns 0" do
        expect(budget.progress_percentage).to eq(0)
      end
    end
  end

  describe "#overspent?" do
    it "returns true when spent exceeds total" do
      budget = create(:single_budget, total_amount: 100, spent_amount: 150)
      expect(budget.overspent?).to be true
    end

    it "returns false when spent is within total" do
      budget = create(:single_budget, total_amount: 100, spent_amount: 50)
      expect(budget.overspent?).to be false
    end
  end

  describe "#near_limit?" do
    it "returns true when progress is between 80% and 100%" do
      budget = create(:single_budget, total_amount: 100, spent_amount: 85)
      expect(budget.near_limit?).to be true
    end

    it "returns false when progress is below 80%" do
      budget = create(:single_budget, total_amount: 100, spent_amount: 50)
      expect(budget.near_limit?).to be false
    end

    it "returns false when progress is 100% or more" do
      budget = create(:single_budget, total_amount: 100, spent_amount: 100)
      expect(budget.near_limit?).to be false
    end
  end

  describe "#status_color" do
    it "returns red when overspent" do
      budget = create(:single_budget, status: "active", total_amount: 100, spent_amount: 150)
      expect(budget.status_color).to eq("red")
    end

    it "returns yellow when near limit" do
      budget = create(:single_budget, status: "active", total_amount: 100, spent_amount: 85)
      expect(budget.status_color).to eq("yellow")
    end

    it "returns gray for planning status" do
      budget = create(:single_budget, status: "planning")
      expect(budget.status_color).to eq("gray")
    end

    it "returns blue for active status" do
      budget = create(:single_budget, status: "active")
      expect(budget.status_color).to eq("blue")
    end

    it "returns green for completed status" do
      budget = create(:single_budget, status: "completed")
      expect(budget.status_color).to eq("green")
    end
  end

  describe "#status_text" do
    it "returns Chinese text for each status" do
      expect(create(:single_budget, status: "planning").status_text).to eq("规划中")
      expect(create(:single_budget, status: "active").status_text).to eq("进行中")
      expect(create(:single_budget, status: "completed").status_text).to eq("已完成")
      expect(create(:single_budget, status: "cancelled").status_text).to eq("已取消")
    end
  end

  describe "status methods" do
    let(:budget) { create(:single_budget, status: "planning") }

    describe "#planning?" do
      it "returns true when status is planning" do
        expect(budget.planning?).to be true
      end
    end

    describe "#active?" do
      it "returns false when status is not active" do
        expect(budget.active?).to be false
      end
    end

    describe "#start!" do
      it "changes status to active" do
        budget.start!
        expect(budget.reload.status).to eq("active")
      end
    end

    describe "#complete!" do
      it "changes status to completed" do
        budget.complete!
        expect(budget.reload.status).to eq("completed")
      end
    end

    describe "#cancel!" do
      it "changes status to cancelled" do
        budget.cancel!
        expect(budget.reload.status).to eq("cancelled")
      end
    end
  end
end
