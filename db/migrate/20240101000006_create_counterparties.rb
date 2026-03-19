class CreateCounterparties < ActiveRecord::Migration[8.0]
  def change
    create_table :counterparties do |t|
      t.string :name, null: false
    end
    add_index :counterparties, :name, unique: true
  end
end
