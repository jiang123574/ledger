# frozen_string_literal: true

module Accounts
  class BillStatementsController < ApplicationController
    before_action :set_account

    def create
      unless @account.credit_card?
        render json: { error: "该账户不是信用卡" }, status: :unprocessable_entity
        return
      end

      begin
        billing_date = Date.parse(params[:billing_date])
      rescue ArgumentError, Date::Error
        render json: { error: "日期格式错误" }, status: :bad_request
        return
      end

      statement_amount = BigDecimal(params[:statement_amount].to_s)
      if statement_amount <= 0
        render json: { error: "金额必须大于0" }, status: :bad_request
        return
      end

      statement = @account.bill_statements.find_or_initialize_by(billing_date: billing_date)
      statement.statement_amount = statement_amount
      statement.save!

      render json: { success: true, statement: { billing_date: statement.billing_date, statement_amount: statement.statement_amount.round(2).to_f } }
    end

    private

    def set_account
      @account = Account.find(params[:account_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "账户不存在" }, status: :not_found
    end
  end
end
