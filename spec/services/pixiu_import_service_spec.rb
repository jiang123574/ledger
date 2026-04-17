# frozen_string_literal: true

require "rails_helper"

RSpec.describe PixiuImportService, type: :service do
  describe "constants" do
    it "defines expense categories" do
      expect(PixiuImportService::EXPENSE_CATEGORIES).to include("日常支出")
      expect(PixiuImportService::EXPENSE_CATEGORIES).to include("还款")
    end

    it "defines income categories" do
      expect(PixiuImportService::INCOME_CATEGORIES).to include("日常收入")
      expect(PixiuImportService::INCOME_CATEGORIES).to include("报销")
    end

    it "defines transfer categories" do
      expect(PixiuImportService::TRANSFER_CATEGORIES).to include("转账")
      expect(PixiuImportService::TRANSFER_CATEGORIES).to include("信用卡还款")
    end
  end

  describe ".preview" do
    let(:csv_content) do
      <<~CSV
        日期,交易分类,交易类型,资金账户,流入金额,流出金额,备注
        2024-01-01,日常支出,消费,现金,0,100.00,午餐
        2024-01-02,日常收入,工资,银行,5000.00,0,工资
        2024-01-03,转账,转账,现金→银行,0,500.00,转账
        2024-01-04,日常支出,消费,现金,0,0,无金额
      CSV
    end

    let(:temp_file) do
      file = Tempfile.new([ "test", ".csv" ])
      file.write(csv_content)
      file.close
      file
    end

    after { temp_file.unlink }

    it "returns stats and sample data" do
      result = described_class.preview(temp_file.path)

      expect(result[:stats][:total]).to eq(4)
      expect(result[:stats][:valid]).to eq(2)
      expect(result[:stats][:transfers]).to eq(1)
      expect(result[:stats][:invalid]).to eq(1)
    end

    it "includes sample data" do
      result = described_class.preview(temp_file.path)

      expect(result[:sample_data]).to be_an(Array)
      expect(result[:sample_data].size).to be <= 10
    end
  end

  describe ".transfer?" do
    it "returns true for transfer categories" do
      expect(described_class.send(:transfer?, "转账", nil)).to be true
      expect(described_class.send(:transfer?, "信用卡还款", nil)).to be true
    end

    it "returns falsy for non-transfer categories" do
      expect(described_class.send(:transfer?, "日常支出", nil)).to be_falsy
      expect(described_class.send(:transfer?, "日常收入", nil)).to be_falsy
    end
  end
end
