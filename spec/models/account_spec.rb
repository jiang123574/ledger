# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account, type: :model do
  # ==================== Associations ====================
  describe 'associations' do
    it { is_expected.to have_many(:entries).dependent(:destroy) }
    it { is_expected.to have_many(:transaction_entries).class_name('Entry') }
    it { is_expected.to have_many(:valuation_entries).class_name('Entry') }
    it { is_expected.to have_many(:trade_entries).class_name('Entry') }
    it { is_expected.to have_many(:plans).dependent(:destroy) }
    it { is_expected.to have_many(:recurring_transactions).dependent(:destroy) }
  end

  # ==================== Validations ====================
  describe 'validations' do
    subject { build(:account) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_length_of(:currency).is_equal_to(3) }
  end

  # ==================== Scopes ====================
  describe 'scopes' do
    let!(:visible_account) { create(:account, hidden: false) }
    let!(:hidden_account) { create(:account, hidden: true, name: 'Hidden Account') }
    let!(:included_account) { create(:account, include_in_total: true) }
    let!(:excluded_account) { create(:account, include_in_total: false, name: 'Excluded Account') }

    describe '.visible' do
      it 'returns only non-hidden accounts' do
        expect(Account.visible).to include(visible_account)
        expect(Account.visible).not_to include(hidden_account)
      end
    end

    describe '.included_in_total' do
      it 'returns only accounts included in total' do
        expect(Account.included_in_total).to include(included_account)
        expect(Account.included_in_total).not_to include(excluded_account)
      end
    end

    describe '.by_type' do
      let!(:cash_account) { create(:account, type: 'CASH') }
      let!(:bank_account) { create(:account, type: 'BANK', name: 'Bank Account') }

      it 'filters by type when provided' do
        expect(Account.by_type('CASH')).to include(cash_account)
        expect(Account.by_type('CASH')).not_to include(bank_account)
      end

      it 'returns all when type is blank' do
        expect(Account.by_type(nil).count).to eq(Account.count)
        expect(Account.by_type('').count).to eq(Account.count)
      end
    end

    describe '.by_currency' do
      let!(:cny_account) { create(:account, currency: 'CNY') }
      let!(:usd_account) { create(:account, currency: 'USD', name: 'USD Account') }

      it 'filters by currency when provided' do
        expect(Account.by_currency('CNY')).to include(cny_account)
        expect(Account.by_currency('CNY')).not_to include(usd_account)
      end

      it 'returns all when currency is blank' do
        expect(Account.by_currency(nil).count).to eq(Account.count)
      end
    end

    describe '.by_last_activity' do
      let!(:old_account) { create(:account, last_transaction_date: 10.days.ago, name: 'Old Account') }
      let!(:new_account) { create(:account, last_transaction_date: 1.day.ago, name: 'New Account') }

      it 'orders by last_transaction_date descending' do
        result = Account.by_last_activity.to_a
        # 过滤掉 nil 值
        dated_results = result.select(&:last_transaction_date)
        if dated_results.size >= 2
          expect(dated_results.first.last_transaction_date).to be >= dated_results.last.last_transaction_date
        end
      end
    end
  end

  # ==================== Constants ====================
  describe 'constants' do
    it 'defines ACCOUNT_TYPES' do
      expect(Account::ACCOUNT_TYPES).to include(
        'CASH' => '现金',
        'BANK' => '储蓄卡',
        'CREDIT' => '信用卡',
        'INVESTMENT' => '网络账户',
        'LOAN' => '贷款',
        'DEBT' => '欠款'
      )
    end
  end

  # ==================== Instance Methods ====================
  describe 'instance methods' do
    let(:account) { create(:account, initial_balance: 1000, currency: 'CNY') }

    describe '#current_balance' do
      it 'returns initial balance when no entries' do
        expect(account.current_balance).to eq(BigDecimal('1000'))
      end

      it 'adds positive entry amounts' do
        create(:entry, account: account, amount: 500)
        expect(account.current_balance).to eq(BigDecimal('1500'))
      end

      it 'subtracts negative entry amounts' do
        create(:entry, account: account, amount: -200)
        expect(account.current_balance).to eq(BigDecimal('800'))
      end

      it 'handles multiple entries' do
        create(:entry, account: account, amount: 500)
        create(:entry, account: account, amount: -200)
        create(:entry, account: account, amount: 100)
        expect(account.current_balance).to eq(BigDecimal('1400'))
      end
    end

    describe '#balance_series' do
      it 'returns balance series for specified months' do
        series = account.balance_series(3)
        expect(series.length).to eq(3)
        expect(series.first).to have_key(:date)
        expect(series.first).to have_key(:balance)
      end

      it 'defaults to 12 months' do
        series = account.balance_series
        expect(series.length).to eq(12)
      end
    end

    describe '#monthly_flow' do
      let!(:income_entry) { create(:entry, account: account, amount: 1000, date: Date.current.beginning_of_month) }
      let!(:expense_entry) { create(:entry, account: account, amount: -300, date: Date.current.beginning_of_month + 1.day) }

      it 'returns income and expense for the month' do
        month_str = Date.current.strftime('%Y-%m')
        flow = account.monthly_flow(month_str)

        expect(flow[:income]).to eq(1000)
        expect(flow[:expense]).to eq(300)
      end
    end

    describe '#cash_flow' do
      let!(:income_entry) { create(:entry, account: account, amount: 2000, date: 5.days.ago) }
      let!(:expense_entry) { create(:entry, account: account, amount: -500, date: 3.days.ago) }

      it 'returns income, expense, and net for the period' do
        flow = account.cash_flow(7.days.ago, Date.current)

        expect(flow[:income]).to eq(2000)
        expect(flow[:expense]).to eq(500)
        expect(flow[:net]).to eq(1500)
      end
    end

    describe '#currency_symbol' do
      it 'returns the currency symbol' do
        expect(account.currency_symbol).to be_present
      end
    end

    describe '#type_name' do
      it 'returns Chinese name for known types' do
        cash_account = create(:account, type: 'CASH', name: 'Cash Account')
        expect(cash_account.type_name).to eq('现金')
      end

      it 'returns type itself for unknown types' do
        custom_account = create(:account, type: 'CUSTOM', name: 'Custom Account')
        expect(custom_account.type_name).to eq('CUSTOM')
      end

      it 'returns "账户" when type is blank' do
        no_type_account = create(:account, type: nil, name: 'No Type Account')
        expect(no_type_account.type_name).to eq('账户')
      end
    end

    describe '#update_entries_cache!' do
      it 'updates transactions_count and last_transaction_date' do
        create(:entry, account: account, date: 5.days.ago)
        create(:entry, account: account, date: 2.days.ago)

        account.update_entries_cache!

        expect(account.transactions_count).to eq(2)
        expect(account.last_transaction_date).to eq(2.days.ago.to_date)
      end
    end

    describe '#credit_card?' do
      it 'returns true for CREDIT type with billing_day' do
        credit_account = create(:account, type: 'CREDIT', billing_day: 16, name: 'Credit Card')
        expect(credit_account.credit_card?).to be true
      end

      it 'returns false for non-CREDIT type' do
        cash_account = create(:account, type: 'CASH', name: 'Cash')
        expect(cash_account.credit_card?).to be false
      end

      it 'returns false for CREDIT without billing_day' do
        credit_no_billing = create(:account, type: 'CREDIT', billing_day: nil, name: 'Credit No Billing')
        expect(credit_no_billing.credit_card?).to be false
      end
    end

    describe '#bill_cycle_for' do
      let(:credit_card) do
        create(:account,
          type: 'CREDIT',
          billing_day: 16,
          billing_day_mode: 'current',
          name: 'Credit Card'
        )
      end

      it 'returns bill cycle hash for credit card' do
        cycle = credit_card.bill_cycle_for(Date.new(2026, 3, 15))

        expect(cycle).to have_key(:start_date)
        expect(cycle).to have_key(:end_date)
        expect(cycle).to have_key(:due_date)
        expect(cycle).to have_key(:label)
        expect(cycle).to have_key(:current)
      end

      it 'returns nil for non-credit card' do
        cash_account = create(:account, type: 'CASH', name: 'Cash')
        expect(cash_account.bill_cycle_for).to be_nil
      end

      it 'returns nil when billing_day is invalid' do
        invalid_card = create(:account, type: 'CREDIT', billing_day: 0, name: 'Invalid Card')
        expect(invalid_card.bill_cycle_for).to be_nil
      end

      context 'with billing_day_mode "current"' do
        it 'includes billing day in current cycle' do
          cycle = credit_card.bill_cycle_for(Date.new(2026, 3, 16))
          expect(cycle[:end_date]).to eq(Date.new(2026, 3, 16))
        end
      end

      context 'with billing_day_mode "next"' do
        let(:next_mode_card) do
          create(:account,
            type: 'CREDIT',
            billing_day: 16,
            billing_day_mode: 'next',
            name: 'Next Mode Card'
          )
        end

        it 'excludes billing day from current cycle' do
          cycle = next_mode_card.bill_cycle_for(Date.new(2026, 3, 15))
          expect(cycle[:end_date]).to eq(Date.new(2026, 3, 15))
        end
      end
    end

    describe '#bill_cycles' do
      let(:credit_card) do
        create(:account,
          type: 'CREDIT',
          billing_day: 16,
          billing_day_mode: 'current',
          name: 'Credit Card'
        )
      end

      it 'returns array of bill cycles' do
        cycles = credit_card.bill_cycles(3)
        expect(cycles).to be_an(Array)
        expect(cycles.length).to be >= 2
      end

      it 'returns empty array for non-credit card' do
        cash_account = create(:account, type: 'CASH', name: 'Cash')
        expect(cash_account.bill_cycles).to eq([])
      end
    end

    describe '#bill_cycle_summary' do
      let(:credit_card) { create(:account, type: 'CREDIT', billing_day: 16, name: 'Credit Card') }
      let!(:spend_entry) { create(:entry, account: credit_card, amount: -1000, date: Date.current) }
      let!(:repay_entry) { create(:entry, account: credit_card, amount: 500, date: Date.current) }

      it 'returns summary hash with spend and repay info' do
        summary = credit_card.bill_cycle_summary(
          start_date: 1.month.ago,
          end_date: Date.current
        )

        expect(summary).to have_key(:spend_amount)
        expect(summary).to have_key(:repay_amount)
        expect(summary).to have_key(:balance_due)
        expect(summary).to have_key(:spend_count)
        expect(summary).to have_key(:repay_count)
      end
    end
  end

  # ==================== Class Methods ====================
  describe 'class methods' do
    describe '.default_currency' do
      it 'returns a currency code' do
        expect(Account.default_currency).to be_a(String)
        expect(Account.default_currency.length).to eq(3)
      end
    end

    describe '.total_assets' do
      let!(:visible_included) { create(:account, initial_balance: 1000, hidden: false, include_in_total: true) }
      let!(:hidden_included) { create(:account, initial_balance: 500, hidden: true, include_in_total: true, name: 'Hidden') }
      let!(:visible_excluded) { create(:account, initial_balance: 300, hidden: false, include_in_total: false, name: 'Excluded') }

      it 'sums only visible and included accounts' do
        expect(Account.total_assets).to eq(BigDecimal('1000'))
      end

      it 'includes entry amounts in calculation' do
        create(:entry, account: visible_included, amount: 500)
        expect(Account.total_assets).to eq(BigDecimal('1500'))
      end
    end

    describe '.balance_by_type' do
      let!(:cash_account) { create(:account, type: 'CASH', initial_balance: 1000, hidden: false, include_in_total: true) }
      let!(:bank_account) { create(:account, type: 'BANK', initial_balance: 2000, hidden: false, include_in_total: true, name: 'Bank') }

      it 'returns hash with balance by type' do
        result = Account.balance_by_type

        expect(result).to be_a(Hash)
        expect(result['CASH']).to eq(BigDecimal('1000'))
        expect(result['BANK']).to eq(BigDecimal('2000'))
      end
    end
  end

  # ==================== Edge Cases ====================
  describe 'edge cases' do
    it 'handles zero initial balance' do
      account = create(:account, initial_balance: 0)
      expect(account.current_balance).to eq(BigDecimal('0'))
    end

    it 'handles nil initial balance' do
      account = create(:account, initial_balance: nil)
      expect(account.current_balance).to eq(BigDecimal('0'))
    end

    it 'handles negative balance' do
      account = create(:account, initial_balance: -500)
      create(:entry, account: account, amount: -200)
      expect(account.current_balance).to eq(BigDecimal('-700'))
    end
  end
end
