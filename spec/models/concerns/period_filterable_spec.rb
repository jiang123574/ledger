# frozen_string_literal: true

require "rails_helper"

RSpec.describe PeriodFilterable, type: :model do
  describe ".resolve_period" do
    context "when period_type is 'all'" do
      it "returns nil" do
        expect(PeriodFilterable.resolve_period("all", "2024")).to be_nil
      end
    end

    context "when period_type is 'year'" do
      it "returns full year date range" do
        start_date, end_date = PeriodFilterable.resolve_period("year", "2024")
        expect(start_date).to eq(Date.new(2024, 1, 1))
        expect(end_date).to eq(Date.new(2024, 12, 31))
      end
    end

    context "when period_type is 'month'" do
      it "returns month date range" do
        start_date, end_date = PeriodFilterable.resolve_period("month", "2024-03")
        expect(start_date).to eq(Date.new(2024, 3, 1))
        expect(end_date).to eq(Date.new(2024, 3, 31))
      end

      it "handles February correctly" do
        start_date, end_date = PeriodFilterable.resolve_period("month", "2024-02")
        expect(start_date).to eq(Date.new(2024, 2, 1))
        expect(end_date).to eq(Date.new(2024, 2, 29)) # 2024 is a leap year
      end
    end

    context "when period_type is 'week'" do
      it "returns week date range for valid format" do
        start_date, end_date = PeriodFilterable.resolve_period("week", "2024-W01")
        expect(start_date).to be_a(Date)
        expect(end_date - start_date).to eq(6)
      end

      it "returns nil for invalid week format" do
        expect(PeriodFilterable.resolve_period("week", "invalid")).to be_nil
      end
    end

    context "when period_type is unknown" do
      it "parses YYYY-MM format as month" do
        start_date, end_date = PeriodFilterable.resolve_period("custom", "2024-06")
        expect(start_date).to eq(Date.new(2024, 6, 1))
        expect(end_date).to eq(Date.new(2024, 6, 30))
      end

      it "returns nil for unparseable values" do
        expect(PeriodFilterable.resolve_period("custom", "invalid")).to be_nil
      end
    end

    context "when period_type or period_value is blank" do
      it "returns nil for blank period_type" do
        expect(PeriodFilterable.resolve_period("", "2024-01")).to be_nil
      end

      it "returns nil for blank period_value" do
        expect(PeriodFilterable.resolve_period("month", "")).to be_nil
      end

      it "returns nil for nil values" do
        expect(PeriodFilterable.resolve_period(nil, nil)).to be_nil
      end
    end
  end

  describe ".default_period_value" do
    before do
      allow(Date).to receive(:current).and_return(Date.new(2024, 3, 15))
    end

    it "returns current year for year type" do
      expect(PeriodFilterable.default_period_value("year")).to eq("2024")
    end

    it "returns current week for week type" do
      result = PeriodFilterable.default_period_value("week")
      expect(result).to match(/\d{4}-W\d{2}/)
    end

    it "returns current month for other types" do
      expect(PeriodFilterable.default_period_value("month")).to eq("2024-03")
    end

    it "returns current month for nil type" do
      expect(PeriodFilterable.default_period_value(nil)).to eq("2024-03")
    end
  end
end
