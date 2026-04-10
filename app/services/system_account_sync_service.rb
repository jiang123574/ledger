# frozen_string_literal: true

class SystemAccountSyncService
  RECEIVABLE_ACCOUNT_NAME = "应收款"
  PAYABLE_ACCOUNT_NAME = "应付款"
  DEFAULT_CURRENCY = "CNY"

  class << self
    def sync_all!
      changed = false
      changed ||= sync_receivable_account!
      changed ||= sync_payable_account!
      bump_cache_versions if changed
    end

    def sync_receivable_account!
      # 新逻辑：创建应收款时已通过转账 Entry 记录金额，不再设置 initial_balance
      # 保持 initial_balance = 0，让 current_balance = 0 + entry_sum 正确反映应收款金额
      upsert_system_account!(name: RECEIVABLE_ACCOUNT_NAME, initial_balance: 0)
    end

    def sync_payable_account!
      amount = Payable.unsettled.sum(:remaining_amount).to_d
      upsert_system_account!(name: PAYABLE_ACCOUNT_NAME, initial_balance: -amount)
    end

    private

    def upsert_system_account!(name:, initial_balance:)
      account = Account.find_or_initialize_by(name: name)
      account.type = account.type.presence || "CASH"
      account.currency = account.currency.presence || DEFAULT_CURRENCY
      account.include_in_total = true if account.include_in_total.nil?
      account.hidden = false if account.hidden.nil?

      return false if account.persisted? && account.initial_balance.to_d == initial_balance.to_d

      account.initial_balance = initial_balance
      account.save!
      true
    end

    def bump_cache_versions
      CacheBuster.bump(:accounts)
      CacheBuster.bump(:entries)
    end
  end
end
