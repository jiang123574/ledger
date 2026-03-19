class SettingsController < ApplicationController
  before_action :load_currencies, only: [:show]

  def show
    @currencies = Currency.order(:code)
    @backups = BackupService.list_backups.take(10)
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
      render json: { valid: false, errors: ["请选择文件"] }
      return
    end

    errors = ImportService.validate_csv(params[:file])

    render json: {
      valid: errors.empty?,
      errors: errors,
      total_rows: CSV.read(params[:file].path).length - 1
    }
  rescue => e
    render json: { valid: false, errors: [e.message] }
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
