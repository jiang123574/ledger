# Service for preparing data for accounts#index
# Encapsulates caching, data loading, and query building
class AccountsIndexService
  def initialize(params, cache_versions)
    @params = params
    @av = cache_versions[:accounts]
    @ev = cache_versions[:entries]
  end

  def load_accounts
    Rails.cache.fetch("accounts_list/#{@params[:show_hidden]}/#{@av}", expires_in: CacheConfig::TEN_MINUTES) do
      if @params[:show_hidden] == "true"
        Account.order(:sort_order, :name).to_a
      else
        Account.visible.order(:sort_order, :name).to_a
      end
    end
  end

  def load_account_balances(accounts)
    Rails.cache.fetch("account_balances/#{@ev}", expires_in: CacheConfig::SHORT) do
      account_ids = accounts.map(&:id)
      results = Entry.where(account_id: account_ids, entryable_type: "Entryable::Transaction")
                       .group(:account_id)
                       .sum(:amount)
      Account.where(id: account_ids).pluck(:id, :initial_balance).each_with_object({}) do |(id, ib), hash|
        hash[id] = ib.to_d + (results[id] || 0)
      end
    end
  end

  def load_total_assets
    Rails.cache.fetch("total_assets/#{@ev}", expires_in: CacheConfig::SHORT) do
      Account.total_assets
    end
  end

  def load_categories
    Rails.cache.fetch("categories_active/#{@av}", expires_in: CacheConfig::LONG) do
      Category.active.by_sort_order.to_a
    end
  end

  def load_expense_categories
    Rails.cache.fetch("expense_categories_active/#{@av}", expires_in: CacheConfig::LONG) do
      Category.expense.active.by_sort_order.to_a
    end
  end

  def load_counterparties
    Rails.cache.fetch("counterparties_list/#{@av}", expires_in: CacheConfig::LONG) do
      Counterparty.order(:name).to_a
    end
  end

  def load_unsettled_receivables
    Receivable.where(settled_at: nil).order(date: :desc).limit(50)
  end

  def build_entries_query
    query_service = AccountEntriesQueryService.new(@params)
    query_service.build
  end

  def load_entries_with_balance(entries_query, page, per_page)
    filter_cache_key = AccountEntriesQueryService.new(@params).cache_key
    entries_cache_key = "entries_list/#{filter_cache_key}/#{page}/#{per_page}/#{@ev}"

    cached_data = Rails.cache.fetch(entries_cache_key, expires_in: CacheConfig::MEDIUM) do
      result = AccountStatsService.entries_with_balance(
        entries_query, page: page, per_page: per_page, account_id: @params[:account_id].presence
      )
      result.map { |entry, balance| [ entry.id, balance ] }
    end

    entry_ids = cached_data.map(&:first)
    balance_map = cached_data.to_h

    return [] if entry_ids.empty?

    entries = Entry.where(id: entry_ids)
      .includes(:entryable, entryable: :category)
      .to_a

    entry_id_to_index = entry_ids.each_with_index.to_h
    entries.sort_by! { |e| entry_id_to_index[e.id] || Float::INFINITY }
    AccountStatsService.preload_transfer_accounts_for(entries.map { |e| [ e, nil ] })
    entries.map { |e| [ e, balance_map[e.id] ] }
  end

  def load_total_count(entries_query, filter_cache_key)
    Rails.cache.fetch("entries_count/#{filter_cache_key}/#{@ev}", expires_in: CacheConfig::FAST) do
      entries_query.count
    end
  end

  def load_stats(period_type, period_value)
    category_ids = @params[:category_ids]&.map(&:to_i)&.select { |id| id > 0 } || []
    stats_cache_key = "stats/#{@params[:account_id] || 'all'}/#{period_type}/#{period_value}/#{@params[:type]}/#{category_ids.empty? ? 'no_cat' : category_ids.sort.join(',')}/#{@ev}"

    Rails.cache.fetch(stats_cache_key, expires_in: CacheConfig::SHORT) do
      AccountStatsService.entry_stats(
        account_id: @params[:account_id].presence,
        period_type: period_type,
        period_value: period_value,
        filter_type: @params[:type].presence,
        category_ids: category_ids
      )
    end
  end
end
