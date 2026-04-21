# frozen_string_literal: true

class ActivityLogCleanupJob < ApplicationJob
  queue_as :low

  def perform(retention_days: 365)
    cutoff_date = retention_days.days.ago

    deleted_count = ActivityLog.where("created_at < ?", cutoff_date).delete_all

    Rails.logger.info "ActivityLogCleanupJob: Deleted #{deleted_count} activity logs older than #{retention_days} days"
  end
end
