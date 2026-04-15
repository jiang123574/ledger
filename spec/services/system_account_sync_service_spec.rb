# frozen_string_literal: true

require "rails_helper"

RSpec.describe SystemAccountSyncService, type: :service do
  # 清理系统账户
  before do
    Account.where(name: [ "应收款", "应付款" ]).destroy_all
  end

  describe ".sync_all!" do
    it "creates system accounts" do
      described_class.sync_all!

      expect(Account.exists?(name: "应收款")).to be true
      expect(Account.exists?(name: "应付款")).to be true
    end

    it "bumps cache versions when accounts are created" do
      expect(CacheBuster).to receive(:bump).with(:accounts)
      expect(CacheBuster).to receive(:bump).with(:entries)
      described_class.sync_all!
    end

    context "when accounts already exist with correct values" do
      before do
        described_class.sync_all!
      end

      it "does not bump cache versions" do
        expect(CacheBuster).not_to receive(:bump)
        described_class.sync_all!
      end
    end
  end

  describe ".sync_receivable_account!" do
    it "creates receivable account with zero initial balance" do
      described_class.sync_receivable_account!
      account = Account.find_by(name: "应收款")
      expect(account).to be_present
      expect(account.initial_balance).to eq(0)
    end

    it "updates existing receivable account" do
      existing = create(:account, name: "应收款", initial_balance: 100)
      described_class.sync_receivable_account!
      expect(existing.reload.initial_balance).to eq(0)
    end

    it "returns true when account is created" do
      expect(described_class.sync_receivable_account!).to be true
    end

    it "returns false when no change needed" do
      described_class.sync_receivable_account!
      expect(described_class.sync_receivable_account!).to be false
    end
  end

  describe ".sync_payable_account!" do
    context "with no unsettled payables" do
      it "creates payable account with zero initial balance" do
        described_class.sync_payable_account!
        account = Account.find_by(name: "应付款")
        expect(account).to be_present
        expect(account.initial_balance).to eq(0)
      end
    end

    context "with unsettled payables" do
      let(:account) { create(:account) }

      before do
        create(:payable, account: account, remaining_amount: 500, settled_at: nil)
        create(:payable, account: account, remaining_amount: 300, settled_at: nil)
      end

      it "creates payable account with negative initial balance" do
        described_class.sync_payable_account!
        account = Account.find_by(name: "应付款")
        expect(account).to be_present
        expect(account.initial_balance).to eq(-800)
      end
    end
  end
end
