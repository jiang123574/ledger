class ShortcutsController < ApplicationController
  def index
    @shortcuts = default_shortcuts
    @custom_shortcuts = load_custom_shortcuts
  end

  def update
    shortcuts = params[:shortcuts] || {}
    save_custom_shortcuts(shortcuts)
    redirect_to shortcuts_path, notice: "快捷键已更新"
  end

  def reset
    clear_custom_shortcuts
    redirect_to shortcuts_path, notice: "已恢复默认快捷键"
  end

  private

  def default_shortcuts
    [
      { key: "n", description: "新建交易", action: "new_transaction", group: "交易" },
      { key: "s", description: "搜索", action: "search", group: "交易" },
      { key: "e", description: "导出", action: "export", group: "交易" },
      { key: "/", description: "快速搜索", action: "quick_search", group: "导航" },
      { key: "g t", description: "跳转到交易", action: "goto_transactions", group: "导航" },
      { key: "g a", description: "跳转到账户", action: "goto_accounts", group: "导航" },
      { key: "g r", description: "跳转到报表", action: "goto_reports", group: "导航" },
      { key: "g b", description: "跳转到预算", action: "goto_budgets", group: "导航" },
      { key: "g s", description: "跳转到设置", action: "goto_settings", group: "导航" },
      { key: "?", description: "显示快捷键帮助", action: "show_help", group: "帮助" },
      { key: "Escape", description: "关闭弹窗/取消", action: "escape", group: "通用" }
    ]
  end

  def load_custom_shortcuts
    file = Rails.root.join("tmp", "shortcuts.json")
    return {} unless File.exist?(file)
    JSON.parse(File.read(file))
  rescue JSON::ParserError
    {}
  end

  def save_custom_shortcuts(shortcuts)
    file = Rails.root.join("tmp", "shortcuts.json")
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, shortcuts.to_json)
  end

  def clear_custom_shortcuts
    file = Rails.root.join("tmp", "shortcuts.json")
    File.delete(file) if File.exist?(file)
  end
end
