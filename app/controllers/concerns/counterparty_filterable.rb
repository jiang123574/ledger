# CounterpartyFilterable - 提供按联系人筛选的通用方法
# 用于 PayablesController 和 ReceivablesController
#
# 使用方式:
#   include CounterpartyFilterable
#
# 提供的方法:
#   - build_counterparty_stats(records) - 构建联系人统计
#   - filter_by_counterparty(scope, counterparty_id) - 按联系人筛选
#   - counterparty_filter_token_for(record) - 获取筛选 token
module CounterpartyFilterable
  extend ActiveSupport::Concern

  # 构建联系人统计数据（用于侧边栏筛选）
  # @param records [ActiveRecord::Relation] 应付款/应收款记录
  # @return [Array<Hash>] 统计数组，包含 name, filter_value, count, amount
  def build_counterparty_stats(records)
    records.group_by { |r| counterparty_filter_token_for(r) }
      .map do |filter_value, rows|
        first = rows.first
        name = extract_counterparty_name(first)
        {
          name: name,
          filter_value: filter_value,
          count: rows.size,
          amount: rows.sum { |row| row.remaining_amount.to_d }
        }
      end
      .sort_by { |s| [ -s[:amount], -s[:count], s[:name] ] }
      .first(8)
  end

  # 按联系人筛选记录
  # @param scope [ActiveRecord::Relation] 查询范围
  # @param counterparty_id [String, nil] 联系人筛选值
  # @return [ActiveRecord::Relation] 筛选后的范围
  def filter_by_counterparty(scope, counterparty_id)
    return scope if counterparty_id.blank?

    # 未设置联系人的情况
    if counterparty_id == "none"
      return scope.where(counterparty_id: nil)
    end

    # 按 ID 筛选
    normalized_id = counterparty_id.start_with?("id:") ? counterparty_id.delete_prefix("id:") : counterparty_id

    cp = Counterparty.find_by(id: normalized_id)
    return scope.none unless cp

    scope.where(counterparty_id: cp.id)
  end

  # 获取记录的筛选 token
  # @param record [Payable, Receivable] 记录
  # @return [String] 筛选 token (id:xxx 或 none)
  def counterparty_filter_token_for(record)
    record.counterparty_id.present? ? "id:#{record.counterparty_id}" : "none"
  end

  private

  # 提取联系人名称
  def extract_counterparty_name(record)
    record.counterparty&.name || "未设置联系人"
  end
end
