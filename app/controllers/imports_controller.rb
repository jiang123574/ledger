class ImportsController < ApplicationController
  def new
    @templates = ImportService.templates
    @supported_formats = ImportService::SUPPORTED_FORMATS
  end

  def preview
    if params[:file].blank?
      render json: { error: t("import.errors.no_file", default: "请选择文件") }, status: :bad_request
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
      render json: { error: t("import.errors.preview_failed", default: "预览失败: %{message}", message: e.message) }, status: :unprocessable_entity
    end
  end

  def create
    if params[:file].blank?
      redirect_to new_import_path, alert: t("import.errors.no_file", default: "请选择要导入的文件")
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
        flash[:warning] = t("import.partial_success", success: @results[:success], failed: @results[:failed])
        flash[:import_errors] = @results[:errors].first(10) if @results[:errors].any?
      else
        flash[:notice] = t("import.success", count: @results[:success])
      end

      redirect_to transactions_path
    rescue ImportService::ImportError => e
      redirect_to new_import_path, alert: t("import.errors.import_failed", message: e.message)
    rescue => e
      redirect_to new_import_path, alert: t("import.errors.import_failed", message: e.message)
    end
  end

  def templates
    render json: ImportService.templates
  end

  private

  def field_mapping_params
    return {} unless params[:field_mapping].present?

    # Only permit known field names
    allowed_fields = %w[date type amount account category note tag]
    params[:field_mapping].select { |_, v| allowed_fields.include?(v) }
  end
end
