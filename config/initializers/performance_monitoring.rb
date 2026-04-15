# frozen_string_literal: true

# Rack::MiniProfiler 配置
# 仅在开发环境启用，提供请求级性能分析
if Rails.env.development?
  require "rack-mini-profiler"

  # 初始化 MiniProfiler
  Rack::MiniProfiler.config.tap do |config|
    # 在页面右下角显示性能分析面板
    config.start_hidden = false

    # 跳过路径配置由 rack-mini-profiler 默认处理（含 /assets）

    # 最大请求数保留
    config.max_traces_to_show = 50

    # 显示 SQL 查询详情（禁用缓存以获取完整信息，代价是每次请求都分析）
    config.disable_caching = true
  end

  Rack::MiniProfilerRails.initialize!(Rails.application)

  # 慢查询日志（仅开发环境）
  # 记录执行时间超过阈值的 SQL 查询
  ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|
    duration = (finish - start) * 1000.0 # 转换为毫秒

    if duration > 100
      sql = payload[:sql].to_s
      Rails.logger.warn("[SLOW QUERY] #{duration.round(1)}ms: #{sql}")
    end
  end
end
