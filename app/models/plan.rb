class Plan < ApplicationRecord
  self.inheritance_column = nil

  # Types
  INSTALLMENT = "INSTALLMENT"
  RECURRING = "RECURRING"
  ONE_TIME = "ONE_TIME"

  TYPES = [ INSTALLMENT, RECURRING, ONE_TIME ].freeze

  belongs_to :account, class_name: "Account", optional: true

  validates :name, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :day_of_month, inclusion: { in: 1..31 }
  validates :type, inclusion: { in: TYPES }, allow_nil: true
  validates :installments_total, numericality: { greater_than: 0 }, if: -> { type == INSTALLMENT }
  validates :total_amount, presence: true, if: -> { type == INSTALLMENT }

  scope :active, -> { where(active: true) }
  scope :installment, -> { where(type: INSTALLMENT) }
  scope :recurring, -> { where(type: RECURRING) }

  def active?
    active == true || active == 1
  end

  def installments_remaining
    return 0 unless type == INSTALLMENT
    installments_total - installments_completed
  end

  def completed?
    type == INSTALLMENT && installments_completed >= installments_total
  end

  def progress_percentage
    return 100 if completed?
    return 0 unless type == INSTALLMENT && installments_total.positive?
    (installments_completed.to_f / installments_total * 100).round(1)
  end

  def next_due_date
    return nil unless active?
    
    today = Date.current
    next_month = today.next_month
    
    # Calculate next due date based on day_of_month
    if today.day < day_of_month
      Date.new(today.year, today.month, day_of_month)
    else
      Date.new(next_month.year, next_month.month, [ day_of_month, Date.civil(next_month.year, next_month.month, -1).day ].min)
    end
  end

  def generate_transaction!
    return nil unless active? && account.present?
    return nil if type == INSTALLMENT && completed?

    transaction = Transaction.create!(
      account: account,
      amount: amount,
      currency: currency || "CNY",
      type: "EXPENSE",
      category: "计划还款",
      note: "#{name} (#{installments_completed + 1}/#{installments_total})",
      date: Date.current
    )

    if type == INSTALLMENT
      increment!(:installments_completed)
      update!(active: false) if completed?
    end

    update!(last_generated: Time.current)
    transaction
  end

  class << self
    def generate_all_due!
      active.find_each do |plan|
        next unless plan.next_due_date == Date.current
        
        begin
          plan.generate_transaction!
        rescue => e
          Rails.logger.error("Failed to generate plan #{plan.id}: #{e.message}")
        end
      end
    end
  end
end