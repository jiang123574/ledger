require "csv"

class ExportService
  def self.transactions_to_csv
    CSV.generate(encoding: "UTF-8", headers: true) do |csv|
      csv << [ "日期", "类型", "金额", "账户", "分类", "目标账户", "备注" ]

      Transaction.includes(:account, :category, :target_account).find_each(batch_size: 1000) do |t|
        csv << [
          t.date&.strftime("%Y-%m-%d"),
          t.type == "INCOME" ? "收入" : "支出",
          t.amount,
          t.account&.name,
          t.category&.name,
          t.target_account&.name,
          t.note
        ]
      end
    end
  end

  def self.export_file_name
    "transactions_#{Time.now.strftime("%Y%m%d_%H%M%S")}.csv"
  end
end
