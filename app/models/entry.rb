# Entry 统一模型
# 学习自 Sure: https://github.com/we-promise/sure
#
# 设计理念：
# - Entry 是所有财务记录的统一入口
# - 使用 delegated_type 支持多种类型
# - 统一的查询接口和缓存策略
# - JSONB 存储灵活元数据

class Entry < ApplicationRecord
  include Monetizable
  
  # 操作记录 - 创建、更新、删除时自动记录
  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity
  
  delegated_type :entryable, types: Entryable::TYPES, dependent: :destroy
  accepts_nested_attributes_for :entryable, update_only: true
  
  belongs_to :account
  belongs_to :transfer, optional: true
  belongs_to :import, optional: true
  belongs_to :parent_entry, class_name: "Entry", optional: true
  
  has_many :child_entries, class_name: "Entry", foreign_key: :parent_entry_id, dependent: :destroy
  
  validates :date, :name, :amount, :currency, presence: true
  validates :date, uniqueness: { scope: [:account_id, :entryable_type] }, if: -> { valuation? }
  validates :date, comparison: { greater_than: -> { 30.years.ago.to_date } }
  validates :external_id, uniqueness: { scope: [:account_id, :source] }, 
            if: -> { external_id.present? && source.present? }
  
  scope :visible, -> { joins(:account).where(accounts: { hidden: false }) }

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
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :excluded, -> { where(excluded: true) }
  scope :not_excluded, -> { where(excluded: false) }
  scope :transfers, -> { where.not(transfer_id: nil) }

  # Entryable::Transaction JOIN scopes - 避免在多处硬编码 SQL
  scope :with_entryable_transaction, -> {
    joins('INNER JOIN entryable_transactions ON entries.entryable_id = entryable_transactions.id')
  }

  scope :with_category, -> {
    with_entryable_transaction
      .joins('INNER JOIN categories ON entryable_transactions.category_id = categories.id')
  }

  scope :transactions_only, -> {
    where(entryable_type: 'Entryable::Transaction')
  }

  scope :non_transfers, -> {
    where("transfer_id IS NULL")
  }

  scope :expenses, -> {
    transactions_only.non_transfers.with_entryable_transaction
      .where(entryable_transactions: { kind: 'expense' })
  }

  scope :incomes, -> {
    transactions_only.non_transfers
      .where('amount > 0')
  }
  
  def transaction?
    entryable_type == 'Entryable::Transaction'
  end
  
  def valuation?
    entryable_type == 'Entryable::Valuation'
  end
  
  def trade?
    entryable_type == 'Entryable::Trade'
  end
  
  def classification
    amount.negative? ? 'expense' : 'income'
  end
  
  def lock_attribute!(attr_name)
    self.locked_attributes ||= {}
    self.locked_attributes[attr_name] = Time.current.iso8601
    save!
  end
  
  def locked?(attr_name)
    locked_attributes&.dig(attr_name.to_s).present?
  end
  
  def locked_field_names
    locked_attributes&.keys || []
  end
  
  def locked_fields_with_timestamps
    (locked_attributes || {}).transform_values do |timestamp|
      Time.zone.parse(timestamp.to_s) rescue timestamp
    end
  end
  
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
    def search(params)
      EntrySearch.new(params).build_query(all)
    end
    
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
    
    def min_supported_date
      30.years.ago.to_date
    end
  end

  private

  def log_create_activity
    ActivityLog.log_create(
      self,
      description: "创建交易: #{name} #{amount}元"
    )
  end

  def log_update_activity
    ActivityLog.log_update(
      self,
      description: "更新交易: #{name}"
    )
  end

  def log_destroy_activity
    ActivityLog.log_destroy(
      self,
      description: "删除交易: #{name} #{amount}元"
    )
  end
end