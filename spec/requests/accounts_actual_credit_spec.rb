# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Accounts actual credit", type: :request do
  before { login }

  describe "PATCH /accounts/:id/update_actual_credit" do
    let(:account) { create(:account, :credit_card, credit_limit: 20_000) }

    it "saves the value and refreshes the accounts list cache" do
      version_before = CacheBuster.version(:accounts)

      patch "/accounts/#{account.id}/update_actual_credit",
        params: { actual_available_credit: "18833.98" },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["actual_available_credit"]).to eq("18833.98")
      expect(account.reload.actual_available_credit).to eq(18833.98)
      # accounts_list 缓存以该版本号为 key，不 bump 会导致刷新后回显旧值
      expect(CacheBuster.version(:accounts)).to be > version_before
    end

    it "clears the value when blank" do
      account.update_column(:actual_available_credit, 18833.98)
      version_before = CacheBuster.version(:accounts)

      patch "/accounts/#{account.id}/update_actual_credit",
        params: { actual_available_credit: "" },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(account.reload.actual_available_credit).to be_nil
      expect(CacheBuster.version(:accounts)).to be > version_before
    end
  end
end
