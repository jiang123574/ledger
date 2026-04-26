require 'rails_helper'

RSpec.describe AccountDashboardService do
  let(:account) { create(:account, initial_balance: 1000) }
  let(:category) { create(:category, :expense) }
  let(:params) { {} }

  subject { AccountDashboardService.new(params) }

  describe '#load_dashboard' do
    before do
      create(:entry, :expense, account: account, amount: -100, date: Date.current)
    end

    it 'returns a hash with all required keys' do
      result = subject.load_dashboard

      expect(result).to have_key(:accounts)
      expect(result).to have_key(:accounts_map)
      expect(result).to have_key(:account_balances)
      expect(result).to have_key(:total_assets)
      expect(result).to have_key(:categories)
      expect(result).to have_key(:expense_categories)
      expect(result).to have_key(:counterparties)
      expect(result).to have_key(:unsettled_receivables)
      expect(result).to have_key(:entries_with_balance)
      expect(result).to have_key(:total_count)
      expect(result).to have_key(:page)
      expect(result).to have_key(:per_page)
      expect(result).to have_key(:account_balance)
      expect(result).to have_key(:total_income)
      expect(result).to have_key(:total_expense)
      expect(result).to have_key(:total_balance)
      expect(result).to have_key(:entry)
      expect(result).to have_key(:new_transaction)
    end

    it 'loads accounts correctly' do
      result = subject.load_dashboard
      expect(result[:accounts]).to include(account)
    end

    it 'builds accounts_map indexed by id' do
      result = subject.load_dashboard
      expect(result[:accounts_map][account.id]).to eq(account)
    end

    it 'calculates account balances correctly' do
      result = subject.load_dashboard
      expect(result[:account_balances][account.id]).to eq(BigDecimal('900'))
    end

    it 'returns paginated entries' do
      result = subject.load_dashboard
      expect(result[:entries_with_balance]).to be_an(Array)
      expect(result[:page]).to eq(1)
      expect(result[:per_page]).to eq(15)
    end

    context 'with show_hidden param' do
      let!(:hidden_account) { create(:account, hidden: true, name: 'Hidden') }

      it 'includes hidden accounts when show_hidden is true' do
        params[:show_hidden] = 'true'
        result = subject.load_dashboard
        expect(result[:accounts]).to include(hidden_account)
      end

      it 'excludes hidden accounts when show_hidden is false' do
        params[:show_hidden] = 'false'
        result = subject.load_dashboard
        expect(result[:accounts]).not_to include(hidden_account)
      end
    end

    context 'with account_id filter' do
      let!(:other_account) { create(:account, name: 'Other') }

      before do
        create(:entry, :expense, account: other_account, amount: -50, date: Date.current)
        params[:account_id] = account.id
      end

      it 'only returns entries for specified account' do
        result = subject.load_dashboard
        entry_accounts = result[:entries_with_balance].map { |e, _| e.account_id }
        expect(entry_accounts).to all(eq(account.id))
      end
    end

    context 'with pagination params' do
      before do
        params[:page] = 2
        params[:per_page] = 10
      end

      it 'respects page param' do
        result = subject.load_dashboard
        expect(result[:page]).to eq(2)
      end

      it 'clamps per_page to minimum 15' do
        params[:per_page] = 5
        result = subject.load_dashboard
        expect(result[:per_page]).to eq(15)
      end

      it 'clamps per_page to maximum 200' do
        params[:per_page] = 500
        result = subject.load_dashboard
        expect(result[:per_page]).to eq(200)
      end

      it 'clamps page to valid range' do
        params[:page] = 2000
        result = subject.load_dashboard
        expect(result[:page]).to eq(1000)
      end

      it 'clamps per_page to valid range' do
        params[:per_page] = 5
        result = subject.load_dashboard
        expect(result[:per_page]).to eq(15)
      end
    end
  end

  describe '.build_entries_query' do
    let(:params) { { account_id: account.id } }

    it 'builds query with account filter' do
      query = AccountDashboardService.build_entries_query(params, 'month', Date.current.strftime('%Y-%m'))
      expect(query.where_values_hash['account_id']).to eq(account.id)
    end

    it 'filters by transaction entryable type' do
      query = AccountDashboardService.build_entries_query({}, 'month', Date.current.strftime('%Y-%m'))
      expect(query.where_values_hash['entryable_type']).to include('Entryable::Transaction')
    end
  end

  describe '.build_count_cache_key' do
    it 'builds cache key from params' do
      params = { account_id: 1, type: 'expense', period_type: 'month' }
      key = AccountDashboardService.build_count_cache_key(params)
      expect(key).to include('1')
      expect(key).to include('expense')
      expect(key).to include('month')
    end
  end

  describe '.build_entries_cache_key' do
    it 'includes sort_direction in cache key' do
      params = { account_id: 1, sort_direction: 'asc' }
      key = AccountDashboardService.build_entries_cache_key(params)
      expect(key).to include('asc')
    end

    it 'defaults to desc sort_direction' do
      params = { account_id: 1 }
      key = AccountDashboardService.build_entries_cache_key(params)
      expect(key).to include('desc')
    end
  end
end