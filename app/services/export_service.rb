require "csv"

class ExportService
  CSV_HEADERS = [ "日期", "类型", "金额", "账户", "父分类", "子分类", "备注" ].freeze

  # 已废弃：统一走 entries_to_csv
  def self.transactions_to_csv
    entries_to_csv
  end

  def self.entries_to_csv
    CSV.generate(encoding: "UTF-8", headers: true) do |csv|
      csv << CSV_HEADERS

      entry_scope.find_each(batch_size: 1000) do |entry|
        csv << entry_to_row(entry)
      end
    end
  end

  def self.entries_to_csv_stream(io)
    CSV.new(io, encoding: "UTF-8", headers: true) do |csv|
      csv << CSV_HEADERS

      entry_scope.find_each(batch_size: 1000) do |entry|
        csv << entry_to_row(entry)
      end
    end
  end

  def self.export_file_name
    "transactions_#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv"
  end

  def self.entries_export_file_name
    "entries_#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv"
  end

  def self.entry_scope
    Entry.includes(:account, entryable: { category: :parent })
         .where(entryable_type: "Entryable::Transaction")
  end

  def self.entry_to_row(entry)
    category = entry.entryable&.category

    parent_name, child_name = if category&.parent
      [ category.parent.name, category.name ]
    else
      [ category&.name, "" ]
    end

    [
      entry.date&.strftime("%Y-%m-%d"),
      entry.amount >= 0 ? "收入" : "支出",
      entry.amount.abs,
      entry.account&.name,
      parent_name,
      child_name,
      entry.notes
    ]
  end
end
