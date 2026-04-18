# TurboNativeHelper - Turbo Native App 检测与适配
#
# Turbo Native 是 Hotwire 官方的原生客户端框架，
# 允许将 Rails Web 应用封装为 iOS/Android 原生应用。
# 原生壳使用 WebView 渲染页面，同时提供原生导航、手势、系统功能。
#
# 用法：
#   turbo_native_app?   # 在 controller/view 中判断是否为原生客户端
#   turbo_native_config # 获取原生客户端配置 meta 标签
module TurboNativeHelper
  # 检测当前请求是否来自 Turbo Native 原生客户端
  # Turbo Native SDK 会在 User-Agent 中包含 "Turbo Native" 标识
  def turbo_native_app?
    request.user_agent.to_s.include?("Turbo Native")
  end

  # 为 Turbo Native 客户端生成配置 meta 标签
  # 控制原生导航栏的行为（标题、按钮、动作）
  #
  # 参数：
  #   title:    页面标题（显示在原生导航栏）
  #   button:   右上角按钮类型 :none / :add / :done / :custom
  #   path:     按钮点击后的目标路径
  def turbo_native_config(title: nil, button: :none, path: nil)
    return unless turbo_native_app?

    tags = []
    tags << tag.meta(name: "turbo-native-title", content: title) if title

    case button
    when :add
      tags << tag.meta(name: "turbo-native-button", content: "add")
      tags << tag.meta(name: "turbo-native-button-path", content: path) if path
    when :done
      tags << tag.meta(name: "turbo-native-button", content: "done")
      tags << tag.meta(name: "turbo-native-button-path", content: path) if path
    end

    safe_join(tags, "\n")
  end

  # 隐藏仅对 Web 有意义的元素（Turbo Native 中不需要的）
  # 用法：<% unless turbo_native_app? %> ... <% end %>
  def turbo_native_excluded_class
    turbo_native_app? ? "hidden" : ""
  end
end
