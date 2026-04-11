# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EntryCreationService, type: :service do
  let(:account) { create(:account) }
  let(:another_account) { create(:account, name: 'Another Account') }
  let(:category) { create(:category) }

  # ==================== .create_regular ====================
  describe '.create_regular' do
    context 'expense' do
      it 'creates an expense entry with negative amount' do
        entry = described_class.create_regular(
          type: 'EXPENSE', account_id: account.id,
          amount: 100, date: Date.current, note: '买咖啡', category_id: category.id
        )

        expect(entry).to be_persisted
        expect(entry.amount).to eq(-100)
        expect(entry.account).to eq(account)
        expect(entry.entryable.kind).to eq('expense')
        expect(entry.entryable.category).to eq(category)
      end

      it 'handles string amount' do
        entry = described_class.create_regular(
          type: 'EXPENSE', account_id: account.id,
          amount: '123.45', date: Date.current, note: '测试'
        )

        # 金额被解析为 BigDecimal
        expect(entry.amount).to eq(BigDecimal('123.45'))
      end

      it 'handles float amount' do
        entry = described_class.create_regular(
          type: 'EXPENSE', account_id: account.id,
          amount: 99.99, date: Date.current, note: '测试'
        )

        # 支出金额为负数
        expect(entry.amount).to be_within(0.01).of(-99.99)
      end
    end

    context 'income' do
      it 'creates an income entry with positive amount' do
        entry = described_class.create_regular(
          type: 'INCOME', account_id: account.id,
          amount: 5000, date: Date.current, note: '工资'
        )

        expect(entry).to be_persisted
        expect(entry.amount).to eq(5000)
        expect(entry.entryable.kind).to eq('income')
      end

      it 'creates entry without category' do
        entry = described_class.create_regular(
          type: 'INCOME', account_id: account.id,
          amount: 1000, date: Date.current, note: '红包'
        )

        expect(entry).to be_persisted
        expect(entry.entryable.category).to be_nil
      end
    end

    context 'with notes' do
      it 'creates entry with notes' do
        entry = described_class.create_regular(
          type: 'EXPENSE', account_id: account.id,
          amount: 100, date: Date.current, note: '详细备注'
        )

        expect(entry.notes).to eq('详细备注')
      end

      it 'creates entry without notes' do
        entry = described_class.create_regular(
          type: 'EXPENSE', account_id: account.id,
          amount: 100, date: Date.current
        )

        expect(entry.notes).to be_nil
      end

      it 'uses note as name when present' do
        entry = described_class.create_regular(
          type: 'EXPENSE', account_id: account.id,
          amount: 100, date: Date.current, note: '自定义名称'
        )

        expect(entry.name).to eq('自定义名称')
      end

      it 'generates default name when note is blank' do
        entry = described_class.create_regular(
          type: 'EXPENSE', account_id: account.id,
          amount: 100, date: Date.current
        )

        expect(entry.name).to include('支出')
        expect(entry.name).to include('100')
      end
    end

    context 'with currency' do
      it 'uses default CNY currency' do
        entry = described_class.create_regular(
          type: 'EXPENSE', account_id: account.id,
          amount: 100, date: Date.current
        )

        expect(entry.currency).to eq('CNY')
      end

      it 'uses custom currency' do
        entry = described_class.create_regular(
          type: 'EXPENSE', account_id: account.id,
          amount: 100, date: Date.current, currency: 'USD'
        )

        expect(entry.currency).to eq('USD')
      end
    end
  end

  # ==================== .create_transfer ====================
  describe '.create_transfer' do
    it 'creates a pair of transfer entries' do
      expect {
        described_class.create_transfer(
          from_account_id: account.id, to_account_id: another_account.id,
          amount: 1000, date: Date.current
        )
      }.to change(Entry, :count).by(2)

      out_entry = Entry.find_by(account: account, amount: -1000)
      in_entry = Entry.find_by(account: another_account, amount: 1000)

      expect(out_entry).to be_present
      expect(in_entry).to be_present
      expect(out_entry.transfer_id).to eq(in_entry.transfer_id)
    end

    it 'creates transfer with note' do
      described_class.create_transfer(
        from_account_id: account.id, to_account_id: another_account.id,
        amount: 500, date: Date.current, note: '转账备注'
      )

      out_entry = Entry.find_by(account: account)
      expect(out_entry.notes).to eq('转账备注')
    end

    it 'generates UUID transfer_id' do
      described_class.create_transfer(
        from_account_id: account.id, to_account_id: another_account.id,
        amount: 100, date: Date.current
      )

      entry = Entry.where.not(transfer_id: nil).last
      expect(entry.transfer_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end

    it 'sets transfer name with account names' do
      described_class.create_transfer(
        from_account_id: account.id, to_account_id: another_account.id,
        amount: 100, date: Date.current
      )

      out_entry = Entry.find_by(account: account)
      expect(out_entry.name).to include('转账')
      expect(out_entry.name).to include(account.name)
      expect(out_entry.name).to include(another_account.name)
    end

    it 'returns transfer_id' do
      transfer_id = described_class.create_transfer(
        from_account_id: account.id, to_account_id: another_account.id,
        amount: 100, date: Date.current
      )

      expect(transfer_id).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
    end
  end

  # ==================== .create_with_funding_transfer ====================
  describe '.create_with_funding_transfer' do
    let(:funding_account) { create(:account, name: '工商银行') }
    let(:destination_account) { create(:account, name: '信用卡') }

    it 'creates 3 entries: funding transfer + expense' do
      expect {
        described_class.create_with_funding_transfer(
          funding_account_id: funding_account.id,
          destination_account_id: destination_account.id,
          amount: 500, date: Date.current,
          category_id: category.id, note: '购物'
        )
      }.to change(Entry, :count).by(3)
    end

    it 'creates entries with correct amounts' do
      described_class.create_with_funding_transfer(
        funding_account_id: funding_account.id,
        destination_account_id: destination_account.id,
        amount: 1000, date: Date.current
      )

      # funding -> destination 转账（-1000, +1000）
      # destination 消费（-1000）
      funding_entry = Entry.where(account: funding_account).first
      expect(funding_entry.amount).to eq(-1000)
    end

    it 'links transfer entries with same transfer_id' do
      described_class.create_with_funding_transfer(
        funding_account_id: funding_account.id,
        destination_account_id: destination_account.id,
        amount: 100, date: Date.current
      )

      transfer_entries = Entry.where.not(transfer_id: nil)
      transfer_ids = transfer_entries.pluck(:transfer_id).uniq
      expect(transfer_ids.size).to eq(1)
    end

    it 'includes note in transfer note' do
      described_class.create_with_funding_transfer(
        funding_account_id: funding_account.id,
        destination_account_id: destination_account.id,
        amount: 100, date: Date.current, note: '特别备注'
      )

      transfer_entry = Entry.where(account: funding_account).first
      expect(transfer_entry.notes).to eq('特别备注')
    end

    it 'applies category to expense entry' do
      described_class.create_with_funding_transfer(
        funding_account_id: funding_account.id,
        destination_account_id: destination_account.id,
        amount: 100, date: Date.current, category_id: category.id
      )

      expense_entry = Entry.where(account: destination_account, amount: ...0).last
      expect(expense_entry.entryable.category).to eq(category)
    end
  end

  # ==================== .next_sort_order ====================
  describe '.next_sort_order' do
    it 'returns 1 for first entry on date' do
      sort_order = described_class.next_sort_order(account.id, Date.current)
      expect(sort_order).to eq(1)
    end

    it 'increments sort_order for existing entries' do
      create(:entry, account: account, date: Date.current, sort_order: 1)
      create(:entry, account: account, date: Date.current, sort_order: 2)

      sort_order = described_class.next_sort_order(account.id, Date.current)
      expect(sort_order).to eq(3)
    end

    it 'handles different dates independently' do
      create(:entry, account: account, date: Date.current, sort_order: 5)

      sort_order = described_class.next_sort_order(account.id, 1.day.ago)
      expect(sort_order).to eq(1)
    end
  end

  # ==================== Edge Cases ====================
  describe 'edge cases' do
    it 'handles zero amount' do
      entry = described_class.create_regular(
        type: 'EXPENSE', account_id: account.id,
        amount: 0, date: Date.current
      )

      expect(entry).to be_persisted
      expect(entry.amount).to eq(0)
    end

    it 'handles large amounts' do
      entry = described_class.create_regular(
        type: 'INCOME', account_id: account.id,
        amount: 999999999.99, date: Date.current
      )

      expect(entry).to be_persisted
      expect(entry.amount).to eq(999999999.99)
    end

    it 'handles future dates' do
      entry = described_class.create_regular(
        type: 'EXPENSE', account_id: account.id,
        amount: 100, date: 30.days.from_now
      )

      expect(entry).to be_persisted
    end

    it 'handles special characters in note' do
      entry = described_class.create_regular(
        type: 'EXPENSE', account_id: account.id,
        amount: 100, date: Date.current, note: '测试 & 特殊字符'
      )

      expect(entry.notes).to include('&')
    end
  end

  # ==================== Error Handling ====================
  describe 'error handling' do
    it 'raises error for invalid account' do
      expect {
        described_class.create_regular(
          type: 'EXPENSE', account_id: -1,
          amount: 100, date: Date.current
        )
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'raises error for missing required fields' do
      expect {
        described_class.create_regular(
          type: 'EXPENSE', account_id: account.id
          # missing amount and date
        )
      }.to raise_error(ArgumentError)
    end

    it 'raises error for invalid transfer accounts' do
      expect {
        described_class.create_transfer(
          from_account_id: 999999, to_account_id: another_account.id,
          amount: 100, date: Date.current
        )
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
