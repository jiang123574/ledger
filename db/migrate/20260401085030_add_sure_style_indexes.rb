class AddSureStyleIndexes < ActiveRecord::Migration[8.1]
  def change
    # 复合索引 - 学习 Sure 的索引策略
    # 账户交易查询优化
    add_index :transactions, [ :account_id, :date ],
              name: 'idx_trans_account_date'
    add_index :transactions, [ :date, :type ],
              name: 'idx_trans_date_type'

    # 转账查询优化
    add_index :transactions, [ :target_account_id, :date ],
              name: 'idx_trans_target_date'

    # 分类统计优化
    add_index :transactions, [ :category_id, :date, :type ],
              name: 'idx_trans_category_date_type'

    # 部分索引 - 只索引活跃数据
    add_index :transactions, :date,
              name: 'idx_trans_date_income',
              where: "type = 'INCOME'"
    add_index :transactions, :date,
              name: 'idx_trans_date_expense',
              where: "type = 'EXPENSE'"

    # 账户索引优化
    add_index :accounts, [ :hidden, :include_in_total, :type ],
              name: 'idx_accounts_visibility_type'

    # 分类索引
    add_index :categories, [ :active, :type ],
              name: 'idx_categories_active_type'

    # 标签查询优化
    add_index :transaction_tags, [ :tag_id, :transaction_id ],
              name: 'idx_trans_tags_tag_trans'

    # 唯一索引防止重复 - 学习 Sure 的防重复策略
    add_index :transactions, [ :account_id, :date, :amount, :type ],
              name: 'idx_trans_unique_check',
              where: "dedupe_key IS NULL"

    # 预算查询优化
    add_index :budgets, [ :month, :category_id ],
              name: 'idx_budgets_month_category'

    # 定期交易查询优化
    add_index :recurring_transactions, [ :account_id, :is_active ],
              name: 'idx_recurring_active'

    # 附件查询优化
    add_index :attachments, [ :transaction_id, :file_type ],
              name: 'idx_attachments_trans_type'
  end
end
