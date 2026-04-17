# frozen_string_literal: true

# Turbo Native 配置暂时不需要额外初始化
# 主要修改在 ApplicationController 中：
# 1. allow_browser 跳过 Turbo Native 检查
# 2. CSP 头对 Turbo Native 放宽
# 3. X-Frame-Options 对 Turbo Native 不限制
