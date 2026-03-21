require 'rails_helper'

RSpec.describe Account, type: :model do
  describe "associations" do
    it { should have_many(:sent_transactions).class_name("Transaction") }
    it { should have_many(:received_transactions).class_name("Transaction") }
  end

  describe "validations" do
    subject { build(:account) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_presence_of(:currency) }
  end

  describe "#current_balance" do
    let(:account) { create(:account, initial_balance: 1000, currency: "CNY") }

    it "returns initial balance when no transactions" do
      expect(account.current_balance).to eq(BigDecimal("1000"))
    end

    it "adds income transactions" do
      create(:transaction, account: account, type: "INCOME", amount: 500)
      expect(account.current_balance).to eq(BigDecimal("1500"))
    end

    it "subtracts expense transactions" do
      create(:transaction, account: account, type: "EXPENSE", amount: 300)
      expect(account.current_balance).to eq(BigDecimal("700"))
    end

    it "handles transfers correctly" do
      target_account = create(:account, initial_balance: 500)

      # Transfer out
      create(:transaction, account: account, target_account: target_account, type: "TRANSFER", amount: 200)

      expect(account.current_balance).to eq(BigDecimal("800"))
      expect(target_account.current_balance).to eq(BigDecimal("700"))
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