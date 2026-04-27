require 'rails_helper'

RSpec.describe AccountEntriesQueryService do
  let(:service) { described_class.new(params) }
  let(:account) { create(:account) }
  let(:category) { create(:category, :expense) }
  let(:category_income) { create(:category, :income) }

  describe '#build' do
    context 'with no filters' do
      let(:params) { {} }

      before do
        create(:entry, :expense, account: account, date: Date.current)
        create(:entry, :expense, account: account, date: Date.yesterday)
      end

      it 'returns all transaction entries' do
        entries = service.build
        expect(entries.count).to eq 2
      end

      it 'orders entries by date descending' do
        entries = service.build.to_a
        expect(entries.first.date).to eq Date.current
        expect(entries.last.date).to eq Date.yesterday
      end
    end

    context 'with account_id filter' do
      let(:other_account) { create(:account) }
      let(:params) { { account_id: account.id } }

      before do
        create(:entry, :expense, account: account, date: Date.current)
        create(:entry, :expense, account: other_account, date: Date.current)
      end

      it 'returns entries for specified account only' do
        entries = service.build
        expect(entries.count).to eq 1
        expect(entries.first.account_id).to eq account.id
      end
    end

    context 'with type filter' do
      let(:params) { { type: 'expense' } }

      before do
        create(:entry, :expense, account: account, date: Date.current)
        create(:entry, :income, account: account, date: Date.current)
      end

      it 'returns entries of specified type only' do
        entries = service.build
        expect(entries.count).to eq 1
        expect(entries.first.amount).to be_negative
      end
    end

    context 'with category_ids filter' do
      let(:other_category) { create(:category, :expense) }
      let(:params) { { category_ids: [ category.id ] } }

      before do
        create(:entry, :expense, account: account, date: Date.current,
               entryable: build(:entryable_transaction, kind: 'expense', category: category))
        create(:entry, :expense, account: account, date: Date.current,
               entryable: build(:entryable_transaction, kind: 'expense', category: other_category))
      end

      it 'returns entries with specified category only' do
        entries = service.build
        expect(entries.count).to eq 1
      end
    end

    context 'with period filter' do
      let(:params) { { period_type: 'month', period_value: Date.current.strftime('%Y-%m') } }

      before do
        create(:entry, :expense, account: account, date: Date.current)
        create(:entry, :expense, account: account, date: Date.current.prev_month)
      end

      it 'returns entries within the period only' do
        entries = service.build
        expect(entries.count).to eq 1
        expect(entries.first.date.month).to eq Date.current.month
      end
    end

    context 'with search filter' do
      let(:params) { { search: 'Grocery' } }

      before do
        create(:entry, :expense, account: account, date: Date.current, name: 'Grocery shopping')
        create(:entry, :expense, account: account, date: Date.current, name: 'Coffee shop')
      end

      it 'returns entries matching search term' do
        entries = service.build
        expect(entries.count).to eq 1
        expect(entries.first.name).to include('Grocery')
      end
    end

    context 'with sort_direction asc' do
      let(:params) { { sort_direction: 'asc' } }

      before do
        create(:entry, :expense, account: account, date: Date.current)
        create(:entry, :expense, account: account, date: Date.yesterday)
      end

      it 'orders entries ascending by date' do
        entries = service.build.to_a
        expect(entries.first.date).to eq Date.yesterday
        expect(entries.last.date).to eq Date.current
      end
    end
  end

  describe '#cache_key' do
    let(:params) do
      {
        account_id: 1,
        type: 'expense',
        period_type: 'month',
        period_value: '2026-04',
        category_ids: [ 2, 3 ],
        sort_direction: 'desc'
      }
    end

    it 'generates consistent cache key from params' do
      key = service.cache_key
      expect(key).to include('1')
      expect(key).to include('expense')
      expect(key).to include('month')
      expect(key).to include('2026-04')
    end

    context 'with different params' do
      let(:params2) { { account_id: 2, type: 'expense' } }
      let(:service2) { described_class.new(params2) }

      it 'generates different cache keys' do
        expect(service.cache_key).not_to eq service2.cache_key
      end
    end
  end
end
