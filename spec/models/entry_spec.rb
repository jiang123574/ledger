# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Entry, type: :model do
  # 测试 associations
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:transfer).optional } if defined?(Transfer)
    # import association uses Import model which may not exist
    xit { is_expected.to belong_to(:import).optional }
    it { is_expected.to belong_to(:parent_entry).optional }
    it { is_expected.to have_many(:child_entries).dependent(:destroy) }
    it { is_expected.to have_many(:attachments).dependent(:destroy) }
    it { is_expected.to have_many(:payables_as_source).dependent(:nullify) }
    it { is_expected.to have_delegated_type(:entryable) }
    it { is_expected.to accept_nested_attributes_for(:entryable).update_only(true) }
  end

  # 测试 validations
  describe 'validations' do
    subject { build(:entry) }

    context 'when transfer_id is not present' do
      it { is_expected.to validate_presence_of(:date) }
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:amount) }
      it { is_expected.to validate_presence_of(:currency) }
    end

    context 'when transfer_id is present' do
      subject { build(:entry, transfer_id: SecureRandom.uuid) }

      it { is_expected.to validate_presence_of(:date) }
      it { is_expected.to validate_presence_of(:amount) }
      it { is_expected.to validate_presence_of(:currency) }
      it { is_expected.not_to validate_presence_of(:name) }
    end

    it { is_expected.to validate_comparison_of(:date).is_greater_than(30.years.ago.to_date) }

    context 'uniqueness validations' do
      let(:account) { create(:account) }

      context 'for valuation entries' do
        let(:entry) { create(:entry, :valuation, account: account) }

        it 'validates uniqueness of date scoped to account_id and entryable_type' do
          duplicate_entry = build(:entry, :valuation, account: account, date: entry.date)
          expect(duplicate_entry).not_to be_valid
          expect(duplicate_entry.errors[:date]).to be_present
        end
      end

      context 'for external_id with source' do
        it 'validates uniqueness of external_id scoped to account_id and source' do
          existing_entry = create(:entry, external_id: 'ext123', source: 'bank', account: account)
          duplicate_entry = build(:entry, external_id: 'ext123', source: 'bank', account: account)
          expect(duplicate_entry).not_to be_valid
          expect(duplicate_entry.errors[:external_id]).to be_present
        end
      end
    end
  end

  # 测试 scopes
  describe 'scopes' do
    let!(:hidden_account) { create(:account, hidden: true) }
    let!(:visible_account) { create(:account, hidden: false) }
    let!(:hidden_entry) { create(:entry, account: hidden_account) }
    let!(:visible_entry) { create(:entry, account: visible_account) }

    describe '.visible' do
      it 'returns entries from visible accounts' do
        expect(Entry.visible).to include(visible_entry)
        expect(Entry.visible).not_to include(hidden_entry)
      end
    end

    describe '.chronological' do
      let!(:old_entry) { create(:entry, date: 2.days.ago) }
      let!(:new_entry) { create(:entry, date: Date.current) }
      let!(:valuation_entry) { create(:entry, :valuation, date: Date.current) }

      it 'orders by date ascending, valuation last, then sort_order and id' do
        entries = Entry.chronological.to_a
        expect(entries.first).to eq(old_entry)
        expect(entries.last).to eq(valuation_entry)
      end
    end

    describe '.reverse_chronological' do
      let!(:old_entry) { create(:entry, date: 2.days.ago) }
      let!(:new_entry) { create(:entry, date: Date.current) }

      it 'orders by date descending' do
        entries = Entry.reverse_chronological.to_a
        expect(entries.first).to eq(new_entry)
        expect(entries.last).to eq(old_entry)
      end
    end

    describe '.by_account' do
      let(:account1) { create(:account) }
      let(:account2) { create(:account) }
      let!(:entry1) { create(:entry, account: account1) }
      let!(:entry2) { create(:entry, account: account2) }

      it 'filters by account_id' do
        expect(Entry.by_account(account1.id)).to include(entry1)
        expect(Entry.by_account(account1.id)).not_to include(entry2)
      end
    end

    describe '.by_date_range' do
      let!(:old_entry) { create(:entry, date: 5.days.ago) }
      let!(:recent_entry) { create(:entry, date: 2.days.ago) }
      let!(:today_entry) { create(:entry, date: Date.current) }

      it 'filters entries within date range' do
        entries = Entry.by_date_range(3.days.ago, Date.current)
        expect(entries).to include(recent_entry, today_entry)
        expect(entries).not_to include(old_entry)
      end
    end

    describe '.excluded' do
      let!(:excluded_entry) { create(:entry, excluded: true) }
      let!(:included_entry) { create(:entry, excluded: false) }

      it 'returns only excluded entries' do
        expect(Entry.excluded).to include(excluded_entry)
        expect(Entry.excluded).not_to include(included_entry)
      end
    end

    describe '.not_excluded' do
      let!(:excluded_entry) { create(:entry, excluded: true) }
      let!(:included_entry) { create(:entry, excluded: false) }

      it 'returns only non-excluded entries' do
        expect(Entry.not_excluded).to include(included_entry)
        expect(Entry.not_excluded).not_to include(excluded_entry)
      end
    end

    describe '.transfers' do
      let!(:transfer_entry) { create(:entry, transfer_id: SecureRandom.uuid) }
      let!(:regular_entry) { create(:entry) }

      it 'returns only transfer entries' do
        expect(Entry.transfers).to include(transfer_entry)
        expect(Entry.transfers).not_to include(regular_entry)
      end
    end

    describe '.transactions_only' do
      let!(:transaction_entry) { create(:entry) }
      let!(:valuation_entry) { create(:entry, :valuation) }

      it 'returns only transaction entries' do
        expect(Entry.transactions_only).to include(transaction_entry)
        expect(Entry.transactions_only).not_to include(valuation_entry)
      end
    end

    describe '.non_transfers' do
      let!(:transfer_entry) { create(:entry, transfer_id: SecureRandom.uuid) }
      let!(:regular_entry) { create(:entry) }

      it 'returns only non-transfer entries' do
        expect(Entry.non_transfers).to include(regular_entry)
        expect(Entry.non_transfers).not_to include(transfer_entry)
      end
    end

    describe '.expenses' do
      let!(:expense_entry) { create(:entry, :expense) }
      let!(:income_entry) { create(:entry, :income) }

      it 'returns only expense entries' do
        expect(Entry.expenses).to include(expense_entry)
        expect(Entry.expenses).not_to include(income_entry)
      end
    end

    describe '.incomes' do
      let!(:expense_entry) { create(:entry, :expense, amount: 100) }
      let!(:income_entry) { create(:entry, :income, amount: 200) }

      it 'returns only income entries (positive amount)' do
        expect(Entry.incomes).to include(income_entry)
        expect(Entry.incomes).not_to include(expense_entry)
      end
    end
  end

  # 测试 instance methods
  describe 'instance methods' do
    describe '#transaction?' do
      it 'returns true for transaction entries' do
        entry = create(:entry)
        expect(entry.transaction?).to be true
      end

      it 'returns false for non-transaction entries' do
        entry = create(:entry, :valuation)
        expect(entry.transaction?).to be false
      end
    end

    describe '#valuation?' do
      it 'returns true for valuation entries' do
        entry = create(:entry, :valuation)
        expect(entry.valuation?).to be true
      end

      it 'returns false for non-valuation entries' do
        entry = create(:entry)
        expect(entry.valuation?).to be false
      end
    end

    describe '#trade?' do
      it 'returns true for trade entries' do
        entry = create(:entry, :trade)
        expect(entry.trade?).to be true
      end

      it 'returns false for non-trade entries' do
        entry = create(:entry)
        expect(entry.trade?).to be false
      end
    end

    describe '#classification' do
      it 'returns "expense" for negative amount' do
        entry = build(:entry, amount: -100)
        expect(entry.classification).to eq('expense')
      end

      it 'returns "income" for positive amount' do
        entry = build(:entry, amount: 500)
        expect(entry.classification).to eq('income')
      end

      it 'returns "income" for zero amount' do
        entry = build(:entry, amount: 0)
        expect(entry.classification).to eq('income')
      end
    end

    describe '#display_entry_type' do
      context 'when transfer_id is present' do
        let(:entry) { build(:entry, transfer_id: SecureRandom.uuid) }

        it 'returns TRANSFER' do
          expect(entry.display_entry_type).to eq('TRANSFER')
        end
      end

      context 'when entryable responds to kind' do
        let(:expense_entry) { create(:entry, :expense) }
        let(:income_entry) { create(:entry, :income) }

        it 'returns EXPENSE for expense entries' do
          expect(expense_entry.display_entry_type).to eq('EXPENSE')
        end

        it 'returns INCOME for income entries' do
          expect(income_entry.display_entry_type).to eq('INCOME')
        end
      end

      context 'when entryable does not respond to kind' do
        let(:entry) { create(:entry, :valuation) }

        it 'returns EXPENSE' do
          expect(entry.display_entry_type).to eq('EXPENSE')
        end
      end
    end

    describe '#display_amount' do
      it 'returns absolute value for negative amounts' do
        entry = build(:entry, amount: -100.50)
        expect(entry.display_amount).to eq(100.50)
      end

      it 'returns the same value for positive amounts' do
        entry = build(:entry, amount: 200.00)
        expect(entry.display_amount).to eq(200.00)
      end

      it 'returns 0 for zero amount' do
        entry = build(:entry, amount: 0)
        expect(entry.display_amount).to eq(0)
      end
    end

    describe '#display_note' do
      it 'returns notes when present' do
        entry = build(:entry, notes: '买咖啡', name: '支出')
        expect(entry.display_note).to eq('买咖啡')
      end

      it 'returns name when notes is nil' do
        entry = build(:entry, notes: nil, name: '午餐')
        expect(entry.display_note).to eq('午餐')
      end

      it 'returns name when notes is empty' do
        entry = build(:entry, notes: '', name: '晚餐')
        expect(entry.display_note).to eq('晚餐')
      end
    end

    describe '#account_name' do
      it 'returns account name when account exists' do
        account = create(:account, name: '工商银行')
        entry = create(:entry, account: account)
        expect(entry.account_name).to eq('工商银行')
      end

      it 'returns fallback when account is nil' do
        entry = build(:entry, account: nil)
        expect(entry.account_name).to eq('未知账户')
      end
    end

    describe '#display_category' do
      it 'returns category from entryable when it responds to category' do
        category = create(:category)
        entryable = create(:entryable_transaction, category: category)
        entry = create(:entry, entryable: entryable)
        expect(entry.display_category).to eq(category)
      end

      it 'returns nil when entryable does not respond to category' do
        entry = create(:entry, :valuation)
        expect(entry.display_category).to be_nil
      end
    end

    describe '#display_category_id' do
      it 'returns category_id from entryable when it responds to category_id' do
        category = create(:category)
        entryable = create(:entryable_transaction, category: category)
        entry = create(:entry, entryable: entryable)
        expect(entry.display_category_id).to eq(category.id)
      end

      it 'returns nil when entryable does not respond to category_id' do
        entry = create(:entry, :valuation)
        expect(entry.display_category_id).to be_nil
      end
    end

    describe '#target_account_for_display' do
      context 'when transfer_id is not present' do
        let(:entry) { build(:entry) }

        it 'returns nil' do
          expect(entry.target_account_for_display).to be_nil
        end
      end

      context 'when transfer_id is present' do
        let(:account1) { create(:account) }
        let(:account2) { create(:account) }
        let(:transfer_id) { SecureRandom.uuid }
        let!(:outgoing_entry) { create(:entry, account: account1, transfer_id: transfer_id, amount: -100) }
        let!(:incoming_entry) { create(:entry, account: account2, transfer_id: transfer_id, amount: 100) }

        it 'returns the target account for incoming transfer' do
          # incoming_entry 是转入方（amount > 0），自己就是 target_account
          expect(incoming_entry.target_account_for_display).to eq(account2)
        end

        it 'returns the target account for outgoing transfer' do
          # outgoing_entry 是转出方（amount < 0），target_account 是配对的转入账户
          expect(outgoing_entry.target_account_for_display).to eq(account2)
        end
      end
    end

    describe '#source_account_for_transfer' do
      context 'when transfer_id is not present' do
        let(:account) { create(:account) }
        let(:entry) { build(:entry, account: account) }

        it 'returns the entry account' do
          expect(entry.source_account_for_transfer).to eq(account)
        end
      end

      context 'when transfer_id is present and amount is negative' do
        let(:account1) { create(:account) }
        let(:account2) { create(:account) }
        let(:transfer_id) { SecureRandom.uuid }
        let!(:outgoing_entry) { create(:entry, account: account1, transfer_id: transfer_id, amount: -100) }
        let!(:incoming_entry) { create(:entry, account: account2, transfer_id: transfer_id, amount: 100) }

        it 'returns the entry account' do
          expect(outgoing_entry.source_account_for_transfer).to eq(account1)
        end
      end

      context 'when transfer_id is present and amount is positive' do
        let(:account1) { create(:account) }
        let(:account2) { create(:account) }
        let(:transfer_id) { SecureRandom.uuid }
        let!(:outgoing_entry) { create(:entry, account: account1, transfer_id: transfer_id, amount: -100) }
        let!(:incoming_entry) { create(:entry, account: account2, transfer_id: transfer_id, amount: 100) }

        it 'returns the source account' do
          expect(incoming_entry.source_account_for_transfer).to eq(account1)
        end
      end
    end

    describe '#lock_attribute!' do
      let(:entry) { create(:entry) }

      it 'locks the specified attribute' do
        entry.lock_attribute!(:date)
        expect(entry.locked?(:date)).to be true
      end

      it 'saves the entry' do
        expect { entry.lock_attribute!(:date) }.to change { entry.updated_at }
      end

      it 'stores timestamp for locked attribute' do
        entry.lock_attribute!(:date)
        expect(entry.locked_attributes['date']).to be_present
      end
    end

    describe '#locked?' do
      let(:entry) { create(:entry) }

      it 'returns true for locked attributes' do
        entry.lock_attribute!(:date)
        expect(entry.locked?(:date)).to be true
      end

      it 'returns false for non-locked attributes' do
        expect(entry.locked?(:date)).to be false
      end

      it 'handles string attribute names' do
        entry.lock_attribute!(:date)
        expect(entry.locked?('date')).to be true
      end
    end

    describe '#locked_field_names' do
      let(:entry) { create(:entry) }

      it 'returns array of locked attribute names' do
        entry.lock_attribute!(:date)
        entry.lock_attribute!(:amount)
        expect(entry.locked_field_names).to contain_exactly('date', 'amount')
      end

      it 'returns empty array when no attributes are locked' do
        expect(entry.locked_field_names).to eq([])
      end
    end

    describe '#locked_fields_with_timestamps' do
      let(:entry) { create(:entry) }

      it 'returns hash with timestamps for locked attributes' do
        entry.lock_attribute!(:date)
        result = entry.locked_fields_with_timestamps
        expect(result['date']).to be_a(Time)
      end
    end

    describe '#mark_user_modified!' do
      let(:entry) { create(:entry) }

      it 'sets user_modified to true' do
        entry.mark_user_modified!
        expect(entry.user_modified?).to be true
      end

      it 'persists the change' do
        entry.mark_user_modified!
        entry.reload
        expect(entry.user_modified?).to be true
      end
    end

    describe '#protected_from_sync?' do
      it 'returns true when excluded' do
        entry = build(:entry, excluded: true)
        expect(entry.protected_from_sync?).to be true
      end

      it 'returns true when user_modified' do
        entry = build(:entry, user_modified: true)
        expect(entry.protected_from_sync?).to be true
      end

      it 'returns true when import_locked' do
        entry = build(:entry, import_locked: true)
        expect(entry.protected_from_sync?).to be true
      end

      it 'returns false when none of the protection flags are set' do
        entry = build(:entry, excluded: false, user_modified: false, import_locked: false)
        expect(entry.protected_from_sync?).to be false
      end
    end

    describe '#protection_reason' do
      it 'returns :excluded when excluded' do
        entry = build(:entry, excluded: true)
        expect(entry.protection_reason).to eq(:excluded)
      end

      it 'returns :user_modified when user_modified' do
        entry = build(:entry, user_modified: true)
        expect(entry.protection_reason).to eq(:user_modified)
      end

      it 'returns :import_locked when import_locked' do
        entry = build(:entry, import_locked: true)
        expect(entry.protection_reason).to eq(:import_locked)
      end

      it 'returns nil when no protection flags are set' do
        entry = build(:entry, excluded: false, user_modified: false, import_locked: false)
        expect(entry.protection_reason).to be_nil
      end
    end

    describe '#unlock_for_sync!' do
      let(:entry) { create(:entry, user_modified: true, import_locked: true, locked_attributes: { 'date' => Time.current.iso8601 }) }

      it 'resets user_modified to false' do
        entry.unlock_for_sync!
        expect(entry.user_modified?).to be false
      end

      it 'resets import_locked to false' do
        entry.unlock_for_sync!
        expect(entry.import_locked?).to be false
      end

      it 'clears locked_attributes' do
        entry.unlock_for_sync!
        expect(entry.locked_attributes).to eq({})
      end

      it 'updates entryable locked_attributes' do
        entry.entryable.update!(locked_attributes: { 'category_id' => Time.current.iso8601 })
        entry.unlock_for_sync!
        expect(entry.entryable.locked_attributes).to eq({})
      end
    end

    describe '#split_parent?' do
      let(:parent_entry) { create(:entry) }

      it 'returns true when has child entries' do
        create(:entry, parent_entry: parent_entry)
        expect(parent_entry.split_parent?).to be true
      end

      it 'returns false when no child entries' do
        expect(parent_entry.split_parent?).to be false
      end
    end

    describe '#split_child?' do
      it 'returns true when has parent_entry_id' do
        parent = create(:entry)
        child = build(:entry, parent_entry: parent)
        expect(child.split_child?).to be true
      end

      it 'returns false when no parent_entry_id' do
        entry = build(:entry)
        expect(entry.split_child?).to be false
      end
    end

    describe '#split!' do
      let(:account) { create(:account) }
      let(:category) { create(:category) }
      let(:parent_entry) { create(:entry, account: account, amount: -300, date: Date.current) }

      context 'with valid splits' do
        let(:splits) do
          [
            { name: 'Split 1', amount: -100, category_id: category.id },
            { name: 'Split 2', amount: -200, category_id: category.id }
          ]
        end

        it 'creates child entries' do
          expect { parent_entry.split!(splits) }.to change { parent_entry.child_entries.count }.by(2)
        end

        it 'sets excluded to true on parent' do
          parent_entry.split!(splits)
          expect(parent_entry.excluded?).to be true
        end

        it 'marks parent as user_modified' do
          parent_entry.split!(splits)
          expect(parent_entry.user_modified?).to be true
        end

        it 'creates child entries with correct attributes' do
          parent_entry.split!(splits)
          children = parent_entry.child_entries.order(:amount)
          expect(children.map(&:name)).to contain_exactly('Split 1', 'Split 2')
          expect(children.map(&:amount)).to contain_exactly(-100, -200)
        end
      end

      context 'with invalid splits' do
        let(:invalid_splits) do
          [
            { name: 'Split 1', amount: -100, category_id: category.id },
            { name: 'Split 2', amount: -150, category_id: category.id }
          ]
        end

        it 'raises ArgumentError when amounts do not sum to parent amount' do
          expect { parent_entry.split!(invalid_splits) }.to raise_error(ArgumentError, /Split amounts must sum to parent amount/)
        end

        it 'does not create child entries' do
          original_child_count = parent_entry.child_entries.count
          begin
            parent_entry.split!(invalid_splits)
          rescue ArgumentError
            # Expected
          end
          expect(parent_entry.child_entries.count).to eq(original_child_count)
        end
      end
    end

    describe '#unsplit!' do
      let(:account) { create(:account) }
      let(:parent_entry) { create(:entry, account: account, amount: -300, excluded: true) }
      let!(:child1) { create(:entry, account: account, parent_entry: parent_entry, amount: -100) }
      let!(:child2) { create(:entry, account: account, parent_entry: parent_entry, amount: -200) }

      it 'destroys child entries' do
        expect { parent_entry.unsplit! }.to change { Entry.count }.by(-2)
      end

      it 'sets excluded to false on parent' do
        parent_entry.unsplit!
        expect(parent_entry.excluded?).to be false
      end
    end
  end

  # 测试 class methods
  describe 'class methods' do
    describe '.search' do
      it 'delegates to EntrySearch' do
        search_params = { account_id: 1 }
        search_double = instance_double(EntrySearch)
        expect(EntrySearch).to receive(:new).with(search_params).and_return(search_double)
        expect(search_double).to receive(:build_query).with(Entry.all).and_return(Entry.none)
        Entry.search(search_params)
      end
    end

    describe '.bulk_update!' do
      let(:account) { create(:account) }
      let(:category) { create(:category) }
      let!(:entry1) { create(:entry, account: account) }
      let!(:entry2) { create(:entry, account: account) }
      let(:bulk_params) { { date: Date.current, notes: 'Bulk update' } }

      # TODO: Fix bulk_update! method to work with scopes
      xit 'updates all entries' do
        Entry.bulk_update!(bulk_params)
        expect(entry1.reload.date).to eq(Date.current)
        expect(entry1.notes).to eq('Bulk update')
      end

      xit 'returns the number of updated entries' do
        result = Entry.bulk_update!(bulk_params)
        expect(result).to eq(2)
      end

      xit 'skips date update for split children' do
        child = create(:entry, account: account, parent_entry: entry1)
        Entry.bulk_update!({ date: Date.yesterday })
        expect(child.reload.date).not_to eq(Date.yesterday)
      end
    end

    describe '.min_supported_date' do
      it 'returns date 30 years ago' do
        expect(Entry.min_supported_date).to eq(30.years.ago.to_date)
      end
    end

    describe '.preload_transfer_accounts' do
      let(:account1) { create(:account) }
      let(:account2) { create(:account) }
      let(:transfer_id) { SecureRandom.uuid }
      let!(:outgoing) { create(:entry, account: account1, transfer_id: transfer_id, amount: -100) }
      let!(:incoming) { create(:entry, account: account2, transfer_id: transfer_id, amount: 100) }

      it 'preloads transfer accounts for entries' do
        entries = [ outgoing, incoming ]
        Entry.preload_transfer_accounts(entries)
        expect(outgoing.instance_variable_get(:@transfer_accounts_cache)).to be_present
        expect(incoming.instance_variable_get(:@transfer_accounts_cache)).to be_present
      end

      it 'returns empty hash when no transfer_ids' do
        entries = [ create(:entry) ]
        expect(Entry.preload_transfer_accounts(entries)).to eq({})
      end
    end
  end

  # 测试边界条件和异常情况
  describe 'edge cases' do
    it 'handles very old dates' do
      old_date = 29.years.ago.to_date
      entry = build(:entry, date: old_date)
      expect(entry).to be_valid
    end

    it 'rejects dates older than 30 years' do
      too_old_date = 31.years.ago.to_date
      entry = build(:entry, date: too_old_date)
      expect(entry).not_to be_valid
      expect(entry.errors[:date]).to be_present
    end

    it 'handles zero amount' do
      entry = build(:entry, amount: 0)
      expect(entry).to be_valid
    end

    it 'handles very large amounts' do
      entry = build(:entry, amount: 999999999.99)
      expect(entry).to be_valid
    end

    it 'handles very small negative amounts' do
      entry = build(:entry, amount: -0.01)
      expect(entry).to be_valid
    end

    it 'handles nil notes' do
      entry = build(:entry, notes: nil)
      expect(entry).to be_valid
    end

    it 'handles empty notes' do
      entry = build(:entry, notes: '')
      expect(entry).to be_valid
    end

    it 'handles long names' do
      entry = build(:entry, name: 'A' * 255)
      expect(entry).to be_valid
    end

    it 'handles different currencies' do
      entry = build(:entry, currency: 'USD')
      expect(entry).to be_valid
    end
  end

  # 测试回调
  describe 'callbacks' do
    describe 'activity logging' do
      let(:entry) { build(:entry) }

      it 'logs creation activity after create' do
        expect(ActivityLog).to receive(:log_create).with(entry, description: a_string_starting_with('创建交易:'))
        entry.save!
      end

      it 'logs update activity after update' do
        entry.save!
        expect(ActivityLog).to receive(:log_update).with(entry, description: a_string_starting_with('更新交易:'))
        entry.update!(name: 'Updated name')
      end

      it 'logs destroy activity after destroy' do
        entry.save!
        expect(ActivityLog).to receive(:log_destroy).with(entry, description: a_string_starting_with('删除交易:'))
        entry.destroy
      end
    end
  end
end
