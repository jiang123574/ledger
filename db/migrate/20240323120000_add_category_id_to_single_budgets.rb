class AddCategoryIdToSingleBudgets < ActiveRecord::Migration[8.0]
  def change
    add_reference :single_budgets, :category, foreign_key: { to_table: :categories }, index: true
  end
end
