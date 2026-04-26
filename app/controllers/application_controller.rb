class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Turbo Native Android WebView 的 Chrome 版本可能低于要求，跳过检查
  allow_browser versions: :modern, if: -> { !turbo_native_app? }

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # ============ 安全头 ============
  before_action :set_csp_nonce
  before_action :set_security_headers

  # ============ Session-based Auth 全站保护 ============
  # 个人记账工具部署在公网，必须有访问控制
  # 通过 AUTH_USER / AUTH_PASSWORD 环境变量配置
  # 未配置时跳过认证（开发环境或无需认证场景）
  #
  # 放开的端点：
  # - /up（健康检查）
  # - /manifest / /manifest.json（PWA）
  # - /api/v1/external/*（使用独立 API Key 认证）
  # - /login（登录页面）
  before_action :require_login

  private

  def turbo_native_app?
    request.user_agent.to_s.include?("Turbo Native")
  end
  helper_method :turbo_native_app?

  # CSP nonce 生成
  def set_csp_nonce
    @csp_nonce = SecureRandom.base64(16)
  end

  # 提供给视图使用的 nonce
  def csp_nonce
    @csp_nonce
  end
  helper_method :csp_nonce

  def set_security_headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    # Turbo Native Android WebView 需要在 iframe 中加载，不能限制同源
    response.headers["X-Frame-Options"] = "SAMEORIGIN" unless turbo_native_app?
    response.headers["X-XSS-Protection"] = "0"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=(), payment=(), usb=(), serial=(), bluetooth=()"
    # Turbo Native 不设置 CSP，避免 importmap/inline script 被阻止
    unless turbo_native_app?
      response.headers["Content-Security-Policy"] =
        "default-src 'self'; " +
        "style-src 'self' 'unsafe-inline'; " +
        "script-src 'self' 'nonce-#{@csp_nonce}'; " +
        "img-src 'self' data: blob:; " +
        "font-src 'self'; " +
        "connect-src 'self'; " +
        "frame-ancestors 'self'"
    end
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
      request.path.start_with?("/api/v1/external/") ||
      request.path == login_path
  end
end
