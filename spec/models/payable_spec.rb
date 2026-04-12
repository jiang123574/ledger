# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payable, type: :model do
  # ==================== Associations ====================
  describe 'associations' do
    it { is_expected.to belong_to(:source_entry).class_name('Entry').optional }
    it { is_expected.to belong_to(:counterparty).optional }
    it { is_expected.to belong_to(:account).optional }
  end

  # ==================== Validations ====================
  describe 'validations' do
    subject { build(:payable) }

    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:original_amount) }
    it { is_expected.to validate_numericality_of(:original_amount).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:remaining_amount).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:date) }
  end

  # ==================== Scopes ====================
  describe 'scopes' do
    let!(:settled_payable) { create(:payable, settled_at: Time.current, remaining_amount: 0) }
    let!(:unsettled_payable) { create(:payable, settled_at: nil, remaining_amount: 100) }
    let!(:partially_settled) { create(:payable, settled_at: nil, remaining_amount: 50, description: 'Partial') }
    let!(:old_payable) { create(:payable, date: 30.days.ago, description: 'Old') }
    let!(:new_payable) { create(:payable, date: 1.day.ago, description: 'New') }

    describe '.unsettled' do
      it 'returns payables without settled_at and remaining_amount > 0' do
        result = Payable.unsettled
        expect(result).to include(unsettled_payable)
        expect(result).to include(partially_settled)
        expect(result).not_to include(settled_payable)
      end
    end

    describe '.settled' do
      it 'returns payables with settled_at' do
        result = Payable.settled
        expect(result).to include(settled_payable)
        expect(result).not_to include(unsettled_payable)
      end
    end

    describe '.recent' do
      it 'orders by date descending' do
        result = Payable.recent
        expect(result.first.date).to be >= result.last.date
      end
    end

    describe '.by_category' do
      let!(:rent_payable) { create(:payable, category: '房租', description: 'Rent') }
      let!(:utility_payable) { create(:payable, category: '水电', description: 'Utility') }

      it 'filters by category when provided' do
        expect(Payable.by_category('房租')).to include(rent_payable)
        expect(Payable.by_category('房租')).not_to include(utility_payable)
      end

      it 'returns all when category is blank' do
        expect(Payable.by_category(nil).count).to eq(Payable.count)
        expect(Payable.by_category('').count).to eq(Payable.count)
      end
    end
  end

  # ==================== Constants ====================
  describe 'constants' do
    it 'defines CATEGORIES' do
      expect(Payable::CATEGORIES).to eq(%w[日常支出 房租 水电 网费 保险 医疗 教育 税费 其他])
    end
  end

  # ==================== Instance Methods ====================
  describe 'instance methods' do
    let(:account) { create(:account) }
    let(:entry) { create(:entry, account: account, amount: 1000, date: Date.current) }

    describe '#source_amount' do
      it 'returns source_entry amount when present' do
        payable = build(:payable, source_entry: entry, original_amount: 500)
        expect(payable.source_amount).to eq(entry.amount)
      end

      it 'returns original_amount when source_entry is nil' do
        payable = build(:payable, source_entry: nil, original_amount: 500)
        expect(payable.source_amount).to eq(500)
      end
    end

    describe '#source_date' do
      it 'returns source_entry date when present' do
        payable = build(:payable, source_entry: entry, date: 1.month.ago)
        expect(payable.source_date).to eq(entry.date)
      end

      it 'returns date when source_entry is nil' do
        payable = build(:payable, source_entry: nil, date: 1.month.ago)
        expect(payable.source_date).to eq(1.month.ago.to_date)
      end
    end

    describe '#settled?' do
      it 'returns true when settled_at is present' do
        payable = build(:payable, settled_at: Time.current)
        expect(payable.settled?).to be true
      end

      it 'returns true when remaining_amount is 0' do
        payable = build(:payable, settled_at: nil, remaining_amount: 0)
        expect(payable.settled?).to be true
      end

      it 'returns false when settled_at is nil and remaining_amount > 0' do
        payable = build(:payable, settled_at: nil, remaining_amount: 100)
        expect(payable.settled?).to be false
      end

      it 'handles nil remaining_amount' do
        payable = build(:payable, settled_at: nil, remaining_amount: nil)
        expect(payable.settled?).to be true
      end
    end

    describe '#progress_percentage' do
      it 'returns 0 when original_amount is 0' do
        payable = build(:payable, original_amount: 0, remaining_amount: 0)
        expect(payable.progress_percentage).to eq(0)
      end

      it 'returns 0 when nothing is paid' do
        payable = build(:payable, original_amount: 1000, remaining_amount: 1000)
        expect(payable.progress_percentage).to eq(0)
      end

      it 'returns 100 when fully paid' do
        payable = build(:payable, original_amount: 1000, remaining_amount: 0)
        expect(payable.progress_percentage).to eq(100)
      end

      it 'returns correct percentage for partial payment' do
        payable = build(:payable, original_amount: 1000, remaining_amount: 250)
        expect(payable.progress_percentage).to eq(75)
      end

      it 'handles nil values' do
        payable = build(:payable, original_amount: nil, remaining_amount: nil)
        expect(payable.progress_percentage).to eq(0)
      end
    end

    describe '#status' do
      it 'returns "已完成" when settled' do
        payable = build(:payable, settled_at: Time.current, original_amount: 1000, remaining_amount: 0)
        expect(payable.status).to eq('已完成')
      end

      it 'returns "部分付款" when partially paid' do
        payable = build(:payable, settled_at: nil, original_amount: 1000, remaining_amount: 500)
        expect(payable.status).to eq('部分付款')
      end

      it 'returns "待付款" when not started' do
        payable = build(:payable, settled_at: nil, original_amount: 1000, remaining_amount: 1000)
        expect(payable.status).to eq('待付款')
      end
    end

    describe '#status_color' do
      it 'returns "green" for completed' do
        payable = build(:payable, settled_at: Time.current)
        expect(payable.status_color).to eq('green')
      end

      it 'returns "orange" for partial' do
        payable = build(:payable, settled_at: nil, original_amount: 1000, remaining_amount: 500)
        expect(payable.status_color).to eq('orange')
      end

      it 'returns "gray" for pending' do
        payable = build(:payable, settled_at: nil, original_amount: 1000, remaining_amount: 1000)
        expect(payable.status_color).to eq('gray')
      end
    end
  end

  # ==================== Callbacks ====================
  describe 'callbacks' do
    describe 'after_commit :sync_system_accounts' do
      it 'calls SystemAccountSyncService.sync_all! after commit' do
        expect(SystemAccountSyncService).to receive(:sync_all!)
        create(:payable)
      end
    end
  end

  # ==================== Edge Cases ====================
  describe 'edge cases' do
    it 'handles very large amounts' do
      payable = build(:payable, original_amount: 999999999.99)
      expect(payable).to be_valid
    end

    it 'handles decimal amounts' do
      payable = build(:payable, original_amount: 123.45, remaining_amount: 67.89)
      expect(payable).to be_valid
    end

    it 'handles future dates' do
      payable = build(:payable, date: 30.days.from_now)
      expect(payable).to be_valid
    end
  end
end
