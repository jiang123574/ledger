class AddUniqueIndexOnBudgetItemsCategory < ActiveRecord::Migration[8.1]
  def up
    # 清理历史重复：每个 (single_budget_id, category_id) 保留"最完整"的一行
    # （金额更高 → 有备注 → id 更小），删除其余行，避免误删带数据的条目
    execute <<~SQL.squish
      DELETE FROM budget_items
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY single_budget_id, category_id
                   ORDER BY amount DESC, (COALESCE(notes, '') <> '') DESC, id ASC
                 ) AS rn
          FROM budget_items
          WHERE category_id IS NOT NULL
        ) ranked
        WHERE rn > 1
      )
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
