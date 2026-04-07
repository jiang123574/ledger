# frozen_string_literal: true

class Importers::ExcelImporter < Importers::BaseImporter
  private

  def parse_rows(file)
    raise ImportService::ImportError, "Excel 导入需要安装 roo gem" unless defined?(Roo)

    spreadsheet = Roo::Spreadsheet.open(file.path)
    sheet = spreadsheet.sheet(0)
    headers = sheet.row(1)
    rows = []

    (2..sheet.last_row).each do |row_num|
      rows << Hash[[ headers, sheet.row(row_num) ].transpose]
    end

    rows
  end

  def normalize_row(raw_row)
    raw_row.transform_values { |v| v.to_s.strip }
  end

  def format_name
    "excel"
  end
end
