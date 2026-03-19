module Api
  class CurrencyController < ApplicationController
    skip_before_action :verify_authenticity_token

    before_action :set_currencies

    def rates
      render json: {
        base: @default_currency.code,
        rates: @currencies.pluck(:code, :exchange_rate).to_h
      }
    end

    private

    def set_currencies
      @currencies = Currency.all
      @default_currency = Currency.default || Currency.find_by(code: "CNY")
    end
  end
end
