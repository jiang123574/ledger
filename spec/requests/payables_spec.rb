# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payables", type: :request do
  before { http_login }

  describe "GET /payables" do
    let(:account) { create(:account) }
    let(:counterparty_a) { create(:counterparty, name: "供应商A") }
    let(:counterparty_b) { create(:counterparty, name: "供应商B") }

    it "filters unsettled payables by counterparty id token" do
      Payable.create!(
        description: "A-待付款",
        original_amount: 100,
        remaining_amount: 100,
        date: Date.current,
        account: account,
        counterparty: counterparty_a
      )
      Payable.create!(
        description: "B-待付款",
        original_amount: 200,
        remaining_amount: 200,
        date: Date.current,
        account: account,
        counterparty: counterparty_b
      )

      get "/payables", params: { counterparty_id: "id:#{counterparty_a.id}" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A-待付款")
      expect(response.body).not_to include("B-待付款")
    end

    it "filters unsettled payables with none token" do
      Payable.create!(
        description: "无联系人-待付款",
        original_amount: 80,
        remaining_amount: 80,
        date: Date.current,
        account: account,
        counterparty: nil
      )
      Payable.create!(
        description: "有联系人-待付款",
        original_amount: 120,
        remaining_amount: 120,
        date: Date.current,
        account: account,
        counterparty: counterparty_a
      )

      get "/payables", params: { counterparty_id: "none" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("无联系人-待付款")
      expect(response.body).not_to include("有联系人-待付款")
    end
  end
end
