# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PWA", type: :request do
  describe "GET /manifest" do
    it "returns PWA manifest as JSON" do
      get pwa_manifest_path
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("我的账本")
      expect(json["short_name"]).to eq("账本")
      expect(json["start_url"]).to eq("/")
      expect(json["display"]).to eq("standalone")
    end

    it "includes icons" do
      get pwa_manifest_path
      json = JSON.parse(response.body)
      expect(json["icons"]).to be_an(Array)
      expect(json["icons"].length).to eq(2)
    end

    it "includes theme and background colors" do
      get pwa_manifest_path
      json = JSON.parse(response.body)
      expect(json["theme_color"]).to eq("#1a1a1a")
      expect(json["background_color"]).to eq("#f8f9fa")
    end

    it "includes categories" do
      get pwa_manifest_path
      json = JSON.parse(response.body)
      expect(json["categories"]).to include("finance")
    end
  end

  describe "GET /manifest.json" do
    it "returns manifest via .json path" do
      get "/manifest.json"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("我的账本")
    end
  end

  # public/manifest.json 是浏览器实际拿到的 manifest（/manifest.json 由静态文件提供）
  describe "public/manifest.json" do
    let(:manifest) { JSON.parse(Rails.root.join("public/manifest.json").read) }

    it "快捷方式 URL 都能路由到已存在的页面" do
      urls = manifest["shortcuts"].map { |shortcut| shortcut["url"] }
      expect(urls).to all(be_present)

      urls.each do |url|
        path = url.split("?").first
        expect { Rails.application.routes.recognize_path(path, method: :get) }
          .not_to raise_error("#{url} 没有对应路由")
      end
    end
  end
end
