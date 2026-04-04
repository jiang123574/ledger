# 记录慢请求到 Rails 日志
# 开发环境默认 500ms，生产环境默认 200ms
# 通过 SLOW_REQUEST_THRESHOLD_MS 环境变量可调整阈值
class SlowRequestLogger
  def initialize(app)
    @app = app
  end

  def call(env)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, response = @app.call(env)
    elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)

    if elapsed >= threshold
      path = env["PATH_INFO"]
      method = env["REQUEST_METHOD"]
      Rails.logger.warn "[PERF] Slow request: #{method} #{path} — #{elapsed}ms (#{status})"
    end

    [status, headers, response]
  end

  private

  def threshold
    @threshold ||= begin
      env_val = ENV["SLOW_REQUEST_THRESHOLD_MS"]
      env_val ? env_val.to_i : (Rails.env.production? ? 200 : 500)
    end
  end
end
