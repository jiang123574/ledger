require 'rails_helper'

RSpec.describe Currency, type: :model do
  describe "validations" do
    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
    it { should validate_length_of(:code).is_equal_to(3) }
  end

  describe ".symbol" do
    it "returns correct symbol for known currencies" do
      expect(Currency.symbol("CNY")).to eq("¥")
      expect(Currency.symbol("USD")).to eq("$")
      expect(Currency.symbol("EUR")).to eq("€")
    end

    it "returns code for unknown currencies" do
      expect(Currency.symbol("XYZ")).to eq("XYZ")
    end
  end

  describe ".convert" do
    it "returns same amount for same currency" do
      expect(Currency.convert(100, "CNY", "CNY")).to eq(100)
    end
  end
end