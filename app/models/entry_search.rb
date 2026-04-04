# frozen_string_literal: true

class EntrySearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :start_date, :date
  attribute :end_date, :date
  attribute :entryable_type, :string
  attribute :account_id, :integer
  attribute :category_id, :integer
  attribute :tag_id, :integer
  attribute :search, :string
  attribute :kind, :string
  
  attribute :min_amount, :decimal
  attribute :max_amount, :decimal
  
  attribute :month, :string
  attribute :period_type, :string
  attribute :period_value, :string
  
  attribute :sort, :string, default: "date_desc"
  
  attr_reader :params

  def initialize(params = {})
    @params = if params.respond_to?(:to_unsafe_h)
      params.to_unsafe_h.with_indifferent_access
    else
      params.to_h.with_indifferent_access
    end
    super(
      start_date: parse_date(@params[:start_date]),
      end_date: parse_date(@params[:end_date]),
      entryable_type: @params[:entryable_type] || @params[:type],
      account_id: parse_integer(@params[:account_id]),
      category_id: parse_integer(@params[:category_id]),
      tag_id: parse_integer(@params[:tag_id]),
      search: @params[:search]&.strip,
      kind: @params[:kind],
      min_amount: parse_decimal(@params[:min_amount]),
      max_amount: parse_decimal(@params[:max_amount]),
      month: @params[:month],
      period_type: @params[:period_type],
      period_value: @params[:period_value],
      sort: @params[:sort] || "date_desc"
    )
  end

  def build_query(scope = Entry.all)
    scope = scope.visible
    scope = apply_date_filter(scope)
    scope = apply_period_filter(scope)
    scope = apply_entryable_type_filter(scope)
    scope = apply_kind_filter(scope)
    scope = apply_account_filter(scope)
    scope = apply_category_filter(scope)
    scope = apply_tag_filter(scope)
    scope = apply_search_filter(scope)
    scope = apply_amount_filter(scope)
    apply_sort(scope)
  end

  def active_filters?
    filters_count > 0
  end

  def filters_count
    [
      start_date, end_date, entryable_type, account_id, category_id,
      tag_id, search, min_amount, max_amount, month, kind, period_type
    ].compact.count
  end

  def active_filters_list
    [].tap do |list|
      list << { key: "start_date", label: "开始日期", value: start_date&.strftime("%Y-%m-%d") } if start_date
      list << { key: "end_date", label: "结束日期", value: end_date&.strftime("%Y-%m-%d") } if end_date
      list << { key: "entryable_type", label: "类型", value: type_display } if entryable_type
      list << { key: "kind", label: "收支类型", value: kind_display } if kind
      list << { key: "account_id", label: "账户", value: account_name } if account_id
      list << { key: "category_id", label: "分类", value: category_name } if category_id
      list << { key: "tag_id", label: "标签", value: tag_name } if tag_id
      list << { key: "search", label: "关键词", value: search } if search
      list << { key: "min_amount", label: "最小金额", value: min_amount } if min_amount
      list << { key: "max_amount", label: "最大金额", value: max_amount } if max_amount
      list << { key: "month", label: "月份", value: month } if month
      list << { key: "period_type", label: "周期", value: period_type } if period_type
    end
  end

  def to_params
    params = {}
    params[:start_date] = start_date&.strftime("%Y-%m-%d") if start_date
    params[:end_date] = end_date&.strftime("%Y-%m-%d") if end_date
    params[:entryable_type] = entryable_type if entryable_type.present?
    params[:kind] = kind if kind.present?
    params[:account_id] = account_id if account_id
    params[:category_id] = category_id if category_id
    params[:tag_id] = tag_id if tag_id
    params[:search] = search if search.present?
    params[:min_amount] = min_amount if min_amount
    params[:max_amount] = max_amount if max_amount
    params[:month] = month if month.present?
    params[:period_type] = period_type if period_type.present?
    params[:period_value] = period_value if period_value.present?
    params[:sort] = sort if sort.present?
    params
  end

  def clear_filter(key)
    new_params = to_params
    new_params.delete(key.to_sym)
    new_params
  end

  private

  def apply_date_filter(scope)
    scope = scope.where("entries.date >= ?", start_date) if start_date
    scope = scope.where("entries.date <= ?", end_date) if end_date
    scope
  end

  def apply_period_filter(scope)
    date_range = PeriodFilterable.resolve_period(period_type, period_value)
    return scope unless date_range

    scope.by_date_range(date_range[0], date_range[1])
  end

  def apply_entryable_type_filter(scope)
    return scope unless entryable_type.present?
    scope.where(entryable_type: entryable_type)
  end

  def apply_kind_filter(scope)
    return scope unless kind.present?
    scope.with_entryable_transaction
         .where(entryable_transactions: { kind: kind })
  end

  def apply_category_filter(scope)
    return scope unless category_id
    scope.with_entryable_transaction
         .where(entryable_transactions: { category_id: category_id })
  end

  def apply_tag_filter(scope)
    return scope unless tag_id
    scope.joins('INNER JOIN taggings ON taggings.taggable_id = entries.entryable_id AND taggings.taggable_type = \'Entryable::Transaction\'')
         .where(taggings: { tag_id: tag_id })
  end

  def apply_account_filter(scope)
    return scope unless account_id
    scope.where(account_id: account_id)
  end

  def apply_search_filter(scope)
    return scope unless search.present?
    pattern = "%#{search}%"
    scope.where("entries.name LIKE ? OR entries.notes LIKE ?", pattern, pattern)
  end

  def apply_amount_filter(scope)
    scope = scope.where("entries.amount >= ?", min_amount) if min_amount
    scope = scope.where("entries.amount <= ?", max_amount) if max_amount
    scope
  end

  def apply_sort(scope)
    case sort
    when "date_asc"
      scope.chronological
    when "amount_desc"
      scope.order(amount: :desc)
    when "amount_asc"
      scope.order(amount: :asc)
    else
      scope.reverse_chronological
    end
  end

  def type_display
    {
      "Entryable::Transaction" => "交易",
      "Entryable::Valuation" => "估值",
      "Entryable::Trade" => "交易记录"
    }[entryable_type] || entryable_type
  end

  def kind_display
    { "income" => "收入", "expense" => "支出" }[kind] || kind
  end

  def account_name
    Account.find_by(id: account_id)&.name
  end

  def category_name
    Category.find_by(id: category_id)&.name
  end

  def tag_name
    Tag.find_by(id: tag_id)&.name
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_integer(value)
    value.to_i if value.present?
  end

  def parse_decimal(value)
    BigDecimal(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end
end