# frozen_string_literal: true

# Facade for multi-format import. Delegates to format-specific Importers.
#
# Supported formats: csv, xlsx, xls, ofx, qif
#
# Usage:
#   ImportService.import(file, field_mapping: { "日期" => "date", ... })
#   ImportService.preview(file)
#   ImportService.validate_file(file)
#
# For backward compatibility, all old class methods still work.
class ImportService
  class ImportError < StandardError; end

  SUPPORTED_FORMATS = %w[csv xlsx xls ofx qif].freeze

  # Format-specific importer classes
  FORMAT_IMPORTERS = {
    "csv" => Importers::CsvImporter,
    "xlsx" => Importers::ExcelImporter,
    "xls" => Importers::ExcelImporter,
    "ofx" => Importers::OfxImporter,
    "qif" => Importers::QifImporter
  }.freeze

  # Field mapping templates for UI
  TEMPLATES = [
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
  ].freeze

  # ---- Public API ----

  def self.import(file, options = {})
    importer_for(file).call(file, options)
  end

  def self.preview(file, options = {})
    importer_for(file).preview(file, options)
  end

  def self.validate_file(file)
    errors = []

    format = detect_format(file)
    errors << I18n.t("import.errors.unsupported_format") unless SUPPORTED_FORMATS.include?(format)

    if file.size > 10.megabytes
      errors << I18n.t("import.errors.file_too_large", max: "10MB")
    end

    unless validate_file_content?(file, format)
      errors << I18n.t("import.errors.content_mismatch")
    end

    { valid: errors.empty?, errors: errors, format: format }
  end

  # Backward compatibility aliases for SettingsController
  def self.import_transactions_csv(file, field_mapping = nil)
    import(file, field_mapping: field_mapping)
  end

  def self.validate_csv(file)
    result = validate_file(file)
    result[:errors]
  end

  # Backward compatibility: templates
  def self.templates
    TEMPLATES
  end

  def self.default_csv_mapping
    Importers::ImportRowMapper.default_mapping
  end

  # ---- Private ----

  private_class_method

  def self.detect_format(file)
    ext = File.extname(file.original_filename).downcase.gsub(".", "")
    ext = "xlsx" if ext == "xls"
    ext
  end

  def self.importer_for(file)
    format = detect_format(file)
    FORMAT_IMPORTERS[format] || raise(ImportError, "不支持的文件格式: #{format}")
  end

  def self.validate_file_content?(file, format)
    return true unless %w[csv xlsx xls].include?(format)

    content = File.read(file.path, 1024)

    case format
    when "csv"
      content.valid_encoding? && content.match?(/[\w\s,;|\t\n]/)
    when "xlsx", "xls"
      content.start_with?("PK") || content.start_with?("\xD0\xCF")
    else
      true
    end
  rescue StandardError
    false
  end
end
