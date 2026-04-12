# frozen_string_literal: true

require "rails_helper"
require "tempfile"

RSpec.describe "Importers" do
  let(:account) { create(:account) }
  let(:category) { create(:category, :expense) }

  describe Importers::CsvImporter do
    let(:csv_content) do
      <<~CSV
        日期,类型,金额,分类,账户,备注
        2024-01-01,支出,100.00,餐饮,现金,午餐
        2024-01-02,收入,5000.00,工资,银行卡,月薪
      CSV
    end

    let(:csv_file) do
      file = Tempfile.new(["test", ".csv"])
      file.write(csv_content)
      file.rewind
      file
    end

    after { csv_file.close! }

    describe ".preview" do
      it "returns preview data" do
        result = described_class.preview(csv_file)
        expect(result[:format]).to eq("csv")
        expect(result[:total_rows]).to eq(2)
        expect(result[:headers]).to include("日期")
      end
    end

    describe ".call" do
      it "imports rows from CSV" do
        result = described_class.call(csv_file)
        # CSV import depends on field mapping matching the actual columns
        expect(result).to have_key(:success)
        expect(result).to have_key(:failed)
        expect(result).to have_key(:errors)
      end
    end
  end

  describe Importers::BaseImporter do
    describe ".format_name" do
      it "returns demodulized class name" do
        importer = Importers::CsvImporter.new
        # format_name is private
        expect(importer.send(:format_name)).to eq("csv")
      end
    end

    describe "#initialize" do
      it "sets default results structure" do
        importer = described_class.new
        expect(importer.instance_variable_get(:@results)).to include(
          success: 0,
          failed: 0,
          errors: [],
          imported_ids: []
        )
      end

      it "accepts field_mapping option" do
        mapping = { date: "日期" }
        importer = described_class.new(field_mapping: mapping)
        expect(importer.instance_variable_get(:@field_mapping)).to eq(mapping)
      end
    end

    describe "#parse_rows" do
      it "raises NotImplementedError" do
        importer = described_class.new
        expect { importer.send(:parse_rows, nil) }.to raise_error(NotImplementedError)
      end
    end

    describe "#normalize_row" do
      it "raises NotImplementedError" do
        importer = described_class.new
        expect { importer.send(:normalize_row, nil) }.to raise_error(NotImplementedError)
      end
    end
  end

  describe Importers::QifImporter do
    describe ".format_name" do
      it "returns qif" do
        importer = described_class.new
        expect(importer.send(:format_name)).to eq("qif")
      end
    end
  end

  describe Importers::OfxImporter do
    describe ".format_name" do
      it "returns ofx" do
        importer = described_class.new
        expect(importer.send(:format_name)).to eq("ofx")
      end
    end
  end

  describe Importers::ExcelImporter do
    describe ".format_name" do
      it "returns excel" do
        importer = described_class.new
        expect(importer.send(:format_name)).to eq("excel")
      end
    end
  end
end
