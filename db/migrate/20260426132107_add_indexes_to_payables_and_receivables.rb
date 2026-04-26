class AddIndexesToPayablesAndReceivables < ActiveRecord::Migration[8.1]
  def change
    # payables 表索引 - 优化 unsettled scope 查询
    add_index :payables, [ :settled_at, :date ], name: "idx_payables_settled_date"

    # receivables 表索引 - 同上
    add_index :receivables, [ :settled_at, :date ], name: "idx_receivables_settled_date"

    # entryable_transactions 表索引 - 优化分类+类型查询
    add_index :entryable_transactions, [ :category_id, :kind ], name: "idx_entryable_transactions_category_kind"
  end
end
