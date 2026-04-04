# frozen_string_literal: true

class Importers::QifImporter < Importers::BaseImporter
  private

  def parse_rows(file)
    content = File.read(file.path, encoding: "UTF-8")
    parse_qif_content(content)
  end

  def normalize_row(raw_row)
    # Raw QIF data is already a hash from parse_qif_content
    {
      "日期" => raw_row[:date],
      "金额" => raw_row[:amount],
      "收款人" => raw_row[:payee],
      "分类" => raw_row[:category]
    }
  end

  def format_name
    "qif"
  end

  # QIF has its own import logic (creates Entry directly)
  def import_row(row, _idx)
    amount = row["金额"].to_f
    return if amount.zero? && row["日期"].nil?

    kind = amount >= 0 ? "income" : "expense"
    account = ImportAccountResolver.find_or_create(@options[:account_name] || "Imported Account")

    category_name = row["分类"]
    category = category_name.present? ? ImportAccountResolver.find_or_create_category(category_name, kind == "income" ? "INCOME" : "EXPENSE") : nil

    entryable = Entryable::Transaction.new(kind: kind, category_id: category&.id)
    entryable.save(validate: false)

    Entry.create!(
      date: parse_qif_date(row["日期"]),
      name: row["收款人"] || row["分类"] || "QIF Import",
      amount: amount,
      currency: "CNY",
      account: account,
      entryable: entryable
    )

    @results[:success] += 1
  end

  def preview(file)
    content = File.read(file.path, encoding: "UTF-8")
    transactions = parse_qif_content(content)

    {
      format: "qif",
      headers: [ "日期", "金额", "收款人", "分类" ],
      rows: transactions.first(MAX_PREVIEW_ROWS).map do |tx|
        { "日期" => tx[:date], "金额" => tx[:amount], "收款人" => tx[:payee], "分类" => tx[:category] }
      end,
      total_rows: transactions.count
    }
  end

  def parse_qif_content(content)
    transactions = []
    current = {}

    content.each_line do |line|
      line = line.strip
      next if line.empty?

      if line.start_with?("^")
        transactions << current if current[:date] && current[:amount]
        current = {}
      elsif line.start_with?("D")
        current[:date] = line[1..]
      elsif line.start_with?("T")
        current[:amount] = AmountParser.parse(line[1..])
      elsif line.start_with?("P")
        current[:payee] = line[1..]
      elsif line.start_with?("M")
        current[:memo] = line[1..]
      elsif line.start_with?("L")
        current[:category] = line[1..]
      end
    end

    transactions << current if current[:date] && current[:amount]
    transactions
  end

  def parse_qif_date(date_str)
    return Date.current if date_str.blank?

    formats = [ "%m/%d/%Y", "%d/%m/%Y", "%Y-%m-%d", "%m/%d'%y" ]

    formats.each do |fmt|
      begin
        return Date.strptime(date_str.strip, fmt)
      rescue ArgumentError
        next
      end
    end

    Date.parse(date_str)
  rescue ArgumentError, Date::Error
    Date.current
  end
end
