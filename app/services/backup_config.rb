# frozen_string_literal: true

require "json"
require "fileutils"

# Manages backup configuration (WebDAV credentials, auto-backup settings).
# Persists to a JSON file in tmp/.
class BackupConfig
  CONFIG_FILE = Rails.root.join("storage", "backup_config.json").freeze

  # ---- WebDAV Configuration ----

  def self.webdav_configured?
    config.dig("webdav", "url").present?
  end

  def self.webdav_config
    webdav = config["webdav"] || {}
    password = webdav["password"]

    {
      url: webdav["url"],
      username: webdav["username"],
      password: password ? decrypt_password(password) : nil,
      directory: webdav["directory"] || "/"
    }
  end

  def self.configure_webdav(url:, username:, password:, directory: "/")
    merged = config

    # 如果密码为空，保留原有密码（支持修改配置时只改 URL/用户名）
    existing_password = merged.dig("webdav", "password")
    final_password = if password.present?
      encrypt_password(password)
    elsif existing_password.present?
      existing_password
    else
      nil
    end

    merged["webdav"] = {
      "url" => url.chomp("/"),
      "username" => username,
      "password" => final_password,
      "directory" => directory
    }
    save(merged)
  end

  def self.build_webdav_client
    return nil unless webdav_configured?

    wc = webdav_config
    WebdavClient.new(
      url: wc[:url],
      username: wc[:username],
      password: wc[:password],
      directory: wc[:directory]
    )
  end

  # ---- Auto Backup Configuration ----

  def self.auto_backup_enabled?
    config.dig("auto_backup", "enabled") == true
  end

  def self.auto_backup_config
    config["auto_backup"] || {}
  end

  def self.enable_auto_backup(frequency: "daily", retention: 10, webdav_sync: false)
    merged = config
    merged["auto_backup"] = {
      "enabled" => true,
      "frequency" => frequency,
      "retention_count" => retention,
      "webdav_sync" => webdav_sync
    }
    save(merged)
  end

  def self.disable_auto_backup
    merged = config
    merged["auto_backup"] = { "enabled" => false }
    save(merged)
  end

  # ---- Persistence ----

  def self.config
    return {} unless File.exist?(CONFIG_FILE)

    JSON.parse(File.read(CONFIG_FILE))
  rescue JSON::ParserError
    {}
  end

  def self.save(data)
    FileUtils.mkdir_p(File.dirname(CONFIG_FILE))
    # 原子写入：先写临时文件再 rename，避免并发读写损坏 JSON
    temp_path = "#{CONFIG_FILE}.tmp"
    File.write(temp_path, data.to_json)
    File.rename(temp_path, CONFIG_FILE)
  end

  private_class_method :new

  def self.encrypt_password(password)
    ActiveSupport::MessageEncryptor.new(
      Rails.application.secret_key_base[0, 32]
    ).encrypt_and_sign(password)
  end

  def self.decrypt_password(encrypted)
    ActiveSupport::MessageEncryptor.new(
      Rails.application.secret_key_base[0, 32]
    ).decrypt_and_verify(encrypted)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    Base64.decode64(encrypted)
  end
end
