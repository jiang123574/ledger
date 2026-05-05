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
      record.destroy
      redirect_to backups_path, alert: "备份文件已不存在，记录已清理"
      return
    end

    send_file record.file_path,
              filename: record.filename,
              type: "application/octet-stream"
  end

  def restore
    record = BackupRecord.find(params[:id])

    unless File.exist?(record.file_path)
      record.destroy
      redirect_to backups_path, alert: "备份文件已不存在，记录已清理"
      return
    end

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

    respond_to do |format|
      format.turbo_stream do
        message = result[:success] ? "✓ 连接成功" : "✗ #{result[:error]}"
        css_class = result[:success] ? "text-sm text-green-600 dark:text-green-400" : "text-sm text-red-600 dark:text-red-400"
        render turbo_stream: turbo_stream.update("webdav-test-result", "<span class=\"#{css_class}\">#{message}</span>".html_safe)
      end
      format.json { render json: result }
    end
  end

  def webdav_upload
    record = BackupRecord.find(params[:id])

    unless File.exist?(record.file_path)
      record.destroy
      redirect_to backups_path, alert: "备份文件已不存在，记录已清理"
      return
    end

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
    result = BackupService.download_from_webdav(safe_filename, BackupService::BACKUP_DIR.join(safe_filename))

    if result[:success]
      # 安全验证：确保下载的文件路径在 BACKUP_DIR 内
      begin
        expanded_path = Pathname.new(result[:path]).realpath
        base_dir = BackupService::BACKUP_DIR.realpath
        unless expanded_path.to_s.start_with?(base_dir.to_s)
          redirect_to backups_path, alert: "非法文件路径"
          return
        end
      rescue Errno::ENOENT
        redirect_to backups_path, alert: "下载文件不存在"
        return
      end

      send_file expanded_path, filename: safe_filename
    else
      redirect_to backups_path, alert: result[:error]
    end
  end

  def webdav_delete
    safe_filename = File.basename(params[:filename].to_s)
    result = BackupService.delete_from_webdav(safe_filename)

    if result[:success]
      redirect_to backups_path, notice: "云端备份已删除"
    else
      redirect_to backups_path, alert: result[:error]
    end
  end

  # Auto Backup
  def enable_auto_backup
    result = BackupService.enable_auto_backup(
      frequency: params[:frequency] || "daily",
      retention: params[:retention] || 10,
      webdav_sync: params[:webdav_sync] == "1"
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
