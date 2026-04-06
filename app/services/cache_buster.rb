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
    current = cache_store.read(key).to_i
    new_version = current + 1
    cache_store.write(key, new_version)
    new_version
  end

  # Read current version for a given scope
  def self.version(scope)
    cache_store.read(version_key(scope)).to_i
  end

  # Convenience: bump multiple scopes at once
  def self.bump_all(*scopes)
    scopes.each { |s| bump(s) }
  end

  # Clear internal cache versions (useful for tests)
  def self.clear!
    cache_store.clear if cache_store.respond_to?(:clear)
    @cache_store = nil
  end

  private_class_method :new

  def self.version_key(scope)
    "#{NAMESPACE}/#{scope}"
  end

  def self.cache_store
    # test 环境默认 :null_store 不保留写入，导致 bump/version 永远为 0
    # 回退到进程内内存 store，保持 CacheBuster 语义稳定且不影响生产配置
    @cache_store ||= begin
      store = Rails.cache
      store.is_a?(ActiveSupport::Cache::NullStore) ? ActiveSupport::Cache::MemoryStore.new : store
    end
  end
end
