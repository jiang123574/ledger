require 'rails_helper'

RSpec.describe RecurringTransaction do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:category).optional }
  end

  describe 'validations' do
    subject { build(:recurring_transaction) }

    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:frequency) }
    it { is_expected.to validate_presence_of(:next_date) }
    it { is_expected.to validate_inclusion_of(:frequency).in_array(%w[daily weekly monthly yearly]) }
  end

  describe 'scopes' do
    before { RecurringTransaction.destroy_all }

    describe '.active' do
      let!(:active_recurring) { create(:recurring_transaction, is_active: 1) }
      let!(:inactive_recurring) { create(:recurring_transaction, is_active: 0) }

      it 'returns only active recurring transactions' do
        expect(RecurringTransaction.active).to include(active_recurring)
        expect(RecurringTransaction.active).not_to include(inactive_recurring)
      end
    end

    describe '.due_today' do
      let!(:due_today) { create(:recurring_transaction, is_active: 1, next_date: Date.current) }
      let!(:due_tomorrow) { create(:recurring_transaction, is_active: 1, next_date: Date.tomorrow) }

      it 'returns active transactions with next_date <= today' do
        expect(RecurringTransaction.due_today).to include(due_today)
        expect(RecurringTransaction.due_today).not_to include(due_tomorrow)
      end
    end
  end

  describe '#active?' do
    it 'returns true when is_active is 1' do
      recurring = build(:recurring_transaction, is_active: 1)
      expect(recurring.active?).to be true
    end

    it 'returns true when is_active is true' do
      recurring = build(:recurring_transaction, is_active: true)
      expect(recurring.active?).to be true
    end

    it 'returns false when is_active is 0' do
      recurring = build(:recurring_transaction, is_active: 0)
      expect(recurring.active?).to be false
    end
  end

  describe '#next_execution_date' do
    let(:base_date) { Date.new(2026, 1, 15) }

    it 'calculates next day for daily frequency' do
      recurring = build(:recurring_transaction, frequency: 'daily', next_date: base_date)
      result = recurring.next_execution_date
      expect(result).to be > base_date
      expect(result.to_date).to eq(base_date + 1.day)
    end

    it 'calculates next week for weekly frequency' do
      recurring = build(:recurring_transaction, frequency: 'weekly', next_date: base_date)
      result = recurring.next_execution_date
      expect(result).to be > base_date
      expect(result.to_date).to eq(base_date + 1.week)
    end

    it 'calculates next month for monthly frequency' do
      recurring = build(:recurring_transaction, frequency: 'monthly', next_date: base_date)
      result = recurring.next_execution_date
      expect(result).to be > base_date
    end

    it 'calculates next year for yearly frequency' do
      recurring = build(:recurring_transaction, frequency: 'yearly', next_date: base_date)
      result = recurring.next_execution_date
      expect(result).to be > base_date
    end
  end

  describe '#create_transaction' do
    let(:account) { create(:account) }
    let(:category) { create(:category, :expense) }
    let!(:recurring) do
      create(:recurring_transaction,
        account: account,
        category: category,
        amount: 100,
        frequency: 'monthly',
        next_date: Date.current,
        type: 'expense',
        currency: 'CNY',
        note: 'Test recurring'
      )
    end

    it 'creates an entry' do
      expect { recurring.create_transaction }.to change(Entry, :count).by(1)
    end

    it 'creates entry with correct account' do
      entry = recurring.create_transaction
      expect(entry.account).to eq account
    end

    it 'creates entry with negative amount for expense type' do
      entry = recurring.create_transaction
      expect(entry.amount).to be_negative
    end

    it 'creates entry with positive amount for income type' do
      recurring.update!(type: 'income')
      entry = recurring.create_transaction
      expect(entry.amount).to be_positive
    end

    it 'updates next_date after creating transaction' do
      original_next_date = recurring.next_date
      recurring.create_transaction
      expect(recurring.next_date).to be > original_next_date
    end

    it 'uses note as entry name' do
      entry = recurring.create_transaction
      expect(entry.name).to eq 'Test recurring'
    end
  end

  describe 'transaction_type compatibility' do
    it 'returns type value as transaction_type' do
      recurring = build(:recurring_transaction, type: 'expense')
      expect(recurring.transaction_type).to eq 'expense'
    end

    it 'sets type when transaction_type is assigned' do
      recurring = build(:recurring_transaction)
      recurring.transaction_type = 'income'
      expect(recurring.type).to eq 'income'
    end
  end
end