class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :category_type
      t.references :parent, foreign_key: { to_table: :categories }, null: true
      t.integer :sort_order, default: 0
    end
    add_index :categories, :name, unique: true
  end
end
