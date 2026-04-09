# frozen_string_literal: true

# 测试辅助：Session-based Auth 支持
# 在 request specs 中使用 `login` helper 通过认证
module AuthHelper
  def login(user = "admin", password = "testpass")
    post login_path, params: { username: user, password: password }
  end

  def logout
    delete logout_path
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request

  # 全局：测试环境默认设置 AUTH 环境变量
  config.before(:suite) do
    ENV["AUTH_USER"] = "admin"
    ENV["AUTH_PASSWORD"] = "testpass"
  end
end
