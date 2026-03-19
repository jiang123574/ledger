class OneTimeBudget < ApplicationRecord
  belongs_to :category, class_name: "Category", optional: true

  validates :name, :amount, :start_date, presence: true

  scope :active, -> { where(status: "active") }
  scope :current, -> { where("start_date <= ? AND (end_date IS NULL OR end_date >= ?)", Time.current, Time.current) }

  def expired?
    end_date.present? && end_date < Time.current
  end
end
