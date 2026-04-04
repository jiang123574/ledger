# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Entry, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:child_entries) }
  end

  describe 'validations' do
    subject { build(:entry) }

    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:currency) }
  end

  describe 'delegated_type' do
    it 'creates an entryable transaction' do
      entry = create(:entry)
      expect(entry.entryable).to be_present
    end
  end

  describe '#display_entry_type' do
    context 'expense entry' do
      let(:entry) { create(:entry, :expense) }

      it 'returns EXPENSE' do
        expect(entry.display_entry_type).to eq('EXPENSE')
      end
    end

    context 'income entry' do
      let(:entry) { create(:entry, :income) }

      it 'returns INCOME' do
        expect(entry.display_entry_type).to eq('INCOME')
      end
    end

    context 'transfer entry' do
      let(:entry) { create(:entry, amount: -500) }

      it 'returns TRANSFER when transfer_id is present' do
        allow(entry).to receive(:transfer_id).and_return(12345)
        expect(entry.display_entry_type).to eq('TRANSFER')
      end
    end
  end

  describe '#display_amount' do
    it 'returns absolute value of amount' do
      entry = build(:entry, amount: -100.50)
      expect(entry.display_amount).to eq(100.50)
    end

    it 'returns positive amount unchanged' do
      entry = build(:entry, amount: 200.00)
      expect(entry.display_amount).to eq(200.00)
    end
  end

  describe '#display_note' do
    it 'returns notes when present' do
      entry = build(:entry, notes: '买咖啡', name: '支出')
      expect(entry.display_note).to eq('买咖啡')
    end

    it 'falls back to name when notes is nil' do
      entry = build(:entry, notes: nil, name: '午餐')
      expect(entry.display_note).to eq('午餐')
    end
  end

  describe '#account_name' do
    it 'returns account name' do
      account = create(:account, name: '工商银行')
      entry = create(:entry, account: account)
      expect(entry.account_name).to eq('工商银行')
    end

    it 'returns fallback when no account' do
      entry = build(:entry, account: nil)
      expect(entry.account_name).to eq('未知账户')
    end
  end

  describe '#display_category' do
    it 'returns category from entryable' do
      category = create(:category)
      entryable = create(:entryable_transaction, category: category)
      entry = create(:entry, entryable: entryable)
      expect(entry.display_category).to eq(category)
    end
  end

  describe '#classification' do
    it 'returns expense for negative amount' do
      entry = build(:entry, amount: -100)
      expect(entry.classification).to eq('expense')
    end

    it 'returns income for positive amount' do
      entry = build(:entry, amount: 500)
      expect(entry.classification).to eq('income')
    end
  end

  describe 'scopes' do
    let!(:expense_entry) { create(:entry, amount: -100, date: 1.day.ago) }
    let!(:income_entry) { create(:entry, amount: 200, date: Date.current) }

    describe '.reverse_chronological' do
      it 'orders by date descending' do
        entries = described_class.reverse_chronological.to_a
        expect(entries.first).to eq(income_entry)
        expect(entries.last).to eq(expense_entry)
      end
    end

    describe '.by_date_range' do
      it 'filters entries within date range' do
        entries = described_class.by_date_range(Date.current, Date.current)
        expect(entries).to include(income_entry)
        expect(entries).not_to include(expense_entry)
      end
    end
  end
end
