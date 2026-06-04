# 账户页面条目查询构建服务
# 从 AccountsController 提取的 build_entries_query 逻辑
class AccountEntriesQueryService
  attr_reader :params

  def initialize(params)
    @params = params
  end

  # 构建条目查询
  # @return [ActiveRecord::Relation]
  def build
    entries = base_scope

    entries = apply_account_filter(entries)
    entries = apply_type_filter(entries)
    entries = apply_category_filter(entries)
    entries = apply_period_filter(entries)
    entries = apply_search_filter(entries)
    entries = apply_transfer_filter(entries)
    entries = apply_sort(entries)

    entries
  end

  # 构建缓存键
  # @return [String]
  def cache_key
    sort_direction = params[:sort_direction]&.downcase || "desc"
    sort_direction = "desc" unless sort_direction.in?(%w[asc desc])
    "#{params[:account_id]}_#{params[:type]}_#{params[:period_type]}_#{params[:period_value]}_#{params[:start_date]}_#{params[:end_date]}_#{params[:search]}_#{Array(params[:category_ids]).sort.join(',')}_#{sort_direction}"
  end

  private

  def base_scope
    Entry.where(entryable_type: [ "Entryable::Transaction" ])
  end

  def apply_account_filter(entries)
    if params[:account_id].present?
      entries.where(account_id: params[:account_id])
    else
      entries.where("transfer_id IS NULL OR amount < 0")
    end
  end

  def apply_type_filter(entries)
    if params[:type].present?
      kind = params[:type].downcase
      entries.with_entryable_transaction
             .where(entryable_transactions: { kind: kind })
    else
      entries
    end
  end

  def apply_category_filter(entries)
    if params[:category_ids].present?
      category_ids = Array(params[:category_ids]).reject(&:blank?)
      if category_ids.any?
        entries.with_entryable_transaction
               .where(entryable_transactions: { category_id: category_ids })
      else
        entries
      end
    else
      entries
    end
  end

  def apply_period_filter(entries)
    # 支持直接的 start_date/end_date 参数
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]) rescue nil
      end_date = Date.parse(params[:end_date]) rescue nil
      if start_date && end_date
        entries.by_date_range(start_date, end_date)
      else
        entries
      end
    else
      period_type = params[:period_type].presence || "month"
      period_value = params[:period_value].presence || PeriodFilterable.default_period_value(period_type)

      range = PeriodFilterable.resolve_period(period_type, period_value)
      if range
        entries.by_date_range(range.first, range.last)
      else
        entries
      end
    end
  end

  def apply_search_filter(entries)
    if params[:search].present?
      raw = params[:search].to_s.strip
      safe = raw.gsub(/[%_]/) { |char| "\\#{char}" }

      entries = entries
        .joins("LEFT JOIN entryable_transactions AS st ON entries.entryable_id = st.id AND entries.entryable_type = 'Entryable::Transaction'")
        .joins("LEFT JOIN categories AS sc ON st.category_id = sc.id")

      if raw.match?(/\A-?\d+(\.\d+)?\z/)
        amount_val = BigDecimal(raw)
        entries = entries.where(
          "entries.name LIKE ? OR entries.notes LIKE ? OR sc.name LIKE ? OR ABS(entries.amount) = ?",
          "%#{safe}%", "%#{safe}%", "%#{safe}%", amount_val
        )
      else
        search_term = "%#{safe}%"
        entries = entries.where(
          "entries.name LIKE ? OR entries.notes LIKE ? OR sc.name LIKE ?",
          search_term, search_term, search_term
        )
      end
    else
      entries
    end
  end

  def apply_transfer_filter(entries)
    if params[:exclude_transfers] == "true"
      entries.non_transfers
    else
      entries
    end
  end

  def apply_sort(entries)
    sort_direction = params[:sort_direction]&.downcase || "desc"
    sort_direction = "desc" unless sort_direction.in?(%w[asc desc])

    if sort_direction == "asc"
      entries.order(
        date: :asc,
        Arel.sql("CASE WHEN entries.entryable_type = 'Entryable::Valuation' THEN 1 ELSE 0 END") => :asc,
        sort_order: :asc,
        Arel.sql("COALESCE(entries.parent_entry_id, entries.id)") => :asc,
        Arel.sql("CASE WHEN entries.parent_entry_id IS NULL THEN 0 ELSE 1 END") => :asc,
        id: :asc
      )
    else
      entries.order(
        date: :desc,
        Arel.sql("CASE WHEN entries.entryable_type = 'Entryable::Valuation' THEN 1 ELSE 0 END") => :desc,
        sort_order: :desc,
        Arel.sql("COALESCE(entries.parent_entry_id, entries.id)") => :desc,
        Arel.sql("CASE WHEN entries.parent_entry_id IS NULL THEN 0 ELSE 1 END") => :asc,
        id: :desc
      )
    end
  end
end
