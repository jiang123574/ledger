# frozen_string_literal: true

class TransactionSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  # 基础筛选
  attribute :start_date, :date
  attribute :end_date, :date
  attribute :type, :string
  attribute :account_id, :integer
  attribute :category_id, :integer
  attribute :tag_id, :integer
  attribute :search, :string

  # 金额范围
  attribute :min_amount, :decimal
  attribute :max_amount, :decimal

  # 月份快捷筛选
  attribute :month, :string

  # 排序
  attribute :sort, :string, default: "date_desc"

  # 筛选条件存储
  attr_reader :params

  def initialize(params = {})
    @params = params.to_h.with_indifferent_access
    super(
      start_date: parse_date(@params[:start_date]),
      end_date: parse_date(@params[:end_date]),
      type: @params[:type],
      account_id: parse_integer(@params[:account_id]),
      category_id: parse_integer(@params[:category_id]),
      tag_id: parse_integer(@params[:tag_id]),
      search: @params[:search]&.strip,
      min_amount: parse_decimal(@params[:min_amount]),
      max_amount: parse_decimal(@params[:max_amount]),
      month: @params[:month],
      sort: @params[:sort] || "date_desc"
    )
  end

  def apply(scope)
    scope = apply_date_filter(scope)
    scope = apply_month_filter(scope)
    scope = apply_type_filter(scope)
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
      start_date, end_date, type, account_id, category_id,
      tag_id, search, min_amount, max_amount, month
    ].compact.count
  end

  def active_filters_list
    [].tap do |list|
      list << { key: "start_date", label: "开始日期", value: start_date&.strftime("%Y-%m-%d") } if start_date
      list << { key: "end_date", label: "结束日期", value: end_date&.strftime("%Y-%m-%d") } if end_date
      list << { key: "type", label: "类型", value: type_display } if type
      list << { key: "account_id", label: "账户", value: account_name } if account_id
      list << { key: "category_id", label: "分类", value: category_name } if category_id
      list << { key: "tag_id", label: "标签", value: tag_name } if tag_id
      list << { key: "search", label: "关键词", value: search } if search
      list << { key: "min_amount", label: "最小金额", value: min_amount } if min_amount
      list << { key: "max_amount", label: "最大金额", value: max_amount } if max_amount
      list << { key: "month", label: "月份", value: month } if month
    end
  end

  def to_params
    params = {}
    params[:start_date] = start_date&.strftime("%Y-%m-%d") if start_date
    params[:end_date] = end_date&.strftime("%Y-%m-%d") if end_date
    params[:type] = type if type.present?
    params[:account_id] = account_id if account_id
    params[:category_id] = category_id if category_id
    params[:tag_id] = tag_id if tag_id
    params[:search] = search if search.present?
    params[:min_amount] = min_amount if min_amount
    params[:max_amount] = max_amount if max_amount
    params[:month] = month if month.present?
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
    scope = scope.where("date >= ?", start_date) if start_date
    scope = scope.where("date <= ?", end_date) if end_date
    scope
  end

  def apply_month_filter(scope)
    return scope unless month.present?
    start = Date.parse("#{month}-01")
    send = start.end_of_month
    scope.where(date: start..send)
  end

  def apply_type_filter(scope)
    return scope unless type.present?
    scope.where(type: type)
  end

  def apply_account_filter(scope)
    return scope unless account_id
    scope.where(account_id: account_id)
  end

  def apply_category_filter(scope)
    return scope unless category_id
    scope.where(category_id: category_id)
  end

  def apply_tag_filter(scope)
    return scope unless tag_id
    scope.joins(:transaction_tags).where(transaction_tags: { tag_id: tag_id })
  end

  def apply_search_filter(scope)
    return scope unless search.present?
    pattern = "%#{search}%"
    scope.where("note LIKE ? OR category LIKE ?", pattern, pattern)
  end

  def apply_amount_filter(scope)
    scope = scope.where("amount >= ?", min_amount) if min_amount
    scope = scope.where("amount <= ?", max_amount) if max_amount
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
    else # date_desc
      scope.reverse_chronological
    end
  end

  def type_display
    {
      "INCOME" => "收入",
      "EXPENSE" => "支出",
      "TRANSFER" => "转账",
      "ADVANCE" => "预支",
      "REIMBURSE" => "报销"
    }[type] || type
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
