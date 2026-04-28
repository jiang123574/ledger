# frozen_string_literal: true

class OperationLog < ApplicationRecord
  belongs_to :item, polymorphic: true

  # 操作类型扩展：支持更多操作
  ACTIONS = %w[create update destroy settle revert execute import export backup restore].freeze
  SENSITIVE_FIELDS = %w[password encrypted_password token api_key secret].freeze
  SENSITIVE_PARAMS = %w[password password_confirmation auth_token api_key secret csrf_token].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :item_type, presence: true
  validates :item_id, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_item, ->(item) { where(item: item) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_item_type, ->(type) { where(item_type: type) }

  def changes_summary
    return nil unless changeset.present?

    parsed = changeset.is_a?(String) ? JSON.parse(changeset) : changeset

    parsed.map do |field, values|
      next if field.in?(%w[updated_at created_at id])

      if values.is_a?(Array)
        old_val, new_val = values
        "#{field}: #{old_val} → #{new_val}"
      else
        "#{field}: #{values}"
      end
    end.compact.join(", ")
  end

  def request_info
    parts = []
    parts << "#{request_method} #{request_path}" if request_method && request_path
    parts << "UA: #{user_agent[0..50]}..." if user_agent
    parts.join(" | ")
  end

  class << self
    # 记录创建操作
    def log_create(item, request: nil, description: nil)
      attrs = filter_sensitive_fields(item.attributes)

      create!(
        item: item,
        action: "create",
        changeset: attrs.to_json,
        description: description || "创建 #{item.class.model_name.human}",
        **extract_request_info(request)
      )
    end

    # 记录更新操作
    def log_update(item, request: nil, description: nil)
      return unless item.saved_changes.present?

      filtered_changes = item.saved_changes.except("updated_at", "created_at")
      filtered_changes = filter_sensitive_fields_from_changes(filtered_changes)
      return if filtered_changes.empty?

      create!(
        item: item,
        action: "update",
        changeset: filtered_changes.to_json,
        description: description || generate_update_description(item, filtered_changes),
        **extract_request_info(request)
      )
    end

    # 记录删除操作
    def log_destroy(item, request: nil, description: nil)
      attrs = filter_sensitive_fields(item.attributes)

      create!(
        item: item,
        action: "destroy",
        changeset: attrs.to_json,
        description: description || "删除 #{item.class.model_name.human}",
        **extract_request_info(request)
      )
    end

    # 记录结算操作（应收/应付）
    def log_settle(item, amount: nil, account: nil, request: nil, description: nil)
      data = {
        amount: amount,
        account_id: account&.id,
        account_name: account&.name,
        remaining: item.remaining_amount,
        settled_at: item.settled_at
      }

      create!(
        item: item,
        action: "settle",
        changeset: data.to_json,
        description: description || "结算 #{item.class.model_name.human}: #{data[:description]}",
        **extract_request_info(request)
      )
    end

    # 记录撤销操作
    def log_revert(item, request: nil, description: nil)
      create!(
        item: item,
        action: "revert",
        changeset: { reverted_to: item.attributes_before_revert }.to_json,
        description: description || "撤销 #{item.class.model_name.human} 操作",
        **extract_request_info(request)
      )
    end

    # 记录执行操作（计划/周期交易）
    def log_execute(item, result: nil, request: nil, description: nil)
      data = {
        executed_at: Time.current,
        result_type: result&.class&.name,
        result_id: result&.id
      }

      create!(
        item: item,
        action: "execute",
        changeset: data.to_json,
        description: description || "执行 #{item.class.model_name.human}",
        **extract_request_info(request)
      )
    end

    # 记录导入操作
    def log_import(item_type:, count: nil, source: nil, request: nil, description: nil)
      create!(
        item_type: item_type,
        item_id: 0,
        action: "import",
        changeset: { count: count, source: source }.to_json,
        description: description || "导入 #{count} 条 #{item_type}",
        **extract_request_info(request)
      )
    end

    private

    def extract_request_info(request)
      return {} unless request

      {
        request_path: request.path,
        request_method: request.method,
        request_params: filter_params(request.params),
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      }
    end

    def filter_params(params)
      return nil unless params

      # 只保留有用的参数，过滤敏感信息和无关数据
      filtered = params.to_h.deep_dup

      # 移除敏感字段
      SENSITIVE_PARAMS.each { |key| filtered.delete(key) }

      # 移除 Rails 内部参数
      %w[controller action format utf8 authenticity_token commit].each { |key| filtered.delete(key) }

      # 如果过滤后为空，返回 nil
      filtered.blank? ? nil : filtered
    end

    def filter_sensitive_fields(attributes)
      attributes.except(*SENSITIVE_FIELDS)
    end

    def filter_sensitive_fields_from_changes(changes)
      changes.except(*SENSITIVE_FIELDS)
    end

    def generate_update_description(item, changes)
      fields = changes.keys.reject { |k| k.in?(%w[updated_at created_at]) }
      "#{item.class.model_name.human} 更新: #{fields.join(', ')}"
    end
  end
end