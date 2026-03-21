class SettingsController < ApplicationController
  before_action :load_settings_data, only: [ :show ]

  def show
  end

  # Shortcuts actions
  def update_shortcuts
    shortcuts = params[:shortcuts] || {}
    save_custom_shortcuts(shortcuts)
    redirect_to settings_path(anchor: "shortcuts"), notice: "快捷键已更新"
  end

  def reset_shortcuts
    clear_custom_shortcuts
    redirect_to settings_path(anchor: "shortcuts"), notice: "已恢复默认快捷键"
  end

  # Counterparties actions (delegated to CounterpartiesController)
  def counterparties
    redirect_to counterparties_path
  end

  private

  ITEMS_PER_PAGE = 20

  def load_settings_data
    @currencies = Currency.order(:code)
    @backups = BackupService.list_backups.take(10)

    # Load shortcuts data
    @shortcuts = default_shortcuts
    @custom_shortcuts = load_custom_shortcuts

    # Load counterparties data with pagination
    page = params[:page].to_i.zero? ? 1 : params[:page].to_i
    @total_counterparties = Counterparty.count
    @total_receivables = Receivable.where.not(counterparty: [ nil, "" ]).count
    
    # Get all counterparties sorted by receivables count, then by name
    all_counterparties = Counterparty.all.order(:name).map do |cp|
      cp.define_singleton_method(:receivables_count) { Receivable.where(counterparty: cp.name).count }
      cp
    end.sort_by { |cp| [ -cp.receivables_count, cp.name ] }
    
    @counterparties = Kaminari.paginate_array(all_counterparties).page(page).per(ITEMS_PER_PAGE)
    @total_pages = (@total_counterparties.to_f / ITEMS_PER_PAGE).ceil
  end

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
  rescue
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

  def export_transactions
    csv_data = ExportService.transactions_to_csv
    file_name = ExportService.export_file_name

    send_data csv_data,
              filename: file_name,
              type: "text/csv",
              disposition: "attachment"
  end

  def import_transactions
    if params[:file].blank?
      redirect_to settings_path, alert: "请选择要导入的文件"
      return
    end

    file = params[:file]
    unless file.content_type == "text/csv" || file.content_type.include?("excel")
      redirect_to settings_path, alert: "请上传 CSV 格式的文件"
      return
    end

    results = ImportService.import_transactions_csv(file)

    if results[:failed] > 0
      flash[:warning] = "导入完成: 成功 #{results[:success]} 条, 失败 #{results[:failed]} 条"
      flash[:import_errors] = results[:errors] if results[:errors].any?
    else
      flash[:notice] = "成功导入 #{results[:success]} 条交易记录"
    end

    redirect_to settings_path
  end

  def validate_import
    if params[:file].blank?
      render json: { valid: false, errors: [ "请选择文件" ] }
      return
    end

    errors = ImportService.validate_csv(params[:file])

    render json: {
      valid: errors.empty?,
      errors: errors,
      total_rows: CSV.read(params[:file].path).length - 1
    }
  rescue => e
    render json: { valid: false, errors: [ e.message ] }
  end

  def create_backup
    result = BackupService.create_backup

    if result[:success]
      BackupService.cleanup_old_backups
      redirect_to settings_path, notice: "备份已创建: #{result[:file_name]}"
    else
      redirect_to settings_path, alert: result[:error]
    end
  end

  def download_backup
    backup_name = params[:name]
    backup_path = Rails.root.join("tmp", "backups", backup_name)

    unless File.exist?(backup_path)
      redirect_to settings_path, alert: "备份文件不存在"
      return
    end

    send_file backup_path,
              filename: backup_name,
              type: "application/sql"
  end

  def clear_all_data
    ActiveRecord::Base.transaction do
      Attachment.destroy_all
      ImportBatch.destroy_all
      RecurringTransaction.destroy_all
      Plan.destroy_all
      Budget.destroy_all
      Transaction.destroy_all
      Category.destroy_all
      Account.destroy_all
    end

    redirect_to settings_path, notice: "所有数据已清除"
  rescue => e
    redirect_to settings_path, alert: "清除失败: #{e.message}"
  end

  private

  def load_currencies
    @currencies = Currency.order(:code)
  end
end
