class AddPgTrgmExtensionAndIndexes < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'pg_trgm'

    add_index :entries, :name, using: :gin, opclass: :gin_trgm_ops, name: :idx_entries_name_trgm
    add_index :entries, :notes, using: :gin, opclass: :gin_trgm_ops, name: :idx_entries_notes_trgm
  end
end
