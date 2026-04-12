# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe "Importers" do
  # ============================================================
  # QIF Importer
  # ============================================================
  describe Importers::QifImporter do
    let(:importer) { described_class.new(account_name: "Test Account") }

    describe "#format_name" do
      it "returns 'qif'" do
        expect(importer.send(:format_name)).to eq("qif")
      end
    end

    describe "#parse_rows" do
      it "parses a standard Bank type QIF file" do
        qif_content = <<~QIF
          !Type:Bank
          D03/03/2024
          T-100.00
          PCoffee Shop
          LFood:Dining
          ^
          D03/04/2024
          T2500.00
          PSalary
          LIncome:Salary
          ^
        QIF

        file = Tempfile.new(["test", ".qif"])
        file.write(qif_content)
        file.rewind

        rows = importer.send(:parse_rows, file)
        expect(rows.size).to eq(2)

        expect(rows[0][:date]).to eq("03/03/2024")
        expect(rows[0][:amount]).to eq(BigDecimal("-100.00"))
        expect(rows[0][:payee]).to eq("Coffee Shop")
        expect(rows[0][:category]).to eq("Food:Dining")

        expect(rows[1][:date]).to eq("03/04/2024")
        expect(rows[1][:amount]).to eq(BigDecimal("2500.00"))
        expect(rows[1][:payee]).to eq("Salary")
        expect(rows[1][:category]).to eq("Income:Salary")

        file.close
        file.unlink
      end

      it "parses a Cash type QIF file" do
        qif_content = <<~QIF
          !Type:Cash
          D01/15/2024
          T-50.00
          PGrocery Store
          LGroceries
          ^
          D01/16/2024
          T-30.50
          PBus Fare
          LTransport
          ^
        QIF

        file = Tempfile.new(["test", ".qif"])
        file.write(qif_content)
        file.rewind

        rows = importer.send(:parse_rows, file)
        expect(rows.size).to eq(2)
        expect(rows[0][:payee]).to eq("Grocery Store")
        expect(rows[1][:amount]).to eq(BigDecimal("-30.50"))

        file.close
        file.unlink
      end

      it "parses QIF with memo fields" do
        qif_content = <<~QIF
          !Type:Bank
          D05/01/2024
          T-25.00
          PRestaurant
          MLunch with friends
          LFood
          ^
        QIF

        file = Tempfile.new(["memo", ".qif"])
        file.write(qif_content)
        file.rewind

        rows = importer.send(:parse_rows, file)
        expect(rows.size).to eq(1)
        expect(rows[0][:memo]).to eq("Lunch with friends")
        expect(rows[0][:payee]).to eq("Restaurant")

        file.close
        file.unlink
      end

      it "skips transactions missing date or amount" do
        qif_content = <<~QIF
          !Type:Bank
          D03/03/2024
          T-100.00
          PValid Transaction
          ^
          PNo Date Transaction
          ^
          D03/05/2024
          PNo Amount Transaction
          ^
        QIF

        file = Tempfile.new(["partial", ".qif"])
        file.write(qif_content)
        file.rewind

        rows = importer.send(:parse_rows, file)
        # Only the first transaction has both date and amount
        expect(rows.size).to eq(1)
        expect(rows[0][:payee]).to eq("Valid Transaction")

        file.close
        file.unlink
      end

      it "handles empty QIF file" do
        qif_content = "!Type:Bank\n"

        file = Tempfile.new(["empty", ".qif"])
        file.write(qif_content)
        file.rewind

        rows = importer.send(:parse_rows, file)
        expect(rows).to be_empty

        file.close
        file.unlink
      end

      it "handles multiple transactions with various amounts" do
        qif_content = <<~QIF
          !Type:Bank
          D03/01/2024
          T1,500.00
          PIncome with comma
          ^
          D03/02/2024
          T-75.50
          PExpense
          ^
          D03/03/2024
          T0.00
          PZero amount
          ^
        QIF

        file = Tempfile.new(["multi", ".qif"])
        file.write(qif_content)
        file.rewind

        rows = importer.send(:parse_rows, file)
        expect(rows.size).to eq(3)
        # AmountParser strips commas
        expect(rows[0][:amount]).to eq(BigDecimal("1500.00"))
        expect(rows[1][:amount]).to eq(BigDecimal("-75.50"))
        expect(rows[2][:amount]).to eq(BigDecimal("0.00"))

        file.close
        file.unlink
      end
    end

    describe "#normalize_row" do
      it "converts raw QIF data to normalized hash" do
        raw = {
          date: "03/03/2024",
          amount: BigDecimal("-100.00"),
          payee: "Coffee Shop",
          category: "Food:Dining",
          memo: "Morning coffee"
        }

        result = importer.send(:normalize_row, raw)
        expect(result["日期"]).to eq("03/03/2024")
        expect(result["金额"]).to eq(BigDecimal("-100.00"))
        expect(result["收款人"]).to eq("Coffee Shop")
        expect(result["分类"]).to eq("Food:Dining")
      end

      it "handles row with nil values" do
        raw = { date: nil, amount: nil, payee: nil, category: nil }

        result = importer.send(:normalize_row, raw)
        expect(result["日期"]).to be_nil
        expect(result["金额"]).to be_nil
        expect(result["收款人"]).to be_nil
        expect(result["分类"]).to be_nil
      end
    end

    describe "#import_row" do
      it "creates an Entry for a valid expense transaction" do
        row = {
          "日期" => "03/03/2024",
          "金额" => BigDecimal("-50.00"),
          "收款人" => "Test Payee",
          "分类" => "Test Category"
        }

        expect { importer.send(:import_row, row, 0) }.to change(Entry, :count).by(1)

        entry = Entry.last
        expect(entry.name).to eq("Test Payee")
        expect(entry.amount).to eq(BigDecimal("-50.00"))
      end

      it "creates an Entry for a valid income transaction" do
        row = {
          "日期" => "03/03/2024",
          "金额" => BigDecimal("1000.00"),
          "收款人" => "Employer",
          "分类" => "Salary"
        }

        expect { importer.send(:import_row, row, 0) }.to change(Entry, :count).by(1)

        entry = Entry.last
        expect(entry.amount).to eq(BigDecimal("1000.00"))
      end

      it "skips rows with zero amount and no date" do
        row = { "日期" => nil, "金额" => BigDecimal("0"), "收款人" => nil, "分类" => nil }

        expect { importer.send(:import_row, row, 0) }.not_to change(Entry, :count)
      end
    end

    describe "#preview" do
      it "returns preview data for QIF file" do
        qif_content = <<~QIF
          !Type:Bank
          D03/03/2024
          T-100.00
          PCoffee
          ^
          D03/04/2024
          T200.00
          PSalary
          ^
        QIF

        file = Tempfile.new(["preview", ".qif"])
        file.write(qif_content)
        file.rewind

        # preview is private on instances; call via send
        result = importer.send(:preview, file)
        expect(result[:format]).to eq("qif")
        expect(result[:headers]).to eq([ "日期", "金额", "收款人", "分类" ])
        expect(result[:rows].size).to eq(2)
        expect(result[:total_rows]).to eq(2)

        file.close
        file.unlink
      end
    end

    describe "#parse_qif_date" do
      it "parses MM/DD/YYYY format" do
        date = importer.send(:parse_qif_date, "03/15/2024")
        expect(date).to eq(Date.new(2024, 3, 15))
      end

      it "parses DD/MM/YYYY format" do
        date = importer.send(:parse_qif_date, "15/03/2024")
        expect(date).to eq(Date.new(2024, 3, 15))
      end

      it "parses YYYY-MM-DD format" do
        date = importer.send(:parse_qif_date, "2024-03-15")
        expect(date).to eq(Date.new(2024, 3, 15))
      end

      it "returns current date for blank input" do
        date = importer.send(:parse_qif_date, nil)
        expect(date).to eq(Date.current)
      end

      it "returns current date for unparseable input" do
        date = importer.send(:parse_qif_date, "not-a-date")
        expect(date).to eq(Date.current)
      end

      it "handles short year format" do
        date = importer.send(:parse_qif_date, "03/15'24")
        expect(date).to eq(Date.new(2024, 3, 15))
      end
    end
  end

  # ============================================================
  # OFX Importer
  # ============================================================
  describe Importers::OfxImporter do
    let(:importer) { described_class.new(account_name: "OFX Account") }

    describe "#format_name" do
      it "returns 'ofx'" do
        expect(importer.send(:format_name)).to eq("ofx")
      end
    end

    describe "#normalize_row" do
      it "extracts metadata and returns the raw row" do
        raw = {
          "日期" => Date.new(2024, 3, 3),
          "金额" => BigDecimal("-50.00"),
          "描述" => "Test Transaction",
          "FIT_ID" => "FIT123",
          "_account_name" => "My Bank",
          "_currency" => "USD"
        }

        result = importer.send(:normalize_row, raw)
        expect(result["日期"]).to eq(Date.new(2024, 3, 3))
        expect(result["金额"]).to eq(BigDecimal("-50.00"))
        expect(result["描述"]).to eq("Test Transaction")
        expect(result["FIT_ID"]).to eq("FIT123")
        # Metadata should be removed from the returned hash
        expect(result).not_to have_key("_account_name")
        expect(result).not_to have_key("_currency")
      end

      it "stores account name and currency in instance variables" do
        raw = {
          "日期" => Date.new(2024, 3, 3),
          "金额" => BigDecimal("100.00"),
          "描述" => "Deposit",
          "FIT_ID" => "FIT456",
          "_account_name" => "Savings",
          "_currency" => "EUR"
        }

        importer.send(:normalize_row, raw)
        expect(importer.instance_variable_get(:@ofx_account_name)).to eq("Savings")
        expect(importer.instance_variable_get(:@ofx_currency)).to eq("EUR")
      end

      it "handles row without metadata fields" do
        raw = {
          "日期" => Date.new(2024, 1, 1),
          "金额" => BigDecimal("200.00"),
          "描述" => "ATM Withdrawal",
          "FIT_ID" => "FIT789"
        }

        result = importer.send(:normalize_row, raw)
        expect(result["日期"]).to eq(Date.new(2024, 1, 1))
        expect(result["描述"]).to eq("ATM Withdrawal")
      end
    end

    describe "#import_row" do
      it "creates an Entry for an expense OFX transaction" do
        importer.send(:normalize_row, {
          "日期" => Date.new(2024, 3, 3),
          "金额" => BigDecimal("-75.50"),
          "描述" => "Store Purchase",
          "FIT_ID" => "FIT001",
          "_account_name" => "Checking",
          "_currency" => "CNY"
        })

        row = {
          "日期" => Date.new(2024, 3, 3),
          "金额" => BigDecimal("-75.50"),
          "描述" => "Store Purchase",
          "FIT_ID" => "FIT001"
        }

        expect { importer.send(:import_row, row, 0) }.to change(Entry, :count).by(1)

        entry = Entry.last
        expect(entry.name).to eq("Store Purchase")
      end

      it "creates an Entry for an income OFX transaction" do
        importer.send(:normalize_row, {
          "日期" => Date.new(2024, 3, 3),
          "金额" => BigDecimal("3000.00"),
          "描述" => "Direct Deposit",
          "FIT_ID" => "FIT002",
          "_account_name" => "Checking",
          "_currency" => "CNY"
        })

        row = {
          "日期" => Date.new(2024, 3, 3),
          "金额" => BigDecimal("3000.00"),
          "描述" => "Direct Deposit",
          "FIT_ID" => "FIT002"
        }

        expect { importer.send(:import_row, row, 0) }.to change(Entry, :count).by(1)

        entry = Entry.last
        expect(entry.amount).to eq(BigDecimal("3000.00"))
      end

      it "skips rows with zero amount and no date" do
        row = {
          "日期" => nil,
          "金额" => BigDecimal("0"),
          "描述" => nil,
          "FIT_ID" => nil
        }

        expect { importer.send(:import_row, row, 0) }.not_to change(Entry, :count)
      end
    end

    describe "SUPPORTED_HEADERS" do
      it "defines the expected OFX headers" do
        expect(Importers::OfxImporter::SUPPORTED_HEADERS).to eq(%w[日期 金额 描述 FIT_ID])
      end
    end
  end

  # Helper to wrap a Tempfile with original_filename for ImportService
  def fake_upload(filename, content)
    file = Tempfile.new(["upload", File.extname(filename)])
    file.write(content)
    file.rewind
    wrapper = OpenStruct.new(
      path: file.path,
      original_filename: filename,
      size: file.size,
      tempfile: file
    )
    wrapper.define_singleton_method(:close) { file.close; file.unlink }
    wrapper
  end

  # ============================================================
  # ImportService
  # ============================================================
  describe ImportService do
    describe ".detect_format" do
      it "detects csv format" do
        file = double("file", original_filename: "transactions.csv")
        expect(ImportService.send(:detect_format, file)).to eq("csv")
      end

      it "detects xlsx format" do
        file = double("file", original_filename: "transactions.xlsx")
        expect(ImportService.send(:detect_format, file)).to eq("xlsx")
      end

      it "detects xls format and normalizes to xlsx" do
        file = double("file", original_filename: "transactions.xls")
        expect(ImportService.send(:detect_format, file)).to eq("xlsx")
      end

      it "detects ofx format" do
        file = double("file", original_filename: "bank.ofx")
        expect(ImportService.send(:detect_format, file)).to eq("ofx")
      end

      it "detects qif format" do
        file = double("file", original_filename: "bank.qif")
        expect(ImportService.send(:detect_format, file)).to eq("qif")
      end

      it "handles uppercase extensions" do
        file = double("file", original_filename: "data.CSV")
        expect(ImportService.send(:detect_format, file)).to eq("csv")
      end

      it "returns unknown for unsupported format" do
        file = double("file", original_filename: "data.txt")
        expect(ImportService.send(:detect_format, file)).to eq("txt")
      end
    end

    describe ".importer_for" do
      it "returns CsvImporter for csv files" do
        file = double("file", original_filename: "data.csv")
        expect(ImportService.send(:importer_for, file)).to eq(Importers::CsvImporter)
      end

      it "returns ExcelImporter for xlsx files" do
        file = double("file", original_filename: "data.xlsx")
        expect(ImportService.send(:importer_for, file)).to eq(Importers::ExcelImporter)
      end

      it "returns ExcelImporter for xls files" do
        file = double("file", original_filename: "data.xls")
        expect(ImportService.send(:importer_for, file)).to eq(Importers::ExcelImporter)
      end

      it "returns OfxImporter for ofx files" do
        file = double("file", original_filename: "data.ofx")
        expect(ImportService.send(:importer_for, file)).to eq(Importers::OfxImporter)
      end

      it "returns QifImporter for qif files" do
        file = double("file", original_filename: "data.qif")
        expect(ImportService.send(:importer_for, file)).to eq(Importers::QifImporter)
      end

      it "raises ImportError for unsupported format" do
        file = double("file", original_filename: "data.txt")
        expect { ImportService.send(:importer_for, file) }.to raise_error(ImportService::ImportError)
      end
    end

    describe ".validate_file" do
      it "returns valid for a good csv file" do
        file = fake_upload("test.csv", "日期,金额,类型\n2024-01-01,100,收入\n")
        result = ImportService.validate_file(file)
        expect(result[:valid]).to be true
        expect(result[:format]).to eq("csv")
        expect(result[:errors]).to be_empty
        file.close
      end

      it "returns error for unsupported format" do
        file = fake_upload("test.xyz", "some data")
        result = ImportService.validate_file(file)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(a_string_matching(/unsupported|不支持/))
        file.close
      end

      it "returns error for file exceeding 10MB" do
        file = fake_upload("large.csv", "header\n")
        allow(file).to receive(:size).and_return(11.megabytes)
        result = ImportService.validate_file(file)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(a_string_matching(/10MB/))
        file.close
      end

      it "passes validation for ofx files without content check" do
        file = fake_upload("bank.ofx", "<OFX>data</OFX>")
        result = ImportService.validate_file(file)
        expect(result[:valid]).to be true
        expect(result[:format]).to eq("ofx")
        file.close
      end

      it "passes validation for qif files without content check" do
        file = fake_upload("bank.qif", "!Type:Bank\nD03/03/2024\nT-100.00\n^\n")
        result = ImportService.validate_file(file)
        expect(result[:valid]).to be true
        expect(result[:format]).to eq("qif")
        file.close
      end
    end

    describe ".import_transactions_csv" do
      it "delegates to import with field_mapping" do
        file = double("file", original_filename: "data.csv")
        mapping = { "日期" => "date" }

        expect(ImportService).to receive(:import).with(file, field_mapping: mapping)
        ImportService.import_transactions_csv(file, mapping)
      end

      it "delegates to import without mapping" do
        file = double("file", original_filename: "data.csv")

        expect(ImportService).to receive(:import).with(file, field_mapping: nil)
        ImportService.import_transactions_csv(file)
      end
    end

    describe ".validate_csv" do
      it "returns errors array from validate_file" do
        file = fake_upload("data.csv", "header\n")
        # validate_csv delegates to validate_file
        errors = ImportService.validate_csv(file)
        expect(errors).to be_an(Array)
        file.close
      end
    end

    describe ".templates" do
      it "returns the template array" do
        templates = ImportService.templates
        expect(templates).to be_an(Array)
        expect(templates.size).to eq(3)
        expect(templates.map { |t| t[:name] }).to include("标准格式", "支付宝格式", "微信支付格式")
      end
    end

    describe ".default_csv_mapping" do
      it "returns a mapping hash" do
        mapping = ImportService.default_csv_mapping
        expect(mapping).to be_a(Hash)
        expect(mapping).to have_key("日期")
      end
    end

    describe "SUPPORTED_FORMATS" do
      it "includes all expected formats" do
        expect(ImportService::SUPPORTED_FORMATS).to eq(%w[csv xlsx xls ofx qif])
      end
    end

    describe "FORMAT_IMPORTERS" do
      it "maps each format to its importer class" do
        expect(ImportService::FORMAT_IMPORTERS["csv"]).to eq(Importers::CsvImporter)
        expect(ImportService::FORMAT_IMPORTERS["xlsx"]).to eq(Importers::ExcelImporter)
        expect(ImportService::FORMAT_IMPORTERS["xls"]).to eq(Importers::ExcelImporter)
        expect(ImportService::FORMAT_IMPORTERS["ofx"]).to eq(Importers::OfxImporter)
        expect(ImportService::FORMAT_IMPORTERS["qif"]).to eq(Importers::QifImporter)
      end
    end

    describe ".import with CSV" do
      it "returns import result hash" do
        csv_data = "日期,类型,金额,备注\n2024-01-15,支出,50.00,午餐\n"
        file = fake_upload("import.csv", csv_data)

        result = ImportService.import(file)
        expect(result).to have_key(:success)
        expect(result).to have_key(:failed)
        expect(result).to have_key(:errors)
        expect(result[:success]).to be_a(Integer)
        expect(result[:failed]).to be_a(Integer)
      end
    end
  end
end
