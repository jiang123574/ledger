class CreateReceivables < ActiveRecord::Migration[8.0]
  def change
    create_table :receivables do |t|
      t.string :counterparty
      t.decimal :original_amount, precision: 10, scale: 2
      t.decimal :remaining_amount, precision: 10, scale: 2
      t.string :currency, limit: 3, default: "CNY"
      t.string :note
      t.datetime :settled_at
      t.references :source_transaction, foreign_key: { to_table: :transactions }, null: true
      t.timestamps
    end
  end
end
