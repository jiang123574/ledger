# frozen_string_literal: true

# Maps raw row hashes to structured transaction data.
# Handles field mapping, date/amount parsing, transfer detection.
class ImportRowMapper
  DEFAULT_MAPPING = {
    "日期" => "date", "交易时间" => "date", "date" => "date",
    "类型" => "type", "收支类型" => "type", "交易分类" => "type", "type" => "type",
    "父类" => "category", "收支大类" => "category", "分类" => "category", "category" => "category",
    "子类" => "sub_category", "交易类型" => "sub_category",
    "金额" => "amount", "金额（元）" => "amount", "金额(元)" => "amount", "amount" => "amount",
    "流入金额" => "income_amount",
    "流出金额" => "expense_amount",
    "账户" => "account", "支付方式" => "account", "资金账户" => "account", "account" => "account",
    "币种" => "currency",
    "备注" => "note", "商品说明" => "note", "商品" => "note", "note" => "note",
    "标签" => "tag", "tag" => "tag"
  }.freeze

  def self.default_mapping
    DEFAULT_MAPPING.dup
  end

  def self.suggest_mapping(headers)
    mapping = {}
    headers.each do |header|
      header_lower = header.to_s.downcase.strip
      DEFAULT_MAPPING.each do |pattern, field|
        if header_lower.include?(pattern.downcase) || header == pattern
          mapping[header] = field
          break
        end
      end
    end
    mapping
  end

  # Map a row hash using the given field mapping.
  # Returns a structured data hash with :date, :type, :amount, etc.
  def self.map_row(row, mapping = default_mapping)
    data = {
      date: nil, type: nil, amount: nil, account: nil,
      category: nil, sub_category: nil, note: nil, tag: nil,
      currency: nil, income_amount: nil, expense_amount: nil
    }

    row.each do |key, value|
      field = mapping[key] || mapping[key.to_s.strip]
      next unless field && value.present?

      case field
      when "date"           then data[:date] = DateParser.parse(value)
      when "type"           then data[:type] = TypeParser.parse(value)
      when "amount"         then data[:amount] = AmountParser.parse(value)
      when "income_amount"  then data[:income_amount] = AmountParser.parse(value)
      when "expense_amount" then data[:expense_amount] = AmountParser.parse(value)
      when "account"        then data[:account] = value.to_s.strip
      when "category"       then data[:category] = value.to_s.strip
      when "sub_category"   then data[:sub_category] = value.to_s.strip
      when "currency"       then data[:currency] = value.to_s.strip
      when "note"           then data[:note] = value.to_s.strip
      when "tag"            then data[:tag] = value.to_s.strip
      end
    end

    resolve_income_expense_amounts(data)
  end

  private_class_method :new

  # When income_amount / expense_amount are present, determine type and amount
  def self.resolve_income_expense_amounts(data)
    income = data[:income_amount].to_f
    expense = data[:expense_amount].to_f
    return data if income <= 0 && expense <= 0

    account_str = data[:account].to_s
    is_transfer_account = account_str.include?("→") || account_str.include?("->")

    if data[:type] == "TRANSFER" && is_transfer_account && income > 0 && income == expense
      data[:amount] = income
      data[:category] = nil
      data[:sub_category] = nil
    elsif is_transfer_account && income > 0 && income == expense
      data[:type] = "TRANSFER"
      data[:amount] = income
      data[:category] = nil
      data[:sub_category] = nil
    elsif income > 0 || expense > 0
      if income > 0 && expense > 0
        if income >= expense
          data[:type] = "INCOME"
          data[:amount] = income
        else
          data[:type] = "EXPENSE"
          data[:amount] = expense
        end
      elsif income > 0
        data[:type] = "INCOME"
        data[:amount] = income
      elsif expense > 0
        data[:type] = "EXPENSE"
        data[:amount] = expense
      end
    end

    data
  end
end

# Small value-object parsers extracted from ImportService
class DateParser
  FORMATS = %w[
    %Y-%m-%d %Y/%m/%d %Y.%m.%d
    %m/%d/%Y %d/%m/%Y
    %Y年%m月%d日
    "%Y-%m-%d %H:%M:%S" "%Y/%m/%d %H:%M:%S"
  ].freeze

  def self.parse(date_str)
    return nil if date_str.blank?

    date_str = date_str.to_s.strip

    FORMATS.each do |fmt|
      begin
        return Date.strptime(date_str, fmt)
      rescue ArgumentError
        next
      end
    end

    Date.parse(date_str)
  rescue ArgumentError, Date::Error
    nil
  end
end

