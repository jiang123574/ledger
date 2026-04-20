# frozen_string_literal: true

class AddBudgetItemsCountToSingleBudgets < ActiveRecord::Migration[8.1]
  def change
    add_column :single_budgets, :budget_items_count, :integer, default: 0, null: false

    # Backfill existing counts
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE single_budgets
          SET budget_items_count = (
            SELECT COUNT(*) FROM budget_items WHERE budget_items.single_budget_id = single_budgets.id
          )
        SQL
      end
    end
  end
end
