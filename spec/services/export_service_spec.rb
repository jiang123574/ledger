# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportService, type: :service do
  let(:account) { create(:account) }
  let(:category) { create(:category) }

  describe '.entries_to_csv' do
    before do
      # 创建一些Entry用于导出
      create(:entry,
        account: account,
        entryable: create(:entryable_transaction, category: category, kind: 'EXPENSE'),
        amount: -100,
        date: Date.current,
        notes: '测试支出'
      )
      create(:entry,
        account: account,
        entryable: create(:entryable_transaction, category: category, kind: 'INCOME'),
        amount: 500,
        date: Date.current,
        notes: '测试收入'
      )
    end

    it 'returns CSV string' do
      csv = described_class.entries_to_csv

      expect(csv).to be_a(String)
      expect(csv).to include('日期')
    end

    it 'includes CSV header' do
      csv = described_class.entries_to_csv

      expect(csv).to include('日期')
      expect(csv).to include('类型')
      expect(csv).to include('金额')
      expect(csv).to include('账户')
      expect(csv).to include('分类')
      expect(csv).to include('备注')
    end

    it 'includes entry data' do
      csv = described_class.entries_to_csv

      expect(csv).to include(account.name)
      expect(csv).to include(category.name)
    end

    it 'correctly formats amounts' do
      csv = described_class.entries_to_csv

      expect(csv).to include('100')
      expect(csv).to include('500')
    end

    it 'correctly formats dates' do
      csv = described_class.entries_to_csv

      expect(csv).to include(Date.current.strftime("%Y-%m-%d"))
    end

    it 'distinguishes income and expense' do
      csv = described_class.entries_to_csv

      expect(csv).to include('收入')
      expect(csv).to include('支出')
    end

    it 'includes notes' do
      csv = described_class.entries_to_csv

      expect(csv).to include('测试支出')
      expect(csv).to include('测试收入')
    end
  end

  describe '.transactions_to_csv' do
    before do
      create(:entry,
        account: account,
        entryable: create(:entryable_transaction),
        amount: -50,
        date: Date.current
      )
    end

    it 'returns CSV (deprecated method)' do
      csv = described_class.transactions_to_csv

      expect(csv).to be_a(String)
      expect(csv).to include('日期')
    end

    it 'uses entries_to_csv internally' do
      allow(described_class).to receive(:entries_to_csv).and_return("mocked csv")

      result = described_class.transactions_to_csv

      expect(described_class).to have_received(:entries_to_csv)
    end
  end

  describe '.export_file_name' do
    it 'returns filename with timestamp' do
      filename = described_class.export_file_name

      expect(filename).to match(/^transactions_\d{8}_\d{6}\.csv$/)
    end

    it 'includes date and time components' do
      filename = described_class.export_file_name

      # 验证格式，但不依赖具体时间值
      parts = filename.split('_')
      expect(parts[1]).to match(/^\d{8}$/) # 日期部分
      expect(parts[2]).to match(/^\d{6}\.csv$/) # 时间部分
    end
  end

  describe '.entries_export_file_name' do
    it 'returns filename with timestamp' do
      filename = described_class.entries_export_file_name

      expect(filename).to match(/^entries_\d{8}_\d{6}\.csv$/)
    end

    it 'includes date and time components' do
      filename = described_class.entries_export_file_name

      # 验证格式，但不依赖具体时间值
      parts = filename.split('_')
      expect(parts[1]).to match(/^\d{8}$/) # 日期部分
      expect(parts[2]).to match(/^\d{6}\.csv$/) # 时间部分
    end
  end

  describe 'CSV format' do
    before do
      create(:entry,
        account: account,
        entryable: create(:entryable_transaction, category: category),
        amount: -75.50,
        date: 5.days.ago,
        notes: 'Some note'
      )
    end

    it 'produces valid CSV with encoding' do
      csv = described_class.entries_to_csv

      # 应该可以被解析
      parsed = CSV.parse(csv, headers: true)
      expect(parsed).not_to be_empty

      first_row = parsed.first
      expect(first_row).not_to be_nil
    end

    it 'handles special characters in notes' do
      create(:entry,
        account: account,
        entryable: create(:entryable_transaction),
        amount: -10,
        date: Date.current,
        notes: '特殊字符: "引号", 逗号,'
      )

      csv = described_class.entries_to_csv
      parsed = CSV.parse(csv, headers: true)

      # 应该能正确处理特殊字符
      expect(parsed.count).to be >= 2
    end
  end

  describe 'with no entries' do
    it 'returns CSV with only header' do
      # 删除所有transaction类型的entry
      Entry.where(entryable_type: 'Entryable::Transaction').delete_all

      csv = described_class.entries_to_csv

      # 应该至少有header
      lines = csv.strip.split("\n")
      expect(lines.count).to be >= 1
    end
  end
end
