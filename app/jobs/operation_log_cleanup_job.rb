# frozen_string_literal: true

class OperationLogCleanupJob < ApplicationJob
  queue_as :low

  def perform(retention_days: 365)
    cutoff_date = retention_days.days.ago

    deleted_count = OperationLog.where("created_at < ?", cutoff_date).delete_all

    Rails.logger.info "OperationLogCleanupJob: Deleted #{deleted_count} operation logs older than #{retention_days} days"
  end
end

# 兼容性别名
ActivityLogCleanupJob = OperationLogCleanupJob
