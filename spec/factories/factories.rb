# frozen_string_literal: true

FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "Tag #{n}" }
    color { '#3498db' }
  end

  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    category_type { 'EXPENSE' }
    color { '#6b7280' }
    active { true }
    level { 0 }

    trait :income do
      category_type { 'INCOME' }
    end

    trait :expense do
      category_type { 'EXPENSE' }
    end

    trait :with_parent do
      association :parent, factory: :category
      level { parent.level + 1 }
    end
  end

  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    type { 'CASH' }
    currency { 'CNY' }
    initial_balance { 1000 }
    include_in_total { true }
    hidden { false }
  end

  factory :transaction do
    association :account
    association :category
    type { 'EXPENSE' }
    amount { 100.50 }
    date { Date.today }
    currency { 'CNY' }
    note { 'Test transaction' }
  end

  factory :budget do
    sequence(:month) { |n| "2024-#{(n % 12 + 1).to_s.rjust(2, '0')}" }
    amount { 1000 }
    association :category, factory: :category
  end

  factory :currency do
    sequence(:code) { |n| [ 'CNY', 'USD', 'EUR', 'GBP', 'JPY' ][n % 5] }
    name { [ '人民币', '美元', '欧元', '英镑', '日元' ][code[0].ord % 5] }
    symbol { [ '¥', '$', '€', '£', '¥' ][code[0].ord % 5] }
    rate { 1.0 }
    is_default { code == 'CNY' }
    is_active { true }
  end

  factory :exchange_rate do
    from_currency { 'USD' }
    to_currency { 'CNY' }
    rate { 7.2 }
    date { Date.current }
    source { 'manual' }
  end

  factory :receivable do
    description { 'Test receivable' }
    original_amount { 1000 }
    remaining_amount { 1000 }
    currency { 'CNY' }
    date { Date.current }
  end

  factory :plan do
    sequence(:name) { |n| "Plan #{n}" }
    type { Plan::RECURRING }
    amount { 100 }
    currency { 'CNY' }
    day_of_month { 15 }
    active { true }

    trait :installment do
      type { Plan::INSTALLMENT }
      total_amount { 1200 }
      installments_total { 12 }
      installments_completed { 0 }
    end

    trait :recurring do
      type { Plan::RECURRING }
    end

    trait :inactive do
      active { false }
    end
  end

  factory :counterparty do
    sequence(:name) { |n| "Counterparty #{n}" }
    contact { 'contact@example.com' }
    note { 'Test note' }
  end
end
