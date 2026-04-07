# frozen_string_literal: true

class VersionsController < ApplicationController
  before_action :set_activity_log, only: [ :show, :revert ]

  def index
    @activity_logs = ActivityLog.order(created_at: :desc)
                                .page(params[:page])
                                .per(50)

    # 按模型类型过滤
    if params[:item_type].present?
      @activity_logs = @activity_logs.where(item_type: params[:item_type])
    end

    # 按事件类型过滤
    if params[:action_type].present?
      @activity_logs = @activity_logs.where(action: params[:action_type])
    end

    # 搜索
    if params[:search].present?
      @activity_logs = @activity_logs.where("description LIKE ?", "%#{params[:search]}%")
    end
  end

  def show
  end

  def revert
    if @activity_log.revert!
      redirect_to versions_path, notice: "已成功回滚操作"
    else
      redirect_to versions_path, alert: "回滚失败"
    end
  end

  private

  def set_activity_log
    @activity_log = ActivityLog.find(params[:id])
  end
end
