require 'rails_helper'

RSpec.describe Tagging do
  describe 'associations' do
    it { is_expected.to belong_to(:tag) }
    it { is_expected.to belong_to(:taggable) }
  end

  describe 'validations' do
    let(:tag) { create(:tag) }
    let(:account) { create(:account) }
    let(:entry) { create(:entry, :expense, account: account) }
    let(:transaction) { entry.entryable }

    it 'validates uniqueness of tag scoped to taggable' do
      Tagging.create!(tag: tag, taggable: transaction)
      duplicate = Tagging.new(tag: tag, taggable: transaction)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:tag_id]).to be_present
    end
  end

  describe 'polymorphic association' do
    let(:tag) { create(:tag) }
    let(:account) { create(:account) }

    it 'can tag an Entryable::Transaction' do
      entry = create(:entry, :expense, account: account)
      transaction = entry.entryable
      tagging = Tagging.create!(tag: tag, taggable: transaction)
      expect(tagging.taggable).to eq transaction
      expect(tagging.taggable_type).to eq 'Entryable::Transaction'
    end
  end

  describe 'uniqueness constraint' do
    let(:tag) { create(:tag) }
    let(:account) { create(:account) }
    let(:entry1) { create(:entry, :expense, account: account) }
    let(:entry2) { create(:entry, :expense, account: account) }
    let(:transaction1) { entry1.entryable }
    let(:transaction2) { entry2.entryable }

    it 'allows same tag on different taggables' do
      Tagging.create!(tag: tag, taggable: transaction1)
      tagging2 = Tagging.new(tag: tag, taggable: transaction2)
      expect(tagging2).to be_valid
    end

    it 'allows different tags on same taggable' do
      tag1 = create(:tag, name: 'Tag1')
      tag2 = create(:tag, name: 'Tag2')
      Tagging.create!(tag: tag1, taggable: transaction1)
      tagging2 = Tagging.new(tag: tag2, taggable: transaction1)
      expect(tagging2).to be_valid
    end
  end

  describe 'deletion behavior' do
    let(:tag) { create(:tag) }
    let(:account) { create(:account) }
    let(:entry) { create(:entry, :expense, account: account) }
    let(:transaction) { entry.entryable }

    it 'tagging is removed when tag is destroyed' do
      tagging = Tagging.create!(tag: tag, taggable: transaction)
      tag.destroy
      expect(Tagging.exists?(tagging.id)).to be false
    end

    it 'tagging is removed when taggable (transaction) is destroyed' do
      tagging = Tagging.create!(tag: tag, taggable: transaction)
      entry.destroy
      expect(Tagging.exists?(tagging.id)).to be false
    end
  end
end