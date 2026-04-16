class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # ============ 安全头 ============
  before_action :set_security_headers

  # ============ Session-based Auth 全站保护 ============
  # 个人记账工具部署在公网，必须有访问控制
  # 通过 AUTH_USER / AUTH_PASSWORD 环境变量配置
  # 未配置时跳过认证（开发环境或无需认证场景）
  #
  # 放开的端点：
  # - /up（健康检查）
  # - /manifest / /manifest.json（PWA）
  # - /api/external/*（使用独立 API Key 认证）
  # - /login（登录页面）
  before_action :require_login

  private

  def set_security_headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["X-XSS-Protection"] = "0"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=(), payment=(), usb=(), serial=(), bluetooth=()"
    response.headers["Content-Security-Policy"] = "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net"
  end

  def require_login
    return unless auth_configured?
    return if skip_auth_for_path?
    return if logged_in?

    store_location
    redirect_to login_path, alert: "请先登录"
  end

  def auth_configured?
    ENV["AUTH_USER"].present? && ENV["AUTH_PASSWORD"].present?
  end

  def logged_in?
    session[:authenticated] == true
  end
  helper_method :logged_in?

  def store_location
    session[:return_to] = request.fullpath if request.get? && !request.xhr?
  end

  def skip_auth_for_path?
    request.path == "/up" ||
      request.path.start_with?("/manifest") ||
      request.path.start_with?("/api/external/") ||
      request.path == login_path
  end
end
