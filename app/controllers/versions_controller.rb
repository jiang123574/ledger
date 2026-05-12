# frozen_string_literal: true

class VersionsController < ApplicationController
  before_action :set_operation_log, only: [ :show ]

  def index
    @operation_logs = OperationLog.order(created_at: :desc)
                                .page(params[:page])
                                .per(50)

    # 按模型类型过滤
    if params[:item_type].present?
      @operation_logs = @operation_logs.where(item_type: params[:item_type])
    end

    # 按操作类型过滤
    if params[:action_type].present?
      @operation_logs = @operation_logs.where(action: params[:action_type])
    end

    # 搜索（转义 LIKE 通配符防止注入）
    if params[:search].present?
      search_term = params[:search].to_s.gsub(/[%_]/) { |char| "\\#{char}" }
      @operation_logs = @operation_logs.where("description LIKE ?", "%#{search_term}%")
    end
  end

  def show
  end

  private

  def set_operation_log
    @operation_log = OperationLog.find(params[:id])
  end
end
