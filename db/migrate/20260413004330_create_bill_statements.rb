class CreateBillStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :bill_statements do |t|
      t.references :account, null: false, foreign_key: true
      t.date :billing_date, null: false
      t.decimal :statement_amount, precision: 10, scale: 2, null: false
      t.timestamps
    end

    add_index :bill_statements, [ :account_id, :billing_date ], unique: true
  end
end
