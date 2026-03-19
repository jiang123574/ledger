class CreateTransactionTags < ActiveRecord::Migration[8.0]
  def change
    create_table :transaction_tags, id: false do |t|
      t.references :transaction, foreign_key: { to_table: :transactions, on_delete: :cascade }, null: false
      t.references :tag, foreign_key: { on_delete: :cascade }, null: false
    end
    add_index :transaction_tags, [:transaction_id, :tag_id], unique: true
  end
end
