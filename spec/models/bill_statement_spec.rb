require 'rails_helper'

RSpec.describe BillStatement do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
  end

  describe 'validations' do
    subject { build(:bill_statement) }

    it { is_expected.to validate_presence_of(:billing_date) }
    it { is_expected.to validate_presence_of(:statement_amount) }
    it { is_expected.to validate_numericality_of(:statement_amount).is_greater_than(0) }
    it { is_expected.to validate_uniqueness_of(:billing_date).scoped_to(:account_id) }
  end

  describe 'creation' do
    let(:account) { create(:account, :credit_card) }

    it 'creates a valid bill statement' do
      statement = BillStatement.create!(
        account: account,
        billing_date: Date.current,
        statement_amount: 1000.50
      )
      expect(statement).to be_persisted
      expect(statement.statement_amount).to eq 1000.50
    end

    it 'requires statement_amount to be positive' do
      statement = build(:bill_statement, statement_amount: 0)
      expect(statement).not_to be_valid
      expect(statement.errors[:statement_amount]).to be_present
    end

    it 'prevents duplicate billing_date for same account' do
      create(:bill_statement, account: account, billing_date: Date.current)
      duplicate = build(:bill_statement, account: account, billing_date: Date.current)
      expect(duplicate).not_to be_valid
    end
  end

  describe 'different accounts can have same billing_date' do
    let(:account1) { create(:account, :credit_card) }
    let(:account2) { create(:account, :credit_card) }

    it 'allows same billing_date for different accounts' do
      statement1 = create(:bill_statement, account: account1, billing_date: Date.current)
      statement2 = build(:bill_statement, account: account2, billing_date: Date.current)
      expect(statement2).to be_valid
    end
  end
end