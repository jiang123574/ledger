# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entryable::Trade, type: :model do
  describe "validations" do
    it { should validate_presence_of(:qty) }
    it { should validate_numericality_of(:qty).is_greater_than(0) }
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than(0) }
  end

  describe "associations" do
    it "belongs to security optionally" do
      trade = Entryable::Trade.new
      expect(trade).to respond_to(:security)
    end
  end

  describe "#buy?" do
    it "returns true when order_type is 'buy'" do
      trade = Entryable::Trade.new(order_type: "buy")
      expect(trade.buy?).to be true
    end

    it "returns false when order_type is 'sell'" do
      trade = Entryable::Trade.new(order_type: "sell")
      expect(trade.buy?).to be false
    end

    it "returns false when order_type is nil" do
      trade = Entryable::Trade.new(order_type: nil)
      expect(trade.buy?).to be false
    end
  end

  describe "#sell?" do
    it "returns true when order_type is 'sell'" do
      trade = Entryable::Trade.new(order_type: "sell")
      expect(trade.sell?).to be true
    end

    it "returns false when order_type is 'buy'" do
      trade = Entryable::Trade.new(order_type: "buy")
      expect(trade.sell?).to be false
    end
  end

  describe "#total_value" do
    it "calculates qty * price" do
      trade = Entryable::Trade.new(qty: 100, price: 15.5)
      expect(trade.total_value).to eq(1550.0)
    end

    it "handles decimal values" do
      trade = Entryable::Trade.new(qty: 0.5, price: 100)
      expect(trade.total_value).to eq(50.0)
    end
  end

  describe "#lock_saved_attributes!" do
    it "locks security_id when present" do
      trade = Entryable::Trade.new(security_id: 1, qty: 100, price: 10)
      allow(trade).to receive(:lock_attr!)
      trade.lock_saved_attributes!
      expect(trade).to have_received(:lock_attr!).with(:security_id)
    end

    it "locks qty when present" do
      trade = Entryable::Trade.new(qty: 100, price: 10)
      allow(trade).to receive(:lock_attr!)
      trade.lock_saved_attributes!
      expect(trade).to have_received(:lock_attr!).with(:qty)
    end

    it "locks price when present" do
      trade = Entryable::Trade.new(price: 10)
      allow(trade).to receive(:lock_attr!)
      trade.lock_saved_attributes!
      expect(trade).to have_received(:lock_attr!).with(:price)
    end

    it "does not lock nil attributes" do
      trade = Entryable::Trade.new(security_id: nil, qty: nil, price: nil)
      allow(trade).to receive(:lock_attr!)
      trade.lock_saved_attributes!
      expect(trade).not_to have_received(:lock_attr!)
    end
  end
end
