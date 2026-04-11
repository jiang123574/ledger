# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings", type: :request do
  before do
    login
    allow(BackupService).to receive(:list_backups).and_return([])
  end

  describe "GET /settings" do
    it "returns success" do
      get settings_path
      expect(response).to have_http_status(:success)
    end

    context "general section" do
      it "returns success" do
        get settings_general_path
        expect(response).to have_http_status(:success)
      end
    end

    context "currencies section" do
      it "returns success" do
        get settings_currencies_path
        expect(response).to have_http_status(:success)
      end
    end

    context "data section" do
      it "returns success" do
        get settings_data_path
        expect(response).to have_http_status(:success)
      end
    end

    context "shortcuts section" do
      it "returns success" do
        get settings_shortcuts_path
        expect(response).to have_http_status(:success)
      end
    end

    context "danger section" do
      it "returns success" do
        get settings_danger_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /settings/export" do
    before do
      allow(ExportService).to receive(:transactions_to_csv).and_return("date,amount\n2024-01-01,100")
      allow(ExportService).to receive(:export_file_name).and_return("export_20240101.csv")
    end

    it "sends CSV file" do
      post export_transactions_path
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/csv")
    end
  end

  describe "POST /settings/import" do
    context "without file" do
      it "redirects with alert" do
        post import_transactions_path
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to eq("请选择要导入的文件")
      end
    end

    context "with non-CSV file" do
      it "redirects with alert" do
        file = Rack::Test::UploadedFile.new(
          StringIO.new("content"),
          "text/plain",
          original_filename: "test.txt"
        )
        post import_transactions_path, params: { file: file }
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to eq("请上传 CSV 格式的文件")
      end
    end
  end

  describe "POST /settings/validate_import" do
    context "without file" do
      it "returns JSON error" do
        post validate_import_path
        json = JSON.parse(response.body)
        expect(json["valid"]).to be false
        expect(json["errors"]).to include("请选择文件")
      end
    end
  end

  describe "POST /settings/backup" do
    context "when backup succeeds" do
      before do
        allow(BackupService).to receive(:create_backup).and_return({
          success: true,
          file_name: "backup.sql"
        })
        allow(BackupService).to receive(:cleanup_old_backups)
      end

      it "redirects with success notice" do
        post create_backup_path
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to include("backup.sql")
      end
    end

    context "when backup fails" do
      before do
        allow(BackupService).to receive(:create_backup).and_return({
          success: false,
          error: "备份失败"
        })
      end

      it "redirects with error alert" do
        post create_backup_path
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to eq("备份失败")
      end
    end
  end

  describe "POST /settings/shortcuts/reset" do
    it "redirects with success notice" do
      post reset_shortcuts_path
      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to be_present
    end
  end
end
