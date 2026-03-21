class Category < ApplicationRecord
  self.inheritance_column = nil

  # ============ 关联 ============
  has_many :children, class_name: "Category", foreign_key: "parent_id", dependent: :destroy
  belongs_to :parent, class_name: "Category", foreign_key: "parent_id", optional: true
  has_many :transactions, dependent: :nullify
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
    left_joins(:transactions)
      .group(:id)
      .select("categories.*, COUNT(transactions.id) as transactions_count")
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

  # 所有后代
  def descendants
    children.flat_map { |child| [ child ] + child.descendants }
  end

  # 自己和所有后代
  def self_and_descendants
    [ self ] + descendants
  end

  # 交易统计
  def transactions_count
    @transactions_count ||= transactions.count
  end

  # 本月交易金额
  def monthly_amount(month = Date.current.strftime("%Y-%m"))
    transactions.for_month(month).sum(:amount)
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
    %w[parent children transactions budgets]
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

    if self_and_descendants.map(&:id).include?(parent_id)
      errors.add(:parent_id, "不能创建循环引用")
    end
  end
end
