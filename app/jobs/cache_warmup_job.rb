# frozen_string_literal: true

class CacheWarmupJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting cache warmup..."

    warmup_category_tree
    warmup_account_balances

    Rails.logger.info "Cache warmup completed"
  end

  private

  def warmup_category_tree
    Category.tree
    Rails.logger.info "Category tree cached"
  end

  def warmup_account_balances
    Account.find_each do |account|
      Rails.cache.fetch("account:#{account.id}:balance", expires_in: 1.hour) do
        account.entries.sum(:amount)
      end
    end
    Rails.logger.info "Account balances cached"
  end
end
