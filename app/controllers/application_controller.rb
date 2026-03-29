class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :run_due_plans_if_needed

  private

  def run_due_plans_if_needed
    return unless request.get?
    return unless request.format.html?

    cache_key = "plans:auto_execute:last_run_at"
    last_run_at = Rails.cache.read(cache_key)
    return if last_run_at.present? && last_run_at > 1.minute.ago

    Plan.generate_all_due!
    Rails.cache.write(cache_key, Time.current, expires_in: 10.minutes)
  rescue => e
    Rails.logger.error("Auto execute plans failed: #{e.class} - #{e.message}")
  end
end
