class AddIncludeInTotalToPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :plans, :include_in_total, :integer, default: 0, null: false
  end
end
