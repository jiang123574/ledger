require 'rails_helper'

RSpec.describe AccountsIndexService do
  let(:account) { create(:account, initial_balance: 5000, include_in_total: true) }

  describe '#load_entries_with_balance' do
    it 'preloads entry accounts and transaction associations for rendering' do
      entry = create(:entry, account: account, date: Date.current)
      service = AccountsIndexService.new({}, { accounts: CacheBuster.version(:accounts), entries: CacheBuster.version(:entries) })

      result = service.load_entries_with_balance(Entry.where(id: entry.id).reverse_chronological, 1, 15)
      loaded_entry = result.first.first

      expect(loaded_entry.association(:account)).to be_loaded
      expect(loaded_entry.association(:entryable)).to be_loaded
      expect(loaded_entry.entryable.association(:category)).to be_loaded
    end
  end

  describe '#load_total_assets' do
    it 'uses cache key containing both accounts and entries versions' do
      av = CacheBuster.version(:accounts)
      ev = CacheBuster.version(:entries)
      service = AccountsIndexService.new({}, { accounts: av, entries: ev })

      expect(Rails.cache).to receive(:fetch).with("total_assets/#{av}/#{ev}", anything).and_call_original

      service.load_total_assets
    end

    it 'cache key changes when accounts version changes' do
      av1 = CacheBuster.version(:accounts)
      ev = CacheBuster.version(:entries)
      service1 = AccountsIndexService.new({}, { accounts: av1, entries: ev })

      service1.load_total_assets

      CacheBuster.bump(:accounts)
      av2 = CacheBuster.version(:accounts)

      expect(av2).not_to eq(av1)

      service2 = AccountsIndexService.new({}, { accounts: av2, entries: ev })
      expect(Rails.cache).to receive(:fetch).with("total_assets/#{av2}/#{ev}", anything).and_call_original

      service2.load_total_assets
    end

    it 'cache key changes when entries version changes' do
      av = CacheBuster.version(:accounts)
      ev1 = CacheBuster.version(:entries)
      service1 = AccountsIndexService.new({}, { accounts: av, entries: ev1 })

      service1.load_total_assets

      CacheBuster.bump(:entries)
      ev2 = CacheBuster.version(:entries)

      expect(ev2).not_to eq(ev1)

      service2 = AccountsIndexService.new({}, { accounts: av, entries: ev2 })
      expect(Rails.cache).to receive(:fetch).with("total_assets/#{av}/#{ev2}", anything).and_call_original

      service2.load_total_assets
    end
  end
end
