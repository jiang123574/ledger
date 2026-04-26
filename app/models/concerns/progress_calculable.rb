# 可复用的进度计算模块
# 提供统一的进度百分比计算和状态判断方法
#
# 使用方式：
#   class Budget < ApplicationRecord
#     include ProgressCalculable
#
#     # 可选：覆盖计算方法
#     def progress_total
#       amount
#     end
#
#     def progress_current
#       spent_amount
#     end
#   end

module ProgressCalculable
  extend ActiveSupport::Concern

  # 进度百分比（0-100）
  # 默认实现：progress_current / progress_total * 100
  # 子类可覆盖 progress_total 和 progress_current 方法
  def progress_percentage
    total = progress_total.to_d
    return 0 if total <= 0
    (progress_current.to_d / total * 100).round(1)
  end

  # 剩余金额
  def progress_remaining
    progress_total.to_d - progress_current.to_d
  end

  # 是否超额/超支
  def progress_exceeded?
    progress_remaining < 0
  end

  # 是否接近限制（80%-100%）
  def progress_near_limit?
    progress_percentage >= 80 && progress_percentage < 100
  end

  # 是否已完成（100%）
  def progress_completed?
    progress_percentage >= 100
  end

  # 默认进度颜色
  # 子类可覆盖 status_color 方法提供自定义逻辑
  def progress_color
    return "red" if progress_exceeded?
    return "yellow" if progress_near_limit?
    return "green" if progress_completed?
    "blue"
  end

  # 以下方法需要子类实现或覆盖

  # 进度总量（默认返回 amount 或 total_amount）
  def progress_total
    respond_to?(:amount) ? amount : (respond_to?(:total_amount) ? total_amount : 0)
  end

  # 进度当前值（默认返回 spent_amount 或计算值）
  def progress_current
    respond_to?(:spent_amount) ? spent_amount : 0
  end
end
