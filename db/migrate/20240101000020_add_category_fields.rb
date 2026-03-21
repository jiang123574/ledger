class AddCategoryFields < ActiveRecord::Migration[8.0]
  def change
    change_table :categories, bulk: true do |t|
      t.string :color, limit: 7, default: "#6b7280"
      t.string :icon
      t.integer :sort_order, default: 0
      t.boolean :active, default: true
      t.integer :level, default: 0
    end

    add_index :categories, :sort_order
    add_index :categories, :active
  end
end