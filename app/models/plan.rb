class Plan < ApplicationRecord
  self.inheritance_column = nil

  # Types
  INSTALLMENT = "INSTALLMENT"
  MORTGAGE = "MORTGAGE"
  RECURRING = "RECURRING"
  ONE_TIME = "ONE_TIME"

  TYPES = [ INSTALLMENT, MORTGAGE, RECURRING, ONE_TIME ].freeze

  belongs_to :account, class_name: "Account", optional: true
  belongs_to :category, optional: true

  validates :name, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :day_of_month, inclusion: { in: 1..31 }
  validates :type, inclusion: { in: TYPES }, allow_nil: true
  validates :installments_total, numericality: { greater_than: 0 }, if: :installment_like?
  validates :total_amount, presence: true, if: :installment_like?

  scope :active, -> { where(active: true) }
  scope :installment, -> { where(type: INSTALLMENT) }
  scope :mortgage, -> { where(type: MORTGAGE) }
  scope :recurring, -> { where(type: RECURRING) }

  def active?
    active == true || active == 1
  end

  def installments_remaining
    return 0 unless installment_like?
    installments_total - installments_completed
  end

  def completed?
    installment_like? && installments_completed >= installments_total
  end

  def progress_percentage
    return 100 if completed?
    return 0 unless installment_like? && installments_total.positive?
    (installments_completed.to_f / installments_total * 100).round(1)
  end

  def next_due_date
    return nil unless active?

    today = Date.current

    # 如果本月已经执行过，跳过到下个月
    if last_generated.present?
      last_gen_date = last_generated.to_date
      if last_gen_date.month == today.month && last_gen_date.year == today.year
        next_month = today.next_month
        max_day_next_month = Date.civil(next_month.year, next_month.month, -1).day
        actual_day_next_month = [ day_of_month, max_day_next_month ].min
        return Date.new(next_month.year, next_month.month, actual_day_next_month)
      end
    end

    # If today is the due day, return today
    if today.day == day_of_month
      return today
    end

    next_month = today.next_month

    # Calculate next due date based on day_of_month
    # Handle case where day_of_month exceeds month's max days
    max_day_this_month = Date.civil(today.year, today.month, -1).day
    actual_day_this_month = [ day_of_month, max_day_this_month ].min

    if today.day < actual_day_this_month
      Date.new(today.year, today.month, actual_day_this_month)
    else
      max_day_next_month = Date.civil(next_month.year, next_month.month, -1).day
      actual_day_next_month = [ day_of_month, max_day_next_month ].min
      Date.new(next_month.year, next_month.month, actual_day_next_month)
    end
  end

  def generate_transaction!
    return nil unless active? && account.present?
    return nil if installment_like? && completed?

    # 检查当天是否已有相同金额的交易（避免重复执行）
    today = Date.current
    existing = account.entries.where(date: today, amount: -amount.to_d).first
    if existing
      Rails.logger.info("Skipping plan #{id}: transaction with same amount already exists for #{today}")
      return nil
    end

    ApplicationRecord.transaction do
      entry = create_entry(
        account: account,
        amount: -amount.to_d,  # Plan 默认是支出，金额为负
        currency: currency || default_currency,
        date: Date.current,
        name: transaction_note,
        kind: "expense",
        category: category || find_or_create_default_category
      )

      if installment_like?
        increment!(:installments_completed)
        update!(active: false) if completed?
      end

      update!(last_generated: Time.current)
      entry
    end
  end

  private

  def create_entry(account:, amount:, currency:, date:, name:, kind:, category:)
    entryable = Entryable::Transaction.new(
      kind: kind,
      category_id: category&.id
    )
    entryable.save(validate: false)

    Entry.create!(
      account_id: account.id,
      date: date,
      name: name,
      amount: amount,
      currency: currency,
      entryable: entryable
    )
  end

  def default_currency
    "CNY"
  end

  def transaction_type
    "EXPENSE"
  end

  def transaction_note
    return name unless installment_like?

    I18n.t("plans.installment_note", name: name, current: installments_completed + 1, total: installments_total)
  end

  def installment_like?
    [ INSTALLMENT, MORTGAGE ].include?(type)
  end

  def find_or_create_default_category
    Category.find_or_create_by(name: I18n.t("plans.default_category"), category_type: "EXPENSE") do |c|
      c.active = true if c.active.nil?
    end
  end

  class << self
    def generate_all_due!
      active.find_each do |plan|
        next unless plan.next_due_date == Date.current
        next if plan.last_generated&.to_date == Date.current

        begin
          plan.generate_transaction!
        rescue StandardError => e
          Rails.logger.error("Failed to generate plan #{plan.id}: #{e.message}\n#{e.backtrace.first(3).join("\n")}")
        end
      end
    end
  end
end
