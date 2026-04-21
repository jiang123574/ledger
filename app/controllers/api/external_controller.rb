module Api
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
        account_id: params[:account_id],
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
