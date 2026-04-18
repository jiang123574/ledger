# frozen_string_literal: true

# Session 配置
# 确保在 HTTP（非 HTTPS）开发环境中 cookie 正常工作
Rails.application.config.action_dispatch.cookies_same_site_protection = :lax

# Cookie session 使用默认配置
# 在开发环境中，Secure 标志为 false（允许 HTTP）
