# frozen_string_literal: true

require "rails_helper"

RSpec.describe Importers::ImportRowMapper do
  describe ".default_mapping" do
    it "returns a hash mapping Chinese headers to fields" do
      mapping = described_class.default_mapping
      expect(mapping["日期"]).to eq("date")
      expect(mapping["金额"]).to eq("amount")
      expect(mapping["类型"]).to eq("type")
    end

    it "includes English aliases" do
      mapping = described_class.default_mapping
      expect(mapping["date"]).to eq("date")
      expect(mapping["amount"]).to eq("amount")
      expect(mapping["type"]).to eq("type")
    end

    it "includes income/expense amount fields" do
      mapping = described_class.default_mapping
      expect(mapping["流入金额"]).to eq("income_amount")
      expect(mapping["流出金额"]).to eq("expense_amount")
    end
  end

  describe ".suggest_mapping" do
    it "maps known headers" do
      headers = [ "日期", "金额", "类型", "备注" ]
      result = described_class.suggest_mapping(headers)
      expect(result["日期"]).to eq("date")
      expect(result["金额"]).to eq("amount")
      expect(result["类型"]).to eq("type")
      expect(result["备注"]).to eq("note")
    end

    it "handles partial header matches" do
      headers = [ "交易时间", "金额（元）" ]
      result = described_class.suggest_mapping(headers)
      expect(result["交易时间"]).to eq("date")
      expect(result["金额（元）"]).to eq("amount")
    end

    it "returns empty for unknown headers" do
      headers = [ "未知字段", "Other" ]
      result = described_class.suggest_mapping(headers)
      expect(result).to be_empty
    end
  end

  describe ".map_row" do
    it "maps standard CSV row to structured data" do
      row = { "日期" => "2024-01-15", "类型" => "支出", "金额" => "100.50", "账户" => "现金", "备注" => "午餐" }
      result = described_class.map_row(row)

      expect(result[:date]).to eq(Date.new(2024, 1, 15))
      expect(result[:type]).to eq("EXPENSE")
      expect(result[:amount].to_f).to eq(100.50)
      expect(result[:account]).to eq("现金")
      expect(result[:note]).to eq("午餐")
    end

    it "maps income type" do
      row = { "类型" => "收入", "金额" => "5000" }
      result = described_class.map_row(row)
      expect(result[:type]).to eq("INCOME")
    end

    it "maps transfer type" do
      row = { "类型" => "转账" }
      result = described_class.map_row(row)
      expect(result[:type]).to eq("TRANSFER")
    end

    it "handles income/expense amounts" do
      row = { "流入金额" => "5000", "流出金额" => "0", "账户" => "银行卡" }
      result = described_class.map_row(row)
      expect(result[:type]).to eq("INCOME")
      expect(result[:amount].to_f).to eq(5000.0)
    end

    it "handles expense from income/expense amounts" do
      row = { "流入金额" => "0", "流出金额" => "100", "账户" => "现金" }
      result = described_class.map_row(row)
      expect(result[:type]).to eq("EXPENSE")
      expect(result[:amount].to_f).to eq(100.0)
    end

    it "handles transfer with → notation" do
      row = { "类型" => "转账", "流入金额" => "1000", "流出金额" => "1000", "账户" => "现金→银行卡" }
      result = described_class.map_row(row)
      expect(result[:type]).to eq("TRANSFER")
    end

    it "strips whitespace from values" do
      row = { "账户" => "  现金  ", "备注" => "  午餐  " }
      result = described_class.map_row(row)
      expect(result[:account]).to eq("现金")
      expect(result[:note]).to eq("午餐")
    end

    it "handles blank values" do
      row = { "日期" => "", "金额" => nil, "类型" => "  " }
      result = described_class.map_row(row)
      expect(result[:date]).to be_nil
      expect(result[:amount]).to be_nil
    end

    it "maps category fields" do
      row = { "收支大类" => "日常支出", "交易类型" => "餐饮" }
      result = described_class.map_row(row)
      expect(result[:category]).to eq("日常支出")
      expect(result[:sub_category]).to eq("餐饮")
    end

    it "maps currency field" do
      row = { "币种" => "USD" }
      result = described_class.map_row(row)
      expect(result[:currency]).to eq("USD")
    end

    it "maps tag field" do
      row = { "标签" => "工作" }
      result = described_class.map_row(row)
      expect(result[:tag]).to eq("工作")
    end

    it "uses custom mapping" do
      custom_mapping = { "Timestamp" => "date", "Value" => "amount" }
      row = { "Timestamp" => "2024-01-15", "Value" => "99.99" }
      result = described_class.map_row(row, custom_mapping)
      expect(result[:date]).to eq(Date.new(2024, 1, 15))
      expect(result[:amount].to_f).to eq(99.99)
    end
  end

  describe ".resolve_income_expense_amounts" do
    it "does nothing when both amounts are zero" do
      data = { type: nil, amount: nil, income_amount: nil, expense_amount: nil, account: "" }
      result = described_class.send(:resolve_income_expense_amounts, data)
      expect(result[:type]).to be_nil
    end

    it "sets income type when income amount > 0" do
      data = { type: nil, amount: nil, income_amount: 5000.0, expense_amount: 0.0, account: "银行卡" }
      result = described_class.send(:resolve_income_expense_amounts, data)
      expect(result[:type]).to eq("INCOME")
      expect(result[:amount].to_f).to eq(5000.0)
    end

    it "sets expense type when expense amount > 0" do
      data = { type: nil, amount: nil, income_amount: 0.0, expense_amount: 100.0, account: "现金" }
      result = described_class.send(:resolve_income_expense_amounts, data)
      expect(result[:type]).to eq("EXPENSE")
      expect(result[:amount].to_f).to eq(100.0)
    end

    it "detects transfer with → separator" do
      data = { type: "TRANSFER", amount: nil, income_amount: 1000.0, expense_amount: 1000.0, account: "现金→银行卡" }
      result = described_class.send(:resolve_income_expense_amounts, data)
      expect(result[:type]).to eq("TRANSFER")
    end
  end
end
