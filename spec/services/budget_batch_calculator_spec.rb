require 'rails_helper'

RSpec.describe BudgetBatchCalculator do
  let(:account) { create(:account) }
  let(:category) { create(:category, :expense) }
  let(:month) { Date.current.strftime('%Y-%m') }

  describe '.calculate_spent_amounts' do
    context 'with empty budgets array' do
      it 'returns empty hash' do
        result = described_class.calculate_spent_amounts([])
        expect(result).to eq({})
      end
    end

    context 'with total budget (no category)' do
      let!(:budget) { create(:budget, month: month, amount: 1000, category_id: nil) }

      before do
        # Create expense entries
        create(:entry, :expense, account: account, date: Date.current, amount: -100)
        create(:entry, :expense, account: account, date: Date.current, amount: -50)
      end

      it 'calculates total spent amount for the month' do
        result = described_class.calculate_spent_amounts([ budget ])
        expect(result[budget.id]).to eq 150
      end

      it 'returns 0 for budget with no matching entries' do
        budget_no_entries = create(:budget, month: '2020-01', amount: 500)
        result = described_class.calculate_spent_amounts([ budget_no_entries ])
        expect(result[budget_no_entries.id]).to eq 0
      end
    end

    context 'with category budget' do
      let!(:budget) { create(:budget, month: month, amount: 500, category: category) }

      before do
        # Entry with specific category
        entryable = create(:entryable_transaction, kind: 'expense', category: category)
        create(:entry, account: account, date: Date.current, amount: -100, entryable: entryable)
        # Entry with different category
        create(:entry, :expense, account: account, date: Date.current, amount: -50)
      end

      it 'calculates spent amount for specific category only' do
        result = described_class.calculate_spent_amounts([ budget ])
        expect(result[budget.id]).to eq 100
      end
    end

    context 'with multiple budgets' do
      let!(:total_budget) { create(:budget, month: month, amount: 1000, category_id: nil) }
      let!(:category_budget) { create(:budget, month: month, amount: 500, category: category) }

      before do
        entryable = create(:entryable_transaction, kind: 'expense', category: category)
        create(:entry, account: account, date: Date.current, amount: -200, entryable: entryable)
        create(:entry, :expense, account: account, date: Date.current, amount: -100)
      end

      it 'calculates amounts for all budgets correctly' do
        result = described_class.calculate_spent_amounts([ total_budget, category_budget ])
        expect(result[total_budget.id]).to eq 300
        expect(result[category_budget.id]).to eq 200
      end
    end

    context 'with budgets in current month' do
      let!(:budget) { create(:budget, month: month, amount: 1000, category_id: nil) }

      before do
        create(:entry, :expense, account: account, date: Date.current, amount: -100)
      end

      it 'calculates spent amount correctly' do
        result = described_class.calculate_spent_amounts([ budget ])
        expect(result[budget.id]).to eq 100
      end
    end
  end

  describe '.assign_spent_amounts' do
    let!(:budget) { create(:budget, month: month, amount: 500, category: category) }

    before do
      entryable = create(:entryable_transaction, kind: 'expense', category: category)
      create(:entry, account: account, date: Date.current, amount: -150, entryable: entryable)
    end

    it 'assigns calculated spent_amount to budget objects' do
      budgets = described_class.assign_spent_amounts([ budget ])
      expect(budgets.first.spent_amount).to eq 150
    end

    it 'returns the budgets array' do
      budgets = described_class.assign_spent_amounts([ budget ])
      expect(budgets).to be_an(Array)
      expect(budgets.first).to eq budget
    end
  end
end
