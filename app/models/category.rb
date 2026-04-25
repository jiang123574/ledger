class Category < ApplicationRecord
  self.inheritance_column = nil

  # 数据库列名是 type，但模型使用 category_type
  alias_attribute :category_type, :type

  # ============ 关联 ============
  has_many :children, -> { order(:sort_order, :name) }, class_name: "Category", foreign_key: "parent_id", dependent: :destroy
  belongs_to :parent, class_name: "Category", foreign_key: "parent_id", optional: true
  has_many :entryable_transactions, class_name: "Entryable::Transaction", foreign_key: "category_id", dependent: :nullify
  has_many :entries, through: :entryable_transactions, source: :entry
  has_many :budgets, dependent: :nullify
  has_many :one_time_budgets, dependent: :nullify
  has_many :recurring_transactions, dependent: :nullify

  # ============ 验证 ============
  validates :name, presence: true, length: { maximum: 100 }
  validates :name, uniqueness: { scope: :parent_id }
  validate :no_circular_reference

  # ============ Scopes ============
  scope :alphabetically, -> { order(:name) }
  scope :by_sort_order, -> { order(:sort_order, :name) }
  scope :roots, -> { where(parent_id: nil) }
  scope :expense, -> { where(category_type: "EXPENSE") }
  scope :income, -> { where(category_type: "INCOME") }
  scope :active, -> { where(active: true) }
  scope :with_transaction_counts, -> {
    left_joins(:entries)
      .group(:id)
      .select("categories.*, COUNT(entries.id) as transactions_count")
  }

  # ============ 回调 ============
  before_validation :set_defaults
  before_save :update_level

  # ============ 类型方法 ============
  def expense?
    category_type == "EXPENSE"
  end

  def income?
    category_type == "INCOME"
  end

  def root?
    parent_id.nil?
  end

  def leaf?
    children.empty?
  end

  def depth
    level || 0
  end

  # 完整路径名称
  def full_name(separator: " > ")
    parent ? "#{parent.full_name(separator: separator)}#{separator}#{name}" : name
  end

  # 所有祖先
  def ancestors
    parent ? [ parent ] + parent.ancestors : []
  end

  # 所有后代（实例方法，递归加载）
  def descendants
    children.flat_map { |child| [ child ] + child.descendants }
  end

  # 自己和所有后代
  def self_and_descendants
    [ self ] + descendants
  end

  # 批量获取后代 ID（单次 SQL，避免递归 N+1）
  # 用于预算验证等需要快速检查的场景
  def self_and_descendant_ids
    [ id ] + Category.where(parent_id: id).pluck(:id)
  end

  # 类方法：给定一批 category IDs，获取它们及其所有后代的 IDs（单次递归 CTE 查询）
  def self.descendant_ids_for(category_ids)
    return [] if category_ids.blank?
    return [] if category_ids.all?(&:blank?)

    ids = category_ids.compact_blank
    return [] if ids.empty?

    sql = <<~SQL
      WITH RECURSIVE cat_tree AS (
        SELECT id FROM categories WHERE id IN (#{ids.join(',')})
        UNION
        SELECT c.id FROM categories c
        INNER JOIN cat_tree ct ON c.parent_id = ct.id
      )
      SELECT id FROM cat_tree
    SQL

    ActiveRecord::Base.connection.execute(sql).map { |row| row["id"].to_i }
  end

  # 类方法：给定一批 category IDs，获取它们及其所有祖先的 IDs（单次递归 CTE 查询）
  def self.ancestor_ids_for(category_ids)
    return [] if category_ids.blank?
    return [] if category_ids.all?(&:blank?)

    ids = category_ids.compact_blank
    return [] if ids.empty?

    sql = <<~SQL
      WITH RECURSIVE cat_tree AS (
        SELECT id, parent_id FROM categories WHERE id IN (#{ids.join(',')})
        UNION
        SELECT c.id, c.parent_id FROM categories c
        INNER JOIN cat_tree ct ON c.id = ct.parent_id
      )
      SELECT id FROM cat_tree WHERE id NOT IN (#{ids.join(',')})
    SQL

    ActiveRecord::Base.connection.execute(sql).map { |row| row["id"].to_i }
  end

  # 交易统计
  def transactions_count
    @transactions_count ||= entries.count
  end

  # 本月交易金额
  def monthly_amount(month = Date.current.strftime("%Y-%m"))
    start_date = Date.parse("#{month}-01")
    end_date = start_date.end_of_month

    entries.where(date: start_date..end_date)
      .sum("CASE WHEN entryable_transactions.kind = 'expense' THEN entries.amount * -1 ELSE entries.amount END")
  end

  # 预算进度
  def budget_progress(month = Date.current.strftime("%Y-%m"))
    budget = budgets.find_by(month: month)
    return nil unless budget

    spent = monthly_amount(month)
    {
      budget: budget.amount,
      spent: spent,
      remaining: budget.amount - spent,
      percentage: (spent / budget.amount * 100).round(1)
    }
  end

  # ============ Ransack ============
  def self.ransackable_attributes(auth_object = nil)
    %w[name category_type color icon parent_id sort_order active level created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[parent children entries budgets]
  end

  private

  def set_defaults
    self.category_type ||= "EXPENSE"
    self.sort_order ||= 0
    self.active = true if active.nil?
  end

  def update_level
    self.level = parent ? parent.level + 1 : 0
  end

  def no_circular_reference
    return unless parent_id_changed? && parent_id.present?
    return unless id.present?

    if Category.descendant_ids_for([ id ]).include?(parent_id)
      errors.add(:parent_id, "不能创建循环引用")
    end
  end
end
