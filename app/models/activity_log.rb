# frozen_string_literal: true

class ActivityLog < ApplicationRecord
  belongs_to :item, polymorphic: true

  ACTIONS = %w[create update destroy].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :item_type, presence: true
  validates :item_id, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_item, ->(item) { where(item: item) }
  scope :by_action, ->(action) { where(action: action) }

  # 获取变更摘要
  def changes_summary
    return nil unless changes.present?
    
    parsed = changes.is_a?(String) ? JSON.parse(changes) : changes
    
    parsed.map do |field, values|
      next if field.in?(%w[updated_at created_at])
      
      old_val, new_val = values
      "#{field}: #{old_val} → #{new_val}"
    end.compact.join(", ")
  end

  # 恢复到这个版本
  def revert!
    return false if action == 'create'
    
    item_class = item_type.constantize
    record = item_class.find_by(id: item_id)
    
    case action
    when 'update'
      return false unless changes.present?
      
      parsed = changes.is_a?(String) ? JSON.parse(changes) : changes
      
      parsed.each do |field, (old_val, _new_val)|
        next if field.in?(%w[updated_at created_at])
        
        record&.update(field => old_val)
      end
      
    when 'destroy'
      # 从 changes 中恢复记录
      return false unless changes.present?
      
      parsed = changes.is_a?(String) ? JSON.parse(changes) : changes
      
      record = item_class.new(parsed.except('id', 'created_at', 'updated_at'))
      record.save(validate: false)
    end
    
    record
  end

  class << self
    # 记录创建操作
    def log_create(item, whodunnit: nil, ip_address: nil, description: nil)
      create!(
        item: item,
        action: 'create',
        changes: item.attributes.to_json,
        whodunnit: whodunnit,
        ip_address: ip_address,
        description: description || "创建 #{item.class.name}"
      )
    end

    # 记录更新操作
    def log_update(item, whodunnit: nil, ip_address: nil, description: nil)
      return unless item.saved_changes.present?
      
      filtered_changes = item.saved_changes.except('updated_at', 'created_at')
      return if filtered_changes.empty?
      
      create!(
        item: item,
        action: 'update',
        changes: filtered_changes.to_json,
        whodunnit: whodunnit,
        ip_address: ip_address,
        description: description || generate_update_description(filtered_changes)
      )
    end

    # 记录删除操作
    def log_destroy(item, whodunnit: nil, ip_address: nil, description: nil)
      create!(
        item: item,
        action: 'destroy',
        changes: item.attributes.to_json,
        whodunnit: whodunnit,
        ip_address: ip_address,
        description: description || "删除 #{item.class.name}"
      )
    end

    private

    def generate_update_description(changes)
      fields = changes.keys.reject { |k| k.in?(%w[updated_at created_at]) }
      "更新字段: #{fields.join(', ')}"
    end
  end
end