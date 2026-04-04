# frozen_string_literal: true

require "csv"

class Importers::CsvImporter < Importers::BaseImporter
  private

  def parse_rows(file)
    rows = []
    CSV.foreach(file.path, encoding: "UTF-8", headers: true) do |row|
      rows << row.to_h
    end
    rows
  end

  def normalize_row(raw_row)
    raw_row.transform_values { |v| v.to_s.strip }
  end

  def format_name
    "csv"
  end
end
