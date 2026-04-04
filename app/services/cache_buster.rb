# frozen_string_literal: true

# Cache versioning utility. Replaces delete_matched with atomic version bumps.
#
# Usage:
#   CacheBuster.bump(:entries)        # increment version
#   CacheBuster.version(:entries)     # read current version
#
# Cache keys should include the version:
#   Rails.cache.fetch("entries_list/#{CacheBuster.version(:entries)}") { ... }
#
# This avoids expensive delete_matched calls on SolidCache.
class CacheBuster
  NAMESPACE = "cache_buster"

  # Increment version for a given scope and return new version
  def self.bump(scope)
    key = version_key(scope)
    current = Rails.cache.read(key).to_i
    new_version = current + 1
    Rails.cache.write(key, new_version, raw: true)
    new_version
  end

  # Read current version for a given scope
  def self.version(scope)
    Rails.cache.read(version_key(scope)).to_i
  end

  # Convenience: bump multiple scopes at once
  def self.bump_all(*scopes)
    scopes.each { |s| bump(s) }
  end

  private_class_method :new

  def self.version_key(scope)
    "#{NAMESPACE}/#{scope}"
  end
end
