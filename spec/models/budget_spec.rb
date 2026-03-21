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
end
