# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardComponent, type: :component do
  it "initializes with title" do
    component = CardComponent.new(title: "Test")
    expect(component.instance_variable_get(:@title)).to eq("Test")
  end

  it "initializes with classes" do
    component = CardComponent.new(classes: "my-class")
    expect(component.instance_variable_get(:@classes)).to eq("my-class")
  end

  it "initializes without arguments" do
    component = CardComponent.new
    expect(component.instance_variable_get(:@title)).to be_nil
    expect(component.instance_variable_get(:@classes)).to eq("")
  end
end

RSpec.describe MonthNavigatorComponent, type: :component do
  it "renders current month" do
    result = render_inline(MonthNavigatorComponent.new(current_month: "2026-04-01"))
    expect(result).to have_text("2026-04-01")
  end

  it "renders previous arrow" do
    result = render_inline(MonthNavigatorComponent.new(current_month: "2026-04-01"))
    expect(result).to have_text("←")
  end

  it "renders next arrow" do
    result = render_inline(MonthNavigatorComponent.new(current_month: "2026-04-01"))
    expect(result).to have_text("→")
  end

  it "renders links for navigation" do
    result = render_inline(MonthNavigatorComponent.new(current_month: "2026-04-01"))
    expect(result).to have_css("a", count: 2)
  end

  it "renders with flex layout" do
    result = render_inline(MonthNavigatorComponent.new(current_month: "2026-04-01"))
    expect(result.to_s).to include("flex")
  end
end

RSpec.describe TransactionRowComponent, type: :component do
  let(:transaction) do
    double("transaction",
      category: "Food",
      display_amount: "¥100.00",
      income?: false,
      note: "Lunch",
      date: Date.new(2026, 4, 1),
      account_name: "Cash"
    )
  end

  it "renders transaction category" do
    result = render_inline(TransactionRowComponent.new(transaction: transaction))
    expect(result).to have_text("Food")
  end

  it "renders amount" do
    result = render_inline(TransactionRowComponent.new(transaction: transaction))
    expect(result).to have_text("¥100.00")
  end

  it "renders note when present" do
    result = render_inline(TransactionRowComponent.new(transaction: transaction))
    expect(result).to have_text("Lunch")
  end

  it "renders date" do
    result = render_inline(TransactionRowComponent.new(transaction: transaction))
    expect(result).to have_text("2026-04-01")
  end

  it "renders account name by default" do
    result = render_inline(TransactionRowComponent.new(transaction: transaction))
    expect(result).to have_text("Cash")
  end

  it "hides account name when show_account is false" do
    result = render_inline(TransactionRowComponent.new(transaction: transaction, show_account: false))
    expect(result).not_to have_text("Cash")
  end

  it "applies expense styling for expense transactions" do
    result = render_inline(TransactionRowComponent.new(transaction: transaction))
    expect(result.to_s).to include("text-expense")
  end

  it "applies income styling for income transactions" do
    income_transaction = double("transaction",
      category: "Salary",
      display_amount: "¥5,000.00",
      income?: true,
      note: nil,
      date: Date.new(2026, 4, 1),
      account_name: "Bank"
    )
    result = render_inline(TransactionRowComponent.new(transaction: income_transaction))
    expect(result.to_s).to include("text-income")
  end

  it "renders '未分类' when category is nil" do
    no_cat = double("transaction",
      category: nil,
      display_amount: "¥50.00",
      income?: false,
      note: nil,
      date: Date.new(2026, 4, 1),
      account_name: "Cash"
    )
    result = render_inline(TransactionRowComponent.new(transaction: no_cat))
    expect(result).to have_text("未分类")
  end
end
