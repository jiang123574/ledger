module Api
  module V1
    class ExternalController < ApplicationController
      skip_before_action :verify_authenticity_token

      before_action :verify_api_key

    def health
      render json: { status: "ok", timestamp: Time.current }
    end

    def context
      accounts = Account.visible.pluck(:id, :name)
      categories = Category.pluck(:id, :name)

      render json: {
        accounts: accounts.map { |id, name| { id: id, name: name } },
        categories: categories.map { |id, name| { id: id, name: name } }
      }
    end

    def transactions
      if request.get?
        list_transactions
      else
        create_transaction
      end
    end

    # GET /api/v1/external/transactions - 读取流水（供 agent/外部系统分析）
    # 查询参数: account_id / type(expense|income) / category_id / start_date / end_date / limit(默认100, 最大500)
    def list_transactions
      scope = Entry.visible.reverse_chronological

      if params[:account_id].present?
        account_id = params[:account_id].to_i
        unless Account.exists?(id: account_id)
          render json: { success: false, error: "Account not found" }, status: :not_found
          return
        end
        scope = scope.by_account(account_id)
      end

      if params[:type].present?
        kind = %w[expense income].include?(params[:type].to_s.downcase) ? params[:type].to_s.downcase : "expense"
        scope = scope.with_entryable_transaction.where(entryable_transactions: { kind: kind })
      end

      if params[:category_id].present?
        scope = scope.with_entryable_transaction.where(entryable_transactions: { category_id: params[:category_id].to_i })
      end

      if params[:start_date].present? || params[:end_date].present?
        begin
          start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.new(2000, 1, 1)
          end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
        rescue ArgumentError
          render json: { success: false, error: "Invalid date format" }, status: :bad_request
          return
        end
        scope = scope.by_date_range(start_date, end_date)
      end

      total = scope.count
      limit = params[:limit].to_i
      limit = 100 if limit <= 0
      limit = 500 if limit > 500

      entries = scope.limit(limit).to_a
      # 多态关联 entryable 不能用 includes，需手动 Preloader（支持多态 + 嵌套 category）
      ActiveRecord::Associations::Preloader.new(records: entries, associations: [ :account, { entryable: :category } ]).call

      render json: {
        success: true,
        total: total,
        transactions: entries.map { |entry| serialize_entry(entry) }
      }
    end

    def create_transaction
      # 验证 account_id
      account_id = params[:account_id].to_i
      account = Account.find_by(id: account_id)
      unless account
        render json: { success: false, error: "Account not found" }, status: :not_found
        return
      end

      # 支持新的 Entry 创建
      kind = params[:type].to_s.downcase == "income" ? "income" : "expense"
      amount = params[:amount].to_d
      entry_amount = kind == "income" ? amount : -amount

      entryable = Entryable::Transaction.new(
        kind: kind,
        category_id: params[:category_id]
      )

      unless entryable.valid?
        render json: { success: false, errors: entryable.errors.full_messages }, status: :unprocessable_entity
        return
      end

      entry = Entry.new(
        account_id: account.id,
        date: params[:date] || Time.current,
        name: params[:note] || "API导入",
        amount: entry_amount,
        currency: "CNY",
        entryable: entryable
      )

      if entry.save
        render json: { success: true, entry: { id: entry.id, date: entry.date, amount: entry.amount } }, status: :created
      else
        render json: { success: false, errors: entry.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def serialize_entry(entry)
      entryable = entry.entryable
      {
        id: entry.id,
        date: entry.date.to_s,
        name: entry.name,
        amount: entry.amount.to_f,
        currency: entry.currency,
        kind: entryable.respond_to?(:kind) ? entryable.kind : nil,
        entryable_type: entry.entryable_type,
        transfer_id: entry.transfer_id,
        account_id: entry.account_id,
        account_name: entry.account&.name,
        category_id: entryable.respond_to?(:category_id) ? entryable.category_id : nil,
        category_name: entryable.respond_to?(:category) ? entryable.category&.name : nil,
        notes: entry.notes,
        created_at: entry.created_at.iso8601
      }
    end

    def verify_api_key
      api_key = ENV["EXTERNAL_API_KEY"]
      if api_key.blank?
        render json: { error: "API Key not configured" }, status: :forbidden
        return
      end

      provided_key = request.headers["X-API-Key"]
      unless ActiveSupport::SecurityUtils.secure_compare(provided_key.to_s, api_key)
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

    def transaction_params
      params.permit(:date, :type, :amount, :category, :category_id, :note, :account_id, :transaction_type)
    end
    end
  end
end
