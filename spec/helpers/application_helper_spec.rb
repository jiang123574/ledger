# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#format_currency" do
    it "formats amount with default currency" do
      result = helper.format_currency(1234.56)
      expect(result).to include("1,234.56")
    end

    it "formats zero amount" do
      result = helper.format_currency(0)
      expect(result).to include("0.00")
    end

    it "formats nil as zero" do
      result = helper.format_currency(nil)
      expect(result).to include("0.00")
    end

    it "formats negative amounts" do
      result = helper.format_currency(-100.50)
      expect(result).to include("100.50")
    end

    it "accepts custom unit" do
      result = helper.format_currency(100, unit: "$")
      expect(result).to include("$")
    end

    it "accepts custom precision" do
      result = helper.format_currency(100.567, precision: 0)
      expect(result).to include("101")
    end
  end

  describe "#format_currency_with_sign" do
    it "adds + sign for income" do
      result = helper.format_currency_with_sign(100, type: "INCOME")
      expect(result).to start_with("+")
    end

    it "adds - sign for expense" do
      result = helper.format_currency_with_sign(100, type: "EXPENSE")
      expect(result).to start_with("-")
    end

    it "formats nil as zero" do
      result = helper.format_currency_with_sign(nil, type: "INCOME")
      expect(result).to include("+")
      expect(result).to include("0.00")
    end

    it "includes unit when provided" do
      result = helper.format_currency_with_sign(100, type: "INCOME", unit: "¥")
      expect(result).to include("¥")
    end

    it "handles without unit" do
      result = helper.format_currency_with_sign(100, type: "EXPENSE", unit: "")
      expect(result).not_to include("¥")
    end
  end

  describe "#format_balance" do
    it "returns positive format for positive amounts" do
      result = helper.format_balance(1000)
      expect(result[:amount]).to start_with("+")
      expect(result[:css_class]).to eq("text-income")
    end

    it "returns negative format for negative amounts" do
      result = helper.format_balance(-500)
      expect(result[:amount]).to start_with("-")
      expect(result[:css_class]).to eq("text-expense")
    end

    it "handles nil as zero" do
      result = helper.format_balance(nil)
      expect(result[:amount]).to start_with("+")
      expect(result[:css_class]).to eq("text-income")
    end

    it "handles zero as positive" do
      result = helper.format_balance(0)
      expect(result[:css_class]).to eq("text-income")
    end

    it "accepts custom unit" do
      result = helper.format_balance(100, unit: "$")
      expect(result[:amount]).to include("$")
    end
  end

  describe "#currency_unit_for (private)" do
    it "returns ¥ for CNY (default)" do
      expect(helper.send(:currency_unit_for, "CNY")).to eq("¥")
    end

    it "returns $ for USD" do
      expect(helper.send(:currency_unit_for, "USD")).to eq("$")
    end

    it "returns € for EUR" do
      expect(helper.send(:currency_unit_for, "EUR")).to eq("€")
    end

    it "returns £ for GBP" do
      expect(helper.send(:currency_unit_for, "GBP")).to eq("£")
    end

    it "returns ¥ for JPY" do
      expect(helper.send(:currency_unit_for, "JPY")).to eq("¥")
    end

    it "returns ¥ for unknown currencies" do
      expect(helper.send(:currency_unit_for, "XXX")).to eq("¥")
    end

    it "returns ¥ for nil" do
      expect(helper.send(:currency_unit_for, nil)).to eq("¥")
    end
  end
end
