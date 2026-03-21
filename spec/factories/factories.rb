# frozen_string_literal: true

FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "Tag #{n}" }
    color { '#3498db' }
  end

  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    type { 'EXPENSE' }
    color { '#6b7280' }
    active { true }
    level { 0 }
    
    trait :income do
      type { 'INCOME' }
    end
    
    trait :expense do
      type { 'EXPENSE' }
    end
    
    trait :with_parent do
      association :parent, factory: :category
      level { parent.level + 1 }
    end
  end

  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    account_type { 'CHECKING' }
    currency { 'CNY' }
    initial_balance { 1000 }
  end

  factory :transaction do
    association :account
    association :category
    type { 'EXPENSE' }
    amount { 100.50 }
    date { Date.today }
    note { 'Test transaction' }
  end
end