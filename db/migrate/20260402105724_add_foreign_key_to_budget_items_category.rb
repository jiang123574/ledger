class AddForeignKeyToBudgetItemsCategory < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :budget_items, :categories, column: :category_id, on_delete: :nullify
  end
end
