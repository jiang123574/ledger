class CreatePayables < ActiveRecord::Migration[8.0]
  def change
    create_table :payables do |t|
      t.string :description
      t.decimal :original_amount, precision: 10, scale: 2
      t.decimal :remaining_amount, precision: 10, scale: 2
      t.string :currency, limit: 3, default: 'CNY'
      t.date :date, default: -> { 'CURRENT_DATE' }
      t.string :category
      t.string :counterparty
      t.text :note
      t.datetime :settled_at
      t.integer :source_transaction_id
      t.references :counterparty, foreign_key: true, null: true
      t.references :account, foreign_key: true, null: true

      t.timestamps
    end

    add_reference :transactions, :payable, foreign_key: true, null: true
  end
end
