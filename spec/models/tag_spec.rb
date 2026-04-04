# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:taggings).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:tag) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(50) }
  end

  describe 'scopes' do
    describe '.alphabetically' do
      it 'orders tags by name' do
        tag_b = create(:tag, name: 'Banana')
        tag_a = create(:tag, name: 'Apple')
        tag_c = create(:tag, name: 'Cherry')

        expect(Tag.alphabetically).to eq([ tag_a, tag_b, tag_c ])
      end
    end
  end

  describe '#set_default_color' do
    it 'sets a random color if not provided' do
      tag = build(:tag, name: 'Test', color: nil)
      tag.valid?

      expect(tag.color).to match(/\A#[0-9A-Fa-f]{6}\z/)
    end
  end
end
