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
      return filter_none_counterparty(scope)
    end

    # 按名称筛选（用于 receivables 的 counterparty 字符串字段）
    if counterparty_id.start_with?("name:")
      name = counterparty_id.delete_prefix("name:")
      return filter_by_counterparty_name(scope, name)
    end

    # 按 ID 筛选（标准情况）
    normalized_id = counterparty_id.start_with?("id:") ? counterparty_id.delete_prefix("id:") : counterparty_id

    cp = Counterparty.find_by(id: normalized_id)
    return scope.none unless cp

    filter_by_counterparty_id(scope, cp)
  end

  # 获取记录的筛选 token
  # @param record [Payable, Receivable] 记录
  # @return [String] 筛选 token (id:xxx, name:xxx, 或 none)
  def counterparty_filter_token_for(record)
    if record.counterparty_id.present?
      "id:#{record.counterparty_id}"
    elsif record.respond_to?(:counterparty) && record.counterparty.present?
      "name:#{record.counterparty}"
    else
      "none"
    end
  end

  private

  # 提取联系人名称
  def extract_counterparty_name(record)
    if record.counterparty&.name.present?
      record.counterparty.name
    elsif record.respond_to?(:counterparty) && record.counterparty.present?
      record.counterparty
    else
      "未设置联系人"
    end
  end

  # 筛选未设置联系人的记录
  # 子类可覆盖此方法以适应不同的字段结构
  def filter_none_counterparty(scope)
    if scope.klass.respond_to?(:counterparty) && scope.klass.column_names.include?("counterparty")
      # Receivable 模型有 counterparty 字符串字段
      scope.where(counterparty_id: nil, counterparty: [ nil, "" ])
    else
      # Payable 模型只有 counterparty_id
      scope.where(counterparty_id: nil)
    end
  end

  # 按联系人名称筛选（用于 counterparty 字符串字段）
  def filter_by_counterparty_name(scope, name)
    if scope.klass.column_names.include?("counterparty")
      scope.where(counterparty: name).or(scope.joins(:counterparty).where(counterparties: { name: name }))
    else
      # 如果没有 counterparty 字符串字段，只按关联筛选
      scope.joins(:counterparty).where(counterparties: { name: name })
    end
  end

  # 按联系人 ID 筛选
  def filter_by_counterparty_id(scope, counterparty)
    if scope.klass.column_names.include?("counterparty")
      # Receivable 模型：同时筛选 counterparty_id 和 counterparty 字符串
      scope.where(counterparty_id: counterparty.id).or(scope.where(counterparty: counterparty.name))
    else
      # Payable 模型：只筛选 counterparty_id
      scope.where(counterparty_id: counterparty.id)
    end
  end
end
