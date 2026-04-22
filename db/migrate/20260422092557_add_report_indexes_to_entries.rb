class AddReportIndexesToEntries < ActiveRecord::Migration[8.1]
  def change
    add_index :entries, [ :date, :entryable_type, :transfer_id ],
      where: "entryable_type = 'Entryable::Transaction' AND transfer_id IS NULL",
      name: 'idx_entries_report_transactions'
  end
end
