# frozen_string_literal: true

# Rack::MiniProfiler 配置
# 仅在开发环境启用，提供请求级性能分析
if Rails.env.development?
  require "rack-mini-profiler"

  # 初始化 MiniProfiler
  Rack::MiniProfiler.config.tap do |config|
    # 在页面右下角显示性能分析面板
    config.start_hidden = false

    # 启用内存快照（需要 stackprof gem）
    config.enable_advanced_debugging_tools = true

    # 排除静态资源请求
    config.skip_paths ||= %w[/.well-known /assets /favicon.ico /manifest.json]

    # 最大请求数保留
    config.max_traces_to_save = 50

    # 显示 SQL 查询详情
    config.disable_caching = true
  end

  Rack::MiniProfilerRails.initialize!(Rails.application)
end

# 慢查询日志
# 记录执行时间超过阈值的 SQL 查询
ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|
  duration = (finish - start) * 1000.0 # 转换为毫秒

  # 开发环境：> 100ms 的查询
  # 生产环境：> 500ms 的查询
  threshold = Rails.env.development? ? 100 : 500

  if duration > threshold
    sql = payload[:sql].to_s
    Rails.logger.warn("[SLOW QUERY] #{duration.round(1)}ms: #{sql}")
  end
end
