# frozen_string_literal: true

module Api
  class VitalsController < ActionController::API
    # Disable CSRF for API endpoint
    skip_before_action :verify_authenticity_token, raise: false

    def create
      # Log web vitals metrics
      metric_data = params.permit(:metric, :value, :rating, :url, :timestamp)
      
      Rails.logger.info "[WebVitals] #{metric_data[:metric]}: #{metric_data[:value]}ms (#{metric_data[:rating]}) - #{metric_data[:url]}"
      
      # Optionally store in database for analysis
      # WebVitalMetric.create!(metric_data.to_h) if defined?(WebVitalMetric)
      
      head :ok
    end
  end
end