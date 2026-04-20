class AddSourceEntryIdToReceivables < ActiveRecord::Migration[8.1]
  def change
    add_reference :receivables, :source_entry, null: true, foreign_key: { to_table: :entries }
  end
end
