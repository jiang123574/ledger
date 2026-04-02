class AddCategoryIdToBudgetItems < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_items, :category_id, :integer
  end
end
