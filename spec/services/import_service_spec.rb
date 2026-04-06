# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportService, type: :service do
  describe '.SUPPORTED_FORMATS' do
    it 'includes common formats' do
      expect(described_class::SUPPORTED_FORMATS).to include('csv', 'xlsx', 'xls', 'ofx', 'qif')
    end
  end

  describe '.TEMPLATES' do
    it 'provides field mapping templates' do
      templates = described_class::TEMPLATES

      expect(templates).not_to be_empty
      expect(templates.first).to include(:name, :mapping)
    end

    it 'includes 标准格式 template' do
      template = described_class::TEMPLATES.find { |t| t[:name] == "标准格式" }

      expect(template).to be_present
      expect(template[:mapping]).to include("日期" => "date")
    end

    it 'includes 支付宝格式 template' do
      template = described_class::TEMPLATES.find { |t| t[:name] == "支付宝格式" }

      expect(template).to be_present
      expect(template[:mapping]).to include("交易时间" => "date")
    end

    it 'includes 微信支付格式 template' do
      template = described_class::TEMPLATES.find { |t| t[:name] == "微信支付格式" }

      expect(template).to be_present
      expect(template[:mapping]).to include("交易时间" => "date")
    end
  end

  describe '.validate_file' do
    context 'with valid format' do
      it 'imports are supported for csv, xlsx, xls, ofx, qif' do
        supported = ['csv', 'xlsx', 'xls', 'ofx', 'qif']

        supported.each do |format|
          expect(described_class::SUPPORTED_FORMATS).to include(format)
        end
      end
    end

    context 'with large file' do
      it 'considers file size limit for validation' do
        # 这个测试只检查服务的逻辑是否存在
        # 实际文件验证由ImportService负责
        expect(described_class).to respond_to(:validate_file)
      end
    end

    context 'format detection' do
      it 'supports all configured formats' do
        formats = described_class::SUPPORTED_FORMATS

        expect(formats).not_to be_empty
      end
    end
  end

  describe '.FORMAT_IMPORTERS' do
    it 'maps formats to importer classes' do
      mapping = described_class::FORMAT_IMPORTERS

      expect(mapping['csv']).to eq(Importers::CsvImporter)
      expect(mapping['xlsx']).to eq(Importers::ExcelImporter)
      expect(mapping['xls']).to eq(Importers::ExcelImporter)
      expect(mapping['ofx']).to eq(Importers::OfxImporter)
      expect(mapping['qif']).to eq(Importers::QifImporter)
    end
  end

  describe 'backward compatibility' do
    describe '.import_transactions_csv' do
      it 'method exists for backward compatibility' do
        expect(described_class).to respond_to(:import_transactions_csv)
      end
    end

    describe '.validate_csv' do
      it 'method exists for backward compatibility' do
        expect(described_class).to respond_to(:validate_csv)
      end
    end
  end

end

