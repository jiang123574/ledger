class CreateTransactionTags < ActiveRecord::Migration[8.0]
  def change
    create_table :transaction_tags, id: false do |t|
      t.belongs_to :transaction, foreign_key: true, null: false
      t.belongs_to :tag, foreign_key: true, null: false

      t.timestamps
    end

    add_index :transaction_tags, [:transaction_id, :tag_id], unique: true
  end
end