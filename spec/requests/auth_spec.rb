# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session-based Auth", type: :request do
  before do
    ENV["AUTH_USER"] = "admin"
    ENV["AUTH_PASSWORD"] = "testpass"
  end

  context "when credentials are correct" do
    before { login("admin", "testpass") }

    it "allows access to protected pages" do
      get "/accounts"
      expect(response).to have_http_status(:success)
    end

    it "allows access to dashboard" do
      get "/dashboard"
      expect(response).to have_http_status(:success)
    end
  end

  context "when credentials are missing" do
    it "redirects to login page" do
      get "/accounts"
      expect(response).to redirect_to(login_path)
    end
  end

  context "when credentials are wrong" do
    before { login("admin", "wrongpassword") }

    it "shows error and stays on login page" do
      get "/accounts"
      expect(response).to redirect_to(login_path)
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

  context "login page" do
    it "is accessible without auth" do
      get login_path
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
      expect(response).to have_http_status(:success)
    end
  end

  context "logout" do
    before { login("admin", "testpass") }

    it "clears session and redirects to login" do
      delete logout_path
      expect(response).to redirect_to(login_path)

      get "/accounts"
      expect(response).to redirect_to(login_path)
    end
  end
end
