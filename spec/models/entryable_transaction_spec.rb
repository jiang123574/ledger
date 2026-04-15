# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entryable::Transaction, type: :model do
  let(:account) { create(:account) }
  let(:category) { create(:category, name: "Food") }

  describe "associations" do
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to have_many(:taggings).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:taggings) }
  end

  describe "defaults" do
    it "sets default kind to expense" do
      transaction = Entryable::Transaction.new
      expect(transaction.kind).to eq("expense")
    end

    it "initializes locked_attributes" do
      transaction = Entryable::Transaction.new
      expect(transaction.locked_attributes).to eq({})
    end

    it "initializes extra" do
      transaction = Entryable::Transaction.new
      expect(transaction.extra).to eq({})
    end
  end

  describe "#income?" do
    it "returns true for income transactions" do
      entry = create(:entry, :income, account: account)
      expect(entry.entryable.income?).to be true
    end

    it "returns false for expense transactions" do
      entry = create(:entry, :expense, account: account)
      expect(entry.entryable.income?).to be false
    end
  end

  describe "#expense?" do
    it "returns true for expense transactions" do
      entry = create(:entry, :expense, account: account)
      expect(entry.entryable.expense?).to be true
    end

    it "returns false for income transactions" do
      entry = create(:entry, :income, account: account)
      expect(entry.entryable.expense?).to be false
    end
  end

  describe "tags" do
    let(:entry) { create(:entry, :expense, account: account) }
    let(:tag) { create(:tag, name: "Important") }

    describe "#tag_list" do
      it "returns list of tag names" do
        entry.entryable.tags << tag
        expect(entry.entryable.tag_list).to include("Important")
      end
    end

    describe "#tag_list=" do
      it "creates tags from names" do
        entry.entryable.tag_list = [ "Tag1", "Tag2" ]
        entry.entryable.save!

        expect(entry.entryable.tags.pluck(:name)).to include("Tag1", "Tag2")
      end

      it "finds existing tags" do
        existing_tag = create(:tag, name: "Existing")
        entry.entryable.tag_list = [ "Existing" ]
        entry.entryable.save!

        expect(entry.entryable.tags).to include(existing_tag)
      end
    end
  end

  describe "#lock_saved_attributes!" do
    it "locks category_id when present" do
      entry = create(:entry, :expense, account: account)
      entry.entryable.update!(category: category)
      entry.entryable.lock_saved_attributes!

      expect(entry.entryable.locked_attributes).to have_key("category_id")
    end

    it "locks tag_ids when tags exist" do
      entry = create(:entry, :expense, account: account)
      tag = create(:tag, name: "Test")
      entry.entryable.tags << tag
      entry.entryable.lock_saved_attributes!

      expect(entry.entryable.locked_attributes).to have_key("tag_ids")
    end
  end

  describe "extra store accessor" do
    it "stores provider_data" do
      entry = create(:entry, :expense, account: account)
      entry.entryable.provider_data = { source: "import" }
      entry.entryable.save!

      expect(entry.entryable.reload.provider_data).to eq("source" => "import")
    end

    it "stores sync_status" do
      entry = create(:entry, :expense, account: account)
      entry.entryable.sync_status = "synced"
      entry.entryable.save!

      expect(entry.entryable.reload.sync_status).to eq("synced")
    end
  end
end
