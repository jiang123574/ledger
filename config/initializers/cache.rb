# frozen_string_literal: true

# Cache configuration for fragment caching
# Using SolidCache for Rails 8+

# Enable fragment caching in development for testing
if Rails.env.development?
  Rails.application.config.action_controller.perform_caching = true
end