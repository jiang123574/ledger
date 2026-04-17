class AddCategoryToPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :plans, :category_id, :integer
    add_index :plans, :category_id
    add_foreign_key :plans, :categories, validate: false
  end
end
