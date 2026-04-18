# frozen_string_literal: true

require "rails_helper"

RSpec.describe BackupsController, type: :request do
  let(:backup_dir) { BackupService::BACKUP_DIR }
  let(:config_file) { BackupConfig::CONFIG_FILE }

  before { login }

  after do
    FileUtils.rm_rf(backup_dir)
    File.delete(config_file) if File.exist?(config_file)
  end

  # Helper to mock pg_dump success by simulating file creation
  def stub_pg_dump_success
    status = double(success?: true)
    allow(Open3).to receive(:capture3) do |env, *cmd|
      if cmd.include?("-f")
        idx = cmd.index("-f")
        file_path = cmd[idx + 1]
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, "DUMP DATA")
      end
      [ "", "", status ]
    end
  end

  def stub_pg_dump_failure(error_msg = "error")
    status = double(success?: false)
    allow(Open3).to receive(:capture3).and_return([ "", error_msg, status ])
  end

  def stub_psql_success
    status = double(success?: true)
    allow(Open3).to receive(:capture3).and_return([ "", "", status ])
  end

  def stub_psql_failure(error_msg = "error")
    status = double(success?: false)
    allow(Open3).to receive(:capture3).and_return([ "", error_msg, status ])
  end

  describe "GET /backups (index)" do
    it "returns success" do
      get backups_path
      expect(response).to have_http_status(:success)
    end

    it "renders the index page" do
      get backups_path
      expect(response.body).to be_present
    end

    it "shows existing backups" do
      create(:backup_record, filename: "recent_backup.sql")
      get backups_path
      expect(response.body).to include("recent_backup.sql")
    end

    it "shows webdav section when configured" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      get backups_path
      expect(response).to have_http_status(:success)
    end

    it "shows auto backup status when enabled" do
      BackupService.enable_auto_backup
      get backups_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /backups (create)" do
    it "creates a backup and redirects with notice" do
      stub_pg_dump_success

      post backups_path
      expect(response).to redirect_to(backups_path)
      expect(flash[:notice]).to be_present
    end

    it "redirects with alert on failure" do
      stub_pg_dump_failure("pg_dump error")

      post backups_path
      expect(response).to redirect_to(backups_path)
      expect(flash[:alert]).to be_present
    end

    it "creates a backup record in database" do
      stub_pg_dump_success

      expect { post backups_path }.to change(BackupRecord, :count).by(1)
    end

    it "sets backup type to manual by default" do
      stub_pg_dump_success

      post backups_path
      expect(BackupRecord.last.backup_type).to eq("manual")
    end

    it "accepts type parameter" do
      stub_pg_dump_success

      post backups_path, params: { type: "auto" }
      expect(BackupRecord.last.backup_type).to eq("auto")
    end

    it "skips sync when sync param is false" do
      stub_pg_dump_success
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:upload)

      post backups_path, params: { sync: "false" }

      expect(webdav_client).not_to have_received(:upload)
    end
  end

  describe "GET /backups/:id/download" do
    it "sends the backup file" do
      file_path = backup_dir.join("dl_test.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "BACKUP DATA")

      record = create(:backup_record, filename: "dl_test.sql", file_path: file_path.to_s)

      get download_backup_path(record)
      expect(response).to have_http_status(:success)
      expect(response.header["Content-Disposition"]).to include("dl_test.sql")
    end

    it "sets content type to octet-stream" do
      file_path = backup_dir.join("dl_ct.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "DATA")

      record = create(:backup_record, filename: "dl_ct.sql", file_path: file_path.to_s)

      get download_backup_path(record)
      expect(response.header["Content-Type"]).to include("application/octet-stream")
    end

    it "redirects with alert when file does not exist" do
      record = create(:backup_record, filename: "missing_dl.sql", file_path: "/nonexistent/missing_dl.sql")

      get download_backup_path(record)
      expect(response).to redirect_to(backups_path)
      expect(flash[:alert]).to eq("备份文件不存在")
    end
  end

  describe "POST /backups/:id/restore" do
    it "restores backup and redirects with notice" do
      file_path = backup_dir.join("restore_req.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "SQL DATA")

      record = create(:backup_record, filename: "restore_req.sql", file_path: file_path.to_s)

      stub_psql_success

      post restore_backup_path(record)
      expect(response).to redirect_to(backups_path)
      expect(flash[:notice]).to eq("数据已从备份恢复")
    end

    it "redirects with alert on restore failure" do
      file_path = backup_dir.join("restore_fail_req.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "SQL DATA")

      record = create(:backup_record, filename: "restore_fail_req.sql", file_path: file_path.to_s)

      stub_psql_failure("restore error")

      post restore_backup_path(record)
      expect(response).to redirect_to(backups_path)
      expect(flash[:alert]).to be_present
    end

    it "calls BackupService.restore_backup" do
      file_path = backup_dir.join("restore_spy.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "SQL DATA")

      record = create(:backup_record, filename: "restore_spy.sql", file_path: file_path.to_s)

      stub_psql_success
      expect(BackupService).to receive(:restore_backup).with(file_path.to_s).and_call_original

      post restore_backup_path(record)
    end
  end

  describe "DELETE /backups/:id (destroy)" do
    it "deletes backup and redirects with notice" do
      file_path = backup_dir.join("destroy_req.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "DATA")

      record = create(:backup_record, filename: "destroy_req.sql", file_path: file_path.to_s)

      delete backup_path(record)
      expect(response).to redirect_to(backups_path)
      expect(flash[:notice]).to eq("备份已删除")
      expect(BackupRecord.find_by(id: record.id)).to be_nil
    end

    it "deletes the file from disk" do
      file_path = backup_dir.join("destroy_file.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "DATA")

      record = create(:backup_record, filename: "destroy_file.sql", file_path: file_path.to_s)

      delete backup_path(record)
      expect(File.exist?(file_path)).to be false
    end

    it "handles non-existent record" do
      # Create then delete directly
      record = create(:backup_record, file_path: "/tmp/gone.sql")
      BackupRecord.where(id: record.id).delete_all

      delete backup_path(id: record.id)
      expect(response).to redirect_to(backups_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /backups/webdav_connect" do
    it "configures webdav and redirects with notice" do
      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:test_connection).and_return({ success: true, message: "连接成功" })

      post webdav_connect_backups_path, params: {
        url: "https://dav.example.com",
        username: "user",
        password: "pass",
        directory: "/backups"
      }

      expect(response).to redirect_to(backups_path)
      expect(flash[:notice]).to eq("WebDAV 连接成功")
    end

    it "redirects with alert on failure" do
      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:test_connection).and_return({ success: false, error: "连接失败" })

      post webdav_connect_backups_path, params: {
        url: "https://dav.example.com",
        username: "user",
        password: "pass"
      }

      expect(response).to redirect_to(backups_path)
      expect(flash[:alert]).to eq("连接失败")
    end

    it "saves webdav configuration" do
      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:test_connection).and_return({ success: true })

      post webdav_connect_backups_path, params: {
        url: "https://dav.example.com",
        username: "admin",
        password: "secret",
        directory: "/data"
      }

      expect(BackupConfig.webdav_configured?).to be true
      config = BackupConfig.webdav_config
      expect(config[:url]).to eq("https://dav.example.com")
      expect(config[:username]).to eq("admin")
    end
  end

  describe "GET /backups/webdav_test" do
    it "returns json with failure when not configured" do
      get webdav_test_backups_path
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["error"]).to eq("WebDAV 未配置")
    end

    it "returns json with success when configured and connection works" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:test_connection).and_return({ success: true, message: "OK" })

      get webdav_test_backups_path
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end

    it "returns json with failure when connection fails" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:test_connection).and_return({ success: false, error: "timeout" })

      get webdav_test_backups_path
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
      expect(json["error"]).to eq("timeout")
    end
  end

  describe "POST /backups/enable_auto_backup" do
    it "enables auto backup and redirects with notice" do
      post enable_auto_backup_backups_path, params: { frequency: "daily", retention: 7 }
      expect(response).to redirect_to(backups_path)
      expect(flash[:notice]).to eq("自动备份已启用")
      expect(BackupService.auto_backup_enabled?).to be true
    end

    it "uses default parameters when none provided" do
      post enable_auto_backup_backups_path
      expect(response).to redirect_to(backups_path)
      config = BackupConfig.auto_backup_config
      expect(config["frequency"]).to eq("daily")
      expect(config["retention_count"]).to eq(10)
    end

    it "passes webdav_sync parameter as true" do
      post enable_auto_backup_backups_path, params: { webdav_sync: "true" }
      config = BackupConfig.auto_backup_config
      expect(config["webdav_sync"]).to be true
    end

    it "passes webdav_sync parameter as false by default" do
      post enable_auto_backup_backups_path
      config = BackupConfig.auto_backup_config
      expect(config["webdav_sync"]).to be false
    end

    it "accepts custom frequency" do
      post enable_auto_backup_backups_path, params: { frequency: "weekly" }
      config = BackupConfig.auto_backup_config
      expect(config["frequency"]).to eq("weekly")
    end

    it "accepts custom retention" do
      post enable_auto_backup_backups_path, params: { retention: 5 }
      config = BackupConfig.auto_backup_config
      # Controller passes params directly (string), config stores as-is
      expect(config["retention_count"].to_s).to eq("5")
    end
  end

  describe "POST /backups/disable_auto_backup" do
    it "disables auto backup and redirects with notice" do
      BackupService.enable_auto_backup

      post disable_auto_backup_backups_path
      expect(response).to redirect_to(backups_path)
      expect(flash[:notice]).to eq("自动备份已禁用")
      expect(BackupService.auto_backup_enabled?).to be false
    end

    it "redirects successfully even when already disabled" do
      post disable_auto_backup_backups_path
      expect(response).to redirect_to(backups_path)
    end
  end

  describe "POST /backups/:id/webdav_upload" do
    it "uploads backup to webdav and redirects with notice" do
      file_path = backup_dir.join("upload_req.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "DATA")

      record = create(:backup_record, filename: "upload_req.sql", file_path: file_path.to_s)

      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:upload).and_return({ success: true, url: "https://dav.example.com/upload_req.sql" })

      post webdav_upload_backup_path(record)
      expect(response).to redirect_to(backups_path)
      expect(flash[:notice]).to eq("已上传到 WebDAV")
    end

    it "updates webdav_url on record after successful upload" do
      file_path = backup_dir.join("upload_url.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "DATA")

      record = create(:backup_record, filename: "upload_url.sql", file_path: file_path.to_s)

      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:upload).and_return({ success: true, url: "https://dav.example.com/upload_url.sql" })

      post webdav_upload_backup_path(record)
      expect(record.reload.webdav_url).to eq("https://dav.example.com/upload_url.sql")
    end

    it "redirects with alert on upload failure" do
      file_path = backup_dir.join("upload_fail.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(file_path, "DATA")

      record = create(:backup_record, filename: "upload_fail.sql", file_path: file_path.to_s)

      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:upload).and_return({ success: false, error: "upload failed" })

      post webdav_upload_backup_path(record)
      expect(response).to redirect_to(backups_path)
      expect(flash[:alert]).to eq("upload failed")
    end
  end

  describe "GET /webdav/download" do
    it "downloads file from webdav and sends it" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      target_path = BackupService::BACKUP_DIR.join("remote.sql")
      FileUtils.mkdir_p(backup_dir)
      File.write(target_path, "REMOTE DATA")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:download).and_return({ success: true, path: target_path.to_s })

      get webdav_download_backups_path, params: { filename: "remote.sql" }
      expect(response).to have_http_status(:success)
    end

    it "redirects with alert on download failure" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:download).and_return({ success: false, error: "下载失败" })

      get webdav_download_backups_path, params: { filename: "nope.sql" }
      expect(response).to redirect_to(backups_path)
      expect(flash[:alert]).to eq("下载失败")
    end
  end
end
