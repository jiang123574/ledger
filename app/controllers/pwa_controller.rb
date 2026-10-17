# frozen_string_literal: true

# PWA manifest。
# 内容唯一来源是 public/manifest.json：/manifest.json 由静态文件直接提供（ActionDispatch::Static
# 优先于路由），这里只服务不带扩展名的 /manifest，避免在控制器里再维护一份内容导致两边漂移。
class PwaController < ApplicationController
  skip_before_action :verify_authenticity_token

  MANIFEST_PATH = Rails.root.join("public/manifest.json")

  def manifest
    send_file MANIFEST_PATH, type: "application/manifest+json", disposition: "inline"
  end
end
