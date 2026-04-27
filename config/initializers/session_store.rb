# frozen_string_literal: true

# Session 配置
# 确保在 HTTP（非 HTTPS）开发环境中 cookie 正常工作
Rails.application.config.action_dispatch.cookies_same_site_protection = :lax

# 内网部署（无 SSL）时，禁用 cookie secure 标志
if ENV["NO_SSL"] == "true"
  Rails.application.config.action_dispatch.cookies_serializer = :json
  Rails.application.config.action_dispatch.cookies_digest = nil
  Rails.application.config.action_dispatch.use_cookies_with_metadata = false
end
