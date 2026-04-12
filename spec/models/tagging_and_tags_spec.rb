# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tagging, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:tag) }
  end

  describe "taggable polymorphism" do
    let(:tag) { create(:tag, name: "Important") }
    let(:account) { create(:account) }
    let(:entry) { create(:entry, :expense, account: account) }

    it "can tag an entryable transaction" do
      tagging = Tagging.create!(tag: tag, taggable: entry.entryable)

      expect(tagging.taggable).to eq(entry.entryable)
      expect(tagging.tag).to eq(tag)
    end

    it "destroys tagging when tag is destroyed" do
      Tagging.create!(tag: tag, taggable: entry.entryable)

      expect {
        tag.destroy
      }.to change(Tagging, :count).by(-1)
    end

    it "destroys tagging when taggable is destroyed" do
      Tagging.create!(tag: tag, taggable: entry.entryable)

      expect {
        entry.entryable.destroy
      }.to change(Tagging, :count).by(-1)
    end
  end
end

RSpec.describe Tag, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:taggings).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(50) }
  end

  describe "scopes" do
    let!(:tag_b) { create(:tag, name: "Banana") }
    let!(:tag_a) { create(:tag, name: "Apple") }
    let!(:tag_c) { create(:tag, name: "Cherry") }

    describe ".alphabetically" do
      it "orders tags by name" do
        expect(Tag.alphabetically.pluck(:name)).to eq(["Apple", "Banana", "Cherry"])
      end
    end
  end

  describe "#description" do
    it "returns nil if attribute does not exist" do
      tag = Tag.new(name: "Test")
      expect(tag.description).to be_nil
    end
  end

  describe "color generation" do
    it "generates a random color when not provided" do
      tag = Tag.new(name: "No Color")
      tag.valid?
      expect(tag.color).to match(/\A#[0-9A-Fa-f]{6}\z/)
    end

    it "validates color format" do
      tag = Tag.new(name: "Bad Color", color: "invalid")
      expect(tag).not_to be_valid
      expect(tag.errors[:color]).to be_present
    end

    it "allows valid hex color" do
      tag = Tag.new(name: "Good Color", color: "#FF5733")
      tag.valid?
      expect(tag.errors[:color]).to be_empty
    end
  end
end

RSpec.describe Category, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:parent).optional }
    it { is_expected.to have_many(:children) }
    it { is_expected.to have_many(:budgets) }
  end

  describe "scopes" do
    let!(:expense_cat) { create(:category, name: "Food", category_type: "EXPENSE") }
    let!(:income_cat) { create(:category, :income, name: "Salary") }
    let!(:inactive_cat) { create(:category, name: "Inactive", active: false) }

    describe ".expense" do
      it "returns expense categories" do
        expect(Category.expense).to include(expense_cat)
        expect(Category.expense).not_to include(income_cat)
      end
    end

    describe ".income" do
      it "returns income categories" do
        expect(Category.income).to include(income_cat)
        expect(Category.income).not_to include(expense_cat)
      end
    end

    describe ".active" do
      it "returns active categories" do
        expect(Category.active).to include(expense_cat)
        expect(Category.active).not_to include(inactive_cat)
      end
    end
  end

  describe "#root?" do
    it "returns true for root categories" do
      category = create(:category, level: 0)
      expect(category.root?).to be true
    end

    it "returns false for child categories" do
      parent = create(:category)
      child = create(:category, parent: parent, level: 1)
      expect(child.root?).to be false
    end
  end
end
