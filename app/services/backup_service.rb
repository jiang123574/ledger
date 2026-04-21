# frozen_string_literal: true

require "fileutils"
require "open3"

# Backup management facade. Delegates to BackupConfig, WebDAVClient.
class BackupService
  BACKUP_DIR = Rails.root.join("storage", "backups").freeze

  # ===================
  # Local Backup
  # ===================

  def self.create_backup(options = {})
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    FileUtils.mkdir_p(BACKUP_DIR)

    backup_file = BACKUP_DIR.join("ledger_backup_#{timestamp}.sql")
    result = create_database_backup(backup_file)
    return result unless result[:success]

    record = BackupRecord.create!(
      filename: result[:file_name],
      file_path: result[:file_path].to_s,
      file_size: result[:size],
      backup_type: options[:type] || "manual",
      status: "completed"
    )

    # WebDAV sync if configured
    if BackupConfig.webdav_configured? && options[:sync] != false
      sync_to_webdav(result[:file_path], result[:file_name], record)
    end

    cleanup_old_backups

    result.merge(record_id: record.id)
  end

  def self.list_backups(limit: 20)
    BackupRecord.order(created_at: :desc).limit(limit).map do |record|
      {
        id: record.id,
        name: record.filename,
        path: record.file_path,
        size: record.file_size,
        created_at: record.created_at,
        type: record.backup_type,
        status: record.status,
        webdav_url: record.webdav_url
      }
    end
  end

  def self.restore_backup(backup_file)
    unless File.exist?(backup_file)
      return { success: false, error: "备份文件不存在" }
    end

    Rails.logger.info("Starting restore from backup file: #{backup_file}")

    db_config = get_primary_db_config
    result = execute_psql_restore(db_config, backup_file.to_s)

    if result[:success]
      # 恢复成功后更新缓存字段
      update_caches_after_restore
      { success: true }
    else
      Rails.logger.error("Backup restore failed: #{result[:error]}")
      { success: false, error: result[:error] || "恢复失败" }
    end
  end

  def self.delete_backup(backup_id)
    record = BackupRecord.find_by(id: backup_id)
    return { success: false, error: "记录不存在" } unless record

    File.delete(record.file_path) if File.exist?(record.file_path)

    if BackupConfig.webdav_configured? && record.webdav_url.present?
      webdav = BackupConfig.build_webdav_client
      webdav&.delete(record.filename)
    end

    record.destroy
    { success: true }
  end

  # ===================
  # WebDAV (delegate to WebDAVClient)
  # ===================

  def self.configure_webdav(url:, username:, password:, directory: "/")
    BackupConfig.configure_webdav(url: url, username: username, password: password, directory: directory)

    webdav = BackupConfig.build_webdav_client
    webdav&.test_connection || { success: false, error: "WebDAV 未配置" }
  end

  def self.webdav_configured?
    BackupConfig.webdav_configured?
  end

  def self.webdav_config
    BackupConfig.webdav_config
  end

  def self.test_webdav_connection
    webdav = BackupConfig.build_webdav_client
    return { success: false, error: "WebDAV 未配置" } unless webdav

    webdav.test_connection
  end

  def self.upload_to_webdav(file_path, filename)
    webdav = BackupConfig.build_webdav_client
    return { success: false, error: "WebDAV 未配置" } unless webdav

    webdav.upload(file_path, filename)
  end

  def self.download_from_webdav(filename, local_path)
    webdav = BackupConfig.build_webdav_client
    return { success: false, error: "WebDAV 未配置" } unless webdav

    webdav.download(filename, local_path)
  end

  def self.list_webdav_backups
    webdav = BackupConfig.build_webdav_client
    return [] unless webdav

    webdav.list_files
  end

  def self.delete_from_webdav(filename)
    webdav = BackupConfig.build_webdav_client
    return { success: false, error: "WebDAV 未配置" } unless webdav

    webdav.delete(filename)
  end

  # ===================
  # Auto Backup (delegate to BackupConfig)
  # ===================

  def self.auto_backup_enabled?
    BackupConfig.auto_backup_enabled?
  end

  def self.enable_auto_backup(frequency: "daily", retention: 10, webdav_sync: false)
    BackupConfig.enable_auto_backup(frequency: frequency, retention: retention, webdav_sync: webdav_sync)
    { success: true }
  end

  def self.disable_auto_backup
    BackupConfig.disable_auto_backup
    { success: true }
  end

  def self.perform_auto_backup
    return unless auto_backup_enabled?

    ab_config = BackupConfig.auto_backup_config
    create_backup(type: "auto", sync: ab_config["webdav_sync"])
  end

  # ===================
  # Private
  # ===================

  private_class_method

  def self.create_database_backup(backup_file)
    db_config = get_primary_db_config
    result = execute_pg_dump(db_config, backup_file.to_s)

    if result[:success] && File.exist?(backup_file)
      {
        success: true,
        file_path: backup_file.to_s,
        file_name: File.basename(backup_file),
        size: File.size(backup_file)
      }
    else
      { success: false, error: result[:error] || "备份创建失败" }
    end
  end

  def self.get_primary_db_config
    config = Rails.configuration.database_configuration[Rails.env]
    config.is_a?(Hash) && config.key?("primary") ? config["primary"] : config
  end

  # Security: db_config comes from Rails.configuration, not user input.
  # Ensure config files (database.yml) are not externally modifiable.
  def self.execute_pg_dump(db_config, backup_file)
    db_name = db_config["database"]
    db_host = db_config["host"] || "localhost"
    db_user = db_config["username"] || "postgres"
    db_password = db_config["password"]

    env_vars = { "PGPASSWORD" => db_password }
    cmd = [
      "pg_dump",
      "-h", db_host,
      "-U", db_user,
      "-d", db_name,
      "--clean",
      "--no-owner",
      "--no-acl",
      "-f", backup_file
    ]

    stdout, stderr, status = Open3.capture3(env_vars, *cmd)

    if status.success?
      { success: true, error: nil }
    else
      { success: false, error: stderr.presence || stdout.presence || "pg_dump 命令执行失败" }
    end
  end

  def self.execute_psql_restore(db_config, backup_file)
    db_name = db_config["database"]
    db_host = db_config["host"] || "localhost"
    db_user = db_config["username"] || "postgres"
    db_password = db_config["password"]

    filtered_file = filter_pg17_params(backup_file)

    env_vars = { "PGPASSWORD" => db_password }
    cmd = [
      "psql",
      "-h", db_host,
      "-U", db_user,
      "-d", db_name,
      "-1",
      "-v", "ON_ERROR_STOP=1",
      "-f", filtered_file
    ]

    stdout, stderr, status = Open3.capture3(env_vars, *cmd)

    FileUtils.rm_f(filtered_file) if filtered_file != backup_file

    if status.success?
      { success: true, error: nil }
    else
      { success: false, error: stderr.presence || stdout.presence || "psql 命令执行失败" }
    end
  end

  def self.filter_pg17_params(backup_file)
    pg_version = get_pg_version
    if pg_version && pg_version < 17
      filtered_file = backup_file.sub(/\.sql$/, "_filtered.sql")
      content = File.read(backup_file)
      filtered_content = content.gsub(/^SET transaction_timeout = .*;\n/, "")
      File.write(filtered_file, filtered_content)
      filtered_file
    else
      backup_file
    end
  end

  def self.get_pg_version
    stdout, _, status = Open3.capture3("psql --version")
    if status.success?
      match = stdout.match(/PostgreSQL\)\s+(\d+)/)
      match ? match[1].to_i : nil
    end
  end

  def self.cleanup_old_backups(keep: 10)
    BackupRecord.order(created_at: :desc).drop(keep).each do |backup|
      begin
        File.delete(backup.file_path) if File.exist?(backup.file_path)
        backup.destroy
      rescue StandardError => e
        Rails.logger.error("Failed to cleanup backup #{backup.id}: #{e.message}")
      end
    end
  end

  def self.sync_to_webdav(file_path, filename, record)
    webdav = BackupConfig.build_webdav_client
    return unless webdav

    result = webdav.upload(file_path, filename)
    if result[:success]
      record.update!(webdav_url: result[:url])
    else
      Rails.logger.error("WebDAV upload failed: #{result[:error]}")
    end
  end

  def self.update_caches_after_restore
    Rails.logger.info("Updating caches after database restore...")

    # 批量更新 Account 缓存
    Account.find_each do |account|
      account.update_entries_cache!
    rescue StandardError => e
      Rails.logger.error("Failed to update cache for account #{account.id}: #{e.message}")
    end

    # 清除 Rails 缓存
    Rails.cache.clear

    Rails.logger.info("Cache update completed")
  end
end
