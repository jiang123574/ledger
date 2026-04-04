# 共享的 Entry 操作逻辑，用于 TransactionsController 和 EntriesController
module EntryableActions
  extend ActiveSupport::Concern

  private

  # 构建重定向 URL：优先使用当前请求的过滤参数，否则回退到 referer
  def build_redirect_url
    if params[:account_id].present? || params[:period_type].present? || params[:search].present?
      accounts_path(filter_params)
    else
      referer = request.referer
      return accounts_path if referer.blank?

      begin
        uri = URI.parse(referer)
        filter_params_from_referer = Rack::Utils.parse_nested_query(uri.query).symbolize_keys
        accounts_path(filter_params_from_referer.select { |k, v| v.present? })
      rescue URI::InvalidURIError
        accounts_path
      end
    end
  end

  # 处理成功保存后的重定向，支持继续录入模式
  def handle_successful_save(message)
    if params[:continue_entry] == "1"
      respond_to do |format|
        format.json { render json: { success: true, message: "#{message}，请继续录入" } }
        format.html { redirect_to(continue_entry_redirect_url, notice: "#{message}，请继续录入") }
        format.turbo_stream { redirect_to(continue_entry_redirect_url, notice: "#{message}，请继续录入") }
      end
      return
    end

    redirect_url = build_redirect_url
    respond_to do |format|
      format.html { redirect_to redirect_url, notice: message }
      format.turbo_stream { redirect_to redirect_url, notice: message }
      format.json { render json: { success: true, message: message } }
    end
  end

  # 处理保存失败的重定向，支持传入多个 record（如 @entry + @entry.entryable）
  def handle_save_error(*records)
    all_errors = records.flat_map { |r| r.respond_to?(:errors) && r.errors.any? ? r.errors.full_messages : [] }
    error_message = all_errors.any? ? all_errors.join(", ") : "操作失败，请重试"

    respond_to do |format|
      format.json { render json: { success: false, error: error_message } }
      format.html { redirect_to accounts_path(filter_params), alert: error_message }
    end
  end

  # 已知错误消息的场景（如"账户不存在"）
  def handle_save_error_with_message(message)
    respond_to do |format|
      format.json { render json: { success: false, error: message } }
      format.html { redirect_to accounts_path(filter_params), alert: message }
    end
  end

  # 继续录入模式的重定向 URL（在 referer 基础上追加参数）
  def continue_entry_redirect_url(continue_param: "open_new_transaction")
    fallback = accounts_path("#{continue_param}": 1)
    referer = request.referer
    return fallback if referer.blank?

    uri = URI.parse(referer)
    params_hash = Rack::Utils.parse_nested_query(uri.query)
    params_hash[continue_param] = "1"
    uri.query = params_hash.to_query
    uri.to_s
  rescue URI::InvalidURIError
    fallback
  end

  # 统一的缓存过期逻辑
  def expire_entries_cache
    CacheBuster.bump(:entries)
    CacheBuster.bump(:accounts)
  end
end
