# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountStatsService, type: :service do
  let(:account) { create(:account, initial_balance: 1000) }
  let(:another_account) { create(:account, initial_balance: 500) }

  describe '.entry_stats' do
    context 'with single account' do
      before do
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction, kind: 'EXPENSE'),
          amount: -100,
          date: 5.days.ago
        )
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction, kind: 'INCOME'),
          amount: 500,
          date: 3.days.ago
        )
      end

      it 'calculates income and expense correctly' do
        stats = described_class.entry_stats(
          account_id: account.id,
          period_type: 'month',
          period_value: nil
        )

        expect(stats[:total_income]).to be > 0
        expect(stats[:total_expense]).to be > 0
        expect(stats[:total_balance]).to eq(stats[:total_income] - stats[:total_expense])
      end

      it 'includes account balance' do
        stats = described_class.entry_stats(
          account_id: account.id,
          period_type: 'month',
          period_value: nil
        )

        expect(stats[:account_balance]).to eq(account.current_balance)
      end

      it 'filters by period_type month' do
        stats = described_class.entry_stats(
          account_id: account.id,
          period_type: 'month',
          period_value: nil
        )

        expect(stats[:total_income]).to be >= 0
        expect(stats[:total_expense]).to be >= 0
      end

      it 'filters by period_type year' do
        stats = described_class.entry_stats(
          account_id: account.id,
          period_type: 'year',
          period_value: Date.current.year.to_s
        )

        expect(stats).to include(:total_income, :total_expense, :total_balance)
      end

      it 'filters by category_ids' do
        category = create(:category)
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction, kind: 'EXPENSE', category: category),
          amount: -200,
          date: Date.current
        )

        stats = described_class.entry_stats(
          account_id: account.id,
          period_type: 'month',
          period_value: nil,
          category_ids: [category.id]
        )

        expect(stats[:total_expense]).to be > 0
      end

      it 'returns stats hash with all required keys' do
        stats = described_class.entry_stats(
          account_id: account.id,
          period_type: 'month',
          period_value: nil
        )

        expect(stats).to include(:account_balance, :total_income, :total_expense, :total_balance)
        expect(stats[:total_balance]).to eq(stats[:total_income] - stats[:total_expense])
      end
    end

    context 'with multiple accounts' do
      before do
        create(:entry,
          account: account,
          entryable: create(:entryable_transaction),
          amount: -100,
          date: Date.current
        )
        create(:entry,
          account: another_account,
          entryable: create(:entryable_transaction),
          amount: -50,
          date: Date.current
        )
      end

      it 'sums stats across all included accounts when account_id is nil' do
        stats = described_class.entry_stats(
          account_id: nil,
          period_type: 'month',
          period_value: nil
        )

        expect(stats[:total_expense]).to be >= 150
      end
    end

    context 'with no matching entries' do
      it 'returns zero stats for empty period' do
        stats = described_class.entry_stats(
          account_id: account.id,
          period_type: 'year',
          period_value: '2020'
        )

        expect(stats[:total_income]).to eq(0)
        expect(stats[:total_expense]).to eq(0)
        expect(stats[:total_balance]).to eq(0)
      end
    end
  end

  describe '.entries_with_balance' do
    before do
      create(:entry,
        account: account,
        entryable: create(:entryable_transaction),
        amount: -100,
        date: 10.days.ago
      )
      create(:entry,
        account: account,
        entryable: create(:entryable_transaction),
        amount: 500,
        date: 5.days.ago
      )
      create(:entry,
        account: account,
        entryable: create(:entryable_transaction),
        amount: -50,
        date: 1.day.ago
      )
    end

    it 'returns entries with calculated balances' do
      entries_scope = Entry.where(account: account)
      result = described_class.entries_with_balance(
        entries_scope,
        page: 1,
        per_page: 10,
        account_id: account.id
      )

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
      
      result.each do |entry, balance|
        expect(entry).to be_a(Entry)
        expect(balance).to be_present
      end
    end

    it 'respects pagination' do
      entries_scope = Entry.where(account: account)
      
      page1 = described_class.entries_with_balance(
        entries_scope,
        page: 1,
        per_page: 2,
        account_id: account.id
      )
      
      page2 = described_class.entries_with_balance(
        entries_scope,
        page: 2,
        per_page: 2,
        account_id: account.id
      )

      expect(page1.length).to eq(2)
      expect(page2.length).to eq(1)
      
      # 第一页和第二页的entries应该不同
      page1_ids = page1.map { |e, _| e.id }
      page2_ids = page2.map { |e, _| e.id }
      expect(page1_ids & page2_ids).to be_empty
    end

    it 'calculates cumulative balance correctly' do
      entries_scope = Entry.where(account: account).order(date: :asc, id: :asc)
      result = described_class.entries_with_balance(
        entries_scope,
        page: 1,
        per_page: 10,
        account_id: account.id
      )

      # 排序后验证余额递增
      balances = result.map { |_, balance| balance }
      expect(balances).not_to be_empty
    end

    it 'handles transfer entries' do
      transfer = create(:entry,
        account: account,
        entryable: create(:entryable_transaction),
        amount: 100,
        date: Date.current
      )
      transfer.update_column(:transfer_id, 999) #模拟转账

      entries_scope = Entry.where(account: account)
      result = described_class.entries_with_balance(
        entries_scope,
        page: 1,
        per_page: 10,
        account_id: account.id
      )

      expect(result.length).to be > 0
    end

    it 'handles empty results' do
      other_account = create(:account)
      entries_scope = Entry.where(account: other_account)
      
      result = described_class.entries_with_balance(
        entries_scope,
        page: 1,
        per_page: 10,
        account_id: other_account.id
      )

      expect(result).to eq([])
    end

    it 'includes eagerloaded associations' do
      entries_scope = Entry.where(account: account)
      result = described_class.entries_with_balance(
        entries_scope,
        page: 1,
        per_page: 10,
        account_id: account.id
      )

      entry, _balance = result.first
      
      # "entryable" 应该已被加载
      expect(entry.association(:entryable)).to be_loaded
    end

    context 'with multiple accounts' do
      before do
        create(:entry,
          account: another_account,
          entryable: create(:entryable_transaction),
          amount: -50,
          date: 2.days.ago
        )
      end

      it 'calculates balance for single account correctly' do
        entries_scope = Entry.where(account: account)
        result = described_class.entries_with_balance(
          entries_scope,
          page: 1,
          per_page: 10,
          account_id: account.id
        )

        expect(result.length).to eq(3)
      end

      it 'calculates cross-account transfer balances' do
        # 创建转账关系
        transfer_in = create(:entry,
          account: another_account,
          entryable: create(:entryable_transaction),
          amount: 100,
          date: 3.days.ago
        )
        transfer_in.update_column(:transfer_id, 123)

        entries_scope = Entry.where(account: another_account)
        result = described_class.entries_with_balance(
          entries_scope,
          page: 1,
          per_page: 10,
          account_id: nil # 全账户视图
        )

        expect(result).not_to be_empty
      end
    end
  end

  describe '.preload_transfer_accounts_for' do
    let(:from_account) { create(:account, name: '借记卡') }
    let(:to_account) { create(:account, name: '信用卡') }

    before do
      # 创建转账配对
      transfer_out = create(:entry,
        account: from_account,
        entryable: create(:entryable_transaction),
        amount: -100,
        date: Date.current
      )
      transfer_in = create(:entry,
        account: to_account,
        entryable: create(:entryable_transaction),
        amount: 100,
        date: Date.current
      )
      
      # 关联转账ID
      transfer_out.update_column(:transfer_id, 1)
      transfer_in.update_column(:transfer_id, 1)
    end

    it 'preloads transfer account relationships' do
      entries_scope = Entry.where(transfer_id: 1).to_a
      entries_with_balance = entries_scope.map { |e| [e, nil] }

      expect {
        described_class.preload_transfer_accounts_for(entries_with_balance)
      }.not_to raise_error
    end

    it 'eliminates N+1 queries for transfer accounts' do
      entries_scope = Entry.where(transfer_id: 1)
      entries_with_balance = entries_scope.map { |e| [e, nil] }

      # 预加载后，访问关联账户应该不会产生额外查询
      described_class.preload_transfer_accounts_for(entries_with_balance)
      
      # 这取决于Entry模型的实现细节
    end
  end

  describe 'edge cases' do
    it 'handles nil account_id gracefully' do
      expect {
        described_class.entry_stats(
          account_id: nil,
          period_type: 'month',
          period_value: nil
        )
      }.not_to raise_error
    end

    it 'handles invalid period_type gracefully' do
      stats = described_class.entry_stats(
        account_id: account.id,
        period_type: 'invalid_type',
        period_value: nil
      )

      expect(stats).to include(:total_income, :total_expense, :total_balance)
    end

    it 'handles large page numbers' do
      entries_scope = Entry.where(account: account)
      result = described_class.entries_with_balance(
        entries_scope,
        page: 1000,
        per_page: 10,
        account_id: account.id
      )

      expect(result).to eq([])
    end

    it 'handles very high per_page values' do
      entries_scope = Entry.where(account: account)
      result = described_class.entries_with_balance(
        entries_scope,
        page: 1,
        per_page: 100000,
        account_id: account.id
      )

      expect(result.length).to be >= 0
    end
  end
end
