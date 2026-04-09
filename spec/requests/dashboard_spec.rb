# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  before { login }

  describe "GET /dashboard" do
    it "returns HTTP success" do
      get "/dashboard"
      expect(response).to have_http_status(:success)
    end

    it "renders the dashboard template" do
      get "/dashboard"
      expect(response.body).to include("总资产") # 视图中应该有资产信息
    end

    context "with month parameter" do
      it "accepts a month filter" do
        get "/dashboard", params: { month: "2024-01" }
        expect(response).to have_http_status(:success)
      end
    end
  end
end
