require 'rails_helper'

RSpec.describe ExchangeRate, type: :model do
  describe "validations" do
    subject { build(:exchange_rate) }

    it { should validate_presence_of(:from_currency) }
    it { should validate_presence_of(:to_currency) }
    it { should validate_presence_of(:rate) }
    it { should validate_presence_of(:date) }
    it { should validate_numericality_of(:rate).is_greater_than(0) }
  end

  describe ".latest_rate" do
    it "returns 1 for same currency" do
      expect(ExchangeRate.latest_rate("CNY", "CNY")).to eq(BigDecimal("1"))
    end

    it "returns the latest rate for different currencies" do
      create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: Date.current)
      expect(ExchangeRate.latest_rate("USD", "CNY")).to eq(BigDecimal("7.2"))
    end
  end

  describe ".convert" do
    it "returns same amount for same currency" do
      expect(ExchangeRate.convert(100, "CNY", "CNY")).to eq(100)
    end
  end
end
