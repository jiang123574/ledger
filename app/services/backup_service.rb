require "fileutils"
require "net/http"
require "uri"
require "json"

class BackupService
  BACKUP_DIR = Rails.root.join("tmp", "backups").freeze
  CONFIG_FILE = Rails.root.join("tmp", "backup_config.json").freeze

  class WebDAVError < StandardError; end

  # ===================
  # Local Backup Methods
  # ===================

  def self.create_backup(options = {})
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    FileUtils.mkdir_p(BACKUP_DIR)

    backup_file = BACKUP_DIR.join("ledger_backup_#{timestamp}.sql")

    # Create database backup
    result = create_database_backup(backup_file)
    return result unless result[:success]

    # Record in database
    record = BackupRecord.create!(
      filename: result[:file_name],
      file_path: result[:file_path].to_s,
      file_size: result[:size],
      backup_type: options[:type] || "manual",
      status: "completed"
    )

    # WebDAV sync if configured
    if webdav_configured? && options[:sync] != false
      begin
        upload_to_webdav(result[:file_path], result[:file_name])
        record.update!(webdav_url: webdav_url_for(result[:file_name]))
      rescue => e
        Rails.logger.error("WebDAV upload failed: #{e.message}")
      end
    end

    # Cleanup old backups
    cleanup_old_backups

    result.merge(record_id: record.id)
  end

  def self.list_backups(limit: 20)
    records = BackupRecord.order(created_at: :desc).limit(limit)

    records.map do |record|
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

    db_config = Rails.configuration.database_configuration[Rails.env]
    db_name = db_config["database"]
    db_host = db_config["host"] || "localhost"
    db_user = db_config["username"] || "postgres"
    db_password = db_config["password"]

    env_vars = { "PGPASSWORD" => db_password }
    cmd = "psql -h #{db_host} -U #{db_user} -d #{db_name} -f #{backup_file}"

    success = if db_password.present?
      system(env_vars, cmd, out: File::NULL, err: File::NULL)
    else
      system(cmd, out: File::NULL, err: File::NULL)
    end

    if success
      { success: true }
    else
      { success: false, error: "恢复失败" }
    end
  end

  def self.delete_backup(backup_id)
    record = BackupRecord.find_by(id: backup_id)
    return { success: false, error: "记录不存在" } unless record

    # Delete local file
    if File.exist?(record.file_path)
      File.delete(record.file_path)
    end

    # Delete from WebDAV if configured
    if webdav_configured? && record.webdav_url.present?
      begin
        delete_from_webdav(record.filename)
      rescue => e
        Rails.logger.warn("WebDAV delete failed: #{e.message}")
      end
    end

    record.destroy
    { success: true }
  end

  # ===================
  # WebDAV Methods
  # ===================

  def self.configure_webdav(url:, username:, password:, directory: "/")
    config = {
      webdav: {
        url: url.chomp("/"),
        username: username,
        password: encrypt_password(password),
        directory: directory
      }
    }

    FileUtils.mkdir_p(File.dirname(CONFIG_FILE))
    File.write(CONFIG_FILE, config.to_json)

    # Test connection
    test_webdav_connection
  end

  def self.webdav_configured?
    config = load_config
    config.dig("webdav", "url").present?
  end

  def self.webdav_config
    config = load_config
    webdav = config["webdav"] || {}

    {
      url: webdav["url"],
      username: webdav["username"],
      password: webdav["password"] ? decrypt_password(webdav["password"]) : nil,
      directory: webdav["directory"] || "/"
    }
  end

  def self.test_webdav_connection
    return { success: false, error: "WebDAV 未配置" } unless webdav_configured?

    config = webdav_config
    uri = URI.parse("#{config[:url]}#{config[:directory]}")

    request = Net::HTTP::Propfind.new(uri)
    request.basic_auth(config[:username], config[:password])
    request["Depth"] = "0"

    response = make_webdav_request(uri, request)

    if response.code.to_i < 400
      { success: true, message: "连接成功" }
    else
      { success: false, error: "连接失败: #{response.code} #{response.message}" }
    end
  rescue => e
    { success: false, error: "连接失败: #{e.message}" }
  end

  def self.upload_to_webdav(file_path, filename)
    return { success: false, error: "WebDAV 未配置" } unless webdav_configured?

    config = webdav_config
    remote_path = "#{config[:directory]}/#{filename}".gsub("//", "/")
    uri = URI.parse("#{config[:url]}#{remote_path}")

    # Create directory if needed
    ensure_webdav_directory(config)

    # Upload file
    request = Net::HTTP::Put.new(uri)
    request.basic_auth(config[:username], config[:password])
    request.content_type = "application/octet-stream"
    request.body_stream = File.open(file_path, "rb")

    response = make_webdav_request(uri, request)

    if response.code.to_i < 400
      { success: true, url: uri.to_s }
    else
      { success: false, error: "上传失败: #{response.code}" }
    end
  rescue => e
    { success: false, error: "上传失败: #{e.message}" }
  end

  def self.download_from_webdav(filename, local_path)
    return { success: false, error: "WebDAV 未配置" } unless webdav_configured?

    config = webdav_config
    remote_path = "#{config[:directory]}/#{filename}".gsub("//", "/")
    uri = URI.parse("#{config[:url]}#{remote_path}")

    request = Net::HTTP::Get.new(uri)
    request.basic_auth(config[:username], config[:password])

    response = make_webdav_request(uri, request)

    if response.code.to_i == 200
      File.open(local_path, "wb") { |f| f.write(response.body) }
      { success: true, path: local_path }
    else
      { success: false, error: "下载失败: #{response.code}" }
    end
  rescue => e
    { success: false, error: "下载失败: #{e.message}" }
  end

  def self.list_webdav_backups
    return [] unless webdav_configured?

    config = webdav_config
    uri = URI.parse("#{config[:url]}#{config[:directory]}")

    request = Net::HTTP::Propfind.new(uri)
    request.basic_auth(config[:username], config[:password])
    request["Depth"] = "1"
    request.content_type = "application/xml"

    response = make_webdav_request(uri, request)

    return [] unless response.code.to_i == 207

    parse_webdav_response(response.body)
  rescue => e
    Rails.logger.error("WebDAV list failed: #{e.message}")
    []
  end

  def self.delete_from_webdav(filename)
    return { success: false, error: "WebDAV 未配置" } unless webdav_configured?

    config = webdav_config
    remote_path = "#{config[:directory]}/#{filename}".gsub("//", "/")
    uri = URI.parse("#{config[:url]}#{remote_path}")

    request = Net::HTTP::Delete.new(uri)
    request.basic_auth(config[:username], config[:password])

    response = make_webdav_request(uri, request)

    if response.code.to_i < 400
      { success: true }
    else
      { success: false, error: "删除失败: #{response.code}" }
    end
  end

  # ===================
  # Auto Backup
  # ===================

  def self.auto_backup_enabled?
    config = load_config
    config.dig("auto_backup", "enabled") == true
  end

  def self.enable_auto_backup(frequency: "daily", retention: 10, webdav_sync: false)
    config = load_config
    config["auto_backup"] = {
      enabled: true,
      frequency: frequency,
      retention_count: retention,
      webdav_sync: webdav_sync
    }
    save_config(config)
    { success: true }
  end

  def self.disable_auto_backup
    config = load_config
    config["auto_backup"] = { enabled: false }
    save_config(config)
    { success: true }
  end

  def self.perform_auto_backup
    return unless auto_backup_enabled?

    config = load_config["auto_backup"]
    create_backup(type: "auto", sync: config["webdav_sync"])
  end

  # ===================
  # Private Methods
  # ===================

  private_class_method

  def self.create_database_backup(backup_file)
    db_config = Rails.configuration.database_configuration[Rails.env]
    db_name = db_config["database"]
    db_host = db_config["host"] || "localhost"
    db_user = db_config["username"] || "postgres"
    db_password = db_config["password"]

    env_vars = { "PGPASSWORD" => db_password }
    cmd = "pg_dump -h #{db_host} -U #{db_user} -d #{db_name} -f #{backup_file}"

    output = if db_password.present?
      system(env_vars, cmd, out: File::NULL, err: File::NULL)
    else
      system(cmd, out: File::NULL, err: File::NULL)
    end

    if output && File.exist?(backup_file)
      {
        success: true,
        file_path: backup_file.to_s,
        file_name: File.basename(backup_file),
        size: File.size(backup_file)
      }
    else
      { success: false, error: "备份创建失败" }
    end
  end

  def self.cleanup_old_backups(keep: 10)
    backups = BackupRecord.order(created_at: :desc)
    backups.drop(keep).each do |backup|
      begin
        File.delete(backup.file_path) if File.exist?(backup.file_path)
        backup.destroy
      rescue => e
        Rails.logger.error("Failed to cleanup backup #{backup.id}: #{e.message}")
      end
    end
  end

  def self.load_config
    return {} unless File.exist?(CONFIG_FILE)
    JSON.parse(File.read(CONFIG_FILE))
  rescue
    {}
  end

  def self.save_config(config)
    FileUtils.mkdir_p(File.dirname(CONFIG_FILE))
    File.write(CONFIG_FILE, config.to_json)
  end

  def self.encrypt_password(password)
    # Use Rails encrypted credentials or a secure key
    # For simplicity, we use Base64 with a warning that this should be
    # replaced with proper encryption in production
    ActiveSupport::MessageEncryptor.new(
      Rails.application.secret_key_base[0, 32]
    ).encrypt_and_sign(password)
  end

  def self.decrypt_password(encrypted)
    ActiveSupport::MessageEncryptor.new(
      Rails.application.secret_key_base[0, 32]
    ).decrypt_and_verify(encrypted)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    # Fallback for old base64-encoded passwords
    Base64.decode64(encrypted)
  end

  def self.webdav_url_for(filename)
    return nil unless webdav_configured?
    config = webdav_config
    "#{config[:url]}#{config[:directory]}/#{filename}".gsub("//", "/")
  end

  def self.make_webdav_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.read_timeout = 60
    http.request(request)
  end

  def self.ensure_webdav_directory(config)
    dir_path = config[:directory]
    return if dir_path == "/" || dir_path.empty?

    uri = URI.parse("#{config[:url]}#{dir_path}")
    request = Net::HTTP::Mkcol.new(uri)
    request.basic_auth(config[:username], config[:password])

    make_webdav_request(uri, request)
  rescue => e
    # Directory might already exist
    nil
  end

  def self.parse_webdav_response(xml_body)
    require "nokogiri"

    doc = Nokogiri::XML(xml_body)
    doc.remove_namespaces!

    doc.xpath("//response").map do |response|
      href = response.at_xpath("href")&.text
      next if href.nil?

      filename = File.basename(URI.decode_www_form_component(href))
      next if filename.empty?

      {
        name: filename,
        href: href,
        size: response.at_xpath("propstat/prop/getcontentlength")&.text&.to_i,
        last_modified: response.at_xpath("propstat/prop/getlastmodified")&.text
      }
    end.compact
  rescue => e
    Rails.logger.error("Failed to parse WebDAV response: #{e.message}")
    []
  end
end
