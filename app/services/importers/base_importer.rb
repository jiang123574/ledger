# frozen_string_literal: true

# Base class for all format-specific importers.
# Subclasses must implement: #parse_rows(file), #raw_row_to_hash(row)
class Importers::BaseImporter
  MAX_PREVIEW_ROWS = 100

  class << self
    # Public entry point: import all rows from file
    def call(file, options = {})
      new(options).import(file)
    end

    # Public entry point: preview rows from file
    def preview(file, options = {})
      new(options).preview(file)
    end
  end

  def initialize(options = {})
    @field_mapping = options[:field_mapping] || ImportRowMapper.default_mapping
    @options = options
    @results = { success: 0, failed: 0, errors: [], imported_ids: [] }
  end

  def import(file)
    rows = parse_rows(file)

    rows.each_with_index do |raw_row, idx|
      begin
        row = normalize_row(raw_row)
        import_row(row, idx)
      rescue StandardError => e
        @results[:failed] += 1
        @results[:errors] << "第 #{idx + 1} 行: #{e.message}"
      end
    end

    @results
  end

  def preview(file)
    rows = parse_rows(file)
    preview_rows = rows.first(MAX_PREVIEW_ROWS).map { |r| normalize_row(r) }
    headers = preview_rows.first&.keys || []

    {
      format: format_name,
      headers: headers,
      rows: preview_rows,
      total_rows: rows.size,
      suggested_mapping: ImportRowMapper.suggest_mapping(headers)
    }
  end

  private

  # Subclasses must implement: parse file into array of raw row objects
  def parse_rows(file)
    raise NotImplementedError, "#{self.class}#parse_rows must be implemented"
  end

  # Subclasses must implement: convert raw row to Hash
  def normalize_row(raw_row)
    raise NotImplementedError, "#{self.class}#normalize_row must be implemented"
  end

  # Subclasses may override for format-specific display name
  def format_name
    self.class.name.demodulize.gsub("Importer", "").downcase
  end

  def import_row(row, _idx)
    data = ImportRowMapper.map_row(row, @field_mapping)

    return if data[:date].nil?
    return if data[:amount].nil? && data[:type] != "TRANSFER"

    create_record(data)
  end

  def create_record(data)
    ApplicationRecord.transaction do
      if data[:type] == "TRANSFER"
        records = create_transfer_records(data)
        if records.is_a?(Array)
          @results[:success] += records.size
          @results[:imported_ids] += records.map(&:id)
        end
      else
        record = create_single_record(data)
        @results[:success] += 1
        @results[:imported_ids] << record.id if record
      end
    end
  end

  # Create record using Entry model
  def create_single_record(data)
    ImportRecordCreator.create_entry(data)
  end

  def create_transfer_records(data)
    ImportRecordCreator.create_entry_transfer(data)
  end
end
