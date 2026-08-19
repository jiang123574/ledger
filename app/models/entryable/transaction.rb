# Entryable::Transaction - 具体交易实现
# 这是原 Transaction 模型的新实现

class Entryable::Transaction < ApplicationRecord
  include Entryable

  self.table_name = "entryable_transactions"

  belongs_to :category, class_name: "::Category", optional: true

  has_many :taggings, as: :taggable, class_name: "::Tagging", dependent: :destroy
  has_many :tags, through: :taggings

  # 退款相关
  scope :refunds, -> { where(is_refund: true) }
  scope :non_refunds, -> { where(is_refund: false) }

  # 退款关联（可选）
  belongs_to :refund_of_entry, class_name: "Entry", optional: true

  store_accessor :extra, :provider_data, :sync_status, :enrichment_data

  after_initialize :set_defaults, if: :new_record?

  def kind
    super || "expense"
  end

  def set_defaults
    self.locked_attributes ||= {}
    self.extra ||= {}
  end

  def income?
    kind == "income"
  end

  def expense?
    kind == "expense"
  end

  def refund?
    is_refund?
  end

  def buyer_refund?
    kind == "expense" && is_refund?
  end

  def seller_refund?
    kind == "income" && is_refund?
  end

  def tag_list=(tag_names)
    self.tags = tag_names.map do |name|
      Tag.find_or_create_by(name: name.strip)
    end
  end

  def tag_list
    tags.pluck(:name)
  end

  def lock_saved_attributes!
    lock_attr!(:category_id) if category_id.present?
    lock_attr!(:tag_ids) if tags.any?
  end

  def self.by_category_stats(account_id: nil, period_type: "month")
    query = joins(:entry).where.not(category_id: nil)
    query = query.where(entries: { account_id: account_id }) if account_id.present?

    query.joins(:category)
         .group("categories.name", "categories.id")
         .order("SUM(entries.amount) DESC")
         .select(
           "categories.id as category_id",
           "categories.name as category_name",
           "SUM(entries.amount) as total_amount",
           "COUNT(*) as count"
         )
  end
end
