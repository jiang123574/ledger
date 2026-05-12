require 'rails_helper'

RSpec.describe AccountBalanceService do
  let(:today) { Date.today }
  let(:start_date) { today.beginning_of_year }
  let(:end_date) { today.end_of_year }
  let(:service) { described_class.new(start_date: start_date, end_date: end_date) }

  describe '#compute_balance_data' do
    context 'with no accounts' do
      it 'returns zero values' do
        result = service.compute_balance_data

        expect(result[:current_assets]).to eq(0)
        expect(result[:current_liabilities]).to eq(0)
        expect(result[:current_net_worth]).to eq(0)
      end
    end

    context 'with asset accounts' do
      let!(:cash_account) { create(:account, type: 'CASH', initial_balance: 1000) }
      let!(:bank_account) { create(:account, type: 'BANK', initial_balance: 5000) }

      it 'calculates current assets correctly' do
        result = service.compute_balance_data

        expect(result[:current_assets]).to eq(6000)
        expect(result[:asset_account_ids]).to contain_exactly(cash_account.id, bank_account.id)
      end
    end

    context 'with liability accounts' do
      let!(:credit_account) { create(:account, type: 'CREDIT', initial_balance: -500) }
      let!(:loan_account) { create(:account, type: 'LOAN', initial_balance: -2000) }

      it 'calculates current liabilities correctly' do
        result = service.compute_balance_data

        expect(result[:current_liabilities]).to eq(-2500)
        expect(result[:liability_account_ids]).to contain_exactly(credit_account.id, loan_account.id)
      end
    end

    context 'with entries' do
      let!(:bank_account) { create(:account, type: 'BANK', initial_balance: 1000) }
      let!(:credit_account) { create(:account, type: 'CREDIT', initial_balance: -200) }

      before do
        # 收入 entry
        create(:entry, account: bank_account, amount: 100, date: today.beginning_of_month)
        # 支出 entry
        create(:entry, account: bank_account, amount: -50, date: today.beginning_of_month)
        # 信用卡还款
        create(:entry, account: credit_account, amount: 50, date: today.beginning_of_month)
      end

      it 'calculates monthly deltas' do
        result = service.compute_balance_data

        expect(result[:current_assets]).to eq(1050) # 1000 + 100 - 50
        expect(result[:current_liabilities]).to eq(-150) # -200 + 50
        expect(result[:monthly_asset_delta][today.month]).to eq(50)
        expect(result[:monthly_liability_delta][today.month]).to eq(50)
      end
    end

    context 'with hidden accounts' do
      let!(:active_account) { create(:account, type: 'BANK', initial_balance: 1000) }
      let!(:hidden_account) { create(:account, type: 'BANK', initial_balance: 500, hidden: true) }

      it 'excludes hidden accounts' do
        result = service.compute_balance_data

        expect(result[:current_assets]).to eq(1000)
        expect(result[:asset_account_ids]).to contain_exactly(active_account.id)
      end
    end
  end

  describe '#compute_net_worth_trend' do
    context 'with mixed accounts and entries' do
      let!(:bank_account) { create(:account, type: 'BANK', initial_balance: 10000) }
      let!(:credit_account) { create(:account, type: 'CREDIT', initial_balance: -1000) }

      before do
        # 1月收入
        create(:entry, account: bank_account, amount: 500, date: Date.new(today.year, 1, 15))
        # 2月支出
        create(:entry, account: bank_account, amount: -200, date: Date.new(today.year, 2, 15))
        # 3月信用卡消费
        create(:entry, account: credit_account, amount: -100, date: Date.new(today.year, 3, 15))
      end

      it 'returns trend data with correct structure' do
        result = service.compute_net_worth_trend

        expect(result).to have_key(:labels)
        expect(result).to have_key(:net_worth)
        expect(result).to have_key(:assets)
        expect(result).to have_key(:liabilities)
        expect(result).to have_key(:details)
      end

      it 'calculates monthly net worth correctly' do
        result = service.compute_net_worth_trend

        # 估算起始净资产 = 当前净资产 - 期间总变动
        # 当前: assets=10300, liabilities=-1100, net_worth=9200
        # 变动: assets=300, liabilities=-100, total=200
        # 起始: 9000

        first_month = result[:details].first
        expect(first_month[:net_worth]).to be_within(0.01).of(9000.0 + 500.0)
      end
    end
  end

  describe '#compute_yearly_asset_trend' do
    let!(:bank_account) { create(:account, type: 'BANK', initial_balance: 5000) }

    before do
      create(:entry, account: bank_account, amount: 100, date: Date.new(today.year, 1, 15))
      create(:entry, account: bank_account, amount: 200, date: Date.new(today.year, 6, 15))
    end

    it 'returns 12 months of data' do
      result = service.compute_yearly_asset_trend

      expect(result.size).to eq(12)
    end

    it 'has correct structure for each month' do
      result = service.compute_yearly_asset_trend

      result.each do |month|
        expect(month).to have_key(:label)
        expect(month).to have_key(:month)
        expect(month).to have_key(:assets)
        expect(month).to have_key(:liabilities)
        expect(month).to have_key(:net_worth)
      end
    end

    it 'accumulates changes correctly' do
      result = service.compute_yearly_asset_trend

      # 1月应该有 +100 的变动
      expect(result[0][:assets]).to be_within(0.01).of(5000.0 + 100.0)
      # 6月应该额外有 +200 的变动
      expect(result[5][:assets]).to be_within(0.01).of(5000.0 + 100.0 + 200.0)
    end
  end
end
