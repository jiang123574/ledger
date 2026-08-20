# frozen_string_literal: true

class VersionsController < ApplicationController
  before_action :set_operation_log, only: [ :show ]

  ITEM_TYPE_LABELS = {
    "Entry" => "交易",
    "Receivable" => "应收款",
    "Payable" => "应付款",
    "Plan" => "计划",
    "RecurringTransaction" => "周期交易",
    "Budget" => "预算",
    "SingleBudget" => "单次预算",
    "Account" => "账户",
    "Category" => "分类",
    "Tag" => "标签",
    "Counterparty" => "交易对手"
  }.freeze

  ACTION_LABELS = {
    "create" => "创建",
    "update" => "更新",
    "destroy" => "删除",
    "settle" => "结算",
    "revert" => "撤销",
    "execute" => "执行",
    "import" => "导入",
    "export" => "导出",
    "backup" => "备份",
    "restore" => "恢复"
  }.freeze

  def index
    @operation_logs = OperationLog.order(created_at: :desc)

    # 按模型类型过滤
    if params[:item_type].present?
      @operation_logs = @operation_logs.where(item_type: params[:item_type])
    end

    # 按操作类型过滤
    if params[:action_type].present?
      @operation_logs = @operation_logs.where(action: params[:action_type])
    end

    # 按 IP 过滤
    if params[:ip_address].present?
      @operation_logs = @operation_logs.where(ip_address: params[:ip_address])
    end

    # 时间范围过滤（容错：非法日期参数忽略，不抛 500）
    date_from = safe_parse_date(params[:date_from])
    if date_from
      @operation_logs = @operation_logs.where("created_at >= ?", date_from.beginning_of_day)
    end

    date_to = safe_parse_date(params[:date_to])
    if date_to
      @operation_logs = @operation_logs.where("created_at <= ?", date_to.end_of_day)
    end

    # 搜索（转义 LIKE 通配符防止注入）
    if params[:search].present?
      search_term = params[:search].to_s.gsub(/[%_]/) { |char| "\\#{char}" }
      @operation_logs = @operation_logs.where("description LIKE ?", "%#{search_term}%")
    end

    # 统计数据（一次 group 查询，减少数据库压力）
    @stats = build_stats

    # 导出（全量，顺序与页面一致：created_at desc）
    if params[:format] == "csv"
      send_data generate_csv(@operation_logs.reorder(created_at: :desc)), filename: "operation_logs_#{Date.today}.csv", type: "text/csv"
      return
    elsif params[:format] == "json"
      render json: generate_json(@operation_logs.reorder(created_at: :desc))
      return
    end

    # 分页 / 无限滚动
    @operation_logs = @operation_logs.page(params[:page]).per(50)

    # 标记当前筛选条件
    @active_filters = build_active_filters(date_from, date_to)

    # 快捷预设
    @quick_presets = build_quick_presets
  end

  def show
  end

  private

  def set_operation_log
    @operation_log = OperationLog.find(params[:id])
  end

  # 安全解析日期，非法值返回 nil 而非抛异常
  def safe_parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue Date::Error, ArgumentError
    nil
  end

  # 一次 group 查询，比多次 count 高效
  def build_stats
    today_logs = OperationLog.where("created_at >= ?", Time.current.beginning_of_day)
    counts = today_logs.group(:action).count
    {
      today: counts.values.sum,
      create: counts["create"] || 0,
      update: counts["update"] || 0,
      destroy: counts["destroy"] || 0
    }
  end

  def build_active_filters(date_from, date_to)
    filters = []
    if params[:item_type].present?
      filters << { key: "item_type", label: "模型: #{item_type_label(params[:item_type])}", value: params[:item_type] }
    end
    if params[:action_type].present?
      filters << { key: "action_type", label: "操作: #{action_label(params[:action_type])}", value: params[:action_type] }
    end
    if params[:search].present?
      filters << { key: "search", label: "搜索: #{params[:search]}", value: params[:search] }
    end
    if params[:ip_address].present?
      filters << { key: "ip_address", label: "IP: #{params[:ip_address]}", value: params[:ip_address] }
    end
    if date_from || date_to
      label = "时间: "
      label += date_from.to_s if date_from
      label += " ~ "
      label += date_to.to_s if date_to
      filters << { key: "date_range", label: label, value: "#{params[:date_from]}|#{params[:date_to]}" }
    end
    filters
  end

  def build_quick_presets
    today = Date.today
    [
      { label: "今天", params: { date_from: today.to_s, date_to: today.to_s } },
      { label: "昨天", params: { date_from: (today - 1.day).to_s, date_to: (today - 1.day).to_s } },
      { label: "近7天", params: { date_from: (today - 6.days).to_s, date_to: today.to_s } },
      { label: "近30天", params: { date_from: (today - 29.days).to_s, date_to: today.to_s } },
      { label: "删除操作", params: { action_type: "destroy" } },
      { label: "交易相关", params: { item_type: "Entry" } }
    ]
  end

  def generate_csv(logs)
    require "csv"
    CSV.generate(headers: true) do |csv|
      csv << [ "时间", "操作", "模型类型", "记录ID", "描述", "变更摘要", "请求路径", "IP地址" ]
      logs.each do |log|
        csv << [
          log.created_at.strftime("%Y-%m-%d %H:%M:%S"),
          action_label(log.action),
          item_type_label(log.item_type),
          log.item_id,
          log.description,
          log.changes_summary,
          log.request_path,
          log.ip_address
        ]
      end
    end
  end

  def generate_json(logs)
    logs.map do |log|
      {
        id: log.id,
        created_at: log.created_at.iso8601,
        action: log.action,
        action_label: action_label(log.action),
        item_type: log.item_type,
        item_type_label: item_type_label(log.item_type),
        item_id: log.item_id,
        description: log.description,
        changes_summary: log.changes_summary,
        request_path: log.request_path,
        request_method: log.request_method,
        ip_address: log.ip_address
      }
    end
  end

  # ---- Helper 方法（通过 helper_method 暴露给视图，避免视图直接引用 Controller 常量） ----

  def item_type_label(type)
    ITEM_TYPE_LABELS[type] || type
  end
  helper_method :item_type_label

  def action_label(action)
    ACTION_LABELS[action] || action
  end
  helper_method :action_label

  def item_type_options
    ITEM_TYPE_LABELS.to_a
  end
  helper_method :item_type_options

  def action_type_options
    ACTION_LABELS.to_a
  end
  helper_method :action_type_options
end
