require "csv"

class ImportService
  class ImportError < StandardError; end

  SUPPORTED_FORMATS = %w[csv xlsx xls ofx qif].freeze
  MAX_PREVIEW_ROWS = 100

  # Main import method - dispatches to format-specific handlers
  def self.import(file, options = {})
    format = detect_format(file)

    case format
    when "csv"
      import_csv(file, options)
    when "xlsx", "xls"
      import_excel(file, options)
    when "ofx"
      import_ofx(file, options)
    when "qif"
      import_qif(file, options)
    else
      raise ImportError, "不支持的文件格式: #{format}"
    end
  end

  # Preview import data
  def self.preview(file, options = {})
    format = detect_format(file)

    case format
    when "csv"
      preview_csv(file, options)
    when "xlsx", "xls"
      preview_excel(file, options)
    when "ofx"
      preview_ofx(file, options)
    when "qif"
      preview_qif(file, options)
    else
      raise ImportError, "不支持的文件格式: #{format}"
    end
  end

  # CSV Import
  def self.import_csv(file, options = {})
    results = { success: 0, failed: 0, errors: [], imported_ids: [] }
    field_mapping = options[:field_mapping] || default_csv_mapping

    CSV.foreach(file.path, encoding: encoding(file), headers: true) do |row|
      begin
        transaction_data = map_csv_row(row, field_mapping)
        next if transaction_data[:date].nil? || transaction_data[:amount].nil?

        transaction = create_transaction(transaction_data)
        results[:success] += 1
        results[:imported_ids] << transaction.id
      rescue => e
        results[:failed] += 1
        results[:errors] << "第 #{$.} 行: #{e.message}"
      end
    end

    results
  end

  def self.preview_csv(file, options = {})
    rows = []
    headers = []
    field_mapping = options[:field_mapping] || default_csv_mapping

    CSV.foreach(file.path, encoding: encoding(file), headers: true).with_index do |row, idx|
      break if idx >= MAX_PREVIEW_ROWS

      headers = row.headers if headers.empty?
      rows << row.to_h
    end

    {
      format: "csv",
      headers: headers,
      rows: rows,
      total_rows: CSV.read(file.path, encoding: encoding(file)).length - 1,
      suggested_mapping: suggest_mapping(headers)
    }
  end

  # Excel Import (simplified - would need roo gem for full support)
  def self.import_excel(file, options = {})
    # Note: For full Excel support, add 'roo' gem to Gemfile
    raise ImportError, "Excel 导入需要安装 roo gem" unless defined?(Roo)

    results = { success: 0, failed: 0, errors: [], imported_ids: [] }

    spreadsheet = Roo::Spreadsheet.open(file.path)
    sheet = spreadsheet.sheet(0)
    headers = sheet.row(1)

    (2..sheet.last_row).each do |row_num|
      begin
        row_data = Hash[[ headers, sheet.row(row_num) ].transpose]
        transaction_data = map_csv_row(row_data, options[:field_mapping] || default_csv_mapping)
        next if transaction_data[:date].nil? || transaction_data[:amount].nil?

        transaction = create_transaction(transaction_data)
        results[:success] += 1
        results[:imported_ids] << transaction.id
      rescue => e
        results[:failed] += 1
        results[:errors] << "第 #{row_num} 行: #{e.message}"
      end
    end

    results
  end

  def self.preview_excel(file, options = {})
    raise ImportError, "Excel 导入需要安装 roo gem" unless defined?(Roo)

    spreadsheet = Roo::Spreadsheet.open(file.path)
    sheet = spreadsheet.sheet(0)
    headers = sheet.row(1)
    rows = []

    (2..[ sheet.last_row, MAX_PREVIEW_ROWS + 1 ].min).each do |row_num|
      rows << Hash[[ headers, sheet.row(row_num) ].transpose]
    end

    {
      format: "excel",
      headers: headers,
      rows: rows,
      total_rows: sheet.last_row - 1,
      suggested_mapping: suggest_mapping(headers)
    }
  end

  # OFX Import (Open Financial Exchange)
  def self.import_ofx(file, options = {})
    require "ofx"

    results = { success: 0, failed: 0, errors: [], imported_ids: [] }

    ofx = OFX(file.path)
    account = find_or_create_account(options[:account_name] || "Imported Account")

    ofx.account.transactions.each do |tx|
      begin
        amount = tx.amount.to_d
        transaction_type = amount >= 0 ? "INCOME" : "EXPENSE"

        transaction = Transaction.create!(
          date: tx.posted_at.to_date,
          type: transaction_type,
          amount: amount.abs,
          account: account,
          note: tx.name || tx.memo || "OFX Import",
          currency: ofx.account.currency || "CNY"
        )

        results[:success] += 1
        results[:imported_ids] << transaction.id
      rescue => e
        results[:failed] += 1
        results[:errors] << "交易 #{tx.fit_id}: #{e.message}"
      end
    end

    results
  end

  def self.preview_ofx(file, options = {})
    require "ofx"

    ofx = OFX(file.path)
    transactions = ofx.account.transactions.first(MAX_PREVIEW_ROWS)

    {
      format: "ofx",
      headers: [ "日期", "金额", "描述", "FIT ID" ],
      rows: transactions.map do |tx|
        {
          "日期" => tx.posted_at&.to_date,
          "金额" => tx.amount,
          "描述" => tx.name || tx.memo,
          "FIT ID" => tx.fit_id
        }
      end,
      total_rows: ofx.account.transactions.count,
      account_info: {
        bank_id: ofx.account.bank_id,
        account_id: ofx.account.id,
        currency: ofx.account.currency
      }
    }
  end

  # QIF Import (Quicken Interchange Format)
  def self.import_qif(file, options = {})
    results = { success: 0, failed: 0, errors: [], imported_ids: [] }
    account = find_or_create_account(options[:account_name] || "Imported Account")

    content = File.read(file.path, encoding: encoding(file))
    transactions = parse_qif_content(content)

    transactions.each do |tx_data|
      begin
        transaction = Transaction.create!(
          date: parse_qif_date(tx_data[:date]),
          type: tx_data[:amount] >= 0 ? "INCOME" : "EXPENSE",
          amount: tx_data[:amount].abs,
          account: account,
          note: tx_data[:payee] || tx_data[:memo] || "QIF Import",
          category: tx_data[:category]
        )

        results[:success] += 1
        results[:imported_ids] << transaction.id
      rescue => e
        results[:failed] += 1
        results[:errors] << "交易失败: #{e.message}"
      end
    end

    results
  end

  def self.preview_qif(file, options = {})
    content = File.read(file.path, encoding: encoding(file))
    transactions = parse_qif_content(content)

    {
      format: "qif",
      headers: [ "日期", "金额", "收款人", "分类" ],
      rows: transactions.first(MAX_PREVIEW_ROWS).map do |tx|
        {
          "日期" => tx[:date],
          "金额" => tx[:amount],
          "收款人" => tx[:payee],
          "分类" => tx[:category]
        }
      end,
      total_rows: transactions.count
    }
  end

  # Validation
  def self.validate_file(file)
    errors = []

    format = detect_format(file)
    errors << I18n.t("import.errors.unsupported_format") unless SUPPORTED_FORMATS.include?(format)

    if file.size > 10.megabytes
      errors << I18n.t("import.errors.file_too_large", max: "10MB")
    end

    # Validate file content matches extension
    unless validate_file_content?(file, format)
      errors << I18n.t("import.errors.content_mismatch")
    end

    { valid: errors.empty?, errors: errors, format: format }
  end

  def self.create_transaction(data)
    ApplicationRecord.transaction do
      account = find_or_create_account(data[:account])
      category = find_or_create_category(data[:category], data[:type])
      transaction_type = data[:type] || (data[:amount] >= 0 ? "INCOME" : "EXPENSE")

      Transaction.create!(
        date: data[:date] || Date.current,
        type: transaction_type,
        amount: data[:amount]&.abs || 0,
        account: account,
        category: category,
        note: data[:note],
        tag: data[:tag]
      )
    end
  end

  # Field mapping templates
  def self.templates
    [
      {
        name: "标准格式",
        mapping: { "日期" => "date", "类型" => "type", "金额" => "amount", "账户" => "account", "分类" => "category", "备注" => "note" }
      },
      {
        name: "支付宝格式",
        mapping: { "交易时间" => "date", "收支类型" => "type", "金额（元）" => "amount", "账户" => "account", "交易分类" => "category", "商品说明" => "note" }
      },
      {
        name: "微信支付格式",
        mapping: { "交易时间" => "date", "交易类型" => "type", "金额(元)" => "amount", "支付方式" => "account", "交易分类" => "category", "商品" => "note" }
      }
    ]
  end

  private_class_method

  def self.detect_format(file)
    ext = File.extname(file.original_filename).downcase.gsub(".", "")
    ext = "xlsx" if ext == "xls"
    ext
  end

  def self.encoding(file)
    # Try to detect encoding, default to UTF-8
    content = File.read(file.path, 1024)
    content.encoding.name
  rescue
    "UTF-8"
  end

  def self.default_csv_mapping
    {
      "日期" => "date", "交易时间" => "date", "date" => "date",
      "类型" => "type", "收支类型" => "type", "交易类型" => "type", "type" => "type",
      "金额" => "amount", "金额（元）" => "amount", "金额(元)" => "amount", "amount" => "amount",
      "账户" => "account", "支付方式" => "account", "account" => "account",
      "分类" => "category", "交易分类" => "category", "category" => "category",
      "备注" => "note", "商品说明" => "note", "商品" => "note", "note" => "note",
      "标签" => "tag", "tag" => "tag"
    }
  end

  def self.suggest_mapping(headers)
    mapping = {}
    headers.each do |header|
      header_lower = header.to_s.downcase.strip
      default = default_csv_mapping

      default.each do |pattern, field|
        if header_lower.include?(pattern.downcase) || header == pattern
          mapping[header] = field
          break
        end
      end
    end
    mapping
  end

  def self.map_csv_row(row, mapping)
    data = { date: nil, type: nil, amount: nil, account: nil, category: nil, note: nil, tag: nil }

    row.each do |key, value|
      field = mapping[key] || mapping[key.to_s.strip]
      next unless field && value.present?

      case field
      when "date"
        data[:date] = parse_date(value)
      when "type"
        data[:type] = parse_type(value)
      when "amount"
        data[:amount] = parse_amount(value)
      when "account"
        data[:account] = value.to_s.strip
      when "category"
        data[:category] = value.to_s.strip
      when "note"
        data[:note] = value.to_s.strip
      when "tag"
        data[:tag] = value.to_s.strip
      end
    end

    data
  end

  def self.create_transaction(data)
    account = find_or_create_account(data[:account])
    category = find_or_create_category(data[:category], data[:type])
    transaction_type = data[:type] || (data[:amount] >= 0 ? "INCOME" : "EXPENSE")

    Transaction.create!(
      date: data[:date] || Date.current,
      type: transaction_type,
      amount: data[:amount]&.abs || 0,
      account: account,
      category: category,
      note: data[:note],
      tag: data[:tag]
    )
  end

  def self.parse_date(date_str)
    return nil if date_str.blank?

    # Try multiple date formats
    date_str = date_str.to_s.strip

    formats = [
      "%Y-%m-%d", "%Y/%m/%d", "%Y.%m.%d",
      "%m/%d/%Y", "%d/%m/%Y",
      "%Y年%m月%d日",
      "%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S"
    ]

    formats.each do |fmt|
      begin
        return Date.strptime(date_str, fmt)
      rescue
        next
      end
    end

    Date.parse(date_str)
  rescue
    nil
  end

  def self.parse_type(type_str)
    return nil if type_str.blank?

    case type_str.to_s.strip
    when "收入", "INCOME", "income", "收", "+", "Income" then "INCOME"
    when "支出", "EXPENSE", "expense", "支", "-", "Expense" then "EXPENSE"
    when "转账", "TRANSFER", "transfer", "Transfer" then "TRANSFER"
    else nil
    end
  end

  def self.parse_amount(amount_str)
    return nil if amount_str.blank?

    # Clean up the amount string
    cleaned = amount_str.to_s.gsub(/[¥$€£,\s]/, "").strip

    # Handle negative amounts in parentheses
    if cleaned.start_with?("(") && cleaned.end_with?(")")
      cleaned = "-" + cleaned[1..-2]
    end

    BigDecimal(cleaned)
  rescue
    nil
  end

  def self.find_or_create_account(name)
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

  # Validate file content matches extension
  def self.validate_file_content?(file, format)
    return true unless %w[csv xlsx xls].include?(format)

    # Read first few bytes to check magic numbers/content
    content = File.read(file.path, 1024)

    case format
    when "csv"
      # CSV should be text-based
      content.valid_encoding? && content.match?(/[\w\s,;|\t\n]/)
    when "xlsx", "xls"
      # Excel files start with PK (xlsx) or D0CF (xls)
      content.start_with?("PK") || content.start_with?("\xD0\xCF")
    else
      true
    end
  rescue
    false
  end

  # QIF parsing
  def self.parse_qif_content(content)
    transactions = []
    current = {}

    content.each_line do |line|
      line = line.strip
      next if line.empty?

      if line.start_with?("^")
        # End of transaction
        if current[:date] && current[:amount]
          transactions << current
        end
        current = {}
      elsif line.start_with?("D")
        current[:date] = line[1..-1]
      elsif line.start_with?("T")
        current[:amount] = parse_amount(line[1..-1])
      elsif line.start_with?("P")
        current[:payee] = line[1..-1]
      elsif line.start_with?("M")
        current[:memo] = line[1..-1]
      elsif line.start_with?("L")
        current[:category] = line[1..-1]
      end
    end

    # Don't forget the last transaction if file doesn't end with ^
    if current[:date] && current[:amount]
      transactions << current
    end

    transactions
  end

  def self.parse_qif_date(date_str)
    return nil if date_str.blank?

    # QIF dates are often in MM/DD/YYYY or DD/MM/YYYY format
    formats = [ "%m/%d/%Y", "%d/%m/%Y", "%Y-%m-%d", "%m/%d'%y" ]

    formats.each do |fmt|
      begin
        return Date.strptime(date_str.strip, fmt)
      rescue
        next
      end
    end

    Date.parse(date_str)
  rescue
    Date.current
  end
end
