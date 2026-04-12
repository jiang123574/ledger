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
end
