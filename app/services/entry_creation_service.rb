# frozen_string_literal: true

# Entry 创建服务
# 封装普通交易创建、转账创建、带资金来源的支出创建
class EntryCreationService
  class CreationError < StandardError; end

  # 获取指定日期的最大 sort_order
  def self.next_sort_order(account_id, date)
    max_order = Entry.where(account_id: account_id, date: date).maximum(:sort_order) || 0
    max_order + 1
  end

  # 创建普通收支 Entry
  def self.create_regular(type:, account_id:, amount:, date:, currency: "CNY", note: nil, category_id: nil)
    kind = type.downcase
    sort_order = next_sort_order(account_id, date)

    entry = nil
    Entry.transaction do
      entryable = Entryable::Transaction.create!(
        kind: kind,
        category_id: category_id
      )

      entry = Entry.create!(
        account_id: account_id,
        date: date,
        name: note.presence || "#{type == 'INCOME' ? '收入' : '支出'} #{amount}",
        amount: kind == "income" ? amount : -amount,
        currency: currency,
        notes: note,
        entryable: entryable,
        sort_order: sort_order
      )
    end
    entry
  end

  # 创建转账 Entry 对（转出 + 转入）
  def self.create_transfer(from_account_id:, to_account_id:, amount:, date:, currency: "CNY", note: nil)
    from_account = Account.find(from_account_id)
    to_account = Account.find(to_account_id)

    transfer_id = SecureRandom.uuid
    transfer_note = note.presence || "转账: #{from_account.name} → #{to_account.name}"

    # 获取两个账户的下一个 sort_order
    sort_order_out = next_sort_order(from_account_id, date)
    sort_order_in = next_sort_order(to_account_id, date)

    entry_out = nil
    entry_in = nil

    Entry.transaction do
      entry_out = Entry.create!(
        account_id: from_account_id,
        date: date,
        name: transfer_note,
        amount: -amount,
        currency: currency,
        notes: note.presence,
        entryable: Entryable::Transaction.create!(kind: "expense"),
        transfer_id: transfer_id,
        sort_order: sort_order_out
      )

      entry_in = Entry.create!(
        account_id: to_account_id,
        date: date,
        name: transfer_note,
        amount: amount,
        currency: currency,
        notes: note.presence,
        entryable: Entryable::Transaction.create!(kind: "income"),
        transfer_id: transfer_id,
        sort_order: sort_order_in
      )
    end

    [ entry_out, entry_in ]
  end

  # 创建带资金来源转账的支出（先从资金来源账户转账到消费账户，再创建支出）
  def self.create_with_funding_transfer(funding_account_id:, destination_account_id:,
                                         amount:, date:, currency: "CNY", note: nil, category_id: nil)
    source_account = Account.find(funding_account_id)
    destination_account = Account.find(destination_account_id)

    transfer_out = nil
    transfer_in = nil
    expense_entry = nil

    Entry.transaction do
      transfer_id = SecureRandom.uuid
      transfer_note = [
        "自动补记资金来源",
        source_account.name,
        "->",
        destination_account.name,
        (note.present? ? "（#{note}）" : nil)
      ].compact.join(" ")

      # 获取 sort_order
      sort_order_out = next_sort_order(source_account.id, date)
      sort_order_in = next_sort_order(destination_account.id, date)

      # 资金来源转账：转出
      transfer_out = Entry.create!(
        account_id: source_account.id,
        date: date,
        name: transfer_note,
        amount: -amount,
        currency: currency,
        notes: note.presence,
        entryable: Entryable::Transaction.create!(kind: "expense"),
        transfer_id: transfer_id,
        sort_order: sort_order_out
      )

      # 资金来源转账：转入
      transfer_in = Entry.create!(
        account_id: destination_account.id,
        date: date,
        name: transfer_note,
        amount: amount,
        currency: currency,
        notes: note.presence,
        entryable: Entryable::Transaction.create!(kind: "income"),
        transfer_id: transfer_id,
        sort_order: sort_order_in
      )

      # 实际支出
      sort_order_expense = next_sort_order(destination_account.id, date)
      expense_entryable = Entryable::Transaction.create!(
        kind: "expense",
        category_id: category_id
      )

      expense_entry = Entry.create!(
        account_id: destination_account.id,
        date: date,
        name: note.presence || "支出 #{amount}",
        amount: -amount,
        currency: currency,
        notes: note,
        entryable: expense_entryable,
        sort_order: sort_order_expense
      )
    end

    # 返回支出 entry（用于前端显示）
    expense_entry
  end
end
