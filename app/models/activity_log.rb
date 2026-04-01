# frozen_string_literal: true

class ActivityLog < ApplicationRecord
  belongs_to :item, polymorphic: true

  ACTIONS = %w[create update destroy].freeze
  SENSITIVE_FIELDS = %w[password encrypted_password token api_key secret].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :item_type, presence: true
  validates :item_id, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_item, ->(item) { where(item: item) }
  scope :by_action, ->(action) { where(action: action) }

  def changes_summary
    return nil unless changeset.present?
    
    parsed = changeset.is_a?(String) ? JSON.parse(changeset) : changeset
    
    parsed.map do |field, values|
      next if field.in?(%w[updated_at created_at])
      
      old_val, new_val = values
      "#{field}: #{old_val} → #{new_val}"
    end.compact.join(", ")
  end

  def revert!
    return false if action == 'create'
    
    item_class = item_type.constantize
    record = item_class.find_by(id: item_id)
    
    case action
    when 'update'
      return false unless changeset.present?
      
      parsed = changeset.is_a?(String) ? JSON.parse(changeset) : changeset
      
      parsed.each do |field, (old_val, _new_val)|
        next if field.in?(%w[updated_at created_at])
        
        record&.update(field => old_val)
      end
      
    when 'destroy'
      return false unless changeset.present?
      
      parsed = changeset.is_a?(String) ? JSON.parse(changeset) : changeset
      
      record = item_class.new(parsed.except('created_at', 'updated_at'))
      record.id = parsed['id']
      record.save(validate: false)
      
      update!(item_id: record.id) if record.persisted?
    end
    
    record
  end

  class << self
    def log_create(item, whodunnit: nil, ip_address: nil, description: nil)
      attrs = filter_sensitive_fields(item.attributes)
      
      create!(
        item: item,
        action: 'create',
        changeset: attrs.to_json,
        whodunnit: whodunnit,
        ip_address: ip_address,
        description: description || "创建 #{item.class.name}"
      )
    end

    def log_update(item, whodunnit: nil, ip_address: nil, description: nil)
      return unless item.saved_changes.present?
      
      filtered_changes = item.saved_changes.except('updated_at', 'created_at')
      filtered_changes = filter_sensitive_fields_from_changes(filtered_changes)
      return if filtered_changes.empty?
      
      create!(
        item: item,
        action: 'update',
        changeset: filtered_changes.to_json,
        whodunnit: whodunnit,
        ip_address: ip_address,
        description: description || generate_update_description(filtered_changes)
      )
    end

    def log_destroy(item, whodunnit: nil, ip_address: nil, description: nil)
      attrs = filter_sensitive_fields(item.attributes)
      
      create!(
        item: item,
        action: 'destroy',
        changeset: attrs.to_json,
        whodunnit: whodunnit,
        ip_address: ip_address,
        description: description || "删除 #{item.class.name}"
      )
    end

    private

    def filter_sensitive_fields(attributes)
      attributes.except(*SENSITIVE_FIELDS)
    end

    def filter_sensitive_fields_from_changes(changes)
      changes.except(*SENSITIVE_FIELDS)
    end

    def generate_update_description(changes)
      fields = changes.keys.reject { |k| k.in?(%w[updated_at created_at]) }
      "更新字段: #{fields.join(', ')}"
    end
  end
end