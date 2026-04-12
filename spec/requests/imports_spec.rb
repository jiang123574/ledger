# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Imports", type: :request do
  before do
    login
  end

  describe "GET /imports/new" do
    it "returns success" do
      get new_import_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /imports/pixiu" do
    context "step 1" do
      it "returns success" do
        get pixiu_imports_path(step: 1)
        expect(response).to have_http_status(:success)
      end
    end

    context "step 2 without uploaded file" do
      it "redirects to step 1 with alert" do
        get pixiu_imports_path(step: 2)
        expect(response).to redirect_to(pixiu_imports_path(step: 1))
        expect(flash[:alert]).to eq("请先上传文件")
      end
    end

    context "step 3 without uploaded file" do
      it "redirects to step 1 with alert" do
        get pixiu_imports_path(step: 3)
        expect(response).to redirect_to(pixiu_imports_path(step: 1))
        expect(flash[:alert]).to eq("请先上传文件")
      end
    end

    context "step 4" do
      it "returns success" do
        get pixiu_imports_path(step: 4)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /imports/pixiu_upload" do
    context "without file" do
      it "redirects to step 1 with alert" do
        post pixiu_upload_imports_path
        expect(response).to redirect_to(pixiu_imports_path(step: 1))
        expect(flash[:alert]).to eq("请选择文件")
      end
    end

    context "with non-CSV file" do
      it "redirects to step 1 with alert" do
        file = Rack::Test::UploadedFile.new(
          StringIO.new("not a csv"),
          "text/plain",
          original_filename: "test.txt"
        )
        post pixiu_upload_imports_path, params: { file: file }
        expect(response).to redirect_to(pixiu_imports_path(step: 1))
        expect(flash[:alert]).to eq("请上传 CSV 文件")
      end
    end

    context "with valid CSV file" do
      let(:csv_content) do
        <<~CSV
          日期,交易分类,交易类型,资金账户,流入金额,流出金额,备注
          2024-01-01,日常支出,消费,现金,0,100.00,测试
        CSV
      end

      it "redirects to step 2" do
        file = Rack::Test::UploadedFile.new(
          StringIO.new(csv_content),
          "text/csv",
          original_filename: "test.csv"
        )
        post pixiu_upload_imports_path, params: { file: file }
        expect(response).to redirect_to(pixiu_imports_path(step: 2))
      end
    end
  end

  describe "POST /imports/pixiu_confirm" do
    context "without uploaded file" do
      it "redirects to step 1 with alert" do
        post pixiu_confirm_imports_path
        expect(response).to redirect_to(pixiu_imports_path(step: 1))
        expect(flash[:alert]).to eq("文件已过期，请重新上传")
      end
    end
  end
end
