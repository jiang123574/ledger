# frozen_string_literal: true

require "rails_helper"

RSpec.describe BackupService do
  let(:backup_dir) { Rails.root.join("tmp", "backups") }
  let(:config_file) { Rails.root.join("tmp", "backup_config.json") }

  before do
    FileUtils.mkdir_p(backup_dir)
  end

  after do
    FileUtils.rm_rf(backup_dir)
    File.delete(config_file) if File.exist?(config_file)
  end

  describe ".list_backups" do
    it "returns empty list when no backups exist" do
      result = BackupService.list_backups
      expect(result).to eq([])
    end

    it "returns backup records ordered by created_at desc" do
      create(:backup_record, filename: "old_backup.sql", created_at: 2.days.ago)
      create(:backup_record, filename: "new_backup.sql", created_at: 1.hour.ago)

      result = BackupService.list_backups
      expect(result.first[:name]).to eq("new_backup.sql")
      expect(result.last[:name]).to eq("old_backup.sql")
    end

    it "respects limit parameter" do
      5.times { |i| create(:backup_record, filename: "backup_#{i}.sql") }

      result = BackupService.list_backups(limit: 3)
      expect(result.size).to eq(3)
    end

    it "includes backup details" do
      record = create(:backup_record,
        filename: "test.sql",
        file_size: 1024,
        backup_type: "manual",
        status: "completed"
      )

      result = BackupService.list_backups
      expect(result.first[:name]).to eq("test.sql")
      expect(result.first[:size]).to eq(1024)
      expect(result.first[:type]).to eq("manual")
      expect(result.first[:status]).to eq("completed")
    end
  end

  describe ".delete_backup" do
    it "returns error for non-existent record" do
      result = BackupService.delete_backup(999_999)
      expect(result[:success]).to be false
      expect(result[:error]).to eq("记录不存在")
    end

    it "deletes backup file and record" do
      backup_file = backup_dir.join("test_backup.sql")
      File.write(backup_file, "SELECT 1;")

      record = create(:backup_record,
        filename: "test_backup.sql",
        file_path: backup_file.to_s
      )

      result = BackupService.delete_backup(record.id)
      expect(result[:success]).to be true
      expect(BackupRecord.find_by(id: record.id)).to be_nil
    end

    it "handles missing file gracefully" do
      record = create(:backup_record,
        filename: "missing.sql",
        file_path: "/nonexistent/missing.sql"
      )

      result = BackupService.delete_backup(record.id)
      expect(result[:success]).to be true
    end
  end

  describe ".restore_backup" do
    it "returns error for missing file" do
      result = BackupService.restore_backup("/nonexistent/backup.sql")
      expect(result[:success]).to be false
      expect(result[:error]).to eq("备份文件不存在")
    end
  end

  describe ".webdav_configured?" do
    it "returns false when not configured" do
      expect(BackupService.webdav_configured?).to be false
    end
  end

  describe ".auto_backup_enabled?" do
    it "returns false by default" do
      expect(BackupService.auto_backup_enabled?).to be false
    end
  end

  describe ".enable_auto_backup" do
    it "enables auto backup" do
      result = BackupService.enable_auto_backup(frequency: "daily", retention: 7)
      expect(result[:success]).to be true
      expect(BackupService.auto_backup_enabled?).to be true
    end
  end

  describe ".disable_auto_backup" do
    it "disables auto backup" do
      BackupService.enable_auto_backup
      result = BackupService.disable_auto_backup
      expect(result[:success]).to be true
      expect(BackupService.auto_backup_enabled?).to be false
    end
  end

  describe ".test_webdav_connection" do
    it "returns error when not configured" do
      result = BackupService.test_webdav_connection
      expect(result[:success]).to be false
      expect(result[:error]).to eq("WebDAV 未配置")
    end
  end

  describe ".upload_to_webdav" do
    it "returns error when not configured" do
      result = BackupService.upload_to_webdav("/tmp/test.sql", "test.sql")
      expect(result[:success]).to be false
      expect(result[:error]).to eq("WebDAV 未配置")
    end
  end

  describe ".download_from_webdav" do
    it "returns error when not configured" do
      result = BackupService.download_from_webdav("test.sql", "/tmp/test.sql")
      expect(result[:success]).to be false
    end
  end

  describe ".list_webdav_backups" do
    it "returns empty array when not configured" do
      result = BackupService.list_webdav_backups
      expect(result).to eq([])
    end
  end
end

RSpec.describe BackupConfig do
  let(:config_file) { Rails.root.join("tmp", "backup_config.json") }

  after do
    File.delete(config_file) if File.exist?(config_file)
  end

  describe ".config" do
    it "returns empty hash when file doesn't exist" do
      File.delete(config_file) if File.exist?(config_file)
      expect(BackupConfig.config).to eq({})
    end

    it "returns empty hash for invalid JSON" do
      FileUtils.mkdir_p(File.dirname(config_file))
      File.write(config_file, "invalid json")
      expect(BackupConfig.config).to eq({})
    end

    it "parses valid JSON config" do
      FileUtils.mkdir_p(File.dirname(config_file))
      File.write(config_file, { "test" => "value" }.to_json)
      expect(BackupConfig.config["test"]).to eq("value")
    end
  end

  describe ".webdav_configured?" do
    it "returns false by default" do
      expect(BackupConfig.webdav_configured?).to be false
    end

    it "returns true when configured" do
      BackupConfig.configure_webdav(
        url: "https://dav.example.com",
        username: "user",
        password: "pass"
      )
      expect(BackupConfig.webdav_configured?).to be true
    end
  end

  describe ".configure_webdav" do
    it "saves webdav configuration" do
      BackupConfig.configure_webdav(
        url: "https://dav.example.com/",
        username: "user",
        password: "pass",
        directory: "/backups"
      )

      config = BackupConfig.webdav_config
      expect(config[:url]).to eq("https://dav.example.com")
      expect(config[:username]).to eq("user")
      expect(config[:directory]).to eq("/backups")
    end

    it "strips trailing slash from URL" do
      BackupConfig.configure_webdav(
        url: "https://dav.example.com///",
        username: "user",
        password: "pass"
      )

      config = BackupConfig.webdav_config
      expect(config[:url]).to eq("https://dav.example.com//")
    end
  end

  describe ".auto_backup_enabled?" do
    it "returns false by default" do
      expect(BackupConfig.auto_backup_enabled?).to be false
    end
  end

  describe ".enable_auto_backup" do
    it "enables with default settings" do
      BackupConfig.enable_auto_backup
      expect(BackupConfig.auto_backup_enabled?).to be true
    end

    it "saves custom settings" do
      BackupConfig.enable_auto_backup(frequency: "weekly", retention: 5, webdav_sync: true)
      config = BackupConfig.auto_backup_config
      expect(config["frequency"]).to eq("weekly")
      expect(config["retention_count"]).to eq(5)
      expect(config["webdav_sync"]).to be true
    end
  end

  describe ".disable_auto_backup" do
    it "disables auto backup" do
      BackupConfig.enable_auto_backup
      BackupConfig.disable_auto_backup
      expect(BackupConfig.auto_backup_enabled?).to be false
    end
  end

  describe ".build_webdav_client" do
    it "returns nil when not configured" do
      expect(BackupConfig.build_webdav_client).to be_nil
    end
  end
end
