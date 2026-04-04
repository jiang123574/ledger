# frozen_string_literal: true

class Importers::OfxImporter < Importers::BaseImporter
  SUPPORTED_HEADERS = %w[日期 金额 描述 FIT_ID].freeze

  private

  def parse_rows(file)
    require "ofx"

    ofx = OFX(file.path)
    ofx.account.transactions.map do |tx|
      {
        "日期" => tx.posted_at&.to_date,
        "金额" => tx.amount,
        "描述" => tx.name || tx.memo,
        "FIT_ID" => tx.fit_id,
        "_account_name" => @options[:account_name] || "Imported Account",
        "_currency" => ofx.account.currency || "CNY"
      }
    end
  end

  def normalize_row(raw_row)
    # Store metadata for later use
    @ofx_account_name = raw_row.delete("_account_name")
    @ofx_currency = raw_row.delete("_currency")
    raw_row
  end

  def format_name
    "ofx"
  end

  # OFX has its own import logic (creates Entry directly)
  def import_row(row, _idx)
    amount = row["金额"].to_d
    return if amount.zero? && row["日期"].nil?

    kind = amount >= 0 ? "income" : "expense"
    account = ImportAccountResolver.find_or_create(@ofx_account_name)

    entryable = Entryable::Transaction.new(kind: kind)
    entryable.save(validate: false)

    Entry.create!(
      date: row["日期"] || Date.current,
      name: row["描述"] || "OFX Import",
      amount: amount,
      currency: @ofx_currency || "CNY",
      account: account,
      entryable: entryable
    )

    @results[:success] += 1
  end

  def preview(file)
    require "ofx"

    ofx = OFX(file.path)
    transactions = ofx.account.transactions.first(MAX_PREVIEW_ROWS)

    {
      format: "ofx",
      headers: [ "日期", "金额", "描述", "FIT ID" ],
      rows: transactions.map do |tx|
        { "日期" => tx.posted_at&.to_date, "金额" => tx.amount, "描述" => tx.name || tx.memo, "FIT_ID" => tx.fit_id }
      end,
      total_rows: ofx.account.transactions.count,
      account_info: {
        bank_id: ofx.account.bank_id,
        account_id: ofx.account.id,
        currency: ofx.account.currency
      }
    }
  end
end
