require "csv"

class ExportService
  CSV_HEADERS = [ "日期", "类型", "金额", "账户", "转出账户", "转入账户", "父分类", "子分类", "备注" ].freeze

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

      transfer_batch = []
      transfer_scope.find_each(batch_size: 1000) do |entry|
        transfer_batch << entry
        if transfer_batch.size >= 1000
          Entry.preload_transfer_accounts(transfer_batch)
          transfer_batch.each { |e| csv << transfer_to_row(e) }
          transfer_batch = []
        end
      end
      if transfer_batch.any?
        Entry.preload_transfer_accounts(transfer_batch)
        transfer_batch.each { |e| csv << transfer_to_row(e) }
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
         .where(transfer_id: nil)
         .order(date: :desc, id: :asc)
  end

  def self.transfer_scope
    Entry.includes(:account)
         .where(entryable_type: "Entryable::Transaction")
         .where.not(transfer_id: nil)
         .where("entries.amount < 0")
         .order(date: :desc, id: :asc)
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
      nil,
      nil,
      parent_name,
      child_name,
      entry.notes
    ]
  end

  def self.transfer_to_row(entry)
    source = entry.source_account_for_transfer
    target = entry.target_account_for_display

    [
      entry.date&.strftime("%Y-%m-%d"),
      "转账",
      entry.amount.abs,
      "#{source&.name} → #{target&.name}",
      source&.name,
      target&.name,
      nil,
      nil,
      entry.notes
    ]
  end
end
