class AddUniqueIndexOnBudgetItemsCategory < ActiveRecord::Migration[8.1]
  def up
    # 清理历史重复：(single_budget_id, category_id) 只保留最小 id 的一条
    execute <<~SQL.squish
      DELETE FROM budget_items a
      USING budget_items b
      WHERE a.single_budget_id = b.single_budget_id
        AND a.category_id = b.category_id
        AND a.category_id IS NOT NULL
        AND a.id > b.id
    SQL

    # 裸 DELETE 绕过了回调，重算 counter_cache，避免 budget_items_count 残留
    execute <<~SQL.squish
      UPDATE single_budgets s
      SET budget_items_count = (SELECT COUNT(*) FROM budget_items b WHERE b.single_budget_id = s.id)
    SQL

    # Postgres 唯一索引将 NULL 视为互不相等，无分类的条目不受影响
    add_index :budget_items, [ :single_budget_id, :category_id ],
      unique: true, name: "index_budget_items_on_single_budget_id_and_category_id"
  end

  def down
    remove_index :budget_items, name: "index_budget_items_on_single_budget_id_and_category_id"
  end
end
