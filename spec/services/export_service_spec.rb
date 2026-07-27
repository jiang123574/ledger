# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExportService, type: :service do
  let(:account) { create(:account, name: "Test Account") }
  let(:category) { create(:category, name: "Food") }

  describe ".transactions_to_csv" do
    it "generates CSV with correct headers" do
      csv = described_class.transactions_to_csv
      expect(csv).to include("日期")
      expect(csv).to include("类型")
      expect(csv).to include("金额")
      expect(csv).to include("账户")
      expect(csv).to include("转出账户")
      expect(csv).to include("转入账户")
      expect(csv).to include("父分类")
      expect(csv).to include("子分类")
      expect(csv).to include("备注")
    end

    it "includes expense entries" do
      entry = create(:entry, :expense, account: account, date: Date.new(2024, 1, 15), amount: -100)
      entry.entryable.update!(category: category)

      csv = described_class.transactions_to_csv
      expect(csv).to include("2024-01-15")
      expect(csv).to include("支出")
      expect(csv).to include("100.0")
    end

    it "includes income entries" do
      create(:entry, :income, account: account, date: Date.new(2024, 1, 20), amount: 500)

      csv = described_class.transactions_to_csv
      expect(csv).to include("2024-01-20")
      expect(csv).to include("收入")
      expect(csv).to include("500.0")
    end

    it "includes account name" do
      create(:entry, :expense, account: account)

      csv = described_class.transactions_to_csv
      expect(csv).to include("Test Account")
    end

    it "includes category name" do
      entry = create(:entry, :expense, account: account)
      entry.entryable.update!(category: category)

      csv = described_class.transactions_to_csv
      expect(csv).to include("Food")
    end

    context "with no entries" do
      before do
        Entry.where(entryable_type: "Entryable::Transaction").destroy_all
      end

      it "generates CSV with headers only" do
        csv = described_class.transactions_to_csv
        lines = csv.split("\n")
        expect(lines.length).to eq(1)
        expect(lines[0]).to include("日期")
      end
    end
  end

  describe ".entries_to_csv" do
    it "generates CSV with correct headers" do
      csv = described_class.entries_to_csv
      expect(csv).to include("日期")
      expect(csv).to include("类型")
      expect(csv).to include("金额")
      expect(csv).to include("账户")
      expect(csv).to include("转出账户")
      expect(csv).to include("转入账户")
      expect(csv).to include("父分类")
      expect(csv).to include("子分类")
      expect(csv).to include("备注")
    end

    it "excludes transfer entries from regular transaction rows" do
      from_account = create(:account, name: "Bank A")
      to_account = create(:account, name: "Bank B")
      transfer_id = SecureRandom.uuid

      create(:entry, :expense, account: from_account, amount: -100, date: Date.new(2024, 3, 1),
             transfer_id: transfer_id)
      create(:entry, :income, account: to_account, amount: 100, date: Date.new(2024, 3, 1),
             transfer_id: transfer_id)

      csv = described_class.entries_to_csv
      expect(csv).not_to include("支出,100.0,Bank A")
      expect(csv).not_to include("收入,100.0,Bank B")
    end

    it "exports transfers as single row with transfer type" do
      from_account = create(:account, name: "Bank A")
      to_account = create(:account, name: "Bank B")
      transfer_id = SecureRandom.uuid

      create(:entry, :expense, account: from_account, amount: -200, date: Date.new(2024, 3, 1),
             transfer_id: transfer_id, notes: "Transfer test")
      create(:entry, :income, account: to_account, amount: 200, date: Date.new(2024, 3, 1),
             transfer_id: transfer_id, notes: "Transfer test")

      csv = described_class.entries_to_csv
      expect(csv).to include("转账")
      expect(csv).to include("Bank A → Bank B")
      expect(csv).to include("Bank A")
      expect(csv).to include("Bank B")
      expect(csv).to include("200.0")
      expect(csv).to include("Transfer test")
    end

    it "exports regular entries and transfers together" do
      from_account = create(:account, name: "Bank A")
      to_account = create(:account, name: "Bank B")
      transfer_id = SecureRandom.uuid

      create(:entry, :expense, account: account, amount: -50, date: Date.new(2024, 2, 1))
      create(:entry, :expense, account: from_account, amount: -100, date: Date.new(2024, 3, 1),
             transfer_id: transfer_id)
      create(:entry, :income, account: to_account, amount: 100, date: Date.new(2024, 3, 1),
             transfer_id: transfer_id)

      csv = described_class.entries_to_csv
      lines = csv.split("\n")
      expect(lines.length).to eq(3)

      expect(csv).to include("支出")
      expect(csv).to include("转账")
    end
  end

  describe ".export_file_name" do
    it "returns a filename with timestamp" do
      filename = described_class.export_file_name
      expect(filename).to match(/^transactions_\d{8}_\d{6}\.csv$/)
    end
  end

  describe ".entries_export_file_name" do
    it "returns a filename with timestamp" do
      filename = described_class.entries_export_file_name
      expect(filename).to match(/^entries_\d{8}_\d{6}\.csv$/)
    end
  end
end
