# EntryDisplayHelper - Entry 显示相关的辅助方法
# 用于简化 accounts/index.html.erb 中的视图逻辑
module EntryDisplayHelper
  # 类型徽章的 CSS 类映射
  TYPE_BADGE_CLASSES = {
    "收入" => "bg-income-light text-income",
    "支出" => "bg-expense-light text-expense",
    "转账" => "bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300",
    "转入" => "bg-income-light text-income",
    "转出" => "bg-expense-light text-expense"
  }.freeze

  DEFAULT_BADGE_CLASS = "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300"

  # 获取 Entry 的显示类型标签
  # @param entry [Entry] 交易记录
  # @param account_filter [String, nil] 当前账户筛选参数
  # @return [String] 显示类型（收入/支出/转账/转入/转出）
  def entry_display_type(entry, account_filter = nil)
    entry_type = entry.display_entry_type

    if entry_type == "TRANSFER"
      if account_filter.blank?
        "转账"
      elsif entry.amount.positive?
        "转入"
      else
        "转出"
      end
    else
      entry.display_type_label
    end
  end

  # 获取 Entry 的金额显示类型（用于流入流出列）
  # @param entry [Entry] 交易记录
  # @param account_filter [String, nil] 当前账户筛选参数
  # @return [String] 类型标识（INCOME/EXPENSE/TRANSFER）
  def entry_display_amount_type(entry, account_filter = nil)
    entry_type = entry.display_entry_type

    if entry_type == "TRANSFER"
      if account_filter.blank?
        "TRANSFER"
      elsif entry.amount.positive?
        "INCOME"
      else
        "EXPENSE"
      end
    else
      entry.display_flow_type
    end
  end

  # 获取类型徽章的 CSS 类
  # @param display_type [String] 显示类型
  # @return [String] CSS 类字符串
  def entry_type_badge_class(display_type)
    TYPE_BADGE_CLASSES[display_type] || DEFAULT_BADGE_CLASS
  end

  # 获取转账对手账户名称
  # @param entry [Entry] 交易记录
  # @param account_filter [String, nil] 当前账户筛选参数
  # @return [String, nil] 对手账户名称
  def entry_transfer_counterpart(entry, account_filter = nil)
    is_inflow = entry.display_entry_type == "TRANSFER" && entry.amount.positive?

    if is_inflow
      entry.source_account_for_transfer&.name
    else
      entry.target_account_for_display&.name
    end
  end

  # 判断 Entry 是否为转账且为流入
  # @param entry [Entry] 交易记录
  # @return [Boolean]
  def entry_is_transfer_inflow?(entry)
    entry.display_entry_type == "TRANSFER" && entry.amount.positive?
  end

  # 判断 Entry 是否为转账且为流出
  # @param entry [Entry] 交易记录
  # @return [Boolean]
  def entry_is_transfer_outflow?(entry)
    entry.display_entry_type == "TRANSFER" && entry.amount.negative?
  end

  # 获取转账显示文本（带箭头）
  # @param entry [Entry] 交易记录
  # @param account_filter [String, nil] 当前账户筛选参数
  # @return [String] 显示文本
  def entry_transfer_display_text(entry, account_filter = nil)
    if account_filter.present?
      counterpart = entry_transfer_counterpart(entry, account_filter)
      is_inflow = entry.amount.positive?
      is_inflow ? "← #{counterpart}" : "→ #{counterpart}"
    else
      "#{entry.source_account_for_transfer&.name} → #{entry.target_account_for_display&.name}"
    end
  end

  # 获取 Entry 分类显示文本
  # @param entry [Entry] 交易记录
  # @param account_filter [String, nil] 当前账户筛选参数
  # @return [String] 显示文本
  def entry_category_display_text(entry, account_filter = nil)
    if entry.display_entry_type == "TRANSFER"
      entry_transfer_display_text(entry, account_filter)
    else
      entry.display_category&.name || "-"
    end
  end
end
