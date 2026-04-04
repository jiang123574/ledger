# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HTTP Basic Auth", type: :request do
  before do
    # 确保测试环境 AUTH 变量已设置
    ENV["AUTH_USER"] = "admin"
    ENV["AUTH_PASSWORD"] = "testpass"
  end

  context "when credentials are correct" do
    before { http_login("admin", "testpass") }

    it "allows access to protected pages" do
      get "/accounts"
      expect(response).to have_http_status(:success) # redirect to /accounts is root
    end

    it "allows access to dashboard" do
      get "/dashboard"
      expect(response).to have_http_status(:success)
    end
  end

  context "when credentials are missing" do
    it "returns 401 Unauthorized" do
      get "/accounts"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "when credentials are wrong" do
    before { http_login("admin", "wrongpassword") }

    it "returns 401 Unauthorized" do
      get "/accounts"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "health check endpoint" do
    it "is always accessible without auth" do
      get "/up"
      expect(response).to have_http_status(:success)
    end
  end

  context "PWA manifest" do
    it "is accessible without auth" do
      get "/manifest.json"
      expect(response).to have_http_status(:success)
    end
  end

  context "when AUTH env vars are not set" do
    before do
      ENV.delete("AUTH_USER")
      ENV.delete("AUTH_PASSWORD")
    end

    after do
      ENV["AUTH_USER"] = "admin"
      ENV["AUTH_PASSWORD"] = "testpass"
    end

    it "allows access without auth" do
      get "/accounts"
      # 不应该返回 401
      expect(response).not_to have_http_status(:unauthorized)
    end
  end
end
