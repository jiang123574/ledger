# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EntryCreationService, type: :service do
  describe '.create_regular' do
    let(:account) { create(:account) }
    let(:category) { create(:category) }

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
    end
  end

  describe '.create_transfer' do
    let(:from_account) { create(:account, name: '招商银行') }
    let(:to_account) { create(:account, name: '支付宝') }

    it 'creates a pair of transfer entries' do
      expect {
        described_class.create_transfer(
          from_account_id: from_account.id, to_account_id: to_account.id,
          amount: 1000, date: Date.current
        )
      }.to change(Entry, :count).by(2)

      out_entry = Entry.find_by(account: from_account, amount: -1000)
      in_entry = Entry.find_by(account: to_account, amount: 1000)

      expect(out_entry).to be_present
      expect(in_entry).to be_present
      expect(out_entry.transfer_id).to eq(in_entry.transfer_id)
    end
  end

  describe '.create_with_funding_transfer' do
    let(:funding_account) { create(:account, name: '工商银行') }
    let(:destination_account) { create(:account, name: '信用卡') }
    let(:category) { create(:category) }

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
  end
end
