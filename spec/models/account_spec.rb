require 'rails_helper'

RSpec.describe Account, type: :model do
  describe "associations" do
    it { should have_many(:entries).dependent(:destroy) }
    it { should have_many(:transaction_entries) }
    it { should have_many(:plans).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:account) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_presence_of(:currency) }
  end

  describe "#current_balance" do
    let(:account) { create(:account, initial_balance: 1000, currency: "CNY") }

    it "returns initial balance when no entries" do
      expect(account.current_balance).to eq(BigDecimal("1000"))
    end

    it "adds income entries" do
      entry = create(:entry, :income, account: account, amount: 500)
      create(:entryable_transaction, :income, category: nil)
      entry.update!(entryable: Entryable::Transaction.first)

      expect(account.current_balance).to eq(BigDecimal("1500"))
    end

    it "subtracts expense entries" do
      entry = create(:entry, :expense, account: account)
      create(:entryable_transaction, :expense, category: nil)
      entry.update!(entryable: Entryable::Transaction.first)

      expect(account.current_balance).to eq(BigDecimal("899.5"))
    end
  end

  describe ".total_assets" do
    it "sums all visible accounts included in total" do
      create(:account, initial_balance: 1000, include_in_total: true, hidden: false)
      create(:account, initial_balance: 500, include_in_total: true, hidden: false)
      create(:account, initial_balance: 200, include_in_total: false)
      create(:account, initial_balance: 100, include_in_total: true, hidden: true)

      expect(Account.total_assets).to eq(BigDecimal("1500"))
    end
  end
end
