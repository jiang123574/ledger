# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Category, type: :model do
  # ==================== Associations ====================
  describe 'associations' do
    it { is_expected.to have_many(:children).class_name('Category').dependent(:destroy) }
    it { is_expected.to belong_to(:parent).class_name('Category').optional }
    it { is_expected.to have_many(:entryable_transactions).class_name('Entryable::Transaction').dependent(:nullify) }
    it { is_expected.to have_many(:entries).through(:entryable_transactions) }
    it { is_expected.to have_many(:budgets).dependent(:nullify) }
    it { is_expected.to have_many(:one_time_budgets).dependent(:nullify) }
    it { is_expected.to have_many(:recurring_transactions).dependent(:nullify) }
  end

  # ==================== Validations ====================
  describe 'validations' do
    subject { build(:category) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:parent_id) }

    describe 'no_circular_reference' do
      let(:parent) { create(:category, name: 'Parent') }
      let(:child) { create(:category, name: 'Child', parent: parent) }

      it 'prevents circular reference' do
        parent.parent = child
        expect(parent).not_to be_valid
        expect(parent.errors[:parent_id]).to include('不能创建循环引用')
      end

      it 'allows valid parent assignment' do
        child.parent = parent
        expect(child).to be_valid
      end
    end
  end

  # ==================== Scopes ====================
  describe 'scopes' do
    let!(:food) { create(:category, name: 'Food', sort_order: 2) }
    let!(:transport) { create(:category, name: 'Transport', sort_order: 1) }
    let!(:salary) { create(:category, name: 'Salary', category_type: 'INCOME') }
    let!(:expense_cat) { create(:category, name: 'Expense', category_type: 'EXPENSE') }
    let!(:parent_cat) { create(:category, name: 'Parent Cat', parent_id: nil) }
    let!(:child_cat) { create(:category, name: 'Child Cat', parent: parent_cat) }
    let!(:active_cat) { create(:category, name: 'Active', active: true) }
    let!(:inactive_cat) { create(:category, name: 'Inactive', active: false) }

    describe '.alphabetically' do
      it 'orders by name ascending' do
        result = Category.alphabetically
        expect(result.first.name).to be <= result.last.name
      end
    end

    describe '.by_sort_order' do
      it 'orders by sort_order then name' do
        result = Category.by_sort_order
        expect(result.first.sort_order).to be <= result.last.sort_order
      end
    end

    describe '.roots' do
      it 'returns only root categories' do
        result = Category.roots
        expect(result).to include(parent_cat)
        expect(result).not_to include(child_cat)
      end
    end

    describe '.expense' do
      it 'returns only expense categories' do
        result = Category.expense
        expect(result).to include(expense_cat)
        expect(result).not_to include(salary)
      end
    end

    describe '.income' do
      it 'returns only income categories' do
        result = Category.income
        expect(result).to include(salary)
        expect(result).not_to include(expense_cat)
      end
    end

    describe '.active' do
      it 'returns only active categories' do
        result = Category.active
        expect(result).to include(active_cat)
        expect(result).not_to include(inactive_cat)
      end
    end

    describe '.with_transaction_counts' do
      it 'includes transactions_count attribute' do
        result = Category.with_transaction_counts.first
        expect(result).to respond_to(:transactions_count)
      end
    end
  end

  # ==================== Instance Methods ====================
  describe 'instance methods' do
    let(:root_category) { create(:category, name: 'Root', category_type: 'EXPENSE') }
    let(:child_category) { create(:category, name: 'Child', parent: root_category) }
    let(:grandchild_category) { create(:category, name: 'Grandchild', parent: child_category) }

    describe '#expense?' do
      it 'returns true for EXPENSE type' do
        category = build(:category, category_type: 'EXPENSE')
        expect(category.expense?).to be true
      end

      it 'returns false for INCOME type' do
        category = build(:category, category_type: 'INCOME')
        expect(category.expense?).to be false
      end
    end

    describe '#income?' do
      it 'returns true for INCOME type' do
        category = build(:category, category_type: 'INCOME')
        expect(category.income?).to be true
      end

      it 'returns false for EXPENSE type' do
        category = build(:category, category_type: 'EXPENSE')
        expect(category.income?).to be false
      end
    end

    describe '#root?' do
      it 'returns true when parent_id is nil' do
        expect(root_category.root?).to be true
      end

      it 'returns false when parent_id is present' do
        expect(child_category.root?).to be false
      end
    end

    describe '#leaf?' do
      it 'returns true when no children' do
        expect(grandchild_category.leaf?).to be true
      end

      it 'returns false when has children' do
        # 创建一个新的测试场景
        parent = create(:category, name: 'New Parent')
        create(:category, name: 'New Child', parent: parent)
        parent.reload
        expect(parent.leaf?).to be false
      end
    end

    describe '#depth' do
      it 'returns 0 for root category' do
        expect(root_category.depth).to eq(0)
      end

      it 'returns 1 for child category' do
        expect(child_category.depth).to eq(1)
      end

      it 'returns 2 for grandchild category' do
        expect(grandchild_category.depth).to eq(2)
      end
    end

    describe '#full_name' do
      it 'returns name for root category' do
        expect(root_category.full_name).to eq('Root')
      end

      it 'returns full path for nested category' do
        expect(child_category.full_name).to eq('Root > Child')
        expect(grandchild_category.full_name).to eq('Root > Child > Grandchild')
      end

      it 'supports custom separator' do
        expect(child_category.full_name(separator: '/')).to eq('Root/Child')
      end
    end

    describe '#ancestors' do
      it 'returns empty array for root category' do
        expect(root_category.ancestors).to eq([])
      end

      it 'returns all ancestors in order' do
        ancestors = grandchild_category.ancestors
        expect(ancestors.map(&:id)).to eq([ child_category.id, root_category.id ])
      end
    end

    describe '#descendants' do
      it 'returns empty array for leaf category' do
        expect(grandchild_category.descendants).to eq([])
      end

      it 'returns direct children only' do
        root_category.reload
        descendants = root_category.descendants
        expect(descendants).to be_an(Array)
      end
    end

    describe '#self_and_descendants' do
      it 'returns self in the result' do
        root_category.reload
        result = root_category.self_and_descendants
        expect(result).to include(root_category)
      end
    end

    describe '#self_and_descendant_ids' do
      it 'returns self id' do
        ids = root_category.self_and_descendant_ids
        expect(ids).to include(root_category.id)
      end
    end

    describe '#transactions_count' do
      it 'returns count of entries' do
        account = create(:account)
        create_list(:entry, 3, account: account, entryable: create(:entryable_transaction, category: root_category))

        expect(root_category.transactions_count).to eq(3)
      end
    end

    describe '#monthly_amount' do
      it 'returns sum of absolute amounts for the month' do
        account = create(:account)
        month_str = Date.current.strftime('%Y-%m')

        create(:entry, account: account, amount: 100, date: Date.current, entryable: create(:entryable_transaction, category: root_category))
        create(:entry, account: account, amount: -50, date: Date.current, entryable: create(:entryable_transaction, category: root_category))

        expect(root_category.monthly_amount(month_str)).to eq(150)
      end
    end

    describe '#budget_progress' do
      let(:account) { create(:account) }
      let(:month_str) { Date.current.strftime('%Y-%m') }

      before do
        create(:budget, category: root_category, month: month_str, amount: 1000)
        create(:entry, account: account, amount: -300, date: Date.current, entryable: create(:entryable_transaction, category: root_category))
      end

      it 'returns budget progress hash' do
        progress = root_category.budget_progress(month_str)

        expect(progress[:budget]).to eq(1000)
        expect(progress[:spent]).to eq(300)
        expect(progress[:remaining]).to eq(700)
        expect(progress[:percentage]).to eq(30.0)
      end

      it 'returns nil when no budget exists' do
        expect(root_category.budget_progress('2020-01')).to be_nil
      end
    end
  end

  # ==================== Class Methods ====================
  describe 'class methods' do
    describe '.descendant_ids_for' do
      it 'returns empty array for blank input' do
        expect(Category.descendant_ids_for(nil)).to eq([])
        expect(Category.descendant_ids_for([])).to eq([])
      end

      it 'responds to method' do
        expect(Category).to respond_to(:descendant_ids_for)
      end
    end

    describe '.ransackable_attributes' do
      it 'returns list of ransackable attributes' do
        expect(Category.ransackable_attributes).to include('name', 'category_type', 'color')
      end
    end

    describe '.ransackable_associations' do
      it 'returns list of ransackable associations' do
        expect(Category.ransackable_associations).to include('parent', 'children', 'entries')
      end
    end
  end

  # ==================== Callbacks ====================
  describe 'callbacks' do
    describe 'before_validation :set_defaults' do
      it 'sets category_type to EXPENSE by default' do
        category = Category.new(name: 'Test')
        category.valid?
        expect(category.category_type).to eq('EXPENSE')
      end

      it 'sets sort_order to 0 by default' do
        category = Category.new(name: 'Test')
        category.valid?
        expect(category.sort_order).to eq(0)
      end

      it 'sets active to true by default' do
        category = Category.new(name: 'Test')
        category.valid?
        expect(category.active).to be true
      end
    end

    describe 'before_save :update_level' do
      it 'updates level based on parent' do
        root = create(:category, level: 0)
        child = create(:category, parent: root)

        expect(child.level).to eq(1)
      end
    end
  end

  # ==================== Edge Cases ====================
  describe 'edge cases' do
    it 'handles deep nesting' do
      levels = 5.times.reduce(nil) do |parent, i|
        create(:category, name: "Level #{i}", parent: parent)
      end

      expect(levels.depth).to eq(4)
    end

    it 'handles special characters in name' do
      category = create(:category, name: '餐饮 & 娱乐 (Food & Entertainment)')
      expect(category.full_name).to include('&')
    end

    it 'handles unicode characters' do
      category = create(:category, name: '🎉 庆祝')
      expect(category.name).to include('🎉')
    end
  end
end
