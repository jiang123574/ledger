puts "Seeding database..."

Account.create!(
  name: "Cash",
  type: "CASH",
  initial_balance: 0.00,
  currency: "CNY"
)

Account.create!(
  name: "Bank Card",
  type: "BANK",
  initial_balance: 0.00,
  currency: "CNY"
)

Account.create!(
  name: "Credit Card",
  type: "CREDIT",
  initial_balance: 0.00,
  currency: "CNY",
  credit_limit: 10000.00
)

Category.create!(name: "Food", type: "EXPENSE")
Category.create!(name: "Transportation", type: "EXPENSE")
Category.create!(name: "Shopping", type: "EXPENSE")
Category.create!(name: "Entertainment", type: "EXPENSE")
Category.create!(name: "Utilities", type: "EXPENSE")
Category.create!(name: "Salary", type: "INCOME")
Category.create!(name: "Investment", type: "INCOME")

Tag.create!(name: "Necessary", color: "#27ae60")
Tag.create!(name: "Optional", color: "#e74c3c")
Tag.create!(name: "Work", color: "#3498db")
Tag.create!(name: "Personal", color: "#9b59b6")

Currency.create!(code: "CNY", name: "Chinese Yuan", symbol: "¥", is_default: true, rate: 1.0)
Currency.create!(code: "USD", name: "US Dollar", symbol: "$", is_default: false, rate: 7.2)
Currency.create!(code: "EUR", name: "Euro", symbol: "€", is_default: false, rate: 7.8)
Currency.create!(code: "JPY", name: "Japanese Yen", symbol: "¥", is_default: false, rate: 0.048)

puts "Seeding completed!"
