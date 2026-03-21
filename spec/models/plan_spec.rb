require 'rails_helper'

RSpec.describe Plan, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:account) { create(:account, name: 'Test Account', type: 'CASH') }

  describe 'constants' do
    it 'defines plan types' do
      expect(Plan::INSTALLMENT).to eq('INSTALLMENT')
      expect(Plan::RECURRING).to eq('RECURRING')
      expect(Plan::ONE_TIME).to eq('ONE_TIME')
    end
  end

  describe 'validations' do
    it 'requires name' do
      plan = build(:plan, name: nil)
      expect(plan).not_to be_valid
      expect(plan.errors[:name]).to be_present
    end

    it 'requires amount' do
      plan = build(:plan, amount: nil)
      expect(plan).not_to be_valid
    end

    it 'validates day_of_month range' do
      plan = build(:plan, day_of_month: 0)
      expect(plan).not_to be_valid

      plan = build(:plan, day_of_month: 32)
      expect(plan).not_to be_valid

      plan = build(:plan, day_of_month: 15)
      expect(plan).to be_valid
    end

    it 'validates plan type' do
      plan = build(:plan, type: 'INVALID')
      expect(plan).not_to be_valid
    end

    context 'for installment plans' do
      it 'requires total_amount' do
        plan = build(:plan, type: Plan::INSTALLMENT, total_amount: nil, installments_total: 12)
        expect(plan).not_to be_valid
      end

      it 'requires installments_total > 0' do
        plan = build(:plan, type: Plan::INSTALLMENT, total_amount: 1200, installments_total: 0)
        expect(plan).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      @active_plan = create(:plan, name: 'Active Plan', active: true)
      @inactive_plan = create(:plan, name: 'Inactive Plan', active: false)
      @installment_plan = create(:plan, type: Plan::INSTALLMENT, total_amount: 1200, installments_total: 12)
    end

    it 'returns active plans' do
      expect(Plan.active).to include(@active_plan)
      expect(Plan.active).not_to include(@inactive_plan)
    end

    it 'returns installment plans' do
      expect(Plan.installment).to include(@installment_plan)
    end
  end

  describe '#installments_remaining' do
    it 'returns remaining installments' do
      plan = build(:plan, type: Plan::INSTALLMENT, installments_total: 12, installments_completed: 3)
      expect(plan.installments_remaining).to eq(9)
    end

    it 'returns 0 for non-installment plans' do
      plan = build(:plan, type: Plan::ONE_TIME)
      expect(plan.installments_remaining).to eq(0)
    end
  end

  describe '#progress_percentage' do
    it 'calculates progress percentage' do
      plan = build(:plan, type: Plan::INSTALLMENT, installments_total: 12, installments_completed: 3)
      expect(plan.progress_percentage).to eq(25.0)
    end

    it 'returns 100 for completed plans' do
      plan = build(:plan, type: Plan::INSTALLMENT, installments_total: 12, installments_completed: 12)
      expect(plan.progress_percentage).to eq(100)
    end
  end

  describe '#completed?' do
    it 'returns true when all installments are done' do
      plan = build(:plan, type: Plan::INSTALLMENT, installments_total: 12, installments_completed: 12)
      expect(plan).to be_completed
    end

    it 'returns false when not all installments are done' do
      plan = build(:plan, type: Plan::INSTALLMENT, installments_total: 12, installments_completed: 6)
      expect(plan).not_to be_completed
    end
  end

  describe '#next_due_date' do
    it 'calculates next due date correctly' do
      plan = build(:plan, day_of_month: 15, active: true)

      travel_to Date.new(2024, 1, 10) do
        expect(plan.next_due_date).to eq(Date.new(2024, 1, 15))
      end
    end

    it 'rolls over to next month when day has passed' do
      plan = build(:plan, day_of_month: 15, active: true)

      travel_to Date.new(2024, 1, 20) do
        expect(plan.next_due_date).to eq(Date.new(2024, 2, 15))
      end
    end

    it 'returns nil for inactive plans' do
      plan = build(:plan, active: false)
      expect(plan.next_due_date).to be_nil
    end
  end

  describe '#generate_transaction!' do
    let!(:plan) { create(:plan, name: 'Test Plan', amount: 100, account: account, active: true) }

    it 'creates a transaction' do
      expect { plan.generate_transaction! }.to change(Transaction, :count).by(1)
    end

    it 'returns the transaction' do
      transaction = plan.generate_transaction!
      expect(transaction).to be_a(Transaction)
      expect(transaction.amount).to eq(100)
    end

    it 'uses default category' do
      transaction = plan.generate_transaction!
      expect(transaction.category.name).to eq(I18n.t('plans.default_category'))
    end

    it 'updates last_generated timestamp' do
      plan.generate_transaction!
      expect(plan.reload.last_generated).to be_present
    end

    it 'returns nil without account' do
      plan.update!(account: nil)
      expect(plan.generate_transaction!).to be_nil
    end

    context 'for installment plans' do
      let!(:installment_plan) do
        create(:plan,
          name: 'Installment Plan',
          type: Plan::INSTALLMENT,
          amount: 100,
          total_amount: 1200,
          installments_total: 12,
          installments_completed: 0,
          account: account,
          active: true
        )
      end

      it 'increments installments_completed' do
        installment_plan.generate_transaction!
        expect(installment_plan.reload.installments_completed).to eq(1)
      end

      it 'deactivates plan when completed' do
        installment_plan.update!(installments_completed: 11)
        installment_plan.generate_transaction!
        expect(installment_plan.reload.active?).to be false
      end

      it 'wraps in a transaction' do
        # Test that if something fails, the whole operation is rolled back
        allow(Transaction).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

        expect {
          installment_plan.generate_transaction!
        }.to raise_error(ActiveRecord::RecordInvalid)

        expect(installment_plan.reload.installments_completed).to eq(0)
      end
    end
  end

  describe '.generate_all_due!' do
    before do
      today = Date.current
      @due_plan = create(:plan, name: 'Due Plan', account: account, active: true, day_of_month: today.day)
      @not_due_plan = create(:plan, name: 'Not Due Plan', account: account, active: true, day_of_month: today.day == 31 ? 1 : today.day + 1)
    end

    it 'generates transactions for due plans' do
      expect { Plan.generate_all_due! }.to change(Transaction, :count).by(1)
    end
  end
end