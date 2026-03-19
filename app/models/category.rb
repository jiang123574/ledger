class Category < ApplicationRecord
  self.inheritance_column = nil

  has_many :children, class_name: "Category", foreign_key: "parent_id", dependent: :destroy
  belongs_to :parent, class_name: "Category", foreign_key: "parent_id", optional: true
  has_many :transactions, dependent: :nullify
  has_many :budgets, dependent: :nullify
  has_many :one_time_budgets, dependent: :nullify
  has_many :recurring_transactions, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :expense, -> { where(category_type: "EXPENSE") }
  scope :income, -> { where(category_type: "INCOME") }

  def full_name
    parent ? "#{parent.name} > #{name}" : name
  end
end
