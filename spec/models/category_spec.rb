# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:children).dependent(:destroy) }
    it { is_expected.to belong_to(:parent).optional }
    it { is_expected.to have_many(:transactions).dependent(:nullify) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe 'scopes' do
    describe '.roots' do
      it 'returns categories without parent' do
        root = create(:category, parent_id: nil)
        child = create(:category, parent: root)

        expect(Category.roots).to include(root)
        expect(Category.roots).not_to include(child)
      end
    end

    describe '.active' do
      it 'returns only active categories' do
        active = create(:category, active: true)
        inactive = create(:category, active: false)

        expect(Category.active).to include(active)
        expect(Category.active).not_to include(inactive)
      end
    end
  end

  describe '#root?' do
    it 'returns true for categories without parent' do
      category = build(:category, parent_id: nil)

      expect(category.root?).to be true
    end

    it 'returns false for categories with parent' do
      parent = create(:category)
      category = build(:category, parent: parent)

      expect(category.root?).to be false
    end
  end

  describe '#leaf?' do
    it 'returns true for categories without children' do
      category = create(:category)

      expect(category.leaf?).to be true
    end

    it 'returns false for categories with children' do
      parent = create(:category)
      create(:category, parent: parent)

      expect(parent.leaf?).to be false
    end
  end

  describe '#full_name' do
    it 'returns just the name for root categories' do
      category = build(:category, name: 'Food')

      expect(category.full_name).to eq('Food')
    end

    it 'returns full path for nested categories' do
      parent = create(:category, name: 'Food')
      child = create(:category, name: 'Groceries', parent: parent)

      expect(child.full_name).to eq('Food > Groceries')
    end
  end

  describe '#update_level' do
    it 'sets level to 0 for root categories' do
      category = create(:category, parent_id: nil)

      expect(category.level).to eq(0)
    end

    it 'sets level based on parent' do
      parent = create(:category, level: 0)
      child = create(:category, parent: parent)

      expect(child.level).to eq(1)
    end
  end

  describe '#no_circular_reference' do
    it 'prevents circular references' do
      parent = create(:category)
      child = create(:category, parent: parent)

      # Try to make parent a child of its own child
      parent.parent = child
      parent.valid?

      expect(parent.errors[:parent_id]).to include('不能创建循环引用')
    end
  end
end
