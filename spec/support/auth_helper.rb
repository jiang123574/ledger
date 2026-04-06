# frozen_string_literal: true

# 测试辅助：HTTP Basic Auth 支持
# 在 request specs 中使用 `http_login` helper 通过认证
module AuthHelper
  def http_login(user = "admin", password = "testpass")
    @default_auth_headers = {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(user, password)
    }
  end

  private

  def get(path, **args)
    super(path, **merge_auth_headers(args))
  end

  def post(path, **args)
    super(path, **merge_auth_headers(args))
  end

  def put(path, **args)
    super(path, **merge_auth_headers(args))
  end

  def patch(path, **args)
    super(path, **merge_auth_headers(args))
  end

  def delete(path, **args)
    super(path, **merge_auth_headers(args))
  end

  def merge_auth_headers(args)
    headers = (args[:headers] || {}).merge(@default_auth_headers || {})
    args.merge(headers: headers)
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request

  # 全局：测试环境默认设置 AUTH 环境变量（让 ApplicationController 的 auth_required? 返回 true）
  config.before(:suite) do
    ENV["AUTH_USER"] = "admin"
    ENV["AUTH_PASSWORD"] = "testpass"
  end
end
