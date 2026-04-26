require 'rails_helper'

RSpec.describe OneTimeBudget do
  describe 'associations' do
    it { is_expected.to belong_to(:category).optional }
  end

  describe 'validations' do
    subject { build(:one_time_budget) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:start_date) }
  end

  describe 'scopes' do
    before { OneTimeBudget.destroy_all }

    describe '.active' do
      let!(:active_budget) { create(:one_time_budget, status: 'active') }
      let!(:completed_budget) { create(:one_time_budget, status: 'completed') }

      it 'returns only active budgets' do
        expect(OneTimeBudget.active).to include(active_budget)
        expect(OneTimeBudget.active).not_to include(completed_budget)
      end
    end

    describe '.current' do
      let!(:current_budget) do
        create(:one_time_budget, start_date: Date.current - 5.days, end_date: Date.current + 5.days, status: 'active')
      end
      let!(:past_budget) do
        create(:one_time_budget, start_date: Date.current - 30.days, end_date: Date.current - 10.days, status: 'active')
      end

      it 'returns budgets within current date range' do
        expect(OneTimeBudget.current).to include(current_budget)
        expect(OneTimeBudget.current).not_to include(past_budget)
      end

      it 'includes budgets without end_date' do
        ongoing = create(:one_time_budget, start_date: Date.current - 5.days, end_date: nil, status: 'active')
        expect(OneTimeBudget.current).to include(ongoing)
      end
    end
  end

  describe '#expired?' do
    it 'returns true when end_date is past' do
      budget = build(:one_time_budget, end_date: 1.day.ago)
      expect(budget.expired?).to be true
    end

    it 'returns false when end_date is future' do
      budget = build(:one_time_budget, end_date: 1.day.from_now)
      expect(budget.expired?).to be false
    end

    it 'returns false when end_date is nil' do
      budget = build(:one_time_budget, end_date: nil)
      expect(budget.expired?).to be false
    end
  end

  describe 'creation' do
    let(:category) { create(:category, :expense) }

    it 'creates budget with valid attributes' do
      budget = OneTimeBudget.create!(
        name: 'Trip Budget',
        amount: 5000,
        start_date: Date.current,
        end_date: 7.days.from_now,
        category: category,
        status: 'planning'
      )
      expect(budget).to be_persisted
      expect(budget.amount).to eq 5000
    end

    it 'creates budget without category' do
      budget = OneTimeBudget.create!(
        name: 'General Budget',
        amount: 1000,
        start_date: Date.current,
        status: 'planning'
      )
      expect(budget).to be_persisted
      expect(budget.category_id).to be_nil
    end
  end
end