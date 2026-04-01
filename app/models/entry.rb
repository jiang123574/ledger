# Entry 统一模型
# 学习自 Sure: https://github.com/we-promise/sure
#
# 设计理念：
# - Entry 是所有财务记录的统一入口
# - 使用 delegated_type 支持多种类型
# - 统一的查询接口和缓存策略
# - JSONB 存储灵活元数据

class Entry < ApplicationRecord
  include Monetizable, Enrichable
  
  # Delegated Type - 学习 Sure 的设计
  delegated_type :entryable, types: Entryable::TYPES, dependent: :destroy
  accepts_nested_attributes_for :entryable, update_only: true
  
  # 关联
  belongs_to :account
  belongs_to :transfer, optional: true
  belongs_to :import, optional: true
  belongs_to :parent_entry, class_name: "Entry", optional: true
  
  has_many :child_entries, class_name: "Entry", foreign_key: :parent_entry_id, dependent: :destroy
  
  # 验证
  validates :date, :name, :amount, :currency, presence: true
  validates :date, uniqueness: { scope: [:account_id, :entryable_type] }, if: -> { valuation? }
  validates :date, comparison: { greater_than: -> { 30.years.ago.to_date } }
  validates :external_id, uniqueness: { scope: [:account_id, :source] }, 
            if: -> { external_id.present? && source.present? }
  
  # Scopes - 学习 Sure 的 scope 设计
  scope :visible, -> { joins(:account).where(accounts: { status: ['draft', 'active'] }) }
  
  scope :chronological, -> {
    order(
      date: :asc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Entryable::Valuation' THEN 1 ELSE 0 END") => :asc,
      created_at: :asc
    )
  }
  
  scope :reverse_chronological, -> {
    order(
      date: :desc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Entryable::Valuation' THEN 1 ELSE 0 END") => :desc,
      created_at: :desc
    )
  }
  
  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :by_period, ->(period_type, period_value) { Transaction.period_scope(period_type, period_value) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :excluded, -> { where(excluded: true) }
  scope :not_excluded, -> { where(excluded: false) }
  
  scope :income, -> { where(entryable_type: 'Entryable::Transaction', entryable: { kind: 'income' }) }
  scope :expense, -> { where(entryable_type: 'Entryable::Transaction', entryable: { kind: 'expense' }) }
  scope :transfers, -> { where.not(transfer_id: nil) }
  
  # 类型判断
  def transaction?
    entryable_type == 'Entryable::Transaction'
  end
  
  def valuation?
    entryable_type == 'Entryable::Valuation'
  end
  
  def trade?
    entryable_type == 'Entryable::Trade'
  end
  
  # 分类
  def classification
    amount.negative? ? 'expense' : 'income'
  end
  
  # 锁定机制 - 学习 Sure
  def lock_attribute!(attr_name)
    self.locked_attributes ||= {}
    self.locked_attributes[attr_name] = Time.current.iso8601
    save!
  end
  
  def locked?(attr_name)
    locked_attributes&.dig(attr_name).present?
  end
  
  def locked_field_names
    locked_attributes&.keys || []
  end
  
  def locked_fields_with_timestamps
    (locked_attributes || {}).transform_values do |timestamp|
      Time.zone.parse(timestamp.to_s) rescue timestamp
    end
  end
  
  # 保护机制
  def mark_user_modified!
    update!(user_modified: true)
  end
  
  def protected_from_sync?
    excluded? || user_modified? || import_locked?
  end
  
  def protection_reason
    return :excluded if excluded?
    return :user_modified if user_modified?
    return :import_locked if import_locked?
    nil
  end
  
  def unlock_for_sync!
    transaction do
      update!(user_modified: false, import_locked: false, locked_attributes: {})
      entryable&.update!(locked_attributes: {})
    end
  end
  
  # 分层交易 - 学习 Sure
  def split_parent?
    child_entries.exists?
  end
  
  def split_child?
    parent_entry_id.present?
  end
  
  def split!(splits)
    total = splits.sum { |s| s[:amount].to_d }
    unless total == amount
      raise ArgumentError, 
            "Split amounts must sum to parent amount (expected #{amount}, got #{total})"
    end
    
    transaction do
      splits.map do |split_attrs|
        child_entry = child_entries.create!(
          account: account,
          date: date,
          name: split_attrs[:name],
          amount: split_attrs[:amount],
          currency: currency,
          entryable: Entryable::Transaction.new(
            category_id: split_attrs[:category_id]
          )
        )
      end
      
      update!(excluded: true)
      mark_user_modified!
    end
  end
  
  def unsplit!
    transaction do
      child_entries.destroy_all
      update!(excluded: false)
    end
  end
  
  class << self
    # 搜索方法
    def search(params)
      EntrySearch.new(params).build_query(all)
    end
    
    # 批量更新
    def bulk_update!(bulk_update_params, update_tags: false)
      bulk_attributes = {
        date: bulk_update_params[:date],
        notes: bulk_update_params[:notes],
        entryable_attributes: {
          category_id: bulk_update_params[:category_id],
          merchant_id: bulk_update_params[:merchant_id]
        }.compact_blank
      }.compact_blank
      
      tag_ids = Array.wrap(bulk_update_params[:tag_ids]).reject(&:blank?)
      has_updates = bulk_attributes.present? || update_tags
      
      return 0 unless has_updates
      
      transaction do
        each do |entry|
          changed = false
          
          if bulk_attributes.present?
            attrs = bulk_attributes.dup
            attrs.delete(:date) if entry.split_child?
            
            if attrs.present?
              attrs[:entryable_attributes] = attrs[:entryable_attributes].dup if attrs[:entryable_attributes].present?
              attrs[:entryable_attributes][:id] = entry.entryable_id if attrs[:entryable_attributes].present?
              entry.update! attrs
              changed = true
            end
          end
          
          if update_tags && entry.transaction?
            entry.transaction.tag_ids = tag_ids
            entry.transaction.save!
            entry.entryable.lock_attr!(:tag_ids) if entry.transaction.tags.any?
            changed = true
          end
          
          if changed
            entry.lock_saved_attributes!
            entry.mark_user_modified!
          end
        end
      end
      
      size
    end
    
    # 最小支持日期
    def min_supported_date
      30.years.ago.to_date
    end
  end
end