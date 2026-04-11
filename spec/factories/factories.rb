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

  factory :payable do
    description { 'Test payable' }
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

    trait :active do
      active { true }
    end

    trait :inactive do
      active { false }
    end

    trait :completed do
      type { Plan::INSTALLMENT }
      total_amount { 1200 }
      installments_total { 12 }
      installments_completed { 12 }
    end

    trait :installment do
      type { Plan::INSTALLMENT }
      total_amount { 1200 }
      installments_total { 12 }
      installments_completed { 0 }
    end

    trait :recurring do
      type { Plan::RECURRING }
    end
  end

  factory :counterparty do
    sequence(:name) { |n| "Counterparty #{n}" }
    contact { 'contact@example.com' }
    note { 'Test note' }
  end

  # ============ Entry 新模型工厂 ============
  factory :entry do
    association :account
    sequence(:name) { |n| "Entry #{n}" }
    amount { -100.50 }
    currency { 'CNY' }
    date { Date.current }
    excluded { false }
    entryable { association(:entryable_transaction) }

    trait :income do
      amount { 500.00 }
      entryable { association(:entryable_transaction, :income) }
    end

    trait :expense do
      amount { -100.50 }
      entryable { association(:entryable_transaction, :expense) }
    end

    trait :valuation do
      entryable { association(:entryable_valuation) }
    end

    trait :trade do
      entryable { association(:entryable_trade) }
    end
  end

  factory :entryable_transaction, class: 'Entryable::Transaction' do
    kind { 'expense' }
    association :category, factory: :category

    trait :income do
      kind { 'income' }
    end

    trait :expense do
      kind { 'expense' }
    end
  end

  factory :entryable_valuation, class: 'Entryable::Valuation' do
    extra { { valuation_method: 'market_price', source: 'manual' } }
  end

  factory :entryable_trade, class: 'Entryable::Trade' do
    qty { 100 }
    price { 10.5 }
    extra { { order_type: 'buy' } }
  end

  factory :single_budget do
    sequence(:name) { |n| "Single Budget #{n}" }
    start_date { Date.current }
    end_date { 30.days.from_now }
    total_amount { 5000 }
    currency { 'CNY' }
    status { 'pending' }
  end

  factory :budget_item do
    association :single_budget
    association :category, factory: :category
    amount { 1000 }
  end

  factory :backup_record do
    sequence(:filename) { |n| "backup_#{n}.sql" }
    file_path { "/tmp/#{filename}" }
    file_size { 1024 * 1024 }
    backup_type { 'manual' }
    status { 'completed' }
  end

  factory :recurring_transaction do
    association :account
    association :category
    transaction_type { 'expense' }
    amount { 100.00 }
    currency { 'CNY' }
    frequency { 'monthly' }
    next_date { Date.tomorrow }
    is_active { 1 }
    note { 'Monthly payment' }
  end
end
