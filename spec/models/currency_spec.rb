require 'rails_helper'

RSpec.describe Currency, type: :model do
  describe "validations" do
    subject { build(:currency) }

    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
    it { should validate_length_of(:code).is_equal_to(3) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:symbol) }
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active currencies" do
        active_currency = create(:currency, is_active: true)
        inactive_currency = create(:currency, is_active: false, code: "XYZ")

        expect(Currency.active).to include(active_currency)
        expect(Currency.active).not_to include(inactive_currency)
      end
    end
  end

  describe ".default" do
    it "returns the default currency" do
      default_currency = create(:currency, is_default: true, code: "CNY")
      expect(Currency.default).to eq(default_currency)
    end

    it "returns CNY currency when no default is set" do
      cny_currency = create(:currency, code: "CNY", is_default: false)
      expect(Currency.default).to eq(cny_currency)
    end

    it "returns nil when no default and no CNY currency exists" do
      create(:currency, code: "USD", is_default: false)
      expect(Currency.default).to be_nil
    end
  end

  describe "#symbol_display" do
    it "returns the symbol when present" do
      currency = build(:currency, symbol: "$", code: "USD")
      expect(currency.symbol_display).to eq("$")
    end

    it "returns the symbol from CURRENCY_SYMBOLS when symbol is blank" do
      currency = build(:currency, symbol: nil, code: "USD")
      expect(currency.symbol_display).to eq("$")
    end

    it "returns the code when symbol is blank and not in CURRENCY_SYMBOLS" do
      currency = build(:currency, symbol: nil, code: "XYZ")
      expect(currency.symbol_display).to eq("XYZ")
    end
  end

  describe "#exchange_rate" do
    it "returns 1 for default currency" do
      currency = build(:currency, is_default: true)
      expect(currency.exchange_rate).to eq(BigDecimal("1"))
    end

    it "returns rate when present for non-default currency" do
      currency = build(:currency, is_default: false, rate: 7.2)
      expect(currency.exchange_rate).to eq(BigDecimal("7.2"))
    end

    it "returns 1 when rate is blank for non-default currency" do
      currency = build(:currency, is_default: false, rate: nil)
      expect(currency.exchange_rate).to eq(BigDecimal("1"))
    end
  end

  describe "#convert_to_default" do
    it "returns amount unchanged for default currency" do
      currency = build(:currency, is_default: true)
      expect(currency.convert_to_default(100)).to eq(100)
    end

    it "converts amount using exchange rate for non-default currency" do
      currency = build(:currency, is_default: false, rate: 7.2)
      expect(currency.convert_to_default(100)).to eq(720.0)
    end

    it "rounds to 2 decimal places" do
      currency = build(:currency, is_default: false, rate: 7.25)
      expect(currency.convert_to_default(100)).to eq(725.0)
      expect(currency.convert_to_default(33.33)).to eq(241.64) # 33.33 * 7.25 = 241.6425
    end
  end

  describe "#convert_from_default" do
    it "returns amount unchanged for default currency" do
      currency = build(:currency, is_default: true)
      expect(currency.convert_from_default(720)).to eq(720)
    end

    it "converts amount using exchange rate for non-default currency" do
      currency = build(:currency, is_default: false, rate: 7.2)
      expect(currency.convert_from_default(720)).to eq(100.0)
    end

    it "returns amount when exchange rate is zero" do
      currency = build(:currency, is_default: false, rate: 0)
      expect(currency.convert_from_default(720)).to eq(720)
    end

    it "rounds to 2 decimal places" do
      currency = build(:currency, is_default: false, rate: 7.25)
      expect(currency.convert_from_default(725)).to eq(100.0)
      expect(currency.convert_from_default(241.64)).to eq(33.33) # 241.64 / 7.25 = 33.329655...
    end
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

    it "converts between currencies using exchange rates" do
      create(:currency, code: "USD", rate: 7.2, is_default: false)
      create(:currency, code: "CNY", rate: 1, is_default: true)

      # USD to CNY: amount * from_rate / to_rate = 100 * 7.2 / 1 = 720
      expect(Currency.convert(100, "USD", "CNY")).to eq(720.0)
    end

    it "handles missing currency gracefully" do
      create(:currency, code: "CNY", rate: 1, is_default: true)

      # Non-existent currency defaults to rate 1
      expect(Currency.convert(100, "XYZ", "CNY")).to eq(100.0)
    end

    it "handles zero to_rate by returning default_amount" do
      create(:currency, code: "USD", rate: 7.2, is_default: false)
      create(:currency, code: "EUR", rate: 0, is_default: false)

      # When to_rate is 0, target_amount = default_amount (no division)
      expect(Currency.convert(100, "USD", "EUR")).to eq(720.0)
    end
  end
end
