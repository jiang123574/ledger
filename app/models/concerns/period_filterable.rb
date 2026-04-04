# frozen_string_literal: true

# 期间过滤的公共逻辑
# 被 Transaction、EntrySearch、AccountsController 等多处复用
module PeriodFilterable
  extend ActiveSupport::Concern

  class_methods do
    # 根据 period_type 和 period_value 返回日期范围
    # @return [Array(Date, Date)] [start_date, end_date] 或 nil
    def resolve_period(period_type, period_value)
      return nil unless period_type.present? && period_value.present?

      case period_type
      when 'all'
        nil
      when 'year'
        year = period_value.to_i
        [Date.new(year, 1, 1), Date.new(year, 12, 31)]
      when 'month'
        start = Date.parse("#{period_value}-01")
        [start, start.end_of_month]
      when 'week'
        if (m = period_value.match(/\A(\d{4})-W(\d{2})\z/))
          start_date = Date.commercial(m[1].to_i, m[2].to_i, 1)
          [start_date, start_date + 6.days]
        else
          nil
        end
      else
        # 尝试解析为 month 格式 (YYYY-MM)
        if period_value.match?(/\A\d{4}-\d{2}\z/)
          start = Date.parse("#{period_value}-01")
          [start, start.end_of_month]
        else
          nil
        end
      end
    end

    # 默认期间值（当前）
    def default_period_value(period_type)
      case period_type
      when 'year' then Date.current.year.to_s
      when 'week' then Date.current.strftime("%G-W%V")
      else Date.current.strftime("%Y-%m")
      end
    end
  end
end
