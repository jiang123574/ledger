# frozen_string_literal: true

class PwaController < ApplicationController
  skip_before_action :verify_authenticity_token

  def manifest
    render json: {
      name: "我的账本",
      short_name: "账本",
      icons: [
        { src: "/icon.png", type: "image/png", sizes: "512x512" },
        { src: "/icon.svg", type: "image/svg+xml", sizes: "any" }
      ],
      start_url: "/",
      display: "standalone",
      orientation: "portrait-primary",
      scope: "/",
      description: "个人记账应用 - 管理您的财务",
      theme_color: "#1a1a1a",
      background_color: "#f8f9fa",
      categories: ["finance", "productivity"]
    }
  end
end