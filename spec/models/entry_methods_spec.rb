# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entry, type: :model do
  let(:account) { create(:account) }

  describe "type check methods" do
    describe "#transaction?" do
      it "returns true for transaction entries" do
        entry = create(:entry, :expense, account: account)
        expect(entry.transaction?).to be true
      end

      it "returns false for valuation entries" do
        entry = create(:entry, :valuation, account: account)
        expect(entry.transaction?).to be false
      end
    end

    describe "#valuation?" do
      it "returns true for valuation entries" do
        entry = create(:entry, :valuation, account: account)
        expect(entry.valuation?).to be true
      end

      it "returns false for transaction entries" do
        entry = create(:entry, :expense, account: account)
        expect(entry.valuation?).to be false
      end
    end

    describe "#trade?" do
      it "returns true for trade entries" do
        entry = create(:entry, :trade, account: account)
        expect(entry.trade?).to be true
      end

      it "returns false for transaction entries" do
        entry = create(:entry, :expense, account: account)
        expect(entry.trade?).to be false
      end
    end
  end

  describe "#classification" do
    it "returns expense for negative amounts" do
      entry = Entry.new(amount: -100)
      expect(entry.classification).to eq("expense")
    end

    it "returns income for positive amounts" do
      entry = Entry.new(amount: 100)
      expect(entry.classification).to eq("income")
    end
  end

  describe "display methods" do
    describe "#display_entry_type" do
      it "returns TRANSFER when transfer_id is present" do
        entry = Entry.new(transfer_id: 1)
        expect(entry.display_entry_type).to eq("TRANSFER")
      end

      it "returns EXPENSE for expense transactions" do
        entry = create(:entry, :expense, account: account)
        expect(entry.display_entry_type).to eq("EXPENSE")
      end

      it "returns INCOME for income transactions" do
        entry = create(:entry, :income, account: account)
        expect(entry.display_entry_type).to eq("INCOME")
      end

      it "returns EXPENSE for valuation entries" do
        entry = create(:entry, :valuation, account: account)
        expect(entry.display_entry_type).to eq("EXPENSE")
      end
    end

    describe "#display_amount" do
      it "returns absolute value of amount" do
        entry = Entry.new(amount: -100.50)
        expect(entry.display_amount).to eq(100.50)
      end

      it "returns same value for positive amounts" do
        entry = Entry.new(amount: 100.50)
        expect(entry.display_amount).to eq(100.50)
      end
    end

    describe "#display_category" do
      it "returns category from entryable for transactions" do
        category = create(:category, name: "Food")
        entry = create(:entry, :expense, account: account)
        entry.entryable.update!(category: category)

        expect(entry.display_category).to eq(category)
      end

      it "returns nil for non-transaction entries" do
        entry = create(:entry, :valuation, account: account)
        expect(entry.display_category).to be_nil
      end
    end

    describe "#display_note" do
      it "returns notes when present" do
        entry = Entry.new(notes: "Test notes", name: "Test name")
        expect(entry.display_note).to eq("Test notes")
      end

      it "returns name when notes is blank" do
        entry = Entry.new(notes: nil, name: "Test name")
        expect(entry.display_note).to eq("Test name")
      end
    end

    describe "#account_name" do
      it "returns account name" do
        entry = Entry.new(account: account)
        expect(entry.account_name).to eq(account.name)
      end

      it "returns 未知账户 when account is nil" do
        entry = Entry.new(account: nil)
        expect(entry.account_name).to eq("未知账户")
      end
    end
  end

  describe "lock methods" do
    let(:entry) { create(:entry, :expense, account: account) }

    describe "#locked?" do
      it "returns true for locked attributes" do
        entry.update!(locked_attributes: { "name" => Time.current.iso8601 })
        expect(entry.locked?(:name)).to be true
      end

      it "returns false for unlocked attributes" do
        expect(entry.locked?(:name)).to be false
      end
    end

    describe "#lock_attribute!" do
      it "locks the attribute" do
        entry.lock_attribute!(:name)
        expect(entry.locked?(:name)).to be true
      end
    end
  end

  describe "split methods" do
    let(:entry) { create(:entry, :expense, account: account, amount: -300) }

    describe "#split_parent?" do
      it "returns true when has child entries" do
        child = create(:entry, :expense, account: account, parent_entry: entry, amount: -100)
        expect(entry.split_parent?).to be true
      end

      it "returns false when no child entries" do
        expect(entry.split_parent?).to be false
      end
    end

    describe "#split_child?" do
      it "returns true when has parent_entry_id" do
        child = Entry.new(parent_entry_id: entry.id)
        expect(child.split_child?).to be true
      end

      it "returns false when no parent_entry_id" do
        expect(entry.split_child?).to be false
      end
    end

    describe "#split!" do
      it "creates child entries and marks parent as excluded" do
        splits = [
          { name: "Split 1", amount: -100 },
          { name: "Split 2", amount: -200 }
        ]

        entry.split!(splits)

        expect(entry.child_entries.count).to eq(2)
        expect(entry.reload.excluded?).to be true
      end

      it "raises error when amounts don't sum to parent" do
        splits = [
          { name: "Split 1", amount: -100 },
          { name: "Split 2", amount: -100 }
        ]

        expect { entry.split!(splits) }.to raise_error(ArgumentError)
      end
    end

    describe "#unsplit!" do
      it "removes child entries and unmarks excluded" do
        splits = [
          { name: "Split 1", amount: -100 },
          { name: "Split 2", amount: -200 }
        ]
        entry.split!(splits)

        entry.unsplit!

        expect(entry.child_entries.count).to eq(0)
        expect(entry.reload.excluded?).to be false
      end
    end
  end

  describe "protected_from_sync?" do
    it "returns true when excluded" do
      entry = Entry.new(excluded: true)
      expect(entry.protected_from_sync?).to be true
    end

    it "returns true when user_modified" do
      entry = Entry.new(user_modified: true)
      expect(entry.protected_from_sync?).to be true
    end

    it "returns true when import_locked" do
      entry = Entry.new(import_locked: true)
      expect(entry.protected_from_sync?).to be true
    end

    it "returns false when none of the above" do
      entry = Entry.new(excluded: false, user_modified: false, import_locked: false)
      expect(entry.protected_from_sync?).to be false
    end
  end

  describe "#protection_reason" do
    it "returns :excluded when excluded" do
      entry = Entry.new(excluded: true)
      expect(entry.protection_reason).to eq(:excluded)
    end

    it "returns :user_modified when user_modified" do
      entry = Entry.new(excluded: false, user_modified: true)
      expect(entry.protection_reason).to eq(:user_modified)
    end

    it "returns :import_locked when import_locked" do
      entry = Entry.new(excluded: false, user_modified: false, import_locked: true)
      expect(entry.protection_reason).to eq(:import_locked)
    end

    it "returns nil when not protected" do
      entry = Entry.new(excluded: false, user_modified: false, import_locked: false)
      expect(entry.protection_reason).to be_nil
    end
  end
end
