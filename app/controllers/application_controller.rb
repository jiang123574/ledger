class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # ============ HTTP Basic Auth 全站保护 ============
  # 个人记账工具部署在公网，必须有访问控制
  # 通过 AUTH_USER / AUTH_PASSWORD 环境变量配置
  # 未配置时仅在 Rails.env.production? 启用（开发环境不拦截）
  #
  # 放开的端点：
  # - /up（健康检查）
  # - /manifest / /manifest.json（PWA）
  # - /api/external/*（使用独立 API Key 认证）
  http_basic_authenticate_with name: -> { ENV["AUTH_USER"] },
                                password: -> { ENV["AUTH_PASSWORD"] },
                                if: -> { auth_required? }

  private

  # 是否需要 Basic Auth 认证
  def auth_required?
    return false if ENV["AUTH_USER"].blank? || ENV["AUTH_PASSWORD"].blank?
    return false if skip_auth_for_path?
    true
  end

  # 跳过认证的路径（健康检查、PWA manifest、外部 API）
  def skip_auth_for_path?
    request.path == "/up" ||
      request.path.start_with?("/manifest") ||
      request.path.start_with?("/api/external/")
  end
end
