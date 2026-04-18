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
    merged["webdav"] = {
      "url" => url.chomp("/"),
      "username" => username,
      "password" => encrypt_password(password),
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
    File.write(CONFIG_FILE, data.to_json)
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
