class BackupsController < ApplicationController
  def index
    @backups = BackupService.list_backups(limit: 20)
    @webdav_configured = BackupService.webdav_configured?
    @auto_backup_enabled = BackupService.auto_backup_enabled?

    if @webdav_configured
      @webdav_config = BackupService.webdav_config
      @webdav_backups = BackupService.list_webdav_backups
    end
  end

  def create
    result = BackupService.create_backup(type: params[:type] || "manual", sync: params[:sync] != "false")

    if result[:success]
      redirect_to backups_path, notice: "备份已创建: #{result[:file_name]}"
    else
      redirect_to backups_path, alert: result[:error]
    end
  end

  def download
    record = BackupRecord.find(params[:id])

    unless File.exist?(record.file_path)
      redirect_to backups_path, alert: "备份文件不存在"
      return
    end

    send_file record.file_path,
              filename: record.filename,
              type: "application/octet-stream"
  end

  def restore
    record = BackupRecord.find(params[:id])
    result = BackupService.restore_backup(record.file_path)

    if result[:success]
      redirect_to backups_path, notice: "数据已从备份恢复"
    else
      redirect_to backups_path, alert: result[:error]
    end
  end

  def destroy
    result = BackupService.delete_backup(params[:id])

    if result[:success]
      redirect_to backups_path, notice: "备份已删除"
    else
      redirect_to backups_path, alert: result[:error]
    end
  end

  # WebDAV Actions
  def webdav_config
    @webdav_config = BackupService.webdav_config if BackupService.webdav_configured?
  end

  def webdav_connect
    result = BackupService.configure_webdav(
      url: params[:url],
      username: params[:username],
      password: params[:password],
      directory: params[:directory] || "/"
    )

    if result[:success]
      redirect_to backups_path, notice: "WebDAV 连接成功"
    else
      redirect_to backups_path, alert: result[:error]
    end
  end

  def webdav_test
    result = BackupService.test_webdav_connection
    render json: result
  end

  def webdav_upload
    record = BackupRecord.find(params[:id])
    result = BackupService.upload_to_webdav(record.file_path, record.filename)

    if result[:success]
      record.update!(webdav_url: result[:url])
      redirect_to backups_path, notice: "已上传到 WebDAV"
    else
      redirect_to backups_path, alert: result[:error]
    end
  end

  def webdav_download
    safe_filename = File.basename(params[:filename].to_s)
    result = BackupService.download_from_webdav(safe_filename, Rails.root.join("tmp", "backups", safe_filename))

    if result[:success]
      send_file result[:path], filename: safe_filename
    else
      redirect_to backups_path, alert: result[:error]
    end
  end

  # Auto Backup
  def enable_auto_backup
    result = BackupService.enable_auto_backup(
      frequency: params[:frequency] || "daily",
      retention: params[:retention] || 10,
      webdav_sync: params[:webdav_sync] == "true"
    )

    if result[:success]
      redirect_to backups_path, notice: "自动备份已启用"
    else
      redirect_to backups_path, alert: "启用失败"
    end
  end

  def disable_auto_backup
    result = BackupService.disable_auto_backup

    if result[:success]
      redirect_to backups_path, notice: "自动备份已禁用"
    else
      redirect_to backups_path, alert: "禁用失败"
    end
  end
end
