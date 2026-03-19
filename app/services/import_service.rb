require "csv"

class ImportService
  class ImportError < StandardError; end

  def self.import_transactions_csv(file)
    results = { success: 0, failed: 0, errors: [] }

    CSV.foreach(file.path, encoding: "UTF-8", headers: true) do |row|
      begin
        date = parse_date(row["日期"])
        transaction_type = parse_type(row["类型"])
        amount = parse_amount(row["金额"])
        account_name = row["账户"]
        category_name = row["分类"]
        target_account_name = row["目标账户"]
        note = row["备注"]

        next if date.nil? || amount.nil? || transaction_type.nil?

        account = find_or_create_account(account_name)
        category = find_or_create_category(category_name, transaction_type) if category_name.present?
        target_account = find_or_create_account(target_account_name) if target_account_name.present?

        Transaction.create!(
          date: date,
          type: transaction_type,
          amount: amount.abs,
          account_id: account&.id,
          category_id: category&.id,
          target_account_id: target_account&.id,
          note: note
        )

        results[:success] += 1
      rescue => e
        results[:failed] += 1
        results[:errors] << "第 #{$.} 行: #{e.message}"
      end
    end

    results
  end

  def self.validate_csv(file)
    errors = []

    begin
      CSV.foreach(file.path, encoding: "UTF-8", headers: true) do |row|
        date = parse_date(row["日期"])
        amount = parse_amount(row["金额"])
        type = parse_type(row["类型"])

        errors << "第 #{$.} 行: 日期格式错误" if row["日期"].present? && date.nil?
        errors << "第 #{$.} 行: 金额格式错误" if row["金额"].present? && amount.nil?
        errors << "第 #{$.} 行: 类型必须是'收入'或'支出'" if row["类型"].present? && type.nil?
      end
    rescue => e
      errors << "CSV 文件格式错误: #{e.message}"
    end

    errors
  end

  private_class_method

  def self.parse_date(date_str)
    return nil if date_str.blank?

    Date.parse(date_str)
  rescue
    nil
  end

  def self.parse_type(type_str)
    return nil if type_str.blank?

    case type_str.strip
    when "收入", "INCOME", "income" then "INCOME"
    when "支出", "EXPENSE", "expense" then "EXPENSE"
    else nil
    end
  end

  def self.parse_amount(amount_str)
    return nil if amount_str.blank?

    amount_str.gsub(/[¥$,\s]/, "").to_d
  rescue
    nil
  end

  def self.find_or_create_account(name)
    return nil if name.blank?

    Account.find_or_create_by(name: name.strip) do |a|
      a.type = "CASH"
    end
  end

  def self.find_or_create_category(name, type)
    return nil if name.blank?

    Category.find_or_create_by(name: name.strip) do |c|
      c.type = type || "EXPENSE"
    end
  end
end
