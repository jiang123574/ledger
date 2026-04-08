class AddNotesIndexToEntries < ActiveRecord::Migration[8.1]
  def change
    add_index :entries, [ :account_id, :date, :notes ], name: :idx_entries_account_date_notes
    add_index :entries, [ :account_id, :date, :name ], name: :idx_entries_account_date_name
  end
end
