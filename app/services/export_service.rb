require "csv"

class ExportService
  # 已废弃：统一走 entries_to_csv
  def self.transactions_to_csv
    entries_to_csv
  end

  def self.entries_to_csv
    CSV.generate(encoding: "UTF-8", headers: true) do |csv|
      csv << ["日期", "类型", "金额", "账户", "分类", "备注"]

      Entry.includes(:account, :entryable).where(entryable_type: 'Entryable::Transaction').find_each(batch_size: 1000) do |entry|
        csv << [
          entry.date&.strftime("%Y-%m-%d"),
          entry.amount >= 0 ? "收入" : "支出",
          entry.amount.abs,
          entry.account&.name,
          entry.entryable&.category&.name,
          entry.notes
        ]
      end
    end
  end

  def self.export_file_name
    "transactions_#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv"
  end

  def self.entries_export_file_name
    "entries_#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv"
  end
end
