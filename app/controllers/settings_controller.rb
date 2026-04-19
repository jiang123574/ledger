class SettingsController < ApplicationController
  def show
    @currencies = Currency.order(:code)
    @backups = BackupService.list_backups.take(10)
    @shortcuts = default_shortcuts
    @section = params[:section] || "general"

    # 按需加载数据，避免不必要的查询
    if @section == "categories"
      # 这里只需要预加载 children，parent 关联并未在分类设置页面中直接使用。
      # 这样可以避免无效的 includes(:parent) 导致 N+1 检测告警。
      @categories = Category.includes(:children).order(:sort_order, :name)
      @expense_roots = @categories.select(&:expense?).select(&:root?)
      @income_roots = @categories.select(&:income?).select(&:root?)
      @expense_parent_options = @expense_roots.map { |c| [ c.name, c.id ] }
      @income_parent_options = @income_roots.map { |c| [ c.name, c.id ] }
    end

    if @section == "contacts"
      @counterparties = Counterparty.all.order(:name)
      ids = @counterparties.map(&:id)
      names = @counterparties.map(&:name)

      receivable_counts_by_id = Receivable.where(counterparty_id: ids).group(:counterparty_id).count
      receivable_counts_by_name = Receivable.where(counterparty: names).group(:counterparty).count

      payable_counts_by_id = Payable.where(counterparty_id: ids).group(:counterparty_id).count

      @receivable_counts = {}
      @payable_counts = {}
      @total_link_counts = {}

      @counterparties.each do |counterparty|
        receivable_count = receivable_counts_by_id[counterparty.id].to_i + receivable_counts_by_name[counterparty.name].to_i
        payable_count = payable_counts_by_id[counterparty.id].to_i

        @receivable_counts[counterparty.id] = receivable_count
        @payable_counts[counterparty.id] = payable_count
        @total_link_counts[counterparty.id] = receivable_count + payable_count
      end
    end
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
  rescue StandardError => e
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
    backup_name = File.basename(params[:name].to_s)

    # 确保 .sql 后缀存在（Rails 路由可能把 .sql 当作 format 解析）
    backup_name = "#{backup_name}.sql" unless backup_name.end_with?(".sql")

    backup_path = BackupService::BACKUP_DIR.join(backup_name)

    unless File.exist?(backup_path)
      redirect_to settings_path, alert: "备份文件不存在"
      return
    end

    send_file backup_path,
              filename: backup_name,
              type: "application/sql"
  end

  def restore_upload
    if params[:backup_file].blank?
      redirect_to settings_path, alert: "请选择要恢复的备份文件"
      return
    end

    # 二次确认：需要输入 AUTH_PASSWORD
    unless confirm_with_password(params[:confirm_password])
      redirect_to settings_path, alert: "确认密码错误，操作已取消"
      return
    end

    # 保存上传的文件到临时位置
    uploaded_file = params[:backup_file]
    temp_path = BackupService::BACKUP_DIR.join("restore_#{Time.now.strftime('%Y%m%d_%H%M%S')}.sql")

    # 确保目录存在
    FileUtils.mkdir_p(File.dirname(temp_path))

    # 复制上传的文件到临时文件，兼容各种上传实现
    if uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile
      IO.copy_stream(uploaded_file.tempfile, temp_path)
    else
      IO.copy_stream(uploaded_file.path, temp_path)
    end

    # 执行恢复
    result = BackupService.restore_backup(temp_path)

    # 清理临时文件
    FileUtils.rm_f(temp_path)

    if result[:success]
      redirect_to settings_path, notice: "数据已从备份文件恢复"
    else
      redirect_to settings_path, alert: "恢复失败: #{result[:error]}"
    end
  rescue StandardError => e
    FileUtils.rm_f(temp_path) if temp_path
    redirect_to settings_path, alert: "恢复失败: #{e.message}"
  end

  def clear_all_data
    unless confirm_with_password(params[:confirm_password])
      redirect_to settings_path, alert: "确认密码错误，操作已取消"
      return
    end

    connection = ActiveRecord::Base.connection
    old_timeout = connection.execute("SHOW statement_timeout").first["statement_timeout"]
    connection.execute("SET statement_timeout = '300000'")

    begin
      Attachment.delete_all
      ImportBatch.delete_all
      RecurringTransaction.delete_all
      Plan.delete_all
      BillStatement.delete_all
      BudgetItem.delete_all
      SingleBudget.delete_all
      Budget.delete_all
      OneTimeBudget.delete_all
      Payable.delete_all
      Receivable.delete_all
      Counterparty.delete_all
      ActivityLog.delete_all
      Tagging.delete_all
      Tag.delete_all

      Entryable::Transaction.delete_all
      Entryable::Valuation.delete_all
      Entryable::Trade.delete_all
      Entry.delete_all

      Category.delete_all
      Account.delete_all

      Rails.cache.clear

      redirect_to settings_path, notice: "所有数据已清除"
    rescue StandardError => e
      redirect_to settings_path, alert: "清除失败: #{e.message}"
    ensure
      connection.execute("SET statement_timeout = '#{old_timeout}'")
    end
  end

  def reset_shortcuts
    clear_custom_shortcuts
    redirect_to settings_path, notice: "已恢复默认快捷键"
  end

  private

  def default_shortcuts
    [
      { key: "n", description: "新建交易", action: "new_transaction", group: "交易" },
      { key: "s", description: "搜索", action: "search", group: "交易" },
      { key: "/", description: "快速搜索", action: "quick_search", group: "导航" },
      { key: "g a", description: "跳转到账户", action: "goto_accounts", group: "导航" },
      { key: "g r", description: "跳转到报表", action: "goto_reports", group: "导航" },
      { key: "g b", description: "跳转到预算", action: "goto_budgets", group: "导航" },
      { key: "g s", description: "跳转到设置", action: "goto_settings", group: "导航" },
      { key: "?", description: "显示快捷键帮助", action: "show_help", group: "帮助" },
      { key: "Escape", description: "关闭弹窗/取消", action: "escape", group: "通用" }
    ]
  end

  def clear_custom_shortcuts
    file = Rails.root.join("tmp", "shortcuts.json")
    File.delete(file) if File.exist?(file)
  end

  # 敏感操作二次确认：验证 AUTH_PASSWORD
  def confirm_with_password(input_password)
    return false if input_password.blank?
    auth_password = ENV["AUTH_PASSWORD"]
    # 未设置 AUTH_PASSWORD 时，使用 "CONFIRM" 作为默认确认词
    expected = auth_password.presence || "CONFIRM"
    ActiveSupport::SecurityUtils.secure_compare(input_password, expected)
  end
end
