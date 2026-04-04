class ImportsController < ApplicationController
  def new
    @supported_formats = ImportService::SUPPORTED_FORMATS
    @templates = []
  end

  def pixiu
    @current_step = params[:step].to_i || 1

    case @current_step
    when 1
      # Upload step
    when 2
      unless session[:pixiu_file_path].present?
        redirect_to pixiu_imports_path(step: 1), alert: "请先上传文件"
        return
      end
      preview_data = PixiuImportService.preview(session[:pixiu_file_path])
      @stats = preview_data[:stats]
      @sample_data = preview_data[:sample_data]
    when 3
      unless session[:pixiu_file_path].present?
        redirect_to pixiu_imports_path(step: 1), alert: "请先上传文件"
        return
      end
      mappings = PixiuImportService.load_mappings(session[:pixiu_file_path])
      @accounts_map = mappings[:accounts_map]
      @categories_map = mappings[:categories_map]
    when 4
      @import_result = session[:import_result] || {}
    end
  end

  def pixiu_upload
    file = params[:file]

    unless file.present?
      redirect_to pixiu_imports_path(step: 1), alert: "请选择文件"
      return
    end

    unless file.content_type == 'text/csv' || file.original_filename.end_with?('.csv')
      redirect_to pixiu_imports_path(step: 1), alert: "请上传 CSV 文件"
      return
    end

    temp_path = Rails.root.join('tmp', "pixiu_#{Time.current.to_i}.csv")
    FileUtils.cp(file.tempfile.path, temp_path)

    session[:pixiu_file_path] = temp_path.to_s
    session[:pixiu_file_name] = file.original_filename

    redirect_to pixiu_imports_path(step: 2)
  end

  def pixiu_confirm
    file_path = session[:pixiu_file_path]

    unless file_path.present? && File.exist?(file_path)
      redirect_to pixiu_imports_path(step: 1), alert: "文件已过期，请重新上传"
      return
    end

    accounts_map = PixiuImportService.build_accounts_map(params[:accounts])
    categories_map = PixiuImportService.build_categories_map(params[:categories])

    result = PixiuImportService.import(file_path, accounts_map, categories_map)

    session[:import_result] = result
    session.delete(:pixiu_file_path)
    session.delete(:pixiu_file_name)

    File.delete(file_path) if File.exist?(file_path)
    Rails.cache.clear

    redirect_to pixiu_imports_path(step: 4)
  end
end
