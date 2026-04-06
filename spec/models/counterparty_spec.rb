require 'rails_helper'

RSpec.describe Counterparty, type: :model do
  describe 'validations' do
    it 'requires name' do
      counterparty = build(:counterparty, name: nil)
      expect(counterparty).not_to be_valid
      expect(counterparty.errors[:name]).to be_present
    end

    it 'requires unique name' do
      create(:counterparty, name: 'Test Counterparty')
      duplicate = build(:counterparty, name: 'Test Counterparty')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end
  end

  describe 'scopes' do
    it '.ordered orders by name' do
      c1 = create(:counterparty, name: 'Zebra')
      c2 = create(:counterparty, name: 'Alpha')

      expect(Counterparty.ordered).to eq([ c2, c1 ].sort_by(&:name))
    end
  end

  describe '#receivables' do
    let(:counterparty) { create(:counterparty, name: 'Test Company') }

    it 'returns receivables with matching counterparty name' do
      receivable = create(:receivable)
      receivable.update!(counterparty: counterparty)

      expect(counterparty.receivables).to include(receivable)
    end
  end

  describe '#total_receivable_amount' do
    let(:counterparty) { create(:counterparty, name: 'Test Company') }

    it 'returns 0 when no receivables' do
      expect(counterparty.total_receivable_amount).to eq(0)
    end

    it 'sums all receivable amounts' do
      r1 = create(:receivable, original_amount: 1000)
      r1.update!(counterparty: counterparty)
      r2 = create(:receivable, original_amount: 500)
      r2.update!(counterparty: counterparty)

      expect(counterparty.total_receivable_amount).to eq(1500)
    end
  end

  describe '#pending_receivable_amount' do
    let(:counterparty) { create(:counterparty, name: 'Test Company') }

    it 'returns 0 when no pending receivables' do
      r = create(:receivable, original_amount: 1000, remaining_amount: 0)
      r.update!(counterparty: counterparty, settled_at: Time.current)
      expect(counterparty.pending_receivable_amount).to eq(0)
    end

    it 'sums only pending receivables' do
      r1 = create(:receivable, original_amount: 1000, remaining_amount: 1000)
      r1.update!(counterparty: counterparty)
      r2 = create(:receivable, original_amount: 500, remaining_amount: 0)
      r2.update!(counterparty: counterparty, settled_at: Time.current)

      expect(counterparty.pending_receivable_amount).to eq(1000)
    end
  end

  describe '#settled_receivable_amount' do
    let(:counterparty) { create(:counterparty, name: 'Test Company') }

    it 'returns 0 when no settled receivables' do
      r = create(:receivable, original_amount: 1000, remaining_amount: 1000)
      r.update!(counterparty: counterparty)
      expect(counterparty.settled_receivable_amount).to eq(0)
    end

    it 'sums only settled receivables' do
      r1 = create(:receivable, original_amount: 1000, remaining_amount: 1000)
      r1.update!(counterparty: counterparty)
      r2 = create(:receivable, original_amount: 500, remaining_amount: 0)
      r2.update!(counterparty: counterparty, settled_at: Time.current)

      expect(counterparty.settled_receivable_amount).to eq(500)
    end
  end

  describe '#receivables_count' do
    let(:counterparty) { create(:counterparty, name: 'Test Company') }

    it 'returns count of receivables' do
      r1 = create(:receivable)
      r1.update!(counterparty: counterparty)
      r2 = create(:receivable)
      r2.update!(counterparty: counterparty)

      expect(counterparty.receivables_count).to eq(2)
    end
  end
end
