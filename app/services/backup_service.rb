require "fileutils"

class BackupService
  def self.create_backup
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    backup_dir = Rails.root.join("tmp", "backups")
    FileUtils.mkdir_p(backup_dir)

    db_config = Rails.configuration.database_configuration[Rails.env]
    db_name = db_config["database"]
    db_host = db_config["host"] || "localhost"
    db_user = db_config["username"] || "postgres"
    db_password = db_config["password"]

    backup_file = backup_dir.join("ledger_backup_#{timestamp}.sql")

    env_vars = {
      "PGPASSWORD" => db_password
    }

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
        file_name: "ledger_backup_#{timestamp}.sql",
        size: File.size(backup_file)
      }
    else
      {
        success: false,
        error: "备份创建失败"
      }
    end
  end

  def self.list_backups
    backup_dir = Rails.root.join("tmp", "backups")
    return [] unless Dir.exist?(backup_dir)

    Dir.glob(backup_dir.join("*.sql"))
       .sort_by { |f| File.mtime(f) }
       .reverse
       .map do |f|
        {
          name: File.basename(f),
          path: f,
          size: File.size(f),
          created_at: File.mtime(f)
        }
      end
  end

  def self.cleanup_old_backups(keep: 5)
    backups = list_backups
    return if backups.size <= keep

    backups.drop(keep).each do |backup|
      File.delete(backup[:path])
    end
  end
end
