class AddBalanceDistributionToPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :plans, :balance_distribution, :string, default: "LAST", null: false
  end
end
