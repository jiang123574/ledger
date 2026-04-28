# frozen_string_literal: true

class AutoBackupJob < ApplicationJob
  queue_as :low

  def perform
    return unless BackupService.auto_backup_enabled?

    Rails.logger.info "AutoBackupJob: Starting automatic backup..."

    result = BackupService.perform_auto_backup

    if result[:success]
      Rails.logger.info "AutoBackupJob: Backup completed successfully - #{result[:file_name]}"
    else
      Rails.logger.error "AutoBackupJob: Backup failed - #{result[:error]}"
    end

    result
  end
end
