# frozen_string_literal: true

require "rails_helper"
require "tempfile"

RSpec.describe PixiuImportService do
  let(:valid_csv) do
    <<~CSV
      日期,资金账户,收支大类,交易分类,交易类型,流入金额,流出金额,备注
      2024-01-01,现金,日常支出,餐饮,午餐,0,50.00,午饭
      2024-01-02,银行卡,日常收入,工资,月薪,5000.00,0,一月工资
      2024-01-03,支付宝余额,转账,转账,转账/转到银行卡,0,1000.00,转账到银行卡
      2024-01-04,,日常支出,交通,打车,0,30.00,
    CSV
  end

  let(:csv_file) do
    file = Tempfile.new(["pixiu_test", ".csv"])
    file.write(valid_csv)
    file.rewind
    file
  end

  after { csv_file.close! }

  describe ".preview" do
    it "returns stats and sample data" do
      result = described_class.preview(csv_file.path)
      expect(result[:stats][:total]).to eq(4)
      expect(result[:stats][:valid]).to be >= 2
      expect(result[:sample_data]).to be_an(Array)
    end

    it "counts transfers" do
      result = described_class.preview(csv_file.path)
      expect(result[:stats][:transfers]).to be >= 1
    end

    it "skips blank date rows" do
      csv_with_blank = <<~CSV
        日期,资金账户,收支大类,交易分类,交易类型,流入金额,流出金额,备注
        2024-01-01,现金,日常支出,餐饮,午餐,0,50.00,午饭
        ,现金,日常支出,餐饮,晚餐,0,60.00,
      CSV
      file = Tempfile.new(["blank_test", ".csv"])
      file.write(csv_with_blank)
      file.rewind

      result = described_class.preview(file.path)
      expect(result[:stats][:total]).to eq(2)
    ensure
      file.close!
    end

    it "limits sample data to 10 items" do
      many_rows = "日期,资金账户,收支大类,交易分类,交易类型,流入金额,流出金额,备注\n"
      20.times do |i|
        many_rows += "2024-01-#{(i + 1).to_s.rjust(2, '0')},现金,日常支出,餐饮,午餐,0,#{i + 1}.00,备注#{i}\n"
      end
      file = Tempfile.new(["many_rows", ".csv"])
      file.write(many_rows)
      file.rewind

      result = described_class.preview(file.path)
      expect(result[:sample_data].size).to be <= 10
    ensure
      file.close!
    end
  end

  describe ".load_mappings" do
    it "returns accounts and categories maps" do
      result = described_class.load_mappings(csv_file.path)
      expect(result).to have_key(:accounts_map)
      expect(result).to have_key(:categories_map)
    end

    it "collects accounts from regular entries" do
      result = described_class.load_mappings(csv_file.path)
      expect(result[:accounts_map]).to be_a(Hash)
    end

    it "collects categories from regular entries" do
      result = described_class.load_mappings(csv_file.path)
      expect(result[:categories_map]).to be_a(Hash)
    end
  end

  describe ".import" do
    it "handles invalid date gracefully" do
      bad_csv = <<~CSV
        日期,资金账户,收支大类,交易分类,交易类型,流入金额,流出金额,备注
        not-a-date,现金,日常支出,餐饮,午餐,0,50.00,午饭
      CSV
      file = Tempfile.new(["bad_date", ".csv"])
      file.write(bad_csv)
      file.rewind

      result = described_class.import(file.path, {}, {})
      expect(result[:errors]).to be >= 1
    ensure
      file.close!
    end

    it "skips blank date rows" do
      blank_csv = <<~CSV
        日期,资金账户,收支大类,交易分类,交易类型,流入金额,流出金额,备注
        ,现金,日常支出,餐饮,午餐,0,50.00,午饭
      CSV
      file = Tempfile.new(["blank_date", ".csv"])
      file.write(blank_csv)
      file.rewind

      result = described_class.import(file.path, {}, {})
      expect(result[:imported]).to eq(0)
    ensure
      file.close!
    end
  end

  describe ".build_accounts_map (via load_mappings)" do
    it "creates accounts from CSV data" do
      result = described_class.load_mappings(csv_file.path)
      expect(result[:accounts_map]).to be_a(Hash)
      expect(result[:accounts_map].keys).to include("现金")
    end
  end

  describe ".build_categories_map (via load_mappings)" do
    it "creates categories from CSV data" do
      result = described_class.load_mappings(csv_file.path)
      expect(result[:categories_map]).to be_a(Hash)
    end
  end

  describe "constants" do
    it "defines EXPENSE_CATEGORIES" do
      expect(PixiuImportService::EXPENSE_CATEGORIES).to include("日常支出")
    end

    it "defines INCOME_CATEGORIES" do
      expect(PixiuImportService::INCOME_CATEGORIES).to include("日常收入")
    end

    it "defines TRANSFER_CATEGORIES" do
      expect(PixiuImportService::TRANSFER_CATEGORIES).to include("转账")
    end

    it "defines NON_TRANSFER_KEYWORDS" do
      expect(PixiuImportService::NON_TRANSFER_KEYWORDS).to include("手续费")
    end
  end
end
