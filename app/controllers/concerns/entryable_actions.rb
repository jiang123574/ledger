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
  def handle_successful_save(message, entry = nil)
    if params[:continue_entry] == "1"
      respond_to do |format|
        format.json do
          response_data = { success: true, message: "#{message}，请继续录入" }
          if entry
            response_data[:entry] = entry_to_render_data(entry)
          end
          render json: response_data
        end
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

  # 处理多条 entry 的成功保存（用于带资金来源转账场景）
  def handle_successful_save_with_entries(message, entries)
    if params[:continue_entry] == "1"
      respond_to do |format|
        format.json do
          response_data = { success: true, message: "#{message}，请继续录入" }
          if entries && entries.any?
            response_data[:entries] = entries.map { |e| entry_to_render_data(e) }
          end
          render json: response_data
        end
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

  # 将 Entry 转换为前端渲染所需的 JSON 数据
  def entry_to_render_data(entry)
    entry_type = entry.display_entry_type
    is_transfer = entry_type == "TRANSFER"
    is_inflow = is_transfer && entry.amount.positive?
    flow_type = entry.display_flow_type

    display_type = if is_transfer
      is_inflow ? "转入" : "转出"
    else
      entry.display_type_label
    end

    display_amount_type = if is_transfer
      is_inflow ? "INCOME" : "EXPENSE"
    else
      flow_type
    end

    account_name = entry.account&.name || "未知账户"

    # 对于转账记录，使用正确的对方账户方法
    transfer_from = nil
    transfer_to = nil
    if is_transfer
      source_account = entry.source_account_for_transfer
      target_account = entry.target_account_for_display
      transfer_from = source_account&.name
      transfer_to = target_account&.name
    end

    {
      id: entry.id,
      date: entry.date&.to_s,
      display_name: entry.name || entry.notes || "-",
      display_type: display_type,
      display_amount_type: display_amount_type,
      display_amount: entry.display_amount,
      account_name: account_name,
      transfer_from: transfer_from,
      transfer_to: transfer_to,
      show_both_amounts: false,
      balance_after: nil  # 余额需要刷新页面才能正确显示
    }
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
