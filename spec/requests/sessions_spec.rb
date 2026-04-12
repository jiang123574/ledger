# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /login" do
    it "returns success" do
      get login_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /login" do
    context "with valid credentials" do
      it "redirects to root path" do
        post login_path, params: { username: "admin", password: "testpass" }
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("登录成功")
      end

      it "sets session as authenticated" do
        post login_path, params: { username: "admin", password: "testpass" }
        expect(session[:authenticated]).to be true
      end
    end

    context "with invalid credentials" do
      it "renders login page with error" do
        post login_path, params: { username: "wrong", password: "wrong" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(flash[:alert]).to eq("用户名或密码错误")
      end
    end

    context "with missing credentials" do
      it "renders login page with error" do
        post login_path, params: { username: "", password: "" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /logout" do
    before { login }

    it "redirects to login path" do
      delete logout_path
      expect(response).to redirect_to(login_path)
      expect(flash[:notice]).to eq("已退出登录")
    end

    it "clears authentication session" do
      delete logout_path
      expect(session[:authenticated]).to be_nil
    end
  end
end
