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
      transaction = Transaction.new(transaction_params)
      transaction.date ||= Time.current

      if transaction.save
        render json: { success: true, transaction: transaction }, status: :created
      else
        render json: { success: false, errors: transaction.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def verify_api_key
      api_key = ENV["EXTERNAL_API_KEY"]
      return if api_key.blank?

      provided_key = request.headers["X-API-Key"]
      unless provided_key == api_key
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

    def transaction_params
      params.permit(:date, :type, :amount, :category, :category_id, :note, :account_id, :transaction_type)
    end
  end
end
