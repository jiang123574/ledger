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

  describe "scopes" do
    describe ".for_pair" do
      it "returns the latest rate for a currency pair" do
        old_rate = create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.0, date: 1.day.ago)
        new_rate = create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: Date.current)

        # for_pair scope already calls .first, returns single record or nil
        expect(ExchangeRate.for_pair("USD", "CNY")).to eq(new_rate)
      end

      it "returns nil when no rate exists for the pair" do
        create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: Date.current)
        expect(ExchangeRate.for_pair("EUR", "CNY")).to be_nil
      end
    end

    describe ".latest" do
      it "returns rates ordered by date descending" do
        old_rate = create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.0, date: 1.day.ago)
        new_rate = create(:exchange_rate, from_currency: "EUR", to_currency: "CNY", rate: 8.0, date: Date.current)

        expect(ExchangeRate.latest.first).to eq(new_rate)
      end
    end

    describe ".for_date" do
      it "returns rates for a specific date" do
        rate_today = create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: Date.current)
        rate_yesterday = create(:exchange_rate, from_currency: "EUR", to_currency: "CNY", rate: 8.0, date: 1.day.ago)

        expect(ExchangeRate.for_date(Date.current)).to include(rate_today)
        expect(ExchangeRate.for_date(Date.current)).not_to include(rate_yesterday)
      end
    end
  end

  describe ".latest_rate" do
    it "returns 1 for same currency" do
      expect(ExchangeRate.latest_rate("CNY", "CNY")).to eq(BigDecimal("1"))
    end

    it "returns the latest rate for different currencies" do
      create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: Date.current)
      expect(ExchangeRate.latest_rate("USD", "CNY")).to eq(BigDecimal("7.2"))
    end

    it "returns 1 when no rate exists for the pair" do
      # Use a currency pair that doesn't exist
      ExchangeRate.where(from_currency: "USD", to_currency: "EUR").destroy_all
      expect(ExchangeRate.latest_rate("USD", "EUR")).to eq(BigDecimal("1"))
    end
  end

  describe ".rate_on_date" do
    it "returns 1 for same currency" do
      expect(ExchangeRate.rate_on_date("CNY", "CNY", Date.current)).to eq(BigDecimal("1"))
    end

    it "returns rate for specific date when it exists" do
      rate = create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: Date.current)
      expect(ExchangeRate.rate_on_date("USD", "CNY", Date.current)).to eq(BigDecimal("7.2"))
    end

    it "falls back to latest rate when no rate exists for the date" do
      create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: 1.day.ago)
      expect(ExchangeRate.rate_on_date("USD", "CNY", Date.current)).to eq(BigDecimal("7.2"))
    end
  end

  describe ".convert" do
    it "returns same amount for same currency" do
      expect(ExchangeRate.convert(100, "CNY", "CNY")).to eq(100)
    end

    it "converts amount using rate for the date" do
      create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: Date.current)
      expect(ExchangeRate.convert(100, "USD", "CNY")).to eq(720.0)
    end

    it "uses latest rate when no rate exists for the date" do
      create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: 1.day.ago)
      expect(ExchangeRate.convert(100, "USD", "CNY", date: Date.current)).to eq(720.0)
    end

    it "rounds to 2 decimal places" do
      create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.25, date: Date.current)
      expect(ExchangeRate.convert(33.33, "USD", "CNY")).to eq(241.64)
    end
  end

  describe "#create_reverse!" do
    it "creates a reverse exchange rate" do
      rate = create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: Date.current, source: "manual")

      expect { rate.create_reverse! }.to change { ExchangeRate.count }.by(1)

      reverse_rate = ExchangeRate.find_by(from_currency: "CNY", to_currency: "USD", date: Date.current)
      expect(reverse_rate).to be_present
      expect(reverse_rate.rate).to eq((1.0 / 7.2).round(6))
      expect(reverse_rate.source).to eq("manual_auto_reversed")
    end

    it "does not create reverse rate if rate is zero" do
      # Since rate must be greater than 0 due to validation, we need to bypass validation
      rate = build(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 0, date: Date.current)
      rate.save(validate: false)

      expect { rate.create_reverse! }.not_to change { ExchangeRate.count }
    end

    it "does not create duplicate reverse rate if one already exists" do
      rate = create(:exchange_rate, from_currency: "USD", to_currency: "CNY", rate: 7.2, date: Date.current, source: "manual")
      existing_reverse = create(:exchange_rate, from_currency: "CNY", to_currency: "USD", rate: 0.138889, date: Date.current)

      expect { rate.create_reverse! }.not_to change { ExchangeRate.count }
    end
  end
end
