# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_08_082312) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.integer "billing_day"
    t.string "billing_day_mode", default: "current"
    t.decimal "credit_limit", precision: 10, scale: 2
    t.string "currency", limit: 3, default: "CNY"
    t.integer "due_day"
    t.string "due_day_mode", default: "fixed"
    t.integer "due_day_offset"
    t.jsonb "extra", default: {}
    t.integer "hidden", default: 0
    t.integer "include_in_total", default: 1
    t.decimal "initial_balance", precision: 10, scale: 2, default: "0.0"
    t.date "last_transaction_date"
    t.jsonb "locked_attributes", default: {}
    t.string "name", null: false
    t.integer "sort_order", default: 0
    t.integer "transactions_count", default: 0, null: false
    t.string "type"
    t.index ["extra"], name: "idx_accounts_extra_gin", using: :gin
    t.index ["hidden", "include_in_total", "type"], name: "idx_accounts_visibility_type"
    t.index ["hidden", "include_in_total"], name: "index_accounts_visibility"
    t.index ["last_transaction_date"], name: "idx_accounts_last_trans_date"
    t.index ["locked_attributes"], name: "idx_accounts_locked_gin", using: :gin
    t.index ["name"], name: "index_accounts_on_name", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
    t.index ["blob_id"], name: "index_active_storage_variant_records_on_blob_id"
  end

  create_table "activity_logs", force: :cascade do |t|
    t.string "action", null: false
    t.json "changeset"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "ip_address"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.datetime "updated_at", null: false
    t.string "whodunnit"
    t.index ["action"], name: "index_activity_logs_on_action"
    t.index ["created_at"], name: "index_activity_logs_on_created_at"
    t.index ["item_type", "item_id"], name: "index_activity_logs_on_item"
    t.index ["item_type", "item_id"], name: "index_activity_logs_on_item_type_and_item_id"
  end

  create_table "attachments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entry_id"
    t.string "file_name", limit: 255, null: false
    t.string "file_path", limit: 500, null: false
    t.integer "file_size", default: 0
    t.string "file_type", limit: 50, null: false
    t.string "thumbnail_path", limit: 500
    t.integer "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_attachments_on_entry_id"
    t.index ["transaction_id", "file_type"], name: "idx_attachments_trans_type"
    t.index ["transaction_id"], name: "index_attachments_on_transaction_id"
  end

  create_table "backup_records", force: :cascade do |t|
    t.string "backup_type", limit: 20, default: "manual"
    t.datetime "created_at", null: false
    t.string "file_path", limit: 500, null: false
    t.integer "file_size", default: 0
    t.string "filename", null: false
    t.string "note", limit: 500
    t.string "status", limit: 20, default: "completed"
    t.datetime "updated_at", null: false
    t.string "webdav_url", limit: 500
  end

  create_table "budget_items", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "category", limit: 50
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.string "name", limit: 100, null: false
    t.text "notes"
    t.bigint "single_budget_id", null: false
    t.decimal "spent_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_budget_items_on_category"
    t.index ["single_budget_id"], name: "index_budget_items_on_single_budget_id"
  end

  create_table "budgets", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "CNY"
    t.string "month", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_budgets_on_category_id"
    t.index ["month", "category_id"], name: "index_budgets_month_category"
    t.index ["month"], name: "index_budgets_on_month"
  end

  create_table "categories", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "color", limit: 7, default: "#6b7280"
    t.jsonb "extra", default: {}
    t.string "icon"
    t.integer "level", default: 0
    t.string "name", null: false
    t.integer "parent_id"
    t.integer "sort_order", default: 0
    t.string "type"
    t.index ["active", "type"], name: "idx_categories_active_type"
    t.index ["active"], name: "index_categories_on_active"
    t.index ["name", "parent_id"], name: "index_categories_on_name_and_parent_id", unique: true
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["sort_order"], name: "index_categories_on_sort_order"
    t.index ["type", "sort_order"], name: "index_categories_type_order"
  end

  create_table "counterparties", force: :cascade do |t|
    t.string "contact"
    t.string "name", null: false
    t.text "note"
    t.index ["name"], name: "index_counterparties_on_name", unique: true
  end

  create_table "currencies", force: :cascade do |t|
    t.string "code", limit: 3, null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true
    t.boolean "is_default", default: false
    t.string "name", limit: 50, null: false
    t.decimal "rate", precision: 12, scale: 6, default: "1.0"
    t.string "symbol", limit: 10, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_currencies_on_code", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.integer "account_id", null: false
    t.decimal "amount", precision: 19, scale: 4, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "CNY", null: false
    t.date "date", null: false
    t.integer "entryable_id", null: false
    t.string "entryable_type", null: false
    t.boolean "excluded", default: false, null: false
    t.string "external_id"
    t.jsonb "extra", default: {}
    t.integer "import_id"
    t.boolean "import_locked", default: false, null: false
    t.jsonb "locked_attributes", default: {}
    t.string "name", null: false
    t.text "notes"
    t.integer "parent_entry_id"
    t.integer "sort_order", default: 0, null: false
    t.string "source"
    t.integer "transfer_id"
    t.datetime "updated_at", null: false
    t.boolean "user_modified", default: false, null: false
    t.index "lower((name)::text)", name: "idx_entries_name_lower"
    t.index ["account_id", "date", "entryable_type"], name: "idx_entries_account_date_type"
    t.index ["account_id", "date", "name"], name: "idx_entries_account_date_name"
    t.index ["account_id", "date", "notes"], name: "idx_entries_account_date_notes"
    t.index ["account_id", "date"], name: "idx_entries_account_date"
    t.index ["account_id", "source", "external_id"], name: "idx_entries_external_unique", unique: true, where: "((external_id IS NOT NULL) AND (source IS NOT NULL))"
    t.index ["date", "entryable_type"], name: "idx_entries_date_type"
    t.index ["entryable_type", "entryable_id"], name: "idx_entries_entryable"
    t.index ["excluded"], name: "idx_entries_excluded", where: "(excluded = true)"
    t.index ["extra"], name: "idx_entries_extra_gin", using: :gin
    t.index ["id"], name: "index_entries_on_id", unique: true
    t.index ["import_id"], name: "idx_entries_import"
    t.index ["import_locked"], name: "idx_entries_import_locked", where: "(import_locked = true)"
    t.index ["locked_attributes"], name: "idx_entries_locked_gin", using: :gin
    t.index ["parent_entry_id"], name: "idx_entries_parent"
    t.index ["sort_order"], name: "index_entries_on_sort_order"
    t.index ["transfer_id"], name: "idx_entries_transfer"
    t.index ["user_modified"], name: "idx_entries_user_modified", where: "(user_modified = true)"
  end

  create_table "entryable_trades", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "extra", default: {}
    t.jsonb "locked_attributes", default: {}
    t.decimal "price", precision: 19, scale: 4
    t.decimal "qty", precision: 19, scale: 4
    t.integer "security_id"
    t.datetime "updated_at", null: false
    t.index ["security_id"], name: "idx_trades_security"
  end

  create_table "entryable_transactions", force: :cascade do |t|
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.jsonb "extra", default: {}
    t.string "kind"
    t.jsonb "locked_attributes", default: {}
    t.integer "merchant_id"
    t.bigint "source_transaction_id"
    t.jsonb "tags", default: []
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "idx_trans_category"
    t.index ["merchant_id"], name: "idx_trans_merchant"
    t.index ["source_transaction_id"], name: "index_entryable_transactions_on_source_transaction_id"
    t.index ["tags"], name: "idx_trans_tags_gin", using: :gin
  end

  create_table "entryable_valuations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "extra", default: {}
    t.jsonb "locked_attributes", default: {}
    t.datetime "updated_at", null: false
  end

  create_table "exchange_rates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "date", null: false
    t.string "from_currency", limit: 3, null: false
    t.decimal "rate", precision: 12, scale: 6, null: false
    t.string "source", limit: 50, default: "manual"
    t.string "to_currency", limit: 3, null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_exchange_rates_on_date"
    t.index ["from_currency", "to_currency", "date"], name: "index_exchange_rates_on_from_currency_and_to_currency_and_date", unique: true
    t.index ["from_currency"], name: "index_exchange_rates_on_from_currency"
    t.index ["to_currency"], name: "index_exchange_rates_on_to_currency"
  end

  create_table "import_batches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "records"
    t.string "source_name"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_import_batches_on_created_at"
  end

  create_table "one_time_budgets", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "CNY"
    t.datetime "end_date"
    t.string "name", limit: 100, null: false
    t.text "note"
    t.datetime "start_date", null: false
    t.string "status", limit: 20, default: "active"
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_one_time_budgets_on_category_id"
  end

  create_table "payables", force: :cascade do |t|
    t.bigint "account_id"
    t.string "category"
    t.bigint "counterparty_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "CNY"
    t.date "date", default: -> { "CURRENT_DATE" }
    t.string "description"
    t.text "note"
    t.decimal "original_amount", precision: 10, scale: 2
    t.decimal "remaining_amount", precision: 10, scale: 2
    t.datetime "settled_at"
    t.bigint "source_entry_id"
    t.integer "source_transaction_id"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_payables_on_account_id"
    t.index ["counterparty_id"], name: "index_payables_on_counterparty_id"
    t.index ["source_entry_id"], name: "index_payables_on_source_entry_id"
  end

  create_table "plans", force: :cascade do |t|
    t.integer "account_id"
    t.integer "active", default: 1
    t.decimal "amount", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "CNY"
    t.integer "day_of_month", default: 1
    t.integer "installments_completed", default: 0
    t.integer "installments_total", default: 1
    t.datetime "last_generated"
    t.string "name"
    t.decimal "total_amount", precision: 10, scale: 2
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_plans_on_account_id"
  end

  create_table "receivables", force: :cascade do |t|
    t.bigint "account_id"
    t.string "category"
    t.bigint "counterparty_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "CNY"
    t.date "date", default: -> { "CURRENT_DATE" }
    t.string "description"
    t.string "note"
    t.decimal "original_amount", precision: 10, scale: 2
    t.decimal "remaining_amount", precision: 10, scale: 2
    t.datetime "settled_at"
    t.bigint "source_entry_id"
    t.integer "source_transaction_id"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_receivables_on_account_id"
    t.index ["counterparty_id"], name: "index_receivables_on_counterparty_id"
    t.index ["source_entry_id"], name: "index_receivables_on_source_entry_id"
    t.index ["source_transaction_id"], name: "index_receivables_on_source_transaction_id"
  end

  create_table "recurring_transactions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "CNY"
    t.string "frequency", null: false
    t.integer "is_active", default: 1
    t.datetime "next_date", null: false
    t.string "note"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "is_active"], name: "idx_recurring_active"
    t.index ["account_id"], name: "index_recurring_transactions_on_account_id"
    t.index ["category_id"], name: "index_recurring_transactions_on_category_id"
  end

  create_table "single_budgets", force: :cascade do |t|
    t.bigint "category_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "CNY"
    t.text "description"
    t.date "end_date"
    t.string "name", limit: 100, null: false
    t.decimal "spent_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.date "start_date", null: false
    t.string "status", limit: 20, default: "planning", null: false
    t.decimal "total_amount", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_single_budgets_on_category_id"
    t.index ["end_date"], name: "index_single_budgets_on_end_date"
    t.index ["start_date"], name: "index_single_budgets_on_start_date"
    t.index ["status"], name: "index_single_budgets_on_status"
  end

  create_table "taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "tag_id", null: false
    t.bigint "taggable_id", null: false
    t.string "taggable_type", null: false
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_type", "taggable_id", "tag_id"], name: "index_taggings_uniqueness", unique: true
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
  end

  create_table "tags", force: :cascade do |t|
    t.string "color", limit: 7, default: "#3498db"
    t.datetime "created_at", null: false
    t.string "name", limit: 50, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "transaction_tags", id: false, force: :cascade do |t|
    t.integer "tag_id", null: false
    t.integer "transaction_id", null: false
    t.index ["tag_id", "transaction_id"], name: "idx_trans_tags_tag_trans"
    t.index ["tag_id"], name: "index_transaction_tags_on_tag_id"
    t.index ["transaction_id", "tag_id"], name: "index_transaction_tags_on_transaction_id_and_tag_id", unique: true
    t.index ["transaction_id"], name: "index_transaction_tags_on_transaction_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "account_id"
    t.decimal "amount", precision: 10, scale: 2
    t.string "category"
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "CNY"
    t.datetime "date"
    t.string "dedupe_key", limit: 40
    t.decimal "exchange_rate", precision: 12, scale: 6
    t.jsonb "extra", default: {}
    t.integer "link_id"
    t.jsonb "locked_attributes", default: {}
    t.string "note"
    t.decimal "original_amount", precision: 12, scale: 6
    t.bigint "payable_id"
    t.integer "receivable_id"
    t.integer "sort_order", default: 0
    t.string "tag"
    t.integer "target_account_id"
    t.string "type"
    t.datetime "updated_at", null: false
    t.boolean "user_modified", default: false, null: false
    t.index ["account_id", "date", "amount", "type"], name: "idx_trans_unique_check", where: "(dedupe_key IS NULL)"
    t.index ["account_id", "date", "type"], name: "index_transactions_on_account_id_and_date_and_type"
    t.index ["account_id", "date"], name: "index_transactions_account_date"
    t.index ["account_id", "type", "date"], name: "idx_trans_account_type_date"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["category"], name: "index_transactions_on_category"
    t.index ["category_id", "date", "type"], name: "idx_trans_category_date_type"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["date", "type"], name: "idx_trans_date_type"
    t.index ["date"], name: "idx_trans_date_expense", where: "((type)::text = 'EXPENSE'::text)"
    t.index ["date"], name: "idx_trans_date_income", where: "((type)::text = 'INCOME'::text)"
    t.index ["date"], name: "index_transactions_on_date"
    t.index ["dedupe_key"], name: "index_transactions_on_dedupe_key"
    t.index ["extra"], name: "idx_trans_extra_gin", using: :gin
    t.index ["link_id"], name: "index_transactions_on_link_id"
    t.index ["locked_attributes"], name: "idx_trans_locked_gin", using: :gin
    t.index ["payable_id"], name: "index_transactions_on_payable_id"
    t.index ["receivable_id"], name: "index_transactions_on_receivable_id"
    t.index ["target_account_id", "date"], name: "idx_trans_target_date"
    t.index ["target_account_id", "date"], name: "index_transactions_on_target_account_id_and_date"
    t.index ["target_account_id", "type", "date"], name: "idx_trans_target_type_date"
    t.index ["target_account_id"], name: "index_transactions_on_target_account_id"
    t.index ["type", "date", "account_id"], name: "idx_trans_type_date_account"
    t.index ["type", "date"], name: "index_transactions_type_date"
    t.index ["type"], name: "index_transactions_on_type"
    t.index ["user_modified"], name: "idx_trans_user_modified", where: "(user_modified = true)"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attachments", "entries", on_delete: :cascade
  add_foreign_key "attachments", "transactions"
  add_foreign_key "budget_items", "categories", on_delete: :nullify
  add_foreign_key "budget_items", "single_budgets"
  add_foreign_key "budgets", "categories"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "entries", "accounts", on_delete: :cascade
  add_foreign_key "entries", "entries", column: "parent_entry_id", on_delete: :nullify
  add_foreign_key "entryable_transactions", "categories", on_delete: :nullify
  add_foreign_key "one_time_budgets", "categories"
  add_foreign_key "payables", "accounts"
  add_foreign_key "payables", "counterparties"
  add_foreign_key "payables", "entries", column: "source_entry_id", on_delete: :nullify
  add_foreign_key "plans", "accounts"
  add_foreign_key "receivables", "accounts"
  add_foreign_key "receivables", "counterparties"
  add_foreign_key "receivables", "entries", column: "source_entry_id", on_delete: :nullify
  add_foreign_key "receivables", "transactions", column: "source_transaction_id"
  add_foreign_key "recurring_transactions", "accounts"
  add_foreign_key "recurring_transactions", "categories"
  add_foreign_key "single_budgets", "categories"
  add_foreign_key "taggings", "tags"
  add_foreign_key "transaction_tags", "tags", on_delete: :cascade
  add_foreign_key "transaction_tags", "transactions", on_delete: :cascade
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "accounts", column: "target_account_id"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "payables"
  add_foreign_key "transactions", "receivables"
  add_foreign_key "transactions", "transactions", column: "link_id"
end
