# frozen_string_literal: true

require "rails_helper"

RSpec.describe BackupService do
  let(:backup_dir) { BackupService::BACKUP_DIR }
  let(:config_file) { BackupConfig::CONFIG_FILE }

  before do
    FileUtils.mkdir_p(backup_dir)
  end

  after do
    FileUtils.rm_rf(backup_dir)
    File.delete(config_file) if File.exist?(config_file)
  end

  # Helper to mock pg_dump success by also stubbing File.exist? for the backup file path
  def stub_pg_dump_success
    status = double(success?: true)
    # Stub capture3 and also simulate the file being created
    allow(Open3).to receive(:capture3) do |env, *cmd|
      # Find the -f flag and create the file
      if cmd.include?("-f")
        idx = cmd.index("-f")
        file_path = cmd[idx + 1]
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, "DUMP DATA #{rand(1000)}")
      end
      [ "", "", status ]
    end
  end

  def stub_pg_dump_failure(error_msg = "pg_dump error")
    status = double(success?: false)
    allow(Open3).to receive(:capture3).and_return([ "", error_msg, status ])
  end

  def stub_psql_success
    status = double(success?: true)
    allow(Open3).to receive(:capture3).and_return([ "", "", status ])
  end

  def stub_psql_failure(error_msg = "psql error")
    status = double(success?: false)
    allow(Open3).to receive(:capture3).and_return([ "", error_msg, status ])
  end

  # ========================
  # create_backup
  # ========================
  describe ".create_backup" do
    it "creates a backup record on success" do
      stub_pg_dump_success

      result = BackupService.create_backup
      expect(result[:success]).to be true
      expect(result).to have_key(:record_id)
      expect(BackupRecord.count).to eq(1)
    end

    it "returns failure when pg_dump fails" do
      stub_pg_dump_failure("pg_dump connection refused")

      result = BackupService.create_backup
      expect(result[:success]).to be false
      expect(result[:error]).to include("pg_dump connection refused")
    end

    it "sets backup type from options" do
      stub_pg_dump_success

      BackupService.create_backup(type: "auto")
      expect(BackupRecord.last.backup_type).to eq("auto")
    end

    it "defaults to manual backup type" do
      stub_pg_dump_success

      BackupService.create_backup
      expect(BackupRecord.last.backup_type).to eq("manual")
    end

    it "sets status to completed" do
      stub_pg_dump_success

      BackupService.create_backup
      expect(BackupRecord.last.status).to eq("completed")
    end

    it "syncs to webdav when configured and sync not disabled" do
      stub_pg_dump_success
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:upload).and_return({ success: true, url: "https://dav.example.com/f.sql" })

      BackupService.create_backup(sync: true)
      expect(webdav_client).to have_received(:upload)
    end

    it "skips webdav sync when sync is false" do
      stub_pg_dump_success
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      # build_webdav_client should not be called because BackupConfig.webdav_configured? is checked,
      # but sync: false causes early return. Actually the code checks both conditions.
      # We verify no upload happens by ensuring BackupConfig.build_webdav_client is not called for sync purposes
      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:upload)

      BackupService.create_backup(sync: false)
      expect(webdav_client).not_to have_received(:upload)
    end

    it "skips webdav sync when webdav not configured" do
      stub_pg_dump_success
      expect(BackupConfig).not_to receive(:build_webdav_client)

      BackupService.create_backup
    end

    it "cleans up old backups beyond retention limit" do
      stub_pg_dump_success

      # Create 11 existing backups (oldest first)
      11.times { |i| create(:backup_record, filename: "old_#{i}.sql", file_path: "/tmp/old_#{i}.sql", created_at: (12 - i).hours.ago) }

      BackupService.create_backup
      # 11 old + 1 new = 12, cleanup keeps latest 10 => 2 deleted
      expect(BackupRecord.count).to eq(10)
    end

    it "includes file_name and size in result" do
      stub_pg_dump_success

      result = BackupService.create_backup
      expect(result[:file_name]).to be_present
      expect(result[:size]).to be_a(Integer)
      expect(result[:size]).to be > 0
    end

    it "stores the file path in the record" do
      stub_pg_dump_success

      BackupService.create_backup
      record = BackupRecord.last
      expect(record.file_path).to include("ledger_backup_")
      expect(record.file_path).to end_with(".sql")
    end

    it "sets webdav_url on record after successful webdav sync" do
      stub_pg_dump_success
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:upload).and_return({ success: true, url: "https://dav.example.com/mybackup.sql" })

      BackupService.create_backup
      expect(BackupRecord.last.webdav_url).to eq("https://dav.example.com/mybackup.sql")
    end

    it "does not set webdav_url when upload fails" do
      stub_pg_dump_success
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:upload).and_return({ success: false, error: "timeout" })

      BackupService.create_backup
      expect(BackupRecord.last.webdav_url).to be_nil
    end
  end

  # ========================
  # restore_backup
  # ========================
  describe ".restore_backup" do
    it "returns error when file does not exist" do
      result = BackupService.restore_backup("/nonexistent/backup.sql")
      expect(result[:success]).to be false
      expect(result[:error]).to eq("备份文件不存在")
    end

    it "calls update_caches_after_restore on success" do
      backup_file = backup_dir.join("restore_test.sql")
      File.write(backup_file, "SELECT 1;")

      stub_psql_success

      expect(BackupService).to receive(:update_caches_after_restore)
      result = BackupService.restore_backup(backup_file.to_s)
      expect(result[:success]).to be true
    end

    it "returns error when psql restore fails" do
      backup_file = backup_dir.join("restore_fail.sql")
      File.write(backup_file, "BAD SQL;")

      stub_psql_failure("psql relation not found")

      result = BackupService.restore_backup(backup_file.to_s)
      expect(result[:success]).to be false
      expect(result[:error]).to include("psql relation not found")
    end

    it "does not call update_caches_after_restore on failure" do
      backup_file = backup_dir.join("restore_fail2.sql")
      File.write(backup_file, "BAD SQL;")

      stub_psql_failure

      expect(BackupService).not_to receive(:update_caches_after_restore)
      BackupService.restore_backup(backup_file.to_s)
    end

    it "builds correct psql command with db config" do
      backup_file = backup_dir.join("restore_cmd.sql")
      File.write(backup_file, "SELECT 1;")

      allow(BackupService).to receive(:get_pg_version).and_return(17)

      status = double(success?: true)
      expect(Open3).to receive(:capture3) do |env, *cmd|
        expect(cmd).to include("psql")
        expect(cmd).to include("-f", backup_file.to_s)
        expect(cmd).to include("-v", "ON_ERROR_STOP=1")
        [ "", "", status ]
      end

      BackupService.restore_backup(backup_file.to_s)
    end

    it "returns success true on successful restore" do
      backup_file = backup_dir.join("restore_ok.sql")
      File.write(backup_file, "SELECT 1;")

      stub_psql_success

      result = BackupService.restore_backup(backup_file.to_s)
      expect(result[:success]).to be true
    end
  end

  # ========================
  # list_backups
  # ========================
  describe ".list_backups" do
    it "returns all relevant keys for each backup" do
      record = create(:backup_record, filename: "full.sql", file_path: "/tmp/full.sql", file_size: 2048, backup_type: "auto", status: "completed")

      result = BackupService.list_backups
      backup = result.first
      expect(backup[:id]).to eq(record.id)
      expect(backup[:name]).to eq("full.sql")
      expect(backup[:path]).to eq("/tmp/full.sql")
      expect(backup[:size]).to eq(2048)
      expect(backup[:type]).to eq("auto")
      expect(backup[:status]).to eq("completed")
      expect(backup).to have_key(:created_at)
      expect(backup).to have_key(:webdav_url)
    end

    it "returns empty array with no records" do
      expect(BackupService.list_backups).to eq([])
    end

    it "defaults to limit of 20" do
      25.times { create(:backup_record) }
      expect(BackupService.list_backups.size).to eq(20)
    end

    it "accepts custom limit" do
      10.times { create(:backup_record) }
      expect(BackupService.list_backups(limit: 5).size).to eq(5)
    end

    it "orders by created_at descending" do
      old = create(:backup_record, filename: "old.sql", created_at: 2.days.ago)
      new_rec = create(:backup_record, filename: "new.sql", created_at: 1.hour.ago)

      result = BackupService.list_backups
      expect(result.first[:name]).to eq("new.sql")
      expect(result.last[:name]).to eq("old.sql")
    end
  end

  # ========================
  # delete_backup
  # ========================
  describe ".delete_backup" do
    it "returns error for non-existent record" do
      result = BackupService.delete_backup(999_999)
      expect(result[:success]).to be false
      expect(result[:error]).to eq("记录不存在")
    end

    it "deletes the file from disk when it exists" do
      file_path = backup_dir.join("deletable.sql")
      File.write(file_path, "data")

      record = create(:backup_record, file_path: file_path.to_s)
      BackupService.delete_backup(record.id)
      expect(File.exist?(file_path)).to be false
    end

    it "destroys the database record" do
      record = create(:backup_record, file_path: "/tmp/nonexistent_del.sql")
      BackupService.delete_backup(record.id)
      expect(BackupRecord.find_by(id: record.id)).to be_nil
    end

    it "handles missing file gracefully" do
      record = create(:backup_record, file_path: "/tmp/does_not_exist_del.sql")
      result = BackupService.delete_backup(record.id)
      expect(result[:success]).to be true
    end

    it "deletes from webdav when configured and webdav_url present" do
      record = create(:backup_record, file_path: "/tmp/wd.sql", webdav_url: "https://dav.example.com/wd.sql")

      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:delete).and_return({ success: true })

      result = BackupService.delete_backup(record.id)
      expect(result[:success]).to be true
      expect(webdav_client).to have_received(:delete).with(record.filename)
    end

    it "does not attempt webdav deletion when no webdav_url" do
      record = create(:backup_record, file_path: "/tmp/no_wd.sql", webdav_url: nil)

      expect(BackupConfig).not_to receive(:build_webdav_client)
      result = BackupService.delete_backup(record.id)
      expect(result[:success]).to be true
    end

    it "does not attempt webdav deletion when webdav not configured" do
      record = create(:backup_record, file_path: "/tmp/no_cfg.sql", webdav_url: "https://dav.example.com/f.sql")

      result = BackupService.delete_backup(record.id)
      expect(result[:success]).to be true
    end
  end

  # ========================
  # WebDAV integration
  # ========================
  describe ".configure_webdav" do
    it "delegates to BackupConfig and tests connection" do
      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:test_connection).and_return({ success: true, message: "连接成功" })

      result = BackupService.configure_webdav(url: "https://dav.example.com", username: "user", password: "pass")
      expect(result[:success]).to be true
    end
  end

  describe ".webdav_configured?" do
    it "returns false when not configured" do
      expect(BackupService.webdav_configured?).to be false
    end

    it "returns true when configured" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")
      expect(BackupService.webdav_configured?).to be true
    end
  end

  describe ".webdav_config" do
    it "returns config hash with decrypted password" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "admin", password: "secret123")
      config = BackupService.webdav_config
      expect(config[:url]).to eq("https://dav.example.com")
      expect(config[:username]).to eq("admin")
      expect(config[:password]).to eq("secret123")
    end
  end

  describe ".test_webdav_connection" do
    it "returns error when not configured" do
      result = BackupService.test_webdav_connection
      expect(result[:success]).to be false
      expect(result[:error]).to eq("WebDAV 未配置")
    end

    it "delegates to webdav client when configured" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:test_connection).and_return({ success: true, message: "OK" })

      result = BackupService.test_webdav_connection
      expect(result[:success]).to be true
    end
  end

  describe ".upload_to_webdav" do
    it "returns error when not configured" do
      result = BackupService.upload_to_webdav("/tmp/test.sql", "test.sql")
      expect(result[:success]).to be false
      expect(result[:error]).to eq("WebDAV 未配置")
    end

    it "uploads file when configured" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:upload).and_return({ success: true, url: "https://dav.example.com/test.sql" })

      result = BackupService.upload_to_webdav("/tmp/test.sql", "test.sql")
      expect(result[:success]).to be true
      expect(result[:url]).to eq("https://dav.example.com/test.sql")
    end
  end

  describe ".download_from_webdav" do
    it "returns error when not configured" do
      result = BackupService.download_from_webdav("test.sql", "/tmp/test.sql")
      expect(result[:success]).to be false
      expect(result[:error]).to eq("WebDAV 未配置")
    end

    it "downloads file when configured" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:download).and_return({ success: true, path: "/tmp/test.sql" })

      result = BackupService.download_from_webdav("test.sql", "/tmp/test.sql")
      expect(result[:success]).to be true
      expect(result[:path]).to eq("/tmp/test.sql")
    end
  end

  describe ".list_webdav_backups" do
    it "returns empty array when not configured" do
      expect(BackupService.list_webdav_backups).to eq([])
    end

    it "returns file list when configured" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:list_files).and_return([ { name: "backup1.sql" } ])

      result = BackupService.list_webdav_backups
      expect(result).to eq([ { name: "backup1.sql" } ])
    end
  end

  describe ".delete_from_webdav" do
    it "returns error when not configured" do
      result = BackupService.delete_from_webdav("test.sql")
      expect(result[:success]).to be false
      expect(result[:error]).to eq("WebDAV 未配置")
    end

    it "deletes file when configured" do
      BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")

      webdav_client = instance_double(WebdavClient)
      allow(BackupConfig).to receive(:build_webdav_client).and_return(webdav_client)
      allow(webdav_client).to receive(:delete).and_return({ success: true })

      result = BackupService.delete_from_webdav("test.sql")
      expect(result[:success]).to be true
    end
  end

  # ========================
  # Auto backup
  # ========================
  describe ".perform_auto_backup" do
    it "does nothing when auto backup is disabled" do
      expect(BackupService).not_to receive(:create_backup)
      BackupService.perform_auto_backup
    end

    it "creates backup when auto backup is enabled" do
      stub_pg_dump_success

      BackupService.enable_auto_backup(frequency: "daily", retention: 5)
      expect(BackupService).to receive(:create_backup).and_call_original
      BackupService.perform_auto_backup
    end
  end

  describe ".auto_backup_enabled?" do
    it "returns false by default" do
      expect(BackupService.auto_backup_enabled?).to be false
    end

    it "returns true after enabling" do
      BackupService.enable_auto_backup
      expect(BackupService.auto_backup_enabled?).to be true
    end

    it "returns false after disabling" do
      BackupService.enable_auto_backup
      BackupService.disable_auto_backup
      expect(BackupService.auto_backup_enabled?).to be false
    end
  end

  # ========================
  # update_caches_after_restore (private)
  # ========================
  describe ".update_caches_after_restore" do
    it "clears Rails cache" do
      expect(Rails.cache).to receive(:clear)
      BackupService.send(:update_caches_after_restore)
    end
  end

  # ========================
  # BackupConfig persistence & encryption
  # ========================
  describe BackupConfig do
    let(:cfg_file) { BackupConfig::CONFIG_FILE }

    after do
      File.delete(cfg_file) if File.exist?(cfg_file)
    end

    describe ".save and .config" do
      it "persists data to disk and reads it back" do
        BackupConfig.save({ "test_key" => "test_value" })
        expect(File.exist?(cfg_file)).to be true
        expect(BackupConfig.config["test_key"]).to eq("test_value")
      end

      it "creates directory if needed" do
        dir = File.dirname(cfg_file)
        FileUtils.rm_rf(dir)
        BackupConfig.save({ "k" => "v" })
        expect(File.exist?(cfg_file)).to be true
      end

      it "returns empty hash when file doesn't exist" do
        File.delete(cfg_file) if File.exist?(cfg_file)
        expect(BackupConfig.config).to eq({})
      end

      it "returns empty hash for invalid JSON" do
        FileUtils.mkdir_p(File.dirname(cfg_file))
        File.write(cfg_file, "invalid json{{{")
        expect(BackupConfig.config).to eq({})
      end

      it "overwrites existing config" do
        BackupConfig.save({ "old" => "value" })
        BackupConfig.save({ "new" => "value" })
        config = BackupConfig.config
        expect(config["new"]).to eq("value")
        expect(config["old"]).to be_nil
      end
    end

    describe "encrypt_password / decrypt_password" do
      it "encrypts and decrypts a password" do
        original = "my_secret_password"
        encrypted = BackupConfig.send(:encrypt_password, original)
        expect(encrypted).not_to eq(original)
        decrypted = BackupConfig.send(:decrypt_password, encrypted)
        expect(decrypted).to eq(original)
      end

      it "produces different ciphertext for same input (non-deterministic)" do
        enc1 = BackupConfig.send(:encrypt_password, "same_password")
        enc2 = BackupConfig.send(:encrypt_password, "same_password")
        # MessageEncryptor uses random IV, so ciphertext should differ
        expect(enc1).not_to eq(enc2)
      end

      it "handles empty string" do
        encrypted = BackupConfig.send(:encrypt_password, "")
        decrypted = BackupConfig.send(:decrypt_password, encrypted)
        expect(decrypted).to eq("")
      end

      it "handles special characters" do
        original = "p@$$w0rd!#%&*()_+-=[]{}|;':\",./<>?"
        encrypted = BackupConfig.send(:encrypt_password, original)
        decrypted = BackupConfig.send(:decrypt_password, encrypted)
        expect(decrypted).to eq(original)
      end

      it "handles unicode characters" do
        original = "密码测试🔑"
        encrypted = BackupConfig.send(:encrypt_password, original)
        decrypted = BackupConfig.send(:decrypt_password, encrypted)
        expect(decrypted).to eq(original)
      end
    end

    describe ".webdav_configured?" do
      it "returns false by default" do
        File.delete(cfg_file) if File.exist?(cfg_file)
        expect(BackupConfig.webdav_configured?).to be false
      end

      it "returns true when configured" do
        BackupConfig.configure_webdav(url: "https://dav.example.com", username: "user", password: "pass")
        expect(BackupConfig.webdav_configured?).to be true
      end
    end

    describe ".configure_webdav" do
      it "saves webdav configuration with encrypted password" do
        BackupConfig.configure_webdav(
          url: "https://dav.example.com/",
          username: "user",
          password: "pass",
          directory: "/backups"
        )

        config = BackupConfig.webdav_config
        expect(config[:url]).to eq("https://dav.example.com")
        expect(config[:username]).to eq("user")
        expect(config[:password]).to eq("pass")
        expect(config[:directory]).to eq("/backups")
      end

      it "preserves other config keys" do
        BackupConfig.save({ "other_key" => "other_value" })
        BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")
        expect(BackupConfig.config["other_key"]).to eq("other_value")
      end

      it "defaults directory to /" do
        BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")
        expect(BackupConfig.webdav_config[:directory]).to eq("/")
      end
    end

    describe ".webdav_config" do
      it "returns directory defaulting to /" do
        BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")
        config = BackupConfig.webdav_config
        expect(config[:directory]).to eq("/")
      end

      it "returns nil password when not set" do
        FileUtils.mkdir_p(File.dirname(cfg_file))
        File.write(cfg_file, { "webdav" => { "url" => "https://dav.example.com" } }.to_json)
        config = BackupConfig.webdav_config
        expect(config[:password]).to be_nil
      end
    end

    describe ".build_webdav_client" do
      it "returns a WebdavClient instance when configured" do
        BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")
        client = BackupConfig.build_webdav_client
        expect(client).to be_a(WebdavClient)
      end

      it "returns nil when not configured" do
        File.delete(cfg_file) if File.exist?(cfg_file)
        expect(BackupConfig.build_webdav_client).to be_nil
      end
    end

    describe ".auto_backup_config" do
      it "returns empty hash by default" do
        File.delete(cfg_file) if File.exist?(cfg_file)
        expect(BackupConfig.auto_backup_config).to eq({})
      end

      it "returns stored config after enabling" do
        BackupConfig.enable_auto_backup(frequency: "weekly", retention: 3, webdav_sync: true)
        config = BackupConfig.auto_backup_config
        expect(config["enabled"]).to be true
        expect(config["frequency"]).to eq("weekly")
        expect(config["retention_count"]).to eq(3)
        expect(config["webdav_sync"]).to be true
      end
    end

    describe ".enable_auto_backup" do
      it "enables with default settings" do
        BackupConfig.enable_auto_backup
        expect(BackupConfig.auto_backup_enabled?).to be true
        config = BackupConfig.auto_backup_config
        expect(config["frequency"]).to eq("daily")
        expect(config["retention_count"]).to eq(10)
        expect(config["webdav_sync"]).to be false
      end
    end

    describe ".disable_auto_backup" do
      it "disables auto backup" do
        BackupConfig.enable_auto_backup
        BackupConfig.disable_auto_backup
        expect(BackupConfig.auto_backup_enabled?).to be false
      end

      it "preserves other config" do
        BackupConfig.configure_webdav(url: "https://dav.example.com", username: "u", password: "p")
        BackupConfig.enable_auto_backup
        BackupConfig.disable_auto_backup
        expect(BackupConfig.webdav_configured?).to be true
      end
    end
  end
end
