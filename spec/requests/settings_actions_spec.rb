# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings Actions", type: :request do
  before { login }

  describe "GET /settings" do
    it "renders general settings page" do
      get settings_path
      expect(response).to have_http_status(:ok)
    end

    it "renders categories section" do
      create(:category, :expense)
      get settings_path(section: "categories")
      expect(response).to have_http_status(:ok)
    end

    it "renders currencies section" do
      create(:currency, code: "CNY")
      get settings_path(section: "currencies")
      expect(response).to have_http_status(:ok)
    end

    it "renders contacts section" do
      get settings_path(section: "contacts")
      expect(response).to have_http_status(:ok)
    end

    it "renders data section" do
      get settings_path(section: "data")
      expect(response).to have_http_status(:ok)
    end

    it "renders danger section" do
      get settings_path(section: "danger")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /settings/export" do
    it "exports transactions as CSV" do
      create(:entry, account: create(:account))
      post export_transactions_path
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end
  end

  describe "POST /settings/backup" do
    it "creates a backup and redirects on success" do
      allow(BackupService).to receive(:create_backup).and_return(
        { success: true, file_name: "test_backup.sql", file_path: "/tmp/test.sql" }
      )
      post create_backup_path
      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to include("备份已创建")
    end

    it "redirects with alert on failure" do
      allow(BackupService).to receive(:create_backup).and_return(
        { success: false, error: "备份失败" }
      )
      post create_backup_path
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("备份失败")
    end
  end

  describe "POST /settings/validate_import" do
    it "returns error when no file provided" do
      post validate_import_path
      json = JSON.parse(response.body)
      expect(json["valid"]).to be false
      expect(json["errors"]).to include("请选择文件")
    end
  end

  describe "POST /settings/import" do
    it "redirects with alert when no file provided" do
      post import_transactions_path
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("请选择要导入的文件")
    end

    it "rejects non-CSV files" do
      file = Rack::Test::UploadedFile.new(StringIO.new("content"), "text/plain", original_filename: "test.txt")
      post import_transactions_path, params: { file: file }
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("请上传 CSV 格式的文件")
    end
  end

  describe "POST /settings/clear_data" do
    it "rejects without password confirmation" do
      post clear_all_data_path
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("确认密码错误，操作已取消")
    end

    it "rejects with wrong password" do
      post clear_all_data_path, params: { confirm_password: "wrong" }
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("确认密码错误，操作已取消")
    end

    it "clears all data with correct password" do
      account = create(:account)
      post clear_all_data_path, params: { confirm_password: "testpass" }
      expect(response).to redirect_to(settings_path)
      expect(flash[:notice]).to eq("所有数据已清除")
      expect(Account.count).to eq(0)
    end
  end

  describe "POST /settings/restore_upload" do
    it "redirects with alert when no file provided" do
      post restore_upload_settings_backup_path
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("请选择要恢复的备份文件")
    end

    it "rejects without password confirmation" do
      file = Rack::Test::UploadedFile.new(StringIO.new("SELECT 1;"), "application/sql", original_filename: "backup.sql")
      post restore_upload_settings_backup_path, params: { backup_file: file }
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("确认密码错误，操作已取消")
    end
  end

  describe "GET /settings/backup/:name" do
    it "redirects with alert when file not found" do
      get download_settings_backup_path(name: "nonexistent")
      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq("备份文件不存在")
    end

    it "sends backup file when it exists" do
      backup_dir = Rails.root.join("tmp", "backups")
      FileUtils.mkdir_p(backup_dir)
      backup_file = backup_dir.join("test_backup.sql")
      File.write(backup_file, "SELECT 1;")

      begin
        get download_settings_backup_path(name: "test_backup")
        expect(response).to have_http_status(:ok)
      ensure
        File.delete(backup_file) if File.exist?(backup_file)
      end
    end
  end
end
