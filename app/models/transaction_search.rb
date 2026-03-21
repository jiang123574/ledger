# frozen_string_literal: true

class TransactionSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :start_date, :date
  attribute :end_date, :date
  attribute :type, :string
  attribute :account_id, :integer
  attribute :category_id, :integer
  attribute :search, :string

  def initialize(params = {})
    @params = params
    super(
      start_date: parse_date(params[:start_date]),
      end_date: parse_date(params[:end_date]),
      type: params[:type],
      account_id: params[:account_id],
      category_id: params[:category_id],
      search: params[:search]
    )
  end

  def apply(scope)
    scope = scope.where(date: start_date..end_date) if start_date.present? && end_date.present?
    scope = scope.where(type: type) if type.present?
    scope = scope.where(account_id: account_id) if account_id.present?
    scope = scope.where(category_id: category_id) if category_id.present?
    scope = scope.where("note LIKE ?", "%#{search}%") if search.present?
    scope
  end

  def active_filters?
    start_date.present? || end_date.present? || type.present? || account_id.present? || category_id.present? || search.present?
  end

  def to_params
    params = {}
    params[:start_date] = start_date if start_date.present?
    params[:end_date] = end_date if end_date.present?
    params[:type] = type if type.present?
    params[:account_id] = account_id if account_id.present?
    params[:category_id] = category_id if category_id.present?
    params[:search] = search if search.present?
    params
  end

  private

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value)
  rescue ArgumentError
    nil
  end
end
