# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#format_currency" do
    it "formats positive amount with default currency unit" do
      expect(helper.format_currency(1234.56)).to eq("¥1,234.56")
    end

    it "formats zero amount" do
      expect(helper.format_currency(0)).to eq("¥0.00")
    end

    it "formats negative amount" do
      # Rails number_to_currency puts the minus sign before the unit
      expect(helper.format_currency(-500)).to eq("-¥500.00")
    end

    it "handles nil as zero" do
      expect(helper.format_currency(nil)).to eq("¥0.00")
    end

    it "accepts custom unit" do
      expect(helper.format_currency(100, unit: "$")).to eq("$100.00")
    end

    it "accepts custom precision" do
      expect(helper.format_currency(1234.567, precision: 3)).to eq("¥1,234.567")
    end
  end

  describe "#format_currency_with_sign" do
    it "formats income with plus sign" do
      result = helper.format_currency_with_sign(1000, type: "INCOME")
      expect(result).to eq("+1,000.00")
    end

    it "formats expense with minus sign" do
      result = helper.format_currency_with_sign(500, type: "EXPENSE")
      expect(result).to eq("-500.00")
    end

    it "handles nil as zero with income type" do
      expect(helper.format_currency_with_sign(nil, type: "INCOME")).to eq("+0.00")
    end

    it "handles nil as zero with expense type" do
      expect(helper.format_currency_with_sign(nil, type: "EXPENSE")).to eq("-0.00")
    end

    it "uses absolute value regardless of input sign" do
      result = helper.format_currency_with_sign(-100, type: "INCOME")
      expect(result).to eq("+100.00")
    end

    it "accepts custom unit" do
      result = helper.format_currency_with_sign(100, type: "INCOME", unit: "$")
      expect(result).to eq("+$100.00")
    end

    it "accepts custom precision" do
      result = helper.format_currency_with_sign(1234.567, type: "EXPENSE", precision: 3)
      expect(result).to eq("-1,234.567")
    end
  end

  describe "#format_balance" do
    it "formats positive balance with income color and plus sign" do
      result = helper.format_balance(1000)
      expect(result[:amount]).to eq("+¥1,000.00")
      expect(result[:css_class]).to eq("text-income")
    end

    it "formats negative balance with expense color and minus sign" do
      result = helper.format_balance(-500)
      expect(result[:amount]).to eq("-¥500.00")
      expect(result[:css_class]).to eq("text-expense")
    end

    it "formats zero balance with income color" do
      result = helper.format_balance(0)
      expect(result[:amount]).to eq("+¥0.00")
      expect(result[:css_class]).to eq("text-income")
    end

    it "handles nil as zero" do
      result = helper.format_balance(nil)
      expect(result[:amount]).to eq("+¥0.00")
      expect(result[:css_class]).to eq("text-income")
    end
  end
end
