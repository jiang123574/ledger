class AddSortOrderToEntries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :entries, :sort_order, :integer, default: 0, null: false
    add_index :entries, :sort_order, algorithm: :concurrently

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE entries
          SET sort_order = sub.row_number
          FROM (
            SELECT id, row_number() OVER (PARTITION BY account_id, date ORDER BY created_at DESC) AS row_number
            FROM entries
          ) AS sub
          WHERE entries.id = sub.id
        SQL
      end
    end
  end
end
