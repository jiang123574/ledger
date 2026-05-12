# EntrySerializer - 交易记录 JSON 序列化器
# 用于 AccountsController#entries API 响应
# 只返回前端需要的字段，减少 JSON 大小
#
class EntrySerializer
  # 必要字段列表（前端 entry_card_renderer.js 实际使用的字段）
  REQUIRED_FIELDS = %i[
    id
    date
    display_type
    display_amount_type
    display_amount
    display_name
    note
    balance_after
    show_both_amounts
    transfer_from
    transfer_to
    account_name
  ].freeze

  class << self
    # 创建单个条目的序列化哈希
    # @param entry [Entry] 交易记录
    # @param balance [BigDecimal] 余额
    # @param account_filter [String, nil] 当前筛选的账户 ID
    # @return [Hash] 序列化的 JSON 数据
    def serialize(entry, balance: nil, account_filter: nil)
      entry_type = entry.display_entry_type
      is_transfer = entry_type == "TRANSFER"
      is_inflow = is_transfer && entry.amount.positive?

      display_type = compute_display_type(entry, is_transfer, is_inflow, account_filter)
      display_amount_type = compute_display_amount_type(entry, is_transfer, is_inflow, account_filter)
      display_name = compute_display_name(entry, is_transfer, is_inflow, account_filter)

      {
        id: entry.id,
        account_id: entry.account_id,  # 保留向后兼容
        name: entry.name,              # 保留向后兼容
        date: entry.date&.strftime("%Y-%m-%d"),
        amount: entry.amount.to_f,     # 保留向后兼容
        display_amount: entry.display_amount,
        type: entry_type,              # 保留向后兼容
        display_type: display_type,
        display_amount_type: display_amount_type,
        display_name: display_name,
        note: entry.display_note,
        balance_after: balance || 0,
        show_both_amounts: is_transfer && account_filter.blank?,
        transfer_from: is_transfer ? entry.source_account_for_transfer&.name : nil,
        transfer_to: is_transfer ? entry.target_account_for_display&.name : nil,
        account_name: entry.account&.name || "未知账户"
      }
    end

    # 批量序列化条目
    # @param entries [Array<Entry>] 交易记录列表
    # @param balance_map [Hash<Integer, BigDecimal>] 余额映射 { entry_id => balance }
    # @param account_filter [String, nil] 当前筛选的账户 ID
    # @return [Array<Hash>] 序列化的 JSON 数据数组
    def serialize_batch(entries, balance_map: {}, account_filter: nil)
      entries.map do |entry|
        serialize(entry, balance: balance_map[entry.id], account_filter: account_filter)
      end
    end

    private

    def compute_display_type(entry, is_transfer, is_inflow, account_filter)
      if is_transfer
        if account_filter.blank?
          "转账"
        else
          is_inflow ? "转入" : "转出"
        end
      else
        entry.display_type_label
      end
    end

    def compute_display_amount_type(entry, is_transfer, is_inflow, account_filter)
      if is_transfer
        if account_filter.blank?
          "TRANSFER"
        else
          is_inflow ? "INCOME" : "EXPENSE"
        end
      else
        entry.display_entry_type
      end
    end

    def compute_display_name(entry, is_transfer, is_inflow, account_filter)
      if is_transfer
        transfer_counterpart = compute_transfer_counterpart(entry, is_inflow)
        if account_filter.present?
          (is_inflow ? "← " : "→ ") + (transfer_counterpart || "未知账户")
        else
          "#{entry.source_account_for_transfer&.name} → #{entry.target_account_for_display&.name}"
        end
      else
        entry.display_category&.name || "-"
      end
    end

    def compute_transfer_counterpart(entry, is_inflow)
      if is_inflow
        entry.source_account_for_transfer&.name
      else
        entry.target_account_for_display&.name
      end
    end
  end
end