class TypeParser
  def self.parse(type_str)
    return nil if type_str.blank?

    case type_str.to_s.strip
    when "收入", "INCOME", "income", "收", "+", "Income", "日常收入" then "INCOME"
    when "支出", "EXPENSE", "expense", "支", "-", "Expense", "日常支出" then "EXPENSE"
    when "转账", "TRANSFER", "transfer", "Transfer" then "TRANSFER"
    else nil
    end
  end
end

class AmountParser
  def self.parse(amount_str)
    return nil if amount_str.blank?

    cleaned = amount_str.to_s.gsub(/[¥$€£,\s]/, "").strip

    if cleaned.start_with?("(") && cleaned.end_with?(")")
      cleaned = "-" + cleaned[1..-2]
    end

    BigDecimal(cleaned)
  rescue ArgumentError
    nil
  end
end

class ImportRecordCreator
  # 已废弃：统一走 create_entry
  def self.create_transaction(data)
    create_entry(data)
  end

  # 已废弃：统一走 create_entry_transfer
  def self.create_transfer(data)
    create_entry_transfer(data)
  end

  def self.create_entry(data)
    original_type = data[:type]
    amount = data[:amount]

    if amount && amount < 0
      case original_type
      when "EXPENSE" then kind = "income"
      when "INCOME" then kind = "expense"
      else kind = "income"
      end
      amount = amount.abs
    else
      kind = (original_type == "INCOME") ? "income" : "expense"
    end

    account = ImportAccountResolver.find_or_create(data[:account])
    type_str = kind == "income" ? "INCOME" : "EXPENSE"
    category = resolve_category(data, type_str)

    note_parts = []
    note_parts << data[:sub_category] if data[:sub_category].present?
    note_parts << data[:note] if data[:note].present?
    final_note = note_parts.join(" - ")

    entryable = Entryable::Transaction.create!(kind: kind, category_id: category&.id)

    Entry.create!(
      account_id: account.id,
      date: data[:date] || Date.current,
      name: final_note || "#{kind == 'income' ? '收入' : '支出'} #{amount}",
      amount: kind == "income" ? amount.to_d : -amount.to_d,
      currency: data[:currency] || account&.currency || "CNY",
      notes: final_note,
      entryable: entryable
    )
  end

  def self.create_entry_transfer(data)
    account_str = data[:account].to_s
    amount = data[:amount].to_f.abs
    return nil if amount <= 0 || data[:date].nil?

    return nil unless account_str.include?("→") || account_str.include?("->")

    parts = account_str.split(/→|->/).map(&:strip)
    from_account = ImportAccountResolver.find_or_create(parts[0])
    to_account = ImportAccountResolver.find_or_create(parts[1])

    note = "转账: #{parts[0]} → #{parts[1]}#{data[:note] ? " - #{data[:note]}" : ""}"

    transfer_id = SecureRandom.uuid.gsub("-", "").to_i(16) % 2_000_000_000

    entryable_out = Entryable::Transaction.create!(kind: "expense")
    entry_out = Entry.create!(
      account_id: from_account.id, date: data[:date], name: note,
      amount: -amount.to_d, currency: from_account.currency, notes: note,
      entryable: entryable_out, transfer_id: transfer_id
    )

    entryable_in = Entryable::Transaction.create!(kind: "income")
    entry_in = Entry.create!(
      account_id: to_account.id, date: data[:date], name: note,
      amount: amount.to_d, currency: to_account.currency, notes: note,
      entryable: entryable_in, transfer_id: transfer_id
    )

    [ entry_out, entry_in ]
  end

  private_class_method :new

  def self.resolve_category(data, type_str)
    parent_name = data[:category]
    sub_name = data[:sub_category]

    if parent_name.present? && sub_name.present?
      ImportAccountResolver.find_or_create_sub_category(parent_name, sub_name, type_str)
    elsif parent_name.present?
      ImportAccountResolver.find_or_create_category(parent_name, type_str)
    else
      nil
    end
  end
end

class ImportAccountResolver
  def self.find_or_create(name)
    return nil if name.blank?

    Account.find_or_create_by(name: name.strip) do |a|
      a.type = "CASH"
      a.currency = "CNY"
    end
  end

  def self.find_or_create_category(name, type)
    return nil if name.blank?

    Category.find_or_create_by(name: name.strip) do |c|
      c.type = (type == "INCOME") ? "INCOME" : "EXPENSE"
    end
  end

  def self.find_or_create_sub_category(parent_name, sub_name, type)
    return nil if sub_name.blank?

    parent = Category.find_or_create_by(name: parent_name.strip) do |c|
      c.type = (type == "INCOME") ? "INCOME" : "EXPENSE"
    end

    Category.find_or_create_by(name: sub_name.strip, parent_id: parent.id) do |c|
      c.type = (type == "INCOME") ? "INCOME" : "EXPENSE"
      c.parent = parent
    end
  end

  private_class_method :new
end
