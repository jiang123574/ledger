class ImportsController < ApplicationController
  def new
    @templates = ImportService.templates
    @supported_formats = ImportService::SUPPORTED_FORMATS
  end

  def preview
    if params[:file].blank?
      render json: { error: "请选择文件" }, status: :bad_request
      return
    end

    validation = ImportService.validate_file(params[:file])
    unless validation[:valid]
      render json: { error: validation[:errors].join(", ") }, status: :bad_request
      return
    end

    begin
      @preview_data = ImportService.preview(params[:file], field_mapping_params)
      @field_mapping = field_mapping_params

      respond_to do |format|
        format.html
        format.json { render json: @preview_data }
      end
    rescue => e
      render json: { error: "预览失败: #{e.message}" }, status: :unprocessable_entity
    end
  end

  def create
    if params[:file].blank?
      redirect_to new_import_path, alert: "请选择要导入的文件"
      return
    end

    validation = ImportService.validate_file(params[:file])
    unless validation[:valid]
      redirect_to new_import_path, alert: validation[:errors].join(", ")
      return
    end

    begin
      @results = ImportService.import(params[:file], field_mapping_params.merge(account_name: params[:account_name]))

      if @results[:failed] > 0
        flash[:warning] = "导入完成: 成功 #{@results[:success]} 条, 失败 #{@results[:failed]} 条"
        flash[:import_errors] = @results[:errors].first(10) if @results[:errors].any?
      else
        flash[:notice] = "成功导入 #{@results[:success]} 条交易记录"
      end

      redirect_to transactions_path
    rescue ImportService::ImportError => e
      redirect_to new_import_path, alert: "导入失败: #{e.message}"
    rescue => e
      redirect_to new_import_path, alert: "导入失败: #{e.message}"
    end
  end

  def templates
    render json: ImportService.templates
  end

  private

  def field_mapping_params
    params[:field_mapping]&.permit!&.to_h || {}
  end
end
