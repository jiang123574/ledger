# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PWA", type: :request do
  # public/manifest.json 是 manifest 的唯一来源，/manifest.json 由静态文件直接提供
  # （ActionDispatch::Static 优先于路由）；原来的 /manifest（无扩展名）路由已删除
  let(:manifest_source) { Rails.root.join("public/manifest.json") }
  let(:manifest) { JSON.parse(manifest_source.read) }

  describe "GET /manifest.json" do
    it "返回 public/manifest.json 的内容" do
      get "/manifest.json"

      expect(response).to have_http_status(:ok)
      expect(response.body.b).to eq(manifest_source.binread)
    end
  end

  describe "public/manifest.json 内容" do
    it "是合法的 PWA manifest" do
      expect(manifest["name"]).to eq("我的账本")
      expect(manifest["short_name"]).to eq("账本")
      expect(manifest["start_url"]).to eq("/dashboard")
      expect(manifest["display"]).to eq("standalone")
      expect(manifest["theme_color"]).to eq("#1a1a1a")
      expect(manifest["background_color"]).to eq("#1a1a1a")
    end

    it "包含图标" do
      expect(manifest["icons"]).to be_an(Array)
      expect(manifest["icons"].length).to eq(2)
      expect(manifest["icons"].map { |icon| icon["src"] }).to include("/icon.png", "/icon.svg")
    end

    it "快捷方式 URL 都能路由到已存在的页面" do
      urls = manifest["shortcuts"].map { |shortcut| shortcut["url"] }
      expect(urls).to all(be_present)

      urls.each do |url|
        path = url.split("?").first
        # 失败时 RoutingError 会带出具体路径（No route matches [/xxx]）
        expect { Rails.application.routes.recognize_path(path, method: :get) }.not_to raise_error
      end
    end
  end
end
