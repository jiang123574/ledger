# EntryPresenter - 提取 entry→JSON 转换逻辑
# 从 accounts_controller.rb 中提取，保持向后兼容
class EntryPresenter
  # 用于 entries action 的 JSON 序列化
  # @param entry [Entry] Entry 对象
  # @param balance_map [Hash] { entry_id => balance_after } 的映射
  # @param account_filter [String, nil] 当前账户筛选 ID（可选）
  # @return [Hash] 包含所有展示字段的哈希
  def self.entry_to_json(entry, balance_map, account_filter = nil)
    entry_type = entry.display_entry_type
    is_transfer = entry_type == "TRANSFER"
    is_inflow = is_transfer && entry.amount.positive?

    display_type = if is_transfer
      if account_filter.blank?
        "转账"
      else
        is_inflow ? "转入" : "转出"
      end
    else
      entry.display_type_label
    end

    display_amount_type = if is_transfer
      if account_filter.blank?
        "TRANSFER"
      else
        is_inflow ? "INCOME" : "EXPENSE"
      end
    else
      entry.display_flow_type
    end

    transfer_counterpart = if is_inflow
      entry.source_account_for_transfer&.name
    else
      entry.target_account_for_display&.name
    end

    display_name = if is_transfer
      if account_filter.present?
        (is_inflow ? "← " : "→ ") + (transfer_counterpart || "未知账户")
      else
        "#{entry.source_account_for_transfer&.name} → #{entry.target_account_for_display&.name}"
      end
    else
      entry.display_category&.name || "-"
    end

    {
      id: entry.id,
      account_id: entry.account_id,
      name: entry.name,
      date: entry.date&.strftime("%Y-%m-%d"),
      amount: entry.amount.to_f,
      display_amount: entry.display_amount,
      type: entry_type,
      display_type: display_type,
      display_amount_type: display_amount_type,
      display_name: display_name,
      note: entry.display_note || entry.account&.name || "未知账户",
      balance_after: balance_map[entry.id],
      show_both_amounts: is_transfer && account_filter.blank?,
      transfer_from: is_transfer ? entry.source_account_for_transfer&.name : nil,
      transfer_to: is_transfer ? entry.target_account_for_display&.name : nil,
      account_name: entry.account&.name || "未知账户"
    }
  end

  # 用于 bills_entries action 的 JSON 序列化
  # @param entry [Entry] Entry 对象
  # @param balance_after [Numeric, nil] 余额（可选，如果为 nil 则在调用处计算）
  # @return [Hash] 包含所有展示字段的哈希
  def self.entry_for_bill(entry, balance_after = nil)
    entry_type = entry.display_entry_type
    is_transfer = entry_type == "TRANSFER"
    is_inflow = is_transfer && entry.amount.positive?

    display_type = if is_transfer
      is_inflow ? "转入" : "转出"
    else
      entry.display_type_label
    end

    display_amount_type = if is_transfer
      is_inflow ? "INCOME" : "EXPENSE"
    else
      entry.display_flow_type
    end

    display_name = if is_transfer
      counterpart = is_inflow ? entry.source_account_for_transfer&.name : entry.target_account_for_display&.name
      (is_inflow ? "← " : "→ ") + (counterpart || "未知账户")
    else
      entry.display_category&.name || "-"
    end

    {
      id: entry.id,
      date: entry.date,
      amount: entry.amount,
      display_amount: entry.display_amount,
      type: entry_type,
      type_label: entry.display_type_label,
      display_type: display_type,
      display_amount_type: display_amount_type,
      display_name: display_name,
      note: entry.display_note,
      category_name: entry.display_category&.name,
      account_name: entry.account&.name || "未知账户",
      transfer_from: is_transfer && entry.source_account_for_transfer&.name,
      transfer_to: is_transfer && entry.target_account_for_display&.name,
      is_repayment: entry.amount.positive?,
      is_spend: entry.amount.negative?,
      balance_after: balance_after
    }
  end
end
