# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransactionSearch, type: :model do
  describe '#apply' do
    let(:scope) { Transaction.all }

    it 'returns scope with default sort when no filters' do
      search = described_class.new({})

      result = search.apply(scope)

      expect(result.to_sql).to include('ORDER BY')
    end

    it 'filters by date range' do
      search = described_class.new(
        start_date: '2024-01-01',
        end_date: '2024-12-31'
      )

      result = search.apply(scope)

      expect(result.to_sql).to include('date')
    end

    it 'filters by type' do
      search = described_class.new(type: 'INCOME')

      result = search.apply(scope)

      expect(result.to_sql).to include('type')
    end

    it 'filters by account_id' do
      search = described_class.new(account_id: 1)

      result = search.apply(scope)

      expect(result.to_sql).to include('account_id')
    end

    it 'filters by category_id' do
      search = described_class.new(category_id: 1)

      result = search.apply(scope)

      expect(result.to_sql).to include('category_id')
    end

    it 'filters by search term' do
      search = described_class.new(search: 'test')

      result = search.apply(scope)

      expect(result.to_sql).to include('note')
    end
  end

  describe '#active_filters?' do
    it 'returns false when no filters' do
      search = described_class.new({})

      expect(search.active_filters?).to be false
    end

    it 'returns true when type is present' do
      search = described_class.new(type: 'INCOME')

      expect(search.active_filters?).to be true
    end

    it 'returns true when search is present' do
      search = described_class.new(search: 'test')

      expect(search.active_filters?).to be true
    end
  end

  describe '#to_params' do
    it 'returns only sort by default' do
      search = described_class.new({})

      params = search.to_params

      expect(params[:sort]).to eq('date_desc')
    end

    it 'returns only present values' do
      search = described_class.new(
        type: 'INCOME',
        start_date: '2024-01-01'
      )

      params = search.to_params

      expect(params[:type]).to eq('INCOME')
      expect(params[:start_date]).to be_present
    end
  end
end