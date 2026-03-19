class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.string :name
      t.string :type
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency, limit: 3, default: "CNY"
      t.decimal :total_amount, precision: 10, scale: 2
      t.integer :installments_total, default: 1
      t.integer :installments_completed, default: 0
      t.references :account, foreign_key: { to_table: :accounts }, null: true
      t.integer :day_of_month, default: 1
      t.integer :active, default: 1
      t.datetime :last_generated
      t.timestamps
    end
  end
end
