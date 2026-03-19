class Plan < ApplicationRecord
  self.inheritance_column = nil

  belongs_to :account, class_name: "Account", optional: true

  validates :name, :amount, presence: true
  validates :day_of_month, inclusion: { in: 1..31 }

  scope :active, -> { where(active: true) }

  def active?
    active == true || active == 1
  end

  def installments_remaining
    installments_total - installments_completed
  end
end
