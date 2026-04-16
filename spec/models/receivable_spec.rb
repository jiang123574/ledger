# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Receivable, type: :model do
  # ==================== Associations ====================
  describe 'associations' do
    it { is_expected.to belong_to(:counterparty).optional }
    it { is_expected.to belong_to(:account).optional }
  end

  # ==================== Validations ====================
  describe 'validations' do
    subject { build(:receivable) }

    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:original_amount) }
    it { is_expected.to validate_numericality_of(:original_amount).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:remaining_amount).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:date) }

    describe 'transfer_id format' do
      it 'allows nil transfer_id' do
        receivable = build(:receivable, transfer_id: nil)
        expect(receivable).to be_valid
      end

      it 'allows valid UUID format' do
        receivable = build(:receivable, transfer_id: SecureRandom.uuid)
        expect(receivable).to be_valid
      end

      it 'rejects invalid format' do
        receivable = build(:receivable, transfer_id: 'invalid-id')
        expect(receivable).not_to be_valid
        expect(receivable.errors[:transfer_id]).to be_present
      end

      it 'rejects integer format' do
        receivable = build(:receivable, transfer_id: '12345')
        expect(receivable).not_to be_valid
      end
    end
  end

  # ==================== Scopes ====================
  describe 'scopes' do
    let!(:settled_receivable) { create(:receivable, settled_at: Time.current, remaining_amount: 0) }
    let!(:unsettled_receivable) { create(:receivable, settled_at: nil, remaining_amount: 100) }
    let!(:partially_settled) { create(:receivable, settled_at: nil, remaining_amount: 50, description: 'Partial') }
    let!(:old_receivable) { create(:receivable, date: 30.days.ago, description: 'Old') }
    let!(:new_receivable) { create(:receivable, date: 1.day.ago, description: 'New') }

    describe '.unsettled' do
      it 'returns receivables without settled_at and remaining_amount > 0' do
        result = Receivable.unsettled
        expect(result).to include(unsettled_receivable)
        expect(result).to include(partially_settled)
        expect(result).not_to include(settled_receivable)
      end
    end

    describe '.settled' do
      it 'returns receivables with settled_at' do
        result = Receivable.settled
        expect(result).to include(settled_receivable)
        expect(result).not_to include(unsettled_receivable)
      end
    end

    describe '.recent' do
      it 'orders by date descending' do
        result = Receivable.recent
        expect(result.first.date).to be >= result.last.date
      end
    end

    describe '.by_category' do
      let!(:travel_receivable) { create(:receivable, category: '差旅', description: 'Travel') }
      let!(:food_receivable) { create(:receivable, category: '餐饮', description: 'Food') }

      it 'filters by category when provided' do
        expect(Receivable.by_category('差旅')).to include(travel_receivable)
        expect(Receivable.by_category('差旅')).not_to include(food_receivable)
      end

      it 'returns all when category is blank' do
        expect(Receivable.by_category(nil).count).to eq(Receivable.count)
        expect(Receivable.by_category('').count).to eq(Receivable.count)
      end
    end
  end

  # ==================== Constants ====================
  describe 'constants' do
    it 'defines CATEGORIES' do
      expect(Receivable::CATEGORIES).to eq(%w[差旅 餐饮 交通 办公用品 其他])
    end
  end

  # ==================== Instance Methods ====================
  describe 'instance methods' do
    describe '#reimbursement_transfer_ids' do
      it 'returns empty array when nil' do
        receivable = build(:receivable, reimbursement_transfer_ids: nil)
        expect(receivable.reimbursement_transfer_ids).to eq([])
      end

      it 'returns array when present' do
        ids = [ SecureRandom.uuid, SecureRandom.uuid ]
        receivable = build(:receivable, reimbursement_transfer_ids: ids)
        expect(receivable.reimbursement_transfer_ids).to eq(ids)
      end
    end

    describe '#settled?' do
      it 'returns true when settled_at is present' do
        receivable = build(:receivable, settled_at: Time.current)
        expect(receivable.settled?).to be true
      end

      it 'returns true when remaining_amount is 0' do
        receivable = build(:receivable, settled_at: nil, remaining_amount: 0)
        expect(receivable.settled?).to be true
      end

      it 'returns false when settled_at is nil and remaining_amount > 0' do
        receivable = build(:receivable, settled_at: nil, remaining_amount: 100)
        expect(receivable.settled?).to be false
      end

      it 'handles nil remaining_amount' do
        receivable = build(:receivable, settled_at: nil, remaining_amount: nil)
        expect(receivable.settled?).to be true
      end
    end

    describe '#progress_percentage' do
      it 'returns 0 when original_amount is 0' do
        receivable = build(:receivable, original_amount: 0, remaining_amount: 0)
        expect(receivable.progress_percentage).to eq(0)
      end

      it 'returns 0 when nothing is settled' do
        receivable = build(:receivable, original_amount: 1000, remaining_amount: 1000)
        expect(receivable.progress_percentage).to eq(0)
      end

      it 'returns 100 when fully settled' do
        receivable = build(:receivable, original_amount: 1000, remaining_amount: 0)
        expect(receivable.progress_percentage).to eq(100)
      end

      it 'returns correct percentage for partial settlement' do
        receivable = build(:receivable, original_amount: 1000, remaining_amount: 250)
        expect(receivable.progress_percentage).to eq(75)
      end

      it 'handles nil values' do
        receivable = build(:receivable, original_amount: nil, remaining_amount: nil)
        expect(receivable.progress_percentage).to eq(0)
      end
    end

    describe '#status' do
      it 'returns "已完成" when settled' do
        receivable = build(:receivable, settled_at: Time.current, original_amount: 1000, remaining_amount: 0)
        expect(receivable.status).to eq('已完成')
      end

      it 'returns "部分报销" when partially settled' do
        receivable = build(:receivable, settled_at: nil, original_amount: 1000, remaining_amount: 500)
        expect(receivable.status).to eq('部分报销')
      end

      it 'returns "待报销" when not started' do
        receivable = build(:receivable, settled_at: nil, original_amount: 1000, remaining_amount: 1000)
        expect(receivable.status).to eq('待报销')
      end
    end

    describe '#status_color' do
      it 'returns "green" for completed' do
        receivable = build(:receivable, settled_at: Time.current)
        expect(receivable.status_color).to eq('green')
      end

      it 'returns "orange" for partial' do
        receivable = build(:receivable, settled_at: nil, original_amount: 1000, remaining_amount: 500)
        expect(receivable.status_color).to eq('orange')
      end

      it 'returns "gray" for pending' do
        receivable = build(:receivable, settled_at: nil, original_amount: 1000, remaining_amount: 1000)
        expect(receivable.status_color).to eq('gray')
      end
    end
  end

  # ==================== Callbacks ====================
  describe 'callbacks' do
    describe 'after_commit :sync_system_accounts' do
      it 'calls SystemAccountSyncService.sync_all! after commit' do
        expect(SystemAccountSyncService).to receive(:sync_all!)
        create(:receivable)
      end
    end
  end

  # ==================== Edge Cases ====================
  describe 'edge cases' do
    it 'handles very large amounts' do
      receivable = build(:receivable, original_amount: 999999999.99)
      expect(receivable).to be_valid
    end

    it 'handles decimal amounts' do
      receivable = build(:receivable, original_amount: 123.45, remaining_amount: 67.89)
      expect(receivable).to be_valid
    end

    it 'handles future dates' do
      receivable = build(:receivable, date: 30.days.from_now)
      expect(receivable).to be_valid
    end
  end
end
